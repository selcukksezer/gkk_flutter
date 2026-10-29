import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/battle_pass.dart';
import 'package:gkk_flutter/providers/battle_pass_provider.dart';
import 'package:gkk_flutter/screens/season/widgets/season_banner_shader.dart';
import 'package:gkk_flutter/screens/season/widgets/season_quest_card.dart';
import 'package:gkk_flutter/screens/season/widgets/season_reward_illustrations.dart';
import 'package:gkk_flutter/screens/season/widgets/season_tier_track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummySeason = BpSeason(
    id: 'season_3',
    seasonNumber: 3,
    startAt: DateTime.now().subtract(const Duration(days: 5)),
    endAt: DateTime.now().add(const Duration(days: 25)),
    isActive: true,
    description: 'Daeva Uyanışı',
  );

  final dummyStatus = BpPlayerStatus(
    playerId: 'p1',
    seasonId: 'season_3',
    currentLevel: 10,
    currentBpp: 10450,
    dailyGrindBppPool: 150,
    dailyPvpBppPool: 100,
    hasVip: false,
    claimedNormal: <int>[1, 2, 3],
    claimedVip: <int>[],
    updatedAt: DateTime.now(),
  );

  final dummyRewards = <BpLevelReward>[
    const BpLevelReward(
      level: 1,
      normalRewardGold: 500,
      normalRewardItemId: null,
      normalRewardItem: null,
      normalRewardQuantity: 1,
      vipRewardGold: 1000,
      vipRewardItemId: null,
      vipRewardItem: null,
      vipRewardQuantity: 1,
    ),
    const BpLevelReward(
      level: 5,
      normalRewardGold: 0,
      normalRewardItemId: 'chest_diamond_01',
      normalRewardItem: <String, dynamic>{
        'name': 'Elmas Sandık',
        'rarity': 'epic',
        'icon': 'chest',
      },
      normalRewardQuantity: 1,
      vipRewardGold: 2000,
      vipRewardItemId: null,
      vipRewardItem: null,
      vipRewardQuantity: 1,
    ),
    const BpLevelReward(
      level: 10,
      normalRewardGold: 0,
      normalRewardItemId: 'dye_celestial_01',
      normalRewardItem: <String, dynamic>{
        'name': 'Gök Mavisi Boya Ampulü',
        'rarity': 'rare',
        'icon': 'potion',
      },
      normalRewardQuantity: 2,
      vipRewardGold: 5000,
      vipRewardItemId: null,
      vipRewardItem: null,
      vipRewardQuantity: 1,
    ),
    const BpLevelReward(
      level: 15,
      normalRewardGold: 0,
      normalRewardItemId: 'skin_sword_daeva',
      normalRewardItem: <String, dynamic>{
        'name': 'Daeva Kılıç Kaplaması',
        'rarity': 'legendary',
        'icon': 'weapon',
      },
      normalRewardQuantity: 1,
      vipRewardGold: 10000,
      vipRewardItemId: null,
      vipRewardItem: null,
      vipRewardQuantity: 1,
    ),
    const BpLevelReward(
      level: 20,
      normalRewardGold: 0,
      normalRewardItemId: 'wings_celestial_archon',
      normalRewardItem: <String, dynamic>{
        'name': 'Arkonun İlahi Kanatları',
        'rarity': 'mythic',
        'icon': 'wings',
      },
      normalRewardQuantity: 1,
      vipRewardGold: 25000,
      vipRewardItemId: null,
      vipRewardItem: null,
      vipRewardQuantity: 1,
    ),
  ];

  final dummyQuest = BpPlayerQuest(
    id: 'pq_1',
    playerId: 'p1',
    seasonId: 'season_3',
    templateId: 'qt_1',
    currentProgress: 3,
    isCompleted: false,
    rewardClaimed: false,
    updatedAt: DateTime.now(),
    template: const BpQuestTemplate(
      id: 'qt_1',
      description: 'Zindanlarda 5 Boss Kes',
      questType: 'daily',
      targetSystem: 'dungeon',
      targetCount: 5,
      bppReward: 150,
    ),
  );

  final dummyQuestCompleted = BpPlayerQuest(
    id: 'pq_2',
    playerId: 'p1',
    seasonId: 'season_3',
    templateId: 'qt_2',
    currentProgress: 10,
    isCompleted: true,
    rewardClaimed: false,
    updatedAt: DateTime.now(),
    template: const BpQuestTemplate(
      id: 'qt_2',
      description: '10 PvP Maçı Kazan',
      questType: 'weekly',
      targetSystem: 'pvp',
      targetCount: 10,
      bppReward: 500,
    ),
  );

  group('Aion 2 Mobile Season Pass UI Widgets', () {
    testWidgets('SeasonBannerShader renders correctly with cosmic details',
        (WidgetTester tester) async {
      final state = BattlePassState(
        activeSeason: dummySeason,
        status: dummyStatus,
        rewards: dummyRewards,
        quests: <BpPlayerQuest>[dummyQuest],
        isLoading: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeasonBannerShader(
              state: state,
              daysLeft: 25,
              onBuyVip: () {},
              isVipBuying: false,
            ),
          ),
        ),
      );

      // Verify season title and countdown
      expect(find.text('SEZON 3'), findsOneWidget);
      expect(find.text('25 gün kaldı'), findsOneWidget);
      expect(find.text('BPP İLERLEMESİ'), findsOneWidget);
      expect(find.text('Zindan BPP'), findsOneWidget);
      expect(find.text('PvP BPP'), findsOneWidget);
      expect(find.textContaining('VIP'), findsWidgets);

      // Verify VIP active badge when hasVip is true
      final vipStatus = BpPlayerStatus(
        playerId: 'p1',
        seasonId: 'season_3',
        currentLevel: 10,
        currentBpp: 10450,
        dailyGrindBppPool: 150,
        dailyPvpBppPool: 100,
        hasVip: true,
        claimedNormal: <int>[1, 2, 3],
        claimedVip: <int>[],
        updatedAt: DateTime.now(),
      );
      final vipState = BattlePassState(
        activeSeason: dummySeason,
        status: vipStatus,
        rewards: dummyRewards,
        quests: <BpPlayerQuest>[dummyQuest],
        isLoading: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeasonBannerShader(
              state: vipState,
              daysLeft: 25,
              onBuyVip: () {},
              isVipBuying: false,
            ),
          ),
        ),
      );
      expect(find.text('DAEVA VIP'), findsOneWidget);
    });

    testWidgets('SeasonTierTrackRow displays dual tracks (Free vs Daeva VIP)',
        (WidgetTester tester) async {
      final reward = dummyRewards[1]; // Level 5 Diamond Chest

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeasonTierTrackRow(
              reward: reward,
              reached: true,
              isCurrent: false,
              claimedNormal: false,
              claimedVip: false,
              hasVip: false,
              claimingFree: false,
              claimingVip: false,
              onClaimFree: () {},
              onClaimVip: () {},
            ),
          ),
        ),
      );

      expect(find.text('SERBEST HAT'), findsOneWidget);
      expect(find.text('DAEVA VIP'), findsOneWidget);
      expect(find.text('SV'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('AL'), findsOneWidget);
      expect(find.text('VIP GEREKLİ'), findsOneWidget);
    });

    testWidgets('SeasonRewardIllustrationView renders all 5 authentic illustrations',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                SeasonRewardIllustrationView(
                  type: SeasonRewardIllustrationType.celestialWings,
                  size: 50,
                ),
                SeasonRewardIllustrationView(
                  type: SeasonRewardIllustrationType.epicWeaponSkin,
                  size: 50,
                ),
                SeasonRewardIllustrationView(
                  type: SeasonRewardIllustrationType.diamondChest,
                  size: 50,
                ),
                SeasonRewardIllustrationView(
                  type: SeasonRewardIllustrationType.dyeAmpoule,
                  size: 50,
                ),
                SeasonRewardIllustrationView(
                  type: SeasonRewardIllustrationType.goldCache,
                  size: 50,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(SeasonRewardIllustrationView), findsNWidgets(5));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('SeasonQuestCard displays daily and weekly cards with claim state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                SeasonQuestCard(
                  quest: dummyQuest,
                  claiming: false,
                  onClaim: () {},
                ),
                SeasonQuestCard(
                  quest: dummyQuestCompleted,
                  claiming: false,
                  onClaim: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('GÜNLÜK GÖREV'), findsOneWidget);
      expect(find.text('Zindanlarda 5 Boss Kes'), findsOneWidget);
      expect(find.text('3 / 5'), findsOneWidget);

      expect(find.text('HAFTALIK GÖREV'), findsOneWidget);
      expect(find.text('10 PvP Maçı Kazan'), findsOneWidget);
      expect(find.text('+500 BPP AL'), findsOneWidget);
    });

    testWidgets('Mobile 390x844 responsive layout test with SafeArea',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final state = BattlePassState(
        activeSeason: dummySeason,
        status: dummyStatus,
        rewards: dummyRewards,
        quests: <BpPlayerQuest>[dummyQuest, dummyQuestCompleted],
        isLoading: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: ListView(
                children: <Widget>[
                  SeasonBannerShader(
                    state: state,
                    daysLeft: 25,
                    onBuyVip: () {},
                    isVipBuying: false,
                  ),
                  const SizedBox(height: 12),
                  ...dummyRewards.map(
                    (r) => SeasonTierTrackRow(
                      reward: r,
                      reached: r.level <= 10,
                      isCurrent: r.level == 10,
                      claimedNormal: r.level < 5,
                      claimedVip: false,
                      hasVip: false,
                      claimingFree: false,
                      claimingVip: false,
                      onClaimFree: () {},
                      onClaimVip: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('SEZON 3'), findsOneWidget);
      expect(find.text('SERBEST HAT'), findsWidgets);
      expect(find.text('DAEVA VIP'), findsWidgets);
    });
  });
}
