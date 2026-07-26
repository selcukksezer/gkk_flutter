import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../components/common/app_messenger.dart';
import '../core/services/app_foreground_service.dart';
import '../core/services/device_session_service.dart';
import '../core/services/supabase_service.dart';
import '../routing/app_router.dart';
import '../utils/logout_helper.dart';

/// Kicks stale installs when another device claims the account.
class SessionEnforcementGate extends ConsumerStatefulWidget {
  const SessionEnforcementGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionEnforcementGate> createState() => _SessionEnforcementGateState();
}

class _SessionEnforcementGateState extends ConsumerState<SessionEnforcementGate> {
  Timer? _pollTimer;
  supa.RealtimeChannel? _channel;
  bool _checking = false;
  bool _kicked = false;
  int _verifyFailures = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    AppForegroundService.instance.addListener(_onAppResume);
  }

  @override
  void dispose() {
    AppForegroundService.instance.removeListener(_onAppResume);
    _pollTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _onAppResume() {
    unawaited(_verifySession(showMessage: true));
  }

  Future<void> _bootstrap() async {
    if (!SupabaseService.isInitialized) return;

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_verifySession(showMessage: true));
    });

    SupabaseService.client.auth.onAuthStateChange.listen((supa.AuthState data) {
      if (data.session == null) {
        _channel?.unsubscribe();
        _channel = null;
        return;
      }
      unawaited(_verifySession(showMessage: false));
      _subscribeRealtime(data.session!.user.id);
    });

    final session = SupabaseService.client.auth.currentSession;
    if (session != null) {
      await _verifySession(showMessage: false);
      _subscribeRealtime(session.user.id);
    }
  }

  void _subscribeRealtime(String authId) {
    if (!SupabaseService.isInitialized) return;
    _channel?.unsubscribe();
    _channel = SupabaseService.client
        .channel('device-session-$authId')
        .onPostgresChanges(
          event: supa.PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: supa.PostgresChangeFilter(
            type: supa.PostgresChangeFilterType.eq,
            column: 'auth_id',
            value: authId,
          ),
          callback: (_) => unawaited(_verifySession(showMessage: true)),
        )
        .subscribe();
  }

  Future<void> _verifySession({required bool showMessage}) async {
    if (!mounted || _kicked || _checking) return;
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentSession == null) {
      return;
    }

    _checking = true;
    try {
      final DeviceSessionVerifyResult result =
          await DeviceSessionService.verifyCurrentDevice();
      if (!mounted || result.valid) {
        _verifyFailures = 0;
        return;
      }

      if (result.reason == DeviceSessionReason.otherDevice ||
          result.reason == DeviceSessionReason.superseded) {
        await _forceLogout(
          message: result.reason == DeviceSessionReason.otherDevice
              ? 'Hesabın başka bir cihazda açıldı. Bu oturum kapatıldı.'
              : 'Yeni giriş algılandı. Tek cihaz kuralı gereği çıkış yapıldı.',
          showMessage: showMessage,
        );
      }
    } catch (_) {
      _verifyFailures++;
      if (_verifyFailures >= 3 && mounted && !_kicked) {
        await _forceLogout(
          message: 'Oturum doğrulanamadı. Tekrar giriş yap.',
          showMessage: showMessage,
        );
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _forceLogout({
    required String message,
    required bool showMessage,
  }) async {
    if (_kicked) return;
    _kicked = true;
    await performLogout(ref);
    if (!mounted) return;
    if (showMessage) {
      AppMessenger.showError(context, message);
    }
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
