import '../core/services/supabase_service.dart';

class GuildVaultRepository {
  Future<Map<String, dynamic>> getVault() async {
    final dynamic raw = await SupabaseService.client.rpc('get_guild_vault');
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{'success': false, 'error': 'Geçersiz kasa cevabı'};
  }

  Future<Map<String, dynamic>> collectRewards() async {
    final dynamic raw = await SupabaseService.client.rpc('collect_guild_vault_rewards');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'success': true};
  }

  Future<Map<String, dynamic>> distributeGold(Map<String, dynamic> payload) async {
    final dynamic raw = await SupabaseService.client.rpc(
      'distribute_guild_vault_gold',
      params: <String, dynamic>{'p_payload': payload},
    );
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'success': true};
  }

  Future<Map<String, dynamic>> distributeItem({
    required String vaultItemId,
    required String userId,
    required int quantity,
  }) async {
    final dynamic raw = await SupabaseService.client.rpc(
      'distribute_guild_vault_item',
      params: <String, dynamic>{
        'p_vault_item_id': vaultItemId,
        'p_user_id': userId,
        'p_quantity': quantity,
      },
    );
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'success': true};
  }
}
