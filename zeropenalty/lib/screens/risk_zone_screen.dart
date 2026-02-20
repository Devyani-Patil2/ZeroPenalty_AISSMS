import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/risk_zone.dart';
import '../services/risk_zone_service.dart';
import '../utils/constants.dart';

class RiskZoneScreen extends StatefulWidget {
  const RiskZoneScreen({super.key});

  @override
  State<RiskZoneScreen> createState() => _RiskZoneScreenState();
}

class _RiskZoneScreenState extends State<RiskZoneScreen> {
  final MapController _mapController = MapController();
  final RiskZoneService _service = RiskZoneService();
  FlutterTts? _tts;

  // All 10 zones
  late final List<RiskZone> _zones;

  // Live GPS
  LatLng? _userPosition;
  StreamSubscription<Position>? _geoSub;
  bool _gpsAvailable = false;

  // Zone entry warning
  String? _lastWarnedZoneId;

  // Selected zone for bottom panel
  RiskZone? _selectedZone;

  // Risk-level colors
  static const _riskColors = {
    'HIGH': AppColors.danger,
    'MEDIUM': AppColors.warning,
    'LOW': AppColors.safe,
  };

  @override
  void initState() {
    super.initState();
    _zones = _service.getAllZones();
    _initTts();
    _startGps();
  }

  @override
  void dispose() {
    _geoSub?.cancel();
    _tts?.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts!.setLanguage('en-US');
    await _tts!.setSpeechRate(0.5);
    await _tts!.setVolume(1.0);
  }

  Future<void> _startGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      setState(() => _gpsAvailable = true);

      // Get initial position
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) {
          setState(() {
            _userPosition = LatLng(pos.latitude, pos.longitude);
          });
        }
      } catch (_) {}

      // Stream updates
      _geoSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position pos) {
        if (!mounted) return;
        setState(() {
          _userPosition = LatLng(pos.latitude, pos.longitude);
        });
        _checkZoneEntry(pos.latitude, pos.longitude);
      });
    } catch (_) {}
  }

  void _checkZoneEntry(double lat, double lng) {
    final zone = _service.detectZoneOffline(lat, lng);

    // Only warn if entering a HIGH-risk zone and haven't warned for this zone yet
    if (zone.riskLevel == 'HIGH' &&
        zone.id != _lastWarnedZoneId &&
        !zone.isDefaultZone) {
      _lastWarnedZoneId = zone.id;
      _showZoneWarning(zone);
    } else if (zone.isDefaultZone || zone.riskLevel != 'HIGH') {
      // Reset when leaving HIGH zone so re-entry triggers warning again
      if (_lastWarnedZoneId != null &&
          _zones
              .any((z) => z.id == _lastWarnedZoneId && z.riskLevel == 'HIGH')) {
        _lastWarnedZoneId = null;
      }
    }
  }

  void _showZoneWarning(RiskZone zone) {
    // Voice warning
    _tts?.speak(
      'Warning. You are entering ${zone.name}. This is a high risk zone. Speed limit is ${zone.speedLimit} kilometers per hour.',
    );

    // Popup dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.danger, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'High Risk Zone!',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                zone.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                zone.description,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.speed, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Speed Limit: ${zone.speedLimit} km/h',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('I Understand'),
            ),
          ],
        ),
      );
    }
  }

  Color _riskColor(String level) => _riskColors[level] ?? Colors.grey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Map ──
            _buildMap(),
            // ── Top bar ──
            _buildTopBar(),
            // ── Legend ──
            _buildLegend(),
            // ── GPS status badge ──
            _buildGpsBadge(),
            // ── Bottom zone info panel ──
            if (_selectedZone != null) _buildBottomPanel(_selectedZone!),
            // ── Center-on-me FAB ──
            if (_userPosition != null) _buildCenterFab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final puneCenter = LatLng(18.52, 73.86);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userPosition ?? puneCenter,
        initialZoom: 12.5,
        onTap: (_, __) {
          setState(() => _selectedZone = null);
        },
      ),
      children: [
        // ── OSM Tiles ──
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.zeropenalty',
        ),
        // ── Zone circles ──
        CircleLayer(
          circles: _zones.map((zone) {
            final color = _riskColor(zone.riskLevel);
            final isSelected = _selectedZone?.id == zone.id;
            return CircleMarker(
              point: LatLng(zone.latitude, zone.longitude),
              radius: zone.radius,
              useRadiusInMeter: true,
              color: color.withOpacity(isSelected ? 0.35 : 0.2),
              borderColor: color.withOpacity(isSelected ? 1.0 : 0.7),
              borderStrokeWidth: isSelected ? 3 : 2,
            );
          }).toList(),
        ),
        // ── Zone name labels (as markers) ──
        MarkerLayer(
          markers: _zones.map((zone) {
            final color = _riskColor(zone.riskLevel);
            return Marker(
              point: LatLng(zone.latitude, zone.longitude),
              width: 140,
              height: 50,
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedZone = zone);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.card.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color, width: 1.5),
                      ),
                      child: Text(
                        zone.name.length > 18
                            ? '${zone.name.substring(0, 16)}…'
                            : zone.name,
                        style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: color, size: 14),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        // ── User position marker ──
        if (_userPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userPosition!,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withOpacity(0.3),
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.my_location,
                        color: AppColors.accent, size: 16),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background.withOpacity(0.95),
              AppColors.background.withOpacity(0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.5)),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RISK ZONES',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 3,
                  ),
                ),
                Text(
                  'Pune, India — ${_zones.length} zones mapped',
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      top: 70,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _legendRow(AppColors.danger, 'HIGH Risk'),
            const SizedBox(height: 6),
            _legendRow(AppColors.warning, 'MEDIUM Risk'),
            const SizedBox(height: 6),
            _legendRow(AppColors.safe, 'LOW Risk'),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.3),
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildGpsBadge() {
    return Positioned(
      top: 70,
      left: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _gpsAvailable
                ? AppColors.safe.withOpacity(0.5)
                : AppColors.danger.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gpsAvailable ? AppColors.safe : AppColors.danger,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _gpsAvailable
                  ? (_userPosition != null ? 'GPS LIVE' : 'GPS WAITING...')
                  : 'GPS OFF',
              style: TextStyle(
                color: _gpsAvailable ? AppColors.safe : AppColors.danger,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterFab() {
    return Positioned(
      bottom: _selectedZone != null ? 210 : 24,
      right: 16,
      child: FloatingActionButton.small(
        backgroundColor: AppColors.card,
        onPressed: () {
          if (_userPosition != null) {
            _mapController.move(_userPosition!, 15);
          }
        },
        child: const Icon(Icons.my_location, color: AppColors.accent, size: 20),
      ),
    );
  }

  Widget _buildBottomPanel(RiskZone zone) {
    final color = _riskColor(zone.riskLevel);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border:
              Border(top: BorderSide(color: color.withOpacity(0.5), width: 2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Zone name + risk badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    zone.name,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${zone.riskLevel} RISK',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              zone.description,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            // Stats row
            Row(
              children: [
                _panelStat(
                    Icons.speed, '${zone.speedLimit}', 'km/h limit', color),
                const SizedBox(width: 12),
                _panelStat(Icons.gavel, '${zone.penaltyMultiplier}×',
                    'fine multiplier', AppColors.warning),
                const SizedBox(width: 12),
                _panelStat(
                  Icons.notifications_active,
                  zone.alertStrength,
                  'alert level',
                  zone.alertStrength == 'STRONG'
                      ? AppColors.danger
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                _panelStat(Icons.circle_outlined, '${zone.radius.toInt()}m',
                    'radius', AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
