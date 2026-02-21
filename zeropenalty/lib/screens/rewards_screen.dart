import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../utils/constants.dart';

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
            builder: (context, profile, _) {
              final p = profile.profile;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rewards',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTierCard(context, p.tier, p.lifetimeAvgScore),
                  const SizedBox(height: 20),
                  _buildPointsCard(context, p.totalPoints),
                  const SizedBox(height: 24),
                  _buildRedemptionSection(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTierCard(BuildContext context, String tier, double avgScore) {
    Color tierColor;
    IconData tierIcon;
    String tierDesc;
    double nextThreshold;

    switch (tier) {
      case 'Safe Driver':
        tierColor = AppColors.safe;
        tierIcon = Icons.verified;
        tierDesc = 'You are a safe driver! Keep up the excellent work.';
        nextThreshold = 100;
        break;
      case 'Improving':
        tierColor = AppColors.warning;
        tierIcon = Icons.trending_up;
        tierDesc =
            'You\'re getting better! Score avg 80+ to become a Safe Driver.';
        nextThreshold = 80;
        break;
      default:
        tierColor = AppColors.danger;
        tierIcon = Icons.warning;
        tierDesc = 'Focus on safe driving to improve your tier.';
        nextThreshold = 50;
    }

    final progress = (avgScore / nextThreshold).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tierColor.withOpacity(0.15), context.cardBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tierColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(tierIcon, color: tierColor, size: 48),
          const SizedBox(height: 12),
          Text(
            tier,
            style: TextStyle(
              color: tierColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tierDesc,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: context.borderColor,
              valueColor: AlwaysStoppedAnimation(tierColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Avg: ${avgScore.toStringAsFixed(0)} / ${nextThreshold.toStringAsFixed(0)}',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsCard(BuildContext context, int points) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningLight.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stars,
                color: AppColors.warningLight, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Points',
                style: TextStyle(color: context.textMuted, fontSize: 13),
              ),
              Text(
                '$points',
                style: const TextStyle(
                  color: AppColors.warningLight,
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

  Widget _buildRedemptionSection(BuildContext context) {
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
        const SizedBox(height: 12),
        _rewardCard(context, 'Fuel Voucher', '₹100 fuel discount', '500 pts',
            Icons.local_gas_station, AppColors.accent),
        const SizedBox(height: 10),
        _rewardCard(context, 'Insurance Discount', '5% off next premium',
            '1000 pts', Icons.security, AppColors.safe),
        const SizedBox(height: 10),
        _rewardCard(context, 'Service Coupon', 'Free vehicle health check',
            '750 pts', Icons.build, AppColors.primaryLight),
        const SizedBox(height: 10),
        _rewardCard(context, 'Parking Pass', '1 hour free parking', '300 pts',
            Icons.local_parking, AppColors.warningLight),
      ],
    );
  }

  Widget _rewardCard(BuildContext context, String title, String desc,
      String cost, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              cost,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
