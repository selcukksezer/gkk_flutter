class MarketOrder {
  const MarketOrder({
    required this.orderId,
    required this.sellerId,
    required this.itemId,
    required this.itemName,
    required this.itemType,
    required this.rarity,
    required this.isStackable,
    required this.maxStack,
    required this.side,
    required this.quantity,
    required this.price,
    required this.status,
    required this.createdAt,
    this.inventoryRowId,
    this.enhancementLevel = 0,
  });

  final String orderId;
  final String sellerId;
  final String itemId;
  final String itemName;
  final String itemType;
  final String rarity;
  final bool isStackable;
  final int maxStack;
  final String side;
  final int quantity;
  final int price;
  final String status;
  final String createdAt;
  final String? inventoryRowId;
  final int enhancementLevel;

  int get totalValue => price * quantity;

  int get sellerReceives => (totalValue * 0.95).floor();

  int get marketFee => totalValue - sellerReceives;

  factory MarketOrder.fromJson(Map<String, dynamic> json) {
    return MarketOrder(
      orderId: (json['order_id'] ?? json['id'] ?? '').toString(),
      sellerId: (json['seller_id'] ?? json['player_id'] ?? '').toString(),
      itemId: (json['item_id'] ?? '').toString(),
      itemName: (json['item_name'] ?? 'Bilinmeyen Eşya').toString(),
      itemType: (json['item_type'] ?? '').toString(),
      rarity: (json['rarity'] ?? 'common').toString(),
      isStackable: json['is_stackable'] == true,
      maxStack: (json['max_stack'] as num?)?.toInt() ?? 1,
      side: (json['side'] ?? 'sell').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'open').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      inventoryRowId: json['inventory_row_id']?.toString(),
      enhancementLevel: (json['enhancement_level'] as num?)?.toInt() ?? 0,
    );
  }
}

class MarketListing {
  const MarketListing({
    required this.orderId,
    required this.sellerId,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.isStackable,
    required this.maxStack,
    required this.rarity,
    required this.itemType,
    this.enhancementLevel = 0,
  });

  final String orderId;
  final String sellerId;
  final String itemId;
  final String itemName;
  final int quantity;
  final int unitPrice;
  final bool isStackable;
  final int maxStack;
  final String rarity;
  final String itemType;
  final int enhancementLevel;
}

class MarketTicker {
  const MarketTicker({
    required this.itemId,
    required this.itemName,
    required this.itemType,
    required this.rarity,
    required this.isStackable,
    required this.lowestPrice,
    required this.volume,
    required this.priceChange,
    required this.maxAvailableQty,
    this.cheapestOrderId,
    this.cheapestSellerId,
  });

  final String itemId;
  final String itemName;
  final String itemType;
  final String rarity;
  final bool isStackable;
  final int lowestPrice;
  final int volume;
  final int priceChange;
  final int maxAvailableQty;
  final String? cheapestOrderId;
  final String? cheapestSellerId;

  factory MarketTicker.fromRpcJson(Map<String, dynamic> json) {
    return MarketTicker(
      itemId: (json['item_id'] ?? '').toString(),
      itemName: (json['item_name'] ?? 'Bilinmeyen Eşya').toString(),
      itemType: (json['item_type'] ?? '').toString(),
      rarity: (json['rarity'] ?? 'common').toString(),
      isStackable: json['is_stackable'] == true,
      lowestPrice: (json['lowest_price'] as num?)?.toInt() ?? 0,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      // Server yüzde döner; UI helper'lar baz puan (bps) bekler.
      priceChange: ((json['price_change'] as num?)?.toInt() ?? 0) * 100,
      maxAvailableQty: (json['max_available_qty'] as num?)?.toInt() ?? 0,
      cheapestOrderId: json['cheapest_order_id']?.toString(),
      cheapestSellerId: json['cheapest_seller_id']?.toString(),
    );
  }
}

/// Tek pazar işlemi (satış veya alış) — get_my_market_history satırı.
class MarketTradeRecord {
  const MarketTradeRecord({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.fee,
    required this.isSale,
    required this.counterparty,
    this.tradedAt,
  });

  final String id;
  final String itemId;
  final String itemName;
  final int quantity;
  final int unitPrice;
  final int totalPrice;
  final int fee;
  final bool isSale;
  final String counterparty;
  final DateTime? tradedAt;

  /// Satışta ele geçen net altın; alışta ödenen toplam.
  int get netAmount => isSale ? totalPrice - fee : totalPrice;

  factory MarketTradeRecord.fromJson(Map<String, dynamic> json) {
    return MarketTradeRecord(
      id: (json['id'] ?? '').toString(),
      itemId: (json['item_id'] ?? '').toString(),
      itemName: (json['item_name'] ?? 'Bilinmeyen Eşya').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toInt() ?? 0,
      totalPrice: (json['total_price'] as num?)?.toInt() ?? 0,
      fee: (json['fee'] as num?)?.toInt() ?? 0,
      isSale: (json['role'] ?? '').toString() == 'sale',
      counterparty: (json['counterparty'] ?? 'Oyuncu').toString(),
      tradedAt: DateTime.tryParse((json['traded_at'] ?? '').toString())
          ?.toLocal(),
    );
  }
}

class MarketTickerQuery {
  const MarketTickerQuery({
    this.search = '',
    this.itemType = '',
    this.rarity = '',
    this.sortKey = 'price_asc',
  });

  final String search;
  final String itemType;
  final String rarity;
  final String sortKey;

  MarketTickerQuery copyWith({
    String? search,
    String? itemType,
    String? rarity,
    String? sortKey,
  }) {
    return MarketTickerQuery(
      search: search ?? this.search,
      itemType: itemType ?? this.itemType,
      rarity: rarity ?? this.rarity,
      sortKey: sortKey ?? this.sortKey,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MarketTickerQuery &&
        other.search == search &&
        other.itemType == itemType &&
        other.rarity == rarity &&
        other.sortKey == sortKey;
  }

  @override
  int get hashCode => Object.hash(search, itemType, rarity, sortKey);
}

class MarketTickersPage {
  const MarketTickersPage({
    required this.items,
    required this.total,
    required this.totalListings,
  });

  final List<MarketTicker> items;
  final int total;
  final int totalListings;
}

/// Fixed player market fee rate (5% deducted from seller proceeds).
const double marketFeeRate = 0.05;

int marketSellerReceives(int unitPrice, int quantity) {
  final int total = unitPrice * quantity;
  return (total * (1 - marketFeeRate)).floor();
}

int marketFeeAmount(int unitPrice, int quantity) {
  final int total = unitPrice * quantity;
  return total - marketSellerReceives(unitPrice, quantity);
}
