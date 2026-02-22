import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import '../engine/sensor_service.dart';
import '../engine/event_detector.dart';
import '../engine/zone_manager.dart';
import '../engine/alert_manager.dart';
import '../engine/scoring_engine.dart';
import '../engine/feedback_engine.dart';
import '../engine/osm_risk_service.dart';
import '../models/trip.dart';
import '../models/zone.dart';
import '../data/database_helper.dart';
import '../services/api_service.dart';
import '../services/ml_api_service.dart';
import '../services/route_service.dart';
import '../utils/constants.dart';

/// Manages active trip state
class TripProvider extends ChangeNotifier {
  SensorService _sensorService =
      SensorService(useSimulation: AppConstants.useSimulation);
  final RouteService _routeService = RouteService();
  final EventDetector _eventDetector = EventDetector();
  final ZoneManager _zoneManager = ZoneManager();
  final AlertManager _alertManager = AlertManager();
  final OsmRiskService _osmRiskService = OsmRiskService();
  final MlApiService _mlApiService = MlApiService();
  FlutterTts? _tts;

  // OSM dynamic zone tracking
  OsmRiskResult? _osmRiskResult;
  String _lastAnnouncedZone = '';
  MlTripAnalysis? _mlAnalysis;

  // Demo / Live mode
  bool _isDemoMode = AppConstants.useSimulation;
  bool _isSimulatedTrip = false;

  // Location error — set when LIVE mode can't get GPS
  String? _locationError;

  // Trip state
  bool _isActive = false;
  DateTime? _startTime;
  double _currentSpeed = 0;
  double _maxSpeed = 0;
  double _totalSpeed = 0;
  int _speedReadings = 0;
  double _latitude = 0;
  double _longitude = 0;
  Zone? _currentZone;
  int _tripDurationSeconds = 0;
  double _distanceKm = 0;
  final List<TripEvent> _events = [];
  final List<String> _recentAlerts = [];
  final List<LatLng> _pathPoints = [];
  Trip? _lastCompletedTrip;

  StreamSubscription? _sensorSub;
  Timer? _durationTimer;

  // Getters
  bool get isActive => _isActive;
  bool get isDemoMode => _isDemoMode;
  bool get isSimulatedTrip => _isSimulatedTrip;
  String? get locationError => _locationError;
  double get currentSpeed => _currentSpeed;
  double get maxSpeed => _maxSpeed;
  double get latitude => _latitude;
  double get longitude => _longitude;
  Zone? get currentZone => _currentZone;
  int get tripDuration => _tripDurationSeconds;
  double get distanceKm => _distanceKm;
  List<TripEvent> get events => List.unmodifiable(_events);
  List<String> get recentAlerts => List.unmodifiable(_recentAlerts);
  List<LatLng> get pathPoints => List.unmodifiable(_pathPoints);
  Trip? get lastCompletedTrip => _lastCompletedTrip;
  OsmRiskResult? get osmRiskResult => _osmRiskResult;
  MlTripAnalysis? get mlAnalysis => _mlAnalysis;
  double get currentSpeedLimit {
    // Prefer OSM dynamic speed limit if available
    if (_osmRiskResult != null) return _osmRiskResult!.speedLimit.toDouble();
    return _currentZone?.speedLimit ?? 60;
  }

  bool get isOverspeeding => _currentSpeed > currentSpeedLimit;
  String get dynamicZoneName =>
      _osmRiskResult?.zoneName ?? _currentZone?.name ?? 'Open Road';
  String get dynamicRiskLevel => _osmRiskResult?.riskLevel ?? 'LOW';

  double get liveScore {
    if (_events.isEmpty) return 100;
    return ScoringEngine.calculateScore(_events);
  }

  /// Clear the location error
  void clearLocationError() {
    _locationError = null;
    notifyListeners();
  }

  /// Toggle between demo and live mode (only when trip is not active)
  void toggleDemoMode() {
    if (_isActive) return; // can't switch mid-trip
    _isDemoMode = !_isDemoMode;
    _locationError = null;
    _sensorService = SensorService(useSimulation: _isDemoMode);
    notifyListeners();
  }

