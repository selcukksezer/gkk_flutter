import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../core/assets/mesh_asset_registry.dart';
import '../../../core/engine/adaptive_quality_scaler.dart';
import '../../../core/services/app_haptics.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../graphics_settings_service.dart';
import '../services/preloader_diagnostics_service.dart';
import 'settings_design.dart';

/// Preloader Status & Cache Diagnostics UI widget for Settings.
///
/// Features:
/// - Real-time telemetry: RAM/VRAM footprint, frame budget, touch-yield status.
/// - 3D Asset Cache & CC0 Mesh Registry statistics and category distribution.
/// - Asset integrity verification with detailed report.
/// - Shader pipeline status and manual Shader Warm-Up trigger CTA.
/// - Low-spec hardware preset simulator (Low, Mid, High, Ultra).
/// - Cache clearing and manual preloader loop pause/resume controls.
/// - AdaptiveQualityScaler dynamic thermal tier & hysteresis auto-scale wiring.
class PreloaderCacheDiagnosticsCard extends StatefulWidget {
  const PreloaderCacheDiagnosticsCard({
    super.key,
    this.diagnosticsService,
    this.scaler,
    this.autoStartPolling = true,
  });

  final PreloaderDiagnosticsService? diagnosticsService;
  final AdaptiveQualityScaler? scaler;
  final bool autoStartPolling;

  @override
  State<PreloaderCacheDiagnosticsCard> createState() =>
      _PreloaderCacheDiagnosticsCardState();
}

