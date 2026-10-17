import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/repertoire/repertoire_graph.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/san_text.dart';
import '../widgets/spoken.dart';
import 'repertoire_controller.dart';

// Geometry of the tree (D-050): these numbers define how the outline
// reads, so they are named here rather than snapped to the spacing scale.

/// A row: one line of moves, 32 high (D-096: compact, but still a
/// reasonable finger target; the mockup's 26 is too small to tap).
const _rowHeight = 32.0;

/// The fold arrow's column at the start of every row, and its icon.
const _foldWidth = 20.0;
const _foldIcon = 12.0;

/// The branch guides (├ └): where a level's vertical line stands, the
/// column it takes, its tick and its thickness. A level is indented by the
/// inset plus the column: the line stands under the fold arrow above.
const _guideInset = 9.0;
const _guideColumn = 12.0;
const _guideTick = 10.0;
const _guideWidth = 1.5;
const _levelIndent = _guideInset + _guideColumn;

/// Levels that are still indented; deeper ones stay at the last step.
const _maxIndentLevels = 5;

/// The current row's background radius, the current move's pill padding,
/// the marks' size, and how many moves before the current one a long line
/// keeps when it is cut short to show the current move.
const _currentRadius = 8.0;
const _rowEnd = 6.0;
const _pillSide = 6.0;
const _pillLead = 4.0;
const _pillTop = 1.0;
const _markIcon = 14.0;
const _leadMoves = 2;

/// The move number on the current move's black pill.
const _currentNumberAlpha = 0.7;

/// One row of the tree: the moves from a branching point up to the next one
/// (or to the end of the line, or to a transposition).
class _Segment {
  _Segment({
    required this.moves,
    required this.path,
    required this.depth,
    required this.transposition,
    required this.forks,
    this.share,
    this.last = true,
    this.trail = const [],
  });

  final List<RepMove> moves;

  /// Path of the last move ('/e2e4/e7e5'); also the key of its expansion.
  final String path;

  /// Branching level (0 – from the root).
  final int depth;

  /// The last move reaches a position shown in full elsewhere.
  final bool transposition;

  /// Continuations after the last move (0 – the line ends here).
  final int forks;

  /// The first move's share among the opponent's replies (%), shown only
  /// when the weights differ.
  final int? share;

  /// The last of its siblings: its guide stops at the middle of the row (└).
  final bool last;

  /// For each ancestor level (from 1), whether its guide runs on past
  /// this row (the ancestor has siblings below).
  final List<bool> trail;
}

/// The repertoire as an outline of lines (F-REP-07, D-050): a line runs as
/// notation until it branches; its continuations are indented rows under
/// it. A move opens its position; the row (or the arrow) folds the branch.
/// Transpositions are shown once in full; other occurrences link to it.
class RepertoireTree extends ConsumerStatefulWidget {
  const RepertoireTree({super.key, required this.c, required this.onOpen, this.problemKeys = const {}, this.tools});
  final RepertoireController c;

  /// The filter and fold-all controls, shown by the parent (D-052).
  final RepertoireTreeTools? tools;

  /// Opens a position in the browser.
  final void Function(PositionKey key) onOpen;

  /// Positions considered problematic (for the filter).
  final Set<PositionKey> problemKeys;

  @override
  ConsumerState<RepertoireTree> createState() => _RepertoireTreeState();
}

/// The tree's own tools (only problems, fold / unfold all), drawn outside
/// the tree on the "Moves | Tree" row so they cost no extra row (D-052).
class RepertoireTreeTools extends ChangeNotifier {
  _RepertoireTreeState? _state;

  bool get onlyProblems => _state?._onlyProblems ?? false;
  bool get allExpanded => _state?._reportedAll ?? false;

  void toggleOnlyProblems() => _state?._toggleOnlyProblems();
  void toggleAll() => _state?._toggleAll();

  void _changed() => notifyListeners();
}

class _RepertoireTreeState extends ConsumerState<RepertoireTree> with AutomaticKeepAliveClientMixin {
  /// Paths of rows whose continuations are shown.
  final Set<String> _expanded = {};
  bool _onlyProblems = false;
  Map<PositionKey, String> _first = {};
  final Map<String, int> _lines = {};
  int _revision = -1;
  PositionKey? _shownKey;
  final _currentKey = GlobalKey();
  final _scroll = ScrollController();
  PositionKey? _tappedKey;

  @override
  void initState() {
    super.initState();
    widget.tools?._state = this;
  }

  @override
  void didUpdateWidget(RepertoireTree old) {
    super.didUpdateWidget(old);
    if (old.tools != widget.tools) {
      if (old.tools?._state == this) old.tools!._state = null;
      widget.tools?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.tools?._state == this) widget.tools!._state = null;
    _scroll.dispose();
    super.dispose();
  }

