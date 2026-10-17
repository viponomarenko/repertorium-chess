/// One board geometry for every screen with a board (D-052).
///
/// Portrait: the board is full width by default; a grip under it drags the
/// board smaller to give the text more room (or back). The size is a single
/// setting, so a board resized on one screen is the same on the others.
/// Landscape: the board fills the height on the left, the text on the right.
/// A tablet in portrait: the board leaves the text its share of the height;
/// both stand in one column in the middle.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../app/providers.dart';
import '../theme/tokens.dart';

/// Smallest board share of the width.
const kMinBoardScale = 0.5;

/// Reading mode: the board this share of the width, the rest for text.
const kReadingBoardScale = 0.6;

/// Height of the grip under the board: compact, so the text under the
/// board keeps its room (D-095).
const kBoardGripHeight = 14.0;

/// Room every screen keeps under the board for its text, at 100 % text
/// size; screens with open panels ask for more via [BoardLayout.extraBelow].
const kMinTextBelowBoard = 160.0;

void setBoardScale(WidgetRef ref, double v) {
  final x = v.clamp(kMinBoardScale, 1.0).toDouble();
  ref.read(settingsProvider.notifier).update((s) => s.copyWith(boardScale: x));
}

/// Switches between the full-width board and reading mode.
void toggleReadingBoard(WidgetRef ref) =>
    setBoardScale(ref, ref.read(settingsProvider).boardScale < 0.99 ? 1.0 : kReadingBoardScale);

/// Where the board ended up; passed to the panel builder.
class BoardGeometry {
  const BoardGeometry({required this.boardSize, required this.wide, required this.constraints, this.gutter = 0});
  final double boardSize;

  /// With [BoardLayout.belowBleeds]: the side margin that keeps the text
  /// in one column with a board narrower than the screen.
  final double gutter;

  /// Landscape: the panel stands beside the board, not under it.
  final bool wide;
  final BoxConstraints constraints;
}

class BoardLayout extends ConsumerStatefulWidget {
  const BoardLayout({
    super.key,
    required this.board,
    required this.below,
    this.extraBelow,
    this.belowBleeds = false,
    this.gripHeight = kBoardGripHeight,
  });

  /// Height of the grip under the board (the analysis keeps it tighter).
  final double gripHeight;

  /// The text has a bar that goes from edge to edge, so it takes the whole
  /// width and keeps the rest in the column itself ([BoardGeometry.gutter]).
  final bool belowBleeds;

  /// The board; laid out as a square of the computed size.
  final Widget board;

  /// Text under the board (portrait) or beside it (landscape).
  final Widget Function(BuildContext context, BoardGeometry g) below;

  /// Room needed under the board beyond [kMinTextBelowBoard] (open panels),
  /// not scaled with the text size.
  final double Function(BoxConstraints c)? extraBelow;

  /// Landscape when the text beside a full-height board gets at least
  /// 280 wide; otherwise the board stands above the text.
  static bool isWide(BoxConstraints c) => c.maxWidth >= 560 && c.maxWidth - c.maxHeight >= 280;

  @override
  ConsumerState<BoardLayout> createState() => _BoardLayoutState();
}

class _BoardLayoutState extends ConsumerState<BoardLayout> {
  /// Board share of the width while the grip is dragged (saved on release).
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(settingsProvider.select((s) => s.boardScale));
    final scale = _drag ?? saved;
    return LayoutBuilder(
      builder: (context, c) {
        if (BoardLayout.isWide(c)) {
          final size = c.maxHeight - 2 * AppSpacing.sm;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: SizedBox.square(dimension: size, child: widget.board),
              ),
              Expanded(
                child: widget.below(context, BoardGeometry(boardSize: size, wide: true, constraints: c)),
              ),
            ],
          );
        }
        final t = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
        // A tablet standing upright: a board from edge to edge would leave
        // the text a strip at the bottom, so the text keeps its share of
        // the height and stands in one column with the board (D-084).
        final tablet = c.maxWidth >= AppBreakpoints.wide;
        final text =
            math.max(kMinTextBelowBoard * t, tablet ? c.maxHeight * AppBreakpoints.textShareBelowBoard : 0.0) +
            (widget.extraBelow?.call(c) ?? 0);
        final size = math.max(120.0, math.min(c.maxWidth * scale, c.maxHeight - text - widget.gripHeight));
        final inset = tablet && size < c.maxWidth - 2 * AppSpacing.sm;
        final gutter = inset ? math.max(0.0, (c.maxWidth - math.max(size, AppSizes.minPanelWidth)) / 2) : 0.0;
        return Column(
          children: [
            if (inset) AppGap.v8,
            Center(
              child: SizedBox.square(dimension: size, child: widget.board),
            ),
            _grip(context, c.maxWidth, size, scale),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.belowBleeds ? 0 : gutter),
                child: widget.below(
                  context,
                  BoardGeometry(boardSize: size, wide: false, constraints: c, gutter: widget.belowBleeds ? gutter : 0),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Drag down for a bigger board, up for more text; a double tap switches
  /// between full width and reading mode.
  Widget _grip(BuildContext context, double width, double size, double scale) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    String pct(double v) => l.percentValue((v.clamp(kMinBoardScale, 1.0) * 100).round());
    return Semantics(
      slider: true,
      label: l.boardSize,
      hint: l.boardSizeHint,
      value: pct(scale),
      increasedValue: pct(scale + 0.1),
      decreasedValue: pct(scale - 0.1),
      onIncrease: () => setBoardScale(ref, scale + 0.1),
      onDecrease: () => setBoardScale(ref, scale - 0.1),
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('board-size-grip'),
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => toggleReadingBoard(ref),
        // Start from the board as drawn (the height may cap it below the
        // saved share), so the drag moves it at once.
        onVerticalDragStart: (_) => setState(() => _drag = size / width),
        onVerticalDragUpdate: (d) =>
            setState(() => _drag = ((_drag ?? scale) + d.delta.dy / width).clamp(kMinBoardScale, 1.0).toDouble()),
        onVerticalDragEnd: (_) {
          final v = _drag;
          if (v != null) setBoardScale(ref, v);
          setState(() => _drag = null);
        },
        child: SizedBox(
          height: widget.gripHeight,
          width: double.infinity,
          child: Center(
            child: Container(
              width: AppSizes.gripWidth,
              height: AppSizes.gripHeight,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: AppOpacity.guide),
                borderRadius: AppRadius.full,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
