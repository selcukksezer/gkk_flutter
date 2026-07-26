import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';
import '../models/policy_model.dart';

class PolicyState {
  const PolicyState({
    this.isLoading = false,
    this.documents = const <LegalDocument>[],
    this.status,
    this.error,
  });

  final bool isLoading;
  final List<LegalDocument> documents;
  final PolicyStatus? status;
  final String? error;

  bool get needsAcceptance => status != null && !status!.allAccepted;

  PolicyState copyWith({
    bool? isLoading,
    List<LegalDocument>? documents,
    PolicyStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return PolicyState(
      isLoading: isLoading ?? this.isLoading,
      documents: documents ?? this.documents,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PolicyNotifier extends Notifier<PolicyState> {
  @override
  PolicyState build() {
    Future<void>.microtask(refresh);
    return const PolicyState(isLoading: true);
  }

  Future<void> refresh() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentSession == null) {
      state = const PolicyState();
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dynamic docsRaw = await SupabaseService.client.rpc(
        'get_active_legal_documents',
        params: <String, dynamic>{'p_locale': 'tr'},
      );
      final dynamic statusRaw = await SupabaseService.client.rpc(
        'get_my_policy_status',
        params: <String, dynamic>{'p_locale': 'tr'},
      );

      final List<LegalDocument> docs = <LegalDocument>[];
      if (docsRaw is List) {
        for (final dynamic row in docsRaw) {
          if (row is Map) {
            docs.add(LegalDocument.fromJson(Map<String, dynamic>.from(row)));
          }
        }
      } else if (docsRaw is Map) {
        final dynamic items = docsRaw['items'] ?? docsRaw['documents'];
        if (items is List) {
          for (final dynamic row in items) {
            if (row is Map) {
              docs.add(LegalDocument.fromJson(Map<String, dynamic>.from(row)));
            }
          }
        }
      }

      PolicyStatus? status;
      if (statusRaw is Map && statusRaw['success'] != false) {
        status = PolicyStatus.fromJson(Map<String, dynamic>.from(statusRaw));
      }

      state = PolicyState(
        isLoading: false,
        documents: docs,
        status: status,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> acceptAll() async {
    try {
      await SupabaseService.client.rpc(
        'accept_all_legal_documents',
        params: <String, dynamic>{'p_locale': 'tr'},
      );
      await refresh();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Kayıt öncesi — oturum gerekmez; aktif Topluluk Kuralları.
  Future<LegalDocument?> fetchCommunityDocumentPublic() async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final dynamic row = await SupabaseService.client
          .from('legal_documents')
          .select('doc_type, version, title, body_md, published_at')
          .eq('doc_type', 'community')
          .eq('is_active', true)
          .maybeSingle();
      if (row is! Map) return null;
      return LegalDocument.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }
}

final policyProvider =
    NotifierProvider<PolicyNotifier, PolicyState>(PolicyNotifier.new);
