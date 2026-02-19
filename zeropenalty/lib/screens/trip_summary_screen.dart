import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../utils/constants.dart';
import '../engine/scoring_engine.dart';

class TripSummaryScreen extends StatelessWidget {
  const TripSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<TripProvider>(
          builder: (context, trip, _) {
            final t = trip.lastCompletedTrip;
            if (t == null) {
              return const Center(
                child: Text('No trip data', style: TextStyle(color: AppColors.textMuted)),
              );
            }

            final score = t.mlScore ?? t.localScore;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  _buildScoreRing(score),
                  const SizedBox(height: 24),
                  _buildTripInfo(t),
                  const SizedBox(height: 20),
                  _buildEventBreakdown(t),
                  const SizedBox(height: 20),
                  _buildZoneAnalysis(t),
                  const SizedBox(height: 20),
                  _buildFeedback(t),
                  const SizedBox(height: 20),
                  _buildPointsEarned(t),
                  const SizedBox(height: 24),
                  _buildDoneButton(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: AppColors.safe, size: 28),
        const SizedBox(width: 10),
        const Text(
          'Trip Complete!',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreRing(double score) {
    final color = AppColors.scoreColor(score);
    final grade = ScoringEngine.getColorGrade(score);

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: _ScoreRingPainter(score: score, color: color),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      score.toStringAsFixed(0),
                      style: TextStyle(
                        color: color,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Safety Score',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              grade.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripInfo(t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _infoItem('Duration', t.formattedDuration, Icons.timer),
          _infoItem('Distance', '${t.distanceKm.toStringAsFixed(1)} km', Icons.straighten),
          _infoItem('Avg Speed', '${t.avgSpeed.toStringAsFixed(0)} km/h', Icons.speed),
          _infoItem('Max Speed', '${t.maxSpeed.toStringAsFixed(0)} km/h', Icons.flash_on),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _buildEventBreakdown(t) {
    final events = [
      {'label': 'Overspeeding', 'count': t.overspeedCount, 'icon': Icons.speed, 'color': AppColors.danger},
      {'label': 'Harsh Brakes', 'count': t.harshBrakeCount, 'icon': Icons.pan_tool, 'color': AppColors.warning},
      {'label': 'Sharp Turns', 'count': t.sharpTurnCount, 'icon': Icons.turn_right, 'color': AppColors.warningLight},
      {'label': 'Rash Accel', 'count': t.rashAccelCount, 'icon': Icons.rocket_launch, 'color': AppColors.primaryLight},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Event Breakdown',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...events.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(e['icon'] as IconData, color: e['color'] as Color, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e['label'] as String,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (e['color'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${e['count']}',
                        style: TextStyle(
                          color: e['color'] as Color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildZoneAnalysis(t) {
    final zones = [
      {'label': 'High Risk', 'count': t.highRiskEvents, 'color': AppColors.danger},
      {'label': 'Medium Risk', 'count': t.mediumRiskEvents, 'color': AppColors.warning},
      {'label': 'Low Risk', 'count': t.lowRiskEvents, 'color': AppColors.safe},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zone-wise Analysis',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: zones
                .map((z) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (z['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: (z['color'] as Color).withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${z['count']}',
                              style: TextStyle(
                                color: z['color'] as Color,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              z['label'] as String,
                              style: TextStyle(
                                color: (z['color'] as Color).withOpacity(0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback(t) {
    if (t.feedback.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: AppColors.warningLight, size: 18),
              SizedBox(width: 8),
              Text(
                'Coaching Tips',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...t.feedback.map<Widget>((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  f,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPointsEarned(t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.2), AppColors.accent.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.stars, color: AppColors.warningLight, size: 28),
          const SizedBox(width: 10),
          Text(
            '+${t.pointsEarned} Points Earned',
            style: const TextStyle(
              color: AppColors.warningLight,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Back to Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// Circular score ring painter
class _ScoreRingPainter extends CustomPainter {
  final double score;
  final Color color;

  _ScoreRingPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background
    final bgPaint = Paint()
      ..color = AppColors.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final sweepAngle = (score / 100) * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
