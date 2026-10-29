import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/screens/enhancement/widgets/enhancement_rune_picker_sheet.dart';
import 'package:gkk_flutter/screens/enhancement/widgets/enhancement_scroll_picker_sheet.dart';
import 'package:gkk_flutter/screens/enhancement/widgets/enhancement_upgrade_table_dialog.dart';

InventoryItem _mockItem({
  required String rowId,
  required String itemId,
  required String name,
  required ItemType itemType,
  required Rarity rarity,
  int quantity = 1,
  String description = 'Test description',
  String icon = '🔮',
}) {
  return InventoryItem(
    rowId: rowId,
    itemId: itemId,
    quantity: quantity,
    slotPosition: 0,
    isEquipped: false,
    equippedSlot: 'none',
    enhancementLevel: 0,
    isFavorite: false,
    pendingSync: false,
    name: name,
    description: description,
    icon: icon,
    itemType: itemType,
    rarity: rarity,
    basePrice: 100,
    vendorSellPrice: 50,
    attack: 0,
    defense: 0,
    health: 0,
    power: 0,
    luck: 0,
    mana: 0,
    equipSlot: EquipSlot.none,
    weaponType: WeaponType.none,
    armorType: ArmorType.none,
    requiredLevel: 1,
    canEnhance: true,
    maxEnhancement: 15,
    isStackable: true,
    maxStack: 99,
    isTradeable: true,
    potionType: PotionType.none,
    energyRestore: 0,
    healthRestore: 0,
    toleranceIncrease: 0,
  );
}

