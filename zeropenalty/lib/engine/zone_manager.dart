import 'dart:math';
import '../models/zone.dart';
import '../data/mock_zones.dart';

/// Zone manager — determines current risk zone from GPS coordinates
class ZoneManager {
  /// Get current zone based on lat/lng
  /// Returns the matching zone or a default LOW_RISK zone
  Zone getCurrentZone(double lat, double lng) {
    for (final zone in MockZones.zones) {
      if (_isPointInPolygon(lat, lng, zone.polygon)) {
        return zone;
      }
    }
    // Default: low risk highway
    return Zone(
      name: 'Open Road',
      risk: ZoneRisk.low,
      speedLimit: 60,
      polygon: [],
    );
  }

  /// Ray-casting point-in-polygon algorithm
  bool _isPointInPolygon(double lat, double lng, List<List<double>> polygon) {
    if (polygon.isEmpty) return false;

    int n = polygon.length;
    bool inside = false;

    double x = lat, y = lng;
    double x1 = polygon[0][0], y1 = polygon[0][1];

    for (int i = 1; i <= n; i++) {
      double x2 = polygon[i % n][0];
      double y2 = polygon[i % n][1];

      if (y > min(y1, y2)) {
        if (y <= max(y1, y2)) {
          if (x <= max(x1, x2)) {
            double xIntersection = (y - y1) * (x2 - x1) / (y2 - y1) + x1;
            if (x1 == x2 || x <= xIntersection) {
              inside = !inside;
            }
          }
        }
      }

      x1 = x2;
      y1 = y2;
    }

    return inside;
  }
}
