import '../services/supabase_service.dart';
import '../../repositories/inventory_repository.dart';

const int kDefaultInventoryBoxGemCost = 10;

final Map<String, int> _gemCostCache = <String, int>{};

/// Gem ile envanter kutusu acma maliyeti — loot_box_configs.price (RPC).
Future<int> fetchInventoryBoxGemCost(String itemId) async {
  if (!isInventoryLootBox(itemId)) return kDefaultInventoryBoxGemCost;

  final int? cached = _gemCostCache[itemId];
  if (cached != null) return cached;

  try {
    final dynamic res = await SupabaseService.client.rpc(
      'get_inventory_box_gem_cost',
      params: <String, dynamic>{'p_box_id': itemId},
    );
    final int cost = _parseCost(res);
    _gemCostCache[itemId] = cost;
    return cost;
  } catch (_) {
    return kDefaultInventoryBoxGemCost;
  }
}

int _parseCost(dynamic res) {
  if (res is int) return res.clamp(1, 999999);
  if (res is num) return res.toInt().clamp(1, 999999);
  if (res is String) {
    return (int.tryParse(res) ?? kDefaultInventoryBoxGemCost).clamp(1, 999999);
  }
  return kDefaultInventoryBoxGemCost;
}

String formatInventoryBoxGemCostLabel(int gemCost) {
  return '$gemCost ELMAS';
}
