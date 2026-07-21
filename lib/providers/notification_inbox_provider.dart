import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/app_foreground_service.dart';
import '../core/services/game_notification_scheduler.dart';
import '../core/services/supabase_service.dart';
import '../models/facility_model.dart';
import '../models/notification_item.dart';
import '../models/quest_model.dart';
import '../providers/auth_provider.dart';
import '../providers/box_opening_provider.dart';
import '../providers/daily_reward_provider.dart';
import '../providers/player_provider.dart';
import '../providers/pvp_invite_provider.dart';
import '../providers/trade_invite_provider.dart';
import '../routing/app_router.dart';

class NotificationInboxState {
  const NotificationInboxState({
    this.items = const <GameNotificationItem>[],
    this.dismissedIds = const <String>{},
    this.isRefreshing = false,
    this.lastRefreshAt,
  });

  final List<GameNotificationItem> items;
  final Set<String> dismissedIds;
  final bool isRefreshing;
  final DateTime? lastRefreshAt;

  int get unreadCount =>
      items.where((GameNotificationItem i) => !dismissedIds.contains(i.id)).length;

  List<GameNotificationItem> get visibleItems => items
      .where((GameNotificationItem i) => !dismissedIds.contains(i.id))
      .toList(growable: false);

  NotificationInboxState copyWith({
    List<GameNotificationItem>? items,
    Set<String>? dismissedIds,
    bool? isRefreshing,
    DateTime? lastRefreshAt,
  }) {
    return NotificationInboxState(
      items: items ?? this.items,
      dismissedIds: dismissedIds ?? this.dismissedIds,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastRefreshAt: lastRefreshAt ?? this.lastRefreshAt,
    );
  }
}

class NotificationInboxNotifier extends Notifier<NotificationInboxState> {
  static const Duration _pollInterval = Duration(seconds: 20);
  static const Duration _tickInterval = Duration(seconds: 1);
  static const int _maxStoredDismissals = 400;

  Timer? _pollTimer;
  Timer? _tickTimer;
  List<GameNotificationItem> _remoteItems = const <GameNotificationItem>[];
  bool _refreshInFlight = false;
  bool _dismissLoaded = false;

  void _onForegroundChanged() {
    if (AppForegroundService.instance.isForeground) {
      _syncPolling();
    } else {
      _stopPolling();
      _stopTickTimer();
    }
  }

  static String _dismissPrefsKey(String userId) => 'notification_dismissed_$userId';

  @override
  NotificationInboxState build() {
    AppForegroundService.instance.addListener(_onForegroundChanged);
    ref.listen<AuthState>(authProvider, (_, __) => _syncPolling());
    ref.listen<PvpInviteState>(pvpInviteProvider, (_, __) {
      _publishMerged();
      _syncTickTimer();
    });
    ref.listen<TradeInviteState>(tradeInviteProvider, (_, __) {
      _publishMerged();
    });
    ref.listen<DailyRewardState>(dailyRewardProvider, (_, __) {
      _publishMerged();
    });
    ref.listen<PlayerState>(playerProvider, (_, __) {
      _publishMerged();
      _syncTickTimer();
    });
    ref.listen<List<BoxOpening>>(boxOpeningProvider, (_, __) {
      _publishMerged();
      _syncTickTimer();
    });

    ref.onDispose(() {
      AppForegroundService.instance.removeListener(_onForegroundChanged);
      _stopPolling();
      _stopTickTimer();
    });
    Future<void>.microtask(_syncPolling);
    return const NotificationInboxState();
  }

  void _syncPolling() {
    final bool hasSession = SupabaseService.isInitialized &&
        SupabaseService.client.auth.currentSession != null;
    if (hasSession) {
      unawaited(_ensureDismissLoaded());
      _startPolling();
    } else {
      _stopPolling();
      _stopTickTimer();
      _remoteItems = const <GameNotificationItem>[];
      _dismissLoaded = false;
      state = const NotificationInboxState();
    }
  }

