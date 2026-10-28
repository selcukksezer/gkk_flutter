import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_identity_service.dart';

class SavedLoginCredentials {
  const SavedLoginCredentials({
    this.rememberMe = true,
    this.email = '',
    this.username,
    this.password = '',
    this.knownUsernameEmails = const <String, String>{},
  });

  final bool rememberMe;
  final String email;
  final String? username;
  final String password;
  final Map<String, String> knownUsernameEmails;

  bool get hasSavedAccount =>
      rememberMe && email.trim().isNotEmpty && password.isNotEmpty;

  String get displayHandle {
    final String cleanUser = username?.trim() ?? '';
    if (cleanUser.isNotEmpty && !cleanUser.contains('@')) {
      return '@$cleanUser';
    }
    return email.trim();
  }
}

/// Persists remembered login credentials locally (encrypted with a per-install
/// device key via HMAC-SHA256 CTR + authentication tag) so device-switch
/// re-logins require at most a single tap alongside native OS/Browser Autofill.
abstract final class SavedCredentialsService {
  static const String _rememberKey = 'gkk_auth_remember_me_v1';
  static const String _vaultKey = 'gkk_auth_saved_vault_v1';
  static const String _usernameMapKey = 'gkk_auth_username_map_v1';
  static const String _kdfSalt = 'gkk_shadow_citadel_auth_vault_v1';

  static Future<SavedLoginCredentials> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool rememberMe = prefs.getBool(_rememberKey) ?? true;
    final Map<String, String> knownMap = _decodeUsernameMap(
      prefs.getString(_usernameMapKey),
    );

    if (!rememberMe) {
      return SavedLoginCredentials(
        rememberMe: false,
        knownUsernameEmails: knownMap,
      );
    }

    final String? sealed = prefs.getString(_vaultKey);
    if (sealed == null || sealed.isEmpty) {
      return SavedLoginCredentials(
        rememberMe: true,
        knownUsernameEmails: knownMap,
      );
    }

