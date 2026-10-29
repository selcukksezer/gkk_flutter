import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/constants/economy_constants.dart';
import 'package:gkk_flutter/models/battle_pass.dart';
import 'package:gkk_flutter/screens/season/season_pass_logic.dart';

void main() {
  group('SeasonPassLogic - XP & Level Calculations', () {
    test('calculateXpInCurrentLevel calculates modulo 1000 correctly', () {
      expect(SeasonPassLogic.calculateXpInCurrentLevel(0), equals(0));
      expect(SeasonPassLogic.calculateXpInCurrentLevel(250), equals(250));
      expect(SeasonPassLogic.calculateXpInCurrentLevel(999), equals(999));
      expect(SeasonPassLogic.calculateXpInCurrentLevel(1000), equals(0));
      expect(SeasonPassLogic.calculateXpInCurrentLevel(2450), equals(450));
      expect(SeasonPassLogic.calculateXpInCurrentLevel(-100), equals(0));
    });

    test('calculateLevelProgress returns normalized float between 0.0 and 1.0', () {
      expect(SeasonPassLogic.calculateLevelProgress(0), equals(0.0));
      expect(SeasonPassLogic.calculateLevelProgress(250), closeTo(0.25, 0.0001));
      expect(SeasonPassLogic.calculateLevelProgress(500), closeTo(0.50, 0.0001));
      expect(SeasonPassLogic.calculateLevelProgress(750), closeTo(0.75, 0.0001));
      expect(SeasonPassLogic.calculateLevelProgress(1000), equals(0.0));
      expect(SeasonPassLogic.calculateLevelProgress(1800), closeTo(0.80, 0.0001));
      expect(SeasonPassLogic.calculateLevelProgress(-50), equals(0.0));
    });

    test('totalBppForLevel calculates cumulative XP threshold', () {
      expect(SeasonPassLogic.totalBppForLevel(0), equals(0));
      expect(SeasonPassLogic.totalBppForLevel(1), equals(1000));
      expect(SeasonPassLogic.totalBppForLevel(5), equals(5000));
      expect(SeasonPassLogic.totalBppForLevel(10), equals(10000));
      expect(SeasonPassLogic.totalBppForLevel(20), equals(20000));
      expect(SeasonPassLogic.totalBppForLevel(-3), equals(0));
    });

    test('bppNeededForNextLevel returns remaining XP to level up', () {
      expect(SeasonPassLogic.bppNeededForNextLevel(0), equals(1000));
      expect(SeasonPassLogic.bppNeededForNextLevel(300), equals(700));
      expect(SeasonPassLogic.bppNeededForNextLevel(999), equals(1));
      expect(SeasonPassLogic.bppNeededForNextLevel(1000), equals(1000));
      expect(SeasonPassLogic.bppNeededForNextLevel(2850), equals(150));
      expect(SeasonPassLogic.bppNeededForNextLevel(-10), equals(1000));
    });

    test('daily grind (dungeon) cap checks and remaining allowance', () {
      expect(SeasonPassLogic.isDailyGrindCapped(0), isFalse);
      expect(SeasonPassLogic.isDailyGrindCapped(299), isFalse);
      expect(SeasonPassLogic.isDailyGrindCapped(300), isTrue);
      expect(SeasonPassLogic.isDailyGrindCapped(450), isTrue);

      expect(SeasonPassLogic.remainingDailyGrindAllowance(0), equals(300));
      expect(SeasonPassLogic.remainingDailyGrindAllowance(120), equals(180));
      expect(SeasonPassLogic.remainingDailyGrindAllowance(300), equals(0));
      expect(SeasonPassLogic.remainingDailyGrindAllowance(350), equals(0));
      expect(SeasonPassLogic.remainingDailyGrindAllowance(-20), equals(300));
    });

    test('daily PvP cap checks and remaining allowance', () {
      expect(SeasonPassLogic.isDailyPvpCapped(0), isFalse);
      expect(SeasonPassLogic.isDailyPvpCapped(199), isFalse);
      expect(SeasonPassLogic.isDailyPvpCapped(200), isTrue);
      expect(SeasonPassLogic.isDailyPvpCapped(250), isTrue);

      expect(SeasonPassLogic.remainingDailyPvpAllowance(0), equals(200));
      expect(SeasonPassLogic.remainingDailyPvpAllowance(75), equals(125));
      expect(SeasonPassLogic.remainingDailyPvpAllowance(200), equals(0));
      expect(SeasonPassLogic.remainingDailyPvpAllowance(300), equals(0));
      expect(SeasonPassLogic.remainingDailyPvpAllowance(-10), equals(200));
    });
  });

  group('SeasonPassLogic - Reward Claim Tracking & Eligibility', () {
    test('isLevelReached requires rewardLevel > 0 and currentLevel >= rewardLevel', () {
      expect(SeasonPassLogic.isLevelReached(currentLevel: 5, rewardLevel: 0), isFalse);
      expect(SeasonPassLogic.isLevelReached(currentLevel: 4, rewardLevel: 5), isFalse);
      expect(SeasonPassLogic.isLevelReached(currentLevel: 5, rewardLevel: 5), isTrue);
      expect(SeasonPassLogic.isLevelReached(currentLevel: 10, rewardLevel: 5), isTrue);
      expect(SeasonPassLogic.isLevelReached(currentLevel: 0, rewardLevel: 1), isFalse);
    });

    test('isFreeRewardClaimable only true when reached and not claimed', () {
      final claimedList = <int>[1, 2, 3];

      // Not reached
      expect(
        SeasonPassLogic.isFreeRewardClaimable(
          currentLevel: 4,
          rewardLevel: 5,
          claimedNormal: claimedList,
        ),
        isFalse,
      );

      // Reached and already claimed
      expect(
        SeasonPassLogic.isFreeRewardClaimable(
          currentLevel: 5,
          rewardLevel: 2,
          claimedNormal: claimedList,
        ),
        isFalse,
      );

      // Reached and unclaimed
      expect(
        SeasonPassLogic.isFreeRewardClaimable(
          currentLevel: 5,
          rewardLevel: 4,
          claimedNormal: claimedList,
        ),
        isTrue,
      );
      expect(
        SeasonPassLogic.isFreeRewardClaimable(
          currentLevel: 5,
          rewardLevel: 5,
          claimedNormal: claimedList,
        ),
        isTrue,
      );
    });

    test('isVipRewardClaimable requires hasVip, reached, and not claimed', () {
      final claimedVipList = <int>[1, 2];

      // Missing VIP pass
      expect(
        SeasonPassLogic.isVipRewardClaimable(
          currentLevel: 5,
          rewardLevel: 3,
          hasVip: false,
          claimedVip: claimedVipList,
        ),
        isFalse,
      );

      // Has VIP pass but level not reached
      expect(
        SeasonPassLogic.isVipRewardClaimable(
          currentLevel: 4,
          rewardLevel: 5,
          hasVip: true,
          claimedVip: claimedVipList,
        ),
        isFalse,
      );

      // Has VIP pass, reached, but already claimed
      expect(
        SeasonPassLogic.isVipRewardClaimable(
          currentLevel: 5,
          rewardLevel: 2,
          hasVip: true,
          claimedVip: claimedVipList,
        ),
        isFalse,
      );

      // Has VIP pass, reached, and unclaimed
      expect(
        SeasonPassLogic.isVipRewardClaimable(
          currentLevel: 5,
          rewardLevel: 3,
          hasVip: true,
          claimedVip: claimedVipList,
        ),
        isTrue,
      );
    });

    test('isVipRewardLocked indicates reward reached but locked specifically by missing VIP', () {
      // Reached, but no VIP -> locked by VIP
      expect(
        SeasonPassLogic.isVipRewardLocked(
          currentLevel: 5,
          rewardLevel: 5,
          hasVip: false,
        ),
        isTrue,
      );

      // Reached and has VIP -> not locked by VIP
      expect(
        SeasonPassLogic.isVipRewardLocked(
          currentLevel: 5,
          rewardLevel: 5,
          hasVip: true,
        ),
        isFalse,
      );

      // Not reached -> locked by level, NOT specifically VIP
      expect(
        SeasonPassLogic.isVipRewardLocked(
          currentLevel: 4,
          rewardLevel: 5,
          hasVip: false,
        ),
        isFalse,
      );
    });

    test('countClaimableRewards calculates total pending claims across both tracks', () {
      final rewards = List.generate(
        5,
        (i) => BpLevelReward(
          level: i + 1,
          normalRewardQuantity: 1,
          normalRewardGold: 100,
          vipRewardQuantity: 1,
          vipRewardGold: 200,
        ),
      );

      // Null status
      expect(
        SeasonPassLogic.countClaimableRewards(status: null, rewards: rewards),
        equals(0),
      );

      // Level 3, no VIP, claimed nothing: 3 free rewards
      final status1 = BpPlayerStatus(
        playerId: 'p1',
        seasonId: 's1',
        currentLevel: 3,
        currentBpp: 3000,
        dailyGrindBppPool: 0,
        dailyPvpBppPool: 0,
        hasVip: false,
        claimedNormal: [],
        claimedVip: [],
        updatedAt: DateTime.now(),
      );
      expect(
        SeasonPassLogic.countClaimableRewards(status: status1, rewards: rewards),
        equals(3),
      );

      // Level 3, with VIP, claimed nothing: 3 free + 3 VIP = 6
      final status2 = BpPlayerStatus(
        playerId: 'p1',
        seasonId: 's1',
        currentLevel: 3,
        currentBpp: 3000,
        dailyGrindBppPool: 0,
        dailyPvpBppPool: 0,
        hasVip: true,
        claimedNormal: [],
        claimedVip: [],
        updatedAt: DateTime.now(),
      );
      expect(
        SeasonPassLogic.countClaimableRewards(status: status2, rewards: rewards),
        equals(6),
      );

      // Level 3, with VIP, claimed level 1 free & level 1 VIP: 2 free + 2 VIP = 4
      final status3 = BpPlayerStatus(
        playerId: 'p1',
        seasonId: 's1',
        currentLevel: 3,
        currentBpp: 3000,
        dailyGrindBppPool: 0,
        dailyPvpBppPool: 0,
        hasVip: true,
        claimedNormal: [1],
        claimedVip: [1],
        updatedAt: DateTime.now(),
      );
      expect(
        SeasonPassLogic.countClaimableRewards(status: status3, rewards: rewards),
        equals(4),
      );
    });
  });

  group('SeasonPassLogic - VIP Pass Affordability & Upgrade', () {
    test('canAffordVipPass and missingGemsForVip against default 500 gem cost', () {
      expect(EconomyConstants.battlePassVipGemCost, equals(500));

      expect(SeasonPassLogic.canAffordVipPass(playerGems: 0), isFalse);
      expect(SeasonPassLogic.missingGemsForVip(playerGems: 0), equals(500));

      expect(SeasonPassLogic.canAffordVipPass(playerGems: 499), isFalse);
      expect(SeasonPassLogic.missingGemsForVip(playerGems: 499), equals(1));

      expect(SeasonPassLogic.canAffordVipPass(playerGems: 500), isTrue);
      expect(SeasonPassLogic.missingGemsForVip(playerGems: 500), equals(0));

      expect(SeasonPassLogic.canAffordVipPass(playerGems: 1200), isTrue);
      expect(SeasonPassLogic.missingGemsForVip(playerGems: 1200), equals(0));
    });

    test('canAffordVipPass supports custom cost override', () {
      expect(
        SeasonPassLogic.canAffordVipPass(playerGems: 300, cost: 300),
        isTrue,
      );
      expect(
        SeasonPassLogic.canAffordVipPass(playerGems: 299, cost: 300),
        isFalse,
      );
      expect(
        SeasonPassLogic.missingGemsForVip(playerGems: 250, cost: 300),
        equals(50),
      );
    });
  });

  group('SeasonPassLogic - Quest Progression & Sorting', () {
    test('calculateQuestProgress clamps between 0.0 and 1.0', () {
      expect(
        SeasonPassLogic.calculateQuestProgress(
          currentProgress: 0,
          targetCount: 10,
        ),
        equals(0.0),
      );
      expect(
        SeasonPassLogic.calculateQuestProgress(
          currentProgress: 5,
          targetCount: 10,
        ),
        closeTo(0.5, 0.0001),
      );
      expect(
        SeasonPassLogic.calculateQuestProgress(
          currentProgress: 10,
          targetCount: 10,
        ),
        equals(1.0),
      );
      expect(
        SeasonPassLogic.calculateQuestProgress(
          currentProgress: 15,
          targetCount: 10,
        ),
        equals(1.0),
      );
      expect(
        SeasonPassLogic.calculateQuestProgress(
          currentProgress: 5,
          targetCount: 0,
        ),
        equals(0.0),
      );
    });

    test('isQuestClaimable only true when isCompleted and not rewardClaimed', () {
      expect(
        SeasonPassLogic.isQuestClaimable(isCompleted: false, rewardClaimed: false),
        isFalse,
      );
      expect(
        SeasonPassLogic.isQuestClaimable(isCompleted: true, rewardClaimed: false),
        isTrue,
      );
      expect(
        SeasonPassLogic.isQuestClaimable(isCompleted: true, rewardClaimed: true),
        isFalse,
      );
    });

    test('sortQuests prioritizes unclaimed completed, then active, then claimed', () {
      final now = DateTime.now();
      final qClaimable = BpPlayerQuest(
        id: 'q_claimable',
        playerId: 'p1',
        seasonId: 's1',
        templateId: 't1',
        currentProgress: 10,
        isCompleted: true,
        rewardClaimed: false,
        updatedAt: now,
      );
      final qInProgressLow = BpPlayerQuest(
        id: 'q_low',
        playerId: 'p1',
        seasonId: 's1',
        templateId: 't2',
        currentProgress: 2,
        isCompleted: false,
        rewardClaimed: false,
        updatedAt: now,
      );
      final qInProgressHigh = BpPlayerQuest(
        id: 'q_high',
        playerId: 'p1',
        seasonId: 's1',
        templateId: 't3',
        currentProgress: 8,
        isCompleted: false,
        rewardClaimed: false,
        updatedAt: now,
      );
      final qDoneAndClaimed = BpPlayerQuest(
        id: 'q_claimed',
        playerId: 'p1',
        seasonId: 's1',
        templateId: 't4',
        currentProgress: 10,
        isCompleted: true,
        rewardClaimed: true,
        updatedAt: now,
      );

      final unsorted = [
        qDoneAndClaimed,
        qInProgressLow,
        qClaimable,
        qInProgressHigh,
      ];

      final sorted = SeasonPassLogic.sortQuests(unsorted);

      expect(sorted.map((q) => q.id).toList(), equals([
        'q_claimable',
        'q_high',
        'q_low',
        'q_claimed',
      ]));
    });
  });

  group('SeasonPassLogic - Milestone Levels', () {
    test('identifies key milestone levels 5, 10, 15, 20', () {
      expect(SeasonPassLogic.isMilestoneLevel(5), isTrue);
      expect(SeasonPassLogic.isMilestoneLevel(10), isTrue);
      expect(SeasonPassLogic.isMilestoneLevel(15), isTrue);
      expect(SeasonPassLogic.isMilestoneLevel(20), isTrue);

      expect(SeasonPassLogic.isMilestoneLevel(1), isFalse);
      expect(SeasonPassLogic.isMilestoneLevel(4), isFalse);
      expect(SeasonPassLogic.isMilestoneLevel(7), isFalse);
      expect(SeasonPassLogic.isMilestoneLevel(19), isFalse);
      expect(SeasonPassLogic.isMilestoneLevel(21), isFalse);
    });
  });

  group('BattlePass Models - Parsing & Logic Integrity', () {
    test('BpPlayerStatus.fromJson with defaults', () {
      final json = <String, dynamic>{
        'player_id': 'player_abc',
        'season_id': 'season_1',
        'current_level': 12,
        'current_bpp': 12450,
        'updated_at': '2026-10-28T20:00:00Z',
      };

      final status = BpPlayerStatus.fromJson(json);

      expect(status.playerId, equals('player_abc'));
      expect(status.seasonId, equals('season_1'));
      expect(status.currentLevel, equals(12));
      expect(status.currentBpp, equals(12450));
      expect(status.dailyGrindBppPool, equals(0));
      expect(status.dailyPvpBppPool, equals(0));
      expect(status.hasVip, isFalse);
      expect(status.claimedNormal, isEmpty);
      expect(status.claimedVip, isEmpty);
    });

    test('BpSeasonRewardEntry label formatting', () {
      const goldEntry = BpSeasonRewardEntry(
        track: 'free',
        level: 1,
        rewardType: 'gold',
        gold: 5000,
        gems: 0,
        quantity: 1,
        displayName: '5000 Altın',
        displayRarity: 'common',
      );
      expect(goldEntry.label, equals('5000 Altın'));

      const gemsEntry = BpSeasonRewardEntry(
        track: 'vip',
        level: 10,
        rewardType: 'gems',
        gold: 0,
        gems: 100,
        quantity: 1,
        displayName: '100 Elmas',
        displayRarity: 'rare',
      );
      expect(gemsEntry.label, equals('100 Elmas'));

      const itemEntry = BpSeasonRewardEntry(
        track: 'vip',
        level: 20,
        rewardType: 'item',
        gold: 0,
        gems: 0,
        quantity: 1,
        itemId: 'wings_celestial',
        itemName: 'Daeva Kanatları',
        displayName: 'Kanatlar',
        displayRarity: 'legendary',
      );
      expect(itemEntry.label, equals('Daeva Kanatları x1'));
    });

    test('BpSeasonRewardsBundle converts to level rewards preserving track contents', () {
      final bundle = BpSeasonRewardsBundle(
        seasonId: 'season_1',
        seasonNumber: 1,
        levels: [
          const BpSeasonLevelRewards(
            level: 1,
            free: BpSeasonRewardEntry(
              track: 'free',
              level: 1,
              rewardType: 'gold',
              gold: 1500,
              gems: 0,
              quantity: 1,
              displayName: 'Altın Kesesi',
              displayRarity: 'common',
            ),
            vip: BpSeasonRewardEntry(
              track: 'vip',
              level: 1,
              rewardType: 'item',
              gold: 0,
              gems: 0,
              quantity: 3,
              itemId: 'potion_celestial',
              itemName: 'Daeva İksiri',
              displayName: 'İksir',
              displayRarity: 'rare',
            ),
          ),
        ],
        featuredFree: [],
        featuredVip: [],
      );

      final levelRewards = bundle.toLevelRewards();
      expect(levelRewards.length, equals(1));
      final r = levelRewards.first;
      expect(r.level, equals(1));
      expect(r.normalRewardGold, equals(1500));
      expect(r.vipRewardItemId, equals('potion_celestial'));
      expect(r.vipRewardQuantity, equals(3));
      expect(r.vipRewardItem?['name'], equals('Daeva İksiri'));
    });
  });
}
