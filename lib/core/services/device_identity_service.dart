import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists a stable per-install device identifier for auth requests.
abstract final class DeviceIdentityService {
  static const String _storageKey = 'gkk_device_id';

  static Future<String> currentId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? existing = prefs.getString(_storageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final String id = _generateId();
    await prefs.setString(_storageKey, id);
    return id;
  }

  static Future<int?> readInt(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(key)) return null;
    return prefs.getInt(key);
  }

  static Future<void> writeInt(String key, int value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  static Future<void> removeKey(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static String _generateId() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final String hex = bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'gkk-$hex';
  }
}
