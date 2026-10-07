import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/repertoire/repertoire_graph.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/notation_view.dart';
import '../widgets/san_text.dart';
import '../widgets/spoken.dart';
import 'repertoire_controller.dart';

// Geometry of the tree (D-050): these numbers define how the outline
// reads, so they are named here rather than snapped to the spacing scale.

/// The fold arrow's column at the start of every row; a row is
/// [kMoveChipMinHeight] high.
const _foldWidth = 32.0;

/// How far each branching level is indented.
const _levelIndent = 16.0;

/// Levels that are still indented; deeper ones stay at the last step.
const _maxIndentLevels = 5;

/// The guide line of a continuation: under the middle of the fold arrow of
/// the row above.
const _guideInset = 15.0;
const _guideWidth = 1.5;

/// The narrowest move target (36 x 40, as in the notation, D-046).
const _moveMinWidth = 40.0;

/// Around a small mark after a move (share, problem, comment).
const _markPadding = EdgeInsets.only(left: AppSpacing.xxs, right: AppSpacing.xs);

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

    void walk(PositionKey key, String path, int depth) {
      final children = next(key);
      final opponent = children.where((m) => m.role == MoveRole.opponent).toList();
      final total = opponent.fold(0, (a, m) => a + m.weight);
      final weighted = opponent.length > 1 && total > 0 && opponent.map((m) => m.weight).toSet().length > 1;
      for (final m in children) {
        if (rows.length > 3000) return;
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
          ),
        );
        if (cont.isNotEmpty && (all || filter != null || _expanded.contains(p))) {
          walk(moves.last.toKey, p, depth + 1);
        }
      }
    }

    walk(g.rootKey, '', 0);
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

  Widget _row(BuildContext context, _Segment s, PositionKey? current) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final f = ref.watch(notationFormatterProvider);
    final canFold = s.forks > 0 && !_onlyProblems;
    final open = _onlyProblems || _expanded.contains(s.path);
    void toggle() => setState(() => open ? _expanded.remove(s.path) : _expanded.add(s.path));
    final small = context.tt.meta.tabular;

    final items = <Widget>[];
    for (var i = 0; i < s.moves.length; i++) {
      final m = s.moves[i];
      final isCurrent = m.toKey == current && !(s.transposition && i == s.moves.length - 1);
      items.add(_move(context, f, m, forceNumber: i == 0, isCurrent: isCurrent));
      if (i == 0 && s.share != null) {
        items.add(
          Tooltip(
            message: l.treeOpponentShare(s.share!),
            child: Padding(
              padding: _markPadding,
              child: Text('${s.share}%', style: small),
            ),
          ),
        );
      }
      if (widget.problemKeys.contains(m.toKey)) {
        items.add(
          Padding(
            padding: _markPadding,
            child: Icon(AppIcons.warning, size: AppSizes.iconSm, color: cs.error),
          ),
        );
      }
      if (m.comment.isNotEmpty) {
        items.add(
          Padding(
            padding: _markPadding,
            child: Icon(AppIcons.comment, size: AppSizes.iconSm, color: cs.onSurfaceVariant),
          ),
        );
      }
    }
    if (s.transposition) {
      items.add(
        Semantics(
          button: true,
          child: InkWell(
            onTap: () => _select(s.moves.last.toKey),
            borderRadius: AppRadius.xsAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kMoveChipMinHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.transposition, size: AppSizes.iconSm, color: cs.onSurfaceVariant),
                    AppGap.h4,
                    Text(l.transposition, style: small),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else if (canFold && !open) {
      items.add(
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMoveChipMinHeight),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xxs),
              child: Text('· ${l.linesN(_linesFrom(s.moves.last.toKey, s.path))}', style: small),
            ),
          ),
        ),
      );
    }

    final row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canFold ? toggle : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _foldWidth,
              height: kMoveChipMinHeight,
              child: canFold
                  ? Semantics(
                      button: true,
                      expanded: open,
                      label: open ? l.collapse : l.expand,
                      excludeSemantics: true,
                      child: Icon(
                        open ? AppIcons.expand : AppIcons.chevronRight,
                        size: AppSizes.iconSm,
                        color: cs.onSurface,
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: items),
            ),
          ],
        ),
      ),
    );
    if (s.depth == 0) return row;
    // Continuations: a thin guide line per level, as in the notation.
    final level = (s.depth - 1).clamp(0, _maxIndentLevels);
    return Padding(
      padding: EdgeInsets.only(left: _levelIndent * level + _guideInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: cs.outlineVariant, width: _guideWidth),
          ),
        ),
        child: row,
      ),
    );
  }

  Widget _move(
    BuildContext context,
    NotationFormatter f,
    RepMove m, {
    required bool forceNumber,
    required bool isCurrent,
  }) {
    final tt = context.tt;
    final cs = Theme.of(context).colorScheme;
    final pos = positionFromFen(_g.positions[m.fromKey]!.fen);
    final white = pos.turn == Side.white;
    final number = white ? '${pos.fullmoves}. ' : (forceNumber ? '${pos.fullmoves}... ' : '');
    final fg = isCurrent ? tt.currentMoveForeground : null;
    // The notation's move style for every move (D-053); own side lines
    // (not the main move) grey.
    final moveStyle = tt.moveMain.copyWith(
      color: fg ?? (m.role == MoveRole.alternative ? cs.onSurfaceVariant : cs.onSurface),
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
        child: Container(
          // Same dense 36 x 40 move targets as the notation (D-046).
          constraints: const BoxConstraints(minHeight: kMoveChipMinHeight, minWidth: _moveMinWidth),
          padding: kMoveChipPadding,
          decoration: moveChipDecoration(tt, current: isCurrent),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: number,
                    style: tt.moveNumber.copyWith(color: fg),
                  ),
                  ...f.spans(m.san, moveStyle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
