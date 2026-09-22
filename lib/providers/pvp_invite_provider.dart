import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/app_foreground_service.dart';
import '../core/services/supabase_service.dart';
import 'auth_provider.dart';

/// Gelen PvP düello daveti (VS overlay verisi).
class PvpInvite {
  const PvpInvite({
    required this.inviteId,
    required this.wager,
    required this.challengerId,
    required this.challengerName,
    this.challengerAvatar,
    this.challengerLevel = 1,
    this.challengerPower = 0,
    this.challengerRating = 1000,
    this.expiresAt,
  });

  final String inviteId;
  final int wager;
  final String challengerId;
  final String challengerName;
  final String? challengerAvatar;
  final int challengerLevel;
  final int challengerPower;
  final int challengerRating;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && !expiresAt!.isAfter(DateTime.now());

  factory PvpInvite.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> ch = json['challenger'] is Map
        ? Map<String, dynamic>.from(json['challenger'] as Map)
        : <String, dynamic>{};
    final String display = (ch['display_name'] ?? '').toString();
    return PvpInvite(
      inviteId: (json['invite_id'] ?? '').toString(),
      wager: (json['wager'] as num?)?.toInt() ?? 0,
      challengerId: (ch['auth_id'] ?? '').toString(),
      challengerName:
          display.isNotEmpty ? display : (ch['username'] ?? 'Oyuncu').toString(),
      challengerAvatar: ch['avatar_url']?.toString(),
      challengerLevel: (ch['level'] as num?)?.toInt() ?? 1,
      challengerPower: (ch['power'] as num?)?.toInt() ?? 0,
      challengerRating: (ch['pvp_rating'] as num?)?.toInt() ?? 1000,
      expiresAt: DateTime.tryParse((json['expires_at'] ?? '').toString())
          ?.toLocal(),
    );
  }
}

/// Davet eden tarafın görmediği düello sonucu (kabul/red).
class PvpDuelResultNotice {
  const PvpDuelResultNotice({
    required this.inviteId,
    required this.wager,
    required this.declined,
    required this.duel,
    required this.opponentId,
    required this.opponentName,
    this.opponentAvatar,
    this.opponentLevel = 1,
    this.opponentPower = 0,
    this.opponentRating = 1000,
    this.expired = false,
  });

  final String inviteId;
  final int wager;
  final bool declined;
  final bool expired;

  /// respond_pvp_invite'ın kaydettiği result JSON'u (declined ise boş).
  final Map<String, dynamic> duel;
  final String opponentId;
  final String opponentName;
  final String? opponentAvatar;
  final int opponentLevel;
  final int opponentPower;
  final int opponentRating;

  factory PvpDuelResultNotice.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> op = json['opponent'] is Map
        ? Map<String, dynamic>.from(json['opponent'] as Map)
        : <String, dynamic>{};
    final String display = (op['display_name'] ?? '').toString();
    return PvpDuelResultNotice(
      inviteId: (json['invite_id'] ?? '').toString(),
      wager: (json['wager'] as num?)?.toInt() ?? 0,
      declined: (json['status'] ?? '').toString() == 'declined',
      expired: (json['status'] ?? '').toString() == 'expired',
      duel: json['result'] is Map
          ? Map<String, dynamic>.from(json['result'] as Map)
          : <String, dynamic>{},
      opponentId: (op['auth_id'] ?? '').toString(),
      opponentName:
          display.isNotEmpty ? display : (op['username'] ?? 'Oyuncu').toString(),
      opponentAvatar: op['avatar_url']?.toString(),
      opponentLevel: (op['level'] as num?)?.toInt() ?? 1,
      opponentPower: (op['power'] as num?)?.toInt() ?? 0,
      opponentRating: (op['pvp_rating'] as num?)?.toInt() ?? 1000,
    );
  }
}

/// Arena saldırısı / savunma sonucu (uygulama kapalıyken gelen maç).
class PvpArenaResultNotice {
  const PvpArenaResultNotice({
    required this.notificationId,
    required this.opponentName,
    required this.wager,
    required this.ratingChange,
    required this.won,
  });

  final String notificationId;
  final String opponentName;
  final int wager;
  final int ratingChange;
  final bool won;

  factory PvpArenaResultNotice.fromJson(Map<String, dynamic> json) => PvpArenaResultNotice(
        notificationId: (json['notification_id'] ?? '').toString(),
        opponentName: (json['opponent_name'] ?? 'Rakip').toString(),
        wager: (json['wager'] as num?)?.toInt() ?? 0,
        ratingChange: (json['rating_change'] as num?)?.toInt() ?? 0,
        won: json['won'] == true,
      );
}

class PvpInviteState {
  const PvpInviteState({
    this.pending = const <PvpInvite>[],
    this.dismissedIds = const <String>{},
    this.unseenResults = const <PvpDuelResultNotice>[],
    this.unseenArenaResults = const <PvpArenaResultNotice>[],
  });

  final List<PvpInvite> pending;
  final Set<String> dismissedIds;
  final List<PvpDuelResultNotice> unseenResults;
  final List<PvpArenaResultNotice> unseenArenaResults;

  PvpInvite? get nextPopup {
    for (final PvpInvite invite in pending) {
      if (invite.isExpired) continue;
      if (!dismissedIds.contains(invite.inviteId)) return invite;
    }
    return null;
  }

  PvpDuelResultNotice? get nextResult {
    for (final PvpDuelResultNotice r in unseenResults) {
      if (!dismissedIds.contains(r.inviteId)) return r;
    }
    return null;
  }

