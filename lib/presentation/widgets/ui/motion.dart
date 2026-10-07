import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Replaces its child with a cross-fade when the child's key (or type)
/// changes: a status, a verdict, a loaded list instead of a spinner.
/// Nothing moves, so the layout around it stays where it is.
class AppSwitcher extends StatelessWidget {
  const AppSwitcher({super.key, required this.child, this.alignment = Alignment.topCenter, this.sized = false});
  final Widget child;
  final AlignmentGeometry alignment;

  /// Also animate the height when the old and the new child differ.
  final bool sized;

  @override
  Widget build(BuildContext context) {
    final m = AppMotion.of(context);
    final switcher = AnimatedSwitcher(
      duration: m.base,
      switchInCurve: AppMotion.enterCurve,
      switchOutCurve: AppMotion.exitCurve,
      layoutBuilder: (current, previous) => Stack(alignment: alignment, children: [...previous, ?current]),
      child: child,
    );
    if (!sized) return switcher;
    return AnimatedSize(duration: m.base, curve: AppMotion.standard, alignment: alignment, child: switcher);
  }
}

/// Shows or hides a block under other content: it grows open and fades in,
/// fades out and closes. For panels, banners and rows that come and go.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final m = AppMotion.of(context);
    return AnimatedSize(
      duration: m.base,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: m.base,
        switchInCurve: AppMotion.enterCurve,
        switchOutCurve: AppMotion.exitCurve,
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
        child: visible ? child : const SizedBox(width: double.infinity),
      ),
    );
  }
}

/// A number that runs to its new value instead of jumping.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({super.key, required this.value, required this.format, this.style});
  final double value;
  final String Function(double) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: AppMotion.of(context).enter,
      curve: AppMotion.standard,
      builder: (_, v, _) => Text(format(v), style: style),
    );
  }
}

/// A value between 0 and 1 that glides to its new state; [builder] draws it.
class AnimatedFraction extends StatelessWidget {
  const AnimatedFraction({super.key, required this.value, required this.builder, this.emphasis = false});
  final double value;
  final Widget Function(BuildContext, double) builder;

  /// A slower run for moments worth noticing (a goal filling up).
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final m = AppMotion.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0.0, 1.0)),
      duration: emphasis ? m.emphasis : m.enter,
      curve: AppMotion.enterCurve,
      builder: (context, v, _) => builder(context, v),
    );
  }
}

/// Pops its child in with a small overshoot when [trigger] changes
/// (a check mark, a trophy).
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.trigger, required this.child});
  final Object? trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final m = AppMotion.of(context);
    if (!m.enabled) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0.6, end: 1),
      duration: m.enter,
      curve: AppMotion.accent,
      builder: (_, v, c) => Transform.scale(scale: v, child: c),
      child: child,
    );
  }
}

/// Shakes its child sideways once when [trigger] changes (a wrong answer).
class Shake extends StatelessWidget {
  const Shake({super.key, required this.trigger, required this.child});
  final Object? trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final m = AppMotion.of(context);
    if (!m.enabled || trigger == null) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 1, end: 0),
      duration: m.enter,
      curve: Curves.linear,
      // Three quick swings that die out.
      builder: (_, v, c) => Transform.translate(offset: Offset(AppSpacing.sm * v * _swing(1 - v), 0), child: c),
      child: child,
    );
  }

  static double _swing(double t) {
    final phase = t * 3 % 1;
    return phase < 0.5 ? 1 - 4 * phase : 4 * phase - 3;
  }
}

/// Fades its child in again whenever [trigger] changes, without rebuilding
/// or moving it: a tab or a view switched in place.
class FadeOnChange extends StatefulWidget {
  const FadeOnChange({super.key, required this.trigger, required this.child});
  final Object? trigger;
  final Widget child;

  @override
  State<FadeOnChange> createState() => _FadeOnChangeState();
}

class _FadeOnChangeState extends State<FadeOnChange> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, value: 1);
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: AppMotion.enterCurve);

  @override
  void didUpdateWidget(FadeOnChange old) {
    super.didUpdateWidget(old);
    if (old.trigger == widget.trigger) return;
    final m = AppMotion.of(context);
    if (!m.enabled) return;
    _c
      ..duration = m.base
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _fade, child: widget.child);
}

/// Lets its child grow open and fade in when it first appears (a panel
/// under the board, a banner). It leaves at once: what the user closed
/// should be gone.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child});
  final Widget child;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late final Animation<double> _size = CurvedAnimation(parent: _c, curve: AppMotion.standard);
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: AppMotion.enterCurve);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final m = AppMotion.of(context);
    if (m.enabled) {
      _c
        ..duration = m.base
        ..forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: _size,
    alignment: Alignment.topCenter,
    child: FadeTransition(opacity: _fade, child: widget.child),
  );
}
