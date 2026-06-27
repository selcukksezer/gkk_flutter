import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';
import '../models/guild_model.dart';
import 'player_provider.dart';

class GuildState {
  const GuildState({
    this.guild,
    required this.searchResults,
    required this.recommendedGuilds,
    required this.isLoading,
    required this.isSearching,
    required this.isLoadingRecommended,
    required this.isMutating,
    this.error,
  });

  final GuildData? guild;
  final List<GuildData> searchResults;
  final List<GuildData> recommendedGuilds;
  final bool isLoading;
  final bool isSearching;
  final bool isLoadingRecommended;
  final bool isMutating;
  final String? error;

  bool get hasValidGuild => guild != null && guild!.isValid;

  factory GuildState.initial() => const GuildState(
        searchResults: <GuildData>[],
        recommendedGuilds: <GuildData>[],
        isLoading: false,
        isSearching: false,
        isLoadingRecommended: false,
        isMutating: false,
      );

  GuildState copyWith({
    GuildData? guild,
    List<GuildData>? searchResults,
    List<GuildData>? recommendedGuilds,
    bool? isLoading,
    bool? isSearching,
    bool? isLoadingRecommended,
    bool? isMutating,
    String? error,
    bool clearError = false,
    bool clearGuild = false,
  }) {
    return GuildState(
      guild: clearGuild ? null : (guild ?? this.guild),
      searchResults: searchResults ?? this.searchResults,
      recommendedGuilds: recommendedGuilds ?? this.recommendedGuilds,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      isLoadingRecommended:
          isLoadingRecommended ?? this.isLoadingRecommended,
      isMutating: isMutating ?? this.isMutating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class GuildNotifier extends Notifier<GuildState> {
  @override
  GuildState build() => GuildState.initial();

  List<GuildData> _parseGuildListResponse(dynamic response) {
    final List<dynamic> raw = response is List
        ? response
        : response is Map && response['results'] is List
            ? response['results'] as List
            : <dynamic>[];

    return raw
        .whereType<Map<String, dynamic>>()
        .map(GuildData.fromJson)
        .where((g) => g.guildId.isNotEmpty)
        .toList();
  }

  Future<void> _syncPlayerProfile() async {
    await ref.read(playerProvider.notifier).loadProfile();
  }

  Future<void> loadGuild() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response =
          await SupabaseService.client.rpc('get_my_guild');

      if (response == null) {
        state = state.copyWith(isLoading: false, clearGuild: true);
        return;
      }

      final GuildRpcResult result = GuildRpcResult.fromResponse(response);
      if (!result.success || result.guild == null) {
        state = state.copyWith(
          isLoading: false,
          clearGuild: true,
          error: result.error,
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        guild: result.guild,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearGuild: true,
        error: 'Lonca bilgileri yuklenirken bir hata olustu: ${e.toString()}',
      );
    }
  }

  Future<void> loadRecommendedGuilds() async {
    state = state.copyWith(isLoadingRecommended: true, clearError: true);
    try {
      final response =
          await SupabaseService.client.rpc('get_recommended_guilds');

      state = state.copyWith(
        isLoadingRecommended: false,
        recommendedGuilds: _parseGuildListResponse(response),
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingRecommended: false,
        error:
            'Onerilen loncalar yuklenirken bir hata olustu: ${e.toString()}',
      );
    }
  }

  Future<void> searchGuilds(String query) async {
    state = state.copyWith(isSearching: true, clearError: true);
    try {
      final response = await SupabaseService.client
          .rpc('search_guilds', params: <String, dynamic>{
        'p_query': query,
      });

      state = state.copyWith(
        isSearching: false,
        searchResults: _parseGuildListResponse(response),
      );
    } catch (e) {
      state = state.copyWith(
        isSearching: false,
        error: 'Lonca araması sirasinda bir hata olustu: ${e.toString()}',
      );
    }
  }

  Future<bool> createGuild({
    required String name,
    required String description,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final response = await SupabaseService.client
          .rpc('create_guild', params: <String, dynamic>{
        'p_name': name,
        'p_description': description,
      });

      final GuildRpcResult result = GuildRpcResult.fromResponse(response);
      if (!result.success) {
        state = state.copyWith(
          isMutating: false,
          error: result.error ?? 'Lonca olusturulamadi.',
        );
        return false;
      }

      await loadGuild();
      await _syncPlayerProfile();
      state = state.copyWith(isMutating: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        error: 'Lonca olusturulurken bir hata olustu: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> joinGuild(String guildId) async {
    if (guildId.isEmpty) {
      state = state.copyWith(error: 'Gecersiz lonca kimligi.');
      return false;
    }

    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final response = await SupabaseService.client
          .rpc('join_guild', params: <String, dynamic>{
        'p_guild_id': guildId,
      });

      final GuildRpcResult result = GuildRpcResult.fromResponse(response);
      if (!result.success) {
        state = state.copyWith(
          isMutating: false,
          error: result.error ?? 'Loncaya katilma basarisiz.',
        );
        return false;
      }

      await loadGuild();
      await _syncPlayerProfile();
      state = state.copyWith(isMutating: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        error: 'Loncaya katilirken bir hata olustu: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> setMinJoinPower(int minPower) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final response = await SupabaseService.client.rpc(
        'set_guild_min_join_power',
        params: <String, dynamic>{'p_min_power': minPower},
      );

      final GuildRpcResult result = GuildRpcResult.fromResponse(response);
      if (!result.success) {
        state = state.copyWith(
          isMutating: false,
          error: result.error ?? 'Guc limiti guncellenemedi.',
        );
        return false;
      }

      await loadGuild();
      state = state.copyWith(isMutating: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        error: 'Guc limiti guncellenirken bir hata olustu: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> leaveGuild() async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final response = await SupabaseService.client.rpc('leave_guild');
      final GuildRpcResult result = GuildRpcResult.fromResponse(response);
      if (!result.success) {
        state = state.copyWith(
          isMutating: false,
          error: result.error ?? 'Loncadan ayrilma basarisiz.',
        );
        return false;
      }

      state = state.copyWith(isMutating: false, clearGuild: true);
      await _syncPlayerProfile();
      await loadRecommendedGuilds();
      return true;
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        error: 'Loncadan ayrilirken bir hata olustu: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> disbandGuild() async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final response = await SupabaseService.client.rpc('disband_guild');
      final GuildRpcResult result = GuildRpcResult.fromResponse(response);
      if (!result.success) {
        state = state.copyWith(
          isMutating: false,
          error: result.error ?? 'Lonca dagitilamadi.',
        );
        return false;
      }

      state = state.copyWith(isMutating: false, clearGuild: true);
      await _syncPlayerProfile();
      await loadRecommendedGuilds();
      return true;
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        error: 'Lonca dagitilirken bir hata olustu: ${e.toString()}',
      );
      return false;
    }
  }

  void clearSearchResults() {
    state = state.copyWith(searchResults: <GuildData>[]);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clear() {
    state = GuildState.initial();
  }
}

final NotifierProvider<GuildNotifier, GuildState> guildProvider =
    NotifierProvider<GuildNotifier, GuildState>(GuildNotifier.new);

/// Lonca üyeliği için tek kaynak: guildProvider + playerProfile fallback.
final Provider<bool> hasGuildMembershipProvider = Provider<bool>((ref) {
  final guildState = ref.watch(guildProvider);
  if (guildState.hasValidGuild) return true;
  final profile = ref.watch(playerProvider).profile;
  return profile?.guildId != null && profile!.guildId!.isNotEmpty;
});
