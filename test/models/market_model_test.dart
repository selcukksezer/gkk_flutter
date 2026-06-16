import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/market_model.dart';

void main() {
  group('market fee', () {
    test('5 percent fee on 1000 x 10', () {
      expect(marketFeeAmount(1000, 10), 500);
      expect(marketSellerReceives(1000, 10), 9500);
    });

    test('single unit fee floors correctly', () {
      expect(marketSellerReceives(99, 1), 94);
      expect(marketFeeAmount(99, 1), 5);
    });
  });

  group('MarketOrder', () {
    test('computes seller receives from price and quantity', () {
      const MarketOrder order = MarketOrder(
        orderId: 'o1',
        sellerId: 's1',
        itemId: 'i1',
        itemName: 'Test',
        itemType: 'material',
        rarity: 'common',
        isStackable: true,
        maxStack: 99,
        side: 'sell',
        quantity: 10,
        price: 1000,
        status: 'open',
        createdAt: '',
      );

      expect(order.totalValue, 10000);
      expect(order.marketFee, 500);
      expect(order.sellerReceives, 9500);
    });
  });
}
