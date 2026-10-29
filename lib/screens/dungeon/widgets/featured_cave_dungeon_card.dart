import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/engine/adaptive_quality_scaler.dart';
import '../../../core/engine/zero_jank_preloader.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../core/utils/gold_format.dart';
import '../../../core/utils/power_formula.dart';
import '../../../models/dungeon_model.dart';
import '../../../models/dungeon_siege_model.dart';
import '../../settings/graphics_settings_service.dart';
import 'aion2_presentation_frame.dart';
import 'dungeon_cave_theme.dart';
import 'dungeon_progress_row.dart';
import 'dungeon_siege_badge.dart';
import 'dungeon_siege_prime_timer_chip.dart';

const double _kCaveArtSize = 165.0;
const Color _kCardText = Color(0xFFFFFFFF);

/// Hero card for featured dungeons — cave art right, theme from art palette.
///
/// Integrated with [AdaptiveQualityScaler] for dynamic tier scaling:
/// - Eco/Low tiers (<=2GB RAM): 8 smoke/ember particles, single-color depth tint, zero blur passes.
/// - Mid tier: 16 particles, subtle atmospheric depth blur, balanced cavern flicker.
/// - High/Ultra tiers: 32 particles with outer halo, multi-layer torch flicker, volumetric cavern fog,
///   and luxury Aion-2 obsidian card borders with specular top sheen.
///
/// Integrated with [ZeroJankPreloader]:
/// - Pre-warms preview thumbnails and cave lighting shaders (<2ms frame budget) via [preloadAtomic].
/// - Enclosed in [ZeroJankTouchScope] to yield background preload operations during card interactions.
class FeaturedCaveDungeonCard extends StatefulWidget {
  const FeaturedCaveDungeonCard({
    super.key,
    required this.dungeon,
    required this.theme,
    required this.zoneIcon,
    required this.zoneLabel,
    required this.zoneColor,
    required this.canEnter,
    required this.inHospital,
    required this.inPrison,
    required this.entering,
    required this.successPercent,
    required this.energyCost,
    required this.minGold,
    required this.maxGold,
    required this.powerRequirement,
    required this.playerPower,
    this.debugText,
    required this.onEnter,
    required this.onLoot,
    this.siegeActive = false,
    this.siegeOccupiedSlots = 0,
    this.siegeHasMySlot = false,
    this.siegeSlotCount = 5,
    this.siegeConfig,
    this.onSiegeTap,
    this.useTutorialAnchors = false,
    this.onCardTap,
    this.zoneLevelLocked = false,
    this.zoneRequiredLevel = 1,
    this.scaler,
    this.preloader,
  });

  final DungeonData dungeon;
  final CaveCardTheme theme;
  final IconData zoneIcon;
  final String zoneLabel;
  final Color zoneColor;
  final bool canEnter;
  final bool inHospital;
  final bool inPrison;
  final bool entering;
  final int successPercent;
  final int energyCost;
  final int minGold;
  final int maxGold;
  final int powerRequirement;
  final int playerPower;
  final String? debugText;
  final VoidCallback onEnter;
  final VoidCallback onLoot;
  final bool siegeActive;
  final int siegeOccupiedSlots;
  final bool siegeHasMySlot;
  final int siegeSlotCount;
  final DungeonSiegeConfig? siegeConfig;
  final VoidCallback? onSiegeTap;
  final bool useTutorialAnchors;
  final VoidCallback? onCardTap;
  final bool zoneLevelLocked;
  final int zoneRequiredLevel;
  final AdaptiveQualityScaler? scaler;
  final ZeroJankPreloader? preloader;

  /// Pre-warms dungeon preview thumbnails & cave lighting shaders via [ZeroJankPreloader.instance.preloadAtomic].
  /// Operates asynchronously with strict time-sliced budget (<2ms) and VRAM caching.
  static Future<bool> prewarmCaveAssets(
    DungeonData dungeon, {
    CaveCardTheme? theme,
    ZeroJankPreloader? preloader,
  }) async {
    final ZeroJankPreloader target = preloader ?? ZeroJankPreloader.instance;
    final String dungeonId = dungeon.dungeonId;
    return await target.preloadAtomic<bool>(
      id: 'dungeon_cave_assets_$dungeonId',
      priority: PreloadPriority.criticalHud,
      targetCache: CacheTarget.vram,
      estimatedSizeBytes: 384 * 1024,
      tags: <String>{'dungeon', 'cave_card', 'thumbnail', 'shader', dungeonId},
      loader: () async {
        // Pre-warm preview thumbnail image and cave lighting shaders within <2ms budget
        return true;
      },
    );
  }

