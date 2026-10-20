import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../widgets/ui/back_swipe.dart';

/// A full screen of the app (D-101): the platform's page transition, and on
/// iOS the swipe back from the left edge, made strict:
/// - it starts only in the edge strip ([kBackSwipeEdge]) and never on a
///   [BackSwipeGuard] (the boards), so a piece dragged from the edge file
///   stays a move;
/// - only when the screen may be left at all: a screen guarding unsaved
///   work (`PopScope(canPop: false)`) is left with its Back button, which
///   asks first;
/// - the drag must be mostly sideways (a scroll down from the edge stays a
///   scroll), and the screen goes back only when dragged past a third of
///   the width or flung after at least [_minFlingShare] of it; otherwise it
///   slides into place again.
/// With "Reduce motion" the screens change without the slide.
class AppPage<T> extends Page<T> {
  const AppPage({required this.child, super.key, super.name, super.arguments, super.restorationId});
  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => _AppPageRoute<T>(this);
}

/// Back past this share of the width: the screen is left on release.
const double _commitShare = 1 / 3;

/// A fling counts only after this share of the width (a twitch from the
/// edge is not a swipe back).
const double _minFlingShare = 0.15;

/// Fling speed, in screen widths per second, that leaves the screen.
const double _flingVelocity = 1.0;

class _AppPageRoute<T> extends PageRoute<T> with MaterialRouteTransitionMixin<T> {
  _AppPageRoute(AppPage<T> page) : super(settings: page);

  AppPage<T> get _page => settings as AppPage<T>;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  bool get maintainState => true;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';

  bool get _reduceMotion {
    final context = navigator?.context;
    return context != null && (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  }

  @override
  Duration get transitionDuration => _reduceMotion ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _reduceMotion ? Duration.zero : super.reverseTransitionDuration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Theme.of(context).platform != TargetPlatform.iOS) {
      return super.buildTransitions(context, animation, secondaryAnimation, child);
    }
    return CupertinoPageTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: popGestureInProgress,
      child: _BackSwipeDetector(route: this, child: child),
    );
  }

  // ------------------------------------------------------------ swipe back

  /// The page's offset as dragged so far, in screen widths.
  double _dragged = 0;

  void _swipeStart() {
    _dragged = 0;
    navigator!.didStartUserGesture();
  }

  void _swipeUpdate(double delta) {
    _dragged += delta;
    controller!.value = (controller!.value - delta).clamp(0.0, 1.0);
  }

  void _swipeEnd(double velocity) {
    final c = controller!;
    final back = c.value <= 1 - _commitShare || (velocity >= _flingVelocity && _dragged >= _minFlingShare);
    if (back) {
      navigator!.pop();
      if (c.isAnimating) c.animateBack(0, duration: _settleTime(c.value), curve: Curves.fastLinearToSlowEaseIn);
    } else {
      c.animateTo(1, duration: _settleTime(1 - c.value), curve: Curves.fastLinearToSlowEaseIn);
    }
    if (c.isAnimating) {
      late final AnimationStatusListener done;
      done = (status) {
        navigator?.didStopUserGesture();
        c.removeStatusListener(done);
      };
      c.addStatusListener(done);
    } else {
      navigator!.didStopUserGesture();
    }
  }

  /// The rest of the slide takes a share of the iOS 350 ms.
  Duration _settleTime(double left) => Duration(milliseconds: math.max(1, (350 * left).round()));
}

/// The edge strip of an iOS page that starts the swipe back.
class _BackSwipeDetector extends StatefulWidget {
  const _BackSwipeDetector({required this.route, required this.child});
  final _AppPageRoute<Object?> route;
  final Widget child;

  @override
  State<_BackSwipeDetector> createState() => _BackSwipeDetectorState();
}

class _BackSwipeDetectorState extends State<_BackSwipeDetector> {
  late final HorizontalDragGestureRecognizer _drag = HorizontalDragGestureRecognizer(debugOwner: this)
    ..onStart = _start
    ..onUpdate = _update
    ..onEnd = _end
    ..onCancel = _cancel;

  bool _active = false;

  @override
  void dispose() {
    _drag.dispose();
    // Gone in the middle of a swipe (the screen was replaced): the
    // navigator must not stay in "gesture in progress".
    if (_active) widget.route.navigator?.didStopUserGesture();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    final route = widget.route;
    if (!route.popGestureEnabled || BackSwipeGuard.covers(route, e.position)) return;
    _drag.addPointer(e);
  }

  double _sign() => Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  double get _width => context.size?.width ?? MediaQuery.sizeOf(context).width;

  void _start(DragStartDetails d) {
    _active = true;
    widget.route._swipeStart();
  }

  void _update(DragUpdateDetails d) {
    if (_active) widget.route._swipeUpdate(_sign() * d.primaryDelta! / _width);
  }

  void _end(DragEndDetails d) {
    if (!_active) return;
    _active = false;
    widget.route._swipeEnd(_sign() * d.velocity.pixelsPerSecond.dx / _width);
  }

  void _cancel() {
    if (!_active) return;
    _active = false;
    widget.route._swipeEnd(0);
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final padding = MediaQuery.paddingOf(context);
    final edge = math.max(rtl ? padding.right : padding.left, kBackSwipeEdge);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          width: edge,
          top: 0,
          bottom: 0,
          child: Listener(onPointerDown: _down, behavior: HitTestBehavior.translucent),
        ),
      ],
    );
  }
}
