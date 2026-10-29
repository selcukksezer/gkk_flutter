import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/l10n/l10n.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/screens/market/widgets/market_item_pedestal.dart';
import 'package:gkk_flutter/screens/trade/trade_screen.dart';
import 'package:gkk_flutter/screens/trade/widgets/trade_theme.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

InventoryItem _createMockInventoryItem({
  required String rowId,
  required String name,
  required String rarity,
  int quantity = 1,
  String icon = '🗡️',
  bool isTradeable = true,
  bool isDirectTradeable = true,
  bool isEquipped = false,
}) {
  return InventoryItem.fromJson(<String, dynamic>{
    'row_id': rowId,
    'item_id': 'itm_$rowId',
    'quantity': quantity,
    'slot_position': 0,
    'is_equipped': isEquipped,
    'equipped_slot': '',
    'enhancement_level': 0,
    'is_favorite': false,
    'pending_sync': false,
    'name': name,
    'description': 'Aion 2 test equipment',
    'icon': icon,
    'item_type': 'weapon',
    'rarity': rarity,
    'facility_type': null,
    'base_price': 100,
    'vendor_sell_price': 50,
    'attack': 10,
    'defense': 5,
    'health': 0,
    'power': 0,
    'luck': 0,
    'mana': 0,
    'equip_slot': 'weapon',
    'weapon_type': 'sword',
    'armor_type': 'none',
    'sub_type': 'sword',
    'required_level': 1,
    'can_enhance': true,
    'max_enhancement': 10,
    'is_stackable': true,
    'max_stack': 99,
    'is_tradeable': isTradeable,
    'is_han_only': false,
    'is_market_tradeable': isTradeable,
    'is_direct_tradeable': isDirectTradeable,
    'potion_type': 'none',
    'energy_restore': 0,
    'health_restore': 0,
    'tolerance_increase': 0,
  });
}

Widget _buildTestGoldChip(int amount, {bool compact = false}) {
  if (amount <= 0) return const SizedBox.shrink();
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 6 : 10,
      vertical: compact ? 4 : 6,
    ),
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      gradient: LinearGradient(
        colors: <Color>[
          AppColors.liquidGold.withValues(alpha: 0.18),
          AppColors.carbonVoid,
        ],
      ),
      border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.5), width: 1.0),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: AppColors.liquidGold.withValues(alpha: 0.15),
          blurRadius: 8,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.monetization_on, size: compact ? 13 : 16, color: AppColors.liquidGold),
        const SizedBox(width: 5),
        Text(
          '$amount Altın',
          style: TextStyle(
            color: AppColors.liquidGold,
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ],
    ),
  );
}

