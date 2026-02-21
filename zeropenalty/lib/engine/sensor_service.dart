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
  // DEMO / SIMULATION MODE
  // ═══════════════════════════════════════════════════════════════════

  void _startSimulation() {
    _simStep = 0;
    _simSpeed = 0;

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
    final phase = (_simStep ~/ 15) % 6;

    switch (phase) {
      case 0:
        _simSpeed = min(_simSpeed + 3 + _random.nextDouble() * 2, 45);
        _simLat += 0.00005;
        break;
      case 1:
        _simSpeed = 35 + _random.nextDouble() * 10;
        _simLat += 0.00008;
        _simLng += 0.00003;
        break;
      case 2:
        _simSpeed = max(_simSpeed - 2, 20 + _random.nextDouble() * 15);
        _simLat = 18.5200 + _random.nextDouble() * 0.001;
        _simLng = 73.8560 + _random.nextDouble() * 0.001;
        break;
      case 3:
        _simSpeed = 60 + _random.nextDouble() * 30;
        _simLat += 0.0002;
        _simLng -= 0.0001;
        break;
      case 4:
        _simSpeed = max(_simSpeed - 15, 5);
        break;
      case 5:
        _simSpeed = 30 + _random.nextDouble() * 20;
        _simLat += 0.00006;
        break;
    }

    _simSpeed = max(0, _simSpeed + (_random.nextDouble() - 0.5) * 3);

    double accelY = 0;
    double gyroZ = 0;

    if (_simStep % 20 == 0 && _random.nextDouble() > 0.5) {
      accelY = -(AppConstants.harshBrakeThreshold + _random.nextDouble() * 3);
    } else if (_simStep % 25 == 0 && _random.nextDouble() > 0.6) {
      accelY = AppConstants.rashAccelThreshold + _random.nextDouble() * 2;
    }
    if (_simStep % 18 == 0 && _random.nextDouble() > 0.5) {
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
