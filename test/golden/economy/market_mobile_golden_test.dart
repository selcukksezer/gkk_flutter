import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/kingdom/kingdom_market_blessing_banner.dart';
import 'package:gkk_flutter/components/layout/game_chrome.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_controller.dart';
import 'package:gkk_flutter/l10n/l10n.dart';
import 'package:gkk_flutter/models/auth_model.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/kingdom_market_blessing_model.dart';
import 'package:gkk_flutter/models/market_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/models/staff_model.dart';
import 'package:gkk_flutter/providers/auth_provider.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/kingdom_market_blessing_provider.dart';
import 'package:gkk_flutter/providers/market_provider.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/providers/staff_provider.dart';
import 'package:gkk_flutter/screens/market/market_screen.dart';
import 'package:gkk_flutter/screens/market/widgets/market_browse_tab.dart';
import 'package:gkk_flutter/screens/market/widgets/market_design.dart';
import 'package:gkk_flutter/screens/market/widgets/market_item_pedestal.dart';
import 'package:gkk_flutter/screens/market/widgets/market_my_market_tab.dart';
import 'package:gkk_flutter/screens/market/widgets/market_sell_tab.dart';
import 'package:gkk_flutter/screens/market/widgets/market_tab_bar.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

/// Authentic mobile viewport specifications (iPhone 14 / modern 390x844 mobile standard).
const double kMobileWidth = 390.0;
const double kMobileHeight = 844.0;
const double kDevicePixelRatio = 2.0; // 780x1688 crisp mobile golden render
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);

const String kOutputDirReports = 'reports/screenshots/mobile_goldens';
const String kOutputDirLocal = 'test/golden/economy/goldens';

// Standard 8-byte PNG header signature
const List<int> kPngSignature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

Future<File> captureWidgetToPngFile({
  required WidgetTester tester,
  required GlobalKey repaintKey,
  required String filename,
}) async {
  for (final String path in <String>[kOutputDirReports, kOutputDirLocal]) {
    final Directory dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
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
    for (final String path in <String>[kOutputDirReports, kOutputDirLocal]) {
      final File file = File('$path/$filename');
      await file.writeAsBytes(pngBytes, flush: true);
      savedFile = file;
    }
  });

  return savedFile!;
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK MODELS & DATA FIXTURES
// ─────────────────────────────────────────────────────────────────────────────

PlayerProfile createMockPlayerProfile() {
  return PlayerProfile.fromJson(<String, dynamic>{
    'id': 'p-market-001',
    'auth_id': 'auth-market-001',
    'username': 'AionTycoon',
    'email': 'tycoon@aion2.com',
    'display_name': 'Ticaret Loncası Lideri',
    'avatar_url': '',
    'avatar_frame': 'gold_celestial',
    'level': 50,
    'xp': 110000,
    'gold': 750000,
    'gems': 1400,
    'energy': 100,
    'max_energy': 100,
    'attack': 1100,
    'defense': 950,
    'health': 4200,
    'max_health': 4200,
    'power': 2450,
    'is_online': true,
    'is_banned': false,
    'tutorial_completed': true,
    'guild_id': 'guild-trade-01',
    'guild_role': 'guild_master',
    'referral_code': 'MARKET2026',
    'referred_by': null,
    'pvp_rating': 1600,
    'pvp_wins': 35,
    'pvp_losses': 10,
    'addiction_level': 0,
    'tolerance': 0,
  });
}

List<MarketTicker> createMockMarketTickers() {
  return <MarketTicker>[
    const MarketTicker(
      itemId: 'wpn_sword_dragon',
      itemName: 'Ejder Katili Kılıç',
      itemType: 'weapon',
      rarity: 'mythic',
      isStackable: false,
      lowestPrice: 28000,
      volume: 12,
      priceChange: 450, // +4.5%
      maxAvailableQty: 3,
      cheapestOrderId: 'order_wpn_01',
      cheapestSellerId: 'seller_101',
    ),
    const MarketTicker(
      itemId: 'chest_guardian_aion',
      itemName: 'Aion Muhafız Zırhı',
      itemType: 'armor',
      rarity: 'legendary',
      isStackable: false,
      lowestPrice: 54000,
      volume: 6,
      priceChange: -200, // -2.0%
      maxAvailableQty: 2,
      cheapestOrderId: 'order_arm_01',
      cheapestSellerId: 'seller_102',
    ),
    const MarketTicker(
      itemId: 'mat_dragon_scale',
      itemName: 'Ejder Pulu',
      itemType: 'material',
      rarity: 'epic',
      isStackable: true,
      lowestPrice: 1500,
      volume: 180,
      priceChange: 800, // +8.0%
      maxAvailableQty: 45,
      cheapestOrderId: 'order_mat_01',
      cheapestSellerId: 'seller_103',
    ),
    const MarketTicker(
      itemId: 'potion_hp_large',
      itemName: 'Büyük Can İksiri',
      itemType: 'potion',
      rarity: 'rare',
      isStackable: true,
      lowestPrice: 420,
      volume: 650,
      priceChange: 0,
      maxAvailableQty: 150,
      cheapestOrderId: 'order_pot_01',
      cheapestSellerId: 'seller_104',
    ),
  ];
}

