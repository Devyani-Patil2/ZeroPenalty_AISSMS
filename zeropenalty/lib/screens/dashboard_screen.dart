import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/trip_provider.dart';
import '../providers/history_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/constants.dart';
import '../engine/scoring_engine.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().loadTrips();
      context.read<ProfileProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildStartTripButton(),
              const SizedBox(height: 24),
              _buildQuickStats(),
              const SizedBox(height: 24),
              _buildLastTrip(),
              const SizedBox(height: 24),
              _buildRecentTrips(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<ProfileProvider>(
      builder: (context, profile, _) {
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, ${profile.profile.name}! 👋',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    profile.profile.tier,
                    style: TextStyle(
                      color: AppColors.scoreColor(
                          profile.profile.lifetimeAvgScore),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStartTripButton() {
    return Consumer<TripProvider>(
      builder: (context, trip, _) {
        return Column(
          children: [
            // ── Demo / Live Mode Toggle ──
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          trip.isDemoMode ? AppColors.warning : AppColors.safe,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.isDemoMode ? 'DEMO MODE' : 'LIVE MODE',
                          style: TextStyle(
                            color: trip.isDemoMode
                                ? AppColors.warning
                                : AppColors.safe,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          trip.isDemoMode
                              ? '🎮 Simulated Data — for presentations'
                              : '📡 Real GPS + Sensors — for actual driving',
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: !trip.isDemoMode,
                    onChanged:
                        trip.isActive ? null : (_) => trip.toggleDemoMode(),
                    activeColor: AppColors.safe,
                    inactiveThumbColor: AppColors.warning,
                  ),
                ],
              ),
            ),
            // ── Start Trip Button ──
            GestureDetector(
              onTap: () async {
                final started = await trip.startTrip();
                if (!context.mounted) return;
                if (started) {
                  Navigator.pushNamed(context, '/trip');
                } else if (trip.locationError != null) {
                  // Show location error dialog
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Row(
                        children: [
                          Icon(Icons.location_off,
                              color: AppColors.danger, size: 28),
                          SizedBox(width: 10),
                          Text(
                            'Location Required',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      content: Text(
                        trip.locationError!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            trip.clearLocationError();
                          },
                          child: const Text('OK'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            trip.clearLocationError();
                            await Geolocator.openLocationSettings();
                          },
                          icon: const Icon(Icons.settings, size: 16),
                          label: const Text('Open Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF4A42E8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 48),
                    const SizedBox(height: 8),
                    const Text(
                      'Start Trip',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      trip.isDemoMode
                          ? 'Tap to begin demo session'
                          : 'Tap to begin driving session',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickStats() {
    return Consumer<ProfileProvider>(
      builder: (context, profile, _) {
        return Row(
          children: [
            _statCard('Trips', '${profile.profile.totalTrips}', Icons.route,
                AppColors.accent),
            const SizedBox(width: 12),
            _statCard(
              'Avg Score',
              profile.profile.lifetimeAvgScore.toStringAsFixed(0),
              Icons.speed,
              AppColors.scoreColor(profile.profile.lifetimeAvgScore),
            ),
            const SizedBox(width: 12),
            _statCard('Points', '${profile.profile.totalPoints}', Icons.stars,
                AppColors.warningLight),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastTrip() {
    return Consumer<HistoryProvider>(
      builder: (context, history, _) {
        if (history.trips.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Center(
              child: Text(
                'No trips yet. Start your first trip!',
                style: TextStyle(color: context.textMuted, fontSize: 14),
              ),
            ),
          );
        }

        final last = history.trips.first;
        final score = last.mlScore ?? last.localScore;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last Trip',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.scoreColor(score).withOpacity(0.15),
                    ),
                    child: Center(
                      child: Text(
                        score.toStringAsFixed(0),
                        style: TextStyle(
                          color: AppColors.scoreColor(score),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          last.formattedDuration,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${last.distanceKm.toStringAsFixed(1)} km • +${last.pointsEarned} pts',
                          style:
                              TextStyle(color: context.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentTrips() {
    return Consumer<HistoryProvider>(
      builder: (context, history, _) {
        if (history.trips.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Trips',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...history.trips.take(3).map((trip) {
              final score = trip.mlScore ?? trip.localScore;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.surfaceBg,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: context.borderColor.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.scoreColor(score).withOpacity(0.15),
                      ),
                      child: Center(
                        child: Text(
                          score.toStringAsFixed(0),
                          style: TextStyle(
                            color: AppColors.scoreColor(score),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.formattedDuration,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${trip.distanceKm.toStringAsFixed(1)} km',
                            style: TextStyle(
                                color: context.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+${trip.pointsEarned} pts',
                      style: const TextStyle(
                        color: AppColors.warningLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
