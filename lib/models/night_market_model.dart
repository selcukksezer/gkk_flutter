class NightMarketOffer {
  const NightMarketOffer({
    required this.offerId,
    required this.itemId,
    required this.itemName,
    this.rarity,
    this.icon,
    required this.gemPrice,
    required this.baseGemPrice,
    required this.stockPerPlayer,
    required this.purchased,
    required this.remaining,
  });

  final String offerId;
  final String itemId;
  final String itemName;
  final String? rarity;
  final String? icon;
  final int gemPrice;
  final int baseGemPrice;
  final int stockPerPlayer;
  final int purchased;
  final int remaining;

  factory NightMarketOffer.fromJson(Map<String, dynamic> json) {
    return NightMarketOffer(
      offerId: (json['offer_id'] ?? '').toString(),
      itemId: (json['item_id'] ?? '').toString(),
      itemName: (json['item_name'] ?? json['item_id'] ?? '').toString(),
      rarity: json['rarity']?.toString(),
      icon: json['icon']?.toString(),
      gemPrice: (json['gem_price'] as num?)?.toInt() ?? 0,
      baseGemPrice: (json['base_gem_price'] as num?)?.toInt() ?? 0,
      stockPerPlayer: (json['stock_per_player'] as num?)?.toInt() ?? 1,
      purchased: (json['purchased'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    );
  }
}

class NightMarketStatus {
  const NightMarketStatus({
    required this.active,
    this.startsAt,
    this.endsAt,
    required this.secondsLeft,
    required this.shadowBonus,
    required this.shadowDiscountPct,
    required this.offers,
  });

  final bool active;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int secondsLeft;
  final bool shadowBonus;
  final int shadowDiscountPct;
  final List<NightMarketOffer> offers;

  factory NightMarketStatus.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawOffers = json['offers'] is List
        ? json['offers'] as List
        : const <dynamic>[];
    return NightMarketStatus(
      active: json['active'] == true,
      startsAt: json['starts_at'] == null
          ? null
          : DateTime.tryParse(json['starts_at'].toString()),
      endsAt: json['ends_at'] == null
          ? null
          : DateTime.tryParse(json['ends_at'].toString()),
      secondsLeft: (json['seconds_left'] as num?)?.toInt() ?? 0,
      shadowBonus: json['shadow_bonus'] == true,
      shadowDiscountPct: (json['shadow_discount_pct'] as num?)?.toInt() ?? 0,
      offers: rawOffers
          .whereType<Map>()
          .map((dynamic o) => NightMarketOffer.fromJson(Map<String, dynamic>.from(o)))
          .toList(growable: false),
    );
  }

  static const NightMarketStatus closed = NightMarketStatus(
    active: false,
    secondsLeft: 0,
    shadowBonus: false,
    shadowDiscountPct: 0,
    offers: <NightMarketOffer>[],
  );
}
