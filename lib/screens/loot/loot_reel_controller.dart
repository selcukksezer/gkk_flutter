import 'dart:math' as math;

import 'package:flutter/animation.dart';

import 'loot_models.dart';

/// Builds the loot-box spin reel and computes eased scroll progress.
class LootReelController {
  LootReelController({
    required List<LootDropView> source,
    required int targetIndex,
    math.Random? random,
    this.reelSize = 56,
    this.targetReelIndex = 42,
    this.totalSpinMs = 9000,
    this.finalSixItemsMs = 5000,
  }) : _rng = random ?? math.Random(DateTime.now().microsecondsSinceEpoch) {
    final int safeTarget = targetIndex.clamp(0, source.length - 1);
    items = buildRandomizedReel(source, safeTarget);
  }

  final int reelSize;
  final int targetReelIndex;
  final int totalSpinMs;
  final int finalSixItemsMs;

  final math.Random _rng;
  late final List<LootDropView> items;

  List<LootDropView> buildRandomizedReel(
    List<LootDropView> source,
    int target,
  ) {
    final List<LootDropView> reel = List<LootDropView>.generate(
      reelSize,
      (_) => source[_rng.nextInt(source.length)],
      growable: false,
    );

    final LootDropView targetDrop = source[target];
    reel[targetReelIndex] = targetDrop;

    final List<LootDropView> premiumEquipmentPool = source
        .where(
          (d) =>
              d.itemId != targetDrop.itemId &&
              _isLegendaryPlus(d) &&
              _isEquipmentDrop(d),
        )
        .toList(growable: false);

    final List<LootDropView> equipmentFallbackPool = source
        .where((d) => d.itemId != targetDrop.itemId && _isEquipmentDrop(d))
        .toList(growable: false);

    final List<int> neighborPositions = <int>[
      targetReelIndex - 1,
      targetReelIndex + 1,
      targetReelIndex - 2,
      targetReelIndex + 2,
      targetReelIndex - 3,
      targetReelIndex + 3,
    ];

    for (final int pos in neighborPositions) {
      if (pos < 0 || pos >= reel.length) continue;
      if (premiumEquipmentPool.isNotEmpty) {
        reel[pos] =
            premiumEquipmentPool[_rng.nextInt(premiumEquipmentPool.length)];
      } else if (equipmentFallbackPool.isNotEmpty) {
        reel[pos] =
            equipmentFallbackPool[_rng.nextInt(equipmentFallbackPool.length)];
      }
    }

    if (premiumEquipmentPool.length >= 2) {
      reel[targetReelIndex - 1] =
          premiumEquipmentPool[_rng.nextInt(premiumEquipmentPool.length)];

      LootDropView right =
          premiumEquipmentPool[_rng.nextInt(premiumEquipmentPool.length)];
      int guard = 0;
      while (right.itemId == reel[targetReelIndex - 1].itemId && guard < 8) {
        right = premiumEquipmentPool[_rng.nextInt(premiumEquipmentPool.length)];
        guard++;
      }
      reel[targetReelIndex + 1] = right;
    }

    return reel;
  }

  double spinProgress(double t, double targetOffset, double itemExtent) {
    if (targetOffset <= 0) return 1;

    final double finalWindow = math.min(targetOffset, itemExtent * 6);
    final double preFinalDistance = math.max(0, targetOffset - finalWindow);
    final double accelDistance = preFinalDistance * 0.18;
    final double cruiseDistance = preFinalDistance - accelDistance;

    final double finalPhasePortion = (finalSixItemsMs / totalSpinMs).clamp(
      0.1,
      0.9,
    );
    final double prePhasePortion = 1 - finalPhasePortion;
    final double accelTime = prePhasePortion * 0.35;
    final double cruiseTime = prePhasePortion - accelTime;
    final double decelStart = prePhasePortion;

    double covered;
    if (t <= accelTime) {
      final double p = Curves.easeInCubic.transform(t / accelTime);
      covered = accelDistance * p;
    } else if (t <= decelStart) {
      final double p = (t - accelTime) / cruiseTime;
      covered = accelDistance + (cruiseDistance * p);
    } else {
      final double u = ((t - decelStart) / (1 - decelStart)).clamp(0, 1);

      final double cruiseVelocity = cruiseDistance / cruiseTime;
      final double m0Raw = (cruiseVelocity * (1 - decelStart)) / finalWindow;
      final double m0 = m0Raw.clamp(0.2, 2.8);

      final double a = m0 - 2;
      final double b = 3 - (2 * m0);
      final double c = m0;
      final double h = ((a * u * u * u) + (b * u * u) + (c * u)).clamp(0, 1);

      covered = preFinalDistance + (finalWindow * h);
    }

    return (covered / targetOffset).clamp(0, 1);
  }

  bool _isLegendaryPlus(LootDropView drop) {
    final String rarity = drop.rarity.toLowerCase();
    return rarity == 'legendary' || rarity == 'mythic';
  }

  bool _isEquipmentDrop(LootDropView drop) {
    final String itemId = drop.itemId.toLowerCase();
    if (itemId.startsWith('wpn_') ||
        itemId.startsWith('head_') ||
        itemId.startsWith('chest_') ||
        itemId.startsWith('legs_') ||
        itemId.startsWith('boots_') ||
        itemId.startsWith('gloves_') ||
        itemId.startsWith('ring_') ||
        itemId.startsWith('neck_')) {
      return true;
    }

    final String name = drop.itemName.toLowerCase();
    return name.contains('sword') ||
        name.contains('axe') ||
        name.contains('bow') ||
        name.contains('dagger') ||
        name.contains('staff') ||
        name.contains('spear') ||
        name.contains('mace') ||
        name.contains('hammer') ||
        name.contains('wand') ||
        name.contains('armor') ||
        name.contains('ring') ||
        name.contains('necklace') ||
        name.contains('amulet') ||
        name.contains('pendant') ||
        name.contains('choker') ||
        name.contains('robe') ||
        name.contains('mail') ||
        name.contains('plate') ||
        name.contains('helm') ||
        name.contains('hood') ||
        name.contains('gloves') ||
        name.contains('greaves') ||
        name.contains('tunic') ||
        name.contains('gown') ||
        name.contains('trousers') ||
        name.contains('pants') ||
        name.contains('boots');
  }
}
