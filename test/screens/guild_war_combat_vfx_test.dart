import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/screens/guild_war/widgets/siege_combat_vfx_coordinator.dart';
import 'package:gkk_flutter/screens/guild_war/widgets/siege_combat_viewport.dart';
import 'package:gkk_flutter/models/guild_war_model.dart';
import 'package:gkk_flutter/screens/guild_war/battle_result_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Guild War Combat VFX & Juice Modules (All 9 Modules)', () {
    late GuildWarCombatVfxCoordinator coordinator;

    setUp(() {
      coordinator = GuildWarCombatVfxCoordinator(enableHaptics: false);
    });

    tearDown(() {
      coordinator.dispose();
    });

    // -------------------------------------------------------------------------
    // Module 1: Camera Shake
    // -------------------------------------------------------------------------
    test('Module 1: Camera Shake - trauma addition, decay and directional offset', () {
      expect(coordinator.trauma, 0.0);
      expect(coordinator.shakeOffset, Offset.zero);

      coordinator.triggerCatapultShake();
      expect(coordinator.trauma, closeTo(0.55, 0.01));

      coordinator.triggerGateSmashTremor();
      expect(coordinator.trauma, 1.0); // Clamped at 1.0

      coordinator.update(0.1);
      expect(coordinator.trauma, closeTo(0.85, 0.05));
      expect(coordinator.shakeOffset.distance, greaterThan(0.0));

      coordinator.update(1.0);
      expect(coordinator.trauma, 0.0);
      expect(coordinator.shakeOffset, Offset.zero);
      expect(coordinator.shakeRotation, 0.0);
    });

    // -------------------------------------------------------------------------
    // Module 2: Hit-Stop (30-50ms target freeze)
    // -------------------------------------------------------------------------
    test('Module 2: Hit-Stop - 30-50ms micro-pause time dilation', () async {
      expect(coordinator.isHitStopped, isFalse);
      expect(coordinator.timeDilation, 1.0);

      coordinator.triggerHitStop(duration: const Duration(milliseconds: 40));
      expect(coordinator.isHitStopped, isTrue);
      expect(coordinator.timeDilation, 0.05);

      await Future<void>.delayed(const Duration(milliseconds: 55));
      expect(coordinator.isHitStopped, isFalse);
      expect(coordinator.timeDilation, 1.0);
    });

    // -------------------------------------------------------------------------
    // Module 3: Rim Flash (Faction Aura Flashes)
    // -------------------------------------------------------------------------
    test('Module 3: Rim Flash - Faction aura tints and intensity decay', () {
      expect(coordinator.rimFlashIntensity, 0.0);

      // Elyos Cyan Aura Flash
      coordinator.triggerRimFlash(tint: SiegeFaction.elyos.auraColor, intensity: 1.0);
      expect(coordinator.rimFlashColor, const Color(0xFF00E5FF));
      expect(coordinator.rimFlashIntensity, 1.0);

      coordinator.update(0.1);
      expect(coordinator.rimFlashIntensity, closeTo(0.6, 0.05));

      // Asmodian Crimson Aura Flash
      coordinator.triggerRimFlash(tint: SiegeFaction.asmodian.auraColor, intensity: 0.9);
      expect(coordinator.rimFlashColor, const Color(0xFFFF2A4D));
      expect(coordinator.rimFlashIntensity, 0.9);

      coordinator.update(0.5);
      expect(coordinator.rimFlashIntensity, 0.0);
    });

    // -------------------------------------------------------------------------
    // Module 4: Weapon Trails
    // -------------------------------------------------------------------------
    test('Module 4: Weapon Trails - Arrow volleys and commander blade swing ribbons', () {
      expect(coordinator.weaponTrails, isEmpty);

      final double now = 100.0;
      coordinator.spawnSiegeArrowVolleyTrail(
        start: const Offset(50, 150),
        target: const Offset(200, 150),
        now: now,
      );

      expect(coordinator.weaponTrails.length, 1);
      final arrowTrail = coordinator.weaponTrails.first;
      expect(arrowTrail.points.length, 7);
      expect(arrowTrail.primaryColor, const Color(0xFFFFD54F));

      coordinator.spawnCommanderBladeSwingTrail(
        origin: const Offset(100, 100),
        angle: 0.0,
        now: now,
        isElyos: true,
      );

      expect(coordinator.weaponTrails.length, 2);
      final bladeTrail = coordinator.weaponTrails.last;
      expect(bladeTrail.primaryColor, const Color(0xFF00E5FF));
      expect(bladeTrail.points.length, 9);
    });

    // -------------------------------------------------------------------------
    // Module 5: Dynamic Decals
    // -------------------------------------------------------------------------
    test('Module 5: Dynamic Decals - Craters, wall scorches and expiration', () {
      expect(coordinator.decals, isEmpty);

      coordinator.spawnDecal(
        position: const Offset(150, 200),
        type: SiegeDecalType.burningCrater,
        radius: 40.0,
      );

      expect(coordinator.decals.length, 1);
      final decal = coordinator.decals.first;
      expect(decal.type, SiegeDecalType.burningCrater);
      expect(decal.opacity, closeTo(1.0, 0.05));
      expect(decal.isExpired, isFalse);

      coordinator.spawnDecal(
        position: const Offset(120, 180),
        type: SiegeDecalType.wallScorch,
        radius: 35.0,
      );

      coordinator.spawnDecal(
        position: const Offset(140, 210),
        type: SiegeDecalType.crackedEarthFissure,
        radius: 45.0,
      );

      expect(coordinator.decals.length, 3);
    });

    // -------------------------------------------------------------------------
    // Module 6: Particle Emitter
    // -------------------------------------------------------------------------
    test('Module 6: Particles - Emits smoke plumes, fiery embers and debris', () {
      expect(coordinator.particles, isEmpty);

      coordinator.emitSiegeBlastParticles(origin: const Offset(100, 100), count: 28);
      expect(coordinator.particles.length, 28);

      final hasSmoke = coordinator.particles.any((p) => p.type == SiegeParticleType.smokePlume);
      final hasEmbers = coordinator.particles.any((p) => p.type == SiegeParticleType.fieryEmber);
      final hasDebris = coordinator.particles.any((p) => p.type == SiegeParticleType.stoneDebris);
      final hasSparks = coordinator.particles.any((p) => p.type == SiegeParticleType.metalSpark);

      expect(hasSmoke, isTrue);
      expect(hasEmbers, isTrue);
      expect(hasDebris, isTrue);
      expect(hasSparks, isTrue);

      // Simulation update
      coordinator.update(0.1);
      for (final p in coordinator.particles) {
        expect(p.life, lessThan(1.0));
      }
    });

    // -------------------------------------------------------------------------
    // Module 7: Haptics
    // -------------------------------------------------------------------------
    test('Module 7: Haptics - Triggers heavy siege vibration pulses without error', () async {
      await expectLater(coordinator.triggerHeavySiegeHaptics(), completes);
      await expectLater(coordinator.triggerGateTremorHaptics(), completes);
      await expectLater(coordinator.triggerCommanderClashHaptics(), completes);
    });

    // -------------------------------------------------------------------------
    // Module 8: Floating Damage Numbers
    // -------------------------------------------------------------------------
    test('Module 8: Floating Damage Numbers - Multi-target mass battle damage text', () {
      expect(coordinator.damageNumbers, isEmpty);

      coordinator.spawnDamageNumber(
        position: const Offset(100, 100),
        amount: 3450,
        damageType: SiegeDamageType.catapultBoulder,
        isCritical: true,
      );

      expect(coordinator.damageNumbers.length, 1);
      final dmg = coordinator.damageNumbers.first;
      expect(dmg.text, contains('3450'));
      expect(dmg.isCritical, isTrue);
      expect(dmg.color, const Color(0xFFFFD700));

      coordinator.spawnMassBattleDamageVolley(
        center: const Offset(150, 150),
        damages: [1200, 890, 2400],
        damageType: SiegeDamageType.siegeArrowVolley,
      );

      expect(coordinator.damageNumbers.length, 4);

      coordinator.update(0.1);
      expect(coordinator.damageNumbers.first.position.dy, lessThan(100)); // Moves upward
    });

    // -------------------------------------------------------------------------
    // Module 9: Knockback & Troop Flinching
    // -------------------------------------------------------------------------
    test('Module 9: Knockback & Troop Flinching - Gate and troop recoil springs', () {
      expect(coordinator.fortressGateFlinch.offset, Offset.zero);
      expect(coordinator.defenderTroopFlinch.offset, Offset.zero);

      coordinator.applyGateSmashImpulse();
      expect(coordinator.fortressGateFlinch.velocity.dy, greaterThan(0.0));
      expect(coordinator.defenderTroopFlinch.velocity.dx, greaterThan(0.0));

      coordinator.update(0.05);
      expect(coordinator.fortressGateFlinch.offset.dy, greaterThan(0.0));
      expect(coordinator.defenderTroopFlinch.offset.dx, greaterThan(0.0));

      coordinator.applyCommanderClashImpulse();
      expect(coordinator.attackerCommanderFlinch.velocity.dx, lessThan(0.0));
      expect(coordinator.defenderCommanderFlinch.velocity.dx, greaterThan(0.0));
    });

    // -------------------------------------------------------------------------
    // Master Orchestrated Events (All 9 Modules Combined)
    // -------------------------------------------------------------------------
    test('Orchestrated Events: Catapult boulder strike triggers all 9 modules', () {
      coordinator.executeCatapultBoulderStrike(
        impactPoint: const Offset(120, 120),
        damage: 4800,
        isCritical: true,
      );

      // 1. Camera shake
      expect(coordinator.trauma, greaterThan(0.5));
      // 2. Hit-stop
      expect(coordinator.isHitStopped, isTrue);
      // 3. Rim flash
      expect(coordinator.rimFlashIntensity, greaterThan(0.9));
      // 4. Weapon trails
      expect(coordinator.weaponTrails, isNotEmpty);
      // 5. Decals
      expect(coordinator.decals, isNotEmpty);
      // 6. Particles
      expect(coordinator.particles, isNotEmpty);
      // 8. Damage numbers
      expect(coordinator.damageNumbers, isNotEmpty);
      expect(coordinator.damageNumbers.last.text, contains('4800'));
      // 9. Troop flinch
      expect(coordinator.defenderTroopFlinch.velocity.distance, greaterThan(0.0));
    });

    test('Orchestrated Events: Gate battering ram smash triggers all 9 modules', () {
      coordinator.executeGateSmashStrike(
        gateCenter: const Offset(150, 150),
        damage: 6200,
      );

      expect(coordinator.trauma, greaterThan(0.8));
      expect(coordinator.isHitStopped, isTrue);
      expect(coordinator.rimFlashColor, SiegeFaction.asmodian.auraColor);
      expect(coordinator.decals.length, 2); // Scorch + fissure
      expect(coordinator.particles, isNotEmpty);
      expect(coordinator.damageNumbers.last.text, contains('6200'));
      expect(coordinator.fortressGateFlinch.velocity.distance, greaterThan(0.0));
    });

    test('Orchestrated Events: Commander duel clash triggers all 9 modules', () {
      coordinator.executeCommanderDuelClash(
        clashPoint: const Offset(100, 100),
        attackerDamage: 3200,
        defenderDamage: 2800,
        isElyosAttacker: true,
      );

      expect(coordinator.trauma, greaterThan(0.4));
      expect(coordinator.isHitStopped, isTrue);
      expect(coordinator.rimFlashColor, SiegeFaction.elyos.auraColor);
      expect(coordinator.weaponTrails.length, 2); // Both blade trails
      expect(coordinator.damageNumbers.length, 2); // Reciprocal duel damage
      expect(coordinator.attackerCommanderFlinch.velocity.distance, greaterThan(0.0));
      expect(coordinator.defenderCommanderFlinch.velocity.distance, greaterThan(0.0));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget Tests for SiegeCombatViewport and BattleResultScreen
  // ---------------------------------------------------------------------------
  group('SiegeCombatViewport Widget Tests', () {
    testWidgets('Renders fortress gate, catapult, units, and tactical controls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SiegeCombatViewport(
              territoryName: 'Beluslan Kalesi',
              attackPower: 5000,
              defensePower: 4500,
              pointsGained: 15,
              isVictory: true,
              autoPlay: false,
              height: 320,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Beluslan Kalesi'), findsNothing); // Inside phase header
      expect(find.textContaining('KALE KAPISI'), findsOneWidget);
      expect(find.text('Mancınık'), findsNWidgets(2)); // Engine label + button
      expect(find.text('Koçbaşı'), findsNWidgets(2)); // Ram label + button
      expect(find.text('Düello'), findsOneWidget); // Duel button

      // Tap Mancınık tactical button
      await tester.tap(find.text('Mancınık').last);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Hasar:'), findsOneWidget);
    });

    testWidgets('Preserves battle scoring and stats in BattleResultScreen', (tester) async {
      const result = GuildWarAttackResult(
        success: true,
        message: 'Kuşatma zaferle sonuçlandı!',
        pointsGained: 25,
        attackPower: 7500,
        defensePower: 6000,
        territoryName: 'Reshanta Kalesi',
        defenderGuildName: 'Karanlık Lejyon',
        healthLost: 120,
        goldSpent: 500,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: BattleResultScreen(result: result),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('BÖLGE ELE GEÇİRİLDİ!'), findsOneWidget);
      expect(find.text('Reshanta Kalesi'), findsOneWidget);
      expect(find.text('7500'), findsOneWidget);
      expect(find.text('6000'), findsOneWidget);
      expect(find.text('+25'), findsOneWidget);
      expect(find.text('-120 HP'), findsOneWidget);
      expect(find.text('500 🪙'), findsOneWidget);

      // Verify the interactive Kuşatma Çarpışma Tekrarı is present
      expect(find.textContaining('KUŞATMA ÇARPIŞMA TEKRARI'), findsOneWidget);
    });
  });
}
