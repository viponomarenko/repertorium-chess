import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../domain/pgn/pgn_model.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'san_text.dart';
import 'spoken.dart';

/// NAG code -> symbol (F-VIEW-02).
String nagSymbol(int nag) => switch (nag) {
  1 => '!',
  2 => '?',
  3 => '!!',
  4 => '??',
  5 => '!?',
  6 => '?!',
  7 => '□',
  // 11/12: equal, quiet / active play – shown as plain equality.
  10 || 11 || 12 => '=',
  13 => '∞',
  14 => '⩲',
  15 => '⩱',
  16 => '±',
  17 => '∓',
  18 => '+−',
  19 => '−+',
  22 || 23 => '⨀',
  32 || 33 => '⟳',
  36 || 37 => '↑',
  40 || 41 => '→',
  44 || 45 => '=/∞',
  132 || 133 => '⇆',
  138 || 139 => '⊕',
  140 => '∆',
  146 => 'N',
  // Rare codes have no common symbol: hidden rather than shown as "$11".
  _ => '',
};

String moveNumberText(GameNode n, {bool forceNumber = false}) {
  final p = n.parent!.position;
  if (p.turn == Side.white) return '${p.fullmoves}. ';
  return forceNumber ? '${p.fullmoves}... ' : '';
}

String moveLabel(GameNode n, {bool forceNumber = false}) => '${moveNumberText(n, forceNumber: forceNumber)}${n.san}';

/// Geometry of a move in every notation (D-052): moves stand close like
/// text, 36 high; the current move is inverted in a rounded chip.
const kMoveChipMinHeight = AppSizes.moveRow;
const kMoveChipPadding = AppInsets.moveChip;

BoxDecoration? moveChipDecoration(TabiyaText tt, {required bool current}) =>
    current ? BoxDecoration(color: tt.currentMoveBackground, borderRadius: AppRadius.xsAll) : null;

/// One move outside [NotationView] (the path under the board, a line of
/// explored moves): the same fonts, sizes and chip as the notation — the
/// number in [TabiyaText.moveNumber], the move in [TabiyaText.moveMain].
class MoveChip extends ConsumerWidget {
  const MoveChip({
    super.key,
    this.number = '',
    required this.san,
    this.current = false,
    this.color,
    this.onTap,
    this.tapHeight = kMoveChipMinHeight,
  });

  /// "12. " / "12... " or empty.
  final String number;
  final String san;
  final bool current;

  /// Text color instead of the usual (e.g. moves not saved yet).
  final Color? color;
  final VoidCallback? onTap;

  /// Height of the tap area; the chip itself stays [kMoveChipMinHeight].
  final double tapHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = context.tt;
    final f = ref.watch(notationFormatterProvider);
    final fg = current ? tt.currentMoveForeground : color;
    final chip = Container(
      constraints: const BoxConstraints(minHeight: kMoveChipMinHeight),
      padding: kMoveChipPadding,
      decoration: moveChipDecoration(tt, current: current),
      alignment: Alignment.center,
      child: Text.rich(
        TextSpan(
          children: [
            if (number.isNotEmpty)
              TextSpan(
                text: number,
                style: tt.moveNumber.copyWith(color: fg),
              ),
            ...f.spans(san, tt.moveMain.copyWith(color: fg)),
          ],
        ),
        maxLines: 1,
        softWrap: false,
      ),
    );
    final area = ConstrainedBox(
      constraints: BoxConstraints(minHeight: tapHeight),
      child: Center(widthFactor: 1, child: chip),
    );
    return Semantics(
      button: onTap != null,
      selected: current,
      child: onTap == null ? area : InkWell(onTap: onTap, borderRadius: AppRadius.xsAll, child: area),
    );
  }
}

