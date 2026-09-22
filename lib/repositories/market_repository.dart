import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors/app_exception.dart';
import '../core/services/supabase_service.dart';
import '../models/market_model.dart';

abstract class MarketRepository {
  Future<MarketTickersPage> fetchTickersPage({
    required int limit,
    required int offset,
    MarketTickerQuery query = const MarketTickerQuery(),
  });
  Future<List<MarketOrder>> fetchMyOrders({required String sellerId});
  Future<List<MarketListing>> fetchListingsForItem(String itemId);
  Future<bool> createOrder({
    required String itemRowId,
    required int quantity,
    required int price,
  });
  Future<bool> cancelOrder({required String orderId});
  Future<bool> updateListingPrice({
    required String orderId,
    required int newPrice,
  });
  Future<bool> purchaseListing({
    required String orderId,
    required int quantity,
  });
  Future<List<MarketTradeRecord>> fetchMyHistory({
    int limit = 30,
    int offset = 0,
  });
}

class SupabaseMarketRepository implements MarketRepository {
  static const int defaultPageSize = 48;

  @override
  Future<MarketTickersPage> fetchTickersPage({
    required int limit,
    required int offset,
    MarketTickerQuery query = const MarketTickerQuery(),
  }) async {
    _ensureReady();

    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'get_market_tickers',
        params: <String, dynamic>{
          'p_limit': limit,
          'p_offset': offset,
          'p_search': query.search.isEmpty ? null : query.search,
          'p_item_type': query.itemType.isEmpty ? null : query.itemType,
          'p_rarity': query.rarity.isEmpty ? null : query.rarity,
          'p_sort': query.sortKey,
        },
      );

