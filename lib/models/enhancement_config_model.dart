import '../../models/inventory_model.dart';
import '../../models/item_model.dart';

/// Sunucu kaynaklı güçlendirme tablosu (+ yerel fallback).
class EnhancementConfig {
  const EnhancementConfig({
    required this.baseCosts,
    required this.successRates,
    required this.destroyRates,
    required this.rarityMultipliers,
    this.goldDiscountPct = 0,
    this.monumentLevel = 0,
    this.fromServer = false,
  });

  final Map<int, int> baseCosts;
  final Map<int, int> successRates;
  final Map<int, int> destroyRates;
  final Map<String, double> rarityMultipliers;
  final int goldDiscountPct;
  final int monumentLevel;
  final bool fromServer;

  static const EnhancementConfig fallback = EnhancementConfig(
    baseCosts: <int, int>{
      0: 100000,
      1: 200000,
      2: 300000,
      3: 500000,
      4: 1500000,
      5: 3500000,
      6: 7500000,
      7: 15000000,
      8: 50000000,
      9: 200000000,
      10: 1000000000,
    },
    successRates: <int, int>{
      0: 100,
      1: 100,
      2: 100,
      3: 100,
      4: 70,
      5: 60,
      6: 50,
      7: 35,
      8: 20,
      9: 10,
      10: 3,
    },
    destroyRates: <int, int>{
      0: 0,
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 100,
      7: 100,
      8: 100,
      9: 100,
      10: 100,
    },
    rarityMultipliers: <String, double>{
      'common': 1.0,
      'uncommon': 1.5,
      'rare': 2.5,
      'epic': 4.0,
      'legendary': 7.0,
      'mythic': 12.0,
    },
  );

  factory EnhancementConfig.fromRpc(Map<String, dynamic> json) {
    return EnhancementConfig(
      baseCosts: _parseIntMap(json['base_costs'], EnhancementConfig.fallback.baseCosts),
      successRates: _parseIntMap(json['success_rates'], EnhancementConfig.fallback.successRates),
      destroyRates: _parseIntMap(json['destroy_rates'], EnhancementConfig.fallback.destroyRates),
      rarityMultipliers: _parseDoubleMap(json['rarity_multipliers']),
      goldDiscountPct: _asInt(json['gold_discount_pct']),
      monumentLevel: _asInt(json['monument_level']),
      fromServer: true,
    );
  }

  double rarityMultiplier(Rarity rarity) =>
      rarityMultipliers[rarity.name] ?? fallback.rarityMultiplier(rarity);

  int baseGoldCost(int enhancementLevel) =>
      baseCosts[enhancementLevel] ?? fallback.baseCosts[enhancementLevel] ?? 0;

  int successChanceForLevel(int level) =>
      successRates[level] ?? fallback.successRates[level] ?? 0;

  int goldCostForItem(InventoryItem? item) {
    if (item == null) return 0;
    final int raw = (baseGoldCost(item.enhancementLevel) * rarityMultiplier(item.rarity)).floor();
    if (goldDiscountPct <= 0) return raw;
    return (raw * (100 - goldDiscountPct) / 100).floor();
  }

  int undiscountedGoldCostForItem(InventoryItem? item) {
    if (item == null) return 0;
    return (baseGoldCost(item.enhancementLevel) * rarityMultiplier(item.rarity)).floor();
  }

  static Map<int, int> _parseIntMap(Object? raw, Map<int, int> fallbackMap) {
    if (raw is List) {
      final Map<int, int> out = <int, int>{};
      for (int i = 0; i < raw.length; i++) {
        out[i] = _asInt(raw[i]);
      }
      return out;
    }
    if (raw is Map) {
      return raw.map(
        (Object? key, Object? value) => MapEntry<int, int>(_asInt(key), _asInt(value)),
      );
    }
    return fallbackMap;
  }

  static Map<String, double> _parseDoubleMap(Object? raw) {
    if (raw is! Map) return EnhancementConfig.fallback.rarityMultipliers;
    return raw.map(
      (Object? key, Object? value) => MapEntry<String, double>(
        key.toString(),
        (value as num?)?.toDouble() ?? 1.0,
      ),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
