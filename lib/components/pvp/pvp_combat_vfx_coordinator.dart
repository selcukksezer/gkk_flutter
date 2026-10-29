import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/combat/combat_juice_coordinator.dart';
import '../../core/vfx/directional_camera_shake.dart';
import '../../core/vfx/gpu_particle_system.dart';
import '../../core/vfx/ground_decal_system.dart' as decals;
import '../../core/vfx/hit_stop_manager.dart';
import '../../core/vfx/knockback_ragdoll_controller.dart';
import '../../core/vfx/ribbon_trail_renderer.dart' as ribbon;
import '../../core/vfx/rim_hit_flash_effect.dart';

// =============================================================================
// PVP COMBAT VFX & GAME FEEL COORDINATOR (2027 Aion 2 Obsidian-Glass & Juice V2)
// Orchestrates ALL 9 Combat Juice Modules into PvP Arena Duels:
// 1. Directional Camera Shake (trauma decay + angle bias + harmonic damping)
// 2. Hit-Stop (strict 30-50ms channel-targeted micro-pauses on all hits)
// 3. Rim Flash (Fresnel silhouette highlight synchronized with hit-stop freeze)
// 4. Weapon Trails (Dual blade / greatsword / runic blade ribbon arcs)
// 5. Dynamic Decals (Sand bursts, ground cracks, blood splatter, scorch marks)
// 6. Particles (Clashing incandescent sparks, blood spray, impact flashes)
// 7. Mobile Haptics (Actuator-protected: Medium on normal, Heavy on critical)
// 8. Floating Damage Numbers & Dynamic Combo Multiplier Counter
// 9. Knockback & Stun Reactions (Harmonic spring recoil + stun swirl)
// 10. Aion 2 Obsidian-Glass telemetry HUD & leak-free managed lifecycle host
// =============================================================================

/// Weapon archetype used in the duel for ribbon trail styling.
enum PvpWeaponTrailType {
  dualBlades,
  greatsword,
  runicBlade,
}

/// A floating damage number popup animating in screen space.
class PvpDamagePopup {
  PvpDamagePopup({
    required this.id,
    required this.text,
    required this.position,
    required this.color,
    this.isCritical = false,
    this.isParry = false,
    this.isBlocked = false,
    this.initialScale = 1.0,
    Duration? lifetime,
  })  : lifetime = lifetime ?? const Duration(milliseconds: 950),
        createdAt = DateTime.now();

  final String id;
  final String text;
  final Offset position;
  final Color color;
  final bool isCritical;
  final bool isParry;
  final bool isBlocked;
  final double initialScale;
  final Duration lifetime;
  final DateTime createdAt;

