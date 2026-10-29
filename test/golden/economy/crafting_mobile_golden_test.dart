import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/layout/game_chrome.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_controller.dart';
import 'package:gkk_flutter/l10n/l10n.dart';
import 'package:gkk_flutter/models/auth_model.dart';
import 'package:gkk_flutter/models/crafting_model.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/models/staff_model.dart';
import 'package:gkk_flutter/providers/auth_provider.dart';
import 'package:gkk_flutter/providers/crafting_provider.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/providers/staff_provider.dart';
import 'package:gkk_flutter/screens/crafting/crafting_screen.dart';
import 'package:gkk_flutter/screens/crafting/widgets/crafting_main_ui.dart';
import 'package:gkk_flutter/screens/crafting/widgets/crafting_preview_panel.dart';
import 'package:gkk_flutter/screens/crafting/widgets/crafting_recipe_preview_dialog.dart';
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
    'id': 'p-test-001',
    'auth_id': 'auth-test-001',
    'username': 'AionMasterSmith',
    'email': 'smith@aion2.com',
    'display_name': 'Demirci Ustası',
    'avatar_url': '',
    'avatar_frame': 'gold_celestial',
    'level': 45,
    'xp': 85000,
    'gold': 350000,
    'gems': 850,
    'energy': 100,
    'max_energy': 100,
    'attack': 980,
    'defense': 820,
    'health': 3400,
    'max_health': 3400,
    'power': 2100,
    'is_online': true,
    'is_banned': false,
    'tutorial_completed': true,
    'guild_id': 'guild-craft-01',
    'guild_role': 'artisan',
    'referral_code': 'CRAFT2026',
    'referred_by': null,
    'pvp_rating': 1420,
    'pvp_wins': 20,
    'pvp_losses': 5,
    'addiction_level': 0,
    'tolerance': 0,
    'craft_queue_slots': 3,
  });
}

List<CraftRecipe> createMockCraftRecipes() {
  return <CraftRecipe>[
    const CraftRecipe(
      id: 'rec_wpn_01',
      name: 'Ejder Katili Kılıç',
      description: 'Efsanevi ejderha aleviyle temperlenmiş kadim kılıç.',
      recipeType: 'weapon',
      itemType: 'weapon',
      outputItemId: 'wpn_sword_dragon',
      outputQuantity: 1,
      outputRarity: 'mythic',
      requiredLevel: 25,
      requiredFacilityLevel: 2,
      productionTimeSeconds: 120,
      successRate: 0.90,
      ingredients: <CraftIngredient>[
        CraftIngredient(itemId: 'mat_dragon_scale', itemName: 'Ejder Pulu', quantity: 5),
        CraftIngredient(itemId: 'mat_mithril_ingot', itemName: 'Mithril Külçesi', quantity: 10),
      ],
      gemCost: 0,
      goldCost: 2500,
      xpReward: 350,
    ),
    const CraftRecipe(
      id: 'rec_arm_01',
      name: 'Aion Muhafız Zırhı',
      description: 'Işık savaşçıları için kutsanmış göğüslük.',
      recipeType: 'armor',
      itemType: 'armor',
      outputItemId: 'chest_guardian_aion',
      outputQuantity: 1,
      outputRarity: 'legendary',
      requiredLevel: 30,
      requiredFacilityLevel: 3,
      productionTimeSeconds: 240,
      successRate: 0.85,
      ingredients: <CraftIngredient>[
        CraftIngredient(itemId: 'mat_mithril_ingot', itemName: 'Mithril Külçesi', quantity: 15),
        CraftIngredient(itemId: 'mat_celestial_essence', itemName: 'Göksel Öz', quantity: 3),
      ],
      gemCost: 10,
      goldCost: 5000,
      xpReward: 600,
    ),
    const CraftRecipe(
      id: 'rec_pot_01',
      name: 'Büyük Can İksiri',
      description: 'Yaraları hızla iyileştiren yoğunlaştırılmış can iksiri.',
      recipeType: 'potion',
      itemType: 'potion',
      outputItemId: 'potion_hp_large',
      outputQuantity: 3,
      outputRarity: 'rare',
      requiredLevel: 10,
      requiredFacilityLevel: 1,
      productionTimeSeconds: 45,
      successRate: 0.98,
      ingredients: <CraftIngredient>[
        CraftIngredient(itemId: 'mat_sunflower', itemName: 'Güneş Çiçeği', quantity: 4),
        CraftIngredient(itemId: 'mat_pure_water', itemName: 'Saf Kaynak Suyu', quantity: 2),
      ],
      gemCost: 0,
      goldCost: 400,
      xpReward: 120,
    ),
    const CraftRecipe(
      id: 'rec_acc_01',
      name: 'Yıldız Işığı Yüzüğü',
      description: 'Kullanıcısının mana akışını artıran büyülü yüzük.',
      recipeType: 'accessory',
      itemType: 'accessory',
      outputItemId: 'ring_starlight',
      outputQuantity: 1,
      outputRarity: 'epic',
      requiredLevel: 20,
      requiredFacilityLevel: 2,
      productionTimeSeconds: 90,
      successRate: 0.92,
      ingredients: <CraftIngredient>[
        CraftIngredient(itemId: 'mat_starlight_gem', itemName: 'Yıldız Taşı', quantity: 2),
        CraftIngredient(itemId: 'mat_mithril_ingot', itemName: 'Mithril Külçesi', quantity: 4),
      ],
      gemCost: 5,
      goldCost: 1800,
      xpReward: 250,
    ),
  ];
}

