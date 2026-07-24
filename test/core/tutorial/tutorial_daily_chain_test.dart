import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_step.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track_registry.dart';

void main() {
  group('D1–D7 daily chain', () {
    test('daily chain track has 7 ordered steps', () {
      final TutorialTrack? track =
          TutorialTrackRegistry.trackById(TutorialTrackId.dailyChain);
      expect(track, isNotNull);
      expect(track!.steps.length, 7);
      expect(
        track.steps.map((s) => s.id).toList(),
        TutorialTrackId.dailyChainStepIds,
      );
    });

    test('eligible steps unlock sequentially', () {
      expect(
        TutorialTrackRegistry.eligibleSteps(
          trackId: TutorialTrackId.dailyChain,
          completedStepIds: <String>{},
        ).first.id,
        'daily_d1_dungeon',
      );

      final List<TutorialStepV2> afterD3 = TutorialTrackRegistry.eligibleSteps(
        trackId: TutorialTrackId.dailyChain,
        completedStepIds: <String>{
          'daily_d1_dungeon',
          'daily_d2_inventory',
          'daily_d3_craft',
        },
      );
      expect(afterD3.first.id, 'daily_d4_guild');
      expect(afterD3.first.allowedRoutes, contains(TutorialRoutes.guild));
    });

    test('D7 accepts siege hub or guild war routes', () {
      final List<TutorialStepV2> d7 = TutorialTrackRegistry.eligibleSteps(
        trackId: TutorialTrackId.dailyChain,
        completedStepIds: <String>{
          'daily_d1_dungeon',
          'daily_d2_inventory',
          'daily_d3_craft',
          'daily_d4_guild',
          'daily_d5_pvp',
          'daily_d6_market',
        },
      );
      expect(d7.first.id, 'daily_d7_siege');
      expect(d7.first.allowedRoutes, contains(TutorialRoutes.dungeonSiegeHub));
      expect(d7.first.allowedRoutes, contains(TutorialRoutes.guildWar));
    });
  });
}