class _PreloaderCacheDiagnosticsCardState
    extends State<PreloaderCacheDiagnosticsCard> {
  late final PreloaderDiagnosticsService _service;
  bool _ownsService = false;
  AdaptiveQualityScaler? _scaler;

  @override
  void initState() {
    super.initState();
    if (widget.diagnosticsService != null) {
      _service = widget.diagnosticsService!;
      _ownsService = false;
    } else {
      _service = PreloaderDiagnosticsService.instance;
      _ownsService = true;
    }

    _service.addListener(_onServiceUpdate);
    if (widget.autoStartPolling) {
      _service.startTelemetryPolling();
    }

    try {
      _scaler = widget.scaler ?? GraphicsSettingsService.instance.scaler;
    } catch (_) {
      _scaler = null;
    }
    _scaler?.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scaler?.removeListener(_onServiceUpdate);
    _service.removeListener(_onServiceUpdate);
    if (_ownsService || widget.autoStartPolling) {
      _service.stopTelemetryPolling();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CombinedDiagnosticsSnapshot snap = _service.latestSnapshot;

    return SettingsGlassCard(
      accent: AppColors.accentCyan,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header with Live Status & Controls
          _buildHeader(snap),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 14),

          // 1. Zero-Jank Preloader & Memory Footprint
          _buildPreloaderMemorySection(snap),
          const SizedBox(height: 16),

          // 2. Hardware Spec Profile Testing Selector
          _buildHardwarePresetSelector(snap),
          const SizedBox(height: 16),

          // 3. 3D Asset Cache & CC0 Models
          _build3dAssetCacheSection(snap),
          const SizedBox(height: 16),

          // 4. Shader Pipeline & Warm-Up
          _buildShaderWarmupSection(snap),
          const SizedBox(height: 16),

          // 5. AdaptiveQualityScaler & Dynamic Thermal Tier
          if (_scaler != null) ...<Widget>[
            _buildAdaptiveQualitySection(snap, _scaler!),
            const SizedBox(height: 16),
          ],

          // 6. Global Cache Purge Action
          _buildCacheActions(snap),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Header & Live Indicator
  // ---------------------------------------------------------------------------

  Widget _buildHeader(CombinedDiagnosticsSnapshot snap) {
    final bool touchYield = snap.isTouchYielding;
    final bool isPaused = snap.isPreloaderPaused;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Top banner: Aion rune tag + live heartbeat badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: AppColors.accentCyan.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.accentCyan.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'ᚠ AION HYPER-ENGINE',
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.accentCyan,
                      fontSize: 9.5,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '• ZERO-JANK CORE',
                    style: AppTextStyles.caption.copyWith(
                      color: SettingsPalette.titanium,
                      fontSize: 9,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: <Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPaused ? SettingsPalette.ruby : SettingsPalette.neon,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: (isPaused ? SettingsPalette.ruby : SettingsPalette.neon)
                            .withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isPaused ? 'TELEMETRİ DURDU' : 'CANLI TELEMETRİ',
                  style: AppTextStyles.captionBold.copyWith(
                    color: isPaused ? SettingsPalette.ruby : SettingsPalette.neon,
                    fontSize: 9.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.accentCyan.withValues(alpha: 0.35),
                    SettingsPalette.obsidian,
                  ],
                ),
                border: Border.all(
                  color: AppColors.accentCyan.withValues(alpha: 0.6),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.accentCyan.withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(
                Icons.memory_rounded,
                size: 22,
                color: AppColors.accentCyan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'ÖN YÜKLEYİCİ VE ÖNBELLEK DİYAGNOSTİK',
                    style: AppTextStyles.captionBold.copyWith(
                      color: SettingsPalette.textHi,
                      letterSpacing: 0.8,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Zero-Jank VRAM, 3D varlık akışı ve shader telemetrisi',
                    style: AppTextStyles.caption.copyWith(
                      color: SettingsPalette.titanium,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Pause / Resume background preloader toggle button
            SettingsPressable(
              onTap: () {
                AppHaptics.selection();
                _service.togglePreloaderPause();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isPaused
                      ? SettingsPalette.ruby.withValues(alpha: 0.22)
                      : SettingsPalette.obsidian.withValues(alpha: 0.85),
                  border: Border.all(
                    color: isPaused
                        ? SettingsPalette.ruby.withValues(alpha: 0.65)
                        : SettingsPalette.titanium.withValues(alpha: 0.35),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (isPaused ? SettingsPalette.ruby : AppColors.accentCyan)
                          .withValues(alpha: 0.18),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 14,
                      color: isPaused ? SettingsPalette.ruby : SettingsPalette.textHi,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isPaused ? 'DURAKLATILDI' : 'ÇALIŞIYOR',
                      style: AppTextStyles.captionBold.copyWith(
                        color: isPaused ? SettingsPalette.ruby : SettingsPalette.textHi,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Badges: Touch-Yield status + Frame Budget + Presets + AQS Tier
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: <Widget>[
            _buildLiveStatusPill(
              label: touchYield ? 'GİRİŞ BEKLETME: AKTİF' : 'AKIŞ: KESİNTİSİZ',
              color: touchYield ? SettingsPalette.gold : SettingsPalette.neon,
              icon: touchYield ? Icons.touch_app_rounded : Icons.bolt_rounded,
            ),
            _buildLiveStatusPill(
              label: 'Kare Bütçesi: ${snap.frameBudgetMs.toStringAsFixed(1)} ms',
              color: AppColors.accentCyan,
              icon: Icons.speed_rounded,
            ),
            _buildLiveStatusPill(
              label: snap.activePreset.label,
              color: SettingsPalette.fuchsia,
              icon: Icons.tune_rounded,
            ),
            if (_scaler != null) ...<Widget>[
              _buildLiveStatusPill(
                label: 'AQS: ${_scaler!.currentTier.name.toUpperCase()} (L${_scaler!.currentThrottleLevel})',
                color: _scaler!.currentThrottleLevel == 0
                    ? SettingsPalette.neon
                    : SettingsPalette.coral,
                icon: Icons.auto_graph_rounded,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLiveStatusPill({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              color: color,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Preloader & Memory Footprint Section
  // ---------------------------------------------------------------------------

  Widget _buildPreloaderMemorySection(CombinedDiagnosticsSnapshot snap) {
    final p = snap.preloaderSnapshot;
    final double ramMb = p.ramUsedBytes / (1024 * 1024);
    final double ramMaxMb = p.ramCeilingBytes / (1024 * 1024);
    final double vramMb = p.vramUsedBytes / (1024 * 1024);
    final double vramMaxMb = p.vramCeilingBytes / (1024 * 1024);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SettingsPalette.navy.withValues(alpha: 0.6),
            SettingsPalette.obsidian.withValues(alpha: 0.82),
          ],
        ),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.22),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.accentCyan.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'ᚱ MEMORY GAUGE',
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.accentCyan,
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.data_usage_rounded,
                size: 16,
                color: AppColors.accentCyan,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ZERO-JANK BELLEK VE GÖREV DAĞILIMI',
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Total Footprint Bento Capsule
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: SettingsPalette.obsidian.withValues(alpha: 0.7),
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.speed_rounded,
                      size: 14,
                      color: AppColors.accentCyan,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Toplam Varlık & Bellek Tüketimi',
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.titanium,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${snap.totalMemoryMb.toStringAsFixed(1)} / ${snap.totalCeilingMb.toStringAsFixed(0)} MB (${(snap.totalUtilizationFraction * 100).toStringAsFixed(1)}%)',
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.accentCyan,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // RAM Usage Bar
          _buildMemoryBar(
            title: 'Sistem RAM',
            usedMb: ramMb,
            maxMb: ramMaxMb,
            fraction: p.ramUsageFraction,
            color: SettingsPalette.gold,
            watermarkNote: 'Tavan: %95',
          ),
          const SizedBox(height: 10),

          // VRAM Usage Bar
          _buildMemoryBar(
            title: 'GPU VRAM',
            usedMb: vramMb,
            maxMb: vramMaxMb,
            fraction: p.vramUsageFraction,
            color: AppColors.accentCyan,
            watermarkNote: 'Tavan: %95',
          ),
          const SizedBox(height: 14),

          // Tasks grid & Cache Hit Rate
          Row(
            children: <Widget>[
              Expanded(
                child: _buildMetricTile(
                  label: 'Önbellek İsabeti',
                  value: '${(p.hitRate * 100).toStringAsFixed(1)}%',
                  accent: SettingsPalette.neon,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Tahliyeler (Evict)',
                  value: '${p.totalEvictions}',
                  accent: SettingsPalette.coral,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Tamamlanan Görev',
                  value: '${p.completedTasks}',
                  accent: SettingsPalette.textHi,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Detailed task state row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: SettingsPalette.navy.withValues(alpha: 0.5),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _buildTaskDot(label: 'Bekleyen', count: p.pendingTasks, color: SettingsPalette.gold),
                _buildTaskDot(label: 'Çalışan', count: p.runningTasks, color: AppColors.accentCyan),
                _buildTaskDot(label: 'İptal', count: p.cancelledTasks, color: SettingsPalette.titanium),
                _buildTaskDot(label: 'Hata', count: p.failedTasks, color: SettingsPalette.ruby),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryBar({
    required String title,
    required double usedMb,
    required double maxMb,
    required double fraction,
    required Color color,
    String? watermarkNote,
  }) {
    final double pct = (fraction * 100).clamp(0.0, 100.0);
    final Color barColor = pct > 90
        ? SettingsPalette.ruby
        : (pct > 75 ? SettingsPalette.gold : color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  title,
                  style: AppTextStyles.caption.copyWith(
                    color: SettingsPalette.titanium,
                    fontSize: 11,
                  ),
                ),
                if (watermarkNote != null) ...<Widget>[
                  const SizedBox(width: 6),
                  Text(
                    '($watermarkNote)',
                    style: AppTextStyles.caption.copyWith(
                      color: SettingsPalette.titanium.withValues(alpha: 0.6),
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ],
            ),
            Text(
              '${usedMb.toStringAsFixed(1)} / ${maxMb.toStringAsFixed(0)} MB (${pct.toStringAsFixed(1)}%)',
              style: AppTextStyles.captionBold.copyWith(
                color: SettingsPalette.textHi,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: SettingsPalette.navy.withValues(alpha: 0.65),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: SettingsPalette.titanium,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTextStyles.captionBold.copyWith(
              color: accent,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskDot({
    required String label,
    required int count,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$label: $count',
          style: AppTextStyles.caption.copyWith(
            color: SettingsPalette.textMid,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Hardware Spec Profile Testing Selector
  // ---------------------------------------------------------------------------

  Widget _buildHardwarePresetSelector(CombinedDiagnosticsSnapshot snap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: SettingsPalette.gold.withValues(alpha: 0.15),
                border: Border.all(
                  color: SettingsPalette.gold.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                'ᚹ PRESETS',
                style: AppTextStyles.captionBold.copyWith(
                  color: SettingsPalette.gold,
                  fontSize: 9,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.phone_android_rounded,
              size: 16,
              color: SettingsPalette.gold,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'DÜŞÜK SİSTEM PROFİL TESTİ (DONANIM TAVANI)',
                style: AppTextStyles.captionBold.copyWith(
                  color: SettingsPalette.textHi,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.4,
          children: DiagnosticsHardwarePreset.values.map((preset) {
            final bool selected = snap.activePreset == preset;
            return SettingsPressable(
              onTap: () {
                AppHaptics.selection();
                _service.setHardwarePreset(preset);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: selected
                        ? <Color>[
                            AppColors.accentCyan.withValues(alpha: 0.25),
                            SettingsPalette.obsidian.withValues(alpha: 0.9),
                          ]
                        : <Color>[
                            SettingsPalette.obsidian.withValues(alpha: 0.8),
                            SettingsPalette.navy.withValues(alpha: 0.5),
                          ],
                  ),
                  border: Border.all(
                    color: selected
                        ? AppColors.accentCyan
                        : SettingsPalette.titanium.withValues(alpha: 0.25),
                    width: selected ? 1.5 : 1.0,
                  ),
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: AppColors.accentCyan.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            preset.label,
                            style: AppTextStyles.captionBold.copyWith(
                              color: selected ? AppColors.accentCyan : SettingsPalette.textHi,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preset.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: SettingsPalette.titanium,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AppColors.accentCyan,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. 3D Asset Cache & CC0 Mesh Registry Section
  // ---------------------------------------------------------------------------

  Widget _build3dAssetCacheSection(CombinedDiagnosticsSnapshot snap) {
    final m = snap.meshStats;
    final double cachedMb = m.cachedMemoryBytes / (1024 * 1024);
    final double maxCacheMb = m.maxCacheMemoryBytes / (1024 * 1024);
    final report = _service.lastIntegrityReport;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SettingsPalette.navy.withValues(alpha: 0.55),
            SettingsPalette.obsidian.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(
          color: SettingsPalette.fuchsia.withValues(alpha: 0.25),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: SettingsPalette.fuchsia.withValues(alpha: 0.15),
                  border: Border.all(
                    color: SettingsPalette.fuchsia.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'ᛗ 3D MESH',
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.fuchsia,
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.view_in_ar_rounded,
                size: 16,
                color: SettingsPalette.fuchsia,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '3D VARLIK DEPOSU VE CC0 MODEL ÖNBELLEĞİ',
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            children: <Widget>[
              Expanded(
                child: _buildMetricTile(
                  label: 'Kayıtlı CC0 Model',
                  value: '${m.totalCc0Models} / ${m.totalModels}',
                  accent: SettingsPalette.gold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Önbellekteki Mesh',
                  value: '${m.cachedModelsCount} adet',
                  accent: SettingsPalette.fuchsia,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Mesh Belleği',
                  value: '${cachedMb.toStringAsFixed(1)} / ${maxCacheMb.toStringAsFixed(0)} MB',
                  accent: SettingsPalette.textHi,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Categories Breakdown Chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: m.modelsByCategory.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: SettingsPalette.navy.withValues(alpha: 0.75),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text(
                  '${_categoryLabel(entry.key)}: ${entry.value}',
                  style: AppTextStyles.caption.copyWith(
                    color: SettingsPalette.textMid,
                    fontSize: 10,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Action: Verify Asset Integrity & Clear Mesh Cache
          Row(
            children: <Widget>[
              Expanded(
                child: SettingsPressable(
                  enabled: !_service.isVerifyingIntegrity,
                  onTap: () async {
                    AppHaptics.selection();
                    await _service.verifyAssetIntegrity();
                    if (mounted) {
                      AppHaptics.success();
                    }
                  },
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: <Color>[
                          SettingsPalette.fuchsia.withValues(alpha: 0.4),
                          SettingsPalette.navy,
                        ],
                      ),
                      border: Border.all(
                        color: SettingsPalette.fuchsia.withValues(alpha: 0.75),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: SettingsPalette.fuchsia.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: _service.isVerifyingIntegrity
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                SettingsPalette.fuchsia,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: SettingsPalette.fuchsia,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Bütünlüğü Doğrula',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: SettingsPalette.textHi,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SettingsPressable(
                  onTap: () {
                    AppHaptics.selection();
                    _service.clearMeshCache();
                    AppHaptics.light();
                  },
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: SettingsPalette.obsidian.withValues(alpha: 0.85),
                      border: Border.all(
                        color: SettingsPalette.titanium.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.cleaning_services_rounded,
                          size: 14,
                          color: SettingsPalette.titanium,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Mesh Önbelleği Boşalt',
                          style: AppTextStyles.captionBold.copyWith(
                            color: SettingsPalette.titanium,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Integrity verification report banner if executed
          if (report != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: report.isAllValid
                    ? SettingsPalette.neon.withValues(alpha: 0.12)
                    : SettingsPalette.ruby.withValues(alpha: 0.15),
                border: Border.all(
                  color: report.isAllValid
                      ? SettingsPalette.neon.withValues(alpha: 0.5)
                      : SettingsPalette.ruby.withValues(alpha: 0.5),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (report.isAllValid ? SettingsPalette.neon : SettingsPalette.ruby)
                        .withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    report.isAllValid ? Icons.check_circle_rounded : Icons.warning_rounded,
                    size: 18,
                    color: report.isAllValid ? SettingsPalette.neon : SettingsPalette.ruby,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${report.validCount}/${report.totalChecked} 3D Varlık doğrulandı (${report.elapsed.inMilliseconds} ms). Apeks/İndeks bütünlüğü geçerli.',
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.textHi,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _categoryLabel(ModelCategory c) => switch (c) {
        ModelCategory.weapon => 'Silahlar',
        ModelCategory.character => 'Karakterler',
        ModelCategory.building => 'Yapılar',
        ModelCategory.natureProp => 'Doğa',
        ModelCategory.dungeonProp => 'Zindan',
      };

  // ---------------------------------------------------------------------------
  // 5. Shader Warm-Up & Pipeline Section
  // ---------------------------------------------------------------------------

  Widget _buildShaderWarmupSection(CombinedDiagnosticsSnapshot snap) {
    final s = snap.shaderStats;
    final warmupResult = _service.lastWarmupResult;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SettingsPalette.navy.withValues(alpha: 0.55),
            SettingsPalette.obsidian.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(
          color: SettingsPalette.coral.withValues(alpha: 0.25),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: SettingsPalette.coral.withValues(alpha: 0.15),
                  border: Border.all(
                    color: SettingsPalette.coral.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'ᛋ PSO PIPELINE',
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.coral,
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.whatshot_rounded,
                size: 16,
                color: SettingsPalette.coral,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'SHADER PİPELİNE VE ISITMA (WARM-UP)',
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Shaders Stats Row
          Row(
            children: <Widget>[
              Expanded(
                child: _buildMetricTile(
                  label: 'Kayıtlı Shader',
                  value: '${s.totalRegistered}',
                  accent: SettingsPalette.gold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Derlenen / Hazır',
                  value: '${s.totalCompiled}',
                  accent: AppColors.accentCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Isıtılan (PSO)',
                  value: '${s.totalWarmedUp}',
                  accent: SettingsPalette.neon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Warm-up Trigger CTA Button
          SettingsPressable(
            enabled: !_service.isWarmingUp,
            onTap: () async {
              AppHaptics.selection();
              await _service.triggerShaderWarmup();
              if (mounted) {
                AppHaptics.success();
              }
            },
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: <Color>[
                    SettingsPalette.coral.withValues(alpha: 0.85),
                    SettingsPalette.gold.withValues(alpha: 0.75),
                  ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: SettingsPalette.coral.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _service.isWarmingUp
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.fireplace_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SHADER WARM-UP ÇALIŞTIR',
                          style: AppTextStyles.captionBold.copyWith(
                            color: Colors.white,
                            fontSize: 12,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Warmup result feedback
          if (warmupResult != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: SettingsPalette.neon.withValues(alpha: 0.12),
                border: Border.all(
                  color: SettingsPalette.neon.withValues(alpha: 0.45),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: SettingsPalette.neon.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: SettingsPalette.neon,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warmupResult.summary,
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.textHi,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. AdaptiveQualityScaler & Dynamic Thermal Tier Section
  // ---------------------------------------------------------------------------

  Widget _buildAdaptiveQualitySection(
    CombinedDiagnosticsSnapshot snap,
    AdaptiveQualityScaler scaler,
  ) {
    final int throttle = scaler.currentThrottleLevel;
    final Color throttleColor = switch (throttle) {
      0 => SettingsPalette.neon,
      1 => SettingsPalette.gold,
      2 => SettingsPalette.coral,
      _ => SettingsPalette.ruby,
    };
    final String throttleText = switch (throttle) {
      0 => 'Nominal (L0)',
      1 => 'Hafif Kısma (L1)',
      2 => 'Orta Kısma (L2)',
      _ => 'Aşırı Kısma (L3)',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SettingsPalette.navy.withValues(alpha: 0.55),
            SettingsPalette.obsidian.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(
          color: SettingsPalette.gold.withValues(alpha: 0.25),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: SettingsPalette.gold.withValues(alpha: 0.15),
                  border: Border.all(
                    color: SettingsPalette.gold.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'ᛏ AQS TIER',
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.gold,
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.auto_graph_rounded,
                size: 16,
                color: SettingsPalette.gold,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ADAPTİF KALİTE VE DİNAMİK TERMAL TİER (AQS)',
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bento Metrics Row
          Row(
            children: <Widget>[
              Expanded(
                child: _buildMetricTile(
                  label: 'Donanım Tier',
                  value: scaler.currentTier.name.toUpperCase(),
                  accent: SettingsPalette.gold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Termal Kısma',
                  value: throttleText,
                  accent: throttleColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'İşleme Ölçeği',
                  value: '${(scaler.currentResolutionScale * 100).toStringAsFixed(0)}%',
                  accent: AppColors.accentCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dynamic Auto-Scaling Toggle using SettingsNeonToggle (Zero invalid Switch properties!)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: SettingsPalette.obsidian.withValues(alpha: 0.7),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.thermostat_rounded,
                  size: 18,
                  color: SettingsPalette.gold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Dinamik Termal & FPS Ölçekleme',
                        style: AppTextStyles.body.copyWith(
                          color: SettingsPalette.textHi,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '60-frame hareketli ortalama ile aşırı ısınma ve FPS düşüş koruması',
                        style: AppTextStyles.caption.copyWith(
                          color: SettingsPalette.titanium,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SettingsNeonToggle(
                  value: scaler.isAutoScalingEnabled,
                  onChanged: (bool enabled) {
                    AppHaptics.selection();
                    scaler.setAutoScaling(enabled);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Events & Stability row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _buildLiveStatusPill(
                label: 'Düşürme: ${scaler.totalDownscaleEvents} Adet',
                color: SettingsPalette.coral,
                icon: Icons.trending_down_rounded,
              ),
              _buildLiveStatusPill(
                label: 'Toparlanma: ${scaler.totalUpscaleEvents} Adet',
                color: SettingsPalette.neon,
                icon: Icons.trending_up_rounded,
              ),
              _buildLiveStatusPill(
                label: 'Hedef: ${scaler.targetFps.toStringAsFixed(0)} FPS (${scaler.targetFrameTimeMs.toStringAsFixed(1)} ms)',
                color: SettingsPalette.titanium,
                icon: Icons.timer_outlined,
              ),
              if (scaler.currentStableDuration.inSeconds > 0)
                _buildLiveStatusPill(
                  label: 'Kararlılık: ${scaler.currentStableDuration.inSeconds} sn',
                  color: AppColors.accentCyan,
                  icon: Icons.hourglass_bottom_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Global Cache Purge Action
  // ---------------------------------------------------------------------------

  Widget _buildCacheActions(CombinedDiagnosticsSnapshot snap) {
    return SettingsOutlineButton(
      label: 'Tüm Önbellekleri Boşalt (RAM, VRAM, Mesh)',
      icon: Icons.delete_sweep_rounded,
      accent: SettingsPalette.coral,
      onPressed: () {
        AppHaptics.heavy();
        final int count = _service.clearAllCaches(forceAll: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tüm önbellekler başarıyla boşaltıldı ($count öğe temizlendi).',
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: SettingsPalette.obsidian,
            ),
          );
        }
      },
    );
  }
}
