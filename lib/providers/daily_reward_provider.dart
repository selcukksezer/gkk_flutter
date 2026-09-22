import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_reward_model.dart';
import '../repositories/daily_reward_repository.dart';
import 'player_provider.dart';

class DailyRewardState {
  const DailyRewardState({
    this.isLoading = false,
    this.claimInProgress = false,
    this.status,
    this.error,
    this.lastClaimWarning,
    this.autoPromptedThisSession = false,
  });

  final bool isLoading;
  final bool claimInProgress;
  final DailyRewardStatus? status;
  final String? error;
  final String? lastClaimWarning;
  /// Home auto-popup once per app session (claim → loadProfile must not re-open).
  final bool autoPromptedThisSession;

  /// Hot reload can leave pre-field instances with null bool storage.
  bool get didAutoPromptThisSession {
    try {
      return autoPromptedThisSession;
    } catch (_) {
      return false;
    }
  }

  /// Hot reload can leave pre-field instances with null bool storage.
  static bool _readAutoPrompted(DailyRewardState state) {
    return state.didAutoPromptThisSession;
  }

  DailyRewardState copyWith({
    bool? isLoading,
    bool? claimInProgress,
    DailyRewardStatus? status,
    String? error,
    String? lastClaimWarning,
    bool? autoPromptedThisSession,
    bool clearError = false,
    bool clearStatus = false,
    bool clearWarning = false,
  }) {
    return DailyRewardState(
      isLoading: isLoading ?? this.isLoading,
      claimInProgress: claimInProgress ?? this.claimInProgress,
      status: clearStatus ? null : (status ?? this.status),
      error: clearError ? null : (error ?? this.error),
      lastClaimWarning: clearWarning
          ? null
          : (lastClaimWarning ?? this.lastClaimWarning),
      autoPromptedThisSession:
          autoPromptedThisSession ?? _readAutoPrompted(this),
    );
  }
}

final dailyRewardRepositoryProvider = Provider<DailyRewardRepository>(
  (ref) => DailyRewardRepository(),
);

class DailyRewardNotifier extends Notifier<DailyRewardState> {
  DailyRewardRepository get _repository => ref.read(dailyRewardRepositoryProvider);

  @override
  DailyRewardState build() => const DailyRewardState();

  Future<void> loadStatus() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final status = await _repository.getStatus();
      state = state.copyWith(isLoading: false, status: status);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> claim() async {
    state = state.copyWith(
      claimInProgress: true,
      clearError: true,
      clearWarning: true,
    );
    try {
      final result = await _repository.claim();
      if (!result.success) {
        state = state.copyWith(
          claimInProgress: false,
          error: result.error ?? 'Ödül alınamadı.',
        );
        return false;
      }

      await loadStatus();
      await ref.read(playerProvider.notifier).loadProfile();
      state = state.copyWith(
        claimInProgress: false,
        autoPromptedThisSession: true,
        lastClaimWarning: result.warning ??
            (result.itemSkipped ? result.message : null),
      );
      return true;
    } catch (e) {
      state = state.copyWith(claimInProgress: false, error: e.toString());
      return false;
    }
  }

  void markAutoPromptedThisSession() {
    state = state.copyWith(autoPromptedThisSession: true);
  }

  void clear() {
    state = const DailyRewardState();
  }
}

final dailyRewardProvider =
    NotifierProvider<DailyRewardNotifier, DailyRewardState>(
  DailyRewardNotifier.new,
);
