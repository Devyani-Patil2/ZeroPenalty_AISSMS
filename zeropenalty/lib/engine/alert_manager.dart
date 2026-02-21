import 'package:flutter/services.dart';
import '../utils/constants.dart';

/// Manages real-time alerts: voice (TTS), vibration, and text overlay
class AlertManager {
  DateTime? _lastAlertTime;
  DateTime? _lastVoiceAlertTime;

  bool canSpeak(DateTime now) {
    if (_lastVoiceAlertTime == null) return true;
    return now.difference(_lastVoiceAlertTime!).inMilliseconds >=
        AppConstants.voiceCooldownMs;
  }

  void recordVoiceAlert(DateTime now) {
    _lastVoiceAlertTime = now;
  }

  /// Generate alert text for an event
  String getAlertText(String eventType,
      {double? speed, double? limit, String? zone}) {
    switch (eventType) {
      case 'overspeed':
        if (zone == 'HIGH_RISK') {
          return '⚠️ Slow down! School zone — limit ${limit?.toInt()} km/h';
        }
        return '⚠️ Slow down! Speed limit ${limit?.toInt()} km/h';
      case 'harsh_brake':
        return '🛑 Harsh braking detected!';
      case 'sharp_turn':
        return '↩️ Sharp turn detected!';
      case 'rash_accel':
        return '🚀 Rash acceleration!';
      default:
        return '⚠️ Drive carefully!';
    }
  }

  /// Get voice prompt text
  String getVoicePrompt(String eventType, {String? zone}) {
    switch (eventType) {
      case 'overspeed':
        if (zone == 'HIGH_RISK') return 'Slow down. You are in a school zone.';
        return 'Please slow down. You are exceeding the speed limit.';
      case 'harsh_brake':
        return 'Harsh braking detected. Maintain safe following distance.';
      case 'sharp_turn':
        return 'Sharp turn detected. Please steer smoothly.';
      case 'rash_accel':
        return 'Rapid acceleration detected. Please accelerate gradually.';
      default:
        return 'Please drive carefully.';
    }
  }

  /// Trigger vibration based on severity
  void triggerVibration(String severity) {
    try {
      switch (severity) {
        case 'high':
          HapticFeedback.heavyImpact();
          break;
        case 'medium':
          HapticFeedback.mediumImpact();
          break;
        default:
          HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  /// Get severity level from event
  String getSeverity(String eventType, String zoneType) {
    if (zoneType == 'HIGH_RISK') return 'high';
    if (zoneType == 'MEDIUM_RISK' || eventType == 'overspeed') return 'medium';
    return 'low';
  }
}