    try {
      final List<int> key = await _deriveDeviceKey();
      final String? jsonText = _unseal(sealed, key);
      if (jsonText == null) {
        return SavedLoginCredentials(
          rememberMe: true,
          knownUsernameEmails: knownMap,
        );
      }
      final Object? decoded = jsonDecode(jsonText);
      if (decoded is! Map) {
        return SavedLoginCredentials(
          rememberMe: true,
          knownUsernameEmails: knownMap,
        );
      }
      final String email = (decoded['email'] ?? '').toString().trim();
      final String? rawUser = decoded['username']?.toString().trim();
      final String password = (decoded['password'] ?? '').toString();
      return SavedLoginCredentials(
        rememberMe: true,
        email: email,
        username: (rawUser == null || rawUser.isEmpty) ? null : rawUser,
        password: password,
        knownUsernameEmails: knownMap,
      );
    } catch (_) {
      return SavedLoginCredentials(
        rememberMe: true,
        knownUsernameEmails: knownMap,
      );
    }
  }

  static Future<void> save({
    required String email,
    required String password,
    String? username,
    required bool rememberMe,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, rememberMe);

    final String cleanEmail = email.trim();
    final String cleanUser = (username ?? '').trim();
    if (cleanEmail.isNotEmpty &&
        cleanUser.isNotEmpty &&
        !cleanUser.contains('@')) {
      final Map<String, String> knownMap = _decodeUsernameMap(
        prefs.getString(_usernameMapKey),
      );
      knownMap[cleanUser.toLowerCase()] = cleanEmail;
      await prefs.setString(_usernameMapKey, jsonEncode(knownMap));
    }

    if (!rememberMe) {
      await prefs.remove(_vaultKey);
      return;
    }

    if (cleanEmail.isEmpty || password.isEmpty) {
      return;
    }

    final List<int> key = await _deriveDeviceKey();
    final String payload = jsonEncode(<String, dynamic>{
      'email': cleanEmail,
      if (cleanUser.isNotEmpty) 'username': cleanUser,
      'password': password,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
    });
    await prefs.setString(_vaultKey, _seal(payload, key));
  }

  static Future<void> setRememberMe(bool rememberMe) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, rememberMe);
    if (!rememberMe) {
      await prefs.remove(_vaultKey);
    }
  }

  static Future<void> clearSavedAccount({bool keepRememberEnabled = true}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_vaultKey);
    await prefs.setBool(_rememberKey, keepRememberEnabled);
  }

  static Future<void> updatePasswordIfSaved(String newPassword) async {
    final SavedLoginCredentials current = await load();
    if (!current.hasSavedAccount || newPassword.isEmpty) return;
    await save(
      email: current.email,
      password: newPassword,
      username: current.username,
      rememberMe: current.rememberMe,
    );
  }

  static String resolveIdentifier(
    String rawInput,
    Map<String, String> knownUsernameEmails,
  ) {
    final String trimmed = rawInput.trim();
    if (trimmed.contains('@') && !trimmed.startsWith('@')) return trimmed;
    final String normalized = trimmed.startsWith('@')
        ? trimmed.substring(1).toLowerCase()
        : trimmed.toLowerCase();
    return knownUsernameEmails[normalized] ?? trimmed;
  }

  static Map<String, String> _decodeUsernameMap(String? raw) {
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final Object? parsed = jsonDecode(raw);
      if (parsed is! Map) return <String, String>{};
      final Map<String, String> out = <String, String>{};
      parsed.forEach((Object? k, Object? v) {
        final String ks = (k ?? '').toString().trim().toLowerCase();
        final String vs = (v ?? '').toString().trim();
        if (ks.isNotEmpty && vs.isNotEmpty) {
          out[ks] = vs;
        }
      });
      return out;
    } catch (_) {
      return <String, String>{};
    }
  }

  static Future<List<int>> _deriveDeviceKey() async {
    final String deviceId = await DeviceIdentityService.currentId();
    final Hmac hmac = Hmac(sha256, utf8.encode(_kdfSalt));
    return hmac.convert(utf8.encode(deviceId)).bytes;
  }

  static String _seal(String plaintext, List<int> key) {
    final Random rng = Random.secure();
    final List<int> iv = List<int>.generate(16, (_) => rng.nextInt(256));
    final List<int> plainBytes = utf8.encode(plaintext);
    final List<int> cipherBytes = _xorKeystream(plainBytes, key, iv);

    final Hmac macHmac = Hmac(sha256, key);
    final List<int> tag = macHmac
        .convert(<int>[...iv, ...cipherBytes])
        .bytes
        .sublist(0, 16);

    return 'v1:${base64Url.encode(iv)}:${base64Url.encode(cipherBytes)}:${base64Url.encode(tag)}';
  }

  static String? _unseal(String sealed, List<int> key) {
    final List<String> parts = sealed.split(':');
    if (parts.length != 4 || parts[0] != 'v1') return null;

    final List<int> iv = base64Url.decode(parts[1]);
    final List<int> cipherBytes = base64Url.decode(parts[2]);
    final List<int> tag = base64Url.decode(parts[3]);

    final Hmac macHmac = Hmac(sha256, key);
    final List<int> expectedTag = macHmac
        .convert(<int>[...iv, ...cipherBytes])
        .bytes
        .sublist(0, 16);

    if (!_constantTimeEquals(tag, expectedTag)) return null;

    final List<int> plainBytes = _xorKeystream(cipherBytes, key, iv);
    return utf8.decode(plainBytes);
  }

  static List<int> _xorKeystream(List<int> input, List<int> key, List<int> iv) {
    final List<int> out = List<int>.filled(input.length, 0);
    final Hmac prf = Hmac(sha256, key);
    int offset = 0;
    int counter = 0;
    while (offset < input.length) {
      final List<int> block = prf.convert(<int>[
        ...iv,
        (counter >> 24) & 0xFF,
        (counter >> 16) & 0xFF,
        (counter >> 8) & 0xFF,
        counter & 0xFF,
      ]).bytes;
      final int take = min(block.length, input.length - offset);
      for (int i = 0; i < take; i++) {
        out[offset + i] = input[offset + i] ^ block[i];
      }
      offset += take;
      counter++;
    }
    return out;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
