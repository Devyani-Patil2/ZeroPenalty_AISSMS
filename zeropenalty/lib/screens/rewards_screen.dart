import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../utils/constants.dart';
import 'achievements_screen.dart';
import 'coupons_screen.dart';

import '../models/coupon.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Consumer<ProfileProvider>(
          builder: (context, provider, child) {
            final profile = provider.profile;
            final availableCoupons = provider.coupons
                .where((c) => c.status == CouponStatus.available)
                .length;

            return CustomScrollView(
              slivers: [
                _buildAppBar(context, profile),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPointsCard(context, profile),
                        const SizedBox(height: 25),
                        _buildNavGrid(context, profile, availableCoupons),
                        const SizedBox(height: 25),
                        _buildTierBenefits(context, profile.tier),
                        const SizedBox(height: 100), // Spacing for bottom nav
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, dynamic profile) {
    return SliverAppBar(
      expandedHeight: 120,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Text(
          'Driving Rewards',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
      ),
    );
  }

  Widget _buildPointsCard(BuildContext context, dynamic profile) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(profile.tier.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${profile.totalPoints}',
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(width: 8),
              const Text('ZP Points',
                  style: TextStyle(fontSize: 16, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              const Text('1000 points = ₹10 fuel credit',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

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

  Widget _buildTierBenefits(BuildContext context, String tier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tier Benefits',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            children: [
              _benefitRow(context, 'Fuel Points Multiplier', '1.2x', true),
              const Divider(height: 30),
              _benefitRow(context, 'Monthly Challenge Entry', 'Unlocked', true),
              const Divider(height: 30),
              _benefitRow(context, 'Service Center Discounts', '5% OFF',
                  tier != 'Improving'),
              const Divider(height: 30),
              _benefitRow(
                  context, 'Priority Support', 'Platinum Only', tier == 'Pro'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _benefitRow(
      BuildContext context, String label, String val, bool isUnlocked) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: isUnlocked ? context.textPrimary : context.textMuted)),
        Text(val,
            style: TextStyle(
                color: isUnlocked ? AppColors.primary : context.textMuted,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
