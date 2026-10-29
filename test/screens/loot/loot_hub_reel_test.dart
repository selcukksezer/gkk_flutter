import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/loot/loot_models.dart';
import 'package:gkk_flutter/screens/loot/loot_reel_controller.dart';

void main() {
  group('LootReelController Tests', () {
    late List<LootDropView> sampleDrops;

    setUp(() {
      sampleDrops = <LootDropView>[
        const LootDropView(
          itemId: 'wpn_excalibur',
          itemName: 'Excalibur Divine Sword',
          icon: 'sword',
          rarity: 'mythic',
          dropRate: 0.5,
          minQuantity: 1,
          maxQuantity: 1,
        ),
        const LootDropView(
          itemId: 'chest_dragon_plate',
          itemName: 'Dragon Plate Armor',
          icon: 'armor',
          rarity: 'legendary',
          dropRate: 2.0,
          minQuantity: 1,
          maxQuantity: 1,
        ),
        const LootDropView(
          itemId: 'ring_shadow_band',
          itemName: 'Shadow Band Ring',
          icon: 'ring',
          rarity: 'epic',
          dropRate: 8.0,
          minQuantity: 1,
          maxQuantity: 1,
        ),
        const LootDropView(
          itemId: 'potion_greater_health',
          itemName: 'Greater Health Potion',
          icon: 'potion',
          rarity: 'rare',
          dropRate: 20.0,
          minQuantity: 5,
          maxQuantity: 10,
        ),
        const LootDropView(
          itemId: 'mat_iron_ore',
          itemName: 'Iron Ore',
          icon: 'ore',
          rarity: 'common',
          dropRate: 69.5,
          minQuantity: 10,
          maxQuantity: 25,
        ),
      ];
    });

    test('builds reel with target item exactly at targetReelIndex', () {
      final LootReelController controller = LootReelController(
        source: sampleDrops,
        targetIndex: 0, // Excalibur
        reelSize: 56,
        targetReelIndex: 42,
        random: math.Random(42),
      );

      expect(controller.items.length, 56);
      expect(controller.items[42].itemId, 'wpn_excalibur');
      expect(controller.items[42].rarity, 'mythic');
    });

    test('places suspense/equipment drops adjacent to target item', () {
      final LootReelController controller = LootReelController(
        source: sampleDrops,
        targetIndex: 3, // Potion
        reelSize: 56,
        targetReelIndex: 42,
        random: math.Random(123),
      );

      expect(controller.items[42].itemId, 'potion_greater_health');
      // Neighbors should be populated from available pools
      expect(controller.items[41], isNotNull);
      expect(controller.items[43], isNotNull);
    });

    test('spinProgress bounds and continuity', () {
      final LootReelController controller = LootReelController(
        source: sampleDrops,
        targetIndex: 1,
        random: math.Random(99),
      );

      const double targetOffset = 6400.0;
      const double itemExtent = 154.0;

      // At t = 0
      expect(controller.spinProgress(0.0, targetOffset, itemExtent), 0.0);
      expect(controller.spinProgress(-0.1, targetOffset, itemExtent), 0.0);

      // At t = 1.0 (exact landing guarantee)
      expect(controller.spinProgress(1.0, targetOffset, itemExtent), 1.0);
      expect(controller.spinProgress(1.5, targetOffset, itemExtent), 1.0);

      // Monotonicity / forward movement checks across key checkpoints
      final double p05 = controller.spinProgress(0.05, targetOffset, itemExtent);
      final double p25 = controller.spinProgress(0.25, targetOffset, itemExtent);
      final double p50 = controller.spinProgress(0.50, targetOffset, itemExtent);
      final double p75 = controller.spinProgress(0.75, targetOffset, itemExtent);
      final double p95 = controller.spinProgress(0.95, targetOffset, itemExtent);
      final double p100 = controller.spinProgress(1.00, targetOffset, itemExtent);

      expect(p25, greaterThan(p05));
      expect(p50, greaterThan(p25));
      expect(p75, greaterThan(p50));
      expect(p95, greaterThan(p75));
      expect(p100, 1.0);
    });

    test('pixelOffset computes exact pixel distance', () {
      final LootReelController controller = LootReelController(
        source: sampleDrops,
        targetIndex: 0,
      );

      const double targetOffset = 5000.0;
      const double itemExtent = 150.0;

      expect(controller.pixelOffset(0.0, targetOffset, itemExtent), 0.0);
      expect(controller.pixelOffset(1.0, targetOffset, itemExtent), 5000.0);
    });

    test('anticipationShudderOffset returns vibration during launch and suspense brake', () {
      final LootReelController controller = LootReelController(
        source: sampleDrops,
        targetIndex: 0,
        enableAnticipationShudder: true,
      );

      final double launchShudder = controller.anticipationShudderOffset(0.02);
      expect(launchShudder.abs(), greaterThan(0.0));

      final double midCruiseShudder = controller.anticipationShudderOffset(0.35);
      expect(midCruiseShudder, 0.0); // smooth cruise

      final double brakeShudder = controller.anticipationShudderOffset(0.75);
      expect(brakeShudder.abs(), greaterThan(0.0));
    });

    test('detects high-rarity suspense items near center reticle', () {
      final LootReelController controller = LootReelController(
        source: sampleDrops,
        targetIndex: 0, // Mythic Excalibur
        reelSize: 56,
        targetReelIndex: 42,
        random: math.Random(7),
      );

      const double itemExtent = 154.0;
      const double viewportWidth = 360.0;
      const double cardWidth = 142.0;
      final double rawTargetOffset = (42 * itemExtent) - ((viewportWidth - cardWidth) / 2);

      // At t = 1.0, target item (Mythic) is at center
      final bool nearCenter = controller.isSuspenseItemNearCenter(
        1.0,
        rawTargetOffset,
        itemExtent,
        viewportWidth,
        cardWidth,
      );

      expect(nearCenter, isTrue);
    });
  });

  group('Loot Models & Helper Tests', () {
    test('lootCompactNum formats numbers cleanly for mobile HUD', () {
      expect(lootCompactNum(500), '500');
      expect(lootCompactNum(1500), '1.5K');
      expect(lootCompactNum(25000), '25.0K');
      expect(lootCompactNum(1200000), '1.2M');
      expect(lootCompactNum(3400000000), '3.4B');
    });

    test('lootJackpotPercentLabel formats percent correctly', () {
      expect(lootJackpotPercentLabel(0.05), '%5.0');
      expect(lootJackpotPercentLabel(0.025), '%2.5');
      expect(lootJackpotPercentLabel(5.0), '%5.0');
    });

    test('findLootTargetDropIndex locates reward item in drops list', () {
      final List<LootDropView> drops = <LootDropView>[
        const LootDropView(
          itemId: 'wpn_01',
          itemName: 'Flame Sword',
          icon: '',
          rarity: 'rare',
          dropRate: 10,
          minQuantity: 1,
          maxQuantity: 1,
        ),
        const LootDropView(
          itemId: 'wpn_02',
          itemName: 'Frost Dagger',
          icon: '',
          rarity: 'epic',
          dropRate: 5,
          minQuantity: 1,
          maxQuantity: 1,
        ),
      ];

      final Map<String, dynamic> payload = <String, dynamic>{
        'success': true,
        'reward': <String, dynamic>{
          'item_id': 'wpn_02',
          'name': 'Frost Dagger',
          'quantity': 1,
          'rarity': 'epic',
        },
      };

      final int targetIdx = findLootTargetDropIndex(payload, drops);
      expect(targetIdx, 1);
    });

    test('lootDropFromRewardPayload constructs valid LootDropView from RPC payload', () {
      final Map<String, dynamic> payload = <String, dynamic>{
        'success': true,
        'reward': <String, dynamic>{
          'item_id': 'acc_ring_09',
          'name': 'Ring of Celestial Might',
          'icon': 'ring_celestial',
          'rarity': 'legendary',
          'amount': 2,
        },
      };

      final LootDropView? drop = lootDropFromRewardPayload(payload);
      expect(drop, isNotNull);
      expect(drop!.itemId, 'acc_ring_09');
      expect(drop.itemName, 'Ring of Celestial Might');
      expect(drop.rarity, 'legendary');
      expect(drop.minQuantity, 2);
      expect(drop.maxQuantity, 2);
    });
  });
}