  PvpArenaResultNotice? get nextArenaResult {
    for (final PvpArenaResultNotice r in unseenArenaResults) {
      if (!dismissedIds.contains(r.notificationId)) return r;
    }
    return null;
  }

  PvpInviteState copyWith({
    List<PvpInvite>? pending,
    Set<String>? dismissedIds,
    List<PvpDuelResultNotice>? unseenResults,
    List<PvpArenaResultNotice>? unseenArenaResults,
  }) {
    return PvpInviteState(
      pending: pending ?? this.pending,
      dismissedIds: dismissedIds ?? this.dismissedIds,
      unseenResults: unseenResults ?? this.unseenResults,
      unseenArenaResults: unseenArenaResults ?? this.unseenArenaResults,
    );
  }
}

class PvpInviteNotifier extends Notifier<PvpInviteState> {
  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(seconds: 8);

  void _onForegroundChanged() {
    if (AppForegroundService.instance.isForeground) {
      _syncPolling();
    } else {
      _stopPolling();
    }
  }

  @override
  PvpInviteState build() {
    AppForegroundService.instance.addListener(_onForegroundChanged);
    ref.listen<AuthState>(authProvider, (AuthState? prev, AuthState next) {
      _syncPolling();
    });
    ref.onDispose(() {
      AppForegroundService.instance.removeListener(_onForegroundChanged);
      _stopPolling();
    });
    Future<void>.microtask(_syncPolling);
    return const PvpInviteState();
  }

  void _syncPolling() {
    final bool hasSession = SupabaseService.isInitialized &&
        SupabaseService.client.auth.currentSession != null;
    if (hasSession) {
      _startPolling();
    } else {
      _stopPolling();
      state = const PvpInviteState();
    }
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    if (!AppForegroundService.instance.isForeground) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (AppForegroundService.instance.isForeground) {
        poll();
      }
    });
    poll();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> poll() async {
    if (!SupabaseService.isInitialized) return;
    if (SupabaseService.client.auth.currentUser == null) return;

    try {
      final List<dynamic> results = await Future.wait(<Future<dynamic>>[
        SupabaseService.client.rpc('get_pending_pvp_invites'),
        SupabaseService.client.rpc('get_unseen_pvp_results'),
        SupabaseService.client.rpc('get_unseen_arena_pvp_results'),
      ]);
      final dynamic rawInvites = results[0];
      final dynamic rawResults = results[1];
      final dynamic rawArena = results[2];
      state = state.copyWith(
        pending: rawInvites is List
            ? rawInvites
                .whereType<Map>()
                .map((Map e) =>
                    PvpInvite.fromJson(Map<String, dynamic>.from(e)))
                .toList(growable: false)
            : state.pending,
        unseenResults: rawResults is List
            ? rawResults
                .whereType<Map>()
                .map((Map e) => PvpDuelResultNotice.fromJson(
                    Map<String, dynamic>.from(e)))
                .toList(growable: false)
            : state.unseenResults,
        unseenArenaResults: rawArena is List
            ? rawArena
                .whereType<Map>()
                .map((Map e) => PvpArenaResultNotice.fromJson(
                    Map<String, dynamic>.from(e)))
                .toList(growable: false)
            : state.unseenArenaResults,
      );
    } catch (e) {
      // 8 sn'de bir tekrar denenir; davetler 2 dk yaşadığı için kayıp riski düşük.
      if (kDebugMode) debugPrint('pvp invite poll fail: $e');
    }
  }

  /// Challenger sonucu gördü — sunucuda işaretle, listeden düş.
  Future<void> markResultSeen(String inviteId) async {
    dismiss(inviteId);
    state = state.copyWith(
      unseenResults: state.unseenResults
          .where((PvpDuelResultNotice r) => r.inviteId != inviteId)
          .toList(growable: false),
    );
    try {
      await SupabaseService.client.rpc(
        'mark_pvp_result_seen',
        params: <String, dynamic>{'p_invite_id': inviteId},
      );
    } catch (_) {
      // Sessiz — sonraki poll'de tekrar gelirse dismissedIds engeller.
    }
  }

  Future<void> markArenaResultSeen(String notificationId) async {
    dismiss(notificationId);
    state = state.copyWith(
      unseenArenaResults: state.unseenArenaResults
          .where((PvpArenaResultNotice r) => r.notificationId != notificationId)
          .toList(growable: false),
    );
    try {
      await SupabaseService.client.rpc(
        'mark_arena_pvp_result_seen',
        params: <String, dynamic>{'p_notification_id': notificationId},
      );
    } catch (_) {}
  }

  void dismiss(String inviteId) {
    state = state.copyWith(
      dismissedIds: <String>{...state.dismissedIds, inviteId},
    );
  }

  /// Kabul/red. Kabulde düello sonucu döner.
  Future<Map<String, dynamic>> respond({
    required String inviteId,
    required bool accept,
  }) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'respond_pvp_invite',
        params: <String, dynamic>{
          'p_invite_id': inviteId,
          'p_accept': accept,
        },
      );
      dismiss(inviteId);
      await poll();
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return <String, dynamic>{'success': false};
    } catch (_) {
      // Ağ hatası: daveti düşürme — popup tekrar açılır, oyuncu yeniden dener.
      return <String, dynamic>{
        'success': false,
        'error': 'Bağlantı hatası — davet tekrar gösterilecek.',
        'retryable': true,
      };
    }
  }
}

final NotifierProvider<PvpInviteNotifier, PvpInviteState> pvpInviteProvider =
    NotifierProvider<PvpInviteNotifier, PvpInviteState>(PvpInviteNotifier.new);
