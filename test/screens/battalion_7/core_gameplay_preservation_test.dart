import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/models/dungeon_siege_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Core Mobile Gameplay Logic Preservation Tests', () {
    test('PlayerProfile preserves core attributes, leveling progression, and stamina constraints', () {
      final json = <String, dynamic>{
        'id': 'hero_77',
        'auth_id': 'auth_hero_77',
        'username': 'ValiantWarrior',
        'email': 'valiant@mobile.game',
        'display_name': 'Valiant',
        'level': 25,
        'xp': 14500,
        'gold': 85000,
        'gems': 120.0,
        'energy': 85,
        'max_energy': 120,
        'attack': 180,
        'defense': 140,
        'health': 920,
        'max_health': 920,
        'power': 420,
        'is_online': true,
        'is_banned': false,
        'tutorial_completed': true,
        'pvp_rating': 1650,
        'pvp_wins': 48,
        'pvp_losses': 12,
        'addiction_level': 1,
        'tolerance': 3,
        'hospital_lifetime_count': 2,
        'global_suspicion_level': 0,
        'created_at': '2026-04-10T10:00:00Z',
        'updated_at': '2026-10-28T20:00:00Z',
      };

      final profile = PlayerProfile.fromJson(json);

      // Core RPG Attributes
      expect(profile.level, 25);
      expect(profile.xp, 14500);
      expect(profile.attack, 180);
      expect(profile.defense, 140);
      expect(profile.power, 420);

      // Health and Energy (Stamina) Invariants
      expect(profile.health, lessThanOrEqualTo(profile.maxHealth));
      expect(profile.energy, lessThanOrEqualTo(profile.maxEnergy));
      expect(profile.health, 920);
      expect(profile.energy, 85);

      // Economy Balances
      expect(profile.gold, 85000);
      expect(profile.gems, 120.0);
      expect(profile.gold, greaterThanOrEqualTo(0));
      expect(profile.gems, greaterThanOrEqualTo(0.0));

      // PvP Stats
      expect(profile.pvpRating, 1650);
      expect(profile.pvpWins, 48);
      expect(profile.pvpLosses, 12);
      final winRate = profile.pvpWins / (profile.pvpWins + profile.pvpLosses);
      expect(winRate, closeTo(0.80, 0.01));

      // Hospital & Prison status flags
      expect(profile.hospitalUntil, isNull);
      expect(profile.prisonUntil, isNull);
      expect(profile.isBanned, isFalse);
    });

    test('Hospitalized state correctly activates hospital cooldown', () {
      final hospitalRelease = DateTime.now().add(const Duration(minutes: 15));
      final json = <String, dynamic>{
        'id': 'hero_injured',
        'auth_id': 'auth_injured',
        'username': 'InjuredHero',
        'email': 'injured@mobile.game',
        'level': 10,
        'xp': 1000,
        'gold': 500,
        'gems': 0.0,
        'energy': 10,
        'max_energy': 100,
        'attack': 50,
        'defense': 40,
        'health': 0,
        'max_health': 200,
        'power': 90,
        'is_online': true,
        'is_banned': false,
        'tutorial_completed': true,
        'hospital_until': hospitalRelease.toIso8601String(),
        'hospital_reason': 'Defeated in high-tier dungeon siege',
        'hospital_lifetime_count': 5,
        'created_at': '2026-04-10T10:00:00Z',
        'updated_at': '2026-10-28T20:00:00Z',
      };

      final profile = PlayerProfile.fromJson(json);
      expect(profile.hospitalUntil, isNotNull);
      expect(DateTime.parse(profile.hospitalUntil!).isAfter(DateTime.now()), isTrue);
      expect(profile.hospitalReason, contains('dungeon siege'));
      expect(profile.health, 0);
    });

    test('Dungeon Siege model preserves prime times, phases, and active status', () {
      final json = <String, dynamic>{
        'enabled': true,
        'in_prime_window': true,
        'siege_active': true,
        'is_banned': false,
        'banned_dungeon_ids': <String>['dng_010'],
        'sessions': <dynamic>[],
        'config': <String, dynamic>{
          'is_enabled': true,
          'slot_count': 6,
          'slot_duration_minutes': 30,
          'challenge_gold_cost': 5000,
          'loot_bonus_pct': 0.20,
          'gold_bonus_pct': 0.15,
          'rep_bonus_pct': 0.10,
          'in_prime_window': true,
          'siege_dungeon_ids': <String>['dng_010', 'dng_020'],
        },
      };

      final status = DungeonSiegeStatus.fromJson(json);
      expect(status.enabled, isTrue);
      expect(status.inPrimeWindow, isTrue);
      expect(status.siegeActive, isTrue);
      expect(status.isBannedForDungeon('dng_010'), isTrue);
      expect(status.isBannedForDungeon('dng_020'), isFalse);
      expect(isSiegeDungeon('dng_010', status: status), isTrue);
      expect(status.config.slotCount, 6);
      expect(status.config.slotDurationMinutes, 30);
      expect(status.config.challengeGoldCost, 5000);
      expect(status.config.goldBonusPct, 0.15);
    });
  });
}