void main() {
  group('Enhancement Rune Picker Tests', () {
    test('Catalog entries have complete Aion 2 metadata', () {
      expect(kEnhancementRuneCatalog.containsKey('basic'), isTrue);
      expect(kEnhancementRuneCatalog.containsKey('advanced'), isTrue);
      expect(kEnhancementRuneCatalog.containsKey('superior'), isTrue);
      expect(kEnhancementRuneCatalog.containsKey('legendary'), isTrue);
      expect(kEnhancementRuneCatalog.containsKey('protection'), isTrue);
      expect(kEnhancementRuneCatalog.containsKey('blessed'), isTrue);

      final EnhancementRuneCatalogEntry legendary =
          kEnhancementRuneCatalog['legendary']!;
      expect(legendary.statBoost, contains('+25%'));
      expect(legendary.socketOdds, contains('76%'));
      expect(legendary.rarity, equals('Efsanevi'));
      expect(legendary.category, contains('Godstone'));

      expect(enhancementRuneLabel('none'), equals('Rune kullanma'));
      expect(enhancementRuneLabel('basic'), contains('Manastone'));
      expect(enhancementRuneDescription('basic'), isNotNull);
      expect(enhancementRuneTypeFromItemId('rune_legendary'), equals('legendary'));
    });

    testWidgets('Empty rune inventory renders Aion 2 empty state and fallback',
        (WidgetTester tester) async {
      EnhancementRuneType? pickedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () async {
                    pickedResult = await showEnhancementRunePickerSheet(
                      context: context,
                      ownedRunes: <InventoryItem>[],
                      selectedRune: 'none',
                    );
                  },
                  child: const Text('Open Rune Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Rune Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Manastone & Godstone Yuvası'), findsOneWidget);
      expect(find.text('Envanterinde Manastone / Rün Yok'), findsOneWidget);
      expect(find.text('Rune Olmadan Devam Et'), findsOneWidget);

      await tester.tap(find.text('Rune Olmadan Devam Et'));
      await tester.pumpAndSettle();

      expect(pickedResult, equals('none'));
    });

    testWidgets('Rune picker renders owned runes with glowing badges and selection',
        (WidgetTester tester) async {
      EnhancementRuneType? pickedResult;
      final List<InventoryItem> owned = <InventoryItem>[
        _mockItem(
          rowId: 'r1',
          itemId: 'rune_basic',
          name: 'Temel Manastone',
          itemType: ItemType.rune,
          rarity: Rarity.common,
          quantity: 5,
        ),
        _mockItem(
          rowId: 'r2',
          itemId: 'rune_legendary',
          name: 'Efsanevi Tanrı Taşı (Godstone)',
          itemType: ItemType.rune,
          rarity: Rarity.legendary,
          quantity: 2,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () async {
                    pickedResult = await showEnhancementRunePickerSheet(
                      context: context,
                      ownedRunes: owned,
                      selectedRune: 'none',
                    );
                  },
                  child: const Text('Open Rune Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Rune Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('2 Rün'), findsOneWidget);
      expect(find.text('Tümü'), findsOneWidget);
      expect(find.text('Manastone'), findsOneWidget);
      expect(find.text('Godstone'), findsOneWidget);

      expect(find.text('Temel Manastone'), findsOneWidget);
      expect(find.text('Efsanevi Tanrı Taşı (Godstone)'), findsOneWidget);
      expect(find.text('×5'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
      expect(find.text('+25% Başarı · %75 Yıkım Koruması'), findsOneWidget);

      // Tap legendary rune
      await tester.tap(find.text('Efsanevi Tanrı Taşı (Godstone)'));
      await tester.pumpAndSettle();

      expect(pickedResult, equals('legendary'));
    });
  });

  group('Enhancement Scroll Picker Tests', () {
    testWidgets('Empty scroll inventory renders stylish empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    showEnhancementScrollPickerSheet(
                      context: context,
                      ownedScrolls: <InventoryItem>[],
                      requiredScrollId: 'scroll_weapon_epic',
                    );
                  },
                  child: const Text('Open Scroll Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Scroll Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Gerekli Büyüleme Parşömeni'), findsOneWidget);
      expect(find.text('Envanterde Uygun Parşömen Yok'), findsOneWidget);
      expect(find.text('Geri Dön'), findsOneWidget);

      await tester.tap(find.text('Geri Dön'));
      await tester.pumpAndSettle();
      expect(find.text('Envanterde Uygun Parşömen Yok'), findsNothing);
    });

    testWidgets('Scroll picker displays L1-L100 stones, supplements, and multiplier bonuses',
        (WidgetTester tester) async {
      InventoryItem? pickedScroll;
      final List<InventoryItem> owned = <InventoryItem>[
        _mockItem(
          rowId: 's1',
          itemId: 'scroll_l85_stone',
          name: 'L85 Büyüleme Taşı',
          itemType: ItemType.scroll,
          rarity: Rarity.epic,
          quantity: 3,
        ),
        _mockItem(
          rowId: 's2',
          itemId: 'scroll_felicitous_supplement',
          name: 'Felicitous Kutsama Parşömeni',
          itemType: ItemType.scroll,
          rarity: Rarity.legendary,
          quantity: 1,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () async {
                    pickedScroll = await showEnhancementScrollPickerSheet(
                      context: context,
                      ownedScrolls: owned,
                      requiredScrollId: null,
                    );
                  },
                  child: const Text('Open Scroll Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Scroll Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Büyüleme Parşömeni & Taşları'), findsOneWidget);
      expect(find.text('L85 Büyüleme Taşı'), findsOneWidget);
      expect(find.text('Felicitous Kutsama Parşömeni'), findsOneWidget);
      expect(find.text('2.00× Çarpan'), findsOneWidget);
      expect(find.text('1.30× Çarpan'), findsOneWidget);

      // Tap felicitous supplement
      await tester.tap(find.text('Felicitous Kutsama Parşömeni'));
      await tester.pumpAndSettle();

      expect(pickedScroll, isNotNull);
      expect(pickedScroll?.itemId, equals('scroll_felicitous_supplement'));
    });
  });

  group('Enhancement Upgrade Table Dialog Tests', () {
    testWidgets('Upgrade table displays +1 through +15 matrix and tier filters',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final Map<int, int> costs = <int, int>{
        0: 1000,
        1: 2000,
        2: 3000,
        3: 5000,
        4: 8000,
        5: 12000,
        6: 18000,
        7: 25000,
        8: 35000,
        9: 50000,
        10: 75000,
      };
      final Map<int, int> chances = <int, int>{
        0: 100,
        1: 95,
        2: 90,
        3: 85,
        4: 80,
        5: 70,
        6: 60,
        7: 50,
        8: 40,
        9: 30,
        10: 25,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    showEnhancementUpgradeTableDialog(
                      context: context,
                      currentLevel: 4,
                      upgradeCosts: costs,
                      upgradeChances: chances,
                      formatGold: (int amt) => '$amt Altın',
                      riskLabel: (int lvl) => lvl < 5 ? 'Güvenli' : 'Riskli',
                      riskColor: (int lvl) => lvl < 5 ? Colors.green : Colors.amber,
                      successColor: (int ch) => ch > 70 ? Colors.green : Colors.orange,
                    );
                  },
                  child: const Text('Open Upgrade Table'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Upgrade Table'));
      await tester.pumpAndSettle();

      expect(find.text('Aion 2 Olasılık Matrisi'), findsOneWidget);
      expect(find.text('GÜVENLİ'), findsOneWidget);
      expect(find.text('RİSKLİ'), findsOneWidget);
      expect(find.text('ABYSS'), findsOneWidget);

      // Verify level badges
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);

      // Catalyst guide button
      expect(find.text('Katalizör Rehberi'), findsOneWidget);
      await tester.tap(find.text('Katalizör Rehberi'));
      await tester.pumpAndSettle();

      expect(find.text('Aion 2 Güçlendirme Katalizör Kılavuzu'), findsOneWidget);
      expect(find.text('Gizle'), findsOneWidget);

      // Tab filter to Abyss (+11~+15)
      await tester.tap(find.text('Abyss (+11~+15)'));
      await tester.pumpAndSettle();

      expect(find.text('+15'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Kapat').last);
      await tester.pumpAndSettle();

      expect(find.text('Aion 2 Olasılık Matrisi'), findsNothing);
    });
  });
}
