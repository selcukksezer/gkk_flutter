import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/dungeon_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/screens/dungeon/dungeon_battle_profiles.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_cave_theme.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_mob_pack_rig.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_stage_combat_view.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/featured_cave_dungeon_card.dart';
import 'package:gkk_flutter/utils/item_icon_resolver.dart';

void main() {
  group('Asset Pipeline & Multi-Mob 60 FPS Dungeon Overhaul', () {
    test('all 48 weapon icons are transparent PNGs and normalizeAssetPath rewrites legacy JPEGs', () {
      final Directory wpnDir = Directory('assets/items/weapons');
      expect(wpnDir.existsSync(), isTrue);

      final List<File> pngs = wpnDir
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.toLowerCase().endsWith('.png'))
          .toList();
      final List<File> jpegs = wpnDir
          .listSync()
          .whereType<File>()
          .where((File f) =>
              f.path.toLowerCase().endsWith('.jpeg') ||
              f.path.toLowerCase().endsWith('.jpg'))
          .toList();

      expect(pngs.length, greaterThanOrEqualTo(48));
      expect(jpegs, isEmpty);

      expect(
        ItemIconResolver.normalizeAssetPath(
          'assets/items/weapons/wpn_sword_common.jpeg',
        ),
        'assets/items/weapons/wpn_sword_common.png',
      );
      expect(
        ItemIconResolver.normalizeAssetPath(
          'items/weapons/wpn_dagger_mythic.jpg',
        ),
        'assets/items/weapons/wpn_dagger_mythic.png',
      );
    });

    test('resolveDungeonMobPack generates 3-5 valid monsters for all 65 dungeons', () {
      for (final DungeonBattleProfile profile in kAllDungeonBattleProfiles) {
        final List<DungeonMobPackMember> pack = resolveDungeonMobPack(profile);

        if (profile.isBoss) {
          expect(pack.length, 5,
              reason: 'Boss dungeon #${profile.dungeonNumber} should spawn 5-mob boss pack');
        } else if (profile.dungeonNumber <= 2) {
          expect(pack.length, 3,
              reason: 'Early dungeon #${profile.dungeonNumber} should spawn 3-mob pack');
        } else {
          expect(pack.length, 4,
              reason: 'Standard dungeon #${profile.dungeonNumber} should spawn 4-mob pack');
        }

        expect(pack.last.isLeader, isTrue);
        expect(pack.last.name, profile.enemyName);

        for (final DungeonMobPackMember mob in pack) {
          final File f = File(mob.spriteAsset);
          expect(f.existsSync(), isTrue,
              reason: 'Missing pack sprite ${mob.spriteAsset} in #${profile.dungeonNumber}');
        }
      }

      // Species lairs must spawn lore-authentic brood packmates (no goblins in spider nest)
      final List<DungeonMobPackMember> wolfPack =
          resolveDungeonMobPack(DungeonBattleProfile.forNumber(1));
      expect(
        wolfPack.every(
          (DungeonMobPackMember m) => m.spriteAsset.contains('mob_dire_wolf'),
        ),
        isTrue,
      );

      final List<DungeonMobPackMember> spiderPack =
          resolveDungeonMobPack(DungeonBattleProfile.forNumber(2));
      expect(
        spiderPack.every(
          (DungeonMobPackMember m) =>
              m.spriteAsset.contains('mob_venom_spider'),
        ),
        isTrue,
      );
    });

    testWidgets('DungeonStageCombatView renders multi-mob pack at 390x844 mobile across all phases with zero overflows',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final DungeonBattleProfile bossProfile =
          DungeonBattleProfile.forNumber(10); // Boss pack (5 mobs)

      for (final DungeonStagePhase phase in DungeonStagePhase.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(390, 844)),
              child: Scaffold(
                body: _MobilePackStageHarness(
                  profile: bossProfile,
                  phase: phase,
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 250));
        if (phase == DungeonStagePhase.fighting) {
          // Advance across multiple beats including vanguard soul-shatter & Boss climax!
          await tester.pump(const Duration(milliseconds: 2400));
          expect(find.textContaining('/5'), findsWidgets);
          await tester.pump(const Duration(milliseconds: 3800));
        }

        expect(find.textContaining(bossProfile.enemyName), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('FeaturedCaveDungeonCard renders multi-mob pack diorama & badge cleanly on 375x812 phone',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const DungeonData sampleDungeon = DungeonData(
        id: '10',
        dungeonId: 'dng_010',
        name: 'Orman Efendisi İni',
        description: '',
        difficulty: 'boss',
        requiredLevel: 8,
        maxPlayers: 1,
        energyCost: 15,
        minGold: 2400,
        maxGold: 5200,
        lootTable: <String>[],
        isGroup: false,
        powerRequirement: 18500,
        zone: 1,
        isBoss: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(375, 812)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: FeaturedCaveDungeonCard(
                  dungeon: sampleDungeon,
                  theme: CaveCardTheme.forDungeonNumber(10) ?? CaveCardTheme.cyberCave,
                  zoneIcon: Icons.forest_rounded,
                  zoneLabel: 'GÖLGELİ ORMAN',
                  zoneColor: const Color(0xFF10B981),
                  canEnter: true,
                  inHospital: false,
                  inPrison: false,
                  entering: false,
                  successPercent: 78,
                  energyCost: 15,
                  minGold: 2400,
                  maxGold: 5200,
                  powerRequirement: 18500,
                  playerPower: 21000,
                  onEnter: () {},
                  onLoot: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('SÜRÜ: 5 DÜŞMAN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _MobilePackStageHarness extends StatefulWidget {
  const _MobilePackStageHarness({
    required this.profile,
    required this.phase,
  });

  final DungeonBattleProfile profile;
  final DungeonStagePhase phase;

  @override
  State<_MobilePackStageHarness> createState() =>
      _MobilePackStageHarnessState();
}

class _MobilePackStageHarnessState extends State<_MobilePackStageHarness>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..value = 0.35;

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DungeonStageCombatView(
        profile: widget.profile,
        stagePhase: widget.phase,
        ambient: _ambient,
        characterAsset: 'assets/dungeon/hero_battle_warrior.png',
        characterClass: CharacterClass.warrior,
        playerName: 'MobilKahraman',
        playerLevel: 28,
        playerPower: 42000,
        powerRequirement: 36000,
        fullscreen: true,
        hudTopInset: 48,
      ),
    );
  }
}
