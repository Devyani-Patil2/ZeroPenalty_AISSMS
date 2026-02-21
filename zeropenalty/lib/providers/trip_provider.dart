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
import '../models/trip.dart';
import '../models/zone.dart';
import '../data/database_helper.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

/// Manages active trip state
class TripProvider extends ChangeNotifier {
  SensorService _sensorService =
      SensorService(useSimulation: AppConstants.useSimulation);
  final EventDetector _eventDetector = EventDetector();
  final ZoneManager _zoneManager = ZoneManager();
  final AlertManager _alertManager = AlertManager();
  FlutterTts? _tts;

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
  double get currentSpeedLimit => _currentZone?.speedLimit ?? 60;
  bool get isOverspeeding => _currentSpeed > currentSpeedLimit;

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
    _pathPoints.add(LatLng(data.latitude, data.longitude));

    // Update zone
    _currentZone = _zoneManager.getCurrentZone(data.latitude, data.longitude);

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

    // Voice prompt
    final voiceText = _alertManager.getVoicePrompt(event.eventType, zone: zone);
    _tts?.speak(voiceText);

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

  /// Async sync to Python backend
  Future<void> _syncToBackend(Trip trip) async {
    try {
      final result = await ApiService.uploadTrip(trip.toJson());
      if (result != null && result['ml_score'] != null) {
        // Update local trip with ML data
        await DatabaseHelper.updateTripML(
          trip.id ?? 0,
          (result['ml_score'] as num).toDouble(),
          List<String>.from(result['feedback'] ?? []),
        );
      }
    } catch (e) {
      print('Backend sync failed (offline mode): $e');
    }
  }
}
