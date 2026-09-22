import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import '../core/legal/legal_document_content.dart';
import '../core/services/supabase_service.dart';
import '../models/policy_model.dart';

export '../models/policy_model.dart' show kRegisterOnlyLegalDocTypes;

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

  /// Gameplay gate disabled — legal consent is register-screen only.
  bool get needsAcceptance => false;

  PolicyState copyWith({
    bool? isLoading,
    List<LegalDocument>? documents,
    PolicyStatus? status,
    String? error,
    bool clearError = false,
    bool clearStatus = false,
  }) {
    return PolicyState(
      isLoading: isLoading ?? this.isLoading,
      documents: documents ?? this.documents,
      status: clearStatus ? null : (status ?? this.status),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PolicyNotifier extends Notifier<PolicyState> {
  StreamSubscription<dynamic>? _authSub;
  int _refreshEpoch = 0;

  @override
  PolicyState build() {
    ref.onDispose(() {
      unawaited(_authSub?.cancel());
      _authSub = null;
    });

    if (SupabaseService.isInitialized) {
      _authSub?.cancel();
      _authSub = SupabaseService.client.auth.onAuthStateChange.listen((
        data,
      ) {
        final AuthChangeEvent event = data.event;
        if (event == AuthChangeEvent.signedOut) {
          _refreshEpoch++;
          state = const PolicyState();
          return;
        }
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.initialSession) {
          unawaited(refresh());
        }
      });
    }

    Future<void>.microtask(refresh);
    return const PolicyState(isLoading: true);
  }

  Future<void> refresh() async {
    final int epoch = ++_refreshEpoch;
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentSession == null) {
      if (epoch != _refreshEpoch) return;
      state = const PolicyState();
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      try {
        await SupabaseService.client.rpc('ensure_auth_user_profile');
      } catch (_) {}
      if (epoch != _refreshEpoch) return;

      final dynamic docsRaw = await SupabaseService.client.rpc(
        'get_active_legal_documents',
        params: <String, dynamic>{'p_locale': 'tr'},
      );
      if (epoch != _refreshEpoch) return;

      final dynamic statusRaw = await SupabaseService.client.rpc(
        'get_my_policy_status',
        params: <String, dynamic>{'p_locale': 'tr'},
      );
      if (epoch != _refreshEpoch) return;

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
      if (epoch != _refreshEpoch) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> acceptAll() async {
    // Cancel any concurrent auth-triggered refresh (signedIn race).
    _refreshEpoch++;
    try {
      final dynamic ensured = await SupabaseService.client.rpc(
        'ensure_auth_user_profile',
      );
      if (ensured is Map && ensured['success'] == false) {
        return _friendlyPolicyError(
          ensured['error']?.toString() ?? 'Oyuncu profili hazır değil',
        );
      }

      final dynamic raw = await SupabaseService.client.rpc(
        'accept_all_legal_documents',
        params: <String, dynamic>{'p_locale': 'tr'},
      );
      if (raw is Map && raw['success'] == false) {
        return _friendlyPolicyError(
          raw['error']?.toString() ?? 'Sözleşmeler kaydedilemedi',
        );
      }

      // Authoritative status from accept RPC — ignore stale parallel refresh.
      _refreshEpoch++;
      if (raw is Map && raw['status'] is Map) {
        final PolicyStatus status = PolicyStatus.fromJson(
          Map<String, dynamic>.from(raw['status'] as Map),
        );
        state = PolicyState(
          isLoading: false,
          documents: state.documents,
          status: status,
        );
        if (!status.allAccepted && status.missing.isNotEmpty) {
          await refresh();
        }
      } else {
        await refresh();
      }

      final PolicyStatus? verified = state.status;
      if (verified == null ||
          (!verified.allAccepted && verified.missing.isNotEmpty)) {
        return _friendlyPolicyError(
          state.error ?? 'Kabul kaydedildi ama doğrulama başarısız',
        );
      }
      return null;
    } catch (e) {
      return _friendlyPolicyError(e.toString());
    }
  }

  static String _friendlyPolicyError(String raw) {
    if (raw.contains('policy_acceptances_user_id_fkey') ||
        raw.contains('is not present in table "users"')) {
      return 'Oyuncu profilin henüz oluşmadı. Çıkış yapıp tekrar giriş yap veya destek ticket aç.';
    }
    return raw;
  }

  /// Kayıt öncesi — oturum gerekmez. DB fail / multi-row → app canonical.
  /// Never returns null — register UI always has readable community rules.
  Future<LegalDocument> fetchCommunityDocumentPublic() async {
    const LegalDocument fallback = LegalDocument(
      type: 'community',
      version: 1,
      title: 'Topluluk Kuralları',
      bodyMd: '',
    );
    if (!SupabaseService.isInitialized) {
      return LegalDocumentContent.resolve(fallback);
    }
    try {
      // TR+EN both active → maybeSingle throws. Prefer TR, limit 1.
      dynamic row;
      try {
        row = await SupabaseService.client
            .from('legal_documents')
            .select('doc_type, version, title, body_md, published_at, locale')
            .eq('doc_type', 'community')
            .eq('is_active', true)
            .eq('locale', 'tr')
            .order('version', ascending: false)
            .limit(1)
            .maybeSingle();
      } catch (_) {
        row = await SupabaseService.client
            .from('legal_documents')
            .select('doc_type, version, title, body_md, published_at')
            .eq('doc_type', 'community')
            .eq('is_active', true)
            .order('version', ascending: false)
            .limit(1)
            .maybeSingle();
      }
      if (row is Map) {
        return LegalDocumentContent.resolve(
          LegalDocument.fromJson(Map<String, dynamic>.from(row)),
        );
      }
    } catch (_) {}
    return LegalDocumentContent.resolve(fallback);
  }
}

final policyProvider =
    NotifierProvider<PolicyNotifier, PolicyState>(PolicyNotifier.new);
