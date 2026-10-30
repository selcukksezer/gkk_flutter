import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/combat/combat_juice_coordinator.dart';
import '../../../core/vfx/directional_camera_shake.dart';
import '../../../core/vfx/gpu_particle_system.dart';
import '../../../core/vfx/ground_decal_system.dart' as decals;
import '../../../core/vfx/hit_stop_manager.dart';
import '../../../core/vfx/knockback_ragdoll_controller.dart';
import '../../../core/vfx/ribbon_trail_renderer.dart' as ribbon;
import '../../../core/vfx/rim_hit_flash_effect.dart';
import 'dungeon_battle_effects.dart';
import 'dungeon_cave_theme.dart';
import 'dungeon_cinematic_atmosphere.dart';

/// ----------------------------------------------------------------------------
/// Production 2027 AAA Combat Feel & VFX Suite for Dungeon Encounters
/// Requirement R3 (Combat Mechanics, VFX & Game Feel) & R5 (Integration)
///
/// Wires all 9 Combat Juice Modules:
/// 1. Directional Camera Shake (trauma decay + directional recoil impulse)
/// 2. Hit-Stop (30-50ms micro-pause on heavy impacts)
/// 3. Rim Flash (specular outline highlight on hit)
/// 4. Weapon Trails (ribbon arcs with Catmull-Rom interpolation)
/// 5. Dynamic Decals (scorch / blood / impact cracks on 3D terrain)
/// 6. GPU Particles (sparks, impact bursts, embers)
/// 7. Haptics (tactile feedback pulses on impact)
/// 8. Floating Damage Numbers (bouncy overshoot + critical scaling)
/// 9. Knockback & Hit Reactions (physics impulse + spine tilt recoil)
/// ----------------------------------------------------------------------------

enum HapticImpactLevel {
  light,
  medium,
  heavy,
  critical,
}

/// Model representing a floating combat damage number.
class DungeonDamageNumber {
  final String id;
  final int damage;
  final bool isCritical;
  final bool isPlayerTarget; // true if damage taken by player, false if by enemy
  final Offset startOffset;
  double elapsed;
  final double duration;

  DungeonDamageNumber({
    required this.damage,
    required this.isCritical,
    required this.isPlayerTarget,
    required this.startOffset,
    this.elapsed = 0.0,
    this.duration = 1.15,
  }) : id = 'dmg_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(9999)}';

  bool get isExpired => elapsed >= duration;

  /// Normalized progress 0.0 -> 1.0
  double get progress => (elapsed / duration).clamp(0.0, 1.0);

  /// Bouncy scale animation: pops up rapidly, overshoots, settles, then fades.
  double get scale {
    if (progress < 0.18) {
      final double t = progress / 0.18;
      // Spring overshoot
      return isCritical ? (1.25 + 0.60 * _easeOutBack(t)) : (1.0 + 0.30 * _easeOutBack(t));
    } else if (progress < 0.35) {
      final double t = (progress - 0.18) / 0.17;
      return isCritical ? ui.lerpDouble(1.85, 1.45, t)! : ui.lerpDouble(1.3, 1.0, t)!;
    } else {
      return isCritical ? 1.45 : 1.0;
    }
  }

  /// Upward float translation with slight drift.
  Offset get currentOffset {
    final double verticalRise = progress * (isCritical ? 56.0 : 42.0);
    final double horizontalDrift = math.sin(progress * math.pi) * (isPlayerTarget ? -10.0 : 10.0);
    return Offset(startOffset.dx + horizontalDrift, startOffset.dy - verticalRise);
  }

  /// Alpha fade out during the last 35% of lifetime.
  double get opacity {
    if (progress < 0.65) return 1.0;
    final double fadeT = (progress - 0.65) / 0.35;
    return (1.0 - fadeT).clamp(0.0, 1.0);
  }

  static double _easeOutBack(double x) {
    const double c1 = 1.70158;
    const double c3 = c1 + 1.0;
    return 1.0 + c3 * math.pow(x - 1.0, 3) + c1 * math.pow(x - 1.0, 2);
  }
}

// =============================================================================
// VFX System 1: Elemental Sparks Models
// =============================================================================

/// Single particle belonging to an elemental spark burst with ballistic physics.
class ElementalSpark {
  ElementalSpark({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.maxLifetime,
    required this.gravity,
    required this.drag,
    required this.turbulenceFreq,
    required this.turbulenceAmp,
    this.elapsed = 0.0,
  }) : turbulencePhase = math.Random().nextDouble() * math.pi * 2;

  Offset position;
  Offset velocity;
  final Color color;
  final double size;
  final double maxLifetime;
  final double gravity;
  final double drag;
  final double turbulenceFreq;
  final double turbulenceAmp;
  final double turbulencePhase;
  double elapsed;

  bool get isExpired => elapsed >= maxLifetime;
  double get progress => (elapsed / maxLifetime).clamp(0.0, 1.0);

  void update(double dt) {
    elapsed += dt;
    // Ballistic integration with exponential air drag and gravity
    velocity = Offset(
      velocity.dx * math.pow(drag, dt * 60.0),
      (velocity.dy + gravity * dt) * math.pow(drag, dt * 60.0),
    );
    // Curl noise / sinusoidal turbulence micro-perturbations
    final double turbX = math.sin(elapsed * turbulenceFreq + turbulencePhase) * turbulenceAmp * dt;
    final double turbY = math.cos(elapsed * turbulenceFreq + turbulencePhase) * turbulenceAmp * 0.5 * dt;
    position = Offset(position.dx + velocity.dx * dt + turbX, position.dy + velocity.dy * dt + turbY);
  }
}

/// A collection of elemental spark particles emitted together.
class ElementalSparkBatch {
  ElementalSparkBatch({
    required this.sparks,
    required this.elementType,
    required this.origin,
    this.duration = 0.65,
  }) : id = 'spark_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(9999)}';

  final String id;
  final List<ElementalSpark> sparks;
  final HitDamageType elementType;
  final Offset origin;
  final double duration;
  double elapsed = 0.0;

  bool get isExpired => elapsed >= duration || sparks.isEmpty;

  void update(double dt) {
    elapsed += dt;
    for (int i = sparks.length - 1; i >= 0; i--) {
      sparks[i].update(dt);
      if (sparks[i].isExpired) {
        sparks.removeAt(i);
      }
    }
  }
}

// =============================================================================
// VFX System 2: Blood & Energy Slashes Models
// =============================================================================

/// Quadratic Bezier tapered blade slash ribbon with outer glow and optional blood droplets.
class EnergySlashEffect {
  EnergySlashEffect({
    required this.startPoint,
    required this.endPoint,
    required this.controlPoint,
    required this.primaryColor,
    required this.glowColor,
    this.isBlood = false,
    this.strokeWidth = 5.0,
    this.duration = 0.38,
    List<Offset>? bloodDroplets,
  })  : id = 'slash_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(9999)}',
        bloodDroplets = bloodDroplets ?? <Offset>[];

  final String id;
  final Offset startPoint;
  final Offset endPoint;
  final Offset controlPoint;
  final Color primaryColor;
  final Color glowColor;
  final bool isBlood;
  final double strokeWidth;
  final double duration;
  final List<Offset> bloodDroplets;
  double elapsed = 0.0;

  bool get isExpired => elapsed >= duration;
  double get progress => (elapsed / duration).clamp(0.0, 1.0);

  /// Normalized sub-segment [headT, tailT] representing the moving blade window
  double get headT => (progress * 1.6).clamp(0.0, 1.0);
  double get tailT => math.max(0.0, (progress - 0.25) * 1.33).clamp(0.0, 1.0);

  /// Overall alpha fade curve
  double get opacity {
    if (progress < 0.6) return 1.0;
    return (1.0 - (progress - 0.6) / 0.4).clamp(0.0, 1.0);
  }

  void update(double dt) {
    elapsed += dt;
  }
}

// =============================================================================
// VFX System 3: Impact Radial Bursts Models
// =============================================================================

/// High-energy expanding shockwave ring with radiating directional spikes.
class RadialBurstEffect {
  RadialBurstEffect({
    required this.epicenter,
    required this.maxRadius,
    required this.coreColor,
    required this.rimColor,
    this.spikeCount = 14,
    this.duration = 0.42,
  })  : id = 'burst_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(9999)}',
        spikeAngles = List<double>.generate(spikeCount, (int i) => (i * 2 * math.pi / spikeCount) + (math.Random().nextDouble() - 0.5) * 0.25),
        spikeLengths = List<double>.generate(spikeCount, (int i) => 0.75 + math.Random().nextDouble() * 0.5);

  final String id;
  final Offset epicenter;
  final double maxRadius;
  final Color coreColor;
  final Color rimColor;
  final int spikeCount;
  final double duration;
  final List<double> spikeAngles;
  final List<double> spikeLengths;
  double elapsed = 0.0;

  bool get isExpired => elapsed >= duration;
  double get progress => (elapsed / duration).clamp(0.0, 1.0);

  /// Ease-out cubic expansion curve for shockwave pressure wave
  double get radius => maxRadius * (1.0 - math.pow(1.0 - progress, 3.2));

  double get opacity => math.pow(1.0 - progress, 1.8).toDouble().clamp(0.0, 1.0);

  void update(double dt) {
    elapsed += dt;
  }
}

// =============================================================================
// VFX System 4: Spell Circle Animations Models
// =============================================================================

