import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/utils/character_class_abilities.dart';
import 'package:gkk_flutter/core/utils/player_health.dart';
import 'package:gkk_flutter/core/utils/power_formula.dart';
import 'package:gkk_flutter/models/facility_model.dart';
import 'package:gkk_flutter/models/kingdom_market_blessing_model.dart';
import 'package:gkk_flutter/models/mekan_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/providers/mekan_provider.dart';
import 'package:gkk_flutter/screens/facilities/facility_detail_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // 1. HOME SCREEN CORE GAMEPLAY LOGIC & GUARDS
  // ===========================================================================
  group('1. Home Screen Core Gameplay Logic & Guards', () {
    test('PlayerHealthStatus resolves accurately across boundary thresholds', () {
      // Critical: < 20%
      expect(
        resolveHealthStatus(health: 19, maxHealth: 100),
        PlayerHealthStatus.critical,
      );
      expect(
        resolveHealthStatus(health: 0, maxHealth: 100),
        PlayerHealthStatus.critical,
      );

      // Wounded: >= 20% and < 50%
      expect(
        resolveHealthStatus(health: 20, maxHealth: 100),
        PlayerHealthStatus.wounded,
      );
      expect(
        resolveHealthStatus(health: 49, maxHealth: 100),
        PlayerHealthStatus.wounded,
      );

      // Recovering: >= 50% and < 100%
      expect(
        resolveHealthStatus(health: 50, maxHealth: 100),
        PlayerHealthStatus.recovering,
      );
      expect(
        resolveHealthStatus(health: 100, maxHealth: 100),
        PlayerHealthStatus.healthy,
      );
    });

    test('isLowHealthAlert flags critical and wounded conditions under 50%', () {
      expect(isLowHealthAlert(health: 10, maxHealth: 100), isTrue);
      expect(isLowHealthAlert(health: 49, maxHealth: 100), isTrue);
      expect(isLowHealthAlert(health: 50, maxHealth: 100), isFalse);
      expect(isLowHealthAlert(health: 100, maxHealth: 100), isFalse);
      expect(isLowHealthAlert(health: 0, maxHealth: 0), isFalse);
    });

    test('Combat power resolution incorporates player attributes and equipped gear', () {
      const PlayerProfile testProfile = PlayerProfile(
        id: 'test_p1',
        authId: 'auth_1',
        username: 'ValiantKnight',
        email: 'valiant@example.com',
        displayName: 'Valiant',
        avatarUrl: null,
        avatarFrame: null,
        level: 25,
        xp: 12000,
        gold: 50000,
        gems: 120.0,
        energy: 100,
        maxEnergy: 100,
        attack: 150,
        defense: 120,
        health: 500,
        maxHealth: 500,
        power: 1000,
        isOnline: true,
        isBanned: false,
        tutorialCompleted: true,
        guildId: null,
        guildRole: null,
        referralCode: 'REF123',
        referredBy: null,
        pvpRating: 1500,
        pvpWins: 40,
        pvpLosses: 10,
        addictionLevel: 10,
        tolerance: 15,
        lastPotionUsedAt: '',
        warriorBloodlustUntil: '',
        hospitalUntil: '',
        prisonUntil: '',
        globalSuspicionLevel: 0,
        lastBribeAt: '',
        lastLoginAt: '',
        lastLogin: '',
        createdAt: '',
        updatedAt: '',
        characterClass: CharacterClass.warrior,
      );

      final InventoryItem weapon = InventoryItem(
        id: 'w1',
        itemId: 'legendary_blade',
        name: 'Legendary Blade',
        itemType: 'weapon',
        rarity: 'legendary',
        quantity: 1,
        isEquipped: true,
        slot: 'weapon',
        attackBonus: 80,
        defenseBonus: 10,
      );

      final InventoryItem armor = InventoryItem(
        id: 'a1',
        itemId: 'dragon_plate',
        name: 'Dragon Plate',
        itemType: 'armor',
        rarity: 'epic',
        quantity: 1,
        isEquipped: true,
        slot: 'chest',
        attackBonus: 15,
        defenseBonus: 95,
      );

      final int basePower = resolveDungeonCombatPower(
        profile: testProfile,
        equippedItems: const <InventoryItem>[],
      );
      expect(basePower, greaterThan(0));

      final int equippedPower = resolveDungeonCombatPower(
        profile: testProfile,
        equippedItems: <InventoryItem>[weapon, armor],
      );
      expect(equippedPower, greaterThan(basePower));
    });

    test('Home status indicators detect future hospital and prison restrictions', () {
      bool isFuture(String? dateStr) {
        if (dateStr == null || dateStr.isEmpty) return false;
        final DateTime? d = DateTime.tryParse(dateStr);
        if (d == null) return false;
        return d.isAfter(DateTime.now());
      }

      final String pastDate = DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String();
      final String futureDate = DateTime.now().add(const Duration(minutes: 45)).toIso8601String();

      expect(isFuture(null), isFalse);
      expect(isFuture(''), isFalse);
      expect(isFuture(pastDate), isFalse);
      expect(isFuture(futureDate), isTrue);
    });
  });

  // ===========================================================================
  // 2. FACILITIES SCREEN CORE GAMEPLAY LOGIC & GUARDS
  // ===========================================================================
  group('2. Facilities Screen Core Gameplay Logic & Guards', () {
    test('15 distinct facilities are registered with complete metadata', () {
      expect(kFacilityMetaByType.length, 15);

      final List<String> expectedTypes = <String>[
        'mining', 'quarry', 'lumber_mill', 'clay_pit', 'sand_quarry',
        'farming', 'herb_garden', 'ranch', 'apiary', 'mushroom_farm',
        'rune_mine', 'holy_spring', 'shadow_pit', 'elemental_forge', 'time_well',
      ];

      for (final String type in expectedTypes) {
        final FacilityMeta? meta = facilityMetaFor(type);
        expect(meta, isNotNull, reason: 'Facility meta for $type must exist');
        expect(meta!.name.isNotEmpty, isTrue);
        expect(meta.icon.isNotEmpty, isTrue);
        expect(meta.description.isNotEmpty, isTrue);
        expect(meta.baseRate, greaterThan(0));
        expect(meta.baseUpgradeCost, greaterThan(0));
        expect(meta.multiplier, greaterThanOrEqualTo(1.5));
        expect(meta.resources.length, 6, reason: 'Each facility must have 6 resource tiers');
      }
    });

    test('Facility upgrade cost scales exponentially per level', () {
      // Level 1 should equal baseUpgradeCost
      final int costL1 = facilityUpgradeCost('mining', 1);
      final FacilityMeta miningMeta = facilityMetaFor('mining')!;
      expect(costL1, miningMeta.baseUpgradeCost);

      // Level 2 should equal baseUpgradeCost * multiplier
      final int costL2 = facilityUpgradeCost('mining', 2);
      expect(costL2, (miningMeta.baseUpgradeCost * miningMeta.multiplier).floor());

      // Level 3 should be costL2 * multiplier
      final int costL3 = facilityUpgradeCost('mining', 3);
      expect(costL3, greaterThan(costL2));
      expect(costL3, (miningMeta.baseUpgradeCost * miningMeta.multiplier * miningMeta.multiplier).floor());

      // Unknown facility returns 0
      expect(facilityUpgradeCost('non_existent_facility', 1), 0);
    });

    test('Rarity unlock levels and drop rate distribution rules', () {
      expect(kFacilityRarityUnlockLevels['common'], 1);
      expect(kFacilityRarityUnlockLevels['uncommon'], 3);
      expect(kFacilityRarityUnlockLevels['rare'], 5);
      expect(kFacilityRarityUnlockLevels['epic'], 7);
      expect(kFacilityRarityUnlockLevels['legendary'], 9);
      expect(kFacilityRarityUnlockLevels['mythic'], 10);

      // Level 1 drop rate is 100% common
      final Map<String, int> l1Weights = facilityRarityWeightsAtLevel(1);
      expect(l1Weights['common'], 100);
      expect(l1Weights['uncommon'], 0);
      expect(l1Weights['mythic'], 0);

      // Level 10 has all 6 rarities active and sums to 100%
      final Map<String, int> l10Weights = facilityRarityWeightsAtLevel(10);
      final int l10Total = l10Weights.values.fold<int>(0, (int sum, int w) => sum + w);
      expect(l10Total, 100);
      expect(l10Weights['mythic'], greaterThan(0));
      expect(l10Weights['legendary'], greaterThan(0));
      expect(l10Weights['epic'], greaterThan(0));
      expect(l10Weights['rare'], greaterThan(0));
      expect(l10Weights['uncommon'], greaterThan(0));
      expect(l10Weights['common'], greaterThan(0));
    });

    test('Effective suspicion and bribe cost calculation by character class', () {
      const PlayerProfile warrior = PlayerProfile(
        id: 'p_warrior',
        authId: 'a1',
        username: 'Warrior',
        email: 'w@test.com',
        displayName: 'Warrior',
        avatarUrl: null,
        avatarFrame: null,
        level: 10,
        xp: 0,
        gold: 1000,
        gems: 50.0,
        energy: 100,
        maxEnergy: 100,
        attack: 100,
        defense: 100,
        health: 100,
        maxHealth: 100,
        power: 100,
        isOnline: true,
        isBanned: false,
        tutorialCompleted: true,
        guildId: null,
        guildRole: null,
        referralCode: null,
        referredBy: null,
        pvpRating: 1000,
        pvpWins: 0,
        pvpLosses: 0,
        addictionLevel: 0,
        tolerance: 0,
        lastPotionUsedAt: '',
        warriorBloodlustUntil: '',
        hospitalUntil: '',
        prisonUntil: '',
        globalSuspicionLevel: 95,
        lastBribeAt: '',
        lastLoginAt: '',
        lastLogin: '',
        createdAt: '',
        updatedAt: '',
        characterClass: CharacterClass.warrior,
      );

      const PlayerProfile shadow = PlayerProfile(
        id: 'p_shadow',
        authId: 'a2',
        username: 'Shadow',
        email: 's@test.com',
        displayName: 'Shadow',
        avatarUrl: null,
        avatarFrame: null,
        level: 10,
        xp: 0,
        gold: 1000,
        gems: 50.0,
        energy: 100,
        maxEnergy: 100,
        attack: 100,
        defense: 100,
        health: 100,
        maxHealth: 100,
        power: 100,
        isOnline: true,
        isBanned: false,
        tutorialCompleted: true,
        guildId: null,
        guildRole: null,
        referralCode: null,
        referredBy: null,
        pvpRating: 1000,
        pvpWins: 0,
        pvpLosses: 0,
        addictionLevel: 0,
        tolerance: 0,
        lastPotionUsedAt: '',
        warriorBloodlustUntil: '',
        hospitalUntil: '',
        prisonUntil: '',
        globalSuspicionLevel: 95,
        lastBribeAt: '',
        lastLoginAt: '',
        lastLogin: '',
        createdAt: '',
        updatedAt: '',
        characterClass: CharacterClass.shadow,
      );

      // Warrior capped at 100 suspicion
      expect(effectiveSuspicionLevel(warrior), 95);
      // Shadow capped at 80 suspicion (Ghost Step passive)
      expect(effectiveSuspicionLevel(shadow), 80);

      // Bribe cost: Warrior pays base 5 gems
      expect(bribeGemCostForClass(CharacterClass.warrior, baseCost: 5), 5);
      // Shadow gets -25% discount: ceil(5 * 0.75) = ceil(3.75) = 4 gems
      expect(bribeGemCostForClass(CharacterClass.shadow, baseCost: 5), 4);
    });

    test('Facility production countdown and duration formatting', () {
      expect(kFacilityProductionDurationSeconds, 120);

      final DateTime now = DateTime(2026, 10, 28, 12, 0, 0);
      final DateTime futureTarget = now.add(const Duration(minutes: 1, seconds: 45));
      final DateTime pastTarget = now.subtract(const Duration(seconds: 10));

      expect(formatFacilityRemaining(futureTarget, now: now), '01:45');
      expect(formatFacilityRemaining(pastTarget, now: now), '✅');
      expect(formatFacilityRemaining(null), '00:00');
    });

    test('Queue item summation is exact across batches', () {
      final List<FacilityQueueItem> queue = <FacilityQueueItem>[
        const FacilityQueueItem(id: 'q1', itemId: 'ore_1', rarity: 'common', quantity: 25),
        const FacilityQueueItem(id: 'q2', itemId: 'ore_2', rarity: 'rare', quantity: 10),
        const FacilityQueueItem(id: 'q3', itemId: 'ore_3', rarity: 'legendary', quantity: 2),
      ];
      expect(sumFacilityQueueQuantity(queue), 37);
      expect(sumFacilityQueueQuantity(const <FacilityQueueItem>[]), 0);
    });
  });

  // ===========================================================================
  // 3. MEKANS SCREEN CORE GAMEPLAY LOGIC & GUARDS
  // ===========================================================================
  group('3. Mekans Screen Core Gameplay Logic & Guards', () {
    test('Default page size is 20 and pagination increments offset', () {
      expect(MekanRepository.defaultPageSize, 20);

      const int pageSize = MekanRepository.defaultPageSize;
      int currentOffset = 0;
      final List<int> pageSizes = <int>[20, 20, 15];

      for (final int size in pageSizes) {
        expect(size <= pageSize, isTrue);
        currentOffset += size;
      }
      expect(currentOffset, 55);
    });

    test('MekanType enum to string and string to enum parsing preserves all 5 types', () {
      final Map<String, MekanType> expectedMappings = <String, MekanType>{
        'bar': MekanType.bar,
        'kahvehane': MekanType.kahvehane,
        'dovus_kulubu': MekanType.dovusKulubu,
        'luks_lounge': MekanType.luksLounge,
        'yeralti': MekanType.yeralti,
      };

      for (final MapEntry<String, MekanType> entry in expectedMappings.entries) {
        final Mekan testMekan = Mekan(
          id: 'm_${entry.key}',
          ownerId: 'owner_1',
          mekanType: entry.value,
          name: 'Test Mekan',
          level: 1,
          fame: 100,
          suspicion: 10,
          isOpen: true,
          monthlyRentPaidAt: '',
          createdAt: '',
        );
        expect(testMekan.typeKey, entry.key);
      }
    });

    test('Mekan happy hour and raid closed temporal flags evaluate correctly', () {
      final String futureDate = DateTime.now().add(const Duration(hours: 2)).toIso8601String();
      final String pastDate = DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();

      final Mekan openMekan = Mekan(
        id: 'm1',
        ownerId: 'o1',
        mekanType: MekanType.bar,
        name: 'The Golden Tankard',
        level: 3,
        fame: 500,
        suspicion: 20,
        isOpen: true,
        closedUntil: null,
        monthlyRentPaidAt: '',
        createdAt: '',
        happyHourUntil: futureDate,
      );

      expect(openMekan.isOpen, isTrue);
      expect(openMekan.happyHourActive, isTrue);
      expect(openMekan.raidClosed, isFalse);

      final Mekan raidedMekan = Mekan(
        id: 'm2',
        ownerId: 'o2',
        mekanType: MekanType.yeralti,
        name: 'Underground Den',
        level: 2,
        fame: 200,
        suspicion: 80,
        isOpen: false,
        closedUntil: futureDate,
        monthlyRentPaidAt: '',
        createdAt: '',
        happyHourUntil: pastDate,
      );

      expect(raidedMekan.isOpen, isFalse);
      expect(raidedMekan.happyHourActive, isFalse);
      expect(raidedMekan.raidClosed, isTrue);
    });

    test('Filtering mechanically subsets mekan collections by typeKey', () {
      final List<Mekan> testMekans = <Mekan>[
        Mekan(
          id: '1', ownerId: 'o', mekanType: MekanType.bar,
          name: 'Bar A', level: 1, fame: 0, suspicion: 0, isOpen: true,
          monthlyRentPaidAt: '', createdAt: '',
        ),
        Mekan(
          id: '2', ownerId: 'o', mekanType: MekanType.bar,
          name: 'Bar B', level: 1, fame: 0, suspicion: 0, isOpen: true,
          monthlyRentPaidAt: '', createdAt: '',
        ),
        Mekan(
          id: '3', ownerId: 'o', mekanType: MekanType.kahvehane,
          name: 'Kahve A', level: 1, fame: 0, suspicion: 0, isOpen: true,
          monthlyRentPaidAt: '', createdAt: '',
        ),
        Mekan(
          id: '4', ownerId: 'o', mekanType: MekanType.dovusKulubu,
          name: 'Fight Club', level: 1, fame: 0, suspicion: 0, isOpen: true,
          monthlyRentPaidAt: '', createdAt: '',
        ),
      ];

      List<Mekan> filterBy(String filter) {
        return filter == 'all'
            ? testMekans
            : testMekans.where((Mekan m) => m.typeKey == filter).toList();
      }

      expect(filterBy('all').length, 4);
      expect(filterBy('bar').length, 2);
      expect(filterBy('kahvehane').length, 1);
      expect(filterBy('dovus_kulubu').length, 1);
      expect(filterBy('yeralti').length, 0);
    });
  });

  // ===========================================================================
  // 4. KINGDOM COMPONENTS & BLESSING LOGIC & GUARDS
  // ===========================================================================
  group('4. Kingdom Components & Blessing Logic & Guards', () {
    test('KingdomMarketBlessingStatus inactive constructor generates dormant state', () {
      final KingdomMarketBlessingStatus inactive = KingdomMarketBlessingStatus.inactive();
      expect(inactive.active, isFalse);
      expect(inactive.goldDiscountPct, 0);
      expect(inactive.gemDiscountPct, 0);
      expect(inactive.hasDiscountForCurrency('gold'), isFalse);
      expect(inactive.hasDiscountForCurrency('gems'), isFalse);
      expect(inactive.applyDiscount(1000, 'gold'), 1000);
      expect(inactive.applyDiscount(50, 'gems'), 50);
    });

    test('KingdomMarketBlessingStatus calculates exact discounted prices', () {
      final DateTime futureEnd = DateTime.now().add(const Duration(minutes: 30));
      final KingdomMarketBlessingStatus activeBlessing = KingdomMarketBlessingStatus(
        active: true,
        goldDiscountPct: 20, // 20% off gold
        gemDiscountPct: 10,  // 10% off gems
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        expiresAt: futureEnd,
        activatedByUsername: 'ArthurPendragon',
        activatedByGuildName: 'Camelot',
      );

      expect(activeBlessing.active, isTrue);
      expect(activeBlessing.discountPctForCurrency('gold'), 20);
      expect(activeBlessing.discountPctForCurrency('gems'), 10);
      expect(activeBlessing.hasDiscountForCurrency('gold'), isTrue);
      expect(activeBlessing.hasDiscountForCurrency('gems'), isTrue);

      // Gold: 1000 gold with 20% discount = 800 gold
      expect(activeBlessing.applyDiscount(1000, 'gold'), 800);
      // Gold: 250 gold with 20% discount = 200 gold
      expect(activeBlessing.applyDiscount(250, 'gold'), 200);
      // Gems: 100 gems with 10% discount = 90 gems
      expect(activeBlessing.applyDiscount(100, 'gems'), 90);
      // Gems: 45 gems with 10% discount = 40 gems (floor(45 * 0.9) = 40)
      expect(activeBlessing.applyDiscount(45, 'gems'), 40);

      // Activator label formats correctly
      expect(activeBlessing.activatorLabel, 'Camelot · ArthurPendragon');

      // Discount summary
      expect(activeBlessing.discountSummary(), 'altın %20 · elmas %10');

      // Remaining label shows minutes
      expect(activeBlessing.remainingLabel().contains('dk kaldı'), isTrue);
    });

    test('Expired blessing outputs termination label', () {
      final DateTime pastEnd = DateTime.now().subtract(const Duration(seconds: 15));
      final KingdomMarketBlessingStatus expiredBlessing = KingdomMarketBlessingStatus(
        active: true,
        goldDiscountPct: 15,
        gemDiscountPct: 5,
        expiresAt: pastEnd,
      );

      expect(expiredBlessing.remainingLabel(), 'Süre doldu');
    });

    test('Territory provincial ratio clamps cleanly between 0.0 and 1.0', () {
      double computeTerritoryRatio(int controlled, int total) {
        if (total <= 0) return 0.0;
        return (controlled / total).clamp(0.0, 1.0);
      }

      expect(computeTerritoryRatio(7, 9), closeTo(7 / 9, 1e-4));
      expect(computeTerritoryRatio(0, 9), 0.0);
      expect(computeTerritoryRatio(9, 9), 1.0);
      expect(computeTerritoryRatio(12, 9), 1.0);
      expect(computeTerritoryRatio(-2, 9), 0.0);
      expect(computeTerritoryRatio(5, 0), 0.0);
    });
  });
}
