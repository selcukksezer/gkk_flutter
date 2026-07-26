import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/universal_game_dialog.dart';
import '../../routing/app_router.dart';
import '../tutorial/tutorial_controller.dart';
import '../tutorial/tutorial_persistence.dart';
import '../tutorial/tutorial_triggers.dart';

/// Envanter dolu → tek bildirim (dialog veya kısa snack).
///
/// One-shot flags live in tutorial v2 progress ([TutorialProgressState.flags]).
/// Legacy SharedPreferences keys are migrated once on first use.
class BankTutorial {
  static const String _legacyShownKey = 'bank_tutorial_shown';
  static const String _legacyCoachKey = 'bank_deposit_coach_shown';

  static bool _dialogOpen = false;

  /// Envanter dolu — zafer/loot ekranında en fazla 1 popup.
  static Future<void> maybeShowInventoryFullDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (_dialogOpen || !context.mounted) return;

    await TutorialTriggers.prepareBankTutorialForInventoryFull(ref);
    if (!context.mounted) return;

    final TutorialController controller = ref.read(tutorialProvider.notifier);
    await _migrateLegacyPrefs(controller);

    if (controller.hasProgressFlag(TutorialProgressState.flagBankFullPrompted)) {
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
      await controller.setProgressFlag(
        TutorialProgressState.flagBankFullPrompted,
      );
    } finally {
      _dialogOpen = false;
    }
  }

  /// Banka ekranında ilk yatırma coach-mark (tek seferlik).
  static Future<bool> shouldShowDepositCoach(WidgetRef ref) async {
    final TutorialController controller = ref.read(tutorialProvider.notifier);
    await _migrateLegacyPrefs(controller);
    if (!controller.hasProgressFlag(
      TutorialProgressState.flagBankFullPrompted,
    )) {
      return false;
    }
    return !controller.hasProgressFlag(
      TutorialProgressState.flagBankDepositCoachShown,
    );
  }

  static Future<void> markDepositCoachShown(WidgetRef ref) async {
    final TutorialController controller = ref.read(tutorialProvider.notifier);
    await controller.setProgressFlag(
      TutorialProgressState.flagBankDepositCoachShown,
    );
  }

  static Future<void> _migrateLegacyPrefs(TutorialController controller) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_legacyShownKey) == true &&
        !controller.hasProgressFlag(
          TutorialProgressState.flagBankFullPrompted,
        )) {
      await controller.setProgressFlag(
        TutorialProgressState.flagBankFullPrompted,
      );
    }
    if (prefs.getBool(_legacyCoachKey) == true &&
        !controller.hasProgressFlag(
          TutorialProgressState.flagBankDepositCoachShown,
        )) {
      await controller.setProgressFlag(
        TutorialProgressState.flagBankDepositCoachShown,
      );
    }
  }
}