/// Multi-ring concentric arcane matrix with counter-rotating geometry and orbital runes.
class SpellCircleEffect {
  SpellCircleEffect({
    required this.center,
    required this.radius,
    required this.runeColor,
    required this.glowColor,
    this.elementType = HitDamageType.voidEnergy,
    this.duration = 1.6,
    this.rotationSpeed = 1.2,
  })  : id = 'circle_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(9999)}';

  final String id;
  final Offset center;
  final double radius;
  final Color runeColor;
  final Color glowColor;
  final HitDamageType elementType;
  final double duration;
  final double rotationSpeed;
  double elapsed = 0.0;
  double rotation = 0.0;

  bool get isExpired => elapsed >= duration;
  double get progress => (elapsed / duration).clamp(0.0, 1.0);

  /// Breathing expansion scale: pop in with overshoot, breathe, shrink on finish
  double get scale {
    if (progress < 0.18) {
      final double t = progress / 0.18;
      return 0.2 + 0.85 * (1.0 - math.pow(1.0 - t, 3));
    } else if (progress > 0.8) {
      final double t = (progress - 0.8) / 0.2;
      return (1.05 - 0.3 * t).clamp(0.0, 1.1);
    } else {
      final double breath = math.sin((progress - 0.18) * math.pi * 4.0) * 0.04;
      return 1.0 + breath;
    }
  }

  double get opacity {
    if (progress < 0.15) return (progress / 0.15).clamp(0.0, 1.0);
    if (progress > 0.75) return ((1.0 - progress) / 0.25).clamp(0.0, 1.0);
    return 1.0;
  }

  void update(double dt) {
    elapsed += dt;
    rotation += rotationSpeed * dt;
  }
}

// =============================================================================
// VFX System 5: Critical Strike Flashes Models
// =============================================================================

/// Anamorphic optical lens flare with 8-point starburst and high-energy vignette flash.
class CriticalStrikeFlashEffect {
  CriticalStrikeFlashEffect({
    required this.epicenter,
    this.flareColor = const Color(0xFFFFFFFF),
    this.secondaryColor = BattlePalette.warningSolar,
    this.flareWidth = 320.0,
    this.duration = 0.32,
  }) : id = 'crit_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(9999)}';

  final String id;
  final Offset epicenter;
  final Color flareColor;
  final Color secondaryColor;
  final double flareWidth;
  final double duration;
  double elapsed = 0.0;

  bool get isExpired => elapsed >= duration;
  double get progress => (elapsed / duration).clamp(0.0, 1.0);

  /// Intense exponential falloff for lens flare
  double get opacity => math.pow(1.0 - progress, 3.5).toDouble().clamp(0.0, 1.0);

  /// Anamorphic horizontal streak width expansion
  double get currentFlareWidth => flareWidth * (0.8 + 0.6 * (1.0 - math.pow(1.0 - progress, 2)));

  void update(double dt) {
    elapsed += dt;
  }
}

/// Comprehensive Controller managing all 9 Combat Juice & VFX modules for Dungeon battles.
class DungeonCombatVfxController extends ChangeNotifier {
  DungeonCombatVfxController({
    DungeonAtmosphereController? atmosphereController,
  })  : _atmosphereController = atmosphereController,
        cameraShake = DirectionalCameraShake(
          config: const CameraShakeConfig(
            traumaExponent: 2.0,
            decayRate: 2.2,
            maxTranslation: Offset(22.0, 16.0),
            maxRoll: 0.075,
            directionalBiasWeight: 0.85,
          ),
        ),
        hitStopManager = HitStopManager(),
        enemyRimFlash = RimHitFlashController(),
        playerRimFlash = RimHitFlashController(),
        ribbonTrail = ribbon.RibbonTrail(
          config: const ribbon.RibbonTrailConfig(
            lifetime: 0.28,
            baseColor: BattlePalette.liquidGold,
            glowColor: BattlePalette.coralFlare,
            glowIntensity: 3.2,
            startWidthMultiplier: 1.0,
            endWidthMultiplier: 0.1,
          ),
        ),
        enemyKnockback = KnockbackRagdollController(
          config: const KnockbackConfig(
            groundFriction: 8.0,
            gravity: 18.0,
            blendInDuration: 0.05,
            blendOutDuration: 0.28,
          ),
        ),
        playerKnockback = KnockbackRagdollController(
          config: const KnockbackConfig(
            groundFriction: 8.5,
            gravity: 18.0,
            blendInDuration: 0.04,
            blendOutDuration: 0.25,
          ),
        ),
        particleSystem = GpuParticlePresets.weaponImpact() {
    _coordinator = CombatJuiceCoordinator(
      cameraShake: cameraShake,
      hitStopManager: hitStopManager,
      rimFlashController: enemyRimFlash,
      ribbonTrail: ribbonTrail,
      knockbackController: enemyKnockback,
      decalSystem: _atmosphereController?.decalSystem,
      particleSystem: particleSystem,
    );
  }

  final DungeonAtmosphereController? _atmosphereController;
  late final CombatJuiceCoordinator _coordinator;

  final DirectionalCameraShake cameraShake;
  final HitStopManager hitStopManager;
  final RimHitFlashController enemyRimFlash;
  final RimHitFlashController playerRimFlash;
  final ribbon.RibbonTrail ribbonTrail;
  final KnockbackRagdollController enemyKnockback;
  final KnockbackRagdollController playerKnockback;
  final GpuParticleSystem particleSystem;

  final List<DungeonDamageNumber> _damageNumbers = <DungeonDamageNumber>[];
  List<DungeonDamageNumber> get damageNumbers => List.unmodifiable(_damageNumbers);

  final List<ElementalSparkBatch> _sparks = <ElementalSparkBatch>[];
  List<ElementalSparkBatch> get activeSparks => List.unmodifiable(_sparks);

  final List<EnergySlashEffect> _slashes = <EnergySlashEffect>[];
  List<EnergySlashEffect> get activeSlashes => List.unmodifiable(_slashes);

  final List<RadialBurstEffect> _radialBursts = <RadialBurstEffect>[];
  List<RadialBurstEffect> get activeRadialBursts => List.unmodifiable(_radialBursts);

  final List<SpellCircleEffect> _spellCircles = <SpellCircleEffect>[];
  List<SpellCircleEffect> get activeSpellCircles => List.unmodifiable(_spellCircles);

  final List<CriticalStrikeFlashEffect> _criticalFlashes = <CriticalStrikeFlashEffect>[];
  List<CriticalStrikeFlashEffect> get activeCriticalFlashes => List.unmodifiable(_criticalFlashes);

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  /// Connects or updates the external atmospheric decals controller.
  void setAtmosphereController(DungeonAtmosphereController controller) {
    _coordinator.decalSystem = controller.decalSystem;
  }

  // ---------------------------------------------------------------------------
  // Frame Update Loop (Advances all 9 modules synchronously)
  // ---------------------------------------------------------------------------

