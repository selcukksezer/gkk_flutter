import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/services/app_haptics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'graphics_quality_section.dart';
import 'graphics_settings_provider.dart';
import 'graphics_settings_service.dart';
import 'services/preloader_diagnostics_service.dart';
import 'widgets/preloader_cache_diagnostics_card.dart';
import 'widgets/settings_design.dart';

/// Fullscreen 2027 Aion-2 Graphics Quality & Adaptive Scaler Screen.
///
/// Responsive 390x844 layout for mobile viewports.
/// Contains fine-grained engine feature tuning, hardware diagnostics, dynamic FPS &
/// resolution scale indicators, zero-jank preset switcher, ZeroJankPreloader diagnostics,
/// and a live performance simulation bench to verify dynamic downscaling & hysteresis recovery.
class GraphicsSettingsScreen extends ConsumerStatefulWidget {
  const GraphicsSettingsScreen({super.key});

  @override
  ConsumerState<GraphicsSettingsScreen> createState() => _GraphicsSettingsScreenState();
}

class _GraphicsSettingsScreenState extends ConsumerState<GraphicsSettingsScreen> {
  static const Color cyanAion = Color(0xFF00E5FF);
  static const Color violetAion = Color(0xFFB388FF);

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(graphicsSettingsProvider);
    final notifier = ref.read(graphicsSettingsProvider.notifier);
    final telemetry = ref.watch(scalerTelemetryProvider);

