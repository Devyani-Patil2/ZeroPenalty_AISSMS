import 'dart:math';
import 'package:dio/dio.dart';
import '../models/risk_zone.dart';

/// Service for risk zone detection — offline (embedded zones) + online (Flask API).
class RiskZoneService {
  static const double basePenalty = 500; // ₹500 base fine

  // Flask API base URL (change for production / ngrok)
  static const String _apiBase = 'http://10.0.2.2:5000'; // Android emulator
  // static const String _apiBase = 'http://192.168.x.x:5000'; // real device

  // ─── All 10 Pune Risk Zones (mirrors zones.json) ─────────────────
  static const List<Map<String, dynamic>> _zonesData = [
    {
      "id": "zone_001",
      "name": "Pune Railway Station Zone",
      "risk_level": "HIGH",
      "speed_limit": 20,
      "penalty_multiplier": 3.0,
      "alert_strength": "STRONG",
      "latitude": 18.5284,
      "longitude": 73.8742,
      "radius": 300,
      "description":
          "Dense pedestrian and vehicle traffic near the main railway station"
    },
    {
      "id": "zone_002",
      "name": "FC Road School Zone",
      "risk_level": "HIGH",
      "speed_limit": 15,
      "penalty_multiplier": 3.5,
      "alert_strength": "STRONG",
      "latitude": 18.5185,
      "longitude": 73.8416,
      "radius": 250,
      "description":
          "Active school zone on Fergusson College Road — children crossing frequently"
    },
    {
      "id": "zone_003",
      "name": "Laxmi Road Market Zone",
      "risk_level": "HIGH",
      "speed_limit": 20,
      "penalty_multiplier": 2.5,
      "alert_strength": "STRONG",
      "latitude": 18.5162,
      "longitude": 73.8570,
      "radius": 400,
      "description":
          "Busy commercial market area with high pedestrian and two-wheeler density"
    },
    {
      "id": "zone_004",
      "name": "Shivajinagar Hospital Zone",
      "risk_level": "HIGH",
      "speed_limit": 20,
      "penalty_multiplier": 3.0,
      "alert_strength": "STRONG",
      "latitude": 18.5308,
      "longitude": 73.8474,
      "radius": 200,
      "description":
          "Hospital zone — noise and speed restrictions strictly enforced"
    },
    {
      "id": "zone_005",
      "name": "Hinjewadi IT Park Zone",
      "risk_level": "MEDIUM",
      "speed_limit": 40,
      "penalty_multiplier": 1.8,
      "alert_strength": "STRONG",
      "latitude": 18.5912,
      "longitude": 73.7389,
      "radius": 600,
      "description": "IT corridor with peak-hour office traffic"
    },
    {
      "id": "zone_006",
      "name": "Viman Nagar Residential Zone",
      "risk_level": "MEDIUM",
      "speed_limit": 30,
      "penalty_multiplier": 1.5,
      "alert_strength": "NORMAL",
      "latitude": 18.5679,
      "longitude": 73.9143,
      "radius": 500,
      "description":
          "Residential zone with children, elderly, and internal colony traffic"
    },
    {
      "id": "zone_007",
      "name": "Katraj Ghat Blind Curve Zone",
      "risk_level": "HIGH",
      "speed_limit": 25,
      "penalty_multiplier": 2.8,
      "alert_strength": "STRONG",
      "latitude": 18.4534,
      "longitude": 73.8674,
      "radius": 350,
      "description": "Sharp curves and accident-prone ghat section"
    },
    {
      "id": "zone_008",
      "name": "Koregaon Park Nightlife Zone",
      "risk_level": "MEDIUM",
      "speed_limit": 35,
      "penalty_multiplier": 2.0,
      "alert_strength": "STRONG",
      "latitude": 18.5362,
      "longitude": 73.8931,
      "radius": 450,
      "description":
          "High pedestrian activity at night — elevated DUI and speed risk"
    },
    {
      "id": "zone_009",
      "name": "Hadapsar Industrial Zone",
      "risk_level": "LOW",
      "speed_limit": 50,
      "penalty_multiplier": 1.2,
      "alert_strength": "NORMAL",
      "latitude": 18.5089,
      "longitude": 73.9259,
      "radius": 700,
      "description": "Industrial area with moderate heavy-vehicle movement"
    },
    {
      "id": "zone_010",
      "name": "Baner Road Construction Zone",
      "risk_level": "HIGH",
      "speed_limit": 20,
      "penalty_multiplier": 2.5,
      "alert_strength": "STRONG",
      "latitude": 18.5590,
      "longitude": 73.7868,
      "radius": 300,
      "description":
          "Active construction zone — uneven road surface and reduced lane width"
    },
    // ── Demo-area zones (visible on map during demo route) ──
    {
      "id": "zone_011",
      "name": "AISSMS College Zone",
      "risk_level": "HIGH",
      "speed_limit": 20,
      "penalty_multiplier": 3.0,
      "alert_strength": "STRONG",
      "latitude": 18.5165,
      "longitude": 73.8565,
      "radius": 200,
      "description":
          "College zone — students crossing frequently, strict speed enforcement"
    },
    {
      "id": "zone_012",
      "name": "Shaniwar Wada Tourist Zone",
      "risk_level": "MEDIUM",
      "speed_limit": 25,
      "penalty_multiplier": 2.0,
      "alert_strength": "STRONG",
      "latitude": 18.5205,
      "longitude": 73.8535,
      "radius": 250,
      "description": "Tourist area near Shaniwar Wada — pedestrian heavy zone"
    },
    {
      "id": "zone_013",
      "name": "Bajirao Road Speed Trap",
      "risk_level": "HIGH",
      "speed_limit": 30,
      "penalty_multiplier": 2.5,
      "alert_strength": "STRONG",
      "latitude": 18.5150,
      "longitude": 73.8570,
      "radius": 300,
      "description":
          "Speed enforcement zone on Bajirao Road — frequent overspeeding violations"
    },
  ];

