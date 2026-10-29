import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/common/gkk_tab_bar.dart';
import 'package:gkk_flutter/components/common/gkk_tab_page_shell.dart';
import 'package:gkk_flutter/components/layout/game_screen_background.dart';
import 'package:gkk_flutter/l10n/l10n.dart';
import 'package:gkk_flutter/models/quest_model.dart';
import 'package:gkk_flutter/screens/quests/quest_banner_shader.dart';
import 'package:gkk_flutter/screens/quests/quest_card.dart';
import 'package:gkk_flutter/screens/quests/quest_detail_modal.dart';
import 'package:gkk_flutter/screens/quests/quest_logic.dart';
import 'package:gkk_flutter/screens/quests/quest_reward_illustrations.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

/// Authentic mobile viewport specifications (390x844 with Retina 2.0x Pixel Ratio).
const double kMobileWidth = 390.0;
const double kMobileHeight = 844.0;
const double kDevicePixelRatio = 2.0; // 780x1688 mobile golden render
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);

const String kOutputDir = 'reports/screenshots/mobile_goldens';

/// Standard 8-byte PNG header signature.
const List<int> kPngSignature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// Captures a widget rendered inside a [RepaintBoundary] to a disk PNG file.
Future<File> captureWidgetToPngFile({
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
    final RenderRepaintBoundary boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: kDevicePixelRatio);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode image to PNG for $filename');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final File file = File('$kOutputDir/$filename');
    await file.writeAsBytes(pngBytes, flush: true);
    savedFile = file;
  });

  return savedFile!;
}

// ─────────────────────────────────────────────────────────────────────────────
// SAMPLE QUEST FIXTURES
// ─────────────────────────────────────────────────────────────────────────────

final QuestData sampleDailyActive = QuestData(
  id: 'qd_1',
  questId: 'q_d_goblin_slayer',
  name: 'Goblin İstilası',
  description: 'Gölge ormanında 10 dağ goblini avla ve kristali kurtar.',
  difficulty: QuestDifficulty.easy,
  requiredLevel: 5,
  energyCost: 10,
  goldReward: 850,
  xpReward: 350,
  gemReward: 5,
  itemRewards: const ['herb_sacred'],
  status: QuestStatus.active,
  progress: 6,
  progressMax: 10,
  target: 10,
  expiresAt: DateTime.now().add(const Duration(hours: 14)).toIso8601String(),
);

final QuestData sampleDailyCompleted = QuestData(
  id: 'qd_2',
  questId: 'q_d_aether_mine',
  name: 'Aether Kristali Toplama',
  description: 'Madenden 5 saf aether kristali çıkar ve Daeva kulesine teslim et.',
  difficulty: QuestDifficulty.medium,
  requiredLevel: 12,
  energyCost: 15,
  goldReward: 2400,
  xpReward: 1200,
  gemReward: 15,
  itemRewards: const ['aether_gem'],
  status: QuestStatus.completed,
  progress: 5,
  progressMax: 5,
  target: 5,
  expiresAt: DateTime.now().add(const Duration(hours: 18)).toIso8601String(),
);

final QuestData sampleWeeklyActive = QuestData(
  id: 'qw_1',
  questId: 'q_w_abyss_patrol',
  name: 'Abyss Devriye Akını',
  description: 'Uçurum çatlağında 3 kadim muhafızı alt et ve zafer mührü kazan.',
  difficulty: QuestDifficulty.hard,
  requiredLevel: 45,
  energyCost: 35,
  goldReward: 18500,
  xpReward: 9500,
  gemReward: 60,
  itemRewards: const ['abyss_essence', 'ancient_scroll'],
  status: QuestStatus.active,
  progress: 2,
  progressMax: 3,
  target: 3,
  expiresAt: DateTime.now().add(const Duration(days: 4)).toIso8601String(),
);

final QuestData sampleWeeklyCompleted = QuestData(
  id: 'qw_2',
  questId: 'q_w_siege_warlord',
  name: 'Kuşatma Şampiyonu',
  description: 'Lonca kuşatmasında 2 zafer elde et ve lejyonunu zirveye taşı.',
  difficulty: QuestDifficulty.hard,
  requiredLevel: 50,
  energyCost: 50,
  goldReward: 35000,
  xpReward: 18000,
  gemReward: 120,
  itemRewards: const ['legion_insignia'],
  status: QuestStatus.completed,
  progress: 2,
  progressMax: 2,
  target: 2,
  expiresAt: DateTime.now().add(const Duration(days: 3)).toIso8601String(),
);

