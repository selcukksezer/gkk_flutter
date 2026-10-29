import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/vfx/directional_camera_shake.dart';
import '../../../../core/vfx/gpu_particle_system.dart';
import '../../../../core/vfx/ground_decal_system.dart' as gds;
import '../../../../core/vfx/hit_stop_manager.dart';
import '../../../../core/vfx/knockback_ragdoll_controller.dart';
import '../../../../core/vfx/refraction_effect.dart';
import '../../../../core/vfx/ribbon_trail_renderer.dart' as rtr;
import '../../../../core/vfx/rim_hit_flash_effect.dart';

// =============================================================================
// 1. Enums & Data Structures for Guild War Siege VFX
// =============================================================================

/// Types of siege damage inflicted during fortress warfare.
enum SiegeDamageType {
  catapultBoulder,
  siegeArrowVolley,
  gateBatteringRam,
  commanderSlash,
  magicalAuraBlast;

  Color get color {
    switch (this) {
      case SiegeDamageType.catapultBoulder:
        return const Color(0xFFFF5722); // Fiery Orange
      case SiegeDamageType.siegeArrowVolley:
        return const Color(0xFFFFD54F); // Golden Amber
      case SiegeDamageType.gateBatteringRam:
        return const Color(0xFFFF1744); // Crimson Impact
      case SiegeDamageType.commanderSlash:
        return const Color(0xFF00E5FF); // Cyan Blade Glow
      case SiegeDamageType.magicalAuraBlast:
        return const Color(0xFFE040FB); // Arcane Violet
    }
  }

  Color get rimFlashTint {
    switch (this) {
      case SiegeDamageType.catapultBoulder:
        return const Color(0xFFFF6F00);
      case SiegeDamageType.siegeArrowVolley:
        return const Color(0xFFFFEE58);
      case SiegeDamageType.gateBatteringRam:
        return const Color(0xFFFF3D00);
      case SiegeDamageType.commanderSlash:
        return const Color(0xFF80D8FF);
      case SiegeDamageType.magicalAuraBlast:
        return const Color(0xFFEA80FC);
    }
  }
}

/// Faction alignment for aura rim flashes and thematic colors.
enum SiegeFaction {
  elyos,
  asmodian;

  Color get auraColor => this == SiegeFaction.elyos
      ? const Color(0xFF00E5FF)
      : const Color(0xFFFF2A4D);

  Color get crestGold => const Color(0xFFFFD54F);
}

/// Dynamic ground and fortress wall decal types.
enum SiegeDecalType {
  burningCrater,
  wallScorch,
  crackedEarthFissure,
  bladeGouge,
}

// =============================================================================
// 2. Dynamic Decal System (Module 5)
// =============================================================================

class SiegeDecal {
  final String id;
  final Offset position;
  final double radius;
  final double rotation; // Radians
  final SiegeDecalType type;
  final Color primaryColor;
  final Color secondaryColor;
  final DateTime createdAt;
  final Duration lifetime;

  SiegeDecal({
    required this.id,
    required this.position,
    required this.radius,
    required this.rotation,
    required this.type,
    required this.primaryColor,
    required this.secondaryColor,
    DateTime? createdAt,
    this.lifetime = const Duration(seconds: 8),
  }) : createdAt = createdAt ?? DateTime.now();

  double get ageRatio {
    final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
    return (elapsed / lifetime.inMilliseconds).clamp(0.0, 1.0);
  }

  double get opacity => (1.0 - ageRatio).clamp(0.0, 1.0);
  bool get isExpired => ageRatio >= 1.0;
}

// =============================================================================
// 3. Multi-Layer Particle System (Module 6)
// =============================================================================

enum SiegeParticleType {
  fieryEmber,
  smokePlume,
  stoneDebris,
  metalSpark,
}

class SiegeParticle {
  Offset position;
  Offset velocity;
  double scale;
  double rotation;
  double rotationSpeed;
  Color color;
  double alpha;
  double life; // 0.0 to 1.0
  double decaySpeed;
  SiegeParticleType type;
  double gravity;

  SiegeParticle({
    required this.position,
    required this.velocity,
    required this.scale,
    this.rotation = 0.0,
    this.rotationSpeed = 0.0,
    required this.color,
    this.alpha = 1.0,
    this.life = 1.0,
    required this.decaySpeed,
    required this.type,
    this.gravity = 0.0,
  });

  bool update(double dt) {
    position += velocity * dt;
    velocity = Offset(velocity.dx * 0.96, velocity.dy * 0.96 + gravity * dt);
    rotation += rotationSpeed * dt;
    life -= decaySpeed * dt;
    alpha = life.clamp(0.0, 1.0);
    return life > 0.0;
  }
}

// =============================================================================
// 4. Floating Damage Number (Module 8)
// =============================================================================

class SiegeDamageNumber {
  final String id;
  final String text;
  Offset position;
  Offset velocity;
  final Color color;
  final bool isCritical;
  double scale;
  double opacity;
  double life; // 1.0 down to 0.0
  final double decaySpeed;

  SiegeDamageNumber({
    required this.id,
    required this.text,
    required this.position,
    required this.velocity,
    required this.color,
    this.isCritical = false,
    this.scale = 1.0,
    this.opacity = 1.0,
    this.life = 1.0,
    this.decaySpeed = 1.2,
  });

