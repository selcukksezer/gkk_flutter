import '../core/errors/app_exception.dart';
import '../core/services/supabase_service.dart';
import '../models/dungeon_siege_model.dart';

abstract class DungeonSiegeRepository {
  Future<DungeonSiegeStatus> getStatus({String? dungeonId});
  Future<DungeonSiegeActionResult> claimSlot(String dungeonId);
  Future<DungeonSiegeActionResult> challengeSlot(String slotId);
  Future<DungeonSiegeActionResult> releaseSlot(String slotId);
}

class SupabaseDungeonSiegeRepository implements DungeonSiegeRepository {
  void _ensureReady() {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }
  }

  Map<String, dynamic> _asMap(dynamic response) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw AppException('Gecersiz sunucu cevabi.', code: 'SIEGE_INVALID_RESPONSE');
  }

  @override
  Future<DungeonSiegeStatus> getStatus({String? dungeonId}) async {
    _ensureReady();
    try {
      final dynamic response = await SupabaseService.client.rpc(
        'get_dungeon_siege_status',
        params: <String, dynamic>{'p_dungeon_id': dungeonId},
      );
      return DungeonSiegeStatus.fromJson(_asMap(response));
    } catch (e) {
      if (e is AppException) rethrow;
      return DungeonSiegeStatus.empty();
    }
  }

  @override
  Future<DungeonSiegeActionResult> claimSlot(String dungeonId) async {
    _ensureReady();
    final dynamic response = await SupabaseService.client.rpc(
      'claim_siege_slot',
      params: <String, dynamic>{'p_dungeon_id': dungeonId},
    );
    return DungeonSiegeActionResult.fromJson(_asMap(response));
  }

  @override
  Future<DungeonSiegeActionResult> challengeSlot(String slotId) async {
    _ensureReady();
    final dynamic response = await SupabaseService.client.rpc(
      'challenge_siege_slot',
      params: <String, dynamic>{'p_slot_id': slotId},
    );
    return DungeonSiegeActionResult.fromJson(_asMap(response));
  }

  @override
  Future<DungeonSiegeActionResult> releaseSlot(String slotId) async {
    _ensureReady();
    final dynamic response = await SupabaseService.client.rpc(
      'release_siege_slot',
      params: <String, dynamic>{'p_slot_id': slotId},
    );
    return DungeonSiegeActionResult.fromJson(_asMap(response));
  }
}