  void update(double dt) {
    if (dt <= 0.0 || _isDisposed) return;

    // Apply Hit-Stop time dilation to game simulation
    final double timeScale = hitStopManager.getTimeScale();
    final double scaledDt = dt * timeScale;

    cameraShake.update(dt); // Shake continues during hit-stop
    hitStopManager.update(dt);
    enemyRimFlash.update(dt);
    playerRimFlash.update(dt);
    ribbonTrail.update(scaledDt > 0 ? scaledDt : 0.001);
    enemyKnockback.update(scaledDt);
    playerKnockback.update(scaledDt);
    particleSystem.update(dt);

    // Update active elemental spark batches
    for (int i = _sparks.length - 1; i >= 0; i--) {
      _sparks[i].update(dt);
      if (_sparks[i].isExpired) {
        _sparks.removeAt(i);
      }
    }

    // Update active energy & blood slashes
    for (int i = _slashes.length - 1; i >= 0; i--) {
      _slashes[i].update(dt);
      if (_slashes[i].isExpired) {
        _slashes.removeAt(i);
      }
    }

    // Update active impact radial bursts
    for (int i = _radialBursts.length - 1; i >= 0; i--) {
      _radialBursts[i].update(dt);
      if (_radialBursts[i].isExpired) {
        _radialBursts.removeAt(i);
      }
    }

    // Update active spell circles
    for (int i = _spellCircles.length - 1; i >= 0; i--) {
      _spellCircles[i].update(dt);
      if (_spellCircles[i].isExpired) {
        _spellCircles.removeAt(i);
      }
    }

    // Update active critical strike flashes
    for (int i = _criticalFlashes.length - 1; i >= 0; i--) {
      _criticalFlashes[i].update(dt);
      if (_criticalFlashes[i].isExpired) {
        _criticalFlashes.removeAt(i);
      }
    }

    // Update floating damage numbers
    for (int i = _damageNumbers.length - 1; i >= 0; i--) {
      _damageNumbers[i].elapsed += dt;
      if (_damageNumbers[i].isExpired) {
        _damageNumbers.removeAt(i);
      }
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Combat Event Triggers
  // ---------------------------------------------------------------------------

  /// Spawns a batch of elemental sparks with distinct particle physics per damage type.
  void triggerElementalSparks({
    required Offset origin,
    HitDamageType elementType = HitDamageType.fire,
    int count = 28,
    double speedMultiplier = 1.0,
  }) {
    if (_isDisposed) return;

    final math.Random rng = math.Random();
    final List<ElementalSpark> list = <ElementalSpark>[];

    // Configure elemental parameters
    Color sparkBaseColor;
    double gravity;
    double drag;
    double turbulenceFreq;
    double turbulenceAmp;
    double lifetimeBase;

    switch (elementType) {
      case HitDamageType.fire:
        sparkBaseColor = BattlePalette.coralFlare;
        gravity = -35.0; // Upward convection
        drag = 0.94;
        turbulenceFreq = 18.0;
        turbulenceAmp = 45.0;
        lifetimeBase = 0.55;
        break;
      case HitDamageType.frost:
        sparkBaseColor = const Color(0xFF64D2FF);
        gravity = 20.0;
        drag = 0.96;
        turbulenceFreq = 12.0;
        turbulenceAmp = 20.0;
        lifetimeBase = 0.65;
        break;
      case HitDamageType.lightning:
        sparkBaseColor = BattlePalette.warningSolar;
        gravity = 0.0;
        drag = 0.90;
        turbulenceFreq = 35.0; // Rapid zig-zag
        turbulenceAmp = 90.0;
        lifetimeBase = 0.38;
        break;
      case HitDamageType.poison:
        sparkBaseColor = BattlePalette.toxicNeon;
        gravity = 65.0; // Heavy viscous drip
        drag = 0.92;
        turbulenceFreq = 10.0;
        turbulenceAmp = 25.0;
        lifetimeBase = 0.60;
        break;
      case HitDamageType.holy:
        sparkBaseColor = const Color(0xFFFFF7C2);
        gravity = -20.0;
        drag = 0.95;
        turbulenceFreq = 8.0;
        turbulenceAmp = 30.0;
        lifetimeBase = 0.70;
        break;
      case HitDamageType.voidEnergy:
        sparkBaseColor = const Color(0xFFBF5AF2);
        gravity = -5.0;
        drag = 0.93;
        turbulenceFreq = 22.0;
        turbulenceAmp = 50.0;
        lifetimeBase = 0.58;
        break;
      case HitDamageType.physical:
        sparkBaseColor = BattlePalette.liquidGold;
        gravity = 45.0;
        drag = 0.93;
        turbulenceFreq = 14.0;
        turbulenceAmp = 35.0;
        lifetimeBase = 0.48;
        break;
    }

    final int effectiveCount = math.min(count, 45);
    for (int i = 0; i < effectiveCount; i++) {
      final double angle = rng.nextDouble() * math.pi * 2;
      final double speed = (70.0 + rng.nextDouble() * 140.0) * speedMultiplier;
      final double size = 1.5 + rng.nextDouble() * 2.8;
      final double lifetime = lifetimeBase * (0.7 + rng.nextDouble() * 0.6);

      // Color variation within palette
      Color pColor = sparkBaseColor;
      if (elementType == HitDamageType.fire && rng.nextBool()) {
        pColor = BattlePalette.liquidGold;
      } else if (elementType == HitDamageType.holy && rng.nextBool()) {
        pColor = Colors.white;
      } else if (elementType == HitDamageType.voidEnergy && rng.nextBool()) {
        pColor = BattlePalette.cyberFuchsia;
      }

      list.add(
        ElementalSpark(
          position: origin,
          velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
          color: pColor,
          size: size,
          maxLifetime: lifetime,
          gravity: gravity,
          drag: drag,
          turbulenceFreq: turbulenceFreq,
          turbulenceAmp: turbulenceAmp,
        ),
      );
    }

    _sparks.add(
      ElementalSparkBatch(
        sparks: list,
        elementType: elementType,
        origin: origin,
        duration: lifetimeBase * 1.3,
      ),
    );

    // Limit active batches
    if (_sparks.length > 5) {
      _sparks.removeAt(0);
    }
  }

  /// Triggers a curved crescent energy or blood slash.
  void triggerSlash({
    required Offset startPoint,
    required Offset endPoint,
    Offset? controlPoint,
    Color? primaryColor,
    Color? glowColor,
    bool isBlood = false,
    double strokeWidth = 5.5,
    double duration = 0.38,
  }) {
    if (_isDisposed) return;

    // Compute arched control point if not specified
    Offset ctrl = controlPoint ?? Offset.zero;
    if (controlPoint == null) {
      final Offset mid = Offset((startPoint.dx + endPoint.dx) / 2.0, (startPoint.dy + endPoint.dy) / 2.0);
      final double dx = endPoint.dx - startPoint.dx;
      final double dy = endPoint.dy - startPoint.dy;
      final double normalX = -dy;
      final double normalY = dx;
      final double len = math.sqrt(normalX * normalX + normalY * normalY);
      final double offsetDist = isBlood ? 32.0 : 42.0;
      if (len > 0.0001) {
        ctrl = Offset(mid.dx + (normalX / len) * offsetDist, mid.dy + (normalY / len) * offsetDist);
      } else {
        ctrl = mid + const Offset(0.0, -30.0);
      }
    }

    // Generate secondary blood droplet offsets if in blood mode
    final List<Offset> droplets = <Offset>[];
    if (isBlood) {
      final math.Random rng = math.Random();
      for (int i = 0; i < 7; i++) {
        final double t = 0.2 + rng.nextDouble() * 0.7;
        final double bx = (1 - t) * (1 - t) * startPoint.dx + 2 * (1 - t) * t * ctrl.dx + t * t * endPoint.dx;
        final double by = (1 - t) * (1 - t) * startPoint.dy + 2 * (1 - t) * t * ctrl.dy + t * t * endPoint.dy;
        droplets.add(Offset(bx + (rng.nextDouble() - 0.5) * 16.0, by + (rng.nextDouble() - 0.5) * 16.0));
      }
    }

    _slashes.add(
      EnergySlashEffect(
        startPoint: startPoint,
        endPoint: endPoint,
        controlPoint: ctrl,
        primaryColor: primaryColor ?? (isBlood ? BattlePalette.mysticRuby : BattlePalette.warningSolar),
        glowColor: glowColor ?? (isBlood ? const Color(0xFF660000) : BattlePalette.coralFlare),
        isBlood: isBlood,
        strokeWidth: strokeWidth,
        duration: duration,
        bloodDroplets: droplets,
      ),
    );

    if (_slashes.length > 5) {
      _slashes.removeAt(0);
    }
  }

  /// Triggers an expanding shockwave radial burst with energy spikes.
  void triggerRadialBurst({
    required Offset epicenter,
    double maxRadius = 75.0,
    Color coreColor = const Color(0xFFFFFFFF),
    Color rimColor = BattlePalette.warningSolar,
    int spikeCount = 14,
    double duration = 0.42,
  }) {
    if (_isDisposed) return;

    _radialBursts.add(
      RadialBurstEffect(
        epicenter: epicenter,
        maxRadius: maxRadius,
        coreColor: coreColor,
        rimColor: rimColor,
        spikeCount: spikeCount,
        duration: duration,
      ),
    );

    if (_radialBursts.length > 4) {
      _radialBursts.removeAt(0);
    }
  }

  /// Triggers a rotating runic spell circle animation.
  void triggerSpellCircle({
    required Offset center,
    double radius = 70.0,
    Color runeColor = BattlePalette.liquidGold,
    Color glowColor = BattlePalette.cyberFuchsia,
    HitDamageType elementType = HitDamageType.voidEnergy,
    double duration = 1.8,
    double rotationSpeed = 1.5,
  }) {
    if (_isDisposed) return;

    _spellCircles.add(
      SpellCircleEffect(
        center: center,
        radius: radius,
        runeColor: runeColor,
        glowColor: glowColor,
        elementType: elementType,
        duration: duration,
        rotationSpeed: rotationSpeed,
      ),
    );

    if (_spellCircles.length > 3) {
      _spellCircles.removeAt(0);
    }
  }

  /// Triggers an anamorphic lens flare and starburst critical strike flash.
  void triggerCriticalStrikeFlash({
    required Offset epicenter,
    Color flareColor = const Color(0xFFFFFFFF),
    Color secondaryColor = BattlePalette.warningSolar,
    double flareWidth = 340.0,
    double duration = 0.32,
  }) {
    if (_isDisposed) return;

    _criticalFlashes.add(
      CriticalStrikeFlashEffect(
        epicenter: epicenter,
        flareColor: flareColor,
        secondaryColor: secondaryColor,
        flareWidth: flareWidth,
        duration: duration,
      ),
    );

    if (_criticalFlashes.length > 2) {
      _criticalFlashes.removeAt(0);
    }
  }

  /// Triggers a full spellcasting invocation sequence with spell circle, elemental sparks, and shockwave.
  void triggerSpellCast({
    required Offset origin,
    required HitDamageType elementType,
    double radius = 75.0,
    double duration = 1.6,
  }) {
    if (_isDisposed) return;

    Color runeColor;
    Color glowColor;
    switch (elementType) {
      case HitDamageType.fire:
        runeColor = BattlePalette.warningSolar;
        glowColor = BattlePalette.coralFlare;
        break;
      case HitDamageType.frost:
        runeColor = const Color(0xFFE0F7FA);
        glowColor = const Color(0xFF00E5FF);
        break;
      case HitDamageType.lightning:
        runeColor = Colors.white;
        glowColor = BattlePalette.liquidGold;
        break;
      case HitDamageType.poison:
        runeColor = BattlePalette.toxicNeon;
        glowColor = const Color(0xFF007A33);
        break;
      case HitDamageType.holy:
        runeColor = const Color(0xFFFFFFEE);
        glowColor = BattlePalette.liquidGold;
        break;
      case HitDamageType.voidEnergy:
      default:
        runeColor = BattlePalette.cyberFuchsia;
        glowColor = const Color(0xFF7A00B8);
        break;
    }

    triggerSpellCircle(
      center: origin,
      radius: radius,
      runeColor: runeColor,
      glowColor: glowColor,
      elementType: elementType,
      duration: duration,
    );

    triggerElementalSparks(
      origin: origin,
      elementType: elementType,
      count: 24,
      speedMultiplier: 0.85,
    );

    triggerRadialBurst(
      epicenter: origin,
      maxRadius: radius * 1.15,
      coreColor: Colors.white,
      rimColor: glowColor,
      spikeCount: 16,
      duration: 0.5,
    );

    cameraShake.addTrauma(0.35, hitDirection: const Offset(0.0, 1.0));
    triggerHaptic(HapticImpactLevel.light);
    notifyListeners();
  }

  /// Triggers a strike from the player against the dungeon monster.
  void triggerPlayerStrike({
    required int damage,
    bool isCritical = false,
    HitDamageType damageType = HitDamageType.physical,
    Offset impactPoint = const Offset(260.0, 110.0),
  }) {
    if (_isDisposed) return;

    final double hitAngle = isCritical ? -0.22 : 0.0; // slight upward slash angle

    // 1. Camera Shake
    final double trauma = isCritical ? 0.82 : 0.42;
    if (isCritical) {
      cameraShake.triggerPreset(
        CameraShakePreset.heavyCrit,
        hitDirection: const Offset(1.0, -0.3),
        directionalWeight: 0.90,
      );
    } else {
      cameraShake.addTrauma(
        trauma,
        hitDirection: const Offset(1.0, 0.0),
        directionalWeight: 0.75,
      );
    }

    // 2. 30-50ms Hit-Stop
    final int freezeMs = isCritical ? 50 : 35;
    hitStopManager.trigger(
      HitStopRequest(
        id: 'player_hit_${DateTime.now().microsecondsSinceEpoch}',
        freezeDuration: Duration(milliseconds: freezeMs),
        easeOutDuration: Duration(milliseconds: (freezeMs * 0.4).round()),
        targetTimeScale: 0.0,
        channels: TimeDilationChannel.combatPair,
        resumptionCurve: isCritical
            ? HitStopResumptionCurve.easeOutCubic
            : HitStopResumptionCurve.smoothStep,
        conflictPolicy: HitStopConflictPolicy.override,
        priority: isCritical ? 4 : 2,
      ),
    );

    // 3. Enemy Rim Flash
    final ui.Color flashColor = isCritical
        ? RimFlashTint.bloodRed
        : damageType.rimFlashTint;
    enemyRimFlash.triggerHit(
      tint: flashColor,
      intensityMultiplier: isCritical ? 2.4 : 1.3,
      duration: Duration(milliseconds: isCritical ? 140 : 100),
      hitStopDuration: Duration(milliseconds: freezeMs),
    );

    // 4. Weapon Ribbon Trail
    _coordinator.onAttackSwing(
      attackerId: 'player',
      hitAngle: hitAngle,
      weaponLength: isCritical ? 110.0 : 85.0,
      weaponHiltPosition: const Offset(130.0, 120.0),
      isHeavySwing: isCritical,
      customTrailColor: isCritical ? BattlePalette.cyberFuchsia : BattlePalette.liquidGold,
      customGlowColor: isCritical ? BattlePalette.warningSolar : BattlePalette.coralFlare,
    );

    // 5. Dynamic Ground Decal
    if (_atmosphereController != null) {
      if (isCritical) {
        _atmosphereController!.triggerScorchMark();
      } else {
        _atmosphereController!.triggerSlashGouge();
      }
    }

    // 6. GPU Particles
    final int sparkCount = isCritical ? 45 : 22;
    particleSystem.emitBurst(
      layerIndex: 0,
      count: sparkCount,
      origin: impactPoint,
      directionAngle: hitAngle,
      speedMultiplier: isCritical ? 1.5 : 1.0,
    );
    if (particleSystem.layers.length > 1) {
      particleSystem.emitBurst(
        layerIndex: 1,
        count: isCritical ? 4 : 1,
        origin: impactPoint,
      );
    }

    // 7. Elemental Sparks (distinct physics, convection & turbulence)
    triggerElementalSparks(
      origin: impactPoint,
      elementType: damageType,
      count: isCritical ? 36 : 22,
      speedMultiplier: isCritical ? 1.4 : 1.0,
    );

    // 8. Curved Energy Slash
    triggerSlash(
      startPoint: const Offset(140.0, 150.0),
      endPoint: impactPoint + const Offset(30.0, -35.0),
      isBlood: false,
      primaryColor: isCritical ? BattlePalette.warningSolar : const Color(0xFFFFFFFF),
      glowColor: isCritical ? BattlePalette.cyberFuchsia : BattlePalette.liquidGold,
      strokeWidth: isCritical ? 7.0 : 5.0,
      duration: isCritical ? 0.38 : 0.30,
    );

    // 9. Impact Radial Burst Shockwave
    triggerRadialBurst(
      epicenter: impactPoint,
      maxRadius: isCritical ? 90.0 : 62.0,
      coreColor: Colors.white,
      rimColor: isCritical ? BattlePalette.cyberFuchsia : BattlePalette.warningSolar,
      spikeCount: isCritical ? 18 : 12,
      duration: isCritical ? 0.45 : 0.35,
    );

    // 10. Critical Strike Flash
    if (isCritical) {
      triggerCriticalStrikeFlash(
        epicenter: impactPoint,
        flareColor: Colors.white,
        secondaryColor: BattlePalette.warningSolar,
        flareWidth: 360.0,
      );
    }

    // 11. Haptics
    triggerHaptic(isCritical ? HapticImpactLevel.critical : HapticImpactLevel.medium);

    // 12. Floating Damage Number
    _spawnDamageNumber(
      damage: damage,
      isCritical: isCritical,
      isPlayerTarget: false,
      startOffset: impactPoint + const Offset(0.0, -25.0),
    );

    // 13. Knockback & Hit Reactions
    final double impulseForce = isCritical ? 14.0 : 7.5;
    enemyKnockback.applyImpulse(
      KnockbackImpulse(
        impulse: KnockbackVector3(impulseForce * 0.85, impulseForce * 0.28, 0.0),
        verticalLaunchImpulse: impulseForce * 0.28,
        isCriticalHit: isCritical,
        customRagdollPeakWeight: isCritical ? 1.0 : 0.65,
        sourceAttackerId: 'player',
      ),
    );

    notifyListeners();
  }

  /// Triggers a counter-attack strike from the dungeon monster against the player.
  void triggerEnemyStrike({
    required int damage,
    bool isCritical = false,
    HitDamageType damageType = HitDamageType.voidEnergy,
    Offset impactPoint = const Offset(120.0, 110.0),
  }) {
    if (_isDisposed) return;

    final double hitAngle = math.pi + (isCritical ? 0.22 : 0.0); // strikes leftward

    // 1. Camera Shake (biased toward player side)
    final double trauma = isCritical ? 0.88 : 0.48;
    cameraShake.addTrauma(
      trauma,
      hitDirection: const Offset(-1.0, 0.1),
      directionalWeight: 0.85,
    );

    // 2. 30-50ms Hit-Stop
    final int freezeMs = isCritical ? 50 : 35;
    hitStopManager.trigger(
      HitStopRequest(
        id: 'enemy_hit_${DateTime.now().microsecondsSinceEpoch}',
        freezeDuration: Duration(milliseconds: freezeMs),
        easeOutDuration: Duration(milliseconds: (freezeMs * 0.35).round()),
        targetTimeScale: 0.0,
        channels: TimeDilationChannel.combatPair,
        resumptionCurve: HitStopResumptionCurve.smoothStep,
      ),
    );

    // 3. Player Rim Flash
    playerRimFlash.triggerHit(
      tint: isCritical ? RimFlashTint.bloodRed : const Color(0xFFFF5555),
      intensityMultiplier: isCritical ? 2.5 : 1.4,
      duration: Duration(milliseconds: isCritical ? 140 : 100),
      hitStopDuration: Duration(milliseconds: freezeMs),
    );

    // 4. Weapon Ribbon Trail (Enemy swing arc)
    _coordinator.onAttackSwing(
      attackerId: 'enemy',
      hitAngle: hitAngle,
      weaponLength: isCritical ? 100.0 : 80.0,
      weaponHiltPosition: const Offset(250.0, 110.0),
      isHeavySwing: isCritical,
      customTrailColor: BattlePalette.mysticRuby,
      customGlowColor: BattlePalette.cyberFuchsia,
    );

    // 5. Dynamic Decal (Blood splatter)
    if (_atmosphereController != null) {
      _atmosphereController!.triggerBloodSplatter();
    }

    // 6. GPU Particles
    particleSystem.emitBurst(
      layerIndex: 0,
      count: isCritical ? 40 : 20,
      origin: impactPoint,
      directionAngle: hitAngle,
    );

    // 7. Elemental Sparks (blood / void / shadow)
    triggerElementalSparks(
      origin: impactPoint,
      elementType: damageType,
      count: isCritical ? 34 : 20,
      speedMultiplier: isCritical ? 1.3 : 1.0,
    );

    // 8. Curved Blood Slash with trailing blood droplets
    triggerSlash(
      startPoint: const Offset(250.0, 75.0),
      endPoint: impactPoint + const Offset(-30.0, 35.0),
      isBlood: true,
      primaryColor: isCritical ? BattlePalette.mysticRuby : const Color(0xFFFF4444),
      glowColor: const Color(0xFF550000),
      strokeWidth: isCritical ? 7.5 : 5.5,
      duration: isCritical ? 0.40 : 0.32,
    );

    // 9. Impact Radial Burst
    triggerRadialBurst(
      epicenter: impactPoint,
      maxRadius: isCritical ? 85.0 : 55.0,
      coreColor: Colors.white,
      rimColor: BattlePalette.mysticRuby,
      spikeCount: isCritical ? 16 : 10,
      duration: isCritical ? 0.42 : 0.32,
    );

    if (isCritical) {
      triggerCriticalStrikeFlash(
        epicenter: impactPoint,
        flareColor: const Color(0xFFFFB0B0),
        secondaryColor: BattlePalette.mysticRuby,
        flareWidth: 320.0,
      );
    }

    // 10. Haptics
    triggerHaptic(isCritical ? HapticImpactLevel.critical : HapticImpactLevel.heavy);

    // 11. Floating Damage Number (over player)
    _spawnDamageNumber(
      damage: damage,
      isCritical: isCritical,
      isPlayerTarget: true,
      startOffset: impactPoint + const Offset(0.0, -25.0),
    );

    // 12. Player Knockback Reaction
    final double impulseForce = isCritical ? 13.0 : 7.0;
    playerKnockback.applyImpulse(
      KnockbackImpulse(
        impulse: KnockbackVector3(-impulseForce * 0.85, impulseForce * 0.25, 0.0),
        verticalLaunchImpulse: impulseForce * 0.25,
        isCriticalHit: isCritical,
        customRagdollPeakWeight: isCritical ? 0.95 : 0.60,
        sourceAttackerId: 'enemy',
      ),
    );

    notifyListeners();
  }

  /// Triggers a clash / parry collision between combatants.
  void triggerClash({
    Offset centerPoint = const Offset(195.0, 110.0),
  }) {
    if (_isDisposed) return;

    // 1. Camera Shake (micro vibration)
    cameraShake.triggerPreset(CameraShakePreset.microVibration);

    // 2. Hit-Stop (crisp 30ms parry freeze)
    hitStopManager.triggerMedium();

    // 3. Rim Flash on both combatants
    enemyRimFlash.triggerHit(
      tint: RimFlashTint.lightningGold,
      intensityMultiplier: 1.2,
      duration: const Duration(milliseconds: 80),
    );
    playerRimFlash.triggerHit(
      tint: RimFlashTint.lightningGold,
      intensityMultiplier: 1.2,
      duration: const Duration(milliseconds: 80),
    );

    // 4. Ribbon trails crossing
    _coordinator.onAttackSwing(
      attackerId: 'player_clash',
      hitAngle: -0.15,
      weaponLength: 75.0,
      weaponHiltPosition: const Offset(130.0, 110.0),
      customTrailColor: BattlePalette.warningSolar,
    );
    _coordinator.onAttackSwing(
      attackerId: 'enemy_clash',
      hitAngle: math.pi + 0.15,
      weaponLength: 75.0,
      weaponHiltPosition: const Offset(260.0, 110.0),
      customTrailColor: BattlePalette.coralFlare,
    );

    // 5. Dual Crossing Energy Slashes colliding at center
    triggerSlash(
      startPoint: const Offset(130.0, 140.0),
      endPoint: centerPoint + const Offset(15.0, -15.0),
      primaryColor: BattlePalette.warningSolar,
      glowColor: BattlePalette.coralFlare,
      strokeWidth: 5.5,
      duration: 0.30,
    );
    triggerSlash(
      startPoint: const Offset(260.0, 80.0),
      endPoint: centerPoint + const Offset(-15.0, 15.0),
      primaryColor: BattlePalette.mysticRuby,
      glowColor: BattlePalette.cyberFuchsia,
      strokeWidth: 5.5,
      duration: 0.30,
    );

    // 6. Decal
    _atmosphereController?.triggerSlashGouge();

    // 7. High-intensity spark explosion at center
    particleSystem.emitBurst(
      layerIndex: 0,
      count: 35,
      origin: centerPoint,
      speedMultiplier: 1.3,
    );

    // 8. Elemental Lightning Sparks
    triggerElementalSparks(
      origin: centerPoint,
      elementType: HitDamageType.lightning,
      count: 28,
      speedMultiplier: 1.3,
    );

    // 9. Radial Burst Shockwave
    triggerRadialBurst(
      epicenter: centerPoint,
      maxRadius: 72.0,
      coreColor: Colors.white,
      rimColor: BattlePalette.warningSolar,
      spikeCount: 16,
      duration: 0.36,
    );

    // 10. Parry Optical Flash
    triggerCriticalStrikeFlash(
      epicenter: centerPoint,
      flareColor: Colors.white,
      secondaryColor: BattlePalette.warningSolar,
      flareWidth: 260.0,
      duration: 0.24,
    );

    // 11. Haptics
    triggerHaptic(HapticImpactLevel.medium);

    notifyListeners();
  }

  /// Triggers a lethal finishing blow ending the encounter.
  void triggerFinishingBlow({
    required bool isPlayerWinner,
    required int fatalDamage,
  }) {
    if (_isDisposed) return;

    final Offset deathPoint = isPlayerWinner ? const Offset(260.0, 110.0) : const Offset(120.0, 110.0);

    // Grand Evocation Spell Circle
    triggerSpellCircle(
      center: deathPoint,
      radius: 80.0,
      runeColor: isPlayerWinner ? BattlePalette.liquidGold : BattlePalette.mysticRuby,
      glowColor: isPlayerWinner ? BattlePalette.cyberFuchsia : const Color(0xFF4A0000),
      elementType: isPlayerWinner ? HitDamageType.holy : HitDamageType.voidEnergy,
      duration: 2.2,
    );

    // Lethal Radial Burst Shockwave
    triggerRadialBurst(
      epicenter: deathPoint,
      maxRadius: 120.0,
      coreColor: Colors.white,
      rimColor: isPlayerWinner ? BattlePalette.warningSolar : BattlePalette.mysticRuby,
      spikeCount: 22,
      duration: 0.65,
    );

    // Blinding Critical Flash & Anamorphic Flare
    triggerCriticalStrikeFlash(
      epicenter: deathPoint,
      flareColor: Colors.white,
      secondaryColor: isPlayerWinner ? BattlePalette.warningSolar : BattlePalette.mysticRuby,
      flareWidth: 420.0,
      duration: 0.45,
    );

    if (isPlayerWinner) {
      triggerPlayerStrike(
        damage: fatalDamage,
        isCritical: true,
        damageType: HitDamageType.fire,
      );
      cameraShake.triggerPreset(CameraShakePreset.explosiveShock);
      _atmosphereController?.triggerScorchMark();
      _atmosphereController?.triggerBloodSplatter();
      triggerHaptic(HapticImpactLevel.critical);
    } else {
      triggerEnemyStrike(
        damage: fatalDamage,
        isCritical: true,
        damageType: HitDamageType.voidEnergy,
      );
      cameraShake.triggerPreset(CameraShakePreset.explosiveShock);
      _atmosphereController?.triggerBloodSplatter();
      triggerHaptic(HapticImpactLevel.critical);
    }
  }

  /// Parses combat flavor line and triggers appropriate combat feel module.
  void processCombatLine(
    String line, {
    required int playerAttack,
    required int playerDefense,
  }) {
    final String lower = line.toLowerCase();
    final math.Random rng = math.Random();

    // Detect elemental affinity from battle log text
    HitDamageType detectedType = HitDamageType.physical;
    if (lower.contains('ateş') || lower.contains('alev') || lower.contains('yakıcı')) {
      detectedType = HitDamageType.fire;
    } else if (lower.contains('buz') || lower.contains('don') || lower.contains('soğuk')) {
      detectedType = HitDamageType.frost;
    } else if (lower.contains('yıldırım') || lower.contains('şimşek') || lower.contains('elektrik')) {
      detectedType = HitDamageType.lightning;
    } else if (lower.contains('zehir') || lower.contains('asit') || lower.contains('toksik')) {
      detectedType = HitDamageType.poison;
    } else if (lower.contains('kutsal') || lower.contains('ışık') || lower.contains('nur')) {
      detectedType = HitDamageType.holy;
    } else if (lower.contains('karanlık') || lower.contains('gölge') || lower.contains('hiçlik')) {
      detectedType = HitDamageType.voidEnergy;
    }

    // Estimate realistic damage numbers based on stats
    final int basePlayerDmg = math.max(25, (playerAttack * 0.85 + rng.nextInt(35)).round());
    final int baseEnemyDmg = math.max(18, (playerDefense * 0.55 + rng.nextInt(25)).round());

    // Check for magical spell invocation
    if (lower.contains('büyü') || lower.contains('ritüel') || lower.contains('efsun') || lower.contains('mühür')) {
      triggerSpellCast(
        origin: const Offset(195.0, 110.0),
        elementType: detectedType,
      );
    }

    if (lower.contains('kritik') || lower.contains('ezici')) {
      triggerPlayerStrike(
        damage: (basePlayerDmg * 2.2).round(),
        isCritical: true,
        damageType: detectedType,
      );
    } else if (lower.contains('ilk hamle') ||
        lower.contains('karşı saldırı') ||
        lower.contains('isabet etti') ||
        lower.contains('alt ettin')) {
      triggerPlayerStrike(
        damage: basePlayerDmg,
        isCritical: false,
        damageType: detectedType,
      );
    } else if (lower.contains('sert bir darbe') ||
        lower.contains('yaralandı') ||
        lower.contains('düştün')) {
      triggerEnemyStrike(
        damage: lower.contains('düştün') ? (baseEnemyDmg * 2.0).round() : baseEnemyDmg,
        isCritical: lower.contains('düştün'),
        damageType: detectedType,
      );
    } else if (lower.contains('eğildin') ||
        lower.contains('savurdu') ||
        lower.contains('göz göze') ||
        lower.contains('kılıç havada')) {
      triggerClash();
    } else if (lower.contains('sarsıldı') || lower.contains('çatladı') || lower.contains('yıkım')) {
      cameraShake.addTrauma(0.55, hitDirection: const Offset(0.0, 1.0));
      _atmosphereController?.triggerCrackedFlagstones();
      triggerHaptic(HapticImpactLevel.medium);
    } else {
      // Ambient combat pulse
      triggerClash();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _spawnDamageNumber({
    required int damage,
    required bool isCritical,
    required bool isPlayerTarget,
    required Offset startOffset,
  }) {
    // Offset slightly if previous number exists
    final double jitterX = (math.Random().nextDouble() - 0.5) * 16.0;
    final double jitterY = (math.Random().nextDouble() - 0.5) * 8.0;

    _damageNumbers.add(
      DungeonDamageNumber(
        damage: damage,
        isCritical: isCritical,
        isPlayerTarget: isPlayerTarget,
        startOffset: startOffset + Offset(jitterX, jitterY),
      ),
    );

    // Cap active floating numbers to avoid clutter
    if (_damageNumbers.length > 8) {
      _damageNumbers.removeAt(0);
    }
  }

  /// Platform-safe haptic trigger.
  void triggerHaptic(HapticImpactLevel level) {
    try {
      switch (level) {
        case HapticImpactLevel.light:
          HapticFeedback.lightImpact();
          break;
        case HapticImpactLevel.medium:
          HapticFeedback.mediumImpact();
          break;
        case HapticImpactLevel.heavy:
          HapticFeedback.heavyImpact();
          break;
        case HapticImpactLevel.critical:
          HapticFeedback.heavyImpact();
          HapticFeedback.vibrate();
          break;
      }
    } catch (_) {
      // Gracefully silent in headless or unsupported platforms
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _sparks.clear();
    _slashes.clear();
    _radialBursts.clear();
    _spellCircles.clear();
    _criticalFlashes.clear();
    _damageNumbers.clear();
    _coordinator.dispose();
    cameraShake.dispose();
    hitStopManager.dispose();
    enemyRimFlash.dispose();
    playerRimFlash.dispose();
    super.dispose();
  }
}

// =============================================================================
// VFX System 1: Elemental Sparks CustomPainter & Standalone Widget
// =============================================================================

/// CustomPainter rendering ballistic elemental spark bursts with distinct elemental behaviors.
class ElementalSparksPainter extends CustomPainter {
  const ElementalSparksPainter({
    required this.batches,
  });

  final List<ElementalSparkBatch> batches;

  @override
  void paint(Canvas canvas, Size size) {
    if (batches.isEmpty) return;

    final Paint corePaint = Paint()..style = PaintingStyle.fill;
    final Paint glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    for (final ElementalSparkBatch batch in batches) {
      for (final ElementalSpark spark in batch.sparks) {
        final double alpha = (1.0 - spark.progress).clamp(0.0, 1.0);
        final double currentSize = spark.size * (1.0 - spark.progress * 0.4);

        // Halo glow
        glowPaint.color = spark.color.withValues(alpha: alpha * 0.6);
        canvas.drawCircle(spark.position, currentSize * 2.2, glowPaint);

        // Brilliant core
        corePaint.color = Colors.white.withValues(alpha: alpha * 0.9);
        canvas.drawCircle(spark.position, currentSize * 0.7, corePaint);

        // Elemental-specific visual flourish
        if (batch.elementType == HitDamageType.lightning) {
          // Sharp mini zig-zag spark
          final Paint boltPaint = Paint()
            ..color = spark.color.withValues(alpha: alpha * 0.8)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke;
          final double jx = math.sin(spark.elapsed * 50) * 4.0;
          final double jy = math.cos(spark.elapsed * 50) * 4.0;
          canvas.drawLine(spark.position, spark.position + Offset(jx, jy), boltPaint);
        } else if (batch.elementType == HitDamageType.holy || batch.elementType == HitDamageType.frost) {
          // 4-pointed glint
          final Paint glintPaint = Paint()
            ..color = spark.color.withValues(alpha: alpha * 0.75)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;
          final double glintLen = currentSize * 2.5;
          canvas.drawLine(
            spark.position - Offset(glintLen, 0),
            spark.position + Offset(glintLen, 0),
            glintPaint,
          );
          canvas.drawLine(
            spark.position - Offset(0, glintLen),
            spark.position + Offset(0, glintLen),
            glintPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant ElementalSparksPainter oldDelegate) {
    return batches.isNotEmpty || oldDelegate.batches.isNotEmpty;
  }
}

/// Standalone widget for displaying elemental sparks.
class DungeonElementalSparksWidget extends StatelessWidget {
  const DungeonElementalSparksWidget({
    super.key,
    required this.batches,
  });

  final List<ElementalSparkBatch> batches;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: ElementalSparksPainter(batches: batches),
      ),
    );
  }
}

// =============================================================================
// VFX System 2: Blood & Energy Slashes CustomPainter & Standalone Widget
// =============================================================================

/// CustomPainter rendering curved Bezier crescent blades with outer energy glow or crimson blood mist.
class EnergySlashPainter extends CustomPainter {
  const EnergySlashPainter({
    required this.slashes,
  });

  final List<EnergySlashEffect> slashes;

  @override
  void paint(Canvas canvas, Size size) {
    if (slashes.isEmpty) return;

    for (final EnergySlashEffect slash in slashes) {
      _paintSlash(canvas, slash);
    }
  }

  void _paintSlash(Canvas canvas, EnergySlashEffect slash) {
    final double headT = slash.headT;
    final double tailT = slash.tailT;
    if (headT <= tailT) return;

    final double opacity = slash.opacity;

    // Approximate quadratic Bezier points between tailT and headT
    final List<Offset> points = <Offset>[];
    const int segments = 16;
    for (int i = 0; i <= segments; i++) {
      final double localT = tailT + (headT - tailT) * (i / segments);
      final double bx = (1 - localT) * (1 - localT) * slash.startPoint.dx +
          2 * (1 - localT) * localT * slash.controlPoint.dx +
          localT * localT * slash.endPoint.dx;
      final double by = (1 - localT) * (1 - localT) * slash.startPoint.dy +
          2 * (1 - localT) * localT * slash.controlPoint.dy +
          localT * localT * slash.endPoint.dy;
      points.add(Offset(bx, by));
    }

    if (points.length < 2) return;

    final Path slashPath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      slashPath.lineTo(points[i].dx, points[i].dy);
    }

    // Outer glow pass
    final Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = slash.strokeWidth * 3.2
      ..color = slash.glowColor.withValues(alpha: opacity * 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawPath(slashPath, glowPaint);

    // Primary energy/blood stroke
    final Paint primaryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = slash.strokeWidth
      ..color = slash.primaryColor.withValues(alpha: opacity * 0.95);
    canvas.drawPath(slashPath, primaryPaint);

    // Razor-sharp luminous white core for energy slashes
    if (!slash.isBlood) {
      final Paint corePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = slash.strokeWidth * 0.38
        ..color = Colors.white.withValues(alpha: opacity);
      canvas.drawPath(slashPath, corePaint);
    }

    // Secondary blood droplets
    if (slash.isBlood && slash.bloodDroplets.isNotEmpty) {
      final Paint bloodDropPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = slash.primaryColor.withValues(alpha: opacity * 0.85);
      for (final Offset drop in slash.bloodDroplets) {
        final double dropProgress = slash.progress;
        final Offset currentDropPos = drop + Offset(0.0, dropProgress * 18.0);
        final double dropRadius = (2.2 * (1.0 - dropProgress * 0.5)).clamp(0.5, 3.0);
        canvas.drawCircle(currentDropPos, dropRadius, bloodDropPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant EnergySlashPainter oldDelegate) {
    return slashes.isNotEmpty || oldDelegate.slashes.isNotEmpty;
  }
}

/// Standalone widget for displaying energy or blood slashes.
class DungeonEnergySlashWidget extends StatelessWidget {
  const DungeonEnergySlashWidget({
    super.key,
    required this.slashes,
  });

  final List<EnergySlashEffect> slashes;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: EnergySlashPainter(slashes: slashes),
      ),
    );
  }
}

// =============================================================================
// VFX System 3: Impact Radial Bursts CustomPainter & Standalone Widget
// =============================================================================

/// CustomPainter rendering expanding shockwave pressure ripples with radiating energy spikes.
class RadialBurstPainter extends CustomPainter {
  const RadialBurstPainter({
    required this.bursts,
  });

  final List<RadialBurstEffect> bursts;

  @override
  void paint(Canvas canvas, Size size) {
    if (bursts.isEmpty) return;

    for (final RadialBurstEffect burst in bursts) {
      _paintBurst(canvas, burst);
    }
  }

  void _paintBurst(Canvas canvas, RadialBurstEffect burst) {
    final double r = burst.radius;
    final double opacity = burst.opacity;
    if (opacity <= 0.001 || r <= 0.5) return;

    final Offset center = burst.epicenter;

    // Outer shockwave glow ring
    final Paint glowRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (5.5 * (1.0 - burst.progress * 0.6)).clamp(1.0, 6.0)
      ..color = burst.rimColor.withValues(alpha: opacity * 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawCircle(center, r, glowRingPaint);

    // Crisp high-energy shockwave ring
    final Paint crispRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.4 * (1.0 - burst.progress * 0.5)).clamp(0.8, 3.0)
      ..color = burst.coreColor.withValues(alpha: opacity * 0.95);
    canvas.drawCircle(center, r, crispRingPaint);

    // Secondary inner pressure counter-ring
    final double innerR = r * 0.68;
    if (innerR > 2.0) {
      final Paint innerRingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = burst.rimColor.withValues(alpha: opacity * 0.45);
      canvas.drawCircle(center, innerR, innerRingPaint);
    }

    // Radiating energy spikes
    final Paint spikePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (2.2 * (1.0 - burst.progress * 0.7)).clamp(0.6, 2.5)
      ..color = burst.rimColor.withValues(alpha: opacity * 0.85);

    for (int i = 0; i < burst.spikeAngles.length; i++) {
      final double angle = burst.spikeAngles[i];
      final double lenFactor = burst.spikeLengths[i];
      final double startDist = r * 0.45;
      final double endDist = (r * 1.08 * lenFactor).clamp(startDist + 1.0, burst.maxRadius * 1.2);

      final Offset p1 = Offset(center.dx + math.cos(angle) * startDist, center.dy + math.sin(angle) * startDist);
      final Offset p2 = Offset(center.dx + math.cos(angle) * endDist, center.dy + math.sin(angle) * endDist);

      canvas.drawLine(p1, p2, spikePaint);
    }
  }

  @override
  bool shouldRepaint(covariant RadialBurstPainter oldDelegate) {
    return bursts.isNotEmpty || oldDelegate.bursts.isNotEmpty;
  }
}

/// Standalone widget for displaying impact radial bursts.
class DungeonRadialBurstWidget extends StatelessWidget {
  const DungeonRadialBurstWidget({
    super.key,
    required this.bursts,
  });

  final List<RadialBurstEffect> bursts;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: RadialBurstPainter(bursts: bursts),
      ),
    );
  }
}

// =============================================================================
// VFX System 4: Spell Circle Animations CustomPainter & Standalone Widget
// =============================================================================

/// CustomPainter rendering multi-tiered concentric magical evocation matrices with counter-rotating geometry.
class SpellCirclePainter extends CustomPainter {
  const SpellCirclePainter({
    required this.circles,
  });

  final List<SpellCircleEffect> circles;

  @override
  void paint(Canvas canvas, Size size) {
    if (circles.isEmpty) return;

    for (final SpellCircleEffect circle in circles) {
      _paintSpellCircle(canvas, circle);
    }
  }

  void _paintSpellCircle(Canvas canvas, SpellCircleEffect circle) {
    final double opacity = circle.opacity;
    final double scale = circle.scale;
    if (opacity <= 0.001 || scale <= 0.01) return;

    final Offset center = circle.center;
    final double R = circle.radius * scale;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // 1. Central glowing aura
    final Paint centralAuraPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        R,
        <Color>[
          circle.glowColor.withValues(alpha: opacity * 0.45),
          circle.runeColor.withValues(alpha: opacity * 0.15),
          circle.glowColor.withValues(alpha: 0.0),
        ],
        <double>[0.0, 0.55, 1.0],
      );
    canvas.drawCircle(Offset.zero, R, centralAuraPaint);

    // 2. Outer Runic Ring (clockwise rotation)
    canvas.save();
    canvas.rotate(circle.rotation);

    final Paint outerBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = circle.runeColor.withValues(alpha: opacity * 0.9);
    canvas.drawCircle(Offset.zero, R, outerBorderPaint);

    final Paint outerGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = circle.glowColor.withValues(alpha: opacity * 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawCircle(Offset.zero, R, outerGlowPaint);

    // Outer perimeter procedural runes / cuneiform notch ticks
    const int runeCount = 18;
    final Paint runeTickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = circle.runeColor.withValues(alpha: opacity * 0.85);

    for (int i = 0; i < runeCount; i++) {
      final double theta = i * (2 * math.pi / runeCount);
      final double cosT = math.cos(theta);
      final double sinT = math.sin(theta);
      // Outer tick
      canvas.drawLine(
        Offset(cosT * (R - 5.0), sinT * (R - 5.0)),
        Offset(cosT * (R + 3.0), sinT * (R + 3.0)),
        runeTickPaint,
      );
      // Small geometric rune glyph (triangle or square notch)
      if (i % 3 == 0) {
        final double midR = R - 9.0;
        canvas.drawCircle(Offset(cosT * midR, sinT * midR), 2.0, runeTickPaint);
      }
    }
    canvas.restore();

    // 3. Middle Celestial Ring (counter-clockwise rotation)
    canvas.save();
    canvas.rotate(-circle.rotation * 1.35);

    final double midR = R * 0.74;
    final Paint midBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = circle.runeColor.withValues(alpha: opacity * 0.8);
    canvas.drawCircle(Offset.zero, midR, midBorderPaint);

    // Inscribed Hexagram (two overlapping equilateral triangles)
    final Path hexagramPath = Path();
    for (int k = 0; k < 2; k++) {
      final double baseAngle = k * (math.pi / 3.0);
      for (int v = 0; v < 3; v++) {
        final double angle = baseAngle + v * (2 * math.pi / 3.0);
        final double vx = math.cos(angle) * midR;
        final double vy = math.sin(angle) * midR;
        if (v == 0) {
          hexagramPath.moveTo(vx, vy);
        } else {
          hexagramPath.lineTo(vx, vy);
        }
      }
      hexagramPath.close();
    }
    final Paint hexPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = circle.glowColor.withValues(alpha: opacity * 0.65);
    canvas.drawPath(hexagramPath, hexPaint);

    canvas.restore();

    // 4. Inner Sanctum Ring and Orbiting Power Nodes
    final double innerR = R * 0.42;
    final Paint innerBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = circle.runeColor.withValues(alpha: opacity * 0.95);
    canvas.drawCircle(Offset.zero, innerR, innerBorderPaint);

    // 4 orbital planetary sigil nodes revolving around the center
    const int nodeCount = 4;
    final Paint nodePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: opacity * 0.95);
    final Paint nodeGlow = Paint()
      ..style = PaintingStyle.fill
      ..color = circle.glowColor.withValues(alpha: opacity * 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    for (int n = 0; n < nodeCount; n++) {
      final double nodeAngle = circle.rotation * 2.2 + n * (math.pi / 2.0);
      final Offset nodePos = Offset(math.cos(nodeAngle) * innerR, math.sin(nodeAngle) * innerR);
      canvas.drawCircle(nodePos, 4.0, nodeGlow);
      canvas.drawCircle(nodePos, 2.2, nodePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SpellCirclePainter oldDelegate) {
    return circles.isNotEmpty || oldDelegate.circles.isNotEmpty;
  }
}

/// Standalone widget for displaying magical spell circles.
class DungeonSpellCircleWidget extends StatelessWidget {
  const DungeonSpellCircleWidget({
    super.key,
    required this.circles,
  });

  final List<SpellCircleEffect> circles;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: SpellCirclePainter(circles: circles),
      ),
    );
  }
}

// =============================================================================
// VFX System 5: Critical Strike Flashes CustomPainter & Standalone Widget
// =============================================================================

/// CustomPainter rendering anamorphic horizontal optical lens streaks and 8-point starburst critical flashes.
class CriticalStrikeFlashPainter extends CustomPainter {
  const CriticalStrikeFlashPainter({
    required this.flashes,
  });

  final List<CriticalStrikeFlashEffect> flashes;

  @override
  void paint(Canvas canvas, Size size) {
    if (flashes.isEmpty) return;

    for (final CriticalStrikeFlashEffect flash in flashes) {
      _paintCriticalFlash(canvas, size, flash);
    }
  }

  void _paintCriticalFlash(Canvas canvas, Size size, CriticalStrikeFlashEffect flash) {
    final double opacity = flash.opacity;
    if (opacity <= 0.001) return;

    final Offset center = flash.epicenter;
    final double width = flash.currentFlareWidth;

    // 1. Full-screen / Arena high-energy illumination vignette flash
    final Paint screenFlashPaint = Paint()
      ..color = flash.secondaryColor.withValues(alpha: opacity * 0.32);
    canvas.drawRect(Offset.zero & size, screenFlashPaint);

    // 2. Anamorphic Horizontal Lens Flare Streak (High AAA bloom)
    final Rect flareRect = Rect.fromCenter(
      center: center,
      width: width,
      height: 14.0 * (1.0 - flash.progress * 0.5),
    );

    final Paint flareGlowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(flareRect.left, flareRect.top),
        Offset(flareRect.right, flareRect.top),
        <Color>[
          flash.secondaryColor.withValues(alpha: 0.0),
          flash.secondaryColor.withValues(alpha: opacity * 0.8),
          Colors.white.withValues(alpha: opacity),
          flash.secondaryColor.withValues(alpha: opacity * 0.8),
          flash.secondaryColor.withValues(alpha: 0.0),
        ],
        <double>[0.0, 0.35, 0.5, 0.65, 1.0],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    canvas.drawOval(flareRect, flareGlowPaint);

    // Super-bright razor core streak
    final Rect razorRect = Rect.fromCenter(
      center: center,
      width: width * 0.85,
      height: 3.2,
    );
    final Paint razorPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.95);
    canvas.drawOval(razorRect, razorPaint);

    // 3. 8-Point Optical Starburst Rays
    final double starburstSize = 48.0 * (1.0 - flash.progress * 0.4);
    final Paint rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0 * (1.0 - flash.progress * 0.7)
      ..color = Colors.white.withValues(alpha: opacity * 0.9);

    // Cardinal rays (vertical & horizontal)
    canvas.drawLine(center - Offset(0, starburstSize), center + Offset(0, starburstSize), rayPaint);
    canvas.drawLine(center - Offset(starburstSize * 0.6, 0), center + Offset(starburstSize * 0.6, 0), rayPaint);

    // Diagonal rays (shorter)
    final double diag = starburstSize * 0.45;
    canvas.drawLine(center - Offset(diag, diag), center + Offset(diag, diag), rayPaint);
    canvas.drawLine(center - Offset(diag, -diag), center + Offset(diag, -diag), rayPaint);

    // 4. Central blazing core sphere
    final Paint corePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawCircle(center, 9.0 * (1.0 - flash.progress * 0.5), corePaint);
  }

  @override
  bool shouldRepaint(covariant CriticalStrikeFlashPainter oldDelegate) {
    return flashes.isNotEmpty || oldDelegate.flashes.isNotEmpty;
  }
}

/// Standalone widget for displaying critical strike flashes and anamorphic flares.
class DungeonCriticalFlashWidget extends StatelessWidget {
  const DungeonCriticalFlashWidget({
    super.key,
    required this.flashes,
  });

