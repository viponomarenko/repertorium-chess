import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A short message about what just happened, maybe with one action
/// ("Undo"). It comes in at the top of the screen, where it covers nothing
/// the hand is working with (D-087): a drop falls from the top edge,
/// spreads into a capsule and the words fade in; it goes the same way back.
@immutable
class AppNotice {
  const AppNotice(this.text, {this.actionLabel, this.onAction});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Shows [text] at the top of the app (see [AppNotice]); a new notice
/// replaces the one on screen. Does nothing while no [NoticeHost] is
/// mounted.
void showNotice(String text, {String? actionLabel, VoidCallback? onAction}) =>
    _NoticeHostState._current?._show(AppNotice(text, actionLabel: actionLabel, onAction: onAction));

/// Hides the notice on screen, if any.
void hideNotice() => _NoticeHostState._current?._hide();

/// Holds the notices over the whole app: put it in `MaterialApp.builder`.
class NoticeHost extends StatefulWidget {
  const NoticeHost({super.key, required this.child});
  final Widget child;

  /// How long a notice stays: a little longer when it offers an action.
  static const Duration plain = Duration(seconds: 4);
  static const Duration withAction = Duration(seconds: 6);

  /// The widest a notice gets, as a share of the screen.
  static const double maxWidthShare = 0.9;

  @override
  State<NoticeHost> createState() => _NoticeHostState();
}

class _NoticeHostState extends State<NoticeHost> with SingleTickerProviderStateMixin {
  static _NoticeHostState? _current;

  /// Drop, spread and words in: 0…[_dropEnd] the drop falls, then it
  /// spreads until [_spreadEnd], the words fade in over the last part.
  static const Duration _inDuration = Duration(milliseconds: 700);
  static const Duration _outDuration = Duration(milliseconds: 450);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _inDuration,
    reverseDuration: _outDuration,
  );
  AppNotice? _notice;
  AppNotice? _next;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _current = this;
    _c.addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    if (identical(_current, this)) _current = null;
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  bool get _motion => AppMotion.of(context).enabled;

  void _show(AppNotice n) {
    if (!mounted) return;
    if (_notice != null && _c.value > 0) {
      // One at a time: the old one goes back up, then the new one falls.
      _next = n;
      _hide();
      return;
    }
    setState(() => _notice = n);
    _timer?.cancel();
    if (_motion) {
      _c.forward(from: 0);
    } else {
      _c.value = 1;
      _arm();
    }
  }

  void _hide() {
    _timer?.cancel();
    if (_notice == null) return;
    if (_motion && _c.value > 0) {
      _c.reverse();
    } else {
      _c.value = 0;
      _onStatus(AnimationStatus.dismissed);
    }
  }

  void _arm() {
    _timer?.cancel();
    final n = _notice;
    if (n == null) return;
    _timer = Timer(n.actionLabel == null ? NoticeHost.plain : NoticeHost.withAction, _hide);
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) _arm();
    if (s == AnimationStatus.dismissed) {
      final next = _next;
      _next = null;
      setState(() => _notice = null);
      if (next != null) _show(next);
    }
  }

  void _act() {
    final n = _notice;
    _hide();
    n?.onAction?.call();
  }

  @override
  Widget build(BuildContext context) {
    final n = _notice;
    return Stack(
      // The app keeps exactly the room it had without the host.
      fit: StackFit.expand,
      children: [
        widget.child,
        if (n != null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, 0),
                // As wide as its words: at most 90 % of the screen (and no
                // wider than a sheet card on a tablet); longer text wraps
                // onto more lines.
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.min(
                        AppSizes.sheetCardWidth,
                        MediaQuery.sizeOf(context).width * NoticeHost.maxWidthShare,
                      ),
                    ),
                    child: GestureDetector(
                      // A flick up puts it away early.
                      onVerticalDragEnd: (d) {
                        if ((d.primaryVelocity ?? 0) < 0) _hide();
                      },
                      child: _Drop(animation: _c, notice: n, onAction: _act),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The notice itself, drawn as a drop that falls and spreads (see
/// [AppNotice]).
class _Drop extends StatelessWidget {
  const _Drop({required this.animation, required this.notice, required this.onAction});
  final Animation<double> animation;
  final AppNotice notice;
  final VoidCallback onAction;

  /// The drop before it spreads, and how far above its place it starts.
  static const double _drop = 40;
  static const double _fall = 72;

  /// The parts of the run: the fall ends, the spread ends, the words start.
  static const double _dropEnd = 0.35;
  static const double _spreadEnd = 0.8;
  static const double _wordsStart = 0.6;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fg = cs.onInverseSurface;
    final body = Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.controlMd),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xl, right: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(notice.text, style: tt.bodyMedium?.copyWith(color: fg)),
                ),
              ),
              if (notice.actionLabel != null)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: fg),
                  onPressed: onAction,
                  child: Text(notice.actionLabel!),
                )
              else
                AppGap.h16,
            ],
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      child: AnimatedBuilder(
        animation: animation,
        child: body,
        builder: (context, child) {
          final t = animation.value;
          final falling = (t / _dropEnd).clamp(0.0, 1.0);
          final spread = ((t - _dropEnd) / (_spreadEnd - _dropEnd)).clamp(0.0, 1.0);
          final words = ((t - _wordsStart) / (1 - _wordsStart)).clamp(0.0, 1.0);
          // Falls with a small bounce, spreads with a soft landing.
          final y = -_fall * (1 - AppMotion.accent.transform(falling));
          final s = AppMotion.enterCurve.transform(spread);
          return Transform.translate(
            offset: Offset(0, y),
            child: Opacity(
              opacity: Curves.easeOut.transform(math.min(1, falling * 2)),
              child: ClipPath(
                clipper: _DropClipper(spread: s, drop: _drop),
                child: ColoredBox(
                  color: cs.inverseSurface,
                  child: Opacity(
                    opacity: Curves.easeOut.transform(words),
                    child: IgnorePointer(ignoring: t < 1, child: child),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The visible part of the notice: a [drop]-wide circle in its middle at
/// [spread] 0, the whole capsule at 1.
class _DropClipper extends CustomClipper<Path> {
  const _DropClipper({required this.spread, required this.drop});
  final double spread;
  final double drop;

  @override
  Path getClip(Size size) {
    final d = math.min(drop, size.height);
    final w = lerpDouble(d, size.width, spread)!;
    final h = lerpDouble(d, size.height, spread)!;
    final r = Rect.fromCenter(center: size.center(Offset.zero), width: w, height: h);
    // A capsule for one line; with more lines, a rounded box (the corners
    // stay those of a one-line capsule).
    final radius = [r.height, r.width, AppSizes.controlMd].reduce(math.min) / 2;
    return Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
  }

  @override
  bool shouldReclip(_DropClipper old) => old.spread != spread || old.drop != drop;
}
