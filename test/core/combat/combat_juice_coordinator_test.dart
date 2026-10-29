import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/combat/combat_juice_coordinator.dart';
import 'package:gkk_flutter/core/vfx/directional_camera_shake.dart';
import 'package:gkk_flutter/core/vfx/gpu_particle_system.dart';
import 'package:gkk_flutter/core/vfx/ground_decal_system.dart' as decals;
import 'package:gkk_flutter/core/vfx/hit_stop_manager.dart';
import 'package:gkk_flutter/core/vfx/knockback_ragdoll_controller.dart';
import 'package:gkk_flutter/core/vfx/ribbon_trail_renderer.dart' as ribbon;
import 'package:gkk_flutter/core/vfx/rim_hit_flash_effect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CombatJuiceCoordinator — Subsystem Wiring & Game Feel (R3 & R5)', () {
    late DirectionalCameraShake cameraShake;
    late HitStopManager hitStopManager;
    late RimHitFlashController rimFlashController;
    late ribbon.RibbonTrail ribbonTrail;
    late KnockbackRagdollController knockbackController;
    late decals.GroundDecalSystem decalSystem;
    late GpuParticleSystem particleSystem;
    late CombatJuiceCoordinator coordinator;

    setUp(() {
      cameraShake = DirectionalCameraShake();
      hitStopManager = HitStopManager();
      rimFlashController = RimHitFlashController();
      ribbonTrail = ribbon.RibbonTrail();
      knockbackController = KnockbackRagdollController();
      decalSystem = decals.GroundDecalSystem(maxDecals: 32);
      particleSystem = GpuParticlePresets.weaponImpact();

      coordinator = CombatJuiceCoordinator(
        cameraShake: cameraShake,
        hitStopManager: hitStopManager,
        rimFlashController: rimFlashController,
        ribbonTrail: ribbonTrail,
        knockbackController: knockbackController,
        decalSystem: decalSystem,
        particleSystem: particleSystem,
      );
    });

    tearDown(() {
      coordinator.dispose();
      hitStopManager.dispose();
      decalSystem.clearAll();
    });

    // =========================================================================
    // 1. Directional Camera Shake
    // =========================================================================
    group('1. Directional Camera Shake', () {
      test('normal hit biases camera shake along hit angle', () {
        const double angle = math.pi * 0.25; // 45 degrees
        final result = coordinator.onHitImpact(
          attackerId: 'player_1',
          hitForce: 6.0,
          hitAngle: angle,
        );

        expect(result.cameraShakeTriggered, isTrue);
        expect(cameraShake.isActive, isTrue);
        expect(cameraShake.trauma, greaterThan(0.0));

        // Direction vector must match cos/sin of angle
        expect(result.cameraShakeDirection.dx, closeTo(math.cos(angle), 1e-4));
        expect(result.cameraShakeDirection.dy, closeTo(math.sin(angle), 1e-4));
      });

      test('critical hit applies high trauma and activates heavyCrit preset', () {
        final result = coordinator.onCriticalHit(
          attackerId: 'player_1',
          hitForce: 9.0,
          hitAngle: math.pi * 0.5,
          criticalMultiplier: 2.5,
        );

        expect(result.cameraShakeTriggered, isTrue);
        expect(cameraShake.trauma, closeTo(CameraShakePreset.heavyCrit.trauma, 0.05));
        expect(cameraShake.config.directionalBiasWeight, equals(0.85));
      });

      test('camera shake config toggle disables shake when set to false', () {
        coordinator.config = coordinator.config.copyWith(enableCameraShake: false);

        final result = coordinator.onHitImpact(
          attackerId: 'player_1',
          hitForce: 7.0,
        );

        expect(result.cameraShakeTriggered, isFalse);
        expect(cameraShake.isActive, isFalse);
        expect(cameraShake.trauma, equals(0.0));
      });
    });

    // =========================================================================
    // 2. 30-50ms Hit Stop (Time Dilation Freeze)
    // =========================================================================
    group('2. 30-50ms Hit Stop (Time Dilation Freeze)', () {
      test('normal hit triggers hit-stop freeze strictly within 30-50ms', () {
        final result = coordinator.onHitImpact(
          attackerId: 'player_1',
          hitForce: 5.0, // medium force
        );

        expect(result.hitStopTriggered, isTrue);
        expect(result.hitStopFreezeDuration.inMilliseconds, inInclusiveRange(30, 50));
        expect(hitStopManager.activeCount, equals(1));
        expect(hitStopManager.isAnyFrozen, isTrue);

        // Attacker and target channels must be frozen to 0.0
        expect(hitStopManager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));
        expect(hitStopManager.getTimeScale(TimeDilationChannel.target), equals(0.0));
      });

      test('critical hit triggers 50ms peak freeze with ease-out resumption', () {
        final result = coordinator.onCriticalHit(
          attackerId: 'player_1',
          hitForce: 10.0,
        );

        expect(result.hitStopTriggered, isTrue);
        expect(result.hitStopFreezeDuration, equals(const Duration(milliseconds: 50)));

        // Step 25ms forward (still in freeze phase: 25ms < 50ms)
        hitStopManager.update(0.025);
        expect(hitStopManager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));

        // Step 25ms forward (total 50ms: end of freeze phase, entering ease-out)
        hitStopManager.update(0.025);
        expect(hitStopManager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));

        // Step 10ms forward (in ease-out ramp)
        hitStopManager.update(0.010);
        final scale = hitStopManager.getTimeScale(TimeDilationChannel.attacker);
        expect(scale, greaterThan(0.0));
        expect(scale, lessThanOrEqualTo(1.0));

        // Complete remaining ease-out
        hitStopManager.update(0.020);
        expect(hitStopManager.getTimeScale(TimeDilationChannel.attacker), equals(1.0));
        expect(hitStopManager.activeCount, equals(0));
      });

      test('hit stop disabled via config bypasses time dilation', () {
        coordinator.config = coordinator.config.copyWith(enableHitStop: false);

        final result = coordinator.onHitImpact(
          attackerId: 'player_1',
          hitForce: 8.0,
        );

        expect(result.hitStopTriggered, isFalse);
        expect(hitStopManager.activeCount, equals(0));
        expect(hitStopManager.isAnyFrozen, isFalse);
      });
    });

    // =========================================================================
    // 3. Enemy Rim-Light Flash (Fresnel silhouette highlight)
    // =========================================================================
    group('3. Enemy Rim-Light Flash', () {
      test('normal physical hit triggers white rim flash with peak holding during hit-stop', () {
        final result = coordinator.onHitImpact(
          attackerId: 'player_1',
          damageType: HitDamageType.physical,
          isCritical: false,
        );

        expect(result.rimFlashTriggered, isTrue);
        expect(result.rimFlashTint, equals(RimFlashTint.white));
        expect(rimFlashController.isFlashing, isTrue);
        expect(rimFlashController.currentIntensity, equals(1.0));
        expect(rimFlashController.config.hitStopDuration, equals(result.hitStopFreezeDuration));
      });

      test('critical hit triggers blood-red flash with boosted intensity', () {
        final result = coordinator.onCriticalHit(
          attackerId: 'player_1',
          damageType: HitDamageType.physical,
        );

        expect(result.rimFlashTriggered, isTrue);
        expect(result.rimFlashTint, equals(RimFlashTint.bloodRed));
        expect(result.rimFlashIntensity, greaterThanOrEqualTo(2.0));
        expect(rimFlashController.currentIntensity, greaterThanOrEqualTo(2.0));
      });

      test('elemental damage types map to respective chromatic tints', () {
        // Fire
        var res = coordinator.onHitImpact(
          attackerId: 'p1',
          damageType: HitDamageType.fire,
        );
        expect(res.rimFlashTint, equals(const Color(0xFFFF5500)));

        // Frost
        res = coordinator.onHitImpact(
          attackerId: 'p1',
          damageType: HitDamageType.frost,
        );
        expect(res.rimFlashTint, equals(RimFlashTint.magicalCyan));

        // Lightning
        res = coordinator.onHitImpact(
          attackerId: 'p1',
          damageType: HitDamageType.lightning,
        );
        expect(res.rimFlashTint, equals(RimFlashTint.lightningGold));

        // Poison
        res = coordinator.onHitImpact(
          attackerId: 'p1',
          damageType: HitDamageType.poison,
        );
        expect(res.rimFlashTint, equals(RimFlashTint.poisonGreen));

        // Void
        res = coordinator.onHitImpact(
          attackerId: 'p1',
          damageType: HitDamageType.voidEnergy,
        );
        expect(res.rimFlashTint, equals(RimFlashTint.voidPurple));
      });
    });

    // =========================================================================
    // 4. Weapon Ribbon Trails (Swing Arc Interpolation)
    // =========================================================================
    group('4. Weapon Ribbon Trails', () {
      test('attack swing interpolates arc and populates ribbon trail samples', () {
        final result = coordinator.onAttackSwing(
          attackerId: 'player_1',
          hitAngle: math.pi * 0.25,
          weaponLength: 80.0,
          weaponHiltPosition: const Offset(100.0, 100.0),
          isHeavySwing: false,
        );

        expect(result.ribbonTrailUpdated, isTrue);
        expect(result.ribbonSamplesAdded, greaterThanOrEqualTo(8));
        expect(ribbonTrail.isNotEmpty, isTrue);
        expect(ribbonTrail.sampleCount, equals(result.ribbonSamplesAdded));

        // Check first sample position is around the swing arc at radius weaponLength
        final firstSample = ribbonTrail.samples.first;
        final distanceFromHilt =
            (firstSample.tip2D - const Offset(100.0, 100.0)).distance;
        expect(distanceFromHilt, closeTo(80.0, 1e-4));
      });

      test('heavy swing boosts trail glow intensity and widens ribbon', () {
        coordinator.onAttackSwing(
          attackerId: 'player_1',
          hitAngle: 0.0,
          isHeavySwing: true,
        );

        expect(ribbonTrail.config.glowIntensity, greaterThanOrEqualTo(3.5));
        expect(ribbonTrail.config.baseColor, equals(const Color(0xFFFF3300)));
      });

      test('ribbon trails disabled via config skips sample generation', () {
        coordinator.config = coordinator.config.copyWith(enableRibbonTrails: false);

        final result = coordinator.onAttackSwing(
          attackerId: 'player_1',
          hitAngle: 0.0,
        );

        expect(result.ribbonTrailUpdated, isFalse);
        expect(result.ribbonSamplesAdded, equals(0));
        expect(ribbonTrail.isEmpty, isTrue);
      });
    });

    // =========================================================================
    // 5. Knockback Impulse & Ragdoll Blend
    // =========================================================================
    group('5. Knockback Impulse & Ragdoll Blend', () {
      test('hit impact calculates and applies directional impulse vector', () {
        const double angle = 0.0; // Straight along positive X
        final result = coordinator.onHitImpact(
          attackerId: 'player_1',
          hitForce: 8.0,
          hitAngle: angle,
          isCritical: false,
        );

        expect(result.knockbackApplied, isTrue);
        expect(result.knockbackImpulse.x, closeTo(8.0 * 0.8, 0.01)); // (1 - verticalRatio 0.2)
        expect(result.knockbackImpulse.y, closeTo(8.0 * 0.2, 0.01));
        expect(result.knockbackImpulse.z, closeTo(0.0, 0.01));

        expect(knockbackController.isActive, isTrue);
        expect(knockbackController.velocity.x, greaterThan(0.0));
      });

      test('critical hit applies airborne launch and blends to full ragdoll weight 1.0', () {
        final result = coordinator.onCriticalHit(
          attackerId: 'player_1',
          hitForce: 10.0,
          criticalMultiplier: 2.0,
        );

        expect(result.knockbackApplied, isTrue);
        expect(result.targetRagdollWeight, equals(1.0));
        expect(knockbackController.isAirborne, isTrue);
        expect(knockbackController.phase, equals(RagdollPhase.blendingIn));
      });

      test('knockback controller disabled via config skips impulse', () {
        coordinator.config = coordinator.config.copyWith(enableKnockback: false);

        final result = coordinator.onHitImpact(
          attackerId: 'player_1',
          hitForce: 10.0,
        );

        expect(result.knockbackApplied, isFalse);
        expect(knockbackController.isActive, isFalse);
      });
    });

    // =========================================================================
    // 6. Impact Ground Decals & GPU Sparks
    // =========================================================================
    group('6. Impact Ground Decals & GPU Sparks', () {
      test('normal physical attack spawns directional slash gouge decal', () {
        final result = coordinator.onHitImpact(
          attackerId: 'player_1',
          damageType: HitDamageType.physical,
          isCritical: false,
          worldImpactPoint: const decals.Vector3D(10.0, 0.0, 5.0),
        );

        expect(result.groundDecalSpawned, isTrue);
        expect(result.groundDecalType, equals(decals.DecalType.slashGouge));
        expect(decalSystem.activeDecalCount, equals(1));
      });

      test('critical strike spawns blood splatter decal', () {
        final result = coordinator.onCriticalHit(
          attackerId: 'player_1',
          worldImpactPoint: const decals.Vector3D(5.0, 0.0, 5.0),
        );

        expect(result.groundDecalSpawned, isTrue);
        expect(result.groundDecalType, equals(decals.DecalType.bloodSplatter));
        expect(decalSystem.activeDecalCount, equals(1));
      });

      test('GPU spark particles are emitted at impact point with hit angle alignment', () {
        final result = coordinator.onHitImpact(
          attackerId: 'player_1',
          hitAngle: math.pi * 0.5,
          screenImpactPoint: const Offset(200.0, 300.0),
          isCritical: false,
        );

        expect(result.gpuSparksEmitted, isTrue);
        expect(result.sparkCount, equals(20));
        expect(particleSystem.activeParticleCount, greaterThanOrEqualTo(20));
      });

      test('critical hit increases spark count and speed', () {
        final result = coordinator.onCriticalHit(
          attackerId: 'player_1',
          screenImpactPoint: const Offset(150.0, 150.0),
        );

        expect(result.gpuSparksEmitted, isTrue);
        expect(result.sparkCount, equals(45));
        expect(particleSystem.activeParticleCount, greaterThanOrEqualTo(45));
      });
    });

    // =========================================================================
    // 7. Parry & Block Events
    // =========================================================================
    group('7. Parry & Block Events', () {
      test('block triggers micro-vibration camera shake, glance stop, and gold sparks', () {
        final result = coordinator.onBlockOrParry(
          attackerId: 'enemy_boss',
          isPerfectParry: false,
          sparkOrigin: const Offset(120.0, 120.0),
        );

        expect(result.cameraShakeTriggered, isTrue);
        expect(result.appliedTrauma, equals(CameraShakePreset.microVibration.trauma));
        expect(result.hitStopTriggered, isTrue);
        expect(result.rimFlashTint, equals(RimFlashTint.lightningGold));
        expect(result.gpuSparksEmitted, isTrue);
      });

      test('perfect parry delivers 35ms impact freeze and larger spark burst', () {
        final result = coordinator.onBlockOrParry(
          attackerId: 'enemy_boss',
          isPerfectParry: true,
        );

        expect(result.hitStopTriggered, isTrue);
        expect(result.hitStopFreezeDuration, equals(const Duration(milliseconds: 35)));
        expect(result.sparkCount, equals(35));
      });
    });

    // =========================================================================
    // 8. Death Events
    // =========================================================================
    group('8. Death Events', () {
      test('death event triggers explosive shock shake, heavy freeze, full ragdoll, and blood pool', () {
        final result = coordinator.onDeath(
          attackerId: 'player_1',
          fatalDamage: 120.0,
          isOverkill: true,
          worldImpactPoint: const decals.Vector3D(0.0, 0.0, 0.0),
        );

        expect(result.cameraShakeTriggered, isTrue);
        expect(result.appliedTrauma, equals(CameraShakePreset.explosiveShock.trauma));
        expect(result.hitStopTriggered, isTrue);
        expect(result.knockbackApplied, isTrue);
        expect(result.targetRagdollWeight, equals(1.0));
        expect(result.groundDecalSpawned, isTrue);
        expect(result.groundDecalType, equals(decals.DecalType.bloodSplatter));
      });
    });

    // =========================================================================
    // 9. Graceful Decoupling & Null Safety
    // =========================================================================
    group('9. Graceful Decoupling & Null Safety', () {
      test('coordinator operates without exceptions when ALL subsystems are null', () {
        final decoupled = CombatJuiceCoordinator();

        expect(
          () => decoupled.onAttackSwing(attackerId: 'p1'),
          returnsNormally,
        );
        expect(
          () => decoupled.onHitImpact(attackerId: 'p1'),
          returnsNormally,
        );
        expect(
          () => decoupled.onCriticalHit(attackerId: 'p1'),
          returnsNormally,
        );
        expect(
          () => decoupled.onBlockOrParry(attackerId: 'p1'),
          returnsNormally,
        );
        expect(
          () => decoupled.onDeath(attackerId: 'p1'),
          returnsNormally,
        );
        expect(
          () => decoupled.update(0.016),
          returnsNormally,
        );

        decoupled.dispose();
      });

      test('coordinator operates when only a subset of systems is attached', () {
        final partialCoordinator = CombatJuiceCoordinator(
          cameraShake: cameraShake,
          hitStopManager: hitStopManager,
        );

        final result = partialCoordinator.onHitImpact(
          attackerId: 'p1',
          hitForce: 6.0,
        );

        expect(result.cameraShakeTriggered, isTrue);
        expect(result.hitStopTriggered, isTrue);
        expect(result.rimFlashTriggered, isFalse);
        expect(result.knockbackApplied, isFalse);
        expect(result.groundDecalSpawned, isFalse);
        expect(result.gpuSparksEmitted, isFalse);

        partialCoordinator.dispose();
      });
    });

    // =========================================================================
    // 10. Event Listener & Stream Pipeline
    // =========================================================================
    group('10. Event Listener & Stream Pipeline', () {
      test('addEventListener receives event and feedback result upon dispatch', () {
        CombatJuiceEvent? observedEvent;
        CombatJuiceFeedbackResult? observedResult;

        coordinator.addEventListener((event, result) {
          observedEvent = event;
          observedResult = result;
        });

        coordinator.onHitImpact(
          attackerId: 'hero',
          damage: 42.0,
          hitForce: 7.0,
        );

        expect(observedEvent, isNotNull);
        expect(observedEvent!.attackerId, equals('hero'));
        expect(observedResult, isNotNull);
        expect(observedResult!.cameraShakeTriggered, isTrue);
      });

      test('attachEventStream routes stream events automatically', () async {
        final streamController = StreamController<CombatJuiceEvent>();
        coordinator.attachEventStream(streamController.stream);

        int eventsHandled = 0;
        coordinator.addEventListener((event, result) => eventsHandled++);

        streamController.add(CombatHitImpactEvent(attackerId: 'stream_p1'));
        streamController.add(CombatAttackSwingEvent(attackerId: 'stream_p2'));

        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(eventsHandled, equals(2));
        await streamController.close();
      });

      test('update advances all connected subsystems simultaneously', () {
        // Prime subsystems
        coordinator.onHitImpact(attackerId: 'p1', hitForce: 5.0);
        coordinator.onAttackSwing(attackerId: 'p1');

        expect(cameraShake.trauma, greaterThan(0.0));
        expect(ribbonTrail.isNotEmpty, isTrue);

        final initialTrauma = cameraShake.trauma;

        // Advance simulation by 50ms
        coordinator.update(0.05);

        // Camera shake trauma must have decayed
        expect(cameraShake.trauma, lessThan(initialTrauma));
      });
    });
  });
}
