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

  /// Helper for 10x multi-open price (with standard 10x multiplier).
  int multiOpenPrice({int multiplier = 10}) => price * multiplier;

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

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    'description': description,
    'currency_type': currencyType,
    'price': price,
    'drop_count': dropCount,
    'jackpot_rate': jackpotRate,
    'reward_multiplier': rewardMultiplier,
    'art_asset': artAsset,
    'display_order': displayOrder,
    if (themeId != null) 'theme_id': themeId,
  };
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

  Map<String, dynamic> toMap() => <String, dynamic>{
    'item_id': itemId,
    'item_name': itemName,
    'icon': icon,
    'rarity': rarity,
    'drop_rate': dropRate,
    'min_quantity': minQuantity,
    'max_quantity': maxQuantity,
    'is_featured': isFeatured,
  };
}

/// Represents an individual item drop in a 10x Multi-Open bundle.
class LootMultiOpenReward {
  const LootMultiOpenReward({
    required this.itemId,
    required this.itemName,
    required this.icon,
    required this.rarity,
    required this.quantity,
    this.isJackpot = false,
  });

  final String itemId;
  final String itemName;
  final String icon;
  final String rarity;
  final int quantity;
  final bool isJackpot;

  factory LootMultiOpenReward.fromMap(Map<String, dynamic> map) {
    final int qty = lootToInt(
      map['quantity'],
      fallback: lootToInt(map['amount'], fallback: 1),
    );
    return LootMultiOpenReward(
      itemId: map['item_id']?.toString() ?? '',
      itemName: map['name']?.toString() ??
          map['item_name']?.toString() ??
          'Eşya',
      icon: map['icon']?.toString() ?? '',
      rarity: map['rarity']?.toString() ?? 'common',
      quantity: qty > 0 ? qty : 1,
      isJackpot: map['is_jackpot'] == true || map['is_featured'] == true,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'item_id': itemId,
    'item_name': itemName,
    'name': itemName,
    'icon': icon,
    'rarity': rarity,
    'quantity': quantity,
    'is_jackpot': isJackpot,
  };
}

/// Aggregated result of a 10x Multi-Open session.
class LootMultiOpenResult {
  const LootMultiOpenResult({
    required this.boxId,
    required this.boxName,
    required this.rewards,
    required this.openedAt,
    this.totalGold = 0,
    this.totalGems = 0,
  });

  final String boxId;
  final String boxName;
  final List<LootMultiOpenReward> rewards;
  final DateTime openedAt;
  final int totalGold;
  final int totalGems;

  /// Returns the highest rarity reward in the bundle for celebration highlight.
  LootMultiOpenReward? get highestRarityReward {
    if (rewards.isEmpty) return null;
    const Map<String, int> ranks = <String, int>{
      'eternal': 5,
      'ebedi': 5,
      'archon': 5,
      'mythic': 4,
      'fabled': 4,
      'efsanevi': 4,
      'legendary': 4,
      'heroic': 3,
      'epic': 3,
      'kahraman': 3,
      'destansi': 3,
      'rare': 2,
      'nadir': 2,
      'uncommon': 1,
      'common': 0,
      'siradan': 0,
    };

    LootMultiOpenReward best = rewards.first;
    int bestRank = ranks[best.rarity.toLowerCase()] ?? 0;
    for (final LootMultiOpenReward item in rewards) {
      final int r = ranks[item.rarity.toLowerCase()] ?? 0;
      if (r > bestRank) {
        bestRank = r;
        best = item;
      }
    }
    return best;
  }

  /// Breakdown of drops by rarity tier.
  Map<String, int> get rarityCounts {
    final Map<String, int> counts = <String, int>{};
    for (final LootMultiOpenReward r in rewards) {
      final String k = r.rarity.toLowerCase();
      counts[k] = (counts[k] ?? 0) + 1;
    }
    return counts;
  }

  factory LootMultiOpenResult.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawList = map['rewards'] is List
        ? map['rewards'] as List<dynamic>
        : (map['items'] is List
            ? map['items'] as List<dynamic>
            : const <dynamic>[]);

    return LootMultiOpenResult(
      boxId: map['box_id']?.toString() ?? '',
      boxName: map['box_name']?.toString() ?? 'Sandık',
      rewards: rawList
          .whereType<Map>()
          .map((m) => LootMultiOpenReward.fromMap(Map<String, dynamic>.from(m)))
          .toList(growable: false),
      openedAt: DateTime.tryParse(map['opened_at']?.toString() ?? '') ??
          DateTime.now(),
      totalGold: lootToInt(map['total_gold']),
      totalGems: lootToInt(map['total_gems']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'box_id': boxId,
    'box_name': boxName,
    'rewards': rewards.map((r) => r.toMap()).toList(growable: false),
    'opened_at': openedAt.toIso8601String(),
    'total_gold': totalGold,
    'total_gems': totalGems,
  };
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

/// SQL jackpot_rate is a 0–1 fraction; UI shows percent.
double lootJackpotPercent(double rate) {
  if (rate <= 0) return 0;
  // Guard: already-percent values (>1) stay as-is.
  return rate <= 1.0 ? rate * 100.0 : rate;
}

String lootJackpotPercentLabel(double rate, {int fractionDigits = 1}) {
  return '%';
}

String lootCompactNum(int value) {
  if (value >= 1000000000) {
    return 'B';
  }
  if (value >= 1000000) return 'M';
  if (value >= 1000) return 'K';
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
          'parseLootRpcRows: map payload missing data/rows ()',
        );
      }
      return const <Map<String, dynamic>>[];
    }
  } else {
    if (kDebugMode) {
      debugPrint(
        'parseLootRpcRows: unsupported payload type ',
      );
    }
    return const <Map<String, dynamic>>[];
  }

  if (rows is! List) {
    if (kDebugMode) {
      debugPrint('parseLootRpcRows: rows is , expected List');
    }
    return const <Map<String, dynamic>>[];
  }

  return rows
      .whereType<Map>()
      .map((Map row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

List<LootMultiOpenReward> parseLootMultiOpenRewards(dynamic payload) {
  final List<Map<String, dynamic>> rows = parseLootRpcRows(payload);
  if (rows.isNotEmpty) {
    return rows.map((r) => LootMultiOpenReward.fromMap(r)).toList(growable: false);
  }
  if (payload is Map) {
    final dynamic rewards = payload['rewards'] ?? payload['items'];
    if (rewards is List) {
      return rewards
          .whereType<Map>()
          .map((m) => LootMultiOpenReward.fromMap(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    }
  }
  return const <LootMultiOpenReward>[];
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
