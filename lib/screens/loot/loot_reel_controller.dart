import 'dart:math' as math;

import 'package:flutter/animation.dart';

import 'loot_models.dart';

/// Builds the loot-box spin reel and computes physics-inspired scroll progress.
///
/// Designed to 2027 Aion 2 Mobile standards:
/// - Initial elastic anticipation recoil (reel coils back slightly before launch).
/// - Explosive spring-propelled acceleration into high-velocity warp cruise.
/// - Viscous physics-inspired deceleration across the final suspense corridor.
/// - Anticipation shudder and magnetic lock snap with zero drift on the rolled reward.
class LootReelController {
  LootReelController({
    required List<LootDropView> source,
    required int targetIndex,
    math.Random? random,
    this.reelSize = 56,
    this.targetReelIndex = 42,
    this.totalSpinMs = 9000,
    this.finalSixItemsMs = 5000,
    this.enableAnticipationShudder = true,
  }) : _rng = random ?? math.Random(DateTime.now().microsecondsSinceEpoch) {
    final int safeTarget = source.isEmpty ? 0 : targetIndex.clamp(0, source.length - 1);
    items = source.isEmpty
        ? const <LootDropView>[]
        : buildRandomizedReel(source, safeTarget);
  }

  final int reelSize;
  final int targetReelIndex;
  final int totalSpinMs;
  final int finalSixItemsMs;
  final bool enableAnticipationShudder;

  final math.Random _rng;
  late final List<LootDropView> items;

  /// Constructs a weighted suspense reel placing the [target] at [targetReelIndex]
  /// and framing it with tempting chase/legendary drops for high anticipation.
  List<LootDropView> buildRandomizedReel(
    List<LootDropView> source,
    int target,
  ) {
    if (source.isEmpty) return const <LootDropView>[];

    final List<LootDropView> reel = List<LootDropView>.generate(
      reelSize,
      (_) => source[_rng.nextInt(source.length)],
      growable: false,
    );

    final LootDropView targetDrop = source[target];
    final int safeReelIndex = targetReelIndex.clamp(0, reelSize - 1);
    reel[safeReelIndex] = targetDrop;

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
      safeReelIndex - 1,
      safeReelIndex + 1,
      safeReelIndex - 2,
      safeReelIndex + 2,
      safeReelIndex - 3,
      safeReelIndex + 3,
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
      if (safeReelIndex - 1 >= 0) {
        reel[safeReelIndex - 1] =
            premiumEquipmentPool[_rng.nextInt(premiumEquipmentPool.length)];
      }

      if (safeReelIndex + 1 < reel.length) {
        LootDropView right =
            premiumEquipmentPool[_rng.nextInt(premiumEquipmentPool.length)];
        int guard = 0;
        final String leftId = safeReelIndex - 1 >= 0
            ? reel[safeReelIndex - 1].itemId
            : '';
        while (right.itemId == leftId && guard < 8) {
          right = premiumEquipmentPool[_rng.nextInt(premiumEquipmentPool.length)];
          guard++;
        }
        reel[safeReelIndex + 1] = right;
      }
    }

