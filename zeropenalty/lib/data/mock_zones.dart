import '../models/zone.dart';

/// Pre-defined zones near Pune / AISSMS area
/// Each zone is a polygon defined by lat/lng coordinates.
class MockZones {
  static final List<Zone> zones = [
    // School Zone (AISSMS area)
    Zone(
      name: 'School Zone',
      risk: ZoneRisk.high,
      speedLimit: 20,
      polygon: [
        [18.5155, 73.8555],
        [18.5180, 73.8555],
        [18.5180, 73.8580],
        [18.5155, 73.8580],
      ],
    ),
    // Market Zone (Laxmi Road area)
    Zone(
      name: 'Market Zone',
      risk: ZoneRisk.high,
      speedLimit: 20,
      polygon: [
        [18.5175, 73.8560],
        [18.5195, 73.8560],
        [18.5195, 73.8590],
        [18.5175, 73.8590],
      ],
    ),
    // Hospital Zone (Shaniwar Wada area)
    Zone(
      name: 'Hospital Zone',
      risk: ZoneRisk.medium,
      speedLimit: 25,
      polygon: [
        [18.5195, 73.8525],
        [18.5215, 73.8525],
        [18.5215, 73.8550],
        [18.5195, 73.8550],
      ],
    ),
    // School Zone (Bajirao Road area)
    Zone(
      name: 'School Zone',
      risk: ZoneRisk.high,
      speedLimit: 30,
      polygon: [
        [18.5140, 73.8560],
        [18.5165, 73.8560],
        [18.5165, 73.8580],
        [18.5140, 73.8580],
      ],
    ),
    // Market Zone (Pune Station area)
    Zone(
      name: 'Market Zone',
      risk: ZoneRisk.high,
      speedLimit: 25,
      polygon: [
        [18.5280, 73.8740],
        [18.5320, 73.8740],
        [18.5320, 73.8790],
        [18.5280, 73.8790],
      ],
    ),
    // Hospital Zone (Swargate area)
    Zone(
      name: 'Hospital Zone',
      risk: ZoneRisk.high,
      speedLimit: 25,
      polygon: [
        [18.5010, 73.8620],
        [18.5050, 73.8620],
        [18.5050, 73.8670],
        [18.5010, 73.8670],
      ],
    ),
    // Residential Area (Deccan area)
    Zone(
      name: 'Residential Area',
      risk: ZoneRisk.medium,
      speedLimit: 40,
      polygon: [
        [18.5100, 73.8350],
        [18.5200, 73.8350],
        [18.5200, 73.8450],
        [18.5100, 73.8450],
      ],
    ),
    // Residential Area (Kasba Peth area)
    Zone(
      name: 'Residential Area',
      risk: ZoneRisk.medium,
      speedLimit: 30,
      polygon: [
        [18.5145, 73.8540],
        [18.5160, 73.8540],
        [18.5160, 73.8560],
        [18.5145, 73.8560],
      ],
    ),
    // Highway
    Zone(
      name: 'Highway',
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
