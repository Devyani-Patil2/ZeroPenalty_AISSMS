import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../utils/constants.dart';
import '../widgets/custom_header.dart';
import '../models/coupon.dart';
import 'achievements_screen.dart';
import 'coupons_screen.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Consumer<ProfileProvider>(
            builder: (context, provider, _) {
              final p = provider.profile;
              final availableCoupons = provider.coupons
                  .where((c) => c.status == CouponStatus.available)
                  .length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CustomHeader(title: 'Rewards'),
                  const SizedBox(height: 20),
                  _buildTierCard(context, p.tier, p.lifetimeAvgScore),
                  const SizedBox(height: 20),
                  _buildPointsCard(context, p.totalPoints),
                  const SizedBox(height: 20),
                  _buildNavGrid(context, p, availableCoupons),
                  const SizedBox(height: 24),
                  _buildRedemptionSection(context),
                  const SizedBox(height: 100),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Safe Driver / Tier Card (from teammate's UI) ──
  Widget _buildTierCard(BuildContext context, String tier, double avgScore) {
    final tierLabel = _getTierLabel(tier);
    final tierMessage = _getTierMessage(tier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.verified, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            tierLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tierMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (avgScore / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Avg: ${avgScore.toStringAsFixed(0)} / 100',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Total Points Card (from teammate's UI) ──
  Widget _buildPointsCard(BuildContext context, int totalPoints) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.star, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Points',
                  style: TextStyle(color: context.textSecondary, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                '$totalPoints',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Achievements & Coupons Grid (from user's code) ──
  Widget _buildNavGrid(BuildContext context, dynamic profile, int couponCount) {
    return Row(
      children: [
        Expanded(
          child: _navCard(
            context,
            'Achievements',
            '${profile.unlockedBadgeIds.length} Unlocked',
            Icons.emoji_events,
            Colors.orange,
            const AchievementsScreen(),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _navCard(
            context,
            'My Coupons',
            couponCount > 0 ? '$couponCount Available' : 'No rewards yet',
            Icons.local_activity,
            Colors.blue,
            const CouponsScreen(),
            badgeCount: couponCount,
          ),
        ),
      ],
    );
  }

  Widget _navCard(BuildContext context, String title, String sub, IconData icon,
      Color color, Widget screen,
      {int badgeCount = 0}) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (c) => screen)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 32),
                if (badgeCount > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: AppColors.danger, shape: BoxShape.circle),
                      child: Text('$badgeCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 15),
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(sub,
                style: TextStyle(fontSize: 12, color: context.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── Redeem Rewards Section (from teammate's UI) ──
  Widget _buildRedemptionSection(BuildContext context) {
    final rewards = [
      {
        'icon': Icons.local_gas_station,
        'title': 'Fuel Voucher',
        'desc': '₹100 fuel discount',
        'pts': 500,
        'color': Colors.green
      },
      {
        'icon': Icons.shield,
        'title': 'Insurance Discount',
        'desc': '5% off next premium',
        'pts': 1000,
        'color': Colors.blue
      },
      {
        'icon': Icons.build,
        'title': 'Service Coupon',
        'desc': 'Free vehicle health check',
        'pts': 750,
        'color': Colors.purple
      },
      {
        'icon': Icons.local_parking,
        'title': 'Parking Pass',
        'desc': 'Free parking for 1 day',
        'pts': 300,
        'color': Colors.red
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Redeem Rewards',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        ...rewards.map((r) => _rewardTile(
              context,
              r['icon'] as IconData,
              r['title'] as String,
              r['desc'] as String,
              r['pts'] as int,
              r['color'] as Color,
            )),
      ],
    );
  }

  Widget _rewardTile(BuildContext context, IconData icon, String title,
      String desc, int pts, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(desc,
                    style:
                        TextStyle(color: context.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '$pts pts',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getTierLabel(String tier) {
    switch (tier.toLowerCase()) {
      case 'pro':
        return 'Pro Driver';
      case 'expert':
        return 'Expert Driver';
      case 'improving':
        return 'Improving Driver';
      default:
        return 'Safe Driver';
    }
  }

  String _getTierMessage(String tier) {
    switch (tier.toLowerCase()) {
      case 'pro':
        return 'Outstanding! You are a top-tier driver!';
      case 'expert':
        return 'Great driving! Keep up the excellent work.';
      case 'improving':
        return 'You are getting better! Keep practicing safe driving.';
      default:
        return 'You are a safe driver! Keep up the excellent work.';
    }
  }
}
