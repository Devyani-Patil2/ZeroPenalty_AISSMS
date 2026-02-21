import 'package:flutter/material.dart';
import '../utils/constants.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 0.9, size),
      painter: ShieldLogoPainter(),
    );
  }
}

class ShieldLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shield (White)
    final shieldPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final shieldPath = Path()
      ..moveTo(w * 0.5, 0) // top center
      ..lineTo(w, h * 0.15) // top right
      ..lineTo(w, h * 0.55) // right side
      ..quadraticBezierTo(w, h * 0.75, w * 0.5, h) // bottom curve right
      ..quadraticBezierTo(0, h * 0.75, 0, h * 0.55) // bottom curve left
      ..lineTo(0, h * 0.15) // left side
      ..close();

    canvas.drawPath(shieldPath, shieldPaint);

    // Road (Green) inside shield
    final roadPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final roadPath = Path()
      ..moveTo(w * 0.35, h * 0.15)
      ..lineTo(w * 0.65, h * 0.15)
      ..lineTo(w * 0.58, h * 0.85)
      ..lineTo(w * 0.42, h * 0.85)
      ..close();

    canvas.drawPath(roadPath, roadPaint);

    // Road center dashes (White)
    final dashPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Three dashes along the road
    for (int i = 0; i < 3; i++) {
      final t = 0.25 + i * 0.22;
      final cx = w * 0.5;
      final cy = h * t;
      final dashW = w * 0.03;
      final dashH = h * 0.08;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: dashW, height: dashH),
          const Radius.circular(2),
        ),
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
