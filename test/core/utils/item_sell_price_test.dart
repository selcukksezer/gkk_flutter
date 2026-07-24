import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/utils/item_sell_price.dart';
import 'package:gkk_flutter/models/item_model.dart';

void main() {
  group('computeNpcSellPrice', () {
    test('common Lv1 sword — KO-scale, not inflated table price', () {
      final int price = computeNpcSellPrice(
        itemId: 'wpn_sword_common',
        rarity: Rarity.common,
        itemType: ItemType.weapon,
        requiredLevel: 1,
        basePrice: 1680,
        attack: 1000,
        defense: 0,
        power: 0,
        luck: 0,
        energyRestore: 0,
        healthRestore: 0,
        isTradeable: true,
        isHanOnly: false,
      );
      expect(price, greaterThan(50));
      expect(price, lessThan(300));
    });

    test('rare Lv15 gear — mid-tier gold', () {
      final int price = computeNpcSellPrice(
        itemId: 'wpn_sword_rare',
        rarity: Rarity.rare,
        itemType: ItemType.weapon,
        requiredLevel: 15,
        basePrice: 7280,
        attack: 3500,
        defense: 0,
        power: 0,
        luck: 0,
        energyRestore: 0,
        healthRestore: 0,
        isTradeable: true,
        isHanOnly: false,
      );
      expect(price, greaterThan(200));
      expect(price, lessThan(1200));
    });

    test('mythic material — hard capped low', () {
      final int price = computeNpcSellPrice(
        itemId: 'res_mining_mythic',
        rarity: Rarity.mythic,
        itemType: ItemType.material,
        requiredLevel: 1,
        basePrice: 500000,
        attack: 0,
        defense: 0,
        power: 0,
        luck: 0,
        energyRestore: 0,
        healthRestore: 0,
        isTradeable: true,
        isHanOnly: false,
      );
      expect(price, lessThan(80));
    });

    test('blocks non-tradeable, han-only, cosmetic, loot boxes', () {
      expect(
        computeNpcSellPrice(
          itemId: 'badge_season_01',
          rarity: Rarity.epic,
          itemType: ItemType.cosmetic,
          requiredLevel: 1,
          basePrice: 30000,
          attack: 0,
          defense: 0,
          power: 0,
          luck: 0,
          energyRestore: 0,
          healthRestore: 0,
          isTradeable: false,
          isHanOnly: false,
        ),
        0,
      );

      expect(
        computeNpcSellPrice(
          itemId: 'han_item_berserk',
          rarity: Rarity.epic,
          itemType: ItemType.potion,
          requiredLevel: 1,
          basePrice: 2500000,
          attack: 0,
          defense: 0,
          power: 0,
          luck: 0,
          energyRestore: 0,
          healthRestore: 0,
          isTradeable: true,
          isHanOnly: true,
        ),
        0,
      );

      expect(
        computeNpcSellPrice(
          itemId: 'box_bronze',
          rarity: Rarity.common,
          itemType: ItemType.consumable,
          requiredLevel: 1,
          basePrice: 100,
          attack: 0,
          defense: 0,
          power: 0,
          luck: 0,
          energyRestore: 0,
          healthRestore: 0,
          isTradeable: true,
          isHanOnly: false,
        ),
        0,
      );
    });

    test('enhancement adds small bonus when below cap', () {
      final int base = computeNpcSellPrice(
        itemId: 'wpn_sword_rare',
        rarity: Rarity.rare,
        itemType: ItemType.weapon,
        requiredLevel: 15,
        basePrice: 7280,
        attack: 3500,
        defense: 0,
        power: 0,
        luck: 0,
        energyRestore: 0,
        healthRestore: 0,
        isTradeable: true,
        isHanOnly: false,
      );
      final int plus3 = computeNpcSellPrice(
        itemId: 'wpn_sword_rare',
        rarity: Rarity.rare,
        itemType: ItemType.weapon,
        requiredLevel: 15,
        basePrice: 7280,
        attack: 3500,
        defense: 0,
        power: 0,
        luck: 0,
        energyRestore: 0,
        healthRestore: 0,
        isTradeable: true,
        isHanOnly: false,
        enhancementLevel: 3,
      );
      expect(plus3, greaterThan(base));
    });
  });
}