  bool update(double dt) {
    position += velocity * dt;
    // Apply slight upward drag and gravitational arc
    velocity = Offset(velocity.dx * 0.92, velocity.dy + 80.0 * dt);
    life -= decaySpeed * dt;
    opacity = (life * 1.5).clamp(0.0, 1.0);
    // Elastic pop on spawn
    if (life > 0.75) {
      final t = (1.0 - life) / 0.25;
      scale = isCritical ? ui.lerpDouble(0.6, 1.45, t)! : ui.lerpDouble(0.7, 1.15, t)!;
    } else {
      scale = isCritical ? 1.2 : 1.0;
    }
    return life > 0.0;
  }
}

// =============================================================================
// 5. Weapon Ribbon Trail (Module 4)
// =============================================================================

class SiegeWeaponTrailPoint {
  final Offset tip;
  final Offset base;
  final double timestamp;
  final Color color;
  final double width;

  SiegeWeaponTrailPoint({
    required this.tip,
    required this.base,
    required this.timestamp,
    required this.color,
    required this.width,
  });
}

class SiegeWeaponTrail {
  final String id;
  final List<SiegeWeaponTrailPoint> points = [];
  final Color primaryColor;
  final Color glowColor;
  final double maxDuration;

  SiegeWeaponTrail({
    required this.id,
    required this.primaryColor,
    required this.glowColor,
    this.maxDuration = 0.35,
  });

  void addPoint(Offset tip, Offset base, double now, double width) {
    points.add(SiegeWeaponTrailPoint(
      tip: tip,
      base: base,
      timestamp: now,
      color: primaryColor,
      width: width,
    ));
    prune(now);
  }

  void prune(double now) {
    points.removeWhere((p) => (now - p.timestamp) > maxDuration);
  }

  bool get isEmpty => points.isEmpty;
}

// =============================================================================
// 6. Knockback & Troop Flinch (Module 9)
// =============================================================================

class TroopFlinchState {
  Offset offset = Offset.zero;
  Offset velocity = Offset.zero;
  double rotation = 0.0;
  double angularVelocity = 0.0;

  void applyImpulse(Offset impulse, double angularImpulse) {
    velocity += impulse;
    angularVelocity += angularImpulse;
  }

  void update(double dt) {
    // Spring physics return to origin
    const double springK = 35.0;
    const double damping = 8.0;

    final Offset springForce = -offset * springK - velocity * damping;
    velocity += springForce * dt;
    offset += velocity * dt;

    final double angularSpring = -rotation * 30.0 - angularVelocity * 7.0;
    angularVelocity += angularSpring * dt;
    rotation += angularVelocity * dt;

    if (offset.distance < 0.05 && velocity.distance < 0.05) {
      offset = Offset.zero;
      velocity = Offset.zero;
    }
    if (rotation.abs() < 0.005 && angularVelocity.abs() < 0.005) {
      rotation = 0.0;
      angularVelocity = 0.0;
    }
  }
}

// =============================================================================
// 7. Master Guild War Combat VFX & Juice Coordinator
// =============================================================================

/// Coordinator orchestrating all 9 combat juice VFX systems in Siege Battles:
/// 1. Directional Camera Shake (trauma, 5-DOF multi-octave Perlin rumble)
/// 2. Hit-Stop Engine (subsystem time dilation channels, smooth ease-out curves)
/// 3. Rim-Light Hit Flash & Emissive Silhouette (Fresnel highlight, HDR bloom)
/// 4. Catmull-Rom Ribbon Trails (quad-strip mesh, blade & arrow arcs)
/// 5. Dynamic Ground Decals (OBB projection, scorches, fissures, craters)
/// 6. Multi-Layer GPU Particles (curl turbulence, embers, smoke, stone debris)
/// 7. Haptic Siege Vibration (impact pulses, earth tremors)
/// 8. Floating Damage Numbers (mass battle multi-target combat text)
/// 9. Knockback & Physical Ragdoll (Coulomb friction, airborne parabolic arcs)
/// 10. Refraction & Wavefront Distortion (shockwave & critical hit shaders)
class GuildWarCombatVfxCoordinator extends ChangeNotifier {
  GuildWarCombatVfxCoordinator({
    this.enableHaptics = true,
  }) {
    _initCoreSystems();
  }

  final bool enableHaptics;

  // ---------------------------------------------------------------------------
  // Core VFX Subsystem Controllers (lib/core/vfx/*)
  // ---------------------------------------------------------------------------

  /// 1. Directional Camera Shake Controller
  late final DirectionalCameraShake cameraShakeController;

  /// 2. Hit-Stop & Time Dilation Manager
  late final HitStopManager hitStopManager;

  /// 3. Rim-Light Hit Flash Controller
  late final RimHitFlashController rimHitFlashController;

  /// 4. Ribbon Trail Renderer & Mesh Streamer
  late final rtr.RibbonTrail bladeRibbonTrail;

  /// 5. Ground Decal Projection System
  late final gds.GroundDecalSystem groundDecalSystem;

  /// 6. Multi-Layer GPU Particle System
  late final GpuParticleSystem gpuParticleSystem;

  /// 9. Knockback Ragdoll Controllers for Fortress Battle Entities
  late final KnockbackRagdollController fortressGateRagdoll;
  late final KnockbackRagdollController defenderTroopRagdoll;
  late final KnockbackRagdollController attackerCommanderRagdoll;
  late final KnockbackRagdollController defenderCommanderRagdoll;

  /// 10. Refraction & Distortion Shader Controller
  late final RefractionShaderController refractionController;

  // ---------------------------------------------------------------------------
  // Internal State & Fallback 2D Buffers for Viewport Painters
  // ---------------------------------------------------------------------------

