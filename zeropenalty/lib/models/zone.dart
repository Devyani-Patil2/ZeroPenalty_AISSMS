/// Zone model for risk classification
class Zone {
  final String name;
  final ZoneRisk risk;
  final double speedLimit; // km/h
  final List<List<double>> polygon; // lat,lng pairs

  Zone({
    required this.name,
    required this.risk,
    required this.speedLimit,
    required this.polygon,
  });

  double get multiplier {
    switch (risk) {
      case ZoneRisk.high:
        return 2.0;
      case ZoneRisk.medium:
        return 1.5;
      case ZoneRisk.low:
        return 1.0;
    }
  }

  String get riskLabel {
    switch (risk) {
      case ZoneRisk.high:
        return 'HIGH RISK';
      case ZoneRisk.medium:
        return 'MEDIUM RISK';
      case ZoneRisk.low:
        return 'LOW RISK';
    }
  }

  String get typeString {
    switch (risk) {
      case ZoneRisk.high:
        return 'HIGH_RISK';
      case ZoneRisk.medium:
        return 'MEDIUM_RISK';
      case ZoneRisk.low:
        return 'LOW_RISK';
    }
  }
}

enum ZoneRisk { high, medium, low }