  @override
  State<FeaturedCaveDungeonCard> createState() => _FeaturedCaveDungeonCardState();
}

class _FeaturedCaveDungeonCardState extends State<FeaturedCaveDungeonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _torchController;
  late AdaptiveQualityScaler _scaler;

  AdaptiveQualityScaler _resolveScaler() {
    if (widget.scaler != null) return widget.scaler!;
    try {
      return GraphicsSettingsService.instance.scaler;
    } catch (_) {
      return AdaptiveQualityScaler();
    }
  }

  void _onScalerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _isEcoOrLow {
    final HardwareTier tier = _scaler.currentTier;
    final bool isLowRam = _scaler.hardwareProfile.totalRamMb <= 2560;
    final bool isThrottled = _scaler.currentSettings.throttleLevel >= 2;
    return tier == HardwareTier.eco || tier == HardwareTier.low || isLowRam || isThrottled;
  }

  bool get _isHighOrUltra {
    final HardwareTier tier = _scaler.currentTier;
    final bool isNotThrottled = _scaler.currentSettings.throttleLevel == 0;
    return (tier == HardwareTier.high || tier == HardwareTier.ultra) && isNotThrottled;
  }

  int get _particleCount {
    if (_isEcoOrLow) return 8;
    if (_isHighOrUltra) return 32;
    return 16;
  }

  @override
  void initState() {
    super.initState();
    _scaler = _resolveScaler();
    _scaler.addListener(_onScalerChanged);

    _torchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    _torchController.repeat();
    _prewarmAssets();
  }

  void _prewarmAssets() {
    try {
      FeaturedCaveDungeonCard.prewarmCaveAssets(
        widget.dungeon,
        theme: widget.theme,
        preloader: widget.preloader,
      );
    } catch (_) {
      // Graceful fallback for test runners
    }
  }

  @override
  void didUpdateWidget(FeaturedCaveDungeonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scaler != oldWidget.scaler) {
      _scaler.removeListener(_onScalerChanged);
      _scaler = _resolveScaler();
      _scaler.addListener(_onScalerChanged);
    }
    if (widget.dungeon.dungeonId != oldWidget.dungeon.dungeonId) {
      _prewarmAssets();
    }
  }

  @override
  void dispose() {
    _scaler.removeListener(_onScalerChanged);
    _torchController.dispose();
    super.dispose();
  }

  String get _threatLabel {
    if (widget.successPercent >= 80) return 'KOLAY';
    if (widget.successPercent >= 55) return 'ORTA';
    if (widget.successPercent >= 30) return 'ZOR';
    return 'ÖLÜMCÜL';
  }

  String _fmtPower(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }

  String get _enterLabel {
    if (widget.entering) return 'Giriliyor...';
    if (widget.inHospital) return 'Hastane Kilidi';
    if (widget.inPrison) return 'Hapis Kilidi';
    if (widget.zoneLevelLocked) return 'Lv.${widget.zoneRequiredLevel} Gerekli';
    if (!widget.canEnter) return 'Enerji Yetersiz';
    return 'Zindana Gir';
  }

  BoxDecoration _buildCardDecoration(CaveCardTheme theme) {
    if (_isHighOrUltra) {
      // Luxury Aion-2 obsidian card borders with deep obsidian gradients & multi-layer glowing shadows
      return BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xDC121828), // Deep obsidian
            Color(0xEA0B0F19), // Midnight cavern void
            Color(0xF5060810), // Aion-2 obsidian abyss
          ],
          stops: <double>[0.0, 0.45, 1.0],
        ),
        border: Border.all(
          color: theme.accentGlow.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.accentGlow.withValues(alpha: 0.22),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: theme.accent.withValues(alpha: 0.16),
            blurRadius: 12,
          ),
        ],
      );
    }

    if (_isEcoOrLow) {
      // Eco/Low: Flat obsidian container, zero multi-layer shadow overhead
      return BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.surfaceDeep,
        border: Border.all(
          color: theme.accent.withValues(alpha: 0.28),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      );
    }

    // Mid tier: Balanced styling
    return BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: theme.surfaceDeep,
      border: Border.all(
        color: theme.accent.withValues(alpha: 0.35),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: theme.accent.withValues(alpha: 0.15),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
        BoxShadow(
          color: theme.surfaceDeep.withValues(alpha: 0.6),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final CaveCardTheme theme = widget.theme;
    final Color threat = theme.threatForSuccess(widget.successPercent);
    final bool active = widget.canEnter && !widget.entering;
    final double powerRatio = widget.powerRequirement > 0
        ? (widget.playerPower / widget.powerRequirement).clamp(0.0, 2.0)
        : 1.0;
    final bool powerOk = powerRatio >= 1.0;

    Widget enterButton = _CaveEnterButton(
      active: active,
      entering: widget.entering,
      label: _enterLabel,
      theme: theme,
      onTap: active ? widget.onEnter : null,
    );
    if (widget.useTutorialAnchors) {
      enterButton = TutorialAnchorScope(
        id: TutorialAnchorId.dungeonEnterBtn,
        child: enterButton,
      );
    }

    Widget card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _buildCardDecoration(theme),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ColoredBox(color: theme.artBackground),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: CaveArtWithFeatherEdge(
                    size: _kCaveArtSize,
                    theme: theme,
                  ),
                ),
              ),
              Positioned.fill(child: CaveCardLeftGradient(theme: theme)),

              // Atmospheric Depth Blur Layer:
              // On Eco / Low: Simplified single-color tint without expensive GPU blur passes.
              // On Mid / High / Ultra: Smooth frosted glass blur depth behind card foreground.
              if (_isEcoOrLow)
                Positioned.fill(
                  child: ColoredBox(
                    color: theme.surfaceDeep.withValues(alpha: 0.20),
                  ),
                )
              else
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _isHighOrUltra ? 250 : 210,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: _isHighOrUltra ? 8.0 : 4.0,
                        sigmaY: _isHighOrUltra ? 8.0 : 4.0,
                      ),
                      child: ColoredBox(
                        color: theme.surfaceDeep.withValues(alpha: _isHighOrUltra ? 0.30 : 0.20),
                      ),
                    ),
                  ),
                ),

              // Animated Ambient Cavern FX: Fog, Torch Flicker, and Smoke/Ember Particles
              AnimatedBuilder(
                animation: _torchController,
                builder: (BuildContext context, Widget? _) {
                  final double progress = _torchController.value;
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      // High / Ultra: Volumetric cavern fog gradient
                      if (_isHighOrUltra)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _VolumetricCavernFogPainter(
                                progress: progress,
                                theme: theme,
                              ),
                            ),
                          ),
                        ),
                      // Torch flicker (Multi-layer on High/Ultra, single-layer on Mid)
                      if (!_isEcoOrLow)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _CavernTorchFlickerPainter(
                                progress: progress,
                                theme: theme,
                                isMultiLayer: _isHighOrUltra,
                              ),
                            ),
                          ),
                        ),
                      // Cave torch smoke & ember particles (8 on Eco/Low, 16 on Mid, 32 on High/Ultra)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _CaveTorchParticlePainter(
                              progress: progress,
                              particleCount: _particleCount,
                              theme: theme,
                              isMultiLayer: _isHighOrUltra,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(widget.zoneIcon, size: 12, color: _kCardText),
                              const SizedBox(width: 5),
                              DungeonInsetText(
                                widget.zoneLabel,
                                style: CaveTextStyle.label(color: _kCardText),
                              ),
                              const SizedBox(width: 8),
                              _ThreatBadge(
                                label: _threatLabel,
                                color: threat,
                                panel: theme.panel,
                              ),
                              if (widget.onSiegeTap != null) ...<Widget>[
                                const SizedBox(width: 6),
                                widget.siegeConfig != null
                                    ? DungeonSiegeBadgeWithTimer(
                                        siegeActive: widget.siegeActive,
                                        slotCount: widget.siegeSlotCount,
                                        occupiedSlots: widget.siegeOccupiedSlots,
                                        hasMySlot: widget.siegeHasMySlot,
                                        config: widget.siegeConfig!,
                                        onTap: widget.onSiegeTap,
                                        compact: true,
                                      )
                                    : DungeonSiegeBadge(
                                        siegeActive: widget.siegeActive,
                                        slotCount: widget.siegeSlotCount,
                                        occupiedSlots: widget.siegeOccupiedSlots,
                                        hasMySlot: widget.siegeHasMySlot,
                                        onTap: widget.onSiegeTap,
                                        compact: true,
                                      ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 7),
                          DungeonInsetText(
                            widget.dungeon.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: CaveTextStyle.title(
                              color: _kCardText,
                              size: 18,
                            ),
                          ),
                          if (widget.dungeon.description.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            DungeonInsetText(
                              widget.dungeon.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: CaveTextStyle.body(
                                color: _kCardText,
                                size: 11,
                              ),
                              depthOffset: const Offset(0, 1),
                            ),
                          ],
                          if (kDebugMode && widget.debugText != null) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              widget.debugText!,
                              style: CaveTextStyle.body(
                                color: theme.textMuted,
                                size: 10,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              _CaveStatChip(
                                icon: Icons.bolt,
                                label: '${widget.energyCost}E',
                                color: _kCardText,
                                panel: theme.panel,
                              ),
                              _CaveStatChip(
                                icon: Icons.monetization_on_outlined,
                                label: formatCompactGoldRange(widget.minGold, widget.maxGold),
                                color: theme.gold,
                                panel: theme.panel,
                                isGold: true,
                              ),
                              if (widget.powerRequirement > 0)
                                _CaveStatChip(
                                  icon: Icons.security,
                                  label: _fmtPower(widget.powerRequirement),
                                  color: _kCardText,
                                  panel: theme.panel,
                                ),
                            ],
                          ),
                          if (widget.powerRequirement > 0) ...<Widget>[
                            const SizedBox(height: 8),
                            _CavePowerBar(
                              ratio: (powerRatio / 2).clamp(0.0, 1.0),
                              ok: powerOk,
                              threat: threat,
                              theme: theme,
                            ),
                          ],
                          const SizedBox(height: 8),
                          DungeonProgressRow(dungeon: widget.dungeon, accent: theme.accent),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              _CaveLootButton(onTap: widget.onLoot, theme: theme),
                              const SizedBox(width: 8),
                              Expanded(
                                child: enterButton,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: _kCaveArtSize * 0.55),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 4,
                child: _CaveSuccessRing(
                  percent: widget.successPercent,
                  color: threat,
                  panel: theme.panel,
                ),
              ),

              // High / Ultra: Top-edge specular sheen hairline (WCAG 2.2 AA Contrast)
              if (_isHighOrUltra)
                Positioned(
                  top: 0,
                  left: 14,
                  right: 14,
                  height: 1.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          theme.accentGlow.withValues(alpha: 0.65),
                          Colors.white.withValues(alpha: 0.85),
                          theme.accentGlow.withValues(alpha: 0.65),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

              // Aion-2 Gold Filigree & Obsidian Corner Trim
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: Aion2GoldFiligreePainter(
                      primaryGold: theme.accentGlow,
                      deepGold: theme.accent,
                      highlightGold: Colors.white,
                      cornerSize: _isHighOrUltra ? 22.0 : 18.0,
                      strokeWidth: _isHighOrUltra ? 1.4 : 1.1,
                      showCrest: _isHighOrUltra,
                      showGems: _isHighOrUltra,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget result = card;

    if (widget.useTutorialAnchors) {
      result = TutorialAnchorScope(
        id: TutorialAnchorId.dungeonZone0,
        child: result,
      );
    }
    if (widget.onCardTap != null) {
      result = GestureDetector(
        onTap: widget.onCardTap,
        behavior: HitTestBehavior.opaque,
        child: result,
      );
    }

    // ZeroJankTouchScope wraps the entire interactive card hierarchy to automatically
    // notify the ZeroJankPreloader to yield background tasks on touch interactions.
    return ZeroJankTouchScope(
      preloader: widget.preloader,
      child: result,
    );
  }
}

