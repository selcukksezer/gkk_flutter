import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/models/auth_model.dart';
import 'package:gkk_flutter/models/battle_pass.dart';
import 'package:gkk_flutter/models/codex_model.dart';
import 'package:gkk_flutter/models/comeback_summary_model.dart';
import 'package:gkk_flutter/models/crafting_model.dart';
import 'package:gkk_flutter/models/daily_reward_model.dart';
import 'package:gkk_flutter/models/dungeon_model.dart';
import 'package:gkk_flutter/models/dungeon_siege_economy.dart';
import 'package:gkk_flutter/models/dungeon_siege_model.dart';
import 'package:gkk_flutter/models/dungeon_siege_prime_timer.dart';
import 'package:gkk_flutter/models/enhancement_config_model.dart';
import 'package:gkk_flutter/models/facility_model.dart';
import 'package:gkk_flutter/models/facility_production_preview_model.dart';
import 'package:gkk_flutter/models/guild_model.dart';
import 'package:gkk_flutter/models/guild_vault_model.dart';
import 'package:gkk_flutter/models/guild_war_model.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/models/kingdom_market_blessing_model.dart';
import 'package:gkk_flutter/models/leaderboard_model.dart';
import 'package:gkk_flutter/models/live_ticker_model.dart';
import 'package:gkk_flutter/models/market_model.dart';
import 'package:gkk_flutter/models/mekan_model.dart';
import 'package:gkk_flutter/models/nemesis_model.dart';
import 'package:gkk_flutter/models/night_market_model.dart';
import 'package:gkk_flutter/models/notification_item.dart';
import 'package:gkk_flutter/models/player_badge_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/models/policy_model.dart';
import 'package:gkk_flutter/models/pvp_model.dart';
import 'package:gkk_flutter/models/quest_model.dart';
import 'package:gkk_flutter/models/referral_preview_model.dart';
import 'package:gkk_flutter/models/reputation_model.dart';
import 'package:gkk_flutter/models/retention_promos_model.dart';
import 'package:gkk_flutter/models/staff_model.dart';
import 'package:gkk_flutter/models/support_detail_model.dart';
import 'package:gkk_flutter/models/support_model.dart';

