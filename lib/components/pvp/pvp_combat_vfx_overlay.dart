import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../core/vfx/gpu_particle_system.dart';
import '../../core/vfx/ground_decal_system.dart';
import '../../core/vfx/refraction_effect.dart';
import '../../core/vfx/ribbon_trail_renderer.dart';
import '../../core/vfx/rim_hit_flash_effect.dart';
import '../../screens/settings/graphics_settings_service.dart';
import 'pvp_combat_vfx_coordinator.dart';

// =============================================================================
// 2027 AION 2 OBSIDIAN-GLASS PVP COMBAT VFX OVERLAY (V2 POLISHED SPEC)
// High-performance combat juice overlay stage with:
// 1. Fullscreen combat juice overlay: directional shake, decals, ribbons, GPU sparks
// 2. Battle Crimson (#FFFF1744) critical strike flashes & curved sword slash ribbons
// 3. Ether Cyan (#00E5FF) crystalline deflection shields & hexagonal energy wards
// 4. Arcane burst ripples with multi-harmonic wavefront dispersion & dispersion echoes
// 5. Lightweight CustomPainter with zero-GC static paint object pooling
// 6. Complete SafeArea boundary clamping for damage numbers & HUD combo banner
// 7. Tactical mobile haptic triggers (heavy/medium/light impacts)
// 8. Frosted obsidian-glass sensory cards, specular sheens & tiered combo banners
// 9. 3D Faceted Astral Prisms for Stun Halo
// =============================================================================

/// Design Tokens for 2027 Aion 2 Dark Fantasy Obsidian Glass & Combat VFX
class PvpVfxTokens {
  PvpVfxTokens._();

  // Signature Combat VFX Colors
  static const Color battleCrimson = Color(0xFFFF1744);
  static const Color battleCrimsonGlow = Color(0x80FF1744);
  static const Color battleCrimsonCore = Color(0xFFFFF0F2);
  static const Color battleCrimsonDeep = Color(0xFF88001B);

  static const Color etherCyan = Color(0xFF00E5FF);
  static const Color etherCyanGlow = Color(0x8000E5FF);
  static const Color etherCyanCore = Color(0xFFE0F7FA);
  static const Color etherCyanDeep = Color(0xFF006064);

  static const Color runicGold = Color(0xFFFFD54F);
  static const Color runicGoldGlow = Color(0x80FFD54F);
  static const Color runicGoldCore = Color(0xFFFFFDE7);

  // Obsidian Glass Surface Tokens
  static const Color obsidianGlassDark = Color(0xDD0B0E14);
  static const Color obsidianGlassSurface = Color(0xEA111722);
  static const Color obsidianGlassBorder = Color(0x38FFFFFF);
  static const Color obsidianGlossHighlight = Color(0x22FFFFFF);
  static const Color obsidianBackdropBlur = Color(0x40000000);
}

/// Static object pool for Canvas rendering to prevent GC churn at 60/120 FPS.
class _VfxPaintPool {
  _VfxPaintPool._();

  static final Paint strokePaint = Paint()..style = PaintingStyle.stroke;
  static final Paint fillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint glowStrokePaint = Paint()..style = PaintingStyle.stroke;
  static final Paint glowFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint arcPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint spokePaint = Paint()..style = PaintingStyle.stroke;

  static final Path hexPath = Path();
  static final Path innerHexPath = Path();
  static final Path slashPath = Path();
  static final Path starPath = Path();
  static final Path sparkPath = Path();
}

/// Top-level visual stage applying directional camera shake and overlaying
/// all arena VFX (decals, ribbon trails, GPU sparks, refraction shockwaves,
/// floating damage numbers, deflection shields, and streak combo counters).
class PvpCombatVfxStage extends StatefulWidget {
  const PvpCombatVfxStage({
    super.key,
    required this.coordinator,
    required this.child,
    this.refractionController,
    this.enableHitVignette = true,
    this.enableShockwaveRipples = true,
    this.enableDeflectionShields = true,
    this.enableSlashRibbons = true,
    this.enableHaptics = true,
    this.scaler,
    this.enableAdaptiveQuality = true,
  });

  /// The coordinator driving all combat juice and VFX subsystems.
  final PvpCombatVfxCoordinator coordinator;

  /// The base duel scene (e.g. Arena backdrop, fighter cards, health bars).
  final Widget child;

  /// Optional GPU refraction shader controller for fullscreen distortion shockwaves.
  final RefractionShaderController? refractionController;

  /// Whether to render screen-edge radial vignette flash on heavy / fatal hits.
  final bool enableHitVignette;

  /// Whether to render analytical expanding shockwave ripples on critical hits.
  final bool enableShockwaveRipples;

  /// Whether to render Ether Cyan deflection shields on parries and blocks.
  final bool enableDeflectionShields;

  /// Whether to render procedural incandescent sword slash ribbons on crits.
  final bool enableSlashRibbons;

  /// Whether to trigger synchronized tactile haptics on combat impacts.
  final bool enableHaptics;

  /// Optional AdaptiveQualityScaler override for dynamic frame-budget adaptation.
  final AdaptiveQualityScaler? scaler;

  /// Whether to enable dynamic adaptive quality scaling and ZeroJank asset preloading.
  final bool enableAdaptiveQuality;

  @override
  State<PvpCombatVfxStage> createState() => _PvpCombatVfxStageState();
}

class _PvpCombatVfxStageState extends State<PvpCombatVfxStage> {
  final Set<String> _processedHapticIds = <String>{};
  final Set<String> _processedBurstIds = <String>{};

  AdaptiveQualityScaler? _scaler;
  StreamSubscription<QualitySettings>? _scalerSubscription;
  HardwareTier _currentTier = HardwareTier.mid;
  int _throttleLevel = 0;
  int _maxActiveParticles = 2000;
  double _resolutionScale = 1.0;

  ui.Image? _preloadedSparkSprite;
  ui.Image? _preloadedEmberSprite;
  ui.Image? _preloadedWardSprite;

  /// Whether this stage is currently executing on Eco or Low tier hardware.
  bool get _isEcoOrLowTier =>
      _currentTier == HardwareTier.eco || _currentTier == HardwareTier.low;

  /// Strict particle clamp dynamically derived from [AdaptiveQualityScaler] settings:
  /// - Eco / Low: 15-30 particles.
  /// - Mid: 100-200 particles.
  /// - High / Ultra: 500+ particles.
  int get effectiveSparkClamp {
    switch (_currentTier) {
      case HardwareTier.eco:
        return (_maxActiveParticles * 0.12).round().clamp(15, 20);
      case HardwareTier.low:
        return (_maxActiveParticles * 0.06).round().clamp(20, 30);
      case HardwareTier.mid:
        return (_maxActiveParticles * 0.08).round().clamp(100, 200);
      case HardwareTier.high:
        return math.max(500, (_maxActiveParticles * 0.15).round().clamp(500, 1000));
      case HardwareTier.ultra:
        return math.max(500, (_maxActiveParticles * 0.25).round().clamp(500, 2500));
    }
  }