  static final RiskZone _defaultZone = const RiskZone(
    id: 'zone_default',
    name: 'Open Road (Default Zone)',
    riskLevel: 'LOW',
    speedLimit: 60,
    penaltyMultiplier: 1.0,
    alertStrength: 'NORMAL',
    description: 'No special risk zone detected. Standard road rules apply.',
    isDefaultZone: true,
  );

  /// Get all embedded zones (for the table)
  List<RiskZone> getAllZones() {
    return _zonesData
        .map((z) => RiskZone(
              id: z['id'],
              name: z['name'],
              riskLevel: z['risk_level'],
              speedLimit: z['speed_limit'],
              penaltyMultiplier: (z['penalty_multiplier'] as num).toDouble(),
              alertStrength: z['alert_strength'],
              latitude: (z['latitude'] as num).toDouble(),
              longitude: (z['longitude'] as num).toDouble(),
              radius: (z['radius'] as num).toDouble(),
              description: z['description'],
            ))
        .toList();
  }

  /// Quick test presets
  static const List<Map<String, dynamic>> presets = [
    {
      'label': '🚂 Railway Station',
      'lat': 18.5284,
      'lng': 73.8742,
      'speed': 35
    },
    {'label': '🏫 School Zone', 'lat': 18.5185, 'lng': 73.8416, 'speed': 12},
    {'label': '🌙 Koregaon Park', 'lat': 18.5362, 'lng': 73.8931, 'speed': 50},
    {'label': '⛰️ Katraj Ghat', 'lat': 18.4534, 'lng': 73.8674, 'speed': 40},
    {'label': '🛣️ Open Road', 'lat': 17.0000, 'lng': 72.0000, 'speed': 45},
  ];

  // ─── Haversine Distance (meters) ─────────────────────────────────
  static double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * pi / 180;

  // ─── Offline Zone Detection ──────────────────────────────────────
  RiskZone detectZoneOffline(double lat, double lng) {
    RiskZone? closest;
    double minDist = double.infinity;

    for (final z in _zonesData) {
      final zLat = (z['latitude'] as num).toDouble();
      final zLng = (z['longitude'] as num).toDouble();
      final radius = (z['radius'] as num).toDouble();
      final dist = _haversine(lat, lng, zLat, zLng);
      if (dist <= radius && dist < minDist) {
        minDist = dist;
        closest = RiskZone(
          id: z['id'],
          name: z['name'],
          riskLevel: z['risk_level'],
          speedLimit: z['speed_limit'],
          penaltyMultiplier: (z['penalty_multiplier'] as num).toDouble(),
          alertStrength: z['alert_strength'],
          latitude: zLat,
          longitude: zLng,
          radius: radius,
          description: z['description'],
        );
      }
    }

    return closest ?? _defaultZone;
  }

  // ─── Online API Detection ────────────────────────────────────────
  Future<RiskDetectionResult?> detectZoneOnline(
      double lat, double lng, double speed) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: _apiBase,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 8),
      ));
      final resp = await dio.get('/zone', queryParameters: {
        'lat': lat,
        'lng': lng,
        'speed': speed,
        'dynamic': true,
      });
      if (resp.statusCode == 200 && resp.data['status'] == 'success') {
        final zone = RiskZone.fromApiJson(resp.data['data']);
        final isOver = speed > zone.speedLimit;
        final penalty = isOver ? basePenalty * zone.penaltyMultiplier : 0.0;
        return RiskDetectionResult(
          zone: zone,
          currentSpeed: speed,
          isOverspeed: isOver,
          overspeedBy: isOver ? speed - zone.speedLimit : 0,
          penalty: penalty,
          dataSource: 'online',
        );
      }
    } catch (_) {
      // API unavailable — fall through to offline
    }
    return null;
  }

  // ─── Unified Detection (online → offline fallback) ───────────────
  Future<RiskDetectionResult> detectZone(
      double lat, double lng, double speed) async {
    // Try online first
    final online = await detectZoneOnline(lat, lng, speed);
    if (online != null) return online;

    // Offline fallback
    final zone = detectZoneOffline(lat, lng);
    final isOver = speed > zone.speedLimit;
    final penalty = isOver ? basePenalty * zone.penaltyMultiplier : 0.0;
    return RiskDetectionResult(
      zone: zone,
      currentSpeed: speed,
      isOverspeed: isOver,
      overspeedBy: isOver ? speed - zone.speedLimit : 0,
      penalty: penalty,
      dataSource: 'offline',
    );
  }

  // ─── Time-Based Risk (mirrors risk_engine.py) ────────────────────
  static Map<String, dynamic> getTimeRisk() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final weekday = now.weekday; // 1=Mon, 7=Sun
    final isWeekday = weekday >= 1 && weekday <= 5;
    final t = hour + minute / 60.0;

    final labels = <String>[];
    if (t >= 22 || t < 5) labels.add('🌙 Night Hours — High Risk');
    if (t >= 20 && t < 22) labels.add('🌆 Late Evening');
    if (isWeekday && ((t >= 8 && t <= 10) || (t >= 17 && t <= 19.5))) {
      labels.add('🚦 Rush Hour');
    }
    if (isWeekday && ((t >= 7.5 && t <= 9) || (t >= 13 && t <= 14.5))) {
      labels.add('🏫 School Hours');
    }

    return {
      'labels': labels,
      'hour': hour,
      'isNight': t >= 22 || t < 5,
      'isRushHour':
          isWeekday && ((t >= 8 && t <= 10) || (t >= 17 && t <= 19.5)),
    };
  }
}