      final Map<String, dynamic> data = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);

      final List<dynamic> rows = data['items'] as List<dynamic>? ?? const <dynamic>[];
      final List<MarketTicker> items = rows
          .whereType<Map>()
          .map((Map row) => MarketTicker.fromRpcJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);

      return MarketTickersPage(
        items: items,
        total: (data['total'] as num?)?.toInt() ?? items.length,
        totalListings: (data['total_listings'] as num?)?.toInt() ?? items.length,
      );
    } catch (_) {
      throw AppException('Pazar verisi yuklenemedi.', code: 'MARKET_TICKERS_FAILED');
    }
  }

  @override
  Future<List<MarketListing>> fetchListingsForItem(String itemId) async {
    _ensureReady();

    try {
      final List<dynamic> rows = await SupabaseService.client
          .from('market_orders')
          .select('*')
          .eq('status', 'open')
          .eq('side', 'sell')
          .eq('item_id', itemId)
          .order('price', ascending: true);

      return rows.whereType<Map>().map((row) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(row);
        return MarketListing(
          orderId: (data['order_id'] ?? data['id'] ?? '').toString(),
          sellerId: (data['seller_id'] ?? data['player_id'] ?? '').toString(),
          itemId: (data['item_id'] ?? '').toString(),
          itemName: (data['item_name'] ?? 'Bilinmeyen Eşya').toString(),
          quantity: (data['quantity'] as num?)?.toInt() ?? 0,
          unitPrice: (data['price'] as num?)?.toInt() ?? 0,
          isStackable: data['is_stackable'] == true,
          maxStack: (data['max_stack'] as num?)?.toInt() ?? 1,
          rarity: (data['rarity'] ?? 'common').toString(),
          itemType: (data['item_type'] ?? '').toString(),
          enhancementLevel: (data['enhancement_level'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (_) {
      throw AppException('Ilanlar yuklenemedi.', code: 'MARKET_LISTINGS_FAILED');
    }
  }

  @override
  Future<List<MarketOrder>> fetchMyOrders({required String sellerId}) async {
    _ensureReady();

    try {
      final List<dynamic> rows = await SupabaseService.client
          .from('market_orders')
          .select('*')
          .eq('status', 'open')
          .eq('side', 'sell')
          .or('seller_id.eq.$sellerId,player_id.eq.$sellerId')
          .order('created_at', ascending: false);

      return rows
          .whereType<Map>()
          .map((row) => MarketOrder.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      throw AppException('Ilanlar yuklenemedi.', code: 'MARKET_ORDERS_FAILED');
    }
  }

  @override
  Future<bool> createOrder({
    required String itemRowId,
    required int quantity,
    required int price,
  }) async {
    _ensureReady();

    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'market_list_item',
        params: <String, dynamic>{
          'p_item_row_id': itemRowId,
          'p_quantity': quantity,
          'p_price': price,
        },
      );
      _ensureRpcSuccess(raw);
      return true;
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(_parseRpcError(error), code: 'MARKET_CREATE_FAILED');
    }
  }

  @override
  Future<bool> cancelOrder({required String orderId}) async {
    _ensureReady();

    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'cancel_sell_order',
        params: <String, dynamic>{'p_order_id': orderId},
      );
      _ensureRpcSuccess(raw);
      return true;
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(_parseRpcError(error), code: 'MARKET_CANCEL_FAILED');
    }
  }

  @override
  Future<bool> updateListingPrice({
    required String orderId,
    required int newPrice,
  }) async {
    _ensureReady();

    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'update_market_listing_price',
        params: <String, dynamic>{
          'p_order_id': orderId,
          'p_new_price': newPrice,
        },
      );
      _ensureRpcSuccess(raw);
      return true;
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(_parseRpcError(error), code: 'MARKET_UPDATE_PRICE_FAILED');
    }
  }

  @override
  Future<bool> purchaseListing({
    required String orderId,
    required int quantity,
  }) async {
    _ensureReady();

    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'purchase_market_listing',
        params: <String, dynamic>{
          'p_order_id': orderId,
          'p_quantity': quantity,
        },
      );
      _ensureRpcSuccess(raw);
      return true;
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(_parseRpcError(error), code: 'MARKET_PURCHASE_FAILED');
    }
  }

  @override
  Future<List<MarketTradeRecord>> fetchMyHistory({
    int limit = 30,
    int offset = 0,
  }) async {
    _ensureReady();

    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'get_my_market_history',
        params: <String, dynamic>{'p_limit': limit, 'p_offset': offset},
      );
      if (raw is! Map || raw['success'] != true) return const <MarketTradeRecord>[];
      final List<dynamic> rows = raw['items'] as List<dynamic>? ?? const <dynamic>[];
      return rows
          .whereType<Map>()
          .map((Map row) =>
              MarketTradeRecord.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (_) {
      throw AppException('Islem gecmisi yuklenemedi.', code: 'MARKET_HISTORY_FAILED');
    }
  }

  void _ensureRpcSuccess(dynamic raw) {
    if (raw is! Map) return;

    final Map<String, dynamic> body = Map<String, dynamic>.from(raw);
    if (body['success'] != false) return;

    throw AppException(
      body['error']?.toString() ?? 'Islem basarisiz',
      code: 'MARKET_PURCHASE_FAILED',
    );
  }

  void _ensureReady() {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }
  }

  String _parseRpcError(Object error) {
    if (error is PostgrestException) {
      final String code = error.code ?? '';
      final String message = error.message;
      final String details = error.details?.toString() ?? '';
      final String combined = '$message $details';

      if (code == 'PGRST203' ||
          message.contains('Multiple Choices') ||
          combined.contains('Could not choose')) {
        return 'Pazar satin alma servisi gecici olarak kullanilamiyor';
      }
      if (combined.contains('captcha_required')) return 'captcha_required';
      if (combined.contains('Giris yapmalisiniz')) return 'Giris yapmalisiniz';
      if (combined.contains('Yeterli altin yok')) return 'Yeterli altin yok';
      if (combined.contains('Yeterli elmas yok')) return 'Yeterli elmas yok';
      if (combined.contains('Envanter dolu')) return 'Envanter dolu veya esya eklenemiyor';
      if (combined.contains('Kendi ilaninizi')) return 'Kendi ilaninizi satin alamazsiniz';
      if (combined.contains('Ilan bulunamadi')) return 'Ilan bulunamadi veya satildi';
      if (combined.contains('pazarda satilamaz')) return 'Bu esya pazarda satilamaz';
      if (combined.contains('Kuşanili') || combined.contains('Kusanili')) {
        return 'Kuşanili esya pazara konulamaz';
      }
      if (message.trim().isNotEmpty) return message.trim();
    }

    final String raw = error.toString();
    if (raw.contains('captcha_required')) return 'captcha_required';
    if (raw.contains('Giris yapmalisiniz')) return 'Giris yapmalisiniz';
    if (raw.contains('Yeterli altin yok')) return 'Yeterli altin yok';
    if (raw.contains('Envanter dolu')) return 'Envanter dolu veya esya eklenemiyor';
    if (raw.contains('Kendi ilaninizi')) return 'Kendi ilaninizi satin alamazsiniz';
    if (raw.contains('pazarda satilamaz')) return 'Bu esya pazarda satilamaz';
    if (raw.contains('Kuşanili') || raw.contains('Kusanili')) {
      return 'Kuşanili esya pazara konulamaz';
    }
    final RegExpMatch? match = RegExp(r'(?:Exception|ERROR):\s*(.+)').firstMatch(raw);
    if (match != null) {
      return match.group(1)?.replaceAll('"', '').trim() ?? 'Islem basarisiz';
    }
    return 'Islem basarisiz';
  }
}
