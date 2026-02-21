/// User profile model
class UserProfile {
  String name;
  int totalTrips;
  double lifetimeAvgScore;
  int totalPoints;
  String tier;
  String clusterLabel;

  // Achievement tracking
  double totalKm;
  int cleanBrakeTrips;
  int safeZonesCount;
  int noSpeedTrips;
  int hiScoreTrips;
  List<String> unlockedBadgeIds;

  UserProfile({
    this.name = 'Driver',
    this.totalTrips = 0,
    this.lifetimeAvgScore = 0.0,
    this.totalPoints = 0,
    this.tier = 'Improving',
    this.clusterLabel = 'Moderate',
    this.totalKm = 0.0,
    this.cleanBrakeTrips = 0,
    this.safeZonesCount = 0,
    this.noSpeedTrips = 0,
    this.hiScoreTrips = 0,
    this.unlockedBadgeIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'total_trips': totalTrips,
      'lifetime_avg_score': lifetimeAvgScore,
      'total_points': totalPoints,
      'tier': tier,
      'cluster_label': clusterLabel,
      'total_km': totalKm,
      'clean_brake_trips': cleanBrakeTrips,
      'safe_zones_count': safeZonesCount,
      'no_speed_trips': noSpeedTrips,
      'hi_score_trips': hiScoreTrips,
      'unlocked_badges': unlockedBadgeIds,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] ?? 'Driver',
      totalTrips: map['total_trips'] ?? 0,
      lifetimeAvgScore: (map['lifetime_avg_score'] ?? 0.0).toDouble(),
      totalPoints: map['total_points'] ?? 0,
      tier: map['tier'] ?? 'Improving',
      clusterLabel: map['cluster_label'] ?? 'Moderate',
      totalKm: (map['total_km'] ?? 0.0).toDouble(),
      cleanBrakeTrips: map['clean_brake_trips'] ?? 0,
      safeZonesCount: map['safe_zones_count'] ?? 0,
      noSpeedTrips: map['no_speed_trips'] ?? 0,
      hiScoreTrips: map['hi_score_trips'] ?? 0,
      unlockedBadgeIds: List<String>.from(map['unlocked_badges'] ?? []),
    );
  }
}
