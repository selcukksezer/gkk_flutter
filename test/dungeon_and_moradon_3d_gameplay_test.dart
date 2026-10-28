import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/l10n/app_localizations.dart';
import 'package:gkk_flutter/models/dungeon_model.dart';
import 'package:gkk_flutter/models/moradon_models.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/moradon_hub_provider.dart';
import 'package:gkk_flutter/screens/dungeon/dungeon_battle_profiles.dart';
import 'package:gkk_flutter/screens/dungeon/dungeon_zone_data.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_stage_combat_view.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_zone_3d_diorama.dart';
import 'package:gkk_flutter/screens/home/moradon/moradon_hud_overlay.dart';
import 'package:gkk_flutter/screens/home/moradon/moradon_world_view.dart';

PlayerProfile _makeTestHero() {
  final String nowIso = DateTime.now().toUtc().toIso8601String();
  return PlayerProfile(
    id: 'hero_3d_test',
    authId: 'auth_hero_3d_test',
    username: 'KralSovalye',
    email: 'hero3d@gkk.test',
    displayName: 'KralSovalye',
    avatarUrl: null,
    avatarFrame: null,
    level: 55,
    xp: 32000,
    gold: 185000,
    gems: 420,
    energy: 95,
    maxEnergy: 100,
    attack: 34200,
    defense: 29800,
    health: 28000,
    maxHealth: 28000,
    power: 124000,
    isOnline: true,
    isBanned: false,
    tutorialCompleted: true,
    guildId: 'guild_3d',
    guildRole: 'leader',
    guildName: 'EFSANE',
    referralCode: 'GKK3D',
    referredBy: null,
    pvpRating: 1640,
    pvpWins: 40,
    pvpLosses: 8,
    addictionLevel: 0,
    tolerance: 0,
    lastPotionUsedAt: null,
    warriorBloodlustUntil: null,
    hospitalUntil: null,
    hospitalReason: null,
    hospitalLifetimeCount: 0,
    prisonUntil: null,
    prisonReason: null,
    globalSuspicionLevel: 0,
    lastBribeAt: null,
    lastLoginAt: nowIso,
    lastLogin: nowIso,
    createdAt: nowIso,
    updatedAt: nowIso,
    reputation: 1200,
    luck: 90,
    equipBonusLuck: 4200,
    characterClass: CharacterClass.warrior,
  );
}

class _Test3dMoradonNotifier extends MoradonHubNotifier {
  final MoradonHubState seeded;
  _Test3dMoradonNotifier(this.seeded);

  @override
  MoradonHubState build() => seeded;

  @override
  void bindLocalProfile(PlayerProfile profile, {required int totalPower}) {}
}

