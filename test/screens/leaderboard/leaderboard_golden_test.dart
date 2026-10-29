import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

// Mobile Viewport 390x844 with Retina 2.0x Pixel Ratio (780x1688 mobile golden render)
const double kMobileWidth = 390.0;
const double kMobileHeight = 844.0;
const double kDevicePixelRatio = 2.0;
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);
const String kOutputDir = 'reports/screenshots/mobile_goldens';

// Standard 8-byte PNG header signature
const List<int> kPngSignature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

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

List<LeaderboardEntry> createPvpEntries() {
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

List<LeaderboardEntry> createGuildEntries() {
  return const <LeaderboardEntry>[
    LeaderboardEntry(rank: 1, username: 'AionVanguard', value: 8500000, level: 10, guild: 'Elyos Alliance'),
    LeaderboardEntry(rank: 2, username: 'ShadowLegion', value: 7200000, level: 9, guild: 'Asmodian Pact'),
    LeaderboardEntry(rank: 3, username: 'MysticEclipse', value: 6100000, level: 8, guild: 'Elyos Alliance'),
    LeaderboardEntry(rank: 4, username: 'IronClad', value: 5400000, level: 7, guild: 'Neutral Guild'),
    LeaderboardEntry(rank: 5, username: 'CelestialDawn', value: 4900000, level: 7, guild: 'Elyos Alliance'),
    LeaderboardEntry(rank: 6, username: 'DragonSlayers', value: 4200000, level: 6, guild: 'Neutral Guild'),
    LeaderboardEntry(rank: 7, username: 'NightStalkers', value: 3800000, level: 6, guild: 'Asmodian Pact'),
  ];
}

List<LeaderboardEntry> createDungeonPowerEntries() {
  return const <LeaderboardEntry>[
    LeaderboardEntry(rank: 1, username: 'DragonSlayer_Rex', value: 450000, level: 95, guild: 'DungeonMasters'),
    LeaderboardEntry(rank: 2, username: 'AbyssConqueror', value: 420000, level: 92, guild: 'AionVanguard'),
    LeaderboardEntry(rank: 3, username: 'VoidWalker_X', value: 395000, level: 90, guild: 'MysticEclipse'),
    LeaderboardEntry(rank: 4, username: 'StormBringer', value: 360000, level: 88, guild: 'ShadowLegion'),
    LeaderboardEntry(rank: 5, username: 'FrostWeaver', value: 330000, level: 86, guild: 'CelestialDawn'),
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

Widget buildGoldenTestHarness({
  required GlobalKey repaintKey,
  required LeaderboardState leaderboardState,
  PlayerProfile? playerProfile,
}) {
  final FakeLeaderboardNotifier notifier =
      FakeLeaderboardNotifier(initialState: leaderboardState);

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

Widget buildWidgetGoldenHarness({
  required GlobalKey repaintKey,
  required Widget child,
  double width = kMobileWidth,
  double? height,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.bgDeep,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.liquidGold,
        secondary: AppColors.accentBlue,
        surface: AppColors.bgSurface,
      ),
    ),
    home: Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Center(
        child: RepaintBoundary(
          key: repaintKey,
          child: Container(
            width: width,
            height: height,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF060913), Color(0xFF0D1424)],
              ),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Leaderboard Mobile Golden Screenshot Tests (390x844 SafeArea)', () {
    testWidgets('Captures golden mobile screenshot: PvP Leaderboard with top 3 podium & pinned rank', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final LeaderboardState state = LeaderboardState(
        status: LeaderboardStatus.ready,
        entries: createPvpEntries(),
        categoryIndex: 1, // PvP
        weekly: false,
        playerRank: 8,
        playerValue: 2620,
      );

      await tester.pumpWidget(buildGoldenTestHarness(
        repaintKey: repaintKey,
        leaderboardState: state,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      final File screenshotFile = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '01_leaderboard_pvp_mobile.png',
      );

      // Verify authentic file generation on disk
      expect(screenshotFile.existsSync(), isTrue);
      final Uint8List bytes = await screenshotFile.readAsBytes();
      expect(bytes.length, greaterThan(2048));

      // Verify valid PNG signature header
      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]), reason: 'PNG signature byte mismatch at index $i');
      }
    });

    testWidgets('Captures golden mobile screenshot: Lonca (Guild) Leaderboard mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final LeaderboardState state = LeaderboardState(
        status: LeaderboardStatus.ready,
        entries: createGuildEntries(),
        categoryIndex: 4, // Lonca
        weekly: false,
        playerRank: 12,
        playerValue: 2400000,
      );

      await tester.pumpWidget(buildGoldenTestHarness(
        repaintKey: repaintKey,
        leaderboardState: state,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      final File screenshotFile = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '02_leaderboard_guild_mobile.png',
      );

      expect(screenshotFile.existsSync(), isTrue);
      final Uint8List bytes = await screenshotFile.readAsBytes();
      expect(bytes.length, greaterThan(2048));

      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }
    });

    testWidgets('Captures golden mobile screenshot: Güç (Dungeon Power) Leaderboard mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final LeaderboardState state = LeaderboardState(
        status: LeaderboardStatus.ready,
        entries: createDungeonPowerEntries(),
        categoryIndex: 3, // Güç / Dungeon Power
        weekly: true,
        playerRank: 24,
        playerValue: 185000,
      );

      await tester.pumpWidget(buildGoldenTestHarness(
        repaintKey: repaintKey,
        leaderboardState: state,
        playerProfile: createMockPlayerProfile(),
      ));
      await tester.pumpAndSettle();

      final File screenshotFile = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '03_leaderboard_dungeon_power_mobile.png',
      );

      expect(screenshotFile.existsSync(), isTrue);
      final Uint8List bytes = await screenshotFile.readAsBytes();
      expect(bytes.length, greaterThan(2048));

      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }
    });

    testWidgets('Captures focused golden screenshot: Top 3 Hero Podium component', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, 400 * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(buildWidgetGoldenHarness(
        repaintKey: repaintKey,
        width: 360,
        height: 290,
        child: LeaderboardHeroPodium(
          entries: createPvpEntries().take(3).toList(),
          categoryKey: 'pvp_rating',
          dimmed: false,
        ),
      ));
      await tester.pumpAndSettle();

      final File screenshotFile = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '04_leaderboard_hero_podium_focused.png',
      );

      expect(screenshotFile.existsSync(), isTrue);
      final Uint8List bytes = await screenshotFile.readAsBytes();
      expect(bytes.length, greaterThan(1024));

      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }
    });

    testWidgets('Captures focused golden screenshot: Pinned User Player Card component', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, 200 * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(buildWidgetGoldenHarness(
        repaintKey: repaintKey,
        width: 360,
        height: 110,
        child: const LeaderboardPlayerCard(
          username: 'AionWarrior',
          subtitle: 'Senin Sıralaman',
          valueLabel: '2.6K puan',
          rankLabel: '#8',
          categoryKey: 'pvp_rating',
        ),
      ));
      await tester.pumpAndSettle();

      final File screenshotFile = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '05_leaderboard_pinned_player_card_focused.png',
      );

      expect(screenshotFile.existsSync(), isTrue);
      final Uint8List bytes = await screenshotFile.readAsBytes();
      expect(bytes.length, greaterThan(1024));

      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }
    });
  });
}
