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
  });

  final bool isLoading;
  final bool claimInProgress;
  final DailyRewardStatus? status;
  final String? error;

  DailyRewardState copyWith({
    bool? isLoading,
    bool? claimInProgress,
    DailyRewardStatus? status,
    String? error,
    bool clearError = false,
    bool clearStatus = false,
  }) {
    return DailyRewardState(
      isLoading: isLoading ?? this.isLoading,
      claimInProgress: claimInProgress ?? this.claimInProgress,
      status: clearStatus ? null : (status ?? this.status),
      error: clearError ? null : (error ?? this.error),
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
    state = state.copyWith(claimInProgress: true, clearError: true);
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
      state = state.copyWith(claimInProgress: false);
      return true;
    } catch (e) {
      state = state.copyWith(claimInProgress: false, error: e.toString());
      return false;
    }
  }

  void clear() {
    state = const DailyRewardState();
  }
}

final dailyRewardProvider =
    NotifierProvider<DailyRewardNotifier, DailyRewardState>(
  DailyRewardNotifier.new,
);
