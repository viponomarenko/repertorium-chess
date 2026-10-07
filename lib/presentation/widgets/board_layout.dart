/// One board geometry for every screen with a board (D-052).
///
/// Portrait: the board is full width by default; a grip under it drags the
/// board smaller to give the text more room (or back). The size is a single
/// setting, so a board resized on one screen is the same on the others.
/// Landscape: the board fills the height on the left, the text on the right.
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

/// Height of the grip under the board.
const kBoardGripHeight = 20.0;

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
  const BoardGeometry({required this.boardSize, required this.wide, required this.constraints});
  final double boardSize;

  /// Landscape: the panel stands beside the board, not under it.
  final bool wide;
  final BoxConstraints constraints;
}

class BoardLayout extends ConsumerStatefulWidget {
  const BoardLayout({super.key, required this.board, required this.below, this.extraBelow});

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
        final reserve = kMinTextBelowBoard * t + (widget.extraBelow?.call(c) ?? 0) + kBoardGripHeight;
        final size = math.max(120.0, math.min(c.maxWidth * scale, c.maxHeight - reserve));
        return Column(
          children: [
            Center(
              child: SizedBox.square(dimension: size, child: widget.board),
            ),
            _grip(context, c.maxWidth, size, scale),
            Expanded(
              child: widget.below(context, BoardGeometry(boardSize: size, wide: false, constraints: c)),
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
          height: kBoardGripHeight,
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
