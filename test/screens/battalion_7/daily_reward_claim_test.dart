import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/models/daily_reward_model.dart';
import 'package:gkk_flutter/providers/daily_reward_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DailyRewardStatus & Claim Validation Tests', () {
    test('DailyRewardStatus correctly parses JSON and enforces double-claim prevention flag', () {
      final jsonCanClaim = <String, dynamic>{
        'can_claim': true,
        'cycle_day': 3,
        'cycle_length': 28,
        'streak_length': 2,
        'claimed_today': false,
        'next_reset_at': '2026-10-29T00:00:00.000Z',
        'timezone': 'UTC',
        'today_reward': <String, dynamic>{
          'cycle_day': 3,
          'display_label': 'Gün 3 Ödülü',
          'is_milestone': false,
          'gold': 1500,
          'gems': 10,
          'xp': 300,
          'energy': 25,
          'item_id': 'health_potion_lg',
          'item_name': 'Büyük Can İksiri',
          'item_quantity': 2,
        },
        'week_calendar': <dynamic>[
          <String, dynamic>{
            'cycle_day': 1,
            'status': 'completed',
            'reward': <String, dynamic>{
              'cycle_day': 1,
              'display_label': 'Gün 1',
              'is_milestone': false,
              'gold': 500,
              'gems': 0,
              'xp': 100,
              'energy': 10,
              'item_id': null,
              'item_name': null,
              'item_quantity': 0,
            },
          },
          <String, dynamic>{
            'cycle_day': 2,
            'status': 'completed',
            'reward': <String, dynamic>{
              'cycle_day': 2,
              'display_label': 'Gün 2',
              'is_milestone': false,
              'gold': 1000,
              'gems': 5,
              'xp': 200,
              'energy': 15,
              'item_id': null,
              'item_name': null,
              'item_quantity': 0,
            },
          },
          <String, dynamic>{
            'cycle_day': 3,
            'status': 'today',
            'reward': <String, dynamic>{
              'cycle_day': 3,
              'display_label': 'Gün 3',
              'is_milestone': false,
              'gold': 1500,
              'gems': 10,
              'xp': 300,
              'energy': 25,
              'item_id': 'health_potion_lg',
              'item_name': 'Büyük Can İksiri',
              'item_quantity': 2,
            },
          },
        ],
      };

      final status = DailyRewardStatus.fromJson(jsonCanClaim);
      expect(status.canClaim, isTrue);
      expect(status.claimedToday, isFalse);
      expect(status.cycleDay, 3);
      expect(status.streakLength, 2);
      expect(status.todayReward.gold, 1500);
      expect(status.todayReward.gems, 10);
      expect(status.todayReward.hasItem, isTrue);
      expect(status.todayReward.itemName, 'Büyük Can İksiri');

      // Verify cannot double-claim when claimed_today is true
      final jsonAlreadyClaimed = Map<String, dynamic>.from(jsonCanClaim)
        ..['can_claim'] = false
        ..['claimed_today'] = true;

      final claimedStatus = DailyRewardStatus.fromJson(jsonAlreadyClaimed);
      expect(claimedStatus.canClaim, isFalse);
      expect(claimedStatus.claimedToday, isTrue);
    });

    test('Timestamp persistence parses ISO-8601 next_reset_at accurately across timezones', () {
      final isoString = '2026-10-30T00:00:00.000Z';
      final status = DailyRewardStatus.fromJson(<String, dynamic>{
        'can_claim': false,
        'cycle_day': 5,
        'cycle_length': 7,
        'streak_length': 5,
        'claimed_today': true,
        'next_reset_at': isoString,
        'today_reward': <String, dynamic>{
          'cycle_day': 5,
          'display_label': 'Gün 5',
          'is_milestone': true,
          'gold': 5000,
          'gems': 50,
          'xp': 1000,
          'energy': 50,
          'item_id': null,
          'item_name': null,
          'item_quantity': 0,
        },
      });

      expect(status.nextResetAt, isNotNull);
      expect(status.nextResetAt!.isUtc, isTrue);
      expect(status.nextResetAt!.year, 2026);
      expect(status.nextResetAt!.month, 10);
      expect(status.nextResetAt!.day, 30);
      expect(status.nextResetAt!.hour, 0);
      expect(status.nextResetAt!.toIso8601String(), isoString);
    });

    test('DailyRewardClaimResult preserves rewards and item skip warnings', () {
      final resultWithWarning = DailyRewardClaimResult.fromJson(<String, dynamic>{
        'success': true,
        'cycle_day': 7,
        'streak_length': 7,
        'item_skipped': true,
        'warning': 'Envanter dolu olduğu için eşya ödülü verilemedi.',
        'rewards_granted': <String, dynamic>{
          'cycle_day': 7,
          'gold': 10000,
          'gems': 100,
          'xp': 2500,
          'energy': 100,
        },
      });

      expect(resultWithWarning.success, isTrue);
      expect(resultWithWarning.cycleDay, 7);
      expect(resultWithWarning.streakLength, 7);
      expect(resultWithWarning.itemSkipped, isTrue);
      expect(resultWithWarning.warning, contains('Envanter dolu'));
      expect(resultWithWarning.rewardsGranted?.gold, 10000);
      expect(resultWithWarning.rewardsGranted?.gems, 100);
    });

    test('DailyRewardState tracks session auto-prompting and prevents repetitive dialog pops', () {
      var state = const DailyRewardState();
      expect(state.autoPromptedThisSession, isFalse);
      expect(state.didAutoPromptThisSession, isFalse);

      state = state.copyWith(autoPromptedThisSession: true);
      expect(state.autoPromptedThisSession, isTrue);
      expect(state.didAutoPromptThisSession, isTrue);

      // copyWith without argument preserves autoPromptedThisSession
      state = state.copyWith(claimInProgress: true);
      expect(state.autoPromptedThisSession, isTrue);
    });
  });
}
