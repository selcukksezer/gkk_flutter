import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/errors/app_exception.dart';
import 'package:gkk_flutter/l10n/l10n.dart';
import 'package:gkk_flutter/models/crafting_model.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/providers/box_opening_provider.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/repositories/inventory_repository.dart';
import 'package:gkk_flutter/screens/crafting/widgets/crafting_main_ui.dart';
import 'package:gkk_flutter/screens/crafting/widgets/crafting_preview_panel.dart';
import 'package:gkk_flutter/screens/inventory/inventory_screen.dart';
import 'package:gkk_flutter/screens/inventory/widgets/aion_rarity_glow.dart';
import 'package:gkk_flutter/screens/inventory/widgets/inventory_item_detail_panel.dart';
import 'package:gkk_flutter/screens/inventory/widgets/inventory_power_badge.dart';

class _FakeInventoryRepository implements InventoryRepository {
  _FakeInventoryRepository(this.snapshot, {this.shouldThrowOnFetch = false});

  InventorySnapshot snapshot;
  bool shouldThrowOnFetch;

  @override
  Future<InventorySnapshot> fetchInventory() async {
    if (shouldThrowOnFetch) {
      throw AppException('Envanter yüklenemedi.', code: 'FETCH_FAILED');
    }
    return snapshot;
  }

  @override
  Future<bool> equipItem({required String rowId, required String slot}) async => true;

  @override
  Future<bool> unequipItem({required String slot}) async => true;

  @override
  Future<bool> swapSlots({required int fromSlot, required int toSlot}) async => true;

  @override
  Future<bool> moveItemToSlot({required String rowId, required int targetSlot}) async => true;

  @override
  Future<bool> unequipItemToSlot({required String rowId, required String slot, required int targetSlot}) async => true;

  @override
  Future<bool> swapEquipWithSlot({required String equipSlot, required int targetSlot}) async => true;

  @override
  Future<bool> addItemToServer({required String itemId, required int quantity, int? slotPosition}) async => true;

  @override
  Future<bool> useDetox({required String rowId}) async => true;

  @override
  Future<UseItemResult> useStatResetScroll({required String rowId}) async => const UseItemResult(success: true);

  @override
  Future<UseItemResult> useNameChangeScroll({required String rowId, required String newDisplayName}) async =>
      const UseItemResult(success: true);

  @override
  Future<bool> splitStack({required String rowId, required int splitQuantity, required int targetSlot}) async => true;

  @override
  Future<SellItemResult> sellItemByRow({required String rowId, required int quantity}) async =>
      const SellItemResult(success: true, goldEarned: 100);

  @override
  Future<bool> trashItem({required String rowId}) async => true;

  @override
  Future<bool> toggleFavorite({required String rowId, required bool isFavorite}) async => true;

  @override
  Future<OpenLootBoxResult> openLootBox({required String rowId}) async =>
      const OpenLootBoxResult(success: true);

  @override
  Future<UsePotionResult> usePotion({required String rowId}) async =>
      const UsePotionResult(success: true);
}

PlayerProfile _sampleProfile({
  int level = 25,
  int power = 280,
  int gold = 15000,
  int gems = 250,
}) {
  return PlayerProfile(
    id: 'usr_1',
    authId: 'auth_1',
    username: 'Hero',
    email: 'hero@aion2.com',
    displayName: 'Aion Hero',
    avatarUrl: null,
    avatarFrame: null,
    level: level,
    xp: 5000,
    gold: gold,
    gems: gems,
    energy: 100,
    maxEnergy: 100,
    attack: 100,
    defense: 80,
    health: 500,
    maxHealth: 500,
    power: power,
    isOnline: true,
    isBanned: false,
    tutorialCompleted: true,
    guildId: null,
    guildRole: null,
    referralCode: null,
    referredBy: null,
    pvpRating: 1000,
    pvpWins: 10,
    pvpLosses: 2,
    addictionLevel: 0,
    tolerance: 0,
    lastPotionUsedAt: null,
    warriorBloodlustUntil: null,
    hospitalUntil: null,
    prisonUntil: null,
    prisonReason: null,
    globalSuspicionLevel: 0,
    lastBribeAt: null,
    lastLoginAt: null,
    lastLogin: null,
    createdAt: '2026-03-27T00:00:00Z',
    updatedAt: '2026-03-27T00:00:00Z',
  );
}

