import 'dart:async';
import 'package:flutter/material.dart';
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
  final _latCtrl = TextEditingController(text: '18.5284');
  final _lngCtrl = TextEditingController(text: '73.8742');
  final _speedCtrl = TextEditingController(text: '35');
  Timer? _timeTimer;

  // Risk-level colors (synced with AppColors)
  static const _riskColors = {
    'HIGH': AppColors.danger,
    'MEDIUM': AppColors.warning,
    'LOW': AppColors.safe,
  };
  static const _riskIcons = {'HIGH': '⚠️', 'MEDIUM': '🔶', 'LOW': '✅'};

  @override
  void initState() {
    super.initState();
    _timeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        context.read<RiskZoneProvider>().refreshTimeRisk();
      }
    });
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _speedCtrl.dispose();
    super.dispose();
  }

  void _detect() {
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);
    final speed = double.tryParse(_speedCtrl.text);
    if (lat == null || lng == null || speed == null) return;
    context.read<RiskZoneProvider>().detect(lat, lng, speed);
  }

  void _loadPreset(int index) {
    final p = RiskZoneService.presets[index];
    _latCtrl.text = p['lat'].toString();
    _lngCtrl.text = p['lng'].toString();
    _speedCtrl.text = p['speed'].toString();
    context.read<RiskZoneProvider>().loadPreset(index);
  }

  Color _riskColor(String level) =>
      _riskColors[level] ?? const Color(0xFF636366);

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
                // ── Input Card ──
                SliverToBoxAdapter(child: _buildInputCard()),
                // ── Quick Test Presets ──
                SliverToBoxAdapter(child: _buildPresets()),
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
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.safe),
                ),
                const SizedBox(width: 6),
                Text('ONLINE',
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 10,
                      letterSpacing: 1,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Input Card ──────────────────────────────────────────────────
  Widget _buildInputCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardLabel('GPS + Speed Input'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _inputField('Latitude', _latCtrl)),
              const SizedBox(width: 10),
              Expanded(child: _inputField('Longitude', _lngCtrl)),
              const SizedBox(width: 10),
              Expanded(child: _inputField('Speed (km/h)', _speedCtrl)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Consumer<RiskZoneProvider>(
              builder: (context, prov, _) => ElevatedButton(
                onPressed: prov.isLoading ? null : _detect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 2),
                ),
                child: prov.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Text('DETECT ZONE'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(
              color: context.textMuted,
              fontSize: 9,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
              color: AppColors.primary, fontSize: 14, fontFamily: 'monospace'),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Quick Test Presets ──────────────────────────────────────────
  Widget _buildPresets() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QUICK TEST →',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 10,
                letterSpacing: 2,
              )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(RiskZoneService.presets.length, (i) {
              final p = RiskZoneService.presets[i];
              return OutlinedButton(
                onPressed: () => _loadPreset(i),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: BorderSide(color: context.borderColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: Text(p['label'],
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    )),
              );
            }),
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
          Text('Enter GPS coordinates and press DETECT ZONE',
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
              // Risk Badge Circle
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
              // Zone Info
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
                    // Tags
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
            isOver ? AppColors.danger : AppColors.primary,
          ),
          const SizedBox(width: 10),
          _statBlock(
            'Speed Limit',
            zone.speedLimit.toString(),
            'km/h',
            (zone.speedLimit / 120).clamp(0.0, 1.0),
            AppColors.safe,
          ),
          const SizedBox(width: 10),
          _statBlock(
            'Penalty ×',
            '${zone.penaltyMultiplier}×',
            '× base fine',
            (zone.penaltyMultiplier / 4).clamp(0.0, 1.0),
            AppColors.warning,
          ),
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
    final titleColor =
        isOver ? AppColors.danger : AppColors.safe;

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
                  color: isOver
                      ? AppColors.danger
                      : AppColors.safe,
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
            width: 20,
            height: 1,
            color: AppColors.primary.withOpacity(0.6)),
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
