import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';
import 'auth_provider.dart';

class TradeInvite {
  TradeInvite({
    required this.sessionId,
    required this.initiatorName,
    required this.initiatorId,
  });

  final String sessionId;
  final String initiatorName;
  final String initiatorId;

  factory TradeInvite.fromJson(Map<String, dynamic> json) {
    return TradeInvite(
      sessionId: json['session_id'].toString(),
      initiatorName: (json['initiator_name'] as String?) ?? 'Oyuncu',
      initiatorId: json['initiator_id'].toString(),
    );
  }
}

class TradeInviteState {
  const TradeInviteState({
    this.pending = const <TradeInvite>[],
    this.dismissedSessionIds = const <String>{},
    this.isPolling = false,
    this.blockListRevision = 0,
  });

  final List<TradeInvite> pending;
  final Set<String> dismissedSessionIds;
  final bool isPolling;
  final int blockListRevision;

  TradeInvite? get nextPopup {
    for (final TradeInvite invite in pending) {
      if (!dismissedSessionIds.contains(invite.sessionId)) {
        return invite;
      }
    }
    return null;
  }

  TradeInviteState copyWith({
    List<TradeInvite>? pending,
    Set<String>? dismissedSessionIds,
    bool? isPolling,
    int? blockListRevision,
  }) {
    return TradeInviteState(
      pending: pending ?? this.pending,
      dismissedSessionIds: dismissedSessionIds ?? this.dismissedSessionIds,
      isPolling: isPolling ?? this.isPolling,
      blockListRevision: blockListRevision ?? this.blockListRevision,
    );
  }
}

List<TradeInvite> parseTradeInvites(dynamic raw) {
  if (raw == null) return <TradeInvite>[];

  dynamic decoded = raw;
  if (raw is String) {
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return <TradeInvite>[];
    }
  }

  if (decoded is List) {
    final List<TradeInvite> invites = <TradeInvite>[];
    for (final dynamic row in decoded) {
      if (row is Map) {
        invites.add(TradeInvite.fromJson(Map<String, dynamic>.from(row)));
      }
    }
    return invites;
  }

  if (decoded is Map && decoded['session_id'] != null) {
    return <TradeInvite>[TradeInvite.fromJson(Map<String, dynamic>.from(decoded))];
  }

  return <TradeInvite>[];
}

class TradeInviteNotifier extends Notifier<TradeInviteState> {
  Timer? _pollTimer;
  StreamSubscription<dynamic>? _authSub;

  @override
  TradeInviteState build() {
    ref.listen<AuthState>(authProvider, (AuthState? prev, AuthState next) {
      _syncPolling();
    });

    _authSub?.cancel();
    if (SupabaseService.isInitialized) {
      _authSub = SupabaseService.client.auth.onAuthStateChange.listen((_) => _syncPolling());
    }
    ref.onDispose(() {
      stopPolling();
      _authSub?.cancel();
    });

    Future<void>.microtask(_syncPolling);
    return const TradeInviteState();
  }

  void _syncPolling() {
    final bool hasSession = SupabaseService.isInitialized &&
        SupabaseService.client.auth.currentSession != null;
    if (hasSession) {
      startPolling();
    } else {
      stopPolling();
      state = const TradeInviteState();
    }
  }

  void startPolling() {
    if (_pollTimer != null) return;
    state = state.copyWith(isPolling: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => pollInvites());
    pollInvites();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    state = state.copyWith(isPolling: false);
  }

  Future<void> pollInvites() async {
    if (!SupabaseService.isInitialized) return;
    if (SupabaseService.client.auth.currentUser == null) return;

    try {
      final dynamic raw = await SupabaseService.client.rpc('get_pending_trade_invites');
      final List<TradeInvite> invites = parseTradeInvites(raw);
      state = state.copyWith(pending: invites);
    } catch (_) {
      // Silent — next poll retries.
    }
  }

  void dismissPopup(String sessionId) {
    state = state.copyWith(
      dismissedSessionIds: <String>{...state.dismissedSessionIds, sessionId},
    );
  }

  Future<Map<String, dynamic>> respond({
    required String sessionId,
    required bool accept,
    required bool blockSender,
  }) async {
    final dynamic raw = await SupabaseService.client.rpc(
      'respond_trade_invite',
      params: <String, dynamic>{
        'p_session_id': sessionId,
        'p_accept': accept,
        'p_block_sender': blockSender,
      },
    );
    dismissPopup(sessionId);
    if (!accept && blockSender) {
      state = state.copyWith(blockListRevision: state.blockListRevision + 1);
    }
    await pollInvites();
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{'success': false};
  }
}

final NotifierProvider<TradeInviteNotifier, TradeInviteState> tradeInviteProvider =
    NotifierProvider<TradeInviteNotifier, TradeInviteState>(TradeInviteNotifier.new);
