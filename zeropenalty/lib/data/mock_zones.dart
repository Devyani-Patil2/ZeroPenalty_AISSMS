import '../models/zone.dart';

/// Pre-defined risk zones near Pune / AISSMS area
/// Each zone is a polygon defined by lat/lng coordinates
class MockZones {
  static final List<Zone> zones = [
    // HIGH RISK — AISSMS College Area (School Zone)
    Zone(
      name: 'AISSMS College Zone',
      risk: ZoneRisk.high,
      speedLimit: 25,
      polygon: [
        [18.5195, 73.8553],
        [18.5215, 73.8553],
        [18.5215, 73.8580],
        [18.5195, 73.8580],
      ],
    ),
    // HIGH RISK — Pune Station Area
    Zone(
      name: 'Pune Station Area',
      risk: ZoneRisk.high,
      speedLimit: 25,
      polygon: [
        [18.5280, 73.8740],
        [18.5320, 73.8740],
        [18.5320, 73.8790],
        [18.5280, 73.8790],
      ],
    ),
    // HIGH RISK — Swargate Hospital Zone
    Zone(
      name: 'Swargate Hospital Zone',
      risk: ZoneRisk.high,
      speedLimit: 25,
      polygon: [
        [18.5010, 73.8620],
        [18.5050, 73.8620],
        [18.5050, 73.8670],
        [18.5010, 73.8670],
      ],
    ),
    // MEDIUM RISK — Deccan Residential
    Zone(
      name: 'Deccan Residential',
      risk: ZoneRisk.medium,
      speedLimit: 40,
      polygon: [
        [18.5100, 73.8350],
        [18.5200, 73.8350],
        [18.5200, 73.8450],
        [18.5100, 73.8450],
      ],
    ),
    // MEDIUM RISK — Kothrud Residential
    Zone(
      name: 'Kothrud Residential',
      risk: ZoneRisk.medium,
      speedLimit: 40,
      polygon: [
        [18.5050, 73.8050],
        [18.5150, 73.8050],
        [18.5150, 73.8200],
        [18.5050, 73.8200],
      ],
    ),
    // MEDIUM RISK — Shivajinagar
    Zone(
      name: 'Shivajinagar Residential',
      risk: ZoneRisk.medium,
      speedLimit: 40,
      polygon: [
        [18.5280, 73.8400],
        [18.5380, 73.8400],
        [18.5380, 73.8500],
        [18.5280, 73.8500],
      ],
    ),
    // LOW RISK — Mumbai-Pune Expressway
    Zone(
      name: 'Mumbai-Pune Expressway',
      risk: ZoneRisk.low,
      speedLimit: 80,
      polygon: [
        [18.5400, 73.7800],
        [18.7500, 73.2000],
        [18.7600, 73.2100],
        [18.5500, 73.7900],
      ],
    ),
  ];
}
