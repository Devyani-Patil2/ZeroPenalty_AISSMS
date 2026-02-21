import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../engine/achievement_service.dart';
import '../models/achievement.dart';
import '../providers/profile_provider.dart';
import '../utils/constants.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, child) {
          final profile = profileProvider.profile;
          final badges = AchievementService.badges;

          return Column(
            children: [
              _buildStatsBanner(context, profile),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: badges.length,
                  itemBuilder: (context, index) {
                    final badge = badges[index];
                    final isUnlocked =
                        profile.unlockedBadgeIds.contains(badge.id);
                    return GestureDetector(
                      onTap: () =>
                          _showBadgeDetail(context, badge, isUnlocked, profile),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: BadgeWidget(
                                achievement: badge, unlocked: isUnlocked),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            badge.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isUnlocked
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isUnlocked
                                  ? context.textPrimary
                                  : context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsBanner(BuildContext context, dynamic profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
              context,
              '${profile.unlockedBadgeIds.length}/${AchievementService.badges.length}',
              'Unlocked'),
          Container(width: 1, height: 40, color: context.borderColor),
          _buildStatItem(context, '${profile.totalPoints}', 'ZP Points'),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String val, String label) {
    return Column(
      children: [
        Text(val,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
        Text(label,
            style: TextStyle(fontSize: 12, color: context.textSecondary)),
      ],
    );
  }

  void _showBadgeDetail(BuildContext context, Achievement badge,
      bool isUnlocked, dynamic profile) {
    final progress = badge.getProgress(profile);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            BadgeWidget(achievement: badge, unlocked: isUnlocked, size: 100),
            const SizedBox(height: 20),
            Text(badge.name,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary)),
            const SizedBox(height: 10),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary),
            ),
            const SizedBox(height: 25),
            if (!isUnlocked) ...[
              Stack(
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [badge.bgColor, badge.strokeColor]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${(progress * 100).toInt()}% Progress',
                  style: TextStyle(fontSize: 12, color: badge.strokeColor)),
            ] else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('REWARD UNLOCKED! 🎟️',
                    style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 20),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}