Widget _buildItemPickerSheetContent({
  required List<InventoryItem> items,
  required void Function(InventoryItem item) onSelect,
  required VoidCallback onClose,
}) {
  return Container(
    height: 400,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.spaceNavy,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.35)),
    ),
    child: Column(
      children: <Widget>[
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.mutedTitanium.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Row(
          children: <Widget>[
            const Icon(Icons.inventory_2, color: AppColors.liquidGold, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'TEKLİFE EŞYA EKLE',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: AppColors.mutedTitanium, size: 20),
            ),
          ],
        ),
        const Divider(color: AppColors.darkObsidian),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'Takas edilebilir eşya bulunamadı',
                    style: TextStyle(color: AppColors.mutedTitanium, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (BuildContext ctx, int i) {
                    final InventoryItem item = items[i];
                    final bool tradable = item.isTradeable && (item.isDirectTradeable ?? true);
                    return Opacity(
                      opacity: tradable ? 1.0 : 0.38,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.carbonVoid,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: <Widget>[
                            MarketItemPedestal(
                              rarity: item.rarity.name,
                              iconValue: item.icon,
                              itemName: item.name,
                              size: 38,
                              interactive: false,
                              autoRotate: false,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    tradable ? 'x${item.quantity} Adet' : 'Takas edilemez',
                                    style: const TextStyle(
                                      color: AppColors.mutedTitanium,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (tradable)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.liquidGold.withValues(alpha: 0.2),
                                  foregroundColor: AppColors.liquidGold,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: () => onSelect(item),
                                icon: const Icon(Icons.add, size: 13),
                                label: const Text('Ekle', style: TextStyle(fontSize: 11)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('2027 Aion 2 Mobile — Trade Filigree Panels & Slots', () {
    testWidgets('TradeFiligreePanel renders with custom painter, corner flourishes, and custom fill', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeFiligreePanel(
                accent: AppColors.liquidGold,
                showCornerGems: true,
                showRunicTicks: true,
                child: Text('Aion Filigree'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TradeFiligreePanel), findsOneWidget);
      expect(find.text('Aion Filigree'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('TradeFiligreeSlot renders empty state with rune watermark', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeFiligreeSlot(
                offer: null,
                size: 60,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TradeFiligreeSlot), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('TradeFiligreeSlot renders occupied item with pedestal and remove button for owner', (WidgetTester tester) async {
      bool removed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeFiligreeSlot(
                offer: const <String, dynamic>{
                  'row_id': '101',
                  'name': 'Archon Divine Blade',
                  'rarity': 'mythic',
                  'icon': '🗡️',
                  'quantity': 3,
                },
                isMine: true,
                allowRemove: true,
                onRemove: () => removed = true,
                size: 60,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TradeFiligreeSlot), findsOneWidget);
      expect(find.byType(MarketItemPedestal), findsOneWidget);
      expect(find.text('x3'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(removed, isTrue);

      // Clean up tickers
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('TradeFiligreeSlot does not render remove button when not owned or remove disallowed', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeFiligreeSlot(
                offer: <String, dynamic>{
                  'row_id': '202',
                  'name': 'Dragon Shield',
                  'rarity': 'legendary',
                  'icon': '🛡️',
                  'quantity': 1,
                },
                isMine: false,
                allowRemove: false,
                size: 60,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TradeFiligreeSlot), findsOneWidget);
      expect(find.byType(MarketItemPedestal), findsOneWidget);
      // Single quantity does not render quantity tag
      expect(find.text('x1'), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('TradeFiligreeSlot tap opens 3D pedestal inspection sheet', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeFiligreeSlot(
                offer: const <String, dynamic>{
                  'row_id': '303',
                  'name': 'Abyssal Ring',
                  'rarity': 'epic',
                  'icon': '💍',
                  'quantity': 2,
                },
                size: 60,
              ),
            ),
          ),
        ),
      );

      // Tap slot to trigger inspection sheet
      await tester.tap(find.byType(TradeFiligreeSlot));
      await tester.pumpAndSettle();

      expect(find.byType(MarketPedestalInspectionSheet), findsOneWidget);
      expect(find.text('Abyssal Ring'), findsOneWidget);
      expect(find.text('Takas Teklifi • x2 Adet'), findsOneWidget);
      expect(find.text('Kapat'), findsOneWidget);

      // Tap Kapat to dismiss modal
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      expect(find.byType(MarketPedestalInspectionSheet), findsNothing);
    });

    testWidgets('6-Slot offer deck renders mixed items and empty rune slots', (WidgetTester tester) async {
      final List<Map<String, dynamic>> mockOffers = <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Kılıç', 'rarity': 'epic', 'quantity': 1},
        <String, dynamic>{'name': 'Yüzük', 'rarity': 'mythic', 'quantity': 4},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeFiligreePanel(
                accent: AppColors.liquidGold,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('${mockOffers.length}/6 Eşya'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List<Widget>.generate(6, (int index) {
                        final Map<String, dynamic>? offer = index < mockOffers.length ? mockOffers[index] : null;
                        return TradeFiligreeSlot(offer: offer, size: 50);
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('2/6 Eşya'), findsOneWidget);
      // Total 6 slots generated
      expect(find.byType(TradeFiligreeSlot), findsNWidgets(6));
      // 4 empty slots have rune watermarks
      expect(find.byIcon(Icons.shield_outlined), findsNWidgets(4));
      // 2 occupied slots have pedestals
      expect(find.byType(MarketItemPedestal), findsNWidgets(2));
      expect(find.text('x4'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('2027 Aion 2 Mobile — Trading Offer UI & Gold Presets', () {
    testWidgets('Gold chip renders active gold offer with liquid gold styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _buildTestGoldChip(500),
            ),
          ),
        ),
      );

      expect(find.text('500 Altın'), findsOneWidget);
      expect(find.byIcon(Icons.monetization_on), findsOneWidget);
    });

    testWidgets('Gold chip in compact mode renders with smaller typography', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _buildTestGoldChip(1200, compact: true),
            ),
          ),
        ),
      );

      expect(find.text('1200 Altın'), findsOneWidget);
      final Text textWidget = tester.widget<Text>(find.text('1200 Altın'));
      expect(textWidget.style?.fontSize, 10);
    });

    testWidgets('Gold chip returns shrink widget when amount is zero or negative', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _buildTestGoldChip(0),
            ),
          ),
        ),
      );

      expect(find.text('0 Altın'), findsNothing);
      expect(find.byIcon(Icons.monetization_on), findsNothing);
    });

    testWidgets('Quick gold presets (+100, +500, TÜMÜ) accurately update text controller', (WidgetTester tester) async {
      final TextEditingController goldController = TextEditingController(text: '0');
      const int playerMaxGold = 1500;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Column(
                  children: <Widget>[
                    TextField(controller: goldController),
                    Wrap(
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: () {
                            final int cur = int.tryParse(goldController.text.trim()) ?? 0;
                            goldController.text = (cur + 100).clamp(0, playerMaxGold).toString();
                          },
                          child: const Text('+100'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final int cur = int.tryParse(goldController.text.trim()) ?? 0;
                            goldController.text = (cur + 500).clamp(0, playerMaxGold).toString();
                          },
                          child: const Text('+500'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            goldController.text = playerMaxGold.toString();
                          },
                          child: const Text('TÜMÜ (MAX)'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(goldController.text, '0');

      // Tap +100
      await tester.tap(find.text('+100'));
      await tester.pump();
      expect(goldController.text, '100');

      // Tap +500
      await tester.tap(find.text('+500'));
      await tester.pump();
      expect(goldController.text, '600');

      // Tap TÜMÜ (MAX)
      await tester.tap(find.text('TÜMÜ (MAX)'));
      await tester.pump();
      expect(goldController.text, '1500');
    });

    testWidgets('Duel summary row adapts between wide dual-column and mobile vertical stack', (WidgetTester tester) async {
      Widget buildDeck(bool isCompact) {
        return MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: isCompact
                  ? const Column(
                      children: <Widget>[
                        Text('Senin Teklifin'),
                        TradeDualLockIndicator(myConfirmed: false, partnerConfirmed: false),
                        Text('Karşı Taraf'),
                      ],
                    )
                  : const Column(
                      children: <Widget>[
                        TradeDualLockIndicator(myConfirmed: false, partnerConfirmed: false),
                        Row(
                          children: <Widget>[
                            Expanded(child: Text('Senin Teklifin')),
                            Expanded(child: Text('Karşı Taraf')),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        );
      }

      // 1. Wide view
      await tester.pumpWidget(buildDeck(false));
      expect(find.byType(Row), findsWidgets);
      expect(find.text('Senin Teklifin'), findsOneWidget);
      expect(find.text('Karşı Taraf'), findsOneWidget);

      // 2. Mobile Compact view
      await tester.pumpWidget(buildDeck(true));
      expect(find.byType(Column), findsWidgets);
      expect(find.text('Senin Teklifin'), findsOneWidget);
      expect(find.text('Karşı Taraf'), findsOneWidget);
    });
  });

  group('2027 Aion 2 Mobile — Lock-in Aura & Dual Lock Indicator', () {
    testWidgets('TradeLockInAura unlocked state renders unlocked banner without glow', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeLockInAura(
                isLockedIn: false,
                lockLabel: 'KİLİTLENDİ',
                unlockedLabel: 'TEKLİF HAZIRLANIYOR',
                child: SizedBox(width: 100, height: 60, child: Text('Deck')),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TradeLockInAura), findsOneWidget);
      expect(find.text('TEKLİF HAZIRLANIYOR'), findsOneWidget);
      expect(find.byIcon(Icons.lock_open), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsNothing);
    });

    testWidgets('TradeLockInAura locked state pulses with ethereal shadow and status banner', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeLockInAura(
                isLockedIn: true,
                lockLabel: 'TEKLİF KİLİTLENDİ',
                child: SizedBox(width: 120, height: 80, child: Text('Offer Deck')),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TradeLockInAura), findsOneWidget);
      expect(find.text('TEKLİF KİLİTLENDİ'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);

      // Verify animation frames step without errors
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('TradeDualLockIndicator shows unconfirmed and confirmed states across traders', (WidgetTester tester) async {
      // Both pending
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeDualLockIndicator(
                myConfirmed: false,
                partnerConfirmed: false,
                myName: 'Sen',
                partnerName: 'Lord_Aion',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sen'), findsOneWidget);
      expect(find.text('Lord_Aion'), findsOneWidget);
      expect(find.text('Bekleniyor'), findsNWidgets(2));
      expect(find.byIcon(Icons.sync_alt), findsOneWidget);

      // Both confirmed
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeDualLockIndicator(
                myConfirmed: true,
                partnerConfirmed: true,
                myName: 'Sen',
                partnerName: 'Lord_Aion',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Kilitlendi'), findsNWidgets(2));
      expect(find.byIcon(Icons.vpn_key), findsOneWidget);
    });
  });

  group('2027 Aion 2 Mobile — Player Inventory Exchange & Picker Sheet', () {
    testWidgets('Inventory picker displays tradable items with add button and invokes selection', (WidgetTester tester) async {
      final List<InventoryItem> items = <InventoryItem>[
        _createMockInventoryItem(
          rowId: 'item_1',
          name: 'Kara Çelik Kılıç',
          rarity: 'legendary',
          quantity: 2,
          isTradeable: true,
          isDirectTradeable: true,
        ),
        _createMockInventoryItem(
          rowId: 'item_2',
          name: 'Kutsal Şövalye Rozeti',
          rarity: 'epic',
          quantity: 1,
          isTradeable: false,
          isDirectTradeable: false,
        ),
      ];

      InventoryItem? selectedItem;
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _buildItemPickerSheetContent(
              items: items,
              onSelect: (InventoryItem item) => selectedItem = item,
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      expect(find.text('TEKLİFE EŞYA EKLE'), findsOneWidget);
      expect(find.text('Kara Çelik Kılıç'), findsOneWidget);
      expect(find.text('x2 Adet'), findsOneWidget);
      expect(find.text('Kutsal Şövalye Rozeti'), findsOneWidget);
      expect(find.text('Takas edilemez'), findsOneWidget);

      // Tap Ekle on tradable item
      expect(find.text('Ekle'), findsOneWidget);
      await tester.tap(find.text('Ekle'));
      await tester.pump();
      expect(selectedItem?.name, 'Kara Çelik Kılıç');

      // Tap close
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(closed, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Inventory picker renders empty state when no items tradable', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _buildItemPickerSheetContent(
              items: <InventoryItem>[],
              onSelect: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('Takas edilebilir eşya bulunamadı'), findsOneWidget);
    });
  });

  group('2027 Aion 2 Mobile — Confirmation & Action Buttons', () {
    testWidgets('TradePrimaryButton responds to taps when enabled and meets 48px touch target', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradePrimaryButton(
                label: 'Teklifi Kilitle',
                icon: Icons.lock,
                color: AppColors.toxicNeon,
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Teklifi Kilitle'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);

      final Size buttonSize = tester.getSize(find.byType(TradePrimaryButton));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));

      await tester.tap(find.byType(TradePrimaryButton));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('TradePrimaryButton in disabled state ignores taps and renders muted styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradePrimaryButton(
                label: 'Teklifi Kilitle',
                icon: Icons.lock,
                onPressed: null,
              ),
            ),
          ),
        ),
      );

      final Text textWidget = tester.widget<Text>(find.text('Teklifi Kilitle'));
      expect(textWidget.style?.color, AppColors.mutedTitanium);

      await tester.tap(find.byType(TradePrimaryButton));
      await tester.pump();
    });

    testWidgets('TradeSecondaryButton meets mobile standards and handles tap', (WidgetTester tester) async {
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeSecondaryButton(
                label: 'İptal',
                icon: Icons.close,
                onPressed: () => cancelled = true,
              ),
            ),
          ),
        ),
      );

      final Size buttonSize = tester.getSize(find.byType(TradeSecondaryButton));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));

      await tester.tap(find.byType(TradeSecondaryButton));
      await tester.pump();
      expect(cancelled, isTrue);
    });
  });

  group('2027 Aion 2 Mobile — Countdown Confirmation Seal & Safeguard', () {
    testWidgets('TradeCountdownSeal steps seconds and completes cleanly with checkmark', (WidgetTester tester) async {
      bool completed = false;
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeCountdownSeal(
                durationSeconds: 3,
                title: 'TİCARET TAMAMLANIYOR',
                subtitle: 'Her iki taraf teklifini mühürledi.',
                onComplete: () => completed = true,
                onCancel: () => cancelled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('TİCARET TAMAMLANIYOR'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(completed, isFalse);

      // Advance 1s -> 2
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);

      // Advance 1s -> 1
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);

      // Advance 1s -> 0 (completion)
      await tester.pump(const Duration(seconds: 1));
      expect(completed, isTrue);
      expect(cancelled, isFalse);
      expect(find.text('TAMAMLANDI'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('TradeCountdownSeal cancel safeguard cancels timer and invokes onCancel', (WidgetTester tester) async {
      bool completed = false;
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeCountdownSeal(
                durationSeconds: 3,
                onComplete: () => completed = true,
                onCancel: () => cancelled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Mührü İptal Et'), findsOneWidget);

      // Advance 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);

      // Tap cancel button
      await tester.tap(find.text('Mührü İptal Et'));
      await tester.pump();
      expect(cancelled, isTrue);
      expect(completed, isFalse);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('2027 Aion 2 Mobile — Error States & Blocked Players Panel', () {
    testWidgets('History error state displays retry button and invokes callback', (WidgetTester tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Geçmiş yüklenemedi', style: TextStyle(color: AppColors.mysticRuby)),
                  const SizedBox(height: 12),
                  TradePrimaryButton(
                    label: 'Tekrar Dene',
                    icon: Icons.refresh,
                    onPressed: () => retried = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Geçmiş yüklenemedi'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);

      await tester.tap(find.text('Tekrar Dene'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('History empty state displays placeholder message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.history_toggle_off, color: AppColors.mutedTitanium, size: 40),
                  Text('Henüz ticaret geçmişi kaydı bulunmuyor.'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.history_toggle_off), findsOneWidget);
      expect(find.text('Henüz ticaret geçmişi kaydı bulunmuyor.'), findsOneWidget);
    });

    testWidgets('Blocked players panel expands and allows unblocking', (WidgetTester tester) async {
      bool unblocked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                bool expanded = false;
                return Center(
                  child: TradeFiligreePanel(
                    accent: AppColors.mysticRuby,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        InkWell(
                          onTap: () => setState(() => expanded = !expanded),
                          child: const Row(
                            children: <Widget>[
                              Icon(Icons.block, color: AppColors.mysticRuby),
                              Text('ENGELLENEN OYUNCULAR (1)'),
                            ],
                          ),
                        ),
                        if (expanded)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: <Widget>[
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text('@dark_sorcerer'),
                                      Text('Engel bitiş: 18:30'),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => unblocked = true,
                                  child: const Text('Kaldır'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('ENGELLENEN OYUNCULAR (1)'), findsOneWidget);
      expect(find.text('@dark_sorcerer'), findsNothing);

      // Tap to expand
      await tester.tap(find.text('ENGELLENEN OYUNCULAR (1)'));
      await tester.pumpAndSettle();

      expect(find.text('@dark_sorcerer'), findsOneWidget);
      expect(find.text('Engel bitiş: 18:30'), findsOneWidget);
      expect(find.text('Kaldır'), findsOneWidget);

      await tester.tap(find.text('Kaldır'));
      await tester.pump();
      expect(unblocked, isTrue);
    });

    testWidgets('Trade status banners display appropriate messaging', (WidgetTester tester) async {
      const Map<String, String> statusLabels = <String, String>{
        'searching': '⏳ Oyuncu aranıyor...',
        'pending': '⏳ Ticaret başlatıldı, karşı taraf bekleniyor...',
        'confirming': '✅ Onayınız alındı, karşı taraf bekleniyor',
        'done': '🎉 Ticaret tamamlandı',
      };

      for (final MapEntry<String, String> entry in statusLabels.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text(entry.value),
              ),
            ),
          ),
        );

        expect(find.text(entry.value), findsOneWidget);
      }
    });
  });

  group('2027 Aion 2 Mobile — Trade Log Card & Ledger Entries', () {
    testWidgets('TradeLogCard renders completed trade with positive net gold footnote', (WidgetTester tester) async {
      final Map<String, dynamic> mockEntry = <String, dynamic>{
        'status': 'completed',
        'partner': 'Asmodian_Slayer',
        'date': '2027-10-28 21:40',
        'my_gold': 500,
        'their_gold': 1200,
        'my_items': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Ejderha Yüzüğü',
            'rarity': 'epic',
            'quantity': 1,
            'icon': '💍',
          },
        ],
        'their_items': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Kara Çelik Zırh',
            'rarity': 'legendary',
            'quantity': 1,
            'icon': '🛡️',
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TradeLogCard(entry: mockEntry),
            ),
          ),
        ),
      );

      expect(find.byType(TradeLogCard), findsOneWidget);
      expect(find.text('Asmodian_Slayer'), findsOneWidget);
      expect(find.text('MÜHÜRLENDİ'), findsOneWidget);
      expect(find.text('500 Altın'), findsOneWidget);
      expect(find.text('1200 Altın'), findsOneWidget);
      expect(find.text('Ejderha Yüzüğü x1'), findsOneWidget);
      expect(find.text('Kara Çelik Zırh x1'), findsOneWidget);
      expect(find.text('+700 Altın'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('TradeLogCard renders cancelled trade with empty item placeholders and negative gold', (WidgetTester tester) async {
      final Map<String, dynamic> mockCancelled = <String, dynamic>{
        'status': 'cancelled',
        'partner': 'Renegade_Elf',
        'date': '2027-10-28 14:15',
        'my_gold': 800,
        'their_gold': 200,
        'my_items': <Map<String, dynamic>>[],
        'their_items': <Map<String, dynamic>>[],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TradeLogCard(entry: mockCancelled),
            ),
          ),
        ),
      );

      expect(find.text('Renegade_Elf'), findsOneWidget);
      expect(find.text('İPTAL'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.text('— Eşya yok —'), findsNWidgets(2));

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('2027 Aion 2 Mobile — Backdrop & Neon Panel Styling', () {
    testWidgets('TradeBackdrop renders dark void gradient and custom grid painter', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TradeBackdrop(
              child: Center(child: Text('Celestial Nebula')),
            ),
          ),
        ),
      );

      expect(find.byType(TradeBackdrop), findsOneWidget);
      expect(find.text('Celestial Nebula'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('TradeNeonPanel wraps child with rounded borders and ambient glow', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TradeNeonPanel(
                accent: AppColors.toxicNeon,
                child: Text('Neon Altar'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TradeNeonPanel), findsOneWidget);
      expect(find.text('Neon Altar'), findsOneWidget);
    });
  });

  group('TradeScreen UI Smoke & Tab Navigation Test', () {
    testWidgets('TradeScreen builds with tabs and switches between Trade and History', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TradeScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(TradeScreen), findsOneWidget);
      expect(find.text('🤝 Ticaret'), findsOneWidget);
      expect(find.text('📜 Geçmiş'), findsOneWidget);
      expect(find.text('OYUNCU TİCARET ODASI'), findsOneWidget);
      expect(find.text('ENGELLENEN OYUNCULAR'), findsOneWidget);

      // Switch to History Tab
      await tester.tap(find.text('📜 Geçmiş'));
      await tester.pump();
      expect(find.byType(TradeScreen), findsOneWidget);

      // Switch back to Trade Tab
      await tester.tap(find.text('🤝 Ticaret'));
      await tester.pump();
      expect(find.text('OYUNCU TİCARET ODASI'), findsOneWidget);
    });
  });
}
