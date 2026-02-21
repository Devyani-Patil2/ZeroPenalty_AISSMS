import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Service to communicate with the FastAPI ML backend server.
/// Sends trip data after trip ends, receives ML-enhanced analysis.
class MlApiService {
  /// Change this to your laptop's WiFi IP before running the demo.
  /// Run `ipconfig` in terminal to find it.
  static const String _baseUrl = 'http://172.24.65.220:8000';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Upload a completed trip to the ML backend for analysis.
  /// Returns ML-enhanced results or null if server is unavailable.
  Future<MlTripAnalysis?> uploadTrip({
    required int driverId,
    required String startTime,
    required String endTime,
    required int durationSeconds,
    required double distanceKm,
    required double localScore,
    required double avgSpeed,
    required double maxSpeed,
    required int overspeedCount,
    required int harshBrakeCount,
    required int sharpTurnCount,
    required int rashAccelCount,
    required int highRiskEvents,
    required int mediumRiskEvents,
    required int lowRiskEvents,
    List<Map<String, dynamic>> events = const [],
  }) async {
    try {
      final resp = await _dio.post('/api/trips', data: {
        'driver_id': driverId,
        'start_time': startTime,
        'end_time': endTime,
        'duration_seconds': durationSeconds,
        'distance_km': distanceKm,
        'local_score': localScore,
        'avg_speed': avgSpeed,
        'max_speed': maxSpeed,
        'overspeed_count': overspeedCount,
        'harsh_brake_count': harshBrakeCount,
        'sharp_turn_count': sharpTurnCount,
        'rash_accel_count': rashAccelCount,
        'high_risk_events': highRiskEvents,
        'medium_risk_events': mediumRiskEvents,
        'low_risk_events': lowRiskEvents,
        'events': events,
      });

      if (resp.statusCode == 200 && resp.data != null) {
        return MlTripAnalysis.fromJson(resp.data);
      }
    } catch (e) {
      debugPrint('[MlApiService] ⚠️ ML server unavailable: $e');
    }
    return null;
  }

  /// Get analytics summary for a driver.
  Future<MlAnalyticsSummary?> getAnalytics(int driverId) async {
    try {
      final resp = await _dio.get('/api/analytics/summary/$driverId');
      if (resp.statusCode == 200 && resp.data != null) {
        return MlAnalyticsSummary.fromJson(resp.data);
      }
    } catch (e) {
      debugPrint('[MlApiService] ⚠️ Analytics unavailable: $e');
    }
    return null;
  }

  /// Get ML-powered feedback for a specific trip.
  Future<MlFeedback?> getFeedback(int tripId) async {
    try {
      final resp = await _dio.get('/api/feedback/$tripId');
      if (resp.statusCode == 200 && resp.data != null) {
        return MlFeedback.fromJson(resp.data);
      }
    } catch (e) {
      debugPrint('[MlApiService] ⚠️ Feedback unavailable: $e');
    }
    return null;
  }

  /// Check if ML server is reachable.
  Future<bool> isServerAvailable() async {
    try {
      final resp = await _dio.get('/');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ─── Data Classes ──────────────────────────────────────────────────

class MlTripAnalysis {
  final int tripId;
  final double localScore;
  final double mlScore;
  final bool isAnomaly;
  final String driverCluster; // Cautious, Moderate, Aggressive
  final String riskPrediction; // Low, Medium, High
  final List<String> feedback;
  final int pointsEarned;
  final String tier; // Safe Driver, Improving, Risky

  MlTripAnalysis({
    required this.tripId,
    required this.localScore,
    required this.mlScore,
    required this.isAnomaly,
    required this.driverCluster,
    required this.riskPrediction,
    required this.feedback,
    required this.pointsEarned,
    required this.tier,
  });

  factory MlTripAnalysis.fromJson(Map<String, dynamic> json) {
    return MlTripAnalysis(
      tripId: json['trip_id'] ?? 0,
      localScore: (json['local_score'] as num?)?.toDouble() ?? 0,
      mlScore: (json['ml_score'] as num?)?.toDouble() ?? 0,
      isAnomaly: json['is_anomaly'] ?? false,
      driverCluster: json['driver_cluster'] ?? 'Moderate',
      riskPrediction: json['risk_prediction'] ?? 'Medium',
      feedback: List<String>.from(json['feedback'] ?? []),
      pointsEarned: json['points_earned'] ?? 0,
      tier: json['tier'] ?? 'Improving',
    );
  }
}

class MlAnalyticsSummary {
  final int totalTrips;
  final double lifetimeAvgScore;
  final List<double> last5Scores;
  final double weeklyAvg;
  final double improvementPct;
  final int totalPoints;
  final String tier;
  final String clusterLabel;

  MlAnalyticsSummary({
    required this.totalTrips,
    required this.lifetimeAvgScore,
    required this.last5Scores,
    required this.weeklyAvg,
    required this.improvementPct,
    required this.totalPoints,
    required this.tier,
    required this.clusterLabel,
  });

  factory MlAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return MlAnalyticsSummary(
      totalTrips: json['total_trips'] ?? 0,
      lifetimeAvgScore: (json['lifetime_avg_score'] as num?)?.toDouble() ?? 0,
      last5Scores: (json['last_5_scores'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      weeklyAvg: (json['weekly_avg'] as num?)?.toDouble() ?? 0,
      improvementPct: (json['improvement_pct'] as num?)?.toDouble() ?? 0,
      totalPoints: json['total_points'] ?? 0,
      tier: json['tier'] ?? 'Improving',
      clusterLabel: json['cluster_label'] ?? 'Moderate',
    );
  }
}

class MlFeedback {
  final int tripId;
  final List<String> suggestions;
  final String driverType;
  final String riskLevel;

  MlFeedback({
    required this.tripId,
    required this.suggestions,
    required this.driverType,
    required this.riskLevel,
  });

  factory MlFeedback.fromJson(Map<String, dynamic> json) {
    return MlFeedback(
      tripId: json['trip_id'] ?? 0,
      suggestions: List<String>.from(json['suggestions'] ?? []),
      driverType: json['driver_type'] ?? 'Moderate',
      riskLevel: json['risk_level'] ?? 'Medium',
    );
  }
}
