import '../core/errors/app_exception.dart';
import '../core/services/supabase_service.dart';
import '../models/dungeon_siege_model.dart';

abstract class DungeonSiegeRepository {
  Future<DungeonSiegeStatus> getStatus({String? dungeonId});
  Future<DungeonSiegeHub> getHub();
  Future<({List<DungeonSiegeNotification> notifications, int unreadCount})> getNotifications({
    int limit = 20,
  });
  Future<bool> markNotificationsRead({List<String>? notificationIds});
  Future<DungeonSiegeActionResult> claimSlot(String dungeonId);
  Future<DungeonSiegeActionResult> challengeSlot(String slotId);
  Future<DungeonSiegeActionResult> releaseSlot(String slotId);
  Future<DungeonSiegeActionResult> startGuildHold(String dungeonId);
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
    final Map<String, dynamic> params = <String, dynamic>{};
    if (dungeonId != null && dungeonId.isNotEmpty) {
      params['p_dungeon_id'] = dungeonId;
    }
    final dynamic response = await SupabaseService.client.rpc(
      'get_dungeon_siege_status',
      params: params,
    );
    return DungeonSiegeStatus.fromJson(_asMap(response));
  }

  @override
  Future<DungeonSiegeHub> getHub() async {
    _ensureReady();
    final dynamic response = await SupabaseService.client.rpc('get_dungeon_siege_hub');
    return DungeonSiegeHub.fromJson(_asMap(response));
  }

  @override
  Future<({List<DungeonSiegeNotification> notifications, int unreadCount})> getNotifications({
    int limit = 20,
  }) async {
    _ensureReady();
    final dynamic response = await SupabaseService.client.rpc(
      'get_dungeon_siege_notifications',
      params: <String, dynamic>{'p_limit': limit},
    );
    final Map<String, dynamic> map = _asMap(response);
    final List<DungeonSiegeNotification> notifications =
        (map['notifications'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map>()
            .map(
              (Map<dynamic, dynamic> row) =>
                  DungeonSiegeNotification.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList();
    return (
      notifications: notifications,
      unreadCount: _parseInt(map['unread_count']),
    );
  }

  @override
  Future<bool> markNotificationsRead({List<String>? notificationIds}) async {
    _ensureReady();
    final dynamic response = await SupabaseService.client.rpc(
      'mark_siege_notifications_read',
      params: <String, dynamic>{
        'p_notification_ids': notificationIds?.isEmpty ?? true ? null : notificationIds,
      },
    );
    return _asMap(response)['success'] == true;
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

  @override
  Future<DungeonSiegeActionResult> startGuildHold(String dungeonId) async {
    _ensureReady();
    final dynamic response = await SupabaseService.client.rpc(
      'start_siege_guild_hold',
      params: <String, dynamic>{'p_dungeon_id': dungeonId},
    );
    return DungeonSiegeActionResult.fromJson(_asMap(response));
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
