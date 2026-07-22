import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/dungeon_siege_model.dart';

void main() {
  test('DungeonSiegeConfig parses siege dungeon ids from list', () {
    final DungeonSiegeConfig config = DungeonSiegeConfig.fromJson(<String, dynamic>{
      'is_enabled': true,
      'slot_count': 6,
      'siege_dungeon_ids': <String>['dng_010', 'dng_020'],
      'rep_bonus_pct': 0.15,
      'power_band_pct': 0.25,
      'challenge_cooldown_minutes': 5,
    });

    expect(config.slotCount, 6);
    expect(config.siegeDungeonIds, contains('dng_010'));
    expect(config.repBonusPct, 0.15);
    expect(config.powerBandPct, 0.25);
    expect(config.challengeCooldownMinutes, 5);
  });

  test('isSiegeDungeon prefers config ids when status provided', () {
    final DungeonSiegeStatus status = DungeonSiegeStatus.fromJson(<String, dynamic>{
      'enabled': true,
      'in_prime_window': true,
      'siege_active': true,
      'is_banned': false,
      'sessions': <dynamic>[],
      'config': <String, dynamic>{
        'is_enabled': true,
        'siege_dungeon_ids': <String>['dng_010'],
      },
    });

    expect(isSiegeDungeon('dng_010', status: status), isTrue);
    expect(isSiegeDungeon('dng_020', status: status), isFalse);
  });

  test('DungeonSiegeSession parses hold and territory fields', () {
    final DungeonSiegeSession session = DungeonSiegeSession.fromJson(<String, dynamic>{
      'session_id': 'sess-1',
      'dungeon_id': 'dng_010',
      'zone_number': 1,
      'ends_at': '2026-07-22T21:00:00Z',
      'territory_owner_guild_name': 'Demir Lonca',
      'territory_owner_guild_id': 'guild-1',
      'guild_slots': 3,
      'hold': <String, dynamic>{
        'hold_id': 'hold-1',
        'guild_id': 'guild-1',
        'guild_name': 'Demir Lonca',
        'break_progress': 1,
        'break_required': 3,
        'member_slots': 4,
      },
      'slots': <dynamic>[
        <String, dynamic>{
          'slot_id': 's1',
          'slot_number': 1,
          'is_territory_reserved': true,
        },
      ],
    });

    expect(session.territoryOwnerGuildName, 'Demir Lonca');
    expect(session.territoryOwnerGuildId, 'guild-1');
    expect(session.guildSlots, 3);
    expect(session.hold?.holdId, 'hold-1');
    expect(session.slots.first.isTerritoryReserved, isTrue);
  });

  test('DungeonSiegeActionResult parses Faz B fields', () {
    final DungeonSiegeActionResult result = DungeonSiegeActionResult.fromJson(<String, dynamic>{
      'success': true,
      'you_won': true,
      'hold_broken': true,
      'hold_break_progress': 3,
      'gold_spent': 500,
      'territory_reserved': true,
      'slot_number': 1,
    });

    expect(result.holdBroken, isTrue);
    expect(result.holdBreakProgress, 3);
    expect(result.goldSpent, 500);
    expect(result.territoryReserved, isTrue);
    expect(result.slotNumber, 1);
  });

  test('DungeonSiegeNotification parses payload', () {
    final DungeonSiegeNotification n = DungeonSiegeNotification.fromJson(<String, dynamic>{
      'id': 'n1',
      'type': 'slot_challenged',
      'title': 'Test',
      'body': 'Body',
      'is_unread': true,
      'payload': <String, dynamic>{'dungeon_id': 'dng_010'},
    });

    expect(n.dungeonIdFromPayload, 'dng_010');
    expect(n.isUnread, isTrue);
  });

  test('DungeonSiegeHub parses leaderboard and challenges', () {
    final DungeonSiegeHub hub = DungeonSiegeHub.fromJson(<String, dynamic>{
      'week_key': '2026-W30',
      'status': <String, dynamic>{
        'enabled': true,
        'in_prime_window': true,
        'siege_active': true,
        'is_banned': false,
        'sessions': <dynamic>[],
        'config': <String, dynamic>{'is_enabled': true},
      },
      'leaderboard': <dynamic>[
        <String, dynamic>{'rank': 1, 'player_name': 'Alpha', 'points': 120, 'slot_minutes': 5},
      ],
      'recent_challenges': <dynamic>[
        <String, dynamic>{
          'id': 'c1',
          'dungeon_id': 'dng_010',
          'challenger_name': 'A',
          'defender_name': 'B',
          'winner_name': 'A',
        },
      ],
      'territories': <dynamic>[
        <String, dynamic>{
          'zone_number': 1,
          'territory_id': 't1',
          'territory_name': 'Demir Kalesi',
          'owner_guild_name': 'X',
          'siege_dungeon_id': 'dng_010',
        },
      ],
    });

    expect(hub.weekKey, '2026-W30');
    expect(hub.leaderboard.first.playerName, 'Alpha');
    expect(hub.territories.first.territoryId, 't1');
    expect(hub.territories.first.siegeDungeonId, 'dng_010');
  });
}
