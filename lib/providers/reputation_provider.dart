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

  Future<String?> purchase({required ReputationShopItem item}) async {
    state = state.copyWith(purchasingId: item.id, clearError: true);
    try {
      final Map<String, dynamic> res = await _repo.purchaseItem(itemId: item.id);
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
}

final NotifierProvider<ReputationNotifier, ReputationState> reputationProvider =
    NotifierProvider<ReputationNotifier, ReputationState>(ReputationNotifier.new);
