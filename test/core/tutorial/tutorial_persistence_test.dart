import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_persistence.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track.dart';

void main() {
  group('TutorialProgressState v2', () {
    test('completeTrack marks core when core tracks done', () {
      TutorialProgressState state = TutorialProgressState.initial();
      for (final String id in TutorialTrackId.coreTracks) {
        state = state.completeTrack(id);
      }
      expect(state.coreCompleted, isTrue);
      expect(state.coreCompletedAt, isNotNull);
      expect(state.toJson()['core_completed'], isTrue);
    });

    test('completeStep then completeTrack accumulates steps', () {
      TutorialProgressState state = TutorialProgressState.initial()
          .completeStep(
            trackId: TutorialTrackId.onboarding,
            stepId: 'onboarding_welcome',
          )
          .completeStep(
            trackId: TutorialTrackId.onboarding,
            stepId: 'onboarding_hud_energy',
          );
      expect(
        state.stepsForTrack(TutorialTrackId.onboarding),
        containsAll(<String>['onboarding_welcome', 'onboarding_hud_energy']),
      );
      expect(state.isTrackComplete(TutorialTrackId.onboarding), isFalse);

      state = state.completeTrack(TutorialTrackId.onboarding);
      expect(state.isTrackComplete(TutorialTrackId.onboarding), isTrue);
    });

    test('mergeServer unions completed_tracks and steps', () {
      final TutorialProgressState local = TutorialProgressState(
        version: 2,
        completedTracks: <String>{TutorialTrackId.onboarding},
        stepsByTrack: <String, Set<String>>{
          TutorialTrackId.onboarding: <String>{'onboarding_welcome'},
        },
        skippedAll: false,
      );
      final TutorialProgressState merged = local.mergeServer(
        <String, dynamic>{
          'completed_tracks': <String>[TutorialTrackId.dungeon],
          'steps': <String, dynamic>{
            TutorialTrackId.dungeon: <String>['dungeon_pick_zone'],
          },
        },
        tutorialCompleted: false,
      );
      expect(
        merged.completedTracks,
        containsAll(<String>[
          TutorialTrackId.onboarding,
          TutorialTrackId.dungeon,
        ]),
      );
      expect(
        merged.stepsForTrack(TutorialTrackId.dungeon),
        contains('dungeon_pick_zone'),
      );
    });

    test('mergeServer migrates v1 completed_steps', () {
      final TutorialProgressState local = TutorialProgressState.initial();
      final TutorialProgressState merged = local.mergeServer(
        <String, dynamic>{
          'completed_steps': <String>[
            'onboarding_welcome',
            'onboarding_game_loop',
            'onboarding_home_promo',
            'onboarding_home_hero',
            'onboarding_hud_energy',
            'onboarding_hud_gold',
            'onboarding_hud_gems',
            'onboarding_nav_intro',
            'onboarding_tap_dungeon_tab',
          ],
        },
        tutorialCompleted: false,
      );
      expect(
        merged.stepsForTrack(TutorialTrackId.onboarding).length,
        greaterThanOrEqualTo(9),
      );
      expect(merged.isTrackComplete(TutorialTrackId.onboarding), isTrue);
    });

    test('toJson round-trip preserves tracks', () {
      final TutorialProgressState original = TutorialProgressState.initial()
          .completeStep(
            trackId: TutorialTrackId.inventory,
            stepId: 'inventory_first_item',
          )
          .completeTrack(TutorialTrackId.onboarding);
      final TutorialProgressState restored = TutorialProgressState.fromJson(
        original.toJson(),
      );
      expect(restored.completedTracks, original.completedTracks);
      expect(
        restored.stepsForTrack(TutorialTrackId.inventory),
        original.stepsForTrack(TutorialTrackId.inventory),
      );
      expect(restored.version, 3);
    });

    test('skipAll sets skipped flag and all tracks', () {
      final TutorialProgressState skipped =
          TutorialProgressState.initial().skipAll();
      expect(skipped.skippedAll, isTrue);
      expect(skipped.isTrackComplete(TutorialTrackId.season), isTrue);
    });
  });
}