  void _select(PositionKey key) {
    _tappedKey = key;
    widget.onOpen(key);
  }

  @override
  bool get wantKeepAlive => true;

  RepertoireGraph get _g => widget.c.graph!;

  void _computeFirst(RepertoireGraph g) {
    // Pre-order DFS, main moves first: the first path that reaches a key.
    final first = <PositionKey, String>{g.rootKey: ''};
    final stack = <(PositionKey, String)>[(g.rootKey, '')];
    while (stack.isNotEmpty) {
      final (k, p) = stack.removeLast();
      final moves = g.movesFrom(k);
      for (final m in moves.reversed) {
        final path = '$p/${m.uci}';
        if (!first.containsKey(m.toKey)) {
          first[m.toKey] = path;
          stack.add((m.toKey, path));
        }
      }
    }
    _first = first;
  }

  Set<PositionKey> _ancestorsOfProblems(RepertoireGraph g) {
    final out = <PositionKey>{...widget.problemKeys};
    final queue = [...widget.problemKeys];
    while (queue.isNotEmpty) {
      final k = queue.removeLast();
      for (final m in g.movesTo(k)) {
        if (out.add(m.fromKey)) queue.add(m.fromKey);
      }
    }
    return out;
  }

  /// Lines (rows that end a line or transpose) under the row ending at
  /// [path] in [key] – what a folded row hides.
  int _linesFrom(PositionKey key, String path) => _lines[path] ??= () {
    var n = 0;
    for (final m in _g.movesFrom(key)) {
      var last = m;
      var p = '$path/${m.uci}';
      while (_first[last.toKey] == p && _g.movesFrom(last.toKey).length == 1) {
        last = _g.movesFrom(last.toKey).single;
        p = '$p/${last.uci}';
      }
      n += _first[last.toKey] != p || _g.movesFrom(last.toKey).isEmpty ? 1 : _linesFrom(last.toKey, p);
    }
    return n;
  }();

  /// Rows in display order. [all] ignores folding (for "Expand all").
  List<_Segment> _segments(RepertoireGraph g, {bool all = false}) {
    final rows = <_Segment>[];
    final filter = _onlyProblems ? _ancestorsOfProblems(g) : null;
    List<RepMove> next(PositionKey k) =>
        filter == null ? g.movesFrom(k) : g.movesFrom(k).where((m) => filter.contains(m.toKey)).toList();

    void walk(PositionKey key, String path, int depth, List<bool> trail) {
      final children = next(key);
      final opponent = children.where((m) => m.role == MoveRole.opponent).toList();
      final total = opponent.fold(0, (a, m) => a + m.weight);
      final weighted = opponent.length > 1 && total > 0 && opponent.map((m) => m.weight).toSet().length > 1;
      for (final (j, m) in children.indexed) {
        if (rows.length > 3000) return;
        final last = j == children.length - 1;
        final moves = [m];
        var p = '$path/${m.uci}';
        var trans = _first[m.toKey] != p;
        var cont = trans ? const <RepMove>[] : next(m.toKey);
        while (cont.length == 1) {
          final n = cont.single;
          moves.add(n);
          p = '$p/${n.uci}';
          trans = _first[n.toKey] != p;
          cont = trans ? const <RepMove>[] : next(n.toKey);
        }
        rows.add(
          _Segment(
            moves: moves,
            path: p,
            depth: depth,
            transposition: trans,
            forks: cont.length,
            share: weighted && m.role == MoveRole.opponent ? (100 * m.weight / total).round() : null,
            last: last,
            trail: trail,
          ),
        );
        if (cont.isNotEmpty && (all || filter != null || _expanded.contains(p))) {
          walk(moves.last.toKey, p, depth + 1, depth == 0 ? const [] : [...trail, !last]);
        }
      }
    }

    walk(g.rootKey, '', 0, const []);
    return rows;
  }

  /// Opens every branch on the way to [key] (the browser's position).
  void _reveal(PositionKey key) {
    final path = _first[key];
    if (path == null || path.isEmpty) return;
    final parts = path.split('/');
    for (var i = 2; i < parts.length; i++) {
      _expanded.add(parts.sublist(0, i).join('/'));
    }
  }

