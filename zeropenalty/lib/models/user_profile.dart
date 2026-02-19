/// User profile model
class UserProfile {
  String name;
  int totalTrips;
  double lifetimeAvgScore;
  int totalPoints;
  String tier;
  String clusterLabel;

  UserProfile({
    this.name = 'Driver',
    this.totalTrips = 0,
    this.lifetimeAvgScore = 0.0,
    this.totalPoints = 0,
    this.tier = 'Improving',
    this.clusterLabel = 'Moderate',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'total_trips': totalTrips,
      'lifetime_avg_score': lifetimeAvgScore,
      'total_points': totalPoints,
      'tier': tier,
      'cluster_label': clusterLabel,
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
    );
  }
}
