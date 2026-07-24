import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/app_foreground_service.dart';
import '../core/services/supabase_service.dart';
import '../core/tutorial/tutorial_controller.dart';
import '../core/tutorial/tutorial_track.dart';
import '../models/retention_promos_model.dart';
import 'player_provider.dart';

class RetentionPromosState {
  const RetentionPromosState({
    this.isLoading = false,
    this.promos = RetentionPromos.empty,
    this.error,
    this.lastRefreshAt,
  });

  final bool isLoading;
  final RetentionPromos promos;
  final String? error;
  final DateTime? lastRefreshAt;

  RetentionPromosState copyWith({
    bool? isLoading,
    RetentionPromos? promos,
    String? error,
    DateTime? lastRefreshAt,
    bool clearError = false,
  }) {
    return RetentionPromosState(
      isLoading: isLoading ?? this.isLoading,
      promos: promos ?? this.promos,
      error: clearError ? null : (error ?? this.error),
      lastRefreshAt: lastRefreshAt ?? this.lastRefreshAt,
    );
  }
}

class RetentionPromosNotifier extends Notifier<RetentionPromosState> {
  static const Duration pollInterval = Duration(seconds: 60);

  Timer? _pollTimer;

  @override
  RetentionPromosState build() {
    ref.onDispose(_stopPolling);
    _syncPolling();
    return const RetentionPromosState();
  }

  void _syncPolling() {
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentUser == null) {
      _stopPolling();
      return;
    }
    if (!AppForegroundService.instance.isForeground) {
      _stopPolling();
      return;
    }
    _pollTimer ??= Timer.periodic(pollInterval, (_) => load(silent: true));
    load(silent: true);
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> load({bool silent = false}) async {
    if (!SupabaseService.isInitialized) return;
    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final dynamic raw = await SupabaseService.client.rpc('get_retention_promos');
      if (raw is! Map) {
        state = state.copyWith(isLoading: false, error: 'Geçersiz promos cevabı');
        return;
      }
      final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
      if (map['success'] == false) {
        state = state.copyWith(
          isLoading: false,
          error: map['error']?.toString(),
        );
        return;
      }
      state = state.copyWith(
        isLoading: false,
        promos: RetentionPromos.fromJson(map),
        lastRefreshAt: DateTime.now(),
        clearError: true,
      );
      unawaited(_maybeStartRetentionTutorial());
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _maybeStartRetentionTutorial() async {
    final int level = ref.read(playerProvider).profile?.level ?? 0;
    if (level < 5) return;
    final TutorialController controller = ref.read(tutorialProvider.notifier);
    if (!controller.isTrackComplete(TutorialTrackId.onboarding)) return;
    if (controller.hasActiveTrack) return;
    if (controller.isTrackComplete(TutorialTrackId.retentionIntro)) return;
    await controller.startTrack(TutorialTrackId.retentionIntro);
  }
}

final retentionPromosProvider =
    NotifierProvider<RetentionPromosNotifier, RetentionPromosState>(
  RetentionPromosNotifier.new,
);