/// A line of moves as text ("4... cxb3 5. Qxb3 Nc6") in the notation's
/// fonts: numbers in [TabiyaText.moveNumber], moves in [TabiyaText.moveMain].
List<InlineSpan> lineSpans(String line, TabiyaText tt, NotationFormatter f, {Color? color}) {
  final number = RegExp(r'^\d+\.+$');
  final out = <InlineSpan>[];
  final words = line.split(' ').where((w) => w.isNotEmpty).toList();
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    final sep = i == words.length - 1 ? '' : ' ';
    if (number.hasMatch(w)) {
      // A number never ends a line apart from its move (no-break space).
      out.add(
        TextSpan(
          text: '$w\u00A0',
          style: tt.moveNumber.copyWith(color: color),
        ),
      );
    } else {
      out
        ..addAll(f.spans(w, tt.moveMain.copyWith(color: color)))
        ..add(TextSpan(text: sep, style: tt.moveMain));
    }
  }
  return out;
}

/// A move line as a widget (engine lines, explored lines).
class MoveLineText extends ConsumerWidget {
  const MoveLineText(this.line, {super.key, this.maxLines, this.color});
  final String line;
  final int? maxLines;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text.rich(
    TextSpan(children: lineSpans(line, context.tt, ref.watch(notationFormatterProvider), color: color)),
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
  );
}

