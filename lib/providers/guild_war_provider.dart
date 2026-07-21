import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';
import '../models/guild_war_model.dart';

class GuildWarState {
  const GuildWarState({
    this.season,
    this.tournaments = const [],
    this.territories = const [],
    this.rankings = const [],
    this.attackLogs = const [],
    this.attackLogFilter = GuildWarAttackLogFilter.all,
    this.activeTerritoryId,
    this.territoryDetail,
    this.isTerritoryDetailLoading = false,
    this.activeTournamentId,
    this.tournamentDetail,
    this.tournamentParticipants = const [],
    this.tournamentRounds = const [],
    this.isTournamentDetailLoading = false,
    required this.isLoading,
    this.error,
  });

  final GuildWarSeason? season;
  final List<GuildWarTournament> tournaments;
  final List<TerritoryData> territories;
  final List<GuildWarRanking> rankings;
  final List<GuildWarAttackLog> attackLogs;
  final GuildWarAttackLogFilter attackLogFilter;
  final String? activeTerritoryId;
  final TerritoryDetail? territoryDetail;
  final bool isTerritoryDetailLoading;
  final String? activeTournamentId;
  final GuildWarTournament? tournamentDetail;
  final List<GuildWarParticipant> tournamentParticipants;
  final List<GuildWarTournamentRound> tournamentRounds;
  final bool isTournamentDetailLoading;
  final bool isLoading;
  final String? error;

  factory GuildWarState.initial() => const GuildWarState(isLoading: false);