  void _scrollToCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentKey.currentContext;
      if (!mounted || ctx == null || !_scroll.hasClients) return;
      final target = ctx.findRenderObject();
      if (target == null || !target.attached) return;
      // Only this list may scroll. Scrollable.ensureVisible also moves
      // ancestor PageViews, fighting tab navigation.
      _scroll.position.ensureVisible(target, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
    });
  }

  bool get _allExpanded {
    for (final s in _segments(_g, all: true)) {
      if (s.forks > 0 && !_expanded.contains(s.path)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = context.l10n;
    final g = _g;
    if (_revision != widget.c.revision) {
      _computeFirst(g);
      _lines.clear();
      if (_revision == -1) {
        // Open the first two branching levels right away.
        for (final s in _segments(g, all: true)) {
          if (s.depth < 2) _expanded.add(s.path);
        }
      }
      _revision = widget.c.revision;
    }
    final current = widget.c.inRepertoire ? widget.c.key : null;
    if (current != _shownKey) {
      _shownKey = current;
      if (current != null && current != _tappedKey) {
        _reveal(current);
        _scrollToCurrent();
      }
      _tappedKey = null;
    }
    final rows = _segments(g);
    _report(!_onlyProblems && _allExpanded);
    return rows.isEmpty
        ? Center(child: Text(_onlyProblems ? l.noProblems : l.emptyRepertoire))
        : ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.md, AppSpacing.listBottom),
            itemCount: rows.length,
            itemBuilder: (context, i) => _row(context, rows[i], current),
          );
  }

  bool _reportedAll = false;

  /// Tells the tools row whether everything is open (after this frame).
  void _report(bool allExpanded) {
    if (allExpanded == _reportedAll) return;
    _reportedAll = allExpanded;
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.tools?._changed());
  }

  void _toggleOnlyProblems() {
    setState(() => _onlyProblems = !_onlyProblems);
    widget.tools?._changed();
  }

  void _toggleAll() => setState(() {
    if (_reportedAll) {
      _expanded.clear();
    } else {
      _expanded.addAll([
        for (final s in _segments(_g, all: true))
          if (s.forks > 0) s.path,
      ]);
    }
  });

  /// One row (D-096): fold arrow, the segment's moves in one line (cut
  /// with "…"), the marks in a right column; the current row on a grey
  /// band, the current move in a black pill. Continuations hang on branch
  /// guides.
  Widget _row(BuildContext context, _Segment s, PositionKey? current) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final f = ref.watch(notationFormatterProvider);
    final canFold = s.forks > 0 && !_onlyProblems;
    final open = _onlyProblems || _expanded.contains(s.path);
    void toggle() => setState(() => open ? _expanded.remove(s.path) : _expanded.add(s.path));
    final small = context.tt.meta.tabular;

    var currentIndex = -1;
    for (var i = 0; i < s.moves.length; i++) {
      final m = s.moves[i];
      if (m.toKey == current && !(s.transposition && i == s.moves.length - 1)) currentIndex = i;
    }
    // A long line cut short still shows the current move: it starts a few
    // moves before it, after "…".
    final from = currentIndex > _leadMoves + 1 ? currentIndex - _leadMoves : 0;
    final spans = <InlineSpan>[
      if (from > 0) TextSpan(text: '… ', style: context.tt.moveNumber),
      for (var i = from; i < s.moves.length; i++) ...[
        if (i > from) const TextSpan(text: ' '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _move(context, f, s.moves[i], first: i == 0, forceNumber: i == from, isCurrent: i == currentIndex),
        ),
      ],
    ];

    final problem = s.moves.any((m) => widget.problemKeys.contains(m.toKey));
    final comment = s.moves.any((m) => m.comment.isNotEmpty);
    final marks = <Widget>[
      if (s.share != null)
        Tooltip(
          message: l.treeOpponentShare(s.share!),
          child: Text('${s.share}%', style: small),
        ),
      if (problem)
        Tooltip(
          message: l.frequentMistakes,
          child: Icon(AppIcons.warning, size: _markIcon, color: cs.error),
        ),
      if (comment)
        Tooltip(
          message: l.moveComment,
          child: Icon(AppIcons.comment, size: _markIcon, color: cs.onSurfaceVariant),
        ),
      if (s.transposition)
        Semantics(
          button: true,
          label: l.transposition,
          excludeSemantics: true,
          child: Tooltip(
            message: l.transposition,
            child: InkResponse(
              onTap: () => _select(s.moves.last.toKey),
              radius: AppSizes.tapTarget / 2,
              child: SizedBox(
                height: _rowHeight,
                child: Icon(AppIcons.transposition, size: _markIcon, color: cs.onSurfaceVariant),
              ),
            ),
          ),
        )
      else if (s.forks > 0)
        Text(l.linesN(_linesFrom(s.moves.last.toKey, s.path)), style: small)
      else
        Text(l.lineEnds, style: small),
    ];

    final isCurrentRow = currentIndex >= 0;
    final row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canFold ? toggle : null,
      child: Container(
        height: _rowHeight,
        padding: const EdgeInsets.only(right: _rowEnd),
        decoration: isCurrentRow
            ? BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(_currentRadius))
            : null,
        child: Row(
          children: [
            SizedBox(
              width: _foldWidth,
              height: _rowHeight,
              child: canFold
                  ? Semantics(
                      button: true,
                      expanded: open,
                      label: open ? l.collapse : l.expand,
                      excludeSemantics: true,
                      child: Icon(open ? AppIcons.expand : AppIcons.chevronRight, size: _foldIcon, color: cs.onSurface),
                    )
                  : null,
            ),
            AppGap.h4,
            Expanded(
              child: Text.rich(
                TextSpan(children: spans),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            AppGap.h8,
            for (final (i, m) in marks.indexed) ...[if (i > 0) AppGap.h4, m],
          ],
        ),
      ),
    );
    if (s.depth == 0) return row;
    // Continuations hang on branch guides: a line per open ancestor level
    // and this row's own ├ or └.
    final level = s.depth.clamp(1, _maxIndentLevels);
    return CustomPaint(
      painter: _GuidePainter(
        level: level,
        last: s.last,
        trail: s.trail.take(level - 1).toList(),
        color: cs.outlineVariant,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: _indentOf(level)),
        child: row,
      ),
    );
  }

  Widget _move(
    BuildContext context,
    NotationFormatter f,
    RepMove m, {
    required bool first,
    required bool forceNumber,
    required bool isCurrent,
  }) {
    final tt = context.tt;
    final cs = Theme.of(context).colorScheme;
    final pos = positionFromFen(_g.positions[m.fromKey]!.fen);
    final white = pos.turn == Side.white;
    final number = white ? '${pos.fullmoves}. ' : (forceNumber ? '${pos.fullmoves}... ' : '');
    final fg = isCurrent ? tt.currentMoveForeground : null;
    // The branching move in ink and SemiBold, the rest of the line in a
    // quieter grey (D-096); the user's other choices stay grey.
    final base = first ? tt.moveMain : tt.moveNumber;
    final moveStyle = base.copyWith(
      color: fg ?? (m.role == MoveRole.alternative ? cs.onSurfaceVariant : (first ? cs.onSurface : cs.secondary)),
    );
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: number,
            style: tt.moveNumber.copyWith(
              color: isCurrent ? fg?.withValues(alpha: _currentNumberAlpha) : cs.onSurfaceVariant,
            ),
          ),
          ...f.spans(m.san, moveStyle),
        ],
      ),
      maxLines: 1,
      softWrap: false,
    );
    return Semantics(
      button: true,
      selected: isCurrent,
      label: '$number ${spokenSan(m.san, context.l10n)}'.trim(),
      excludeSemantics: true,
      child: GestureDetector(
        key: isCurrent ? _currentKey : null,
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(m.toKey),
        child: SizedBox(
          height: _rowHeight,
          child: Center(
            widthFactor: 1,
            // The pill reaches past the move instead of pushing it: picking
            // a move never shifts the line.
            child: isCurrent
                ? Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned(
                        // Into the space before the move, and past it over
                        // its own end room, so the next move stays clear.
                        left: -_pillLead,
                        right: 0,
                        top: -_pillTop,
                        bottom: -_pillTop,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: tt.currentMoveBackground, borderRadius: AppRadius.xsAll),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: _pillSide),
                        child: text,
                      ),
                    ],
                  )
                : text,
          ),
        ),
      ),
    );
  }
}

