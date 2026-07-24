import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comeback_summary_model.dart';
import '../repositories/comeback_summary_repository.dart';

class ComebackSummaryState {
  const ComebackSummaryState({
    this.isLoading = false,
    this.summary,
    this.error,
    this.shownThisSession = false,
  });

  final bool isLoading;
  final ComebackSummary? summary;
  final String? error;
  final bool shownThisSession;

  ComebackSummaryState copyWith({
    bool? isLoading,
    ComebackSummary? summary,
    String? error,
    bool? shownThisSession,
    bool clearSummary = false,
    bool clearError = false,
  }) {
    return ComebackSummaryState(
      isLoading: isLoading ?? this.isLoading,
      summary: clearSummary ? null : (summary ?? this.summary),
      error: clearError ? null : (error ?? this.error),
      shownThisSession: shownThisSession ?? this.shownThisSession,
    );
  }
}

final comebackSummaryRepositoryProvider = Provider<ComebackSummaryRepository>(
  (Ref ref) => ComebackSummaryRepository(),
);

class ComebackSummaryNotifier extends Notifier<ComebackSummaryState> {
  ComebackSummaryRepository get _repository =>
      ref.read(comebackSummaryRepositoryProvider);

  @override
  ComebackSummaryState build() => const ComebackSummaryState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ComebackSummary? summary = await _repository.fetchSummary();
      state = state.copyWith(isLoading: false, summary: summary);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void markShownThisSession() {
    state = state.copyWith(shownThisSession: true);
    _repository.markSeen().ignore();
  }

  void resetSession() {
    state = const ComebackSummaryState();
  }
}

final comebackSummaryProvider =
    NotifierProvider<ComebackSummaryNotifier, ComebackSummaryState>(
  ComebackSummaryNotifier.new,
);
