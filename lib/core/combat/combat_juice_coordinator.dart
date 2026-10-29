import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

import '../vfx/directional_camera_shake.dart';
import '../vfx/gpu_particle_system.dart';
import '../vfx/ground_decal_system.dart' as decals;
import '../vfx/hit_stop_manager.dart';
import '../vfx/knockback_ragdoll_controller.dart';
import '../vfx/ribbon_trail_renderer.dart' as ribbon;
import '../vfx/rim_hit_flash_effect.dart';

// =============================================================================
// Combat Damage Types & Visual Mapping
// =============================================================================

/// Types of combat damage with specific sensory feedback profiles.
enum HitDamageType {
  physical,
  fire,
  frost,
  lightning,
  poison,
  holy,
  voidEnergy;

  /// Returns the corresponding Fresnel silhouette rim-flash color.
  ui.Color get rimFlashTint {
    switch (this) {
      case HitDamageType.physical:
        return RimFlashTint.white;
      case HitDamageType.fire:
        return const ui.Color(0xFFFF5500);
      case HitDamageType.frost:
        return RimFlashTint.magicalCyan;
      case HitDamageType.lightning:
        return RimFlashTint.lightningGold;
      case HitDamageType.poison:
        return RimFlashTint.poisonGreen;
      case HitDamageType.holy:
        return const ui.Color(0xFFFFFFA0);
      case HitDamageType.voidEnergy:
        return RimFlashTint.voidPurple;
    }
  }

  /// Default ground decal type spawned by this damage type.
  decals.DecalType get primaryDecalType {
    switch (this) {
      case HitDamageType.physical:
        return decals.DecalType.slashGouge;
      case HitDamageType.fire:
        return decals.DecalType.scorchMark;
      case HitDamageType.frost:
      case HitDamageType.holy:
      case HitDamageType.voidEnergy:
        return decals.DecalType.crackedEarth;
      case HitDamageType.poison:
        return decals.DecalType.bloodSplatter;
      case HitDamageType.lightning:
        return decals.DecalType.scorchMark;
    }
  }
}

// =============================================================================
// Combat Events
// =============================================================================

/// Base contract for all live combat events triggering game-feel feedback.
abstract class CombatJuiceEvent {
  final String eventId;
  final DateTime timestamp;
  final String attackerId;
  final String? targetId;
  final double hitAngle; // Radians
  final Offset screenImpactPoint;
  final decals.Vector3D worldImpactPoint;

  CombatJuiceEvent({
    String? eventId,
    DateTime? timestamp,
    required this.attackerId,
    this.targetId,
    this.hitAngle = 0.0,
    this.screenImpactPoint = Offset.zero,
    this.worldImpactPoint = decals.Vector3D.zero,
  })  : eventId = eventId ?? 'evt_${DateTime.now().microsecondsSinceEpoch}',
        timestamp = timestamp ?? DateTime.now();

  /// Normalized 2D direction vector corresponding to [hitAngle].
  Offset get hitDirection2D => Offset(math.cos(hitAngle), math.sin(hitAngle));

  /// Normalized 3D horizontal direction vector corresponding to [hitAngle].
  KnockbackVector3 get hitDirection3D =>
      KnockbackVector3(math.cos(hitAngle), 0.0, math.sin(hitAngle));
}

/// Attack swing initiated (draws weapon ribbon trail arc).
class CombatAttackSwingEvent extends CombatJuiceEvent {
  final double swingArcAngle; // Total arc angular span in radians
  final double swingSpeed; // Angular velocity or multiplier
  final double weaponLength; // Length of weapon blade/head
  final Offset weaponHiltPosition;
  final Offset weaponTipPosition;
  final bool isHeavySwing;
  final Color? customTrailColor;
  final Color? customGlowColor;
  final int arcSubdivisions;

  CombatAttackSwingEvent({
    super.eventId,
    super.timestamp,
    required super.attackerId,
    super.targetId,
    super.hitAngle,
    super.screenImpactPoint,
    super.worldImpactPoint,
    this.swingArcAngle = math.pi * 0.55,
    this.swingSpeed = 1.0,
    this.weaponLength = 70.0,
    this.weaponHiltPosition = Offset.zero,
    Offset? weaponTipPosition,
    this.isHeavySwing = false,
    this.customTrailColor,
    this.customGlowColor,
    this.arcSubdivisions = 8,
  }) : weaponTipPosition = weaponTipPosition ??
            weaponHiltPosition +
                Offset(math.cos(hitAngle), math.sin(hitAngle)) * weaponLength;
}

/// Combat hit impact on a target (camera shake, hit stop, rim flash, sparks, decals, knockback).
class CombatHitImpactEvent extends CombatJuiceEvent {
  final double damage;
  final double hitForce;
  final bool isCritical;
  final double criticalMultiplier;
  final HitDamageType damageType;
  final bool isBlocked;
  final bool isParried;
  final double targetMass;
  final double targetPoise;
  final double verticalLaunchRatio;
  final KnockbackVector3? customImpulseVector;

