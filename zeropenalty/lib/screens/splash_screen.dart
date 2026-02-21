import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import 'welcome_screen.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isLoggedIn) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Green glowing circle with logo
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryGreen,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(90, 100),
                      painter: ShieldLogoPainter(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // App name
                const Text(
                  'ZeroPenalty',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                // Tagline
                Text(
                  'Drive Smarter. Not Harder.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.6),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the shield + road logo
class ShieldLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Shield shape
    final shieldPath = Path()
      ..moveTo(w * 0.5, 0) // top center
      ..lineTo(w, h * 0.15) // top right
      ..lineTo(w, h * 0.55) // right side
      ..quadraticBezierTo(w, h * 0.75, w * 0.5, h) // bottom curve right
      ..quadraticBezierTo(0, h * 0.75, 0, h * 0.55) // bottom curve left
      ..lineTo(0, h * 0.15) // left side
      ..close();

    canvas.drawPath(shieldPath, paint);

    // Road (dark) inside shield
    final roadPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;

    final roadPath = Path()
      ..moveTo(w * 0.35, h * 0.15)
      ..lineTo(w * 0.65, h * 0.15)
      ..lineTo(w * 0.58, h * 0.85)
      ..lineTo(w * 0.42, h * 0.85)
      ..close();

    canvas.drawPath(roadPath, roadPaint);

    // Road center dashes (white)
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
