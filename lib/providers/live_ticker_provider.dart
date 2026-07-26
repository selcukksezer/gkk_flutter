import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../core/services/app_foreground_service.dart';
import '../core/services/supabase_service.dart';
import '../models/live_ticker_model.dart';
import 'auth_provider.dart';

class LiveTickerState {
  const LiveTickerState({
    this.isLoading = false,
    this.queue = const <LiveTickerItem>[],
    this.passCounts = const <String, int>{},
    this.feedArchive = const <LiveTickerItem>[],
    this.archiveLoading = false,
    this.error,
    this.lastRefreshAt,
  });

  final bool isLoading;
  /// FIFO play queue — index 0 is currently scrolling.
  final List<LiveTickerItem> queue;
  /// How many full marquee passes each id has completed.
  final Map<String, int> passCounts;
  /// Full feed for announcements screen (newest first).
  final List<LiveTickerItem> feedArchive;
  final bool archiveLoading;
  final String? error;
  final DateTime? lastRefreshAt;

  LiveTickerItem? get current => queue.isEmpty ? null : queue.first;

  /// Legacy alias used by any old watchers.
  List<LiveTickerItem> get items => queue;

  LiveTickerState copyWith({
    bool? isLoading,
    List<LiveTickerItem>? queue,
    Map<String, int>? passCounts,
    List<LiveTickerItem>? feedArchive,
    bool? archiveLoading,
    String? error,
    DateTime? lastRefreshAt,
    bool clearError = false,
  }) {
    return LiveTickerState(
      isLoading: isLoading ?? this.isLoading,
      queue: queue ?? this.queue,
      passCounts: passCounts ?? this.passCounts,
      feedArchive: feedArchive ?? this.feedArchive,
      archiveLoading: archiveLoading ?? this.archiveLoading,
      error: clearError ? null : (error ?? this.error),
      lastRefreshAt: lastRefreshAt ?? this.lastRefreshAt,
    );
  }
}

class LiveTickerNotifier extends Notifier<LiveTickerState> {
  static const Duration pollInterval = Duration(seconds: 20);
  static const int maxQueue = 12;
  static const int passesBeforeRetire = 3;

  static const LiveTickerItem _fallback = LiveTickerItem(
    id: 'fallback:quiet',
    type: 'ambient',
    text: '🌌 Kamp sessiz… yeni efsaneler yazılıyor.',
  );

  Timer? _pollTimer;
  RealtimeChannel? _broadcastChannel;
  final Set<String> _retired = <String>{};

  void _onForegroundChanged() {
    if (AppForegroundService.instance.isForeground) {
      _syncPolling();
    } else {
      _stopPolling();
    }
  }

  @override
  LiveTickerState build() {
    AppForegroundService.instance.addListener(_onForegroundChanged);
    ref.listen<AuthState>(authProvider, (_, _) => _syncPolling());
    ref.onDispose(() {
      AppForegroundService.instance.removeListener(_onForegroundChanged);
      _broadcastChannel?.unsubscribe();
      _stopPolling();
    });
    Future<void>.microtask(_syncPolling);
    return LiveTickerState(queue: <LiveTickerItem>[_fallback]);
  }

  void _syncPolling() {
    final bool hasSession = SupabaseService.isInitialized &&
        SupabaseService.client.auth.currentSession != null;
    if (!hasSession || !AppForegroundService.instance.isForeground) {
      _stopPolling();
      return;
    }
    _pollTimer ??= Timer.periodic(pollInterval, (_) => load(silent: true));
    _subscribeStaffBroadcasts();
    unawaited(load(silent: true));
  }

