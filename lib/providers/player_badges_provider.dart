import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';
import '../models/player_badge_model.dart';
import '../repositories/player_badge_repository.dart';
import 'auth_provider.dart';

class PlayerBadgesState {
  const PlayerBadgesState({
    this.isLoading = false,
    this.badges = const <PlayerBadge>[],
    this.error,
  });

  final bool isLoading;
  final List<PlayerBadge> badges;
  final String? error;

  PlayerBadgesState copyWith({
    bool? isLoading,
    List<PlayerBadge>? badges,
    String? error,
    bool clearError = false,
  }) {
    return PlayerBadgesState(
      isLoading: isLoading ?? this.isLoading,
      badges: badges ?? this.badges,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final playerBadgeRepositoryProvider = Provider<PlayerBadgeRepository>(
  (Ref ref) => PlayerBadgeRepository(),
);

class PlayerBadgesNotifier extends Notifier<PlayerBadgesState> {
  @override
  PlayerBadgesState build() {
    ref.listen<AuthState>(authProvider, (_, __) {
      Future<void>.microtask(load);
    });
    Future<void>.microtask(load);
    return const PlayerBadgesState();
  }

  Future<void> load() async {
    if (!SupabaseService.isInitialized) return;
    if (SupabaseService.client.auth.currentSession == null) {
      state = const PlayerBadgesState();
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<PlayerBadge> badges =
          await ref.read(playerBadgeRepositoryProvider).fetchBadges();
      state = state.copyWith(isLoading: false, badges: badges, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final playerBadgesProvider =
    NotifierProvider<PlayerBadgesNotifier, PlayerBadgesState>(
  PlayerBadgesNotifier.new,
);