  CombatHitImpactEvent({
    super.eventId,
    super.timestamp,
    required super.attackerId,
    super.targetId,
    super.hitAngle,
    super.screenImpactPoint,
    super.worldImpactPoint,
    this.damage = 10.0,
    this.hitForce = 5.0,
    this.isCritical = false,
    this.criticalMultiplier = 2.0,
    this.damageType = HitDamageType.physical,
    this.isBlocked = false,
    this.isParried = false,
    this.targetMass = 70.0,
    this.targetPoise = 0.0,
    this.verticalLaunchRatio = 0.20,
    this.customImpulseVector,
  });

  /// Effective force accounting for critical strike bonus.
  double get effectiveForce =>
      isCritical ? hitForce * criticalMultiplier : hitForce;
}

/// Parry or shield block collision.
class CombatBlockParryEvent extends CombatJuiceEvent {
  final bool isPerfectParry;
  final double deflectionForce;
  final Offset sparkOrigin;

  CombatBlockParryEvent({
    super.eventId,
    super.timestamp,
    required super.attackerId,
    super.targetId,
    super.hitAngle,
    super.screenImpactPoint,
    super.worldImpactPoint,
    this.isPerfectParry = false,
    this.deflectionForce = 4.0,
    Offset? sparkOrigin,
  }) : sparkOrigin = sparkOrigin ?? screenImpactPoint;
}

/// Lethal blow terminating target entity.
class CombatDeathEvent extends CombatJuiceEvent {
  final bool isOverkill;
  final double fatalDamage;
  final double deathImpulseForce;
  final bool spawnBloodPool;

  CombatDeathEvent({
    super.eventId,
    super.timestamp,
    required super.attackerId,
    super.targetId,
    super.hitAngle,
    super.screenImpactPoint,
    super.worldImpactPoint,
    this.isOverkill = false,
    this.fatalDamage = 50.0,
    this.deathImpulseForce = 12.0,
    this.spawnBloodPool = true,
  });
}

// =============================================================================
// Combat Juice Result (Detailed telemetry record)
// =============================================================================

/// Record of all feedback mechanisms triggered by a combat event.
class CombatJuiceFeedbackResult {
  final String eventId;
  final DateTime processedAt;

  // Camera Shake
  final bool cameraShakeTriggered;
  final double appliedTrauma;
  final Offset cameraShakeDirection;

  // Hit Stop
  final bool hitStopTriggered;
  final Duration hitStopFreezeDuration;
  final Duration hitStopEaseOutDuration;

  // Rim Hit Flash
  final bool rimFlashTriggered;
  final ui.Color? rimFlashTint;
  final double rimFlashIntensity;

  // Ribbon Trail
  final bool ribbonTrailUpdated;
  final int ribbonSamplesAdded;

  // Knockback & Ragdoll
  final bool knockbackApplied;
  final KnockbackVector3 knockbackImpulse;
  final double targetRagdollWeight;

  // Ground Decal
  final bool groundDecalSpawned;
  final decals.DecalType? groundDecalType;

  // GPU Sparks
  final bool gpuSparksEmitted;
  final int sparkCount;

  const CombatJuiceFeedbackResult({
    required this.eventId,
    required this.processedAt,
    this.cameraShakeTriggered = false,
    this.appliedTrauma = 0.0,
    this.cameraShakeDirection = Offset.zero,
    this.hitStopTriggered = false,
    this.hitStopFreezeDuration = Duration.zero,
    this.hitStopEaseOutDuration = Duration.zero,
    this.rimFlashTriggered = false,
    this.rimFlashTint,
    this.rimFlashIntensity = 0.0,
    this.ribbonTrailUpdated = false,
    this.ribbonSamplesAdded = 0,
    this.knockbackApplied = false,
    this.knockbackImpulse = KnockbackVector3.zero,
    this.targetRagdollWeight = 0.0,
    this.groundDecalSpawned = false,
    this.groundDecalType,
    this.gpuSparksEmitted = false,
    this.sparkCount = 0,
  });

  /// Total hit stop duration (freeze + ease-out).
  Duration get totalHitStopDuration =>
      hitStopFreezeDuration + hitStopEaseOutDuration;

  @override
  String toString() =>
      'CombatJuiceFeedbackResult(eventId: $eventId, shake: $cameraShakeTriggered (trauma: ${appliedTrauma.toStringAsFixed(2)}), '
      'hitStop: $hitStopTriggered (${totalHitStopDuration.inMilliseconds}ms), '
      'rimFlash: $rimFlashTriggered, trail: $ribbonTrailUpdated ($ribbonSamplesAdded samples), '
      'knockback: $knockbackApplied, decal: $groundDecalSpawned ($groundDecalType), '
      'sparks: $gpuSparksEmitted ($sparkCount))';
}

// =============================================================================
// Coordinator Configuration
// =============================================================================

