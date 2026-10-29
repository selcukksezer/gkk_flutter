import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/models/battle_pass.dart';
import 'package:gkk_flutter/providers/battle_pass_provider.dart';
import 'package:gkk_flutter/screens/season/season_pass_logic.dart';
import 'package:gkk_flutter/screens/season/widgets/season_banner_shader.dart';
import 'package:gkk_flutter/screens/season/widgets/season_quest_card.dart';
import 'package:gkk_flutter/screens/season/widgets/season_reward_illustrations.dart';
import 'package:gkk_flutter/screens/season/widgets/season_tier_track.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

import 'season_reward_preview_modal.dart';

/// Authentic mobile viewport specifications (iPhone 14 / modern standard mobile).
const double kMobileWidth = 390.0;
const double kMobileHeight = 844.0;
const double kDevicePixelRatio = 2.0; // 780x1688 crisp mobile golden render
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);

const String kOutputDir = 'reports/screenshots/mobile_goldens';

/// Utility to capture widget to PNG file on disk for golden inspection.
Future<File?> captureWidgetToPng({
  required WidgetTester tester,
  required GlobalKey repaintKey,
  required String filename,
}) async {
  final Directory dir = Directory(kOutputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  File? savedFile;
  await tester.runAsync(() async {
    final RenderObject? renderObj = repaintKey.currentContext?.findRenderObject();
    if (renderObj is! RenderRepaintBoundary) return;
    final ui.Image image = await renderObj.toImage(pixelRatio: kDevicePixelRatio);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final File file = File('$kOutputDir/$filename');
    await file.writeAsBytes(pngBytes, flush: true);
    savedFile = file;
  });

  return savedFile;
}

/// Helper wrapper that enforces authentic mobile viewport, devicePixelRatio, and safe area.
Widget buildMobileTestHarness({
  required GlobalKey repaintKey,
  required Widget child,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF070A10),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.liquidGold,
        secondary: AppColors.accentCyan,
        surface: Color(0xFF141926),
      ),
    ),
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(kMobileWidth, kMobileHeight),
        devicePixelRatio: kDevicePixelRatio,
        padding: kMobileSafeArea,
        viewPadding: kMobileSafeArea,
      ),
      child: Center(
        child: RepaintBoundary(
          key: repaintKey,
          child: SizedBox(
            width: kMobileWidth,
            height: kMobileHeight,
            child: Material(
              color: const Color(0xFF070A10),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

// ─── Test Data Factories ──────────────────────────────────────────────────────

BpSeason createMockSeason() {
  return BpSeason(
    id: 'season_01',
    seasonNumber: 1,
    startAt: DateTime.now().subtract(const Duration(days: 10)),
    endAt: DateTime.now().add(const Duration(days: 20)),
    isActive: true,
    description: 'Aion 2 Celestial Season 1: Daeva Uyanışı',
  );
}

BpPlayerStatus createMockPlayerStatus({
  int currentLevel = 10,
  int currentBpp = 10450,
  bool hasVip = true,
  List<int>? claimedNormal,
  List<int>? claimedVip,
}) {
  return BpPlayerStatus(
    playerId: 'player_test_1',
    seasonId: 'season_01',
    currentLevel: currentLevel,
    currentBpp: currentBpp,
    dailyGrindBppPool: 180,
    dailyPvpBppPool: 90,
    hasVip: hasVip,
    claimedNormal: claimedNormal ?? <int>[1, 2, 3, 5],
    claimedVip: claimedVip ?? <int>[1, 2, 5],
    updatedAt: DateTime.now(),
  );
}

List<BpLevelReward> createMockRewards() {
  return <BpLevelReward>[
    // Tier 1: Claimed
    const BpLevelReward(
      level: 1,
      normalRewardGold: 500,
      normalRewardQuantity: 0,
      vipRewardGold: 1500,
      vipRewardItemId: 'item_hp_pot',
      vipRewardItem: <String, dynamic>{
        'name': 'Büyük Can İksiri',
        'icon': 'potion_red',
        'rarity': 'common',
      },
      vipRewardQuantity: 3,
    ),
    // Tier 2: Claimed
    const BpLevelReward(
      level: 2,
      normalRewardGold: 0,
      normalRewardItemId: 'item_scroll_stamina',
      normalRewardItem: <String, dynamic>{
        'name': 'Dayanıklılık Parşömeni',
        'icon': 'scroll_gold',
        'rarity': 'uncommon',
      },
      normalRewardQuantity: 1,
      vipRewardGold: 2000,
      vipRewardQuantity: 0,
    ),
    // Tier 5: Milestone 1 (Claimed Diamond Chest)
    const BpLevelReward(
      level: 5,
      normalRewardGold: 2500,
      normalRewardQuantity: 0,
      vipRewardGold: 0,
      vipRewardItemId: 'item_chest_diamond',
      vipRewardItem: <String, dynamic>{
        'name': 'Elmas Hazine Sandığı',
        'icon': 'chest_diamond',
        'rarity': 'rare',
      },
      vipRewardQuantity: 1,
    ),
    // Tier 10: Milestone 2 (Claimable Dye Ampoule)
    const BpLevelReward(
      level: 10,
      normalRewardGold: 5000,
      normalRewardQuantity: 0,
      vipRewardGold: 0,
      vipRewardItemId: 'item_dye_pink',
      vipRewardItem: <String, dynamic>{
        'name': 'Gök Pembe Boya Ampulü',
        'icon': 'ampoule_pink',
        'rarity': 'epic',
      },
      vipRewardQuantity: 2,
    ),
    // Tier 15: Milestone 3 (Locked Epic Weapon Skin)
    const BpLevelReward(
      level: 15,
      normalRewardGold: 10000,
      normalRewardQuantity: 0,
      vipRewardGold: 0,
      vipRewardItemId: 'item_weapon_skin_sword',
      vipRewardItem: <String, dynamic>{
        'name': 'Daeva Başkılıcı Görünümü',
        'icon': 'weapon_sword_legendary',
        'rarity': 'epic',
      },
      vipRewardQuantity: 1,
    ),
    // Tier 20: Pinnacle Milestone (Locked Celestial Archon Wings)
    const BpLevelReward(
      level: 20,
      normalRewardGold: 0,
      normalRewardItemId: 'item_badge_season_champ',
      normalRewardItem: <String, dynamic>{
        'name': 'Sezon 1 Şampiyon Rozeti',
        'icon': 'badge_season_01',
        'rarity': 'epic',
      },
      normalRewardQuantity: 1,
      vipRewardGold: 0,
      vipRewardItemId: 'item_wings_archon',
      vipRewardItem: <String, dynamic>{
        'name': 'Gök Daeva Başmelek Kanatları',
        'icon': 'wings_archon_legendary',
        'rarity': 'legendary',
      },
      vipRewardQuantity: 1,
    ),
  ];
}

List<BpPlayerQuest> createMockQuests() {
  return <BpPlayerQuest>[
    BpPlayerQuest(
      id: 'q_1',
      playerId: 'player_test_1',
      seasonId: 'season_01',
      templateId: 't_daily_dungeon',
      currentProgress: 2,
      isCompleted: false,
      rewardClaimed: false,
      updatedAt: DateTime.now(),
      template: const BpQuestTemplate(
        id: 't_daily_dungeon',
        description: '2 Zindan patronu mağlup et ve ganimeti topla',
        questType: 'daily',
        targetSystem: 'dungeon',
        targetCount: 3,
        bppReward: 150,
      ),
    ),
    BpPlayerQuest(
      id: 'q_2',
      playerId: 'player_test_1',
      seasonId: 'season_01',
      templateId: 't_daily_pvp',
      currentProgress: 5,
      isCompleted: true,
      rewardClaimed: false,
      updatedAt: DateTime.now(),
      template: const BpQuestTemplate(
        id: 't_daily_pvp',
        description: 'PvP Arenasında 5 karşılaşmayı tamamla',
        questType: 'daily',
        targetSystem: 'pvp',
        targetCount: 5,
        bppReward: 200,
      ),
    ),
    BpPlayerQuest(
      id: 'q_3',
      playerId: 'player_test_1',
      seasonId: 'season_01',
      templateId: 't_weekly_boss',
      currentProgress: 10,
      isCompleted: true,
      rewardClaimed: true,
      updatedAt: DateTime.now(),
      template: const BpQuestTemplate(
        id: 't_weekly_boss',
        description: 'Haftalık 10 Lejyon Dünya Bossu avına katıl',
        questType: 'weekly',
        targetSystem: 'boss',
        targetCount: 10,
        bppReward: 500,
      ),
    ),
  ];
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Season Pass Mobile Golden Screenshot & Responsive Tests (390x844 SafeArea)', () {
    testWidgets('1. Season Pass Dual-Tier Track renders cleanly in 390x844 with SafeArea bounds', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final season = createMockSeason();
      final status = createMockPlayerStatus(currentLevel: 10, hasVip: true);
      final rewards = createMockRewards();

      final BattlePassState bpState = BattlePassState(
        activeSeason: season,
        status: status,
        rewards: rewards,
        quests: createMockQuests(),
        isLoading: false,
      );

      int freeClaims = 0;
      int vipClaims = 0;

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: SafeArea(
            child: Column(
              children: <Widget>[
                // Animated Banner Header
                SeasonBannerShader(
                  state: bpState,
                  daysLeft: 20,
                  onBuyVip: () {},
                  isVipBuying: false,
                ),
                const SizedBox(height: 10),
                // Dual-Tier Track List
                Expanded(
                  child: ListView.builder(
                    itemCount: rewards.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (context, index) {
                      final r = rewards[index];
                      final reached = status.currentLevel >= r.level;
                      return SeasonTierTrackRow(
                        reward: r,
                        reached: reached,
                        isCurrent: status.currentLevel == r.level,
                        claimedNormal: status.claimedNormal.contains(r.level),
                        claimedVip: status.claimedVip.contains(r.level),
                        hasVip: status.hasVip,
                        claimingFree: false,
                        claimingVip: false,
                        onClaimFree: () => freeClaims++,
                        onClaimVip: () => vipClaims++,
                        isLast: index == rewards.length - 1,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));

      // Assert Viewport bounds
      final RenderBox renderBox = tester.renderObject(find.byKey(repaintKey));
      expect(renderBox.size.width, equals(kMobileWidth));
      expect(renderBox.size.height, equals(kMobileHeight));

      // Verify Header components
      expect(find.text('SEZON 1'), findsOneWidget);
      expect(find.text('20 gün kaldı'), findsOneWidget);
      expect(find.text('450 / 1000'), findsOneWidget);
      expect(find.text('180/300'), findsOneWidget);
      expect(find.text('90/200'), findsOneWidget);

      // Verify Free Track & Daeva VIP headers
      expect(find.text('SERBEST HAT'), findsWidgets);
      expect(find.text('DAEVA VIP'), findsWidgets);

      // Verify Milestones and Medallions
      expect(find.text('1'), findsWidgets);
      expect(find.text('5'), findsWidgets);
      expect(find.text('10'), findsWidgets);

      // Capture Mobile Golden PNG
      final file = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'season_pass_dual_track_mobile.png',
      );
      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    });

    testWidgets('2. Locked vs Unlocked Tiers and Claim Interactions execute correctly', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final season = createMockSeason();
      // Player is at level 10, Free normal claimed up to level 5, level 10 normal is unclimed
      final status = createMockPlayerStatus(
        currentLevel: 10,
        hasVip: false, // Free track only
        claimedNormal: <int>[1, 2, 5],
        claimedVip: <int>[],
      );
      final rewards = createMockRewards();

      int claimedFreeLevel = 0;

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: SafeArea(
            child: ListView.builder(
              itemCount: rewards.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final r = rewards[index];
                final reached = status.currentLevel >= r.level;
                return SeasonTierTrackRow(
                  reward: r,
                  reached: reached,
                  isCurrent: status.currentLevel == r.level,
                  claimedNormal: status.claimedNormal.contains(r.level),
                  claimedVip: status.claimedVip.contains(r.level),
                  hasVip: status.hasVip,
                  claimingFree: false,
                  claimingVip: false,
                  onClaimFree: () => claimedFreeLevel = r.level,
                  onClaimVip: () {},
                  isLast: index == rewards.length - 1,
                );
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Level 1: Normal claimed -> shows 'ALINDI'
      expect(find.text('ALINDI'), findsWidgets);

      // Level 10: Reached, Normal unclimed -> shows 'AL' button
      final alFinder = find.widgetWithText(GestureDetector, 'AL');
      expect(alFinder, findsWidgets);

      // Level 10: VIP requires VIP Pass -> shows 'VIP GEREKLİ'
      expect(find.text('VIP GEREKLİ'), findsWidgets);

      // Tap claim on level 10 normal reward
      await tester.tap(alFinder.first);
      await tester.pump(const Duration(milliseconds: 50));
      expect(claimedFreeLevel, equals(10));

      // Scroll to view higher locked tiers (Level 15 & 20)
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 100));

      // Level 15 & 20: Beyond current level 10 -> shows 'KİLİTLİ'
      expect(find.text('KİLİTLİ'), findsWidgets);
    });

    testWidgets('3. High-Tier Reward Preview Modal renders Celestial Archon Wings cleanly', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      bool modalClaimed = false;

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: SafeArea(
            child: Center(
              child: SeasonRewardPreviewModal(
                rewardTitle: 'Gök Daeva Başmelek Kanatları',
                illustrationType: SeasonRewardIllustrationType.celestialWings,
                rarity: 'legendary',
                requiredLevel: 20,
                isVipTrack: true,
                itemDescription:
                    'Atreia semalarının efsanevi başmelek kanadı. Sahiplerine sonsuz süzülme ve kutsal ışık aurası bahşeder.',
                statBonuses: const <String, String>{
                  'Uçuş Hızı': '+25%',
                  'PvP Saldırı Gücü': '+180',
                  'Kutsal Işık Direnci': '+150',
                  'Süzülme Süresi': 'Sınırsız',
                },
                isClaimable: true,
                isClaimed: false,
                onClaim: () => modalClaimed = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));

      // Verify modal content
      expect(find.text('Gök Daeva Başmelek Kanatları'), findsOneWidget);
      expect(find.text('LEGENDARY'), findsOneWidget);
      expect(find.text('SV 20 GEREKLİ'), findsOneWidget);
      expect(find.text('DAEVA VIP ÖDÜLÜ'), findsOneWidget);
      expect(find.text('Uçuş Hızı'), findsOneWidget);
      expect(find.text('+25%'), findsOneWidget);
      expect(find.text('ŞİMDİ AL'), findsOneWidget);

      // Verify high-tier vector illustration is present
      expect(find.byType(SeasonRewardIllustrationView), findsOneWidget);

      // Tap claim action
      await tester.tap(find.text('ŞİMDİ AL'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(modalClaimed, isTrue);

      // Capture Golden Screenshot
      final file = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'season_reward_preview_modal_wings_mobile.png',
      );
      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    });

    testWidgets('4. High-Tier Reward Preview Modal renders Epic Weapon Skin and Diamond Chest', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: SafeArea(
            child: Center(
              child: SeasonRewardPreviewModal(
                rewardTitle: 'Daeva Başkılıcı Görünümü',
                illustrationType: SeasonRewardIllustrationType.epicWeaponSkin,
                rarity: 'epic',
                requiredLevel: 15,
                isVipTrack: true,
                itemDescription:
                    'Antik Daeva lejyonerlerinin şanını taşıyan platin işlemeli savaş kılıcı.',
                statBonuses: const <String, String>{
                  'Fiziksel Saldırı': '+95',
                  'Kritik Vuruş Oranı': '+8%',
                  'Saldırı Hızı': '+5%',
                },
                isClaimable: false,
                isClaimed: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('Daeva Başkılıcı Görünümü'), findsOneWidget);
      expect(find.text('EPIC'), findsOneWidget);
      expect(find.text('SV 15 GEREKLİ'), findsOneWidget);
      expect(find.text('ALINDI'), findsOneWidget);

      // Capture Golden Screenshot
      final file = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'season_reward_preview_modal_weapon_mobile.png',
      );
      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    });

    testWidgets('5. Season Quest Cards render daily and weekly quests with claimable states', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final quests = createMockQuests();

      String claimedQuestId = '';

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: SafeArea(
            child: ListView.builder(
              itemCount: quests.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final q = quests[index];
                return SeasonQuestCard(
                  quest: q,
                  claiming: false,
                  onClaim: () => claimedQuestId = q.id,
                );
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Daily quests tag
      expect(find.text('GÜNLÜK GÖREV'), findsNWidgets(2));
      // Weekly quest tag
      expect(find.text('HAFTALIK GÖREV'), findsOneWidget);

      // Unfinished quest: '2 / 3'
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('+150 BPP'), findsOneWidget);

      // Completed quest: '+200 BPP AL' button
      final claimQuestBtn = find.text('+200 BPP AL');
      expect(claimQuestBtn, findsOneWidget);

      // Claimed quest: 'ALINDI'
      expect(find.text('ALINDI'), findsOneWidget);

      // Tap claim on completed quest
      await tester.tap(claimQuestBtn);
      await tester.pump(const Duration(milliseconds: 50));
      expect(claimedQuestId, equals('q_2'));

      // Capture Golden Screenshot
      final file = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'season_quest_cards_mobile.png',
      );
      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    });

    testWidgets('6. Season Banner Shader renders cosmic particles and progress meters cleanly', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final season = createMockSeason();
      final status = createMockPlayerStatus(
        currentLevel: 14,
        currentBpp: 14780,
        hasVip: true,
      );

      final BattlePassState bpState = BattlePassState(
        activeSeason: season,
        status: status,
        rewards: createMockRewards(),
        quests: createMockQuests(),
        isLoading: false,
      );

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SeasonBannerShader(
                state: bpState,
                daysLeft: 18,
                onBuyVip: () {},
                isVipBuying: false,
              ),
            ),
          ),
        ),
      );

      // Advance animation ticker to verify particle / shimmer movement
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('SEZON 1'), findsOneWidget);
      expect(find.text('18 gün kaldı'), findsOneWidget);
      expect(find.text('780 / 1000'), findsOneWidget);
      expect(find.text('DAEVA VIP'), findsWidgets);

      // Capture Golden Screenshot
      final file = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'season_banner_shader_mobile.png',
      );
      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    });

    testWidgets('7. SeasonPassLogic calculations validate XP scaling and tier milestones', (
      WidgetTester tester,
    ) async {
      expect(SeasonPassLogic.calculateXpInCurrentLevel(10450), equals(450));
      expect(SeasonPassLogic.calculateLevelProgress(10500), equals(0.5));
      expect(SeasonPassLogic.bppNeededForNextLevel(10450), equals(550));
      expect(SeasonPassLogic.totalBppForLevel(20), equals(20000));
      expect(SeasonPassLogic.isDailyGrindCapped(300), isTrue);
      expect(SeasonPassLogic.isDailyGrindCapped(299), isFalse);
      expect(SeasonPassLogic.isDailyPvpCapped(200), isTrue);
      expect(SeasonPassLogic.remainingDailyGrindAllowance(180), equals(120));
      expect(SeasonPassLogic.remainingDailyPvpAllowance(90), equals(110));

      expect(SeasonPassLogic.isLevelReached(currentLevel: 10, rewardLevel: 10), isTrue);
      expect(SeasonPassLogic.isLevelReached(currentLevel: 10, rewardLevel: 15), isFalse);
    });
  });
}
