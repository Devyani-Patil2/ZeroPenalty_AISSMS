import 'dart:math';
import '../models/trip.dart';
import '../utils/constants.dart';

/// Local rule-based scoring engine
class ScoringEngine {
  /// Calculate trip score from events
  static double calculateScore(List<TripEvent> events) {
    double totalDeduction = 0;

    for (final event in events) {
      final basePenalty = AppConstants.basePenalties[event.eventType] ?? 2.0;
      final multiplier = AppConstants.zoneMultipliers[event.zoneType] ?? 1.0;
      totalDeduction += basePenalty * multiplier;
    }

    return max(0, AppConstants.baseScore - totalDeduction);
  }

  /// Calculate points from score
  static int calculatePoints(double score) {
    return (score * AppConstants.pointsMultiplier).floor();
  }

  /// Get tier from average score
  static String getTier(double avgScore) {
    if (avgScore >= 80) return 'Safe Driver';
    if (avgScore >= 50) return 'Improving';
    return 'Risky';
  }

  /// Get color grade
  static String getColorGrade(double score) {
    if (score >= 80) return 'green';
    if (score >= 50) return 'yellow';
    return 'red';
  }

  /// Count events by type
  static Map<String, int> eventBreakdown(List<TripEvent> events) {
    final counts = <String, int>{
      'overspeed': 0,
      'harsh_brake': 0,
      'sharp_turn': 0,
      'rash_accel': 0,
    };
    for (final event in events) {
      counts[event.eventType] = (counts[event.eventType] ?? 0) + 1;
    }
    return counts;
  }

  /// Count events by zone
  static Map<String, int> zoneBreakdown(List<TripEvent> events) {
    final counts = <String, int>{
      'HIGH_RISK': 0,
      'MEDIUM_RISK': 0,
      'LOW_RISK': 0,
    };
    for (final event in events) {
      counts[event.zoneType] = (counts[event.zoneType] ?? 0) + 1;
    }
    return counts;
  }
}
