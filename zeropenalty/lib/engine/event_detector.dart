import '../models/trip.dart';
import '../models/zone.dart';
import '../utils/constants.dart';
import 'sensor_service.dart';
import 'zone_manager.dart';

/// Detects driving events from sensor data
class EventDetector {
  final ZoneManager _zoneManager = ZoneManager();

  DateTime? _lastOverspeedTime;
  DateTime? _lastBrakeTime;
  DateTime? _lastTurnTime;
  DateTime? _lastAccelTime;

  /// Process sensor data and return detected event (or null)
  TripEvent? detect(SensorData data) {
    final zone = _zoneManager.getCurrentZone(data.latitude, data.longitude);
    final now = data.timestamp;

    // Check overspeed
    if (data.speed > zone.speedLimit) {
      if (_canAlert(_lastOverspeedTime, now)) {
        _lastOverspeedTime = now;
        return TripEvent(
          eventType: 'overspeed',
          timestamp: now,
          speed: data.speed,
          speedLimit: zone.speedLimit,
          zoneType: zone.typeString,
          severity: (data.speed - zone.speedLimit) / zone.speedLimit,
          latitude: data.latitude,
          longitude: data.longitude,
        );
      }
    }

    // Check harsh braking (negative Y acceleration)
    if (data.accelerationY < -AppConstants.harshBrakeThreshold) {
      if (_canAlert(_lastBrakeTime, now)) {
        _lastBrakeTime = now;
        return TripEvent(
          eventType: 'harsh_brake',
          timestamp: now,
          speed: data.speed,
          zoneType: zone.typeString,
          severity: data.accelerationY.abs() / 10.0,
          latitude: data.latitude,
          longitude: data.longitude,
        );
      }
    }

    // Check rash acceleration (positive Y acceleration)
    if (data.accelerationY > AppConstants.rashAccelThreshold) {
      if (_canAlert(_lastAccelTime, now)) {
        _lastAccelTime = now;
        return TripEvent(
          eventType: 'rash_accel',
          timestamp: now,
          speed: data.speed,
          zoneType: zone.typeString,
          severity: data.accelerationY / 8.0,
          latitude: data.latitude,
          longitude: data.longitude,
        );
      }
    }

    // Check sharp turn (Z-axis gyroscope)
    if (data.gyroscopeZ.abs() > AppConstants.sharpTurnThreshold) {
      if (_canAlert(_lastTurnTime, now)) {
        _lastTurnTime = now;
        return TripEvent(
          eventType: 'sharp_turn',
          timestamp: now,
          speed: data.speed,
          zoneType: zone.typeString,
          severity: data.gyroscopeZ.abs() / 4.0,
          latitude: data.latitude,
          longitude: data.longitude,
        );
      }
    }

    return null;
  }

  bool _canAlert(DateTime? lastTime, DateTime now) {
    if (lastTime == null) return true;
    return now.difference(lastTime).inMilliseconds >= AppConstants.alertCooldownMs;
  }

  void reset() {
    _lastOverspeedTime = null;
    _lastBrakeTime = null;
    _lastTurnTime = null;
    _lastAccelTime = null;
  }
}