  void _subscribeStaffBroadcasts() {
    if (!SupabaseService.isInitialized) return;
    if (_broadcastChannel != null) return;

    _broadcastChannel = SupabaseService.client
        .channel('live_ticker_staff_broadcasts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'staff_broadcasts',
          callback: (_) => unawaited(load(silent: true)),
        )
        .subscribe();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  String? _staffBroadcastId(String tickerId) {
    const String prefix = 'staff_broadcast:';
    if (!tickerId.startsWith(prefix)) return null;
    final String id = tickerId.substring(prefix.length);
    return id.isEmpty ? null : id;
  }

  Future<bool> _recordStaffBroadcastPass(String broadcastId) async {
    if (!SupabaseService.isInitialized) return false;
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'record_staff_broadcast_pass',
        params: <String, dynamic>{'p_broadcast_id': broadcastId},
      );
      if (raw is Map) {
        if (raw['success'] != true || raw['inactive'] == true || raw['is_active'] == false) {
          return true;
        }
        final int remaining = _asInt(raw['passes_remaining']) ?? 1;
        return remaining <= 0;
      }
    } catch (_) {
      // Sessiz — sonraki poll düzeltir.
    }
    return false;
  }

  Future<bool> _recordGlobalPass(String tickerId) async {
    if (!SupabaseService.isInitialized) return false;
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'record_live_ticker_pass',
        params: <String, dynamic>{'p_ticker_id': tickerId},
      );
      if (raw is Map) {
        if (raw['retired'] == true || raw['inactive'] == true) return true;
        if (raw['success'] == true) {
          final int remaining = _asInt(raw['passes_remaining']) ?? passesBeforeRetire;
          return remaining <= 0;
        }
      }
    } catch (_) {
      // Sessiz — sonraki poll düzeltir.
    }
    return false;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _retireQueueItem(String id) {
    _retired.add(id);
    final List<LiveTickerItem> nextQueue =
        List<LiveTickerItem>.from(state.queue)..removeWhere((LiveTickerItem e) => e.id == id);
    if (nextQueue.isEmpty) {
      nextQueue.add(_fallback);
    }
    final Map<String, int> counts = Map<String, int>.from(state.passCounts)..remove(id);
    state = state.copyWith(queue: nextQueue, passCounts: counts);
  }

  /// Called by [LiveTicker] after one full slide completes.
  void onPassComplete() {
    if (state.queue.isEmpty) return;

    final LiveTickerItem head = state.queue.first;

    if (head.isStaffBroadcast) {
      final String? broadcastId = _staffBroadcastId(head.id);
      if (broadcastId != null) {
        unawaited(() async {
          final bool retired = await _recordStaffBroadcastPass(broadcastId);
          if (retired || (head.passesRemaining != null && head.passesRemaining! <= 1)) {
            _retireQueueItem(head.id);
          }
          await load(silent: true);
        }());
      } else {
        _retireQueueItem(head.id);
        unawaited(load(silent: true));
      }
      return;
    }

    if (!head.tracksGlobalPasses) {
      return;
    }

    unawaited(() async {
      final bool retired = await _recordGlobalPass(head.id);
      if (retired) {
        _retireQueueItem(head.id);
      }
      await load(silent: true);
    }());
  }

  void _ingest(LiveTickerFeed feed) {
    for (final String id in feed.retiredTickerIds) {
      if (id.isNotEmpty) _retired.add(id);
    }
    if (_retired.length > 600) {
      _retired.remove(_retired.first);
    }

    final List<LiveTickerItem> eligible = <LiveTickerItem>[];
    LiveTickerItem? newestStaff;
    for (final LiveTickerItem item in feed.items) {
      if (item.id.isEmpty || _retired.contains(item.id)) continue;
      if (item.passesRemaining != null && item.passesRemaining! <= 0) {
        _retired.add(item.id);
        continue;
      }
      if (item.isStaffBroadcast) {
        if (newestStaff == null) {
          newestStaff = item;
        } else {
          final DateTime? a = newestStaff.createdAt;
          final DateTime? b = item.createdAt;
          if (b != null && (a == null || b.isAfter(a))) {
            newestStaff = item;
          }
        }
        continue;
      }
      eligible.add(item);
    }

    eligible.sort((LiveTickerItem a, LiveTickerItem b) {
      final DateTime? ac = a.createdAt;
      final DateTime? bc = b.createdAt;
      if (ac == null && bc == null) return 0;
      if (ac == null) return 1;
      if (bc == null) return -1;
      return ac.compareTo(bc);
    });

    final List<LiveTickerItem> pool = <LiveTickerItem>[
      if (newestStaff != null) newestStaff,
      ...eligible.where((LiveTickerItem e) => e.id != _fallback.id),
    ];

    final bool hasReal = pool.isNotEmpty;
    if (!hasReal) {
      state = state.copyWith(
        queue: <LiveTickerItem>[_fallback],
        passCounts: const <String, int>{},
        lastRefreshAt: DateTime.now(),
        clearError: true,
        isLoading: false,
      );
      return;
    }

    final List<LiveTickerItem> capped = pool.length > maxQueue
        ? pool.sublist(0, maxQueue)
        : pool;

    final String? playingId = state.current?.id;
    final List<LiveTickerItem> nextQueue;
    if (newestStaff != null) {
      // Active staff announcement always preempts the strip.
      final List<LiveTickerItem> tail = capped
          .where((LiveTickerItem e) => e.id != newestStaff!.id)
          .toList(growable: false);
      nextQueue = <LiveTickerItem>[newestStaff, ...tail];
    } else if (playingId != null &&
        playingId != _fallback.id &&
        capped.any((LiveTickerItem e) => e.id == playingId)) {
      final LiveTickerItem head = capped.firstWhere((LiveTickerItem e) => e.id == playingId);
      final List<LiveTickerItem> tail =
          capped.where((LiveTickerItem e) => e.id != playingId).toList(growable: false);
      nextQueue = <LiveTickerItem>[head, ...tail];
    } else {
      nextQueue = capped;
    }

    state = state.copyWith(
      queue: nextQueue,
      passCounts: const <String, int>{},
      lastRefreshAt: DateTime.now(),
      clearError: true,
      isLoading: false,
    );
  }

  Future<void> load({bool silent = false}) async {
    await _fetchFeed(limit: maxQueue, silent: silent, updateQueue: true);
  }

  /// Announcements screen — higher limit, no queue mutation.
  Future<void> loadArchive({int limit = 20}) async {
    await _fetchFeed(limit: limit.clamp(3, 20), silent: false, updateQueue: false, archive: true);
  }

  Future<void> _fetchFeed({
    required int limit,
    required bool silent,
    required bool updateQueue,
    bool archive = false,
  }) async {
    if (!SupabaseService.isInitialized) return;
    if (SupabaseService.client.auth.currentSession == null) return;
    if (archive) {
      state = state.copyWith(archiveLoading: true, clearError: true);
    } else if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'get_live_ticker_feed',
        params: <String, dynamic>{'p_limit': limit},
      );
      if (raw is! Map) {
        state = state.copyWith(
          isLoading: false,
          archiveLoading: false,
          error: 'Geçersiz ticker cevabı',
        );
        return;
      }
      final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
      if (map['success'] == false) {
        state = state.copyWith(
          isLoading: false,
          archiveLoading: false,
          error: map['error']?.toString(),
        );
        return;
      }
      final LiveTickerFeed feed = LiveTickerFeed.fromJson(map);
      if (archive) {
        final List<LiveTickerItem> sorted = List<LiveTickerItem>.from(feed.items)
          ..sort((LiveTickerItem a, LiveTickerItem b) {
            final DateTime? ac = a.createdAt;
            final DateTime? bc = b.createdAt;
            if (ac == null && bc == null) return 0;
            if (ac == null) return 1;
            if (bc == null) return -1;
            return bc.compareTo(ac);
          });
        state = state.copyWith(
          feedArchive: sorted,
          archiveLoading: false,
          clearError: true,
        );
        return;
      }
      if (feed.items.isEmpty) {
        if (state.queue.isEmpty) {
          state = state.copyWith(
            isLoading: false,
            queue: <LiveTickerItem>[_fallback],
            clearError: true,
          );
        } else {
          state = state.copyWith(isLoading: false, clearError: true);
        }
        return;
      }
      if (updateQueue) {
        _ingest(feed);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        archiveLoading: false,
        error: e.toString(),
      );
    }
  }
}

final liveTickerProvider =
    NotifierProvider<LiveTickerNotifier, LiveTickerState>(LiveTickerNotifier.new);
