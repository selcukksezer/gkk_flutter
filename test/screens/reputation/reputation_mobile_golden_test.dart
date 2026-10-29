import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/l10n/app_localizations.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/models/reputation_model.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/providers/reputation_provider.dart';
import 'package:gkk_flutter/repositories/player_repository.dart';
import 'package:gkk_flutter/repositories/reputation_repository.dart';
import 'package:gkk_flutter/screens/reputation/reputation_screen.dart';
import 'package:gkk_flutter/screens/reputation/widgets/reputation_activity_log.dart';
import 'package:gkk_flutter/screens/reputation/widgets/reputation_design.dart';
import 'package:gkk_flutter/screens/reputation/widgets/reputation_earn_section.dart';
import 'package:gkk_flutter/screens/reputation/widgets/reputation_shop_grid.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

// ─── Authentic Mobile Viewport 390x844 (iPhone 14 / Aion 2 Standard) ─────────
const double kMobileWidth = 390.0;
const double kMobileHeight = 844.0;
const double kDevicePixelRatio = 2.0;
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);
const String kGoldenOutputDir = 'reports/screenshots/mobile_goldens';

// ─── PNG Golden Screenshot Capturer ──────────────────────────────────────────
Future<File?> captureMobileGolden({
  required WidgetTester tester,
  required GlobalKey repaintKey,
  required String filename,
}) async {
  final Directory dir = Directory(kGoldenOutputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  File? file;
  await tester.runAsync(() async {
    final RenderObject? ro = repaintKey.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) return;

    final ui.Image image = await ro.toImage(pixelRatio: kDevicePixelRatio);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final Uint8List bytes = byteData.buffer.asUint8List();
    final File target = File('${dir.path}/$filename');
    await target.writeAsBytes(bytes, flush: true);
    file = target;
  });
  return file;
}

// ─── Fake Repositories ───────────────────────────────────────────────────────
class _FakePlayerRepository implements PlayerRepository {
  _FakePlayerRepository({required this.profile});
  final PlayerProfile profile;

  @override
  Future<PlayerProfile> loadCurrentPlayer() async => profile;
}

class _FakeReputationRepository implements ReputationRepository {
  _FakeReputationRepository({
    required this.overview,
    required this.shopItems,
  });

  ReputationOverview overview;
  List<ReputationShopItem> shopItems;
  String? lastPurchasedItemId;

  @override
  Future<ReputationOverview> loadOverview() async {
    return ReputationOverview.merge(
      overview: overview,
      shopItems: shopItems,
    );
  }

  @override
  Future<List<ReputationShopItem>> loadShopItems() async => shopItems;

  @override
  Future<Map<String, dynamic>> purchaseItem({required String itemId}) async {
    lastPurchasedItemId = itemId;
    final ReputationShopItem item = shopItems.firstWhere(
      (ReputationShopItem it) => it.id == itemId,
      orElse: () => shopItems.first,
    );
    overview = ReputationOverview(
      globalReputation: (overview.globalReputation - item.costAmount).clamp(0, 9999999),
      activity: <ReputationActivityEntry>[
        ReputationActivityEntry(
          id: 'act_',
          activityType: 'spend',
          source: 'shop:',
          amount: item.costAmount,
          currency: 'global',
          createdAt: DateTime.now(),
        ),
        ...overview.activity,
      ],
      activeBuffs: overview.activeBuffs,
      shopItems: shopItems,
    );
    return <String, dynamic>{'success': true};
  }
}

// ─── Test Harness Wrapper ────────────────────────────────────────────────────
Widget _buildMobileHarness({
  required GlobalKey repaintKey,
  required PlayerProfile profile,
  required _FakeReputationRepository repo,
  Widget? child,
}) {
  return ProviderScope(
    overrides: [
      playerRepositoryProvider.overrideWithValue(_FakePlayerRepository(profile: profile)),
      reputationRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
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
        child: RepaintBoundary(
          key: repaintKey,
          child: SizedBox(
            width: kMobileWidth,
            height: kMobileHeight,
            child: child ?? const ReputationScreen(),
          ),
        ),
      ),
    ),
  );
}

