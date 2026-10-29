import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/l10n/l10n.dart';
import 'package:gkk_flutter/models/leaderboard_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/models/staff_model.dart';
import 'package:gkk_flutter/providers/leaderboard_provider.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/providers/staff_provider.dart';
import 'package:gkk_flutter/screens/leaderboard/leaderboard_screen.dart';
import 'package:gkk_flutter/screens/leaderboard/widgets/leaderboard_design.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

// Mobile Viewport 390x844 (iPhone 14 / modern standard mobile) with SafeArea bounds
const double kMobileWidth = 390.0;
const double kMobileHeight = 844.0;
const double kDevicePixelRatio = 2.0;
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);

// Sample realistic leaderboard entries for testing
List<LeaderboardEntry> createSampleEntries() {
  return const <LeaderboardEntry>[
    LeaderboardEntry(rank: 1, username: 'Kaisinel_Blade', value: 3850, level: 90, guild: 'AionVanguard'),
    LeaderboardEntry(rank: 2, username: 'Marchutan_Fury', value: 3620, level: 88, guild: 'ShadowLegion'),
    LeaderboardEntry(rank: 3, username: 'Lumiel_Sorcerer', value: 3410, level: 85, guild: 'MysticEclipse'),
    LeaderboardEntry(rank: 4, username: 'Nezekan_Shield', value: 3200, level: 82, guild: 'AionVanguard'),
    LeaderboardEntry(rank: 5, username: 'Zikel_Slayer', value: 3050, level: 80, guild: 'IronClad'),
    LeaderboardEntry(rank: 6, username: 'Triniel_Assassin', value: 2900, level: 79, guild: 'ShadowLegion'),
    LeaderboardEntry(rank: 7, username: 'Yustiel_Healer', value: 2750, level: 77, guild: 'CelestialDawn'),
    LeaderboardEntry(rank: 8, username: 'AionWarrior', value: 2620, level: 75, guild: 'AionVanguard'),
    LeaderboardEntry(rank: 9, username: 'Vaizel_Rogue', value: 2480, level: 74, guild: 'NightStalkers'),
    LeaderboardEntry(rank: 10, username: 'Kaisar_Dragon', value: 2300, level: 70, guild: 'DragonSlayers'),
  ];
}

PlayerProfile createMockPlayerProfile({String username = 'AionWarrior'}) {
  return PlayerProfile.fromJson(<String, dynamic>{
    'id': 'p-test-001',
    'auth_id': 'auth-test-001',
    'username': username,
    'email': 'warrior@aion2.com',
    'display_name': 'Aion Warrior',
    'avatar_url': '',
    'avatar_frame': 'gold_celestial',
    'level': 75,
    'xp': 125000,
    'gold': 500000,
    'gems': 1200,
    'energy': 100,
    'max_energy': 100,
    'attack': 1500,
    'defense': 1200,
    'health': 5000,
    'max_health': 5000,
    'power': 2620,
    'is_online': true,
    'is_banned': false,
    'tutorial_completed': true,
    'guild_id': 'guild-001',
    'guild_role': 'member',
    'referral_code': 'WARRIOR2027',
    'referred_by': null,
    'pvp_rating': 1850,
    'pvp_wins': 42,
    'pvp_losses': 12,
    'addiction_level': 0,
    'tolerance': 0,
  });
}

class FakeLeaderboardNotifier extends LeaderboardNotifier {
  FakeLeaderboardNotifier({required this.initialState});
  final LeaderboardState initialState;
  bool refreshCalled = false;

  @override
  LeaderboardState build() => initialState;

  @override
  Future<void> load({int? categoryIndex, bool? weekly}) async {
    state = state.copyWith(
      categoryIndex: categoryIndex ?? state.categoryIndex,
      weekly: weekly ?? state.weekly,
    );
  }

  @override
  Future<void> refresh() async {
    refreshCalled = true;
    state = state.copyWith(status: LeaderboardStatus.ready);
  }