    return reel;
  }

  /// Evaluates normalized reel travel progress in range `[0.0, 1.0]`.
  ///
  /// Guarantees:
  /// - `t <= 0.0` -> `0.0`
  /// - `t >= 1.0` -> `1.0` (Dead-exact landing on [targetOffset]).
  /// - C1 continuity between acceleration, cruise, and viscous deceleration.
  /// - Micro elastic recoil at start and magnetic spring settlement at landing.
  double spinProgress(double t, double targetOffset, double itemExtent) {
    if (targetOffset <= 0) return 1.0;
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;

    // Window of items undergoing dramatic slow deceleration
    final double finalWindow = math.min(targetOffset, itemExtent * 6);
    final double preFinalDistance = math.max(0, targetOffset - finalWindow);

    final double finalPhasePortion = (finalSixItemsMs / totalSpinMs).clamp(
      0.15,
      0.85,
    );
    final double prePhasePortion = 1.0 - finalPhasePortion;

    // Phase intervals within prePhase:
    // [0.0 .. recoilEnd]: Elastic anticipation pull-back
    // [recoilEnd .. accelEnd]: High-torque forward acceleration
    // [accelEnd .. decelStart]: High-velocity cruise
    final double recoilEnd = math.min(0.04, prePhasePortion * 0.15);
    final double accelEnd = prePhasePortion * 0.40;
    final double decelStart = prePhasePortion;

    final double accelDistance = preFinalDistance * 0.25;
    final double cruiseDistance = preFinalDistance - accelDistance;

    double covered;

    if (t < recoilEnd) {
      // Elastic anticipation: subtle backward coil before spring release
      final double p = t / recoilEnd;
      final double recoilMagnitude = enableAnticipationShudder ? 0.004 : 0.0;
      final double backwardDip = -math.sin(p * math.pi) * recoilMagnitude * targetOffset;
      covered = backwardDip;
    } else if (t <= accelEnd) {
      // Cubic spring acceleration
      final double p = (t - recoilEnd) / (accelEnd - recoilEnd);
      final double ease = Curves.easeInCubic.transform(p.clamp(0.0, 1.0));
      covered = accelDistance * ease;
    } else if (t <= decelStart) {
      // Constant cruise speed
      final double p = (t - accelEnd) / (decelStart - accelEnd);
      covered = accelDistance + (cruiseDistance * p.clamp(0.0, 1.0));
    } else {
      // Deceleration phase: Hermite spline smoothly meeting cruise velocity
      // at decelStart and settling at targetOffset as t -> 1.0
      final double cruiseTime = decelStart - accelEnd;
      final double cruiseVelocity = cruiseTime > 0.001
          ? cruiseDistance / cruiseTime
          : preFinalDistance / decelStart;

      final double decelDuration = 1.0 - decelStart;
      final double u = ((t - decelStart) / decelDuration).clamp(0.0, 1.0);

      // Normalized entry slope m0 for the final window
      final double m0Raw = (cruiseVelocity * decelDuration) / math.max(1.0, finalWindow);
      final double m0 = m0Raw.clamp(0.3, 2.5);

      // Hermite cubic polynomial: h(0)=0, h'(0)=m0, h(1)=1, h'(1)=0
      final double a = m0 - 2.0;
      final double b = 3.0 - (2.0 * m0);
      final double c = m0;
      double h = (a * u * u * u) + (b * u * u) + (c * u);

      // Magnetic snap in final 6%: subtle damped micro-bounce settling dead center
      if (u > 0.94 && enableAnticipationShudder) {
        final double snapU = (u - 0.94) / 0.06;
        final double bounce = math.sin(snapU * math.pi * 1.5) *
            math.exp(-snapU * 4.5) *
            0.0025;
        h = (h + bounce).clamp(0.0, 1.0);
      }

      covered = preFinalDistance + (finalWindow * h.clamp(0.0, 1.0));
    }

    final double normalized = covered / targetOffset;
    return normalized.clamp(0.0, 1.0);
  }

  /// Pixel offset of the reel at time [t].
  double pixelOffset(double t, double targetOffset, double itemExtent) {
    return targetOffset * spinProgress(t, targetOffset, itemExtent);
  }

  /// Index of the item currently crossing or closest to the center reticle.
  int itemIndexAt(double t, double targetOffset, double itemExtent, double viewportWidth, double cardWidth) {
    if (items.isEmpty) return 0;
    final double scroll = pixelOffset(t, targetOffset, itemExtent);
    final double centerOnStrip = scroll + (viewportWidth / 2.0);
    final int index = (centerOnStrip / itemExtent).floor();
    return index.clamp(0, items.length - 1);
  }

  /// Returns anticipation shudder displacement in pixels for dramatic camera/screen rumble.
  ///
  /// Peaks during initial torque launch and when decelerating past high-rarity drops.
  double anticipationShudderOffset(double t, {double intensity = 1.0}) {
    if (!enableAnticipationShudder) return 0.0;
    if (t < 0.05) {
      // Launch vibration
      return math.sin(t * 120.0) * 1.8 * intensity;
    }
    if (t > 0.60 && t < 0.96) {
      // Suspense brake shudder decaying into center lock
      final double progress = (t - 0.60) / 0.36;
      final double envelope = math.sin(progress * math.pi);
      return math.sin(t * 80.0) * 1.4 * envelope * intensity;
    }
    return 0.0;
  }

  /// Whether a high-rarity (Epic/Legendary/Mythic) item is currently near the center reticle.
  bool isSuspenseItemNearCenter(
    double t,
    double targetOffset,
    double itemExtent,
    double viewportWidth,
    double cardWidth, {
    int neighborRadius = 1,
  }) {
    final int centerIdx = itemIndexAt(t, targetOffset, itemExtent, viewportWidth, cardWidth);
    final int start = math.max(0, centerIdx - neighborRadius);
    final int end = math.min(items.length - 1, centerIdx + neighborRadius);

    for (int i = start; i <= end; i++) {
      final String rarity = items[i].rarity.toLowerCase();
      if (rarity == 'mythic' || rarity == 'legendary' || rarity == 'epic') {
        return true;
      }
    }
    return false;
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
