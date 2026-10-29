import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/errors/app_exception.dart';
import 'package:gkk_flutter/l10n/app_localizations.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/models/player_badge_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/player_badges_provider.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/repositories/inventory_repository.dart';
import 'package:gkk_flutter/repositories/player_badge_repository.dart';
import 'package:gkk_flutter/repositories/player_repository.dart';
import 'package:gkk_flutter/screens/character/character_screen.dart';

// ─── Fake Repositories ───────────────────────────────────────────────────────

class _FakePlayerRepository implements PlayerRepository {
  _FakePlayerRepository({required this.profile});

  final PlayerProfile profile;

  @override
  Future<PlayerProfile> loadCurrentPlayer() async => profile;
}

class _FakeInventoryRepository implements InventoryRepository {
  _FakeInventoryRepository({required this.snapshot});

  final InventorySnapshot snapshot;
  String? lastEquipRowId;
  String? lastEquipSlot;
  String? lastUnequipSlot;

  @override
  Future<InventorySnapshot> fetchInventory() async => snapshot;

  @override
  Future<bool> equipItem({required String rowId, required String slot}) async {
    lastEquipRowId = rowId;
    lastEquipSlot = slot;
    return true;
  }

  @override
  Future<bool> unequipItem({required String slot}) async {
    lastUnequipSlot = slot;
    return true;
  }

  @override
  Future<bool> swapSlots({required int fromSlot, required int toSlot}) async =>
      true;

  @override
  Future<bool> addItemToServer({
    required String itemId,
    required int quantity,
    int? slotPosition,
  }) async =>
      true;

  @override
  Future<bool> moveItemToSlot({
    required String rowId,
    required int targetSlot,
  }) async =>
      true;

  @override
  Future<bool> unequipItemToSlot({
    required String rowId,
    required String slot,
    required int targetSlot,
  }) async =>
      true;

  @override
  Future<bool> swapEquipWithSlot({
    required String equipSlot,
    required int targetSlot,
  }) async =>
      true;

  @override
  Future<UsePotionResult> usePotion({required String rowId}) async =>
      throw AppException('Not needed');

  @override
  Future<OpenLootBoxResult> openLootBox({required String rowId}) async =>
      const OpenLootBoxResult(success: true);

  @override
  Future<bool> useDetox({required String rowId}) async => true;

  @override
  Future<UseItemResult> useStatResetScroll({required String rowId}) async =>
      const UseItemResult(success: true);

  @override
  Future<UseItemResult> useNameChangeScroll({
    required String rowId,
    required String newDisplayName,
  }) async =>
      const UseItemResult(success: true);

  @override
  Future<bool> splitStack({
    required String rowId,
    required int splitQuantity,
    required int targetSlot,
  }) async =>
      true;

  @override
  Future<SellItemResult> sellItemByRow({
    required String rowId,
    required int quantity,
  }) async =>
      const SellItemResult(success: true);

  @override
  Future<bool> trashItem({required String rowId}) async => true;

  @override
  Future<bool> toggleFavorite({
    required String rowId,
    required bool isFavorite,
  }) async =>
      true;
}

class _FakePlayerBadgeRepository implements PlayerBadgeRepository {
  @override
  Future<List<PlayerBadge>> fetchBadges() async => const <PlayerBadge>[];
}

// ─── Fixtures ───────────────────────────────────────────────────────────────

