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
class SensorService {
  final bool useSimulation;
  StreamController<SensorData>? _controller;

  // Real sensor subscriptions
  StreamSubscription<Position>? _geoSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _realEmitTimer;

  // Latest real readings
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
  double _simLat = 18.5220;
  double _simLng = 73.8557;
  double _simSpeed = 0;
  final _random = Random();

  SensorService({this.useSimulation = true});

  Future<Stream<SensorData>> startSensors() async {
    _controller = StreamController<SensorData>.broadcast();
    if (useSimulation) {
      debugPrint('[SensorService] 🎮 Starting DEMO mode');
      _startSimulation();
    } else {
      debugPrint('[SensorService] 📡 Starting LIVE mode — requesting GPS...');
      await _startRealSensors();
    }
    return _controller!.stream;
  }

  void stopSensors() {
    _simTimer?.cancel();
    _realEmitTimer?.cancel();
    _geoSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _controller?.close();
    _controller = null;
  }

  Future<void> _startRealSensors() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _controller?.close();
      throw LocationNotAvailableException('Location services are turned OFF.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _controller?.close();
      throw LocationNotAvailableException('Location permission denied.');
    }

    _geoSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen((Position pos) {
      _realLat = pos.latitude;
      _realLng = pos.longitude;
      _realSpeed = (pos.speed >= 0) ? pos.speed * 3.6 : 0;
    });

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
  // DEMO / SIMULATION MODE — High-Precision Road Path (Pune Loop)
  // ═══════════════════════════════════════════════════════════════════

  // These points are carefully aligned to stay on the road (Shivaji Rd / Bajirao Rd).
  static const List<List<dynamic>> _demoWaypoints = [
    // 1. South on Shivaji Road (Straight Vertical)
    [18.5220, 73.8557, 30.0],
    [18.5210, 73.8557, 35.0],
    [18.5200, 73.8557, 35.0],
    [18.5190, 73.8557, 40.0],
    [18.5180, 73.8557, 50.0],
    [18.5170, 73.8557, 60.0],
    [18.5160, 73.8557, 70.0], // OVERSPEED

    // 2. Turn Right onto Gadgil Rd
    [18.5158, 73.8557, 25.0],
    [18.5158, 73.8545, 20.0],
    [18.5158, 73.8533, 25.0],

    // 3. North on Bajirao Road (Straight Vertical)
    [18.5170, 73.8533, 40.0],
    [18.5180, 73.8533, 50.0],
    [18.5190, 73.8533, 45.0],
    [18.5200, 73.8533, 30.0],

    // 4. Around Shaniwar Wada
    [18.5200, 73.8520, 20.0],
    [18.5210, 73.8512, 20.0],
    [18.5220, 73.8520, 25.0],
    [18.5220, 73.8540, 30.0],
    [18.5220, 73.8557, 30.0],
  ];

  int _waypointIndex = 0;
  double _waypointProgress = 0;
  double _distanceInSegment = 0;

  void _startSimulation() {
    _simSpeed = 5; // Start with a bit of speed so it moves immediately
    _waypointIndex = 0;
    _waypointProgress = 0;
    _distanceInSegment = 0;
    _simLat = (_demoWaypoints[0][0] as num).toDouble();
    _simLng = (_demoWaypoints[0][1] as num).toDouble();

    _simTimer = Timer.periodic(
      Duration(milliseconds: AppConstants.sensorUpdateMs),
      (timer) {
        final data = _generateSimulatedData();
        if (_controller != null && !_controller!.isClosed) {
          _controller!.add(data);
        }
      },
    );
  }

  SensorData _generateSimulatedData() {
    final currentWP = _demoWaypoints[_waypointIndex];
    final nextIdx = (_waypointIndex + 1) % _demoWaypoints.length;
    final nextWP = _demoWaypoints[nextIdx];

    final startLat = (currentWP[0] as num).toDouble();
    final startLng = (currentWP[1] as num).toDouble();
    final endLat = (nextWP[0] as num).toDouble();
    final endLng = (nextWP[1] as num).toDouble();
    final targetSpeed = (nextWP[2] as num).toDouble();

    final dLat = endLat - startLat;
    final dLng = endLng - startLng;
    final totalDist = sqrt(dLat * dLat + dLng * dLng);

    // Fix: Use the actual sensorUpdateMs (usually 1000ms) for the math
    final secondsPerUpdate = AppConstants.sensorUpdateMs / 1000.0;
    final degPerUpdate = (_simSpeed / 3600.0) * secondsPerUpdate / 111.0;

    if (totalDist > 0) {
      _distanceInSegment += degPerUpdate;
      _waypointProgress = (_distanceInSegment / totalDist).clamp(0.0, 1.0);
      if (_waypointProgress >= 1.0) {
        _waypointIndex = nextIdx;
        _waypointProgress = 0;
        _distanceInSegment = 0;
      }
    } else {
      _waypointIndex = nextIdx;
      _waypointProgress = 0;
      _distanceInSegment = 0;
    }

    _simLat = startLat + dLat * _waypointProgress;
    _simLng = startLng + dLng * _waypointProgress;

    final speedDiff = targetSpeed - _simSpeed;
    _simSpeed += speedDiff * 0.15 + (_random.nextDouble() - 0.5);
    _simSpeed = max(5, _simSpeed); // Minimum speed to keep visible movement

    return SensorData(
      speed: _simSpeed,
      latitude: _simLat,
      longitude: _simLng,
      accelerationX: (_random.nextDouble() - 0.5) * 1.5,
      accelerationY: ((speedDiff > 5) ? 2.5 : ((speedDiff < -5) ? -3.5 : 0)) +
          (_random.nextDouble() - 0.5),
      accelerationZ: 9.8 + (_random.nextDouble() - 0.5) * 0.5,
      isSimulated: true,
    );
  }
}
