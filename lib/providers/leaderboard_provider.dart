import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';
import '../models/leaderboard_model.dart';
import 'player_provider.dart';

enum LeaderboardStatus {
  initial,
  loading,
  ready,
  error,
}

class LeaderboardState {
  const LeaderboardState({
    required this.status,
    required this.entries,
    required this.categoryIndex,
    required this.weekly,
    this.errorMessage,
    this.playerRank,
    this.playerValue,
  });

  final LeaderboardStatus status;
  final List<LeaderboardEntry> entries;
  final int categoryIndex;
  final bool weekly;
  final String? errorMessage;
  final int? playerRank;
  final int? playerValue;

  String get categoryKey => leaderboardCategories[categoryIndex].key;

  factory LeaderboardState.initial() => const LeaderboardState(
        status: LeaderboardStatus.initial,
        entries: <LeaderboardEntry>[],
        categoryIndex: 0,
        weekly: false,
      );

  LeaderboardState copyWith({
    LeaderboardStatus? status,
    List<LeaderboardEntry>? entries,
    int? categoryIndex,
    bool? weekly,
    String? errorMessage,
    int? playerRank,
    int? playerValue,
    bool clearError = false,
    bool clearPlayerRank = false,
  }) {
    return LeaderboardState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      categoryIndex: categoryIndex ?? this.categoryIndex,
      weekly: weekly ?? this.weekly,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      playerRank: clearPlayerRank ? null : (playerRank ?? this.playerRank),
      playerValue: clearPlayerRank ? null : (playerValue ?? this.playerValue),
    );
  }
}

class LeaderboardNotifier extends Notifier<LeaderboardState> {
  @override
  LeaderboardState build() => LeaderboardState.initial();

  Future<void> load({
    int? categoryIndex,
    bool? weekly,
  }) async {
    final int nextCategory = categoryIndex ?? state.categoryIndex;
    final bool nextWeekly = weekly ?? state.weekly;
    final String category = leaderboardCategories[nextCategory].key;

    state = state.copyWith(
      status: LeaderboardStatus.loading,
      categoryIndex: nextCategory,
      weekly: nextWeekly,
      clearError: true,
      clearPlayerRank: true,
    );

    try {
      final dynamic result = await SupabaseService.client.rpc(
        'get_leaderboard',
        params: <String, dynamic>{
          'p_category': category,
          'p_limit': 30,
          'p_timeframe': nextWeekly ? 'weekly' : 'alltime',
        },
      );

      if (result is! List) {
        state = state.copyWith(
          status: LeaderboardStatus.error,
          entries: <LeaderboardEntry>[],
          errorMessage: 'Sıralama yüklenemedi',
        );
        return;
      }

      final List<LeaderboardEntry> entries = result
          .whereType<Map>()
          .map(
            (Map row) => LeaderboardEntry.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .where((LeaderboardEntry e) => e.username.isNotEmpty)
          .toList();

      // Empty board = valid (no rows yet), not a hard failure.
      state = state.copyWith(
        status: LeaderboardStatus.ready,
        entries: entries,
      );
      if (entries.isNotEmpty) {
        await _resolvePlayerRank(entries, category, nextWeekly);
      }
    } catch (_) {
      state = state.copyWith(
        status: LeaderboardStatus.error,
        entries: <LeaderboardEntry>[],
        errorMessage: 'Sıralama yüklenemedi',
      );
    }
  }

  Future<void> selectCategory(int index) async {
    if (index == state.categoryIndex) return;
    await load(categoryIndex: index);
  }

  Future<void> setWeekly(bool weekly) async {
    if (weekly == state.weekly) return;
    await load(weekly: weekly);
  }

  Future<void> refresh() => load();

  Future<void> _resolvePlayerRank(
    List<LeaderboardEntry> entries,
    String category,
    bool weekly,
  ) async {
    final String? username = ref.read(playerProvider).profile?.username;
    if (username == null || username.isEmpty) {
      state = state.copyWith(clearPlayerRank: true);
      return;
    }

    final int idx = entries.indexWhere(
      (LeaderboardEntry e) =>
          e.username.toLowerCase() == username.toLowerCase(),
    );
    if (idx >= 0) {
      state = state.copyWith(
        playerRank: entries[idx].rank,
        playerValue: entries[idx].value,
      );
      return;
    }

    try {
      final dynamic rankResult = await SupabaseService.client.rpc(
        'get_leaderboard_rank',
        params: <String, dynamic>{
          'p_category': category,
          'p_timeframe': weekly ? 'weekly' : 'alltime',
        },
      );
      if (rankResult is Map<String, dynamic>) {
        state = state.copyWith(
          playerRank: (rankResult['rank'] as num?)?.toInt(),
          playerValue: (rankResult['value'] as num?)?.toInt(),
        );
        return;
      }
    } catch (_) {
      // fall through
    }

    state = state.copyWith(clearPlayerRank: true);
  }
}

final NotifierProvider<LeaderboardNotifier, LeaderboardState>
    leaderboardProvider =
    NotifierProvider<LeaderboardNotifier, LeaderboardState>(
  LeaderboardNotifier.new,
);