  double _trauma = 0.0;
  Offset _shakeOffset = Offset.zero;
  double _shakeRotation = 0.0;
  final math.Random _rng = math.Random(1337);

  bool _isHitStopped = false;
  double _timeDilation = 1.0;
  Timer? _hitStopTimer;

  double _rimFlashIntensity = 0.0;
  Color _rimFlashColor = const Color(0xFF00E5FF);

  final List<SiegeWeaponTrail> _weaponTrails = [];
  final List<SiegeDecal> _decals = [];
  final List<SiegeParticle> _particles = [];
  final List<SiegeDamageNumber> _damageNumbers = [];

  // Troop Flinching & Gate Knockback
  final TroopFlinchState defenderTroopFlinch = TroopFlinchState();
  final TroopFlinchState fortressGateFlinch = TroopFlinchState();
  final TroopFlinchState attackerCommanderFlinch = TroopFlinchState();
  final TroopFlinchState defenderCommanderFlinch = TroopFlinchState();

  // ---------------------------------------------------------------------------
  // Coordinator Event Callbacks
  // ---------------------------------------------------------------------------

  /// Fired whenever a siege combat strike resolves (damage dealt, type, critical)
  void Function(SiegeDamageType damageType, Offset impactPoint, int damage, bool isCritical)? onSiegeDamageEvent;

  /// Fired when camera trauma / shake triggers
  void Function(double trauma, Offset direction)? onCameraShakeTriggered;

  /// Fired when hit-stop micro-freeze triggers
  void Function(HitStopPreset preset, Duration duration)? onHitStopTriggered;

  /// Fired when rim flash or faction aura illuminates
  void Function(Offset origin, Color tint)? onRimFlashTriggered;

  /// Fired when ground / wall decal is stamped
  void Function(SiegeDecal decal)? onDecalSpawned;

  /// Fired when particle emitter bursts
  void Function(Offset origin, int particleCount)? onParticleBurstTriggered;

  /// Fired when knockback impulse is delivered
  void Function(KnockbackVector3 impulse)? onKnockbackTriggered;

  /// Fired when refraction shockwave or critical blast expands
  void Function(Offset origin, RefractionEffectMode mode)? onRefractionTriggered;

  /// Fired when floating combat number spawns
  void Function(SiegeDamageNumber damageNumber)? onDamageNumberSpawned;

  // ---------------------------------------------------------------------------
  // Getters for Viewport Painters & Subsystem Access
  // ---------------------------------------------------------------------------

  double get trauma => math.max(_trauma, cameraShakeController.trauma);

  Offset get shakeOffset => cameraShakeController.isActive
      ? cameraShakeController.state.translation
      : _shakeOffset;

  double get shakeRotation => cameraShakeController.isActive
      ? cameraShakeController.state.roll
      : _shakeRotation;

  bool get isHitStopped => _isHitStopped || hitStopManager.activeCount > 0;
  double get timeDilation => _timeDilation;

  double get rimFlashIntensity => rimHitFlashController.isFlashing
      ? rimHitFlashController.currentIntensity
      : _rimFlashIntensity;

  Color get rimFlashColor => rimHitFlashController.isFlashing
      ? rimHitFlashController.config.tint
      : _rimFlashColor;

  List<SiegeWeaponTrail> get weaponTrails => _weaponTrails;
  List<SiegeDecal> get decals => _decals;
  List<SiegeParticle> get particles => _particles;
  List<SiegeDamageNumber> get damageNumbers => _damageNumbers;

  // Direct Core Subsystem Accessors
  DirectionalCameraShake get cameraShake => cameraShakeController;
  HitStopManager get hitStop => hitStopManager;
  RimHitFlashController get rimHitFlash => rimHitFlashController;
  rtr.RibbonTrail get ribbonTrail => bladeRibbonTrail;
  gds.GroundDecalSystem get groundDecals => groundDecalSystem;
  GpuParticleSystem get gpuParticles => gpuParticleSystem;
  KnockbackRagdollController get gateRagdoll => fortressGateRagdoll;
  KnockbackRagdollController get troopRagdoll => defenderTroopRagdoll;
  KnockbackRagdollController get attackerRagdoll => attackerCommanderRagdoll;
  KnockbackRagdollController get defenderRagdoll => defenderCommanderRagdoll;
  RefractionShaderController get refraction => refractionController;

  // ---------------------------------------------------------------------------
  // Subsystem Initialization
  // ---------------------------------------------------------------------------
  void _initCoreSystems() {
    // 1. Camera Shake Controller
    cameraShakeController = DirectionalCameraShake(
      config: CameraShakePreset.heavyCrit.config,
    );
    cameraShakeController.addListener(notifyListeners);

    // 2. Hit-Stop Manager
    hitStopManager = HitStopManager();
    hitStopManager.addListener(notifyListeners);

    // 3. Rim-Light Hit Flash Controller
    rimHitFlashController = RimHitFlashController();
    rimHitFlashController.addListener(notifyListeners);

    // 4. Ribbon Trail Renderer
    bladeRibbonTrail = rtr.RibbonTrail(
      config: const rtr.RibbonTrailConfig(
        lifetime: 0.40,
        startWidthMultiplier: 1.25,
        endWidthMultiplier: 0.15,
        baseColor: Color(0xFF00E5FF),
        glowColor: Color(0xFF80D8FF),
        glowIntensity: 2.5,
      ),
    );

    // 5. Ground Decal System
    groundDecalSystem = gds.GroundDecalSystem(maxDecals: 64);

    // 6. GPU Particle System
    gpuParticleSystem = GpuParticlePresets.spellArcaneBlast();

    // 9. Knockback Ragdoll Controllers
    fortressGateRagdoll = KnockbackRagdollController(
      config: KnockbackConfig.bossPoise,
    );
    defenderTroopRagdoll = KnockbackRagdollController(
      config: KnockbackConfig.heavySmash,
    );
    attackerCommanderRagdoll = KnockbackRagdollController(
      config: KnockbackConfig.mediumHit,
    );
    defenderCommanderRagdoll = KnockbackRagdollController(
      config: KnockbackConfig.mediumHit,
    );

    // 10. Refraction & Wavefront Distortion Shader Controller
    refractionController = RefractionShaderController();
    refractionController.addListener(notifyListeners);
  }

