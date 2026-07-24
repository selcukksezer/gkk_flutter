import '../core/errors/app_exception.dart';
import '../core/services/supabase_service.dart';
import '../models/reputation_model.dart';

abstract class ReputationRepository {
  Future<ReputationOverview> loadOverview();
  Future<List<ReputationShopItem>> loadShopItems();
  Future<Map<String, dynamic>> purchaseItem({required String itemId});
}

class SupabaseReputationRepository implements ReputationRepository {
  @override
  Future<ReputationOverview> loadOverview() async {
    _ensureReady();
    try {
      final dynamic overviewRes =
          await SupabaseService.client.rpc('get_reputation_overview');
      final Map<String, dynamic> overview = _asMap(overviewRes);
      if (overview['success'] == false) {
        throw AppException(
          overview['error']?.toString() ?? 'İtibar verisi alınamadı.',
          code: 'REPUTATION_OVERVIEW_FAILED',
        );
      }

      final List<ReputationShopItem> shopItems = await loadShopItems();
      return ReputationOverview.merge(
        overview: ReputationOverview.fromOverviewJson(overview),
        shopItems: shopItems,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('İtibar servisi kullanılamıyor.', code: 'REPUTATION_LOAD_FAILED');
    }
  }

  @override
  Future<List<ReputationShopItem>> loadShopItems() async {
    _ensureReady();
    try {
      final dynamic shopRes = await SupabaseService.client.rpc('get_reputation_shop');
      final Map<String, dynamic> shop = _asMap(shopRes);
      if (shop['success'] == false) {
        return _fallbackShopItems();
      }
      final List<dynamic> raw = shop['items'] as List<dynamic>? ?? <dynamic>[];
      if (raw.isEmpty) return _fallbackShopItems();
      return raw
          .whereType<Map>()
          .map((Map e) => ReputationShopItem.fromJson(Map<String, dynamic>.from(e)))
          .where((ReputationShopItem item) => item.costType == 'global')
          .toList();
    } catch (_) {
      return _fallbackShopItems();
    }
  }

  @override
  Future<Map<String, dynamic>> purchaseItem({required String itemId}) async {
    _ensureReady();
    final dynamic res = await SupabaseService.client.rpc(
      'purchase_reputation_item',
      params: <String, dynamic>{'p_item_id': itemId},
    );
    return _asMap(res);
  }

  List<ReputationShopItem> _fallbackShopItems() => const <ReputationShopItem>[
        ReputationShopItem(
          id: 'energy_refill',
          name: 'Enerji Yenileme',
          description: '+20 enerji — global itibar ile.',
          iconKey: 'bolt',
          costType: 'global',
          costAmount: 500,
          rarity: 'uncommon',
          effectKey: 'energy_refill',
          effectValue: <String, dynamic>{'energy_gain': 20},
        ),
        ReputationShopItem(
          id: 'gold_boost_30',
          name: 'Altın Avcısı',
          description: '30 dk zindan altın +%15.',
          iconKey: 'gold',
          costType: 'global',
          costAmount: 800,
          rarity: 'rare',
          effectKey: 'gold_boost',
          effectValue: <String, dynamic>{'pct': 15},
          durationMinutes: 30,
        ),
        ReputationShopItem(
          id: 'drop_boost_30',
          name: 'Ganimet Radarı',
          description: '30 dk loot +%10.',
          iconKey: 'loot',
          costType: 'global',
          costAmount: 1000,
          rarity: 'epic',
          effectKey: 'drop_boost',
          effectValue: <String, dynamic>{'pct': 10},
          durationMinutes: 30,
        ),
      ];

  void _ensureReady() {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase bağlantısı hazır değil.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}
