/// Risk Zone data model — mirrors the backend zones.json structure.
class RiskZone {
  final String id;
  final String name;
  final String riskLevel; // HIGH, MEDIUM, LOW
  final int speedLimit; // km/h
  final double penaltyMultiplier;
  final String alertStrength; // STRONG, NORMAL
  final double latitude;
  final double longitude;
  final double radius; // meters
  final String description;
  final bool isDynamic;
  final bool isDefaultZone;
  final String? roadType;
  final bool accidentHotspot;
  final List<String> timeLabels;

  const RiskZone({
    required this.id,
    required this.name,
    required this.riskLevel,
    required this.speedLimit,
    required this.penaltyMultiplier,
    required this.alertStrength,
    this.latitude = 0,
    this.longitude = 0,
    this.radius = 0,
    required this.description,
    this.isDynamic = false,
    this.isDefaultZone = false,
    this.roadType,
    this.accidentHotspot = false,
    this.timeLabels = const [],
  });

  factory RiskZone.fromApiJson(Map<String, dynamic> json) {
    final timeFac = json['time_factors'] as Map<String, dynamic>? ?? {};
    final labels = (timeFac['labels'] as List?)?.cast<String>() ?? [];
    return RiskZone(
      id: json['zone_id'] ?? 'unknown',
      name: json['zone_name'] ?? 'Unknown Zone',
      riskLevel: json['risk_level'] ?? 'LOW',
      speedLimit: (json['speed_limit_kmh'] ?? 60).toInt(),
      penaltyMultiplier: (json['penalty_multiplier'] ?? 1.0).toDouble(),
      alertStrength: json['alert_strength'] ?? 'NORMAL',
      description: json['description'] ?? '',
      isDynamic: json['is_dynamic'] ?? false,
      isDefaultZone: json['is_default_zone'] ?? false,
      roadType: json['road_type'],
      accidentHotspot: json['accident_hotspot'] ?? false,
      timeLabels: labels,
    );
  }
}

/// Detection result wrapping zone + driver state
class RiskDetectionResult {
  final RiskZone zone;
  final double currentSpeed;
  final bool isOverspeed;
  final double overspeedBy;
  final double penalty;
  final String dataSource; // 'static', 'online', 'offline_fallback'

  const RiskDetectionResult({
    required this.zone,
    required this.currentSpeed,
    required this.isOverspeed,
    required this.overspeedBy,
    required this.penalty,
    this.dataSource = 'static',
  });
}
