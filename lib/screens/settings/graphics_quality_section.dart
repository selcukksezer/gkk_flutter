import '../../core/engine/adaptive_quality_scaler.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_haptics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'graphics_settings_provider.dart';
import 'graphics_settings_service.dart';
import 'graphics_settings_screen.dart';
import 'widgets/settings_design.dart';

/// 2027 Aion-2 Mobile Glassmorphism Graphics Quality Settings Section.
class GraphicsQualitySection extends ConsumerWidget {
  const GraphicsQualitySection({
    super.key,
    this.showAdvancedLink = true,
  });

  final bool showAdvancedLink;

  static const Color cyanAion = Color(0xFF00E5FF);
  static const Color violetAion = Color(0xFFB388FF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(graphicsSettingsProvider);
    final notifier = ref.read(graphicsSettingsProvider.notifier);
    final telemetry = ref.watch(scalerTelemetryProvider);

    return SettingsGlassCard(
      accent: cyanAion,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 1. Header
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      cyanAion.withValues(alpha: 0.35),
                      SettingsPalette.obsidian,
                    ],
                  ),
                  border: Border.all(color: cyanAion.withValues(alpha: 0.5)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: cyanAion.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 18, color: cyanAion),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'GÖRSEL & KALİTE MOTORU',
                      style: AppTextStyles.captionBold.copyWith(
                        color: SettingsPalette.textHi,
                        letterSpacing: 1.0,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aion-2 Impeller · Uyarlamalı Performans Ölçekleyici',
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.titanium,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _TierBadge(tier: config.tier),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),

          // 2. Real-Time Memory & Performance Indicator Bento Card
          _MemoryAndPerfIndicator(config: config, telemetry: telemetry),

          const SizedBox(height: 14),

