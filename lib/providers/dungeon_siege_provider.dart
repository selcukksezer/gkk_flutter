import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dungeon_siege_model.dart';
import '../repositories/dungeon_siege_repository.dart';

final Provider<DungeonSiegeRepository> dungeonSiegeRepositoryProvider =
    Provider<DungeonSiegeRepository>((Ref ref) => SupabaseDungeonSiegeRepository());

class DungeonSiegeState {
  const DungeonSiegeState({
    required this.loading,
    required this.status,
    this.errorMessage,
    this.actionLoading = false,
  });

  final bool loading;
  final DungeonSiegeStatus status;
  final String? errorMessage;
  final bool actionLoading;

  factory DungeonSiegeState.initial() => DungeonSiegeState(
        loading: false,
        status: DungeonSiegeStatus.empty(),
      );

  DungeonSiegeState copyWith({
    bool? loading,
    DungeonSiegeStatus? status,
    String? errorMessage,
    bool? actionLoading,
    bool clearError = false,
  }) {
    return DungeonSiegeState(
      loading: loading ?? this.loading,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      actionLoading: actionLoading ?? this.actionLoading,
    );
  }
}

class DungeonSiegeNotifier extends Notifier<DungeonSiegeState> {
  DungeonSiegeRepository get _repository => ref.read(dungeonSiegeRepositoryProvider);

  @override
  DungeonSiegeState build() => DungeonSiegeState.initial();

  Future<void> loadStatus({String? dungeonId}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final DungeonSiegeStatus status = await _repository.getStatus(dungeonId: dungeonId);
      state = state.copyWith(loading: false, status: status);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        status: DungeonSiegeStatus.empty(),
        errorMessage: 'Kuşatma durumu yuklenemedi.',
      );
    }
  }

  Future<DungeonSiegeActionResult?> claimSlot(String dungeonId) async {
    state = state.copyWith(actionLoading: true, clearError: true);
    try {
      final DungeonSiegeActionResult result = await _repository.claimSlot(dungeonId);
      await loadStatus(dungeonId: dungeonId);
      state = state.copyWith(actionLoading: false);
      return result;
    } catch (_) {
      state = state.copyWith(
        actionLoading: false,
        errorMessage: 'Slot alinamadi.',
      );
      return null;
    }
  }

  Future<DungeonSiegeActionResult?> challengeSlot({
    required String slotId,
    required String dungeonId,
  }) async {
    state = state.copyWith(actionLoading: true, clearError: true);
    try {
      final DungeonSiegeActionResult result = await _repository.challengeSlot(slotId);
      await loadStatus(dungeonId: dungeonId);
      state = state.copyWith(actionLoading: false);
      return result;
    } catch (_) {
      state = state.copyWith(
        actionLoading: false,
        errorMessage: 'Meydan okuma basarisiz.',
      );
      return null;
    }
  }

  Future<DungeonSiegeActionResult?> releaseSlot({
    required String slotId,
    required String dungeonId,
  }) async {
    state = state.copyWith(actionLoading: true, clearError: true);
    try {
      final DungeonSiegeActionResult result = await _repository.releaseSlot(slotId);
      await loadStatus(dungeonId: dungeonId);
      state = state.copyWith(actionLoading: false);
      return result;
    } catch (_) {
      state = state.copyWith(
        actionLoading: false,
        errorMessage: 'Slot birakilamadi.',
      );
      return null;
    }
  }
}

final NotifierProvider<DungeonSiegeNotifier, DungeonSiegeState> dungeonSiegeProvider =
    NotifierProvider<DungeonSiegeNotifier, DungeonSiegeState>(DungeonSiegeNotifier.new);
