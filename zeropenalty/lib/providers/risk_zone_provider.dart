import 'package:flutter/material.dart';
import '../models/risk_zone.dart';
import '../services/risk_zone_service.dart';

/// State management for the Risk Zone Intelligence screen.
class RiskZoneProvider extends ChangeNotifier {
  final RiskZoneService _service = RiskZoneService();

  RiskDetectionResult? _result;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _timeRisk = {};

  // Getters
  RiskDetectionResult? get result => _result;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasResult => _result != null;
  Map<String, dynamic> get timeRisk => _timeRisk;
  List<RiskZone> get allZones => _service.getAllZones();

  RiskZoneProvider() {
    refreshTimeRisk();
  }

  /// Detect zone for given coordinates + speed
  Future<void> detect(double lat, double lng, double speed) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _result = await _service.detectZone(lat, lng, speed);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh time-based risk factors
  void refreshTimeRisk() {
    _timeRisk = RiskZoneService.getTimeRisk();
    notifyListeners();
  }

  /// Load a preset and detect
  Future<void> loadPreset(int index) async {
    final p = RiskZoneService.presets[index];
    await detect(
      (p['lat'] as num).toDouble(),
      (p['lng'] as num).toDouble(),
      (p['speed'] as num).toDouble(),
    );
  }

  /// Clear current result
  void clear() {
    _result = null;
    _error = null;
    notifyListeners();
  }
}