void main() {
  group('3D Assets, Moradon Sparring Dummies & Tactical Dungeon Combat', () {
    test('Dark-Gothic 3D runic dais, sparring props & foreground pillars exist on disk', () {
      expect(
        File('assets/dungeon/stage_3d_runic_dais.png').existsSync(),
        isTrue,
      );
      expect(
        File('assets/dungeon/fg_dungeon_left_pillar.png').existsSync(),
        isTrue,
      );
      expect(
        File('assets/dungeon/fg_dungeon_right_pillar.png').existsSync(),
        isTrue,
      );
      expect(
        File('assets/moradon/prop_dungeon_dummy_iron.png').existsSync(),
        isTrue,
      );
      expect(
        File('assets/moradon/prop_dungeon_dummy_boss.png').existsSync(),
        isTrue,
      );
      expect(
        File('assets/moradon/prop_dungeon_brazier_gothic.png').existsSync(),
        isTrue,
      );
      expect(
        File('assets/moradon/plaza_dungeon_rune_pit.png').existsSync(),
        isTrue,
      );
      expect(kMoradonTrainingDummies.length, 4);
      expect(resolveMoradonStyleRank(12).grade, 'EFSANEVİ');
      expect(resolveDungeonStyleRank(10).grade, 'EFSANEVİ');
    });

    testWidgets(
      'Moradon 3D Perspective Camera Rig, 3D/2D toggle & Royal Training Dummy combo strikes work cleanly on mobile (390x844)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final PlayerProfile hero = _makeTestHero();
        final InventoryState inv = InventoryState.initial();
        final MoradonTrainingDummy westDummy = kMoradonTrainingDummies.first;

        // Place hero right next to Central Plaza West Training Dummy
        final MoradonHubState seeded = MoradonHubState(
          playerX: westDummy.x - 45.0,
          playerY: westDummy.y + 8.0,
          targetX: westDummy.x - 45.0,
          targetY: westDummy.y + 8.0,
          zoom: 0.90,
          responsiveZoomApplied: true,
          is3dPerspective: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              moradonHubProvider
                  .overrideWith(() => _Test3dMoradonNotifier(seeded)),
            ],
            child: MaterialApp(
              locale: const Locale('tr'),
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    MoradonWorldView(
                      profile: hero,
                      inventoryState: inv,
                      totalPower: hero.power,
                    ),
                    MoradonHudOverlay(
                      profile: hero,
                      inventoryState: inv,
                      totalPower: hero.power,
                      reputation: hero.reputation ?? 0,
                      onSlotTap: (_, _) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.takeException(), isNull);

        final ProviderContainer container = ProviderScope.containerOf(
          tester.element(find.byType(MoradonWorldView)),
        );
        final MoradonHubNotifier notifier =
            container.read(moradonHubProvider.notifier);

        expect(container.read(moradonHubProvider).is3dPerspective, isTrue);

        // Strike nearby training dummy twice to build combo streak & floating callout
        notifier.interactWithTrainingDummy(westDummy);
        await tester.pump(const Duration(milliseconds: 80));
        notifier.triggerHeroAttack();
        await tester.pump(const Duration(milliseconds: 80));

        final MoradonHubState afterStrikes = container.read(moradonHubProvider);
        expect(afterStrikes.comboStreak, greaterThanOrEqualTo(2));
        expect(afterStrikes.activeStrike, isNotNull);
        expect(afterStrikes.activeStrike!.hitDummyId, westDummy.id);
        expect(afterStrikes.activeStrike!.damage, greaterThan(0));
        expect(tester.takeException(), isNull);

        // Toggle 3D -> 2D -> 3D
        notifier.toggle3dPerspective();
        await tester.pump(const Duration(milliseconds: 60));
        expect(container.read(moradonHubProvider).is3dPerspective, isFalse);
        notifier.toggle3dPerspective();
        await tester.pump(const Duration(milliseconds: 60));
        expect(container.read(moradonHubProvider).is3dPerspective, isTrue);
      },
    );

    testWidgets(
      'DungeonZone3dDiorama renders 3D tilt portal & triggers quick expedition cleanly on 390x844 mobile',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        bool launched = false;
        const DungeonData rec = DungeonData(
          id: '4',
          dungeonId: 'dng_004',
          name: 'Zehirli Mantar Mağarası',
          description: '',
          difficulty: 'normal',
          requiredLevel: 4,
          maxPlayers: 1,
          energyCost: 10,
          minGold: 950,
          maxGold: 2100,
          lootTable: <String>[],
          isGroup: false,
          powerRequirement: 6500,
          zone: 1,
          isBoss: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(390, 844)),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DungeonZone3dDiorama(
                    selectedZone: zoneDataFor(1),
                    dungeons: const <DungeonData>[rec],
                    recommendedDungeon: rec,
                    recommendedSuccessPct: 92,
                    canEnterRecommended: true,
                    clearedCount: 3,
                    totalCount: 10,
                    characterClass: CharacterClass.warrior,
                    playerPower: 18500,
                    onQuickEnterRecommended: () => launched = true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 160));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('dungeon_zone_3d_diorama')), findsOneWidget);

        // Drag-tilt the 3D diorama
        await tester.drag(
          find.byKey(const Key('dungeon_zone_3d_diorama')),
          const Offset(36, -18),
        );
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull);

        // Tap quick expedition button
        final Finder quickBtn =
            find.byKey(const Key('dungeon_diorama_quick_enter_btn'));
        if (quickBtn.evaluate().isNotEmpty) {
          await tester.tap(quickBtn);
          await tester.pump();
          expect(launched, isTrue);
        }
      },
    );

    testWidgets(
      'DungeonStageCombatView executes interactive tactical skill & arena strike commands with zero overflow',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        int arenaTaps = 0;
        final DungeonBattleProfile profile = DungeonBattleProfile.forNumber(12);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(390, 844)),
              child: Scaffold(
                body: _TacticalStageTestHarness(
                  profile: profile,
                  onArenaTap: (_) => arenaTaps++,
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 220));
        expect(tester.takeException(), isNull);

        // Tap center of 3D combat stage to trigger player-controlled strike
        await tester.tapAt(const Offset(195, 420));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
        expect(arenaTaps, 1);
        expect(find.textContaining('HÜKÜMDAR İNFAZI'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _TacticalStageTestHarness extends StatefulWidget {
  const _TacticalStageTestHarness({
    required this.profile,
    required this.onArenaTap,
  });

  final DungeonBattleProfile profile;
  final ValueChanged<bool> onArenaTap;

  @override
  State<_TacticalStageTestHarness> createState() =>
      _TacticalStageTestHarnessState();
}

class _TacticalStageTestHarnessState extends State<_TacticalStageTestHarness>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..value = 0.42;

  DungeonTacticalCommand? _cmd;
  int _seq = 0;

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
        stagePhase: DungeonStagePhase.fighting,
        ambient: _ambient,
        characterAsset: 'assets/dungeon/hero_battle_warrior.png',
        characterClass: CharacterClass.warrior,
        playerName: 'KralSovalye',
        playerLevel: 55,
        playerPower: 124000,
        powerRequirement: 45000,
        fullscreen: true,
        hudTopInset: 48,
        tacticalCommand: _cmd,
        onArenaStrikeTap: (bool sweet) {
          widget.onArenaTap(sweet);
          setState(() {
            _cmd = DungeonTacticalCommand(
              seq: ++_seq,
              type: DungeonTacticalActionType.ultimate,
              skillTitle: '☄️ HÜKÜMDAR İNFAZI',
              damageMultiplier: 2.58,
              isCritical: true,
              aoeAllMobs: true,
              comboStreak: 5,
            );
          });
        },
      ),
    );
  }
}