    return Scaffold(
      extendBody: true,
      body: GameScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              // Top Bar
              _buildTopBar(context, config, telemetry),

              // Scrollable Content
              Expanded(
                child: ListView(
                  padding: GameScrollLayout.withClearance(
                    context,
                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  ),
                  children: <Widget>[
                    // 1. Device Hardware Profile Banner
                    _HardwareProfileHero(
                      profile: config.hardwareProfile,
                      telemetry: telemetry,
                    ),
                    const SizedBox(height: 14),

                    // 2. Dynamic Performance & Resolution Scale Indicators
                    _DynamicPerformanceHero(
                      config: config,
                      telemetry: telemetry,
                    ),
                    const SizedBox(height: 14),

                    // 3. Zero-Jank Quality Preset Switcher
                    _ZeroJankPresetSwitcher(
                      currentTier: config.tier,
                      onSelectTier: (tier) async {
                        await notifier.setTier(tier);
                        await AppHaptics.medium();
                      },
                      scalerTelemetry: telemetry,
                    ),
                    const SizedBox(height: 14),

                    // 4. Primary Graphics Quality Section
                    const GraphicsQualitySection(showAdvancedLink: false),
                    const SizedBox(height: 14),

                    // 5. Fine-Grained Advanced Engine Tuning
                    _AdvancedEngineTuningCard(
                      config: config,
                      notifier: notifier,
                    ),
                    const SizedBox(height: 14),

                    // 6. Live Performance Simulation & Scaler Test Bench
                    _LiveScalerTestBench(
                      notifier: notifier,
                      telemetry: telemetry,
                      config: config,
                    ),
                    const SizedBox(height: 14),

                    // 7. ZeroJankPreloader & Cache Diagnostics Connection
                    const _PreloaderDiagnosticsSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    GraphicsConfigData config,
    ScalerTelemetry telemetry,
  ) {
    final double displayFps = telemetry.rollingFps > 0 ? telemetry.rollingFps : config.targetFps;
    final bool isThrottled = telemetry.throttleLevel > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: SettingsPalette.void_.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: cyanAion.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          SettingsPressable(
            onTap: () {
              AppHaptics.selection();
              Navigator.of(context).pop();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: cyanAion.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: cyanAion),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'GRAFİK VE MOTOR AYARLARI',
                  style: AppTextStyles.titleBold.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Aion-2 AAA Görsel Mimarisi & Uyarlamalı Kalite',
                  style: AppTextStyles.caption.copyWith(
                    color: SettingsPalette.titanium,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          // Live Telemetry Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: (isThrottled ? SettingsPalette.ruby : cyanAion).withValues(alpha: 0.14),
              border: Border.all(
                color: (isThrottled ? SettingsPalette.ruby : cyanAion).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isThrottled ? SettingsPalette.ruby : SettingsPalette.neon,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: (isThrottled ? SettingsPalette.ruby : SettingsPalette.neon).withValues(alpha: 0.8),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${displayFps.toStringAsFixed(0)} FPS · L${telemetry.throttleLevel}',
                  style: AppTextStyles.captionBold.copyWith(
                    color: isThrottled ? SettingsPalette.ruby : SettingsPalette.textHi,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SettingsPressable(
            onTap: () async {
              await ref.read(graphicsSettingsProvider.notifier).resetToRecommended();
              await AppHaptics.medium();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: cyanAion.withValues(alpha: 0.15),
                border: Border.all(color: cyanAion.withValues(alpha: 0.45)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.restart_alt_rounded, size: 13, color: cyanAion),
                  const SizedBox(width: 3),
                  Text(
                    'Önerilen',
                    style: AppTextStyles.captionBold.copyWith(
                      color: cyanAion,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Hardware Profile Diagnostics Hero Card.
class _HardwareProfileHero extends StatelessWidget {
  const _HardwareProfileHero({
    required this.profile,
    required this.telemetry,
  });

  final DeviceHardwareProfile profile;
  final ScalerTelemetry telemetry;

  @override
  Widget build(BuildContext context) {
    final String gpuName = profile.gpuRenderer ?? 'Adreno / Mali GPU';
    final int ramMb = profile.totalRamMb;
    final double refresh = profile.maxRefreshRate;
    final HardwareTier autoTier = profile.autoDetectTier();

    return SettingsGlassCard(
      accent: SettingsPalette.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.devices_other_rounded, size: 16, color: SettingsPalette.gold),
              const SizedBox(width: 8),
              Text(
                'DONANIM VE CİHAZ PROFİLİ',
                style: AppTextStyles.captionBold.copyWith(
                  color: SettingsPalette.textHi,
                  letterSpacing: 0.8,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: SettingsPalette.gold.withValues(alpha: 0.15),
                  border: Border.all(color: SettingsPalette.gold.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${(ramMb / 1024).toStringAsFixed(1)} GB RAM',
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.gold,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  gpuName,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Text(
                  'Tespit: ${autoTier.name.toUpperCase()} Tier',
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.titanium,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _FeatureBadge(
                label: '${refresh.toInt()}Hz Ekran',
                enabled: refresh >= 90,
              ),
              _FeatureBadge(
                label: 'Compute Shaders',
                enabled: profile.supportsComputeShaders,
              ),
              _FeatureBadge(
                label: 'Draco Decompressor',
                enabled: profile.supportsDraco,
              ),
              _FeatureBadge(
                label: 'KTX2 / Basis',
                enabled: profile.supportsKtx2,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color color = enabled ? SettingsPalette.neon : SettingsPalette.titanium;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic Performance & Resolution Scale Indicators Hero Card.
class _DynamicPerformanceHero extends StatelessWidget {
  const _DynamicPerformanceHero({
    required this.config,
    required this.telemetry,
  });

  final GraphicsConfigData config;
  final ScalerTelemetry telemetry;

  static const Color cyanAion = Color(0xFF00E5FF);
  static const Color neonGreen = Color(0xFF00E676);

  @override
  Widget build(BuildContext context) {
    final double displayFps = telemetry.rollingFps > 0 ? telemetry.rollingFps : config.targetFps;
    final double targetFps = config.targetFps;
    final double frameBudgetMs = targetFps > 0 ? (1000.0 / targetFps) : 16.6;

    final Color fpsColor = displayFps >= targetFps * 0.95
        ? neonGreen
        : displayFps >= targetFps * 0.8
            ? SettingsPalette.gold
            : SettingsPalette.ruby;

    final double resScale = telemetry.resolutionScale > 0 ? telemetry.resolutionScale : config.resolutionScale;
    final double savedFillRatePct = math.max(0.0, (1.0 - (resScale * resScale)) * 100.0);

    return SettingsGlassCard(
      accent: cyanAion,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.speed_rounded, size: 16, color: cyanAion),
              const SizedBox(width: 8),
              Text(
                'DİNAMİK PERFORMANS VE ÖLÇEKLEME',
                style: AppTextStyles.captionBold.copyWith(
                  color: SettingsPalette.textHi,
                  letterSpacing: 0.8,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: (telemetry.throttleLevel == 0 ? neonGreen : SettingsPalette.coral).withValues(alpha: 0.15),
                  border: Border.all(
                    color: (telemetry.throttleLevel == 0 ? neonGreen : SettingsPalette.coral).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  telemetry.throttleLevel == 0 ? 'L0 Nominal' : 'L${telemetry.throttleLevel} Kısma Aktif',
                  style: AppTextStyles.captionBold.copyWith(
                    color: telemetry.throttleLevel == 0 ? neonGreen : SettingsPalette.coral,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              // FPS Meter Block
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black.withValues(alpha: 0.35),
                    border: Border.all(color: fpsColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'KARE HIZI (FPS)',
                            style: AppTextStyles.caption.copyWith(
                              color: SettingsPalette.titanium,
                              fontSize: 9.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: fpsColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            displayFps.toStringAsFixed(1),
                            style: AppTextStyles.titleBold.copyWith(
                              color: fpsColor,
                              fontSize: 22,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/ ${targetFps.toInt()} FPS',
                            style: AppTextStyles.caption.copyWith(
                              color: SettingsPalette.titanium,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bütçe: ${frameBudgetMs.toStringAsFixed(1)}ms · ${telemetry.droppedFramesCount} Kayıp',
                        style: AppTextStyles.caption.copyWith(
                          color: SettingsPalette.titanium.withValues(alpha: 0.8),
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Resolution Scale Block
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black.withValues(alpha: 0.35),
                    border: Border.all(color: cyanAion.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'ÇÖZÜNÜRLÜK ÖLÇEĞİ',
                            style: AppTextStyles.caption.copyWith(
                              color: SettingsPalette.titanium,
                              fontSize: 9.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${(resScale * 100).toInt()}%',
                            style: AppTextStyles.captionBold.copyWith(
                              color: cyanAion,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            '${resScale.toStringAsFixed(2)}x',
                            style: AppTextStyles.titleBold.copyWith(
                              color: cyanAion,
                              fontSize: 22,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            resScale >= 1.0 ? 'Doğal' : 'Ölçekli',
                            style: AppTextStyles.caption.copyWith(
                              color: SettingsPalette.titanium,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        savedFillRatePct > 0
                            ? '-${savedFillRatePct.toStringAsFixed(0)}% GPU Doldurma Yükü'
                            : 'Tam Kalite Doğal Piksel',
                        style: AppTextStyles.caption.copyWith(
                          color: savedFillRatePct > 0 ? SettingsPalette.neon : SettingsPalette.titanium.withValues(alpha: 0.8),
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Estimated RAM & VRAM Footprint Mini-Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.memory_rounded, size: 12, color: SettingsPalette.gold),
                    const SizedBox(width: 5),
                    Text(
                      'RAM: ${config.estimatedRamMb} MB',
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.textHi,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 12, color: Colors.white.withValues(alpha: 0.1)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.videogame_asset_rounded, size: 12, color: cyanAion),
                    const SizedBox(width: 5),
                    Text(
                      'VRAM: ${config.estimatedVramMb} MB',
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.textHi,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 12, color: Colors.white.withValues(alpha: 0.1)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      config.autoScalerEnabled ? Icons.bolt_rounded : Icons.pause_rounded,
                      size: 12,
                      color: config.autoScalerEnabled ? SettingsPalette.neon : SettingsPalette.titanium,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      config.autoScalerEnabled ? 'Ölçekleyici Aktif' : 'Ölçekleyici Kapalı',
                      style: AppTextStyles.caption.copyWith(
                        color: config.autoScalerEnabled ? SettingsPalette.neon : SettingsPalette.titanium,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Zero-Jank Quality Preset Switcher Card.
class _ZeroJankPresetSwitcher extends StatelessWidget {
  const _ZeroJankPresetSwitcher({
    required this.currentTier,
    required this.onSelectTier,
    required this.scalerTelemetry,
  });

  final GraphicsQualityTier currentTier;
  final ValueChanged<GraphicsQualityTier> onSelectTier;
  final ScalerTelemetry scalerTelemetry;

  static const Color cyanAion = Color(0xFF00E5FF);
  static const Color violetAion = Color(0xFFB388FF);

  @override
  Widget build(BuildContext context) {
    final tiers = <GraphicsQualityTier>[
      GraphicsQualityTier.eco,
      GraphicsQualityTier.low,
      GraphicsQualityTier.med,
      GraphicsQualityTier.high,
      GraphicsQualityTier.ultra,
    ];

    return SettingsGlassCard(
      accent: violetAion,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: <Color>[
                      violetAion.withValues(alpha: 0.35),
                      SettingsPalette.obsidian,
                    ],
                  ),
                  border: Border.all(color: violetAion.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.bolt_rounded, size: 18, color: violetAion),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'SIFIR-TAKILMA KALİTE ÖN AYARI',
                      style: AppTextStyles.captionBold.copyWith(
                        color: SettingsPalette.textHi,
                        fontSize: 11.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Anlık GPU hat geçişi & otomatik shader ön-ısıtma',
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.titanium,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: SettingsPalette.neon.withValues(alpha: 0.15),
                  border: Border.all(color: SettingsPalette.neon.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.check_circle_outline_rounded, size: 11, color: SettingsPalette.neon),
                    const SizedBox(width: 4),
                    Text(
                      'Hazır',
                      style: AppTextStyles.captionBold.copyWith(
                        color: SettingsPalette.neon,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Tier Buttons Row
          Row(
            children: tiers.map((tier) {
              final bool isSelected = currentTier == tier;
              final Color tierAccent = switch (tier) {
                GraphicsQualityTier.eco => SettingsPalette.gold,
                GraphicsQualityTier.low => SettingsPalette.coral,
                GraphicsQualityTier.med => cyanAion,
                GraphicsQualityTier.high => violetAion,
                GraphicsQualityTier.ultra => SettingsPalette.fuchsia,
                GraphicsQualityTier.custom => SettingsPalette.titanium,
              };

              final String specLabel = switch (tier) {
                GraphicsQualityTier.eco => '30FPS · 0.5x',
                GraphicsQualityTier.low => '30FPS · .75x',
                GraphicsQualityTier.med => '60FPS · 1.0x',
                GraphicsQualityTier.high => '60FPS · SSAO',
                GraphicsQualityTier.ultra => '120FPS · AAA',
                GraphicsQualityTier.custom => 'Özel',
              };

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: SettingsPressable(
                    onTap: () {
                      AppHaptics.medium();
                      onSelectTier(tier);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isSelected
                            ? tierAccent.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: isSelected
                              ? tierAccent.withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.08),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: tierAccent.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            tier.displayName,
                            style: AppTextStyles.captionBold.copyWith(
                              color: isSelected ? SettingsPalette.textHi : SettingsPalette.titanium,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            specLabel,
                            style: AppTextStyles.caption.copyWith(
                              color: isSelected ? tierAccent : SettingsPalette.titanium.withValues(alpha: 0.6),
                              fontSize: 8.5,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          // Active Preset Description Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black.withValues(alpha: 0.25),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.info_outline_rounded, size: 13, color: violetAion),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    currentTier.badgeDescription,
                    style: AppTextStyles.caption.copyWith(
                      color: SettingsPalette.textHi,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Advanced Fine-Grained Engine Tuning Card.
class _AdvancedEngineTuningCard extends StatelessWidget {
  const _AdvancedEngineTuningCard({
    required this.config,
    required this.notifier,
  });

  final GraphicsConfigData config;
  final GraphicsSettingsNotifier notifier;

  static const Color cyanAion = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    final quality = config.qualitySettings;

    return SettingsGlassCard(
      accent: SettingsPalette.fuchsia,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SettingsSectionHeader(
            icon: Icons.tune_rounded,
            title: 'İNCE MOTOR AYARLARI',
            subtitle: 'Gölge haritaları, volümetrik ışık adımları ve SSAO',
            accent: SettingsPalette.fuchsia,
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),

          // Shadow Resolution Selector
          Text(
            'KADEMELİ GÖLGE ÇÖZÜNÜRLÜĞÜ',
            style: AppTextStyles.captionBold.copyWith(
              color: SettingsPalette.titanium,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <int>[0, 512, 1024, 2048].map((res) {
              final bool isSelected = config.shadowsEnabled && config.shadowResolution == res;
              final String label = res == 0 ? 'Kapalı' : '${res}px';

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: SettingsPressable(
                    onTap: () async {
                      if (res == 0) {
                        await notifier.setShadowsEnabled(false);
                      } else {
                        final SharedPreferences prefs = await SharedPreferences.getInstance();
                        await prefs.setInt(GraphicsSettingsService.keyShadowRes, res);
                        await prefs.setBool(GraphicsSettingsService.keyShadows, true);
                        await prefs.setString(GraphicsSettingsService.keyTier, GraphicsQualityTier.custom.name);
                        await GraphicsSettingsService.instance.load();
                      }
                      await AppHaptics.selection();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isSelected
                            ? SettingsPalette.fuchsia.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: isSelected
                              ? SettingsPalette.fuchsia.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: AppTextStyles.captionBold.copyWith(
                            color: isSelected ? SettingsPalette.textHi : SettingsPalette.titanium,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // Volumetric Fog Steps
          Text(
            'VOLÜMETRİK SİS IŞIN ADIMLARI',
            style: AppTextStyles.captionBold.copyWith(
              color: SettingsPalette.titanium,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <int>[0, 4, 16, 32, 64].map((steps) {
              final bool isSelected = config.volumetricFogEnabled && config.volumetricFogSteps == steps;
              final String label = steps == 0 ? 'Kapalı' : '$steps Adım';

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: SettingsPressable(
                    onTap: () async {
                      if (steps == 0) {
                        await notifier.setVolumetricFogEnabled(false);
                      } else {
                        final SharedPreferences prefs = await SharedPreferences.getInstance();
                        await prefs.setInt(GraphicsSettingsService.keyFogSteps, steps);
                        await prefs.setBool(GraphicsSettingsService.keyFog, true);
                        await prefs.setString(GraphicsSettingsService.keyTier, GraphicsQualityTier.custom.name);
                        await GraphicsSettingsService.instance.load();
                      }
                      await AppHaptics.selection();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isSelected
                            ? cyanAion.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: isSelected
                              ? cyanAion.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: AppTextStyles.captionBold.copyWith(
                            color: isSelected ? SettingsPalette.textHi : SettingsPalette.titanium,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),

          // SSAO Sub-Toggle
          SettingsToggleRow(
            title: 'Ortam Karartma (SSAO)',
            subtitle: 'Nesne köşelerinde gerçekçi derinlik gölgeleri oluşturur',
            icon: Icons.grain_rounded,
            value: config.ssaoEnabled && config.postProcessingEnabled,
            onChanged: (val) async {
              await notifier.setSsaoEnabled(val);
              await AppHaptics.selection();
            },
          ),

          // Bloom Sub-Toggle
          SettingsToggleRow(
            title: 'Rünik Parlama & Bloom',
            subtitle: 'Büyü efektleri ve rünlerde sinematik ışık sızıntısı',
            icon: Icons.flare_rounded,
            value: config.bloomEnabled && config.postProcessingEnabled,
            onChanged: (val) async {
              await notifier.setBloomEnabled(val);
              await AppHaptics.selection();
            },
          ),

          // Dynamic Auto-Scaler Switch
          SettingsToggleRow(
            title: 'Otomatik Uyarlamalı Ölçekleyici',
            subtitle: 'Kare hızı düştüğünde çözünürlüğü ve efektleri dinamik kısar',
            icon: Icons.auto_mode_rounded,
            value: config.autoScalerEnabled,
            onChanged: (val) async {
              await notifier.setAutoScalerEnabled(val);
              await AppHaptics.selection();
            },
          ),

          const SizedBox(height: 8),

          // Crowd Density & Particles Stats
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black.withValues(alpha: 0.3),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _StatColumn(
                  label: 'Partikül Limiti',
                  value: '${quality.maxActiveParticles}',
                  color: SettingsPalette.gold,
                ),
                _StatColumn(
                  label: 'Kalabalık Sınırı',
                  value: '${quality.crowdDensityCap} Oyuncu',
                  color: cyanAion,
                ),
                _StatColumn(
                  label: 'LOD Mesafesi',
                  value: '${quality.lodDistanceMultiplier}x',
                  color: SettingsPalette.neon,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: SettingsPalette.titanium,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.captionBold.copyWith(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Live Performance Simulation Bench & Scaler Telemetry HUD.
class _LiveScalerTestBench extends StatefulWidget {
  const _LiveScalerTestBench({
    required this.notifier,
    required this.telemetry,
    required this.config,
  });

  final GraphicsSettingsNotifier notifier;
  final ScalerTelemetry telemetry;
  final GraphicsConfigData config;

  @override
  State<_LiveScalerTestBench> createState() => _LiveScalerTestBenchState();
}

class _LiveScalerTestBenchState extends State<_LiveScalerTestBench> {
  static const Color cyanAion = Color(0xFF00E5FF);
  late List<double> _waveformSamples;

  @override
  void initState() {
    super.initState();
    _initWaveformSamples();
  }

  void _initWaveformSamples() {
    final double targetMs = widget.config.targetFps > 0 ? (1000.0 / widget.config.targetFps) : 16.6;
    _waveformSamples = List<double>.generate(
      60,
      (i) => (targetMs + ((i % 7 == 0) ? 1.2 : (i % 3 == 0) ? -0.8 : 0.2)).clamp(5.0, 50.0),
    );
  }

  void _recordSample(double ms) {
    if (_waveformSamples.length >= 60) {
      _waveformSamples.removeAt(0);
    }
    _waveformSamples.add(ms);
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.telemetry;
    final config = widget.config;
    final double targetFrameTimeMs = config.targetFps > 0 ? (1000.0 / config.targetFps) : 16.6;
    final double thresholdMs = targetFrameTimeMs * 1.15; // Threshold where scaler starts tracking drop

    // Stability fraction towards 5.0 seconds hysteresis ceiling
    final double stabilitySeconds = telemetry.stableUnderThresholdDuration.inMilliseconds / 1000.0;
    final double stabilityFraction = (stabilitySeconds / 5.0).clamp(0.0, 1.0);

    return SettingsGlassCard(
      accent: SettingsPalette.neon,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SettingsSectionHeader(
            icon: Icons.analytics_rounded,
            title: 'CANLI ÖLÇEKLEYİCİ TELEMETRİSİ',
            subtitle: '60 karelik kayan pencere & histerezis toparlanma testi',
            accent: SettingsPalette.neon,
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),

          // Waveform Header & Legend
          Row(
            children: <Widget>[
              Text(
                '60-KARELİK PACING DALGA FORMU',
                style: AppTextStyles.captionBold.copyWith(
                  color: SettingsPalette.titanium,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: cyanAion, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 3),
                  Text('<=Hedef', style: AppTextStyles.caption.copyWith(color: cyanAion, fontSize: 9)),
                  const SizedBox(width: 8),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: SettingsPalette.gold, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 3),
                  Text('Eşik', style: AppTextStyles.caption.copyWith(color: SettingsPalette.gold, fontSize: 9)),
                  const SizedBox(width: 8),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: SettingsPalette.ruby, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 3),
                  Text('Düşüş', style: AppTextStyles.caption.copyWith(color: SettingsPalette.ruby, fontSize: 9)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Custom Painted Waveform Box
          Container(
            height: 85,
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black.withValues(alpha: 0.5),
              border: Border.all(color: SettingsPalette.neon.withValues(alpha: 0.25)),
            ),
            child: CustomPaint(
              painter: _FramePacingWaveformPainter(
                frameTimes: _waveformSamples,
                targetFrameTimeMs: targetFrameTimeMs,
                thresholdFrameTimeMs: thresholdMs,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Telemetry Stats Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(color: SettingsPalette.neon.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _TeleCell(
                      label: 'Kayan FPS',
                      value: telemetry.rollingFps > 0
                          ? telemetry.rollingFps.toStringAsFixed(1)
                          : config.targetFps.toStringAsFixed(1),
                      color: SettingsPalette.neon,
                    ),
                    _TeleCell(
                      label: 'Ortalama Süre',
                      value: telemetry.rollingAvgFrameTimeMs > 0
                          ? '${telemetry.rollingAvgFrameTimeMs.toStringAsFixed(1)}ms'
                          : '${targetFrameTimeMs.toStringAsFixed(1)}ms',
                      color: cyanAion,
                    ),
                    _TeleCell(
                      label: 'P95 Gecikme',
                      value: telemetry.p95FrameTimeMs > 0
                          ? '${telemetry.p95FrameTimeMs.toStringAsFixed(1)}ms'
                          : '${targetFrameTimeMs.toStringAsFixed(1)}ms',
                      color: SettingsPalette.gold,
                    ),
                    _TeleCell(
                      label: 'Jitter (StdDev)',
                      value: telemetry.jitterStandardDeviationMs > 0
                          ? '${telemetry.jitterStandardDeviationMs.toStringAsFixed(1)}ms'
                          : '0.4ms',
                      color: cyanAion,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: Colors.white.withValues(alpha: 0.06), height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _TeleCell(
                      label: 'Gaz Seviyesi',
                      value: 'L${telemetry.throttleLevel}',
                      color: telemetry.throttleLevel == 0 ? SettingsPalette.neon : SettingsPalette.ruby,
                    ),
                    _TeleCell(
                      label: 'Kayıp Kareler',
                      value: '${telemetry.droppedFramesCount}',
                      color: telemetry.droppedFramesCount == 0 ? SettingsPalette.titanium : SettingsPalette.ruby,
                    ),
                    _TeleCell(
                      label: 'Düşürme Olayı',
                      value: '${telemetry.totalDownscaleEvents}',
                      color: SettingsPalette.coral,
                    ),
                    _TeleCell(
                      label: 'Yükseltme Olayı',
                      value: '${telemetry.totalUpscaleEvents}',
                      color: SettingsPalette.neon,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Hysteresis Upscale Recovery Monitor
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: (telemetry.throttleLevel > 0 ? SettingsPalette.coral : SettingsPalette.neon).withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          telemetry.throttleLevel > 0 ? Icons.timer_rounded : Icons.verified_rounded,
                          size: 13,
                          color: telemetry.throttleLevel > 0 ? SettingsPalette.coral : SettingsPalette.neon,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          telemetry.throttleLevel > 0
                              ? 'HİSTEREZİS TOPARLANMA SAYACI'
                              : 'PERFORMANS DURUMU: NOMİNAL',
                          style: AppTextStyles.captionBold.copyWith(
                            color: telemetry.throttleLevel > 0 ? SettingsPalette.coral : SettingsPalette.neon,
                            fontSize: 10,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      telemetry.throttleLevel > 0
                          ? '${stabilitySeconds.toStringAsFixed(1)}s / 5.0s'
                          : 'Toparlanma Gerekmiyor',
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.titanium,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
                if (telemetry.throttleLevel > 0) ...<Widget>[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stabilityFraction,
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        stabilityFraction >= 1.0 ? SettingsPalette.neon : SettingsPalette.coral,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '5 saniye boyunca kesintisiz <=${thresholdMs.toStringAsFixed(1)}ms frame süresi sağlandığında L${telemetry.throttleLevel - 1} seviyesine çıkılır.',
                    style: AppTextStyles.caption.copyWith(
                      color: SettingsPalette.titanium.withValues(alpha: 0.8),
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Simulation Actions
          Text(
            'BENCHMARK VE STRES SİMÜLASYONU',
            style: AppTextStyles.captionBold.copyWith(
              color: SettingsPalette.titanium,
              fontSize: 10.5,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SettingsPalette.ruby.withValues(alpha: 0.2),
                    foregroundColor: SettingsPalette.ruby,
                    elevation: 0,
                    side: BorderSide(color: SettingsPalette.ruby.withValues(alpha: 0.6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () {
                    AppHaptics.heavy();
                    // Feed 35 heavy frames (45ms = 22 FPS) to trigger dynamic downscale
                    for (int i = 0; i < 35; i++) {
                      widget.notifier.recordFrameTelemetry(45.0);
                      _recordSample(45.0);
                    }
                    setState(() {});
                  },
                  icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                  label: Text(
                    'Kare Düşüşü Simüle Et',
                    style: AppTextStyles.captionBold.copyWith(
                      color: SettingsPalette.ruby,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SettingsPalette.neon.withValues(alpha: 0.18),
                    foregroundColor: SettingsPalette.neon,
                    elevation: 0,
                    side: BorderSide(color: SettingsPalette.neon.withValues(alpha: 0.6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () {
                    AppHaptics.selection();
                    // Feed 60 smooth frames (12ms = 83 FPS) to trigger upscale
                    final startTime = DateTime.now().subtract(const Duration(seconds: 6));
                    for (int i = 0; i < 60; i++) {
                      GraphicsSettingsService.instance.scaler.recordFrameTime(
                        12.0,
                        timestamp: startTime.add(Duration(milliseconds: i * 100)),
                      );
                      _recordSample(12.0);
                    }
                    setState(() {});
                  },
                  icon: const Icon(Icons.arrow_upward_rounded, size: 14),
                  label: Text(
                    'Toparlanma Simüle Et',
                    style: AppTextStyles.captionBold.copyWith(
                      color: SettingsPalette.neon,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: SettingsPressable(
              onTap: () {
                AppHaptics.medium();
                GraphicsSettingsService.instance.scaler.frameTracker.reset();
                _initWaveformSamples();
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.refresh_rounded, size: 12, color: SettingsPalette.titanium),
                    const SizedBox(width: 4),
                    Text(
                      'Dalga Formu ve Telemetriyi Sıfırla',
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.titanium,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeleCell extends StatelessWidget {
  const _TeleCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: SettingsPalette.titanium,
            fontSize: 9.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.captionBold.copyWith(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the 60-frame moving window frame pacing waveform.
class _FramePacingWaveformPainter extends CustomPainter {
  const _FramePacingWaveformPainter({
    required this.frameTimes,
    required this.targetFrameTimeMs,
    required this.thresholdFrameTimeMs,
  });

  final List<double> frameTimes;
  final double targetFrameTimeMs;
  final double thresholdFrameTimeMs;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Paint bgPaint = Paint()..color = const Color(0xFF090D16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      bgPaint,
    );

    double maxTime = 42.0;
    for (final t in frameTimes) {
      if (t > maxTime) maxTime = t;
    }
    maxTime = math.max(maxTime, targetFrameTimeMs * 2.2);

    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Target frame line
    final double targetY = size.height - (targetFrameTimeMs / maxTime * size.height).clamp(0.0, size.height);
    linePaint.color = const Color(0xFF00E676).withValues(alpha: 0.6);
    canvas.drawLine(Offset(0, targetY), Offset(size.width, targetY), linePaint);

    // Downscale threshold line
    if (thresholdFrameTimeMs > 0) {
      final double thresholdY = size.height - (thresholdFrameTimeMs / maxTime * size.height).clamp(0.0, size.height);
      linePaint.color = const Color(0xFFFFD54F).withValues(alpha: 0.6);
      canvas.drawLine(Offset(0, thresholdY), Offset(size.width, thresholdY), linePaint);
    }

    if (frameTimes.isEmpty) return;

    final int count = frameTimes.length;
    final double barWidth = (size.width / 60.0).clamp(2.0, 8.0);
    final double step = size.width / math.max(1, count);

    for (int i = 0; i < count; i++) {
      final double time = frameTimes[i];
      final double barHeight = (time / maxTime * size.height).clamp(3.0, size.height);
      final double x = i * step;
      final double y = size.height - barHeight;

      Color barColor;
      if (time <= targetFrameTimeMs * 1.05) {
        barColor = const Color(0xFF00E5FF);
      } else if (time <= thresholdFrameTimeMs * 1.05) {
        barColor = const Color(0xFFFFD54F);
      } else {
        barColor = const Color(0xFFFF1744);
      }

      final Paint barPaint = Paint()..color = barColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, math.min(barWidth, step - 0.5), barHeight),
          const Radius.circular(1.5),
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FramePacingWaveformPainter oldDelegate) {
    return oldDelegate.frameTimes != frameTimes ||
        oldDelegate.targetFrameTimeMs != targetFrameTimeMs ||
        oldDelegate.thresholdFrameTimeMs != thresholdFrameTimeMs;
  }
}

/// ZeroJankPreloader & Asset/Shader Cache Diagnostics Accordion Section.
class _PreloaderDiagnosticsSection extends StatefulWidget {
  const _PreloaderDiagnosticsSection();

  @override
  State<_PreloaderDiagnosticsSection> createState() => _PreloaderDiagnosticsSectionState();
}

class _PreloaderDiagnosticsSectionState extends State<_PreloaderDiagnosticsSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SettingsPressable(
          onTap: () {
            AppHaptics.selection();
            setState(() => _isExpanded = !_isExpanded);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: SettingsPalette.void_.withValues(alpha: 0.75),
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: _isExpanded ? 0.45 : 0.2),
              ),
              boxShadow: _isExpanded
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppColors.accentCyan.withValues(alpha: 0.12),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: AppColors.accentCyan.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.hub_rounded, size: 16, color: AppColors.accentCyan),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'ZERO-JANK PRELOADER & ÖNBELLEK TEŞHİSİ',
                        style: AppTextStyles.captionBold.copyWith(
                          color: SettingsPalette.textHi,
                          letterSpacing: 0.8,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '3D CC0 Mesh önbelleği, Impeller gölgelendirici ısıtma ve bellek tavanı',
                        style: AppTextStyles.caption.copyWith(
                          color: SettingsPalette.titanium,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.accentCyan,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...<Widget>[
          const SizedBox(height: 10),
          const PreloaderCacheDiagnosticsCard(autoStartPolling: true),
        ],
      ],
    );
  }
}
