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
    required this.isLoading,
    this.error,
  });

  final GuildWarSeason? season;
  final List<GuildWarTournament> tournaments;
  final List<TerritoryData> territories;
  final List<GuildWarRanking> rankings;
  final List<GuildWarAttackLog> attackLogs;
  final bool isLoading;
  final String? error;

  factory GuildWarState.initial() => const GuildWarState(isLoading: false);

  GuildWarState copyWith({
    GuildWarSeason? season,
    List<GuildWarTournament>? tournaments,
    List<TerritoryData>? territories,
    List<GuildWarRanking>? rankings,
    List<GuildWarAttackLog>? attackLogs,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return GuildWarState(
      season: season ?? this.season,
      tournaments: tournaments ?? this.tournaments,
      territories: territories ?? this.territories,
      rankings: rankings ?? this.rankings,
      attackLogs: attackLogs ?? this.attackLogs,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
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

  Future<void> loadAttackLogs({String? guildId}) async {
    try {
      final params = <String, dynamic>{'p_limit': 50};
      if (guildId != null) params['p_guild_id'] = guildId;

      final data = await SupabaseService.client.rpc(
        'get_guild_war_attack_logs',
        params: params,
      );
      state = state.copyWith(attackLogs: _parseAttackLogs(data));
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
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
    if (data is List) {
      return data
          .map((e) => GuildWarParticipant.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  Future<TerritoryDetail?> loadTerritoryDetail(String territoryId) async {
    final data = await SupabaseService.client.rpc(
      'get_territory_detail',
      params: {'p_territory_id': territoryId},
    );
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['error'] != null) return null;
      return TerritoryDetail.fromJson(map);
    }
    return null;
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

final guildWarProvider = NotifierProvider<GuildWarNotifier, GuildWarState>(
  GuildWarNotifier.new,
);
