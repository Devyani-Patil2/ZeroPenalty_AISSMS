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
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Consumer<TripProvider>(
            builder: (context, trip, _) {
              return Column(
                children: [
                  _buildTopBar(context, trip),
                  const SizedBox(height: 16),
                  _buildSpeedometer(trip),
                  const SizedBox(height: 16),
                  _buildZoneBadge(trip),
                  const SizedBox(height: 16),
                  _buildTripStats(trip),
                  const SizedBox(height: 16),
                  Expanded(child: _buildAlertsFeed(trip)),
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
          const Spacer(),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedometer(TripProvider trip) {
    final speed = trip.currentSpeed;
    final limit = trip.currentSpeedLimit;
    final isOver = trip.isOverspeeding;
    final ratio = (speed / max(limit, 1)).clamp(0.0, 2.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isOver ? AppColors.danger.withOpacity(0.5) : AppColors.cardBorder,
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
            height: 160,
            child: CustomPaint(
              painter: _SpeedometerPainter(ratio: ratio, isOver: isOver),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      speed.toStringAsFixed(0),
                      style: TextStyle(
                        color:
                            isOver ? AppColors.danger : AppColors.textPrimary,
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'km/h',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Speed limit
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.speed, color: AppColors.textMuted, size: 18),
              const SizedBox(width: 6),
              Text(
                'Limit: ${limit.toStringAsFixed(0)} km/h',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
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

  Widget _buildZoneBadge(TripProvider trip) {
    final zone = trip.currentZone;
    if (zone == null) return const SizedBox();

    final color = AppColors.zoneColor(zone.typeString);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            zone.risk.index == 0
                ? Icons.warning
                : zone.risk.index == 1
                    ? Icons.home
                    : Icons.route,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone.name,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${zone.riskLabel} • Speed limit: ${zone.speedLimit.toStringAsFixed(0)} km/h',
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStats(TripProvider trip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _miniStat('Distance', '${trip.distanceKm.toStringAsFixed(1)} km',
              Icons.straighten),
          const SizedBox(width: 10),
          _miniStat(
              'Max Speed', '${trip.maxSpeed.toStringAsFixed(0)}', Icons.speed),
          const SizedBox(width: 10),
          _miniStat('Events', '${trip.events.length}', Icons.warning_amber),
          const SizedBox(width: 10),
          _miniStat('Score', trip.liveScore.toStringAsFixed(0), Icons.shield,
              color: AppColors.scoreColor(trip.liveScore)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color ?? AppColors.textMuted, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color ?? AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsFeed(TripProvider trip) {
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

/// Custom speedometer arc painter
class _SpeedometerPainter extends CustomPainter {
  final double ratio;
  final bool isOver;

  _SpeedometerPainter({required this.ratio, required this.isOver});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = size.width * 0.42;
    const startAngle = -pi * 0.85;
    const sweepAngle = pi * 0.7;

    // Background arc
    final bgPaint = Paint()
      ..color = AppColors.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * 2,
      false,
      bgPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    if (isOver) {
      progressPaint.color = AppColors.danger;
    } else {
      progressPaint.shader = const LinearGradient(
        colors: [AppColors.safe, AppColors.warning],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    }

    final progress = (ratio.clamp(0, 1.5)) / 1.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
