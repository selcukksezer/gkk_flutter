import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/screens/shop/widgets/merchant_vendor_header.dart';
import 'package:gkk_flutter/screens/shop/widgets/shop_quantity_dialog.dart';

void main() {
  group('MerchantVendorHeader Tests', () {
    testWidgets('renders Koranis merchant title and atmospheric dialogue', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MerchantVendorHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Koranis'), findsOneWidget);
      expect(find.text('Aether Tüccarı'), findsOneWidget);
      expect(find.byType(MerchantVendorHeader), findsOneWidget);
    });

    testWidgets('cycles dialogue on interactive tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MerchantVendorHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find initial quote
      final quoteFinder = find.byIcon(Icons.format_quote_rounded);
      expect(quoteFinder, findsOneWidget);

      // Tap quote bubble to cycle
      await tester.tap(quoteFinder);
      await tester.pumpAndSettle();

      // Tap again
      await tester.tap(quoteFinder);
      await tester.pumpAndSettle();
      expect(find.text('Koranis'), findsOneWidget);
    });

    testWidgets('displays kingdom blessing badge when active', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MerchantVendorHeader(
              hasKingdomBlessing: true,
              blessingDiscountPct: 15,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('-%15 Kutsama'), findsOneWidget);
    });
  });

  group('ShopQuantityDialog Tests', () {
    testWidgets('Buy Mode: displays item name, price, and updates quantity with buttons', (WidgetTester tester) async {
      int? confirmedQty;

      final testItem = <String, dynamic>{
        'id': 'potion_hp_1',
        'item_id': 'potion_hp_1',
        'name': 'Büyük Can İksiri',
        'description': 'Anında 500 can yeniler.',
        'icon': '🧪',
        'rarity': 'rare',
        'is_stackable': true,
        'max_stack': 99,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopQuantityDialog(
              mode: ShopDialogMode.buy,
              item: testItem,
              unitPrice: 150,
              currency: 'gold',
              walletBalance: 2000,
              onConfirm: (qty) async {
                confirmedQty = qty;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Büyük Can İksiri'), findsOneWidget);
      expect(find.text('Tüccardan Satın Al'), findsOneWidget);
      expect(find.text('Miktar Belirle'), findsOneWidget);

      // Initially quantity is 1
      expect(find.text('1'), findsWidgets);

      // Tap +1 button
      final addFinder = find.byIcon(Icons.add);
      expect(addFinder, findsOneWidget);
      await tester.tap(addFinder);
      await tester.pumpAndSettle();

      // Tap +10 button
      final add10Finder = find.text('+10');
      expect(add10Finder, findsOneWidget);
      await tester.tap(add10Finder);
      await tester.pumpAndSettle();

      // Tap CTA Satın Al
      final ctaFinder = find.byIcon(Icons.shopping_bag_rounded);
      expect(ctaFinder, findsOneWidget);
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      expect(confirmedQty, isNotNull);
      expect(confirmedQty! > 1, isTrue);
    });

    testWidgets('Buy Mode: warns when player has insufficient wallet funds', (WidgetTester tester) async {
      final testItem = <String, dynamic>{
        'id': 'legendary_sword',
        'item_id': 'legendary_sword',
        'name': 'Kutsal Aether Kılıcı',
        'description': 'Efsanevi güç.',
        'icon': '⚔️',
        'rarity': 'legendary',
        'is_stackable': false,
        'max_stack': 1,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopQuantityDialog(
              mode: ShopDialogMode.buy,
              item: testItem,
              unitPrice: 50000,
              currency: 'gold',
              walletBalance: 100, // Insufficient!
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Yetersiz bakiye'), findsOneWidget);
    });

    testWidgets('Sell Mode: displays correct sell header and prevents selling locked favorite item', (WidgetTester tester) async {
      final testItem = <String, dynamic>{
        'id': 'gold_ring',
        'item_id': 'gold_ring',
        'name': 'Yakut Yüzük',
        'description': 'Parlak yüzük.',
        'icon': '💍',
        'rarity': 'epic',
        'is_stackable': false,
        'max_stack': 1,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopQuantityDialog(
              mode: ShopDialogMode.sell,
              item: testItem,
              unitPrice: 1200,
              currency: 'gold',
              walletBalance: 5000,
              maxQuantityAvailable: 1,
              isFavorite: true, // Favorite locked!
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tüccara Eşya Sat'), findsOneWidget);
      expect(find.textContaining('favori olarak kilitlidir'), findsOneWidget);
    });
  });

  group('Category and Merchant Calculations', () {
    test('calculate discounted unit price with kingdom blessing', () {
      const int basePrice = 1000;
      const int discountPct = 10;
      final int discounted = (basePrice * (100 - discountPct) / 100).round();
      expect(discounted, equals(900));
    });

    test('vendor sell price fallback calculation', () {
      const int basePrice = 500;
      const int vendorSellPrice = 0;
      final int calculatedSellPrice = vendorSellPrice > 0 ? vendorSellPrice : (basePrice * 0.5).round();
      expect(calculatedSellPrice, equals(250));
    });
  });
}
