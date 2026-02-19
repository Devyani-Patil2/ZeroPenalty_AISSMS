import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../data/database_helper.dart';
import '../engine/scoring_engine.dart';
import '../utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages user profile and rewards state
class ProfileProvider extends ChangeNotifier {
  UserProfile _profile = UserProfile();
  bool _isLoading = false;

  UserProfile get profile => _profile;
  bool get isLoading => _isLoading;

  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('driver_name') ?? 'Driver';

    final totalTrips = await DatabaseHelper.getTripCount(AppConstants.driverId);
    final avgScore = await DatabaseHelper.getAverageScore(AppConstants.driverId);
    final totalPoints = await DatabaseHelper.getTotalPoints(AppConstants.driverId);

    _profile = UserProfile(
      name: name,
      totalTrips: totalTrips,
      lifetimeAvgScore: avgScore,
      totalPoints: totalPoints,
      tier: ScoringEngine.getTier(avgScore),
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('driver_name', name);
    _profile.name = name;
    notifyListeners();
  }

  void refresh() {
    loadProfile();
  }
}
