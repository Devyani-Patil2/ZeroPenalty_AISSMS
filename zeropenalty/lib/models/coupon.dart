// lib/models/coupon.dart

enum CouponStatus { available, used, expired }

class Coupon {
  final String id;
  final String code;
  final String title;
  final String offer;
  final String location;
  final DateTime unlockedAt;
  final DateTime expiresAt;
  final CouponStatus status;
  final String badgeId;
  final String emoji;

  Coupon({
    required this.id,
    required this.code,
    required this.title,
    required this.offer,
    required this.location,
    required this.unlockedAt,
    required this.expiresAt,
    required this.status,
    required this.badgeId,
    required this.emoji,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'title': title,
      'offer': offer,
      'location': location,
      'unlocked_at': unlockedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'status': status.name,
      'badge_id': badgeId,
      'emoji': emoji,
    };
  }

  factory Coupon.fromMap(Map<String, dynamic> map) {
    return Coupon(
      id: map['id'],
      code: map['code'],
      title: map['title'],
      offer: map['offer'],
      location: map['location'],
      unlockedAt: DateTime.parse(map['unlocked_at']),
      expiresAt: DateTime.parse(map['expires_at']),
      status: CouponStatus.values.byName(map['status']),
      badgeId: map['badge_id'],
      emoji: map['emoji'] ?? '🎟️',
    );
  }
}
