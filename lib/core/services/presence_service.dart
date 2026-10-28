import 'dart:async';

import 'package:flutter/widgets.dart';

import 'supabase_service.dart';

/// Keeps `users.is_online` / `last_active_at` fresh with a 45s heartbeat and
/// guarantees `is_online = false` is committed BEFORE `auth.signOut()` clears JWT.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  Timer? _heartbeat;
  bool _started = false;
  String? _currentMekanId;

  /// Mekan detayına girince çağır; çıkınca null yolla.
  void setCurrentMekan(String? mekanId) {
    if (_currentMekanId == mekanId) return;
    _currentMekanId = mekanId;
    if (_started) unawaited(_setOnline(true));
  }

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setOnline(true));
    _heartbeat = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_setOnline(true)),
    );
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    _heartbeat = null;
    unawaited(_setOnline(false));
  }

  /// Must be awaited BEFORE `Supabase.auth.signOut()` so `auth.uid()` is still
  /// authenticated on the server when setting `users.is_online = false`.
  Future<void> goOfflineBeforeSignOut() async {
    if (_started) {
      _started = false;
      WidgetsBinding.instance.removeObserver(this);
    }
    _heartbeat?.cancel();
    _heartbeat = null;
    _currentMekanId = null;
    await _setOnline(false).timeout(
      const Duration(milliseconds: 1600),
      onTimeout: () {},
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_setOnline(true));
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_setOnline(false));
    }
  }

  Future<void> _setOnline(bool online) async {
    if (!SupabaseService.isInitialized) return;
    if (SupabaseService.client.auth.currentUser == null) return;
    try {
      await SupabaseService.client.rpc(
        'set_online_status',
        params: <String, dynamic>{
          'p_is_online': online,
          'p_mekan_id': online ? _currentMekanId : null,
        },
      );
    } catch (_) {
      // Non-blocking — next heartbeat retries.
    }
  }
}