  /// Current normalized animation progress [0.0, 1.0].
  double progress(DateTime now) {
    final int elapsed = now.difference(createdAt).inMilliseconds;
    return (elapsed / lifetime.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Whether this popup has expired and can be collected.
  bool isExpired(DateTime now) => progress(now) >= 1.0;

  /// Current animated screen offset with initial upward bounce and float.
  Offset animatedOffset(DateTime now) {
    final double t = progress(now);
    // Bouncy arc upwards: sharp initial ascent, smooth settle float
    final double yOffset = -55.0 * math.sin(t * math.pi * 0.75);
    final double xDrift = (isCritical ? 14.0 : 6.0) * math.sin(t * math.pi);
    return Offset(position.dx + xDrift, position.dy + yOffset);
  }

  /// Current scale with critical punch-in pop.
  double animatedScale(DateTime now) {
    final double t = progress(now);
    if (isCritical) {
      if (t < 0.25) {
        // Elastic pop up to 1.45x
        return initialScale * (1.0 + 0.45 * math.sin(t / 0.25 * math.pi * 0.5));
      } else {
        return initialScale * (1.45 - (t - 0.25) * 0.45);
      }
    }
    return initialScale * (1.0 + 0.15 * math.sin(t * math.pi));
  }

  /// Current opacity with fast fade out at tail.
  double animatedOpacity(DateTime now) {
    final double t = progress(now);
    if (t < 0.70) return 1.0;
    return (1.0 - (t - 0.70) / 0.30).clamp(0.0, 1.0);
  }
}

/// Streak combo counter for duel consecutive hits.
class PvpComboTracker {
  int _comboCount = 0;
  DateTime _lastHitTime = DateTime.now();
  static const Duration comboTimeout = Duration(milliseconds: 2200);

  int get comboCount => _comboCount;

  /// Increments combo and returns formatted title if threshold met (e.g. 2x, 3x...).
  String? registerHit({bool isCrit = false}) {
    final DateTime now = DateTime.now();
    if (now.difference(_lastHitTime) > comboTimeout) {
      _comboCount = 0;
    }
    _comboCount++;
    _lastHitTime = now;

    if (_comboCount >= 2) {
      if (isCrit) {
        return '$_comboCount' 'x KOMBO KRİTİK!';
      } else {
        return '$_comboCount' 'x KOMBO!';
      }
    }
    return null;
  }

  void reset() {
    _comboCount = 0;
  }
}

/// Fighter physical knockback and stun reaction controller using harmonic spring physics.
class PvpFighterReactionState {
  Offset offset = Offset.zero;
  Offset velocity = Offset.zero;
  double rotation = 0.0;
  double rotationVelocity = 0.0;
  bool isStunned = false;
  double stunTimer = 0.0;
  double stunDuration = 0.0;

  // Spring constants for snappy AAA recoil and return
  double springStiffness = 320.0;
  double damping = 22.0;

  /// Applies a directional knockback impulse.
  void applyKnockback(Offset impulse, {bool triggerStun = false, double stunSec = 0.65}) {
    velocity += impulse;
    rotationVelocity += (impulse.dx > 0 ? 0.22 : -0.22) * (impulse.distance / 120.0);
    if (triggerStun) {
      isStunned = true;
      stunDuration = stunSec;
      stunTimer = stunSec;
    }
  }

  /// Advances spring simulation by [dt] seconds.
  void update(double dt) {
    if (dt <= 0.0) return;

    // Translation spring
    final Offset springForce = -offset * springStiffness;
    final Offset dampingForce = -velocity * damping;
    final Offset acceleration = springForce + dampingForce;
    velocity += acceleration * dt;
    offset += velocity * dt;

    // Rotation spring
    final double rotSpringForce = -rotation * (springStiffness * 0.7);
    final double rotDampingForce = -rotationVelocity * damping;
    rotationVelocity += (rotSpringForce + rotDampingForce) * dt;
    rotation += rotationVelocity * dt;

    // Stun countdown
    if (isStunned) {
      stunTimer -= dt;
      if (stunTimer <= 0.0) {
        isStunned = false;
        stunTimer = 0.0;
      }
    }
  }

  void reset() {
    offset = Offset.zero;
    velocity = Offset.zero;
    rotation = 0.0;
    rotationVelocity = 0.0;
    isStunned = false;
    stunTimer = 0.0;
  }
}

/// Tactile mobile haptic controller supporting test mode toggles.
///
/// Strictly conforms to AAA mobile combat juice standards:
/// - Normal Hit: [HapticFeedback.mediumImpact] (micro-throttled to 25ms to prevent actuator stall)
/// - Critical Hit: [HapticFeedback.heavyImpact] with secondary resonance pulse
/// - Block: [HapticFeedback.selectionClick]
/// - Parry: [HapticFeedback.selectionClick] -> [HapticFeedback.mediumImpact]
/// - Stun / Lethal: [HapticFeedback.heavyImpact] -> [HapticFeedback.vibrate]
class PvpMobileHaptics {
  bool enabled = true;
  DateTime _lastHapticTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Triggered on normal hit impacts: synced with medium impact haptic pulse.
  Future<void> onNormalHit() async {
    if (!enabled) return;
    final DateTime now = DateTime.now();
    // 25ms micro-throttle prevents mobile actuator stutter on high APS combos
    if (now.difference(_lastHapticTime).inMilliseconds < 25) return;
    _lastHapticTime = now;

    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Medium impact feedback pulse.
  Future<void> onMediumHit() async {
    if (!enabled) return;
    final DateTime now = DateTime.now();
    if (now.difference(_lastHapticTime).inMilliseconds < 25) return;
    _lastHapticTime = now;

    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Shield deflection or glancing block feedback.
  Future<void> onBlocked() async {
    if (!enabled) return;
    _lastHapticTime = DateTime.now();
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Perfect parry feedback (sharp click followed by heavy counterpulse).
  Future<void> onParry() async {
    if (!enabled) return;
    _lastHapticTime = DateTime.now();
    try {
      await HapticFeedback.selectionClick();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Heavy impact feedback.
  Future<void> onHeavyHit() async {
    if (!enabled) return;
    _lastHapticTime = DateTime.now();
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Triggered on critical strikes: synced with heavy impact haptic pulse.
  Future<void> onCriticalHit() async {
    if (!enabled) return;
    _lastHapticTime = DateTime.now();
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 65));
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Heavy fatal knockout or boss stun vibration.
  Future<void> onStunOrLethal() async {
    if (!enabled) return;
    _lastHapticTime = DateTime.now();
    try {
      await HapticFeedback.heavyImpact();
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}

/// Main PvP Combat Game Feel & VFX Coordinator.
class PvpCombatVfxCoordinator {
  PvpCombatVfxCoordinator({
    this.enableCameraShake = true,
    this.enableHitStop = true,
    this.enableRimFlash = true,
    this.enableWeaponTrails = true,
    this.enableDecals = true,
    this.enableParticles = true,
    this.enableHaptics = true,
    this.enableFloatingDamage = true,
    this.enableKnockback = true,
  }) {
    _initSubsystems();
  }

  final bool enableCameraShake;
  final bool enableHitStop;
  final bool enableRimFlash;
  final bool enableWeaponTrails;
  final bool enableDecals;
  final bool enableParticles;
  final bool enableHaptics;
  final bool enableFloatingDamage;
  final bool enableKnockback;

  // 1. Camera Shake
  late final DirectionalCameraShake cameraShake;

  // 2. Hit Stop (30-50ms target)
  late final HitStopManager hitStopManager;

  // 3. Rim Flash (Opponent left & Me right)
  late final RimHitFlashController opponentRimFlash;
  late final RimHitFlashController meRimFlash;

  // 4. Weapon Ribbon Trails
  late final ribbon.RibbonTrail ribbonTrail;

  // 5. Dynamic Colosseum Ground Decals
  late final decals.GroundDecalSystem decalSystem;

  // 6. Multi-layer GPU / Canvas Spark Particles
  late final GpuParticleSystem particleSystem;

  // 7. Mobile Haptics
  final PvpMobileHaptics haptics = PvpMobileHaptics();

  // 8. Floating Damage Numbers & Combo Counter
  final List<PvpDamagePopup> damagePopups = <PvpDamagePopup>[];
  final PvpComboTracker comboTracker = PvpComboTracker();
  String? activeComboBanner;
  double comboBannerTimer = 0.0;

  // 9. Knockback & Stun Reactions (Opponent left & Me right)
  final PvpFighterReactionState opponentReaction = PvpFighterReactionState();
  final PvpFighterReactionState meReaction = PvpFighterReactionState();

  bool _isDisposed = false;
  int _eventCounter = 0;

  /// Whether this coordinator has been disposed.
  bool get isDisposed => _isDisposed;

  /// Whether any combat channel is currently undergoing a hit-stop micro-pause.
  bool get isHitStopActive => enableHitStop && hitStopManager.isAnyFrozen;

  /// Current trauma intensity level [0.0, 1.0].
  double get currentTrauma => enableCameraShake ? cameraShake.trauma : 0.0;

  /// Current opponent rim-flash luminescence intensity.
  double get opponentRimIntensity =>
      enableRimFlash ? opponentRimFlash.currentIntensity : 0.0;

  /// Current local player rim-flash luminescence intensity.
  double get meRimIntensity =>
      enableRimFlash ? meRimFlash.currentIntensity : 0.0;

  void _initSubsystems() {
    // 1. Camera shake with punchy mobile parameters
    cameraShake = DirectionalCameraShake(
      config: const CameraShakeConfig(
        traumaExponent: 2.0,
        decayRate: 2.2,
        maxTranslation: Offset(18.0, 12.0),
        maxRoll: 0.055,
        directionalBiasWeight: 0.82,
      ),
    );

    // 2. Hit Stop Manager (30-50ms R3 spec)
    hitStopManager = HitStopManager();

    // 3. Rim flash controllers
    opponentRimFlash = RimHitFlashController(
      defaultConfig: const RimHitFlashConfig(
        duration: Duration(milliseconds: 140),
        rimPower: 3.5,
        rimIntensity: 2.2,
      ),
    );
    meRimFlash = RimHitFlashController(
      defaultConfig: const RimHitFlashConfig(
        duration: Duration(milliseconds: 140),
        rimPower: 3.5,
        rimIntensity: 2.2,
      ),
    );

    // 4. Ribbon trail for weapon arcs
    ribbonTrail = ribbon.RibbonTrail(
      config: const ribbon.RibbonTrailConfig(
        baseColor: Color(0xFFFF8800),
        glowColor: Color(0xFFFFDD44),
        glowIntensity: 2.8,
        lifetime: 0.28,
      ),
    );

    // 5. Arena Ground Decals
    decalSystem = decals.GroundDecalSystem(maxDecals: 32);

    // 6. Particle System (Sparks + Flash)
    particleSystem = GpuParticlePresets.weaponImpact();

    haptics.enabled = enableHaptics;
  }

  // ---------------------------------------------------------------------------
  // Combat Event Dispatchers
  // ---------------------------------------------------------------------------

  /// Triggers a weapon attack swing drawing ribbon arcs across arena from attacker to defender.
  void triggerWeaponSwing({
    required bool attackerIsMe,
    required Offset attackerPos,
    required Offset defenderPos,
    PvpWeaponTrailType weaponType = PvpWeaponTrailType.dualBlades,
    bool isHeavy = false,
  }) {
    if (!enableWeaponTrails || _isDisposed) return;

    final Color baseColor;
    final Color glowColor;
    final double arcSpan;

    switch (weaponType) {
      case PvpWeaponTrailType.dualBlades:
        baseColor = const Color(0xFFFF7700);
        glowColor = const Color(0xFFFFEE55);
        arcSpan = math.pi * 0.65;
      case PvpWeaponTrailType.greatsword:
        baseColor = const Color(0xFFE52E2E);
        glowColor = const Color(0xFFFF9944);
        arcSpan = math.pi * 0.85;
      case PvpWeaponTrailType.runicBlade:
        baseColor = const Color(0xFF00E5FF);
        glowColor = const Color(0xFF88FFFF);
        arcSpan = math.pi * 0.70;
    }

    ribbonTrail.config = ribbonTrail.config.copyWith(
      baseColor: baseColor,
      glowColor: glowColor,
      glowIntensity: isHeavy ? 3.6 : 2.5,
    );

    final Offset dir = (defenderPos - attackerPos);
    final double angle = math.atan2(dir.dy, dir.dx);
    final double distance = dir.distance.clamp(40.0, 240.0);
    const int steps = 8;
    final double startAngle = angle - arcSpan * 0.5;
    final double endAngle = angle + arcSpan * 0.5;
    final double now = ribbonTrail.currentTime;

    for (int i = 0; i <= steps; i++) {
      final double t = i / steps;
      final double curAngle = startAngle + (endAngle - startAngle) * t;
      final Offset tip = attackerPos +
          Offset(math.cos(curAngle), math.sin(curAngle)) * (distance * 0.75);
      final Offset base = attackerPos +
          Offset(math.cos(curAngle), math.sin(curAngle)) * (distance * 0.15);

      ribbonTrail.addSample(
        tip: tip,
        base: base,
        timestamp: now + t * 0.16,
        color: Color.lerp(baseColor, glowColor, t),
        width: isHeavy ? 18.0 : 12.0,
      );
    }
  }

  /// Triggers a full strike impact with all 9 modules coordinated.
  ///
  /// Orchestrates hit-stop micro-pauses (30-50ms), directional camera shake triggers,
  /// Fresnel rim-light flash pulses, and mobile haptics (medium impact on normal,
  /// heavy impact on critical).
  void triggerHitImpact({
    required bool targetIsOpponent,
    required double damageValue,
    required bool isCritical,
    required Offset impactPoint,
    bool isParried = false,
    bool isBlocked = false,
    bool isStun = false,
    HitDamageType damageType = HitDamageType.physical,
  }) {
    if (_isDisposed) return;
    _eventCounter++;

    // Hit direction: from attacker toward defender
    final double hitAngle = targetIsOpponent ? math.pi : 0.0;
    final Offset hitDir = Offset(math.cos(hitAngle), math.sin(hitAngle));

    // 1. Camera Shake (Directional with trauma)
    if (enableCameraShake) {
      if (isCritical) {
        cameraShake.triggerPreset(
          CameraShakePreset.heavyCrit,
          hitDirection: hitDir,
          directionalWeight: 0.88,
        );
      } else if (isParried) {
        cameraShake.triggerPreset(
          CameraShakePreset.microVibration,
          hitDirection: hitDir,
          directionalWeight: 0.75,
        );
      } else if (isBlocked) {
        cameraShake.addTrauma(
          0.22,
          hitDirection: hitDir,
          directionalWeight: 0.65,
        );
      } else {
        cameraShake.triggerPreset(
          CameraShakePreset.lightJab,
          hitDirection: hitDir,
          directionalWeight: 0.72,
        );
      }
    }

    // 2. Hit-Stop (Strict 30-50ms channel-targeted micro-pauses on all hits)
    Duration freezeDuration = Duration.zero;
    if (enableHitStop) {
      if (isCritical) {
        // 50ms heavy critical impact freeze on combat characters
        freezeDuration = const Duration(milliseconds: 50);
        hitStopManager.trigger(
          const HitStopRequest(
            id: 'pvp_crit',
            freezeDuration: Duration(milliseconds: 50),
            easeOutDuration: Duration(milliseconds: 20),
            targetTimeScale: 0.0,
            channels: TimeDilationChannel.combatPair,
            conflictPolicy: HitStopConflictPolicy.extend,
            resumptionCurve: HitStopResumptionCurve.easeOutCubic,
            priority: 4,
          ),
        );
      } else if (isParried) {
        // 35ms parry clash micro-pause
        freezeDuration = const Duration(milliseconds: 35);
        hitStopManager.trigger(
          const HitStopRequest(
            id: 'pvp_parry',
            freezeDuration: Duration(milliseconds: 35),
            easeOutDuration: Duration(milliseconds: 15),
            targetTimeScale: 0.0,
            channels: TimeDilationChannel.combatPair,
            conflictPolicy: HitStopConflictPolicy.extend,
            resumptionCurve: HitStopResumptionCurve.smoothStep,
            priority: 3,
          ),
        );
      } else if (isStun) {
        // 45ms stun breaker micro-pause
        freezeDuration = const Duration(milliseconds: 45);
        hitStopManager.trigger(
          const HitStopRequest(
            id: 'pvp_stun',
            freezeDuration: Duration(milliseconds: 45),
            easeOutDuration: Duration(milliseconds: 18),
            targetTimeScale: 0.0,
            channels: TimeDilationChannel.combatPair,
            conflictPolicy: HitStopConflictPolicy.extend,
            resumptionCurve: HitStopResumptionCurve.easeOutCubic,
            priority: 3,
          ),
        );
      } else if (isBlocked) {
        // 30ms shield block micro-pause
        freezeDuration = const Duration(milliseconds: 30);
        hitStopManager.trigger(
          const HitStopRequest(
            id: 'pvp_block',
            freezeDuration: Duration(milliseconds: 30),
            easeOutDuration: Duration(milliseconds: 12),
            targetTimeScale: 0.05,
            channels: TimeDilationChannel.combatPair,
            conflictPolicy: HitStopConflictPolicy.extend,
            resumptionCurve: HitStopResumptionCurve.easeOutQuad,
            priority: 2,
          ),
        );
      } else {
        // 30ms meaty normal hit micro-pause
        freezeDuration = const Duration(milliseconds: 30);
        hitStopManager.trigger(
          const HitStopRequest(
            id: 'pvp_normal_hit',
            freezeDuration: Duration(milliseconds: 30),
            easeOutDuration: Duration(milliseconds: 15),
            targetTimeScale: 0.0,
            channels: TimeDilationChannel.combatPair,
            conflictPolicy: HitStopConflictPolicy.extend,
            resumptionCurve: HitStopResumptionCurve.smoothStep,
            priority: 2,
          ),
        );
      }
    }

    // 3. Rim Flash on Struck Target (Synchronized with Hit-Stop Duration)
    if (enableRimFlash) {
      final RimHitFlashController targetController =
          targetIsOpponent ? opponentRimFlash : meRimFlash;
      final ui.Color rimTint;
      final double intensity;

      if (isParried || isBlocked) {
        rimTint = RimFlashTint.lightningGold;
        intensity = 1.9;
      } else if (isCritical) {
        rimTint = RimFlashTint.bloodRed;
        intensity = 2.6;
      } else {
        rimTint = damageType.rimFlashTint;
        intensity = 1.35;
      }

      targetController.triggerHit(
        tint: rimTint,
        intensityMultiplier: intensity,
        duration: const Duration(milliseconds: 120),
        hitStopDuration: freezeDuration,
      );
    }

    // 4. Dynamic Decals on Colosseum Ground
    if (enableDecals) {
      final decals.Vector3D worldPos = decals.Vector3D(
        targetIsOpponent ? -2.2 : 2.2,
        0.0,
        0.0,
      );

      if (isCritical) {
        decalSystem.spawnBloodSplatter(
          position: worldPos,
          radius: 2.2,
        );
      } else if (isParried) {
        decalSystem.spawnScorchMark(
          position: worldPos,
          radius: 1.4,
        );
      } else {
        decalSystem.spawnSlashGouge(
          position: worldPos,
          strikeDirection: decals.Vector3D(hitDir.dx, 0.0, hitDir.dy),
          length: 2.4,
          width: 0.6,
        );
      }
    }

    // 5. Particles (Sparks & Spray)
    if (enableParticles) {
      final int sparkCount = isCritical ? 45 : (isParried ? 30 : 18);
      particleSystem.emitBurst(
        layerIndex: 0,
        count: sparkCount,
        origin: impactPoint,
        directionAngle: isParried ? hitAngle + math.pi : hitAngle,
        speedMultiplier: isCritical ? 1.4 : 1.0,
      );

      if (particleSystem.layers.length > 1) {
        particleSystem.emitBurst(
          layerIndex: 1,
          count: isCritical ? 24 : 8,
          origin: impactPoint,
        );
      }
    }

    // 6. Mobile Haptics (Heavy on critical, Medium on normal)
    if (enableHaptics) {
      if (isCritical) {
        haptics.onCriticalHit();
      } else if (isParried) {
        haptics.onParry();
      } else if (isBlocked) {
        haptics.onBlocked();
      } else if (isStun) {
        haptics.onStunOrLethal();
      } else {
        haptics.onNormalHit();
      }
    }

    // 7. Floating Damage Numbers & Combo Counter
    if (enableFloatingDamage) {
      final String labelText;
      final Color labelColor;

      if (isParried) {
        labelText = 'PARRY!';
        labelColor = const Color(0xFFFFD54F);
      } else if (isBlocked) {
        labelText = 'BLOK! -${damageValue.round()}';
        labelColor = const Color(0xFF64B5F6);
      } else if (isCritical) {
        labelText = '💥 KRİTİK! -${damageValue.round()}';
        labelColor = const Color(0xFFFF1744);
      } else {
        labelText = '-${damageValue.round()}';
        labelColor = Colors.white;
      }

      damagePopups.add(
        PvpDamagePopup(
          id: 'dmg_$_eventCounter',
          text: labelText,
          position: impactPoint,
          color: labelColor,
          isCritical: isCritical,
          isParry: isParried,
          isBlocked: isBlocked,
          initialScale: isCritical ? 1.35 : 1.0,
        ),
      );

      final String? comboTitle = comboTracker.registerHit(isCrit: isCritical);
      if (comboTitle != null) {
        activeComboBanner = comboTitle;
        comboBannerTimer = 1.6;
      }
    }

    // 8. Knockback & Stun Reaction
    if (enableKnockback) {
      final PvpFighterReactionState targetState =
          targetIsOpponent ? opponentReaction : meReaction;
      final double force = isCritical ? 65.0 : (isParried ? 18.0 : 36.0);
      final Offset impulse = hitDir * force;

      targetState.applyKnockback(
        impulse,
        triggerStun: isStun || (isCritical && damageValue > 400),
        stunSec: 0.70,
      );
    }
  }

  /// Triggers lethal finisher impact terminating the match.
  void triggerLethalFinisher({
    required bool targetIsOpponent,
    required Offset impactPoint,
  }) {
    if (_isDisposed) return;
    _eventCounter++;

    final double hitAngle = targetIsOpponent ? math.pi : 0.0;
    final Offset hitDir = Offset(math.cos(hitAngle), math.sin(hitAngle));

    if (enableCameraShake) {
      cameraShake.triggerPreset(
        CameraShakePreset.explosiveShock,
        hitDirection: hitDir,
        directionalWeight: 0.95,
      );
    }

    if (enableHitStop) {
      hitStopManager.trigger(
        const HitStopRequest(
          id: 'pvp_lethal',
          freezeDuration: Duration(milliseconds: 50),
          easeOutDuration: Duration(milliseconds: 25),
          targetTimeScale: 0.0,
          channels: TimeDilationChannel.combatPair,
          conflictPolicy: HitStopConflictPolicy.override,
          resumptionCurve: HitStopResumptionCurve.easeOutCubic,
          priority: 5,
        ),
      );
    }

    if (enableRimFlash) {
      final RimHitFlashController targetController =
          targetIsOpponent ? opponentRimFlash : meRimFlash;
      targetController.triggerHit(
        tint: RimFlashTint.bloodRed,
        intensityMultiplier: 3.0,
        duration: const Duration(milliseconds: 240),
        hitStopDuration: const Duration(milliseconds: 50),
      );
    }

    if (enableDecals) {
      decalSystem.spawnBloodSplatter(
        position: decals.Vector3D(targetIsOpponent ? -2.2 : 2.2, 0.0, 0.0),
        radius: 3.2,
      );
    }

    if (enableParticles) {
      particleSystem.emitBurst(
        layerIndex: 0,
        count: 65,
        origin: impactPoint,
        speedMultiplier: 1.6,
      );
    }

    if (enableHaptics) {
      haptics.onStunOrLethal();
    }

    if (enableFloatingDamage) {
      damagePopups.add(
        PvpDamagePopup(
          id: 'dmg_fatal_$_eventCounter',
          text: '💀 NAKAVT!',
          position: impactPoint,
          color: const Color(0xFFFF1744),
          isCritical: true,
          initialScale: 1.6,
        ),
      );
    }

    if (enableKnockback) {
      final PvpFighterReactionState targetState =
          targetIsOpponent ? opponentReaction : meReaction;
      targetState.applyKnockback(
        hitDir * 110.0,
        triggerStun: true,
        stunSec: 1.5,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Simulation Loop
  // ---------------------------------------------------------------------------

  /// Advances all 9 subsystems simultaneously by [dt] seconds.
  void update(double dt) {
    if (dt <= 0.0 || _isDisposed) return;

    // 1. Camera Shake
    cameraShake.update(dt);

    // 2. Hit Stop
    hitStopManager.update(dt);

    // 3. Rim Flash
    opponentRimFlash.update(dt);
    meRimFlash.update(dt);

    // 4. Ribbon Trails
    ribbonTrail.update(dt);

    // 5. Decals
    decalSystem.update(dt);

    // 6. Particles
    particleSystem.update(dt);

    // 8. Damage popups cleanup
    final DateTime now = DateTime.now();
    damagePopups.removeWhere((PvpDamagePopup p) => p.isExpired(now));

    // Combo banner countdown
    if (comboBannerTimer > 0.0) {
      comboBannerTimer -= dt;
      if (comboBannerTimer <= 0.0) {
        activeComboBanner = null;
        comboBannerTimer = 0.0;
      }
    }

    // 9. Knockback & Stun reactions
    opponentReaction.update(dt);
    meReaction.update(dt);
  }

  void reset() {
    opponentReaction.reset();
    meReaction.reset();
    comboTracker.reset();
    activeComboBanner = null;
    damagePopups.clear();
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    cameraShake.dispose();
    hitStopManager.dispose();
    opponentRimFlash.dispose();
    meRimFlash.dispose();
    ribbonTrail.clear();
    decalSystem.clearAll();
    particleSystem.buffer.clear();
    damagePopups.clear();
  }
}

// =============================================================================
// 2027 AION 2 OBSIDIAN-GLASS & COMBAT VFX UI COMPONENTS
// =============================================================================

/// 2027 Aion 2 Obsidian-Glass container with deep refractive backing,
/// subtle aether edge luminescence, and specular top highlight.
class PvpObsidianGlassCard extends StatelessWidget {
  const PvpObsidianGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12.0),
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(16.0)),
    this.obsidianColor = const Color(0xF0080B12),
    this.accentLuminescence = const Color(0xFF00E5FF),
    this.glowIntensity = 0.35,
    this.blurSigma = 14.0,
    this.applySafeArea = false,
    this.safeAreaMinimum = EdgeInsets.zero,
    this.borderWidth = 1.2,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Color obsidianColor;
  final Color accentLuminescence;
  final double glowIntensity;
  final double blurSigma;
  final bool applySafeArea;
  final EdgeInsets safeAreaMinimum;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (applySafeArea) {
      content = SafeArea(
        minimum: safeAreaMinimum,
        child: content,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          // Deep drop shadow for floating elevation
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 18.0,
            offset: const Offset(0, 8),
          ),
          // Aether rim luminescence
          if (glowIntensity > 0.0)
            BoxShadow(
              color: accentLuminescence
                  .withValues(alpha: (glowIntensity * 0.45).clamp(0.0, 1.0)),
              blurRadius: 16.0,
              spreadRadius: -2.0,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  obsidianColor,
                  obsidianColor.withValues(
                      alpha: (obsidianColor.a * 0.88).clamp(0.0, 1.0)),
                  const Color(0xFF05070B).withValues(alpha: 0.96),
                ],
              ),
              border: Border.all(
                color: Color.lerp(
                      const Color(0x33445566),
                      accentLuminescence,
                      (glowIntensity * 0.65).clamp(0.0, 1.0),
                    ) ??
                    const Color(0x33445566),
                width: borderWidth,
              ),
            ),
            child: Stack(
              children: <Widget>[
                // Specular top highlight (Aion 2 polished obsidian crystal rim)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 1.2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.35),
                          accentLuminescence.withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                        stops: const <double>[0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Real-time 2027 Aion 2 Obsidian-Glass Combat Juice Telemetry HUD.
///
/// Visualizes hit-stop state (30-50ms), directional camera shake trauma,
/// Fresnel rim-light flashes, and streak combo counters with zero local overhead.
class PvpCombatVfxObsidianHud extends StatelessWidget {
  const PvpCombatVfxObsidianHud({
    super.key,
    required this.coordinator,
    this.compact = false,
    this.showHitStop = true,
    this.showTrauma = true,
    this.showRimFlash = true,
    this.showCombo = true,
  });

  final PvpCombatVfxCoordinator coordinator;
  final bool compact;
  final bool showHitStop;
  final bool showTrauma;
  final bool showRimFlash;
  final bool showCombo;

  @override
  Widget build(BuildContext context) {
    final bool isFrozen = coordinator.isHitStopActive;
    final double trauma = coordinator.currentTrauma;
    final double opponentFlash = coordinator.opponentRimIntensity;
    final double meFlash = coordinator.meRimIntensity;
    final int combo = coordinator.comboTracker.comboCount;

    final Color activeLuminescence = isFrozen
        ? const Color(0xFFFFD54F) // Hit-stop gold freeze
        : (trauma > 0.4
            ? const Color(0xFFFF3366) // Heavy trauma crimson
            : const Color(0xFF00E5FF)); // Aether cyan standby

    return RepaintBoundary(
      child: SafeArea(
        child: PvpObsidianGlassCard(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0)
              : const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          accentLuminescence: activeLuminescence,
          glowIntensity: isFrozen ? 0.85 : (trauma * 0.7).clamp(0.15, 0.7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Hit Stop Status Badge (30-50ms)
              if (showHitStop) ...<Widget>[
                _buildHitStopBadge(isFrozen),
                const SizedBox(width: 8),
              ],

              // Camera Shake Trauma Gauge
              if (showTrauma) ...<Widget>[
                _buildTraumaMeter(trauma),
                const SizedBox(width: 8),
              ],

              // Rim Flash Luminescence Pulse Dots
              if (showRimFlash) ...<Widget>[
                _buildRimPulseDot('ME', meFlash, const Color(0xFF00E5FF)),
                const SizedBox(width: 4),
                _buildRimPulseDot('OPP', opponentFlash, const Color(0xFFFF3366)),
              ],

              // Combo Count
              if (showCombo && combo >= 2) ...<Widget>[
                const SizedBox(width: 8),
                _buildComboBadge(combo),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHitStopBadge(bool isFrozen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: isFrozen
            ? const Color(0xFFFFD54F).withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: isFrozen ? const Color(0xFFFFD54F) : Colors.white24,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isFrozen ? Icons.pause_circle_filled : Icons.play_arrow,
            size: 11,
            color: isFrozen ? const Color(0xFFFFD54F) : Colors.white60,
          ),
          const SizedBox(width: 3),
          Text(
            isFrozen ? 'HIT-STOP' : 'FLOW',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isFrozen ? const Color(0xFFFFD54F) : Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraumaMeter(double trauma) {
    return SizedBox(
      width: 46,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'TRAUMA',
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Colors.white70,
                ),
              ),
              Text(
                '${(trauma * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  color:
                      trauma > 0.5 ? const Color(0xFFFF5252) : Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2.0),
            child: LinearProgressIndicator(
              value: trauma.clamp(0.0, 1.0),
              minHeight: 3.0,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                trauma > 0.6
                    ? const Color(0xFFFF1744)
                    : (trauma > 0.3
                        ? const Color(0xFFFFB300)
                        : const Color(0xFF00E5FF)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRimPulseDot(String label, double intensity, Color tint) {
    final bool active = intensity > 0.05;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: active
            ? tint.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8.0,
          fontWeight: FontWeight.w800,
          color: active ? tint : Colors.white38,
        ),
      ),
    );
  }

  Widget _buildComboBadge(int combo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFB300), Color(0xFFFF3D00)],
        ),
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Text(
        '${combo}x',
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Managed Ticker host widget that automatically updates [PvpCombatVfxCoordinator]
/// at 60/120Hz without any unmanaged animation controllers or memory leaks.
///
/// Wraps child in an isolated subtree and selectively ticks the coordinator.
class PvpCombatJuiceHost extends StatefulWidget {
  const PvpCombatJuiceHost({
    super.key,
    required this.coordinator,
    required this.child,
    this.autoTick = true,
    this.showTelemetryHud = false,
  });

  final PvpCombatVfxCoordinator coordinator;
  final Widget child;
  final bool autoTick;
  final bool showTelemetryHud;

  @override
  State<PvpCombatJuiceHost> createState() => _PvpCombatJuiceHostState();
}

class _PvpCombatJuiceHostState extends State<PvpCombatJuiceHost>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.autoTick) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    // Cap dt to 33ms (max 1 frame step) to prevent physics integrator instability
    final double rawDt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    final double dt = math.min(rawDt, 0.033);
    _lastElapsed = elapsed;

    if (!widget.coordinator.isDisposed && dt > 0.0) {
      widget.coordinator.update(dt);
      if (mounted && widget.showTelemetryHud) {
        setState(() {});
      }
    }
  }

  @override
  void didUpdateWidget(covariant PvpCombatJuiceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoTick != oldWidget.autoTick) {
      if (widget.autoTick && !_ticker.isActive) {
        _lastElapsed = Duration.zero;
        _ticker.start();
      } else if (!widget.autoTick && _ticker.isActive) {
        _ticker.stop();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        if (widget.showTelemetryHud)
          Positioned(
            top: 12,
            right: 12,
            child: PvpCombatVfxObsidianHud(
              coordinator: widget.coordinator,
              compact: true,
            ),
          ),
      ],
    );
  }
}

/// Compact hit juice badge showing hit-stop micro-pause duration (30-50ms)
/// and rim-light flash state in 2027 Aion 2 Obsidian-Glass styling.
class PvpObsidianHitJuiceIndicator extends StatelessWidget {
  const PvpObsidianHitJuiceIndicator({
    super.key,
    required this.coordinator,
  });

  final PvpCombatVfxCoordinator coordinator;

  @override
  Widget build(BuildContext context) {
    if (!coordinator.isHitStopActive && coordinator.currentTrauma <= 0.05) {
      return const SizedBox.shrink();
    }

    final bool isFrozen = coordinator.isHitStopActive;
    final String label = isFrozen ? 'HIT-STOP [30-50ms]' : 'TRAUMA RECOIL';
    final Color tint =
        isFrozen ? const Color(0xFFFFD54F) : const Color(0xFFFF3366);

    return RepaintBoundary(
      child: PvpObsidianGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        accentLuminescence: tint,
        glowIntensity: 0.6,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: tint.withValues(alpha: 0.8),
                    blurRadius: 6.0,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
