import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// The Repertorium chess logo, drawn from the same geometry as the app icon
/// (assets/icon/tabiya_icon.svg): an opening tree growing from the
/// tabiya square, on a navy tile. Vector, so it is sharp at any size.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 80});
  final double size;

  static const navy = Color(0xFF1B2233);
  static const cream = Color(0xFFECE8DF);
  static const gold = Color(0xFFC9A45C);

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppInfo.name,
    image: true,
    child: ClipRRect(
      // iOS-like icon corner (about 22 % of the side).
      borderRadius: BorderRadius.circular(size * 0.22),
      child: CustomPaint(size: Size.square(size), painter: _LogoPainter()),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // SVG viewBox is 1024 x 1024.
    canvas.scale(size.width / 1024);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1024, 1024), Paint()..color = AppLogo.navy);
    final branches = Path()
      ..moveTo(512, 576)
      ..lineTo(512, 426)
      ..quadraticBezierTo(512, 276, 362, 276)
      ..lineTo(280, 276)
      ..moveTo(512, 426)
      ..quadraticBezierTo(512, 276, 662, 276)
      ..lineTo(744, 276);
    canvas.drawPath(
      branches,
      Paint()
        ..color = AppLogo.cream
        ..style = PaintingStyle.stroke
        ..strokeWidth = 96
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(444, 660, 136, 136), const Radius.circular(22)),
      Paint()..color = AppLogo.gold,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