List<CraftQueueItem> createMockCraftQueue() {
  final DateTime now = DateTime.now();
  return <CraftQueueItem>[
    CraftQueueItem(
      id: 'queue_item_1',
      recipeId: 'rec_wpn_01',
      recipeName: 'Ejder Katili Kılıç',
      recipeIcon: '🗡️',
      batchCount: 1,
      startedAt: now.subtract(const Duration(seconds: 30)).toIso8601String(),
      completesAt: now.add(const Duration(seconds: 90)).toIso8601String(),
      isCompleted: false,
      claimed: false,
      outputItemId: 'wpn_sword_dragon',
      outputQuantity: 1,
      outputName: 'Ejder Katili Kılıç',
    ),
    CraftQueueItem(
      id: 'queue_item_2',
      recipeId: 'rec_pot_01',
      recipeName: 'Büyük Can İksiri',
      recipeIcon: '⚗️',
      batchCount: 2,
      startedAt: now.subtract(const Duration(minutes: 5)).toIso8601String(),
      completesAt: now.subtract(const Duration(minutes: 4)).toIso8601String(),
      isCompleted: true,
      claimed: false,
      outputItemId: 'potion_hp_large',
      outputQuantity: 6,
      outputName: 'Büyük Can İksiri',
    ),
  ];
}

