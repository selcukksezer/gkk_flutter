import '../core/errors/app_exception.dart';
import '../core/services/supabase_service.dart';
import '../models/market_model.dart';

abstract class MarketRepository {
  Future<List<MarketTicker>> fetchTickers();
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
}

class SupabaseMarketRepository implements MarketRepository {
  @override
  Future<List<MarketTicker>> fetchTickers() async {
    _ensureReady();

    try {
      final List<dynamic> rows = await SupabaseService.client
          .from('market_orders')
          .select('*')
          .eq('status', 'open')
          .eq('side', 'sell')
          .order('price', ascending: true);

      final Map<String, _TickerAgg> grouped = <String, _TickerAgg>{};
      for (final dynamic row in rows) {
        if (row is! Map) continue;
        final Map<String, dynamic> data = Map<String, dynamic>.from(row);
        final String itemId = (data['item_id'] ?? '').toString();
        if (itemId.isEmpty) continue;

        final String orderId = (data['order_id'] ?? data['id'] ?? '').toString();
        final String sellerId = (data['seller_id'] ?? data['player_id'] ?? '').toString();
        final String itemName = (data['item_name'] ?? 'Bilinmeyen Eşya').toString();
        final int price = (data['price'] as num?)?.toInt() ?? 0;
        final int quantity = (data['quantity'] as num?)?.toInt() ?? 0;
        final String rarity = (data['rarity'] ?? 'common').toString();
        final String itemType = (data['item_type'] ?? '').toString();
        final bool isStackable = data['is_stackable'] == true;

        final _TickerAgg agg = grouped.putIfAbsent(
          itemId,
          () => _TickerAgg(
            itemId: itemId,
            itemName: itemName,
            itemType: itemType,
            rarity: rarity,
            isStackable: isStackable,
            lowestPrice: price,
            volume: 0,
            maxAvailableQty: 0,
            cheapestOrderId: orderId,
            cheapestSellerId: sellerId,
          ),
        );

        if (price < agg.lowestPrice) {
          agg.lowestPrice = price;
          agg.cheapestOrderId = orderId;
          agg.cheapestSellerId = sellerId;
          agg.maxAvailableQty = quantity;
        } else if (price == agg.lowestPrice && orderId == agg.cheapestOrderId) {
          agg.maxAvailableQty = quantity;
        }
        agg.volume += quantity;
      }

      return grouped.values
          .map((agg) => MarketTicker(
                itemId: agg.itemId,
                itemName: agg.itemName,
                itemType: agg.itemType,
                rarity: agg.rarity,
                isStackable: agg.isStackable,
                lowestPrice: agg.lowestPrice,
                volume: agg.volume,
                priceChange: 0,
                maxAvailableQty: agg.maxAvailableQty,
                cheapestOrderId: agg.cheapestOrderId,
                cheapestSellerId: agg.cheapestSellerId,
              ))
          .toList();
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
      await SupabaseService.client.rpc(
        'market_list_item',
        params: <String, dynamic>{
          'p_item_row_id': itemRowId,
          'p_quantity': quantity,
          'p_price': price,
        },
      );
      return true;
    } catch (error) {
      throw AppException(_parseRpcError(error), code: 'MARKET_CREATE_FAILED');
    }
  }

  @override
  Future<bool> cancelOrder({required String orderId}) async {
    _ensureReady();

    try {
      await SupabaseService.client.rpc(
        'cancel_sell_order',
        params: <String, dynamic>{'p_order_id': orderId},
      );
      return true;
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
      await SupabaseService.client.rpc(
        'update_market_listing_price',
        params: <String, dynamic>{
          'p_order_id': orderId,
          'p_new_price': newPrice,
        },
      );
      return true;
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
      await SupabaseService.client.rpc(
        'purchase_market_listing',
        params: <String, dynamic>{
          'p_order_id': orderId,
          'p_quantity': quantity,
        },
      );
      return true;
    } catch (error) {
      throw AppException(_parseRpcError(error), code: 'MARKET_PURCHASE_FAILED');
    }
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
    final String raw = error.toString();
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

class _TickerAgg {
  _TickerAgg({
    required this.itemId,
    required this.itemName,
    required this.itemType,
    required this.rarity,
    required this.isStackable,
    required this.lowestPrice,
    required this.volume,
    required this.maxAvailableQty,
    required this.cheapestOrderId,
    required this.cheapestSellerId,
  });

  final String itemId;
  final String itemName;
  final String itemType;
  final String rarity;
  final bool isStackable;
  int lowestPrice;
  int volume;
  int maxAvailableQty;
  String cheapestOrderId;
  String cheapestSellerId;
}
