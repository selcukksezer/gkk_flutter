import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/debug/staff_hub_debug_log.dart';
import '../core/services/supabase_service.dart';
import '../models/staff_model.dart';
import '../models/support_model.dart';

class StaffRepository {
  StaffRepository({SupabaseClient? client}) : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> _rpc(String fn, [Map<String, dynamic>? params]) async {
    try {
      final dynamic raw = await _client.rpc(fn, params: params ?? <String, dynamic>{});
      if (raw is Map) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
        // #region agent log
        if (map['success'] == false) {
          StaffHubDebugLog.log(
            'H2',
            'staff_repository.dart:_rpc',
            'rpc_fail',
            data: <String, Object?>{'fn': fn, 'error': map['error']?.toString()},
          );
        }
        // #endregion
        return map;
      }
      return null;
    } catch (e) {
      // #region agent log
      StaffHubDebugLog.log(
        'H2',
        'staff_repository.dart:_rpc',
        'rpc_exception',
        data: <String, Object?>{'fn': fn, 'error': e.toString()},
      );
      // #endregion
      return <String, dynamic>{'success': false, 'error': e.toString()};
    }
  }

  String? _rpcError(Map<String, dynamic>? raw) {
    if (raw == null) return 'Sunucuya ulaşılamadı';
    if (raw['success'] == false) return raw['error']?.toString() ?? 'İşlem başarısız';
    return null;
  }

  Future<({List<StaffPlayerBrief> items, String? error})> searchPlayersResult(
    String query, {
    int limit = 20,
    String? bannedFilter,
  }) async {
    final Map<String, dynamic>? raw = await _rpc('staff_search_players', <String, dynamic>{
      'p_query': query,
      'p_limit': limit,
      'p_banned_filter': bannedFilter,
    });
    final String? error = _rpcError(raw);
    if (error != null) return (items: <StaffPlayerBrief>[], error: error);
    final List items = raw?['items'] is List ? raw!['items'] as List : <dynamic>[];
    return (
      items: items
          .whereType<Map>()
          .map((Map m) => StaffPlayerBrief.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      error: null,
    );
  }

  Future<List<StaffPlayerBrief>> searchPlayers(String query, {int limit = 20}) async {
    final result = await searchPlayersResult(query, limit: limit);
    return result.items;
  }

  Future<StaffPlayerDetail?> getPlayerDetail(String authId) async {
    final result = await getPlayerDetailResult(authId);
    return result.player;
  }

  Future<({StaffPlayerDetail? player, String? error})> getPlayerDetailResult(String authId) async {
    final Map<String, dynamic>? raw = await _rpc('staff_get_player_detail', <String, dynamic>{
      'p_target_user_id': authId,
    });
    final String? error = _rpcError(raw);
    if (error != null) return (player: null, error: error);
    if (raw?['player'] is! Map) return (player: null, error: 'Detay yüklenemedi.');
    return (
      player: StaffPlayerDetail.fromJson(Map<String, dynamic>.from(raw!['player'] as Map)),
      error: null,
    );
  }

  Future<({List<StaffAuditEntry> items, String? error})> listAuditResult({
    int limit = 50,
    int offset = 0,
    String? action,
    String? targetType,
    String? actorQuery,
    String? targetQuery,
    String? actorRole,
  }) async {
    final Map<String, dynamic>? raw = await _rpc('staff_list_audit', <String, dynamic>{
      'p_limit': limit,
      'p_offset': offset,
      'p_action': action,
      'p_target_type': targetType,
      'p_actor_query': actorQuery,
      'p_target_query': targetQuery,
      'p_actor_role': actorRole,
    });
    final String? error = _rpcError(raw);
    if (error != null) return (items: <StaffAuditEntry>[], error: error);
    final List items = raw?['items'] is List ? raw!['items'] as List : <dynamic>[];
    return (
      items: items
          .whereType<Map>()
          .map((Map m) => StaffAuditEntry.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      error: null,
    );
  }

  Future<({List<SupportTicketSummary> items, String? error})> listTicketsResult({
    String? status,
    String? category,
    String? playerQuery,
    int limit = 50,
  }) async {
    final Map<String, dynamic>? raw = await _rpc('staff_list_tickets', <String, dynamic>{
      'p_status': status,
      'p_category': category,
      'p_player_query': playerQuery,
      'p_limit': limit,
    });
    final String? error = _rpcError(raw);
    if (error != null) return (items: <SupportTicketSummary>[], error: error);
    final List items = raw?['items'] is List ? raw!['items'] as List : <dynamic>[];
    return (
      items: items
          .whereType<Map>()
          .map((Map m) => SupportTicketSummary.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      error: null,
    );
  }

  Future<List<SupportTicketSummary>> listTickets({
    String? status,
    String? category,
    String? playerQuery,
    int limit = 50,
  }) async {
    final result = await listTicketsResult(
      status: status,
      category: category,
      playerQuery: playerQuery,
      limit: limit,
    );
    return result.items;
  }

  Future<({List<BugReportSummary> items, String? error})> listBugReportsResult({
    String? status,
    String? playerQuery,
    int limit = 50,
  }) async {
    final Map<String, dynamic>? raw = await _rpc('staff_list_bug_reports', <String, dynamic>{
      'p_status': status,
      'p_player_query': playerQuery,
      'p_limit': limit,
    });
    final String? error = _rpcError(raw);
    if (error != null) return (items: <BugReportSummary>[], error: error);
    final List items = raw?['items'] is List ? raw!['items'] as List : <dynamic>[];
    return (
      items: items
          .whereType<Map>()
          .map((Map m) => BugReportSummary.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      error: null,
    );
  }

  Future<List<BugReportSummary>> listBugReports({
    String? status,
    String? playerQuery,
    int limit = 50,
  }) async {
    final result = await listBugReportsResult(
      status: status,
      playerQuery: playerQuery,
      limit: limit,
    );
    return result.items;
  }

  Future<List<StaffAuditEntry>> listAudit({
    int limit = 50,
    int offset = 0,
    String? action,
    String? targetType,
    String? actorQuery,
    String? targetQuery,
    String? actorRole,
  }) async {
    final result = await listAuditResult(
      limit: limit,
      offset: offset,
      action: action,
      targetType: targetType,
      actorQuery: actorQuery,
      targetQuery: targetQuery,
      actorRole: actorRole,
    );
    return result.items;
  }

  Future<({List<ChatReportEntry> items, String? error})> listChatReportsResult({
    String? status = 'open',
    String? senderQuery,
    int limit = 50,
  }) async {
    final Map<String, dynamic>? raw = await _rpc('staff_list_chat_reports', <String, dynamic>{
      'p_status': status,
      'p_sender_query': senderQuery,
      'p_limit': limit,
    });
    final String? error = _rpcError(raw);
    if (error != null) return (items: <ChatReportEntry>[], error: error);
    final List items = raw?['items'] is List ? raw!['items'] as List : <dynamic>[];
    return (
      items: items
          .whereType<Map>()
          .map((Map m) => ChatReportEntry.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      error: null,
    );
  }

  Future<List<ChatReportEntry>> listChatReports({
    String? status = 'open',
    String? senderQuery,
    int limit = 50,
  }) async {
    final result = await listChatReportsResult(
      status: status,
      senderQuery: senderQuery,
      limit: limit,
    );
    return result.items;
  }

  Future<String?> resolveChatReport(String reportId, String action, {String? note}) async {
    final Map<String, dynamic>? raw = await _rpc('staff_resolve_chat_report', <String, dynamic>{
      'p_report_id': reportId,
      'p_action': action,
      'p_note': note,
    });
    if (raw == null) return 'Sunucuya ulaşılamadı';
    if (raw['success'] == false) return raw['error']?.toString() ?? 'İşlem başarısız';
    return null;
  }

  Future<({List<GmRosterEntry> items, String? error})> listActiveGmsResult() async {
    final Map<String, dynamic>? raw = await _rpc('staff_list_active_gms');
    final String? error = _rpcError(raw);
    if (error != null) return (items: <GmRosterEntry>[], error: error);
    final List items = raw?['items'] is List ? raw!['items'] as List : <dynamic>[];
    return (
      items: items
          .whereType<Map>()
          .map((Map m) => GmRosterEntry.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      error: null,
    );
  }

  Future<List<GmRosterEntry>> listActiveGms() async {
    final result = await listActiveGmsResult();
    return result.items;
  }

  Future<({List<PermissionCatalogItem> items, String? error})> getPermissionCatalogResult() async {
    final Map<String, dynamic>? raw = await _rpc('staff_get_permission_catalog');
    final String? error = _rpcError(raw);
    if (error != null) return (items: <PermissionCatalogItem>[], error: error);
    final List items = raw?['items'] is List ? raw!['items'] as List : <dynamic>[];
    return (
      items: items
          .whereType<Map>()
          .map((Map m) => PermissionCatalogItem.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      error: null,
    );
  }

  Future<List<PermissionCatalogItem>> getPermissionCatalog() async {
    final result = await getPermissionCatalogResult();
    return result.items;
  }

  Future<String?> assignGm(String authId, List<String> permissions) async {
    final Map<String, dynamic>? raw = await _rpc('staff_assign_gm', <String, dynamic>{
      'p_target_user_id': authId,
      'p_permissions': permissions,
    });
    return _rpcError(raw);
  }

  Future<String?> setGmPermissions(String authId, List<String> permissions) async {
    return _rpcError(await _rpc('staff_set_gm_permissions', <String, dynamic>{
      'p_target_user_id': authId,
      'p_permissions': permissions,
    }));
  }

  Future<String?> revokeGm(String authId, String reason) async {
    return _rpcError(await _rpc('staff_revoke_gm', <String, dynamic>{
      'p_target_user_id': authId,
      'p_reason': reason,
    }));
  }

  Future<String?> assignTicket(String ticketId, String staffAuthId) async {
    return _rpcError(await _rpc('staff_assign_ticket', <String, dynamic>{
      'p_ticket_id': ticketId,
      'p_staff_auth_id': staffAuthId,
    }));
  }

  Future<String?> ensureThekingAdmin() async {
    return _rpcError(await _rpc('staff_ensure_theking_admin'));
  }

  Future<String?> approveBugReport(String reportId, int gems, {String? note}) async {
    return _rpcError(await _rpc('staff_approve_bug_report', <String, dynamic>{
      'p_report_id': reportId,
      'p_gems': gems,
      'p_note': note,
    }));
  }

  Future<String?> suggestBugReward(String reportId, int gems, {String? note}) async {
    return _rpcError(await _rpc('staff_suggest_bug_reward', <String, dynamic>{
      'p_report_id': reportId,
      'p_gems': gems,
      'p_note': note,
    }));
  }

  Future<({List<GemRewardPendingItem> items, String? error})> listGemRewardPendingResult({
    int limit = 50,
  }) async {
    final Map<String, dynamic>? raw = await _rpc('staff_list_gem_reward_pending', <String, dynamic>{
      'p_limit': limit,
    });
    final String? error = _rpcError(raw);
    if (error != null) return (items: <GemRewardPendingItem>[], error: error);
    final List items = raw?['items'] is List ? raw!['items'] as List : <dynamic>[];
    return (
      items: items
          .whereType<Map>()
          .map((Map m) => GemRewardPendingItem.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      error: null,
    );
  }

  Future<({List<GemRewardHistoryItem> items, bool hasMore, String? error})> listGemRewardHistoryResult({
    String? usernameQuery,
    int limit = 50,
    int offset = 0,
  }) async {
    final Map<String, dynamic>? raw = await _rpc('staff_list_gem_reward_history', <String, dynamic>{
      'p_username_query': usernameQuery,
      'p_limit': limit,
      'p_offset': offset,
    });
    final String? error = _rpcError(raw);
    if (error != null) {
      return (items: <GemRewardHistoryItem>[], hasMore: false, error: error);
    }
    final List items = raw?['items'] is List ? raw!['items'] as List : <dynamic>[];
    return (
      items: items
          .whereType<Map>()
          .map((Map m) => GemRewardHistoryItem.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      hasMore: raw?['has_more'] == true,
      error: null,
    );
  }

  Future<String?> rejectGemRewardRequest(String reportId, {String? note}) async {
    return _rpcError(await _rpc('staff_reject_gem_reward_request', <String, dynamic>{
      'p_report_id': reportId,
      if (note != null) 'p_note': note,
    }));
  }

  Future<String?> adjustPlayerStat(
    String authId,
    String stat,
    int delta, {
    required String reason,
  }) async {
    return _rpcError(await _rpc('staff_adjust_player_stat', <String, dynamic>{
      'p_target_user_id': authId,
      'p_stat': stat,
      'p_delta': delta,
      'p_reason': reason,
    }));
  }

  Future<String?> playerAction(String fn, Map<String, dynamic> params) async {
    return _rpcError(await _rpc(fn, params));
  }

  Future<({List<StaffInventoryRow> items, int slotCount, int capacity, String? error})> getPlayerInventory(
    String authId,
  ) async {
    final Map<String, dynamic>? raw = await _rpc('staff_get_player_inventory', <String, dynamic>{
      'p_target_user_id': authId,
    });
    final String? error = _rpcError(raw);
    if (error != null) {
      return (items: <StaffInventoryRow>[], slotCount: 0, capacity: 20, error: error);
    }
    final List items = raw?['items'] is List ? raw!['items'] as List : <dynamic>[];
    return (
      items: items
          .whereType<Map>()
          .map((Map m) => StaffInventoryRow.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      slotCount: (raw?['slot_count'] as num?)?.toInt() ?? 0,
      capacity: (raw?['capacity'] as num?)?.toInt() ?? 20,
      error: null,
    );
  }

  Future<({List<StaffItemCatalogEntry> items, int total, String? error})> searchItems(
    String query, {
    int limit = 5000,
  }) async {
    final Map<String, dynamic>? raw = await _rpc('staff_search_items', <String, dynamic>{
      'p_query': query.trim().isEmpty ? null : query.trim(),
      'p_limit': limit,
    });
    final String? error = _rpcError(raw);
    if (error != null) return (items: <StaffItemCatalogEntry>[], total: 0, error: error);
    final dynamic rawItems = raw?['items'];
    final List<dynamic> items = rawItems is List
        ? rawItems
        : rawItems is Map
            ? rawItems.values.toList()
            : <dynamic>[];
    return (
      items: items
          .whereType<Map>()
          .map((Map m) => StaffItemCatalogEntry.fromJson(Map<String, dynamic>.from(m)))
          .where((StaffItemCatalogEntry e) => e.id.isNotEmpty)
          .toList(),
      total: (raw?['total'] as num?)?.toInt() ?? items.length,
      error: null,
    );
  }

  Future<String?> adjustInventory(
    String authId,
    String itemId,
    int delta,
    String reason,
  ) async {
    return _rpcError(await _rpc('staff_adjust_inventory', <String, dynamic>{
      'p_target_user_id': authId,
      'p_item_id': itemId,
      'p_quantity_delta': delta,
      'p_reason': reason,
    }));
  }

  Future<String?> setInventoryQuantity(
    String authId,
    String itemId,
    int quantity,
    String reason,
  ) async {
    return _rpcError(await _rpc('staff_set_inventory_quantity', <String, dynamic>{
      'p_target_user_id': authId,
      'p_item_id': itemId,
      'p_quantity': quantity,
      'p_reason': reason,
    }));
  }

  Future<String?> removeInventoryRow(
    String authId,
    String rowId,
    String reason, {
    bool forceEquipped = false,
  }) async {
    return _rpcError(await _rpc('staff_remove_inventory_row', <String, dynamic>{
      'p_target_user_id': authId,
      'p_row_id': rowId,
      'p_reason': reason,
      'p_force_equipped': forceEquipped,
    }));
  }
}