PlayerProfile _testProfile({CharacterClass cClass = CharacterClass.warrior}) {
  return PlayerProfile(
    id: 'char_test_1',
    authId: 'auth_1',
    username: 'AionCommander',
    email: 'commander@aion.test',
    displayName: 'AionCommander',
    avatarUrl: null,
    avatarFrame: 'glow',
    level: 45,
    xp: 125000,
    gold: 50000,
    gems: 250,
    energy: 90,
    maxEnergy: 100,
    attack: 420,
    defense: 310,
    health: 1200,
    maxHealth: 1200,
    power: 1850,
    isOnline: true,
    isBanned: false,
    tutorialCompleted: true,
    guildId: 'guild_1',
    guildRole: 'Commander',
    guildName: 'Elyos Order',
    characterClass: cClass,
    reputation: 1500,
    statPoints: 5,
    pvpWins: 42,
    pvpLosses: 8,
    pvpRating: 1450,
    tolerance: 15,
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

InventoryItem _testWeapon() {
  return const InventoryItem(
    rowId: 'row_wpn_1',
    itemId: 'item_greatsword_1',
    quantity: 1,
    slotPosition: 0,
    isEquipped: true,
    equippedSlot: 'weapon',
    enhancementLevel: 7,
    isFavorite: true,
    pendingSync: false,
    name: 'Ethereal Sun Blade',
    description: 'Forged with radiant Aion starlight.',
    icon: '⚔️',
    itemType: ItemType.weapon,
    rarity: Rarity.legendary,
    basePrice: 1000,
    vendorSellPrice: 500,
    attack: 150,
    defense: 25,
    health: 80,
    power: 320,
    luck: 15,
    mana: 50,
    equipSlot: EquipSlot.weapon,
    weaponType: WeaponType.sword,
    armorType: ArmorType.none,
    requiredLevel: 40,
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

InventoryItem _testChest() {
  return const InventoryItem(
    rowId: 'row_chest_1',
    itemId: 'item_chest_plate_1',
    quantity: 1,
    slotPosition: 1,
    isEquipped: true,
    equippedSlot: 'chest',
    enhancementLevel: 5,
    isFavorite: false,
    pendingSync: false,
    name: 'Celestial Dragon Plate',
    description: 'Imbued with iridescent dragon scales.',
    icon: '🛡️',
    itemType: ItemType.armor,
    rarity: Rarity.epic,
    basePrice: 800,
    vendorSellPrice: 400,
    attack: 20,
    defense: 120,
    health: 200,
    power: 280,
    luck: 5,
    mana: 20,
    equipSlot: EquipSlot.chest,
    weaponType: WeaponType.none,
    armorType: ArmorType.plate,
    requiredLevel: 35,
    canEnhance: true,
    maxEnhancement: 10,
    isStackable: false,
    maxStack: 1,
    isTradeable: true,
    potionType: PotionType.none,
    energyRestore: 0,
    healthRestore: 0,
    toleranceIncrease: 0,
  );
}

Widget _wrapScreen({
  required Widget child,
  required PlayerProfile profile,
  required InventorySnapshot snapshot,
  Size size = const Size(393, 852), // iPhone 14 Pro
  EdgeInsets padding = const EdgeInsets.only(top: 59, bottom: 34),
}) {
  return ProviderScope(
    overrides: [
      playerRepositoryProvider.overrideWithValue(
        _FakePlayerRepository(profile: profile),
      ),
      inventoryRepositoryProvider.overrideWithValue(
        _FakeInventoryRepository(snapshot: snapshot),
      ),
      playerBadgeRepositoryProvider.overrideWithValue(
        _FakePlayerBadgeRepository(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080B12),
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: padding,
          viewPadding: padding,
          devicePixelRatio: 3.0,
        ),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    ),
  );
}

Widget _wrapOverlayTest({
  required Widget child,
  required PlayerProfile profile,
  InventorySnapshot snapshot = const InventorySnapshot(
    items: <InventoryItem>[],
    equippedItems: <String, InventoryItem?>{},
  ),
}) {
  return ProviderScope(
    overrides: [
      playerRepositoryProvider.overrideWithValue(
        _FakePlayerRepository(profile: profile),
      ),
      inventoryRepositoryProvider.overrideWithValue(
        _FakeInventoryRepository(snapshot: snapshot),
      ),
      playerBadgeRepositoryProvider.overrideWithValue(
        _FakePlayerBadgeRepository(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080B12),
      ),
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

// ─── Test Suite ─────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CharacterTurntableViewport 3D & Aion 2 Aesthetics', () {
    testWidgets('renders turntable and handles horizontal rotation drag', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterTurntableViewport(
              characterClass: CharacterClass.warrior,
              equippedCount: 4,
              height: 380,
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the 360 degree indicator
      expect(find.text('360°'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Perform horizontal turntable drag gesture across viewport
      final Finder turntable = find.byType(CharacterTurntableViewport);
      await tester.drag(turntable, const Offset(120, 0));
      await tester.pump();

      // Tap reset orientation button
      final Finder resetBtn = find.byTooltip('Açıyı Sıfırla');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pump();
    });

    testWidgets('renders with Alchemist and Shadow class aesthetics', (
      WidgetTester tester,
    ) async {
      for (final CharacterClass cClass in <CharacterClass>[
        CharacterClass.alchemist,
        CharacterClass.shadow,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CharacterTurntableViewport(
                characterClass: cClass,
                equippedCount: 2,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    testWidgets('toggles between character and weapon inspection modes', (
      WidgetTester tester,
    ) async {
      TurntableMode? lastReportedMode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterTurntableViewport(
              characterClass: CharacterClass.warrior,
              onModeChanged: (TurntableMode mode) {
                lastReportedMode = mode;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Karakter Vitrini'), findsOneWidget);

      // Tap mode toggle chip
      await tester.tap(find.text('Karakter Vitrini'));
      await tester.pump();

      // Switches to weapon inspection mode
      expect(lastReportedMode, TurntableMode.weapon);
      expect(find.text('Silah Teftişi'), findsOneWidget);
      expect(find.text('Efsanevi Altın Kılıç'), findsOneWidget);

      // Tap again to switch back to character mode
      await tester.tap(find.text('Silah Teftişi'));
      await tester.pump();

      expect(lastReportedMode, TurntableMode.character);
      expect(find.text('Karakter Vitrini'), findsOneWidget);
    });
  });

  group('EquipmentSocketDock & Gear Tap Interactions', () {
    testWidgets('renders all 8 standard mobile gear sockets', (
      WidgetTester tester,
    ) async {
      final Map<String, InventoryItem> equipped = <String, InventoryItem>{
        'weapon': _testWeapon(),
        'chest': _testChest(),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EquipmentSocketDock(
              equippedItems: equipped,
              onSlotTap: (EquipmentSlotDef def, InventoryItem? item) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Check slot watermarks and labels
      expect(find.text('Miğfer'), findsOneWidget);
      expect(find.text('Silah'), findsOneWidget);
      expect(find.text('Zırh'), findsOneWidget);
      expect(find.text('Eldiven'), findsOneWidget);
      expect(find.text('Pantolon'), findsOneWidget);
      expect(find.text('Çizme'), findsOneWidget);
      expect(find.text('Yüzük'), findsOneWidget);
      expect(find.text('Kolye'), findsOneWidget);

      // Check enhancement levels on equipped items (+7 weapon, +5 chest)
      expect(find.text('+7'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
    });

    testWidgets('tapping equipped socket opens EquipmentDetailModal', (
      WidgetTester tester,
    ) async {
      final InventoryItem weapon = _testWeapon();
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify modal content
      expect(find.text('Ethereal Sun Blade'), findsOneWidget);
      expect(find.text('Saldırı: +150'), findsOneWidget);
      expect(find.text('Kuşanı Çıkar'), findsOneWidget);

      // Tap unequip
      await tester.tap(find.text('Kuşanı Çıkar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(unequipTapped, isTrue);
    });
  });

  group('CharacterGlassOverlay Non-Blocking & Stat Allocation', () {
    testWidgets('collapses to non-blocking HUD pill and expands on toggle', (
      WidgetTester tester,
    ) async {
      bool expanded = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return _wrapOverlayTest(
              profile: _testProfile(),
              child: CharacterGlassOverlay(
                profile: _testProfile(),
                isExpanded: expanded,
                onToggleExpanded: () {
                  setState(() => expanded = !expanded);
                },
                onOpenCodex: () {},
                onOpenReputation: () {},
                onCustomizeProfile: () {},
                highlightPowerTutorial: false,
                statTutorialStep: false,
                claimingDetox: false,
                onClaimDetox: () {},
              ),
            );
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // In collapsed mode: mini HUD pill with 'Statlar' button is visible
      expect(find.widgetWithText(FilledButton, 'Statlar'), findsOneWidget);
      expect(find.text('AionCommander'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.widgetWithText(FilledButton, 'Statlar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Expanded mode reveals full glassmorphic stats
      expect(find.text('Modeli İncele (Kapat)'), findsOneWidget);
      expect(find.text('Koleksiyon Kodex'), findsOneWidget);
      expect(find.text('Stat puanları'), findsOneWidget);

      // Tap to collapse
      await tester.tap(find.text('Modeli İncele (Kapat)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Back to collapsed HUD
      expect(find.widgetWithText(FilledButton, 'Statlar'), findsOneWidget);
    });

    testWidgets('transitions fluidly between Stats, Equipment, Titles, and Codex tabs', (
      WidgetTester tester,
    ) async {
      CharacterTab currentTab = CharacterTab.stats;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return _wrapOverlayTest(
              profile: _testProfile(),
              child: SingleChildScrollView(
                child: CharacterGlassOverlay(
                  profile: _testProfile(),
                  isExpanded: true,
                  initialTab: currentTab,
                  onTabChanged: (CharacterTab t) {
                    setState(() => currentTab = t);
                  },
                  onToggleExpanded: () {},
                  onOpenCodex: () {},
                  onOpenReputation: () {},
                  onCustomizeProfile: () {},
                  highlightPowerTutorial: false,
                  statTutorialStep: false,
                  claimingDetox: false,
                  onClaimDetox: () {},
                ),
              ),
            );
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // 1. Initial tab is Stats
      expect(find.text('Stat puanları'), findsOneWidget);
      expect(find.text('Koleksiyon Kodex'), findsOneWidget);

      // 2. Switch to Equipment tab
      await tester.tap(find.text('Donanım'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Toplam Ekipman Gücü'), findsOneWidget);
      expect(find.text('Kuşanılan Ekipman Yuvaları'), findsOneWidget);

      // 3. Switch to Titles tab
      await tester.tap(find.text('Unvanlar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Aktif Kozmetik Unvan'), findsOneWidget);
      expect(find.text('Koleksiyon Unvanları'), findsOneWidget);

      // 4. Switch to Codex tab
      await tester.tap(find.text('Kodex'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Koleksiyon Kodex Kaşifi'), findsOneWidget);
      expect(find.text('Koleksiyon Kodexini Aç (Tam Ekran)'), findsOneWidget);

      // 5. Switch back to Stats tab
      await tester.tap(find.widgetWithText(AnimatedContainer, 'Statlar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Stat puanları'), findsOneWidget);
    });
  });

  group('Mobile SafeArea & Viewport Responsiveness', () {
    testWidgets('renders cleanly on iPhone 14 Pro viewport without overflow', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final InventorySnapshot snapshot = InventorySnapshot(
        items: <InventoryItem>[_testWeapon(), _testChest()],
        equippedItems: <String, InventoryItem?>{
          'weapon': _testWeapon(),
          'chest': _testChest(),
        },
      );

      await tester.pumpWidget(
        _wrapScreen(
          child: const CharacterScreen(),
          profile: _testProfile(),
          snapshot: snapshot,
          size: const Size(393, 852),
          padding: const EdgeInsets.only(top: 59, bottom: 34),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CharacterTurntableViewport), findsOneWidget);
      expect(find.byType(EquipmentSocketDock), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on Pixel 7 viewport without overflow', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final InventorySnapshot snapshot = InventorySnapshot(
        items: <InventoryItem>[_testWeapon()],
        equippedItems: <String, InventoryItem?>{
          'weapon': _testWeapon(),
        },
      );

      await tester.pumpWidget(
        _wrapScreen(
          child: const CharacterScreen(),
          profile: _testProfile(cClass: CharacterClass.shadow),
          snapshot: snapshot,
          size: const Size(412, 915),
          padding: const EdgeInsets.only(top: 24, bottom: 16),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CharacterTurntableViewport), findsOneWidget);
      expect(find.byType(EquipmentSocketDock), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on compact mobile viewport (360x640)', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final InventorySnapshot snapshot = const InventorySnapshot(
        items: <InventoryItem>[],
        equippedItems: <String, InventoryItem?>{},
      );

      await tester.pumpWidget(
        _wrapScreen(
          child: const CharacterScreen(),
          profile: _testProfile(cClass: CharacterClass.alchemist),
          snapshot: snapshot,
          size: const Size(360, 640),
          padding: const EdgeInsets.only(top: 20, bottom: 10),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CharacterTurntableViewport), findsOneWidget);
      expect(find.byType(EquipmentSocketDock), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping empty socket on CharacterScreen executes safely', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final InventorySnapshot snapshot = const InventorySnapshot(
        items: <InventoryItem>[],
        equippedItems: <String, InventoryItem?>{},
      );

      await tester.pumpWidget(
        _wrapScreen(
          child: const CharacterScreen(),
          profile: _testProfile(),
          snapshot: snapshot,
          size: const Size(393, 852),
          padding: const EdgeInsets.only(top: 59, bottom: 34),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on empty 'Miğfer' socket
      await tester.tap(find.text('Miğfer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });
}