  final List<CriticalStrikeFlashEffect> flashes;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: CriticalStrikeFlashPainter(flashes: flashes),
      ),
    );
  }
}

// =============================================================================
// Floating Damage Numbers Overlay Painter / Widget
// =============================================================================

class DungeonDamageOverlayPainter extends CustomPainter {
  DungeonDamageOverlayPainter({
    required this.damageNumbers,
  });

  final List<DungeonDamageNumber> damageNumbers;

  @override
  void paint(Canvas canvas, Size size) {
    for (final DungeonDamageNumber dmg in damageNumbers) {
      _paintDamageNumber(canvas, dmg);
    }
  }

  void _paintDamageNumber(Canvas canvas, DungeonDamageNumber dmg) {
    final double scale = dmg.scale;
    final double opacity = dmg.opacity;
    final Offset pos = dmg.currentOffset;

    final String text = dmg.isCritical ? 'KRİTİK! -${dmg.damage}' : '-${dmg.damage}';

    final Color primaryColor = dmg.isPlayerTarget
        ? BattlePalette.mysticRuby
        : (dmg.isCritical ? BattlePalette.warningSolar : const Color(0xFFFFFFFF));

    final Color outlineColor = dmg.isPlayerTarget
        ? const Color(0xFF330000)
        : (dmg.isCritical ? const Color(0xFF882200) : const Color(0xFF111827));

    final double fontSize = dmg.isCritical ? 22.0 : 16.0;

    // 1. Text outline / shadow
    final TextPainter strokePainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: dmg.isCritical ? 1.2 : 0.8,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = dmg.isCritical ? 4.5 : 3.0
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = outlineColor.withValues(alpha: opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 2. Primary text fill
    final TextPainter fillPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: primaryColor.withValues(alpha: opacity),
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: dmg.isCritical ? 1.2 : 0.8,
          shadows: dmg.isCritical
              ? <Shadow>[
                  Shadow(
                    color: BattlePalette.cyberFuchsia.withValues(alpha: opacity * 0.8),
                    blurRadius: 12.0,
                  ),
                ]
              : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(scale);

    final Offset centerOffset = Offset(-fillPainter.width / 2.0, -fillPainter.height / 2.0);
    strokePainter.paint(canvas, centerOffset);
    fillPainter.paint(canvas, centerOffset);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DungeonDamageOverlayPainter oldDelegate) => true;
}

// =============================================================================
// Complete Dungeon Combat Arena VFX Host Widget
// =============================================================================

/// Hosts and renders all Combat Juice and VFX systems around the duel combatants:
/// - Directional Camera Shake Host (screen trauma recoil)
/// - Knockback & Hit Reaction Transforms (flinch & recovery)
/// - Rim-Light Hit Flash silhouettes on character portraits
/// - Concentric Runic Spell Circles & Evocation Matrices (behind combatants)
/// - Weapon Ribbon Trail arcs (Catmull-Rom interpolated)
/// - GPU Particle Sparks & Flash bursts
/// - Ballistic Elemental Sparks (fire, frost, lightning, poison, holy, void)
/// - Curved Bezier Energy & Blood Slashes with outer glow
/// - Expanding Impact Radial Burst shockwaves & pressure ripples
/// - Anamorphic Lens Flare Critical Strike Flashes with 8-point starburst
/// - Floating Damage Numbers with bounce overshoot & critical scaling
class DungeonCombatVfxArenaHost extends StatelessWidget {
  const DungeonCombatVfxArenaHost({
    super.key,
    required this.controller,
    required this.playerPortrait,
    required this.enemyPortrait,
    required this.clashIcon,
    this.arenaWidth = 360.0,
    this.arenaHeight = 140.0,
  });