  GuildWarState copyWith({
    GuildWarSeason? season,
    List<GuildWarTournament>? tournaments,
    List<TerritoryData>? territories,
    List<GuildWarRanking>? rankings,
    List<GuildWarAttackLog>? attackLogs,
    GuildWarAttackLogFilter? attackLogFilter,
    String? activeTerritoryId,
    TerritoryDetail? territoryDetail,
    bool? isTerritoryDetailLoading,
    String? activeTournamentId,
    GuildWarTournament? tournamentDetail,
    List<GuildWarParticipant>? tournamentParticipants,
    List<GuildWarTournamentRound>? tournamentRounds,
    bool? isTournamentDetailLoading,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearTerritoryDetail = false,
    bool clearTournamentDetail = false,
  }) {
    return GuildWarState(
      season: season ?? this.season,
      tournaments: tournaments ?? this.tournaments,
      territories: territories ?? this.territories,
      rankings: rankings ?? this.rankings,
      attackLogs: attackLogs ?? this.attackLogs,
      attackLogFilter: attackLogFilter ?? this.attackLogFilter,
      activeTerritoryId: clearTerritoryDetail ? null : (activeTerritoryId ?? this.activeTerritoryId),
      territoryDetail: clearTerritoryDetail ? null : (territoryDetail ?? this.territoryDetail),
      isTerritoryDetailLoading: isTerritoryDetailLoading ?? this.isTerritoryDetailLoading,
      activeTournamentId:
          clearTournamentDetail ? null : (activeTournamentId ?? this.activeTournamentId),
      tournamentDetail:
          clearTournamentDetail ? null : (tournamentDetail ?? this.tournamentDetail),
      tournamentParticipants:
          clearTournamentDetail ? const [] : (tournamentParticipants ?? this.tournamentParticipants),
      tournamentRounds:
          clearTournamentDetail ? const [] : (tournamentRounds ?? this.tournamentRounds),
      isTournamentDetailLoading:
          isTournamentDetailLoading ?? this.isTournamentDetailLoading,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<GuildWarAttackLog> filteredAttackLogs(String? guildId) {
    return filterAttackLogs(
      logs: attackLogs,
      filter: attackLogFilter,
      guildId: guildId,
    );
  }
}

class GuildWarNotifier extends Notifier<GuildWarState> {
  @override
  GuildWarState build() => GuildWarState.initial();

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait<dynamic>([
        SupabaseService.client.rpc('get_guild_war_season'),
        SupabaseService.client.rpc('get_guild_war_tournaments'),
        SupabaseService.client.rpc('get_guild_war_territories'),
        SupabaseService.client.rpc('get_guild_war_rankings'),
        SupabaseService.client.rpc('get_guild_war_attack_logs', params: {'p_limit': 50}),
      ]);

      state = state.copyWith(
        isLoading: false,
        season: _parseSeason(results[0]),
        tournaments: _parseTournaments(results[1]),
        territories: _parseTerritories(results[2]),
        rankings: _parseRankings(results[3]),
        attackLogs: _parseAttackLogs(results[4]),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadAttackLogs({String? guildId, bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final Map<String, dynamic> params = <String, dynamic>{'p_limit': 50};
      if (guildId != null) params['p_guild_id'] = guildId;

      final dynamic data = await SupabaseService.client.rpc(
        'get_guild_war_attack_logs',
        params: params,
      );
      state = state.copyWith(
        isLoading: false,
        attackLogs: _parseAttackLogs(data),
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setAttackLogFilter(GuildWarAttackLogFilter filter) {
    if (state.attackLogFilter == filter) return;
    state = state.copyWith(attackLogFilter: filter);
  }

  Future<String?> joinTournament(String tournamentId) async {
    try {
      final result = await SupabaseService.client.rpc(
        'join_guild_war',
        params: {'p_tournament_id': tournamentId},
      );
      if (result is Map && result['error'] != null) {
        return result['error'] as String;
      }
      await loadAll();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<GuildWarAttackResult?> attackTerritory(String territoryId) async {
    try {
      final result = await SupabaseService.client.rpc(
        'attack_guild_war_territory',
        params: {'p_territory_id': territoryId},
      );
      if (result is Map<String, dynamic>) {
        final attackResult = GuildWarAttackResult.fromJson(result);
        await loadAll();
        return attackResult;
      }
      return null;
    } catch (e) {
      return GuildWarAttackResult(
        success: false,
        message: '',
        error: e.toString(),
      );
    }
  }

  Future<String?> addDefense(String territoryId, int gems) async {
    try {
      final result = await SupabaseService.client.rpc(
        'add_territory_defense',
        params: {
          'p_territory_id': territoryId,
          'p_gems': gems,
        },
      );
      if (result is Map && result['error'] != null) {
        return result['error'] as String;
      }
      await loadAll();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<GuildWarParticipant>> loadParticipants(String tournamentId) async {
    final data = await SupabaseService.client.rpc(
      'get_tournament_participants',
      params: {'p_tournament_id': tournamentId},
    );
    return _parseParticipants(data);
  }

  Future<List<GuildWarTournamentRound>> loadTournamentMatches(String tournamentId) async {
    final data = await SupabaseService.client.rpc(
      'get_guild_war_tournament_matches',
      params: {'p_tournament_id': tournamentId},
    );
    return _parseTournamentRounds(data);
  }

  Future<void> loadTournamentDetail(String tournamentId) async {
    state = state.copyWith(
      activeTournamentId: tournamentId,
      isTournamentDetailLoading: true,
      clearError: true,
    );
    try {
      if (state.tournaments.isEmpty) {
        final dynamic tournamentList = await SupabaseService.client.rpc('get_guild_war_tournaments');
        state = state.copyWith(tournaments: _parseTournaments(tournamentList));
      }
      if (state.activeTournamentId != tournamentId) return;

      GuildWarTournament? tournament = _findTournament(state.tournaments, tournamentId);
      tournament ??= await _fetchTournamentById(tournamentId);
      final List<GuildWarParticipant> participants = await loadParticipants(tournamentId);
      final List<GuildWarTournamentRound> rounds = await loadTournamentMatches(tournamentId);

      if (state.activeTournamentId != tournamentId) return;

      state = state.copyWith(
        tournamentDetail: tournament,
        tournamentParticipants: participants,
        tournamentRounds: rounds,
        isTournamentDetailLoading: false,
        clearError: true,
      );
    } catch (e) {
      if (state.activeTournamentId != tournamentId) return;
      state = state.copyWith(
        isTournamentDetailLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearTournamentDetail() {
    state = state.copyWith(clearTournamentDetail: true, isTournamentDetailLoading: false);
  }

  Future<GuildWarTournament?> _fetchTournamentById(String tournamentId) async {
    final dynamic data = await SupabaseService.client.rpc(
      'get_guild_war_tournament',
      params: {'p_tournament_id': tournamentId},
    );
    if (data is Map) {
      return GuildWarTournament.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  GuildWarTournament? _findTournament(List<GuildWarTournament> tournaments, String id) {
    for (final GuildWarTournament tournament in tournaments) {
      if (tournament.id == id) return tournament;
    }
    return null;
  }

  Future<void> loadTerritoryDetail(String territoryId) async {
    state = state.copyWith(
      activeTerritoryId: territoryId,
      isTerritoryDetailLoading: true,
      clearError: true,
    );
    try {
      final data = await SupabaseService.client.rpc(
        'get_territory_detail',
        params: {'p_territory_id': territoryId},
      );
      if (state.activeTerritoryId != territoryId) return;

      TerritoryDetail? detail;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (map['error'] == null) {
          detail = TerritoryDetail.fromJson(map);
        }
      }

      state = state.copyWith(
        territoryDetail: detail,
        isTerritoryDetailLoading: false,
        clearError: true,
      );
    } catch (e) {
      if (state.activeTerritoryId != territoryId) return;
      state = state.copyWith(
        isTerritoryDetailLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearTerritoryDetail() {
    state = state.copyWith(clearTerritoryDetail: true, isTerritoryDetailLoading: false);
  }
}

GuildWarSeason? _parseSeason(dynamic data) {
  if (data is Map) {
    return GuildWarSeason.fromJson(Map<String, dynamic>.from(data));
  }
  return null;
}

List<GuildWarTournament> _parseTournaments(dynamic data) {
  if (data is List) {
    return data
        .map((e) => GuildWarTournament.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  return [];
}

List<TerritoryData> _parseTerritories(dynamic data) {
  if (data is List) {
    return data
        .map((e) => TerritoryData.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  return [];
}

List<GuildWarRanking> _parseRankings(dynamic data) {
  if (data is List) {
    return data
        .map((e) => GuildWarRanking.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  return [];
}

List<GuildWarAttackLog> _parseAttackLogs(dynamic data) {
  if (data is List) {
    return data
        .map((e) => GuildWarAttackLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  return [];
}

List<GuildWarParticipant> _parseParticipants(dynamic data) {
  if (data is List) {
    return data
        .map((e) => GuildWarParticipant.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  return [];
}

List<GuildWarTournamentRound> _parseTournamentRounds(dynamic data) {
  if (data is List) {
    return data
        .map((e) => GuildWarTournamentRound.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  return [];
}

final guildWarProvider = NotifierProvider<GuildWarNotifier, GuildWarState>(
  GuildWarNotifier.new,
);
