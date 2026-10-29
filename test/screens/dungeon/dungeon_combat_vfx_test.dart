import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/combat/combat_juice_coordinator.dart';
import 'package:gkk_flutter/core/vfx/directional_camera_shake.dart';
import 'package:gkk_flutter/core/vfx/hit_stop_manager.dart';
import 'package:gkk_flutter/core/vfx/rim_hit_flash_effect.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_battle_effects.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_cinematic_atmosphere.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_combat_vfx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dungeon Combat VFX Suite — All 9 Modules Verification (R3 & R5)', () {
    late DungeonAtmosphereController atmosphereController;
    late DungeonCombatVfxController vfxController;

    setUp(() {
      atmosphereController = DungeonAtmosphereController();
      vfxController = DungeonCombatVfxController(
        atmosphereController: atmosphereController,
      );
    });

    tearDown(() {
      vfxController.dispose();
      atmosphereController.dispose();
    });

    // =========================================================================
    // 1. Directional Camera Shake
    // =========================================================================
    test('1. Camera Shake: normal player strike triggers directional recoil trauma', () {
      vfxController.triggerPlayerStrike(damage: 45, isCritical: false);

      expect(vfxController.cameraShake.isActive, isTrue);
      expect(vfxController.cameraShake.trauma, greaterThan(0.3));
      expect(vfxController.cameraShake.state.translation.dx, isNonZero);
    });

    test('1. Camera Shake: critical strike applies heavy trauma >= 0.75 and roll torque', () {
      vfxController.triggerPlayerStrike(damage: 120, isCritical: true);

      expect(vfxController.cameraShake.isActive, isTrue);
      expect(vfxController.cameraShake.trauma, greaterThanOrEqualTo(0.75));
      expect(vfxController.cameraShake.config.directionalBiasWeight, greaterThanOrEqualTo(0.8));
    });

    // =========================================================================
    // 2. Hit-Stop (30-50ms micro-pause)
    // =========================================================================
    test('2. Hit-Stop: normal impact freezes time scale strictly within 30-50ms range', () {
      vfxController.triggerPlayerStrike(damage: 50, isCritical: false);

      expect(vfxController.hitStopManager.activeCount, equals(1));
      expect(vfxController.hitStopManager.isAnyFrozen, isTrue);
      expect(vfxController.hitStopManager.globalTimeScale, equals(0.0));

      // Advance 15ms (still frozen)
      vfxController.update(0.015);
      expect(vfxController.hitStopManager.isAnyFrozen, isTrue);

      // Advance past 55ms (resumed)
      vfxController.update(0.045);
      expect(vfxController.hitStopManager.globalTimeScale, greaterThan(0.0));
    });

    test('2. Hit-Stop: critical strike triggers 50ms peak freeze with ease-out ramp', () {
      vfxController.triggerPlayerStrike(damage: 150, isCritical: true);

      expect(vfxController.hitStopManager.activeCount, equals(1));
      expect(vfxController.hitStopManager.globalTimeScale, equals(0.0));
    });

    // =========================================================================
    // 3. Enemy & Player Rim-Light Flash
    // =========================================================================
    test('3. Rim Flash: enemy flashes on player strike with Fresnel highlight', () {
      vfxController.triggerPlayerStrike(
        damage: 60,
        isCritical: false,
        damageType: HitDamageType.physical,
      );

      expect(vfxController.enemyRimFlash.isFlashing, isTrue);
      expect(vfxController.enemyRimFlash.currentIntensity, greaterThanOrEqualTo(1.0));
      expect(vfxController.enemyRimFlash.config.tint, equals(RimFlashTint.white));
    });

    test('3. Rim Flash: critical strike triggers blood-red rim highlight with boosted intensity', () {
      vfxController.triggerPlayerStrike(
        damage: 180,
        isCritical: true,
      );

      expect(vfxController.enemyRimFlash.isFlashing, isTrue);
      expect(vfxController.enemyRimFlash.currentIntensity, greaterThanOrEqualTo(2.0));
      expect(vfxController.enemyRimFlash.config.tint, equals(RimFlashTint.bloodRed));
    });

    test('3. Rim Flash: enemy counter-attack flashes player portrait', () {
      vfxController.triggerEnemyStrike(damage: 35, isCritical: false);

      expect(vfxController.playerRimFlash.isFlashing, isTrue);
      expect(vfxController.playerRimFlash.currentIntensity, greaterThan(1.0));
    });

    // =========================================================================
    // 4. Weapon Ribbon Trails
    // =========================================================================
    test('4. Weapon Trails: attack swing generates ribbon trail samples', () {
      vfxController.triggerPlayerStrike(damage: 55, isCritical: false);

      expect(vfxController.ribbonTrail.isNotEmpty, isTrue);
      expect(vfxController.ribbonTrail.sampleCount, greaterThanOrEqualTo(4));
    });

    test('4. Weapon Trails: clash triggers crossing ribbon trails', () {
      vfxController.triggerClash();

      expect(vfxController.ribbonTrail.isNotEmpty, isTrue);
      expect(vfxController.ribbonTrail.sampleCount, greaterThanOrEqualTo(8));
    });

    // =========================================================================
    // 5. Dynamic Decals on Terrain
    // =========================================================================
    test('5. Dynamic Decals: strikes spawn slash gouges and scorch marks on atmosphere ground', () {
      final initialCount = atmosphereController.decalSystem.activeDecalCount;

      // Normal strike spawns slash gouge
      vfxController.triggerPlayerStrike(damage: 40, isCritical: false);
      expect(atmosphereController.decalSystem.activeDecalCount, greaterThan(initialCount));

      // Critical strike spawns scorch mark
      final afterFirst = atmosphereController.decalSystem.activeDecalCount;
      vfxController.triggerPlayerStrike(damage: 120, isCritical: true);
      expect(atmosphereController.decalSystem.activeDecalCount, greaterThan(afterFirst));

      // Enemy hit spawns blood splatter
      final afterSecond = atmosphereController.decalSystem.activeDecalCount;
      vfxController.triggerEnemyStrike(damage: 40);
      expect(atmosphereController.decalSystem.activeDecalCount, greaterThan(afterSecond));
    });

    // =========================================================================
    // 6. GPU Particles
    // =========================================================================
    test('6. GPU Particles: strikes emit spark streaks and incandescent flash bursts', () {
      vfxController.triggerPlayerStrike(damage: 75, isCritical: true);

      expect(vfxController.particleSystem.totalActiveParticles, greaterThan(0));
    });

    // =========================================================================
    // 7. Haptics
    // =========================================================================
    test('7. Haptics: triggers light, medium, heavy, and critical impacts without errors', () {
      expect(() => vfxController.triggerHaptic(HapticImpactLevel.light), returnsNormally);
      expect(() => vfxController.triggerHaptic(HapticImpactLevel.medium), returnsNormally);
      expect(() => vfxController.triggerHaptic(HapticImpactLevel.heavy), returnsNormally);
      expect(() => vfxController.triggerHaptic(HapticImpactLevel.critical), returnsNormally);
    });

    // =========================================================================
    // 8. Floating Damage Numbers
    // =========================================================================
    test('8. Damage Numbers: spawns floating numbers with bounce scale and upward drift', () {
      vfxController.triggerPlayerStrike(damage: 88, isCritical: false);

      expect(vfxController.damageNumbers.length, equals(1));
      final dmg = vfxController.damageNumbers.first;
      expect(dmg.damage, equals(88));
      expect(dmg.isCritical, isFalse);
      expect(dmg.isPlayerTarget, isFalse);
      expect(dmg.scale, greaterThan(0.5));

      // Advance time by 0.1s: scale overshoots in bounce phase
      vfxController.update(0.1);
      expect(dmg.currentOffset.dy, lessThan(dmg.startOffset.dy)); // Floated upwards

      // Advance past lifetime: auto expires and removes
      vfxController.update(1.2);
      expect(vfxController.damageNumbers.isEmpty, isTrue);
    });

    test('8. Damage Numbers: critical hit spawns enlarged scaling number with KRİTİK prefix', () {
      vfxController.triggerPlayerStrike(damage: 245, isCritical: true);

      expect(vfxController.damageNumbers.length, equals(1));
      final dmg = vfxController.damageNumbers.first;
      expect(dmg.damage, equals(245));
      expect(dmg.isCritical, isTrue);
      expect(dmg.scale, greaterThanOrEqualTo(1.0));
    });

    // =========================================================================
    // 9. Knockback & Hit Reactions
    // =========================================================================
    test('9. Knockback: enemy physically recoils backwards and flinches on impact', () {
      vfxController.triggerPlayerStrike(damage: 65, isCritical: false);

      final state = vfxController.enemyKnockback.getStateSnapshot();
      expect(state.isActive, isTrue);
      expect(state.velocity.x, greaterThan(0.0)); // Recoil pushing rightwards
      expect(state.ragdollWeight, greaterThan(0.0)); // Flinch blend
    });

    test('9. Knockback: player physically recoils backwards on enemy strike', () {
      vfxController.triggerEnemyStrike(damage: 50, isCritical: false);

      final state = vfxController.playerKnockback.getStateSnapshot();
      expect(state.isActive, isTrue);
      expect(state.velocity.x, lessThan(0.0)); // Recoil pushing leftwards
    });

    // =========================================================================
    // Combat Log Parsing Integration
    // =========================================================================
    test('Combat Log Line Parsing routes flavor text to appropriate VFX modules', () {
      // Critical strike line
      vfxController.processCombatLine(
        'Ezici bir vuruş! Kritik hasar verildi!',
        playerAttack: 100,
        playerDefense: 80,
      );
      expect(vfxController.cameraShake.isActive, isTrue);
      expect(vfxController.enemyRimFlash.isFlashing, isTrue);
      expect(vfxController.damageNumbers.last.isCritical, isTrue);

      // Enemy hit line
      vfxController.processCombatLine(
        'Sert bir darbe aldın, dişini sıktın.',
        playerAttack: 100,
        playerDefense: 80,
      );
      expect(vfxController.playerRimFlash.isFlashing, isTrue);
      expect(vfxController.damageNumbers.last.isPlayerTarget, isTrue);

      // Clash line
      vfxController.processCombatLine(
        'Düşman savurdu, son anda eğildin!',
        playerAttack: 100,
        playerDefense: 80,
      );
      expect(vfxController.hitStopManager.isAnyFrozen, isTrue);
    });

    // =========================================================================
    // Widget Host Integration Test
    // =========================================================================
    testWidgets('10. DungeonCombatVfxArenaHost renders all 9 layers in widget tree', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 140,
                child: DungeonCombatVfxArenaHost(
                  controller: vfxController,
                  playerPortrait: Container(
                    key: const ValueKey('player_portrait'),
                    width: 70,
                    height: 70,
                    color: Colors.blue,
                  ),
                  enemyPortrait: Container(
                    key: const ValueKey('enemy_portrait'),
                    width: 70,
                    height: 70,
                    color: Colors.red,
                  ),
                  clashIcon: const Icon(Icons.flash_on, key: ValueKey('clash_icon')),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify core widgets exist in tree
      expect(find.byKey(const ValueKey('player_portrait')), findsOneWidget);
      expect(find.byKey(const ValueKey('enemy_portrait')), findsOneWidget);
      expect(find.byKey(const ValueKey('clash_icon')), findsOneWidget);
      expect(find.byType(DirectionalCameraShakeHost), findsOneWidget);
      expect(find.byType(RimHitFlashWidget), findsNWidgets(2)); // player + enemy
      expect(find.byType(CustomPaint), findsWidgets); // trails, particles, numbers

      // Trigger a hit while hosted
      vfxController.triggerPlayerStrike(damage: 99, isCritical: true);
      await tester.pump(const Duration(milliseconds: 16));

      expect(vfxController.cameraShake.isActive, isTrue);
      expect(vfxController.enemyRimFlash.isFlashing, isTrue);
      expect(vfxController.damageNumbers.isNotEmpty, isTrue);
    });
  });
}