  @override
  Future<void> selectCategory(int index) async {
    state = state.copyWith(categoryIndex: index);
  }

  @override
  Future<void> setWeekly(bool weekly) async {
    state = state.copyWith(weekly: weekly);
  }
}

class FakePlayerNotifier extends PlayerNotifier {
  FakePlayerNotifier({this.mockProfile});
  final PlayerProfile? mockProfile;

  @override
  PlayerState build() => PlayerState(
        status: PlayerStatus.ready,
        profile: mockProfile,
      );
}

class FakeStaffNotifier extends StaffNotifier {
  @override
  StaffState build() => const StaffState(isLoading: false, profile: StaffProfile.none);
}

Widget buildTestHarness({
  required LeaderboardState leaderboardState,
  PlayerProfile? playerProfile,
  FakeLeaderboardNotifier? customNotifier,
  GlobalKey? repaintKey,
}) {
  final FakeLeaderboardNotifier notifier =
      customNotifier ?? FakeLeaderboardNotifier(initialState: leaderboardState);

  return ProviderScope(
    overrides: [
      leaderboardProvider.overrideWith(() => notifier),
      playerProvider.overrideWith(() => FakePlayerNotifier(mockProfile: playerProfile)),
      staffProvider.overrideWith(() => FakeStaffNotifier()),
    ],
    child: MaterialApp(
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
            child: const LeaderboardScreen(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LeaderboardScreen Mobile Viewport & SafeArea Tests (390x844)', () {
    testWidgets('Renders full LeaderboardScreen in 390x844 without layout overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final LeaderboardState state = LeaderboardState(
        status: LeaderboardStatus.ready,
        entries: createSampleEntries(),
        categoryIndex: 1, // PvP
        weekly: false,
        playerRank: 8,
        playerValue: 2620,
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: state,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      // Screen structural elements must exist
      expect(find.byType(LeaderboardScreen), findsOneWidget);
      expect(find.byType(LeaderboardHeroPodium), findsOneWidget);
      expect(find.byType(LeaderboardCategoryStrip), findsOneWidget);
      expect(find.byType(LeaderboardTimeSegment), findsOneWidget);
      expect(find.byType(LeaderboardSearchField), findsOneWidget);
      expect(find.byType(LeaderboardPlayerCard), findsOneWidget);

      // Verify no overflow exception was caught by the tester
      expect(tester.takeException(), isNull);
    });
  });

  group('Leaderboard Top 3 Podium Layout Tests', () {
    testWidgets('Top 3 podium displays rank 1, 2, 3 with gold, silver, bronze medals and crown', (
      WidgetTester tester,
    ) async {
      final LeaderboardState state = LeaderboardState(
        status: LeaderboardStatus.ready,
        entries: createSampleEntries(),
        categoryIndex: 1, // PvP
        weekly: false,
        playerRank: 8,
        playerValue: 2620,
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: state,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      // Podium title
      expect(find.text('İlk 3'), findsOneWidget);

      // Top 3 usernames
      expect(find.text('Kaisinel_Blade'), findsOneWidget);
      expect(find.text('Marchutan_Fury'), findsOneWidget);
      expect(find.text('Lumiel_Sorcerer'), findsOneWidget);

      // Medals: Gold (🥇), Silver (🥈), Bronze (🥉)
      expect(find.text('🥇'), findsOneWidget);
      expect(find.text('🥈'), findsOneWidget);
      expect(find.text('🥉'), findsOneWidget);

      // Champion Crown on Rank 1
      expect(find.text('👑'), findsOneWidget);

      // Rank numbers on podium pillars
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('3'), findsWidgets);

      // Value formatting for PvP: '3.9K puan', '3.6K puan', '3.4K puan'
      expect(find.text('3.9K puan'), findsOneWidget);
      expect(find.text('3.6K puan'), findsOneWidget);
      expect(find.text('3.4K puan'), findsOneWidget);
    });

    testWidgets('Podium dims when search filter is active', (
      WidgetTester tester,
    ) async {
      final LeaderboardState state = LeaderboardState(
        status: LeaderboardStatus.ready,
        entries: createSampleEntries(),
        categoryIndex: 1,
        weekly: false,
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: state,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Marchutan');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Hero podium should now be dimmed
      final AnimatedOpacity podiumOpacity = tester.widget<AnimatedOpacity>(
        find.ancestor(of: find.byType(LeaderboardHeroPodium), matching: find.byType(AnimatedOpacity)).first,
      );
      expect(podiumOpacity.opacity, equals(0.5));
    });
  });

  group('Leaderboard Scrolling Rank List Tests', () {
    testWidgets('Renders ranks 4 through 10 with guild badges and value chips', (
      WidgetTester tester,
    ) async {
      final LeaderboardState state = LeaderboardState(
        status: LeaderboardStatus.ready,
        entries: createSampleEntries(),
        categoryIndex: 1, // PvP
        weekly: false,
        playerRank: 8,
        playerValue: 2620,
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: state,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      // Ranks 4 to 10 are in the listEntries (7 rows total)
      expect(find.byType(LeaderboardRankRow), findsWidgets);
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('#5'), findsOneWidget);
      expect(find.text('#6'), findsOneWidget);
      expect(find.text('#7'), findsOneWidget);

      // Guild badges
      expect(find.text('🏰 AionVanguard'), findsWidgets);
      expect(find.text('🏰 IronClad'), findsWidgets);
      expect(find.text('🏰 CelestialDawn'), findsWidgets);
    });

    testWidgets('Highlights logged-in user row in rank list with distinct border', (
      WidgetTester tester,
    ) async {
      final LeaderboardState state = LeaderboardState(
        status: LeaderboardStatus.ready,
        entries: createSampleEntries(),
        categoryIndex: 1,
        weekly: false,
        playerRank: 8,
        playerValue: 2620,
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: state,
        playerProfile: createMockPlayerProfile(username: 'AionWarrior'),
      ));
      await tester.pumpAndSettle();

      // Find LeaderboardRankRow for 'AionWarrior'
      final LeaderboardRankRow userRow = tester.widget<LeaderboardRankRow>(
        find.widgetWithText(LeaderboardRankRow, 'AionWarrior'),
      );
      expect(userRow.highlight, isTrue);

      // Other row should not be highlighted
      final LeaderboardRankRow otherRow = tester.widget<LeaderboardRankRow>(
        find.widgetWithText(LeaderboardRankRow, 'Nezekan_Shield'),
      );
      expect(otherRow.highlight, isFalse);
    });

    testWidgets('Scrolls smoothly down to reveal remaining entries', (
      WidgetTester tester,
    ) async {
      final LeaderboardState state = LeaderboardState(
        status: LeaderboardStatus.ready,
        entries: createSampleEntries(),
        categoryIndex: 1,
        weekly: false,
        playerRank: 8,
        playerValue: 2620,
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: state,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      // Drag scroll view upward
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await tester.pumpAndSettle();

      // Lower ranks like #9 and #10 should be visible
      expect(find.text('Vaizel_Rogue'), findsOneWidget);
      expect(find.text('Kaisar_Dragon'), findsOneWidget);
      expect(find.text('#10'), findsOneWidget);
    });
  });

  group('Leaderboard Tab Category Switches (PvP vs Guild vs Dungeon/Power vs Wealth vs Level)', () {
    testWidgets('Switches to PvP tab and updates header to PvP Sıralaması', (
      WidgetTester tester,
    ) async {
      final FakeLeaderboardNotifier notifier = FakeLeaderboardNotifier(
        initialState: LeaderboardState(
          status: LeaderboardStatus.ready,
          entries: createSampleEntries(),
          categoryIndex: 0, // Initially Servet / Wealth
          weekly: false,
        ),
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: notifier.state,
        customNotifier: notifier,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Servet Sıralaması'), findsOneWidget);

      // Tap PvP category tab (⚔️)
      await tester.tap(find.text('PvP'));
      await tester.pumpAndSettle();

      // Category index should be 1, header updated
      expect(notifier.state.categoryIndex, equals(1));
      expect(find.text('PvP Sıralaması'), findsOneWidget);
    });

    testWidgets('Switches to Lonca (Guild) tab and updates header to Lonca Sıralaması', (
      WidgetTester tester,
    ) async {
      final FakeLeaderboardNotifier notifier = FakeLeaderboardNotifier(
        initialState: LeaderboardState(
          status: LeaderboardStatus.ready,
          entries: createSampleEntries(),
          categoryIndex: 1, // PvP
          weekly: false,
        ),
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: notifier.state,
        customNotifier: notifier,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      // Tap Lonca (🏰) category tab
      await tester.tap(find.text('Lonca'));
      await tester.pumpAndSettle();

      expect(notifier.state.categoryIndex, equals(4));
      expect(find.text('Lonca Sıralaması'), findsOneWidget);
    });

    testWidgets('Switches to Güç (Dungeon/Power) tab and updates header', (
      WidgetTester tester,
    ) async {
      final FakeLeaderboardNotifier notifier = FakeLeaderboardNotifier(
        initialState: LeaderboardState(
          status: LeaderboardStatus.ready,
          entries: createSampleEntries(),
          categoryIndex: 1,
          weekly: false,
        ),
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: notifier.state,
        customNotifier: notifier,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      // Tap Güç (💪) category tab
      await tester.tap(find.text('Güç'));
      await tester.pumpAndSettle();

      expect(notifier.state.categoryIndex, equals(3));
      expect(find.text('Güç Sıralaması'), findsOneWidget);
    });

    testWidgets('Switches to Seviye (Level) tab and updates header', (
      WidgetTester tester,
    ) async {
      final FakeLeaderboardNotifier notifier = FakeLeaderboardNotifier(
        initialState: LeaderboardState(
          status: LeaderboardStatus.ready,
          entries: createSampleEntries(),
          categoryIndex: 0,
          weekly: false,
        ),
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: notifier.state,
        customNotifier: notifier,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      // Tap Seviye (📜) tab
      await tester.tap(find.text('Seviye'));
      await tester.pumpAndSettle();

      expect(notifier.state.categoryIndex, equals(2));
      expect(find.text('Seviye Sıralaması'), findsOneWidget);
    });
  });

  group('Leaderboard Timeframe Segment Tests', () {
    testWidgets('Toggles between Tüm Zamanlar and Haftalık segments', (
      WidgetTester tester,
    ) async {
      final FakeLeaderboardNotifier notifier = FakeLeaderboardNotifier(
        initialState: LeaderboardState(
          status: LeaderboardStatus.ready,
          entries: createSampleEntries(),
          categoryIndex: 1,
          weekly: false,
        ),
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: notifier.state,
        customNotifier: notifier,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tüm zamanlar • 10 oyuncu'), findsOneWidget);

      // Tap Haftalık
      await tester.tap(find.text('Haftalık'));
      await tester.pumpAndSettle();

      expect(notifier.state.weekly, isTrue);
      expect(find.text('Haftalık • 10 oyuncu'), findsOneWidget);

      // Tap Tüm Zamanlar
      await tester.tap(find.text('Tüm Zamanlar'));
      await tester.pumpAndSettle();

      expect(notifier.state.weekly, isFalse);
      expect(find.text('Tüm zamanlar • 10 oyuncu'), findsOneWidget);
    });
  });

  group('Pinned User Rank Card Tests', () {
    testWidgets('Pinned user card displays user rank, formatted value, SEN tag, and subtitle', (
      WidgetTester tester,
    ) async {
      final LeaderboardState state = LeaderboardState(
        status: LeaderboardStatus.ready,
        entries: createSampleEntries(),
        categoryIndex: 1, // PvP
        weekly: false,
        playerRank: 8,
        playerValue: 2620,
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: state,
        playerProfile: createMockPlayerProfile(username: 'AionWarrior'),
      ));
      await tester.pumpAndSettle();

      // Scroll to bottom to view pinned user card
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.byType(LeaderboardPlayerCard), findsOneWidget);
      expect(find.text('SEN'), findsOneWidget);
      expect(find.text('Senin Sıralaman'), findsOneWidget);
      expect(find.text('#8'), findsWidgets);
      expect(find.text('2.6K puan'), findsWidgets);
    });

    testWidgets('Pinned user card handles unranked player gracefully with default label', (
      WidgetTester tester,
    ) async {
      final LeaderboardState state = LeaderboardState(
        status: LeaderboardStatus.ready,
        entries: createSampleEntries(),
        categoryIndex: 1,
        weekly: false,
        playerRank: null,
        playerValue: null,
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: state,
        playerProfile: createMockPlayerProfile(username: 'NewAdventurer'),
      ));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text(LeaderboardValueFormatter.unknown), findsWidgets);
    });
  });

  group('Leaderboard Search & Filter Responsiveness Tests', () {
    testWidgets('Filtering search field updates list results and section label', (
      WidgetTester tester,
    ) async {
      final LeaderboardState state = LeaderboardState(
        status: LeaderboardStatus.ready,
        entries: createSampleEntries(),
        categoryIndex: 1,
        weekly: false,
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: state,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      // Initially shows 'Sıralama Listesi'
      expect(find.text('Sıralama Listesi'), findsOneWidget);

      // Search for 'Shadow' (matches 'Marchutan_Fury' guild, 'Triniel_Assassin' guild)
      await tester.enterText(find.byType(TextField), 'Shadow');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Arama Sonuçları'), findsOneWidget);
      expect(find.text('2 sonuç'), findsOneWidget);
      expect(find.text('Marchutan_Fury'), findsOneWidget);
      expect(find.text('Triniel_Assassin'), findsOneWidget);

      // Unmatched entry should be filtered out
      expect(find.text('Kaisinel_Blade'), findsNothing);
    });

    testWidgets('Empty search result shows LeaderboardEmptySearch view', (
      WidgetTester tester,
    ) async {
      final LeaderboardState state = LeaderboardState(
        status: LeaderboardStatus.ready,
        entries: createSampleEntries(),
        categoryIndex: 1,
        weekly: false,
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: state,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'NonExistentWarrior999');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(LeaderboardEmptySearch), findsOneWidget);
      expect(find.text('"NonExistentWarrior999" için sonuç bulunamadı'), findsOneWidget);
    });
  });

  group('Leaderboard Loading & Error State Tests', () {
    testWidgets('Displays CircularProgressIndicator on initial loading state', (
      WidgetTester tester,
    ) async {
      final LeaderboardState state = LeaderboardState(
        status: LeaderboardStatus.loading,
        entries: const <LeaderboardEntry>[],
        categoryIndex: 0,
        weekly: false,
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: state,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LeaderboardHeroPodium), findsNothing);
    });

    testWidgets('Displays LeaderboardErrorPanel with retry on error state', (
      WidgetTester tester,
    ) async {
      final FakeLeaderboardNotifier notifier = FakeLeaderboardNotifier(
        initialState: const LeaderboardState(
          status: LeaderboardStatus.error,
          entries: <LeaderboardEntry>[],
          categoryIndex: 0,
          weekly: false,
          errorMessage: 'Sunucuya bağlanılamadı. Lütfen tekrar deneyin.',
        ),
      );

      await tester.pumpWidget(buildTestHarness(
        leaderboardState: notifier.state,
        customNotifier: notifier,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(LeaderboardErrorPanel), findsOneWidget);
      expect(find.text('Sunucuya bağlanılamadı. Lütfen tekrar deneyin.'), findsOneWidget);
      expect(find.text('Yeniden Dene'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Yeniden Dene'));
      await tester.pumpAndSettle();

      expect(notifier.refreshCalled, isTrue);
    });
  });
}
