import 'package:flutter/foundation.dart';

class LootBoxView {
  const LootBoxView({
    required this.id,
    required this.name,
    required this.description,
    required this.currencyType,
    required this.price,
    required this.dropCount,
    required this.jackpotRate,
    required this.rewardMultiplier,
    required this.artAsset,
    required this.displayOrder,
    this.themeId,
  });

  final String id;
  final String name;
  final String description;
  final String currencyType;
  final int price;
  final int dropCount;
  final double jackpotRate;
  final double rewardMultiplier;
  final String artAsset;
  final int displayOrder;
  final String? themeId;

  factory LootBoxView.fromMap(Map<String, dynamic> map) {
    final String? themeId = map['theme_id']?.toString();
    return LootBoxView(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Kasa',
      description: map['description']?.toString() ?? '',
      currencyType: map['currency_type']?.toString() ?? 'gold',
      price: lootToInt(map['price']),
      dropCount: lootToInt(map['drop_count']),
      jackpotRate: lootToDouble(map['jackpot_rate']),
      rewardMultiplier: lootToDouble(
        map['reward_multiplier'],
        fallback: 1.0,
      ),
      artAsset: map['art_asset']?.toString() ?? '',
      displayOrder: lootToInt(map['display_order'], fallback: 1),
      themeId: themeId == null || themeId.isEmpty ? null : themeId,
    );
  }
}

class LootDropView {
  const LootDropView({
    required this.itemId,
    required this.itemName,
    required this.icon,
    required this.rarity,
    required this.dropRate,
    required this.minQuantity,
    required this.maxQuantity,
    this.isFeatured = false,
  });

  final String itemId;
  final String itemName;
  final String icon;
  final String rarity;
  final double dropRate;
  final int minQuantity;
  final int maxQuantity;
  final bool isFeatured;

  factory LootDropView.fromMap(Map<String, dynamic> map) {
    return LootDropView(
      itemId: map['item_id']?.toString() ?? '',
      itemName: map['item_name']?.toString() ?? 'Item',
      icon: map['icon']?.toString() ?? '',
      rarity: map['rarity']?.toString() ?? 'common',
      dropRate: lootToDouble(map['drop_rate']),
      minQuantity: lootToInt(map['min_quantity'], fallback: 1),
      maxQuantity: lootToInt(map['max_quantity'], fallback: 1),
      isFeatured: map['is_featured'] == true,
    );
  }
}

int compareLootDropsForPreview(LootDropView a, LootDropView b) {
  if (a.isFeatured != b.isFeatured) {
    return a.isFeatured ? -1 : 1;
  }
  final int rateCmp = b.dropRate.compareTo(a.dropRate);
  if (rateCmp != 0) return rateCmp;
  return a.itemName.compareTo(b.itemName);
}

int lootToInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double lootToDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// SQL `jackpot_rate` is a 0–1 fraction; UI shows percent.
double lootJackpotPercent(double rate) {
  if (rate <= 0) return 0;
  // Guard: already-percent values (>1) stay as-is.
  return rate <= 1.0 ? rate * 100.0 : rate;
}

String lootJackpotPercentLabel(double rate, {int fractionDigits = 1}) {
  return '%${lootJackpotPercent(rate).toStringAsFixed(fractionDigits)}';
}

String lootCompactNum(int value) {
  if (value >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(1)}B';
  }
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}

/// Normalizes Supabase RPC payloads into row maps.
List<Map<String, dynamic>> parseLootRpcRows(dynamic payload) {
  if (payload == null) return const <Map<String, dynamic>>[];

  final dynamic rows;
  if (payload is List) {
    rows = payload;
  } else if (payload is Map) {
    final Map<String, dynamic> map = Map<String, dynamic>.from(payload);
    rows = map['data'] ?? map['rows'];
    if (rows == null) {
      if (kDebugMode) {
        debugPrint(
          'parseLootRpcRows: map payload missing data/rows (${map.keys.join(', ')})',
        );
      }
      return const <Map<String, dynamic>>[];
    }
  } else {
    if (kDebugMode) {
      debugPrint(
        'parseLootRpcRows: unsupported payload type ${payload.runtimeType}',
      );
    }
    return const <Map<String, dynamic>>[];
  }

  if (rows is! List) {
    if (kDebugMode) {
      debugPrint('parseLootRpcRows: rows is ${rows.runtimeType}, expected List');
    }
    return const <Map<String, dynamic>>[];
  }

  return rows
      .whereType<Map>()
      .map((Map row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

int findLootTargetDropIndex(
  Map<String, dynamic> payload,
  List<LootDropView> drops,
) {
  if (drops.isEmpty) return -1;

  final Map<String, dynamic> reward = payload['reward'] is Map
      ? Map<String, dynamic>.from(payload['reward'] as Map)
      : <String, dynamic>{};

  final String resultItemId = reward['item_id']?.toString() ?? '';
  final String resultName = (reward['name']?.toString() ?? '').toLowerCase();

  int index = drops.indexWhere(
    (d) => resultItemId.isNotEmpty && d.itemId == resultItemId,
  );
  if (index >= 0) return index;

  index = drops.indexWhere((d) => d.itemName.toLowerCase() == resultName);
  if (index >= 0) return index;

  index = drops.indexWhere(
    (d) =>
        resultName.isNotEmpty &&
        d.itemName.toLowerCase().contains(resultName),
  );
  return index >= 0 ? index : -1;
}

LootDropView? lootDropFromRewardPayload(Map<String, dynamic> payload) {
  final Map<String, dynamic> reward = payload['reward'] is Map
      ? Map<String, dynamic>.from(payload['reward'] as Map)
      : <String, dynamic>{};

  final String itemId = reward['item_id']?.toString() ?? '';
  if (itemId.isEmpty) return null;

  final int qty = lootToInt(
    reward['quantity'],
    fallback: lootToInt(reward['amount'], fallback: 1),
  );

  final String fallbackName = reward['name']?.toString() ?? 'Reward';

  return LootDropView(
    itemId: itemId,
    itemName: fallbackName,
    icon: reward['icon']?.toString() ?? '',
    rarity: reward['rarity']?.toString() ?? 'common',
    dropRate: 0,
    minQuantity: qty,
    maxQuantity: qty,
  );
}