/// Global knobs and tuning parameters for Combat Juice & Game Feel.
class CombatJuiceConfig {
  final bool enableCameraShake;
  final bool enableHitStop;
  final bool enableRimFlash;
  final bool enableRibbonTrails;
  final bool enableKnockback;
  final bool enableGroundDecals;
  final bool enableGpuSparks;

  final double cameraShakeMultiplier;
  final double hitStopDurationMultiplier;
  final double knockbackImpulseMultiplier;
  final double rimFlashIntensityMultiplier;
  final double decalScaleMultiplier;
  final double sparkCountMultiplier;

  /// Hit stop clamping bounds (R3 spec: 30-50ms target freeze).
  final Duration minHitStopFreeze;
  final Duration maxHitStopFreeze;

  final double baseNormalShakeTrauma;
  final double baseCritShakeTrauma;

  const CombatJuiceConfig({
    this.enableCameraShake = true,
    this.enableHitStop = true,
    this.enableRimFlash = true,
    this.enableRibbonTrails = true,
    this.enableKnockback = true,
    this.enableGroundDecals = true,
    this.enableGpuSparks = true,
    this.cameraShakeMultiplier = 1.0,
    this.hitStopDurationMultiplier = 1.0,
    this.knockbackImpulseMultiplier = 1.0,
    this.rimFlashIntensityMultiplier = 1.0,
    this.decalScaleMultiplier = 1.0,
    this.sparkCountMultiplier = 1.0,
    this.minHitStopFreeze = const Duration(milliseconds: 30),
    this.maxHitStopFreeze = const Duration(milliseconds: 50),
    this.baseNormalShakeTrauma = 0.35,
    this.baseCritShakeTrauma = 0.78,
  });

  CombatJuiceConfig copyWith({
    bool? enableCameraShake,
    bool? enableHitStop,
    bool? enableRimFlash,
    bool? enableRibbonTrails,
    bool? enableKnockback,
    bool? enableGroundDecals,
    bool? enableGpuSparks,
    double? cameraShakeMultiplier,
    double? hitStopDurationMultiplier,
    double? knockbackImpulseMultiplier,
    double? rimFlashIntensityMultiplier,
    double? decalScaleMultiplier,
    double? sparkCountMultiplier,
    Duration? minHitStopFreeze,
    Duration? maxHitStopFreeze,
    double? baseNormalShakeTrauma,
    double? baseCritShakeTrauma,
  }) {
    return CombatJuiceConfig(
      enableCameraShake: enableCameraShake ?? this.enableCameraShake,
      enableHitStop: enableHitStop ?? this.enableHitStop,
      enableRimFlash: enableRimFlash ?? this.enableRimFlash,
      enableRibbonTrails: enableRibbonTrails ?? this.enableRibbonTrails,
      enableKnockback: enableKnockback ?? this.enableKnockback,
      enableGroundDecals: enableGroundDecals ?? this.enableGroundDecals,
      enableGpuSparks: enableGpuSparks ?? this.enableGpuSparks,
      cameraShakeMultiplier:
          cameraShakeMultiplier ?? this.cameraShakeMultiplier,
      hitStopDurationMultiplier:
          hitStopDurationMultiplier ?? this.hitStopDurationMultiplier,
      knockbackImpulseMultiplier:
          knockbackImpulseMultiplier ?? this.knockbackImpulseMultiplier,
      rimFlashIntensityMultiplier:
          rimFlashIntensityMultiplier ?? this.rimFlashIntensityMultiplier,
      decalScaleMultiplier: decalScaleMultiplier ?? this.decalScaleMultiplier,
      sparkCountMultiplier: sparkCountMultiplier ?? this.sparkCountMultiplier,
      minHitStopFreeze: minHitStopFreeze ?? this.minHitStopFreeze,
      maxHitStopFreeze: maxHitStopFreeze ?? this.maxHitStopFreeze,
      baseNormalShakeTrauma:
          baseNormalShakeTrauma ?? this.baseNormalShakeTrauma,
      baseCritShakeTrauma: baseCritShakeTrauma ?? this.baseCritShakeTrauma,
    );
  }
}

// =============================================================================
// Combat Juice Coordinator
// =============================================================================

/// Central Orchestrator wiring live combat events into sensory game feel systems (R3 & R5).
///
/// Connects:
/// 1. Directional camera shake (biased by hit angle and critical power)
/// 2. 30-50ms hit stop (time dilation pause via [HitStopManager])
/// 3. Enemy rim-light flash (fresnel silhouette highlight via [RimHitFlashController])
/// 4. Weapon ribbon trails (swing arc interpolation via [RibbonTrail])
/// 5. Knockback impulse & ragdoll blend (via [KnockbackRagdollController])
/// 6. Impact ground decals and GPU sparks (via [GroundDecalSystem] and [GpuParticleSystem])
///
/// Designed with strict graceful decoupling: any subsystem may be omitted, null,
/// or disabled without causing exceptions or instability.
class CombatJuiceCoordinator {
  DirectionalCameraShake? cameraShake;
  HitStopManager? hitStopManager;
  RimHitFlashController? rimFlashController;
  ribbon.RibbonTrail? ribbonTrail;
  KnockbackRagdollController? knockbackController;
  decals.GroundDecalSystem? decalSystem;
  GpuParticleSystem? particleSystem;

