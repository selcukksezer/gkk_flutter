import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/user_facing_error.dart';
import '../core/services/supabase_service.dart';
import '../models/guild_war_model.dart';
import 'guild_vault_provider.dart';

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
    final List<String> errors = <String>[];

    Future<T> safe<T>(String label, Future<dynamic> call, T Function(dynamic) parse, T fallback) async {
      try {
        return parse(await call);
      } catch (e) {
        errors.add(label);
        return fallback;
      }
    }

    final GuildWarSeason? season = await safe<GuildWarSeason?>(
      'season',
      SupabaseService.client.rpc('get_guild_war_season'),
      _parseSeason,
      state.season,
    );
    final List<GuildWarTournament> tournaments = await safe<List<GuildWarTournament>>(
      'tournaments',
      SupabaseService.client.rpc('get_guild_war_tournaments'),
      _parseTournaments,
      state.tournaments,
    );
    final List<TerritoryData> territories = await safe<List<TerritoryData>>(
      'territories',
      SupabaseService.client.rpc('get_guild_war_territories'),
      _parseTerritories,
      state.territories,
    );
    final List<GuildWarRanking> rankings = await safe<List<GuildWarRanking>>(
      'rankings',
      SupabaseService.client.rpc('get_guild_war_rankings'),
      _parseRankings,
      state.rankings,
    );
    final List<GuildWarAttackLog> attackLogs = await safe<List<GuildWarAttackLog>>(
      'logs',
      SupabaseService.client.rpc('get_guild_war_attack_logs', params: <String, dynamic>{'p_limit': 50}),
      _parseAttackLogs,
      state.attackLogs,
    );

    state = state.copyWith(
      isLoading: false,
      season: season,
      tournaments: tournaments,
      territories: territories,
      rankings: rankings,
      attackLogs: attackLogs,
      error: errors.isEmpty ? null : 'Bazı veriler yüklenemedi (${errors.join(', ')}). Aşağı çekerek yenile.',
    );
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

  Future<TerritoryAttackPreview?> loadAttackPreview(String territoryId) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'get_territory_attack_preview',
        params: <String, dynamic>{'p_territory_id': territoryId},
      );
      if (raw is Map<String, dynamic>) {
        return TerritoryAttackPreview.fromJson(raw);
      }
      if (raw is Map) {
        return TerritoryAttackPreview.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    } catch (e) {
      return TerritoryAttackPreview(
        territoryId: territoryId,
        territoryName: '',
        error: e.toString(),
      );
    }
  }

  Future<String?> addDefenseGold(String territoryId, int gold) async {
    return 'Altın ile savunma kaldırıldı. Elmas veya garnizon kullanın.';
  }

  Future<({String? error, String? message})> joinGarrison(String territoryId) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'guild_war_garrison_join',
        params: <String, dynamic>{'p_territory_id': territoryId},
      );
      if (raw is Map && raw['success'] == false) {
        return (
          error: raw['error']?.toString() ?? raw['message']?.toString() ?? 'Nöbet hatası',
          message: null,
        );
      }
      // Light refresh only — full loadAll floods concurrent RPCs → timeout risk.
      await loadTerritoryDetail(territoryId);
      try {
        final dynamic terrRaw =
            await SupabaseService.client.rpc('get_guild_war_territories');
        state = state.copyWith(territories: _parseTerritories(terrRaw));
      } catch (_) {}
      final String? msg = raw is Map ? raw['message']?.toString() : null;
      return (error: null, message: msg);
    } catch (e) {
      return (error: userFacingErrorMessage(e, fallback: 'Nöbete yazılamadı. Tekrar dene.'), message: null);
    }
  }

  Future<({String? error, String? message})> leaveGarrison() async {
    try {
      final dynamic raw = await SupabaseService.client.rpc('guild_war_garrison_leave');
      if (raw is Map && raw['success'] == false) {
        return (
          error: raw['error']?.toString() ?? raw['message']?.toString() ?? 'Nöbet hatası',
          message: null,
        );
      }
      final String? tid = state.activeTerritoryId;
      if (tid != null) await loadTerritoryDetail(tid);
      try {
        final dynamic terrRaw =
            await SupabaseService.client.rpc('get_guild_war_territories');
        state = state.copyWith(territories: _parseTerritories(terrRaw));
      } catch (_) {}
      final String? msg = raw is Map ? raw['message']?.toString() : null;
      return (error: null, message: msg);
    } catch (e) {
      return (error: userFacingErrorMessage(e, fallback: 'Nöbetten ayrılamadı. Tekrar dene.'), message: null);
    }
  }

  Future<({String? error, String? message})> openAttackPlan(String territoryId) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'guild_war_open_attack_plan',
        params: <String, dynamic>{'p_territory_id': territoryId},
      );
      if (raw is Map && raw['success'] == false) {
        return (
          error: raw['error']?.toString() ?? raw['message']?.toString() ?? 'Plan açılamadı',
          message: null,
        );
      }
      if (state.activeTerritoryId == territoryId) {
        await loadTerritoryDetail(territoryId);
      }
      final String? msg = raw is Map ? raw['message']?.toString() : null;
      return (error: null, message: msg);
    } catch (e) {
      return (error: userFacingErrorMessage(e, fallback: 'Plan açılamadı.'), message: null);
    }
  }

  Future<Map<String, dynamic>?> loadAttackPlan(String territoryId) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'get_territory_attack_plan',
        params: <String, dynamic>{'p_territory_id': territoryId},
      );
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Full garrison status payload (`get_territory_garrison`).
  Future<Map<String, dynamic>?> loadTerritoryGarrisonStatus(String territoryId) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'get_territory_garrison',
        params: <String, dynamic>{'p_territory_id': territoryId},
      );
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Members list only (compat). Prefer [loadTerritoryGarrisonStatus].
  Future<List<Map<String, dynamic>>> loadTerritoryGarrison(String territoryId) async {
    final Map<String, dynamic>? status = await loadTerritoryGarrisonStatus(territoryId);
    if (status == null) return <Map<String, dynamic>>[];
    final dynamic members = status['members'];
    if (members is List) {
      return members
          .whereType<Map>()
          .map((Map e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<String?> pledgeAttackSupport(String planId) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'guild_war_pledge_attack_support',
        params: <String, dynamic>{'p_plan_id': planId},
      );
      if (raw is Map && raw['success'] == false) {
        return raw['error']?.toString() ?? raw['message']?.toString();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<LiveGuildWarClash?> loadLiveClash({String? guildId}) async {
    try {
      final Map<String, dynamic> params = <String, dynamic>{};
      if (guildId != null) params['p_guild_id'] = guildId;
      final dynamic raw = await SupabaseService.client.rpc(
        'get_live_guild_war_clash',
        params: params.isEmpty ? null : params,
      );
      if (raw is Map) {
        return LiveGuildWarClash.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> rallyClash(int matchId) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'rally_guild_war_clash',
        params: <String, dynamic>{'p_match_id': matchId},
      );
      if (raw is Map && raw['success'] == false) {
        return raw['error']?.toString() ?? raw['message']?.toString();
      }
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
      if (result is Map) {
        final attackResult =
            GuildWarAttackResult.fromJson(Map<String, dynamic>.from(result));
        if (attackResult.error == null && attackResult.goldSpent > 0) {
          ref.read(guildVaultProvider.notifier).applyGoldDelta(-attackResult.goldSpent);
        }
        await loadAll();
        // Keep hub/vault UI in sync with spend.
        await ref.read(guildVaultProvider.notifier).load(silent: true);
        return attackResult;
      }
      return const GuildWarAttackResult(
        success: false,
        message: '',
        error: 'Sunucudan beklenmeyen yanıt geldi.',
      );
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
      if (result is Map && result['success'] == false) {
        return result['error']?.toString() ?? 'Savunma eklenemedi.';
      }
      await loadAll();
      return null;
    } catch (e) {
      return userFacingErrorMessage(e, fallback: 'Savunma eklenemedi.');
    }
  }

  Future<({String? error, String? message})> addAttackGems(String planId, int gems) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'add_attack_plan_gems',
        params: <String, dynamic>{
          'p_plan_id': planId,
          'p_gems': gems,
        },
      );
      if (raw is Map && raw['success'] == false) {
        return (
          error: raw['error']?.toString() ?? 'Elmas eklenemedi.',
          message: null,
        );
      }
      final String? tid = state.activeTerritoryId;
      if (tid != null) await loadTerritoryDetail(tid);
      return (
        error: null,
        message: raw is Map ? raw['message']?.toString() : null,
      );
    } catch (e) {
      return (
        error: userFacingErrorMessage(e, fallback: 'Elmas saldırı desteği eklenemedi.'),
        message: null,
      );
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
      String? rpcError;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (map['error'] == null) {
          detail = TerritoryDetail.fromJson(map);
        } else {
          rpcError = map['error'].toString();
        }
      }

      state = state.copyWith(
        territoryDetail: detail,
        isTerritoryDetailLoading: false,
        clearError: rpcError == null,
        error: rpcError,
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
  final dynamic decoded = data;
  if (decoded is Map) {
    return GuildWarSeason.fromJson(Map<String, dynamic>.from(decoded));
  }
  if (decoded is String && decoded.trim().isNotEmpty) {
    final dynamic parsed = jsonDecode(decoded);
    if (parsed is Map) {
      return GuildWarSeason.fromJson(Map<String, dynamic>.from(parsed));
    }
  }
  return null;
}

List<GuildWarTournament> _parseTournaments(dynamic data) {
  if (data is List) {
    return data
        .map((e) => GuildWarTournament.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  if (data is String && data.trim().isNotEmpty) {
    final dynamic parsed = jsonDecode(data);
    if (parsed is List) {
      return parsed
          .map((e) => GuildWarTournament.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
  }
  return <GuildWarTournament>[];
}

List<TerritoryData> _parseTerritories(dynamic data) {
  if (data is List) {
    return data
        .map((e) => TerritoryData.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  if (data is String && data.trim().isNotEmpty) {
    final dynamic parsed = jsonDecode(data);
    if (parsed is List) {
      return parsed
          .map((e) => TerritoryData.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
  }
  return <TerritoryData>[];
}

List<GuildWarRanking> _parseRankings(dynamic data) {
  final dynamic decoded = _unwrapRpcJson(data);
  if (decoded is List) {
    return decoded
        .map((dynamic e) => GuildWarRanking.fromJson(_asStringKeyedMap(e)))
        .toList();
  }
  return <GuildWarRanking>[];
}

List<GuildWarAttackLog> _parseAttackLogs(dynamic data) {
  if (data is List) {
    return data
        .map((e) => GuildWarAttackLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  if (data is String && data.trim().isNotEmpty) {
    final dynamic parsed = jsonDecode(data);
    if (parsed is List) {
      return parsed
          .map((e) => GuildWarAttackLog.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
  }
  return <GuildWarAttackLog>[];
}

List<GuildWarParticipant> _parseParticipants(dynamic data) {
  if (data is List) {
    return data
        .map((e) => GuildWarParticipant.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  if (data is String && data.trim().isNotEmpty) {
    final dynamic parsed = jsonDecode(data);
    if (parsed is List) {
      return parsed
          .map((e) => GuildWarParticipant.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
  }
  return <GuildWarParticipant>[];
}

List<GuildWarTournamentRound> _parseTournamentRounds(dynamic data) {
  if (data is List) {
    return data
        .map((e) => GuildWarTournamentRound.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  if (data is String && data.trim().isNotEmpty) {
    final dynamic parsed = jsonDecode(data);
    if (parsed is List) {
      return parsed
          .map((e) => GuildWarTournamentRound.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
  }
  return <GuildWarTournamentRound>[];
}

dynamic _unwrapRpcJson(dynamic data) {
  if (data is String && data.trim().isNotEmpty) {
    try {
      return jsonDecode(data);
    } catch (_) {
      return data;
    }
  }
  return data;
}

Map<String, dynamic> _asStringKeyedMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected map, got ${value.runtimeType}');
}

final guildWarProvider = NotifierProvider<GuildWarNotifier, GuildWarState>(
  GuildWarNotifier.new,
);
