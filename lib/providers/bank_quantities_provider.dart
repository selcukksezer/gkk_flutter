import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

List<Map<String, dynamic>> _parseBankItemRows(dynamic itemsRaw) {
  List<dynamic> rawList = <dynamic>[];
  if (itemsRaw is Map && itemsRaw['items'] is List) {
    rawList = itemsRaw['items'] as List<dynamic>;
  } else if (itemsRaw is List && itemsRaw.isNotEmpty) {
    final dynamic first = itemsRaw[0];
    if (first is Map && first['items'] is List) {
      rawList = first['items'] as List<dynamic>;
    } else {
      rawList = itemsRaw;
    }
  }

  return rawList
      .whereType<Map>()
      .map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e))
      .where((Map<String, dynamic> row) => _asInt(row['quantity']) > 0)
      .toList(growable: false);
}

/// `item_id` → total qty across bank slots (stack-summed).
Future<Map<String, int>> fetchBankQuantitiesByItemId() async {
  final dynamic itemsRaw = await SupabaseService.client.rpc(
    'get_bank_items',
    params: <String, dynamic>{'p_category': null},
  );

  final Map<String, int> quantities = <String, int>{};
  for (final Map<String, dynamic> row in _parseBankItemRows(itemsRaw)) {
    final String itemId = row['item_id']?.toString() ?? '';
    if (itemId.isEmpty) continue;
    quantities[itemId] = (quantities[itemId] ?? 0) + _asInt(row['quantity']);
  }
  return quantities;
}

/// Lightweight bank stock map for craft material hints.
/// Does not unlock craft — bag still required; UI nudges withdraw.
final bankQuantitiesProvider =
    FutureProvider.autoDispose<Map<String, int>>((Ref ref) async {
  try {
    return await fetchBankQuantitiesByItemId();
  } catch (_) {
    return <String, int>{};
  }
});