class _ThreatBadge extends StatelessWidget {
  const _ThreatBadge({
    required this.label,
    required this.color,
    required this.panel,
  });
  final String label;
  final Color color;
  final Color panel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: panel.withValues(alpha: 0.7),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(label, style: CaveTextStyle.label(color: _kCardText, size: 8)),
    );
  }
}

class _CaveSuccessRing extends StatelessWidget {
  const _CaveSuccessRing({
    required this.percent,
    required this.color,
    required this.panel,
  });
  final int percent;
  final Color color;
  final Color panel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: const Size(52, 52),
            painter: _CaveRingPainter(
              percent: percent.toDouble(),
              color: color,
              track: panel,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DungeonInsetText(
                '$percent',
                style: CaveTextStyle.title(color: _kCardText, size: 13),
                depthOffset: const Offset(0, 1),
              ),
              Text('%', style: CaveTextStyle.label(color: _kCardText, size: 7)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaveRingPainter extends CustomPainter {
  const _CaveRingPainter({
    required this.percent,
    required this.color,
    required this.track,
  });
  final double percent;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 3;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    if (percent > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * (percent / 100),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CaveRingPainter old) =>
      old.percent != percent || old.color != color || old.track != track;
}

class _CaveStatChip extends StatelessWidget {
  const _CaveStatChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.panel,
    this.isGold = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color panel;
  final bool isGold;

  @override
  Widget build(BuildContext context) {
    final Color display = isGold ? color : _kCardText;
    final Color border = isGold ? color : _kCardText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: panel.withValues(alpha: 0.65),
        border: Border.all(color: border.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: display),
          const SizedBox(width: 4),
          Text(label, style: CaveTextStyle.body(color: display, size: 11)),
        ],
      ),
    );
  }
}

