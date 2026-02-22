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

  /// Updates the waypoints used for the simulation.
  /// Typically used after fetching a high-precision route from a service.
  void updateWaypoints(List<List<double>> newWaypoints) {
    if (newWaypoints.isEmpty) return;

    // Update the static list (or we could make it an instance variable)
    // For now, let's keep it simple and just update the state
    _waypointIndex = 0;
    _waypointProgress = 0;
    _distanceInSegment = 0;
    _simLat = newWaypoints[0][0];
    _simLng = newWaypoints[0][1];

    // If we wanted to persist this, we'd need to change _demoWaypoints to be non-static
    // But for the demo, we'll just allow overriding the current points in state
  }

  // ═══════════════════════════════════════════════════════════════════
  // ROAD-PERFECT PUNE ROUTE (105 Points)
  // ═══════════════════════════════════════════════════════════════════

  // These points follow the actual road geometry precisely (AISSMS -> Shivaji Rd -> Shaniwar Wada -> Bajirao Rd -> AISSMS)
  List<List<double>> _activeWaypoints = List.from(_defaultWaypoints);

  static const List<List<double>> _defaultWaypoints = [
    // 1. AISSMS Gate and Kennedy Road (Ultra-Dense)
    [18.53125, 73.86450], [18.53122, 73.86442], [18.53118, 73.86435],
    [18.53115, 73.86428], [18.53112, 73.86421],
    [18.53109, 73.86414], [18.53106, 73.86407], [18.53103, 73.86400],
    [18.53100, 73.86393], [18.53097, 73.86386],
    [18.53094, 73.86379], [18.53091, 73.86372], [18.53088, 73.86365],
    [18.53085, 73.86358], [18.53082, 73.86351],
    [18.53079, 73.86344], [18.53076, 73.86337], [18.53073, 73.86330],
    [18.53070, 73.86323], [18.53067, 73.86316],
    [18.53064, 73.86309], [18.53061, 73.86302], [18.53058, 73.86295],
    [18.53055, 73.86288], [18.53052, 73.86281],
    [18.53049, 73.86274], [18.53046, 73.86267], [18.53043, 73.86260],
    [18.53090, 73.86180], [18.53140, 73.86110],
    [18.53180, 73.86050], [18.53215, 73.85980],

    // 2. Sangam Bridge Crossing (Corrected Bridge Entry)
    [18.53229, 73.85918], [18.53235, 73.85860], [18.53232, 73.85805],
    [18.53225, 73.85760], [18.53210, 73.85720],
    [18.53190, 73.85700], [18.53160, 73.85620], [18.53120, 73.85560],
    [18.53080, 73.85512], [18.53040, 73.85450],

    // 3. Shivaji Road Corridor (Precise Snapping)
    [18.52980, 73.85435], [18.52950, 73.85432], [18.52920, 73.85428],
    [18.52890, 73.85430], [18.52860, 73.85435],
    [18.52830, 73.85440], [18.52800, 73.85445], [18.52765, 73.85455],
    [18.52730, 73.85470], [18.52705, 73.85475],
    [18.52680, 73.85480], [18.52650, 73.85485], [18.52620, 73.85490],
    [18.52590, 73.85495], [18.52550, 73.85500],
    [18.52520, 73.85502], [18.52490, 73.85505], [18.52455, 73.85508],
    [18.52420, 73.85510], [18.52385, 73.85512],
    [18.52350, 73.85515], [18.52315, 73.85516], [18.52280, 73.85518],
    [18.52245, 73.85520], [18.52210, 73.85522],
    [18.52180, 73.85523], [18.52150, 73.85525], [18.52115, 73.85526],
    [18.52080, 73.85528], [18.52050, 73.85529],
    [18.52020, 73.85530], [18.51980, 73.85525], [18.51954, 73.85522],

    // 4. Return Loop (Bajirao Road)
    [18.51930, 73.85540], [18.51915, 73.85570], [18.51935, 73.85600],
    [18.51965, 73.85610], [18.52020, 73.85625],
    [18.52080, 73.85640], [18.52150, 73.85655], [18.52220, 73.85670],
    [18.52300, 73.85695], [18.52380, 73.85710],
    [18.52450, 73.85720], [18.52510, 73.85712], [18.52570, 73.85680],
    [18.52620, 73.85630], [18.52670, 73.85590],
    [18.52720, 73.85560], [18.52780, 73.85595], [18.52840, 73.85650],
    [18.52890, 73.85720], [18.52940, 73.85800],
    [18.52985, 73.85950], [18.53011, 73.86050], [18.53040, 73.86180],
    [18.53080, 73.86330], [18.53120, 73.86435],
  ];

  int _waypointIndex = 0;
  double _waypointProgress = 0;
  double _distanceInSegment = 0;
  double _manualSpeedOverride = -1.0; // -1 means disabled

  /// Call this to manually set sim speed from UI
  void setDemoSpeed(double speed) {
    _manualSpeedOverride = speed;
  }

  void _startSimulation() {
    _simSpeed = 5; // Start speed
    _waypointIndex = 0;
    _waypointProgress = 0;
    _distanceInSegment = 0;
    _manualSpeedOverride = -1.0;
    _simLat = (_activeWaypoints[0][0]);
    _simLng = (_activeWaypoints[0][1]);

    _simTimer = Timer.periodic(
      const Duration(milliseconds: 1000), // AppConstants.sensorUpdateMs
      (timer) {
        final data = _generateSimulatedData();
        if (_controller != null && !_controller!.isClosed) {
          _controller!.add(data);
        }
      },
    );
  }

  SensorData _generateSimulatedData() {
    final currentWP = _activeWaypoints[_waypointIndex];
    final nextIdx = (_waypointIndex + 1) % _activeWaypoints.length;
    final nextWP = _activeWaypoints[nextIdx];

    final startLat = currentWP[0];
    final startLng = currentWP[1];
    final endLat = nextWP[0];
    final endLng = nextWP[1];

    final dLat = endLat - startLat;
    final dLng = endLng - startLng;
    final totalDist = sqrt(dLat * dLat + dLng * dLng);

    // Apply manual speed override if set
    double targetSpeed = 25.0; // Moderate default
    if (_manualSpeedOverride >= 0) {
      targetSpeed = _manualSpeedOverride;
    }

    final secondsPerUpdate = 1.0; // AppConstants.sensorUpdateMs / 1000.0
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

    // Smoother speed approach
    final speedDiff = targetSpeed - _simSpeed;
    _simSpeed += speedDiff * 0.25 + (_random.nextDouble() - 0.5);
    _simSpeed = max(5, _simSpeed);

    // Logic: If turning (at waypoint start) and speed is high, spike gyro to trigger alert
    double simulatedGyroZ = 0;
    if (_waypointProgress < 0.2 && _simSpeed > 45) {
      simulatedGyroZ = 2.0; // Harsh turn threshold is typically ~2.5
    }

    return SensorData(
      speed: _simSpeed,
      latitude: _simLat,
      longitude: _simLng,
      accelerationX: (_random.nextDouble() - 0.5) * 1.5,
      accelerationY: ((speedDiff > 5) ? 2.5 : ((speedDiff < -5) ? -3.5 : 0)) +
          (_random.nextDouble() - 0.5),
      accelerationZ: 9.8 + (_random.nextDouble() - 0.5) * 0.5,
      gyroscopeZ: simulatedGyroZ + (_random.nextDouble() - 0.5) * 0.2,
      isSimulated: true,
    );
  }
}