  final DungeonCombatVfxController controller;
  final Widget playerPortrait;
  final Widget enemyPortrait;
  final Widget clashIcon;
  final double arenaWidth;
  final double arenaHeight;

  @override
  Widget build(BuildContext context) {
    return DirectionalCameraShakeHost(
      controller: controller.cameraShake,
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          // Compute Knockback 2D Offsets and Spine Tilts
          final enemyState = controller.enemyKnockback.getStateSnapshot();
          final playerState = controller.playerKnockback.getStateSnapshot();

          // Enemy recoil (pushes rightwards / backwards)
          final double enemyRecoilX = enemyState.position.x * 2.5;
          final double enemyRecoilY = -enemyState.position.y * 2.0;
          final double enemyRoll = enemyState.spineTilt.roll * 0.12;

          // Player recoil (pushes leftwards / backwards)
          final double playerRecoilX = playerState.position.x * 2.5;
          final double playerRecoilY = -playerState.position.y * 2.0;
          final double playerRoll = playerState.spineTilt.roll * 0.12;

          return SizedBox(
            height: arenaHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: <Widget>[
                // 1. SPELL CIRCLE MATRIX LAYER (rendered behind combatants)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: SpellCirclePainter(
                        circles: controller.activeSpellCircles,
                      ),
                    ),
                  ),
                ),

