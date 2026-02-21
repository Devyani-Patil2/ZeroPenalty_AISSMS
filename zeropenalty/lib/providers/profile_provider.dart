import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/coupon.dart';
import '../data/database_helper.dart';
import '../engine/scoring_engine.dart';
import '../engine/achievement_service.dart';
import '../models/trip.dart';
import '../utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages user profile and rewards state
class ProfileProvider extends ChangeNotifier {
  UserProfile _profile = UserProfile();
  List<Coupon> _coupons = [];
  bool _isLoading = false;

  UserProfile get profile => _profile;
  List<Coupon> get coupons => _coupons;
  bool get isLoading => _isLoading;

  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('driver_name') ?? 'Driver';

    final totalTrips = await DatabaseHelper.getTripCount(AppConstants.driverId);
    final avgScore =
        await DatabaseHelper.getAverageScore(AppConstants.driverId);
    final totalPoints =
        await DatabaseHelper.getTotalPoints(AppConstants.driverId);

    // Achievement stats from prefs
    final totalKm = prefs.getDouble('total_km') ?? 0.0;
    final cleanBrakeTrips = prefs.getInt('clean_brake_trips') ?? 0;
    final safeZonesCount = prefs.getInt('safe_zones_count') ?? 0;
    final noSpeedTrips = prefs.getInt('no_speed_trips') ?? 0;
    final hiScoreTrips = prefs.getInt('hi_score_trips') ?? 0;
    final unlockedBadges = prefs.getStringList('unlocked_badges') ?? [];

    _profile = UserProfile(
      name: name,
      totalTrips: totalTrips,
      lifetimeAvgScore: avgScore,
      totalPoints: totalPoints,
      tier: ScoringEngine.getTier(avgScore),
      totalKm: totalKm,
      cleanBrakeTrips: cleanBrakeTrips,
      safeZonesCount: safeZonesCount,
      noSpeedTrips: noSpeedTrips,
      hiScoreTrips: hiScoreTrips,
      unlockedBadgeIds: unlockedBadges,
    );

    // Load coupons from DB
    final couponMaps = await DatabaseHelper.getCoupons();
    _coupons = couponMaps.map((m) => Coupon.fromMap(m)).toList();

    // Seed demo coupons if none exist
    if (_coupons.isEmpty) {
      final demoCoupons = [
        Coupon(
          id: 'demo_fuel',
          code: 'FUEL100',
          title: 'Fuel Voucher',
          offer: '₹100 off on fuel',
          location: 'HP Petrol Pump, Swargate',
          unlockedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          status: CouponStatus.available,
          badgeId: 'smooth_rider',
          emoji: '⛽',
        ),
        Coupon(
          id: 'demo_service',
          code: 'SERV750',
          title: 'Free Service',
          offer: 'Free vehicle health check',
          location: 'Mahindra Service Center, Pune',
          unlockedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 45)),
          status: CouponStatus.available,
          badgeId: 'zone_guardian',
          emoji: '🔧',
        ),
        Coupon(
          id: 'demo_parking',
          code: 'PARK300',
          title: 'Parking Pass',
          offer: '1 hour free parking',
          location: 'Phoenix Mall, Viman Nagar',
          unlockedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 15)),
          status: CouponStatus.available,
          badgeId: 'cruise_control',
          emoji: '🅿️',
        ),
        Coupon(
          id: 'demo_insurance',
          code: 'INSUR5',
          title: 'Insurance Discount',
          offer: '5% off next premium',
          location: 'ICICI Lombard, FC Road',
          unlockedAt: DateTime.now().subtract(const Duration(days: 10)),
          expiresAt: DateTime.now().add(const Duration(days: 60)),
          status: CouponStatus.available,
          badgeId: 'safe_driver',
          emoji: '🛡️',
        ),
      ];
      for (final c in demoCoupons) {
        await DatabaseHelper.insertCoupon(c.toMap());
      }
      _coupons = demoCoupons;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveAchievementStats(UserProfile p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('total_km', p.totalKm);
    await prefs.setInt('clean_brake_trips', p.cleanBrakeTrips);
    await prefs.setInt('safe_zones_count', p.safeZonesCount);
    await prefs.setInt('no_speed_trips', p.noSpeedTrips);
    await prefs.setInt('hi_score_trips', p.hiScoreTrips);
    await prefs.setStringList('unlocked_badges', p.unlockedBadgeIds);
    _profile = p;
    notifyListeners();
  }

  Future<void> addCoupon(Coupon coupon) async {
    await DatabaseHelper.insertCoupon(coupon.toMap());
    _coupons.insert(0, coupon);
    notifyListeners();
  }

  Future<void> useCoupon(String id) async {
    await DatabaseHelper.updateCouponStatus(id, CouponStatus.used.name);
    final idx = _coupons.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _coupons[idx] = Coupon(
        id: _coupons[idx].id,
        code: _coupons[idx].code,
        title: _coupons[idx].title,
        offer: _coupons[idx].offer,
        location: _coupons[idx].location,
        unlockedAt: _coupons[idx].unlockedAt,
        expiresAt: _coupons[idx].expiresAt,
        status: CouponStatus.used,
        badgeId: _coupons[idx].badgeId,
        emoji: _coupons[idx].emoji,
      );
      notifyListeners();
    }
  }

  Future<void> processTripStats(Trip trip) async {
    final p = _profile;

    // Update lifetime stats
    p.totalKm += trip.distanceKm;
    if (trip.harshBrakeCount == 0) p.cleanBrakeTrips++;
    if (trip.overspeedCount == 0) p.noSpeedTrips++;
    if (trip.localScore >= 80) p.hiScoreTrips++;
    // Safe zones: count total zones minus those with overspeed
    if (trip.overspeedCount == 0) {
      p.safeZonesCount += 2; // Demo bonus
    }

    // Check for new badges
    final newlyUnlocked = <String>[];
    for (final badge in AchievementService.badges) {
      if (!p.unlockedBadgeIds.contains(badge.id)) {
        if (badge.checkUnlocked(trip) || badge.checkUnlocked(p)) {
          newlyUnlocked.add(badge.id);
          p.unlockedBadgeIds.add(badge.id);

          // Generate and save coupon
          final coupon = AchievementService.generateCoupon(badge.id);
          await addCoupon(coupon);
        }
      }
    }

    await saveAchievementStats(p);
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