  /// Manually set the demo simulation speed (only works in simulation)
  void setDemoSpeed(double speed) {
    if (_isSimulatedTrip) {
      _sensorService.setDemoSpeed(speed);
      notifyListeners();
    }
  }

  /// Initialize TTS
  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts!.setLanguage('en-US');
    await _tts!.setSpeechRate(0.5);
    await _tts!.setVolume(1.0);
  }

  /// Start a new trip.
  /// Returns true if trip started, false if blocked (e.g. location error).
  Future<bool> startTrip() async {
    if (_isActive) return false;
    _locationError = null;

    await _initTts();
    _eventDetector.reset();
    _events.clear();
    _recentAlerts.clear();
    _pathPoints.clear();
    _startTime = DateTime.now();
    _currentSpeed = 0;
    _maxSpeed = 0;
    _totalSpeed = 0;
    _speedReadings = 0;
    _tripDurationSeconds = 0;
    _distanceKm = 0;
    _isSimulatedTrip = _isDemoMode;

    // Start sensor stream (real or demo based on current mode)
    _sensorService = SensorService(useSimulation: _isDemoMode);

    if (_isDemoMode) {
      try {
        final start = LatLng(18.53120, 73.86435); // AISSMS
        final end = LatLng(18.51954, 73.85522); // Shaniwar Wada
        final snappedPoints = await _routeService.getRoute(start, end);
        if (snappedPoints.isNotEmpty) {
          final waypoints =
              snappedPoints.map((p) => [p.latitude, p.longitude]).toList();
          _sensorService.updateWaypoints(waypoints);
        }
      } catch (e) {
        debugPrint('Demo Route Fetch Failed: $e');
        // Falls back to hardcoded 150-point set already in SensorService
      }
    }

    try {
      final stream = await _sensorService.startSensors();
      _isActive = true;

      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _tripDurationSeconds++;
        notifyListeners();
      });

      _sensorSub = stream.listen(_onSensorData);
      notifyListeners();
      return true;
    } on LocationNotAvailableException catch (e) {
      // LIVE mode failed — don't start the trip, show error
      _locationError = e.message;
      _isActive = false;
      notifyListeners();
      return false;
    } catch (e) {
      _locationError = 'Failed to start sensors: $e';
      _isActive = false;
      notifyListeners();
      return false;
    }
  }

  /// Process incoming sensor data
  void _onSensorData(SensorData data) {
    _currentSpeed = data.speed;
    if (data.speed > _maxSpeed) _maxSpeed = data.speed;
    _totalSpeed += data.speed;
    _speedReadings++;
    _latitude = data.latitude;
    _longitude = data.longitude;

    // Filter GPS points to avoid big jumps (especially at trip start)
    final newPoint = LatLng(data.latitude, data.longitude);
    if (_pathPoints.isEmpty) {
      // Only add the first point if we have a real GPS fix (not 0,0)
      if (data.latitude.abs() > 0.1 && data.longitude.abs() > 0.1) {
        _pathPoints.add(newPoint);
      }
    } else {
      // Skip points that jump more than 500m from the last point (GPS glitch)
      final lastPt = _pathPoints.last;
      final dx = (data.latitude - lastPt.latitude).abs();
      final dy = (data.longitude - lastPt.longitude).abs();
      // ~0.005 degrees ≈ 500m
      if (dx < 0.005 && dy < 0.005) {
        _pathPoints.add(newPoint);
      }
    }

    // Update zone (polygon-based fallback)
    _currentZone = _zoneManager.getCurrentZone(data.latitude, data.longitude);

    // OSM dynamic risk detection (async, non-blocking)
    _updateOsmRisk(data.latitude, data.longitude);

    // Estimate distance
    _distanceKm += data.speed / 3600; // km/h to km/s * 1s

    // Detect events
    final event = _eventDetector.detect(data);
    if (event != null) {
      _events.add(event);
      _onEvent(event);
    }

    notifyListeners();
  }

  /// Fetch OSM risk data for current location (non-blocking).
  /// Triggers one-time zone-entry voice alert when zone changes.
  Future<void> _updateOsmRisk(double lat, double lng) async {
    try {
      final result = await _osmRiskService.detectRisk(lat, lng);
      _osmRiskResult = result;

      // Map static zones or OSM result to a generic category for the announcement
      String category = result.categoryLabel;

      // If we are in a static zone, provide a smart category based on the zone name
      if (_currentZone != null && _currentZone!.name != 'Open Road') {
        final name = _currentZone!.name.toLowerCase();
        if (name.contains('school') ||
            name.contains('college') ||
            name.contains('univ') ||
            name.contains('aissms')) {
          category = 'School Zone';
        } else if (name.contains('hosp') ||
            name.contains('clinic') ||
            name.contains('medic')) {
          category = 'Hospital Zone';
        } else if (name.contains('mark') ||
            name.contains('peth') ||
            name.contains('stat')) {
          category = 'Market Zone';
        } else if (name.contains('resid') || name.contains('housing')) {
          category = 'Residential Area';
        } else if (name.contains('highw') || name.contains('expres')) {
          category = 'Highway';
        } else {
          category = 'Urban Area';
        }
      }

      // One-time zone-entry alert — only speak when CATEGORY changes
      if (category != _lastAnnouncedZone && category.isNotEmpty) {
        _lastAnnouncedZone = category;

        // Skip generic "Urban Road" or "Open Road"
        final isGeneric = category == 'Urban Road' ||
            category == 'Open Road' ||
            category == 'Secondary Road';

        if (!isGeneric) {
          final speedLimit = currentSpeedLimit.toInt();
          final announce =
              'Entering $category. Speed limit $speedLimit kilometers per hour.';

          _recentAlerts.insert(0, ' $category (Speed Limit: $speedLimit)');
          if (_recentAlerts.length > 3) _recentAlerts.removeLast();

          final now = DateTime.now();
          if (_alertManager.canSpeak(now)) {
            _tts?.speak(announce);
            _alertManager.recordVoiceAlert(now);
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[TripProvider] OSM risk update failed: $e');
    }
  }

  /// Handle detected event
  void _onEvent(TripEvent event) {
    final zone = event.zoneType;
    final alertText = _alertManager.getAlertText(
      event.eventType,
      speed: event.speed,
      limit: event.speedLimit,
      zone: zone,
    );

    // Add to recent alerts (keep last 3)
    _recentAlerts.insert(0, alertText);
    if (_recentAlerts.length > 3) _recentAlerts.removeLast();

    // Voice prompt - with throttling
    final now = DateTime.now();
    if (_alertManager.canSpeak(now)) {
      final voiceText =
          _alertManager.getVoicePrompt(event.eventType, zone: zone);
      _tts?.speak(voiceText);
      _alertManager.recordVoiceAlert(now);
    }

    // Vibration
    final severity = _alertManager.getSeverity(event.eventType, zone);
    _alertManager.triggerVibration(severity);
  }

  /// Stop the trip and return summary
  Future<Trip> stopTrip() async {
    _isActive = false;
    _sensorSub?.cancel();
    _durationTimer?.cancel();
    _sensorService.stopSensors();
    _tts?.stop();

    final endTime = DateTime.now();
    final avgSpeed = _speedReadings > 0 ? _totalSpeed / _speedReadings : 0.0;
    final localScore = ScoringEngine.calculateScore(_events);
    final points = ScoringEngine.calculatePoints(localScore);

    // Count events by type and zone
    final eventCounts = ScoringEngine.eventBreakdown(_events);
    final zoneCounts = ScoringEngine.zoneBreakdown(_events);

    // Build a temporary trip to generate feedback from
    final tempTrip = Trip(
      driverId: AppConstants.driverId,
      startTime: _startTime ?? endTime,
      endTime: endTime,
      durationSeconds: _tripDurationSeconds,
      distanceKm: double.parse(_distanceKm.toStringAsFixed(2)),
      localScore: localScore,
      avgSpeed: double.parse(avgSpeed.toStringAsFixed(1)),
      maxSpeed: double.parse(_maxSpeed.toStringAsFixed(1)),
      overspeedCount: eventCounts['overspeed'] ?? 0,
      harshBrakeCount: eventCounts['harsh_brake'] ?? 0,
      sharpTurnCount: eventCounts['sharp_turn'] ?? 0,
      rashAccelCount: eventCounts['rash_accel'] ?? 0,
      highRiskEvents: zoneCounts['HIGH_RISK'] ?? 0,
      mediumRiskEvents: zoneCounts['MEDIUM_RISK'] ?? 0,
      lowRiskEvents: zoneCounts['LOW_RISK'] ?? 0,
      pointsEarned: points,
      events: List.from(_events),
    );

    // Generate feedback
    final feedback = FeedbackEngine.generateFeedback(tempTrip);

    final tripWithFeedback = Trip(
      driverId: tempTrip.driverId,
      startTime: tempTrip.startTime,
      endTime: tempTrip.endTime,
      durationSeconds: tempTrip.durationSeconds,
      distanceKm: tempTrip.distanceKm,
      localScore: tempTrip.localScore,
      avgSpeed: tempTrip.avgSpeed,
      maxSpeed: tempTrip.maxSpeed,
      overspeedCount: tempTrip.overspeedCount,
      harshBrakeCount: tempTrip.harshBrakeCount,
      sharpTurnCount: tempTrip.sharpTurnCount,
      rashAccelCount: tempTrip.rashAccelCount,
      highRiskEvents: tempTrip.highRiskEvents,
      mediumRiskEvents: tempTrip.mediumRiskEvents,
      lowRiskEvents: tempTrip.lowRiskEvents,
      pointsEarned: tempTrip.pointsEarned,
      feedback: feedback,
      events: tempTrip.events,
    );

    // Save locally
    final id = await DatabaseHelper.insertTrip(tripWithFeedback);
    _lastCompletedTrip = tripWithFeedback;

    // Try to sync to backend
    _syncToBackend(tripWithFeedback);

    notifyListeners();
    return tripWithFeedback;
  }

  /// Async sync to Python ML backend (FastAPI)
  Future<void> _syncToBackend(Trip trip) async {
    try {
      // Try new ML API service first
      final mlResult = await _mlApiService.uploadTrip(
        driverId: trip.driverId,
        startTime: trip.startTime.toIso8601String(),
        endTime: trip.endTime.toIso8601String(),
        durationSeconds: trip.durationSeconds,
        distanceKm: trip.distanceKm,
        localScore: trip.localScore,
        avgSpeed: trip.avgSpeed,
        maxSpeed: trip.maxSpeed,
        overspeedCount: trip.overspeedCount,
        harshBrakeCount: trip.harshBrakeCount,
        sharpTurnCount: trip.sharpTurnCount,
        rashAccelCount: trip.rashAccelCount,
        highRiskEvents: trip.highRiskEvents,
        mediumRiskEvents: trip.mediumRiskEvents,
        lowRiskEvents: trip.lowRiskEvents,
      );

      if (mlResult != null) {
        _mlAnalysis = mlResult;
        debugPrint('[TripProvider] ✅ ML analysis received: '
            'cluster=${mlResult.driverCluster}, '
            'risk=${mlResult.riskPrediction}, '
            'ml_score=${mlResult.mlScore}');

        // Update local trip with ML data
        await DatabaseHelper.updateTripML(
          trip.id ?? 0,
          mlResult.mlScore,
          mlResult.feedback,
        );
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('[TripProvider] ML API failed: $e');
    }

    // Fallback to old API service
    try {
      final result = await ApiService.uploadTrip(trip.toJson());
      if (result != null && result['ml_score'] != null) {
        await DatabaseHelper.updateTripML(
          trip.id ?? 0,
          (result['ml_score'] as num).toDouble(),
          List<String>.from(result['feedback'] ?? []),
        );
      }
    } catch (e) {
      debugPrint('[TripProvider] Backend sync failed (offline mode): $e');
    }
  }
}