List<MarketOrder> createMockMyOrders() {
  return <MarketOrder>[
    const MarketOrder(
      orderId: 'my_order_01',
      sellerId: 'auth-market-001',
      itemId: 'mat_dragon_scale',
      itemName: 'Ejder Pulu',
      itemType: 'material',
      rarity: 'epic',
      isStackable: true,
      maxStack: 99,
      side: 'sell',
      quantity: 10,
      price: 1500,
      status: 'open',
      createdAt: '2026-10-28T18:00:00Z',
    ),
    const MarketOrder(
      orderId: 'my_order_02',
      sellerId: 'auth-market-001',
      itemId: 'potion_hp_large',
      itemName: 'Büyük Can İksiri',
      itemType: 'potion',
      rarity: 'rare',
      isStackable: true,
      maxStack: 99,
      side: 'sell',
      quantity: 25,
      price: 420,
      status: 'open',
      createdAt: '2026-10-28T19:30:00Z',
    ),
  ];
}

List<InventoryItem> createMockMarketInventoryItems() {
  return <InventoryItem>[
    InventoryItem.fromJson(<String, dynamic>{
      'row_id': 'inv_row_01',
      'item_id': 'mat_dragon_scale',
      'quantity': 15,
      'slot_position': 0,
      'is_equipped': false,
      'equipped_slot': '',
      'enhancement_level': 0,
      'is_favorite': false,
      'pending_sync': false,
      'name': 'Ejder Pulu',
      'description': 'Kadim ejderha pulu.',
      'icon': '🐉',
      'item_type': 'material',
      'rarity': 'epic',
      'base_price': 120,
      'vendor_sell_price': 60,
      'attack': 0,
      'defense': 0,
      'health': 0,
      'power': 0,
      'luck': 0,
      'mana': 0,
      'equip_slot': 'none',
      'weapon_type': 'none',
      'armor_type': 'none',
      'required_level': 1,
      'can_enhance': false,
      'max_enhancement': 0,
      'is_stackable': true,
      'max_stack': 99,
      'is_tradeable': true,
      'is_market_tradeable': true,
      'potion_type': 'none',
      'energy_restore': 0,
      'health_restore': 0,
      'tolerance_increase': 0,
    }),
    InventoryItem.fromJson(<String, dynamic>{
      'row_id': 'inv_row_02',
      'item_id': 'wpn_sword_dragon',
      'quantity': 1,
      'slot_position': 1,
      'is_equipped': false,
      'equipped_slot': '',
      'enhancement_level': 3,
      'is_favorite': false,
      'pending_sync': false,
      'name': 'Ejder Katili Kılıç +3',
      'description': 'Efsanevi ejderha aleviyle temperlenmiş kılıç.',
      'icon': '🗡️',
      'item_type': 'weapon',
      'rarity': 'mythic',
      'base_price': 5000,
      'vendor_sell_price': 2500,
      'attack': 180,
      'defense': 15,
      'health': 80,
      'power': 340,
      'luck': 10,
      'mana': 30,
      'equip_slot': 'main_hand',
      'weapon_type': 'sword',
      'armor_type': 'none',
      'required_level': 25,
      'can_enhance': true,
      'max_enhancement': 15,
      'is_stackable': false,
      'max_stack': 1,
      'is_tradeable': true,
      'is_market_tradeable': true,
      'potion_type': 'none',
      'energy_restore': 0,
      'health_restore': 0,
      'tolerance_increase': 0,
    }),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// FAKE PROVIDER NOTIFIERS
// ─────────────────────────────────────────────────────────────────────────────

class FakeMarketNotifier extends MarketNotifier {
  FakeMarketNotifier({required this.initialState});
  final MarketState initialState;

  @override
  MarketState build() => initialState;

  @override
  Future<void> loadTickers({bool force = false, MarketTickerQuery? query}) async {
    // Preserve initialized mock tickers
  }

  @override
  Future<void> loadMyOrders({bool force = false}) async {
    // Preserve initialized mock orders
  }

  @override
  Future<void> loadMyHistory({bool force = false}) async {}
}

class FakeKingdomMarketBlessingNotifier extends KingdomMarketBlessingNotifier {
  FakeKingdomMarketBlessingNotifier({required this.initialStatus});
  final KingdomMarketBlessingStatus initialStatus;

  @override
  KingdomMarketBlessingStatus build() => initialStatus;

  @override
  Future<void> load() async {}
}

class FakePlayerNotifier extends PlayerNotifier {
  FakePlayerNotifier({this.mockProfile});
  final PlayerProfile? mockProfile;

  @override
  PlayerState build() => PlayerState(
        status: PlayerStatus.ready,
        profile: mockProfile,
      );

  @override
  Future<void> loadProfile({bool silent = false}) async {}
}

class FakeInventoryNotifier extends InventoryNotifier {
  FakeInventoryNotifier({required this.items});
  final List<InventoryItem> items;

  @override
  InventoryState build() => InventoryState(
        status: InventoryStatus.ready,
        items: items,
        equippedItems: const <String, InventoryItem?>{},
      );

  @override
  Future<void> loadInventory({bool silent = false}) async {}
}

class FakeStaffNotifier extends StaffNotifier {
  @override
  StaffState build() => const StaffState(isLoading: false, profile: StaffProfile.none);
}

class FakeTutorialController extends TutorialController {
  @override
  TutorialState build() => TutorialState.initial().copyWith(loaded: true);

  @override
  Future<void> onRouteEnter(String route) async {}
}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser(
          id: 'auth-market-001',
          username: 'AionTycoon',
          email: 'tycoon@aion2.com',
          level: 50,
          gold: 750000,
          gems: 1400,
          energy: 100,
          maxEnergy: 100,
          attack: 1100,
          defense: 950,
          health: 4200,
          maxHealth: 4200,
          power: 2450,
          guildId: 'guild-trade-01',
          guildRole: 'guild_master',
        ),
      );
}