/// A move in a list row ("12... Nf6"): the same fonts and sizes as the
/// notation, without the chip.
class MoveText extends ConsumerWidget {
  const MoveText({super.key, this.number = '', required this.san});
  final String number;
  final String san;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = context.tt;
    final f = ref.watch(notationFormatterProvider);
    return Text.rich(
      TextSpan(
        children: [
          if (number.isNotEmpty) TextSpan(text: number, style: tt.moveNumber),
          ...f.spans(san, tt.moveMain),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Which variations the notation shows open.
enum VariationsMode {
  /// First-level variations open, deeper ones folded to one line.
  auto,
  expanded,
  collapsed,
}

/// Game notation (T-10, T-11): the main line flows as text; each variation
/// is an indented block (12 per level, up to 4 levels) a tone lighter than
/// its parent; comments inline without italics, a size smaller than the
/// moves; NAG symbols colored. Moves sit close together like text but keep
/// a 44 dp tap height (D-035). A folded variation is one line
/// ("▸ 3… Bc5 4. b4 +12"); a tap opens it, ▾ at its start folds it again.
/// The variation holding the current move is always open.
class NotationView extends ConsumerStatefulWidget {
  const NotationView({
    super.key,
    required this.game,
    required this.current,
    required this.onSelect,
    this.onLongPress,
    this.revision = 0,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
    this.showComments = true,
    this.variations = VariationsMode.auto,
  });

  /// Default for the variations; a change resets what the user opened or
  /// folded one by one.
  final VariationsMode variations;

  final ChessGame game;
  final GameNode current;
  final void Function(GameNode node) onSelect;
  final void Function(GameNode node, Offset globalPosition)? onLongPress;

  /// Bump to force a rebuild after tree edits.
  final int revision;
  final EdgeInsets padding;
  final bool showComments;

  @override
  ConsumerState<NotationView> createState() => _NotationViewState();
}

class _NotationViewState extends ConsumerState<NotationView> {
  final _currentKey = GlobalKey();
  final _scroll = ScrollController();

  /// Variations opened or folded by hand (start node -> open).
  final _open = <GameNode, bool>{};

  @override
  void didUpdateWidget(NotationView old) {
    super.didUpdateWidget(old);
    if (old.variations != widget.variations) _open.clear();
    if (old.current != widget.current) {
      _userScrolled = false;
      // Moving into a folded variation (arrows, "next") opens it.
      for (GameNode? n = widget.current; n != null; n = n.parent) {
        if (_open[n] == false) _open.remove(n);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
    }
  }

  bool _isOpen(GameNode v, int depth) {
    final manual = _open[v];
    if (manual != null) return manual;
    for (GameNode? n = widget.current; n != null; n = n.parent) {
      if (identical(n, v)) return true;
    }
    return switch (widget.variations) {
      VariationsMode.expanded => true,
      VariationsMode.collapsed => false,
      VariationsMode.auto => depth <= 1,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
  }

  bool _pendingRecheck = false;

  /// Set when the user scrolls the notation by hand, cleared when the
  /// current move changes: while they read elsewhere, a panel that changes
  /// its height (the engine, on every new depth) must not pull the
  /// notation back to the current move.
  bool _userScrolled = false;

  bool _onUserScroll(UserScrollNotification n) {
    if (n.direction != ScrollDirection.idle) _userScrolled = true;
    return false;
  }

  /// The notation area changes size after a move (panels above it re-lay
  /// out), which can push the current move out of view: check again then.
  bool _onMetrics(ScrollMetricsNotification n) {
    if (!_pendingRecheck && !_userScrolled) {
      _pendingRecheck = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingRecheck = false;
        final ctx = _currentKey.currentContext;
        if (ctx == null || !mounted || _userScrolled) return;
        // Minimal movement: only as much as needed to show the move.
        Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
        Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
      });
    }
    return false;
  }

  void _ensureVisible() {
    final ctx = _currentKey.currentContext;
    if (ctx != null && mounted) {
      Scrollable.ensureVisible(ctx, alignment: 0.4, duration: AppTiming.scrollToMove);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _hasComment(GameNode n) => widget.showComments && n.comments.any((c) => c.text.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final f = ref.watch(notationFormatterProvider);
    final blocks = <Widget>[];
    final rootComment = widget.game.root.comments.map((c) => c.text).where((t) => t.isNotEmpty).join(' ');
    if (widget.showComments && rootComment.isNotEmpty) {
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: MovesText(rootComment, style: tt.comment),
        ),
      );
    }
    final first = widget.game.root.mainChild;
    if (first != null) _line(context, f, blocks, widget.game.root, 0);
    return NotificationListener<UserScrollNotification>(
      onNotification: _onUserScroll,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _onMetrics,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: widget.padding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks),
        ),
      ),
    );
  }

  /// Writes the line continuing from [from] (its first child) at [depth].
  /// [from]'s other children are alternatives to that first move.
  void _line(BuildContext context, NotationFormatter f, List<Widget> out, GameNode from, int depth, {GameNode? start}) {
    var items = <Widget>[];
    void flush() {
      if (items.isEmpty) return;
      out.add(_block(context, depth, items));
      items = [];
    }

    var force = true;
    var node = from;
    // A variation starts with [start] (sibling of the main move).
    if (start != null) {
      items.add(_foldButton(context, start, depth));
      _startComment(context, items, start);
      _move(context, f, items, start, forceNumber: true, depth: depth);
      force = _hasComment(start);
      node = start;
    }
    while (node.children.isNotEmpty) {
      final main = node.children.first;
      _startComment(context, items, main);
      // After any comment the reader needs the move number again ("5...").
      final hasStart = widget.showComments && main.startCommentText.isNotEmpty;
      _move(context, f, items, main, forceNumber: force || hasStart, depth: depth);
      force = _hasComment(main);
      final variations = node.children.skip(1).toList();
      if (variations.isNotEmpty) {
        flush();
        for (final v in variations) {
          if (_isOpen(v, depth + 1)) {
            _line(context, f, out, node, depth + 1, start: v);
          } else {
            out.add(_folded(context, f, v, depth + 1));
          }
        }
        force = true;
      }
      node = main;
    }
    flush();
  }

  /// ▾ at the start of an open variation: folds it.
  Widget _foldButton(BuildContext context, GameNode v, int depth) => Semantics(
    button: true,
    label: context.l10n.hideVariation,
    excludeSemantics: true,
    child: InkResponse(
      onTap: () => setState(() => _open[v] = false),
      radius: 20,
      child: SizedBox(
        width: AppSizes.foldToggle,
        height: kMoveChipMinHeight,
        child: Icon(AppIcons.expand, size: AppSizes.iconSm, color: context.tt.variation(depth).color),
      ),
    ),
  );

  /// A folded variation: its first moves and how many more; a tap opens it.
  Widget _folded(BuildContext context, NotationFormatter f, GameNode v, int depth) {
    final tt = context.tt;
    final style = tt.variation(depth);
    final shown = <GameNode>[];
    for (GameNode? n = v; n != null && shown.length < 3; n = n.mainChild) {
      shown.add(n);
    }
    final hidden = 1 + v.subtreeSize - shown.length;
    final text = [for (var i = 0; i < shown.length; i++) moveLabel(shown[i], forceNumber: i == 0)].join(' ');
    return _indented(
      context,
      depth,
      Semantics(
        button: true,
        label: context.l10n.foldedVariation(text, hidden),
        excludeSemantics: true,
        child: InkWell(
          onTap: () => setState(() => _open[v] = true),
          borderRadius: AppRadius.xsAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMoveChipMinHeight),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: AppSizes.foldToggle,
                  child: Icon(AppIcons.chevronRight, size: AppSizes.iconSm, color: style.color),
                ),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        ...f.spans(text, style),
                        if (hidden > 0) TextSpan(text: '  +$hidden', style: tt.meta.tabular),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppGap.h8,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _indented(BuildContext context, int depth, Widget child) {
    final tt = context.tt;
    final indent = TabiyaText.indentPerLevel * (depth - 1).clamp(0, TabiyaText.maxIndentDepth);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: tt.variation(depth).color!.withValues(alpha: AppOpacity.guide),
              width: AppSpacing.xxs,
            ),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _block(BuildContext context, int depth, List<Widget> items) {
    final wrap = Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: items);
    if (depth == 0) return wrap;
    return _indented(
      context,
      depth,
      Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xxs),
        child: wrap,
      ),
    );
  }

