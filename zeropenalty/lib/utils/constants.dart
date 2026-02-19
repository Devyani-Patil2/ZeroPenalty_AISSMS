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

/// App color palette — brand / accent colors (theme-independent)
class AppColors {
  // Dark-only fallback colors (used by screens that haven't migrated)
  static const Color background = Color(0xFF0A0E27);
  static const Color surface = Color(0xFF141832);
  static const Color card = Color(0xFF1C2045);
  static const Color cardBorder = Color(0xFF2A2F5A);

  // Green theme (splash / auth screens)
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color splashBg = Color(0xFF1A1A2E);

  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF8B85FF);
  static const Color accent = Color(0xFF00D9FF);

  static const Color safe = Color(0xFF00E676);
  static const Color safeLight = Color(0xFF69F0AE);
  static const Color warning = Color(0xFFFFAB00);
  static const Color warningLight = Color(0xFFFFD54F);
  static const Color danger = Color(0xFFFF5252);
  static const Color dangerLight = Color(0xFFFF8A80);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B3D6);
  static const Color textMuted = Color(0xFF6B6F99);

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
  Color get surfaceBg => isDark ? AppColors.surface : const Color(0xFFF0F0F5);
  Color get borderColor =>
      isDark ? AppColors.cardBorder : const Color(0xFFE0E0E0);

  Color get textPrimary => isDark ? Colors.white : const Color(0xFF1A1A2E);
  Color get textSecondary =>
      isDark ? const Color(0xFFB0B3D6) : const Color(0xFF616161);
  Color get textMuted =>
      isDark ? const Color(0xFF6B6F99) : const Color(0xFF9E9E9E);
}
