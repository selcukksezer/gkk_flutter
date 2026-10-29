import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/l10n/l10n.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/providers/box_opening_provider.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/repositories/inventory_repository.dart';
import 'package:gkk_flutter/screens/inventory/inventory_screen.dart';

class _FakeInventoryRepository implements InventoryRepository {
  _FakeInventoryRepository(this.snapshot);

  final InventorySnapshot snapshot;

  @override
  Future<InventorySnapshot> fetchInventory() async => snapshot;

  @override
  Future<bool> equipItem({required String rowId, required String slot}) async => true;

  @override
  Future<bool> unequipItem({required String slot}) async => true;

  @override
  Future<bool> swapSlots({required int fromSlot, required int toSlot}) async => true;

  @override
  Future<bool> moveItemToSlot({required String rowId, required int targetSlot}) async => true;

  @override
  Future<bool> unequipItemToSlot(
          {required String rowId, required String slot, required int targetSlot}) async =>
      true;

  @override
  Future<bool> swapEquipWithSlot(
          {required String equipSlot, required int targetSlot}) async =>
      true;

  @override
  Future<bool> addItemToServer(
          {required String itemId, required int quantity, int? slotPosition}) async =>
      true;

  @override
  Future<bool> useDetox({required String rowId}) async => true;

  @override
  Future<UseItemResult> useStatResetScroll({required String rowId}) async =>
      const UseItemResult(success: true);

  @override
  Future<UseItemResult> useNameChangeScroll(
          {required String rowId, required String newDisplayName}) async =>
      const UseItemResult(success: true);

  @override
  Future<bool> splitStack(
          {required String rowId,
          required int splitQuantity,
          required int targetSlot}) async =>
      true;

  @override
  Future<SellItemResult> sellItemByRow(
          {required String rowId, required int quantity}) async =>
      const SellItemResult(success: true, goldEarned: 150);

  @override
  Future<bool> trashItem({required String rowId}) async => true;

  @override
  Future<bool> toggleFavorite(
          {required String rowId, required bool isFavorite}) async =>
      true;

  @override
  Future<OpenLootBoxResult> openLootBox({required String rowId}) async =>
      const OpenLootBoxResult(success: true);

  @override
  Future<UsePotionResult> usePotion({required String rowId}) async =>
      const UsePotionResult(success: true);
}

class _FakePlayerNotifier extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState(
        status: PlayerStatus.ready,
        profile: PlayerProfile(
          id: 'usr_test_1',
          authId: 'auth_test_1',
          username: 'Hero',
          email: 'hero@test.com',
          displayName: 'Aion Hero',
          avatarUrl: null,
          avatarFrame: null,
          level: 30,
          xp: 5000,
          gold: 25000,
          gems: 500,
          energy: 100,
          maxEnergy: 100,
          attack: 100,
          defense: 80,
          health: 500,
          maxHealth: 500,
          power: 280,
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
        ),
      );
}

class _FakeBoxOpeningNotifier extends BoxOpeningNotifier {
  @override
  List<BoxOpening> build() => const <BoxOpening>[];
}

InventoryItem _createTestItem({
  required String rowId,
  required String name,
  required Rarity rarity,
  ItemType itemType = ItemType.weapon,
  EquipSlot equipSlot = EquipSlot.weapon,
  int slotPosition = 0,
  bool isEquipped = false,
  int enhancementLevel = 0,
  int quantity = 1,
  int vendorSellPrice = 300,
  int requiredLevel = 1,
}) {
  return InventoryItem(
    rowId: rowId,
    itemId: 'item_$rowId',
    name: name,
    description: 'Aion 2 Dark Fantasy Item',
    itemType: itemType,
    rarity: rarity,
    equipSlot: equipSlot,
    slotPosition: slotPosition,
    isEquipped: isEquipped,
    equippedSlot: isEquipped ? equipSlot.name : '',
    enhancementLevel: enhancementLevel,
    quantity: quantity,
    attack: 60,
    defense: 30,
    vendorSellPrice: vendorSellPrice,
    requiredLevel: requiredLevel,
    isFavorite: false,
  );
}

void main() {
  group('InventoryScreen Aion 2 Mobile Modernization Tests', () {
    testWidgets('renders 5-column grid, capacity & weight gauge, category tabs, and action bar', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sword = _createTestItem(
        rowId: 'wpn_1',
        name: 'Arkon Ejder Kılıcı',
        rarity: Rarity.mythic,
        enhancementLevel: 7,
        isEquipped: true,
        equipSlot: EquipSlot.weapon,
      );

      final bagPotion = _createTestItem(
        rowId: 'bag_1',
        name: 'Büyük İksir',
        rarity: Rarity.rare,
        itemType: ItemType.potion,
        equipSlot: EquipSlot.none,
        slotPosition: 0,
        quantity: 4,
      );

      final bagArmor = _createTestItem(
        rowId: 'bag_2',
        name: 'Titan Zırhı',
        rarity: Rarity.epic,
        itemType: ItemType.armor,
        equipSlot: EquipSlot.chest,
        slotPosition: 1,
        quantity: 1,
      );

      final fakeRepo = _FakeInventoryRepository(
        InventorySnapshot(
          items: <InventoryItem>[bagPotion, bagArmor],
          equippedItems: <String, InventoryItem?>{'weapon': sword},
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

      // 1. Verify Equipped Section
      expect(find.text('Kusanilanlar'), findsOneWidget);

      // 2. Verify Capacity Header and Pill
      expect(find.text('ENVANTER'), findsOneWidget);
      expect(find.text('2/$inventoryCapacity'), findsOneWidget);

      // 3. Verify Capacity & Weight Gauge
      expect(find.textContaining('KAPASİTE: 2 / 20'), findsOneWidget);
      expect(find.textContaining('AĞIRLIK:'), findsOneWidget);

      // 4. Verify All Category Tabs (Hepsi, Silah, Zırh, İksir, Malzeme, Görev)
      expect(find.text('Hepsi'), findsOneWidget);
      expect(find.text('Silah'), findsOneWidget);
      expect(find.text('Zırh'), findsOneWidget);
      expect(find.text('İksir'), findsOneWidget);
      expect(find.text('Malzeme'), findsOneWidget);
      expect(find.text('Görev'), findsOneWidget);

      // 5. Verify Action Bar buttons (Sırala, Hızlı Sat, Ayrıştır)
      expect(find.text('Sırala'), findsOneWidget);
      expect(find.text('Hızlı Sat'), findsOneWidget);
      expect(find.text('Ayrıştır'), findsOneWidget);

      // 6. Test Category Filter tap
      await tester.tap(find.text('Zırh'));
      await tester.pumpAndSettle();

      // 7. Test Instant Sort Sheet modal
      await tester.tap(find.text('Sırala'));
      await tester.pumpAndSettle();

      expect(find.text('ENVANTERİ SIRALA'), findsOneWidget);
      expect(find.text('Nadirlik Derecesi'), findsOneWidget);
      expect(find.text('Gereken Seviye / Güç'), findsOneWidget);
      expect(find.text('Eşya Türü'), findsOneWidget);

      // Select Nadirlik
      await tester.tap(find.text('Nadirlik Derecesi'));
      await tester.pumpAndSettle();

      // Verify Sort label changed to 'Nadirlik'
      expect(find.text('Nadirlik'), findsOneWidget);

      // 8. Test Quick-Sell dialog modal
      await tester.tap(find.text('Hızlı Sat'));
      await tester.pumpAndSettle();

      expect(find.text('HIZLI SATIŞ'), findsOneWidget);
    });
  });
}
