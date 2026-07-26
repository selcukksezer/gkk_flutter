import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';
import '../models/kingdom_market_blessing_model.dart';

class KingdomMarketBlessingNotifier extends Notifier<KingdomMarketBlessingStatus> {
  @override
  KingdomMarketBlessingStatus build() => KingdomMarketBlessingStatus.inactive();

  Future<void> load() async {
    try {
      final dynamic raw =
          await SupabaseService.client.rpc('get_kingdom_market_blessing_status');
      final Map<String, dynamic>? map = _decodeMap(raw);
      state = map == null
          ? KingdomMarketBlessingStatus.inactive()
          : KingdomMarketBlessingStatus.fromJson(map);
    } catch (_) {
      // Sessiz: indirim banner opsiyonel; mağaza akışını kesme.
    }
  }
}

Map<String, dynamic>? _decodeMap(dynamic data) {
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  if (data is String && data.trim().isNotEmpty) {
    final dynamic parsed = jsonDecode(data);
    if (parsed is Map) {
      return Map<String, dynamic>.from(parsed);
    }
  }
  return null;
}

final kingdomMarketBlessingProvider =
    NotifierProvider<KingdomMarketBlessingNotifier, KingdomMarketBlessingStatus>(
  KingdomMarketBlessingNotifier.new,
);
