import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../data/database_helper.dart';
import '../utils/constants.dart';

/// Manages trip history and analytics state
class HistoryProvider extends ChangeNotifier {
  List<Trip> _trips = [];
  bool _isLoading = false;

  List<Trip> get trips => _trips;
  bool get isLoading => _isLoading;

  List<double> get last5Scores {
    return _trips.take(5).map((t) => t.mlScore ?? t.localScore).toList();
  }

  double get weeklyAvg {
    final recent = _trips.take(7).toList();
    if (recent.isEmpty) return 0;
    final sum = recent.fold<double>(0, (s, t) => s + (t.mlScore ?? t.localScore));
    return sum / recent.length;
  }

  double get improvementPct {
    if (_trips.length < 4) return 0;
    final half = _trips.length ~/ 2;
    final recentAvg = _trips.take(half).fold<double>(0, (s, t) => s + (t.mlScore ?? t.localScore)) / half;
    final olderAvg = _trips.skip(half).fold<double>(0, (s, t) => s + (t.mlScore ?? t.localScore)) / (_trips.length - half);
    return olderAvg > 0 ? ((recentAvg - olderAvg) / olderAvg) * 100 : 0;
  }

  double get lifetimeAvg {
    if (_trips.isEmpty) return 0;
    return _trips.fold<double>(0, (s, t) => s + (t.mlScore ?? t.localScore)) / _trips.length;
  }

  Future<void> loadTrips() async {
    _isLoading = true;
    notifyListeners();

    _trips = await DatabaseHelper.getTrips(AppConstants.driverId);

    _isLoading = false;
    notifyListeners();
  }

  void addTrip(Trip trip) {
    _trips.insert(0, trip);
    notifyListeners();
  }
}
