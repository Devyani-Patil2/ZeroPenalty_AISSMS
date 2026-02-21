import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final Color bgColor;
  final Color strokeColor;
  final double Function(dynamic stats) getProgress;
  final bool Function(dynamic stats) checkUnlocked;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.bgColor,
    required this.strokeColor,
    required this.getProgress,
    required this.checkUnlocked,
  });
}

class ShieldPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  ShieldPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.05); // Top center
    path.lineTo(size.width * 0.9, size.height * 0.2); // Top right
    path.lineTo(size.width * 0.9, size.height * 0.55); // Right side
    path.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.8,
      size.width * 0.5,
      size.height * 0.95,
    ); // Bottom curve right
    path.quadraticBezierTo(
      size.width * 0.1,
      size.height * 0.8,
      size.width * 0.1,
      size.height * 0.55,
    ); // Bottom curve left
    path.lineTo(size.width * 0.1, size.height * 0.2); // Left side
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    // Subtle inner shadow/highlight effect
    final innerPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    final innerPath = Path();
    innerPath.moveTo(size.width * 0.5, size.height * 0.12);
    innerPath.lineTo(size.width * 0.82, size.height * 0.24);
    innerPath.lineTo(size.width * 0.82, size.height * 0.55);
    innerPath.quadraticBezierTo(
      size.width * 0.82,
      size.height * 0.75,
      size.width * 0.5,
      size.height * 0.88,
    );
    innerPath.quadraticBezierTo(
      size.width * 0.18,
      size.height * 0.75,
      size.width * 0.18,
      size.height * 0.55,
    );
    innerPath.lineTo(size.width * 0.18, size.height * 0.24);
    innerPath.close();

    canvas.drawPath(innerPath, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BadgeWidget extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;
  final double size;

  const BadgeWidget({
    super.key,
    required this.achievement,
    required this.unlocked,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1.0 : 0.4,
      child: ColorFiltered(
        colorFilter: unlocked
            ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
            : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
        child: SizedBox(
          width: size,
          height: size * 1.18,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size * 1.18),
                painter: ShieldPainter(
                  color: achievement.bgColor,
                  borderColor: unlocked ? achievement.strokeColor : Colors.grey,
                ),
              ),
              Text(
                achievement.emoji,
                style: TextStyle(fontSize: size * 0.38),
              ),
              if (unlocked)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.star, size: 12, color: Colors.black),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
