import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/universal_game_dialog.dart';
import '../../routing/app_router.dart';
import '../tutorial/tutorial_triggers.dart';

/// Envanter dolu → tek bildirim (dialog veya kısa snack).
class BankTutorial {
  static const String _shownKey = 'bank_tutorial_shown';
  static const String _coachKey = 'bank_deposit_coach_shown';

  static bool _dialogOpen = false;

  /// Envanter dolu — zafer/loot ekranında en fazla 1 popup.
  static Future<void> maybeShowInventoryFullDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (_dialogOpen || !context.mounted) return;

    await TutorialTriggers.prepareBankTutorialForInventoryFull(ref);
    if (!context.mounted) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool alreadyShown = prefs.getBool(_shownKey) ?? false;

    if (alreadyShown) {
      AppMessenger.show(context, 'Envanter dolu — bazı eşyalar alınamadı.');
      return;
    }

    _dialogOpen = true;
    try {
      final bool? goBank = await UniversalGameDialog.show(
        context,
        title: 'Envanterin Dolu',
        message:
            'Cantanda yer kalmadi ve yeni esyalar alinamiyor.\n\n'
            'Kullanmadigin esyalarini BANKAYA koyarak yer acabilirsin. '
            'Bankadaki esyalar guvende kalir ve istedigin zaman geri alabilirsin.',
        confirmLabel: 'Bankaya Git',
        cancelLabel: 'Sonra',
      );
      if (goBank == true && context.mounted) {
        context.go(AppRoutes.bank);
      }
      await prefs.setBool(_shownKey, true);
    } finally {
      _dialogOpen = false;
    }
  }

  /// Banka ekranında ilk yatırma coach-mark (tek seferlik).
  static Future<bool> shouldShowDepositCoach() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool tutorialShown = prefs.getBool(_shownKey) ?? false;
    final bool coachShown = prefs.getBool(_coachKey) ?? false;
    if (!tutorialShown || coachShown) return false;
    return true;
  }

  static Future<void> markDepositCoachShown() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_coachKey, true);
  }
}
