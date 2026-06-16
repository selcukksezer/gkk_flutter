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
