import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/utils/player_health.dart';
import 'package:gkk_flutter/core/utils/potion_health.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';

void main() {
  group('player_health', () {
    test('combat min is 20 percent floored', () {
      expect(playerCombatMinHealth(100), 20);
      expect(playerCombatMinHealth(150), 30);
    });

    test('wounded is 50 percent', () {
      expect(playerWoundedHealth(200), 100);
    });

    test('too low for combat below threshold', () {
      expect(isHealthTooLowForCombat(health: 19, maxHealth: 100), isTrue);
      expect(isHealthTooLowForCombat(health: 20, maxHealth: 100), isFalse);
    });

    test('status tiers', () {
      expect(
        resolveHealthStatus(health: 100, maxHealth: 100),
        PlayerHealthStatus.healthy,
      );
      expect(
        resolveHealthStatus(health: 40, maxHealth: 100),
        PlayerHealthStatus.wounded,
      );
      expect(
        resolveHealthStatus(health: 15, maxHealth: 100),
        PlayerHealthStatus.critical,
      );
    });

    test('gem heal cost scales with missing hp', () {
      expect(gemHealthHealCost(health: 100, maxHealth: 100, level: 5), 0);
      expect(gemHealthHealCost(health: 50, maxHealth: 100, level: 5), 4);
    });

    test('regen duration formatting', () {
      expect(formatRegenDuration(3600), '1 sa');
      expect(formatRegenDuration(0), 'Simdi');
    });
  });

  group('potion_health', () {
    test('effective heal respects tolerance', () {
      expect(
        effectiveHealthRestore(baseRestore: 1000, tolerance: 0),
        1000,
      );
      expect(
        effectiveHealthRestore(baseRestore: 1000, tolerance: 50),
        650,
      );
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
        '+5000 can',
      );
    });
  });
}
