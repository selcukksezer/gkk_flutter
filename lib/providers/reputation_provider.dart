import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/user_facing_error.dart';
import '../models/reputation_model.dart';
import '../repositories/reputation_repository.dart';

final Provider<ReputationRepository> reputationRepositoryProvider =
    Provider<ReputationRepository>((Ref ref) => SupabaseReputationRepository());

class ReputationState {
  const ReputationState({
    required this.loading,
    required this.overview,
    this.error,
    this.purchasingId,
  });

  final bool loading;
  final ReputationOverview overview;
  final String? error;
  final String? purchasingId;

  factory ReputationState.initial() => ReputationState(
        loading: false,
        overview: ReputationOverview.empty(),
      );

  ReputationState copyWith({
    bool? loading,
    ReputationOverview? overview,
    String? error,
    String? purchasingId,
    bool clearError = false,
    bool clearPurchasing = false,
  }) {
    return ReputationState(
      loading: loading ?? this.loading,
      overview: overview ?? this.overview,
      error: clearError ? null : (error ?? this.error),
      purchasingId: clearPurchasing ? null : (purchasingId ?? this.purchasingId),
    );
  }
}

class ReputationNotifier extends Notifier<ReputationState> {
  ReputationRepository get _repo => ref.read(reputationRepositoryProvider);

  @override
  ReputationState build() => ReputationState.initial();

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final ReputationOverview overview = await _repo.loadOverview();
      state = state.copyWith(loading: false, overview: overview);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: userFacingErrorMessage(e, fallback: 'İtibar yüklenemedi.'),
      );
    }
  }

  int factionRep(String factionId) {
    for (final FactionReputation f in state.overview.factions) {
      if (f.factionId == factionId) return f.reputation;
    }
    return 0;
  }

  Future<String?> purchase({
    required ReputationShopItem item,
    String? factionId,
  }) async {
    state = state.copyWith(purchasingId: item.id, clearError: true);
    try {
      final Map<String, dynamic> res = await _repo.purchaseItem(
        itemId: item.id,
        factionId: factionId,
      );
      if (res['success'] != true) {
        final String msg = userFacingErrorMessage(
          res['error'] ?? 'Satın alma başarısız.',
          fallback: 'Satın alma başarısız.',
        );
        state = state.copyWith(clearPurchasing: true, error: msg);
        return msg;
      }
      await load();
      state = state.copyWith(clearPurchasing: true);
      return null;
    } catch (e) {
      final String msg = userFacingErrorMessage(e, fallback: 'Satın alma başarısız.');
      state = state.copyWith(clearPurchasing: true, error: msg);
      return msg;
    }
  }

  Future<String?> donate({
    required String factionId,
    required int goldAmount,
  }) async {
    try {
      final Map<String, dynamic> res = await _repo.donateToFaction(
        factionId: factionId,
        goldAmount: goldAmount,
      );
      if (res['success'] != true) {
        return userFacingErrorMessage(
          res['error'] ?? 'Bağış başarısız.',
          fallback: 'Bağış başarısız.',
        );
      }
      await load();
      return null;
    } catch (e) {
      return userFacingErrorMessage(e, fallback: 'Bağış başarısız.');
    }
  }
}

final NotifierProvider<ReputationNotifier, ReputationState> reputationProvider =
    NotifierProvider<ReputationNotifier, ReputationState>(ReputationNotifier.new);
