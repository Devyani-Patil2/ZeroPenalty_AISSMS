/// Trip data model
class Trip {
  final int? id;
  final int driverId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final double distanceKm;
  final double localScore;
  final double? mlScore;
  final double avgSpeed;
  final double maxSpeed;
  final int overspeedCount;
  final int harshBrakeCount;
  final int sharpTurnCount;
  final int rashAccelCount;
  final int highRiskEvents;
  final int mediumRiskEvents;
  final int lowRiskEvents;
  final int pointsEarned;
  final bool isAnomaly;
  final List<String> feedback;
  final List<TripEvent> events;

  Trip({
    this.id,
    required this.driverId,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.distanceKm,
    required this.localScore,
    this.mlScore,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.overspeedCount,
    required this.harshBrakeCount,
    required this.sharpTurnCount,
    required this.rashAccelCount,
    required this.highRiskEvents,
    required this.mediumRiskEvents,
    required this.lowRiskEvents,
    required this.pointsEarned,
    this.isAnomaly = false,
    this.feedback = const [],
    this.events = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'driver_id': driverId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'duration_seconds': durationSeconds,
      'distance_km': distanceKm,
      'local_score': localScore,
      'ml_score': mlScore,
      'avg_speed': avgSpeed,
      'max_speed': maxSpeed,
      'overspeed_count': overspeedCount,
      'harsh_brake_count': harshBrakeCount,
      'sharp_turn_count': sharpTurnCount,
      'rash_accel_count': rashAccelCount,
      'high_risk_events': highRiskEvents,
      'medium_risk_events': mediumRiskEvents,
      'low_risk_events': lowRiskEvents,
      'points_earned': pointsEarned,
      'is_anomaly': isAnomaly ? 1 : 0,
      'feedback': feedback.join('|||'),
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'],
      driverId: map['driver_id'] ?? 1,
      startTime: DateTime.parse(map['start_time']),
      endTime: DateTime.parse(map['end_time']),
      durationSeconds: map['duration_seconds'] ?? 0,
      distanceKm: (map['distance_km'] ?? 0).toDouble(),
      localScore: (map['local_score'] ?? 100).toDouble(),
      mlScore: map['ml_score']?.toDouble(),
      avgSpeed: (map['avg_speed'] ?? 0).toDouble(),
      maxSpeed: (map['max_speed'] ?? 0).toDouble(),
      overspeedCount: map['overspeed_count'] ?? 0,
      harshBrakeCount: map['harsh_brake_count'] ?? 0,
      sharpTurnCount: map['sharp_turn_count'] ?? 0,
      rashAccelCount: map['rash_accel_count'] ?? 0,
      highRiskEvents: map['high_risk_events'] ?? 0,
      mediumRiskEvents: map['medium_risk_events'] ?? 0,
      lowRiskEvents: map['low_risk_events'] ?? 0,
      pointsEarned: map['points_earned'] ?? 0,
      isAnomaly: (map['is_anomaly'] ?? 0) == 1,
      feedback: (map['feedback'] as String?)?.split('|||').where((s) => s.isNotEmpty).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driver_id': driverId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
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
      'events': events.map((e) => e.toJson()).toList(),
    };
  }

  String get colorGrade {
    final score = mlScore ?? localScore;
    if (score >= 80) return 'green';
    if (score >= 50) return 'yellow';
    return 'red';
  }

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}

/// Trip event model
class TripEvent {
  final String eventType; // overspeed, harsh_brake, sharp_turn, rash_accel
  final DateTime timestamp;
  final double? speed;
  final double? speedLimit;
  final String zoneType; // HIGH_RISK, MEDIUM_RISK, LOW_RISK
  final double? severity;
  final double? latitude;
  final double? longitude;

  TripEvent({
    required this.eventType,
    required this.timestamp,
    this.speed,
    this.speedLimit,
    required this.zoneType,
    this.severity,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'timestamp': timestamp.toIso8601String(),
      'speed': speed,
      'speed_limit': speedLimit,
      'zone_type': zoneType,
      'severity': severity,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  String get displayName {
    switch (eventType) {
      case 'overspeed':
        return 'Overspeeding';
      case 'harsh_brake':
        return 'Harsh Braking';
      case 'sharp_turn':
        return 'Sharp Turn';
      case 'rash_accel':
        return 'Rash Acceleration';
      default:
        return eventType;
    }
  }
}
