import 'package:flutter/widgets.dart';

/// Width of the strip along the leading edge where the swipe back starts
/// (the iOS value; wider on a side with a notch).
const double kBackSwipeEdge = 20;

/// Keeps the swipe back from the screen edge off [child] (D-101): a touch
/// that starts on it, even inside the edge strip, belongs to it alone.
///
/// For the chess boards and the piece palette. A board reads raw touches,
/// outside the gesture arena: without the guard a piece dragged from the
/// edge file would also slide the whole screen away. The guard takes no
/// part in the gestures of [child] (moves, arrows, swipes between moves).
class BackSwipeGuard extends StatefulWidget {
  const BackSwipeGuard({super.key, required this.child});
  final Widget child;

  /// Whether [global] lies on a guard of [route] (only the screen being
  /// swiped counts: the one under it may have a board at the same spot).
  static bool covers(ModalRoute<Object?> route, Offset global) {
    for (final g in _BackSwipeGuardState._mounted) {
      if (!g.mounted || ModalRoute.of(g.context) != route) continue;
      final box = g.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      if ((Offset.zero & box.size).contains(box.globalToLocal(global))) return true;
    }
    return false;
  }

  @override
  State<BackSwipeGuard> createState() => _BackSwipeGuardState();
}

class _BackSwipeGuardState extends State<BackSwipeGuard> {
  static final Set<_BackSwipeGuardState> _mounted = {};

  @override
  void initState() {
    super.initState();
    _mounted.add(this);
  }

  @override
  void dispose() {
    _mounted.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
