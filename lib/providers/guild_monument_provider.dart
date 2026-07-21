import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/user_facing_error.dart';
import '../models/guild_model.dart';
import '../repositories/guild_monument_repository.dart';
import 'guild_provider.dart';
import 'inventory_provider.dart';
import 'player_provider.dart';

class GuildMonumentState {
  const GuildMonumentState({
    this.dashboard,
    required this.isLoading,
    required this.loadFailed,
    this.loadError,
    required this.isUpgrading,
    this.donatingKind,
    this.errorMessage,
  });

  final MonumentDashboard? dashboard;
  final bool isLoading;
  final bool loadFailed;
  final String? loadError;
  final bool isUpgrading;
  final MonumentResourceKind? donatingKind;
  final String? errorMessage;

  factory GuildMonumentState.initial() => const GuildMonumentState(
        isLoading: false,
        loadFailed: false,
        isUpgrading: false,
      );

  GuildMonumentState copyWith({
    MonumentDashboard? dashboard,
    bool? isLoading,
    bool? loadFailed,
    String? loadError,
    bool? isUpgrading,
    MonumentResourceKind? donatingKind,
    String? errorMessage,
    bool clearDashboard = false,
    bool clearError = false,
    bool clearDonatingKind = false,
    bool clearLoadError = false,
  }) {
    return GuildMonumentState(
      dashboard: clearDashboard ? null : (dashboard ?? this.dashboard),
      isLoading: isLoading ?? this.isLoading,
      loadFailed: loadFailed ?? this.loadFailed,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      isUpgrading: isUpgrading ?? this.isUpgrading,
      donatingKind: clearDonatingKind ? null : (donatingKind ?? this.donatingKind),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class GuildMonumentNotifier extends Notifier<GuildMonumentState> {
  GuildMonumentRepository get _repository => ref.read(guildMonumentRepositoryProvider);

  @override
  GuildMonumentState build() => GuildMonumentState.initial();

  String? _resolveGuildId() {
    final String? profileGuildId = ref.read(playerProvider).profile?.guildId;
    if (profileGuildId != null && profileGuildId.isNotEmpty) {
      return profileGuildId;
    }
    return ref.read(guildProvider).guild?.guildId;
  }

  Future<void> bootstrap() async {
    if (ref.read(playerProvider).profile == null) {
      await ref.read(playerProvider.notifier).loadProfile();
    }
    await ref.read(guildProvider.notifier).loadGuild();
    await loadDashboard();
  }

  Future<void> loadDashboard() async {
    final String? guildId = _resolveGuildId();
    if (guildId == null || guildId.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        loadFailed: false,
        clearDashboard: true,
        clearLoadError: true,
      );
      return;
    }

    state = state.copyWith(isLoading: true, loadFailed: false, clearLoadError: true, clearError: true);
    try {
      final MonumentDashboard dashboard = await _repository.fetchDashboard(guildId);
      state = state.copyWith(
        dashboard: dashboard,
        isLoading: false,
        loadFailed: false,
        clearLoadError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        loadFailed: true,
        loadError: userFacingErrorMessage(e, fallback: 'Anıt verileri yüklenemedi.'),
        clearDashboard: true,
      );
    }
  }

  Future<MonumentDonateResult?> quickDonate(MonumentResourceKind kind) async {
    final MonumentDashboard? dashboard = state.dashboard;
    if (dashboard == null) {
      state = state.copyWith(errorMessage: 'Anıt verisi yok');
      return null;
    }

    final int amount = dashboard.myStats.maxDonatable(kind);
    if (amount <= 0) {
      state = state.copyWith(
        errorMessage: 'Bağışlanacak ${kind.shortLabel.toLowerCase()} kaynağın yok',
      );
      return null;
    }

    state = state.copyWith(donatingKind: kind, clearError: true);
    try {
      final MonumentDonateResult result = await monumentDonateKind(
        repository: _repository,
        kind: kind,
        amount: amount,
        stats: dashboard.myStats,
      );
      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      await ref.read(playerProvider.notifier).loadProfile();
      await loadDashboard();
      return result;
    } catch (e) {
      state = state.copyWith(
        errorMessage: userFacingErrorMessage(e, fallback: 'Bağış tamamlanamadı.'),
      );
      return null;
    } finally {
      state = state.copyWith(clearDonatingKind: true);
    }
  }

  Future<MonumentDonateResult?> donateKind({
    required MonumentResourceKind kind,
    required int amount,
  }) async {
    final MonumentDashboard? dashboard = state.dashboard;
    if (dashboard == null) {
      state = state.copyWith(errorMessage: 'Anıt verisi yok');
      return null;
    }

    final int capped = monumentDonateCap(
      owned: dashboard.myStats.owned(kind),
      donatedToday: dashboard.myStats.donatedToday(kind),
      dailyMax: dashboard.myStats.dailyMax(kind),
      requested: amount,
    );
    if (capped <= 0) {
      state = state.copyWith(errorMessage: '${kind.shortLabel} için bağışlanacak miktar yok');
      return null;
    }

    state = state.copyWith(donatingKind: kind, clearError: true);
    try {
      final MonumentDonateResult result = await monumentDonateKind(
        repository: _repository,
        kind: kind,
        amount: capped,
        stats: dashboard.myStats,
      );
      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      await ref.read(playerProvider.notifier).loadProfile();
      await loadDashboard();
      return result;
    } catch (e) {
      state = state.copyWith(
        errorMessage: userFacingErrorMessage(e, fallback: 'Bağış tamamlanamadı.'),
      );
      return null;
    } finally {
      state = state.copyWith(clearDonatingKind: true);
    }
  }

  Future<int?> upgradeMonument() async {
    final profile = ref.read(playerProvider).profile;
    if (!canUpgradeMonument(profile?.guildRole)) {
      state = state.copyWith(errorMessage: 'Yetkiniz yok!');
      return null;
    }

    final String? userId = profile?.authId;
    if (userId == null || userId.isEmpty) {
      state = state.copyWith(errorMessage: 'Oturum bulunamadı');
      return null;
    }

    state = state.copyWith(isUpgrading: true, clearError: true);
    try {
      final int newLevel = await _repository.upgradeMonument(userId: userId);
      await ref.read(guildProvider.notifier).loadGuild();
      await loadDashboard();
      return newLevel;
    } catch (e) {
      state = state.copyWith(
        errorMessage: userFacingErrorMessage(e, fallback: 'Yükseltme başarısız.'),
      );
      return null;
    } finally {
      state = state.copyWith(isUpgrading: false);
    }
  }
}

final NotifierProvider<GuildMonumentNotifier, GuildMonumentState> guildMonumentProvider =
    NotifierProvider<GuildMonumentNotifier, GuildMonumentState>(GuildMonumentNotifier.new);
