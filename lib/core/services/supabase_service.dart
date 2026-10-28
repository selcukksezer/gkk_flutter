import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import 'device_session_service.dart';

class SupabaseService {
  const SupabaseService._();

  static bool _initialized = false;
  static Future<void>? _initInflight;
  static final Completer<void> _readyCompleter = Completer<void>();

  static bool get isConfigured {
    return AppConstants.supabaseUrl.startsWith('https://') &&
        !AppConstants.supabaseUrl.contains('YOUR_PROJECT') &&
        AppConstants.supabaseAnonKey.isNotEmpty &&
        !AppConstants.supabaseAnonKey.contains('YOUR_SUPABASE_ANON_KEY');
  }

  static bool get isInitialized => _initialized;

  /// Completes once [Supabase.initialize] finishes (even if startup timed out early).
  static Future<void> get whenInitialized => _readyCompleter.future;

  static Future<void> initialize({
    Duration startupTimeout = const Duration(seconds: 6),
  }) async {
    if (!isConfigured || _initialized) {
      return;
    }

    final Future<void> inflight = _initInflight ??= _performInitialize();
    try {
      await inflight.timeout(startupTimeout);
    } catch (e) {
      debugPrint('SupabaseService.initialize non-fatal startup delay/error: $e');
    }
  }

  static Future<void> _performInitialize() async {
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConstants.supabaseAnonKey,
      );
      _initialized = true;
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
      if (Supabase.instance.client.auth.currentSession != null) {
        unawaited(
          DeviceSessionService.syncRequestHeaders()
              .timeout(const Duration(seconds: 3))
              .catchError((Object _) {}),
        );
      }
    } catch (e) {
      _initInflight = null;
      rethrow;
    }
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'Supabase is not initialized. Configure AppConstants and call initialize().',
      );
    }
    return Supabase.instance.client;
  }
}