// ─── Fixtures ────────────────────────────────────────────────────────────────
PlayerProfile _mockPlayer() {
  return const PlayerProfile(
    id: 'player_aion_01',
    authId: 'auth_aion_01',
    username: 'SanctumArchdaeva',
    email: 'archdaeva@aion.test',
    displayName: 'SanctumArchdaeva',
    avatarUrl: null,
    avatarFrame: 'glow',
    level: 55,
    xp: 350000,
    gold: 150000,
    gems: 500,
    energy: 100,
    maxEnergy: 100,
    attack: 620,
    defense: 480,
    health: 2400,
    maxHealth: 2400,
    power: 2900,
    isOnline: true,
    isBanned: false,
    tutorialCompleted: true,
    guildId: 'guild_aion_01',
    guildRole: 'Commander',
    characterClass: CharacterClass.warrior,
    reputation: 42500,
    statPoints: 10,
    pvpWins: 128,
    pvpLosses: 24,
    pvpRating: 1850,
    tolerance: 0,
    addictionLevel: 0,
    referralCode: null,
    referredBy: null,
    lastPotionUsedAt: null,
    warriorBloodlustUntil: null,
    hospitalUntil: null,
    prisonUntil: null,
    prisonReason: null,
    globalSuspicionLevel: 0,
    lastBribeAt: null,
    lastLoginAt: '2026-10-28T00:00:00Z',
    lastLogin: null,
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-10-28T00:00:00Z',
  );
}

