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

    test('season L20 step gated by playerLevel < 18', () {
      final Set<String> prior = <String>{
        'season_intro',
        'season_bpp',
        'season_quests_tab',
      };
      final List<TutorialStepV2> low = TutorialTrackRegistry.eligibleSteps(
        trackId: TutorialTrackId.season,
        completedStepIds: prior,
        playerLevel: 10,
      );
      expect(low.any((TutorialStepV2 s) => s.id == 'season_l20_badge'), isFalse);

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

    test('coreCompleted requires enhancement track', () {
      expect(
        TutorialTrackId.coreTracks,
        containsAll(<String>[
          TutorialTrackId.onboarding,
          TutorialTrackId.dungeon,
          TutorialTrackId.inventory,
          TutorialTrackId.character,
          TutorialTrackId.enhancement,
        ]),
      );
      expect(TutorialTrackRegistry.stepById('enhance_season_cta'), isNotNull);
      expect(TutorialTrackRegistry.stepById('inventory_to_character'), isNotNull);
    });

    test('daily chain track registered', () {
      final TutorialTrack? daily =
          TutorialTrackRegistry.trackById(TutorialTrackId.dailyChain);
      expect(daily, isNotNull);
      expect(daily!.steps.length, 7);
    });
  });
}
