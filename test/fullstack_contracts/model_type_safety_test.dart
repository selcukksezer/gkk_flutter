import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/battle_pass.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';

void main() {
  group('Fullstack Model Type Safety & Postgres int8/numeric Resilience Tests', () {
    test('BpSeason safely parses double/num season_number from Postgres', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 'season_01',
        'season_number': 1.0,
        'start_at': '2026-01-01T00:00:00Z',
        'end_at': '2026-12-31T23:59:59Z',
        'is_active': true,
        'description': 'Test Season',
      };
      final BpSeason season = BpSeason.fromJson(json);
      expect(season.seasonNumber, 1);
      expect(season.isActive, true);
    });

    test('BpPlayerStatus safely parses numeric pools, levels, and claimed lists', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'player_id': 'user_01',
        'season_id': 'season_01',
        'current_level': 15.0,
        'current_bpp': 450.0,
        'daily_grind_bpp_pool': 100.0,
        'daily_pvp_bpp_pool': 50.0,
        'has_vip': true,
        'claimed_normal': <dynamic>[1.0, 2.0, 3],
        'claimed_vip': <dynamic>[1.0, 2],
        'updated_at': '2026-10-29T18:00:00Z',
      };
      final BpPlayerStatus status = BpPlayerStatus.fromJson(json);
      expect(status.currentLevel, 15);
      expect(status.currentBpp, 450);
      expect(status.dailyGrindBppPool, 100);
      expect(status.dailyPvpBppPool, 50);
      expect(status.claimedNormal, <int>[1, 2, 3]);
      expect(status.claimedVip, <int>[1, 2]);
    });

    test('BpQuestTemplate and BpPlayerQuest safely parse int8 numbers', () {
      final Map<String, dynamic> tplJson = <String, dynamic>{
        'id': 'q_tpl_01',
        'description': 'Defeat 10 monsters',
        'quest_type': 'kill',
        'target_system': 'dungeon',
        'target_count': 10.0,
        'bpp_reward': 100.0,
      };
      final BpQuestTemplate tpl = BpQuestTemplate.fromJson(tplJson);
      expect(tpl.targetCount, 10);
      expect(tpl.bppReward, 100);

      final Map<String, dynamic> pqJson = <String, dynamic>{
        'id': 'pq_01',
        'player_id': 'user_01',
        'season_id': 'season_01',
        'template_id': 'q_tpl_01',
        'current_progress': 5.0,
        'is_completed': false,
        'reward_claimed': false,
        'updated_at': '2026-10-29T18:00:00Z',
        'template': tplJson,
      };
      final BpPlayerQuest pq = BpPlayerQuest.fromJson(pqJson);
      expect(pq.currentProgress, 5);
      expect(pq.template?.bppReward, 100);
    });

    test('BpLevelReward safely parses reward quantities and gold amounts', () {
      final Map<String, dynamic> lrJson = <String, dynamic>{
        'level': 20.0,
        'normal_reward_item_id': 'item_potion_hp',
        'normal_reward_quantity': 5.0,
        'normal_reward_gold': 50000.0,
        'vip_reward_item_id': 'item_epic_chest',
        'vip_reward_quantity': 1.0,
        'vip_reward_gold': 200000.0,
        'description': 'Milestone 20',
      };
      final BpLevelReward reward = BpLevelReward.fromJson(lrJson);
      expect(reward.level, 20);
      expect(reward.normalRewardQuantity, 5);
      expect(reward.normalRewardGold, 50000);
      expect(reward.vipRewardQuantity, 1);
      expect(reward.vipRewardGold, 200000);
    });

    test('BpSeasonRewardsBundle parses nested tracks and levels with num types', () {
      final Map<String, dynamic> bundleJson = <String, dynamic>{
        'season_id': 'season_01',
        'season_number': 2.0,
        'levels': <dynamic>[
          <String, dynamic>{
            'level': 1.0,
            'free_reward': <String, dynamic>{
              'reward_value': <String, dynamic>{'gold': 1000.0, 'quantity': 1.0},
              'display_name': 'Altın',
            },
          },
        ],
        'featured_free': <dynamic>[],
        'featured_vip': <dynamic>[],
      };
      final BpSeasonRewardsBundle bundle = BpSeasonRewardsBundle.fromRpc(bundleJson);
      expect(bundle.seasonNumber, 2);
      expect(bundle.levels.length, 1);
      expect(bundle.levels.first.level, 1);
      expect(bundle.levels.first.free?.gold, 1000);
    });

    test('InventoryItem safely parses numeric values from get_inventory RPC', () {
      final Map<String, dynamic> invJson = <String, dynamic>{
        'row_id': 'e5b7a110-3882-411a-8c10-21a115802319',
        'item_id': 'wpn_sword_iron',
        'quantity': 1.0,
        'slot_position': 0.0,
        'is_equipped': false,
        'equipped_slot': '',
        'enhancement_level': 3.0,
        'is_favorite': true,
        'pending_sync': false,
        'name': 'Demir Kılıç',
        'description': 'Sağlam bir kılıç.',
        'icon': 'assets/items/generated/wpn_sword_iron.png',
        'item_type': 'weapon',
        'rarity': 'common',
        'base_price': 100.0,
        'vendor_sell_price': 35.0,
        'attack': 25.0,
        'defense': 0.0,
        'health': 0.0,
        'power': 5.0,
        'luck': 0.0,
        'mana': 0.0,
        'equip_slot': 'weapon',
        'weapon_type': 'sword',
        'armor_type': 'none',
        'required_level': 1.0,
        'can_enhance': true,
        'max_enhancement': 9.0,
        'is_stackable': false,
        'max_stack': 1.0,
        'is_tradeable': true,
        'potion_type': 'none',
        'energy_restore': 0.0,
        'health_restore': 0.0,
        'tolerance_increase': 0.0,
      };
      final InventoryItem item = InventoryItem.fromJson(invJson);
      expect(item.quantity, 1);
      expect(item.slotPosition, 0);
      expect(item.enhancementLevel, 3);
      expect(item.attack, 25);
      expect(item.isFavorite, true);
    });
  });
}
