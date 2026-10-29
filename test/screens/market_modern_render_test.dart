import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/kingdom/kingdom_market_blessing_banner.dart';
import 'package:gkk_flutter/components/layout/game_chrome.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_controller.dart';
import 'package:gkk_flutter/l10n/l10n.dart';
import 'package:gkk_flutter/models/auth_model.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
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
import 'package:gkk_flutter/screens/market/widgets/gold_coin_particle_burst.dart';
import 'package:gkk_flutter/screens/market/widgets/market_browse_tab.dart';
import 'package:gkk_flutter/screens/market/widgets/market_design.dart';
import 'package:gkk_flutter/screens/market/widgets/market_helpers.dart';
import 'package:gkk_flutter/screens/market/widgets/market_item_pedestal.dart';
import 'package:gkk_flutter/screens/market/widgets/market_listing_card.dart';
import 'package:gkk_flutter/screens/market/widgets/market_my_market_tab.dart';
import 'package:gkk_flutter/screens/market/widgets/market_sell_tab.dart';
import 'package:gkk_flutter/screens/market/widgets/market_tab_bar.dart';
import 'package:gkk_flutter/screens/trade/widgets/trade_theme.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MOCK DATA FIXTURES
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
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-10-29T00:00:00Z',
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
  MarketTickerQuery? lastQuery;
  int loadTickersCallCount = 0;
  int loadMyOrdersCallCount = 0;
  int loadMyHistoryCallCount = 0;

  @override
  MarketState build() => initialState;

  @override
  Future<void> loadTickers({bool force = false, MarketTickerQuery? query}) async {
    loadTickersCallCount++;
    lastQuery = query;
  }

  @override
  Future<void> loadMyOrders({bool force = false}) async {
    loadMyOrdersCallCount++;
  }

  @override
  Future<void> loadMyHistory({bool force = false}) async {
    loadMyHistoryCallCount++;
  }
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
  FakeAuthNotifier({this.currentUserId = 'auth-market-001'});
  final String currentUserId;

  @override
  AuthState build() => AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser(
          id: currentUserId,
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

Widget buildMarketTestHarness({
  required MarketState marketState,
  KingdomMarketBlessingStatus? blessingStatus,
  PlayerProfile? playerProfile,
  List<InventoryItem>? inventoryItems,
  String currentUserId = 'auth-market-001',
  Widget? overrideChild,
}) {
  return ProviderScope(
    overrides: [
      marketProvider.overrideWith(() => FakeMarketNotifier(initialState: marketState)),
      kingdomMarketBlessingProvider.overrideWith(
        () => FakeKingdomMarketBlessingNotifier(
          initialStatus: blessingStatus ??
              const KingdomMarketBlessingStatus(
                active: true,
                goldDiscountPct: 10,
                gemDiscountPct: 5,
              ),
        ),
      ),
      playerProvider.overrideWith(
        () => FakePlayerNotifier(mockProfile: playerProfile ?? createMockPlayerProfile()),
      ),
      inventoryProvider.overrideWith(
        () => FakeInventoryNotifier(items: inventoryItems ?? createMockMarketInventoryItems()),
      ),
      staffProvider.overrideWith(() => FakeStaffNotifier()),
      tutorialProvider.overrideWith(() => FakeTutorialController()),
      authProvider.overrideWith(() => FakeAuthNotifier(currentUserId: currentUserId)),
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
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 44, bottom: 34),
        ),
        child: SizedBox(
          width: 390,
          height: 844,
          child: overrideChild ?? const MarketScreen(),
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

  group('3D Item Pedestal & Rotating Highlight', () {
    testWidgets('MarketItemPedestal renders with rotating highlight and floats smoothly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MarketItemPedestal(
                itemName: 'Ejderha Katili Kılıç',
                rarity: 'mythic',
                iconValue: '🗡️',
                size: 160,
                autoRotate: true,
                interactive: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MarketItemPedestal), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify animation frames step without errors
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));

      // Test interactive dragging to rotate yaw and pitch
      final Finder pedestalFinder = find.byType(MarketItemPedestal);
      await tester.drag(pedestalFinder, const Offset(30, -20));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(MarketItemPedestal), findsOneWidget);
    });

    testWidgets('MarketItemPedestal adapts to legendary, epic, rare, uncommon, and common visual hierarchy', (WidgetTester tester) async {
      for (final String rarity in <String>['mythic', 'legendary', 'epic', 'rare', 'uncommon', 'common']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: MarketItemPedestal(
                  itemName: 'Aion Donanımı',
                  rarity: rarity,
                  iconValue: '🛡️',
                  size: 120,
                  autoRotate: false,
                ),
              ),
            ),
          ),
        );
        expect(find.byType(MarketItemPedestal), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('MarketPedestalInspectionSheet opens modal with 3D pedestal and thumb buttons', (WidgetTester tester) async {
      bool buyTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    MarketPedestalInspectionSheet.show(
                      context,
                      itemName: 'Kutsal Aion Kalkanı',
                      rarity: 'legendary',
                      price: 25000,
                      stockLabel: 'Efsanevi · 5 Stok',
                      canBuy: true,
                      onBuy: () => buyTapped = true,
                    );
                  },
                  child: const Text('İncele'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('İncele'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check inspection sheet elements
      expect(find.text('Kutsal Aion Kalkanı'), findsOneWidget);
      expect(find.text('Efsanevi · 5 Stok'), findsOneWidget);
      expect(find.text('25.000 Altın'), findsOneWidget);
      expect(find.byType(MarketItemPedestal), findsOneWidget);

      // Verify thumb-accessible buttons
      expect(find.text('Kapat'), findsOneWidget);
      expect(find.text('Satın Al'), findsOneWidget);

      // Tap Satın Al
      await tester.tap(find.text('Satın Al'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(buyTapped, isTrue);
    });

    testWidgets('MarketPedestalInspectionSheet hides buy button when canBuy is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    MarketPedestalInspectionSheet.show(
                      context,
                      itemName: 'Bağlı Kadim Kitap',
                      rarity: 'epic',
                      price: 15000,
                      stockLabel: 'Destansı · Takas Edilemez',
                      canBuy: false,
                    );
                  },
                  child: const Text('İncele'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('İncele'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Bağlı Kadim Kitap'), findsOneWidget);
      expect(find.text('Kapat'), findsOneWidget);
      expect(find.text('Satın Al'), findsNothing);

      await tester.tap(find.text('Kapat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Bağlı Kadim Kitap'), findsNothing);
    });
  });

  group('GoldCoinParticleBurst Simulation & Haptics', () {
    testWidgets('GoldCoinParticleBurst renders genuine coin particles and physics', (WidgetTester tester) async {
      final GoldCoinBurstController controller = GoldCoinBurstController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoldCoinParticleBurst(
              controller: controller,
              child: const Center(child: Text('Market Vitrini')),
            ),
          ),
        ),
      );

      expect(find.text('Market Vitrini'), findsOneWidget);

      // Trigger coin burst animation
      controller.trigger(origin: const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CustomPaint), findsWidgets);

      // Step physics animation frames
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
    });

    testWidgets('GoldCoinParticleBurst.trigger static helper attaches to overlay smoothly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () => GoldCoinParticleBurst.trigger(context),
                  child: const Text('Satın Alma Başarılı'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Satın Alma Başarılı'));
      await tester.pump(const Duration(milliseconds: 50));

      // Advance particle animation to completion
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
    });
  });

  group('MarketBrowseGridCard Modern Rendering & Actions', () {
    testWidgets('MarketBrowseGridCard renders 3D pedestal and handles inspect & buy actions', (WidgetTester tester) async {
      bool inspectTapped = false;
      bool buyTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 175,
                height: 250,
                child: MarketBrowseGridCard(
                  itemName: 'Ateş Ruhu Zırhı',
                  rarity: 'epic',
                  price: 4500,
                  priceChangeBps: 250,
                  stockLabel: 'Destansı · 3 stok',
                  iconValue: '🛡️',
                  canBuy: true,
                  onInspect: () => inspectTapped = true,
                  onBuy: () => buyTapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Ateş Ruhu Zırhı'), findsOneWidget);
      expect(find.text('+2.5%'), findsOneWidget);
      expect(find.byType(MarketItemPedestal), findsOneWidget);

      // Tap buy button
      await tester.tap(find.text('Al'));
      await tester.pump();
      expect(buyTapped, isTrue);

      // Tap card body for 3D inspection
      await tester.tap(find.byType(MarketBrowseGridCard));
      await tester.pump();
      expect(inspectTapped, isTrue);
    });

    testWidgets('MarketBrowseGridCard distinguishes own listing with disabled Senin badge button', (WidgetTester tester) async {
      bool buyTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 175,
                height: 250,
                child: MarketBrowseGridCard(
                  itemName: 'Mithril Madeni',
                  rarity: 'rare',
                  price: 1200,
                  priceChangeBps: 0,
                  stockLabel: 'Nadir · 10 stok',
                  iconValue: '⛏️',
                  ownListing: true,
                  canBuy: false,
                  onBuy: () => buyTapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Mithril Madeni'), findsOneWidget);
      expect(find.text('Senin'), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);

      // Tap button — should not trigger buy because ownListing is true
      await tester.tap(find.text('Senin'));
      await tester.pump();
      expect(buyTapped, isFalse);
    });

    testWidgets('MarketBrowseGridCard renders negative price change and stock label correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 175,
                height: 250,
                child: MarketBrowseGridCard(
                  itemName: 'Aion Muhafız Zırhı',
                  rarity: 'legendary',
                  price: 54000,
                  priceChangeBps: -200,
                  stockLabel: 'Efsanevi · 6 stok',
                  iconValue: '🛡️',
                  canBuy: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Aion Muhafız Zırhı'), findsOneWidget);
      expect(find.text('-2.0%'), findsOneWidget);
      expect(find.text('Efsanevi · 6 stok'), findsOneWidget);
      expect(find.text('54.000'), findsOneWidget);
    });
  });

  group('Market Filter Tabs, Search & Pill Strips', () {
    testWidgets('MarketPillStrip selects category pill and fires callback', (WidgetTester tester) async {
      String selected = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketPillStrip(
              options: marketStaticCategoryPillOptions(),
              selectedKey: selected,
              onSelected: (String key) => selected = key,
            ),
          ),
        ),
      );

      expect(find.text('Silah'), findsOneWidget);
      expect(find.text('Zirh'), findsOneWidget);

      await tester.tap(find.text('Silah'));
      await tester.pump();
      expect(selected, 'weapon');
    });

    testWidgets('MarketPillStrip selects rarity pill and fires callback', (WidgetTester tester) async {
      String selected = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketPillStrip(
              options: marketStaticRarityPillOptions(),
              selectedKey: selected,
              accent: AppColors.coralFlare,
              onSelected: (String key) => selected = key,
            ),
          ),
        ),
      );

      expect(find.text('Destansi'), findsOneWidget);
      await tester.tap(find.text('Destansi'));
      await tester.pump();
      expect(selected, 'epic');
    });

    testWidgets('MarketSortChips toggles between Ucuz and Pahali sorting options', (WidgetTester tester) async {
      bool lowSelected = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return MarketSortChips(
                  lowSelected: lowSelected,
                  onLow: () => setState(() => lowSelected = true),
                  onHigh: () => setState(() => lowSelected = false),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Ucuz'), findsOneWidget);
      expect(find.text('Pahali'), findsOneWidget);
      expect(lowSelected, isTrue);

      await tester.tap(find.text('Pahali'));
      await tester.pump();
      expect(lowSelected, isFalse);

      await tester.tap(find.text('Ucuz'));
      await tester.pump();
      expect(lowSelected, isTrue);
    });

    testWidgets('MarketSearchField triggers search callback upon typing', (WidgetTester tester) async {
      String query = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketSearchField(
              onChanged: (String val) => query = val,
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Mithril');
      await tester.pump();
      expect(query, 'Mithril');
    });

    testWidgets('MarketEmptyState renders custom message and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarketEmptyState(
              message: 'Hic esya bulunamadi',
              icon: Icons.search_off_rounded,
            ),
          ),
        ),
      );

      expect(find.text('Hic esya bulunamadi'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });

    testWidgets('MarketLoadingSpinner renders circular progress indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarketLoadingSpinner(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Currency Displays, Blessing Discount & Fee Math', () {
    test('formatMarketGold formats values in Turkish standard notation', () {
      expect(formatMarketGold(0), '0');
      expect(formatMarketGold(420), '420');
      expect(formatMarketGold(28000), '28.000');
      expect(formatMarketGold(750000), '750.000');
      expect(formatMarketGold(1234567), '1.234.567');
    });

    test('formatMarketPriceChange displays formatted signed percentages', () {
      expect(formatMarketPriceChange(0), '0%');
      expect(formatMarketPriceChange(450), '+4.5%');
      expect(formatMarketPriceChange(-200), '-2.0%');
      expect(formatMarketPriceChange(1250), '+12.5%');
    });

    test('marketPriceChangeColor reflects green, red, and muted colors for price trends', () {
      expect(marketPriceChangeColor(100), AppColors.toxicNeon);
      expect(marketPriceChangeColor(-100), AppColors.mysticRuby);
      expect(marketPriceChangeColor(0), AppColors.mutedTitanium);
    });

    test('KingdomMarketBlessingStatus applies accurate percentage discounts to market prices', () {
      const KingdomMarketBlessingStatus activeBlessing = KingdomMarketBlessingStatus(
        active: true,
        goldDiscountPct: 10,
        gemDiscountPct: 5,
      );
      expect(activeBlessing.hasDiscountForCurrency('gold'), isTrue);
      expect(activeBlessing.discountPctForCurrency('gold'), 10);
      expect(activeBlessing.applyDiscount(54000, 'gold'), 48600);
      expect(activeBlessing.applyDiscount(1500, 'gold'), 1350);

      const KingdomMarketBlessingStatus inactiveBlessing = KingdomMarketBlessingStatus(
        active: false,
      );
      expect(inactiveBlessing.hasDiscountForCurrency('gold'), isFalse);
      expect(inactiveBlessing.applyDiscount(54000, 'gold'), 54000);
    });

    test('Market order fee calculations accurately deduct 5% seller commission', () {
      expect(marketSellerReceives(1000, 10), 9500);
      expect(marketFeeAmount(1000, 10), 500);
      expect(marketSellerReceives(54000, 1), 51300);
      expect(marketFeeAmount(54000, 1), 2700);
    });
  });

  group('Market Screen Full Flow & State Transitions', () {
    testWidgets('MarketScreen renders browse tab with hero banner, blessing, and listing cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final MarketState mockState = MarketState(
        status: MarketStatus.ready,
        tickers: createMockMarketTickers(),
        myOrders: createMockMyOrders(),
        tickersLoaded: true,
        myOrdersLoaded: true,
        totalListings: 42,
        tickerTotal: 4,
      );

      await tester.pumpWidget(buildMarketTestHarness(marketState: mockState));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(MarketScreen), findsOneWidget);
      expect(find.byType(MarketHeroBanner), findsOneWidget);
      expect(find.textContaining('42 aktif ilan'), findsOneWidget);
      expect(find.byType(KingdomMarketBlessingBanner), findsOneWidget);
      expect(find.text('Pazar Listeleri'), findsOneWidget);
      expect(find.text('Ejder Katili Kılıç'), findsOneWidget);
      expect(find.text('Aion Muhafız Zırhı'), findsOneWidget);
    });

    testWidgets('MarketScreen switches to Sell tab and renders tradeable inventory items', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final MarketState mockState = MarketState(
        status: MarketStatus.ready,
        tickers: createMockMarketTickers(),
        myOrders: createMockMyOrders(),
        tickersLoaded: true,
        myOrdersLoaded: true,
        totalListings: 42,
        tickerTotal: 4,
      );

      await tester.pumpWidget(buildMarketTestHarness(marketState: mockState));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Tap 'Sat' tab
      await tester.tap(find.text('Sat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Eşya Sat'), findsOneWidget);
      expect(find.byType(MarketSellTab), findsOneWidget);
      expect(find.text('Ejder Katili Kılıç +3'), findsOneWidget);
    });

    testWidgets('MarketScreen switches to My Market tab and renders active orders and overview', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final MarketState mockState = MarketState(
        status: MarketStatus.ready,
        tickers: createMockMarketTickers(),
        myOrders: createMockMyOrders(),
        tickersLoaded: true,
        myOrdersLoaded: true,
        totalListings: 42,
        tickerTotal: 4,
      );

      await tester.pumpWidget(buildMarketTestHarness(marketState: mockState));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Tap 'Pazarim' tab
      await tester.tap(find.text('Pazarim'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Benim Pazarim'), findsOneWidget);
      expect(find.byType(MarketMyMarketTab), findsOneWidget);
      expect(find.text('Acik Ilan'), findsOneWidget);
      expect(find.text('Beklenen Net'), findsOneWidget);
      expect(find.text('ILANLARIM'), findsOneWidget);
    });

    testWidgets('MarketScreen displays loading spinner when market state is loading', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const MarketState loadingState = MarketState(
        status: MarketStatus.loading,
        tickers: <MarketTicker>[],
        myOrders: <MarketOrder>[],
      );

      await tester.pumpWidget(buildMarketTestHarness(marketState: loadingState));
      await tester.pump();

      expect(find.byType(MarketLoadingSpinner), findsOneWidget);
    });

    testWidgets('MarketScreen displays error message when market fetch fails', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const MarketState errorState = MarketState(
        status: MarketStatus.error,
        tickers: <MarketTicker>[],
        myOrders: <MarketOrder>[],
        errorMessage: 'Sunucuya bağlanılamadı. Lütfen tekrar deneyin.',
      );

      await tester.pumpWidget(buildMarketTestHarness(marketState: errorState));
      await tester.pump();

      expect(find.text('Sunucuya bağlanılamadı. Lütfen tekrar deneyin.'), findsOneWidget);
    });

    testWidgets('MarketScreen displays empty state when browse tickers are empty', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const MarketState emptyState = MarketState(
        status: MarketStatus.ready,
        tickers: <MarketTicker>[],
        myOrders: <MarketOrder>[],
        tickersLoaded: true,
      );

      await tester.pumpWidget(buildMarketTestHarness(marketState: emptyState));
      await tester.pump();

      expect(find.text('Sonuc yok'), findsOneWidget);
    });

    testWidgets('MarketScreen handles empty orders state in My Market tab', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const MarketState emptyOrdersState = MarketState(
        status: MarketStatus.ready,
        tickers: <MarketTicker>[],
        myOrders: <MarketOrder>[],
        tickersLoaded: true,
        myOrdersLoaded: true,
      );

      await tester.pumpWidget(buildMarketTestHarness(marketState: emptyOrdersState));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('Pazarim'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Henuz Acik Ilan Yok'), findsOneWidget);
    });

    testWidgets('MarketScreen handles no tradeable items state in Sell tab', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const MarketState state = MarketState(
        status: MarketStatus.ready,
        tickers: <MarketTicker>[],
        myOrders: <MarketOrder>[],
        tickersLoaded: true,
      );

      await tester.pumpWidget(
        buildMarketTestHarness(
          marketState: state,
          inventoryItems: <InventoryItem>[],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('Sat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Satilabilir Esya Yok'), findsOneWidget);
    });
  });

  group('Mobile Responsiveness on Authentic Viewports', () {
    testWidgets('MarketPrimaryButton meets mobile 48px touch target standard', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MarketPrimaryButton(
                label: 'Onayla',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Onayla'), findsOneWidget);
      await tester.tap(find.byType(MarketPrimaryButton));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('MarketSecondaryButton meets mobile touch target and styling', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MarketSecondaryButton(
                label: 'İptal',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('İptal'), findsOneWidget);
      await tester.tap(find.byType(MarketSecondaryButton));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('TradePrimaryButton meets mobile 48px touch target standard', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradePrimaryButton(
                label: '✅ Onayla',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final Size buttonSize = tester.getSize(find.byType(TradePrimaryButton));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('TradeSecondaryButton meets mobile 48px touch target standard', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeSecondaryButton(
                label: '❌ İptal',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final Size buttonSize = tester.getSize(find.byType(TradeSecondaryButton));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('MarketPressable provides responsive scale down and touch feedback', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MarketPressable(
                onTap: () => tapped = true,
                child: const Text('Dokun'),
              ),
            ),
          ),
        ),
      );

      final Finder pressableFinder = find.byType(MarketPressable);
      final TestGesture gesture = await tester.startGesture(tester.getCenter(pressableFinder));
      await tester.pump(const Duration(milliseconds: 50));

      final AnimatedScale scaleWidget = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scaleWidget.scale, 0.96);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('TradeNeonPanel renders fantasy glow backdrop on mobile viewport (390x844)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TradeBackdrop(
              child: SafeArea(
                child: Center(
                  child: TradeNeonPanel(
                    child: Text('Takas Paneli'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Takas Paneli'), findsOneWidget);
      expect(find.byType(TradeBackdrop), findsOneWidget);
      expect(find.byType(TradeNeonPanel), findsOneWidget);
    });

    testWidgets('MarketGlassCard renders frosted blur and luminous border decoration', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MarketGlassCard(
                borderRadius: 16,
                child: Text('Buzlu Cam Panel'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Buzlu Cam Panel'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('MarketListingCard renders with fantasy typography and haptic response on compact Android (360x640)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MarketListingCard(
                itemName: 'Mithril Zırh',
                rarity: 'mythic',
                metaLine: 'Destansı Savunma · 1 adet',
                priceText: '12.000 Altın',
                iconValue: '🛡️',
                itemType: ItemType.armor,
                onTap: () => cardTapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Mithril Zırh'), findsOneWidget);
      expect(find.text('12.000 Altın'), findsOneWidget);

      await tester.tap(find.byType(MarketListingCard));
      await tester.pump();
      expect(cardTapped, isTrue);
    });
  });
}