  void _startComment(BuildContext context, List<Widget> items, GameNode n) {
    if (!widget.showComments) return;
    final t = n.startCommentText;
    if (t.isEmpty) return;
    items.add(_comment(context, t));
  }

  Widget _comment(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    child: MovesText(text, style: context.tt.comment),
  );

  void _move(
    BuildContext context,
    NotationFormatter f,
    List<Widget> items,
    GameNode n, {
    required bool forceNumber,
    required int depth,
  }) {
    final tt = context.tt;
    final isCurrent = identical(n, widget.current);
    final moveStyle = depth == 0 ? tt.moveMain : tt.variation(depth);
    final numberStyle = depth == 0 ? tt.moveNumber : tt.variation(depth);
    final moveNag = n.nags.where((x) => x >= 1 && x <= 6).toList();
    final otherNags = n.nags.where((x) => x > 6).map(nagSymbol).where((t) => t.isNotEmpty).join(' ');
    final nagColor = moveNag.isEmpty ? null : tt.nag.forNag(moveNag.first);
    final fg = isCurrent ? tt.currentMoveForeground : null;
    final spans = <InlineSpan>[
      TextSpan(
        text: moveNumberText(n, forceNumber: forceNumber),
        style: numberStyle.copyWith(color: fg),
      ),
      ...f.spans(n.san!, moveStyle.copyWith(color: fg)),
      // NAG right after the move, no space (T-10).
      if (moveNag.isNotEmpty)
        TextSpan(
          text: moveNag.map(nagSymbol).join(),
          style: moveStyle.copyWith(color: fg ?? nagColor, fontWeight: context.tt.moveMain.fontWeight),
        ),
      if (otherNags.isNotEmpty)
        TextSpan(
          text: ' $otherNags',
          style: moveStyle.copyWith(color: fg),
        ),
    ];
    // Screen readers get the spoken form ("Кінь f3, шах"), not letters.
    final label =
        '${moveNumberText(n, forceNumber: forceNumber)} ${spokenSan(n.san!, context.l10n)} ${moveNag.map(nagSymbol).join()}'
            .trim();
    items.add(
      Semantics(
        button: true,
        selected: isCurrent,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          key: isCurrent ? _currentKey : null,
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onSelect(n),
          onLongPressStart: widget.onLongPress == null ? null : (d) => widget.onLongPress!(n, d.globalPosition),
          child: Container(
            // Dense rows the user asked for (36 high, D-046): moves stand
            // close like text; still a comfortable 36 x 40 target.
            constraints: const BoxConstraints(minHeight: kMoveChipMinHeight, minWidth: 40),
            padding: kMoveChipPadding,
            decoration: moveChipDecoration(tt, current: isCurrent),
            // widthFactor keeps the chip as wide as the move (inside a Wrap
            // a bare alignment would stretch it to the full line).
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: Text.rich(TextSpan(children: spans)),
            ),
          ),
        ),
      ),
    );
    if (_hasComment(n)) items.add(_comment(context, n.commentText));
  }
}
