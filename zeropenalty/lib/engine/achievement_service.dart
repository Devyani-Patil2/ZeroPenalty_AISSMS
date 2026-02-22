import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../models/coupon.dart';
import '../models/user_profile.dart';
import '../models/trip.dart';
import 'dart:math';

class AchievementService {
  static final List<Achievement> badges = [
    Achievement(
      id: 'smooth',
      emoji: '🕊️',
      bgColor: const Color(0xFF1A3A5C),
      strokeColor: const Color(0xFF00C6FF),
      name: 'Smooth Rider',
      description: 'Complete a trip with zero hard braking events',
      checkUnlocked: (stats) =>
          (stats is Trip) ? stats.harshBrakeCount == 0 : false,
      getProgress: (stats) =>
          (stats is Trip && stats.harshBrakeCount == 0) ? 1.0 : 0.0,
    ),
    Achievement(
      id: 'take_brake',
      emoji: '🛑',
      bgColor: const Color(0xFF1A3320),
      strokeColor: const Color(0xFF00E676),
      name: 'Take a Brake',
      description: 'Complete 15 trips with zero hard braking events',
      checkUnlocked: (stats) =>
          (stats is UserProfile) ? stats.cleanBrakeTrips >= 15 : false,
      getProgress: (stats) =>
          (stats is UserProfile) ? min(1.0, stats.cleanBrakeTrips / 15.0) : 0.0,
    ),
    Achievement(
      id: 'zone_grd',
      emoji: '🏫',
      bgColor: const Color(0xFF332200),
      strokeColor: const Color(0xFFFBC02D),
      name: 'Zone Guardian',
      description: 'Pass 10 risk zones safely without speeding',
      checkUnlocked: (stats) =>
          (stats is UserProfile) ? stats.safeZonesCount >= 10 : false,
      getProgress: (stats) =>
          (stats is UserProfile) ? min(1.0, stats.safeZonesCount / 10.0) : 0.0,
    ),
    Achievement(
      id: 'no_spd',
      emoji: '🐢',
      bgColor: const Color(0xFF2A1500),
      strokeColor: const Color(0xFFFF6D00),
      name: 'No Need for Speed',
      description: 'Complete 5 trips with zero speeding events',
      checkUnlocked: (stats) =>
          (stats is UserProfile) ? stats.noSpeedTrips >= 5 : false,
      getProgress: (stats) =>
          (stats is UserProfile) ? min(1.0, stats.noSpeedTrips / 5.0) : 0.0,
    ),
    Achievement(
      id: 'cruise',
      emoji: '🚗',
      bgColor: const Color(0xFF001A2E),
      strokeColor: const Color(0xFF00C6FF),
      name: 'Cruise Control',
      description: 'Drive a total of 20 km across all trips',
      checkUnlocked: (stats) =>
          (stats is UserProfile) ? stats.totalKm >= 20 : false,
      getProgress: (stats) =>
          (stats is UserProfile) ? min(1.0, stats.totalKm / 20.0) : 0.0,
    ),
    Achievement(
      id: 'opt_spd',
      emoji: '⚡',
      bgColor: const Color(0xFF332800),
      strokeColor: const Color(0xFFFFC400),
      name: 'Optimum Speeder',
      description: 'Keep speed between 30–50 km/h for 80%+ of a trip',
      checkUnlocked: (stats) => (stats is Trip)
          ? stats.avgSpeed >= 30 && stats.avgSpeed <= 50
          : false,
      getProgress: (stats) =>
          (stats is Trip && stats.avgSpeed >= 30 && stats.avgSpeed <= 50)
              ? 1.0
              : 0.0,
    ),
    Achievement(
      id: 'money',
      emoji: '💰',
      bgColor: const Color(0xFF0D2A12),
      strokeColor: const Color(0xFF00E676),
      name: 'Money Maker',
      description: 'Earn a total of 5000 reward points',
      checkUnlocked: (stats) =>
          (stats is UserProfile) ? stats.totalPoints >= 5000 : false,
      getProgress: (stats) =>
          (stats is UserProfile) ? min(1.0, stats.totalPoints / 5000.0) : 0.0,
    ),
    Achievement(
      id: 'explorer',
      emoji: '🗺️',
      bgColor: const Color(0xFF0D1E33),
      strokeColor: const Color(0xFF00C6FF),
      name: 'Pune Explorer',
      description: 'Complete 10 different trips in Pune',
      checkUnlocked: (stats) =>
          (stats is UserProfile) ? stats.totalTrips >= 10 : false,
      getProgress: (stats) =>
          (stats is UserProfile) ? min(1.0, stats.totalTrips / 10.0) : 0.0,
    ),
    Achievement(
      id: 'safe_drv',
      emoji: '🦺',
      bgColor: const Color(0xFF1A0D2E),
      strokeColor: const Color(0xFF9C27B0),
      name: 'Safe Driver',
      description: 'Complete 3 trips with a score of 80 or above',
      checkUnlocked: (stats) =>
          (stats is UserProfile) ? stats.hiScoreTrips >= 3 : false,
      getProgress: (stats) =>
          (stats is UserProfile) ? min(1.0, stats.hiScoreTrips / 3.0) : 0.0,
    ),
  ];