  Future<void> _ensureDismissLoaded() async {
    if (_dismissLoaded) return;
    final String? userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> stored =
          prefs.getStringList(_dismissPrefsKey(userId)) ?? const <String>[];
      state = state.copyWith(dismissedIds: stored.toSet());
    } catch (_) {
      // Bellek içi dismiss yine çalışır.
    } finally {
      _dismissLoaded = true;
    }
  }

  Future<void> _persistDismissedIds() async {
    final String? userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> ids = state.dismissedIds.toList(growable: false);
      final List<String> trimmed = ids.length <= _maxStoredDismissals
          ? ids
          : ids.sublist(ids.length - _maxStoredDismissals);
      await prefs.setStringList(_dismissPrefsKey(userId), trimmed);
    } catch (_) {
      // Oturum içi dismiss korunur.
    }
  }

  void _markDismissedOnServer(String id) {
    if (id.startsWith('friend_event:')) {
      final String eventId = id.substring('friend_event:'.length);
      unawaited(_markFriendshipEventSeen(eventId));
      return;
    }
    if (id.startsWith('pvp_result:')) {
      final String inviteId = id.substring('pvp_result:'.length);
      unawaited(ref.read(pvpInviteProvider.notifier).markResultSeen(inviteId));
    }
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    if (!AppForegroundService.instance.isForeground) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (AppForegroundService.instance.isForeground) {
        refresh();
      }
    });
    unawaited(refresh());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startTickTimer() {
    if (_tickTimer != null) return;
    if (!AppForegroundService.instance.isForeground) return;
    _tickTimer = Timer.periodic(_tickInterval, (_) {
      if (!AppForegroundService.instance.isForeground) {
        _stopTickTimer();
        return;
      }
      _publishMerged();
      if (!_needsTimeTick()) {
        _stopTickTimer();
      }
    });
  }

  void _stopTickTimer() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  void _syncTickTimer() {
    if (_needsTimeTick()) {
      _startTickTimer();
    } else {
      _stopTickTimer();
    }
  }

  bool _needsTimeTick() {
    for (final BoxOpening box in ref.read(boxOpeningProvider)) {
      if (!box.isReady) return true;
    }

    final profile = ref.read(playerProvider).profile;
    if (profile == null) return false;

    if (_isFuture(profile.hospitalUntil) || _isFuture(profile.prisonUntil)) {
      return true;
    }

    for (final GameNotificationItem item in _remoteItems) {
      if (item.kind == NotificationKind.facilityReady) return true;
    }

    return false;
  }

  void dismiss(String id) {
    if (state.dismissedIds.contains(id)) return;
    _markDismissedOnServer(id);
    state = state.copyWith(dismissedIds: <String>{...state.dismissedIds, id});
    unawaited(_persistDismissedIds());
  }

  void dismissAll() {
    final Set<String> merged = <String>{
      ...state.dismissedIds,
      ...state.items.map((GameNotificationItem i) => i.id),
    };
    for (final String id in merged) {
      if (!state.dismissedIds.contains(id)) {
        _markDismissedOnServer(id);
      }
    }
    state = state.copyWith(dismissedIds: merged);
    unawaited(_persistDismissedIds());
  }

  Future<void> refresh() async {
    if (!SupabaseService.isInitialized) return;
    if (SupabaseService.client.auth.currentUser == null) return;
    if (_refreshInFlight) return;

    await _ensureDismissLoaded();

    _refreshInFlight = true;
    state = state.copyWith(isRefreshing: true);

    try {
      await Future.wait<void>(<Future<void>>[
        ref.read(dailyRewardProvider.notifier).loadStatus(),
        ref.read(boxOpeningProvider.notifier).load(),
      ]);

      _remoteItems = await _fetchRemoteItems();
      _publishMerged(lastRefreshAt: DateTime.now());
      _syncTickTimer();
      unawaited(GameNotificationScheduler.instance.syncFacilitiesFromServer());
    } finally {
      _refreshInFlight = false;
      state = state.copyWith(isRefreshing: false);
    }
  }

  void _publishMerged({DateTime? lastRefreshAt}) {
    if (!SupabaseService.isInitialized) return;
    if (SupabaseService.client.auth.currentSession == null) return;

    final Map<String, GameNotificationItem> merged = <String, GameNotificationItem>{};
    for (final GameNotificationItem item in <GameNotificationItem>[
      ..._itemsFromProviders(),
      ..._remoteItems,
    ]) {
      merged[item.id] = item;
    }

    final List<GameNotificationItem> sorted = merged.values.toList(growable: false)
      ..sort((GameNotificationItem a, GameNotificationItem b) {
        final int byPriority = b.priority.compareTo(a.priority);
        if (byPriority != 0) return byPriority;
        return b.createdAt.compareTo(a.createdAt);
      });

    state = state.copyWith(
      items: sorted,
      lastRefreshAt: lastRefreshAt ?? state.lastRefreshAt,
    );
  }

  List<GameNotificationItem> _itemsFromProviders() {
    final DateTime now = DateTime.now();
    final List<GameNotificationItem> out = <GameNotificationItem>[];

    final PvpInviteState pvp = ref.read(pvpInviteProvider);
    for (final PvpInvite invite in pvp.pending) {
      out.add(
        GameNotificationItem(
          id: 'pvp_invite:${invite.inviteId}',
          kind: NotificationKind.pvpInvite,
          title: 'PvP düello daveti',
          body: '${invite.challengerName} seni düelloya çağırıyor (${invite.wager} gold).',
          createdAt: now,
          routePath: AppRoutes.pvp,
          priority: 90,
        ),
      );
    }
    for (final PvpDuelResultNotice result in pvp.unseenResults) {
      out.add(
        GameNotificationItem(
          id: 'pvp_result:${result.inviteId}',
          kind: NotificationKind.pvpResult,
          title: result.declined ? 'Düello reddedildi' : 'Düello sonucu',
          body: result.declined
              ? '${result.opponentName} davetini reddetti.'
              : '${result.opponentName} ile düellon bitti.',
          createdAt: now,
          routePath: AppRoutes.pvp,
          priority: 85,
        ),
      );
    }

    for (final TradeInvite invite in ref.read(tradeInviteProvider).pending) {
      out.add(
        GameNotificationItem(
          id: 'trade:${invite.sessionId}',
          kind: NotificationKind.tradeInvite,
          title: 'Ticaret isteği',
          body: '${invite.initiatorName} seninle ticaret yapmak istiyor.',
          createdAt: now,
          routePath: AppRoutes.trade,
          priority: 88,
        ),
      );
    }

    final DailyRewardState daily = ref.read(dailyRewardProvider);
    if (daily.status?.canClaim == true) {
      out.add(
        GameNotificationItem(
          id: 'daily:claim',
          kind: NotificationKind.dailyReward,
          title: 'Günlük ödül hazır',
          body: 'Bugünkü ödülünü almayı unutma.',
          createdAt: now,
          routePath: AppRoutes.home,
          priority: 70,
        ),
      );
    }

    for (final BoxOpening box in ref.read(boxOpeningProvider)) {
      if (!box.isReady) continue;
      out.add(
        GameNotificationItem(
          id: 'box:${box.openingId}',
          kind: NotificationKind.boxReady,
          title: 'Kasa açılmaya hazır',
          body: '${box.boxName} kasasını açabilirsin.',
          createdAt: box.opensAt.toLocal(),
          routePath: AppRoutes.inventory,
          priority: 65,
        ),
      );
    }

    final profile = ref.read(playerProvider).profile;
    if (profile != null) {
      if (_isFuture(profile.hospitalUntil)) {
        out.add(
          GameNotificationItem(
            id: 'hospital:active',
            kind: NotificationKind.hospital,
            title: 'Hastanedesin',
            body: profile.hospitalReason?.isNotEmpty == true
                ? profile.hospitalReason!
                : 'İyileşene kadar bazı aktiviteler kısıtlı.',
            createdAt: now,
            routePath: AppRoutes.hospital,
            priority: 60,
          ),
        );
      }
      if (_isFuture(profile.prisonUntil)) {
        out.add(
          GameNotificationItem(
            id: 'prison:active',
            kind: NotificationKind.prison,
            title: 'Hapistesin',
            body: profile.prisonReason?.isNotEmpty == true
                ? profile.prisonReason!
                : 'Serbest kalana kadar hareketlerin kısıtlı.',
            createdAt: now,
            routePath: AppRoutes.prison,
            priority: 60,
          ),
        );
      }
      if (profile.maxHealth > 0 &&
          profile.health < (profile.maxHealth * 0.35).round() &&
          !_isFuture(profile.hospitalUntil)) {
        out.add(
          GameNotificationItem(
            id: 'health:low',
            kind: NotificationKind.lowHealth,
            title: 'Canın düşük',
            body: 'Canın %${((profile.health / profile.maxHealth) * 100).round()} — hastaneye git.',
            createdAt: now,
            routePath: AppRoutes.hospital,
            priority: 55,
          ),
        );
      }
    }

    return out;
  }

  Future<List<GameNotificationItem>> _fetchRemoteItems() async {
    final DateTime now = DateTime.now();
    final List<GameNotificationItem> out = <GameNotificationItem>[];
    final int level = ref.read(playerProvider).profile?.level ?? 1;

    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        SupabaseService.client.rpc('get_friends'),
        SupabaseService.client.rpc('get_referral_info'),
        SupabaseService.client.rpc('get_dm_conversations'),
        SupabaseService.client.rpc(
          'get_available_quests',
          params: <String, dynamic>{'p_player_level': level},
        ),
        SupabaseService.client.rpc('get_player_facilities_with_queue'),
        SupabaseService.client.rpc('get_unseen_friendship_events'),
      ]);

      final dynamic friendsRaw = results[0];
      if (friendsRaw is Map) {
        final dynamic incoming = friendsRaw['incoming'];
        if (incoming is List) {
          for (final dynamic row in incoming) {
            if (row is! Map) continue;
            final Map<String, dynamic> map = Map<String, dynamic>.from(row);
            final String id = (map['friendship_id'] ?? map['id'] ?? '').toString();
            final String name = (map['display_name'] ?? map['username'] ?? 'Oyuncu').toString();
            final String username = (map['username'] ?? '').toString();
            if (id.isEmpty) continue;
            final String nameLabel =
                username.isNotEmpty && name != username ? '$name (@$username)' : name;
            out.add(
              GameNotificationItem(
                id: 'friend:$id',
                kind: NotificationKind.friendRequest,
                title: 'Arkadaşlık isteği',
                body: '$nameLabel seni arkadaş olarak eklemek istiyor.',
                createdAt: now,
                routePath: AppRoutes.friends,
                priority: 80,
              ),
            );
          }
        }
      }

      final dynamic referralRaw = results[1];
      if (referralRaw is Map && referralRaw['success'] == true) {
        final int claimable = (referralRaw['claimable_gems'] as num?)?.toInt() ?? 0;
        if (claimable > 0) {
          out.add(
            GameNotificationItem(
              id: 'referral:claim',
              kind: NotificationKind.referralReward,
              title: 'Referans ödülü',
              body: '$claimable gem tahsil edilebilir.',
              createdAt: now,
              routePath: AppRoutes.friends,
              priority: 75,
            ),
          );
        }
      }

      final dynamic dmRaw = results[2];
      if (dmRaw is List) {
        for (final dynamic row in dmRaw) {
          if (row is! Map) continue;
          final Map<String, dynamic> map = Map<String, dynamic>.from(row);
          final int unread = ((map['unread_count'] as num?) ?? 0).toInt();
          if (unread <= 0) continue;
          final String peerId = (map['peer_id'] ?? map['other_user_id'] ?? '').toString();
          final String name =
              (map['display_name'] ?? map['username'] ?? 'Oyuncu').toString();
          out.add(
            GameNotificationItem(
              id: 'chat:$peerId',
              kind: NotificationKind.chatMessage,
              title: 'Okunmamış mesaj',
              body: '$name: $unread yeni mesaj',
              createdAt: now,
              routePath: AppRoutes.chat,
              routeExtra: peerId.isNotEmpty ? <String, String>{'peerId': peerId} : null,
              priority: 72,
            ),
          );
        }
      }

      final dynamic questsRaw = results[3];
      if (questsRaw is List) {
        for (final dynamic row in questsRaw) {
          if (row is! Map) continue;
          final QuestData quest =
              QuestData.fromJson(Map<String, dynamic>.from(row));
          if (quest.status != QuestStatus.completed) continue;
          out.add(
            GameNotificationItem(
              id: 'quest:${quest.questId}',
              kind: NotificationKind.questReward,
              title: 'Görev ödülü hazır',
              body: '${quest.name} — ödülü al.',
              createdAt: now,
              routePath: quest.isSeasonQuest ? AppRoutes.season : AppRoutes.quests,
              priority: 68,
            ),
          );
        }
      }

      final dynamic facilitiesRaw = results[4];
      final List<dynamic> facilityRows = _unwrapFacilityList(facilitiesRaw);
      for (final dynamic row in facilityRows) {
        if (row is! Map) continue;
        final PlayerFacility facility =
            PlayerFacility.fromJson(Map<String, dynamic>.from(row));
        if (!_facilityHasCollectible(facility)) continue;
        out.add(
          GameNotificationItem(
            id: 'facility:${facility.id}',
            kind: NotificationKind.facilityReady,
            title: 'Tesis üretimi hazır',
            body: '${_facilityLabel(facility.facilityType)} — kaynakları topla.',
            createdAt: now,
            routePath: '${AppRoutes.facilities}/${facility.facilityType}',
            priority: 62,
          ),
        );
      }

      out.addAll(_friendshipEventItems(results[5]));
    } catch (_) {
      // Son bilinen remote liste korunur.
    }

    return out;
  }

  bool _isFuture(String? iso) {
    if (iso == null || iso.isEmpty) return false;
    final DateTime? at = DateTime.tryParse(iso);
    if (at == null) return false;
    return at.toLocal().isAfter(DateTime.now());
  }

  List<dynamic> _unwrapFacilityList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      final dynamic payload = raw['data'];
      if (payload is List) return payload;
    }
    return const <dynamic>[];
  }

  bool _facilityHasCollectible(PlayerFacility facility) {
    for (final FacilityQueueItem item in facility.facilityQueue) {
      if (item.isCompleted) return true;
      if (item.completesAt.isNotEmpty) {
        final DateTime? at = DateTime.tryParse(item.completesAt);
        if (at != null && !DateTime.now().isBefore(at.toLocal())) return true;
      }
    }
    return false;
  }

  String _facilityLabel(String typeKey) {
    return switch (typeKey) {
      'farming' => 'Çiftlik',
      'mine' => 'Maden',
      'lumber' => 'Kereste',
      'fishing' => 'Balıkçılık',
      _ => typeKey.isEmpty ? 'Tesis' : typeKey,
    };
  }

  List<GameNotificationItem> _friendshipEventItems(dynamic raw) {
    final List<dynamic> rows = _unwrapJsonList(raw);
    final List<GameNotificationItem> out = <GameNotificationItem>[];

    for (final dynamic row in rows) {
      if (row is! Map) continue;
      final Map<String, dynamic> map = Map<String, dynamic>.from(row);
      final String eventId = (map['event_id'] ?? '').toString();
      if (eventId.isEmpty) continue;

      final String eventType = (map['event_type'] ?? '').toString();
      final Map<String, dynamic> actor = map['actor'] is Map
          ? Map<String, dynamic>.from(map['actor'] as Map)
          : <String, dynamic>{};
      final String displayName = (actor['display_name'] ?? '').toString();
      final String username = (actor['username'] ?? 'Oyuncu').toString();
      final String name =
          displayName.isNotEmpty ? displayName : username;
      final String nameLabel =
          username.isNotEmpty && name != username ? '$name (@$username)' : name;

      final DateTime createdAt =
          DateTime.tryParse((map['created_at'] ?? '').toString())?.toLocal() ??
              DateTime.now();

      final bool accepted = eventType == 'accepted';
      out.add(
        GameNotificationItem(
          id: 'friend_event:$eventId',
          kind: accepted
              ? NotificationKind.friendRequestAccepted
              : NotificationKind.friendRequestRejected,
          title: accepted ? 'Arkadaşlık isteği kabul edildi' : 'Arkadaşlık isteği reddedildi',
          body: accepted
              ? '$nameLabel isteğini kabul etti. Artık arkadaşsınız!'
              : '$nameLabel arkadaşlık isteğini reddetti.',
          createdAt: createdAt,
          routePath: AppRoutes.friends,
          priority: accepted ? 78 : 77,
        ),
      );
    }

    return out;
  }

  List<dynamic> _unwrapJsonList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      final dynamic payload = raw['data'];
      if (payload is List) return payload;
    }
    return const <dynamic>[];
  }

  Future<void> _markFriendshipEventSeen(String eventId) async {
    if (eventId.isEmpty || !SupabaseService.isInitialized) return;
    try {
      await SupabaseService.client.rpc(
        'mark_friendship_event_seen',
        params: <String, dynamic>{'p_event_id': eventId},
      );
    } catch (_) {
      // Sonraki poll'de dismissedIds engeller.
    }
  }
}

final NotifierProvider<NotificationInboxNotifier, NotificationInboxState>
    notificationInboxProvider =
    NotifierProvider<NotificationInboxNotifier, NotificationInboxState>(
  NotificationInboxNotifier.new,
);