final QuestData sampleEpicCampaign = QuestData(
  id: 'qe_1',
  questId: 'q_campaign_tiamat',
  name: 'Tiamat\'ın Gazabı',
  description: 'Kadim Ejder Tapınağında Tiamat muhafızlarını dize getir ve efsanevi kanatları kazan.',
  difficulty: QuestDifficulty.elite,
  requiredLevel: 65,
  energyCost: 80,
  goldReward: 75000,
  xpReward: 48000,
  gemReward: 350,
  itemRewards: const ['dragon_scale', 'celestial_archon_wings'],
  status: QuestStatus.active,
  progress: 0,
  progressMax: 1,
  target: 1,
);

final QuestData sampleDungeonConquest = QuestData(
  id: 'qe_2',
  questId: 'q_dungeon_abyss_gate',
  name: 'Abyss Zindanının Derinlikleri',
  description: 'Karanlık Zindanın 5. katını ölüm olmadan tamamla ve kadim kalıntıları topla.',
  difficulty: QuestDifficulty.dungeon,
  requiredLevel: 60,
  energyCost: 65,
  goldReward: 52000,
  xpReward: 32000,
  gemReward: 220,
  itemRewards: const ['ancient_monolith'],
  status: QuestStatus.active,
  progress: 4,
  progressMax: 5,
  target: 5,
);

final QuestData sampleSeasonCompleted = QuestData(
  id: 'qs_1',
  questId: 'q_s_daeva_glory',
  name: 'Daeva Yükseliş Madalyası',
  description: 'Sezon biletinde 100 kademe puanı toplayarak şanını kanıtla.',
  difficulty: QuestDifficulty.medium,
  requiredLevel: 25,
  energyCost: 0,
  goldReward: 0,
  xpReward: 0,
  gemReward: 0,
  itemRewards: const [],
  status: QuestStatus.completed,
  progress: 100,
  progressMax: 100,
  target: 100,
  isSeasonQuest: true,
  bppReward: 350,
  questType: 'daily',
  bpPlayerQuestId: 'bp_pq_daeva_1',
);

// ─────────────────────────────────────────────────────────────────────────────
// FULL-FIDELITY MOBILE QUESTS VIEW HARNESS
// ─────────────────────────────────────────────────────────────────────────────

class QuestsScreenMobileView extends StatefulWidget {
  const QuestsScreenMobileView({
    super.key,
    required this.quests,
    this.initialCategory = QuestCategory.all,
    this.onClaim,
    this.onComplete,
    this.onGoToSeason,
    this.onDetail,
  });

  final List<QuestData> quests;
  final QuestCategory initialCategory;
  final ValueChanged<QuestData>? onClaim;
  final ValueChanged<QuestData>? onComplete;
  final VoidCallback? onGoToSeason;
  final ValueChanged<QuestData>? onDetail;

  @override
  State<QuestsScreenMobileView> createState() => _QuestsScreenMobileViewState();
}

