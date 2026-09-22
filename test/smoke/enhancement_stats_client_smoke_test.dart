import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/utils/enhancement_stats.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';

InventoryItem _item({
  int attack = 10000,
  int defense = 0,
  int health = 0,
  int luck = 3500,
  int enhancement = 0,
}) {
  return InventoryItem(
    rowId: 'r1',
    itemId: 'wpn_test',
    quantity: 1,
    slotPosition: 0,
    isEquipped: false,
    equippedSlot: '',
    enhancementLevel: enhancement,
    isFavorite: false,
    pendingSync: false,
    name: 'Test',
    description: '',
    icon: '',
    itemType: ItemType.weapon,
    rarity: Rarity.mythic,
    basePrice: 0,
    vendorSellPrice: 0,
    attack: attack,
    defense: defense,
    health: health,
    power: attack + defense + (health ~/ 10) + (luck * 2),
    luck: luck,
    mana: 0,
    equipSlot: EquipSlot.weapon,
    weaponType: WeaponType.sword,
    armorType: ArmorType.none,
    requiredLevel: 1,
    canEnhance: true,
    maxEnhancement: 10,
    isStackable: false,
    maxStack: 1,
    isTradeable: true,
    potionType: PotionType.none,
    energyRestore: 0,
    healthRestore: 0,
    toleranceIncrease: 0,
  );
}

void main() {
  group('enhancement_stats Faz 2 piecewise', () {
    test('multiplier table +0..+10', () {
      expect(enhancementMultiplier(0), 1.0);
      expect(enhancementMultiplier(1), closeTo(1.12, 1e-9));
      expect(enhancementMultiplier(5), closeTo(1.60, 1e-9));
      expect(enhancementMultiplier(6), closeTo(1.72, 1e-9));
      expect(enhancementMultiplier(7), closeTo(1.80, 1e-9));
      expect(enhancementMultiplier(10), closeTo(2.04, 1e-9));
    });

    test('mythic-style ATK/LUCK at +10 uses 2.04', () {
      expect(enhancedStat(20000, 10), 40800);
      expect(enhancedStat(3500, 10), 7140);
    });

    test('format shows effective only', () {
      expect(formatEnhancedStat(10000, 0), '10000');
      expect(formatEnhancedStat(10000, 1), '11200');
      expect(formatEnhancedStat(10000, 10), '20400');
    });

    test('power contribution scales with enhancement', () {
      final InventoryItem base = _item(enhancement: 0);
      final InventoryItem plus10 = _item(enhancement: 10);
      final int p0 = enhancedItemPowerContribution(base);
      final int p10 = enhancedItemPowerContribution(plus10);
      // base = 10000 + 3500*2 = 17000; +10 → ×2.04 = 34680
      expect(p0, 17000);
      expect(p10, 34680);
      expect(
        enhancedItemPowerContribution(base, enhancementLevel: 10),
        p10,
      );
    });
  });
}
