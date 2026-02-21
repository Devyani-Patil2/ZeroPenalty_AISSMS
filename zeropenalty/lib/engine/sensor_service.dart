import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../utils/constants.dart';

/// Sensor data packet — all readings at one point in time
class SensorData {
  final double speed; // km/h
  final double latitude;
  final double longitude;
  final double accelerationX;
  final double accelerationY;
  final double accelerationZ;
  final double gyroscopeX;
  final double gyroscopeY;
  final double gyroscopeZ;
  final DateTime timestamp;
  final bool isSimulated; // flag so UI can show demo badge

  SensorData({
    required this.speed,
    required this.latitude,
    required this.longitude,
    this.accelerationX = 0,
    this.accelerationY = 0,
    this.accelerationZ = 0,
    this.gyroscopeX = 0,
    this.gyroscopeY = 0,
    this.gyroscopeZ = 0,
    DateTime? timestamp,
    this.isSimulated = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Exception thrown when LIVE mode can't access location
class LocationNotAvailableException implements Exception {
  final String message;
  LocationNotAvailableException(this.message);
  @override
  String toString() => message;
}

/// Sensor service — handles REAL GPS + motion sensors with a demo mode.
///
/// When `useSimulation` is true  → generates realistic driving data (for demos).
/// When `useSimulation` is false → reads actual device GPS + sensors.
///   If GPS is not available in LIVE mode, throws LocationNotAvailableException
///   instead of silently falling back to demo.
class SensorService {
  final bool useSimulation;
  StreamController<SensorData>? _controller;

  // Real sensor subscriptions
  StreamSubscription<Position>? _geoSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _realEmitTimer;

  // Latest real readings (updated by individual streams, combined on timer)
  double _realSpeed = 0;
  double _realLat = 0;
  double _realLng = 0;
  double _realAccelX = 0;
  double _realAccelY = 0;
  double _realAccelZ = 9.8;
  double _realGyroX = 0;
  double _realGyroY = 0;
  double _realGyroZ = 0;

  // Simulation state
  Timer? _simTimer;
  double _simLat = 18.5200;
  double _simLng = 73.8560;
  double _simSpeed = 0;
  final _random = Random();
  int _simStep = 0;

  SensorService({this.useSimulation = true});

  /// Start sensor stream.
  /// In LIVE mode, throws LocationNotAvailableException if GPS is not accessible.
  Future<Stream<SensorData>> startSensors() async {
    _controller = StreamController<SensorData>.broadcast();

    if (useSimulation) {
      debugPrint('[SensorService] 🎮 Starting DEMO mode');
      _startSimulation();
    } else {
      debugPrint('[SensorService] 📡 Starting LIVE mode — requesting GPS...');
      await _startRealSensors(); // throws if GPS not available
    }

    return _controller!.stream;
  }

  /// Stop all sensors
  void stopSensors() {
    _simTimer?.cancel();
    _realEmitTimer?.cancel();
    _geoSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _controller?.close();
    _controller = null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // REAL SENSORS — throws if GPS not available (NO silent fallback!)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _startRealSensors() async {
    // ── 1. Check location service ───────────────────────────────────
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[SensorService] ❌ Location services are OFF');
      _controller?.close();
      throw LocationNotAvailableException(
        'Location services are turned OFF.\n\nPlease go to Settings → Location and turn it ON, then try again.',
      );
    }

    // ── 2. Check & request permission ───────────────────────────────
    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('[SensorService] Current permission: $permission');

    if (permission == LocationPermission.denied) {
      debugPrint('[SensorService] Requesting location permission...');
      permission = await Geolocator.requestPermission();
      debugPrint('[SensorService] Permission after request: $permission');
    }

    if (permission == LocationPermission.denied) {
      _controller?.close();
      throw LocationNotAvailableException(
        'Location permission was denied.\n\nPlease allow location access for ZeroPenalty in your phone Settings → Apps → ZeroPenalty → Permissions → Location.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      _controller?.close();
      throw LocationNotAvailableException(
        'Location permission is permanently denied.\n\nPlease go to Settings → Apps → ZeroPenalty → Permissions → Location and set it to \"Allow\".',
      );
    }

    debugPrint('[SensorService] ✅ GPS permission granted: $permission');

    // ── 3. Start GPS stream ─────────────────────────────────────────
    _geoSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen((Position position) {
      _realLat = position.latitude;
      _realLng = position.longitude;
      _realSpeed = (position.speed >= 0) ? position.speed * 3.6 : 0;
    }, onError: (e) {
      debugPrint('[SensorService] ❌ GPS stream error: $e');
    });

    // ── 4. Accelerometer (optional — continue without if unavailable) ──
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 100),
      ).listen((AccelerometerEvent event) {
        _realAccelX = event.x;
        _realAccelY = event.y;
        _realAccelZ = event.z;
      });
      debugPrint('[SensorService] ✅ Accelerometer started');
    } catch (e) {
      debugPrint('[SensorService] ⚠️ Accelerometer unavailable: $e');
    }

    // ── 5. Gyroscope (optional — continue without if unavailable) ───
    try {
      _gyroSub = gyroscopeEventStream(
        samplingPeriod: const Duration(milliseconds: 100),
      ).listen((GyroscopeEvent event) {
        _realGyroX = event.x;
        _realGyroY = event.y;
        _realGyroZ = event.z;
      });
      debugPrint('[SensorService] ✅ Gyroscope started');
    } catch (e) {
      debugPrint('[SensorService] ⚠️ Gyroscope unavailable: $e');
    }

    // ── 6. Combine & emit at fixed interval ─────────────────────────
    debugPrint('[SensorService] ✅ LIVE mode active!');
    _realEmitTimer = Timer.periodic(
      Duration(milliseconds: AppConstants.sensorUpdateMs),
      (_) {
        if (_controller != null && !_controller!.isClosed) {
          _controller!.add(SensorData(
            speed: _realSpeed,
            latitude: _realLat,
            longitude: _realLng,
            accelerationX: _realAccelX,
            accelerationY: _realAccelY,
            accelerationZ: _realAccelZ,
            gyroscopeX: _realGyroX,
            gyroscopeY: _realGyroY,
            gyroscopeZ: _realGyroZ,
            isSimulated: false,
          ));
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DEMO / SIMULATION MODE — Waypoint-based Pune Route
  // ═══════════════════════════════════════════════════════════════════

  // Waypoints following real Pune roads near AISSMS / Shaniwar Wada area.
  // Each waypoint: [lat, lng, targetSpeed, description]
  static const List<List<dynamic>> _demoWaypoints = [
    // ── Start near AISSMS College ──
    [18.5165, 73.8565, 15.0, 'Start near AISSMS College'],
    [18.5172, 73.8558, 25.0, 'Exiting college zone'],
    [18.5180, 73.8552, 35.0, 'Heading north on Tilak Road'],
    // ── Approaching Shaniwar Wada ──
    [18.5190, 73.8545, 40.0, 'Tilak Road — picking up speed'],
    [18.5198, 73.8540, 30.0, 'Approaching Shaniwar Wada area'],
    [18.5205, 73.8535, 20.0, 'Near Shaniwar Wada — tourist zone'],
    // ── Turn towards Laxmi Road ──
    [18.5200, 73.8548, 25.0, 'Turning east towards Laxmi Road'],
    [18.5195, 73.8560, 30.0, 'Heading to Laxmi Road Market'],
    [18.5185, 73.8570, 15.0, 'Entering Laxmi Road Market zone'],
    [18.5178, 73.8578, 20.0, 'In Laxmi Road — heavy traffic'],
    // ── South on Bajirao Road ──
    [18.5170, 73.8575, 35.0, 'Exiting market — Bajirao Road'],
    [18.5160, 73.8572, 45.0, 'Bajirao Road — speeding up'],
    [18.5150, 73.8570, 55.0, 'Bajirao Road — OVERSPEED segment'],
    [18.5145, 73.8568, 60.0, 'Still overspeeding on Bajirao!'],
    // ── Turn back towards AISSMS ──
    [18.5148, 73.8558, 25.0, 'Harsh brake — slowing down'],
    [18.5152, 73.8550, 30.0, 'Residential area — Kasba Peth'],
    [18.5158, 73.8555, 25.0, 'Near school — slowing down'],
    [18.5162, 73.8562, 20.0, 'Back near AISSMS — loop complete'],
  ];

  int _waypointIndex = 0;
  double _waypointProgress = 0; // 0.0 to 1.0 between two waypoints

  void _startSimulation() {
    _simStep = 0;
    _simSpeed = 0;
    _waypointIndex = 0;
    _waypointProgress = 0;

    // Start at the first waypoint
    _simLat = (_demoWaypoints[0][0] as num).toDouble();
    _simLng = (_demoWaypoints[0][1] as num).toDouble();

    _simTimer = Timer.periodic(
      Duration(milliseconds: AppConstants.sensorUpdateMs),
      (timer) {
        _simStep++;
        final data = _generateSimulatedData();
        if (_controller != null && !_controller!.isClosed) {
          _controller!.add(data);
        }
      },
    );
  }

  SensorData _generateSimulatedData() {
    // Advance along the waypoint path
    final currentWP = _demoWaypoints[_waypointIndex];
    final nextIdx = (_waypointIndex + 1) % _demoWaypoints.length;
    final nextWP = _demoWaypoints[nextIdx];

    final startLat = (currentWP[0] as num).toDouble();
    final startLng = (currentWP[1] as num).toDouble();
    final endLat = (nextWP[0] as num).toDouble();
    final endLng = (nextWP[1] as num).toDouble();
    final targetSpeed = (nextWP[2] as num).toDouble();

    // Smoothly interpolate position between waypoints
    _waypointProgress += 0.05 + _random.nextDouble() * 0.02; // ~5-7% per tick

    if (_waypointProgress >= 1.0) {
      // Arrived at next waypoint — advance
      _waypointIndex = nextIdx;
      _waypointProgress = 0;
    }

    // Lerp position
    _simLat = startLat + (endLat - startLat) * _waypointProgress;
    _simLng = startLng + (endLng - startLng) * _waypointProgress;

    // Smoothly approach target speed
    final speedDiff = targetSpeed - _simSpeed;
    _simSpeed += speedDiff * 0.15 + (_random.nextDouble() - 0.5) * 2;
    _simSpeed = max(0, _simSpeed);

    // ── Scripted driving events (only after initial start-up) ──
    double accelY = 0;
    double gyroZ = 0;

    // Only trigger scripted events after first 10 seconds (allow smooth start)
    if (_simStep > 10) {
      // Harsh brake when decelerating sharply (e.g., entering market zone)
      if (speedDiff < -15 && _random.nextDouble() > 0.3) {
        accelY = -(AppConstants.harshBrakeThreshold + _random.nextDouble() * 3);
      }
      // Rash acceleration when speeding up a lot
      else if (speedDiff > 15 && _random.nextDouble() > 0.4) {
        accelY = AppConstants.rashAccelThreshold + _random.nextDouble() * 2;
      }
      // Random harsh brake every ~30 ticks
      else if (_simStep % 30 == 0 && _random.nextDouble() > 0.6) {
        accelY = -(AppConstants.harshBrakeThreshold + _random.nextDouble() * 2);
      }
    }

    // Sharp turns at waypoint transitions
    if (_waypointProgress < 0.1 && _random.nextDouble() > 0.5) {
      gyroZ = (AppConstants.sharpTurnThreshold + _random.nextDouble() * 1.5) *
          (_random.nextBool() ? 1 : -1);
    }

    return SensorData(
      speed: _simSpeed,
      latitude: _simLat,
      longitude: _simLng,
      accelerationX: (_random.nextDouble() - 0.5) * 2,
      accelerationY: accelY,
      accelerationZ: 9.8 + (_random.nextDouble() - 0.5) * 0.5,
      gyroscopeX: (_random.nextDouble() - 0.5) * 0.3,
      gyroscopeY: (_random.nextDouble() - 0.5) * 0.3,
      gyroscopeZ: gyroZ,
      isSimulated: true,
    );
  }
}
