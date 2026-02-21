import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

/// Sensor data packet
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
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Sensor service — handles GPS + Motion sensors with simulation mode
class SensorService {
  final bool useSimulation;
  StreamController<SensorData>? _controller;
  Timer? _simTimer;

  // Simulation state
  double _simLat = 18.5200;
  double _simLng = 73.8560;
  double _simSpeed = 0;
  final _random = Random();
  int _simStep = 0;

  SensorService({this.useSimulation = true});

  /// Start sensor stream
  Stream<SensorData> startSensors() {
    _controller = StreamController<SensorData>.broadcast();

    if (useSimulation) {
      _startSimulation();
    } else {
      _startRealSensors();
    }

    return _controller!.stream;
  }

  /// Stop sensors
  void stopSensors() {
    _simTimer?.cancel();
    _controller?.close();
    _controller = null;
  }

  /// Start real sensor inputs (GPS + accelerometer + gyroscope)
  void _startRealSensors() {
    // In a real Flutter app, you'd use:
    // geolocator.getPositionStream() for GPS
    // sensors_plus accelerometerEvents for acceleration
    // sensors_plus gyroscopeEvents for rotation
    // For now we fall back to simulation
    _startSimulation();
  }

  /// Simulation mode — generates realistic driving data
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
    // Simulate a realistic driving scenario with phases
    final phase = (_simStep ~/ 15) % 6;

    switch (phase) {
      case 0: // Accelerating in residential area
        _simSpeed = min(_simSpeed + 3 + _random.nextDouble() * 2, 45);
        _simLat += 0.00005;
        break;
      case 1: // Driving at moderate speed
        _simSpeed = 35 + _random.nextDouble() * 10;
        _simLat += 0.00008;
        _simLng += 0.00003;
        break;
      case 2: // Entering high-risk zone — school area
        _simSpeed = max(_simSpeed - 2, 20 + _random.nextDouble() * 15);
        _simLat = 18.5200 + _random.nextDouble() * 0.001;
        _simLng = 73.8560 + _random.nextDouble() * 0.001;
        break;
      case 3: // Highway — faster
        _simSpeed = 60 + _random.nextDouble() * 30;
        _simLat += 0.0002;
        _simLng -= 0.0001;
        break;
      case 4: // Sharp braking event
        _simSpeed = max(_simSpeed - 15, 5);
        break;
      case 5: // Recovery
        _simSpeed = 30 + _random.nextDouble() * 20;
        _simLat += 0.00006;
        break;
    }

    // Add noise
    _simSpeed = max(0, _simSpeed + (_random.nextDouble() - 0.5) * 3);

    // Generate realistic accelerometer/gyroscope data
    double accelY = 0;
    double gyroZ = 0;

    // Occasional harsh braking
    if (_simStep % 20 == 0 && _random.nextDouble() > 0.5) {
      accelY = -(AppConstants.harshBrakeThreshold + _random.nextDouble() * 3);
    }
    // Occasional rash acceleration
    else if (_simStep % 25 == 0 && _random.nextDouble() > 0.6) {
      accelY = AppConstants.rashAccelThreshold + _random.nextDouble() * 2;
    }
    // Occasional sharp turn
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
    );
  }
}
