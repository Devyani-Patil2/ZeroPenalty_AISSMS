import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<ProfileProvider>().profile;
      _nameController.text = profile.name;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

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
                children: [
                  const SizedBox(height: 20),
                  // Avatar
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                      ),
                    ),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.cardBg,
                      ),
                      child: Icon(Icons.person,
                          color: context.textSecondary, size: 40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  _isEditing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 200,
                              child: TextField(
                                controller: _nameController,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: AppColors.primary),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                profile.updateName(_nameController.text);
                                setState(() => _isEditing = false);
                              },
                              icon: const Icon(Icons.check,
                                  color: AppColors.safe),
                            ),
                          ],
                        )
                      : GestureDetector(
                          onTap: () => setState(() => _isEditing = true),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                p.name,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.edit,
                                  color: context.textMuted, size: 16),
                            ],
                          ),
                        ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.scoreColor(p.lifetimeAvgScore)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      p.tier,
                      style: TextStyle(
                        color: AppColors.scoreColor(p.lifetimeAvgScore),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Stats grid
                  Row(
                    children: [
                      _profileStat('Total Trips', '${p.totalTrips}',
                          Icons.route, AppColors.accent),
                      const SizedBox(width: 12),
                      _profileStat(
                          'Avg Score',
                          p.lifetimeAvgScore.toStringAsFixed(0),
                          Icons.speed,
                          AppColors.scoreColor(p.lifetimeAvgScore)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _profileStat('Points', '${p.totalPoints}', Icons.stars,
                          AppColors.warningLight),
                      const SizedBox(width: 12),
                      _profileStat('Cluster', p.clusterLabel, Icons.analytics,
                          AppColors.primaryLight),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // ── Theme Toggle ──
                  _buildThemeToggle(),
                  const SizedBox(height: 16),

                  // ── Sign Out Button ──
                  _buildSignOutButton(),
                  const SizedBox(height: 16),

                  // About section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'ZeroPenalty',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version 1.0.0',
                          style:
                              TextStyle(color: context.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Real-time driving behavior coaching.\nGuide, don\'t punish.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: context.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: [
              Icon(
                themeProvider.isDarkMode
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: themeProvider.isDarkMode
                    ? AppColors.warningLight
                    : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: themeProvider.isDarkMode,
                onChanged: (_) => themeProvider.toggleTheme(),
                activeColor: AppColors.primary,
                inactiveThumbColor: AppColors.primary,
                inactiveTrackColor: AppColors.primaryLight.withOpacity(0.3),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await context.read<AuthProvider>().signOut();
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              (route) => false,
            );
          }
        },
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Sign Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: AppColors.danger),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _profileStat(String label, String value, IconData icon, Color color) {
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
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
