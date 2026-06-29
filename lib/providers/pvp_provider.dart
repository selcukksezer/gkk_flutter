import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/user_facing_error.dart';
import '../core/services/supabase_service.dart';

class PvpArena {
  const PvpArena({required this.id, required this.name, required this.mekanType});

  final String id;
  final String name;
  final String mekanType;

  factory PvpArena.fromJson(Map<String, dynamic> json) => PvpArena(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        mekanType: (json['mekan_type'] ?? '').toString(),
      );
}

class PvpRecentMatch {
  const PvpRecentMatch({
    required this.id,
    required this.attackerId,
    required this.defenderId,
    required this.winnerId,
    required this.goldStolen,
    required this.repChangeWinner,
    required this.repChangeLoser,
    required this.isCritical,
    required this.attackerHpRemaining,
    required this.createdAt,
    this.attackerUsername,
    this.defenderUsername,
    this.matchSource = 'pvp',
  });

  final String id;
  final String attackerId;
  final String defenderId;
  final String winnerId;
  final int goldStolen;
  final int repChangeWinner;
  final int repChangeLoser;
  final bool isCritical;
  final int attackerHpRemaining;
  final String createdAt;
  final String? attackerUsername;
  final String? defenderUsername;
  final String matchSource;

  factory PvpRecentMatch.fromJson(Map<String, dynamic> json) => PvpRecentMatch(
        id: (json['id'] ?? '').toString(),
        attackerId: (json['attacker_id'] ?? '').toString(),
        defenderId: (json['defender_id'] ?? '').toString(),
        winnerId: (json['winner_id'] ?? '').toString(),
        goldStolen: _asInt(json['gold_stolen']),
        repChangeWinner: _asInt(json['rep_change_winner']),
        repChangeLoser: _asInt(json['rep_change_loser']),
        isCritical: json['is_critical_success'] == true,
        attackerHpRemaining: _asInt(json['attacker_hp_remaining']),
        createdAt: (json['created_at'] ?? '').toString(),
        attackerUsername: json['attacker_username']?.toString(),
        defenderUsername: json['defender_username']?.toString(),
        matchSource: (json['match_source'] ?? 'pvp').toString(),
      );

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class PvpTournamentMatch {
  const PvpTournamentMatch({
    required this.id,
    required this.p1,
    required this.p2,
    required this.s1,
    required this.s2,
    required this.winner,
    required this.status,
  });

  final int id;
  final String p1;
  final String p2;
  final int s1;
  final int s2;
  final String winner;
  final String status;

  factory PvpTournamentMatch.fromJson(Map<String, dynamic> json) => PvpTournamentMatch(
        id: _asInt(json['id']),
        p1: json['player1_name'] as String? ?? '?',
        p2: json['player2_name'] as String? ?? '?',
        s1: _asInt(json['player1_score']),
        s2: _asInt(json['player2_score']),
        winner: json['winner_name'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
      );

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class PvpTournamentRound {
  const PvpTournamentRound({required this.title, required this.matches});

  final String title;
  final List<PvpTournamentMatch> matches;

  factory PvpTournamentRound.fromJson(Map<String, dynamic> json) {
    final matchList = (json['matches'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => PvpTournamentMatch.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return PvpTournamentRound(
      title: json['title'] as String? ?? '',
      matches: matchList,
    );
  }
}

class PvpTournamentData {
  const PvpTournamentData({
    required this.title,
    required this.championName,
    required this.registrationOpen,
    required this.participantCount,
    required this.prizePool,
    required this.rounds,
    required this.status,
  });

  final String title;
  final String championName;
  final bool registrationOpen;
  final int participantCount;
  final int prizePool;
  final List<PvpTournamentRound> rounds;
  final String status;

  factory PvpTournamentData.empty() => const PvpTournamentData(
        title: 'Haftalık PvP Turnuvası',
        championName: '',
        registrationOpen: false,
        participantCount: 0,
        prizePool: 10000,
        rounds: [],
        status: 'registration',
      );
}

class PvpDashboardState {
  const PvpDashboardState({
    this.arenas = const [],
    this.recentMatches = const [],
    required this.isLoading,
    this.error,
  });

  final List<PvpArena> arenas;
  final List<PvpRecentMatch> recentMatches;
  final bool isLoading;
  final String? error;

  factory PvpDashboardState.initial() => const PvpDashboardState(isLoading: false);

  PvpDashboardState copyWith({
    List<PvpArena>? arenas,
    List<PvpRecentMatch>? recentMatches,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PvpDashboardState(
      arenas: arenas ?? this.arenas,
      recentMatches: recentMatches ?? this.recentMatches,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PvpHistoryState {
  const PvpHistoryState({
    this.matches = const [],
    required this.isLoading,
    this.error,
  });

  final List<PvpRecentMatch> matches;
  final bool isLoading;
  final String? error;

  factory PvpHistoryState.initial() => const PvpHistoryState(isLoading: false);

  PvpHistoryState copyWith({
    List<PvpRecentMatch>? matches,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PvpHistoryState(
      matches: matches ?? this.matches,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PvpTournamentState {
  const PvpTournamentState({
    required this.data,
    required this.isLoading,
    required this.isJoining,
    this.error,
  });

  final PvpTournamentData data;
  final bool isLoading;
  final bool isJoining;
  final String? error;

  factory PvpTournamentState.initial() => PvpTournamentState(
        data: PvpTournamentData.empty(),
        isLoading: false,
        isJoining: false,
      );

  PvpTournamentState copyWith({
    PvpTournamentData? data,
    bool? isLoading,
    bool? isJoining,
    String? error,
    bool clearError = false,
  }) {
    return PvpTournamentState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isJoining: isJoining ?? this.isJoining,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PvpDashboardNotifier extends Notifier<PvpDashboardState> {
  @override
  PvpDashboardState build() => PvpDashboardState.initial();

  Future<void> load({int matchLimit = 8}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'get_pvp_dashboard',
        params: <String, dynamic>{'p_match_limit': matchLimit},
      );
      final Map<String, dynamic> data = _asMap(res);
      final arenas = (data['arenas'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => PvpArena.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final matches = (data['recent_matches'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => PvpRecentMatch.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      state = state.copyWith(isLoading: false, arenas: arenas, recentMatches: matches);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: userFacingErrorMessage(e, fallback: 'PvP verisi yüklenemedi.'),
      );
    }
  }
}

class PvpHistoryNotifier extends Notifier<PvpHistoryState> {
  @override
  PvpHistoryState build() => PvpHistoryState.initial();

  Future<void> load({int limit = 50}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'get_pvp_history',
        params: <String, dynamic>{'p_limit': limit},
      );
      final Map<String, dynamic> data = _asMap(res);
      if (data['success'] == false) {
        state = state.copyWith(
          isLoading: false,
          error: userFacingErrorMessage(
            data['error'] ?? 'Geçmiş yüklenemedi.',
            fallback: 'Geçmiş yüklenemedi.',
          ),
        );
        return;
      }
      final matches = (data['matches'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => PvpRecentMatch.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      state = state.copyWith(isLoading: false, matches: matches);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: userFacingErrorMessage(e, fallback: 'Geçmiş yüklenemedi.'),
      );
    }
  }
}

class PvpTournamentNotifier extends Notifier<PvpTournamentState> {
  @override
  PvpTournamentState build() => PvpTournamentState.initial();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dynamic res = await SupabaseService.client.rpc('get_tournament_bracket');
      final Map<String, dynamic> data = _asMap(res);
      final rounds = (data['rounds'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => PvpTournamentRound.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      state = state.copyWith(
        isLoading: false,
        data: PvpTournamentData(
          title: data['tournament_name'] as String? ?? 'Haftalık PvP Turnuvası',
          championName: data['champion_name'] as String? ?? '',
          registrationOpen: data['registration_open'] as bool? ?? false,
          participantCount: _asInt(data['participant_count']),
          prizePool: _asInt(data['prize_pool'], fallback: 10000),
          rounds: rounds,
          status: data['status'] as String? ?? 'registration',
        ),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: userFacingErrorMessage(e, fallback: 'Turnuva yüklenemedi.'),
      );
    }
  }

  Future<String?> join() async {
    state = state.copyWith(isJoining: true, clearError: true);
    try {
      final dynamic res = await SupabaseService.client.rpc('join_pvp_tournament');
      final Map<String, dynamic> data = _asMap(res);
      if (data['success'] != true) {
        final String message = userFacingErrorMessage(
          data['error'] ?? 'Katılım başarısız.',
          fallback: 'Katılım başarısız.',
        );
        state = state.copyWith(isJoining: false, error: message);
        return message;
      }
      await load();
      state = state.copyWith(isJoining: false);
      return null;
    } catch (e) {
      final String message = userFacingErrorMessage(e, fallback: 'Katılım başarısız.');
      state = state.copyWith(isJoining: false, error: message);
      return message;
    }
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

final NotifierProvider<PvpDashboardNotifier, PvpDashboardState> pvpDashboardProvider =
    NotifierProvider<PvpDashboardNotifier, PvpDashboardState>(PvpDashboardNotifier.new);

final NotifierProvider<PvpHistoryNotifier, PvpHistoryState> pvpHistoryProvider =
    NotifierProvider<PvpHistoryNotifier, PvpHistoryState>(PvpHistoryNotifier.new);

final NotifierProvider<PvpTournamentNotifier, PvpTournamentState> pvpTournamentProvider =
    NotifierProvider<PvpTournamentNotifier, PvpTournamentState>(PvpTournamentNotifier.new);