void main() {
  group('Fullstack Model Contract Tests (Serialization & Deserialization Parity)', () {
    // ─────────────────────────────────────────────────────────────────────────
    // 1. Auth Models
    // ─────────────────────────────────────────────────────────────────────────
    group('Auth Models Contract', () {
      test('AuthSession fromJson and toJson round-trip', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'access_token': 'jwt_access_token_xyz',
          'refresh_token': 'jwt_refresh_token_abc',
          'expires_at': 1893456000,
        };

        final AuthSession session = AuthSession.fromJson(json);
        expect(session.accessToken, equals('jwt_access_token_xyz'));
        expect(session.refreshToken, equals('jwt_refresh_token_abc'));
        expect(session.expiresAt, equals(1893456000));

        final Map<String, dynamic> output = session.toJson();
        expect(output, equals(json));
      });

      test('LoginRequest and RegisterRequest toJson matches Supabase RPC payload', () {
        const LoginRequest login = LoginRequest(
          email: 'kaelen@aion2.mobile',
          password: 'SecretPassword123!',
          deviceId: 'device_iphone_14',
        );

        final Map<String, dynamic> loginJson = login.toJson();
        expect(loginJson['email'], equals('kaelen@aion2.mobile'));
        expect(loginJson['password'], equals('SecretPassword123!'));
        expect(loginJson['device_id'], equals('device_iphone_14'));

        const RegisterRequest reg = RegisterRequest(
          email: 'kaelen@aion2.mobile',
          username: 'Kaelen',
          password: 'SecretPassword123!',
          deviceId: 'device_iphone_14',
          referralCode: 'REF123',
        );

        final Map<String, dynamic> regJson = reg.toJson();
        expect(regJson['email'], equals('kaelen@aion2.mobile'));
        expect(regJson['username'], equals('Kaelen'));
        expect(regJson['referral_code'], equals('REF123'));
      });

      test('AuthUser fromJson parses integer numbers and roles safely', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'id': 'usr_101',
          'username': 'ShadowBlade',
          'email': 'shadow@aion.com',
          'level': 65,
          'gold': 500000,
          'gems': 120.0,
          'energy': 90,
          'max_energy': 100,
          'attack': 450,
          'defense': 320,
          'health': 5500,
          'max_health': 5500,
          'power': 89000,
          'guild_id': 'guild_draco',
          'guild_role': 'commander',
        };

        final AuthUser user = AuthUser.fromJson(json);
        expect(user.id, equals('usr_101'));
        expect(user.username, equals('ShadowBlade'));
        expect(user.level, equals(65));
        expect(user.guildRole, equals('commander'));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Player Profile Contract
    // ─────────────────────────────────────────────────────────────────────────
    group('Player Profile Contract', () {
      test('PlayerProfile handles bigint string coercion, enums, and dates', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'id': 'usr_kaelen',
          'auth_id': 'auth_kaelen_01',
          'username': 'Kaelen',
          'email': 'kaelen@aion2.mobile',
          'display_name': 'Kadim Kaelen',
          'avatar_url': 'https://aion2.mobile/avatars/kaelen.png',
          'avatar_frame': 'dragon_gold_frame',
          'level': 75,
          'xp': 950000,
          'gold': 2450000,
          'gems': 450.5,
          'energy': 100,
          'max_energy': 100,
          'attack': 1250,
          'defense': 1100,
          'health': 24000,
          'max_health': 24000,
          'power': 152000,
          'is_online': true,
          'is_banned': false,
          'tutorial_completed': true,
          'guild_id': 'guild_draco',
          'guild_role': 'leader',
          'referral_code': 'DRACO75',
          'referred_by': null,
          'pvp_rating': 2450,
          'pvp_wins': 312,
          'pvp_losses': 48,
          'addiction_level': 0,
          'tolerance': 0,
          'nightlife_tickets': 3,
          'nightlife_vibe': 15,
          'last_potion_used_at': null,
          'warrior_bloodlust_until': null,
          'hospital_until': null,
          'hospital_reason': null,
          'hospital_lifetime_count': 1,
          'prison_until': null,
          'prison_reason': null,
          'global_suspicion_level': 0,
          'last_bribe_at': null,
          'last_login_at': '2026-10-29T12:00:00Z',
          'last_login': '2026-10-29T12:00:00Z',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-10-29T12:00:00Z',
          'reputation': 8500,
          'guild_name': 'Ejder [LNC]',
          'title': 'Kadim Şövalye',
          'cosmetic_title': 'Ejder Efendisi',
          'endurance': 180,
          'agility': 140,
          'intelligence': 100,
          'luck': 55,
          'equip_bonus_luck': 12,
          'character_class': 'warrior',
          'stat_points': 0,
          'crafting_queue_slots': 3,
        };

        final PlayerProfile profile = PlayerProfile.fromJson(json);
        expect(profile.id, equals('usr_kaelen'));
        expect(profile.characterClass, equals(CharacterClass.warrior));
        expect(profile.level, equals(75));
        expect(profile.gold, equals(2450000));
        expect(profile.gems, equals(450.5));
        expect(profile.guildName, equals('Ejder [LNC]'));
        expect(profile.nightlifeTickets, equals(3));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Inventory & Item Contract
    // ─────────────────────────────────────────────────────────────────────────
    group('Inventory & Item Contract', () {
      test('InventoryItem fromJson and toJson round-trip maintains exact attributes', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'row_id': 'inv_item_draco_blade',
          'item_id': 'wpn_draco_sword',
          'quantity': 1,
          'slot_position': 0,
          'is_equipped': true,
          'equipped_slot': 'weapon',
          'enhancement_level': 10,
          'is_favorite': true,
          'pending_sync': false,
          'name': 'Kadim Ejder Kılıcı',
          'description': 'Aion 2 Mythic Dragon Greatsword',
          'icon': 'assets/images/icons/dragon_sword.png',
          'item_type': 'weapon',
          'rarity': 'mythic',
          'facility_type': null,
          'base_price': 100000,
          'vendor_sell_price': 50000,
          'attack': 620,
          'defense': 120,
          'health': 800,
          'power': 750,
          'luck': 15,
          'mana': 50,
          'equip_slot': 'weapon',
          'weapon_type': 'sword',
          'armor_type': 'none',
          'sub_type': 'sword',
          'required_level': 70,
          'can_enhance': true,
          'max_enhancement': 15,
          'is_stackable': false,
          'max_stack': 1,
          'is_tradeable': true,
          'is_han_only': false,
          'is_market_tradeable': true,
          'is_direct_tradeable': true,
          'potion_type': 'none',
          'energy_restore': 0,
          'health_restore': 0,
          'tolerance_increase': 0,
        };

        final InventoryItem item = InventoryItem.fromJson(json);
        expect(item.rowId, equals('inv_item_draco_blade'));
        expect(item.itemType, equals(ItemType.weapon));
        expect(item.rarity, equals(Rarity.mythic));
        expect(item.equipSlot, equals(EquipSlot.weapon));
        expect(item.weaponType, equals(WeaponType.sword));
        expect(item.attack, equals(620));

        final Map<String, dynamic> output = item.toJson();
        expect(output['row_id'], equals(json['row_id']));
        expect(output['item_id'], equals(json['item_id']));
        expect(output['enhancement_level'], equals(10));
        expect(output['rarity'], equals('mythic'));
      });

      test('ItemTypeParsing, RarityParsing and EquipSlotParsing handle edge strings', () {
        expect(ItemTypeParsing.fromValue('WEAPON'), equals(ItemType.weapon));
        expect(ItemTypeParsing.fromValue('armor'), equals(ItemType.armor));
        expect(ItemTypeParsing.fromValue('unknown_type'), equals(ItemType.consumable));

        expect(RarityParsing.fromValue('MYTHIC'), equals(Rarity.mythic));
        expect(RarityParsing.fromValue('legendary'), equals(Rarity.legendary));
        expect(RarityParsing.fromValue('invalid'), equals(Rarity.common));

        expect(EquipSlotParsing.fromValue('CHEST'), equals(EquipSlot.chest));
        expect(EquipSlotParsing.fromValue('boots'), equals(EquipSlot.boots));
        expect(EquipSlotParsing.fromValue('none'), equals(EquipSlot.none));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Dungeon & Dungeon Siege Models
    // ─────────────────────────────────────────────────────────────────────────
    group('Dungeon & Siege Contract', () {
      test('DungeonData parses zone, difficulty, and loot table', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'id': 'dungeon_draco_01',
          'dungeon_id': 'dungeon_draco_01',
          'name': 'Kızıl Ejder İni',
          'description': 'Aion 2 Dark Fantasy High Level Raid',
          'difficulty': 'hard',
          'required_level': 70,
          'max_players': 1,
          'energy_cost': 20,
          'min_gold': 5000,
          'max_gold': 25000,
          'loot_table': <String>['wpn_draco_sword', 'mat_scale_01'],
          'is_group': false,
          'power_requirement': 140000,
          'zone': 4,
          'is_boss': true,
        };

        final DungeonData dungeon = DungeonData.fromJson(json);
        expect(dungeon.dungeonId, equals('dungeon_draco_01'));
        expect(dungeon.requiredLevel, equals(70));
        expect(dungeon.isBoss, isTrue);
        expect(dungeon.lootTable, contains('wpn_draco_sword'));
      });

      test('DungeonSiegeStatus fromJson parses territory control state', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'enabled': true,
          'in_prime_window': true,
          'siege_active': true,
          'is_banned': false,
          'config': <String, dynamic>{
            'is_enabled': true,
            'slot_count': 5,
            'slot_duration_minutes': 20,
            'challenge_gold_cost': 250000,
          },
          'sessions': <Map<String, dynamic>>[],
        };

        final DungeonSiegeStatus status = DungeonSiegeStatus.fromJson(json);
        expect(status.enabled, isTrue);
        expect(status.inPrimeWindow, isTrue);
        expect(status.siegeActive, isTrue);
        expect(status.config.slotCount, equals(5));
      });

      test('DungeonSiegeEconomy calculates dynamic rates without negative values', () {
        final int cost = DungeonSiegeEconomy.challengeGoldForRange(
          goldMin: 100000,
          goldMax: 500000,
        );
        expect(cost, greaterThan(0));
        expect(cost, greaterThanOrEqualTo(50000));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Guild & Guild War Models
    // ─────────────────────────────────────────────────────────────────────────
    group('Guild & Guild War Contract', () {
      test('GuildData and GuildMemberData serialization matches DB schema', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'guild_id': 'guild_celestial',
          'name': 'Gök Tanrısı [GOK]',
          'description': 'Aion 2 Celestial Vanguard',
          'level': 8,
          'leader_id': 'usr_leader_01',
          'member_count': 24,
          'max_members': 50,
          'total_power': 3200000,
          'monument_level': 4,
          'monument_structural': 85,
          'monument_mystical': 90,
          'monument_critical': 75,
          'monument_gold_pool': 4500000,
          'vault_gold': 4500000,
          'members': <Map<String, dynamic>>[
            <String, dynamic>{
              'player_id': 'usr_leader_01',
              'username': 'Valerius',
              'level': 75,
              'role': 'leader',
              'power': 150000,
              'is_online': true,
            },
          ],
        };

        final GuildData guild = GuildData.fromJson(json);
        expect(guild.guildId, equals('guild_celestial'));
        expect(guild.name, equals('Gök Tanrısı [GOK]'));
        expect(guild.members?.length, equals(1));
        expect(guild.members?.first.role, equals(GuildRole.leader));
      });

      test('GuildWarSeason and GuildWarTournament parse correctly', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'season': 4,
          'week': 2,
          'end_at': '2026-11-05T00:00:00Z',
        };

        final GuildWarSeason season = GuildWarSeason.fromJson(json);
        expect(season.season, equals(4));
        expect(season.week, equals(2));
        expect(season.endAt, isNotNull);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Market Models
    // ─────────────────────────────────────────────────────────────────────────
    group('Market Contract', () {
      test('MarketTicker fromRpcJson parses ticker metrics safely', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'item_id': 'mat_dragon_scale',
          'item_name': 'Ejder Pulu',
          'item_type': 'material',
          'rarity': 'legendary',
          'is_stackable': true,
          'lowest_price': 3200,
          'volume': 480,
          'price_change': 350,
          'max_available_qty': 85,
        };

        final MarketTicker ticker = MarketTicker.fromRpcJson(json);
        expect(ticker.itemId, equals('mat_dragon_scale'));
        expect(ticker.lowestPrice, equals(3200));
        expect(ticker.volume, equals(480));
        expect(ticker.isStackable, isTrue);
      });

      test('MarketOrder fromJson parses order status and sides', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'id': 'ord_sell_001',
          'seller_id': 'usr_kaelen',
          'item_id': 'mat_dragon_scale',
          'item_name': 'Ejder Pulu',
          'quantity': 10,
          'price': 3200,
          'status': 'open',
          'side': 'sell',
          'created_at': '2026-10-29T10:00:00Z',
        };

        final MarketOrder order = MarketOrder.fromJson(json);
        expect(order.orderId, equals('ord_sell_001'));
        expect(order.quantity, equals(10));
        expect(order.price, equals(3200));
        expect(order.status, equals('open'));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 7. PvP Models
    // ─────────────────────────────────────────────────────────────────────────
    group('PvP Contract', () {
      test('PvPTarget fromJson and toJson round-trip', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'id': 'pvp_tgt_01',
          'player_id': 'usr_target_01',
          'username': 'GölgeSavaşçı',
          'level': 72,
          'power': 135000,
          'pvp_rating': 2380,
          'rating': 2380,
          'attack': 1150,
          'defense': 980,
          'health': 21000,
          'estimated_gold': 85000,
          'guild_name': 'Gölge Loncası',
        };

        final PvPTarget target = PvPTarget.fromJson(json);
        expect(target.id, equals('pvp_tgt_01'));
        expect(target.username, equals('GölgeSavaşçı'));
        expect(target.pvpRating, equals(2380));

        final Map<String, dynamic> output = target.toJson();
        expect(output['username'], equals('GölgeSavaşçı'));
        expect(output['level'], equals(72));
      });

      test('PvPResult parses combat outcomes accurately', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'success': true,
          'won': true,
          'opponent_name': 'GölgeSavaşçı',
          'attacker_damage': 18500,
          'defender_damage': 9200,
          'gold_stolen': 15000,
          'gold_change': 15000,
          'rating_change': 28,
          'is_critical': true,
          'defender_hospitalized': true,
        };

        final PvPResult result = PvPResult.fromJson(json);
        expect(result.success, isTrue);
        expect(result.won, isTrue);
        expect(result.goldStolen, equals(15000));
        expect(result.isCritical, isTrue);
        expect(result.defenderHospitalized, isTrue);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 8. Crafting Models
    // ─────────────────────────────────────────────────────────────────────────
    group('Crafting Contract', () {
      test('CraftRecipe and CraftIngredient serialization and parsing', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'id': 'rec_greatsword',
          'recipe_id': 'rec_greatsword',
          'name': 'Kadim Draco Kılıcı',
          'description': 'Efsanevi demirci dövme tarifi',
          'recipe_type': 'weapon',
          'item_type': 'weapon',
          'output_item_id': 'wpn_draco_sword',
          'output_quantity': 1,
          'output_rarity': 'mythic',
          'required_level': 70,
          'required_facility_level': 3,
          'production_time_seconds': 180,
          'success_rate': 0.90,
          'gem_cost': 0,
          'gold_cost': 25000,
          'ingredients': <Map<String, dynamic>>[
            <String, dynamic>{
              'item_id': 'mat_dragon_scale',
              'item_name': 'Ejder Pulu',
              'quantity': 5,
            },
            <String, dynamic>{
              'item_id': 'mat_draco_ore',
              'item_name': 'Draco Cevheri',
              'quantity': 10,
            },
          ],
        };

        final CraftRecipe recipe = CraftRecipe.fromJson(json);
        expect(recipe.id, equals('rec_greatsword'));
        expect(recipe.outputQuantity, equals(1));
        expect(recipe.ingredients.length, equals(2));
        expect(recipe.ingredients.first.itemId, equals('mat_dragon_scale'));
        expect(recipe.ingredients.first.quantity, equals(5));

        final Map<String, dynamic> ingredientJson = recipe.ingredients.first.toJson();
        expect(ingredientJson['item_id'], equals('mat_dragon_scale'));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 9. Facilities Models
    // ─────────────────────────────────────────────────────────────────────────
    group('Facility Contract', () {
      test('PlayerFacility and FacilityQueueItem parse queue states', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'id': 'fac_brewery_01',
          'facility_type': 'brewery',
          'level': 5,
          'suspicion': 10,
          'is_active': true,
          'production_started_at': '2026-10-29T10:00:00Z',
          'facility_queue': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'q_batch_01',
              'quantity': 20,
              'rarity': 'epic',
              'started_at': '2026-10-29T10:00:00Z',
              'completes_at': '2026-10-29T12:00:00Z',
              'is_completed': false,
            },
          ],
        };

        final PlayerFacility facility = PlayerFacility.fromJson(json);
        expect(facility.id, equals('fac_brewery_01'));
        expect(facility.facilityType, equals('brewery'));
        expect(facility.facilityQueue.length, equals(1));
        expect(facility.facilityQueue.first.quantity, equals(20));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 10. Battle Pass Models
    // ─────────────────────────────────────────────────────────────────────────
    group('Battle Pass Contract', () {
      test('BpSeason and BpPlayerStatus parse levels and claimed arrays', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'player_id': 'usr_kaelen',
          'season_id': 'bp_season_03',
          'current_level': 25,
          'current_bpp': 480,
          'daily_grind_bpp_pool': 100,
          'daily_pvp_bpp_pool': 100,
          'has_vip': true,
          'claimed_normal': <dynamic>[1, 2, 3, 4, 5],
          'claimed_vip': <dynamic>[1, 2, 3],
          'updated_at': '2026-10-29T10:00:00Z',
        };

        final BpPlayerStatus status = BpPlayerStatus.fromJson(json);
        expect(status.playerId, equals('usr_kaelen'));
        expect(status.currentLevel, equals(25));
        expect(status.hasVip, isTrue);
        expect(status.claimedNormal, contains(5));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 11. Codex, Badges & Reputation Models
    // ─────────────────────────────────────────────────────────────────────────
    group('Codex, Badges, & Reputation Contract', () {
      test('CodexMilestone parses thresholds and reward labels', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'threshold': 50,
          'claimed': false,
          'claimable': true,
          'reward_gold': 400000,
          'reward_gems': 3,
          'reward_label': '400K Altın + 3 Elmas',
          'reward_kind': 'gold_gems',
        };

        final CodexMilestone milestone = CodexMilestone.fromJson(json);
        expect(milestone.threshold, equals(50));
        expect(milestone.claimable, isTrue);
        expect(milestone.rewardGold, equals(400000));
      });

      test('PlayerBadge parses item icon and earnedAt date safely', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'item_id': 'bdg_first_dragon_slayer',
          'name': 'İlk Ejder Katili',
          'rarity': 'legendary',
          'icon': '🐉',
          'source': 'dungeon_draco_01',
          'earned_at': '2026-10-29T11:00:00Z',
        };

        final PlayerBadge badge = PlayerBadge.fromJson(json);
        expect(badge.itemId, equals('bdg_first_dragon_slayer'));
        expect(badge.name, equals('İlk Ejder Katili'));
        expect(badge.rarity, equals(Rarity.legendary));
      });

      test('ReputationShopItem parses item costs and effect values', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'id': 'rep_potion_draco',
          'name': 'Kadim Güç İksiri',
          'description': 'Saldırı gücünü %15 artırır',
          'icon_key': 'potion_red',
          'cost_type': 'global',
          'cost_amount': 2500,
          'rarity': 'epic',
          'effect_key': 'attack_buff',
          'effect_value': <String, dynamic>{'multiplier': 1.15},
        };

        final ReputationShopItem item = ReputationShopItem.fromJson(json);
        expect(item.id, equals('rep_potion_draco'));
        expect(item.costAmount, equals(2500));
        expect(item.effectKey, equals('attack_buff'));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 12. Mekan, Quest & Policy Models
    // ─────────────────────────────────────────────────────────────────────────
    group('Mekan, Quest & Policy Contract', () {
      test('Mekan fromJson and toJson round-trip', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'id': 'mekan_01',
          'owner_id': 'usr_kaelen',
          'mekan_type': 'dovus_kulubu',
          'name': 'Kadim Gladyatör Arenası',
          'level': 4,
          'fame': 1200,
          'suspicion': 5,
          'is_open': true,
          'closed_until': null,
          'monthly_rent_paid_at': '2026-10-01T00:00:00Z',
          'created_at': '2026-01-01T00:00:00Z',
          'happy_hour_until': null,
          'total_revenue': 850000,
          'total_sales': 340,
          'pvp_match_count': 95,
        };

        final Mekan mekan = Mekan.fromJson(json);
        expect(mekan.id, equals('mekan_01'));
        expect(mekan.mekanType, equals(MekanType.dovusKulubu));
        expect(mekan.level, equals(4));

        final Map<String, dynamic> output = mekan.toJson();
        expect(output['name'], equals('Kadim Gladyatör Arenası'));
        expect(output['mekan_type'], equals('dovus_kulubu'));
      });

      test('QuestData parses difficulty, energy, and rewards', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'id': 'qst_dragon_slayer_01',
          'quest_id': 'qst_dragon_slayer_01',
          'name': 'Ejder Avı',
          'description': '3 Ejder zindanını tamamla',
          'difficulty': 'hard',
          'required_level': 65,
          'energy_cost': 15,
          'gold_reward': 50000,
          'xp_reward': 25000,
          'gem_reward': 5,
          'item_rewards': <String>['mat_dragon_scale'],
          'status': 'active',
          'progress': 1,
          'progress_max': 3,
          'target': 3,
        };

        final QuestData quest = QuestData.fromJson(json);
        expect(quest.name, equals('Ejder Avı'));
        expect(quest.difficulty, equals(QuestDifficulty.hard));
        expect(quest.status, equals(QuestStatus.active));
        expect(quest.goldReward, equals(50000));
      });

      test('LegalDocument and PolicyStatus parse legal gates', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'type': 'terms',
          'version': 2,
          'title': 'Kullanım Koşulları',
          'body_md': '# Aion 2 Kuralları',
          'published_at': '2026-10-01T00:00:00Z',
        };

        final LegalDocument doc = LegalDocument.fromJson(json);
        expect(doc.type, equals('terms'));
        expect(doc.version, equals(2));

        final PolicyStatus status = PolicyStatus.fromJson(const <String, dynamic>{
          'all_accepted': false,
          'missing': <String>['terms', 'privacy'],
        });
        expect(status.allAccepted, isFalse);
        expect(status.missing, contains('terms'));
      });
    });
  });
}