  // ---------------------------------------------------------------------------
  // Frame Update Loop (Advanced by Viewport Ticker)
  // ---------------------------------------------------------------------------
  void update(double dt) {
    // 1. Evaluate Hit-Stop & Time Dilation
    hitStopManager.update(dt);
    if (hitStopManager.activeCount > 0) {
      _isHitStopped = true;
      _timeDilation = hitStopManager.getTimeScale(TimeDilationChannel.target);
      dt *= _timeDilation;
    } else if (_isHitStopped) {
      dt *= _timeDilation;
    }

    // 2. Step Camera Shake Simulation
    cameraShakeController.update(dt);
    if (_trauma > 0.0) {
      _trauma = math.max(0.0, _trauma - dt * 1.5);
      final double shake = _trauma * _trauma;
      final double angle = _rng.nextDouble() * 2 * math.pi;
      final double mag = shake * 24.0;
      _shakeOffset = Offset(math.cos(angle) * mag, math.sin(angle) * mag);
      _shakeRotation = (_rng.nextDouble() * 2.0 - 1.0) * 0.04 * shake;
    } else {
      _shakeOffset = Offset.zero;
      _shakeRotation = 0.0;
    }

    // 3. Step Rim Hit Flash Decay
    rimHitFlashController.update(dt);
    if (!rimHitFlashController.isFlashing && _rimFlashIntensity > 0.0) {
      _rimFlashIntensity = math.max(0.0, _rimFlashIntensity - dt * 4.0);
    }

    // 4. Step Refraction Shader Wavefront
    refractionController.update(dt);

    // 5. Step Ground Decals Simulation
    groundDecalSystem.update(dt);
    _decals.removeWhere((d) => d.isExpired);

    // 6. Step Ribbon Trails
    bladeRibbonTrail.update(dt);

    // 7. Step GPU Particles & 2D Particles
    gpuParticleSystem.update(dt);
    _particles.removeWhere((p) => !p.update(dt));

    // 8. Step Floating Damage Numbers
    _damageNumbers.removeWhere((n) => !n.update(dt));

    // 9. Step Knockback Physics & Ragdoll Kinematics
    fortressGateRagdoll.update(dt);
    defenderTroopRagdoll.update(dt);
    attackerCommanderRagdoll.update(dt);
    defenderCommanderRagdoll.update(dt);

    defenderTroopFlinch.update(dt);
    fortressGateFlinch.update(dt);
    attackerCommanderFlinch.update(dt);
    defenderCommanderFlinch.update(dt);

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Module 1: Camera Shake Triggers
  // ---------------------------------------------------------------------------
  void addTrauma(double amount, {Offset? hitDirection}) {
    _trauma = (_trauma + amount).clamp(0.0, 1.0);
    cameraShakeController.addTrauma(amount, hitDirection: hitDirection);
    onCameraShakeTriggered?.call(_trauma, hitDirection ?? Offset.zero);
    notifyListeners();
  }

  void triggerCatapultShake() {
    cameraShakeController.triggerPreset(
      CameraShakePreset.explosiveShock,
      hitDirection: const Offset(0.0, 1.0),
    );
    addTrauma(0.55, hitDirection: const Offset(0.0, 1.0));
  }

  void triggerGateSmashTremor() {
    cameraShakeController.triggerPreset(
      CameraShakePreset.heavyCrit,
      hitDirection: const Offset(0.0, 1.0),
    );
    addTrauma(0.85, hitDirection: const Offset(0.0, 1.0));
  }

  void triggerCommanderClashShake() {
    cameraShakeController.triggerPreset(
      CameraShakePreset.microVibration,
      hitDirection: const Offset(1.0, 0.0),
    );
    addTrauma(0.42, hitDirection: const Offset(1.0, 0.0));
  }

  // ---------------------------------------------------------------------------
  // Module 2: Hit-Stop Engine (30-50ms target freeze)
  // ---------------------------------------------------------------------------
  void triggerHitStop({
    Duration duration = const Duration(milliseconds: 40),
    HitStopPreset preset = HitStopPreset.medium,
  }) {
    _hitStopTimer?.cancel();
    _isHitStopped = true;
    _timeDilation = 0.05; // 95% time freeze

    hitStopManager.trigger(HitStopRequest(
      id: 'hitstop_${DateTime.now().microsecondsSinceEpoch}',
      freezeDuration: duration,
      easeOutDuration: const Duration(milliseconds: 15),
      targetTimeScale: 0.0,
      channels: TimeDilationChannel.combatPair,
      resumptionCurve: HitStopResumptionCurve.smoothStep,
      onComplete: () {
        _isHitStopped = false;
        _timeDilation = 1.0;
        notifyListeners();
      },
    ));

    onHitStopTriggered?.call(preset, duration);
    notifyListeners();

    _hitStopTimer = Timer(duration, () {
      _isHitStopped = false;
      _timeDilation = 1.0;
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------------
  // Module 3: Rim Flash Faction Aura
  // ---------------------------------------------------------------------------
  void triggerRimFlash({required Color tint, double intensity = 1.0}) {
    _rimFlashColor = tint;
    _rimFlashIntensity = intensity.clamp(0.0, 1.0);

    rimHitFlashController.triggerHit(
      config: RimHitFlashConfig(
        duration: const Duration(milliseconds: 130),
        tint: tint,
        rimIntensity: intensity * 2.2,
        bloomMultiplier: 2.5,
        hitStopDuration: const Duration(milliseconds: 35),
      ),
      intensityMultiplier: intensity,
    );

    onRimFlashTriggered?.call(Offset.zero, tint);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Module 4: Weapon Ribbon Trails
  // ---------------------------------------------------------------------------
  void spawnSiegeArrowVolleyTrail({
    required Offset start,
    required Offset target,
    required double now,
  }) {
    final trail = SiegeWeaponTrail(
      id: 'trail_arrow_${DateTime.now().microsecondsSinceEpoch}',
      primaryColor: const Color(0xFFFFD54F),
      glowColor: const Color(0xFFFF9100),
      maxDuration: 0.45,
    );
    const int steps = 6;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final pos = Offset.lerp(start, target, t)!;
      final arcY = pos.dy - math.sin(t * math.pi) * 45.0;
      final currentPt = Offset(pos.dx, arcY);
      final basePt = Offset(pos.dx - 4, arcY + 2);
      trail.addPoint(
        currentPt,
        basePt,
        now + t * 0.25,
        5.0 * (1.0 - t * 0.4),
      );

      // Stream to RibbonTrail mesh renderer
      bladeRibbonTrail.addSample(
        tip: currentPt,
        base: basePt,
        timestamp: now + t * 0.25,
        width: 5.0 * (1.0 - t * 0.4),
        color: const Color(0xFFFFD54F),
      );
    }
    _weaponTrails.add(trail);
    notifyListeners();
  }

  void spawnCommanderBladeSwingTrail({
    required Offset origin,
    required double angle,
    required double now,
    bool isElyos = true,
  }) {
    final trail = SiegeWeaponTrail(
      id: 'trail_blade_${DateTime.now().microsecondsSinceEpoch}',
      primaryColor: isElyos ? const Color(0xFF00E5FF) : const Color(0xFFFF1744),
      glowColor: isElyos ? const Color(0xFFE0F7FA) : const Color(0xFFFF8A80),
      maxDuration: 0.35,
    );
    const int steps = 8;
    const double arcSpan = math.pi * 0.6;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final currentAngle = angle - arcSpan * 0.5 + arcSpan * t;
      final dir = Offset(math.cos(currentAngle), math.sin(currentAngle));
      final tip = origin + dir * 65.0;
      final base = origin + dir * 15.0;
      trail.addPoint(tip, base, now + t * 0.15, 12.0);

      // Stream to RibbonTrail mesh renderer
      bladeRibbonTrail.addSample(
        tip: tip,
        base: base,
        timestamp: now + t * 0.15,
        width: 12.0 * (1.0 - t * 0.3),
        color: isElyos ? const Color(0xFF00E5FF) : const Color(0xFFFF1744),
      );
    }
    _weaponTrails.add(trail);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Module 5: Dynamic Ground & Wall Decals
  // ---------------------------------------------------------------------------
  void spawnDecal({
    required Offset position,
    required SiegeDecalType type,
    double radius = 32.0,
  }) {
    final decal = SiegeDecal(
      id: 'decal_${DateTime.now().microsecondsSinceEpoch}',
      position: position,
      radius: radius,
      rotation: _rng.nextDouble() * 2 * math.pi,
      type: type,
      primaryColor: type == SiegeDecalType.burningCrater
          ? const Color(0xFFFF5722)
          : type == SiegeDecalType.wallScorch
              ? const Color(0xFF212121)
              : const Color(0xFF8D6E63),
      secondaryColor: const Color(0xFFFFAB00),
    );
    _decals.add(decal);
    if (_decals.length > 20) {
      _decals.removeAt(0);
    }

    // Stamp into OBB Ground Decal System
    gds.DecalType coreDecalType;
    switch (type) {
      case SiegeDecalType.burningCrater:
      case SiegeDecalType.wallScorch:
        coreDecalType = gds.DecalType.scorchMark;
        break;
      case SiegeDecalType.crackedEarthFissure:
        coreDecalType = gds.DecalType.crackedEarth;
        break;
      case SiegeDecalType.bladeGouge:
        coreDecalType = gds.DecalType.slashGouge;
        break;
    }

    groundDecalSystem.spawnDecal(
      type: coreDecalType,
      position: gds.Vector3D(position.dx, 0.0, position.dy),
      size: gds.Vector3D(radius * 2.0, radius * 2.0, 1.0),
      color: decal.primaryColor,
      lifetime: decal.lifetime.inMilliseconds / 1000.0,
    );

    onDecalSpawned?.call(decal);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Module 6: Particle Emitter (Multi-Layer GPU & Viewport 2D)
  // ---------------------------------------------------------------------------
  void emitSiegeBlastParticles({
    required Offset origin,
    int count = 28,
  }) {
    // 1. Emit into GPU Particle System
    gpuParticleSystem.emitAllLayersBurst(
      countPerLayer: math.max(6, (count / 4).round()),
      origin: origin,
    );

    // 2. Emit into Local 2D Particle Pool
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final speed = 80.0 + _rng.nextDouble() * 220.0;
      final vel = Offset(math.cos(angle) * speed, math.sin(angle) * speed - 60.0);

      SiegeParticleType type;
      Color color;
      double gravity = 140.0;
      double scale = 2.0 + _rng.nextDouble() * 4.0;

      if (i % 4 == 0) {
        type = SiegeParticleType.smokePlume;
        color = const Color(0xFF424242);
        gravity = -30.0; // Drifts upward
        scale = 8.0 + _rng.nextDouble() * 10.0;
      } else if (i % 3 == 0) {
        type = SiegeParticleType.stoneDebris;
        color = const Color(0xFF757575);
      } else if (i % 2 == 0) {
        type = SiegeParticleType.fieryEmber;
        color = const Color(0xFFFF6D00);
        gravity = -15.0;
      } else {
        type = SiegeParticleType.metalSpark;
        color = const Color(0xFFFFD54F);
        scale = 1.8;
      }

      _particles.add(SiegeParticle(
        position: origin,
        velocity: vel,
        scale: scale,
        rotation: _rng.nextDouble() * 2 * math.pi,
        rotationSpeed: (_rng.nextDouble() * 2.0 - 1.0) * 8.0,
        color: color,
        decaySpeed: 0.8 + _rng.nextDouble() * 1.4,
        type: type,
        gravity: gravity,
      ));
    }

    onParticleBurstTriggered?.call(origin, count);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Module 7: Haptic Siege Vibration Pulses
  // ---------------------------------------------------------------------------
  Future<void> triggerHeavySiegeHaptics() async {
    if (!enableHaptics) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  Future<void> triggerGateTremorHaptics() async {
    if (!enableHaptics) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  Future<void> triggerCommanderClashHaptics() async {
    if (!enableHaptics) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Module 8: Floating Damage Numbers (Mass Battle Multi-Target)
  // ---------------------------------------------------------------------------
  void spawnDamageNumber({
    required Offset position,
    required int amount,
    required SiegeDamageType damageType,
    bool isCritical = false,
  }) {
    final scatterX = (_rng.nextDouble() * 2.0 - 1.0) * 35.0;
    final initialVel = Offset(scatterX, -110.0 - _rng.nextDouble() * 50.0);

    final num = SiegeDamageNumber(
      id: 'dmg_${DateTime.now().microsecondsSinceEpoch}_${_rng.nextInt(9999)}',
      text: isCritical ? '! KRİTİK -$amount' : '-$amount',
      position: position + Offset(scatterX * 0.4, 0),
      velocity: initialVel,
      color: isCritical ? const Color(0xFFFFD700) : damageType.color,
      isCritical: isCritical,
      scale: isCritical ? 1.3 : 1.0,
    );
    _damageNumbers.add(num);
    onDamageNumberSpawned?.call(num);
    notifyListeners();
  }

  void spawnMassBattleDamageVolley({
    required Offset center,
    required List<int> damages,
    required SiegeDamageType damageType,
  }) {
    for (int i = 0; i < damages.length; i++) {
      final spreadOffset = Offset(
        (i - damages.length / 2) * 28.0 + (_rng.nextDouble() * 12.0 - 6.0),
        (_rng.nextDouble() * 20.0 - 10.0),
      );
      final bool isCrit = i == 0 || (i % 3 == 0);
      spawnDamageNumber(
        position: center + spreadOffset,
        amount: damages[i],
        damageType: damageType,
        isCritical: isCrit,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Module 9: Knockback & Troop Flinching
  // ---------------------------------------------------------------------------
  void applyGateSmashImpulse() {
    fortressGateFlinch.applyImpulse(const Offset(0, 18.0), 0.08);
    defenderTroopFlinch.applyImpulse(const Offset(14.0, -8.0), -0.15);

    final impulse = const KnockbackVector3(0.0, 4.0, 18.0);
    fortressGateRagdoll.applyImpulse(KnockbackImpulse(
      impulse: impulse,
      verticalLaunchImpulse: 4.0,
    ));
    defenderTroopRagdoll.applyImpulse(const KnockbackImpulse(
      impulse: KnockbackVector3(14.0, 6.0, -8.0),
      verticalLaunchImpulse: 6.0,
    ));

    onKnockbackTriggered?.call(impulse);
    notifyListeners();
  }

  void applyCatapultBarrageImpulse() {
    defenderTroopFlinch.applyImpulse(const Offset(-18.0, 12.0), 0.22);

    final impulse = const KnockbackVector3(-18.0, 10.0, 12.0);
    defenderTroopRagdoll.applyImpulse(KnockbackImpulse(
      impulse: impulse,
      verticalLaunchImpulse: 10.0,
      isCriticalHit: true,
    ));

    onKnockbackTriggered?.call(impulse);
    notifyListeners();
  }

  void applyCommanderClashImpulse() {
    attackerCommanderFlinch.applyImpulse(const Offset(-12.0, 4.0), -0.10);
    defenderCommanderFlinch.applyImpulse(const Offset(16.0, -6.0), 0.14);

    attackerCommanderRagdoll.applyImpulse(const KnockbackImpulse(
      impulse: KnockbackVector3(-12.0, 3.0, 4.0),
      verticalLaunchImpulse: 3.0,
    ));
    defenderCommanderRagdoll.applyImpulse(const KnockbackImpulse(
      impulse: KnockbackVector3(16.0, 3.0, -6.0),
      verticalLaunchImpulse: 3.0,
    ));

    onKnockbackTriggered?.call(const KnockbackVector3(16.0, 3.0, -6.0));
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Orchestrated Siege Events Wiring All 9 Modules Together
  // ---------------------------------------------------------------------------

  /// Siege Event 1: Catapult / Trebuchet Boulder Impact
  void executeCatapultBoulderStrike({
    required Offset impactPoint,
    required int damage,
    bool isCritical = false,
  }) {
    // 1. Camera Shake (catapult earth tremors with explosive shock preset)
    triggerCatapultShake();

    // 2. Hit-Stop (45ms micro freeze-frame on boulder smash)
    triggerHitStop(
      duration: const Duration(milliseconds: 45),
      preset: HitStopPreset.medium,
    );

    // 3. Rim Flash (fiery impact flash and ambient rim aura)
    triggerRimFlash(
      tint: SiegeDamageType.catapultBoulder.rimFlashTint,
      intensity: 0.95,
    );

    // 4. Weapon Trails (flaming ballistic trajectory ribbon)
    spawnSiegeArrowVolleyTrail(
      start: impactPoint + const Offset(-180, -220),
      target: impactPoint,
      now: DateTime.now().millisecondsSinceEpoch / 1000.0,
    );

    // 5. Dynamic Decals (burning ground crater and OBB projection)
    spawnDecal(
      position: impactPoint,
      type: SiegeDecalType.burningCrater,
      radius: 42.0,
    );

    // 6. Particles (smoke plume, fiery embers, flying stone blast debris)
    emitSiegeBlastParticles(origin: impactPoint, count: 36);

    // 7. Haptics (heavy siege vibration pulse)
    triggerHeavySiegeHaptics();

    // 8. Floating Damage Numbers (cinematic critical typography)
    spawnDamageNumber(
      position: impactPoint,
      amount: damage,
      damageType: SiegeDamageType.catapultBoulder,
      isCritical: isCritical,
    );

    // 9. Knockback & troop flinching
    applyCatapultBarrageImpulse();

    // 10. Refraction shockwave wavefront blast
    refractionController.triggerShockwave(
      center: Offset(
        (impactPoint.dx / 400.0).clamp(0.1, 0.9),
        (impactPoint.dy / 360.0).clamp(0.1, 0.9),
      ),
      maxRadius: 0.85,
      thickness: 0.10,
      strength: 0.065,
      chromaticAberration: 0.035,
      duration: const Duration(milliseconds: 550),
    );
    onRefractionTriggered?.call(impactPoint, RefractionEffectMode.shockwave);

    onSiegeDamageEvent?.call(SiegeDamageType.catapultBoulder, impactPoint, damage, isCritical);
  }

  /// Siege Event 2: Fortress Gate Battering Ram Smash
  void executeGateSmashStrike({
    required Offset gateCenter,
    required int damage,
  }) {
    // 1. Camera Shake (heavy gate impact tremor)
    triggerGateSmashTremor();

    // 2. Hit-Stop (50ms impact freeze)
    triggerHitStop(
      duration: const Duration(milliseconds: 50),
      preset: HitStopPreset.heavy,
    );

    // 3. Rim Flash (faction crest crimson defense flash)
    triggerRimFlash(
      tint: SiegeFaction.asmodian.auraColor,
      intensity: 1.0,
    );

    // 5. Dynamic Decals (wall scorch and gate stress cracks)
    spawnDecal(
      position: gateCenter,
      type: SiegeDecalType.wallScorch,
      radius: 36.0,
    );
    spawnDecal(
      position: gateCenter + const Offset(0, 30),
      type: SiegeDecalType.crackedEarthFissure,
      radius: 48.0,
    );

    // 6. Particles (gate splinters & masonry debris)
    emitSiegeBlastParticles(origin: gateCenter, count: 42);

    // 7. Haptics (earth tremor pulse)
    triggerGateTremorHaptics();

    // 8. Floating Damage Numbers
    spawnDamageNumber(
      position: gateCenter,
      amount: damage,
      damageType: SiegeDamageType.gateBatteringRam,
      isCritical: true,
    );

    // 9. Knockback & troop flinching
    applyGateSmashImpulse();

    // 10. Refraction shockwave distortion
    refractionController.triggerShockwave(
      center: Offset(
        (gateCenter.dx / 400.0).clamp(0.1, 0.9),
        (gateCenter.dy / 360.0).clamp(0.1, 0.9),
      ),
      maxRadius: 0.95,
      thickness: 0.12,
      strength: 0.08,
      chromaticAberration: 0.045,
      duration: const Duration(milliseconds: 600),
    );
    onRefractionTriggered?.call(gateCenter, RefractionEffectMode.shockwave);

    onSiegeDamageEvent?.call(SiegeDamageType.gateBatteringRam, gateCenter, damage, true);
  }

  /// Siege Event 3: Commander Duel Clash
  void executeCommanderDuelClash({
    required Offset clashPoint,
    required int attackerDamage,
    required int defenderDamage,
    bool isElyosAttacker = true,
  }) {
    // 1. Camera Shake (crisp duel clash micro-vibration)
    triggerCommanderClashShake();

    // 2. Hit-Stop (35ms duel micro-pause)
    triggerHitStop(
      duration: const Duration(milliseconds: 35),
      preset: HitStopPreset.light,
    );

    // 3. Rim Flash (opposing faction aura clash)
    triggerRimFlash(
      tint: isElyosAttacker ? SiegeFaction.elyos.auraColor : SiegeFaction.asmodian.auraColor,
      intensity: 0.85,
    );

    // 4. Weapon Trails (dual blade swing ribbons)
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    spawnCommanderBladeSwingTrail(
      origin: clashPoint + const Offset(-20, 0),
      angle: -0.4,
      now: now,
      isElyos: isElyosAttacker,
    );
    spawnCommanderBladeSwingTrail(
      origin: clashPoint + const Offset(20, 0),
      angle: math.pi - 0.4,
      now: now,
      isElyos: !isElyosAttacker,
    );

    // 5. Dynamic Decals (blade gouges on ground)
    spawnDecal(
      position: clashPoint,
      type: SiegeDecalType.bladeGouge,
      radius: 28.0,
    );

    // 6. Particles (clashing metal sparks)
    emitSiegeBlastParticles(origin: clashPoint, count: 20);

    // 7. Haptics
    triggerCommanderClashHaptics();

    // 8. Floating Damage Numbers (both commanders take reciprocal duel damage)
    spawnDamageNumber(
      position: clashPoint + const Offset(-30, -10),
      amount: attackerDamage,
      damageType: SiegeDamageType.commanderSlash,
      isCritical: true,
    );
    spawnDamageNumber(
      position: clashPoint + const Offset(30, -10),
      amount: defenderDamage,
      damageType: SiegeDamageType.commanderSlash,
      isCritical: false,
    );

    // 9. Knockback & troop flinching
    applyCommanderClashImpulse();

    // 10. Refraction critical blast
    refractionController.triggerCriticalHit(
      center: Offset(
        (clashPoint.dx / 400.0).clamp(0.1, 0.9),
        (clashPoint.dy / 360.0).clamp(0.1, 0.9),
      ),
      maxRadius: 0.75,
      strength: 0.06,
      chromaticAberration: 0.03,
      duration: const Duration(milliseconds: 400),
    );
    onRefractionTriggered?.call(clashPoint, RefractionEffectMode.criticalHit);

    onSiegeDamageEvent?.call(SiegeDamageType.commanderSlash, clashPoint, attackerDamage, true);
  }

  /// Siege Event 4: Mass Arrow Volley Barrage
  void executeArrowVolleyBarrage({
    required Offset targetArea,
    required List<int> arrowDamages,
  }) {
    addTrauma(0.35, hitDirection: const Offset(0.0, 1.0));
    triggerHitStop(duration: const Duration(milliseconds: 25), preset: HitStopPreset.glance);
    triggerRimFlash(tint: SiegeDamageType.siegeArrowVolley.rimFlashTint, intensity: 0.7);

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    for (int i = 0; i < 4; i++) {
      final startOffset = targetArea + Offset(-120.0 - i * 30.0, -180.0 - i * 20.0);
      final destOffset = targetArea + Offset(i * 24.0 - 36.0, (i % 2 == 0 ? 10.0 : -10.0));
      spawnSiegeArrowVolleyTrail(start: startOffset, target: destOffset, now: now + i * 0.05);
    }

    emitSiegeBlastParticles(origin: targetArea, count: 24);
    spawnMassBattleDamageVolley(
      center: targetArea,
      damages: arrowDamages,
      damageType: SiegeDamageType.siegeArrowVolley,
    );

    defenderTroopFlinch.applyImpulse(const Offset(8.0, -4.0), -0.06);
    notifyListeners();
  }

  /// Siege Event 5: Magical Castle Defense Aura Blast
  void executeMagicalAuraBlast({
    required Offset blastCenter,
    required int damage,
    bool isElyos = true,
  }) {
    final auraColor = isElyos ? SiegeFaction.elyos.auraColor : SiegeFaction.asmodian.auraColor;

    addTrauma(0.70, hitDirection: const Offset(0.0, -1.0));
    triggerHitStop(duration: const Duration(milliseconds: 45), preset: HitStopPreset.medium);
    triggerRimFlash(tint: auraColor, intensity: 1.0);

    refractionController.triggerMagicalShield(
      center: Offset(
        (blastCenter.dx / 400.0).clamp(0.1, 0.9),
        (blastCenter.dy / 360.0).clamp(0.1, 0.9),
      ),
      maxRadius: 0.9,
      strength: 0.075,
      tint: auraColor.withValues(alpha: 0.4),
      duration: const Duration(milliseconds: 650),
    );

    spawnDecal(
      position: blastCenter,
      type: SiegeDecalType.crackedEarthFissure,
      radius: 46.0,
    );

    emitSiegeBlastParticles(origin: blastCenter, count: 48);
    triggerGateTremorHaptics();

    spawnDamageNumber(
      position: blastCenter,
      amount: damage,
      damageType: SiegeDamageType.magicalAuraBlast,
      isCritical: true,
    );

    applyGateSmashImpulse();
    onSiegeDamageEvent?.call(SiegeDamageType.magicalAuraBlast, blastCenter, damage, true);
  }

  @override
  void dispose() {
    _hitStopTimer?.cancel();
    cameraShakeController.removeListener(notifyListeners);
    cameraShakeController.dispose();
    hitStopManager.removeListener(notifyListeners);
    hitStopManager.dispose();
    rimHitFlashController.removeListener(notifyListeners);
    rimHitFlashController.dispose();
    refractionController.removeListener(notifyListeners);
    refractionController.dispose();
    super.dispose();
  }
}

/// Convenience type alias ensuring full naming parity across module imports
typedef SiegeCombatVfxCoordinator = GuildWarCombatVfxCoordinator;
