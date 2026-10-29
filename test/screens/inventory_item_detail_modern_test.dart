import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/l10n/l10n.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/screens/inventory/widgets/inventory_item_detail_dialog.dart';
import 'package:gkk_flutter/screens/inventory/widgets/inventory_item_detail_panel.dart';
import 'package:gkk_flutter/screens/inventory/widgets/inventory_power_badge.dart';

class _TestPlayerNotifier extends PlayerNotifier {
  _TestPlayerNotifier(this._initial);
  final PlayerState _initial;

  @override
  PlayerState build() => _initial;
}

class _TestInventoryNotifier extends InventoryNotifier {
  _TestInventoryNotifier(this._initial);
  final InventoryState _initial;

  @override
  InventoryState build() => _initial;
}

PlayerProfile _createMockPlayerProfile({int power = 12500}) {
  final String iso = DateTime.now().toIso8601String();
  return PlayerProfile(
    id: 'p_1',
    authId: 'auth_1',
    username: 'test_player',
    email: 'test@gkk.com',
    displayName: 'AionChampion',
    avatarUrl: null,
    avatarFrame: null,
    level: 30,
    xp: 500,
    gold: 1000,
    gems: 50,
    energy: 100,
    maxEnergy: 100,
    attack: 200,
    defense: 100,
    health: 500,
    maxHealth: 500,
    power: power,
    isOnline: true,
    isBanned: false,
    tutorialCompleted: true,
    guildId: null,
    guildRole: null,
    referralCode: 'REF123',
    referredBy: null,
    pvpRating: 1200,
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
    lastLoginAt: iso,
    lastLogin: iso,
    createdAt: iso,
    updatedAt: iso,
  );
}