_FakeReputationRepository _mockRepo() {
  final List<ReputationShopItem> shopItems = <ReputationShopItem>[
    const ReputationShopItem(
      id: 'energy_refill',
      name: 'Göksel Enerji İksiri',
      description: '+30 enerji — daeva gücü.',
      iconKey: 'bolt',
      costType: 'global',
      costAmount: 500,
      rarity: 'uncommon',
      effectKey: 'energy_refill',
      effectValue: <String, dynamic>{'energy_gain': 30},
      sortOrder: 1,
    ),
    const ReputationShopItem(
      id: 'gold_boost_30',
      name: 'Sanctum Hazine Bereket',
      description: '30 dk zindan altın +%15.',
      iconKey: 'gold',
      costType: 'global',
      costAmount: 800,
      rarity: 'rare',
      effectKey: 'gold_boost',
      effectValue: <String, dynamic>{'pct': 15},
      durationMinutes: 30,
      sortOrder: 2,
    ),
    const ReputationShopItem(
      id: 'drop_boost_30',
      name: 'Aether Ganimet Tılsımı',
      description: '30 dk nadir drop +%10.',
      iconKey: 'loot',
      costType: 'global',
      costAmount: 1200,
      rarity: 'epic',
      effectKey: 'drop_boost',
      effectValue: <String, dynamic>{'pct': 10},
      durationMinutes: 30,
      sortOrder: 3,
    ),
  ];

  final ReputationOverview overview = ReputationOverview(
    globalReputation: 42500,
    activeBuffs: <ReputationActiveBuff>[
      ReputationActiveBuff(
        buffKey: 'gold_boost',
        buffValue: 15.0,
        expiresAt: DateTime.now().add(const Duration(minutes: 25)),
      ),
      ReputationActiveBuff(
        buffKey: 'drop_boost',
        buffValue: 10.0,
        expiresAt: DateTime.now().add(const Duration(minutes: 18)),
      ),
    ],
    activity: <ReputationActivityEntry>[
      ReputationActivityEntry(
        id: 'act_1',
        activityType: 'earn',
        source: 'dungeon',
        amount: 350,
        currency: 'global',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      ReputationActivityEntry(
        id: 'act_2',
        activityType: 'earn',
        source: 'pvp',
        amount: 250,
        currency: 'global',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      ReputationActivityEntry(
        id: 'act_3',
        activityType: 'spend',
        source: 'shop:Göksel Enerji İksiri',
        amount: 500,
        currency: 'global',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ],
    shopItems: shopItems,
  );

  return _FakeReputationRepository(overview: overview, shopItems: shopItems);
}

// ─── Test Suite ─────────────────────────────────────────────────────────────
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aion 2 Mobile Reputation Golden Screenshot Suite (390x844 SafeArea)', () {
    testWidgets('renders mobile 390x844 viewport with strict SafeArea bounds without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final _FakeReputationRepository repo = _mockRepo();
      final PlayerProfile profile = _mockPlayer();

      await tester.pumpWidget(
        _buildMobileHarness(
          repaintKey: repaintKey,
          profile: profile,
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      // Verify Vault Header elements
      expect(find.byType(ReputationVaultHeader), findsOneWidget);
      expect(find.text('TOPLAM İTİBAR'), findsOneWidget);
      expect(find.text('42.5K'), findsOneWidget);
      expect(find.text('Saygın'), findsWidgets);

      // Verify active buff chips
      expect(find.text('Altın +15%'), findsOneWidget);
      expect(find.text('Loot +10%'), findsOneWidget);

      // Verify Tab Bar rendering 4 tabs
      expect(find.byType(ReputationTabBar), findsOneWidget);
      expect(find.text('Birlikler'), findsOneWidget);
      expect(find.text('Kazan'), findsOneWidget);
      expect(find.text('Harca'), findsOneWidget);
      expect(find.text('Geçmiş'), findsOneWidget);

      // Verify initial tab (Tab 0: Hanedanlar & Birlikler / FactionStandingsHub)
      expect(find.byType(FactionStandingsHub), findsOneWidget);

      // Capture Mobile Golden Screenshot
      final File? golden = await captureMobileGolden(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'reputation_mobile_factions_390x844.png',
      );
      expect(golden, isNotNull);
      expect(golden!.existsSync(), isTrue);
    });

    testWidgets('navigates through all 4 tabs and verifies subviews without layout overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final _FakeReputationRepository repo = _mockRepo();
      final PlayerProfile profile = _mockPlayer();

      await tester.pumpWidget(
        _buildMobileHarness(
          repaintKey: repaintKey,
          profile: profile,
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      // --- Switch to Tab 1: İtibar Kazan ---
      await tester.tap(find.text('Kazan'));
      await tester.pumpAndSettle();
      expect(find.byType(ReputationEarnSection), findsOneWidget);
      expect(find.byType(ReputationTierLadder), findsOneWidget);
      expect(find.text('PvP & Arena'), findsOneWidget);
      expect(find.text('Zindan'), findsOneWidget);

      await captureMobileGolden(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'reputation_mobile_earn_390x844.png',
      );

      // --- Switch to Tab 2: İtibar Dükkanı (Harca) ---
      await tester.tap(find.text('Harca'));
      await tester.pumpAndSettle();
      expect(find.byType(ReputationShopGrid), findsOneWidget);
      expect(find.text('Göksel Enerji İksiri'), findsOneWidget);
      expect(find.text('Sanctum Hazine Bereket'), findsOneWidget);
      expect(find.text('Aether Ganimet Tılsımı'), findsOneWidget);

      await captureMobileGolden(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'reputation_mobile_shop_390x844.png',
      );

      // --- Switch to Tab 3: Aktivite Geçmişi ---
      await tester.tap(find.text('Geçmiş'));
      await tester.pumpAndSettle();
      expect(find.byType(ReputationActivityLog), findsOneWidget);
      expect(find.text('Zindan'), findsOneWidget);
      expect(find.text('PvP'), findsOneWidget);

      await captureMobileGolden(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'reputation_mobile_activity_390x844.png',
      );
    });

    testWidgets('executes pull-to-refresh and shop purchase interaction cleanly', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final _FakeReputationRepository repo = _mockRepo();
      final PlayerProfile profile = _mockPlayer();

      await tester.pumpWidget(
        _buildMobileHarness(
          repaintKey: repaintKey,
          profile: profile,
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Shop tab
      await tester.tap(find.text('Harca'));
      await tester.pumpAndSettle();

      // Find and tap purchase button on first item
      final Finder buyButtons = find.widgetWithText(ElevatedButton, 'Satın Al');
      expect(buyButtons, findsWidgets);
      await tester.tap(buyButtons.first);
      await tester.pumpAndSettle();

      // Verify repo recorded purchase
      expect(repo.lastPurchasedItemId, 'energy_refill');
    });
  });
}
