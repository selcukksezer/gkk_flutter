import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tutorial_controller.dart';
import 'tutorial_track.dart';

/// Event hooks from gameplay screens into the tutorial engine (v2).
abstract final class TutorialTriggers {
  static Future<void> onRouteEnter(WidgetRef ref, String route) async {
    await ref.read(tutorialProvider.notifier).onRouteEnter(route);
  }

  static void setPlayerLevelHint(WidgetRef ref, int level) {
    ref.read(tutorialProvider.notifier).setPlayerLevelHint(level);
  }

  static Future<void> onDungeonWin(WidgetRef ref) async {
    await ref.read(tutorialProvider.notifier).onGameEvent(
          TutorialGameEvent.dungeonWin,
        );
  }

  static Future<void> onEquipSuccess(WidgetRef ref) async {
    await ref.read(tutorialProvider.notifier).onGameEvent(
          TutorialGameEvent.equipSuccess,
        );
  }

  static Future<void> onEnhancementAttempt(WidgetRef ref) async {
    await ref.read(tutorialProvider.notifier).onGameEvent(
          TutorialGameEvent.enhancementAttempt,
        );
  }

  static Future<void> onBankDeposit(WidgetRef ref) async {
    await ref.read(tutorialProvider.notifier).onGameEvent(
          TutorialGameEvent.bankDeposit,
        );
  }

  static Future<void> onEnergyLow(WidgetRef ref, {required int energy}) async {
    if (energy > 0) return;
    final TutorialController controller = ref.read(tutorialProvider.notifier);
    // Never steal onboarding / mid-core coaching with shop tip.
    if (!controller.isTrackComplete(TutorialTrackId.onboarding)) return;
    if (controller.hasActiveTrack) return;
    if (controller.isTrackComplete(TutorialTrackId.shop)) return;
    await controller.startTrack(TutorialTrackId.shop);
  }

  /// Banka öğreticisini hazırla — dialog göstermez.
  static Future<void> prepareBankTutorialForInventoryFull(WidgetRef ref) async {
    final TutorialController controller = ref.read(tutorialProvider.notifier);
    if (!controller.isTrackComplete(TutorialTrackId.onboarding)) return;
    if (controller.hasActiveTrack) return;
    if (!controller.isTrackComplete(TutorialTrackId.bank)) {
      await controller.startTrack(TutorialTrackId.bank);
    }
  }

  @Deprecated('Use BankTutorial.maybeShowInventoryFullDialog')
  static Future<void> onInventoryFull(BuildContext context, WidgetRef ref) async {
    await prepareBankTutorialForInventoryFull(ref);
  }

  static Future<void> onAnchorTap(WidgetRef ref, String anchorId) async {
    await ref.read(tutorialProvider.notifier).onAnchorTap(anchorId);
  }
}
