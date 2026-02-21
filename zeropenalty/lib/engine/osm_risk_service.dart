import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// OSM-based dynamic risk detection — directly queries OpenStreetMap Overpass API.
/// No server needed. Detects road type, nearby amenities (schools, hospitals),
/// and applies time-based risk modifiers.
class OsmRiskService {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const int _timeoutSec = 5;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: _timeoutSec),
    receiveTimeout: const Duration(seconds: _timeoutSec + 3),
  ));

  // Cache to avoid hitting OSM every second (cache for 15 seconds)
  OsmRiskResult? _cachedResult;
  DateTime? _cacheTime;
  double _cachedLat = 0;
  double _cachedLng = 0;
  static const int _cacheDurationSec = 15;
  static const double _cacheRadiusM = 50; // reuse if within 50m

  // ─── Road type → risk mapping (mirrors risk_engine.py) ──────────
  static const Map<String, Map<String, dynamic>> roadRiskMap = {
    'motorway': {'speed_limit': 100, 'risk': 'LOW', 'multiplier': 1.0},
    'motorway_link': {'speed_limit': 80, 'risk': 'LOW', 'multiplier': 1.0},
    'trunk': {'speed_limit': 80, 'risk': 'LOW', 'multiplier': 1.1},
    'trunk_link': {'speed_limit': 60, 'risk': 'LOW', 'multiplier': 1.1},
    'primary': {'speed_limit': 60, 'risk': 'LOW', 'multiplier': 1.2},
    'primary_link': {'speed_limit': 50, 'risk': 'MEDIUM', 'multiplier': 1.3},
    'secondary': {'speed_limit': 50, 'risk': 'MEDIUM', 'multiplier': 1.4},
    'secondary_link': {'speed_limit': 40, 'risk': 'MEDIUM', 'multiplier': 1.4},
    'tertiary': {'speed_limit': 40, 'risk': 'MEDIUM', 'multiplier': 1.5},
    'tertiary_link': {'speed_limit': 30, 'risk': 'MEDIUM', 'multiplier': 1.5},
    'residential': {'speed_limit': 30, 'risk': 'MEDIUM', 'multiplier': 1.6},
    'living_street': {'speed_limit': 20, 'risk': 'HIGH', 'multiplier': 2.0},
    'unclassified': {'speed_limit': 30, 'risk': 'MEDIUM', 'multiplier': 1.5},
    'pedestrian': {'speed_limit': 10, 'risk': 'HIGH', 'multiplier': 3.0},
    'footway': {'speed_limit': 10, 'risk': 'HIGH', 'multiplier': 3.0},
    'service': {'speed_limit': 20, 'risk': 'HIGH', 'multiplier': 2.0},
    'track': {'speed_limit': 20, 'risk': 'HIGH', 'multiplier': 2.0},
    'path': {'speed_limit': 10, 'risk': 'HIGH', 'multiplier': 3.0},
  };

  // ─── Amenity → risk boost (mirrors risk_engine.py) ──────────────
  static const Map<String, Map<String, dynamic>> amenityRiskBoost = {
    'school': {'risk_bump': 2, 'label': 'School Zone'},
    'college': {'risk_bump': 1, 'label': 'School Zone'},
    'university': {'risk_bump': 1, 'label': 'School Zone'},
    'hospital': {'risk_bump': 2, 'label': 'Hospital Zone'},
    'clinic': {'risk_bump': 1, 'label': 'Hospital Zone'},
    'marketplace': {'risk_bump': 2, 'label': 'Market Zone'},
    'place_of_worship': {'risk_bump': 1, 'label': 'Residential Area'},
    'bus_station': {'risk_bump': 1, 'label': 'Market Zone'},
    'railway_station': {'risk_bump': 2, 'label': 'Market Zone'},
  };

  static const Map<int, String> _riskFromOrder = {
    0: 'LOW',
    1: 'MEDIUM',
    2: 'HIGH'
  };
  static const Map<String, int> _riskOrder = {'LOW': 0, 'MEDIUM': 1, 'HIGH': 2};

  /// Main entry point — detect risk at a GPS location.
  /// Uses caching to avoid hammering the API.
  Future<OsmRiskResult> detectRisk(double lat, double lng) async {
    // Check cache
    if (_cachedResult != null && _cacheTime != null) {
      final elapsed = DateTime.now().difference(_cacheTime!).inSeconds;
      final dist = _haversineM(lat, lng, _cachedLat, _cachedLng);
      if (elapsed < _cacheDurationSec && dist < _cacheRadiusM) {
        return _cachedResult!;
      }
    }

    try {
      final result = await _fetchFromOsm(lat, lng);
      _cachedResult = result;
      _cacheTime = DateTime.now();
      _cachedLat = lat;
      _cachedLng = lng;
      return result;
    } catch (e) {
      debugPrint('[OsmRiskService] ⚠️ OSM failed: $e — using offline fallback');
      return _offlineFallback(lat, lng);
    }
  }

  /// Query OSM Overpass API for road type + amenities
  Future<OsmRiskResult> _fetchFromOsm(double lat, double lng) async {
    // Query nwr (node, way, relation) for amenities to catch large campuses
    final query = '''
[out:json][timeout:$_timeoutSec];
(
  way(around:40,$lat,$lng)[highway];
  nwr(around:150,$lat,$lng)[amenity];
);
out tags;
''';

    final resp = await _dio.post(
      _overpassUrl,
      data: 'data=$query',
      options: Options(contentType: 'application/x-form-urlencoded'),
    );

    String? roadType;
    final amenities = <String>{};

    if (resp.statusCode == 200 && resp.data != null) {
      final elements = resp.data['elements'] as List? ?? [];
      for (final el in elements) {
        final tags = el['tags'] as Map<String, dynamic>? ?? {};

        // Priority to 'highway' ways
        if (tags.containsKey('highway') && roadType == null) {
          roadType = tags['highway'] as String;
        }

        // Check amenities
        if (tags.containsKey('amenity')) {
          final amenity = tags['amenity'] as String;
          if (amenityRiskBoost.containsKey(amenity)) {
            amenities.add(amenity);
          }
        }
      }
    }

    debugPrint('[OsmRiskService] 🌐 OSM: road=$roadType, amenities=$amenities');
    return _calculateRisk(
        roadType ?? 'unclassified', amenities.toList(), 'online');
  }

  /// Calculate risk from road type + amenities + time
  OsmRiskResult _calculateRisk(
      String roadType, List<String> amenities, String source) {
    final roadInfo = roadRiskMap[roadType] ?? roadRiskMap['unclassified']!;
    int riskScore = _riskOrder[roadInfo['risk'] as String] ?? 0;
    int speedLimit = roadInfo['speed_limit'] as int;
    double multiplier = (roadInfo['multiplier'] as num).toDouble();
    final riskFactors = <String>['🛣️ Road: $roadType'];

    // Amenity bumps
    final amenityLabels = <String>[];
    for (final amenity in amenities) {
      final boost = amenityRiskBoost[amenity];
      if (boost != null) {
        final bump = boost['risk_bump'] as int;
        final label = boost['label'] as String;
        riskScore += bump;
        amenityLabels.add('📍 $label');
        if (bump >= 2) {
          speedLimit = min(speedLimit, 20);
          multiplier += 0.5;
        } else {
          speedLimit = min(speedLimit, 30);
          multiplier += 0.3;
        }
      }
    }
    riskFactors.addAll(amenityLabels);

    // Time-based risk
    final timeRisk = getTimeRisk();
    riskScore += timeRisk['risk_bump'] as int;
    riskFactors.addAll(timeRisk['labels'] as List<String>);

    if (timeRisk['is_night'] == true) {
      speedLimit = max((speedLimit * 0.7).toInt(), 20);
      multiplier += 0.5;
    } else if (timeRisk['is_rush_hour'] == true) {
      speedLimit = max((speedLimit * 0.85).toInt(), 20);
      multiplier += 0.2;
    }

    // School hours + school nearby → extra strict
    if (timeRisk['is_school_hour'] == true &&
        amenities.any((a) => a == 'school' || a == 'college')) {
      speedLimit = min(speedLimit, 15);
      multiplier += 0.8;
      riskFactors.add('🏫 Active School Zone — School Hours');
    }

    riskScore = min(riskScore, 2);
    final finalRisk = _riskFromOrder[riskScore] ?? 'LOW';
    final labels = _buildZoneLabels(roadType, amenities, timeRisk);

    return OsmRiskResult(
      zoneName: labels['name']!,
      categoryLabel: labels['category']!,
      riskLevel: finalRisk,
      speedLimit: speedLimit,
      penaltyMultiplier: min(multiplier, 4.0),
      alertStrength: riskScore >= 1 ? 'STRONG' : 'NORMAL',
      roadType: roadType,
      amenities: amenities,
      description: riskFactors.join(' | '),
      dataSource: source,
      isDynamic: true,
    );
  }

  /// Build zone labels: name (e.g. "School Zone (Night)") and category (e.g. "School Zone")
  Map<String, String> _buildZoneLabels(
      String roadType, List<String> amenities, Map<String, dynamic> timeRisk) {
    String category = 'Urban Road';

    if (amenities.isNotEmpty) {
      category = amenityRiskBoost[amenities.first]?['label'] ?? 'Urban Area';
    } else {
      const roadLabels = {
        'motorway': 'Highway',
        'trunk': 'Trunk Road',
        'primary': 'Primary Road',
        'secondary': 'Secondary Road',
        'residential': 'Residential Area',
        'living_street': 'Living Street',
        'pedestrian': 'Pedestrian Zone',
        'service': 'Service Road',
      };
      category = roadLabels[roadType] ?? 'Urban Road';
    }

    String name = category;
    if (timeRisk['is_night'] == true) {
      name += ' (Night)';
    } else if (timeRisk['is_school_hour'] == true) {
      name += ' (School Hours)';
    } else if (timeRisk['is_rush_hour'] == true) {
      name += ' (Rush Hour)';
    }

    return {'name': name, 'category': category};
  }

  /// Time-based risk calculation (mirrors risk_engine.py)
  static Map<String, dynamic> getTimeRisk() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final weekday = now.weekday; // 1=Mon, 7=Sun
    final isWeekday = weekday >= 1 && weekday <= 5;
    final t = hour + minute / 60.0;

    final labels = <String>[];
    int riskBump = 0;

    final isNight = t >= 22 || t < 5;
    final isLateEvening = t >= 20 && t < 22;
    final isSchoolHour =
        isWeekday && ((t >= 7.5 && t <= 9) || (t >= 13 && t <= 14.5));
    final isRushHour =
        isWeekday && ((t >= 8 && t <= 10) || (t >= 17 && t <= 19.5));

    if (isNight) {
      riskBump += 2;
      labels.add('🌙 Night Hours — High Risk');
    }
    if (isLateEvening) {
      riskBump += 1;
      labels.add('🌆 Late Evening');
    }
    if (isRushHour) {
      riskBump += 1;
      labels.add('🚦 Rush Hour');
    }
    if (isSchoolHour) {
      riskBump += 1;
      labels.add('🏫 School Hours');
    }

    return {
      'risk_bump': min(riskBump, 3),
      'labels': labels,
      'hour': hour,
      'is_night': isNight,
      'is_school_hour': isSchoolHour,
      'is_rush_hour': isRushHour,
      'is_late_evening': isLateEvening,
    };
  }

  /// Offline fallback — just returns a basic result from time risk only
  OsmRiskResult _offlineFallback(double lat, double lng) {
    return _calculateRisk('unclassified', [], 'offline');
  }

  /// Haversine distance in meters
  static double _haversineM(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * pi / 180;
}

/// Result from OSM risk detection
class OsmRiskResult {
  final String zoneName;
  final String categoryLabel; // Generic label like "School Zone"
  final String riskLevel; // HIGH, MEDIUM, LOW
  final int speedLimit; // km/h
  final double penaltyMultiplier;
  final String alertStrength;
  final String roadType;
  final List<String> amenities;
  final String description;
  final String dataSource; // online, offline
  final bool isDynamic;

  const OsmRiskResult({
    required this.zoneName,
    required this.categoryLabel,
    required this.riskLevel,
    required this.speedLimit,
    required this.penaltyMultiplier,
    required this.alertStrength,
    required this.roadType,
    required this.amenities,
    required this.description,
    required this.dataSource,
    required this.isDynamic,
  });

  /// Convert risk level to zone type string for scoring
  String get zoneType {
    switch (riskLevel) {
      case 'HIGH':
        return 'HIGH_RISK';
      case 'MEDIUM':
        return 'MEDIUM_RISK';
      default:
        return 'LOW_RISK';
    }
  }

  bool get isHighRisk => riskLevel == 'HIGH';
  bool get isMediumRisk => riskLevel == 'MEDIUM';
}
