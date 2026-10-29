import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/utils/player_health.dart';
import 'package:gkk_flutter/core/utils/potion_health.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';

void main() {
  group('player_health - Thresholds & Boundary Logic', () {
    test('combat min is 20 percent floored and handles boundaries', () {
      expect(playerCombatMinHealth(100), 20);
      expect(playerCombatMinHealth(150), 30);
      expect(playerCombatMinHealth(1), 1);
      expect(playerCombatMinHealth(0), 1);
      expect(playerCombatMinHealth(-50), 1);
    });

    test('wounded is 50 percent floored and handles boundaries', () {
      expect(playerWoundedHealth(200), 100);
      expect(playerWoundedHealth(100), 50);
      expect(playerWoundedHealth(101), 50);
      expect(playerWoundedHealth(1), 1);
      expect(playerWoundedHealth(0), 1);
      expect(playerWoundedHealth(-10), 1);
    });

    test('player health floor is 15 percent floored', () {
      expect(playerHealthFloor(100), 15);
      expect(playerHealthFloor(200), 30);
      expect(playerHealthFloor(0), 1);
      expect(playerHealthFloor(-5), 1);
    });

    test('too low for combat below threshold and with 0/negative hp', () {
      expect(isHealthTooLowForCombat(health: 19, maxHealth: 100), isTrue);
      expect(isHealthTooLowForCombat(health: 20, maxHealth: 100), isFalse);
      expect(isHealthTooLowForCombat(health: 50, maxHealth: 100), isFalse);
      expect(isHealthTooLowForCombat(health: 0, maxHealth: 100), isTrue);
      expect(isHealthTooLowForCombat(health: -10, maxHealth: 100), isTrue);
      expect(isHealthTooLowForCombat(health: 50, maxHealth: 0), isTrue);
      expect(isHealthTooLowForCombat(health: 0, maxHealth: 0), isTrue);
      expect(isHealthTooLowForCombat(health: 50, maxHealth: -20), isTrue);
    });

    test('isLowHealthAlert flags conditions under wounded threshold', () {
      expect(isLowHealthAlert(health: 10, maxHealth: 100), isTrue);
      expect(isLowHealthAlert(health: 49, maxHealth: 100), isTrue);
      expect(isLowHealthAlert(health: 50, maxHealth: 100), isFalse);
      expect(isLowHealthAlert(health: 100, maxHealth: 100), isFalse);
      expect(isLowHealthAlert(health: 0, maxHealth: 0), isFalse);
      expect(
        isLowHealthAlert(health: 70, maxHealth: 100, alertFraction: 0.80),
        isTrue,
      );
    });

    test('hasWoundedCombatPenalty checks wounded window', () {
      expect(hasWoundedCombatPenalty(health: 19, maxHealth: 100), isFalse);
      expect(hasWoundedCombatPenalty(health: 20, maxHealth: 100), isTrue);
      expect(hasWoundedCombatPenalty(health: 49, maxHealth: 100), isTrue);
      expect(hasWoundedCombatPenalty(health: 50, maxHealth: 100), isFalse);
      expect(hasWoundedCombatPenalty(health: 100, maxHealth: 100), isFalse);
      expect(hasWoundedCombatPenalty(health: 0, maxHealth: 100), isFalse);
      expect(hasWoundedCombatPenalty(health: -5, maxHealth: 100), isFalse);
      expect(hasWoundedCombatPenalty(health: 30, maxHealth: 0), isFalse);
    });

    test('healthFraction calculates clamped ratio with boundary defense', () {
      expect(healthFraction(health: 100, maxHealth: 100), 1.0);
      expect(healthFraction(health: 50, maxHealth: 100), 0.5);
      expect(healthFraction(health: 0, maxHealth: 100), 0.0);
      expect(healthFraction(health: -20, maxHealth: 100), 0.0);
      expect(healthFraction(health: 150, maxHealth: 100), 1.0);
      expect(healthFraction(health: 50, maxHealth: 0), 0.0);
      expect(healthFraction(health: 0, maxHealth: 0), 0.0);
      expect(healthFraction(health: 50, maxHealth: -10), 0.0);
    });

    test('formatHealthRatio displays formatted string', () {
      expect(formatHealthRatio(50, 100), '50/100');
      expect(formatHealthRatio(0, 100), '0/100');
      expect(formatHealthRatio(0, 0), '0/0');
    });
  });

  group('player_health - Status Resolution', () {
    test('status tiers resolve correctly across all HP bands', () {
      expect(
        resolveHealthStatus(health: 100, maxHealth: 100),
        PlayerHealthStatus.healthy,
      );
      expect(
        resolveHealthStatus(health: 120, maxHealth: 100),
        PlayerHealthStatus.healthy,
      );
      expect(
        resolveHealthStatus(health: 99, maxHealth: 100),
        PlayerHealthStatus.recovering,
      );
      expect(
        resolveHealthStatus(health: 50, maxHealth: 100),
        PlayerHealthStatus.recovering,
      );
      expect(
        resolveHealthStatus(health: 49, maxHealth: 100),
        PlayerHealthStatus.wounded,
      );
      expect(
        resolveHealthStatus(health: 20, maxHealth: 100),
        PlayerHealthStatus.wounded,
      );
      expect(
        resolveHealthStatus(health: 19, maxHealth: 100),
        PlayerHealthStatus.critical,
      );
      expect(
        resolveHealthStatus(health: 1, maxHealth: 100),
        PlayerHealthStatus.critical,
      );
      expect(
        resolveHealthStatus(health: 0, maxHealth: 100),
        PlayerHealthStatus.critical,
      );
      expect(
        resolveHealthStatus(health: -10, maxHealth: 100),
        PlayerHealthStatus.critical,
      );
      expect(
        resolveHealthStatus(health: 0, maxHealth: 0),
        PlayerHealthStatus.critical,
      );
      expect(
        resolveHealthStatus(health: -5, maxHealth: -5),
        PlayerHealthStatus.critical,
      );
    });

    test('restricted status resolution handles hospital and prison', () {
      expect(
        resolveHealthStatus(health: 100, maxHealth: 100, restricted: true),
        PlayerHealthStatus.restricted,
      );
      expect(
        resolveHealthStatus(health: 60, maxHealth: 100, restricted: true),
        PlayerHealthStatus.restricted,
      );
      expect(
        resolveHealthStatus(health: 40, maxHealth: 100, restricted: true),
        PlayerHealthStatus.wounded,
      );
      expect(
        resolveHealthStatus(health: 15, maxHealth: 100, restricted: true),
        PlayerHealthStatus.critical,
      );
      expect(
        resolveHealthStatus(health: 0, maxHealth: 100, restricted: true),
        PlayerHealthStatus.critical,
      );
      expect(
        resolveHealthStatus(health: -20, maxHealth: 100, restricted: true),
        PlayerHealthStatus.critical,
      );
    });

    test('health status label, tip, and color coverage', () {
      for (final PlayerHealthStatus status in PlayerHealthStatus.values) {
        expect(healthStatusLabel(status), isNotEmpty);
        expect(healthStatusTip(status), isNotEmpty);
        expect(healthStatusColor(status), isA<Color>());
      }

      expect(healthStatusLabel(PlayerHealthStatus.healthy), 'Saglikli');
      expect(healthStatusLabel(PlayerHealthStatus.recovering), 'Iyilesiyor');
      expect(healthStatusLabel(PlayerHealthStatus.wounded), 'Yarali');
      expect(healthStatusLabel(PlayerHealthStatus.critical), 'Kritik');
      expect(healthStatusLabel(PlayerHealthStatus.restricted), 'Kisitli');
    });
  });

  group('player_health - Clamping & Boundary Helpers', () {
    test('clampPlayerHealth keeps value within [minHealth, maxHealth]', () {
      expect(clampPlayerHealth(health: 50, maxHealth: 100), 50);
      expect(clampPlayerHealth(health: -15, maxHealth: 100), 0);
      expect(clampPlayerHealth(health: 150, maxHealth: 100), 100);
      expect(clampPlayerHealth(health: 0, maxHealth: 100), 0);
      expect(clampPlayerHealth(health: 100, maxHealth: 100), 100);

      // Custom minimum threshold
      expect(
        clampPlayerHealth(health: 10, maxHealth: 100, minHealth: 20),
        20,
      );
      // Inverted minHealth boundary
      expect(
        clampPlayerHealth(health: 50, maxHealth: 100, minHealth: 120),
        100,
      );
      // Negative minHealth sanitized to 0
      expect(
        clampPlayerHealth(health: 5, maxHealth: 100, minHealth: -10),
        5,
      );
      // Zero maxHealth
      expect(clampPlayerHealth(health: 50, maxHealth: 0), 0);
      expect(clampPlayerHealth(health: 50, maxHealth: -20), 0);
    });

    test('isHealthZeroOrDead detects 0 and negative health', () {
      expect(isHealthZeroOrDead(0), isTrue);
      expect(isHealthZeroOrDead(-1), isTrue);
      expect(isHealthZeroOrDead(-999), isTrue);
      expect(isHealthZeroOrDead(1), isFalse);
      expect(isHealthZeroOrDead(100), isFalse);
    });

    test('isHealthFull verifies maximum capacity', () {
      expect(isHealthFull(health: 100, maxHealth: 100), isTrue);
      expect(isHealthFull(health: 120, maxHealth: 100), isTrue);
      expect(isHealthFull(health: 99, maxHealth: 100), isFalse);
      expect(isHealthFull(health: 0, maxHealth: 100), isFalse);
      expect(isHealthFull(health: 0, maxHealth: 0), isFalse);
      expect(isHealthFull(health: 10, maxHealth: -10), isFalse);
    });
  });

  group('player_health - Damage Calculations (Shields, Buffs, 0 HP, Overflow)', () {
    test('calculateEffectiveDamage applies defense buffs and vulnerability', () {
      expect(calculateEffectiveDamage(rawDamage: 100), 100);
      expect(
        calculateEffectiveDamage(
          rawDamage: 100,
          defenseReductionMultiplier: 0.20,
        ),
        80,
      );
      expect(
        calculateEffectiveDamage(
          rawDamage: 100,
          defenseReductionMultiplier: 0.50,
        ),
        50,
      );
      expect(
        calculateEffectiveDamage(
          rawDamage: 100,
          defenseReductionMultiplier: 1.0,
        ),
        0,
      );
      expect(
        calculateEffectiveDamage(
          rawDamage: 100,
          defenseReductionMultiplier: 1.5,
        ),
        0,
      );
      expect(
        calculateEffectiveDamage(
          rawDamage: 100,
          defenseReductionMultiplier: -0.25,
        ),
        100,
      );
      expect(
        calculateEffectiveDamage(
          rawDamage: 100,
          vulnerabilityMultiplier: 0.25,
        ),
        125,
      );
      expect(calculateEffectiveDamage(rawDamage: 0), 0);
      expect(calculateEffectiveDamage(rawDamage: -50), 0);
    });

    test('applyDamageToPlayer normal damage without shield', () {
      final DamageResult result = applyDamageToPlayer(
        currentHealth: 100,
        maxHealth: 100,
        rawDamage: 30,
      );

      expect(result.newHealth, 70);
      expect(result.newShield, 0);
      expect(result.damageDealtToHealth, 30);
      expect(result.damageAbsorbedByShield, 0);
      expect(result.mitigatedDamage, 30);
      expect(result.isFatal, isFalse);
      expect(result.shieldDepleted, isFalse);
    });

    test('applyDamageToPlayer ignores zero and negative damage', () {
      final DamageResult zeroResult = applyDamageToPlayer(
        currentHealth: 100,
        maxHealth: 100,
        rawDamage: 0,
      );
      expect(zeroResult.newHealth, 100);
      expect(zeroResult.damageDealtToHealth, 0);
      expect(zeroResult.isFatal, isFalse);

      final DamageResult negativeResult = applyDamageToPlayer(
        currentHealth: 100,
        maxHealth: 100,
        rawDamage: -45,
      );
      expect(negativeResult.newHealth, 100);
      expect(negativeResult.damageDealtToHealth, 0);
      expect(negativeResult.isFatal, isFalse);
    });

    test('applyDamageToPlayer handles lethal and overkill damage', () {
      final DamageResult exactKill = applyDamageToPlayer(
        currentHealth: 50,
        maxHealth: 100,
        rawDamage: 50,
      );
      expect(exactKill.newHealth, 0);
      expect(exactKill.damageDealtToHealth, 50);
      expect(exactKill.isFatal, isTrue);

      final DamageResult overKill = applyDamageToPlayer(
        currentHealth: 50,
        maxHealth: 100,
        rawDamage: 200,
      );
      expect(overKill.newHealth, 0);
      expect(overKill.damageDealtToHealth, 200);
      expect(overKill.isFatal, isTrue);
    });

    test('applyDamageToPlayer with already dead character remains 0 HP', () {
      final DamageResult result = applyDamageToPlayer(
        currentHealth: 0,
        maxHealth: 100,
        rawDamage: 50,
      );
      expect(result.newHealth, 0);
      expect(result.isFatal, isTrue);
      expect(result.damageDealtToHealth, 0);

      final DamageResult negHpResult = applyDamageToPlayer(
        currentHealth: -15,
        maxHealth: 100,
        rawDamage: 50,
      );
      expect(negHpResult.newHealth, 0);
      expect(negHpResult.isFatal, isTrue);
    });

    test('applyDamageToPlayer partial shield absorption', () {
      final DamageResult result = applyDamageToPlayer(
        currentHealth: 100,
        maxHealth: 100,
        rawDamage: 40,
        currentShield: 60,
      );

      expect(result.newHealth, 100);
      expect(result.newShield, 20);
      expect(result.damageAbsorbedByShield, 40);
      expect(result.damageDealtToHealth, 0);
      expect(result.isFatal, isFalse);
      expect(result.shieldDepleted, isFalse);
    });

    test('applyDamageToPlayer exact shield break', () {
      final DamageResult result = applyDamageToPlayer(
        currentHealth: 100,
        maxHealth: 100,
        rawDamage: 50,
        currentShield: 50,
      );

      expect(result.newHealth, 100);
      expect(result.newShield, 0);
      expect(result.damageAbsorbedByShield, 50);
      expect(result.damageDealtToHealth, 0);
      expect(result.isFatal, isFalse);
      expect(result.shieldDepleted, isTrue);
    });

    test('applyDamageToPlayer shield penetration and remainder damage', () {
      final DamageResult result = applyDamageToPlayer(
        currentHealth: 100,
        maxHealth: 100,
        rawDamage: 75,
        currentShield: 25,
      );

      expect(result.newHealth, 50);
      expect(result.newShield, 0);
      expect(result.damageAbsorbedByShield, 25);
      expect(result.damageDealtToHealth, 50);
      expect(result.isFatal, isFalse);
      expect(result.shieldDepleted, isTrue);
    });

    test('applyDamageToPlayer shield plus lethal penetration', () {
      final DamageResult result = applyDamageToPlayer(
        currentHealth: 30,
        maxHealth: 100,
        rawDamage: 100,
        currentShield: 20,
      );

      expect(result.newHealth, 0);
      expect(result.newShield, 0);
      expect(result.damageAbsorbedByShield, 20);
      expect(result.damageDealtToHealth, 80);
      expect(result.isFatal, isTrue);
      expect(result.shieldDepleted, isTrue);
    });

    test('applyDamageToPlayer sanitizes negative shield input', () {
      final DamageResult result = applyDamageToPlayer(
        currentHealth: 100,
        maxHealth: 100,
        rawDamage: 30,
        currentShield: -20,
      );

      expect(result.newHealth, 70);
      expect(result.newShield, 0);
      expect(result.damageAbsorbedByShield, 0);
    });

    test('applyDamageToPlayer combines defense reduction and shields', () {
      final DamageResult result = applyDamageToPlayer(
        currentHealth: 100,
        maxHealth: 100,
        rawDamage: 100,
        currentShield: 30,
        defenseReductionMultiplier: 0.40,
      );

      // 100 raw * 0.60 = 60 mitigated
      // 30 absorbed by shield, 30 damage to health
      expect(result.mitigatedDamage, 60);
      expect(result.damageAbsorbedByShield, 30);
      expect(result.newShield, 0);
      expect(result.damageDealtToHealth, 30);
      expect(result.newHealth, 70);
      expect(result.shieldDepleted, isTrue);
    });

    test('applyDamageToPlayer handles extreme large integer overflow', () {
      final DamageResult result = applyDamageToPlayer(
        currentHealth: 1000,
        maxHealth: 1000,
        rawDamage: 2000000000,
      );

      expect(result.newHealth, 0);
      expect(result.isFatal, isTrue);
      expect(result.damageDealtToHealth, 2000000000);
    });

    test('DamageResult equals, hashCode, and toString coverage', () {
      const DamageResult d1 = DamageResult(
        newHealth: 50,
        newShield: 10,
        damageDealtToHealth: 20,
        damageAbsorbedByShield: 15,
        mitigatedDamage: 35,
        isFatal: false,
        shieldDepleted: false,
      );
      const DamageResult d2 = DamageResult(
        newHealth: 50,
        newShield: 10,
        damageDealtToHealth: 20,
        damageAbsorbedByShield: 15,
        mitigatedDamage: 35,
        isFatal: false,
        shieldDepleted: false,
      );
      const DamageResult d3 = DamageResult(
        newHealth: 0,
        newShield: 0,
        damageDealtToHealth: 70,
        damageAbsorbedByShield: 0,
        mitigatedDamage: 70,
        isFatal: true,
        shieldDepleted: false,
      );

      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2.hashCode));
      expect(d1 == d3, isFalse);
      expect(d1.toString(), contains('DamageResult'));
    });
  });

  group('player_health - Healing Calculations (Overflow, Revive, Multipliers)', () {
    test('applyHealingToPlayer normal healing within missing health', () {
      final HealResult result = applyHealingToPlayer(
        currentHealth: 40,
        maxHealth: 100,
        rawHeal: 30,
      );

      expect(result.newHealth, 70);
      expect(result.actualHealed, 30);
      expect(result.overheal, 0);
      expect(result.isFullyHealed, isFalse);
    });

    test('applyHealingToPlayer exact full heal', () {
      final HealResult result = applyHealingToPlayer(
        currentHealth: 40,
        maxHealth: 100,
        rawHeal: 60,
      );

      expect(result.newHealth, 100);
      expect(result.actualHealed, 60);
      expect(result.overheal, 0);
      expect(result.isFullyHealed, isTrue);
    });

    test('applyHealingToPlayer overheal and capacity capping', () {
      final HealResult result = applyHealingToPlayer(
        currentHealth: 80,
        maxHealth: 100,
        rawHeal: 50,
      );

      expect(result.newHealth, 100);
      expect(result.actualHealed, 20);
      expect(result.overheal, 30);
      expect(result.isFullyHealed, isTrue);
    });

    test('applyHealingToPlayer ignores zero and negative heal', () {
      final HealResult zeroResult = applyHealingToPlayer(
        currentHealth: 50,
        maxHealth: 100,
        rawHeal: 0,
      );
      expect(zeroResult.newHealth, 50);
      expect(zeroResult.actualHealed, 0);
      expect(zeroResult.overheal, 0);

      final HealResult negResult = applyHealingToPlayer(
        currentHealth: 50,
        maxHealth: 100,
        rawHeal: -30,
      );
      expect(negResult.newHealth, 50);
      expect(negResult.actualHealed, 0);
      expect(negResult.overheal, 0);
    });

    test('applyHealingToPlayer dead player revive barrier', () {
      final HealResult noRevive = applyHealingToPlayer(
        currentHealth: 0,
        maxHealth: 100,
        rawHeal: 50,
        allowRevive: false,
      );
      expect(noRevive.newHealth, 0);
      expect(noRevive.actualHealed, 0);
      expect(noRevive.isFullyHealed, isFalse);

      final HealResult withRevive = applyHealingToPlayer(
        currentHealth: 0,
        maxHealth: 100,
        rawHeal: 50,
        allowRevive: true,
      );
      expect(withRevive.newHealth, 50);
      expect(withRevive.actualHealed, 50);
      expect(withRevive.overheal, 0);
      expect(withRevive.isFullyHealed, isFalse);
    });

    test('applyHealingToPlayer on full health generates pure overheal', () {
      final HealResult result = applyHealingToPlayer(
        currentHealth: 100,
        maxHealth: 100,
        rawHeal: 40,
      );

      expect(result.newHealth, 100);
      expect(result.actualHealed, 0);
      expect(result.overheal, 40);
      expect(result.isFullyHealed, isTrue);
    });

    test('applyHealingToPlayer healing multiplier buff', () {
      final HealResult result = applyHealingToPlayer(
        currentHealth: 40,
        maxHealth: 100,
        rawHeal: 20,
        healingMultiplier: 1.5,
      );

      // 20 * 1.5 = 30 effective heal
      expect(result.newHealth, 70);
      expect(result.actualHealed, 30);
      expect(result.overheal, 0);
    });

    test('applyHealingToPlayer invalid maxHealth', () {
      final HealResult result = applyHealingToPlayer(
        currentHealth: 50,
        maxHealth: 0,
        rawHeal: 20,
      );

      expect(result.newHealth, 0);
      expect(result.actualHealed, 0);
      expect(result.isFullyHealed, isFalse);
    });

    test('HealResult equals, hashCode, and toString coverage', () {
      const HealResult h1 = HealResult(
        newHealth: 80,
        actualHealed: 30,
        overheal: 10,
        isFullyHealed: false,
      );
      const HealResult h2 = HealResult(
        newHealth: 80,
        actualHealed: 30,
        overheal: 10,
        isFullyHealed: false,
      );
      const HealResult h3 = HealResult(
        newHealth: 100,
        actualHealed: 20,
        overheal: 0,
        isFullyHealed: true,
      );

      expect(h1, equals(h2));
      expect(h1.hashCode, equals(h2.hashCode));
      expect(h1 == h3, isFalse);
      expect(h1.toString(), contains('HealResult'));
    });
  });

  group('player_health - Shield Application Calculations', () {
    test('applyShieldToPlayer uncapped addition', () {
      final ShieldApplyResult r1 = applyShieldToPlayer(
        currentShield: 0,
        shieldAmount: 50,
      );
      expect(r1.newShield, 50);
      expect(r1.actualShieldAdded, 50);
      expect(r1.overflowShield, 0);

      final ShieldApplyResult r2 = applyShieldToPlayer(
        currentShield: 50,
        shieldAmount: 30,
      );
      expect(r2.newShield, 80);
      expect(r2.actualShieldAdded, 30);
      expect(r2.overflowShield, 0);
    });

    test('applyShieldToPlayer capped by maxShield', () {
      final ShieldApplyResult r1 = applyShieldToPlayer(
        currentShield: 70,
        shieldAmount: 50,
        maxShield: 100,
      );
      expect(r1.newShield, 100);
      expect(r1.actualShieldAdded, 30);
      expect(r1.overflowShield, 20);

      final ShieldApplyResult r2 = applyShieldToPlayer(
        currentShield: 100,
        shieldAmount: 40,
        maxShield: 100,
      );
      expect(r2.newShield, 100);
      expect(r2.actualShieldAdded, 0);
      expect(r2.overflowShield, 40);
    });

    test('applyShieldToPlayer ignores zero and negative shield', () {
      final ShieldApplyResult zero = applyShieldToPlayer(
        currentShield: 30,
        shieldAmount: 0,
      );
      expect(zero.newShield, 30);
      expect(zero.actualShieldAdded, 0);

      final ShieldApplyResult neg = applyShieldToPlayer(
        currentShield: 30,
        shieldAmount: -20,
      );
      expect(neg.newShield, 30);
      expect(neg.actualShieldAdded, 0);
    });

    test('applyShieldToPlayer sanitizes negative current shield', () {
      final ShieldApplyResult result = applyShieldToPlayer(
        currentShield: -15,
        shieldAmount: 40,
      );
      expect(result.newShield, 40);
      expect(result.actualShieldAdded, 40);
    });

    test('applyShieldToPlayer multiplier buff', () {
      final ShieldApplyResult result = applyShieldToPlayer(
        currentShield: 0,
        shieldAmount: 100,
        shieldMultiplier: 1.25,
      );
      expect(result.newShield, 125);
      expect(result.actualShieldAdded, 125);
    });

    test('ShieldApplyResult equals, hashCode, and toString coverage', () {
      const ShieldApplyResult s1 = ShieldApplyResult(
        newShield: 50,
        actualShieldAdded: 30,
        overflowShield: 10,
      );
      const ShieldApplyResult s2 = ShieldApplyResult(
        newShield: 50,
        actualShieldAdded: 30,
        overflowShield: 10,
      );
      const ShieldApplyResult s3 = ShieldApplyResult(
        newShield: 100,
        actualShieldAdded: 50,
        overflowShield: 0,
      );

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1 == s3, isFalse);
      expect(s1.toString(), contains('ShieldApplyResult'));
    });
  });

  group('player_health - Economy & Passive Regen Math', () {
    test('gem heal cost scales with missing hp and player level tiers', () {
      expect(gemHealthHealCost(health: 100, maxHealth: 100, level: 5), 0);
      expect(gemHealthHealCost(health: 50, maxHealth: 100, level: 5), 4);
      expect(gemHealthHealCost(health: 0, maxHealth: 100, level: 5), 8);
      expect(gemHealthHealCost(health: -20, maxHealth: 100, level: 5), 8);
      expect(gemHealthHealCost(health: 50, maxHealth: 100, level: 15), 6);
      expect(gemHealthHealCost(health: 50, maxHealth: 100, level: 25), 9);
      expect(gemHealthHealCost(health: 50, maxHealth: 100, level: 0), 4);
      expect(gemHealthHealCost(health: 50, maxHealth: 0, level: 5), 0);
      expect(gemHealthHealCost(health: 50, maxHealth: -10, level: 5), 0);
    });

    test('estimateSecondsToFullHealth calculation and alchemist multiplier', () {
      expect(estimateSecondsToFullHealth(health: 100, maxHealth: 100), 0);
      // Missing 50% without bonus (20h pool = 72000s) -> 36000s
      expect(estimateSecondsToFullHealth(health: 50, maxHealth: 100), 36000);
      // Missing 50% with Alchemist 1.5x bonus -> 24000s
      expect(
        estimateSecondsToFullHealth(
          health: 50,
          maxHealth: 100,
          alchemistBonus: true,
        ),
        24000,
      );
      expect(estimateSecondsToFullHealth(health: 0, maxHealth: 100), 72000);
      expect(estimateSecondsToFullHealth(health: -10, maxHealth: 100), 72000);
      expect(estimateSecondsToFullHealth(health: 50, maxHealth: 0), 0);
    });

    test('estimatePassiveHealthRegen points gained over elapsed time', () {
      expect(
        estimatePassiveHealthRegen(
          currentHealth: 100,
          maxHealth: 100,
          elapsedSeconds: 3600,
        ),
        0,
      );
      expect(
        estimatePassiveHealthRegen(
          currentHealth: 500,
          maxHealth: 1000,
          elapsedSeconds: 0,
        ),
        0,
      );
      expect(
        estimatePassiveHealthRegen(
          currentHealth: 500,
          maxHealth: 1000,
          elapsedSeconds: -100,
        ),
        0,
      );
      // 1000 maxHealth, 3600s (1h) at 5%/h -> 50 HP gained
      expect(
        estimatePassiveHealthRegen(
          currentHealth: 500,
          maxHealth: 1000,
          elapsedSeconds: 3600,
        ),
        50,
      );
      // With Alchemist bonus (1.5x) -> 75 HP gained
      expect(
        estimatePassiveHealthRegen(
          currentHealth: 500,
          maxHealth: 1000,
          elapsedSeconds: 3600,
          alchemistBonus: true,
        ),
        75,
      );
      // Capped at missing health (no overheal)
      expect(
        estimatePassiveHealthRegen(
          currentHealth: 980,
          maxHealth: 1000,
          elapsedSeconds: 3600,
        ),
        20,
      );
    });

    test('regen duration formatting across seconds, minutes, hours, and days', () {
      expect(formatRegenDuration(0), 'Simdi');
      expect(formatRegenDuration(-15), 'Simdi');
      expect(formatRegenDuration(45), '45 sn');
      expect(formatRegenDuration(120), '2 dk');
      expect(formatRegenDuration(3600), '1 sa');
      expect(formatRegenDuration(3660), '1 sa 1 dk');
      expect(formatRegenDuration(172800), '2 gun');
      expect(formatRegenDuration(180000), '2 gun 2 sa');
    });

    test('healthRegenPercentPerHour rates', () {
      expect(healthRegenPercentPerHour(), 5.0);
      expect(healthRegenPercentPerHour(alchemistBonus: true), 7.5);
    });
  });

  group('potion_health - Potion Health Integration', () {
    test('effective heal respects tolerance and percentage items', () {
      expect(
        effectiveHealthRestore(baseRestore: 1000, tolerance: 0),
        1000,
      );
      expect(
        effectiveHealthRestore(baseRestore: 1000, tolerance: 50),
        650,
      );
      expect(
        effectiveHealthRestore(
          baseRestore: 1000,
          tolerance: 0,
          alchemistBonus: true,
        ),
        1000,
      );

      // Percentage healing items
      expect(
        effectiveHealthRestore(
          baseRestore: 0,
          tolerance: 0,
          itemId: 'potion_health_minor',
          maxHealth: 1000,
        ),
        250,
      );
      expect(
        effectiveHealthRestore(
          baseRestore: 0,
          tolerance: 0,
          itemId: 'potion_health_major',
          maxHealth: 1000,
        ),
        500,
      );
      expect(
        effectiveHealthRestore(
          baseRestore: 0,
          tolerance: 0,
          itemId: 'potion_health_supreme',
          maxHealth: 1000,
        ),
        1000,
      );
      expect(
        effectiveHealthRestore(
          baseRestore: 0,
          tolerance: 0,
          itemId: 'han_item_restoration',
          maxHealth: 1000,
        ),
        400,
      );
    });

    test('healthPotionHealFraction lookup', () {
      expect(healthPotionHealFraction('potion_health_minor'), 0.25);
      expect(healthPotionHealFraction('potion_health_major'), 0.50);
      expect(healthPotionHealFraction('potion_health_supreme'), 1.0);
      expect(healthPotionHealFraction('han_item_restoration'), 0.40);
      expect(healthPotionHealFraction('unknown_potion'), isNull);
    });

    test('health potion label for inventory item', () {
      const InventoryItem item = InventoryItem(
        rowId: 'r1',
        itemId: 'potion_health_minor',
        quantity: 1,
        slotPosition: 0,
        isEquipped: false,
        equippedSlot: '',
        enhancementLevel: 0,
        isFavorite: false,
        pendingSync: false,
        name: 'Minor HP',
        description: '',
        icon: '',
        itemType: ItemType.potion,
        rarity: Rarity.common,
        basePrice: 0,
        vendorSellPrice: 0,
        attack: 0,
        defense: 0,
        health: 0,
        power: 0,
        luck: 0,
        mana: 0,
        equipSlot: EquipSlot.none,
        weaponType: WeaponType.none,
        armorType: ArmorType.none,
        requiredLevel: 1,
        canEnhance: false,
        maxEnhancement: 0,
        isStackable: true,
        maxStack: 99,
        isTradeable: true,
        potionType: PotionType.health,
        energyRestore: 0,
        healthRestore: 5000,
        toleranceIncrease: 1,
      );

      expect(
        healthPotionEffectLabel(item: item, tolerance: 0),
        '+25% max can',
      );
      expect(
        healthPotionEffectLabel(item: item, tolerance: 0, maxHealth: 1000),
        '+25% can (~250)',
      );

      // Non health potion item returns null
      const InventoryItem energyItem = InventoryItem(
        rowId: 'r2',
        itemId: 'potion_energy_minor',
        quantity: 1,
        slotPosition: 1,
        isEquipped: false,
        equippedSlot: '',
        enhancementLevel: 0,
        isFavorite: false,
        pendingSync: false,
        name: 'Minor Energy',
        description: '',
        icon: '',
        itemType: ItemType.potion,
        rarity: Rarity.common,
        basePrice: 0,
        vendorSellPrice: 0,
        attack: 0,
        defense: 0,
        health: 0,
        power: 0,
        luck: 0,
        mana: 0,
        equipSlot: EquipSlot.none,
        weaponType: WeaponType.none,
        armorType: ArmorType.none,
        requiredLevel: 1,
        canEnhance: false,
        maxEnhancement: 0,
        isStackable: true,
        maxStack: 99,
        isTradeable: true,
        potionType: PotionType.energy,
        energyRestore: 20,
        healthRestore: 0,
        toleranceIncrease: 1,
      );
      expect(
        healthPotionEffectLabel(item: energyItem, tolerance: 0),
        isNull,
      );
    });

    test('healthPotionUseMessage formatting', () {
      expect(
        healthPotionUseMessage(
          itemName: 'Can İksiri',
          health: 80,
          maxHealth: 100,
          healedAmount: 30,
        ),
        'Can İksiri kullanildi. Can: 80/100 (+30)',
      );
      expect(
        healthPotionUseMessage(
          itemName: 'Can İksiri',
          health: 100,
          maxHealth: 100,
          healedAmount: 0,
        ),
        'Can İksiri kullanildi.',
      );
    });
  });
}