/// Where a row at [level] (from 1) starts: its guide column and the
/// levels above it.
double _indentOf(int level) => _levelIndent * (level - 1) + _levelIndent;

/// The branch guides of a continuation row (├ └, D-096): for each
/// ancestor level whose branch goes on, a vertical line through the row;
/// at the row's own level a line down to its middle (└, the last child) or
/// through it (├), and a tick toward the row.
class _GuidePainter extends CustomPainter {
  const _GuidePainter({required this.level, required this.last, required this.trail, required this.color});
  final int level;
  final bool last;
  final List<bool> trail;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = _guideWidth;
    double xOf(int l) => _guideInset + _levelIndent * (l - 1) + _guideWidth / 2;
    for (var k = 1; k < level; k++) {
      if (k - 1 < trail.length && trail[k - 1]) {
        canvas.drawLine(Offset(xOf(k), 0), Offset(xOf(k), size.height), line);
      }
    }
    final x = xOf(level);
    final mid = size.height / 2;
    canvas.drawLine(Offset(x, 0), Offset(x, last ? mid : size.height), line);
    canvas.drawLine(Offset(x, mid), Offset(x + _guideTick, mid), line);
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.level != level || old.last != last || old.color != color || !_sameTrail(old.trail, trail);

  static bool _sameTrail(List<bool> a, List<bool> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
