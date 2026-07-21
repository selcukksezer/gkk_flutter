import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../routing/app_router.dart';
import '../tutorial/tutorial_triggers.dart';

/// Envanter dolu → banka öğretici akışı.
/// Tutorial engine ile entegre; legacy prefs korunur.
class BankTutorial {
  static const String _shownKey = 'bank_tutorial_shown';
  static const String _coachKey = 'bank_deposit_coach_shown';

  /// Envanter dolu sinyali — tutorial engine + fallback dialog.
  static Future<void> maybeShowInventoryFullDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await TutorialTriggers.onInventoryFull(context, ref);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shownKey) ?? false) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B2A),
        title: const Text(
          'Envanterin Dolu',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          'Çantanda yer kalmadı ve yeni eşyalar alınamıyor.\n\n'
          'Kullanmadığın eşyalarını BANKAYA koyarak yer açabilirsin. '
          'Bankadaki eşyalar güvende kalır ve istediğin zaman geri alabilirsin.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Sonra'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ctx.go(AppRoutes.bank);
            },
            child: const Text('Bankaya Git'),
          ),
        ],
      ),
    );

    await prefs.setBool(_shownKey, true);
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
