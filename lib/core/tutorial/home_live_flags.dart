import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Client-only switch: liveliness home body vs legacy HUD-only onboarding.
///
/// Default `false` — home live intentionally off (legacy home). Do not flip on
/// to reintroduce live dashboards. Settings may still persist a user override.
class HomeLiveFlags {
  HomeLiveFlags._();

  static const String prefsKey = 'home_liveliness_enabled';
  static const bool defaultEnabled = false;

  static final ValueNotifier<bool> listenable =
      ValueNotifier<bool>(defaultEnabled);

  static bool get livelinessHome => listenable.value;

  static Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    listenable.value = prefs.getBool(prefsKey) ?? defaultEnabled;
  }

  static Future<void> setEnabled(bool enabled) async {
    listenable.value = enabled;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, enabled);
  }
}
