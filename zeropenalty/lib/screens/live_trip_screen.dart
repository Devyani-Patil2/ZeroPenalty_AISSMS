import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../providers/history_provider.dart';
import '../providers/profile_provider.dart';
import '../services/risk_zone_service.dart';
import '../models/risk_zone.dart';
import '../widgets/app_logo.dart';
import '../utils/constants.dart';

class LiveTripScreen extends StatefulWidget {
  const LiveTripScreen({super.key});

  @override
  State<LiveTripScreen> createState() => _LiveTripScreenState();
}

class _LiveTripScreenState extends State<LiveTripScreen> {
  gmaps.GoogleMapController? _mapController;
  bool _followingUser = true;
  bool _isFullScreen = false;
  final RiskZoneService _zoneService = RiskZoneService();
  List<RiskZone> _allZones = [];

  // Helper to convert latlong2.LatLng to gmaps.LatLng
  gmaps.LatLng _toGmap(latlong.LatLng point) =>
      gmaps.LatLng(point.latitude, point.longitude);

  @override
  void initState() {
    super.initState();
    _allZones = _zoneService.getAllZones();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back during trip
      child: Scaffold(
        backgroundColor: context.bg,
        body: SafeArea(
          child: Consumer<TripProvider>(
            builder: (context, trip, _) {
              // Auto-center map if following enabled
              if (_followingUser && trip.pathPoints.isNotEmpty) {
                _mapController?.animateCamera(
                  gmaps.CameraUpdate.newLatLng(_toGmap(trip.pathPoints.last)),
                );
              }

              return Stack(
                children: [
                  Column(
                    children: [
                      if (!_isFullScreen) _buildTopBar(context, trip),
                      Expanded(
                        child: _isFullScreen
                            ? _buildMapSection(context, trip)
                            : SingleChildScrollView(
                                child: Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    _buildSpeedometer(context, trip),
                                    if (trip.isSimulatedTrip)
                                      _buildSimControl(context, trip),
                                    const SizedBox(height: 16),
                                    _buildMapSection(context, trip),
                                    const SizedBox(height: 16),
                                    _buildZoneBadge(context, trip),
                                    const SizedBox(height: 16),
                                    _buildTripStats(context, trip),
                                    const SizedBox(height: 16),
                                    _buildAlertsFeed(context, trip),
                                  ],
                                ),
                              ),
                      ),
                      if (!_isFullScreen) _buildStopButton(context, trip),
                    ],
                  ),
                  if (_isFullScreen)
                    Positioned(
                      top: 40,
                      left: 20,
                      right: 20,
                      child: _buildTopBar(context, trip, isOverlay: true),
                    ),
                  if (_isFullScreen)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: _buildStopButton(context, trip, isOverlay: true),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, TripProvider trip,
      {bool isOverlay = false}) {
    final minutes = trip.tripDuration ~/ 60;
    final seconds = trip.tripDuration % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: isOverlay
          ? BoxDecoration(
              color: AppColors.background.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            )
          : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'RECORDING',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (trip.isSimulatedTrip ? AppColors.warning : AppColors.safe)
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trip.isSimulatedTrip ? '🎮 DEMO' : '📡 LIVE',
              style: TextStyle(
                color:
                    trip.isSimulatedTrip ? AppColors.warning : AppColors.safe,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedometer(BuildContext context, TripProvider trip) {
    final speed = trip.currentSpeed;
    final limit = trip.currentSpeedLimit;
    final isOver = trip.isOverspeeding;
    final ratio = (speed / max(limit, 1)).clamp(0.0, 2.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isOver ? AppColors.danger.withOpacity(0.5) : context.borderColor,
          width: isOver ? 2 : 1,
        ),
        boxShadow: isOver
            ? [
                BoxShadow(
                    color: AppColors.danger.withOpacity(0.2), blurRadius: 20)
              ]
            : null,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _SpeedometerPainter(
                  ratio: ratio,
                  isOver: isOver,
                  borderColor: context.borderColor),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      speed.toStringAsFixed(0),
                      style: TextStyle(
                        color: isOver ? AppColors.danger : context.textPrimary,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'km/h',
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.speed, color: context.textMuted, size: 16),
              const SizedBox(width: 6),
              Text(
                'Limit: ${limit.toStringAsFixed(0)} km/h',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _localSimSpeed = 25.0;
  Widget _buildSimControl(BuildContext context, TripProvider trip) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'DEMO CONTROL',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${_localSimSpeed.toInt()} km/h',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primary.withOpacity(0.1),
              thumbColor: AppColors.primary,
            ),
            child: Slider(
              value: _localSimSpeed,
              min: 5,
              max: 100,
              onChanged: (val) {
                setState(() => _localSimSpeed = val);
                trip.setDemoSpeed(val);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _speedLabel('SAFE', AppColors.safe),
              _speedLabel('FAST', AppColors.warning),
              _speedLabel('EXTREME', AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _speedLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color.withOpacity(0.7),
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildMapSection(BuildContext context, TripProvider trip) {
    final path = trip.pathPoints;
    final lastPoint = path.isNotEmpty
        ? _toGmap(path.last)
        : const gmaps.LatLng(18.5204, 73.8567);

    return Container(
      height: _isFullScreen ? double.infinity : 300,
      margin: _isFullScreen
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius:
            _isFullScreen ? BorderRadius.zero : BorderRadius.circular(24),
        border: _isFullScreen ? null : Border.all(color: context.borderColor),
      ),
      child: ClipRRect(
        borderRadius:
            _isFullScreen ? BorderRadius.zero : BorderRadius.circular(24),
        child: Stack(
          children: [
            gmaps.GoogleMap(
              initialCameraPosition: gmaps.CameraPosition(
                target: lastPoint,
                zoom: 16.0,
              ),
              onMapCreated: (controller) => _mapController = controller,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onCameraMoveStarted: () {
                if (_followingUser) setState(() => _followingUser = false);
              },
              circles: _allZones
                  .map((z) => gmaps.Circle(
                        circleId: gmaps.CircleId(z.id.toString()),
                        center: gmaps.LatLng(z.latitude, z.longitude),
                        radius: z.radius,
                        fillColor:
                            AppColors.zoneColor(z.riskLevel).withOpacity(0.3),
                        strokeColor: AppColors.zoneColor(z.riskLevel),
                        strokeWidth: 2,
                      ))
                  .toSet(),
              polylines: {
                gmaps.Polyline(
                  polylineId: const gmaps.PolylineId('path'),
                  points: path.map((p) => _toGmap(p)).toList(),
                  color: AppColors.primary,
                  width: 5,
                ),
              },
              markers: {
                // Risk Zone Markers (Invisible but can add info windows if needed)
                ..._allZones.map((z) => gmaps.Marker(
                      markerId: gmaps.MarkerId('zone_${z.id}'),
                      position: gmaps.LatLng(z.latitude, z.longitude),
                      alpha: 0.8,
                      infoWindow: gmaps.InfoWindow(title: z.name),
                    )),
                // Driver Marker
                if (path.isNotEmpty)
                  gmaps.Marker(
                    markerId: const gmaps.MarkerId('driver'),
                    position: lastPoint,
                    icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                        gmaps.BitmapDescriptor.hueAzure),
                    rotation: 0, // Could calculate rotation based on path
                  ),
              },
            ),
            // Map controls
            Positioned(
              bottom: _isFullScreen ? 120 : 12,
              right: 12,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'fullscreen',
                    onPressed: () =>
                        setState(() => _isFullScreen = !_isFullScreen),
                    backgroundColor: AppColors.card,
                    child: Icon(
                        _isFullScreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'recenter',
                    onPressed: () {
                      setState(() => _followingUser = true);
                      if (path.isNotEmpty) {
                        _mapController?.animateCamera(
                          gmaps.CameraUpdate.newLatLng(_toGmap(path.last)),
                        );
                      }
                    },
                    backgroundColor:
                        _followingUser ? AppColors.primary : context.cardBg,
                    child: Icon(Icons.my_location,
                        color:
                            _followingUser ? Colors.white : AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneBadge(BuildContext context, TripProvider trip) {
    final zone = trip.currentZone;
    if (zone == null) return const SizedBox();

    final color = AppColors.zoneColor(zone.typeString);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            zone.risk.index == 0
                ? Icons.warning
                : zone.risk.index == 1
                    ? Icons.home
                    : Icons.route,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone.name,
                  style: TextStyle(
                      color: color, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${zone.riskLabel} • Limit: ${zone.speedLimit.toStringAsFixed(0)} km/h',
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStats(BuildContext context, TripProvider trip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _miniStat(context, 'Dist', '${trip.distanceKm.toStringAsFixed(1)}km',
              Icons.straighten),
          const SizedBox(width: 8),
          _miniStat(context, 'Max', '${trip.maxSpeed.toStringAsFixed(0)}',
              Icons.speed),
          const SizedBox(width: 8),
          _miniStat(
              context, 'Evts', '${trip.events.length}', Icons.warning_amber),
          const SizedBox(width: 8),
          _miniStat(context, 'Score', trip.liveScore.toStringAsFixed(0), null,
              color: AppColors.scoreColor(trip.liveScore),
              customLogo: const AppLogo(size: 14)),
        ],
      ),
    );
  }

  Widget _miniStat(
      BuildContext context, String label, String value, IconData? icon,
      {Color? color, Widget? customLogo}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.surfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            customLogo ??
                Icon(icon, color: color ?? context.textMuted, size: 14),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color ?? context.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: context.textMuted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsFeed(BuildContext context, TripProvider trip) {
    if (trip.recentAlerts.isEmpty) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: Text('✅ Driving safely',
              style: TextStyle(color: AppColors.safe, fontSize: 14)),
        ),
      );
    }

    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        itemCount: trip.recentAlerts.length,
        itemBuilder: (context, index) {
          final color = index == 0 ? AppColors.danger : AppColors.warning;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              trip.recentAlerts[index],
              style: TextStyle(
                color: index == 0 ? AppColors.danger : AppColors.warningLight,
                fontSize: 12,
                fontWeight: index == 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStopButton(BuildContext context, TripProvider trip,
      {bool isOverlay = false}) {
    return Padding(
      padding: isOverlay ? EdgeInsets.zero : const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            final completedTrip = await trip.stopTrip();
            if (context.mounted) {
              context.read<HistoryProvider>().addTrip(completedTrip);
              // Process achievements before refresh
              await context
                  .read<ProfileProvider>()
                  .processTripStats(completedTrip);
              context.read<ProfileProvider>().refresh();
              Navigator.pushReplacementNamed(context, '/summary');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: isOverlay
                  ? const BorderSide(color: Colors.white24)
                  : BorderSide.none,
            ),
            elevation: isOverlay ? 8 : 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stop_circle, size: 24),
              SizedBox(width: 8),
              Text('Stop Trip',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom speedometer arc painter — 240° gauge
class _SpeedometerPainter extends CustomPainter {
  final double ratio;
  final bool isOver;
  final Color borderColor;

  _SpeedometerPainter(
      {required this.ratio, required this.isOver, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final radius = min(size.width, size.height) * 0.42;
    const startAngle = pi * 150 / 180; // 150 degrees
    const totalSweep = pi * 240 / 180; // 240 degrees

    final bgPaint = Paint()
      ..color = borderColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        totalSweep, false, bgPaint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    if (isOver) {
      progressPaint.color = AppColors.danger;
    } else {
      progressPaint.shader = const LinearGradient(
        colors: [AppColors.safe, AppColors.warning],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    }

    final progress = (ratio.clamp(0.0, 1.5)) / 1.5;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        totalSweep * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
