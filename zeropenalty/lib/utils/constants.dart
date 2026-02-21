import 'package:flutter/material.dart';

/// App-wide constants
class AppConstants {
  // API
  static const String apiBaseUrl =
      'http://10.0.2.2:8000'; // Android emulator → localhost
  static const int driverId = 1;

  // Detection thresholds
  static const double harshBrakeThreshold = 6.0; // m/s²
  static const double rashAccelThreshold = 5.0; // m/s²
  static const double sharpTurnThreshold = 2.5; // rad/s
  static const int alertCooldownMs = 5000; // 5 seconds between alerts

  // Scoring
  static const double baseScore = 100.0;
  static const Map<String, double> basePenalties = {
    'overspeed': 5.0,
    'harsh_brake': 3.0,
    'sharp_turn': 2.0,
    'rash_accel': 3.0,
  };
  static const Map<String, double> zoneMultipliers = {
    'HIGH_RISK': 2.0,
    'MEDIUM_RISK': 1.5,
    'LOW_RISK': 1.0,
  };

  // Rewards
  static const double pointsMultiplier = 1.5;

  // Simulation
  static const bool useSimulation = true; // Set false on real device
  static const int sensorUpdateMs = 1000;
}

/// App color palette — dark charcoal + green theme (matches map bg image)
class AppColors {
  // Dark theme base colors (charcoal/slate tones from the map bg)
  static const Color background = Color(0xFF1A1D1E);
  static const Color surface = Color(0xFF222626);
  static const Color card = Color(0xFF2A2E2F);
  static const Color cardBorder = Color(0xFF3A3E3F);

  // Green theme (primary brand — matches green glowing dots in bg)
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color splashBg = Color(0xFF1A1D1E);

  // Primary = green instead of purple
  static const Color primary = Color(0xFF4CAF50);
  static const Color primaryLight = Color(0xFF81C784);
  static const Color accent = Color(0xFF66BB6A);

  static const Color safe = Color(0xFF66BB6A);
  static const Color safeLight = Color(0xFFA5D6A7);
  static const Color warning = Color(0xFFFFB74D);
  static const Color warningLight = Color(0xFFFFD54F);
  static const Color danger = Color(0xFFEF5350);
  static const Color dangerLight = Color(0xFFFF8A80);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B5B3);
  static const Color textMuted = Color(0xFF6E7573);

  static Color scoreColor(double score) {
    if (score >= 80) return safe;
    if (score >= 50) return warning;
    return danger;
  }

  static Color zoneColor(String zoneType) {
    switch (zoneType) {
      case 'HIGH_RISK':
        return danger;
      case 'MEDIUM_RISK':
        return warning;
      case 'LOW_RISK':
        return safe;
      default:
        return textSecondary;
    }
  }
}

/// Theme-aware color helpers via BuildContext extension
extension AppTheme on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bg => Theme.of(this).scaffoldBackgroundColor;
  Color get cardBg => isDark ? AppColors.card : Colors.white;
  Color get surfaceBg => isDark ? AppColors.surface : const Color(0xFFF2F5F3);
  Color get borderColor =>
      isDark ? AppColors.cardBorder : const Color(0xFFDDE0DD);

  Color get textPrimary => isDark ? Colors.white : const Color(0xFF1A1D1E);
  Color get textSecondary =>
      isDark ? const Color(0xFFB0B5B3) : const Color(0xFF5A5F5C);
  Color get textMuted =>
      isDark ? const Color(0xFF6E7573) : const Color(0xFF9E9E9E);
}
