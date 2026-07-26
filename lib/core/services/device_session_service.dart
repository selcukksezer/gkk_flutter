import 'dart:io';

import 'package:flutter/foundation.dart';

import '../errors/app_exception.dart';
import 'device_identity_service.dart';
import 'supabase_service.dart';

/// Client-side single-device session token synced with [public.users.session_epoch].
abstract final class DeviceSessionService {
  static const String _epochKey = 'gkk_session_epoch';

  static Future<int> localEpoch() async {
    final int? value = await DeviceIdentityService.readInt(_epochKey);
    return value ?? 0;
  }

  static Future<void> saveEpoch(int epoch) async {
    await DeviceIdentityService.writeInt(_epochKey, epoch);
  }

  static Future<void> clearEpoch() async {
    await DeviceIdentityService.removeKey(_epochKey);
    await clearRequestHeaders();
  }

  /// Attach device session proof to every PostgREST call (server anti-cheat).
  static Future<void> syncRequestHeaders() async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      return;
    }
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) {
      await clearRequestHeaders();
      return;
    }
    final String deviceId = await DeviceIdentityService.currentId();
    final int epoch = await localEpoch();
    SupabaseService.client.headers['x-gkk-device-id'] = deviceId;
    SupabaseService.client.headers['x-gkk-session-epoch'] = epoch.toString();
  }

  static Future<void> clearRequestHeaders() async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      return;
    }
    SupabaseService.client.headers.remove('x-gkk-device-id');
    SupabaseService.client.headers.remove('x-gkk-session-epoch');
  }

  static String platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'mobile';
  }

  /// After password login: claim this device + bump server epoch.
  static Future<int> claimActiveDevice() async {
    _ensureReady();
    final String deviceId = await DeviceIdentityService.currentId();
    final dynamic raw = await SupabaseService.client.rpc(
      'claim_device_session',
      params: <String, dynamic>{
        'p_device_id': deviceId,
        'p_platform': platformLabel(),
      },
    );
    final Map<String, dynamic> data = _asMap(raw);
    if (data['success'] != true) {
      throw AppException(
        data['error']?.toString() ?? 'Cihaz oturumu kaydedilemedi.',
        code: 'DEVICE_SESSION_CLAIM_FAILED',
      );
    }
    final int epoch = (data['session_epoch'] as num?)?.toInt() ?? 0;
    await saveEpoch(epoch);
    await syncRequestHeaders();
    return epoch;
  }

  /// Returns false when this install is no longer the active session.
  static Future<DeviceSessionVerifyResult> verifyCurrentDevice() async {
    _ensureReady();
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) {
      return const DeviceSessionVerifyResult(valid: true, reason: DeviceSessionReason.noAuth);
    }

    final String deviceId = await DeviceIdentityService.currentId();
    final int epoch = await localEpoch();

    final dynamic raw = await SupabaseService.client.rpc(
      'verify_device_session',
      params: <String, dynamic>{
        'p_device_id': deviceId,
        'p_session_epoch': epoch,
      },
    );
    final Map<String, dynamic> data = _asMap(raw);
    if (data['success'] != true) {
      return DeviceSessionVerifyResult(
        valid: false,
        reason: DeviceSessionReason.error,
        message: data['error']?.toString(),
      );
    }

    if (data['valid'] == true) {
      final String reason = data['reason']?.toString() ?? 'ok';
      if (reason == 'unclaimed') {
        final int claimed = await claimActiveDevice();
        return DeviceSessionVerifyResult(
          valid: true,
          reason: DeviceSessionReason.claimed,
          sessionEpoch: claimed,
        );
      }
      final int serverEpoch = (data['session_epoch'] as num?)?.toInt() ?? epoch;
      if (serverEpoch != epoch) {
        await saveEpoch(serverEpoch);
        await syncRequestHeaders();
      }
      return DeviceSessionVerifyResult(
        valid: true,
        reason: DeviceSessionReason.ok,
        sessionEpoch: serverEpoch,
      );
    }

    final String reason = data['reason']?.toString() ?? 'invalid';
    return DeviceSessionVerifyResult(
      valid: false,
      reason: reason == 'other_device_active'
          ? DeviceSessionReason.otherDevice
          : DeviceSessionReason.superseded,
      sessionEpoch: (data['session_epoch'] as num?)?.toInt(),
    );
  }

  static void _ensureReady() {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'success': false, 'error': 'Invalid response'};
  }
}

enum DeviceSessionReason {
  noAuth,
  ok,
  claimed,
  unclaimed,
  otherDevice,
  superseded,
  error,
}

class DeviceSessionVerifyResult {
  const DeviceSessionVerifyResult({
    required this.valid,
    required this.reason,
    this.sessionEpoch,
    this.message,
  });

  final bool valid;
  final DeviceSessionReason reason;
  final int? sessionEpoch;
  final String? message;
}