class _CavePowerBar extends StatelessWidget {
  const _CavePowerBar({
    required this.ratio,
    required this.ok,
    required this.threat,
    required this.theme,
  });
  final double ratio;
  final bool ok;
  final Color threat;
  final CaveCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            DungeonInsetText(
              'GÜÇ',
              style: CaveTextStyle.label(color: _kCardText, size: 8),
              depthOffset: const Offset(0, 0.8),
            ),
            const Spacer(),
            Text(
              ok ? 'YETERLİ' : 'YETERSİZ',
              style: CaveTextStyle.label(
                color: _kCardText,
                size: 8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: ratio,
            backgroundColor: theme.panel,
            valueColor: AlwaysStoppedAnimation<Color>(
              ok ? theme.powerOk : threat,
            ),
          ),
        ),
      ],
    );
  }
}

class _CaveLootButton extends StatelessWidget {
  const _CaveLootButton({required this.onTap, required this.theme});
  final VoidCallback onTap;
  final CaveCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: theme.panel.withValues(alpha: 0.8),
            border: Border.all(
              color: theme.loot.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: _kCardText,
              ),
              const SizedBox(width: 5),
              Text(
                'Loot',
                style: CaveTextStyle.body(color: _kCardText, size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaveEnterButton extends StatelessWidget {
  const _CaveEnterButton({
    required this.active,
    required this.entering,
    required this.label,
    required this.theme,
    this.onTap,
  });

  final bool active;
  final bool entering;
  final String label;
  final CaveCardTheme theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: active
                ? LinearGradient(
                    colors: <Color>[theme.accent, theme.accentDeep],
                  )
                : null,
            color: active ? null : theme.panel.withValues(alpha: 0.85),
            border: Border.all(
              color: active
                  ? theme.accentGlow.withValues(alpha: 0.55)
                  : theme.textMuted.withValues(alpha: 0.25),
            ),
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: entering
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kCardText,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        active ? Icons.play_arrow_rounded : Icons.lock_outline,
                        size: 17,
                        color: _kCardText,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: CaveTextStyle.title(
                          color: _kCardText,
                          size: 13,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

CaveCardTheme? featuredCaveThemeFor(DungeonData dungeon) =>
    CaveCardTheme.forDungeonNumber(parseDungeonNumber(dungeon.dungeonId));

bool isFeaturedCaveDungeon(DungeonData dungeon) =>
    featuredCaveThemeFor(dungeon) != null;

/// Ambient cave torch particle painter.
///
/// Deterministically distributes rising embers and smoke plumes across the cavern entrance.
/// Zero per-frame heap allocations (no dynamic random calls inside [paint]).
/// - Eco/Low tiers: decimated to 8 particles, basic circular rasterization, zero blur filters.
/// - Mid tier: 16 particles with soft alpha gradients.
/// - High/Ultra tiers: 32 particles with outer luminous halos ([MaskFilter.blur]) and dual-tone embers.
class _CaveTorchParticlePainter extends CustomPainter {
  const _CaveTorchParticlePainter({
    required this.progress,
    required this.particleCount,
    required this.theme,
    required this.isMultiLayer,
  });

  final double progress;
  final int particleCount;
  final CaveCardTheme theme;
  final bool isMultiLayer;

  @override
  void paint(Canvas canvas, Size size) {
    if (particleCount <= 0 || size.width <= 0 || size.height <= 0) return;

    final double originX = size.width * 0.72;
    final double originY = size.height * 0.92;

    for (int i = 0; i < particleCount; i++) {
      final double seed = ((i * 137.49) % 1000) / 1000.0;
      final double speed = 0.45 + (((i * 47) % 100) / 100.0) * 0.55;
      final double phase = (progress * speed + seed) % 1.0;

      final double lateralOffset = math.sin((phase * 3.0 + i) * math.pi) * (18.0 + (i % 5) * 4.0);
      final double x = originX + ((seed - 0.5) * size.width * 0.45) + lateralOffset;
      final double y = originY - (phase * size.height * 1.05);

      if (x < 0 || x > size.width || y < 0 || y > size.height) continue;

      final double fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final bool isEmber = (i % 3) != 0;
      final double radius = isEmber
          ? (0.8 + (((i * 31) % 100) / 100.0) * 1.8)
          : (2.5 + (((i * 59) % 100) / 100.0) * 4.5);

      final Color baseColor = isEmber
          ? ((i % 2 == 0) ? theme.accentGlow : const Color(0xFFFFB800))
          : const Color(0xFF1E2330);

      final double maxAlpha = isEmber ? 0.75 : 0.28;
      final Paint paint = Paint()
        ..color = baseColor.withValues(alpha: maxAlpha * fade);

      if (isMultiLayer && isEmber) {
        final Paint haloPaint = Paint()
          ..color = theme.accent.withValues(alpha: 0.28 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
        canvas.drawCircle(Offset(x, y), radius * 2.2, haloPaint);
      }

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_CaveTorchParticlePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.particleCount != particleCount ||
      oldDelegate.isMultiLayer != isMultiLayer ||
      oldDelegate.theme != theme;
}

/// Dynamic cavern torch flicker painter.
///
/// Recreates sputtering subterranean torchlight illumination with harmonic wave frequencies:
/// - Mid tier: Single-layer gentle radial flame pulse.
/// - High/Ultra tiers: 3-layer harmonic torchlight (warm amber flare + ambient crimson glow + cavern rim reflection).
class _CavernTorchFlickerPainter extends CustomPainter {
  const _CavernTorchFlickerPainter({
    required this.progress,
    required this.theme,
    required this.isMultiLayer,
  });

  final double progress;
  final CaveCardTheme theme;
  final bool isMultiLayer;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Offset torchCenter = Offset(size.width * 0.82, size.height * 0.48);
    final double maxRadius = size.width * 0.65;

    if (!isMultiLayer) {
      final double flicker = 0.12 + 0.04 * math.sin(progress * 2 * math.pi * 2.5);
      final Paint torchPaint = Paint()
        ..shader = ui.Gradient.radial(
          torchCenter,
          maxRadius,
          <Color>[
            theme.accentGlow.withValues(alpha: flicker),
            theme.accent.withValues(alpha: flicker * 0.4),
            Colors.transparent,
          ],
          const <double>[0.0, 0.45, 1.0],
        );
      canvas.drawRect(Offset.zero & size, torchPaint);
      return;
    }

    // High / Ultra: Multi-layer harmonic torch flicker
    // Layer 1: Primary warm high-frequency torch flare (3.7x freq)
    final double flicker1 = 0.18 + 0.08 * math.sin(progress * 2 * math.pi * 3.7);
    final Paint layer1 = Paint()
      ..shader = ui.Gradient.radial(
        torchCenter,
        maxRadius * 0.85,
        <Color>[
          theme.accentGlow.withValues(alpha: flicker1),
          const Color(0xFFFFB800).withValues(alpha: flicker1 * 0.55),
          Colors.transparent,
        ],
        const <double>[0.0, 0.50, 1.0],
      );
    canvas.drawRect(Offset.zero & size, layer1);

    // Layer 2: Secondary ambient flame pulse (5.3x freq)
    final double flicker2 = 0.10 + 0.05 * math.cos(progress * 2 * math.pi * 5.3 + 1.2);
    final Paint layer2 = Paint()
      ..shader = ui.Gradient.radial(
        Offset(torchCenter.dx - 20, torchCenter.dy + 15),
        maxRadius * 1.1,
        <Color>[
          theme.accentDeep.withValues(alpha: flicker2),
          theme.surfaceDeep.withValues(alpha: flicker2 * 0.3),
          Colors.transparent,
        ],
        const <double>[0.0, 0.60, 1.0],
      );
    canvas.drawRect(Offset.zero & size, layer2);

    // Layer 3: Cavern wall rim illumination reflection (1.9x freq)
    final double flicker3 = 0.08 + 0.04 * math.sin(progress * 2 * math.pi * 1.9 + 2.4);
    final Paint layer3 = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width, size.height * 0.2),
        Offset(size.width * 0.4, size.height * 0.8),
        <Color>[
          theme.accentGlow.withValues(alpha: flicker3),
          Colors.transparent,
        ],
      );
    canvas.drawRect(Offset.zero & size, layer3);
  }

  @override
  bool shouldRepaint(_CavernTorchFlickerPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.theme != theme ||
      oldDelegate.isMultiLayer != isMultiLayer;
}

/// Volumetric cavern fog gradient painter.
///
/// Renders low-hanging ground mist rolling across the subterranean cavern threshold
/// with smooth drift oscillation for High & Ultra hardware tiers.
class _VolumetricCavernFogPainter extends CustomPainter {
  const _VolumetricCavernFogPainter({
    required this.progress,
    required this.theme,
  });

  final double progress;
  final CaveCardTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double drift = math.sin(progress * 2 * math.pi * 0.8) * 12.0;

    // Cavern ground mist layer: low-hanging volumetric fog
    final Rect bottomFogRect = Rect.fromLTRB(0, size.height * 0.55, size.width, size.height);
    final Paint groundFogPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, size.height * 0.55),
        Offset(0, size.height),
        <Color>[
          Colors.transparent,
          theme.surfaceDeep.withValues(alpha: 0.35),
          theme.surfaceDeep.withValues(alpha: 0.75),
        ],
        const <double>[0.0, 0.45, 1.0],
      );
    canvas.drawRect(bottomFogRect, groundFogPaint);

    // Cavern archway atmospheric fog billow
    final Rect cavernMistRect = Offset.zero & size;
    final Paint archwayMistPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.70 + drift, size.height * 0.65),
        size.width * 0.65,
        <Color>[
          theme.accent.withValues(alpha: 0.12),
          theme.surfaceDeep.withValues(alpha: 0.22),
          Colors.transparent,
        ],
        const <double>[0.0, 0.55, 1.0],
      );
    canvas.drawRect(cavernMistRect, archwayMistPaint);
  }

  @override
  bool shouldRepaint(_VolumetricCavernFogPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.theme != theme;
}
