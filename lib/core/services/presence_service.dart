import 'dart:async';

import 'package:flutter/widgets.dart';

import 'supabase_service.dart';

/// Keeps users.is_online / last_active_at fresh for trade online checks.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  Timer? _heartbeat;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
    _heartbeat = Timer.periodic(const Duration(minutes: 2), (_) => _setOnline(true));
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    _heartbeat = null;
    _setOnline(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline(true);
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _setOnline(false);
    }
  }

  Future<void> _setOnline(bool online) async {
    if (!SupabaseService.isInitialized) return;
    if (SupabaseService.client.auth.currentUser == null) return;
    try {
      await SupabaseService.client.rpc(
        'set_online_status',
        params: <String, dynamic>{'p_is_online': online},
      );
    } catch (_) {
      // Non-blocking — next heartbeat retries.
    }
  }
}
