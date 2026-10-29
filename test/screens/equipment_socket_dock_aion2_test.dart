import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/screens/character/widgets/equipment_socket_dock.dart';

InventoryItem testItem({
  required String itemId,
  required String name,
  required EquipSlot equipSlot,
  required Rarity rarity,
  int enhancementLevel = 0,
  int attack = 0,
  int defense = 0,
  int health = 0,
  int power = 0,
  int luck = 0,
}) {
  return InventoryItem(
    rowId: 'row_$itemId',
    itemId: itemId,
    quantity: 1,
    slotPosition: 0,
    isEquipped: true,
    equippedSlot: equipSlot.name,
    enhancementLevel: enhancementLevel,
    isFavorite: false,
    pendingSync: false,
    name: name,
    description: 'Test description for $name',
    icon: 'item_sword',
    itemType: equipSlot == EquipSlot.weapon ? ItemType.weapon : ItemType.armor,
    rarity: rarity,
    basePrice: 500,
    vendorSellPrice: 250,
    attack: attack,
    defense: defense,
    health: health,
    power: power,
    luck: luck,
    mana: 20,
    equipSlot: equipSlot,
    weaponType: equipSlot == EquipSlot.weapon ? WeaponType.sword : WeaponType.none,
    armorType: equipSlot == EquipSlot.weapon ? ArmorType.none : ArmorType.plate,
    requiredLevel: 1,
    canEnhance: true,
    maxEnhancement: 15,
    isStackable: false,
    maxStack: 1,
    isTradeable: true,
    potionType: PotionType.none,
    energyRestore: 0,
    healthRestore: 0,
    toleranceIncrease: 0,
  );
}

void main() {
  group('EquipmentSocketDock Aion 2 Modernization Tests', () {
    testWidgets('renders all 12 Aion 2 equipment slots with proper slot labels', (
      WidgetTester tester,
    ) async {
      final Map<String, InventoryItem> equipped = <String, InventoryItem>{
        'weapon': testItem(
          itemId: 'wpn_1',
          name: 'Ethereal Sun Blade',
          equipSlot: EquipSlot.weapon,
          rarity: Rarity.mythic,
          enhancementLevel: 7,
          attack: 150,
        ),
        'chest': testItem(
          itemId: 'chst_1',
          name: 'Daevanion Plate',
          equipSlot: EquipSlot.chest,
          rarity: Rarity.epic,
          enhancementLevel: 5,
          defense: 80,
        ),
        'wings': testItem(
          itemId: 'wng_1',
          name: 'Stormwing Feathers',
          equipSlot: EquipSlot.none,
          rarity: Rarity.legendary,
          enhancementLevel: 15,
          power: 120,
        ),
      };

      EquipmentSlotDef? tappedSlot;
      InventoryItem? tappedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EquipmentSocketDock(
              equippedItems: equipped,
              onSlotTap: (EquipmentSlotDef def, InventoryItem? item) {
                tappedSlot = def;
                tappedItem = item;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify the 8 standard legacy slot names
      expect(find.text('Miğfer'), findsOneWidget);
      expect(find.text('Silah'), findsOneWidget);
      expect(find.text('Zırh'), findsOneWidget);
      expect(find.text('Eldiven'), findsOneWidget);
      expect(find.text('Pantolon'), findsOneWidget);
      expect(find.text('Çizme'), findsOneWidget);
      expect(find.text('Yüzük'), findsOneWidget);
      expect(find.text('Kolye'), findsOneWidget);

      // Verify the 4 additional Aion 2 modern slots
      expect(find.text('Omuzluk'), findsOneWidget);
      expect(find.text('Kanatlar'), findsOneWidget);
      expect(find.text('Yan El'), findsOneWidget);
      expect(find.text('Küpe'), findsOneWidget);

      // Verify enhancement badges (+7, +5, +15)
      expect(find.text('+7'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('+15'), findsOneWidget);

      // Test tapping an equipped slot (weapon)
      await tester.tap(find.text('Silah'));
      await tester.pump();
      expect(tappedSlot?.slotKey, equals('weapon'));
      expect(tappedItem?.name, equals('Ethereal Sun Blade'));

      // Test tapping an empty slot (helmet)
      await tester.tap(find.text('Miğfer'));
      await tester.pump();
      expect(tappedSlot?.slotKey, equals('head'));
      expect(tappedItem, isNull);
    });

    testWidgets('EquipmentDetailModal displays stats, enhancement, and triggers unequip', (
      WidgetTester tester,
    ) async {
      final InventoryItem weapon = testItem(
        itemId: 'ethereal_blade',
        name: 'Ethereal Sun Blade',
        equipSlot: EquipSlot.weapon,
        rarity: Rarity.mythic,
        enhancementLevel: 7,
        attack: 150,
      );

      bool unequipTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (BuildContext ctx) => EquipmentDetailModal(
                        slotDef: kRightEquipmentSlots[0], // weapon
                        item: weapon,
                        onUnequip: () => unequipTapped = true,
                      ),
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify modal content
      expect(find.text('Ethereal Sun Blade'), findsOneWidget);
      expect(find.text('Saldırı: +150'), findsOneWidget);
      expect(find.text('+7'), findsOneWidget);
      expect(find.text('Kuşanı Çıkar'), findsOneWidget);

      // Tap unequip
      await tester.tap(find.text('Kuşanı Çıkar'));
      await tester.pumpAndSettle();

      expect(unequipTapped, isTrue);
    });

    testWidgets('AionEnhancementBadge renders stars according to tier', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                AionEnhancementBadge(level: 3, rarityColor: Colors.blue),
                AionEnhancementBadge(level: 7, rarityColor: Colors.purple),
                AionEnhancementBadge(level: 11, rarityColor: Colors.amber),
                AionEnhancementBadge(level: 15, rarityColor: Colors.pink),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('+3'), findsOneWidget);
      expect(find.text('+7'), findsOneWidget);
      expect(find.text('+11'), findsOneWidget);
      expect(find.text('+15'), findsOneWidget);
      // Star icons are rendered
      expect(find.byIcon(Icons.star_rounded), findsWidgets);
    });

    testWidgets('CustomPaint AionRarityGlowPainter animates breathing value', (
      WidgetTester tester,
    ) async {
      final Map<String, InventoryItem> equipped = <String, InventoryItem>{
        'weapon': testItem(
          itemId: 'blade_1',
          name: 'Divine Edge',
          equipSlot: EquipSlot.weapon,
          rarity: Rarity.epic,
          enhancementLevel: 10,
        ),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EquipmentSocketDock(
              equippedItems: equipped,
              onSlotTap: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('EquipmentQuickTooltip renders item and slot information', (
      WidgetTester tester,
    ) async {
      final InventoryItem item = testItem(
        itemId: 'quick_item',
        name: 'Dragon Harvester',
        equipSlot: EquipSlot.weapon,
        rarity: Rarity.legendary,
        enhancementLevel: 12,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EquipmentQuickTooltip(
              slotDef: kRightEquipmentSlots[0],
              item: item,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Dragon Harvester (+12)'), findsOneWidget);
      expect(find.text('Silah · Efsanevi'), findsOneWidget);
    });
  });
}
