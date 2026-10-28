import 'dart:async';

import 'package:flutter/services.dart';

import 'app_settings_service.dart';

/// Haptic — [AppSettingsService.hapticEnabled] kapalıysa no-op.
///
/// V15 ile tekil titreşimlerin yanında savaş kritik vuruş, örs çekiç darbesi,
/// yükseltme zaferi/kırılması, efsanevi ganimet sütunu ve altın mıknatısı için
/// çok-adımlı ritmik dokunsal koreografiler eklendi.
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

  static Future<void> selection() async {
    if (!_on) return;
    await HapticFeedback.selectionClick();
  }

  /// Hit-stop ağırlığını hissettiren çift darbeli kritik vuruş titreşimi.
  static Future<void> criticalImpact() async {
    if (!_on) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 45));
    if (!_on) return;
    await HapticFeedback.lightImpact();
  }

  /// Demirci örsüne inen çekiç darbesi + metalik geri sekme.
  static Future<void> anvilStrikePulse() async {
    if (!_on) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 55));
    if (!_on) return;
    await HapticFeedback.selectionClick();
  }

  /// Başarılı +basma yükseliş fanfarı (`light -> medium -> heavy`).
  static Future<void> anvilSuccessFanfare() async {
    if (!_on) return;
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 65));
    if (!_on) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 75));
    if (!_on) return;
    await HapticFeedback.heavyImpact();
  }

  /// Yanma / parçalanma çift sarsıntısı.
  static Future<void> anvilShatter() async {
    if (!_on) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 85));
    if (!_on) return;
    await HapticFeedback.heavyImpact();
  }

  /// Destansı / Efsanevi ganimet ışık sütunu düşüşü.
  static Future<void> legendaryDropPulse() async {
    if (!_on) return;
    await HapticFeedback.selectionClick();
    await Future<void>.delayed(const Duration(milliseconds: 55));
    if (!_on) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    if (!_on) return;
    await HapticFeedback.heavyImpact();
  }

  /// Cüzdana uçan altın/ödül parçacıkları için seri tıkırtı.
  static Future<void> coinCascade({int ticks = 3}) async {
    if (!_on) return;
    final int count = ticks.clamp(1, 5);
    for (int i = 0; i < count; i++) {
      if (!_on) return;
      await HapticFeedback.selectionClick();
      if (i + 1 < count) {
        await Future<void>.delayed(const Duration(milliseconds: 52));
      }
    }
  }
}
