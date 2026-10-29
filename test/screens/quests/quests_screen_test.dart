import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/common/gkk_tab_bar.dart';
import 'package:gkk_flutter/l10n/l10n.dart';
import 'package:gkk_flutter/models/quest_model.dart';
import 'package:gkk_flutter/screens/quests/quest_banner_shader.dart';
import 'package:gkk_flutter/screens/quests/quest_card.dart';
import 'package:gkk_flutter/screens/quests/quest_detail_modal.dart';
import 'package:gkk_flutter/screens/quests/quest_logic.dart';
import 'package:gkk_flutter/screens/quests/quest_reward_illustrations.dart';
import 'package:gkk_flutter/screens/quests/quests_screen.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

import 'quests_golden_test.dart' show QuestsScreenMobileView;

const double kMobileWidth = 390.0;
const double kMobileHeight = 844.0;
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);

Widget buildMobileScreenTestHarness({
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
        padding: kMobileSafeArea,
        viewPadding: kMobileSafeArea,
      ),
      child: SizedBox(
        width: kMobileWidth,
        height: kMobileHeight,
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDaily = QuestData(
    id: 't_d_1',
    questId: 'q_d_test_slayer',
    name: 'Orman Koruyucusu',
    description: 'Ormandaki canavarları temizle.',
    difficulty: QuestDifficulty.easy,
    requiredLevel: 5,
    energyCost: 10,
    goldReward: 500,
    xpReward: 250,
    gemReward: 5,
    itemRewards: const ['herb_sacred'],
    status: QuestStatus.active,
    progress: 3,
    progressMax: 10,
    target: 10,
  );

  final testDailyCompleted = QuestData(
    id: 't_d_2',
    questId: 'q_d_test_aether',
    name: 'Aether Hazinesi',
    description: 'Aether cevherini teslim et.',
    difficulty: QuestDifficulty.medium,
    requiredLevel: 10,
    energyCost: 15,
    goldReward: 1200,
    xpReward: 600,
    gemReward: 10,
    itemRewards: const [],
    status: QuestStatus.completed,
    progress: 5,
    progressMax: 5,
    target: 5,
  );

  final testWeekly = QuestData(
    id: 't_w_1',
    questId: 'q_w_test_raid',
    name: 'Haftalık Ejder Avı',
    description: 'Kadim Ejder Bossunu yen.',
    difficulty: QuestDifficulty.hard,
    requiredLevel: 40,
    energyCost: 30,
    goldReward: 15000,
    xpReward: 7500,
    gemReward: 50,
    itemRewards: const ['dragon_scale'],
    status: QuestStatus.active,
    progress: 1,
    progressMax: 3,
    target: 3,
  );

  final testEpic = QuestData(
    id: 't_e_1',
    questId: 'q_campaign_epic_boss',
    name: 'Karanlık Lordun Çöküşü',
    description: 'Elite zindanın son bossunu mağlup et.',
    difficulty: QuestDifficulty.elite,
    requiredLevel: 60,
    energyCost: 70,
    goldReward: 50000,
    xpReward: 30000,
    gemReward: 200,
    itemRewards: const ['celestial_crystal'],
    status: QuestStatus.active,
    progress: 0,
    progressMax: 1,
    target: 1,
  );

  final testSeason = QuestData(
    id: 't_s_1',
    questId: 'q_s_test_season',
    name: 'Sezon Liderliği',
    description: 'Sezon hedeflerini tamamla.',
    difficulty: QuestDifficulty.medium,
    requiredLevel: 1,
    energyCost: 0,
    goldReward: 0,
    xpReward: 0,
    gemReward: 0,
    itemRewards: const [],
    status: QuestStatus.completed,
    progress: 50,
    progressMax: 50,
    target: 50,
    isSeasonQuest: true,
    bppReward: 250,
    questType: 'daily',
    bpPlayerQuestId: 'bp_1',
  );

  group('Aion 2 Mobile Quests Screen — Viewport & SafeArea Tests', () {
    testWidgets('Renders inside 390x844 without RenderFlex overflow', (tester) async {
      final quests = [testDaily, testDailyCompleted, testWeekly, testEpic];

      await tester.pumpWidget(
        buildMobileScreenTestHarness(
          child: QuestsScreenMobileView(
            quests: quests,
            initialCategory: QuestCategory.all,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify no overflow error occurred
      expect(tester.takeException(), isNull);

      // Verify header and tab bar rendered within SafeArea
      expect(find.byType(QuestBannerShader), findsOneWidget);
      expect(find.byType(GkkTabBar), findsOneWidget);
      expect(find.byType(QuestCard), findsNWidgets(quests.length));
    });

    testWidgets('Category tabs filter quests seamlessly', (tester) async {
      final quests = [testDaily, testDailyCompleted, testWeekly, testEpic];

      await tester.pumpWidget(
        buildMobileScreenTestHarness(
          child: QuestsScreenMobileView(
            quests: quests,
            initialCategory: QuestCategory.all,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All tab: 4 quests
      expect(find.byType(QuestCard), findsNWidgets(4));

      // Tap Daily tab
      await tester.tap(find.text('Günlük'));
      await tester.pumpAndSettle();

      // Daily tab: 2 daily quests
      expect(find.byType(QuestCard), findsNWidgets(2));
      expect(find.text('Orman Koruyucusu'), findsOneWidget);
      expect(find.text('Aether Hazinesi'), findsOneWidget);

      // Tap Weekly tab
      await tester.tap(find.text('Haftalık'));
      await tester.pumpAndSettle();

      // Weekly tab: 1 weekly quest
      expect(find.byType(QuestCard), findsNWidgets(1));
      expect(find.text('Haftalık Ejder Avı'), findsOneWidget);

      // Tap Main (Epic) tab
      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();

      // Epic tab: 1 epic quest
      expect(find.byType(QuestCard), findsNWidgets(1));
      expect(find.text('Karanlık Lordun Çöküşü'), findsOneWidget);
    });
  });

  group('Aion 2 Mobile QuestCard Widget Tests', () {
    testWidgets('Active quest shows progress indicator and ratio', (tester) async {
      await tester.pumpWidget(
        buildMobileScreenTestHarness(
          child: Scaffold(
            body: QuestCard(
              quest: testDaily,
              actionLoading: false,
              onComplete: () {},
              onClaim: () {},
              onGoToSeason: () {},
              onDetail: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Orman Koruyucusu'), findsOneWidget);
      expect(find.text('3/10'), findsOneWidget);
      expect(find.text('GÜNLÜK'), findsOneWidget);
      expect(find.text('Kolay'), findsOneWidget);
    });

    testWidgets('Completed quest shows claim button and fires onClaim', (tester) async {
      bool claimFired = false;

      await tester.pumpWidget(
        buildMobileScreenTestHarness(
          child: Scaffold(
            body: QuestCard(
              quest: testDailyCompleted,
              actionLoading: false,
              onComplete: () {},
              onClaim: () {
                claimFired = true;
              },
              onGoToSeason: () {},
              onDetail: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('🎁 Ödülü Al'), findsOneWidget);
      await tester.tap(find.text('🎁 Ödülü Al'));
      await tester.pump();

      expect(claimFired, isTrue);
    });

    testWidgets('Season quest shows Sezona Git button and fires onGoToSeason', (tester) async {
      bool seasonFired = false;

      await tester.pumpWidget(
        buildMobileScreenTestHarness(
          child: Scaffold(
            body: QuestCard(
              quest: testSeason,
              actionLoading: false,
              onComplete: () {},
              onClaim: () {},
              onGoToSeason: () {
                seasonFired = true;
              },
              onDetail: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('🏆 Sezona Git — Ödül Al'), findsOneWidget);
      await tester.tap(find.text('🏆 Sezona Git — Ödül Al'));
      await tester.pump();

      expect(seasonFired, isTrue);
    });

    testWidgets('Card tap fires onDetail callback', (tester) async {
      bool detailFired = false;

      await tester.pumpWidget(
        buildMobileScreenTestHarness(
          child: Scaffold(
            body: QuestCard(
              quest: testDaily,
              actionLoading: false,
              onComplete: () {},
              onClaim: () {},
              onGoToSeason: () {},
              onDetail: () {
                detailFired = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(QuestCard));
      await tester.pump();

      expect(detailFired, isTrue);
    });
  });

  group('Aion 2 Mobile QuestBannerShader Component Tests', () {
    testWidgets('Renders 0%, 50%, and 100% completion dials accurately', (tester) async {
      await tester.pumpWidget(
        buildMobileScreenTestHarness(
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: const [
                  QuestBannerShader(
                    completionRate: 0.0,
                    completedCount: 0,
                    totalQuests: 5,
                  ),
                  QuestBannerShader(
                    completionRate: 0.5,
                    completedCount: 2,
                    totalQuests: 4,
                  ),
                  QuestBannerShader(
                    completionRate: 1.0,
                    completedCount: 5,
                    totalQuests: 5,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('%0'), findsOneWidget);
      expect(find.text('%50'), findsOneWidget);
      expect(find.text('%100'), findsOneWidget);
      expect(find.text('Bitti'), findsWidgets);
      expect(find.text('2 Ödül Hazır'), findsOneWidget);
      expect(find.text('5 Ödül Hazır'), findsOneWidget);
    });
  });

  group('Aion 2 Mobile Quest Detail Modal & Reward Illustration Tests', () {
    testWidgets('showQuestDetailModal opens sheet with vector illustrations and actions', (tester) async {
      bool claimCalled = false;

      await tester.pumpWidget(
        buildMobileScreenTestHarness(
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showQuestDetailModal(
                        context: context,
                        quest: testDailyCompleted,
                        actionLoading: false,
                        onClaim: () {
                          claimCalled = true;
                        },
                        onComplete: () {},
                        onGoToSeason: () {},
                      );
                    },
                    child: const Text('Show Detail'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Detail'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify modal content
      expect(find.text('Aether Hazinesi'), findsOneWidget);
      expect(find.text('🎁 KAZANILACAK ÖDÜLLER'), findsOneWidget);
      expect(find.byType(QuestRewardDetailedCard), findsWidgets);
      expect(find.byType(QuestRewardIllustration), findsWidgets);

      // Tap claim in modal
      await tester.tap(find.text('🎁 Ödülü Al'));
      await tester.pumpAndSettle();

      expect(claimCalled, isTrue);
    });

    testWidgets('QuestRewardIllustration renders all reward types without error', (tester) async {
      await tester.pumpWidget(
        buildMobileScreenTestHarness(
          child: Scaffold(
            body: Row(
              children: const [
                QuestRewardIllustration(type: QuestRewardType.gold),
                QuestRewardIllustration(type: QuestRewardType.gem),
                QuestRewardIllustration(type: QuestRewardType.xp),
                QuestRewardIllustration(type: QuestRewardType.bpp),
                QuestRewardIllustration(type: QuestRewardType.energy),
                QuestRewardIllustration(type: QuestRewardType.material),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(QuestRewardIllustration), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    });
  });

  group('Aion 2 QuestsScreen Riverpod Integration', () {
    testWidgets('QuestsScreen displays loading indicator initially or error gracefully', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: buildMobileScreenTestHarness(
            child: const QuestsScreen(),
          ),
        ),
      );

      // Settle frame
      await tester.pump();

      // Either loading or graceful user error fallback
      expect(tester.takeException(), isNull);
    });
  });
}
