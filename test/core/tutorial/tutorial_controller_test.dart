import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_controller.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_features.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_persistence.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_step.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TutorialFeatures.enabled = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    TutorialFeatures.enabled = false;
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
    test('clearSession drops last route (no cross-account home pending)', () {
      final ProviderContainer container = makeContainer();
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetLastRoute(TutorialRoutes.home);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: TutorialProgressState.initial(),
          activeTrackId: TutorialTrackId.onboarding,
          activeStep: TutorialTrackRegistry.stepById('onboarding_welcome'),
          overlayPaused: true,
        ),
      );

      ctrl.clearSession();

      expect(ctrl.debugLastRoute, isNull);
      final TutorialState after = container.read(tutorialProvider);
      expect(after.loaded, isFalse);
      expect(after.activeStep, isNull);
      expect(after.overlayPaused, isFalse);
    });

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
      expect(after.activeStep?.id, 'onboarding_game_loop');
      expect(
        after.progress.stepsForTrack(TutorialTrackId.onboarding),
        contains('onboarding_welcome'),
      );
    });

    test('highlightOnly tap step advances via anchor tap', () async {
      final ProviderContainer container = makeContainer(
        progress: TutorialProgressState.initial()
            .completeStep(
              trackId: TutorialTrackId.onboarding,
              stepId: 'onboarding_welcome',
            )
            .completeStep(
              trackId: TutorialTrackId.onboarding,
              stepId: 'onboarding_game_loop',
            ),
      );
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: container.read(tutorialProvider).progress,
          activeTrackId: TutorialTrackId.onboarding,
          activeStep: TutorialTrackRegistry.stepById('onboarding_home_promo'),
        ),
      );
      ctrl.debugSetLastRoute(TutorialRoutes.home);

      await ctrl.onAnchorTap(TutorialAnchorId.homePromo);

      final TutorialState after = container.read(tutorialProvider);
      expect(after.activeStep?.id, 'onboarding_home_hero');
    });

    test('completeActiveManual ignored for spotlight tap steps', () async {
      final ProviderContainer container = makeContainer(
        progress: TutorialProgressState.initial(),
      );
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: TutorialProgressState.initial(),
          activeTrackId: TutorialTrackId.dungeon,
          activeStep:
              TutorialTrackRegistry.stepById('dungeon_confirm_enter'),
        ),
      );

      await ctrl.completeActiveManual();

      expect(
        container.read(tutorialProvider).activeStep?.id,
        'dungeon_confirm_enter',
      );
    });

    test('confirm_enter defers first_win until dungeon success', () async {
      final TutorialProgressState progress = TutorialProgressState.initial()
          .completeStep(
            trackId: TutorialTrackId.dungeon,
            stepId: 'dungeon_intro',
          )
          .completeStep(
            trackId: TutorialTrackId.dungeon,
            stepId: 'dungeon_pick_zone',
          )
          .completeStep(
            trackId: TutorialTrackId.dungeon,
            stepId: 'dungeon_enter_btn',
          );
      final ProviderContainer container = makeContainer(progress: progress);
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: progress,
          activeTrackId: TutorialTrackId.dungeon,
          activeStep: TutorialTrackRegistry.stepById('dungeon_confirm_enter'),
        ),
      );
      ctrl.debugSetLastRoute(TutorialRoutes.dungeon);

      await ctrl.onAnchorTap(TutorialAnchorId.dungeonConfirmOk);

      final TutorialState afterConfirm = container.read(tutorialProvider);
      expect(afterConfirm.activeStep, isNull);
      expect(
        afterConfirm.progress.stepsForTrack(TutorialTrackId.dungeon),
        contains('dungeon_confirm_enter'),
      );

      final bool revealed = await ctrl.revealHeldDungeonWin();
      expect(revealed, isTrue);
      expect(
        container.read(tutorialProvider).activeStep?.id,
        'dungeon_first_win',
      );
    });

    test('onGameEvent buffers until matching waitEvent step is active', () async {
      final TutorialProgressState progress = TutorialProgressState.initial()
          .completeStep(
            trackId: TutorialTrackId.dungeon,
            stepId: 'dungeon_intro',
          )
          .completeStep(
            trackId: TutorialTrackId.dungeon,
            stepId: 'dungeon_pick_zone',
          )
          .completeStep(
            trackId: TutorialTrackId.dungeon,
            stepId: 'dungeon_enter_btn',
          );
      final ProviderContainer container = makeContainer(progress: progress);
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: progress,
          activeTrackId: TutorialTrackId.dungeon,
          activeStep: TutorialTrackRegistry.stepById('dungeon_confirm_enter'),
        ),
      );

      await ctrl.onGameEvent(TutorialGameEvent.dungeonWin);
      expect(
        container.read(tutorialProvider).activeStep?.id,
        'dungeon_confirm_enter',
      );

      await ctrl.onAnchorTap(TutorialAnchorId.dungeonConfirmOk);

      final TutorialState after = container.read(tutorialProvider);
      expect(
        after.progress.stepsForTrack(TutorialTrackId.dungeon),
        contains('dungeon_confirm_enter'),
      );
      expect(after.activeStep, isNull);

      await ctrl.revealHeldDungeonWin();
      expect(container.read(tutorialProvider).activeStep?.id, 'dungeon_first_win');
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
            trackId: TutorialTrackId.enhancement,
            stepId: 'enhance_pick_item',
          )
          .completeStep(
            trackId: TutorialTrackId.enhancement,
            stepId: 'enhance_tap_forge',
          )
          .completeStep(
            trackId: TutorialTrackId.enhancement,
            stepId: 'enhance_result',
          )
          .completeStep(
            trackId: TutorialTrackId.enhancement,
            stepId: 'enhance_to_inventory',
          )
          .completeStep(
            trackId: TutorialTrackId.enhancement,
            stepId: 'enhance_open_item',
          );
      final ProviderContainer container = makeContainer(progress: progress);
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      final TutorialStepV2 equipStep =
          TutorialTrackRegistry.stepById('enhance_equip')!;
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: progress,
          activeTrackId: TutorialTrackId.enhancement,
          activeStep: equipStep,
        ),
      );

      await ctrl.onAnchorTap(TutorialAnchorId.inventoryEquipBtn);

      expect(
        container.read(tutorialProvider).activeStep?.id,
        'enhance_equip',
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

    test('completeActiveManual ignored for bottom-nav tap steps', () async {
      final ProviderContainer container = makeContainer(
        progress: TutorialProgressState.initial(),
      );
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: TutorialProgressState.initial(),
          activeTrackId: TutorialTrackId.onboarding,
          activeStep:
              TutorialTrackRegistry.stepById('onboarding_tap_dungeon_tab'),
        ),
      );

      await ctrl.completeActiveManual();

      expect(
        container.read(tutorialProvider).activeStep?.id,
        'onboarding_tap_dungeon_tab',
      );
    });

    test('completeActiveManual advances nav.bottom_bar intro step', () async {
      final ProviderContainer container = makeContainer(
        progress: TutorialProgressState.initial(),
      );
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: TutorialProgressState.initial(),
          activeTrackId: TutorialTrackId.onboarding,
          activeStep:
              TutorialTrackRegistry.stepById('onboarding_nav_intro'),
        ),
      );

      await ctrl.completeActiveManual();

      expect(
        container.read(tutorialProvider).progress.stepsForTrack(
              TutorialTrackId.onboarding,
            ),
        contains('onboarding_nav_intro'),
      );
    });

    test('soft-pauses core track without dropping when leaving route', () async {
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
      // Core pin: dungeon stays active (paused); inventory track must not steal.
      expect(after.activeTrackId, TutorialTrackId.dungeon);
      expect(after.activeStep?.id, 'dungeon_pick_zone');
      expect(after.overlayPaused, isTrue);
      expect(after.progress.isTrackComplete(TutorialTrackId.dungeon), isFalse);
    });

    test('non-core soft-pause may drop so route track can start', () async {
      TutorialProgressState progress = TutorialProgressState.initial();
      for (final String core in TutorialTrackId.coreTracks) {
        progress = progress.completeTrack(core);
      }
      progress = progress.completeStep(
        trackId: TutorialTrackId.market,
        stepId: 'market_browse_intro',
      );
      // Leave market incomplete by not completing the track.

      final ProviderContainer container = makeContainer(progress: progress);
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: progress,
          activeTrackId: TutorialTrackId.market,
          activeStep:
              TutorialTrackRegistry.stepById('market_browse_intro'),
          overlayPaused: true,
        ),
      );
      ctrl.debugSetLastRoute(TutorialRoutes.shop);

      await ctrl.onRouteEnter(TutorialRoutes.shop);

      final TutorialState after = container.read(tutorialProvider);
      expect(after.activeTrackId, TutorialTrackId.shop);
      expect(after.activeStep?.id, 'shop_energy_potion');
    });

    test('unpause flushes pending game event', () async {
      final TutorialProgressState progress = TutorialProgressState.initial()
          .completeStep(
            trackId: TutorialTrackId.enhancement,
            stepId: 'enhance_pick_item',
          )
          .completeStep(
            trackId: TutorialTrackId.enhancement,
            stepId: 'enhance_tap_forge',
          )
          .completeStep(
            trackId: TutorialTrackId.enhancement,
            stepId: 'enhance_result',
          )
          .completeStep(
            trackId: TutorialTrackId.enhancement,
            stepId: 'enhance_to_inventory',
          )
          .completeStep(
            trackId: TutorialTrackId.enhancement,
            stepId: 'enhance_open_item',
          );
      final ProviderContainer container = makeContainer(progress: progress);
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: progress,
          activeTrackId: TutorialTrackId.enhancement,
          activeStep: TutorialTrackRegistry.stepById('enhance_equip'),
          overlayPaused: true,
        ),
      );
      ctrl.debugSetLastRoute(TutorialRoutes.character);

      await ctrl.onGameEvent(TutorialGameEvent.equipSuccess);
      expect(
        container.read(tutorialProvider).activeStep?.id,
        'enhance_equip',
      );

      await ctrl.onRouteEnter(TutorialRoutes.inventory);
      await Future<void>.delayed(Duration.zero);

      final TutorialState after = container.read(tutorialProvider);
      expect(after.overlayPaused, isFalse);
      expect(after.activeStep?.id, isNot('enhance_equip'));
      expect(
        after.progress.stepsForTrack(TutorialTrackId.enhancement),
        contains('enhance_equip'),
      );
    });

    test('blocksNavigation locks onboarding off-home routes', () {
      final ProviderContainer container = makeContainer(
        progress: TutorialProgressState.initial(),
      );
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: TutorialProgressState.initial(),
          activeTrackId: TutorialTrackId.onboarding,
          activeStep:
              TutorialTrackRegistry.stepById('onboarding_welcome'),
        ),
      );

      expect(ctrl.blocksNavigation(TutorialRoutes.home), isFalse);
      expect(ctrl.blocksNavigation(TutorialRoutes.shop), isTrue);
      expect(ctrl.blocksNavigation(TutorialRoutes.dungeon), isTrue);
    });

    test('blocksNavigation allows dungeon on tap-dungeon step', () {
      final ProviderContainer container = makeContainer(
        progress: TutorialProgressState.initial(),
      );
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: TutorialProgressState.initial(),
          activeTrackId: TutorialTrackId.onboarding,
          activeStep: TutorialTrackRegistry.stepById(
            'onboarding_tap_dungeon_tab',
          ),
        ),
      );

      expect(ctrl.blocksNavigation(TutorialRoutes.dungeon), isFalse);
      expect(ctrl.blocksNavigation(TutorialRoutes.shop), isTrue);
    });

    test('allowsNavTab locks all tabs during onboarding narrative', () {
      final ProviderContainer container = makeContainer(
        progress: TutorialProgressState.initial(),
      );
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: TutorialProgressState.initial(),
          activeTrackId: TutorialTrackId.onboarding,
          activeStep:
              TutorialTrackRegistry.stepById('onboarding_welcome'),
        ),
      );

      expect(ctrl.allowsNavTab(2), isFalse);
      expect(ctrl.allowsNavTab(1), isFalse);
    });

    test('revealHeldDungeonWin null-safe when step missing', () async {
      final TutorialProgressState progress = TutorialProgressState.initial()
          .completeStep(
            trackId: TutorialTrackId.dungeon,
            stepId: 'dungeon_intro',
          )
          .completeStep(
            trackId: TutorialTrackId.dungeon,
            stepId: 'dungeon_pick_zone',
          )
          .completeStep(
            trackId: TutorialTrackId.dungeon,
            stepId: 'dungeon_enter_btn',
          );
      final ProviderContainer container = makeContainer(progress: progress);
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: progress,
          activeTrackId: TutorialTrackId.dungeon,
          activeStep: TutorialTrackRegistry.stepById('dungeon_confirm_enter'),
        ),
      );
      ctrl.debugSetLastRoute(TutorialRoutes.dungeon);
      await ctrl.onAnchorTap(TutorialAnchorId.dungeonConfirmOk);

      final bool revealed = await ctrl.revealHeldDungeonWin();
      expect(revealed, isTrue);
      expect(
        container.read(tutorialProvider).activeStep?.id,
        'dungeon_first_win',
      );
    });

    test('completeActiveManual ignored for enhance_equip onGameEvent',
        () async {
      final TutorialProgressState progress = TutorialProgressState.initial()
          .completeStep(
            trackId: TutorialTrackId.enhancement,
            stepId: 'enhance_open_item',
          );
      final ProviderContainer container = makeContainer(progress: progress);
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: progress,
          activeTrackId: TutorialTrackId.enhancement,
          activeStep: TutorialTrackRegistry.stepById('enhance_equip'),
        ),
      );

      await ctrl.completeActiveManual();

      expect(
        container.read(tutorialProvider).activeStep?.id,
        'enhance_equip',
      );
    });

    test('enhance forge completes on enhancementAttempt not tap', () async {
      final TutorialProgressState progress = TutorialProgressState.initial()
          .completeStep(
            trackId: TutorialTrackId.enhancement,
            stepId: 'enhance_pick_item',
          );
      final ProviderContainer container = makeContainer(progress: progress);
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: progress,
          activeTrackId: TutorialTrackId.enhancement,
          activeStep: TutorialTrackRegistry.stepById('enhance_tap_forge'),
        ),
      );
      ctrl.debugSetLastRoute(TutorialRoutes.enhancement);

      await ctrl.onAnchorTap(TutorialAnchorId.enhanceForgeBtn);
      expect(
        container.read(tutorialProvider).activeStep?.id,
        'enhance_tap_forge',
      );

      await ctrl.onGameEvent(TutorialGameEvent.enhancementAttempt);
      expect(
        container.read(tutorialProvider).activeStep?.id,
        'enhance_result',
      );
      expect(
        container
            .read(tutorialProvider)
            .progress
            .stepsForTrack(TutorialTrackId.enhancement),
        contains('enhance_tap_forge'),
      );
    });

    test('enhance forge Devam bypass when forceShowManualCta', () async {
      final TutorialProgressState progress = TutorialProgressState.initial()
          .completeStep(
            trackId: TutorialTrackId.enhancement,
            stepId: 'enhance_pick_item',
          );
      final ProviderContainer container = makeContainer(progress: progress);
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: progress,
          activeTrackId: TutorialTrackId.enhancement,
          activeStep: TutorialTrackRegistry.stepById('enhance_tap_forge'),
          forceShowManualCta: true,
          coachBodyOverride: 'bypass',
        ),
      );
      ctrl.debugSetLastRoute(TutorialRoutes.enhancement);

      await ctrl.completeActiveManual();

      expect(
        container.read(tutorialProvider).activeStep?.id,
        'enhance_result',
      );
      expect(
        container.read(tutorialProvider).forceShowManualCta,
        isFalse,
      );
    });

    test('enhance_open_item Devam bypass advances to equip', () async {
      TutorialProgressState progress = TutorialProgressState.initial();
      for (final String id in <String>[
        'enhance_pick_item',
        'enhance_tap_forge',
        'enhance_result',
        'enhance_to_inventory',
      ]) {
        progress = progress.completeStep(
          trackId: TutorialTrackId.enhancement,
          stepId: id,
        );
      }
      final ProviderContainer container = makeContainer(progress: progress);
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: progress,
          activeTrackId: TutorialTrackId.enhancement,
          activeStep: TutorialTrackRegistry.stepById('enhance_open_item'),
          forceShowManualCta: true,
          coachBodyOverride: 'no equip',
        ),
      );
      ctrl.debugSetLastRoute(TutorialRoutes.inventory);

      await ctrl.completeActiveManual();

      expect(
        container.read(tutorialProvider).activeStep?.id,
        'enhance_equip',
      );
    });

    test('cancelHeldDungeonWin keeps hold for retry after loss', () async {
      final TutorialProgressState progress = TutorialProgressState.initial()
          .completeStep(
            trackId: TutorialTrackId.dungeon,
            stepId: 'dungeon_intro',
          )
          .completeStep(
            trackId: TutorialTrackId.dungeon,
            stepId: 'dungeon_pick_zone',
          )
          .completeStep(
            trackId: TutorialTrackId.dungeon,
            stepId: 'dungeon_enter_btn',
          );
      final ProviderContainer container = makeContainer(progress: progress);
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: progress,
          activeTrackId: TutorialTrackId.dungeon,
          activeStep: TutorialTrackRegistry.stepById('dungeon_confirm_enter'),
        ),
      );
      ctrl.debugSetLastRoute(TutorialRoutes.dungeon);

      await ctrl.onAnchorTap(TutorialAnchorId.dungeonConfirmOk);
      expect(container.read(tutorialProvider).activeStep, isNull);

      ctrl.cancelHeldDungeonWin();

      final bool revealed = await ctrl.revealHeldDungeonWin();
      expect(revealed, isTrue);
      expect(
        container.read(tutorialProvider).activeStep?.id,
        'dungeon_first_win',
      );
    });

    test('step CTA flags: manual vs tap vs game event', () {
      final TutorialStepV2 welcome =
          TutorialTrackRegistry.stepById('onboarding_welcome')!;
      final TutorialStepV2 dungeonTab =
          TutorialTrackRegistry.stepById('onboarding_tap_dungeon_tab')!;
      final TutorialStepV2 equip =
          TutorialTrackRegistry.stepById('enhance_equip')!;
      final TutorialStepV2 forge =
          TutorialTrackRegistry.stepById('enhance_tap_forge')!;
      final TutorialStepV2 result =
          TutorialTrackRegistry.stepById('enhance_result')!;

      expect(welcome.showsManualCta, isTrue);
      expect(dungeonTab.requiresTargetTap, isTrue);
      expect(dungeonTab.showsManualCta, isFalse);
      expect(equip.waitsForGameEvent, isTrue);
      expect(equip.showsManualCta, isFalse);
      expect(forge.waitsForGameEvent, isTrue);
      expect(forge.showsManualCta, isFalse);
      expect(result.showsManualCta, isTrue);
      expect(result.mode, TutorialMode.narrative);
    });

    test('resetAndReplay starts onboarding unpaused as if on home', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ProviderContainer container = makeContainer();
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetLastRoute('/settings');
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: TutorialProgressState.initial()
              .completeTrack(TutorialTrackId.onboarding)
              .completeTrack(TutorialTrackId.dungeon),
          activeTrackId: TutorialTrackId.dungeon,
          activeStep: TutorialTrackRegistry.stepById('dungeon_intro'),
          overlayPaused: true,
        ),
      );

      await ctrl.resetAndReplay();

      final TutorialState after = container.read(tutorialProvider);
      expect(ctrl.debugLastRoute, TutorialRoutes.home);
      expect(after.overlayPaused, isFalse);
      expect(after.activeTrackId, TutorialTrackId.onboarding);
      expect(after.activeStep?.id, 'onboarding_welcome');
      expect(after.progress.completedTracks, isEmpty);
      expect(after.progress.skippedAll, isFalse);
      expect(after.coachEpoch, greaterThan(0));
    });

    test('resumeFromProgress keeps progress and opens next core step', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ProviderContainer container = makeContainer();
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      ctrl.debugSetLastRoute('/settings');
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: TutorialProgressState.initial()
              .completeTrack(TutorialTrackId.onboarding)
              .completeTrack(TutorialTrackId.dungeon)
              .completeTrack(TutorialTrackId.inventory),
          // Mid enhancement — already upgraded in game; do NOT wipe.
          activeTrackId: null,
          activeStep: null,
        ),
      );

      final String? route = await ctrl.resumeFromProgress();

      final TutorialState after = container.read(tutorialProvider);
      expect(after.progress.isTrackComplete(TutorialTrackId.onboarding), isTrue);
      expect(after.progress.isTrackComplete(TutorialTrackId.dungeon), isTrue);
      expect(after.progress.isTrackComplete(TutorialTrackId.inventory), isTrue);
      expect(after.activeTrackId, TutorialTrackId.enhancement);
      expect(after.activeStep?.id, 'enhance_pick_item');
      expect(after.overlayPaused, isFalse);
      expect(route, isNotNull);
    });
  });
}
