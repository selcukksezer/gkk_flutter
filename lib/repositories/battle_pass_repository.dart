import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/supabase_service.dart';
import '../models/battle_pass.dart';

class BattlePassRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<void> ensureInitialized() async {
    await _client.rpc('bp_ensure_player_initialized');
  }

  Future<BpSeason?> getActiveSeason() async {
    final response = await _client
        .from('bp_seasons')
        .select()
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) return null;
    return BpSeason.fromJson(response);
  }

  Future<BpPlayerStatus?> getPlayerStatus(String playerId, String seasonId) async {
    final response = await _client
        .from('bp_player_status')
        .select()
        .eq('player_id', playerId)
        .eq('season_id', seasonId)
        .maybeSingle();

    if (response == null) return null;
    return BpPlayerStatus.fromJson(response);
  }

  Future<List<BpPlayerQuest>> getPlayerQuests(String playerId, String seasonId) async {
    final response = await _client
        .from('bp_player_quests')
        .select('*, template:bp_quest_templates(*)')
        .eq('player_id', playerId)
        .eq('season_id', seasonId);

    return (response as List).map((json) => BpPlayerQuest.fromJson(json)).toList();
  }

  Future<List<BpLevelReward>> getLevelRewards() async {
    final response = await _client
        .from('bp_level_rewards')
        .select('*, normal_reward_item:items!normal_reward_item_id(*), vip_reward_item:items!vip_reward_item_id(*)')
        .order('level', ascending: true);

    return (response as List).map((json) => BpLevelReward.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> claimReward(int level, bool isVip) async {
    final response = await _client.rpc('bp_claim_reward', params: {
      'p_level': level,
      'p_is_vip': isVip,
    });
    return response as Map<String, dynamic>;
  }

  /// VIP Pass satın al — gem bakiyesinden düşer, has_vip = true yapar
  Future<Map<String, dynamic>> buyVipPass() async {
    final response = await _client.rpc('buy_vip_pass');
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> claimQuestReward(String questId) async {
    final response = await _client.rpc('bp_claim_quest_reward', params: {
      'p_quest_id': questId,
    });
    return response as Map<String, dynamic>;
  }
}