  static Map<String, dynamic> couponData = {
    'smooth': {
      'title': '5% OFF FUEL',
      'offer': '5% discount on next fuel fill',
      'description': 'Unlocked for zero hard braking events',
      'loc': 'Any HP/Indian Oil pump'
    },
    'take_brake': {
      'title': 'FREE BRAKE INSPECTION',
      'offer': 'Free brake check at authorized centers',
      'description': 'Complete 15 trips with zero hard braking',
      'loc': 'Bajaj Auto Service'
    },
    'zone_grd': {
      'title': '2 HRS FREE PARKING',
      'offer': 'Free 2-hour parking at SmartPark',
      'description': 'Pass 10 risk zones safely',
      'loc': 'PMRDA Parking Lots'
    },
    'no_spd': {
      'title': '₹50 OFF FUEL',
      'offer': '₹50 off on fuel above ₹500',
      'description': 'Complete 5 trips with zero speeding',
      'loc': 'Any petrol pump'
    },
    'cruise': {
      'title': 'FREE TYRE CHECK',
      'offer': 'Free pressure & air check',
      'description': 'Drive a total of 20 km safely',
      'loc': 'Authorized centers'
    },
    'opt_spd': {
      'title': '10% OFF SERVICE',
      'offer': '10% off next full vehicle service',
      'description': 'Keep speed between 30–50 km/h for 80% trip',
      'loc': 'Partner garages'
    },
    'money': {
      'title': '₹100 OFF FUEL',
      'offer': '₹100 off on fuel above ₹1000',
      'description': 'Earn 5000 total reward points',
      'loc': 'Any petrol pump'
    },
    'explorer': {
      'title': 'FREE CAR WASH',
      'offer': 'Free car wash at partner stations',
      'description': 'Complete 10 different trips in Pune',
      'loc': 'WashKing / ShineAuto'
    },
    'safe_drv': {
      'title': 'FREE OIL CHECK',
      'offer': 'Free oil level & coolant check',
      'description': 'Complete 3 trips with score 80+',
      'loc': 'Authorized centers'
    },
    'gold_score': {
      'title': 'STARBUCKS 20% OFF',
      'offer': 'Premium reward for 95+ safety score',
      'description': 'Achieve a safety score of 95+ in a single trip',
      'loc': 'Starbucks, Pavilion Mall',
      'emoji': '☕'
    },
    'silver_score': {
      'title': 'AMAZON ₹100 OFF',
      'offer': 'Reward for 85+ safety score',
      'description': 'Achieve a safety score of 85+ in a single trip',
      'loc': 'Redeem Online',
      'emoji': '🛒'
    },
    'welcome': {
      'title': 'WELCOME REWARD',
      'offer': '10% off on your next visit',
      'description': 'Unlocked for joining ZeroPenalty!',
      'loc': 'Partner Merchants',
      'emoji': '🎁'
    },
  };

  static Coupon generateCoupon(String badgeId,
      {CouponStatus status = CouponStatus.locked}) {
    final data = couponData[badgeId];
    final now = DateTime.now();
    return Coupon(
      id: 'CPN-${Random().nextInt(99999)}',
      code: 'ZP-${Random().nextInt(9999).toString().padLeft(4, '0')}',
      title: data['title'],
      offer: data['offer'],
      description:
          data['description'] ?? 'Unlock this achievement to earn the reward',
      location: data['loc'],
      unlockedAt: now,
      expiresAt: now.add(const Duration(days: 30)),
      status: status,
      badgeId: badgeId,
      emoji: data['emoji'] ?? badges.firstWhere((b) => b.id == badgeId).emoji,
    );
  }

  static Coupon generateQuickCoupon({
    required String id,
    required String title,
    required String offer,
    required String description,
    required String code,
    required String emoji,
    CouponStatus status = CouponStatus.locked,
  }) {
    final now = DateTime.now();
    return Coupon(
      id: id,
      code: code,
      title: title,
      offer: offer,
      description: description,
      location: 'ZeroPenalty Rewards',
      unlockedAt: now,
      expiresAt: now.add(const Duration(days: 30)),
      status: status,
      badgeId: 'performance',
      emoji: emoji,
    );
  }
}