                // 2. Dual Portrait Combatants Row with Knockback & Rim Flash
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    // PLAYER FIGHTER (Wrapped in Knockback + Rim Hit Flash)
                    Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.identity()
                        ..translate(playerRecoilX, playerRecoilY)
                        ..rotateZ(playerRoll),
                      child: RimHitFlashWidget(
                        controller: controller.playerRimFlash,
                        child: playerPortrait,
                      ),
                    ),

                    // CLASH ICON WITH HIT-STOP DILATION
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: clashIcon,
                    ),

                    // ENEMY FIGHTER (Wrapped in Knockback + Rim Hit Flash)
                    Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.identity()
                        ..translate(enemyRecoilX, enemyRecoilY)
                        ..rotateZ(enemyRoll),
                      child: RimHitFlashWidget(
                        controller: controller.enemyRimFlash,
                        child: enemyPortrait,
                      ),
                    ),
                  ],
                ),

                // 3. WEAPON RIBBON TRAILS OVERLAY
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: ribbon.RibbonTrailPainter(
                        trail: controller.ribbonTrail,
                      ),
                    ),
                  ),
                ),

                // 4. GPU PARTICLE SPARKS & BURSTS OVERLAY
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: GpuParticlePainter(
                        system: controller.particleSystem,
                      ),
                    ),
                  ),
                ),

                // 5. BALLISTIC ELEMENTAL SPARKS OVERLAY
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: ElementalSparksPainter(
                        batches: controller.activeSparks,
                      ),
                    ),
                  ),
                ),

                // 6. CURVED ENERGY & BLOOD SLASHES OVERLAY
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: EnergySlashPainter(
                        slashes: controller.activeSlashes,
                      ),
                    ),
                  ),
                ),

                // 7. EXPANDING IMPACT RADIAL BURSTS OVERLAY
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: RadialBurstPainter(
                        bursts: controller.activeRadialBursts,
                      ),
                    ),
                  ),
                ),

                // 8. ANAMORPHIC CRITICAL STRIKE FLASH OVERLAY
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: CriticalStrikeFlashPainter(
                        flashes: controller.activeCriticalFlashes,
                      ),
                    ),
                  ),
                ),

                // 9. FLOATING DAMAGE NUMBERS OVERLAY
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: DungeonDamageOverlayPainter(
                        damageNumbers: controller.damageNumbers,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
