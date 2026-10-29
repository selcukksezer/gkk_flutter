import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/vfx/knockback_ragdoll_controller.dart';

void main() {
  group('KnockbackVector3 Math & Operations', () {
    test('vector arithmetic produces correct results', () {
      const v1 = KnockbackVector3(3.0, 4.0, 5.0);
      const v2 = KnockbackVector3(1.0, 2.0, 3.0);

      final sum = v1 + v2;
      expect(sum.x, closeTo(4.0, 1e-6));
      expect(sum.y, closeTo(6.0, 1e-6));
      expect(sum.z, closeTo(8.0, 1e-6));

      final diff = v1 - v2;
      expect(diff.x, closeTo(2.0, 1e-6));
      expect(diff.y, closeTo(2.0, 1e-6));
      expect(diff.z, closeTo(2.0, 1e-6));

      final scaled = v1 * 2.5;
      expect(scaled.x, closeTo(7.5, 1e-6));
      expect(scaled.y, closeTo(10.0, 1e-6));
      expect(scaled.z, closeTo(12.5, 1e-6));

      final div = v1 / 2.0;
      expect(div.x, closeTo(1.5, 1e-6));
      expect(div.y, closeTo(2.0, 1e-6));
      expect(div.z, closeTo(2.5, 1e-6));

      final negated = -v1;
      expect(negated.x, closeTo(-3.0, 1e-6));
      expect(negated.y, closeTo(-4.0, 1e-6));
      expect(negated.z, closeTo(-5.0, 1e-6));
    });

    test('division by zero returns zero vector safely', () {
      const v = KnockbackVector3(5.0, 10.0, 15.0);
      final result = v / 0.0;
      expect(result, equals(KnockbackVector3.zero));
    });

    test('dot and cross products calculate genuine 3D vectors', () {
      const v1 = KnockbackVector3(1.0, 0.0, 0.0);
      const v2 = KnockbackVector3(0.0, 1.0, 0.0);

      expect(v1.dot(v2), closeTo(0.0, 1e-6));

      final cross = v1.cross(v2);
      expect(cross.x, closeTo(0.0, 1e-6));
      expect(cross.y, closeTo(0.0, 1e-6));
      expect(cross.z, closeTo(1.0, 1e-6)); // X cross Y = Z
    });

    test('length and normalization', () {
      const v = KnockbackVector3(3.0, 0.0, 4.0);
      expect(v.length, closeTo(5.0, 1e-6));
      expect(v.lengthSquared, closeTo(25.0, 1e-6));
      expect(v.horizontalLength, closeTo(5.0, 1e-6));

      final norm = v.normalized;
      expect(norm.length, closeTo(1.0, 1e-6));
      expect(norm.x, closeTo(0.6, 1e-6));
      expect(norm.z, closeTo(0.8, 1e-6));

      expect(KnockbackVector3.zero.normalized, equals(KnockbackVector3.zero));
    });

    test('reflection with elasticity/restitution', () {
      // Vector moving along +X hitting wall with normal pointing along -X
      const vel = KnockbackVector3(10.0, 0.0, 0.0);
      const wallNormal = KnockbackVector3(-1.0, 0.0, 0.0);

      // Elastic reflection (e = 1.0)
      final elasticRefl = vel.reflect(wallNormal, 1.0);
      expect(elasticRefl.x, closeTo(-10.0, 1e-6));
      expect(elasticRefl.y, closeTo(0.0, 1e-6));
      expect(elasticRefl.z, closeTo(0.0, 1e-6));

      // Inelastic / lossy reflection (e = 0.5)
      final lossyRefl = vel.reflect(wallNormal, 0.5);
      expect(lossyRefl.x, closeTo(-5.0, 1e-6));

      // Vector moving away from normal does not reflect
      final movingAway = elasticRefl.reflect(wallNormal, 1.0);
      expect(movingAway.x, closeTo(-10.0, 1e-6));
    });

    test('lerp and clampMagnitude', () {
      const start = KnockbackVector3(0.0, 0.0, 0.0);
      const end = KnockbackVector3(10.0, 20.0, 30.0);

      final mid = start.lerp(end, 0.5);
      expect(mid.x, closeTo(5.0, 1e-6));
      expect(mid.y, closeTo(10.0, 1e-6));
      expect(mid.z, closeTo(15.0, 1e-6));

      final clamped = end.clampMagnitude(5.0);
      expect(clamped.length, closeTo(5.0, 1e-5));
    });
  });

  group('Momentum Conservation & Mass Resistance', () {
    test('momentum conservation: Delta v is inversely proportional to mass', () {
      // Fixed impulse J = 700 kg*m/s along X
      const impulse = KnockbackImpulse(
        impulse: KnockbackVector3(700.0, 0.0, 0.0),
      );

      final normalController = KnockbackRagdollController(
        config: const KnockbackConfig(mass: 70.0),
      );
      final heavyController = KnockbackRagdollController(
        config: const KnockbackConfig(mass: 140.0),
      );
      final lightController = KnockbackRagdollController(
        config: const KnockbackConfig(mass: 35.0),
      );

      normalController.applyImpulse(impulse);
      heavyController.applyImpulse(impulse);
      lightController.applyImpulse(impulse);

      // Delta v = 700 / 70 = 10 m/s
      expect(normalController.velocity.x, closeTo(10.0, 1e-6));
      // Heavy: Delta v = 700 / 140 = 5 m/s
      expect(heavyController.velocity.x, closeTo(5.0, 1e-6));
      // Light: Delta v = 700 / 35 = 20 m/s
      expect(lightController.velocity.x, closeTo(20.0, 1e-6));

      // Ratio validation
      expect(
        normalController.velocity.x / heavyController.velocity.x,
        closeTo(2.0, 1e-6),
      );
      expect(
        lightController.velocity.x / normalController.velocity.x,
        closeTo(2.0, 1e-6),
      );
    });

    test('poise armor reduces impulse velocity', () {
      const impulse = KnockbackImpulse(
        impulse: KnockbackVector3(700.0, 0.0, 0.0),
      );

      final noPoise = KnockbackRagdollController(
        config: const KnockbackConfig(mass: 70.0, poiseArmor: 0.0),
      );
      final highPoise = KnockbackRagdollController(
        config: const KnockbackConfig(mass: 70.0, poiseArmor: 1.0),
      );

      noPoise.applyImpulse(impulse);
      highPoise.applyImpulse(impulse);

      // High poise (1.0) halves the incoming impulse velocity: 1 / (1 + 1) = 0.5
      expect(noPoise.velocity.x, closeTo(10.0, 1e-6));
      expect(highPoise.velocity.x, closeTo(5.0, 1e-6));
    });

    test('zero or sub-1.0 mass is clamped safely without divide-by-zero', () {
      final controller = KnockbackRagdollController(
        config: const KnockbackConfig(mass: 0.0, poiseArmor: 0.0),
      );

      controller.applyImpulse(const KnockbackImpulse(
        impulse: KnockbackVector3(100.0, 0.0, 0.0),
      ));

      // Clamped to 1.0 mass
      expect(controller.velocity.x, closeTo(100.0, 1e-6));
      expect(controller.velocity.x.isFinite, isTrue);
    });
  });

  group('Ground Damping & Dynamic Friction Decay', () {
    test('horizontal velocity monotonically decays to zero under ground friction', () {
      final controller = KnockbackRagdollController(
        config: const KnockbackConfig(
          mass: 70.0,
          groundFriction: 6.0,
          gravity: 10.0, // Friction deceleration = 6 * 10 = 60 m/s^2
          restVelocityThreshold: 0.05,
        ),
      );

      // Apply initial horizontal impulse giving v0 = 12.0 m/s
      controller.applyImpulse(const KnockbackImpulse(
        impulse: KnockbackVector3(840.0, 0.0, 0.0),
      ));

      expect(controller.velocity.x, closeTo(12.0, 1e-6));
      expect(controller.isAirborne, isFalse);

      var prevSpeed = controller.velocity.horizontalLength;
      var simulatedTime = 0.0;
      const dt = 0.02; // 20ms steps

      // Step physics and verify strictly monotonic deceleration
      for (var i = 0; i < 50; i++) {
        controller.update(dt);
        simulatedTime += dt;
        final currentSpeed = controller.velocity.horizontalLength;

        if (currentSpeed > 0.0) {
          expect(currentSpeed, lessThan(prevSpeed));
          prevSpeed = currentSpeed;
        } else {
          // Reached rest
          break;
        }
      }

      // Should have settled completely within 12 / 60 = 0.2 seconds
      expect(simulatedTime, lessThanOrEqualTo(0.3));
      expect(controller.velocity.x, equals(0.0));
      expect(controller.velocity.horizontalLength, equals(0.0));
      expect(controller.position.x, greaterThan(0.5));
    });

    test('higher ground friction results in shorter stopping distance', () {
      final lowFriction = KnockbackRagdollController(
        config: const KnockbackConfig(groundFriction: 3.0, gravity: 10.0),
      );
      final highFriction = KnockbackRagdollController(
        config: const KnockbackConfig(groundFriction: 9.0, gravity: 10.0),
      );

      const impulse = KnockbackImpulse(
        impulse: KnockbackVector3(700.0, 0.0, 0.0),
      );

      lowFriction.applyImpulse(impulse);
      highFriction.applyImpulse(impulse);

      // Run until both stop
      for (var i = 0; i < 100; i++) {
        lowFriction.update(0.02);
        highFriction.update(0.02);
      }

      expect(lowFriction.velocity.horizontalLength, equals(0.0));
      expect(highFriction.velocity.horizontalLength, equals(0.0));
      expect(
        highFriction.position.x,
        lessThan(lowFriction.position.x),
      );
    });
  });

  group('Critical Hit Launching & Airborne Parabolic Arc', () {
    test('critical hit initiates airborne state and triggers apex and ground impact', () {
      bool apexTriggered = false;
      double recordedApexHeight = 0.0;
      bool groundImpactTriggered = false;
      double recordedImpactVelocity = 0.0;

      final controller = KnockbackRagdollController(
        config: const KnockbackConfig(
          mass: 70.0,
          gravity: 18.0,
          groundRestitution: 0.0, // Inelastic for crisp settlement
          airDrag: 0.0,
        ),
        onAirborneApex: (pos, apexHeight) {
          apexTriggered = true;
          recordedApexHeight = apexHeight;
        },
        onGroundImpact: (pos, impactVelocity) {
          groundImpactTriggered = true;
          recordedImpactVelocity = impactVelocity;
        },
      );

      // Critical hit: launch upward with Vy = 9.0 m/s and horizontal Vx = 4.0 m/s
      controller.applyImpulse(const KnockbackImpulse(
        impulse: KnockbackVector3(280.0, 0.0, 0.0),
        verticalLaunchImpulse: 630.0, // 630 / 70 = 9.0 m/s
        isCriticalHit: true,
      ));

      expect(controller.isAirborne, isTrue);
      expect(controller.velocity.y, closeTo(9.0, 1e-6));
      expect(controller.velocity.x, closeTo(4.0, 1e-6));

      // Theoretical apex height = Vy^2 / (2 * g) = 81 / 36 = 2.25 m
      // Theoretical time to apex = Vy / g = 9 / 18 = 0.5 s
      // Total flight time = 2 * 0.5 = 1.0 s

      const dt = 0.016; // ~60fps
      var elapsed = 0.0;

      while (elapsed < 1.3 && controller.isAirborne) {
        controller.update(dt);
        elapsed += dt;
      }

      expect(apexTriggered, isTrue);
      expect(recordedApexHeight, closeTo(2.25, 0.05));
      expect(controller.peakApexHeight, closeTo(2.25, 0.05));

      expect(groundImpactTriggered, isTrue);
      // Impact speed should match launch speed in vacuum
      expect(recordedImpactVelocity, closeTo(9.0, 0.3));

      // Landed
      expect(controller.position.y, equals(0.0));
      expect(controller.isAirborne, isFalse);
    });

    test('ground restitution causes secondary bounce on landing', () {
      int groundImpactCount = 0;

      final controller = KnockbackRagdollController(
        config: const KnockbackConfig(
          mass: 70.0,
          gravity: 20.0,
          groundRestitution: 0.4, // 40% bounce restitution
          airDrag: 0.0,
        ),
        onGroundImpact: (pos, speed) {
          groundImpactCount++;
        },
      );

      // Launch with high vertical impulse
      controller.applyImpulse(const KnockbackImpulse(
        impulse: KnockbackVector3.zero,
        verticalLaunchImpulse: 1400.0, // 1400 / 70 = 20 m/s
        isCriticalHit: true,
      ));

      // Simulate full trajectory through multiple bounces
      for (var i = 0; i < 200; i++) {
        controller.update(0.02);
      }

      // Should have bounced at least twice before settling
      expect(groundImpactCount, greaterThanOrEqualTo(2));
      expect(controller.position.y, equals(0.0));
      expect(controller.isAirborne, isFalse);
    });
  });

  group('Boundary Collision & Reflection', () {
    test('AABB boundary reflects velocity and corrects penetration', () {
      bool wallCollided = false;
      WallCollisionEvent? collisionEvent;

      final boundary = AABBCollisionBoundary(
        minX: -10.0,
        maxX: 10.0,
        minZ: -10.0,
        maxZ: 10.0,
      );

      final controller = KnockbackRagdollController(
        config: const KnockbackConfig(
          mass: 70.0,
          wallRestitution: 0.5,
          groundFriction: 0.0, // Zero friction to isolate wall bounce
          wallSplatSpeedThreshold: 8.0,
        ),
        boundary: boundary,
        characterRadius: 0.5,
        initialPosition: const KnockbackVector3(9.0, 0.0, 0.0),
        onWallCollision: (event) {
          wallCollided = true;
          collisionEvent = event;
        },
      );

      // Moving right towards maxX (10.0) at 10 m/s. Character radius = 0.5,
      // so wall is hit at X = 9.5.
      controller.applyImpulse(const KnockbackImpulse(
        impulse: KnockbackVector3(700.0, 0.0, 0.0), // Vx = 10 m/s
      ));

      // Step physics into the wall
      controller.update(0.1); // Would advance to X = 10.0 without boundary

      expect(wallCollided, isTrue);
      expect(collisionEvent, isNotNull);
      expect(collisionEvent!.normal.x, closeTo(-1.0, 1e-6));
      expect(collisionEvent!.impactSpeed, closeTo(10.0, 0.2));
      expect(collisionEvent!.isWallSplat, isTrue); // 10 >= 8.0 threshold
      expect(collisionEvent!.contactPosition.x, closeTo(9.5, 1e-5));

      // After rebound, position must remain inside boundary (<= 9.5)
      expect(controller.position.x, lessThanOrEqualTo(9.5));

      // Velocity must be reflected: -10 * 0.5 = -5.0 m/s
      expect(controller.velocity.x, closeTo(-5.0, 1e-5));
    });

    test('Circular boundary reflects radial knockback back toward center', () {
      bool collided = false;
      final circularArena = CircularCollisionBoundary(
        center: KnockbackVector3.zero,
        radius: 10.0,
      );

      final controller = KnockbackRagdollController(
        config: const KnockbackConfig(
          mass: 70.0,
          wallRestitution: 0.6,
          groundFriction: 0.0,
        ),
        boundary: circularArena,
        characterRadius: 0.5,
        initialPosition: const KnockbackVector3(9.0, 0.0, 0.0),
        onWallCollision: (_) => collided = true,
      );

      // Moving outwards along +X
      controller.applyImpulse(const KnockbackImpulse(
        impulse: KnockbackVector3(700.0, 0.0, 0.0),
      ));

      controller.update(0.1);

      expect(collided, isTrue);
      // Position inside radius - characterRadius = 9.5
      expect(controller.position.x, lessThanOrEqualTo(9.5));
      // Reflected towards center (-X direction)
      expect(controller.velocity.x, lessThan(0.0));
    });

    test('PlaneCollisionBoundary prevents penetration across arbitrary wall plane', () {
      final plane = PlaneCollisionBoundary(
        normal: const KnockbackVector3(-1.0, 0.0, 0.0), // Normal facing -X
        distance: -5.0, // Wall at X = 5.0
      );

      final controller = KnockbackRagdollController(
        config: const KnockbackConfig(
          mass: 70.0,
          wallRestitution: 0.4,
          groundFriction: 0.0,
        ),
        boundary: plane,
        characterRadius: 0.4,
        initialPosition: const KnockbackVector3(4.0, 0.0, 0.0),
      );

      controller.applyImpulse(const KnockbackImpulse(
        impulse: KnockbackVector3(700.0, 0.0, 0.0),
      ));

      controller.update(0.15);

      // Character must remain on safe side of plane
      expect(controller.position.x, lessThanOrEqualTo(5.0));
      expect(controller.velocity.x, lessThan(0.0));
    });
  });

  group('Procedural Hit-Reaction & Ragdoll Blend Weight', () {
    test('ragdoll blend transitions cleanly through phases', () {
      final blendWeights = <double>[];
      bool finishedTriggered = false;

      final controller = KnockbackRagdollController(
        config: const KnockbackConfig(
          mass: 70.0,
          blendInDuration: 0.04,
          blendOutDuration: 0.10,
          defaultMaxRagdollWeight: 0.8,
          groundFriction: 15.0, // Fast stop
        ),
        onRagdollBlendChanged: (w) => blendWeights.add(w),
        onKnockbackFinished: () => finishedTriggered = true,
      );

      expect(controller.phase, equals(RagdollPhase.idle));
      expect(controller.ragdollWeight, equals(0.0));

      // Apply light hit
      controller.applyImpulse(const KnockbackImpulse(
        impulse: KnockbackVector3(350.0, 0.0, 0.0),
      ));

      expect(controller.phase, equals(RagdollPhase.blendingIn));

      // Advance through blend-in (0.04s)
      controller.update(0.02);
      expect(controller.ragdollWeight, greaterThan(0.0));
      expect(controller.ragdollWeight, lessThan(0.8));

      controller.update(0.03); // Total 0.05s > 0.04s
      expect(controller.phase, equals(RagdollPhase.ragdollActive));
      expect(controller.ragdollWeight, closeTo(0.8, 1e-5));

      // Continue until physics motion stops and recovery completes
      for (var i = 0; i < 20; i++) {
        controller.update(0.02);
      }

      expect(controller.phase, equals(RagdollPhase.idle));
      expect(controller.ragdollWeight, equals(0.0));
      expect(finishedTriggered, isTrue);
    });

    test('procedural spine tilt produces reactive oscillation and recovers to upright', () {
      final controller = KnockbackRagdollController(
        config: const KnockbackConfig(
          angularSpringStiffness: 50.0,
          angularSpringDamping: 10.0,
        ),
      );

      // Hit from front (+Z) pushes character backwards
      controller.applyDirectionalHit(
        hitDirection: const KnockbackVector3(0.0, 0.0, 1.0),
        impulseMagnitude: 700.0,
      );

      // Pitch should have received an initial kick
      expect(controller.spineTilt.pitchVelocity.abs(), greaterThan(0.01));

      // Step physics: spine tilts into reaction
      controller.update(0.03);
      expect(controller.spineTilt.pitch.abs(), greaterThan(0.001));

      // Over time, spring-damper returns spine tilt to equilibrium (zero)
      for (var i = 0; i < 150; i++) {
        controller.update(0.02);
      }

      expect(controller.spineTilt.pitch.abs(), lessThan(0.005));
      expect(controller.spineTilt.roll.abs(), lessThan(0.005));
      expect(controller.spineTilt.yaw.abs(), lessThan(0.005));
    });
  });

  group('Animator Root Motion Combination', () {
    test('additive mode combines root motion with physics and suppresses on high ragdoll', () {
      final controller = KnockbackRagdollController(
        config: const KnockbackConfig(
          rootMotionCombineMode: RootMotionCombineMode.additive,
        ),
      );

      // Idle: 100% animator pass-through
      const animStep = KnockbackVector3(0.0, 0.0, 0.1);
      final idleDisplacement = controller.update(0.02, animatorRootMotionDelta: animStep);
      expect(idleDisplacement, equals(animStep));

      // Apply heavy hit with peak ragdoll weight 1.0
      controller.applyImpulse(const KnockbackImpulse(
        impulse: KnockbackVector3(700.0, 0.0, 0.0),
        customRagdollPeakWeight: 1.0,
      ));

      // Fast forward into ragdollActive (ragdollWeight = 1.0)
      controller.update(0.06);
      expect(controller.ragdollWeight, closeTo(1.0, 1e-5));

      // With ragdollWeight = 1.0, animator root motion is suppressed (1.0 - 0.85 = 0.15 weight)
      final activeDisplacement = controller.update(
        0.016,
        animatorRootMotionDelta: const KnockbackVector3(0.0, 0.0, 1.0),
      );

      // Displacement along Z should be significantly suppressed compared to 1.0
      expect(activeDisplacement.z, closeTo(0.15, 0.05));
    });

    test('blended mode linearly blends animator and physics displacement', () {
      final controller = KnockbackRagdollController(
        config: const KnockbackConfig(
          rootMotionCombineMode: RootMotionCombineMode.blended,
          blendInDuration: 0.1,
          defaultMaxRagdollWeight: 1.0,
        ),
      );

      controller.applyImpulse(const KnockbackImpulse(
        impulse: KnockbackVector3(700.0, 0.0, 0.0), // Physics pushes X
      ));

      // While blending, ragdoll weight is intermediate
      controller.update(0.05);
      final weight = controller.ragdollWeight;
      expect(weight, greaterThan(0.1));
      expect(weight, lessThan(0.9));

      const animDelta = KnockbackVector3(0.0, 0.0, 1.0);
      final combined = controller.update(0.016, animatorRootMotionDelta: animDelta);
      final currentWeight = controller.ragdollWeight;

      // Z should scale with (1 - currentWeight)
      expect(combined.z, closeTo(1.0 * (1.0 - currentWeight), 0.05));
      // X should scale with currentWeight
      expect(combined.x, greaterThan(0.0));
    });
  });

  group('Combat Presets & State Snapshot', () {
    test('built-in combat presets have valid parameter distributions', () {
      expect(KnockbackConfig.lightStagger.defaultMaxRagdollWeight, lessThan(0.5));
      expect(KnockbackConfig.heavySmash.defaultMaxRagdollWeight, greaterThan(0.8));
      expect(KnockbackConfig.criticalLaunch.defaultMaxRagdollWeight, equals(1.0));
      expect(KnockbackConfig.bossPoise.poiseArmor, greaterThanOrEqualTo(4.0));
      expect(KnockbackConfig.bossPoise.mass, greaterThan(300.0));
    });

    test('state snapshot captures complete simulation state', () {
      final controller = KnockbackRagdollController(
        config: KnockbackConfig.mediumHit,
        initialPosition: const KnockbackVector3(1.0, 2.0, 3.0),
      );

      final state = controller.getStateSnapshot();
      expect(state.position.x, closeTo(1.0, 1e-6));
      expect(state.position.y, closeTo(2.0, 1e-6));
      expect(state.position.z, closeTo(3.0, 1e-6));
      expect(state.phase, equals(RagdollPhase.idle));
      expect(state.isActive, isFalse);

      controller.applyImpulse(const KnockbackImpulse(
        impulse: KnockbackVector3(500.0, 0.0, 0.0),
      ));

      final activeState = controller.getStateSnapshot();
      expect(activeState.isActive, isTrue);
      expect(activeState.phase, equals(RagdollPhase.blendingIn));

      controller.reset(newPosition: const KnockbackVector3(0.0, 0.0, 0.0));
      final resetState = controller.getStateSnapshot();
      expect(resetState.position, equals(KnockbackVector3.zero));
      expect(resetState.isActive, isFalse);
    });
  });
}
