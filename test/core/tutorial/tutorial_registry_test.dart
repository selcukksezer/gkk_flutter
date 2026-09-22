import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_step.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track_registry.dart';

void main() {
  group('TutorialTrackRegistry', () {
    test('core tracks exist with steps', () {
      for (final String id in TutorialTrackId.coreTracks) {
        final TutorialTrack? track = TutorialTrackRegistry.trackById(id);
        expect(track, isNotNull, reason: 'missing track $id');
        expect(track!.steps, isNotEmpty);
      }
    });

    test('onboarding eligible steps respect prerequisites', () {
      final List<TutorialStepV2> first = TutorialTrackRegistry.eligibleSteps(
        trackId: TutorialTrackId.onboarding,
        completedStepIds: <String>{},
      );
      expect(first.first.id, 'onboarding_welcome');

      final List<TutorialStepV2> afterWelcome =
          TutorialTrackRegistry.eligibleSteps(
        trackId: TutorialTrackId.onboarding,
        completedStepIds: <String>{'onboarding_welcome'},
      );
      expect(afterWelcome.first.id, 'onboarding_game_loop');
    });

    test('season L20 step always eligible after quests (even L1)', () {
      final Set<String> prior = <String>{
        'season_intro',
        'season_bpp',
        'season_quests_tab',
      };
      final List<TutorialStepV2> low = TutorialTrackRegistry.eligibleSteps(
        trackId: TutorialTrackId.season,
        completedStepIds: prior,
        playerLevel: 1,
      );
      expect(low.any((TutorialStepV2 s) => s.id == 'season_l20_badge'), isTrue);

      final List<TutorialStepV2> high = TutorialTrackRegistry.eligibleSteps(
        trackId: TutorialTrackId.season,
        completedStepIds: prior,
        playerLevel: 18,
      );
      expect(high.any((TutorialStepV2 s) => s.id == 'season_l20_badge'), isTrue);
    });

    test('route map covers first-visit tracks', () {
      expect(
        TutorialRouteTracks.trackForRoute(TutorialRoutes.home),
        TutorialTrackId.onboarding,
      );
      expect(
        TutorialRouteTracks.trackForRoute(TutorialRoutes.season),
        TutorialTrackId.season,
      );
      expect(
        TutorialRouteTracks.trackForRoute(TutorialRoutes.dungeon),
        TutorialTrackId.dungeon,
      );
      expect(
        TutorialRouteTracks.trackForRoute(TutorialRoutes.crafting),
        TutorialTrackId.craft,
      );
      expect(
        TutorialRouteTracks.trackForRoute(TutorialRoutes.guild),
        TutorialTrackId.guild,
      );
      expect(
        TutorialRouteTracks.trackForRoute(TutorialRoutes.pvp),
        TutorialTrackId.pvp,
      );
      expect(
        TutorialRouteTracks.trackForRoute(TutorialRoutes.horseRace),
        TutorialTrackId.horseRace,
      );
      expect(
        TutorialRouteTracks.trackForRoute(TutorialRoutes.mekans),
        TutorialTrackId.mekans,
      );
      expect(TutorialRouteTracks.trackForRoute('/unknown'), isNull);
    });

    test('coreCompleted requires enhancement + season + hospital + prison', () {
      expect(
        TutorialTrackId.coreTracks,
        containsAll(<String>[
          TutorialTrackId.onboarding,
          TutorialTrackId.dungeon,
          TutorialTrackId.inventory,
          TutorialTrackId.character,
          TutorialTrackId.enhancement,
          TutorialTrackId.season,
          TutorialTrackId.hospital,
          TutorialTrackId.prison,
        ]),
      );
      expect(TutorialTrackRegistry.stepById('enhance_to_inventory'), isNotNull);
      expect(TutorialTrackRegistry.stepById('enhance_equip'), isNotNull);
      expect(TutorialTrackRegistry.stepById('character_tap_season'), isNotNull);
      expect(TutorialTrackRegistry.stepById('inventory_tap_enhance'), isNotNull);
      expect(TutorialTrackRegistry.stepById('season_reset_warn'), isNotNull);
      expect(TutorialTrackRegistry.stepById('season_to_hospital'), isNotNull);
      expect(TutorialTrackRegistry.stepById('hospital_to_prison'), isNotNull);
      expect(TutorialTrackRegistry.stepById('prison_core_done'), isNotNull);
      expect(TutorialTrackRegistry.stepById('season_core_done'), isNull);
    });

    test('season continues after L20 (no silent coach death)', () {
      final Set<String> prior = <String>{
        'season_intro',
        'season_bpp',
        'season_quests_tab',
        'season_l20_badge',
      };
      final List<TutorialStepV2> afterL20 =
          TutorialTrackRegistry.eligibleSteps(
        trackId: TutorialTrackId.season,
        completedStepIds: prior,
        playerLevel: 1,
      );
      expect(afterL20, isNotEmpty);
      expect(afterL20.first.id, 'season_reset_warn');

      prior.add('season_reset_warn');
      final List<TutorialStepV2> afterWarn =
          TutorialTrackRegistry.eligibleSteps(
        trackId: TutorialTrackId.season,
        completedStepIds: prior,
      );
      expect(afterWarn.first.id, 'season_to_hospital');
      expect(
        afterWarn.first.navigateToRoute,
        TutorialRoutes.hospital,
      );
    });

    test('core path walks end-to-end without mid empty eligible', () {
      final List<String> walked = <String>[];
      for (final String trackId in TutorialTrackId.coreTracks) {
        final Set<String> done = <String>{};
        int guard = 0;
        while (guard++ < 80) {
          final List<TutorialStepV2> eligible =
              TutorialTrackRegistry.eligibleSteps(
            trackId: trackId,
            completedStepIds: done,
            playerLevel: 1,
            homeLive: true,
          );
          if (eligible.isEmpty) break;
          walked.add(eligible.first.id);
          done.add(eligible.first.id);
        }
        final TutorialTrack track = TutorialTrackRegistry.trackById(trackId)!;
        expect(
          done.length,
          track.steps.length,
          reason: 'core track $trackId unreachable mid-path; walked=$walked',
        );
      }
      expect(walked.last, 'prison_core_done');
      expect(walked, contains('season_l20_badge'));
      expect(walked, contains('season_reset_warn'));
      expect(walked, contains('season_to_hospital'));
      expect(walked, contains('hospital_to_prison'));
    });

    test('character_tap_season navigates to season', () {
      final TutorialStepV2? step =
          TutorialTrackRegistry.stepById('character_tap_season');
      expect(step?.navigateToRoute, TutorialRoutes.season);
      expect(step?.autoNavigateWhenPaused, isTrue);
    });

    test('daily chain track registered', () {
      final TutorialTrack? daily =
          TutorialTrackRegistry.trackById(TutorialTrackId.dailyChain);
      expect(daily, isNotNull);
      expect(daily!.steps.length, 7);
    });

    test('retention intro steps auto-navigate to target routes', () {
      final TutorialStepV2? codex = TutorialTrackRegistry.stepById('retention_codex');
      final TutorialStepV2? nemesis =
          TutorialTrackRegistry.stepById('retention_nemesis');
      final TutorialStepV2? night = TutorialTrackRegistry.stepById('retention_night');
      expect(codex?.autoNavigateWhenPaused, isTrue);
      expect(codex?.navigateToRoute, TutorialRoutes.character);
      expect(nemesis?.navigateToRoute, TutorialRoutes.pvp);
      expect(night?.navigateToRoute, '${TutorialRoutes.shop}?tab=night');
    });

    test('character stat panel highlights stat card with Devam', () {
      final TutorialStepV2? step =
          TutorialTrackRegistry.stepById('character_stat_panel');
      expect(step, isNotNull);
      expect(step!.mode, TutorialMode.highlightOnly);
      expect(step.completion, TutorialCompletion.onManualDismiss);
      expect(step.anchorId, TutorialAnchorId.characterStatPanel);
    });

    test('character class abilities highlights abilities section', () {
      final TutorialStepV2? step =
          TutorialTrackRegistry.stepById('character_class_abilities');
      expect(step, isNotNull);
      expect(step!.allowsBackgroundInteraction, isFalse);
      expect(step.mode, TutorialMode.highlightOnly);
      expect(step.anchorId, TutorialAnchorId.characterClassAbilities);
      expect(step.body, contains('pasif'));
    });

    test('inventory then enhance path (upgrade before equip)', () {
      final TutorialStepV2? openMenu =
          TutorialTrackRegistry.stepById('inventory_open_menu');
      final TutorialStepV2? tapEnhance =
          TutorialTrackRegistry.stepById('inventory_tap_enhance');
      expect(openMenu, isNotNull);
      expect(tapEnhance, isNotNull);
      expect(openMenu!.mode, TutorialMode.spotlightTap);
      expect(openMenu.anchorId, TutorialAnchorId.navMenuTab);
      expect(tapEnhance!.mode, TutorialMode.spotlightTap);
      expect(tapEnhance.anchorId, TutorialAnchorId.navMenuEnhancement);
      expect(tapEnhance.requiresPrior, contains('inventory_open_menu'));
    });

    test('enhance pick item targets inventory weapon tile', () {
      final TutorialStepV2? step =
          TutorialTrackRegistry.stepById('enhance_pick_item');
      expect(step, isNotNull);
      expect(step!.anchorId, TutorialAnchorId.enhanceInventoryWeapon);
      expect(step.body, isNot(contains('kuşandığın')));
    });

    test('equip happens after enhance_result', () {
      final TutorialStepV2? equip =
          TutorialTrackRegistry.stepById('enhance_equip');
      expect(equip, isNotNull);
      expect(equip!.requiresPrior, contains('enhance_open_item'));
      expect(equip.gameEvent, TutorialGameEvent.equipSuccess);
      expect(
        TutorialTrackRegistry.stepById('inventory_equip'),
        isNull,
      );
    });

    test('character ends at season not enhance', () {
      final TutorialStepV2? season =
          TutorialTrackRegistry.stepById('character_tap_season');
      expect(season, isNotNull);
      expect(season!.anchorId, TutorialAnchorId.navMenuSeason);
      expect(
        TutorialTrackRegistry.stepById('character_tap_enhance'),
        isNull,
      );
    });

    test('system tracks (facilities/trade/hospital/prison) registered', () {
      for (final String id in <String>[
        TutorialTrackId.facilities,
        TutorialTrackId.trade,
        TutorialTrackId.hospital,
        TutorialTrackId.prison,
      ]) {
        final TutorialTrack? track = TutorialTrackRegistry.trackById(id);
        expect(track, isNotNull, reason: 'missing track $id');
        expect(track!.steps, isNotEmpty);
      }
      expect(
        TutorialRouteTracks.trackForRoute(TutorialRoutes.facilities),
        TutorialTrackId.facilities,
      );
      expect(
        TutorialRouteTracks.trackForRoute(TutorialRoutes.trade),
        TutorialTrackId.trade,
      );
      expect(
        TutorialRouteTracks.trackForRoute(TutorialRoutes.hospital),
        TutorialTrackId.hospital,
      );
      expect(
        TutorialRouteTracks.trackForRoute(TutorialRoutes.prison),
        TutorialTrackId.prison,
      );
    });

    test('step ids are unique and priors reference existing steps', () {
      final Set<String> allIds = <String>{};
      for (final TutorialTrack track in TutorialTrackRegistry.tracks) {
        for (final TutorialStepV2 step in track.steps) {
          expect(allIds.add(step.id), isTrue,
              reason: 'duplicate step id ${step.id}');
          expect(step.trackId, track.id,
              reason: '${step.id} trackId mismatch');
        }
      }
      for (final TutorialTrack track in TutorialTrackRegistry.tracks) {
        for (final TutorialStepV2 step in track.steps) {
          for (final String prior in step.requiresPrior) {
            expect(allIds.contains(prior), isTrue,
                reason: '${step.id} requires unknown prior $prior');
          }
        }
      }
    });

    test('every track eventually completes (no dead-end priors)', () {
      for (final TutorialTrack track in TutorialTrackRegistry.tracks) {
        final Set<String> done = <String>{};
        int guard = 0;
        while (guard++ < 100) {
          final List<TutorialStepV2> eligible =
              TutorialTrackRegistry.eligibleSteps(
            trackId: track.id,
            completedStepIds: done,
            playerLevel: 99,
          );
          if (eligible.isEmpty) break;
          done.add(eligible.first.id);
        }
        expect(done.length, track.steps.length,
            reason: 'track ${track.id} has unreachable steps');
      }
    });
  });
}
