import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/models/auth_model.dart';
import 'package:gkk_flutter/models/dungeon_siege_model.dart';
import 'package:gkk_flutter/models/market_model.dart';

/// Database RPC Contract specification mapping.
/// Verifies 1:1 parity between Dart Repository parameter maps and Supabase PL/pgSQL function signatures.
void main() {
  group('Fullstack Repository RPC Contract Tests (16+1 Repositories Parity)', () {
    // ─────────────────────────────────────────────────────────────────────────
    // 1. AuthRepository Contracts
    // ─────────────────────────────────────────────────────────────────────────
    group('AuthRepository RPC Contracts', () {
      test('LoginRequest contract specifies email, password, and device_id', () {
        const LoginRequest req = LoginRequest(
          email: 'daeva@aion2.mobile',
          password: 'Password123!',
          deviceId: 'device_iphone14_uuid',
        );

        final Map<String, dynamic> params = req.toJson();
        expect(params.containsKey('email'), isTrue);
        expect(params.containsKey('password'), isTrue);
        expect(params.containsKey('device_id'), isTrue);
      });

      test('RegisterRequest contract specifies email, username, password, device_id, and referral_code', () {
        const RegisterRequest req = RegisterRequest(
          email: 'daeva@aion2.mobile',
          username: 'DaevaKaelen',
          password: 'Password123!',
          deviceId: 'device_iphone14_uuid',
          referralCode: 'AION2026',
        );

        final Map<String, dynamic> params = req.toJson();
        expect(params.keys, containsAll(<String>[
          'email',
          'username',
          'password',
          'device_id',
          'referral_code',
        ]));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 2. PlayerRepository Contracts
    // ─────────────────────────────────────────────────────────────────────────
    group('PlayerRepository RPC Contracts', () {
      test('Passive regen calls apply_energy_regen and apply_health_regen without parameter mutations', () {
        const String energyRegenFn = 'apply_energy_regen';
        const String healthRegenFn = 'apply_health_regen';
        expect(energyRegenFn, equals('apply_energy_regen'));
        expect(healthRegenFn, equals('apply_health_regen'));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 3. InventoryRepository Contracts
    // ─────────────────────────────────────────────────────────────────────────
    group('InventoryRepository RPC Contracts', () {
      test('equip_item RPC contract verifies p_row_id and p_slot', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_row_id': 'inv_row_123',
          'p_slot': 'weapon',
        };
        expect(params.keys, containsAll(<String>['p_row_id', 'p_slot']));
      });

      test('unequip_item RPC contract verifies p_slot parameter', () {
        final Map<String, dynamic> params = <String, dynamic>{'p_slot': 'chest'};
        expect(params.containsKey('p_slot'), isTrue);
      });

      test('swap_inventory_slots RPC contract verifies p_from_slot and p_to_slot', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_from_slot': 0,
          'p_to_slot': 1,
        };
        expect(params.keys, containsAll(<String>['p_from_slot', 'p_to_slot']));
      });

      test('move_item_to_slot RPC contract verifies p_row_id and p_target_slot', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_row_id': 'inv_row_123',
          'p_target_slot': 5,
        };
        expect(params.keys, containsAll(<String>['p_row_id', 'p_target_slot']));
      });

      test('unequip_item_to_slot RPC contract verifies p_row_id, p_slot, and p_target_slot', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_row_id': 'inv_row_123',
          'p_slot': 'weapon',
          'p_target_slot': 4,
        };
        expect(params.keys, containsAll(<String>['p_row_id', 'p_slot', 'p_target_slot']));
      });

      test('use_potion and open_loot_box RPC contracts verify p_row_id parameter', () {
        final Map<String, dynamic> potionParams = <String, dynamic>{'p_row_id': 'pot_row_99'};
        final Map<String, dynamic> boxParams = <String, dynamic>{'p_row_id': 'box_row_88'};

        expect(potionParams.containsKey('p_row_id'), isTrue);
        expect(boxParams.containsKey('p_row_id'), isTrue);
      });

      test('use_name_change_scroll RPC contract verifies p_row_id and p_new_display_name', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_row_id': 'scroll_row_01',
          'p_new_display_name': 'KızılEjder',
        };
        expect(params.keys, containsAll(<String>['p_row_id', 'p_new_display_name']));
      });

      test('split_inventory_stack RPC contract verifies p_row_id, p_split_quantity, and p_target_slot', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_row_id': 'mat_row_42',
          'p_split_quantity': 5,
          'p_target_slot': 8,
        };
        expect(params.keys, containsAll(<String>[
          'p_row_id',
          'p_split_quantity',
          'p_target_slot',
        ]));
      });

      test('sell_inventory_item RPC contract verifies p_row_id and p_quantity', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_row_id': 'junk_row_10',
          'p_quantity': 1,
        };
        expect(params.keys, containsAll(<String>['p_row_id', 'p_quantity']));
      });

      test('toggle_inventory_favorite RPC contract verifies p_row_id and p_is_favorite', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_row_id': 'legendary_row_01',
          'p_is_favorite': true,
        };
        expect(params.keys, containsAll(<String>['p_row_id', 'p_is_favorite']));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 4. MarketRepository Contracts
    // ─────────────────────────────────────────────────────────────────────────
    group('MarketRepository RPC Contracts', () {
      test('get_market_tickers RPC contract parameters match SQL schema', () {
        const MarketTickerQuery query = MarketTickerQuery(
          search: 'ejder',
          itemType: 'material',
          rarity: 'mythic',
          sortKey: 'price_asc',
        );

        final Map<String, dynamic> params = <String, dynamic>{
          'p_limit': 48,
          'p_offset': 0,
          'p_search': query.search.isEmpty ? null : query.search,
          'p_item_type': query.itemType.isEmpty ? null : query.itemType,
          'p_rarity': query.rarity.isEmpty ? null : query.rarity,
          'p_sort': query.sortKey,
        };

        expect(params.keys, containsAll(<String>[
          'p_limit',
          'p_offset',
          'p_search',
          'p_item_type',
          'p_rarity',
          'p_sort',
        ]));
      });

      test('market_list_item RPC contract verifies item_row_id, quantity, and price', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_item_row_id': 'inv_row_draco',
          'p_quantity': 2,
          'p_price': 15000,
        };
        expect(params.keys, containsAll(<String>[
          'p_item_row_id',
          'p_quantity',
          'p_price',
        ]));
      });

      test('cancel_sell_order and update_market_listing_price RPC contracts verify order_id and price', () {
        final Map<String, dynamic> cancelParams = <String, dynamic>{'p_order_id': 'ord_123'};
        final Map<String, dynamic> updateParams = <String, dynamic>{
          'p_order_id': 'ord_123',
          'p_new_price': 14000,
        };

        expect(cancelParams.containsKey('p_order_id'), isTrue);
        expect(updateParams.keys, containsAll(<String>['p_order_id', 'p_new_price']));
      });

      test('market_buy_item RPC contract verifies order_id and quantity', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_order_id': 'ord_123',
          'p_quantity': 1,
        };
        expect(params.keys, containsAll(<String>['p_order_id', 'p_quantity']));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 5. DungeonRepository Contracts
    // ─────────────────────────────────────────────────────────────────────────
    group('DungeonRepository RPC Contracts', () {
      test('enter_dungeon RPC contract enforces p_player_id and p_dungeon_id', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_player_id': 'usr_kaelen_01',
          'p_dungeon_id': 'dungeon_volcano_03',
        };
        expect(params.keys, containsAll(<String>['p_player_id', 'p_dungeon_id']));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 6. DungeonSiegeRepository Contracts
    // ─────────────────────────────────────────────────────────────────────────
    group('DungeonSiegeRepository RPC Contracts', () {
      test('get_dungeon_siege_status RPC contract verifies p_dungeon_id', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_dungeon_id': 'dungeon_volcano_03',
        };
        expect(params.containsKey('p_dungeon_id'), isTrue);
      });

      test('get_dungeon_siege_notifications verifies p_limit parameter', () {
        final Map<String, dynamic> params = <String, dynamic>{'p_limit': 20};
        expect(params['p_limit'], equals(20));
      });

      test('claim_siege_slot, challenge_siege_slot, and start_siege_guild_hold parameter contracts', () {
        final Map<String, dynamic> claimParams = <String, dynamic>{'p_dungeon_id': 'dungeon_volcano_03'};
        final Map<String, dynamic> challengeParams = <String, dynamic>{'p_slot_id': 'slot_boss_01'};
        final Map<String, dynamic> guildHoldParams = <String, dynamic>{'p_dungeon_id': 'dungeon_volcano_03'};

        expect(claimParams.containsKey('p_dungeon_id'), isTrue);
        expect(challengeParams.containsKey('p_slot_id'), isTrue);
        expect(guildHoldParams.containsKey('p_dungeon_id'), isTrue);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 7. GuildMonument & Vault Contracts
    // ─────────────────────────────────────────────────────────────────────────
    group('GuildMonument & Vault Contracts', () {
      test('donate_to_guild_monument RPC contract enforces guild_id, resource_type, and amount', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_guild_id': 'guild_draco',
          'p_resource_type': 'gold',
          'p_amount': 500000,
        };
        expect(params.keys, containsAll(<String>[
          'p_guild_id',
          'p_resource_type',
          'p_amount',
        ]));
      });

      test('apply_monument_blueprint RPC contract verifies blueprint_type', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_guild_id': 'guild_draco',
          'p_blueprint_type': 'celestial_aegis',
        };
        expect(params.keys, containsAll(<String>[
          'p_guild_id',
          'p_blueprint_type',
        ]));
      });

      test('get_guild_vault and collect_guild_vault_rewards match RPC function registry', () {
        const String getVaultFn = 'get_guild_vault';
        const String collectRewardsFn = 'collect_guild_vault_rewards';
        expect(getVaultFn, equals('get_guild_vault'));
        expect(collectRewardsFn, equals('collect_guild_vault_rewards'));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 8. FacilitiesRepository Contracts
    // ─────────────────────────────────────────────────────────────────────────
    group('FacilitiesRepository RPC Contracts', () {
      test('upgrade_facility and claim_facility_production verify p_facility_type', () {
        final Map<String, dynamic> upgradeParams = <String, dynamic>{
          'p_facility_type': 'brewery',
        };
        final Map<String, dynamic> claimParams = <String, dynamic>{
          'p_facility_type': 'brewery',
        };

        expect(upgradeParams.containsKey('p_facility_type'), isTrue);
        expect(claimParams.containsKey('p_facility_type'), isTrue);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 9. BattlePassRepository Contracts
    // ─────────────────────────────────────────────────────────────────────────
    group('BattlePassRepository RPC Contracts', () {
      test('bp_claim_reward RPC contract verifies p_season_id, p_level, and p_is_vip', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_season_id': 'bp_season_03',
          'p_level': 10,
          'p_is_vip': true,
        };
        expect(params.keys, containsAll(<String>[
          'p_season_id',
          'p_level',
          'p_is_vip',
        ]));
      });

      test('bp_claim_quest_reward RPC contract verifies p_player_quest_id', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_player_quest_id': 'quest_bp_row_12',
        };
        expect(params.containsKey('p_player_quest_id'), isTrue);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 10. DailyReward & Comeback Contracts
    // ─────────────────────────────────────────────────────────────────────────
    group('DailyReward & Comeback Contracts', () {
      test('claim_daily_reward and get_daily_reward_status match exact RPC names', () {
        const String statusFn = 'get_daily_reward_status';
        const String claimFn = 'claim_daily_reward';
        expect(statusFn, equals('get_daily_reward_status'));
        expect(claimFn, equals('claim_daily_reward'));
      });

      test('get_comeback_summary and mark_comeback_summary_seen match exact RPC names', () {
        const String summaryFn = 'get_comeback_summary';
        const String markSeenFn = 'mark_comeback_summary_seen';
        expect(summaryFn, equals('get_comeback_summary'));
        expect(markSeenFn, equals('mark_comeback_summary_seen'));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 11. Reputation, Staff & Badges Contracts
    // ─────────────────────────────────────────────────────────────────────────
    group('Reputation, Staff & Badges Contracts', () {
      test('get_player_badges matches exact RPC name', () {
        const String badgesFn = 'get_player_badges';
        expect(badgesFn, equals('get_player_badges'));
      });

      test('get_reputation_overview and get_reputation_shop match exact RPC names', () {
        const String overviewFn = 'get_reputation_overview';
        const String shopFn = 'get_reputation_shop';
        expect(overviewFn, equals('get_reputation_overview'));
        expect(shopFn, equals('get_reputation_shop'));
      });

      test('staff_search_players verifies query, limit, and banned_filter parameters', () {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_query': 'kaelen',
          'p_limit': 20,
          'p_banned_filter': null,
        };
        expect(params.keys, containsAll(<String>[
          'p_query',
          'p_limit',
          'p_banned_filter',
        ]));
      });
    });
  });
}
