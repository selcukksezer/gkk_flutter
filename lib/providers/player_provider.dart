import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/services/connectivity_service.dart';
import '../models/player_model.dart';
import '../repositories/player_repository.dart';

enum PlayerStatus {
  initial,
  loading,
  ready,
  error,
}

class PlayerState {
  const PlayerState({
    required this.status,
    this.profile,
    this.errorMessage,
  });

  final PlayerStatus status;
  final PlayerProfile? profile;
  final String? errorMessage;

  factory PlayerState.initial() => const PlayerState(status: PlayerStatus.initial);

  PlayerState copyWith({
    PlayerStatus? status,
    PlayerProfile? profile,
    String? errorMessage,
    bool clearProfile = false,
    bool clearError = false,
  }) {
    return PlayerState(
      status: status ?? this.status,
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final Provider<PlayerRepository> playerRepositoryProvider = Provider<PlayerRepository>((Ref ref) {
  return SupabasePlayerRepository();
});

class PlayerNotifier extends Notifier<PlayerState> {
  PlayerRepository get _repository => ref.read(playerRepositoryProvider);

  Future<void>? _inFlightLoad;
  bool _reloadQueued = false;

  @override
  PlayerState build() => PlayerState.initial();

  Future<void> loadProfile() async {
    if (_inFlightLoad != null) {
      _reloadQueued = true;
      await _inFlightLoad;
      if (_reloadQueued) {
        _reloadQueued = false;
        return loadProfile();
      }
      return;
    }

    _inFlightLoad = _performLoad();
    try {
      await _inFlightLoad;
    } finally {
      _inFlightLoad = null;
      if (_reloadQueued) {
        _reloadQueued = false;
        await loadProfile();
      }
    }
  }

  Future<void> _performLoad() async {
    state = state.copyWith(status: PlayerStatus.loading, clearError: true);
    try {
      final PlayerProfile profile =
          await ConnectivityService.instance.trackRequest(
        () => _repository.loadCurrentPlayer(),
      );
      state = state.copyWith(status: PlayerStatus.ready, profile: profile);
    } on AppException catch (e) {
      state = state.copyWith(status: PlayerStatus.error, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        status: PlayerStatus.error,
        errorMessage: 'Profil yüklenirken beklenmeyen bir hata oluştu.',
      );
    }
  }

  void clear() {
    state = state.copyWith(status: PlayerStatus.initial, clearProfile: true, clearError: true);
  }
}

final NotifierProvider<PlayerNotifier, PlayerState> playerProvider =
    NotifierProvider<PlayerNotifier, PlayerState>(PlayerNotifier.new);