Widget buildMarketMobileTestHarness({
  required GlobalKey repaintKey,
  required MarketState marketState,
  KingdomMarketBlessingStatus? blessingStatus,
  PlayerProfile? playerProfile,
  List<InventoryItem>? inventoryItems,
  Widget? overrideChild,
}) {
  final FakeMarketNotifier marketNotifier = FakeMarketNotifier(initialState: marketState);
  final FakeKingdomMarketBlessingNotifier blessingNotifier = FakeKingdomMarketBlessingNotifier(
    initialStatus: blessingStatus ??
        KingdomMarketBlessingStatus(
          isActive: true,
          expiresAt: DateTime.now().add(const Duration(hours: 4)),
          serverNow: DateTime.now(),
          discountPercent: 10,
          bonusPercent: 5,
          locationLabel: 'Pazar',
        ),
  );

  return ProviderScope(
    overrides: [
      marketProvider.overrideWith(() => marketNotifier),
      kingdomMarketBlessingProvider.overrideWith(() => blessingNotifier),
      playerProvider.overrideWith(() => FakePlayerNotifier(mockProfile: playerProfile ?? createMockPlayerProfile())),
      inventoryProvider.overrideWith(() => FakeInventoryNotifier(items: inventoryItems ?? createMockMarketInventoryItems())),
      staffProvider.overrideWith(() => FakeStaffNotifier()),
      tutorialProvider.overrideWith(() => FakeTutorialController()),
      authProvider.overrideWith(() => FakeAuthNotifier()),
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
            child: overrideChild ?? const MarketScreen(),
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TESTS
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Market Mobile Golden & Widget Tests (390x844 SafeArea)', () {
    testWidgets('Captures golden mobile screenshot: Real MarketScreen Browse Tab (390x844 SafeArea)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final MarketState state = MarketState(
        status: MarketStatus.ready,
        tickers: createMockMarketTickers(),
        myOrders: createMockMyOrders(),
        tickersLoaded: true,
        myOrdersLoaded: true,
        totalListings: 48,
        tickerTotal: 4,
      );

      await tester.pumpWidget(buildMarketMobileTestHarness(
        repaintKey: repaintKey,
        marketState: state,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull, reason: 'MarketScreen Browse tab must render with zero overflow');

      // Verify authentic screen components
      expect(find.byType(MarketScreen), findsOneWidget);
      expect(find.byType(MarketHeroBanner), findsOneWidget);
      expect(find.byType(KingdomMarketBlessingBanner), findsOneWidget);
      expect(find.byType(MarketTabBar), findsOneWidget);
      expect(find.byType(MarketBrowseTab), findsOneWidget);
      expect(find.byType(GameTopBar), findsOneWidget);
      expect(find.byType(GameBottomBar), findsOneWidget);

      // Verify market listing items
      expect(find.text('Ejder Katili Kılıç'), findsOneWidget);
      expect(find.text('Aion Muhafız Zırhı'), findsOneWidget);

      final File screenshot = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '01_market_browse_tab_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      final Uint8List bytes = await screenshot.readAsBytes();
      expect(bytes.length, greaterThan(2048));
      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }
    });

    testWidgets('Captures golden mobile screenshot: Real MarketScreen Sell Tab (390x844 SafeArea)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final MarketState state = MarketState(
        status: MarketStatus.ready,
        tickers: createMockMarketTickers(),
        myOrders: createMockMyOrders(),
        tickersLoaded: true,
        myOrdersLoaded: true,
        totalListings: 48,
        tickerTotal: 4,
      );

      await tester.pumpWidget(buildMarketMobileTestHarness(
        repaintKey: repaintKey,
        marketState: state,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap on the Sell tab in MarketTabBar ('Eşya Sat' / tab index 1)
      final Finder sellTabFinder = find.text('Eşya Sat');
      expect(sellTabFinder, findsWidgets);
      await tester.tap(sellTabFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull, reason: 'MarketScreen Sell tab must transition and render with zero overflow');
      expect(find.byType(MarketSellTab), findsOneWidget);

      final File screenshot = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '02_market_sell_tab_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      final Uint8List bytes = await screenshot.readAsBytes();
      expect(bytes.length, greaterThan(2048));
      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }
    });

    testWidgets('Captures golden mobile screenshot: Real MarketScreen My Market Tab (390x844 SafeArea)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final MarketState state = MarketState(
        status: MarketStatus.ready,
        tickers: createMockMarketTickers(),
        myOrders: createMockMyOrders(),
        tickersLoaded: true,
        myOrdersLoaded: true,
        totalListings: 48,
        tickerTotal: 4,
      );

      await tester.pumpWidget(buildMarketMobileTestHarness(
        repaintKey: repaintKey,
        marketState: state,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap on the My Market tab ('Benim Pazarım' / 'Pazarım')
      final Finder myMarketTab = find.text('Pazarım');
      expect(myMarketTab, findsOneWidget);
      await tester.tap(myMarketTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull, reason: 'MarketScreen My Market tab must render with zero overflow');
      expect(find.byType(MarketMyMarketTab), findsOneWidget);

      final File screenshot = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '03_market_my_market_tab_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      final Uint8List bytes = await screenshot.readAsBytes();
      expect(bytes.length, greaterThan(2048));
      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }
    });

    testWidgets('Captures golden screenshot: 3D Item Pedestal & Inspection Modal Sheet on 390x844', (
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
        MaterialApp(
          debugShowCheckedModeBanner: false,
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
            child: Scaffold(
              backgroundColor: AppColors.bgDeep,
              body: Center(
                child: RepaintBoundary(
                  key: repaintKey,
                  child: Container(
                    width: 360,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.goldOutline),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Pazar 3D Eşya İnceleme',
                          style: TextStyle(
                            color: AppColors.liquidGold,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        MarketItemPedestal(
                          itemName: 'Ejder Katili Kılıç',
                          rarity: 'mythic',
                          iconValue: '🗡️',
                          size: 150,
                          autoRotate: false,
                          interactive: false,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Mitolojik Silah · Taban Fiyat: 28.000 Altın',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(MarketItemPedestal), findsOneWidget);

      final File screenshot = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '04_market_pedestal_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      final Uint8List bytes = await screenshot.readAsBytes();
      expect(bytes.length, greaterThan(1024));
      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }
    });
  });
}
