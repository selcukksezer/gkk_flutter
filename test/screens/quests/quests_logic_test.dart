import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/quest_model.dart';
import 'package:gkk_flutter/screens/quests/quest_logic.dart';

void main() {
  group('QuestLogic — Filtering', () {
    final regularDaily = QuestData(
      id: '1',
      questId: 'q_d_daily_slayer',
      name: 'Daily Slayer',
      description: 'Kill 5 monsters',
      difficulty: QuestDifficulty.easy,
      requiredLevel: 1,
      energyCost: 5,
      goldReward: 100,
      xpReward: 50,
      gemReward: 0,
      itemRewards: const [],
      status: QuestStatus.active,
      progress: 2,
      progressMax: 5,
      target: 5,
    );

    final regularWeekly = QuestData(
      id: '2',
      questId: 'q_w_dungeon_master',
      name: 'Weekly Dungeon Master',
      description: 'Clear 3 dungeons',
      difficulty: QuestDifficulty.hard,
      requiredLevel: 10,
      energyCost: 20,
      goldReward: 500,
      xpReward: 300,
      gemReward: 10,
      itemRewards: const [],
      status: QuestStatus.active,
      progress: 1,
      progressMax: 3,
      target: 3,
    );

    final regularMain = QuestData(
      id: '3',
      questId: 'q_campaign_boss',
      name: 'Defeat Dragon',
      description: 'Elite campaign quest',
      difficulty: QuestDifficulty.elite,
      requiredLevel: 25,
      energyCost: 30,
      goldReward: 2000,
      xpReward: 1500,
      gemReward: 50,
      itemRewards: const ['dragon_scale'],
      status: QuestStatus.available,
      progress: 0,
      progressMax: 1,
      target: 1,
    );

    final regularDungeon = QuestData(
      id: '4',
      questId: 'q_underworld_rift',
      name: 'Underworld Rift',
      description: 'Deep dungeon quest',
      difficulty: QuestDifficulty.dungeon,
      requiredLevel: 30,
      energyCost: 40,
      goldReward: 3000,
      xpReward: 2000,
      gemReward: 100,
      itemRewards: const ['void_crystal'],
      status: QuestStatus.available,
      progress: 0,
      progressMax: 1,
      target: 1,
    );

    final seasonDaily = QuestData(
      id: '5',
      questId: 'bp_quest_daily_01',
      name: 'Season Daily Warmup',
      description: 'Participate in 1 arena match',
      difficulty: QuestDifficulty.medium,
      requiredLevel: 5,
      energyCost: 10,
      goldReward: 0,
      xpReward: 0,
      gemReward: 0,
      itemRewards: const [],
      status: QuestStatus.active,
      progress: 1,
      progressMax: 1,
      target: 1,
      isSeasonQuest: true,
      questType: 'daily',
      bppReward: 25,
    );

    final seasonWeekly = QuestData(
      id: '6',
      questId: 'bp_quest_weekly_01',
      name: 'Season Weekly Raid',
      description: 'Win 5 raids',
      difficulty: QuestDifficulty.hard,
      requiredLevel: 15,
      energyCost: 25,
      goldReward: 0,
      xpReward: 0,
      gemReward: 0,
      itemRewards: const [],
      status: QuestStatus.active,
      progress: 3,
      progressMax: 5,
      target: 5,
      isSeasonQuest: true,
      questType: 'weekly',
      bppReward: 100,
    );

    final allQuests = [
      regularDaily,
      regularWeekly,
      regularMain,
      regularDungeon,
      seasonDaily,
      seasonWeekly,
    ];

    test('QuestCategory.all returns all quests intact', () {
      final result = QuestLogic.filterByCategory(allQuests, QuestCategory.all);
      expect(result.length, equals(6));
      expect(result, equals(allQuests));
    });

    test('QuestCategory.daily returns standard daily prefix/easy/medium and season daily', () {
      final result = QuestLogic.filterByCategory(allQuests, QuestCategory.daily);
      expect(result.contains(regularDaily), isTrue);
      expect(result.contains(seasonDaily), isTrue);
      expect(result.contains(regularWeekly), isFalse);
      expect(result.contains(seasonWeekly), isFalse);
      expect(result.contains(regularMain), isFalse);
    });

    test('QuestCategory.weekly returns standard weekly prefix/hard and season weekly', () {
      final result = QuestLogic.filterByCategory(allQuests, QuestCategory.weekly);
      expect(result.contains(regularWeekly), isTrue);
      expect(result.contains(seasonWeekly), isTrue);
      expect(result.contains(regularDaily), isFalse);
      expect(result.contains(seasonDaily), isFalse);
      expect(result.contains(regularMain), isFalse);
    });

    test('QuestCategory.main returns elite and dungeon non-season quests only', () {
      final result = QuestLogic.filterByCategory(allQuests, QuestCategory.main);
      expect(result.contains(regularMain), isTrue);
      expect(result.contains(regularDungeon), isTrue);
      expect(result.contains(seasonDaily), isFalse);
      expect(result.contains(seasonWeekly), isFalse);
      expect(result.contains(regularDaily), isFalse);
    });
  });

  group('QuestLogic — Sorting & Ordering', () {
    test('sortQuests puts completed first, active second, available/failed last', () {
      final qAvailable = QuestData(
        id: '1',
        questId: 'q_avail',
        name: 'Avail',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 10,
        xpReward: 10,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.available,
        progress: 0,
        progressMax: 10,
        target: 10,
      );

      final qActive50 = QuestData(
        id: '2',
        questId: 'q_act_50',
        name: 'Act 50',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 10,
        xpReward: 10,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.active,
        progress: 5,
        progressMax: 10,
        target: 10,
      );

      final qActive80 = QuestData(
        id: '3',
        questId: 'q_act_80',
        name: 'Act 80',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 10,
        xpReward: 10,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.active,
        progress: 8,
        progressMax: 10,
        target: 10,
      );

      final qCompleted = QuestData(
        id: '4',
        questId: 'q_done',
        name: 'Done',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 10,
        xpReward: 10,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.completed,
        progress: 10,
        progressMax: 10,
        target: 10,
      );

      final sorted = QuestLogic.sortQuests([qAvailable, qActive50, qCompleted, qActive80]);

      expect(sorted[0].questId, equals('q_done')); // Rank 0
      expect(sorted[1].questId, equals('q_act_80')); // Rank 1, 80% > 50%
      expect(sorted[2].questId, equals('q_act_50')); // Rank 1, 50%
      expect(sorted[3].questId, equals('q_avail')); // Rank 2
    });
  });

  group('QuestLogic — Progress & Completion Calculations', () {
    test('calculateProgressFraction clamps correctly', () {
      final qNormal = QuestData(
        id: '1',
        questId: 'q1',
        name: 'n',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 0,
        xpReward: 0,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.active,
        progress: 7,
        progressMax: 10,
        target: 10,
      );
      expect(QuestLogic.calculateProgressFraction(qNormal), closeTo(0.7, 0.001));

      final qOvershoot = QuestData(
        id: '2',
        questId: 'q2',
        name: 'n',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 0,
        xpReward: 0,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.active,
        progress: 15,
        progressMax: 10,
        target: 10,
      );
      expect(QuestLogic.calculateProgressFraction(qOvershoot), equals(1.0));

      final qZeroMax = QuestData(
        id: '3',
        questId: 'q3',
        name: 'n',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 0,
        xpReward: 0,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.active,
        progress: 5,
        progressMax: 0,
        target: 0,
      );
      expect(QuestLogic.calculateProgressFraction(qZeroMax), equals(0.0));
    });

    test('calculateOverallCompletionRate calculates aggregate correctly', () {
      expect(QuestLogic.calculateOverallCompletionRate([]), equals(0.0));

      final q1 = QuestData(
        id: '1',
        questId: 'q1',
        name: 'n',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 0,
        xpReward: 0,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.completed,
        progress: 10,
        progressMax: 10,
        target: 10,
      );

      final q2 = QuestData(
        id: '2',
        questId: 'q2',
        name: 'n',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 0,
        xpReward: 0,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.active,
        progress: 5,
        progressMax: 10,
        target: 10,
      );

      final rate = QuestLogic.calculateOverallCompletionRate([q1, q2]);
      // (1.0 + 0.5) / 2 = 0.75
      expect(rate, closeTo(0.75, 0.001));
    });

    test('countCompletedOrReady counts completed and active-ready quests', () {
      final qDone = QuestData(
        id: '1',
        questId: 'q1',
        name: 'n',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 0,
        xpReward: 0,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.completed,
        progress: 10,
        progressMax: 10,
        target: 10,
      );

      final qActiveReady = QuestData(
        id: '2',
        questId: 'q2',
        name: 'n',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 0,
        xpReward: 0,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.active,
        progress: 10,
        progressMax: 10,
        target: 10,
      );

      final qActivePending = QuestData(
        id: '3',
        questId: 'q3',
        name: 'n',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 0,
        xpReward: 0,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.active,
        progress: 3,
        progressMax: 10,
        target: 10,
      );

      final count = QuestLogic.countCompletedOrReady([qDone, qActiveReady, qActivePending]);
      expect(count, equals(2));
      expect(QuestLogic.isObjectiveCompleted(qActiveReady), isTrue);
      expect(QuestLogic.isObjectiveCompleted(qActivePending), isFalse);
      expect(QuestLogic.needsAction(qDone), isTrue);
      expect(QuestLogic.needsAction(qActiveReady), isTrue);
      expect(QuestLogic.needsAction(qActivePending), isFalse);
    });
  });

  group('QuestLogic — Daily Reset & Time Expiration', () {
    test('formatTimeRemaining handles null and invalid dates', () {
      expect(QuestLogic.formatTimeRemaining(null), isNull);
      expect(QuestLogic.formatTimeRemaining(''), isNull);
      expect(QuestLogic.formatTimeRemaining('not-a-date'), isNull);
    });

    test('formatTimeRemaining returns "Süresi doldu" for past dates', () {
      final now = DateTime(2026, 10, 28, 12, 0);
      final past = DateTime(2026, 10, 28, 11, 0).toIso8601String();
      expect(QuestLogic.formatTimeRemaining(past, now: now), equals('Süresi doldu'));
    });

    test('formatTimeRemaining formats days, hours, and minutes', () {
      final now = DateTime(2026, 10, 28, 12, 0);

      // 2 days, 3 hours later
      final inDays = DateTime(2026, 10, 30, 15, 0).toIso8601String();
      expect(QuestLogic.formatTimeRemaining(inDays, now: now), equals('2g 3s'));

      // 5 hours, 20 mins later
      final inHours = DateTime(2026, 10, 28, 17, 20).toIso8601String();
      expect(QuestLogic.formatTimeRemaining(inHours, now: now), equals('5s 20dk'));

      // 45 minutes later
      final inMinutes = DateTime(2026, 10, 28, 12, 45).toIso8601String();
      expect(QuestLogic.formatTimeRemaining(inMinutes, now: now), equals('45dk kaldı'));
    });

    test('getNextDailyResetUtc computes next midnight UTC correctly', () {
      final morning = DateTime.utc(2026, 10, 28, 8, 30);
      final nextReset = QuestLogic.getNextDailyResetUtc(now: morning, resetHourUtc: 0);
      expect(nextReset, equals(DateTime.utc(2026, 10, 29, 0, 0)));

      final countdown = QuestLogic.formatDailyResetCountdown(now: morning, resetHourUtc: 0);
      expect(countdown, equals('15s 30dk'));
    });
  });

  group('QuestLogic — Rewards & Claims', () {
    final validCompletedQuest = QuestData(
      id: '1',
      questId: 'q_valid',
      name: 'Valid Quest',
      description: 'd',
      difficulty: QuestDifficulty.easy,
      requiredLevel: 1,
      energyCost: 0,
      goldReward: 250,
      xpReward: 100,
      gemReward: 5,
      itemRewards: const [],
      status: QuestStatus.completed,
      progress: 5,
      progressMax: 5,
      target: 5,
    );

    test('validateClaim succeeds on completed quest with valid id', () {
      final result = QuestLogic.validateClaim(validCompletedQuest);
      expect(result.canClaim, isTrue);
      expect(result.failureReason, isNull);
    });

    test('validateClaim rejects empty questId', () {
      final emptyIdQuest = QuestData(
        id: '2',
        questId: '   ',
        name: 'Empty ID',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 100,
        xpReward: 0,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.completed,
        progress: 1,
        progressMax: 1,
        target: 1,
      );
      final result = QuestLogic.validateClaim(emptyIdQuest);
      expect(result.canClaim, isFalse);
      expect(result.failureReason, contains('Geçersiz görev ID'));
    });

    test('validateClaim rejects incomplete quests', () {
      final activeQuest = QuestData(
        id: '3',
        questId: 'q_active',
        name: 'Active Quest',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 100,
        xpReward: 0,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.active,
        progress: 2,
        progressMax: 5,
        target: 5,
      );
      final result = QuestLogic.validateClaim(activeQuest);
      expect(result.canClaim, isFalse);
      expect(result.failureReason, contains('Görev tamamlanmadı'));
    });

    test('formatRewardParts and formatClaimMessage format rewards properly', () {
      final parts = QuestLogic.formatRewardParts(validCompletedQuest);
      expect(parts, equals(['🪙250', '✨100 XP', '💎5']));

      final msg = QuestLogic.formatClaimMessage(validCompletedQuest);
      expect(msg, equals('🎁 Ödül alındı: 🪙250 + ✨100 XP + 💎5'));

      final noRewardQuest = QuestData(
        id: '4',
        questId: 'q_empty',
        name: 'Empty',
        description: 'd',
        difficulty: QuestDifficulty.easy,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 0,
        xpReward: 0,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.completed,
        progress: 1,
        progressMax: 1,
        target: 1,
      );
      expect(QuestLogic.formatClaimMessage(noRewardQuest), equals('🎁 Ödül alındı!'));
    });
  });

  group('QuestLogic — Season Quest Tracking', () {
    test('detectNewCompletedSeasonQuest identifies un-notified season quests', () {
      final seasonCompleted1 = QuestData(
        id: '1',
        questId: 'bp_quest_1',
        bpPlayerQuestId: 'bp_player_1',
        name: 'Season 1',
        description: 'd',
        difficulty: QuestDifficulty.medium,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 0,
        xpReward: 0,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.completed,
        progress: 5,
        progressMax: 5,
        target: 5,
        isSeasonQuest: true,
      );

      final seasonActive = QuestData(
        id: '2',
        questId: 'bp_quest_2',
        name: 'Season 2',
        description: 'd',
        difficulty: QuestDifficulty.medium,
        requiredLevel: 1,
        energyCost: 0,
        goldReward: 0,
        xpReward: 0,
        gemReward: 0,
        itemRewards: const [],
        status: QuestStatus.active,
        progress: 2,
        progressMax: 5,
        target: 5,
        isSeasonQuest: true,
      );

      final known = <String>{};
      final detected = QuestLogic.detectNewCompletedSeasonQuest(
        [seasonActive, seasonCompleted1],
        known,
      );
      expect(detected, equals('bp_player_1'));

      known.add('bp_player_1');
      final secondCheck = QuestLogic.detectNewCompletedSeasonQuest(
        [seasonActive, seasonCompleted1],
        known,
      );
      expect(secondCheck, isNull);
    });
  });

  group('QuestData — Serialization & Fallback Robustness', () {
    test('QuestData.fromJson parses string numbers and defaults smoothly', () {
      final json = <String, dynamic>{
        'id': 'uuid-123',
        'quest_id': 'q_test_parse',
        'name': 'Parse Test',
        'description': 'Testing JSON parsing',
        'difficulty': 'elite',
        'required_level': '15',
        'energy_cost': '10',
        'gold_reward': 500,
        'xp_reward': 250,
        'gem_reward': '5',
        'item_rewards': ['ruby', 'iron_ore'],
        'status': 'active',
        'progress': '3',
        'progress_max': '10',
        'target': '10',
        'expires_at': '2026-12-31T23:59:59Z',
        'is_season_quest': true,
        'bpp_reward': '50',
        'bp_player_quest_id': 'bp_row_456',
        'quest_type': 'daily',
      };

      final quest = QuestData.fromJson(json);
      expect(quest.id, equals('uuid-123'));
      expect(quest.questId, equals('q_test_parse'));
      expect(quest.difficulty, equals(QuestDifficulty.elite));
      expect(quest.requiredLevel, equals(15));
      expect(quest.energyCost, equals(10));
      expect(quest.gemReward, equals(5));
      expect(quest.itemRewards, equals(['ruby', 'iron_ore']));
      expect(quest.status, equals(QuestStatus.active));
      expect(quest.progress, equals(3));
      expect(quest.progressMax, equals(10));
      expect(quest.isSeasonQuest, isTrue);
      expect(quest.bppReward, equals(50));
      expect(quest.bpPlayerQuestId, equals('bp_row_456'));
      expect(quest.questType, equals('daily'));

      final serialized = quest.toJson();
      expect(serialized['quest_id'], equals('q_test_parse'));
      expect(serialized['difficulty'], equals('elite'));
      expect(serialized['status'], equals('active'));
    });

    test('QuestData handles unknown difficulty and status defaults gracefully', () {
      final json = <String, dynamic>{
        'id': 'uuid-fallback',
        'quest_id': 'q_fallback',
        'difficulty': 'unknown_diff',
        'status': 'unknown_status',
      };
      final quest = QuestData.fromJson(json);
      expect(quest.difficulty, equals(QuestDifficulty.medium));
      expect(quest.status, equals(QuestStatus.available));
      expect(quest.requiredLevel, equals(1));
      expect(quest.progressMax, equals(1));
    });
  });
}
