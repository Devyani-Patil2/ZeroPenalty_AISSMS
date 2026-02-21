import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../providers/history_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/constants.dart';

class LiveTripScreen extends StatelessWidget {
  const LiveTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back during trip
      child: Scaffold(
        backgroundColor: context.bg,
        body: SafeArea(
          child: Consumer<TripProvider>(
            builder: (context, trip, _) {
              return Column(
                children: [
                  _buildTopBar(context, trip),
                  const SizedBox(height: 16),
                  _buildSpeedometer(context, trip),
                  const SizedBox(height: 20),
                  _buildTripStats(context, trip),
                  const SizedBox(height: 16),
                  Expanded(child: _buildAlertsFeed(context, trip)),
                  _buildStopButton(context, trip),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, TripProvider trip) {
    final minutes = trip.tripDuration ~/ 60;
    final seconds = trip.tripDuration % 60;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'RECORDING',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Demo / Live badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (trip.isSimulatedTrip ? AppColors.warning : AppColors.safe)
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trip.isSimulatedTrip ? '🎮 DEMO' : '📡 LIVE',
              style: TextStyle(
                color:
                    trip.isSimulatedTrip ? AppColors.warning : AppColors.safe,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedometer(BuildContext context, TripProvider trip) {
    final speed = trip.currentSpeed;
    final limit = trip.currentSpeedLimit;
    final isOver = trip.isOverspeeding;
    final ratio = (speed / max(limit, 1)).clamp(0.0, 2.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isOver ? AppColors.danger.withOpacity(0.5) : context.borderColor,
          width: isOver ? 2 : 1,
        ),
        boxShadow: isOver
            ? [
                BoxShadow(
                    color: AppColors.danger.withOpacity(0.2), blurRadius: 20)
              ]
            : null,
      ),
      child: Column(
        children: [
          // Speed display
          SizedBox(
            height: 200,
            width: double.infinity,
            child: CustomPaint(
              painter: _SpeedometerPainter(ratio: ratio, isOver: isOver, borderColor: context.borderColor),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        speed.toStringAsFixed(0),
                        style: TextStyle(
                          color:
                              isOver ? AppColors.danger : context.textPrimary,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'km/h',
                        style:
                            TextStyle(color: context.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Speed limit
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.speed, color: context.textMuted, size: 18),
              const SizedBox(width: 6),
              Text(
                'Limit: ${limit.toStringAsFixed(0)} km/h',
                style: TextStyle(
                    color: context.textSecondary, fontSize: 14),
              ),
              if (isOver) ...[
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${(speed - limit).toStringAsFixed(0)} over',
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildTripStats(BuildContext context, TripProvider trip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _miniStat(context, 'Distance', '${trip.distanceKm.toStringAsFixed(1)} km',
              Icons.straighten),
          const SizedBox(width: 10),
          _miniStat(context,
              'Max Speed', '${trip.maxSpeed.toStringAsFixed(0)}', Icons.speed),
          const SizedBox(width: 10),
          _miniStat(context, 'Events', '${trip.events.length}', Icons.warning_amber),
          const SizedBox(width: 10),
          _miniStat(context, 'Score', trip.liveScore.toStringAsFixed(0), Icons.shield,
              color: AppColors.scoreColor(trip.liveScore)),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, String label, String value, IconData icon, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color ?? context.textMuted, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color ?? context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: context.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsFeed(BuildContext context, TripProvider trip) {
    if (trip.recentAlerts.isEmpty) {
      return const Center(
        child: Text(
          '✅ Driving safely',
          style: TextStyle(color: AppColors.safe, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: trip.recentAlerts.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (index == 0 ? AppColors.danger : AppColors.warning)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (index == 0 ? AppColors.danger : AppColors.warning)
                  .withOpacity(0.3),
            ),
          ),
          child: Text(
            trip.recentAlerts[index],
            style: TextStyle(
              color: index == 0 ? AppColors.danger : AppColors.warningLight,
              fontSize: 13,
              fontWeight: index == 0 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStopButton(BuildContext context, TripProvider trip) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            final completedTrip = await trip.stopTrip();
            if (context.mounted) {
              context.read<HistoryProvider>().addTrip(completedTrip);
              context.read<ProfileProvider>().refresh();
              Navigator.pushReplacementNamed(context, '/summary');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stop_circle, size: 24),
              SizedBox(width: 8),
              Text('Stop Trip',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom speedometer arc painter — 240° gauge
class _SpeedometerPainter extends CustomPainter {
  final double ratio;
  final bool isOver;
  final Color borderColor;

  _SpeedometerPainter({required this.ratio, required this.isOver, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final radius = min(size.width, size.height) * 0.42;
    // 240° arc: starts at 150° (bottom-left) and sweeps 240° clockwise
    const startAngle = pi * 150 / 180; // 150 degrees
    const totalSweep = pi * 240 / 180; // 240 degrees

    // Background arc
    final bgPaint = Paint()
      ..color = borderColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      bgPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    if (isOver) {
      progressPaint.color = AppColors.danger;
    } else {
      progressPaint.shader = const LinearGradient(
        colors: [AppColors.safe, AppColors.warning],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    }

    final progress = (ratio.clamp(0.0, 1.5)) / 1.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
