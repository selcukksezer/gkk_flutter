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

  test('isBannedForDungeon uses banned_dungeon_ids from global status', () {
    final DungeonSiegeStatus status = DungeonSiegeStatus.fromJson(<String, dynamic>{
      'enabled': true,
      'in_prime_window': true,
      'siege_active': true,
      'is_banned': false,
      'banned_dungeon_ids': <String>['dng_010'],
      'sessions': <dynamic>[],
      'config': <String, dynamic>{'is_enabled': true},
    });

    expect(status.isBannedForDungeon('dng_010'), isTrue);
    expect(status.isBannedForDungeon('dng_020'), isFalse);
  });

  test('territoryDefenseSiegeBonusPct caps at 25%', () {
    expect(DungeonSiegeConfig.territoryDefenseSiegeBonusPct(800), 0.2);
    expect(DungeonSiegeConfig.territoryDefenseSiegeBonusPct(1000), 0.25);
    expect(DungeonSiegeConfig.territoryDefenseSiegeBonusPct(50000), 0.25);
  });

  test('territoryDefenseSummary mentions owner-only bonus', () {
    expect(
      DungeonSiegeConfig.territoryDefenseSummary(800),
      '🛡 800 · owner slot +20% (max %25)',
    );
  });

  test('effectiveSiegePowerForSlot applies owner territory bonus', () {
    const DungeonSiegeSession session = DungeonSiegeSession(
      sessionId: 's1',
      dungeonId: 'dng_030',
      zoneNumber: 3,
      endsAt: null,
      slots: <DungeonSiegeSlot>[],
      territoryOwnerGuildId: 'guild-owner',
      territoryDefensePower: 800,
      territoryDefenseMaxBonusPct: 0.2,
    );
    const DungeonSiegeSlot ownerSlot = DungeonSiegeSlot(
      slotId: 'slot-1',
      slotNumber: 1,
      holderId: 'p1',
      holderPower: 1000,
      guildId: 'guild-owner',
    );
    const DungeonSiegeSlot otherSlot = DungeonSiegeSlot(
      slotId: 'slot-2',
      slotNumber: 2,
      holderId: 'p2',
      holderPower: 1000,
      guildId: 'guild-other',
    );

    expect(session.effectiveSiegePowerForSlot(ownerSlot), 1200);
    expect(session.effectiveSiegePowerForSlot(otherSlot), 1000);
    expect(session.slotReceivesTerritoryDefenseBonus(ownerSlot), isTrue);
    expect(session.slotReceivesTerritoryDefenseBonus(otherSlot), isFalse);
  });

  test('DungeonSiegeSlot parses guild_id', () {
    final DungeonSiegeSlot slot = DungeonSiegeSlot.fromJson(<String, dynamic>{
      'slot_id': 's1',
      'slot_number': 1,
      'holder_power': 500,
      'guild_id': 'guild-abc',
    });
    expect(slot.guildId, 'guild-abc');
  });

  test('DungeonSiegeSession hold + defense helpers', () {
    const DungeonSiegeSession ownerSession = DungeonSiegeSession(
      sessionId: 's1',
      dungeonId: 'dng_030',
      zoneNumber: 3,
      endsAt: null,
      slots: <DungeonSiegeSlot>[],
      territoryOwnerGuildId: 'guild-owner',
      territoryDefensePower: 800,
      territoryDefenseSiegeBonusPct: 0.2,
      territoryDefenseMaxBonusPct: 0.2,
      guildSlots: 1,
    );

    expect(ownerSession.holdMinRequired(DungeonSiegeConfig.fromJson(<String, dynamic>{
      'is_enabled': true,
      'hold_min_members': 3,
    }), myGuildId: 'guild-owner'), 3);
    expect(ownerSession.canStartHold(DungeonSiegeConfig.fromJson(<String, dynamic>{
      'is_enabled': true,
      'hold_min_members': 3,
    }), myGuildId: 'guild-owner'), isFalse);
    expect(ownerSession.canStartHold(DungeonSiegeConfig.fromJson(<String, dynamic>{
      'is_enabled': true,
      'hold_min_members': 3,
    }), myGuildId: 'guild-other'), isFalse);
    expect(ownerSession.receivesTerritoryDefenseBonus('guild-owner'), isTrue);
    expect(ownerSession.receivesTerritoryDefenseBonus('guild-other'), isFalse);
  });

  test('DungeonSiegeSession parses hold and territory fields', () {
    final DungeonSiegeSession session = DungeonSiegeSession.fromJson(<String, dynamic>{
      'session_id': 'sess-1',
      'dungeon_id': 'dng_010',
      'zone_number': 1,
      'ends_at': '2026-07-22T21:00:00Z',
      'territory_owner_guild_name': 'Demir Lonca',
      'territory_owner_guild_id': 'guild-1',
      'territory_defense_power': 800,
      'territory_defense_siege_bonus_pct': 0.2,
      'territory_defense_max_bonus_pct': 0.2,
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
    expect(session.territoryDefensePower, 800);
    expect(session.territoryDefenseSiegeBonusPercent, 20);
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

  test('DungeonSiegeRunBonus parses result metadata', () {
    const DungeonSiegeRunBonus bonus = DungeonSiegeRunBonus(
      active: true,
      primeActive: true,
      hasSlot: true,
      applied: true,
      hasHoldBonus: true,
      lootBonusPct: 55,
      goldBonusPct: 40,
      holdBonusPct: 15,
      repGained: 5,
    );

    expect(bonus.shouldShowOnResult, isTrue);
    expect(bonus.resultSummary(), '+55% loot, +40% altın, +5 itibar');
    expect(bonus.holdExtraLine(), contains('+15%'));

    final DungeonSiegeRunBonus parsed = DungeonSiegeRunBonus.fromJson(<String, dynamic>{
      'active': true,
      'prime_active': true,
      'has_slot': true,
      'applied': true,
      'loot_bonus_pct': 40,
      'gold_bonus_pct': 25,
      'rep_gained': 5,
    });

    expect(parsed.lootBonusPct, 40);
    expect(parsed.goldBonusPct, 25);
    expect(parsed.shouldShowOnResult, isTrue);

    const DungeonSiegeRunBonus noSlot = DungeonSiegeRunBonus(
      active: true,
      primeActive: true,
      applied: true,
      hasSlot: false,
      slotLootBonusPct: 40,
      slotGoldBonusPct: 25,
    );
    expect(noSlot.shouldShowNoSlotWarning, isTrue);
    expect(noSlot.noSlotWarningText(slotLootPct: 40, slotGoldPct: 25), contains('slot yok'));
  });

  test('DungeonSiegeStatus challenge gating blocks holder from other slots', () {
    const DungeonSiegeSlot mySlot = DungeonSiegeSlot(
      slotId: 'mine',
      slotNumber: 1,
      holderId: 'player-1',
      isMine: true,
    );
    const DungeonSiegeSlot otherSlot = DungeonSiegeSlot(
      slotId: 'other',
      slotNumber: 2,
      holderId: 'player-2',
    );

    final DungeonSiegeStatus status = DungeonSiegeStatus.fromJson(<String, dynamic>{
      'enabled': true,
      'in_prime_window': true,
      'siege_active': true,
      'is_banned': false,
      'sessions': <dynamic>[
        <String, dynamic>{
          'session_id': 'sess-1',
          'dungeon_id': 'dng_010',
          'zone_number': 1,
          'slots': <dynamic>[
            <String, dynamic>{
              'slot_id': 'mine',
              'slot_number': 1,
              'holder_id': 'player-1',
              'is_mine': true,
              'is_occupied': true,
            },
            <String, dynamic>{
              'slot_id': 'other',
              'slot_number': 2,
              'holder_id': 'player-2',
              'is_occupied': true,
            },
          ],
        },
      ],
      'config': <String, dynamic>{'is_enabled': true},
    });

    expect(status.hasSlotInDungeon('dng_010'), isTrue);
    expect(status.canChallengeSlot('dng_010', mySlot), isFalse);
    expect(status.canChallengeSlot('dng_010', otherSlot), isFalse);
  });

  test('DungeonSiegeStatus allows challenge when no slot held in dungeon', () {
    const DungeonSiegeSlot otherSlot = DungeonSiegeSlot(
      slotId: 'other',
      slotNumber: 2,
      holderId: 'player-2',
    );

    final DungeonSiegeStatus status = DungeonSiegeStatus.fromJson(<String, dynamic>{
      'enabled': true,
      'in_prime_window': true,
      'siege_active': true,
      'is_banned': false,
      'sessions': <dynamic>[
        <String, dynamic>{
          'session_id': 'sess-1',
          'dungeon_id': 'dng_010',
          'zone_number': 1,
          'slots': <dynamic>[
            <String, dynamic>{
              'slot_id': 'mine',
              'slot_number': 1,
              'is_occupied': false,
            },
            <String, dynamic>{
              'slot_id': 'other',
              'slot_number': 2,
              'holder_id': 'player-2',
              'is_occupied': true,
            },
          ],
        },
      ],
      'config': <String, dynamic>{'is_enabled': true},
    });

    expect(status.hasSlotInDungeon('dng_010'), isFalse);
    expect(status.canChallengeSlot('dng_010', otherSlot), isTrue);
  });
}
