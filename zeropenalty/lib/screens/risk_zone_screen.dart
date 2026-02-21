import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/risk_zone_provider.dart';
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
  Timer? _timeTimer;

  // All zones
  late final List<RiskZone> _zones;

  // Live GPS
  LatLng? _userPosition;
  StreamSubscription<Position>? _geoSub;
  bool _gpsAvailable = false;

  // Zone entry warning
  String? _lastWarnedZoneId;

  // Selected zone for bottom panel on map
  RiskZone? _selectedZone;

  // Risk-level colors
  static const _riskColors = {
    'HIGH': AppColors.danger,
    'MEDIUM': AppColors.warning,
    'LOW': AppColors.safe,
  };
  static const _riskIcons = {'HIGH': '⚠️', 'MEDIUM': '🔶', 'LOW': '✅'};

  @override
  void initState() {
    super.initState();
    _zones = _service.getAllZones();
    _initTts();
    _startGps();
    _timeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        context.read<RiskZoneProvider>().refreshTimeRisk();
      }
    });
  }

  @override
  void dispose() {
    _geoSub?.cancel();
    _tts?.stop();
    _timeTimer?.cancel();
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
    if (zone.riskLevel == 'HIGH' &&
        zone.id != _lastWarnedZoneId &&
        !zone.isDefaultZone) {
      _lastWarnedZoneId = zone.id;
      _showZoneWarning(zone);
    } else if (zone.isDefaultZone || zone.riskLevel != 'HIGH') {
      if (_lastWarnedZoneId != null &&
          _zones
              .any((z) => z.id == _lastWarnedZoneId && z.riskLevel == 'HIGH')) {
        _lastWarnedZoneId = null;
      }
    }
  }

  void _showZoneWarning(RiskZone zone) {
    _tts?.speak(
      'Warning. You are entering ${zone.name}. This is a high risk zone. Speed limit is ${zone.speedLimit} kilometers per hour.',
    );
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
                child: Text('High Risk Zone!',
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(zone.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 8),
              Text(zone.description,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
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
                    Text('Speed Limit: ${zone.speedLimit} km/h',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        )),
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
        child: Consumer<RiskZoneProvider>(
          builder: (context, prov, _) {
            return CustomScrollView(
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(child: _buildHeader()),
                // ── LIVE MAP ──
                SliverToBoxAdapter(child: _buildMapSection()),
                // ── Time Risk Banner ──
                SliverToBoxAdapter(child: _buildTimeRiskBanner(prov)),
                // ── Zone Detection Result ──
                if (prov.isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary)),
                    ),
                  )
                else if (prov.hasResult) ...[
                  SliverToBoxAdapter(child: _buildZoneCard(prov.result!)),
                  SliverToBoxAdapter(child: _buildStatsGrid(prov.result!)),
                  SliverToBoxAdapter(child: _buildAlertBanner(prov.result!)),
                ] else
                  SliverToBoxAdapter(child: _buildEmptyState()),
                // ── All Zones Table ──
                SliverToBoxAdapter(child: _buildZonesTable(prov)),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(bottom: BorderSide(color: context.borderColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Center(
              child: Icon(Icons.warning_amber_rounded,
                  color: AppColors.primary, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ZEROPENALTY',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 3,
                  )),
              const Text('Risk Zone Intelligence',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gpsAvailable ? AppColors.safe : AppColors.danger,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _gpsAvailable ? 'GPS LIVE' : 'GPS OFF',
                  style: TextStyle(
                    color: _gpsAvailable ? AppColors.safe : AppColors.danger,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── LIVE MAP SECTION ────────────────────────────────────────────
  Widget _buildMapSection() {
    final puneCenter = LatLng(18.52, 73.86);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Map header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: context.cardBg,
              child: Row(
                children: [
                  _cardLabel('Live Risk Zone Map'),
                  const Spacer(),
                  // Legend
                  _legendDot(AppColors.danger, 'HIGH'),
                  const SizedBox(width: 8),
                  _legendDot(AppColors.warning, 'MED'),
                  const SizedBox(width: 8),
                  _legendDot(AppColors.safe, 'LOW'),
                ],
              ),
            ),
            // Map itself
            SizedBox(
              height: 300,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _userPosition ?? puneCenter,
                      initialZoom: 12.0,
                      onTap: (_, __) {
                        setState(() => _selectedZone = null);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.zeropenalty',
                      ),
                      // Zone circles
                      CircleLayer(
                        circles: _zones.map((zone) {
                          final color = _riskColor(zone.riskLevel);
                          final isSelected = _selectedZone?.id == zone.id;
                          return CircleMarker(
                            point: LatLng(zone.latitude, zone.longitude),
                            radius: zone.radius,
                            useRadiusInMeter: true,
                            color: color.withOpacity(isSelected ? 0.35 : 0.2),
                            borderColor:
                                color.withOpacity(isSelected ? 1.0 : 0.7),
                            borderStrokeWidth: isSelected ? 3 : 2,
                          );
                        }).toList(),
                      ),
                      // Zone name labels
                      MarkerLayer(
                        markers: _zones.map((zone) {
                          final color = _riskColor(zone.riskLevel);
                          return Marker(
                            point: LatLng(zone.latitude, zone.longitude),
                            width: 140,
                            height: 50,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedZone = zone),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.card.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(4),
                                      border:
                                          Border.all(color: color, width: 1.5),
                                    ),
                                    child: Text(
                                      zone.name.length > 18
                                          ? '${zone.name.substring(0, 16)}…'
                                          : zone.name,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.arrow_drop_down,
                                      color: color, size: 12),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      // User position
                      if (_userPosition != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _userPosition!,
                              width: 26,
                              height: 26,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accent.withOpacity(0.3),
                                  border: Border.all(
                                      color: AppColors.accent, width: 2),
                                ),
                                child: const Center(
                                  child: Icon(Icons.my_location,
                                      color: AppColors.accent, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  // Center-on-me button
                  if (_userPosition != null)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _mapController.move(_userPosition!, 15),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.accent.withOpacity(0.5)),
                          ),
                          child: const Icon(Icons.my_location,
                              color: AppColors.accent, size: 18),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Selected zone info panel (below map)
            if (_selectedZone != null) _buildMapZoneInfo(_selectedZone!),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
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
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }

  Widget _buildMapZoneInfo(RiskZone zone) {
    final color = _riskColor(zone.riskLevel);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: context.cardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(zone.name,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    )),
              ),
              _tag('${zone.riskLevel} RISK', color),
            ],
          ),
          const SizedBox(height: 4),
          Text(zone.description,
              style: TextStyle(color: context.textMuted, fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            children: [
              _tag('🚗 ${zone.speedLimit} km/h', color),
              const SizedBox(width: 6),
              _tag('⚡ ${zone.penaltyMultiplier}×', AppColors.warning),
              const SizedBox(width: 6),
              _tag('📏 ${zone.radius.toInt()}m', AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Time Risk Banner ───────────────────────────────────────────
  Widget _buildTimeRiskBanner(RiskZoneProvider prov) {
    final labels = (prov.timeRisk['labels'] ?? []) as List;
    final isNight = prov.timeRisk['isNight'] ?? false;
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final bannerColor = labels.isEmpty
        ? const Color(0xFF30D158)
        : (isNight ? const Color(0xFFFF2D55) : const Color(0xFFFF9F0A));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bannerColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Text('⏱ TIME RISK',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              labels.isEmpty
                  ? '✅ Normal Hours — Standard Risk'
                  : labels.join('  ·  '),
              style: TextStyle(color: bannerColor, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('🕐 $timeStr',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 10,
              )),
        ],
      ),
    );
  }

  // ─── Empty State ────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        children: [
          _cardLabel('Detected Zone'),
          const SizedBox(height: 24),
          const Text('📍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text('Tap a zone on the map above to see details',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 12,
                letterSpacing: 1,
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── Zone Detection Card ────────────────────────────────────────
  Widget _buildZoneCard(RiskDetectionResult result) {
    final zone = result.zone;
    final risk = zone.riskLevel;
    final color = _riskColor(risk);
    final icon = _riskIcons[risk] ?? '📍';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardLabel('Detected Zone'),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 2),
                    Text(risk,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(zone.name,
                        style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        )),
                    const SizedBox(height: 4),
                    Text(zone.description,
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12,
                          height: 1.4,
                        )),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _tag('$risk RISK', color),
                        _tag('🔔 ${zone.alertStrength} ALERT',
                            context.borderColor),
                        _tag('⚡ ${zone.penaltyMultiplier}× MULTIPLIER',
                            context.borderColor),
                        if (zone.isDefaultZone)
                          _tag('DEFAULT ZONE', context.borderColor),
                        if (zone.isDynamic)
                          _tag('🌐 DYNAMIC', AppColors.primary)
                        else
                          _tag('📁 STATIC', context.borderColor),
                        if (zone.accidentHotspot)
                          _tag('⚠️ ACCIDENT HOTSPOT', AppColors.danger),
                        ...zone.timeLabels
                            .map((l) => _tag(l, AppColors.warning)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Stats Grid ─────────────────────────────────────────────────
  Widget _buildStatsGrid(RiskDetectionResult result) {
    final zone = result.zone;
    final speed = result.currentSpeed;
    final isOver = result.isOverspeed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _statBlock(
              'Current Speed',
              speed.toStringAsFixed(1),
              'km/h',
              (speed / 120).clamp(0.0, 1.0),
              isOver ? AppColors.danger : AppColors.primary),
          const SizedBox(width: 10),
          _statBlock('Speed Limit', zone.speedLimit.toString(), 'km/h',
              (zone.speedLimit / 120).clamp(0.0, 1.0), AppColors.safe),
          const SizedBox(width: 10),
          _statBlock('Penalty ×', '${zone.penaltyMultiplier}×', '× base fine',
              (zone.penaltyMultiplier / 4).clamp(0.0, 1.0), AppColors.warning),
        ],
      ),
    );
  }

  Widget _statBlock(String label, String value, String unit, double progress,
      Color barColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 8,
                  letterSpacing: 2,
                )),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                )),
            Text(unit,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 10,
                )),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: context.borderColor.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Alert Banner ───────────────────────────────────────────────
  Widget _buildAlertBanner(RiskDetectionResult result) {
    final zone = result.zone;
    final isOver = result.isOverspeed;
    final speed = result.currentSpeed;
    final penalty = result.penalty;

    final bgColor = isOver
        ? AppColors.danger.withOpacity(0.08)
        : AppColors.safe.withOpacity(0.08);
    final borderColor = isOver
        ? AppColors.danger.withOpacity(0.4)
        : AppColors.safe.withOpacity(0.3);
    final titleColor = isOver ? AppColors.danger : AppColors.safe;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text(isOver ? '🚨' : '✅', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOver ? 'OVERSPEED DETECTED' : 'WITHIN SPEED LIMIT',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOver
                      ? 'Going ${speed.toStringAsFixed(1)} km/h in a ${zone.speedLimit} km/h zone — ${result.overspeedBy.toStringAsFixed(1)} km/h over'
                      : 'Going ${speed.toStringAsFixed(1)} km/h — ${(zone.speedLimit - speed).toStringAsFixed(1)} km/h below limit. Drive safe!',
                  style: TextStyle(color: context.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('FINE APPLICABLE',
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 9,
                    letterSpacing: 2,
                  )),
              const SizedBox(height: 2),
              Text(
                '₹${penalty.toInt()}',
                style: TextStyle(
                  color: isOver ? AppColors.danger : AppColors.safe,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── All Zones Table ────────────────────────────────────────────
  Widget _buildZonesTable(RiskZoneProvider prov) {
    final zones = prov.allZones;
    final activeId = prov.result?.zone.id;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardLabel('All Defined Risk Zones — Pune, India'),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 48,
              columnSpacing: 20,
              headingTextStyle: TextStyle(
                color: context.textMuted,
                fontSize: 9,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
              columns: const [
                DataColumn(label: Text('ZONE NAME')),
                DataColumn(label: Text('RISK')),
                DataColumn(label: Text('LIMIT')),
                DataColumn(label: Text('PENALTY ×')),
                DataColumn(label: Text('ALERT')),
              ],
              rows: zones.map((z) {
                final isActive = z.id == activeId;
                return DataRow(
                  color: WidgetStateProperty.all(
                    isActive
                        ? AppColors.primary.withOpacity(0.05)
                        : Colors.transparent,
                  ),
                  cells: [
                    DataCell(Text(z.name,
                        style: TextStyle(
                          color: context.textPrimary.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ))),
                    DataCell(_riskChip(z.riskLevel)),
                    DataCell(Text('${z.speedLimit} km/h',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ))),
                    DataCell(Text('${z.penaltyMultiplier}×',
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ))),
                    DataCell(Text(z.alertStrength,
                        style: TextStyle(
                          color: z.alertStrength == 'STRONG'
                              ? AppColors.danger
                              : context.textMuted,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────
  BoxDecoration _cardDeco() {
    return BoxDecoration(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.borderColor),
    );
  }

  Widget _cardLabel(String text) {
    return Row(
      children: [
        Container(
            width: 20, height: 1, color: AppColors.primary.withOpacity(0.6)),
        const SizedBox(width: 8),
        Text(text.toUpperCase(),
            style: TextStyle(
              color: context.textMuted,
              fontSize: 10,
              letterSpacing: 3,
            )),
      ],
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 9, letterSpacing: 1)),
    );
  }

  Widget _riskChip(String level) {
    final color = _riskColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              )),
          const SizedBox(width: 5),
          Text(level,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              )),
        ],
      ),
    );
  }
}