class _QuestsScreenMobileViewState extends State<QuestsScreenMobileView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  late QuestCategory _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    final initialIndex = switch (widget.initialCategory) {
      QuestCategory.all => 0,
      QuestCategory.daily => 1,
      QuestCategory.weekly => 2,
      QuestCategory.main => 3,
    };
    _tabCtrl = TabController(length: 4, vsync: this, initialIndex: initialIndex);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) return;
      setState(() {
        _category = QuestCategory.values[_tabCtrl.index];
      });
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = QuestLogic.filterByCategory(widget.quests, _category);
    final sorted = QuestLogic.sortQuests(filtered);
    final completionRate = QuestLogic.calculateOverallCompletionRate(widget.quests);
    final completedCount = QuestLogic.countCompletedOrReady(widget.quests);

    final sectionAccent = switch (_category) {
      QuestCategory.all => const Color(0xFF818CF8),
      QuestCategory.daily => const Color(0xFFFBBF24),
      QuestCategory.weekly => const Color(0xFF38BDF8),
      QuestCategory.main => const Color(0xFFA855F7),
    };

    final sectionTitle = switch (_category) {
      QuestCategory.all => 'Tüm Görevler',
      QuestCategory.daily => 'Günlük Keşifler',
      QuestCategory.weekly => 'Haftalık Seferler',
      QuestCategory.main => 'Destansı & Zindan Görevleri',
    };

    const tabs = [
      (Icons.grid_view_rounded, 'Tümü'),
      (Icons.wb_sunny_rounded, 'Günlük'),
      (Icons.date_range_rounded, 'Haftalık'),
      (Icons.auto_awesome_rounded, 'Ana'),
    ];

    return Scaffold(
      appBar: GameTopBar(
        title: 'Görevler',
        onLogout: () async {},
      ),
      extendBody: true,
      bottomNavigationBar: const GameBottomBar(
        currentRoute: '/quests',
        onLogout: null,
      ),
      backgroundColor: AppColors.bgDeep,
      body: GameScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Celestial Banner Shader
              QuestBannerShader(
                completionRate: completionRate,
                completedCount: completedCount,
                totalQuests: widget.quests.length,
                onTap: () {
                  if (widget.quests.isNotEmpty) {
                    widget.onDetail?.call(widget.quests.first);
                  }
                },
              ),

              // Category Tabs
              GkkTabBar(
                controller: _tabCtrl,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                tabs: tabs
                    .map(
                      (t) => GkkTabBar.labeledTab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(t.$1, size: 13),
                            const SizedBox(width: 4),
                            Text(t.$2),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 6),

              // Quests List
              Expanded(
                child: GkkTabPageShell(
                  tabIndex: _tabCtrl.index,
                  sectionTitle: sectionTitle,
                  sectionAccent: sectionAccent,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 72),
                    itemCount: sorted.length,
                    itemBuilder: (ctx, i) {
                      final q = sorted[i];
                      return GkkTabStaggerItem(
                        index: i,
                        child: QuestCard(
                          quest: q,
                          actionLoading: false,
                          highlightClaimAnchor: q.status == QuestStatus.completed,
                          onComplete: () => widget.onComplete?.call(q),
                          onClaim: () => widget.onClaim?.call(q),
                          onGoToSeason: () => widget.onGoToSeason?.call(),
                          onDetail: () => widget.onDetail?.call(q),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Builds the standardized mobile 390x844 test harness with SafeArea bounds.
Widget buildMobileGoldenTestHarness({
  required GlobalKey repaintKey,
  required Widget child,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('tr'),
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.bgDeep,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.liquidGold,
        secondary: AppColors.accentBlue,
        surface: AppColors.bgSurface,
      ),
    ),
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(kMobileWidth, kMobileHeight),
        devicePixelRatio: kDevicePixelRatio,
        padding: kMobileSafeArea,
        viewPadding: kMobileSafeArea,
      ),
      child: SizedBox(
        width: kMobileWidth,
        height: kMobileHeight,
        child: RepaintBoundary(
          key: repaintKey,
          child: child,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GOLDEN TEST SUITE
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aion 2 Mobile Quests Golden Screenshot Tests (390x844 SafeArea)', () {
    testWidgets('01 Golden: Quests Screen Daily Tab with celestial banner and quest cards', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final quests = <QuestData>[
        sampleDailyActive,
        sampleDailyCompleted,
        sampleSeasonCompleted,
      ];

      await tester.pumpWidget(
        buildMobileGoldenTestHarness(
          repaintKey: repaintKey,
          child: QuestsScreenMobileView(
            quests: quests,
            initialCategory: QuestCategory.daily,
          ),
        ),
      );

      // Settle animations
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final File screenshot = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '01_quests_daily_tab_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      final Uint8List bytes = await screenshot.readAsBytes();
      expect(bytes.length, greaterThan(2048));
      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }

      // Assertions on content
      expect(find.text('Görevler'), findsWidgets);
      expect(find.text('AION 2 EXPEDITIONS'), findsOneWidget);
      expect(find.text('Goblin İstilası'), findsOneWidget);
      expect(find.text('Aether Kristali Toplama'), findsOneWidget);
      expect(find.text('🎁 Ödülü Al'), findsOneWidget);
    });

    testWidgets('02 Golden: Quests Screen Weekly Tab with high-tier raids and timers', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final quests = <QuestData>[
        sampleWeeklyActive,
        sampleWeeklyCompleted,
      ];

      await tester.pumpWidget(
        buildMobileGoldenTestHarness(
          repaintKey: repaintKey,
          child: QuestsScreenMobileView(
            quests: quests,
            initialCategory: QuestCategory.weekly,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final File screenshot = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '02_quests_weekly_tab_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      final Uint8List bytes = await screenshot.readAsBytes();
      expect(bytes.length, greaterThan(2048));
      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }

      expect(find.text('Abyss Devriye Akını'), findsOneWidget);
      expect(find.text('Kuşatma Şampiyonu'), findsOneWidget);
      expect(find.text('HAFTALIK'), findsWidgets);
    });

    testWidgets('03 Golden: Quests Screen Epic & Dungeon Tab with elite relic rewards', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final quests = <QuestData>[
        sampleEpicCampaign,
        sampleDungeonConquest,
      ];

      await tester.pumpWidget(
        buildMobileGoldenTestHarness(
          repaintKey: repaintKey,
          child: QuestsScreenMobileView(
            quests: quests,
            initialCategory: QuestCategory.main,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final File screenshot = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '03_quests_epic_tab_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      final Uint8List bytes = await screenshot.readAsBytes();
      expect(bytes.length, greaterThan(2048));
      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }

      expect(find.text('Tiamat\'ın Gazabı'), findsOneWidget);
      expect(find.text('Abyss Zindanının Derinlikleri'), findsOneWidget);
      expect(find.text('DESTANSI'), findsWidgets);
    });

    testWidgets('04 Golden: Quests Screen Claimed State with 100% dial gauge and ready rewards', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final quests = <QuestData>[
        sampleDailyCompleted,
        sampleWeeklyCompleted,
        sampleSeasonCompleted,
      ];

      await tester.pumpWidget(
        buildMobileGoldenTestHarness(
          repaintKey: repaintKey,
          child: QuestsScreenMobileView(
            quests: quests,
            initialCategory: QuestCategory.all,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final File screenshot = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '04_quests_claimed_state_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      final Uint8List bytes = await screenshot.readAsBytes();
      expect(bytes.length, greaterThan(2048));
      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }

      // Assert 100% completion dial
      expect(find.text('%100'), findsOneWidget);
      expect(find.text('Bitti'), findsOneWidget);
      expect(find.text('🎁 Ödülü Al'), findsWidgets);
      expect(find.text('🏆 Sezona Git — Ödül Al'), findsOneWidget);
    });

    testWidgets('05 Golden: Reward Detail Modal Popup with vector reward illustrations', (
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
        buildMobileGoldenTestHarness(
          repaintKey: repaintKey,
          child: Builder(
            builder: (context) {
              return Scaffold(
                backgroundColor: AppColors.bgDeep,
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showQuestDetailModal(
                        context: context,
                        quest: sampleDailyCompleted,
                        actionLoading: false,
                        onClaim: () {},
                        onComplete: () {},
                        onGoToSeason: () {},
                      );
                    },
                    child: const Text('Open Modal'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Tap to open modal
      await tester.tap(find.text('Open Modal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final File screenshot = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '05_quests_reward_popup_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      final Uint8List bytes = await screenshot.readAsBytes();
      expect(bytes.length, greaterThan(2048));
      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }

      expect(find.text('Aether Kristali Toplama'), findsOneWidget);
      expect(find.text('🎁 KAZANILACAK ÖDÜLLER'), findsOneWidget);
      expect(find.text('2400'), findsOneWidget); // Gold
      expect(find.text('1200'), findsOneWidget); // XP
      expect(find.text('15'), findsOneWidget); // Gems
      expect(find.text('🎁 Ödülü Al'), findsOneWidget);
    });

    testWidgets('06 Golden: Vector Reward Illustrations Showcase (Gold, Gem, XP, BPP, Energy, Material)', (
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
        buildMobileGoldenTestHarness(
          repaintKey: repaintKey,
          child: Scaffold(
            backgroundColor: const Color(0xFF070B14),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AION 2 REWARD ILLUSTRATIONS',
                      style: TextStyle(
                        color: Color(0xFFF1F5F9),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: const [
                        QuestRewardDetailedCard(
                          type: QuestRewardType.gold,
                          amount: '50,000',
                          title: 'Altın Sikke',
                        ),
                        QuestRewardDetailedCard(
                          type: QuestRewardType.gem,
                          amount: '500',
                          title: 'Aether Elması',
                        ),
                        QuestRewardDetailedCard(
                          type: QuestRewardType.xp,
                          amount: '25,000',
                          title: 'Deneyim Puanı',
                        ),
                        QuestRewardDetailedCard(
                          type: QuestRewardType.bpp,
                          amount: '350',
                          title: 'Sezon BPP',
                        ),
                        QuestRewardDetailedCard(
                          type: QuestRewardType.energy,
                          amount: '60',
                          title: 'Kutsal Enerji',
                        ),
                        QuestRewardDetailedCard(
                          type: QuestRewardType.material,
                          amount: '12',
                          title: 'Kadim Kalıntı',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'COMPACT REWARD PILLS',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        QuestRewardPill(type: QuestRewardType.gold, amount: '15,000'),
                        QuestRewardPill(type: QuestRewardType.gem, amount: '120'),
                        QuestRewardPill(type: QuestRewardType.xp, amount: '8,500', suffix: 'XP'),
                        QuestRewardPill(type: QuestRewardType.bpp, amount: '200', suffix: 'BPP'),
                        QuestRewardPill(type: QuestRewardType.energy, amount: '35'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final File screenshot = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '06_quests_reward_illustrations_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      final Uint8List bytes = await screenshot.readAsBytes();
      expect(bytes.length, greaterThan(2048));
      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }

      expect(find.text('Altın Sikke'), findsOneWidget);
      expect(find.text('Aether Elması'), findsOneWidget);
      expect(find.text('Deneyim Puanı'), findsOneWidget);
      expect(find.text('Sezon BPP'), findsOneWidget);
    });
  });
}
