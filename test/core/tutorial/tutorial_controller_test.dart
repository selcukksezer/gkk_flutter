import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_controller.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_persistence.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_step.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ProviderContainer makeContainer({TutorialProgressState? progress}) {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    if (progress != null) {
      container.read(tutorialProvider.notifier).debugSetState(
            TutorialState(
              loaded: true,
              progress: progress,
            ),
          );
    }
    return container;
  }

  group('TutorialController', () {
    test('completeActiveStep advances using next progress (no step loop)',
        () async {
      final ProviderContainer container = makeContainer(
        progress: TutorialProgressState.initial(),
      );
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: TutorialProgressState.initial(),
          activeTrackId: TutorialTrackId.onboarding,
          activeStep: TutorialTrackRegistry.stepById('onboarding_welcome'),
        ),
      );
      ctrl.debugSetLastRoute(TutorialRoutes.home);

      await ctrl.completeActiveManual();

      final TutorialState after = container.read(tutorialProvider);
      expect(after.activeStep?.id, 'onboarding_hud_energy');
      expect(
        after.progress.stepsForTrack(TutorialTrackId.onboarding),
        contains('onboarding_welcome'),
      );
    });

    test('onRouteEnter queues when not loaded, flushes on initialize',
        () async {
      final ProviderContainer container = makeContainer();
      final TutorialController ctrl = container.read(tutorialProvider.notifier);

      await ctrl.onRouteEnter(TutorialRoutes.home);
      expect(container.read(tutorialProvider).loaded, isFalse);
      expect(container.read(tutorialProvider).activeStep, isNull);

      await ctrl.initialize();

      final TutorialState after = container.read(tutorialProvider);
      expect(after.loaded, isTrue);
      expect(after.activeTrackId, TutorialTrackId.onboarding);
      expect(after.activeStep?.id, 'onboarding_welcome');
    });

    test('startTrack does not interrupt active onboarding', () async {
      final ProviderContainer container = makeContainer(
        progress: TutorialProgressState.initial(),
      );
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: TutorialProgressState.initial(),
          activeTrackId: TutorialTrackId.onboarding,
          activeStep: TutorialTrackRegistry.stepById('onboarding_welcome'),
        ),
      );

      await ctrl.startTrack(TutorialTrackId.shop);

      expect(
        container.read(tutorialProvider).activeTrackId,
        TutorialTrackId.onboarding,
      );
    });

    test('onAnchorTap ignores onGameEvent steps', () async {
      final TutorialProgressState progress = TutorialProgressState.initial()
          .completeStep(
            trackId: TutorialTrackId.inventory,
            stepId: 'inventory_first_item',
          );
      final ProviderContainer container = makeContainer(progress: progress);
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      final TutorialStepV2 equipStep =
          TutorialTrackRegistry.stepById('inventory_equip')!;
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: progress,
          activeTrackId: TutorialTrackId.inventory,
          activeStep: equipStep,
        ),
      );

      await ctrl.onAnchorTap(TutorialAnchorId.inventoryEquipBtn);

      expect(
        container.read(tutorialProvider).activeStep?.id,
        'inventory_equip',
      );
    });

    test('allowsNavTab locks to spotlight nav anchor', () {
      final ProviderContainer container = makeContainer(
        progress: TutorialProgressState.initial(),
      );
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      final TutorialStepV2 dungeonTab =
          TutorialTrackRegistry.stepById('onboarding_tap_dungeon_tab')!;
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: TutorialProgressState.initial(),
          activeTrackId: TutorialTrackId.onboarding,
          activeStep: dungeonTab,
        ),
      );

      expect(ctrl.allowsNavTab(2), isTrue); // dungeon
      expect(ctrl.allowsNavTab(1), isFalse); // inventory
      expect(ctrl.allowsNavTab(3), isFalse);
    });

    test('soft-pauses overlay when leaving track route', () async {
      TutorialProgressState progress = TutorialProgressState.initial();
      for (final String id in <String>[
        'onboarding_welcome',
        'onboarding_hud_energy',
        'onboarding_hud_gold',
        'onboarding_hud_gems',
        'onboarding_tap_dungeon_tab',
      ]) {
        progress = progress.completeStep(
          trackId: TutorialTrackId.onboarding,
          stepId: id,
        );
      }
      progress = progress.completeTrack(TutorialTrackId.onboarding);

      final ProviderContainer container = makeContainer(progress: progress);
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      final TutorialStepV2 pick =
          TutorialTrackRegistry.stepById('dungeon_pick_zone')!;
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: progress,
          activeTrackId: TutorialTrackId.dungeon,
          activeStep: pick,
        ),
      );
      ctrl.debugSetLastRoute(TutorialRoutes.dungeon);

      await ctrl.onRouteEnter(TutorialRoutes.inventory);

      final TutorialState after = container.read(tutorialProvider);
      expect(after.activeTrackId, TutorialTrackId.inventory);
      expect(after.progress.isTrackComplete(TutorialTrackId.dungeon), isFalse);
    });
  });
}
