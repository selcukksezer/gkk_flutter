import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/screens/dungeon/dungeon_battle_profiles.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_arena_vfx.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_cave_theme.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_stage_combat_view.dart';

void main() {
  group('65-Dungeon Full-Screen AAA Visual & Identity Catalog', () {
    test('defines all 65 dungeons, combat-stance heroes, foreground pillars, and chamber themes', () {
      expect(kAllDungeonBattleProfiles.length, 65);

      for (final String sharedAsset in <String>[
        'assets/dungeon/hero_battle_warrior.png',
        'assets/dungeon/hero_battle_shadow.png',
        'assets/dungeon/hero_battle_alchemist.png',
        'assets/dungeon/fg_dungeon_left_pillar.png',
        'assets/dungeon/fg_dungeon_right_pillar.png',
        'assets/dungeon/vfx_sword_cleave_fire.png',
        'assets/dungeon/vfx_shadow_twin_slash.png',
        'assets/dungeon/vfx_arcane_alchemist_blast.png',
        'assets/dungeon/vfx_monster_savage_claw.png',
        'assets/dungeon/vfx_impact_shockwave.png',
      ]) {
        final File f = File(sharedAsset);
        expect(f.existsSync(), isTrue, reason: 'Missing shared asset: $sharedAsset');
        expect(f.lengthSync(), greaterThan(4096), reason: 'Empty shared asset: $sharedAsset');
      }

      final Set<String> enemyNames = <String>{};
      final Set<String> turkishTitles = <String>{};
      final Set<String> latinTitles = <String>{};
      final Set<String> quotes = <String>{};
      final Set<DungeonHudFrameStyle> usedFrames = <DungeonHudFrameStyle>{};
      final Set<DungeonWeatherVfxType> usedWeathers = <DungeonWeatherVfxType>{};

      const Set<int> expectedBosses = <int>{
        10, 20, 30, 40, 50, 60, 61, 62, 63, 64, 65,
      };

      for (int i = 0; i < 65; i++) {
        final int num = i + 1;
        final DungeonBattleProfile p =
            DungeonBattleProfile.forDungeonId('dng_${num.toString().padLeft(3, '0')}');

        expect(p.dungeonNumber, num);
        expect(enemyNames.add(p.enemyName), isTrue,
            reason: 'Duplicate enemyName at #$num: ${p.enemyName}');
        expect(turkishTitles.add(p.turkishTitle), isTrue,
            reason: 'Duplicate turkishTitle at #$num: ${p.turkishTitle}');
        expect(latinTitles.add(p.latinTitle), isTrue,
            reason: 'Duplicate latinTitle at #$num: ${p.latinTitle}');
        expect(quotes.add(p.introQuote), isTrue,
            reason: 'Duplicate introQuote at #$num');
        expect(p.clashLines.length, greaterThanOrEqualTo(3));
        expect(p.isBoss, expectedBosses.contains(num),
            reason: 'Boss flag mismatch at #$num');

        usedFrames.add(p.hudFrameStyle);
        usedWeathers.add(p.weatherVfx);

        for (final String assetPath in <String>[
          p.arenaAsset,
          p.enemySpriteAsset,
        ]) {
          final File f = File(assetPath);
          expect(f.existsSync(), isTrue,
              reason: 'Missing asset for dungeon #$num: $assetPath');
          expect(f.lengthSync(), greaterThan(4096),
              reason: 'Empty/corrupt asset for dungeon #$num: $assetPath');
        }

        // Ensure list card CaveCardTheme never uses legacy dungeonN.jpeg toy doors
        final CaveCardTheme? cardTheme = CaveCardTheme.forDungeonNumber(num);
        expect(cardTheme, isNotNull);
        expect(cardTheme!.assetPath.startsWith('assets/dungeon/arena_'), isTrue,
            reason: 'Dungeon #$num card theme still points to ${cardTheme.assetPath}');
      }

      expect(usedFrames.length, DungeonHudFrameStyle.values.length);
      expect(usedWeathers.length, DungeonWeatherVfxType.values.length);
    });

    testWidgets('renders full-screen 2.5D dungeon chamber cleanly across zones, classes & phases',
        (WidgetTester tester) async {
      final List<CharacterClass> classes = <CharacterClass>[
        CharacterClass.warrior,
        CharacterClass.shadow,
        CharacterClass.alchemist,
      ];

      int idx = 0;
      for (final int dngNum in <int>[1, 4, 12, 19, 26, 35, 46, 56, 65]) {
        final DungeonBattleProfile profile =
            DungeonBattleProfile.forNumber(dngNum);
        final CharacterClass cls = classes[idx % classes.length];
        idx++;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _FullscreenStageHarness(
                profile: profile,
                characterClass: cls,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.textContaining(profile.enemyName), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    });
  });
}

class _FullscreenStageHarness extends StatefulWidget {
  const _FullscreenStageHarness({
    required this.profile,
    required this.characterClass,
  });

  final DungeonBattleProfile profile;
  final CharacterClass characterClass;

  @override
  State<_FullscreenStageHarness> createState() =>
      _FullscreenStageHarnessState();
}

class _FullscreenStageHarnessState extends State<_FullscreenStageHarness>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..value = 0.42;

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: DungeonStageCombatView(
            profile: widget.profile,
            stagePhase: DungeonStagePhase.fighting,
            ambient: _ambient,
            characterAsset: 'assets/dungeon/hero_battle_warrior.png',
            characterClass: widget.characterClass,
            playerName: 'TestKahraman',
            playerLevel: 40,
            playerPower: 185000,
            powerRequirement: 158000,
            fullscreen: true,
            hudTopInset: 58,
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: DungeonOrnamentalPanel(
            style: widget.profile.hudFrameStyle,
            primary: widget.profile.primaryColor,
            secondary: widget.profile.secondaryColor,
            fillAlpha: 0.72,
            child: Text(widget.profile.introQuote),
          ),
        ),
      ],
    );
  }
}
