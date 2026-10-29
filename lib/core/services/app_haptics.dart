import 'package:flutter/services.dart';

import 'app_settings_service.dart';

/// Haptic â€” [AppSettingsService.hapticEnabled] kapalıysa no-op.
abstract final class AppHaptics {
  static bool get _on => AppSettingsService.instance.hapticEnabled;

  static Future<void> light() async {
    if (!_on) return;
    await HapticFeedback.lightImpact();
  }

  static Future<void> medium() async {
    if (!_on) return;
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavy() async {
    if (!_on) return;
    await HapticFeedback.heavyImpact();
  }

  static Future<void> success() async {
    if (!_on) return;
    await HapticFeedback.mediumImpact();
  }

  static Future<void> selection() async {
    if (!_on) return;
    await HapticFeedback.selectionClick();
  }

  static Future<void> vibrate() async {
    if (!_on) return;
    await HapticFeedback.vibrate();
  }
}