  @override
  void initState() {
    super.initState();
    _setupScaler();
    _preloadCombatVfxAssets();
  }

  @override
  void didUpdateWidget(covariant PvpCombatVfxStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scaler != oldWidget.scaler ||
        widget.enableAdaptiveQuality != oldWidget.enableAdaptiveQuality) {
      _scalerSubscription?.cancel();
      _setupScaler();
    }
    _triggerPendingHapticsAndVfx();
  }

  @override
  void dispose() {
    _scalerSubscription?.cancel();
    super.dispose();
  }

  void _setupScaler() {
    if (!widget.enableAdaptiveQuality) return;

    try {
      _scaler = widget.scaler ?? GraphicsSettingsService.instance.scaler;
      _scalerSubscription = _scaler?.onSettingsChanged.listen(_handleScalerSettings);
      if (_scaler != null) {
        _applySettings(_scaler!.currentSettings);
      }
    } catch (_) {
      // Fallback in headless unit tests or isolated environments
    }
  }

  void _applySettings(QualitySettings settings) {
    _currentTier = settings.tier;
    _throttleLevel = settings.throttleLevel;
    _maxActiveParticles = settings.maxActiveParticles;
    _resolutionScale = settings.renderResolutionScale;
    _enforceParticleSystemCeiling();
  }

  void _handleScalerSettings(QualitySettings settings) {
    if (!mounted) return;
    setState(() {
      _applySettings(settings);
    });
  }

  void _preloadCombatVfxAssets() {
    try {
      final ZeroJankPreloader preloader = ZeroJankPreloader.instance;

      // 1. Preload combat VFX incandescent hit spark sprite (<2ms budget, criticalHud priority)
      preloader.preloadAtomic<ui.Image?>(
        id: 'pvp_combat_vfx_spark_sprite',
        priority: PreloadPriority.criticalHud,
        targetCache: CacheTarget.vram,
        estimatedSizeBytes: 64 * 64 * 4,
        tags: const <String>{'pvp', 'vfx', 'sparks'},
        loader: () => _generateParticleSprite(
          size: 64,
          coreColor: PvpVfxTokens.battleCrimsonCore,
          glowColor: PvpVfxTokens.battleCrimsonGlow,
        ),
      ).then((ui.Image? img) {
        if (mounted && img != null) {
          setState(() {
            _preloadedSparkSprite = img;
          });
        }
      }).catchError((Object _) => null);

      // 2. Preload combat VFX multi-layer ember burst sprite (<2ms budget, criticalHud priority)
      preloader.preloadAtomic<ui.Image?>(
        id: 'pvp_combat_vfx_ember_sprite',
        priority: PreloadPriority.criticalHud,
        targetCache: CacheTarget.vram,
        estimatedSizeBytes: 64 * 64 * 4,
        tags: const <String>{'pvp', 'vfx', 'embers'},
        loader: () => _generateParticleSprite(
          size: 64,
          coreColor: PvpVfxTokens.runicGoldCore,
          glowColor: PvpVfxTokens.runicGoldGlow,
        ),
      ).then((ui.Image? img) {
        if (mounted && img != null) {
          setState(() {
            _preloadedEmberSprite = img;
          });
        }
      }).catchError((Object _) => null);

      // 3. Preload Ether Cyan deflection shield ward texture (<2ms budget, criticalHud priority)
      preloader.preloadAtomic<ui.Image?>(
        id: 'pvp_combat_vfx_deflection_ward',
        priority: PreloadPriority.criticalHud,
        targetCache: CacheTarget.vram,
        estimatedSizeBytes: 128 * 128 * 4,
        tags: const <String>{'pvp', 'vfx', 'deflection'},
        loader: () => _generateHexWardSprite(
          size: 128,
          coreColor: PvpVfxTokens.etherCyanCore,
          glowColor: PvpVfxTokens.etherCyan,
        ),
      ).then((ui.Image? img) {
        if (mounted && img != null) {
          setState(() {
            _preloadedWardSprite = img;
          });
        }
      }).catchError((Object _) => null);
    } catch (_) {}
  }

  static Future<ui.Image?> _generateParticleSprite({
    required int size,
    required Color coreColor,
    required Color glowColor,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double center = size / 2.0;
    final double radius = size / 2.0;

    final Paint glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center, center),
        radius,
        <Color>[coreColor, glowColor, glowColor.withValues(alpha: 0.0)],
        const <double>[0.0, 0.45, 1.0],
      );

    canvas.drawCircle(Offset(center, center), radius, glowPaint);
    final ui.Picture picture = recorder.endRecording();
    return picture.toImage(size, size);
  }

  static Future<ui.Image?> _generateHexWardSprite({
    required int size,
    required Color coreColor,
    required Color glowColor,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double center = size / 2.0;
    final double radius = size * 0.42;

    final Path path = Path();
    for (int i = 0; i < 6; i++) {
      final double angle = (i * 60 + 30) * math.pi / 180.0;
      final double x = center + radius * math.cos(angle);
      final double y = center + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = glowColor;
    canvas.drawPath(path, glowPaint);

    final Paint corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = coreColor;
    canvas.drawPath(path, corePaint);

    final ui.Picture picture = recorder.endRecording();
    return picture.toImage(size, size);
  }

  void _triggerPendingHapticsAndVfx() {
    final DateTime now = DateTime.now();
    for (final PvpDamagePopup popup in widget.coordinator.damagePopups) {
      if (popup.isExpired(now)) continue;

      if (widget.enableHaptics && !_processedHapticIds.contains(popup.id)) {
        _processedHapticIds.add(popup.id);
        if (popup.isCritical) {
          HapticFeedback.heavyImpact();
        } else if (popup.isParry || popup.isBlocked) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      }

      // High / Ultra Tier Multi-Layer Ember Burst Emitter Hook
      if ((_currentTier == HardwareTier.high || _currentTier == HardwareTier.ultra) &&
          popup.isCritical &&
          !_processedBurstIds.contains(popup.id)) {
        _processedBurstIds.add(popup.id);
        _emitHighTierEmberBurst(popup.position);
      }
    }

    _enforceParticleSystemCeiling();

    // Garbage-collect old processed IDs when popup list shrinks
    if (_processedHapticIds.length > 50) {
      final Set<String> activeIds = widget.coordinator.damagePopups
          .map((PvpDamagePopup p) => p.id)
          .toSet();
      _processedHapticIds.retainAll(activeIds);
      _processedBurstIds.retainAll(activeIds);
    }
  }

  void _emitHighTierEmberBurst(Offset origin) {
    if (!widget.coordinator.enableParticles) return;
    try {
      final GpuParticleSystem system = widget.coordinator.particleSystem;
      final int sparkBurstCount = _currentTier == HardwareTier.ultra ? 80 : 45;
      system.emitBurst(
        layerIndex: 0,
        count: sparkBurstCount,
        origin: origin,
        speedMultiplier: 1.5,
      );
      if (system.layers.length > 1) {
        final int emberBurstCount = _currentTier == HardwareTier.ultra ? 36 : 20;
        system.emitBurst(
          layerIndex: 1,
          count: emberBurstCount,
          origin: origin,
          speedMultiplier: 1.2,
        );
      }
    } catch (_) {}
  }

  void _enforceParticleSystemCeiling() {
    try {
      final GpuParticleBuffer buffer = widget.coordinator.particleSystem.buffer;
      final int maxAllowed = effectiveSparkClamp;
      while (buffer.activeCount > maxAllowed) {
        final int particleIndex = buffer.activeIndices[buffer.activeCount - 1];
        buffer.free(particleIndex);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    _triggerPendingHapticsAndVfx();

    // 1. Directional Camera Shake Transform
    final Offset shakeOffset = widget.coordinator.enableCameraShake
        ? widget.coordinator.cameraShake.translation
        : Offset.zero;
    final double shakeRoll = widget.coordinator.enableCameraShake
        ? widget.coordinator.cameraShake.roll
        : 0.0;

    final DateTime now = DateTime.now();
    final EdgeInsets safePadding = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;

    // Gating hooks for Hardware Tiers:
    // Ribbon weapon trails enabled on Mid, High, Ultra; bypassed on Eco to save quad mesh fill rate
    final bool canRenderRibbonTrails = widget.coordinator.enableWeaponTrails &&
        (_currentTier != HardwareTier.eco);

    // Skip complex distortion/refraction shaders on Eco / Low tiers to protect mobile GPU fill rate
    final bool canRenderRefraction = (widget.refractionController != null &&
        widget.refractionController!.isActive &&
        !_isEcoOrLowTier &&
        _throttleLevel < 2);

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(shakeOffset.dx, shakeOffset.dy)
        ..rotateZ(shakeRoll),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Base duel scene (arena, health bars, fighters)
          widget.child,

          // 2. Colosseum Ground Decals Layer
          if (widget.coordinator.enableDecals)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: GroundDecalPainter(
                      system: widget.coordinator.decalSystem,
                    ),
                  ),
                ),
              ),
            ),

          // 3. Weapon Swing Ribbon Trails Layer (Mid / High / Ultra)
          if (canRenderRibbonTrails)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: RibbonTrailPainter(
                      trail: widget.coordinator.ribbonTrail,
                    ),
                  ),
                ),
              ),
            ),

          // 4. Multi-layer GPU / Spark Particles Layer (Tier-Adaptive Scaler Hooked)
          if (widget.coordinator.enableParticles)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _AdaptivePvpParticlePainter(
                      system: widget.coordinator.particleSystem,
                      tier: _currentTier,
                      maxParticles: effectiveSparkClamp,
                      singleLayerMode: _isEcoOrLowTier,
                      sparkSprite: _preloadedSparkSprite,
                      emberSprite: _preloadedEmberSprite,
                    ),
                  ),
                ),
              ),
            ),

          // 5. Refraction Shockwave & Distortion Pipeline (Impeller/Skia GPU)
          // Skipped completely on Eco / Low tiers
          if (canRenderRefraction)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: RefractionEffectPainter(
                      controller: widget.refractionController!,
                    ),
                  ),
                ),
              ),
            ),

          // 6. Arcane Burst Ripples, Slash Ribbons & Deflection Shields (Tier-Adaptive Batched)
          if ((widget.enableShockwaveRipples || widget.enableSlashRibbons || widget.enableDeflectionShields) &&
              widget.coordinator.damagePopups.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _PvpCombatVfxBatchedPainter(
                      popups: widget.coordinator.damagePopups,
                      now: now,
                      enableRipples: widget.enableShockwaveRipples,
                      enableSlashRibbons: widget.enableSlashRibbons,
                      enableDeflectionShields: widget.enableDeflectionShields,
                      tier: _currentTier,
                      singleLayerMode: _isEcoOrLowTier,
                      wardSprite: _preloadedWardSprite,
                    ),
                  ),
                ),
              ),
            ),

          // 7. Screen-Edge Hit Vignette & Peripheral Shield Flash
          if (widget.enableHitVignette && widget.coordinator.damagePopups.isNotEmpty)
            Positioned.fill(
              child: _PvpHitVignetteOverlay(
                popups: widget.coordinator.damagePopups,
                now: now,
              ),
            ),

          // 8. Floating Damage Numbers Layer (SafeArea bounded & RepaintBoundary isolated)
          if (widget.coordinator.enableFloatingDamage && widget.coordinator.damagePopups.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: _PvpDamageNumbersOverlay(
                    popups: widget.coordinator.damagePopups,
                    safePadding: safePadding,
                  ),
                ),
              ),
            ),

          // 9. Active Combo Banner Overlay (Obsidian Glass + SafeArea aware)
          if (widget.coordinator.activeComboBanner != null)
            Positioned(
              top: math.max(68.0, safePadding.top + 16.0),
              left: math.max(16.0, safePadding.left + 16.0),
              right: math.max(16.0, safePadding.right + 16.0),
              child: Center(
                child: IgnorePointer(
                  child: _PvpComboBanner(
                    bannerText: widget.coordinator.activeComboBanner!,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tier-adaptive particle painter wiring [AdaptiveQualityScaler] limits and [ZeroJankPreloader] sprites:
/// - Eco / Low tiers: clamp active combat hit sparks to 15-30 particles, use simplified single-layer sprites, skip complex distortion/refraction shaders.
/// - Mid tier: 100-200 particles with balanced dual-layer procedural particle highlights.
/// - High / Ultra tiers: full 500+ particle shockwaves, ribbon weapon trails, and multi-layer ember bursts.
class _AdaptivePvpParticlePainter extends CustomPainter {
  _AdaptivePvpParticlePainter({
    required this.system,
    required this.tier,
    required this.maxParticles,
    required this.singleLayerMode,
    this.sparkSprite,
    this.emberSprite,
    this.fragmentShader,
  });

  final GpuParticleSystem system;
  final HardwareTier tier;
  final int maxParticles;
  final bool singleLayerMode;
  final ui.Image? sparkSprite;
  final ui.Image? emberSprite;
  final ui.FragmentShader? fragmentShader;

  @override
  void paint(Canvas canvas, Size size) {
    if (system.activeParticleCount == 0) return;

    final GpuParticleBuffer buffer = system.buffer;
    final int activeCount = buffer.activeCount;
    // Strict clamp according to AdaptiveQualityScaler tier
    final int count = math.min(activeCount, maxParticles);

    final Paint additivePaint = Paint()..blendMode = BlendMode.plus;
    final Paint normalPaint = Paint()..blendMode = BlendMode.srcOver;

    for (int i = 0; i < count; ++i) {
      final int p = buffer.activeIndices[i];
      final int base = p * GpuParticleBuffer.stride;

      final int layerId = buffer.data[base + GpuParticleBuffer.kOffsetLayerId].toInt();

      // On Eco/Low tiers (singleLayerMode): skip layer 1+ to strictly enforce simplified single-layer sprites
      if (singleLayerMode && layerId > 0) {
        continue;
      }

      final double px = buffer.data[base + GpuParticleBuffer.kOffsetX];
      final double py = buffer.data[base + GpuParticleBuffer.kOffsetY];
      final double age = buffer.getNormalizedAge(p);
      final double pSize = buffer.getCurrentSize(p);

      if (pSize <= 0.0) continue;

      final GpuParticleLayerConfig layer = (layerId >= 0 && layerId < system.layers.length)
          ? system.layers[layerId]
          : system.layers[0];

      final double halfSize = pSize * 0.5;
      final Rect bounds = Rect.fromLTWH(px - halfSize, py - halfSize, pSize, pSize);

      // On Eco / Low tiers: skip fragment shader and draw simplified single-layer sprites
      final bool useShader = !singleLayerMode &&
          fragmentShader != null &&
          tier != HardwareTier.eco &&
          tier != HardwareTier.low;

      if (useShader) {
        final double vx = buffer.data[base + GpuParticleBuffer.kOffsetVx];
        final double vy = buffer.data[base + GpuParticleBuffer.kOffsetVy];
        final double rot = buffer.data[base + GpuParticleBuffer.kOffsetRotation];

        final Float32List uniforms = GpuParticleShaderUniforms.pack(
          resolution: size,
          time: system.globalTime,
          bounds: bounds,
          type: layer.type,
          lifetimeProgress: age,
          startColor: layer.startColor,
          endColor: layer.endColor,
          velocity: Offset(vx, vy),
          turbulence: layer.turbulenceStrength,
          emissiveIntensity: layer.emissiveIntensity,
          size: pSize,
          rotation: rot,
          layerParam: layer.layerParam,
        );

        GpuParticleShaderUniforms.apply(fragmentShader!, uniforms);

        final Paint shaderPaint = Paint()
          ..shader = fragmentShader
          ..blendMode =
              layer.blendMode == GpuBlendMode.additive ? BlendMode.plus : BlendMode.srcOver;

        canvas.drawRect(bounds, shaderPaint);
        continue;
      }

      // Preloaded hardware sprite fast-path (ZeroJank preloaded assets)
      if (sparkSprite != null && layer.type == GpuParticleType.sparkStreak) {
        final Paint spritePaint = Paint()
          ..blendMode = BlendMode.plus
          ..color = buffer.getCurrentColor(p);
        canvas.drawImageRect(
          sparkSprite!,
          Rect.fromLTWH(0, 0, sparkSprite!.width.toDouble(), sparkSprite!.height.toDouble()),
          bounds,
          spritePaint,
        );
        continue;
      }

      if (emberSprite != null && layer.type == GpuParticleType.spellOrb) {
        final Paint spritePaint = Paint()
          ..blendMode = BlendMode.plus
          ..color = buffer.getCurrentColor(p);
        canvas.drawImageRect(
          emberSprite!,
          Rect.fromLTWH(0, 0, emberSprite!.width.toDouble(), emberSprite!.height.toDouble()),
          bounds,
          spritePaint,
        );
        continue;
      }

      // Simplified single-layer sprite fallback (optimized for Eco / Low tiers)
      final Color col = buffer.getCurrentColor(p);
      final Paint activePaint =
          layer.blendMode == GpuBlendMode.additive ? additivePaint : normalPaint;
      activePaint.color = col;

      if (singleLayerMode) {
        // Flat fast single-pass primitive (0 overdraw, no inner/outer blurs)
        canvas.drawCircle(Offset(px, py), halfSize, activePaint);
      } else {
        // Multi-layer / High-tier procedural rendering
        switch (layer.type) {
          case GpuParticleType.spellOrb:
            canvas.drawCircle(Offset(px, py), halfSize, activePaint);
            if (layer.emissiveIntensity > 1.5 && tier.index >= HardwareTier.mid.index) {
              final Paint coreHighlight = Paint()
                ..color = const Color(0xCCFFFFFF)
                ..blendMode = BlendMode.plus;
              canvas.drawCircle(Offset(px, py), halfSize * 0.35, coreHighlight);
            }
            break;

          case GpuParticleType.sparkStreak:
            final double vx = buffer.data[base + GpuParticleBuffer.kOffsetVx];
            final double vy = buffer.data[base + GpuParticleBuffer.kOffsetVy];
            final double speed = math.sqrt(vx * vx + vy * vy);
            if (speed > 10.0) {
              final double stretch = (speed * 0.04).clamp(1.0, 5.0);
              final double angle = math.atan2(vy, vx);
              canvas.save();
              canvas.translate(px, py);
              canvas.rotate(angle);
              final Rect capsule = Rect.fromCenter(
                center: Offset.zero,
                width: pSize * stretch,
                height: pSize * 0.65,
              );
              canvas.drawRRect(
                RRect.fromRectAndRadius(capsule, Radius.circular(pSize * 0.3)),
                activePaint,
              );
              canvas.restore();
            } else {
              canvas.drawCircle(Offset(px, py), halfSize, activePaint);
            }
            break;

          default:
            canvas.drawCircle(Offset(px, py), halfSize, activePaint);
            break;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AdaptivePvpParticlePainter oldDelegate) => true;
}

/// Batched zero-GC painter for:
/// - Battle Crimson (#FFFF1744) critical strike bursts & curved sword slash ribbons
/// - Ether Cyan (#00E5FF) crystalline deflection shields & hexagonal energy barriers
/// - Multi-harmonic arcane burst wavefronts with harmonic dispersion echoes
class _PvpCombatVfxBatchedPainter extends CustomPainter {
  _PvpCombatVfxBatchedPainter({
    required this.popups,
    required this.now,
    required this.enableRipples,
    required this.enableSlashRibbons,
    required this.enableDeflectionShields,
    this.tier = HardwareTier.mid,
    this.singleLayerMode = false,
    this.wardSprite,
  });

  final List<PvpDamagePopup> popups;
  final DateTime now;
  final bool enableRipples;
  final bool enableSlashRibbons;
  final bool enableDeflectionShields;
  final HardwareTier tier;
  final bool singleLayerMode;
  final ui.Image? wardSprite;

  @override
  void paint(Canvas canvas, Size size) {
    for (final PvpDamagePopup p in popups) {
      final double progress = p.progress(now);
      if (progress >= 1.0) continue;

      // ── Ether Cyan (#00E5FF) Crystalline Deflection Shield ────────────────
      if (enableDeflectionShields && (p.isParry || p.isBlocked) && progress < 0.72) {
        _drawDeflectionShield(canvas, p, progress);
      }

      // ── Battle Crimson (#FFFF1744) Critical Shockwave & Slash Ribbons ──────
      if (p.isCritical && progress < 0.78) {
        if (enableRipples) {
          _drawArcaneBurstRipples(canvas, p, progress);
        }
        if (enableSlashRibbons && progress < 0.48) {
          _drawSwordSlashRibbon(canvas, p, progress);
        }
      }
    }
  }

  void _drawDeflectionShield(Canvas canvas, PvpDamagePopup p, double progress) {
    final double t = progress / 0.72;
    final double alpha = (1.0 - t) * (1.0 - t * 0.45);
    if (alpha <= 0.01) return;

    final Offset center = p.position;
    final double radius = 34.0 + t * 46.0;

    // Fast-path sprite rendering if preloaded via ZeroJankPreloader
    if (wardSprite != null && !singleLayerMode) {
      final Rect wardDst = Rect.fromCircle(center: center, radius: radius);
      final Paint wardPaint = Paint()
        ..blendMode = BlendMode.plus
        ..color = Colors.white.withValues(alpha: alpha * 0.9);
      canvas.drawImageRect(
        wardSprite!,
        Rect.fromLTWH(0, 0, wardSprite!.width.toDouble(), wardSprite!.height.toDouble()),
        wardDst,
        wardPaint,
      );
      return;
    }

    // 1. Primary Hexagonal Deflection Barrier Path
    final Path hex = _VfxPaintPool.hexPath;
    hex.reset();
    for (int i = 0; i < 6; i++) {
      final double angle = (i * 60 + 30) * math.pi / 180.0;
      final double x = center.dx + radius * math.cos(angle);
      final double y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        hex.moveTo(x, y);
      } else {
        hex.lineTo(x, y);
      }
    }
    hex.close();

    // On Eco / Low tiers: simplified single-layer sprite without blur filters or spokes
    if (singleLayerMode) {
      _VfxPaintPool.strokePaint
        ..color = PvpVfxTokens.etherCyan.withValues(alpha: alpha * 0.8)
        ..strokeWidth = 2.0
        ..maskFilter = null;
      canvas.drawPath(hex, _VfxPaintPool.strokePaint);
      return;
    }

    // 2. Concentric Resonant Inner Hexagon (Rotated 15 degrees for crystalline energy grid)
    final Path innerHex = _VfxPaintPool.innerHexPath;
    innerHex.reset();
    final double innerRadius = radius * 0.70;
    for (int i = 0; i < 6; i++) {
      final double angle = (i * 60 + 45) * math.pi / 180.0;
      final double x = center.dx + innerRadius * math.cos(angle);
      final double y = center.dy + innerRadius * math.sin(angle);
      if (i == 0) {
        innerHex.moveTo(x, y);
      } else {
        innerHex.lineTo(x, y);
      }
    }
    innerHex.close();

    // Outer Ether Cyan Bloom
    _VfxPaintPool.glowStrokePaint
      ..color = PvpVfxTokens.etherCyan.withValues(alpha: alpha * 0.65)
      ..strokeWidth = 4.2 * (1.0 - t * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawPath(hex, _VfxPaintPool.glowStrokePaint);

    // Inner Core Ether Cyan Hex Border
    _VfxPaintPool.strokePaint
      ..color = PvpVfxTokens.etherCyanCore.withValues(alpha: alpha * 0.95)
      ..strokeWidth = 1.8 * (1.0 - t * 0.5)
      ..maskFilter = null;
    canvas.drawPath(hex, _VfxPaintPool.strokePaint);

    // Resonant Crystalline Grid Inner Hex
    _VfxPaintPool.strokePaint
      ..color = PvpVfxTokens.etherCyan.withValues(alpha: alpha * 0.45)
      ..strokeWidth = 1.0
      ..maskFilter = null;
    canvas.drawPath(innerHex, _VfxPaintPool.strokePaint);

    // Radial Energy Spokes Connecting Center to Vertices
    _VfxPaintPool.spokePaint
      ..color = PvpVfxTokens.etherCyan.withValues(alpha: alpha * 0.35)
      ..strokeWidth = 0.8
      ..maskFilter = null;
    for (int i = 0; i < 6; i++) {
      final double angle = (i * 60 + 30) * math.pi / 180.0;
      final double vx = center.dx + radius * math.cos(angle);
      final double vy = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(vx, vy), _VfxPaintPool.spokePaint);
    }

    // Concentric Deflection Shock Arc (Crescent Deflection Wave)
    _VfxPaintPool.arcPaint
      ..color = PvpVfxTokens.etherCyan.withValues(alpha: alpha * 0.8)
      ..strokeWidth = 2.8 * (1.0 - t)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 1.28),
      -math.pi * 0.72,
      math.pi * 1.44,
      false,
      _VfxPaintPool.arcPaint,
    );

    // Tangential Deflection Spark Flecks (4 bursting sparks along the impact plane)
    final double sparkAlpha = alpha * (1.0 - t);
    if (sparkAlpha > 0.05) {
      _VfxPaintPool.fillPaint
        ..color = PvpVfxTokens.etherCyanCore.withValues(alpha: sparkAlpha * 0.9)
        ..maskFilter = null;

      for (int i = 0; i < 4; i++) {
        final double sparkAngle = (-math.pi * 0.6) + (i * math.pi * 0.4);
        final double sparkDist = radius * 1.35 + (t * 24.0);
        final double sx = center.dx + sparkDist * math.cos(sparkAngle);
        final double sy = center.dy + sparkDist * math.sin(sparkAngle);
        canvas.drawCircle(Offset(sx, sy), 2.2 * (1.0 - t), _VfxPaintPool.fillPaint);
      }
    }

    // Incandescent Core Deflection Flash (initial 18%)
    if (t < 0.18) {
      final double flashT = 1.0 - (t / 0.18);
      _VfxPaintPool.glowFillPaint
        ..color = PvpVfxTokens.etherCyanCore.withValues(alpha: flashT * 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9.0);
      canvas.drawCircle(center, 20.0 * flashT, _VfxPaintPool.glowFillPaint);
    }
  }

  void _drawArcaneBurstRipples(Canvas canvas, PvpDamagePopup p, double progress) {
    final double t = progress / 0.78;
    final double alpha = (1.0 - t) * (1.0 - t);
    if (alpha <= 0.01) return;

    final Offset center = p.position;
    final double baseRadius = t * 165.0;

    // On Eco / Low tiers: simplified single-layer wavefront without blur to minimize fill rate
    if (singleLayerMode) {
      _VfxPaintPool.strokePaint
        ..color = PvpVfxTokens.battleCrimson.withValues(alpha: alpha * 0.75)
        ..strokeWidth = 2.4 * (1.0 - t * 0.5)
        ..maskFilter = null;
      canvas.drawCircle(center, baseRadius, _VfxPaintPool.strokePaint);
      return;
    }

    // 1. Battle Crimson (#FFFF1744) Outer Wavefront with Dispersion Blur
    _VfxPaintPool.glowStrokePaint
      ..color = PvpVfxTokens.battleCrimson.withValues(alpha: alpha * 0.70)
      ..strokeWidth = 4.8 * (1.0 - t * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    canvas.drawCircle(center, baseRadius, _VfxPaintPool.glowStrokePaint);

    // 2. Secondary Harmonic Wavefront (Runic Gold / Ember core)
    _VfxPaintPool.strokePaint
      ..color = PvpVfxTokens.runicGold.withValues(alpha: alpha * 0.88)
      ..strokeWidth = 2.2 * (1.0 - t * 0.6)
      ..maskFilter = null;
    canvas.drawCircle(center, baseRadius * 0.88, _VfxPaintPool.strokePaint);

    // 3. Ethereal Violet/Cyan Micro-Echo Harmonic Ring (Mid, High, Ultra)
    _VfxPaintPool.strokePaint
      ..color = PvpVfxTokens.etherCyan.withValues(alpha: alpha * 0.40)
      ..strokeWidth = 1.4 * (1.0 - t)
      ..maskFilter = null;
    canvas.drawCircle(center, baseRadius * 0.68, _VfxPaintPool.strokePaint);

    // 4. Incandescent Strike Origin Flash (first 16% of animation)
    if (t < 0.16) {
      final double flashT = 1.0 - (t / 0.16);
      _VfxPaintPool.glowFillPaint
        ..color = PvpVfxTokens.battleCrimsonCore.withValues(alpha: flashT * 0.90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11.0);
      canvas.drawCircle(center, 30.0 * (1.0 - flashT * 0.3), _VfxPaintPool.glowFillPaint);
    }

    // 5. On High / Ultra tiers: full multi-layer radiating ember bursts around the shockwave ring
    if (tier == HardwareTier.high || tier == HardwareTier.ultra) {
      final double emberAlpha = alpha * (1.0 - t * 0.3);
      _VfxPaintPool.fillPaint
        ..color = PvpVfxTokens.runicGold.withValues(alpha: emberAlpha * 0.85)
        ..maskFilter = null;

      final int emberCount = tier == HardwareTier.ultra ? 8 : 4;
      for (int i = 0; i < emberCount; i++) {
        final double emberAngle = (i * (math.pi * 2.0 / emberCount)) + (t * 0.8);
        final double dist = baseRadius * 0.92;
        final double ex = center.dx + dist * math.cos(emberAngle);
        final double ey = center.dy + dist * math.sin(emberAngle);
        canvas.drawCircle(Offset(ex, ey), 2.2 * (1.0 - t * 0.5), _VfxPaintPool.fillPaint);
      }
    }
  }

  void _drawSwordSlashRibbon(Canvas canvas, PvpDamagePopup p, double progress) {
    final double t = progress / 0.48;
    final double alpha = math.sin(t * math.pi);
    if (alpha <= 0.01) return;

    final Offset center = p.position;
    // Dynamic slash angle based on popup hash code for organic variety
    final double slashAngle = -0.68 + ((p.id.hashCode % 14) - 7) * 0.08;
    final double cosA = math.cos(slashAngle);
    final double sinA = math.sin(slashAngle);

    final double halfLen = (48.0 + t * 96.0);
    final double halfW = 5.2 * (1.0 - t * 0.45);
    final double curveSag = 12.0 * math.sin(t * math.pi);

    final Path slash = _VfxPaintPool.slashPath;
    slash.reset();

    // Curved blade sweep geometry with quadratic sag
    final Offset p1 = Offset(center.dx - cosA * halfLen, center.dy - sinA * halfLen);
    final Offset pCtrl1 = Offset(
      center.dx - sinA * (halfW + curveSag),
      center.dy + cosA * (halfW + curveSag),
    );
    final Offset p3 = Offset(center.dx + cosA * halfLen, center.dy + sinA * halfLen);
    final Offset pCtrl2 = Offset(
      center.dx + sinA * (halfW - curveSag),
      center.dy - cosA * (halfW - curveSag),
    );

    slash.moveTo(p1.dx, p1.dy);
    slash.quadraticBezierTo(pCtrl1.dx, pCtrl1.dy, p3.dx, p3.dy);
    slash.quadraticBezierTo(pCtrl2.dx, pCtrl2.dy, p1.dx, p1.dy);
    slash.close();

    // On Eco / Low tiers: simplified single-layer ribbon without glow blur
    if (singleLayerMode) {
      _VfxPaintPool.fillPaint
        ..color = PvpVfxTokens.battleCrimson.withValues(alpha: alpha * 0.9)
        ..maskFilter = null;
      canvas.drawPath(slash, _VfxPaintPool.fillPaint);
      return;
    }

    // Outer Battle Crimson Slash Bloom
    _VfxPaintPool.glowFillPaint
      ..color = PvpVfxTokens.battleCrimson.withValues(alpha: alpha * 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0);
    canvas.drawPath(slash, _VfxPaintPool.glowFillPaint);

    // Inner Incandescent White-Hot Slash Ribbon Core
    _VfxPaintPool.fillPaint
      ..color = PvpVfxTokens.battleCrimsonCore.withValues(alpha: alpha * 0.96)
      ..maskFilter = null;
    canvas.drawPath(slash, _VfxPaintPool.fillPaint);

    // Anamorphic 4-Point Lens Glint Star at impact center
    final Path star = _VfxPaintPool.starPath;
    star.reset();
    final double glintR = 28.0 * alpha;
    final double glintThin = 2.4;

    star.moveTo(center.dx - glintR, center.dy);
    star.lineTo(center.dx - glintThin, center.dy - glintThin);
    star.lineTo(center.dx, center.dy - glintR * 0.48);
    star.lineTo(center.dx + glintThin, center.dy - glintThin);
    star.lineTo(center.dx + glintR, center.dy);
    star.lineTo(center.dx + glintThin, center.dy + glintThin);
    star.lineTo(center.dx, center.dy + glintR * 0.48);
    star.lineTo(center.dx - glintThin, center.dy + glintThin);
    star.close();

    _VfxPaintPool.fillPaint
      ..color = Colors.white.withValues(alpha: alpha * 0.95)
      ..maskFilter = null;
    canvas.drawPath(star, _VfxPaintPool.fillPaint);

    // Trailing incandescent spark flecks along the blade sweep (High / Ultra full ember burst)
    final double sparkFade = alpha * (1.0 - t * 0.5);
    _VfxPaintPool.fillPaint
      ..color = PvpVfxTokens.runicGold.withValues(alpha: sparkFade * 0.85)
      ..maskFilter = null;

    final int sparkCount = (tier == HardwareTier.high || tier == HardwareTier.ultra) ? 6 : 3;
    for (int i = 0; i < sparkCount; i++) {
      final double factor = -0.7 + i * (1.4 / (sparkCount - 1));
      final double sx = center.dx + cosA * (halfLen * factor) + sinA * (curveSag * 1.5);
      final double sy = center.dy + sinA * (halfLen * factor) - cosA * (curveSag * 1.5);
      canvas.drawCircle(Offset(sx, sy), 1.8 * (1.0 - t), _VfxPaintPool.fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PvpCombatVfxBatchedPainter oldDelegate) => true;
}

/// Dynamic screen-edge radial vignette flash activated on heavy / lethal impacts.
/// Imbued with Battle Crimson (#FFFF1744) on crits and Ether Cyan (#00E5FF) on deflections.
class _PvpHitVignetteOverlay extends StatelessWidget {
  const _PvpHitVignetteOverlay({
    required this.popups,
    required this.now,
  });

  final List<PvpDamagePopup> popups;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    double maxCritIntensity = 0.0;
    double maxDeflectIntensity = 0.0;
    bool isFatal = false;

    for (final PvpDamagePopup p in popups) {
      final double progress = p.progress(now);

      if (p.isCritical && progress < 0.45) {
        final double intensity = 1.0 - (progress / 0.45);
        if (intensity > maxCritIntensity) {
          maxCritIntensity = intensity;
          if (p.text.contains('NAKAVT') || p.text.contains('💀')) {
            isFatal = true;
          }
        }
      } else if ((p.isParry || p.isBlocked) && progress < 0.35) {
        final double intensity = 1.0 - (progress / 0.35);
        if (intensity > maxDeflectIntensity) {
          maxDeflectIntensity = intensity;
        }
      }
    }

    if (maxCritIntensity <= 0.01 && maxDeflectIntensity <= 0.01) {
      return const SizedBox.shrink();
    }

    final Color vignetteColor = isFatal
        ? const Color(0xFFD50000)
        : (maxCritIntensity >= maxDeflectIntensity
            ? PvpVfxTokens.battleCrimson
            : PvpVfxTokens.etherCyan);

    final double effectiveIntensity = math.max(
      maxCritIntensity * 0.40,
      maxDeflectIntensity * 0.28,
    );

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.94,
            colors: <Color>[
              Colors.transparent,
              Colors.transparent,
              vignetteColor.withValues(alpha: effectiveIntensity),
            ],
            stops: const <double>[0.0, 0.58, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Overlay rendering active floating damage popups with AAA typographic punch
/// and strict SafeArea bounds clamping to prevent notch/island clipping.
class _PvpDamageNumbersOverlay extends StatelessWidget {
  const _PvpDamageNumbersOverlay({
    required this.popups,
    required this.safePadding,
  });

  final List<PvpDamagePopup> popups;
  final EdgeInsets safePadding;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final Size screenSize = MediaQuery.sizeOf(context);

    // SafeArea boundaries with comfortable inset margins
    final double minX = safePadding.left + 85.0;
    final double maxX = math.max(minX, screenSize.width - safePadding.right - 85.0);
    final double minY = safePadding.top + 68.0;
    final double maxY = math.max(minY, screenSize.height - safePadding.bottom - 52.0);

    return Stack(
      clipBehavior: Clip.none,
      children: popups.map((PvpDamagePopup p) {
        final Offset rawPos = p.animatedOffset(now);
        final double clampedX = rawPos.dx.clamp(minX, maxX);
        final double clampedY = rawPos.dy.clamp(minY, maxY);

        final double scale = p.animatedScale(now);
        final double opacity = p.animatedOpacity(now);

        return Positioned(
          left: clampedX - 110,
          top: clampedY - 32,
          width: 220,
          height: 64,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Center(
                child: _PvpDamagePopupCard(popup: p),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

/// Individual damage popup badge styling for criticals, parries, blocks, and normal hits
/// styled with 2027 Aion 2 Obsidian-Glass ergonomics and glowing sensory contours.
class _PvpDamagePopupCard extends StatelessWidget {
  const _PvpDamagePopupCard({required this.popup});

  final PvpDamagePopup popup;

  @override
  Widget build(BuildContext context) {
    final bool isCrit = popup.isCritical;
    final bool isParry = popup.isParry;
    final bool isBlocked = popup.isBlocked;

    // Typography scale
    final double fontSize = isCrit ? 26.0 : (isParry || isBlocked ? 19.0 : 17.0);
    final FontWeight fontWeight = isCrit ? FontWeight.w900 : FontWeight.w800;
    final double letterSpacing = isCrit ? 1.8 : 0.8;

    // High-contrast sensory shadow array
    final List<Shadow> shadows = <Shadow>[
      // Pure black deep contrast backing
      Shadow(
        color: Colors.black.withValues(alpha: 0.95),
        blurRadius: isCrit ? 12.0 : 6.0,
        offset: const Offset(0, 2.5),
      ),
      Shadow(
        color: Colors.black.withValues(alpha: 0.85),
        blurRadius: 2.5,
        offset: const Offset(0, -1.0),
      ),
      if (isCrit) ...<Shadow>[
        Shadow(
          color: PvpVfxTokens.battleCrimson.withValues(alpha: 0.95),
          blurRadius: 18.0,
        ),
        Shadow(
          color: PvpVfxTokens.runicGold.withValues(alpha: 0.75),
          blurRadius: 28.0,
        ),
      ] else if (isParry) ...<Shadow>[
        Shadow(
          color: PvpVfxTokens.etherCyan.withValues(alpha: 0.9),
          blurRadius: 16.0,
        ),
      ] else if (isBlocked) ...<Shadow>[
        Shadow(
          color: PvpVfxTokens.etherCyan.withValues(alpha: 0.7),
          blurRadius: 14.0,
        ),
      ],
    ];

    // Card accent borders & glass backgrounds
    Color borderColor = Colors.transparent;
    Color glowColor = Colors.transparent;
    Color displayTextColor = popup.color;

    if (isCrit) {
      borderColor = PvpVfxTokens.battleCrimson.withValues(alpha: 0.85);
      glowColor = PvpVfxTokens.battleCrimson.withValues(alpha: 0.40);
      displayTextColor = PvpVfxTokens.battleCrimsonCore;
    } else if (isParry) {
      borderColor = PvpVfxTokens.etherCyan.withValues(alpha: 0.85);
      glowColor = PvpVfxTokens.etherCyan.withValues(alpha: 0.35);
      displayTextColor = PvpVfxTokens.etherCyanCore;
    } else if (isBlocked) {
      borderColor = PvpVfxTokens.etherCyan.withValues(alpha: 0.55);
      glowColor = PvpVfxTokens.etherCyan.withValues(alpha: 0.25);
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: isCrit
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 4)
            : (isParry || isBlocked
                ? const EdgeInsets.symmetric(horizontal: 11, vertical: 3)
                : EdgeInsets.zero),
        decoration: (isCrit || isParry || isBlocked)
            ? BoxDecoration(
                color: PvpVfxTokens.obsidianGlassDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: borderColor,
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: glowColor,
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.75),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (isCrit)
              const Text(
                '⟨ ',
                style: TextStyle(
                  color: PvpVfxTokens.battleCrimson,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            if (isParry)
              const Padding(
                padding: EdgeInsets.only(right: 5.0),
                child: Text('🛡️ ', style: TextStyle(fontSize: 14)),
              ),
            Text(
              popup.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: displayTextColor,
                fontSize: fontSize,
                fontWeight: fontWeight,
                letterSpacing: letterSpacing,
                fontStyle: isCrit ? FontStyle.italic : FontStyle.normal,
                shadows: shadows,
              ),
            ),
            if (isCrit)
              const Text(
                ' ⟩',
                style: TextStyle(
                  color: PvpVfxTokens.battleCrimson,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic combo badge banner with 2027 Aion 2 frosted obsidian-glass background,
/// specular top-edge gloss gradient, and tiered luminescence:
/// - Tier 1 (2x-4x): Ether Cyan runic trim (⚡)
/// - Tier 2 (5x-9x): Runic Gold solar blaze (⚔️)
/// - Tier 3 (10x+): Battle Crimson demonic combustion (⟨⟨ 🔥 ⟩⟩)
class _PvpComboBanner extends StatelessWidget {
  const _PvpComboBanner({required this.bannerText});

  final String bannerText;

  @override
  Widget build(BuildContext context) {
    final bool isUltraTier = bannerText.contains('DESTAN') ||
        bannerText.contains('10x') ||
        bannerText.contains('11x') ||
        bannerText.contains('12x');
    final bool isCritTier = bannerText.contains('KRİTİK') || bannerText.contains('5x');

    final Color rimGlowColor = isUltraTier
        ? PvpVfxTokens.battleCrimson
        : (isCritTier ? PvpVfxTokens.runicGold : PvpVfxTokens.etherCyan);

    final String iconPrefix = isUltraTier ? '🔥 ' : (isCritTier ? '⚔️ ' : '⚡ ');

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xF0182030),
                PvpVfxTokens.obsidianGlassDark,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: rimGlowColor.withValues(alpha: 0.85),
              width: 1.4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: rimGlowColor.withValues(alpha: 0.48),
                blurRadius: 22,
                spreadRadius: 2,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.85),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // Specular Top-Edge Light Catch Line
              Positioned(
                top: 0,
                left: 12,
                right: 12,
                height: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        PvpVfxTokens.obsidianGlossHighlight,
                        Colors.white.withValues(alpha: 0.5),
                        PvpVfxTokens.obsidianGlossHighlight,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    iconPrefix,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    bannerText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                      fontStyle: FontStyle.italic,
                      shadows: <Shadow>[
                        const Shadow(
                          color: Colors.black,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                        Shadow(
                          color: rimGlowColor,
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fighter card wrapper integrating Knockback physical recoil, Rim Flash, and 3D Stun Star halo.
class PvpFighterVfxWrapper extends StatelessWidget {
  const PvpFighterVfxWrapper({
    super.key,
    required this.reaction,
    required this.rimFlashController,
    required this.child,
    this.showStunHalo = true,
  });

  /// Harmonic spring reaction state driving translation and rotational recoil.
  final PvpFighterReactionState reaction;

  /// Silhouette rim hit flash controller.
  final RimHitFlashController rimFlashController;

  /// The wrapped fighter widget (e.g. 3D gladiator view, card portrait, or health bar).
  final Widget child;

  /// Whether to render revolving stun stars above the fighter when stunned.
  final bool showStunHalo;

  @override
  Widget build(BuildContext context) {
    // 1. Physical knockback translation and spring rotational recoil
    final Widget animatedChild = Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.identity()
        ..translate(reaction.offset.dx, reaction.offset.dy)
        ..rotateZ(reaction.rotation),
      child: RimHitFlashWidget(
        controller: rimFlashController,
        child: child,
      ),
    );

    if (!showStunHalo || !reaction.isStunned) {
      return animatedChild;
    }

    // 2. Revolving 3D Faceted Astral Prisms / Halo on stun reaction
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        animatedChild,
        Positioned(
          top: -16,
          left: 0,
          right: 0,
          child: Center(
            child: _PvpStunHalo(timer: reaction.stunTimer),
          ),
        ),
      ],
    );
  }
}

/// Ethereal revolving 3D faceted astral diamond prisms with elliptical orbit perspective scaling.
class _PvpStunHalo extends StatelessWidget {
  const _PvpStunHalo({required this.timer});

  final double timer;

  @override
  Widget build(BuildContext context) {
    // 6 rotations per second for fast dizzy orbit
    final double angle = timer * math.pi * 6;

    return SizedBox(
      width: 64,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          // Faint orbital ellipse guide ring (zero GC allocations)
          CustomPaint(
            size: const Size(60, 20),
            painter: _PvpStunOrbitRingPainter(),
          ),
          // 3 revolving faceted astral prisms with 3D orbital perspective scaling
          ...List<Widget>.generate(3, (int i) {
            final double starAngle = angle + (i * math.pi * 2 / 3);
            final double sx = math.cos(starAngle) * 24;
            final double sy = math.sin(starAngle) * 8;

            // Depth calculation: sin gives back (-1) to front (+1)
            final double depth = (math.sin(starAngle) + 1.0) * 0.5; // [0.0..1.0]
            final double prismScale = 0.72 + depth * 0.56; // 0.72x to 1.28x
            final double prismOpacity = 0.55 + depth * 0.45; // 0.55 to 1.0

            return Transform.translate(
              offset: Offset(sx, sy),
              child: Opacity(
                opacity: prismOpacity,
                child: Transform.scale(
                  scale: prismScale,
                  child: const _PvpAstralPrismIcon(),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 4-point faceted luminous astral diamond prism custom widget for dark fantasy aesthetic.
class _PvpAstralPrismIcon extends StatelessWidget {
  const _PvpAstralPrismIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(
        painter: _PvpAstralPrismPainter(),
      ),
    );
  }
}

/// Static zero-GC painter for 4-point faceted diamond astral prism.
class _PvpAstralPrismPainter extends CustomPainter {
  static final Paint _coreFill = Paint()
    ..color = PvpVfxTokens.runicGoldCore
    ..style = PaintingStyle.fill;

  static final Paint _glowFill = Paint()
    ..color = PvpVfxTokens.runicGold
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

  static final Path _prismPath = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;
    final double thin = r * 0.24;

    _prismPath.reset();
    _prismPath.moveTo(cx, cy - r);
    _prismPath.lineTo(cx + thin, cy - thin);
    _prismPath.lineTo(cx + r, cy);
    _prismPath.lineTo(cx + thin, cy + thin);
    _prismPath.lineTo(cx, cy + r);
    _prismPath.lineTo(cx - thin, cy + thin);
    _prismPath.lineTo(cx - r, cy);
    _prismPath.lineTo(cx - thin, cy - thin);
    _prismPath.close();

    canvas.drawPath(_prismPath, _glowFill);
    canvas.drawPath(_prismPath, _coreFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Subtle orbital ellipse track painter behind revolving stun stars (zero GC allocations).
class _PvpStunOrbitRingPainter extends CustomPainter {
  static final Paint _ringPaint = Paint()
    ..color = const Color(0xFFFFD54F).withValues(alpha: 0.28)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawOval(rect, _ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