class _FakePlayerNotifier extends PlayerNotifier {
  _FakePlayerNotifier([PlayerProfile? profile])
      : _profile = profile ?? _sampleProfile();

  final PlayerProfile _profile;

  @override
  PlayerState build() => PlayerState(
        status: PlayerStatus.ready,
        profile: _profile,
      );
}

class _FakeBoxOpeningNotifier extends BoxOpeningNotifier {
  _FakeBoxOpeningNotifier([this._initialOpenings = const <BoxOpening>[]]);

  final List<BoxOpening> _initialOpenings;

  @override
  List<BoxOpening> build() => _initialOpenings;

  @override
  Future<void> load() async {}
}

InventoryItem _createSampleItem({
  required String rowId,
  required String name,
  required Rarity rarity,
  ItemType itemType = ItemType.weapon,
  EquipSlot equipSlot = EquipSlot.weapon,
  int slotPosition = 0,
  bool isEquipped = false,
  int enhancementLevel = 0,
  int quantity = 1,
  int attack = 50,
  int defense = 20,
  int health = 0,
  int luck = 10,
  int vendorSellPrice = 500,
  int requiredLevel = 1,
  bool isFavorite = false,
  bool isTradeable = true,
}) {
  return InventoryItem.fromJson(<String, dynamic>{
    'row_id': rowId,
    'item_id': 'item_$rowId',
    'name': name,
    'description': 'Efsanevi Aion 2 savas donanimi',
    'icon': 'weapon_sword',
    'item_type': itemType.name,
    'rarity': rarity.name,
    'equip_slot': equipSlot.name,
    'weapon_type': 'sword',
    'armor_type': 'none',
    'sub_type': 'sword',
    'slot_position': slotPosition,
    'is_equipped': isEquipped,
    'equipped_slot': isEquipped ? equipSlot.name : '',
    'enhancement_level': enhancementLevel,
    'quantity': quantity,
    'attack': attack,
    'defense': defense,
    'health': health,
    'power': attack + defense + health,
    'luck': luck,
    'mana': 0,
    'base_price': 1000,
    'vendor_sell_price': vendorSellPrice,
    'required_level': requiredLevel,
    'can_enhance': true,
    'max_enhancement': 15,
    'is_stackable': itemType == ItemType.potion || itemType == ItemType.material,
    'max_stack': 99,
    'is_tradeable': isTradeable,
    'is_han_only': false,
    'is_market_tradeable': true,
    'is_direct_tradeable': true,
    'potion_type': itemType == ItemType.potion ? 'health' : 'none',
    'energy_restore': 0,
    'health_restore': itemType == ItemType.potion ? 150 : 0,
    'tolerance_increase': 0,
    'is_favorite': isFavorite,
    'pending_sync': false,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aion 2 Rarity Tier System & Visual Hierarchy', () {
    test('AionRarityTier correctly maps standard rarities', () {
      expect(AionRarityTier.fromRarity(Rarity.common), AionRarityTier.common);
      expect(AionRarityTier.fromRarity(Rarity.uncommon), AionRarityTier.common);
      expect(AionRarityTier.fromRarity(Rarity.rare), AionRarityTier.rare);
      expect(AionRarityTier.fromRarity(Rarity.epic), AionRarityTier.epic);
      expect(AionRarityTier.fromRarity(Rarity.legendary), AionRarityTier.mythic);
      expect(AionRarityTier.fromRarity(Rarity.mythic), AionRarityTier.mythic);
    });

    test('AionRarityTier maps high enhancements and archon items to Archon tier', () {
      expect(
        AionRarityTier.fromRarity(Rarity.mythic, enhancementLevel: 9),
        AionRarityTier.archon,
      );
      expect(
        AionRarityTier.fromRarity(Rarity.rare, itemId: 'wpn_archon_blade'),
        AionRarityTier.archon,
      );
      expect(
        AionRarityTier.fromString('archon'),
        AionRarityTier.archon,
      );
    });

    test('AionRarityTier maps localized strings properly', () {
      expect(AionRarityTier.fromString('nadir'), AionRarityTier.rare);
      expect(AionRarityTier.fromString('destansi'), AionRarityTier.epic);
      expect(AionRarityTier.fromString('mitik'), AionRarityTier.mythic);
      expect(AionRarityTier.fromString('efsanevi'), AionRarityTier.mythic);
    });

    test('AionRarityTier maintains AAA glow blur radius and visual radiance hierarchy', () {
      expect(AionRarityTier.common.glowBlurRadius, lessThan(AionRarityTier.rare.glowBlurRadius));
      expect(AionRarityTier.rare.glowBlurRadius, lessThan(AionRarityTier.epic.glowBlurRadius));
      expect(AionRarityTier.epic.glowBlurRadius, lessThan(AionRarityTier.mythic.glowBlurRadius));
      expect(AionRarityTier.mythic.glowBlurRadius, lessThan(AionRarityTier.archon.glowBlurRadius));

      expect(AionRarityTier.common.hasSparkles, isFalse);
      expect(AionRarityTier.rare.hasSparkles, isTrue);
      expect(AionRarityTier.epic.hasSparkles, isTrue);
      expect(AionRarityTier.mythic.hasSparkles, isTrue);
      expect(AionRarityTier.archon.hasSparkles, isTrue);
    });

    test('AionRarityTier color tokens adhere to Aion 2 chromatic identity', () {
      for (final tier in AionRarityTier.values) {
        expect(tier.primaryColor, isNotNull);
        expect(tier.secondaryColor, isNotNull);
        expect(tier.glowColor, isNotNull);
        expect(tier.displayName.isNotEmpty, isTrue);
      }
    });

    test('AionHaptics complete safely without unhandled errors', () async {
      await expectLater(AionHaptics.slotSelect(), completes);
      await expectLater(AionHaptics.dragStart(), completes);
      await expectLater(AionHaptics.slotDrop(), completes);
      await expectLater(AionHaptics.equipSuccess(), completes);
      await expectLater(AionHaptics.craftSuccess(), completes);
      await expectLater(AionHaptics.tabSwitch(), completes);
    });
  });

  group('AionRarityGlowBorder & EnchantingSparklesOverlay Widget Rendering', () {
    testWidgets('AionRarityGlowBorder renders child with rarity gradient and corners', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 80,
                height: 80,
                child: AionRarityGlowBorder(
                  tier: AionRarityTier.archon,
                  isSelected: true,
                  child: const Text('Slot'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Slot'), findsOneWidget);
      expect(find.byType(AionRarityGlowBorder), findsOneWidget);
    });

    testWidgets('AionRarityGlowBorder reflects selected and highlighted states with liquid gold/primary glow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 80,
                height: 80,
                child: AionRarityGlowBorder(
                  tier: AionRarityTier.epic,
                  isSelected: false,
                  isHighlighted: true,
                  hasActiveGlow: true,
                  child: const Text('Highlighted'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Highlighted'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('EnchantingSparklesOverlay ticks particle animation smoothly without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: EnchantingSparklesOverlay(
                  tier: AionRarityTier.epic,
                  particleCount: 8,
                  child: Text('Enchanted'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Enchanted'), findsOneWidget);
      // Advance animation frames
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('InventoryItemDetailPanel Glassmorphic Mobile Inspect Card', () {
    testWidgets('renders glassmorphic inspect card with Aion 2 glow, Bento stats and bottom controls', (tester) async {
      final sampleItem = _createSampleItem(
        rowId: 'archon_1',
        name: 'Gök Tanrısı Kılıcı',
        rarity: Rarity.mythic,
        enhancementLevel: 10,
        attack: 420,
        defense: 150,
      );

      bool equipTapped = false;

      final actions = InventoryItemDetailActions(
        onEquip: (item) async {
          equipTapped = true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: InventoryItemDetailPanel(
                  item: sampleItem,
                  actions: actions,
                  isFavorite: true,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify item title and enhancement level
      expect(find.text(sampleItem.name.toUpperCase()), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);

      // Verify Aion 2 Archon Rarity badge
      expect(find.text('ARKON'), findsOneWidget);

      // Verify Bento stats
      expect(find.text('SALDIRI'), findsOneWidget);
      expect(find.text('SAVUNMA'), findsOneWidget);
      expect(find.text('GÜÇ'), findsOneWidget);

      // Verify bottom thumb action buttons
      expect(find.text('KUŞAN (WEAPON)'), findsOneWidget);

      // Tap primary action button and verify trigger
      await tester.tap(find.text('KUŞAN (WEAPON)'));
      await tester.pump();
      expect(equipTapped, isTrue);
    });

    testWidgets('renders equipped weapon with unequip action and live stat comparison diffs', (tester) async {
      final equippedWeapon = _createSampleItem(
        rowId: 'eq_wpn',
        name: 'Eski Çelik Kılıç',
        rarity: Rarity.rare,
        isEquipped: true,
        enhancementLevel: 0,
        attack: 100,
        defense: 50,
      );

      final inspectedWeapon = _createSampleItem(
        rowId: 'new_wpn',
        name: 'Ejder Yakan Kılıç',
        rarity: Rarity.epic,
        isEquipped: false,
        enhancementLevel: 5,
        attack: 250,
        defense: 30,
      );

      bool unequipTapped = false;

      final actions = InventoryItemDetailActions(
        onUnequip: (item) async {
          unequipTapped = true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: InventoryItemDetailPanel(
                  item: equippedWeapon,
                  equippedItem: inspectedWeapon,
                  actions: actions,
                  isFavorite: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text(equippedWeapon.name.toUpperCase()), findsOneWidget);
      expect(find.text('ÇIKAR (WEAPON)'), findsOneWidget);

      await tester.tap(find.text('ÇIKAR (WEAPON)'));
      await tester.pump();
      expect(unequipTapped, isTrue);
    });

    testWidgets('renders consumable potion with KULLAN action button and health effect description', (tester) async {
      final potionItem = _createSampleItem(
        rowId: 'pot_1',
        name: 'Büyük İksir',
        rarity: Rarity.rare,
        itemType: ItemType.potion,
        equipSlot: EquipSlot.none,
        quantity: 3,
      );

      bool useTapped = false;

      final actions = InventoryItemDetailActions(
        onUse: (item) async {
          useTapped = true;
        },
        consumableEffectLabel: '+150 Can Yeniler',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: InventoryItemDetailPanel(
                  item: potionItem,
                  actions: actions,
                  isFavorite: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text(potionItem.name.toUpperCase()), findsOneWidget);
      expect(find.text('KULLAN'), findsOneWidget);
      expect(find.text('+150 Can Yeniler'), findsOneWidget);

      await tester.tap(find.text('KULLAN'));
      await tester.pump();
      expect(useTapped, isTrue);
    });

    testWidgets('disables equip button when player level is insufficient', (tester) async {
      final highLevelWeapon = _createSampleItem(
        rowId: 'wpn_high',
        name: 'Kadim Balta',
        rarity: Rarity.epic,
        requiredLevel: 50,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: InventoryItemDetailPanel(
                  item: highLevelWeapon,
                  actions: const InventoryItemDetailActions(),
                  isFavorite: false,
                  playerLevel: 20,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('SEVİYE YETERSİZ (Lv.50)'), findsOneWidget);
    });
  });

  group('InventoryScreen Mobile Responsive Grid & Haptics', () {
    testWidgets('renders mobile 5-column grid and 8-slot equipped panel with safe area', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sampleWeapon = _createSampleItem(
        rowId: 'wpn_1',
        name: 'Mithril Kılıç',
        rarity: Rarity.rare,
        isEquipped: true,
        equipSlot: EquipSlot.weapon,
      );

      final sampleBagItem = _createSampleItem(
        rowId: 'bag_1',
        name: 'Şifa İksiri',
        rarity: Rarity.common,
        itemType: ItemType.potion,
        equipSlot: EquipSlot.none,
        slotPosition: 0,
        quantity: 5,
      );

      final fakeRepo = _FakeInventoryRepository(
        InventorySnapshot(
          items: <InventoryItem>[sampleBagItem],
          equippedItems: <String, InventoryItem?>{'weapon': sampleWeapon},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(fakeRepo),
            playerProvider.overrideWith(() => _FakePlayerNotifier()),
            boxOpeningProvider.overrideWith(() => _FakeBoxOpeningNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InventoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify equipment section header & power badge
      expect(find.text('Kusanilanlar'), findsOneWidget);
      expect(find.byType(InventoryPowerBadge), findsOneWidget);

      // Verify inventory section title & capacity pill
      expect(find.text('ENVANTER'), findsOneWidget);
      expect(find.text('1/$inventoryCapacity'), findsOneWidget);

      // Verify dual gauge
      expect(find.textContaining('KAPASİTE: 1 / $inventoryCapacity'), findsOneWidget);
      expect(find.textContaining('AĞIRLIK:'), findsOneWidget);

      // Verify filter category chips (all 6)
      expect(find.text('Hepsi'), findsOneWidget);
      expect(find.text('Silah'), findsOneWidget);
      expect(find.text('Zırh'), findsOneWidget);
      expect(find.text('İksir'), findsOneWidget);
      expect(find.text('Malzeme'), findsOneWidget);
      expect(find.text('Görev'), findsOneWidget);

      // Verify Action Bar buttons (Sırala, Hızlı Sat, Ayrıştır)
      expect(find.text('Sırala'), findsOneWidget);
      expect(find.text('Hızlı Sat'), findsOneWidget);
      expect(find.text('Ayrıştır'), findsOneWidget);

      // Tap on filter tab to test haptic responsiveness
      await tester.tap(find.text('İksir'));
      await tester.pumpAndSettle();

      // Test scroll responsiveness without hitch
      final scrollable = find.byType(SingleChildScrollView).first;
      await tester.drag(scrollable, const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.drag(scrollable, const Offset(0, 200));
      await tester.pumpAndSettle();
    });

    testWidgets('opens sort bottom sheet and switches sort criterion smoothly', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final itemA = _createSampleItem(rowId: 'it_1', name: 'Zırh', rarity: Rarity.rare, slotPosition: 0);
      final itemB = _createSampleItem(rowId: 'it_2', name: 'Kılıç', rarity: Rarity.mythic, slotPosition: 1);

      final fakeRepo = _FakeInventoryRepository(
        InventorySnapshot(
          items: <InventoryItem>[itemA, itemB],
          equippedItems: const <String, InventoryItem?>{},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(fakeRepo),
            playerProvider.overrideWith(() => _FakePlayerNotifier()),
            boxOpeningProvider.overrideWith(() => _FakeBoxOpeningNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InventoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Sort button
      await tester.tap(find.text('Sırala'));
      await tester.pumpAndSettle();

      // Verify bottom sheet options
      expect(find.text('ENVANTERİ SIRALA'), findsOneWidget);
      expect(find.text('Çanta Sırası (Varsayılan)'), findsOneWidget);
      expect(find.text('Nadirlik Derecesi'), findsOneWidget);
      expect(find.text('Gereken Seviye / Güç'), findsOneWidget);
      expect(find.text('Eşya Türü'), findsOneWidget);

      // Choose Nadirlik
      await tester.tap(find.text('Nadirlik Derecesi'));
      await tester.pumpAndSettle();

      expect(find.text('Nadirlik'), findsOneWidget);
    });

    testWidgets('opens quick-sell bottom sheet with tradeable unequipped items', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sellableItem = _createSampleItem(
        rowId: 'sell_1',
        name: 'Eski Çekiç',
        rarity: Rarity.common,
        vendorSellPrice: 120,
        isTradeable: true,
      );

      final fakeRepo = _FakeInventoryRepository(
        InventorySnapshot(
          items: <InventoryItem>[sellableItem],
          equippedItems: const <String, InventoryItem?>{},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(fakeRepo),
            playerProvider.overrideWith(() => _FakePlayerNotifier()),
            boxOpeningProvider.overrideWith(() => _FakeBoxOpeningNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InventoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Hızlı Sat
      await tester.tap(find.text('Hızlı Sat'));
      await tester.pumpAndSettle();

      expect(find.text('HIZLI SATIŞ'), findsOneWidget);
      expect(find.text('Eski Çekiç'), findsOneWidget);
      expect(find.text('Seçilenleri Hızlı Sat'), findsOneWidget);
    });

    testWidgets('opens bulk-salvage bottom sheet with unequipped gear', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final salvageItem = _createSampleItem(
        rowId: 'salvage_1',
        name: 'Hurda Göğüslük',
        rarity: Rarity.common,
        itemType: ItemType.armor,
        equipSlot: EquipSlot.chest,
      );

      final fakeRepo = _FakeInventoryRepository(
        InventorySnapshot(
          items: <InventoryItem>[salvageItem],
          equippedItems: const <String, InventoryItem?>{},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(fakeRepo),
            playerProvider.overrideWith(() => _FakePlayerNotifier()),
            boxOpeningProvider.overrideWith(() => _FakeBoxOpeningNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InventoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Ayrıştır
      await tester.tap(find.text('Ayrıştır'));
      await tester.pumpAndSettle();

      expect(find.text('TOPLU AYRIŞTIRMA'), findsOneWidget);
      expect(find.text('Hurda Göğüslük'), findsOneWidget);
      expect(find.text('Donanımları Ayrıştır'), findsOneWidget);
    });

    testWidgets('renders 20 empty runic slots when inventory is empty', (tester) async {
      final fakeRepo = _FakeInventoryRepository(
        const InventorySnapshot(
          items: <InventoryItem>[],
          equippedItems: <String, InventoryItem?>{},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(fakeRepo),
            playerProvider.overrideWith(() => _FakePlayerNotifier()),
            boxOpeningProvider.overrideWith(() => _FakeBoxOpeningNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InventoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('0/$inventoryCapacity'), findsOneWidget);
      // Runic numbers 1, 2, ..., 20 are rendered in empty slot centers
      expect(find.text('1'), findsWidgets);
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets('renders overburdened state warning banner when capacity or weight limit is exceeded', (tester) async {
      // 20 heavy weapons filling capacity completely
      final fullItems = List<InventoryItem>.generate(20, (i) {
        return _createSampleItem(
          rowId: 'w_$i',
          name: 'Ağır Kılıç #$i',
          rarity: Rarity.rare,
          slotPosition: i,
        );
      });

      final fakeRepo = _FakeInventoryRepository(
        InventorySnapshot(
          items: fullItems,
          equippedItems: const <String, InventoryItem?>{},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(fakeRepo),
            playerProvider.overrideWith(() => _FakePlayerNotifier()),
            boxOpeningProvider.overrideWith(() => _FakeBoxOpeningNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InventoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('20/20'), findsOneWidget);
      expect(find.textContaining('AĞIR YÜK'), findsOneWidget);
    });

    testWidgets('renders error view with retry action button on repository failure', (tester) async {
      final fakeRepo = _FakeInventoryRepository(
        const InventorySnapshot(
          items: <InventoryItem>[],
          equippedItems: <String, InventoryItem?>{},
        ),
        shouldThrowOnFetch: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(fakeRepo),
            playerProvider.overrideWith(() => _FakePlayerNotifier()),
            boxOpeningProvider.overrideWith(() => _FakeBoxOpeningNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InventoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Envanter yüklenemedi.'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);
    });

    testWidgets('renders wide screen layout on tablet / desktop width >= 980', (tester) async {
      tester.view.physicalSize = const Size(1200 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = _FakeInventoryRepository(
        const InventorySnapshot(
          items: <InventoryItem>[],
          equippedItems: <String, InventoryItem?>{},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(fakeRepo),
            playerProvider.overrideWith(() => _FakePlayerNotifier()),
            boxOpeningProvider.overrideWith(() => _FakeBoxOpeningNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InventoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kusanilanlar'), findsOneWidget);
      expect(find.text('ENVANTER'), findsOneWidget);
    });

    testWidgets('renders active box opening panel with countdown and claim action', (tester) async {
      final readyOpening = BoxOpening(
        openingId: 'op_1',
        inventoryRowId: 'row_box_1',
        boxId: 'box_gold',
        boxName: 'Kadim Altın Sandık',
        opensAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
        payment: 'gems',
      );

      final fakeRepo = _FakeInventoryRepository(
        const InventorySnapshot(
          items: <InventoryItem>[],
          equippedItems: <String, InventoryItem?>{},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(fakeRepo),
            playerProvider.overrideWith(() => _FakePlayerNotifier()),
            boxOpeningProvider.overrideWith(() => _FakeBoxOpeningNotifier(<BoxOpening>[readyOpening])),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InventoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('⏳ AÇILAN KUTULAR'), findsOneWidget);
      expect(find.text('Kadim Altın Sandık'), findsOneWidget);
      expect(find.text('Ödülü Al'), findsOneWidget);
    });
  });

  group('Crafting UI Modern Aion 2 Aesthetics & Thumb Controls', () {
    testWidgets('CraftingRecipeGridCard renders Aion 2 rarity glow and handles tap', (tester) async {
      final sampleRecipe = CraftRecipe(
        id: 'rcp_1',
        name: 'Ejder Katili Baltası',
        description: 'Ejderhalara karsi etkili efsanevi balta',
        recipeType: 'weapon',
        itemType: 'weapon',
        outputItemId: 'wpn_dragon_axe',
        outputName: 'Ejder Katili Baltası',
        outputQuantity: 1,
        outputRarity: 'mythic',
        requiredLevel: 40,
        requiredFacilityLevel: 1,
        goldCost: 2500,
        productionTimeSeconds: 60,
        ingredients: const <CraftIngredient>[
          CraftIngredient(itemId: 'mat_dragon_scale', quantity: 4, itemName: 'Ejder Pulu'),
        ],
        successRate: 1.0,
        gemCost: 0,
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                height: 200,
                child: CraftingRecipeGridCard(
                  recipe: sampleRecipe,
                  isSelected: false,
                  hasMaterials: true,
                  onTap: () {
                    tapped = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Ejder Katili Baltası'), findsOneWidget);
      expect(find.text('Sv.40'), findsOneWidget);

      await tester.tap(find.byType(CraftingRecipeGridCard));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('CraftingPreviewPanel renders thumb-friendly batch controls and bottom action button', (tester) async {
      final sampleRecipe = CraftRecipe(
        id: 'rcp_2',
        name: 'Kutsal Şifa İksiri',
        description: 'Yaralari aninda iyilestiren kutsal iksir',
        recipeType: 'potion',
        itemType: 'potion',
        outputItemId: 'pot_divine_heal',
        outputName: 'Kutsal Şifa İksiri',
        outputQuantity: 2,
        outputRarity: 'archon',
        requiredLevel: 20,
        requiredFacilityLevel: 1,
        goldCost: 300,
        productionTimeSeconds: 15,
        ingredients: const <CraftIngredient>[
          CraftIngredient(itemId: 'herb_sacred', quantity: 3, itemName: 'Kutsal Ot'),
        ],
        successRate: 0.95,
        gemCost: 0,
      );

      int batchCount = 1;
      bool craftTapped = false;
      bool closeTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CraftingPreviewPanel(
                recipe: sampleRecipe,
                batchCount: batchCount,
                canCraft: true,
                isCrafting: false,
                hasEnoughMaterials: true,
                canAffordGold: true,
                playerGold: 5000,
                queueUsed: 1,
                queueMax: 4,
                ownedQuantities: const {'herb_sacred': 20},
                onCraft: () {
                  craftTapped = true;
                },
                onClose: () {
                  closeTapped = true;
                },
                onBatchDecrement: () {
                  batchCount--;
                },
                onBatchIncrement: () {
                  batchCount++;
                },
              ),
            ),
          ),
        ),
      );

      // Verify Aion 2 Archon label
      expect(find.text('ARKON · Üretim Ön İzlemesi'), findsOneWidget);
      expect(find.text('Kutsal Şifa İksiri'), findsWidgets);

      // Verify thumb-friendly batch buttons
      expect(find.text('+'), findsOneWidget);
      expect(find.text('−'), findsOneWidget);

      // Verify bottom action buttons
      expect(find.text('İptal'), findsOneWidget);
      expect(find.text('🔨 Üretimi Başlat (1x)'), findsOneWidget);

      // Tap craft button
      await tester.tap(find.text('🔨 Üretimi Başlat (1x)'));
      await tester.pump();
      expect(craftTapped, isTrue);

      // Tap cancel button
      await tester.tap(find.text('İptal'));
      await tester.pump();
      expect(closeTapped, isTrue);
    });

    testWidgets('CraftingPreviewPanel disables craft button when player has insufficient gold or materials', (tester) async {
      final sampleRecipe = CraftRecipe(
        id: 'rcp_3',
        name: 'Efsanevi Miğfer',
        description: 'Güçlü miğfer',
        recipeType: 'armor',
        itemType: 'armor',
        outputItemId: 'arm_helm',
        outputName: 'Efsanevi Miğfer',
        outputQuantity: 1,
        outputRarity: 'epic',
        requiredLevel: 25,
        requiredFacilityLevel: 1,
        goldCost: 1000,
        productionTimeSeconds: 30,
        ingredients: const <CraftIngredient>[
          CraftIngredient(itemId: 'mat_iron', quantity: 10, itemName: 'Demir Külçe'),
        ],
        successRate: 0.9,
        gemCost: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CraftingPreviewPanel(
                recipe: sampleRecipe,
                batchCount: 1,
                canCraft: false,
                isCrafting: false,
                hasEnoughMaterials: false,
                canAffordGold: false,
                playerGold: 100,
                queueUsed: 1,
                queueMax: 4,
                ownedQuantities: const {'mat_iron': 2},
                onCraft: () {},
                onClose: () {},
                onBatchDecrement: () {},
                onBatchIncrement: () {},
              ),
            ),
          ),
        ),
      );

      // Verify disabled state label on craft button
      expect(find.text('Yetersiz Malzeme veya Altın'), findsOneWidget);
    });
  });

  group('Theme Styling & Glassmorphic Customization Robustness', () {
    testWidgets('renders reliably under dark high-contrast and custom theme tokens without errors', (tester) async {
      final customTheme = ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF06B6D4),
          surface: Color(0xFF0B0F19),
        ),
        fontFamily: 'Plus Jakarta Sans',
      );

      final fakeRepo = _FakeInventoryRepository(
        const InventorySnapshot(
          items: <InventoryItem>[],
          equippedItems: <String, InventoryItem?>{},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(fakeRepo),
            playerProvider.overrideWith(() => _FakePlayerNotifier()),
            boxOpeningProvider.overrideWith(() => _FakeBoxOpeningNotifier()),
          ],
          child: MaterialApp(
            theme: customTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const InventoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ENVANTER'), findsOneWidget);
      expect(find.text('Kusanilanlar'), findsOneWidget);
    });
  });
}
