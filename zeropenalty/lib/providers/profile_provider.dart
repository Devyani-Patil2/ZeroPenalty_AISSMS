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
  UserProfile _profile = UserProfile(name: 'Safe Driver');
  List<Coupon> _coupons = [];
  bool _isLoading = true;
  Coupon? _lastEarnedCoupon;

  UserProfile get profile => _profile;
  List<Coupon> get coupons => _coupons;
  bool get isLoading => _isLoading;
  Coupon? get lastEarnedCoupon => _lastEarnedCoupon;

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

    // Load coupons from DB with error handling
    try {
      final couponMaps = await DatabaseHelper.getCoupons();
      _coupons = couponMaps.map((m) => Coupon.fromMap(m)).toList();

      // Seed all rewards as LOCKED by default (roadmap style)
      if (_coupons.isEmpty) {
        final List<Coupon> allRewards = [
          AchievementService.generateCoupon('welcome',
              status: CouponStatus.available),
          AchievementService.generateCoupon('silver_score',
              status: CouponStatus.locked),
          AchievementService.generateCoupon('gold_score',
              status: CouponStatus.locked),
          AchievementService.generateCoupon('smooth',
              status: CouponStatus.locked),
          AchievementService.generateCoupon('take_brake',
              status: CouponStatus.locked),
          AchievementService.generateCoupon('zone_grd',
              status: CouponStatus.locked),
          AchievementService.generateCoupon('no_spd',
              status: CouponStatus.locked),
          AchievementService.generateCoupon('cruise',
              status: CouponStatus.locked),
        ];
        for (final c in allRewards) {
          await DatabaseHelper.insertCoupon(c.toMap());
        }
        _coupons = allRewards;
      }
    } catch (e) {
      debugPrint('Failed to load/seed coupons: $e');
      _coupons = []; // Fallback to empty if DB fails
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
      final old = _coupons[idx];
      _coupons[idx] = Coupon(
        id: old.id,
        code: old.code,
        title: old.title,
        offer: old.offer,
        description: old.description,
        location: old.location,
        unlockedAt: old.unlockedAt,
        expiresAt: old.expiresAt,
        status: CouponStatus.used,
        badgeId: old.badgeId,
        emoji: old.emoji,
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

    // safe zones: demo bonus
    if (trip.overspeedCount == 0) {
      p.safeZonesCount += 2;
    }

    // Dynamic Unlocking based on trip score
    _lastEarnedCoupon = null;
    final tripScore = trip.mlScore ?? trip.localScore;

    if (tripScore >= 85) {
      final silverIdx = _coupons.indexWhere((c) =>
          c.badgeId == 'silver_score' && c.status == CouponStatus.locked);
      if (silverIdx != -1) {
        final unlocked =
            _coupons[silverIdx].copyWith(status: CouponStatus.available);
        _coupons[silverIdx] = unlocked;
        await DatabaseHelper.insertCoupon(
            unlocked.toMap()); // OVERWRITE/UPDATE logic needed
        _lastEarnedCoupon = unlocked;
      }
    }

    if (tripScore >= 95) {
      final goldIdx = _coupons.indexWhere(
          (c) => c.badgeId == 'gold_score' && c.status == CouponStatus.locked);
      if (goldIdx != -1) {
        final unlocked =
            _coupons[goldIdx].copyWith(status: CouponStatus.available);
        _coupons[goldIdx] = unlocked;
        await DatabaseHelper.insertCoupon(unlocked.toMap());
        _lastEarnedCoupon = unlocked;
      }
    }

    // Check for new badges
    for (final badge in AchievementService.badges) {
      if (!p.unlockedBadgeIds.contains(badge.id)) {
        if (badge.checkUnlocked(trip) || badge.checkUnlocked(p)) {
          p.unlockedBadgeIds.add(badge.id);

          // Find the existing locked coupon for this badge and unlock it
          final badgeIdx = _coupons.indexWhere(
              (c) => c.badgeId == badge.id && c.status == CouponStatus.locked);
          if (badgeIdx != -1) {
            final unlocked =
                _coupons[badgeIdx].copyWith(status: CouponStatus.available);
            _coupons[badgeIdx] = unlocked;
            await DatabaseHelper.insertCoupon(unlocked.toMap());
            _lastEarnedCoupon = unlocked;
          } else {
            // Fallback if not seeded for some reason
            final badgeCoupon = AchievementService.generateCoupon(badge.id,
                status: CouponStatus.available);
            await addCoupon(badgeCoupon);
            _lastEarnedCoupon = badgeCoupon;
          }
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
