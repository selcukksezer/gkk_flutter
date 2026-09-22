import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';

class PlayerInboxItem {
  const PlayerInboxItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime? createdAt;

  factory PlayerInboxItem.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    DateTime? readAt;
    if (json['created_at'] is String) {
      createdAt = DateTime.tryParse(json['created_at'] as String);
    }
    if (json['read_at'] is String) {
      readAt = DateTime.tryParse(json['read_at'] as String);
    }
    return PlayerInboxItem(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      readAt: readAt,
      createdAt: createdAt,
    );
  }
}

class PlayerInboxNotifier extends Notifier<List<PlayerInboxItem>> {
  Future<void>? _inFlight;

  @override
  List<PlayerInboxItem> build() {
    Future<void>.microtask(refresh);
    return const <PlayerInboxItem>[];
  }

  Future<void> refresh() async {
    if (_inFlight != null) {
      return _inFlight!;
    }
    _inFlight = _performRefresh();
    try {
      await _inFlight;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _performRefresh() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentSession == null) {
      state = const <PlayerInboxItem>[];
      return;
    }
    try {
      final dynamic raw = await SupabaseService.client.rpc('get_my_inbox_notifications');
      if (raw is Map && raw['items'] is List) {
        state = (raw['items'] as List)
            .whereType<Map>()
            .map((Map m) => PlayerInboxItem.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
    } catch (_) {
      state = const <PlayerInboxItem>[];
    }
  }

  Future<void> markRead(String id) async {
    await SupabaseService.client.rpc(
      'mark_inbox_notification_read',
      params: <String, dynamic>{'p_notification_id': id},
    );
    await refresh();
  }
}

final playerInboxProvider =
    NotifierProvider<PlayerInboxNotifier, List<PlayerInboxItem>>(PlayerInboxNotifier.new);