          // 3. Preset Quality Tier Selector (Eco, Low, Med, High, Ultra)
          Text(
            'KALİTE ÖN AYARI',
            style: AppTextStyles.captionBold.copyWith(
              color: SettingsPalette.titanium,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          _QualityTierSelector(
            currentTier: config.tier,
            onSelect: (tier) async {
              await notifier.setTier(tier);
              await AppHaptics.medium();
            },
          ),

          const SizedBox(height: 16),

          // 4. Target Frame Rate Selector (30 / 60 / 120 FPS)
          Text(
            'HEDEF KARE HIZI (FPS)',
            style: AppTextStyles.captionBold.copyWith(
              color: SettingsPalette.titanium,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          _FpsSelector(
            currentFps: config.targetFps,
            onSelect: (fps) async {
              await notifier.setTargetFps(fps);
              await AppHaptics.selection();
            },
          ),

          const SizedBox(height: 16),

          // 5. Dynamic Resolution Scale Slider
          _ResolutionScaleSlider(
            scale: config.resolutionScale,
            onChanged: (val) async {
              await notifier.setResolutionScale(val);
            },
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),

          // 6. Visual Engine Feature Toggles
          SettingsToggleRow(
            title: 'Dinamik Uyarlamalı Ölçekleyici',
            subtitle: 'FPS düştüğünde çözünürlüğü ve efektleri otomatik düşürür',
            icon: Icons.speed_rounded,
            value: config.autoScalerEnabled,
            onChanged: (val) async {
              await notifier.setAutoScalerEnabled(val);
              await AppHaptics.selection();
            },
          ),

          SettingsToggleRow(
            title: 'Dinamik Gölgeler',
            subtitle: config.shadowsEnabled
                ? '${config.shadowResolution > 0 ? config.shadowResolution : 512}px Kademeli Gölge Haritaları'
                : 'Kapalı (Performans artışı)',
            icon: Icons.wb_sunny_rounded,
            value: config.shadowsEnabled,
            onChanged: (val) async {
              await notifier.setShadowsEnabled(val);
              await AppHaptics.selection();
            },
          ),

          SettingsToggleRow(
            title: 'Volümetrik Sis & Işık Hüzmeleri',
            subtitle: config.volumetricFogEnabled
                ? '${config.volumetricFogSteps > 0 ? config.volumetricFogSteps : 16} Adımlı Işın İlerletmeli Sis'
                : 'Kapalı (Düşük GPU yükü)',
            icon: Icons.cloud_queue_rounded,
            value: config.volumetricFogEnabled,
            onChanged: (val) async {
              await notifier.setVolumetricFogEnabled(val);
              await AppHaptics.selection();
            },
          ),

          SettingsToggleRow(
            title: 'Post-Processing (SSAO & Bloom)',
            subtitle: config.postProcessingEnabled
                ? 'Ortam Karartma (SSAO) ve Rünik Parıltı Etkin'
                : 'Kapalı (Standart Render)',
            icon: Icons.filter_vintage_rounded,
            value: config.postProcessingEnabled,
            onChanged: (val) async {
              await notifier.setPostProcessingEnabled(val);
              await AppHaptics.selection();
            },
          ),

          if (config.postProcessingEnabled) ...<Widget>[
            SettingsToggleRow(
              title: 'Ortam Karartma (SSAO)',
              subtitle: config.ssaoEnabled
                  ? 'Derinlik temelli gerçekçi köşe gölgeleri'
                  : 'Kapalı (Performans kazancı)',
              icon: Icons.blur_on_rounded,
              value: config.ssaoEnabled,
              indent: true,
              onChanged: (val) async {
                await notifier.setSsaoEnabled(val);
                await AppHaptics.selection();
              },
            ),
            SettingsToggleRow(
              title: 'Rünik Parıltı (Bloom)',
              subtitle: config.bloomEnabled
                  ? 'Büyü ve neon ışık parıltısı yayılımı'
                  : 'Kapalı (Standart aydınlatma)',
              icon: Icons.flare_rounded,
              value: config.bloomEnabled,
              indent: true,
              onChanged: (val) async {
                await notifier.setBloomEnabled(val);
                await AppHaptics.selection();
              },
            ),
          ],

          if (showAdvancedLink) ...<Widget>[
            const SizedBox(height: 12),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SettingsPalette.textHi,
                      side: BorderSide(color: cyanAion.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () async {
                      await notifier.resetToRecommended();
                      await AppHaptics.medium();
                    },
                    icon: const Icon(Icons.restart_alt_rounded, size: 16, color: cyanAion),
                    label: Text(
                      'Önerilene Dön',
                      style: AppTextStyles.captionBold.copyWith(color: SettingsPalette.textHi),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cyanAion.withValues(alpha: 0.18),
                      foregroundColor: cyanAion,
                      elevation: 0,
                      side: BorderSide(color: cyanAion.withValues(alpha: 0.7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      AppHaptics.selection();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GraphicsSettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: Text(
                      'Detaylı Ayar',
                      style: AppTextStyles.captionBold.copyWith(color: cyanAion),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});

  final GraphicsQualityTier tier;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label, String rune) = switch (tier) {
      GraphicsQualityTier.eco => (SettingsPalette.neon, 'ECO', '⚡'),
      GraphicsQualityTier.low => (SettingsPalette.titanium, 'LOW', '🛡'),
      GraphicsQualityTier.med => (SettingsPalette.gold, 'MED', '⚖'),
      GraphicsQualityTier.high => (const Color(0xFF00E5FF), 'HIGH', '✦'),
      GraphicsQualityTier.ultra => (const Color(0xFFB388FF), 'ULTRA', '◈'),
      GraphicsQualityTier.custom => (SettingsPalette.coral, 'CUSTOM', '⚙'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            rune,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              color: color,
              fontSize: 10.5,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryAndPerfIndicator extends StatelessWidget {
  const _MemoryAndPerfIndicator({
    required this.config,
    required this.telemetry,
  });

  final GraphicsConfigData config;
  final ScalerTelemetry telemetry;

  @override
  Widget build(BuildContext context) {
    final int ramCap = config.hardwareProfile.totalRamMb;
    final double ramRatio = (config.estimatedRamMb / ramCap).clamp(0.0, 1.0);
    final double vramRatio = (config.estimatedVramMb / (ramCap * 0.4)).clamp(0.0, 1.0);

    final Color ramColor = ramRatio > 0.75
        ? SettingsPalette.ruby
        : ramRatio > 0.50
            ? SettingsPalette.gold
            : SettingsPalette.neon;

    final String resLabel = switch (config.resolutionScale) {
      >= 0.95 => '100% · 1080p',
      >= 0.70 => '75% · 810p',
      _ => '50% · 540p',
    };

    final (Color throttleColor, IconData throttleIcon, String throttleTitle, String throttleDesc) =
        switch (telemetry.throttleLevel) {
      0 => (
          SettingsPalette.neon,
          Icons.ac_unit_rounded,
          'TERMAL SAĞLIK: OPTİMAL (0 KISILMA)',
          'SoC sıcaklığı nominal dengede · Tepe saat frekansları devrede',
        ),
      1 => (
          SettingsPalette.gold,
          Icons.device_thermostat_rounded,
          'TERMAL SAĞLIK: HAFİF KISILMA (L1)',
          'Isı eşiği aşıldı · Otomatik çözünürlük ölçeği dengeleniyor',
        ),
      _ => (
          SettingsPalette.ruby,
          Icons.warning_amber_rounded,
          'TERMAL SAĞLIK: AGRESİF TERMAL KORUMA (L${telemetry.throttleLevel})',
          'Kritik termal bütçe · Efekt adımları ve partikül decimation devrede',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: SettingsPalette.void_.withValues(alpha: 0.65),
        border: Border.all(
          color: GraphicsQualitySection.cyanAion.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header with Live Pulse Indicator
          Row(
            children: <Widget>[
              const Icon(
                Icons.memory_rounded,
                size: 14,
                color: GraphicsQualitySection.cyanAion,
              ),
              const SizedBox(width: 6),
              Text(
                'TAHMİNİ BELLEK VE MOTOR YÜKÜ',
                style: AppTextStyles.captionBold.copyWith(
                  color: SettingsPalette.titanium,
                  letterSpacing: 0.8,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SettingsPalette.neon,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: SettingsPalette.neon.withValues(alpha: 0.8),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                config.tier.badgeDescription,
                style: AppTextStyles.caption.copyWith(
                  color: SettingsPalette.titanium,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // RAM Gauge
          Row(
            children: <Widget>[
              SizedBox(
                width: 70,
                child: Text(
                  'RAM Bütçesi',
                  style: AppTextStyles.caption.copyWith(
                    color: SettingsPalette.textMid,
                    fontSize: 10.5,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ramRatio,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(ramColor),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: Text(
                  '${config.estimatedRamMb} MB / $ramCap MB',
                  textAlign: TextAlign.end,
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // VRAM Gauge
          Row(
            children: <Widget>[
              SizedBox(
                width: 70,
                child: Text(
                  'GPU VRAM',
                  style: AppTextStyles.caption.copyWith(
                    color: SettingsPalette.textMid,
                    fontSize: 10.5,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: vramRatio,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(GraphicsQualitySection.cyanAion),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: Text(
                  '${config.estimatedVramMb} MB VRAM',
                  textAlign: TextAlign.end,
                  style: AppTextStyles.captionBold.copyWith(
                    color: GraphicsQualitySection.cyanAion,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Thermal Throttle Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: throttleColor.withValues(alpha: 0.08),
              border: Border.all(color: throttleColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: <Widget>[
                Icon(throttleIcon, size: 16, color: throttleColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        throttleTitle,
                        style: AppTextStyles.captionBold.copyWith(
                          color: throttleColor,
                          fontSize: 10,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        throttleDesc,
                        style: AppTextStyles.caption.copyWith(
                          color: SettingsPalette.titanium,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Telemetry Strip Bento Chips
          Row(
            children: <Widget>[
              _TelemetryChip(
                icon: Icons.speed_rounded,
                label: telemetry.rollingFps > 0
                    ? '${telemetry.rollingFps.toStringAsFixed(0)} FPS'
                    : 'Hedef ${config.targetFps.toInt()} FPS',
                color: GraphicsQualitySection.cyanAion,
              ),
              const SizedBox(width: 6),
              _TelemetryChip(
                icon: Icons.timer_outlined,
                label: telemetry.rollingAvgFrameTimeMs > 0
                    ? '${telemetry.rollingAvgFrameTimeMs.toStringAsFixed(1)} ms'
                    : '${(1000 / config.targetFps).toStringAsFixed(1)} ms',
                color: SettingsPalette.gold,
              ),
              const SizedBox(width: 6),
              _TelemetryChip(
                icon: Icons.aspect_ratio_rounded,
                label: resLabel,
                color: GraphicsQualitySection.violetAion,
              ),
              const SizedBox(width: 6),
              _TelemetryChip(
                icon: Icons.filter_none_rounded,
                label: telemetry.droppedFramesCount == 0
                    ? '0 Düşüş'
                    : '${telemetry.droppedFramesCount} Kayıp',
                color: telemetry.droppedFramesCount == 0
                    ? SettingsPalette.neon
                    : SettingsPalette.ruby,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TelemetryChip extends StatelessWidget {
  const _TelemetryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 10.5, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.captionBold.copyWith(
                  color: color,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityTierSelector extends StatelessWidget {
  const _QualityTierSelector({
    required this.currentTier,
    required this.onSelect,
  });

  final GraphicsQualityTier currentTier;
  final ValueChanged<GraphicsQualityTier> onSelect;

  static const List<GraphicsQualityTier> tiers = <GraphicsQualityTier>[
    GraphicsQualityTier.eco,
    GraphicsQualityTier.low,
    GraphicsQualityTier.med,
    GraphicsQualityTier.high,
    GraphicsQualityTier.ultra,
  ];

  @override
  Widget build(BuildContext context) {
    final (Color activeColor, IconData activeIcon) = switch (currentTier) {
      GraphicsQualityTier.eco => (SettingsPalette.neon, Icons.battery_charging_full_rounded),
      GraphicsQualityTier.low => (SettingsPalette.titanium, Icons.stay_current_portrait_rounded),
      GraphicsQualityTier.med => (SettingsPalette.gold, Icons.laptop_chromebook_rounded),
      GraphicsQualityTier.high => (GraphicsQualitySection.cyanAion, Icons.desktop_windows_rounded),
      GraphicsQualityTier.ultra => (GraphicsQualitySection.violetAion, Icons.military_tech_rounded),
      GraphicsQualityTier.custom => (SettingsPalette.coral, Icons.tune_rounded),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: tiers.map((tier) {
                final bool isSelected = currentTier == tier;
                final (Color color, IconData icon) = switch (tier) {
                  GraphicsQualityTier.eco => (SettingsPalette.neon, Icons.battery_charging_full_rounded),
                  GraphicsQualityTier.low => (SettingsPalette.titanium, Icons.stay_current_portrait_rounded),
                  GraphicsQualityTier.med => (SettingsPalette.gold, Icons.laptop_chromebook_rounded),
                  GraphicsQualityTier.high => (GraphicsQualitySection.cyanAion, Icons.desktop_windows_rounded),
                  GraphicsQualityTier.ultra => (GraphicsQualitySection.violetAion, Icons.military_tech_rounded),
                  GraphicsQualityTier.custom => (SettingsPalette.coral, Icons.settings_rounded),
                };

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: SettingsPressable(
                      onTap: () => onSelect(tier),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: isSelected
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    color.withValues(alpha: 0.35),
                                    SettingsPalette.obsidian,
                                  ],
                                )
                              : null,
                          color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
                          border: Border.all(
                            color: isSelected
                                ? color.withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.12),
                            width: isSelected ? 1.6 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.38),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              icon,
                              size: 16,
                              color: isSelected ? color : SettingsPalette.titanium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tier.displayName,
                              style: AppTextStyles.captionBold.copyWith(
                                color: isSelected ? SettingsPalette.textHi : SettingsPalette.titanium,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 8),

        // Dynamic Active Tier Target Spec Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: activeColor.withValues(alpha: 0.07),
            border: Border.all(color: activeColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: <Widget>[
              Icon(activeIcon, size: 14, color: activeColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentTier.badgeDescription,
                  style: AppTextStyles.caption.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 10.5,
                  ),
                ),
              ),
              if (currentTier == GraphicsQualityTier.custom)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: SettingsPalette.coral.withValues(alpha: 0.2),
                  ),
                  child: Text(
                    'ÖZEL',
                    style: AppTextStyles.captionBold.copyWith(
                      color: SettingsPalette.coral,
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FpsSelector extends StatelessWidget {
  const _FpsSelector({
    required this.currentFps,
    required this.onSelect,
  });

  final double currentFps;
  final ValueChanged<double> onSelect;

  static const List<double> fpsOptions = <double>[30.0, 60.0, 120.0];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: fpsOptions.map((fps) {
        final bool isSelected = (currentFps - fps).abs() < 1.0;
        final String label = '${fps.toInt()} FPS';
        final String hint = switch (fps.toInt()) {
          30 => 'Tasarruf · 30Hz',
          60 => 'Akıcı · 60Hz',
          _ => 'Aion-2 120Hz',
        };

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: SettingsPressable(
              onTap: () => onSelect(fps),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: isSelected
                      ? LinearGradient(
                          colors: <Color>[
                            GraphicsQualitySection.cyanAion.withValues(alpha: 0.28),
                            SettingsPalette.navy,
                          ],
                        )
                      : null,
                  color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: isSelected
                        ? GraphicsQualitySection.cyanAion.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.1),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: GraphicsQualitySection.cyanAion.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      label,
                      style: AppTextStyles.captionBold.copyWith(
                        color: isSelected
                            ? GraphicsQualitySection.cyanAion
                            : SettingsPalette.textMid,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      hint,
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.titanium,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ResolutionScaleSlider extends StatelessWidget {
  const _ResolutionScaleSlider({
    required this.scale,
    required this.onChanged,
  });

  final double scale;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final int percent = (scale * 100).round();
    final String label = switch (percent) {
      >= 95 => '100% · Native Render (1080p)',
      >= 75 => '$percent% · Dengeli Ölçek (810p)',
      _ => '$percent% · Maksimum FPS (540p)',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'DAHİLİ ÇÖZÜNÜRLÜK ÖLÇEĞİ',
              style: AppTextStyles.captionBold.copyWith(
                color: SettingsPalette.titanium,
                letterSpacing: 0.8,
                fontSize: 11,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: GraphicsQualitySection.cyanAion.withValues(alpha: 0.15),
                border: Border.all(
                  color: GraphicsQualitySection.cyanAion.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                label,
                style: AppTextStyles.captionBold.copyWith(
                  color: GraphicsQualitySection.cyanAion,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: GraphicsQualitySection.cyanAion,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
            thumbColor: SettingsPalette.textHi,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayColor: GraphicsQualitySection.cyanAion.withValues(alpha: 0.2),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: scale.clamp(0.50, 1.00),
            min: 0.50,
            max: 1.00,
            divisions: 10,
            onChanged: (double val) {
              AppHaptics.selection();
              onChanged(val);
            },
          ),
        ),
        const SizedBox(height: 6),

        // Quick Snap Preset Chips
        Row(
          children: <Widget>[
            _ScaleQuickChip(
              targetScale: 0.50,
              currentScale: scale,
              label: '50% Performans · 540p',
              onTap: () {
                AppHaptics.medium();
                onChanged(0.50);
              },
            ),
            const SizedBox(width: 6),
            _ScaleQuickChip(
              targetScale: 0.75,
              currentScale: scale,
              label: '75% Dengeli · 810p',
              onTap: () {
                AppHaptics.medium();
                onChanged(0.75);
              },
            ),
            const SizedBox(width: 6),
            _ScaleQuickChip(
              targetScale: 1.00,
              currentScale: scale,
              label: '100% Yerel · 1080p',
              onTap: () {
                AppHaptics.medium();
                onChanged(1.00);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ScaleQuickChip extends StatelessWidget {
  const _ScaleQuickChip({
    required this.targetScale,
    required this.currentScale,
    required this.label,
    required this.onTap,
  });

  final double targetScale;
  final double currentScale;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = (currentScale - targetScale).abs() < 0.05;
    return Expanded(
      child: SettingsPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: isSelected
                ? GraphicsQualitySection.cyanAion.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: isSelected
                  ? GraphicsQualitySection.cyanAion.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: isSelected ? GraphicsQualitySection.cyanAion : SettingsPalette.titanium,
              fontSize: 9.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