  CombatJuiceConfig config;

  final StreamController<CombatJuiceEvent> _eventStreamController =
      StreamController<CombatJuiceEvent>.broadcast();

  final List<void Function(CombatJuiceEvent event, CombatJuiceFeedbackResult result)>
      _listeners = [];

  StreamSubscription<CombatJuiceEvent>? _attachedStreamSub;
  bool _isDisposed = false;

  CombatJuiceCoordinator({
    this.cameraShake,
    this.hitStopManager,
    this.rimFlashController,
    this.ribbonTrail,
    this.knockbackController,
    this.decalSystem,
    this.particleSystem,
    CombatJuiceConfig? config,
  }) : config = config ?? const CombatJuiceConfig() {
    _eventStreamController.stream.listen((event) {
      handleEvent(event);
    });
  }

  /// Event stream for incoming combat triggers.
  Stream<CombatJuiceEvent> get eventStream => _eventStreamController.stream;

  /// Whether the coordinator is active and not disposed.
  bool get isDisposed => _isDisposed;

  /// Registers an external listener invoked after any combat juice event executes.
  void addEventListener(
      void Function(CombatJuiceEvent event, CombatJuiceFeedbackResult result)
          listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// Removes an active event listener.
  void removeEventListener(
      void Function(CombatJuiceEvent event, CombatJuiceFeedbackResult result)
          listener) {
    _listeners.remove(listener);
  }

  /// Attaches an external combat event stream for automatic processing.
  StreamSubscription<CombatJuiceEvent> attachEventStream(
      Stream<CombatJuiceEvent> stream) {
    _attachedStreamSub?.cancel();
    final sub = stream.listen((event) {
      handleEvent(event);
    });
    _attachedStreamSub = sub;
    return sub;
  }

  /// Dispatches an event directly through the internal stream controller.
  void emitEvent(CombatJuiceEvent event) {
    if (_isDisposed) return;
    _eventStreamController.add(event);
  }

  // ---------------------------------------------------------------------------
  // Core Event Dispatch & Parameter Mapping
  // ---------------------------------------------------------------------------

  /// Routes and executes all game feel feedback for any [CombatJuiceEvent].
  CombatJuiceFeedbackResult handleEvent(CombatJuiceEvent event) {
    if (_isDisposed) {
      return CombatJuiceFeedbackResult(
        eventId: event.eventId,
        processedAt: DateTime.now(),
      );
    }

    CombatJuiceFeedbackResult result;
    if (event is CombatAttackSwingEvent) {
      result = _processAttackSwing(event);
    } else if (event is CombatHitImpactEvent) {
      result = _processHitImpact(event);
    } else if (event is CombatBlockParryEvent) {
      result = _processBlockParry(event);
    } else if (event is CombatDeathEvent) {
      result = _processDeath(event);
    } else {
      result = _processGenericHit(event);
    }

    // Notify registered observers
    for (final listener in List.of(_listeners)) {
      try {
        listener(event, result);
      } catch (_) {
        // Observers should never crash the combat pipeline
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // 1. Attack Swing Handling (Weapon Ribbon Trails)
  // ---------------------------------------------------------------------------

  CombatJuiceFeedbackResult _processAttackSwing(CombatAttackSwingEvent event) {
    bool trailUpdated = false;
    int samplesAdded = 0;

    if (config.enableRibbonTrails && ribbonTrail != null) {
      final trail = ribbonTrail!;
      final subdivisions = math.max(2, event.arcSubdivisions);
      final halfArc = event.swingArcAngle * 0.5;
      final startAngle = event.hitAngle - halfArc;
      final endAngle = event.hitAngle + halfArc;

      final Color baseCol = event.customTrailColor ??
          (event.isHeavySwing
              ? const Color(0xFFFF3300)
              : const Color(0xFFFF9900));
      final Color glowCol = event.customGlowColor ??
          (event.isHeavySwing
              ? const Color(0xFFFFDD44)
              : const Color(0xFFFFAA33));

      trail.config = trail.config.copyWith(
        baseColor: baseCol,
        glowColor: glowCol,
        glowIntensity: event.isHeavySwing ? 3.8 : 2.5,
      );

      final double now = trail.currentTime;
      final double duration =
          (0.20 / math.max(0.1, event.swingSpeed)).clamp(0.05, 0.40);

      // Interpolate weapon swing arc samples along the blade trajectory
      for (int i = 0; i <= subdivisions; i++) {
        final double t = i / subdivisions;
        final double currentAngle = startAngle + (endAngle - startAngle) * t;
        final double timeOffset = now + t * duration;

        final Offset dir = Offset(math.cos(currentAngle), math.sin(currentAngle));
        final Offset hilt = event.weaponHiltPosition;
        final Offset tip = hilt + dir * event.weaponLength;
        final Offset base = hilt + dir * (event.weaponLength * 0.15);

        trail.addSample(
          tip: tip,
          base: base,
          timestamp: timeOffset,
          width: event.isHeavySwing ? 16.0 : 10.0,
          color: Color.lerp(baseCol, glowCol, t),
          opacity: 1.0,
        );
        samplesAdded++;
      }
      trailUpdated = true;
    }

    return CombatJuiceFeedbackResult(
      eventId: event.eventId,
      processedAt: DateTime.now(),
      ribbonTrailUpdated: trailUpdated,
      ribbonSamplesAdded: samplesAdded,
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Hit Impact Handling (Directional Shake, 30-50ms Hit Stop, Rim Flash, etc)
  // ---------------------------------------------------------------------------

  CombatJuiceFeedbackResult _processHitImpact(CombatHitImpactEvent event) {
    // 1. Directional Camera Shake
    bool shakeTriggered = false;
    double appliedTrauma = 0.0;
    Offset shakeDir = event.hitDirection2D;

    if (config.enableCameraShake && cameraShake != null) {
      final baseTrauma = event.isCritical
          ? config.baseCritShakeTrauma
          : config.baseNormalShakeTrauma;
      final forceFactor = (event.hitForce / 5.0).clamp(0.5, 2.0);
      final critFactor =
          event.isCritical ? (event.criticalMultiplier / 2.0) : 1.0;

      appliedTrauma = (baseTrauma *
              forceFactor *
              critFactor *
              config.cameraShakeMultiplier)
          .clamp(0.0, 1.0);

      final double directionalWeight = event.isCritical ? 0.90 : 0.70;

      if (event.isCritical) {
        cameraShake!.triggerPreset(
          CameraShakePreset.heavyCrit,
          hitDirection: shakeDir,
          directionalWeight: directionalWeight,
        );
      } else {
        cameraShake!.addTrauma(
          appliedTrauma,
          hitDirection: shakeDir,
          directionalWeight: directionalWeight,
        );
      }
      shakeTriggered = true;
    }

    // 2. 30-50ms Hit Stop (Time Dilation Freeze)
    bool hitStopTriggered = false;
    Duration freezeDuration = Duration.zero;
    Duration easeOutDuration = Duration.zero;

    if (config.enableHitStop && hitStopManager != null) {
      // Map hit intensity to 30ms - 50ms freeze range
      final int minMs = config.minHitStopFreeze.inMilliseconds; // 30ms
      final int maxMs = config.maxHitStopFreeze.inMilliseconds; // 50ms

      final double normalizedForce = (event.hitForce / 10.0).clamp(0.0, 1.0);
      final int targetFreezeMs = event.isCritical
          ? maxMs
          : (minMs + (maxMs - minMs) * normalizedForce).round();

      final int scaledFreezeMs =
          (targetFreezeMs * config.hitStopDurationMultiplier)
              .round()
              .clamp(minMs, maxMs);

      freezeDuration = Duration(milliseconds: scaledFreezeMs);
      easeOutDuration =
          Duration(milliseconds: (scaledFreezeMs * 0.35).round().clamp(10, 20));

      hitStopManager!.trigger(
        HitStopRequest(
          id: 'combat_${event.eventId}',
          freezeDuration: freezeDuration,
          easeOutDuration: easeOutDuration,
          targetTimeScale: 0.0,
          channels: TimeDilationChannel.combatPair,
          resumptionCurve: event.isCritical
              ? HitStopResumptionCurve.easeOutCubic
              : HitStopResumptionCurve.smoothStep,
          conflictPolicy: event.isCritical
              ? HitStopConflictPolicy.override
              : HitStopConflictPolicy.extend,
          priority: event.isCritical ? 4 : 2,
        ),
      );
      hitStopTriggered = true;
    }

    // 3. Enemy Rim-Light Flash (Fresnel silhouette highlight)
    bool rimFlashTriggered = false;
    ui.Color flashTint = event.damageType.rimFlashTint;
    double flashIntensity = 1.0;

    if (config.enableRimFlash && rimFlashController != null) {
      if (event.isCritical) {
        flashTint = event.damageType == HitDamageType.physical
            ? RimFlashTint.bloodRed
            : event.damageType.rimFlashTint;
        flashIntensity = 2.2 * config.rimFlashIntensityMultiplier;
      } else {
        flashIntensity = 1.0 * config.rimFlashIntensityMultiplier;
      }

      rimFlashController!.triggerHit(
        tint: flashTint,
        intensityMultiplier: flashIntensity,
        duration: const Duration(milliseconds: 100),
        hitStopDuration: freezeDuration,
      );
      rimFlashTriggered = true;
    }

    // 4. Knockback Impulse & Ragdoll Blend
    bool knockbackApplied = false;
    KnockbackVector3 impulseVec = KnockbackVector3.zero;
    double ragdollWeight = 0.0;

    if (config.enableKnockback && knockbackController != null) {
      final double effectiveForce =
          event.effectiveForce * config.knockbackImpulseMultiplier;

      if (event.customImpulseVector != null) {
        impulseVec = event.customImpulseVector!;
      } else {
        final double hForce =
            effectiveForce * (1.0 - event.verticalLaunchRatio);
        final double vForce = effectiveForce * event.verticalLaunchRatio;

        impulseVec = KnockbackVector3(
          math.cos(event.hitAngle) * hForce,
          vForce,
          math.sin(event.hitAngle) * hForce,
        );
      }

      ragdollWeight = event.isCritical
          ? 1.0
          : (effectiveForce / 10.0).clamp(0.25, 0.85);

      knockbackController!.applyImpulse(
        KnockbackImpulse(
          impulse: impulseVec,
          verticalLaunchImpulse: impulseVec.y,
          isCriticalHit: event.isCritical,
          customRagdollPeakWeight: ragdollWeight,
          sourceAttackerId: event.attackerId,
        ),
      );
      knockbackApplied = true;
    }

    // 5. Impact Ground Decals
    bool decalSpawned = false;
    decals.DecalType? decalType;

    if (config.enableGroundDecals && decalSystem != null) {
      final double scale = (event.isCritical ? 1.5 : 1.0) *
          config.decalScaleMultiplier;

      if (event.damageType == HitDamageType.physical && !event.isCritical) {
        // Directional slash gouge
        decalType = decals.DecalType.slashGouge;
        decalSystem!.spawnSlashGouge(
          position: event.worldImpactPoint,
          strikeDirection: decals.Vector3D(
            math.cos(event.hitAngle),
            0.0,
            math.sin(event.hitAngle),
          ),
          length: 2.5 * scale,
          width: 0.6 * scale,
        );
      } else if (event.isCritical) {
        // Critical smash creates blood splatter or cracked earth
        decalType = decals.DecalType.bloodSplatter;
        decalSystem!.spawnBloodSplatter(
          position: event.worldImpactPoint,
          impactVelocity: decals.Vector3D(
            math.cos(event.hitAngle) * 5.0,
            1.0,
            math.sin(event.hitAngle) * 5.0,
          ),
          radius: 2.0 * scale,
        );
      } else {
        decalType = event.damageType.primaryDecalType;
        decalSystem!.spawnScorchMark(
          position: event.worldImpactPoint,
          radius: 1.8 * scale,
        );
      }
      decalSpawned = true;
    }

    // 6. GPU Sparks & Flash Particles
    bool sparksEmitted = false;
    int sparkCount = 0;

    if (config.enableGpuSparks && particleSystem != null) {
      final baseCount = event.isCritical ? 45 : 20;
      sparkCount = (baseCount * config.sparkCountMultiplier).round();

      // Emit directional spark streak burst (Layer 0)
      particleSystem!.emitBurst(
        layerIndex: 0,
        count: sparkCount,
        origin: event.screenImpactPoint,
        directionAngle: event.hitAngle,
        speedMultiplier: event.isCritical ? 1.4 : 1.0,
      );

      // Emit incandescent impact flash (Layer 1 if present)
      if (particleSystem!.layers.length > 1) {
        particleSystem!.emitBurst(
          layerIndex: 1,
          count: event.isCritical ? 3 : 1,
          origin: event.screenImpactPoint,
        );
      }
      sparksEmitted = true;
    }

    return CombatJuiceFeedbackResult(
      eventId: event.eventId,
      processedAt: DateTime.now(),
      cameraShakeTriggered: shakeTriggered,
      appliedTrauma: appliedTrauma,
      cameraShakeDirection: shakeDir,
      hitStopTriggered: hitStopTriggered,
      hitStopFreezeDuration: freezeDuration,
      hitStopEaseOutDuration: easeOutDuration,
      rimFlashTriggered: rimFlashTriggered,
      rimFlashTint: flashTint,
      rimFlashIntensity: flashIntensity,
      knockbackApplied: knockbackApplied,
      knockbackImpulse: impulseVec,
      targetRagdollWeight: ragdollWeight,
      groundDecalSpawned: decalSpawned,
      groundDecalType: decalType,
      gpuSparksEmitted: sparksEmitted,
      sparkCount: sparkCount,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Block / Parry Handling (Micro vibration, glance stop, gold sparks)
  // ---------------------------------------------------------------------------

  CombatJuiceFeedbackResult _processBlockParry(CombatBlockParryEvent event) {
    bool shakeTriggered = false;
    double appliedTrauma = 0.0;

    if (config.enableCameraShake && cameraShake != null) {
      cameraShake!.triggerPreset(
        CameraShakePreset.microVibration,
        hitDirection: event.hitDirection2D,
      );
      appliedTrauma = CameraShakePreset.microVibration.trauma;
      shakeTriggered = true;
    }

    bool hitStopTriggered = false;
    Duration freezeDuration = Duration.zero;

    if (config.enableHitStop && hitStopManager != null) {
      if (event.isPerfectParry) {
        // Perfect parry delivers crisp 45ms impact freeze
        hitStopManager!.triggerMedium();
        freezeDuration = const Duration(milliseconds: 35);
      } else {
        // Standard glance deflection
        hitStopManager!.triggerPreset(HitStopPreset.glance);
        freezeDuration = const Duration(milliseconds: 15);
      }
      hitStopTriggered = true;
    }

    bool rimFlashTriggered = false;
    ui.Color flashTint = RimFlashTint.lightningGold;

    if (config.enableRimFlash && rimFlashController != null) {
      rimFlashController!.triggerHit(
        tint: flashTint,
        intensityMultiplier: event.isPerfectParry ? 1.8 : 1.0,
        duration: const Duration(milliseconds: 70),
      );
      rimFlashTriggered = true;
    }

    bool sparksEmitted = false;
    int sparkCount = 0;

    if (config.enableGpuSparks && particleSystem != null) {
      sparkCount = event.isPerfectParry ? 35 : 15;
      particleSystem!.emitBurst(
        layerIndex: 0,
        count: sparkCount,
        origin: event.sparkOrigin,
        directionAngle: event.hitAngle + math.pi, // Reflect backwards
      );
      sparksEmitted = true;
    }

    return CombatJuiceFeedbackResult(
      eventId: event.eventId,
      processedAt: DateTime.now(),
      cameraShakeTriggered: shakeTriggered,
      appliedTrauma: appliedTrauma,
      cameraShakeDirection: event.hitDirection2D,
      hitStopTriggered: hitStopTriggered,
      hitStopFreezeDuration: freezeDuration,
      rimFlashTriggered: rimFlashTriggered,
      rimFlashTint: flashTint,
      gpuSparksEmitted: sparksEmitted,
      sparkCount: sparkCount,
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Death / Lethal Blow Handling
  // ---------------------------------------------------------------------------

  CombatJuiceFeedbackResult _processDeath(CombatDeathEvent event) {
    bool shakeTriggered = false;
    double appliedTrauma = 0.0;

    if (config.enableCameraShake && cameraShake != null) {
      cameraShake!.triggerPreset(
        CameraShakePreset.explosiveShock,
        hitDirection: event.hitDirection2D,
      );
      appliedTrauma = CameraShakePreset.explosiveShock.trauma;
      shakeTriggered = true;
    }

    bool hitStopTriggered = false;
    Duration freezeDuration = const Duration(milliseconds: 50);

    if (config.enableHitStop && hitStopManager != null) {
      hitStopManager!.triggerHeavy();
      hitStopTriggered = true;
    }

    bool knockbackApplied = false;
    KnockbackVector3 deathImpulse = KnockbackVector3.zero;

    if (config.enableKnockback && knockbackController != null) {
      deathImpulse = KnockbackVector3(
        math.cos(event.hitAngle) * event.deathImpulseForce,
        event.deathImpulseForce * 0.45,
        math.sin(event.hitAngle) * event.deathImpulseForce,
      );

      knockbackController!.applyImpulse(
        KnockbackImpulse(
          impulse: deathImpulse,
          verticalLaunchImpulse: deathImpulse.y,
          isCriticalHit: true,
          customRagdollPeakWeight: 1.0,
          sourceAttackerId: event.attackerId,
        ),
      );
      knockbackApplied = true;
    }

    bool decalSpawned = false;
    decals.DecalType? decalType;

    if (config.enableGroundDecals && decalSystem != null && event.spawnBloodPool) {
      decalType = decals.DecalType.bloodSplatter;
      decalSystem!.spawnBloodSplatter(
        position: event.worldImpactPoint,
        radius: event.isOverkill ? 3.5 : 2.2,
      );
      decalSpawned = true;
    }

    return CombatJuiceFeedbackResult(
      eventId: event.eventId,
      processedAt: DateTime.now(),
      cameraShakeTriggered: shakeTriggered,
      appliedTrauma: appliedTrauma,
      cameraShakeDirection: event.hitDirection2D,
      hitStopTriggered: hitStopTriggered,
      hitStopFreezeDuration: freezeDuration,
      knockbackApplied: knockbackApplied,
      knockbackImpulse: deathImpulse,
      targetRagdollWeight: 1.0,
      groundDecalSpawned: decalSpawned,
      groundDecalType: decalType,
    );
  }

  // ---------------------------------------------------------------------------
  // Generic Fallback
  // ---------------------------------------------------------------------------

  CombatJuiceFeedbackResult _processGenericHit(CombatJuiceEvent event) {
    return _processHitImpact(
      CombatHitImpactEvent(
        eventId: event.eventId,
        timestamp: event.timestamp,
        attackerId: event.attackerId,
        targetId: event.targetId,
        hitAngle: event.hitAngle,
        screenImpactPoint: event.screenImpactPoint,
        worldImpactPoint: event.worldImpactPoint,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Convenience Trigger API
  // ---------------------------------------------------------------------------

  /// Convenience trigger for an attack swing.
  CombatJuiceFeedbackResult onAttackSwing({
    required String attackerId,
    double hitAngle = 0.0,
    double weaponLength = 70.0,
    Offset weaponHiltPosition = Offset.zero,
    bool isHeavySwing = false,
    Color? customTrailColor,
    Color? customGlowColor,
  }) {
    final event = CombatAttackSwingEvent(
      attackerId: attackerId,
      hitAngle: hitAngle,
      weaponLength: weaponLength,
      weaponHiltPosition: weaponHiltPosition,
      isHeavySwing: isHeavySwing,
      customTrailColor: customTrailColor,
      customGlowColor: customGlowColor,
    );
    return handleEvent(event);
  }

  /// Convenience trigger for a normal or critical hit impact.
  CombatJuiceFeedbackResult onHitImpact({
    required String attackerId,
    String? targetId,
    double damage = 10.0,
    double hitForce = 5.0,
    double hitAngle = 0.0,
    bool isCritical = false,
    double criticalMultiplier = 2.0,
    HitDamageType damageType = HitDamageType.physical,
    Offset screenImpactPoint = Offset.zero,
    decals.Vector3D worldImpactPoint = decals.Vector3D.zero,
  }) {
    final event = CombatHitImpactEvent(
      attackerId: attackerId,
      targetId: targetId,
      damage: damage,
      hitForce: hitForce,
      hitAngle: hitAngle,
      isCritical: isCritical,
      criticalMultiplier: criticalMultiplier,
      damageType: damageType,
      screenImpactPoint: screenImpactPoint,
      worldImpactPoint: worldImpactPoint,
    );
    return handleEvent(event);
  }

  /// Convenience trigger for a critical finisher strike.
  CombatJuiceFeedbackResult onCriticalHit({
    required String attackerId,
    String? targetId,
    double damage = 35.0,
    double hitForce = 9.0,
    double hitAngle = 0.0,
    double criticalMultiplier = 2.5,
    HitDamageType damageType = HitDamageType.physical,
    Offset screenImpactPoint = Offset.zero,
    decals.Vector3D worldImpactPoint = decals.Vector3D.zero,
  }) {
    return onHitImpact(
      attackerId: attackerId,
      targetId: targetId,
      damage: damage,
      hitForce: hitForce,
      hitAngle: hitAngle,
      isCritical: true,
      criticalMultiplier: criticalMultiplier,
      damageType: damageType,
      screenImpactPoint: screenImpactPoint,
      worldImpactPoint: worldImpactPoint,
    );
  }

  /// Convenience trigger for a weapon parry or shield block.
  CombatJuiceFeedbackResult onBlockOrParry({
    required String attackerId,
    String? targetId,
    bool isPerfectParry = false,
    double deflectionForce = 4.0,
    double hitAngle = 0.0,
    Offset sparkOrigin = Offset.zero,
  }) {
    final event = CombatBlockParryEvent(
      attackerId: attackerId,
      targetId: targetId,
      isPerfectParry: isPerfectParry,
      deflectionForce: deflectionForce,
      hitAngle: hitAngle,
      screenImpactPoint: sparkOrigin,
      sparkOrigin: sparkOrigin,
    );
    return handleEvent(event);
  }

  /// Convenience trigger for a lethal blow / entity death.
  CombatJuiceFeedbackResult onDeath({
    required String attackerId,
    String? targetId,
    double fatalDamage = 50.0,
    double hitAngle = 0.0,
    bool isOverkill = false,
    decals.Vector3D worldImpactPoint = decals.Vector3D.zero,
  }) {
    final event = CombatDeathEvent(
      attackerId: attackerId,
      targetId: targetId,
      fatalDamage: fatalDamage,
      hitAngle: hitAngle,
      isOverkill: isOverkill,
      worldImpactPoint: worldImpactPoint,
    );
    return handleEvent(event);
  }

  // ---------------------------------------------------------------------------
  // Frame Update Loop & Lifecycle
  // ---------------------------------------------------------------------------

  /// Advances all connected subsystems by [dt] seconds simultaneously.
  void update(double dt) {
    if (dt <= 0.0 || _isDisposed) return;

    cameraShake?.update(dt);
    hitStopManager?.update(dt);
    rimFlashController?.update(dt);
    ribbonTrail?.update(dt);
    knockbackController?.update(dt);
    decalSystem?.update(dt);
    particleSystem?.update(dt);
  }

  /// Disposes coordinator, cancels streams, and releases event subscriptions.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _attachedStreamSub?.cancel();
    _attachedStreamSub = null;
    _listeners.clear();
    _eventStreamController.close();
  }
}