InventoryItem _createMockItem({
  required String rowId,
  required String name,
  required Rarity rarity,
  ItemType itemType = ItemType.weapon,
  EquipSlot equipSlot = EquipSlot.weapon,
  int slotPosition = 0,
  bool isEquipped = false,
  int enhancementLevel = 0,
  int quantity = 1,
  int attack = 100,
  int defense = 50,
  int health = 200,
  int luck = 10,
  int power = 150,
  int requiredLevel = 1,
  int vendorSellPrice = 250,
  String description = 'Kadim Atreia ejder savaşından kalma rünlü silah.',
}) {
  return InventoryItem(
    rowId: rowId,
    itemId: 'item_$rowId',
    quantity: quantity,
    slotPosition: slotPosition,
    isEquipped: isEquipped,
    equippedSlot: isEquipped ? equipSlot.name : '',
    enhancementLevel: enhancementLevel,
    isFavorite: false,
    pendingSync: false,
    name: name,
    description: description,
    icon: 'wpn_sword',
    itemType: itemType,
    rarity: rarity,
    basePrice: 500,
    vendorSellPrice: vendorSellPrice,
    attack: attack,
    defense: defense,
    health: health,
    power: power,
    luck: luck,
    mana: 0,
    equipSlot: equipSlot,
    weaponType: WeaponType.sword,
    armorType: ArmorType.none,
    requiredLevel: requiredLevel,
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
  group('2027 Aion 2 InventoryItemDetailPanel Modern Inspection Card', () {
    testWidgets('renders glowing rarity header, +15 enhancement badge and canvas runes', (WidgetTester tester) async {
      final inspectedWeapon = _createMockItem(
        rowId: 'wpn_archon_blade',
        name: 'Arkon Hükümdar Kılıcı',
        rarity: Rarity.mythic,
        enhancementLevel: 15,
        attack: 650,
        defense: 220,
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
                  item: inspectedWeapon,
                  actions: const InventoryItemDetailActions(),
                  isFavorite: true,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify item title and enhancement badge
      expect(find.text('ARKON HÜKÜMDAR KILIÇI'), findsOneWidget);
      expect(find.text('+15'), findsWidgets);

      // Verify Aion 2 Archon Rarity Badge
      expect(find.text('ARKON'), findsOneWidget);

      // Verify Canvas CustomPainter for Arcane runes is mounted
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('displays stat comparison diffs against equipped item', (WidgetTester tester) async {
      // Currently equipped item: lower stats
      final equippedItem = _createMockItem(
        rowId: 'eq_wpn',
        name: 'Eski Çelik Kılıç',
        rarity: Rarity.rare,
        isEquipped: true,
        enhancementLevel: 0,
        attack: 100,
        defense: 50,
      );

      // Inspected inventory item: much higher stats
      final inspectedItem = _createMockItem(
        rowId: 'new_wpn',
        name: 'Ejder Yakan Kılıç',
        rarity: Rarity.epic,
        isEquipped: false,
        enhancementLevel: 5,
        attack: 250,
        defense: 30,
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
                  item: inspectedItem,
                  equippedItem: equippedItem,
                  actions: const InventoryItemDetailActions(),
                  isFavorite: false,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify Bento Stat headers
      expect(find.text('SALDIRI'), findsOneWidget);
      expect(find.text('SAVUNMA'), findsOneWidget);
      expect(find.text('GÜÇ'), findsOneWidget);

      // Verify positive/negative delta indicator presence
      expect(find.byIcon(Icons.arrow_drop_up_rounded), findsWidgets);
    });

    testWidgets('displays durability gauge and socketed manastones & godstones', (WidgetTester tester) async {
      final archonWeapon = _createMockItem(
        rowId: 'wpn_divine',
        name: 'İlahi Savaş Asası',
        rarity: Rarity.mythic,
        enhancementLevel: 10,
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
                  item: archonWeapon,
                  actions: const InventoryItemDetailActions(),
                  isFavorite: false,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify Durability Bar
      expect(find.text('DAYANIKLILIK'), findsOneWidget);
      expect(find.text('100 / 100'), findsOneWidget);

      // Verify Sockets section
      expect(find.textContaining('BÜYÜ TAŞI YUVALARI'), findsOneWidget);
      expect(find.textContaining('İlahî Taş: Nezekan\'ın Gazabı'), findsOneWidget);
      expect(find.textContaining('Kritik Vuruş +17'), findsOneWidget);
    });

    testWidgets('handles Action Buttons: Equip, Enhance, Socket, Salvage and Delete', (WidgetTester tester) async {
      final item = _createMockItem(
        rowId: 't_item',
        name: 'Test Palası',
        rarity: Rarity.epic,
      );

      bool equipTriggered = false;
      bool enhanceTriggered = false;
      bool socketTriggered = false;
      bool salvageTriggered = false;
      bool deleteTriggered = false;

      final actions = InventoryItemDetailActions(
        onEquip: (it) async => equipTriggered = true,
        onEnhance: (it) async => enhanceTriggered = true,
        onSocket: (it) async => socketTriggered = true,
        onSalvage: (it) async => salvageTriggered = true,
        onDelete: (it) async => deleteTriggered = true,
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
                  item: item,
                  actions: actions,
                  isFavorite: false,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify action buttons are rendered
      expect(find.text('KUŞAN (WEAPON)'), findsOneWidget);
      expect(find.text('GELİŞTİR (+15)'), findsOneWidget);
      expect(find.text('SOKETLE'), findsOneWidget);
      expect(find.text('AYRIŞTIR'), findsOneWidget);
      expect(find.text('SİL'), findsOneWidget);

      // Tap Equip
      await tester.tap(find.text('KUŞAN (WEAPON)'));
      await tester.pump();
      expect(equipTriggered, isTrue);

      // Tap Enhance
      await tester.tap(find.text('GELİŞTİR (+15)'));
      await tester.pump();
      expect(enhanceTriggered, isTrue);

      // Tap Socket
      await tester.tap(find.text('SOKETLE'));
      await tester.pump();
      expect(socketTriggered, isTrue);

      // Tap Salvage
      await tester.tap(find.text('AYRIŞTIR'));
      await tester.pump();
      expect(salvageTriggered, isTrue);

      // Tap Delete
      await tester.tap(find.text('SİL'));
      await tester.pump();
      expect(deleteTriggered, isTrue);
    });
  });

  group('InventoryItemDetailDialog modal display', () {
    testWidgets('shows modal dialog with dark fantasy backdrop', (WidgetTester tester) async {
      final item = _createMockItem(
        rowId: 'dlg_item',
        name: 'Mistik Başlık',
        rarity: Rarity.rare,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showInventoryItemDetailDialog(
                      context,
                      item: item,
                      actions: const InventoryItemDetailActions(),
                      isFavorite: false,
                    );
                  },
                  child: const Text('Aç'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('MİSTİK BAŞLIK'), findsOneWidget);
    });

    testWidgets('renders action buttons and stat diff chips with live comparison', (WidgetTester tester) async {
      final inspected = _createMockItem(
        rowId: 'dlg_sword',
        name: 'Ejder Kilici',
        rarity: Rarity.epic,
        attack: 250,
        enhancementLevel: 5,
      );
      final equipped = _createMockItem(
        rowId: 'eq_sword',
        name: 'Eski Kilic',
        rarity: Rarity.rare,
        attack: 180,
      );

      bool equipTriggered = false;
      bool enhanceTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InventoryItemDetailDialog(
              item: inspected,
              equippedItem: equipped,
              onEquip: (it) async => equipTriggered = true,
              onEnhance: (it) async => enhanceTriggered = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('EJDER KILICI'), findsOneWidget);
      expect(find.text('KUŞAN (WEAPON)'), findsOneWidget);
      expect(find.text('GELİŞTİR (+15)'), findsOneWidget);
      expect(find.byType(InventoryStatDiffChip), findsWidgets);

      await tester.tap(find.text('KUŞAN (WEAPON)'));
      await tester.pump();
      expect(equipTriggered, isTrue);

      await tester.tap(find.text('GELİŞTİR (+15)'));
      await tester.pump();
      expect(enhanceTriggered, isTrue);
    });

    testWidgets('toggles lock state and updates icon', (WidgetTester tester) async {
      final item = _createMockItem(
        rowId: 'locked_item',
        name: 'Kutsal Yuzuk',
        rarity: Rarity.mythic,
      );

      bool lockToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InventoryItemDetailDialog(
              item: item,
              isFavorite: true,
              onLock: (it) async => lockToggled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.lock_rounded));
      await tester.pumpAndSettle();
      expect(lockToggled, isTrue);
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
    });
  });

  group('2027 Aion 2 InventoryPowerBadge', () {
    testWidgets('renders metallic badge and updates combat rating with shimmer', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          playerProvider.overrideWith(
            () => _TestPlayerNotifier(
              PlayerState(
                status: PlayerStatus.ready,
                profile: _createMockPlayerProfile(power: 12500),
              ),
            ),
          ),
          inventoryProvider.overrideWith(
            () => _TestInventoryNotifier(
              InventoryState(
                status: InventoryStatus.ready,
                items: const [],
                equippedItems: const {},
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: InventoryPowerBadge(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Archon tier and power score formatted
      expect(find.text('GÜÇ · ARKON'), findsOneWidget);
      expect(find.text('12.500'), findsOneWidget);
    });
  });
}