List<InventoryItem> createMockInventoryItems() {
  return <InventoryItem>[
    InventoryItem.fromJson(<String, dynamic>{
      'row_id': 'inv_row_01',
      'item_id': 'mat_dragon_scale',
      'quantity': 12,
      'slot_position': 0,
      'is_equipped': false,
      'equipped_slot': '',
      'enhancement_level': 0,
      'is_favorite': false,
      'pending_sync': false,
      'name': 'Ejder Pulu',
      'description': 'Kadim bir ejderhadan düşen sert pul.',
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
      'potion_type': 'none',
      'energy_restore': 0,
      'health_restore': 0,
      'tolerance_increase': 0,
    }),
    InventoryItem.fromJson(<String, dynamic>{
      'row_id': 'inv_row_02',
      'item_id': 'mat_mithril_ingot',
      'quantity': 35,
      'slot_position': 1,
      'is_equipped': false,
      'equipped_slot': '',
      'enhancement_level': 0,
      'is_favorite': false,
      'pending_sync': false,
      'name': 'Mithril Külçesi',
      'description': 'Hafif ve son derece dayanıklı nadir metal.',
      'icon': '🪙',
      'item_type': 'material',
      'rarity': 'rare',
      'base_price': 80,
      'vendor_sell_price': 40,
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

class FakeCraftingNotifier extends CraftingNotifier {
  FakeCraftingNotifier({required this.initialState});
  final CraftingState initialState;

  @override
  CraftingState build() => initialState;

  @override
  Future<void> loadRecipes(int level, {bool force = false}) async {
    // Preserve initialized mock recipes
  }

  @override
  Future<void> loadQueue() async {
    // Preserve initialized mock queue
  }

  @override
  void setSelectedTab(String tab) {
    state = state.copyWith(selectedTab: tab);
  }

  @override
  void selectRecipe(String? recipeId) {
    if (recipeId == null) {
      state = state.copyWith(clearSelectedRecipe: true);
    } else {
      state = state.copyWith(selectedRecipeId: recipeId);
    }
  }

  @override
  void setBatchCount(int count) {
    state = state.copyWith(selectedBatchCount: count);
  }

  @override
  bool hasMaterials({
    required CraftRecipe recipe,
    required List<InventoryItem> inventoryItems,
    int batchCount = 1,
  }) {
    for (final CraftIngredient ingredient in recipe.ingredients) {
      int available = 0;
      for (final InventoryItem item in inventoryItems) {
        if (item.itemId == ingredient.itemId) {
          available += item.quantity;
        }
      }
      if (available < ingredient.quantity * batchCount) {
        return false;
      }
    }
    return true;
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
          id: 'auth-test-001',
          username: 'AionMasterSmith',
          email: 'smith@aion2.com',
          level: 45,
          gold: 350000,
          gems: 850,
          energy: 100,
          maxEnergy: 100,
          attack: 980,
          defense: 820,
          health: 3400,
          maxHealth: 3400,
          power: 2100,
          guildId: 'guild-craft-01',
          guildRole: 'artisan',
        ),
      );
}

Widget buildCraftingMobileTestHarness({
  required GlobalKey repaintKey,
  required CraftingState craftingState,
  PlayerProfile? playerProfile,
  List<InventoryItem>? inventoryItems,
  Widget? overrideChild,
}) {
  final FakeCraftingNotifier craftingNotifier =
      FakeCraftingNotifier(initialState: craftingState);
  final List<InventoryItem> items = inventoryItems ?? createMockInventoryItems();

  return ProviderScope(
    overrides: [
      craftingProvider.overrideWith(() => craftingNotifier),
      playerProvider.overrideWith(() => FakePlayerNotifier(mockProfile: playerProfile ?? createMockPlayerProfile())),
      inventoryProvider.overrideWith(() => FakeInventoryNotifier(items: items)),
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
            child: overrideChild ?? const CraftingScreen(),
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

  group('Crafting Mobile Golden & Widget Tests (390x844 SafeArea)', () {
    testWidgets('Captures golden mobile screenshot: Real CraftingScreen all recipes & active queue', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final CraftingState state = CraftingState(
        recipes: createMockCraftRecipes(),
        queue: createMockCraftQueue(),
        isLoading: false,
        isCrafting: false,
        isCancelling: false,
        isExpandingQueue: false,
        selectedBatchCount: 1,
        selectedTab: 'tumu',
      );

      await tester.pumpWidget(buildCraftingMobileTestHarness(
        repaintKey: repaintKey,
        craftingState: state,
      ));

      // Allow microtasks & initial render turn to process
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Verify no RenderFlex overflow exception
      expect(tester.takeException(), isNull, reason: 'CraftingScreen must have zero RenderFlex overflow');

      // Verify key screen widgets
      expect(find.byType(CraftingScreen), findsOneWidget);
      expect(find.byType(CraftingCategoryTabBar), findsOneWidget);
      expect(find.byType(GameTopBar), findsOneWidget);
      expect(find.byType(GameBottomBar), findsOneWidget);

      // Verify authentic recipe cards are present
      expect(find.text('Ejder Katili Kılıç'), findsWidgets);
      expect(find.text('Aion Muhafız Zırhı'), findsWidgets);
      expect(find.text('Büyük Can İksiri'), findsWidgets);

      // Capture authentic golden mobile screenshot
      final File screenshot = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '01_crafting_screen_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      final Uint8List bytes = await screenshot.readAsBytes();
      expect(bytes.length, greaterThan(2048));
      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }
    });

    testWidgets('Captures golden mobile screenshot: Weapon category tab & active queue layout stability', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final CraftingState state = CraftingState(
        recipes: createMockCraftRecipes(),
        queue: createMockCraftQueue(),
        isLoading: false,
        isCrafting: false,
        isCancelling: false,
        isExpandingQueue: false,
        selectedBatchCount: 1,
        selectedTab: 'weapon',
      );

      await tester.pumpWidget(buildCraftingMobileTestHarness(
        repaintKey: repaintKey,
        craftingState: state,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
      expect(find.byType(CraftingScreen), findsOneWidget);

      // Verify weapon recipe is filtered and displayed
      expect(find.text('Ejder Katili Kılıç'), findsWidgets);

      final File screenshot = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '02_crafting_category_weapons_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      final Uint8List bytes = await screenshot.readAsBytes();
      expect(bytes.length, greaterThan(2048));
      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }
    });

    testWidgets('Captures golden mobile screenshot: Crafting Recipe Preview Dialog on 390x844', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final CraftRecipe previewRecipe = createMockCraftRecipes().first;
      final CraftingState state = CraftingState(
        recipes: createMockCraftRecipes(),
        queue: createMockCraftQueue(),
        isLoading: false,
        isCrafting: false,
        isCancelling: false,
        isExpandingQueue: false,
        selectedBatchCount: 1,
        selectedRecipeId: previewRecipe.id,
        selectedTab: 'tumu',
      );

      await tester.pumpWidget(buildCraftingMobileTestHarness(
        repaintKey: repaintKey,
        craftingState: state,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap on the first recipe card to trigger modal sheet
      final Finder recipeTile = find.text('Ejder Katili Kılıç').first;
      await tester.tap(recipeTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull, reason: 'Modal dialog must open without overflow on 390x844');

      // Verify modal contents
      expect(find.byType(CraftingPreviewPanel), findsOneWidget);
      expect(find.text('Gereken Malzemeler'), findsOneWidget);

      final File screenshot = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '03_crafting_recipe_preview_modal_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      final Uint8List bytes = await screenshot.readAsBytes();
      expect(bytes.length, greaterThan(2048));
      for (int i = 0; i < kPngSignature.length; i++) {
        expect(bytes[i], equals(kPngSignature[i]));
      }
    });

    testWidgets('Widget Layout Stability: Empty category state renders cleanly with zero overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      // Empty recipe list
      final CraftingState state = CraftingState(
        recipes: const <CraftRecipe>[],
        queue: const <CraftQueueItem>[],
        isLoading: false,
        isCrafting: false,
        isCancelling: false,
        isExpandingQueue: false,
        selectedBatchCount: 1,
        selectedTab: 'rune',
      );

      await tester.pumpWidget(buildCraftingMobileTestHarness(
        repaintKey: repaintKey,
        craftingState: state,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('Bu kategoride tarif bulunamadı.'), findsOneWidget);

      final File screenshot = await captureWidgetToPngFile(
        tester: tester,
        repaintKey: repaintKey,
        filename: '04_crafting_empty_state_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      final Uint8List bytes = await screenshot.readAsBytes();
      expect(bytes.length, greaterThan(1024));
    });
  });
}
