import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/pvp/pvp_combat_vfx_coordinator.dart';
import 'package:gkk_flutter/components/pvp/pvp_combat_vfx_overlay.dart';
import 'package:gkk_flutter/core/vfx/directional_camera_shake.dart';
import 'package:gkk_flutter/core/vfx/ground_decal_system.dart';
import 'package:gkk_flutter/core/vfx/rim_hit_flash_effect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PvpCombatVfxCoordinator — All 9 Combat VFX/Juice Modules', () {
    late PvpCombatVfxCoordinator coordinator;

    setUp(() {
      coordinator = PvpCombatVfxCoordinator();
      coordinator.haptics.enabled = false; // Disable platform haptics in test
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('1. Directional Camera Shake: applies directional trauma on hits and crits', () {
      expect(coordinator.cameraShake.trauma, 0.0);

      // Normal strike
      coordinator.triggerHitImpact(
        targetIsOpponent: true,
        damageValue: 120.0,
        isCritical: false,
        impactPoint: const Offset(100, 200),
      );

      expect(coordinator.cameraShake.trauma, greaterThan(0.0));
      final double normalTrauma = coordinator.cameraShake.trauma;

      // Reset & Crit strike
      coordinator.cameraShake.reset();
      coordinator.triggerHitImpact(
        targetIsOpponent: true,
        damageValue: 350.0,
        isCritical: true,
        impactPoint: const Offset(100, 200),
      );

      expect(coordinator.cameraShake.trauma, greaterThan(normalTrauma));
      expect(coordinator.cameraShake.trauma, closeTo(CameraShakePreset.heavyCrit.trauma, 0.05));
    });

    test('2. Hit-Stop: triggers time-dilation pause strictly within 30-50ms target range', () {
      expect(coordinator.hitStopManager.isFrozen, isFalse);

      // Critical strike triggers 50ms freeze
      coordinator.triggerHitImpact(
        targetIsOpponent: true,
        damageValue: 450.0,
        isCritical: true,
        impactPoint: const Offset(100, 200),
      );

      expect(coordinator.hitStopManager.isFrozen, isTrue);
      final activeReq = coordinator.hitStopManager.activeRequest;
      expect(activeReq, isNotNull);
      expect(activeReq!.freezeDuration.inMilliseconds, inInclusiveRange(30, 50));
      expect(activeReq.freezeDuration.inMilliseconds, equals(50));
    });

    test('2b. Hit-Stop on Parry: triggers crisp 35ms freeze', () {
      coordinator.triggerHitImpact(
        targetIsOpponent: false,
        damageValue: 80.0,
        isCritical: false,
        isParried: true,
        impactPoint: const Offset(270, 200),
      );

      expect(coordinator.hitStopManager.isFrozen, isTrue);
      final activeReq = coordinator.hitStopManager.activeRequest;
      expect(activeReq, isNotNull);
      expect(activeReq!.freezeDuration.inMilliseconds, inInclusiveRange(30, 50));
      expect(activeReq.freezeDuration.inMilliseconds, equals(35));
    });

    test('3. Rim Flash: activates Fresnel highlight with color tint mapping', () {
      expect(coordinator.opponentRimFlash.isFlashing, isFalse);
      expect(coordinator.meRimFlash.isFlashing, isFalse);

      // Critical hit on opponent activates bloodRed rim flash on opponent
      coordinator.triggerHitImpact(
        targetIsOpponent: true,
        damageValue: 400.0,
        isCritical: true,
        impactPoint: const Offset(100, 200),
      );

      expect(coordinator.opponentRimFlash.isFlashing, isTrue);
      expect(coordinator.opponentRimFlash.config.tint, equals(RimFlashTint.bloodRed));
      expect(coordinator.meRimFlash.isFlashing, isFalse);

      // Parry on me activates lightningGold rim flash on me
      coordinator.triggerHitImpact(
        targetIsOpponent: false,
        damageValue: 50.0,
        isCritical: false,
        isParried: true,
        impactPoint: const Offset(270, 200),
      );

      expect(coordinator.meRimFlash.isFlashing, isTrue);
      expect(coordinator.meRimFlash.config.tint, equals(RimFlashTint.lightningGold));
    });

    test('4. Weapon Ribbon Trails: generates arc samples from attacker to defender', () {
      expect(coordinator.ribbonTrail.sampleCount, equals(0));

      coordinator.triggerWeaponSwing(
        attackerIsMe: true,
        attackerPos: const Offset(270, 200),
        defenderPos: const Offset(100, 200),
        weaponType: PvpWeaponTrailType.greatsword,
        isHeavy: true,
      );

      expect(coordinator.ribbonTrail.sampleCount, greaterThan(0));
      expect(coordinator.ribbonTrail.config.width, equals(20.0)); // Heavy greatsword width
    });

    test('5. Dynamic Decals: spawns colosseum ground decals at impact point', () {
      expect(coordinator.decalSystem.activeDecalCount, equals(0));

      // Normal strike -> slash gouge
      coordinator.triggerHitImpact(
        targetIsOpponent: true,
        damageValue: 120.0,
        isCritical: false,
        impactPoint: const Offset(100, 200),
      );

      expect(coordinator.decalSystem.activeDecalCount, equals(1));
      expect(coordinator.decalSystem.decals.first.type, equals(DecalType.slashGouge));

      // Critical strike -> blood splatter
      coordinator.triggerHitImpact(
        targetIsOpponent: true,
        damageValue: 400.0,
        isCritical: true,
        impactPoint: const Offset(100, 200),
      );

      expect(coordinator.decalSystem.activeDecalCount, equals(2));
      expect(coordinator.decalSystem.decals.last.type, equals(DecalType.bloodSplatter));
    });

    test('6. Particles: emits clashing spark particles with angle and speed boost on crits', () {
      expect(coordinator.particleSystem.totalActiveParticles, equals(0));

      coordinator.triggerHitImpact(
        targetIsOpponent: true,
        damageValue: 350.0,
        isCritical: true,
        impactPoint: const Offset(100, 200),
      );

      expect(coordinator.particleSystem.totalActiveParticles, greaterThan(30));
    });

    test('7. Mobile Haptics: handles calls safely without throwing exceptions', () async {
      coordinator.haptics.enabled = true;
      await coordinator.haptics.onNormalHit();
      await coordinator.haptics.onParry();
      await coordinator.haptics.onCriticalHit();
      await coordinator.haptics.onStunOrLethal();
      expect(coordinator.haptics.enabled, isTrue);
    });

    test('8. Floating Damage Numbers & Combo Counter: registers popups and combos', () {
      expect(coordinator.damagePopups.length, equals(0));
      expect(coordinator.comboTracker.comboCount, equals(0));

      // Hit 1
      coordinator.triggerHitImpact(
        targetIsOpponent: true,
        damageValue: 150.0,
        isCritical: false,
        impactPoint: const Offset(100, 200),
      );

      expect(coordinator.damagePopups.length, equals(1));
      expect(coordinator.damagePopups.first.text, equals('-150'));
      expect(coordinator.comboTracker.comboCount, equals(1));

      // Hit 2 (Combo begins)
      coordinator.triggerHitImpact(
        targetIsOpponent: true,
        damageValue: 320.0,
        isCritical: true,
        impactPoint: const Offset(100, 200),
      );

      expect(coordinator.damagePopups.length, equals(2));
      expect(coordinator.damagePopups.last.isCritical, isTrue);
      expect(coordinator.damagePopups.last.text, contains('KRİTİK!'));
      expect(coordinator.comboTracker.comboCount, equals(2));
      expect(coordinator.activeComboBanner, contains('2x KOMBO'));
    });

    test('9. Knockback & Stun Reactions: applies impulse and spring recoil recovery', () {
      final reaction = coordinator.opponentReaction;
      expect(reaction.offset, equals(Offset.zero));
      expect(reaction.isStunned, isFalse);

      coordinator.triggerHitImpact(
        targetIsOpponent: true,
        damageValue: 450.0,
        isCritical: true,
        isStun: true,
        impactPoint: const Offset(100, 200),
      );

      expect(reaction.isStunned, isTrue);
      expect(reaction.velocity.dx, lessThan(0.0)); // Knockback to the left

      // Advance physics simulation
      reaction.update(0.05);
      expect(reaction.offset.dx, lessThan(0.0));

      // Settle spring back
      for (int i = 0; i < 40; i++) {
        reaction.update(0.05);
      }
      expect(reaction.offset.dx.abs(), lessThan(1.0));
      expect(reaction.isStunned, isFalse);
    });

    test('Lethal Finisher: terminates duel with explosive shake, 50ms freeze, and knockdown', () {
      coordinator.triggerLethalFinisher(
        targetIsOpponent: true,
        impactPoint: const Offset(100, 200),
      );

      expect(coordinator.cameraShake.trauma, closeTo(CameraShakePreset.explosiveShock.trauma, 0.05));
      expect(coordinator.hitStopManager.isFrozen, isTrue);
      expect(coordinator.opponentRimFlash.isFlashing, isTrue);
      expect(coordinator.opponentReaction.isStunned, isTrue);
      expect(coordinator.damagePopups.last.text, contains('NAKAVT'));
    });

    test('Coordinator Update advances all 9 subsystems simultaneously', () {
      coordinator.triggerHitImpact(
        targetIsOpponent: true,
        damageValue: 200.0,
        isCritical: true,
        impactPoint: const Offset(100, 200),
      );

      coordinator.update(0.016);
      expect(coordinator.cameraShake.translation, isNotNull);
      expect(coordinator.particleSystem.totalActiveParticles, greaterThan(0));
    });
  });

  group('PvpCombatVfxStage & PvpFighterVfxWrapper Widget Rendering', () {
    testWidgets('PvpCombatVfxStage renders child and overlay layers cleanly', (
      WidgetTester tester,
    ) async {
      final coordinator = PvpCombatVfxCoordinator();
      coordinator.haptics.enabled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PvpCombatVfxStage(
              coordinator: coordinator,
              child: Container(
                key: const ValueKey('arena_floor'),
                color: Colors.black,
                child: const Text('Colosseum Duel'),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('arena_floor')), findsOneWidget);
      expect(find.text('Colosseum Duel'), findsOneWidget);

      coordinator.dispose();
    });

    testWidgets('PvpFighterVfxWrapper renders fighter and stun halo when stunned', (
      WidgetTester tester,
    ) async {
      final reaction = PvpFighterReactionState()..applyKnockback(const Offset(-10, 0), triggerStun: true);
      final rimCtrl = RimHitFlashController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PvpFighterVfxWrapper(
              reaction: reaction,
              rimFlashController: rimCtrl,
              child: const Icon(Icons.person, size: 60),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PvpFighterVfxWrapper), findsOneWidget);
      expect(find.byType(Icon), findsWidgets); // Fighter icon + stun stars

      rimCtrl.dispose();
    });
  });
}
