import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/services/supabase_service.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/player_provider.dart';
import '../models/market_model.dart';
import '../repositories/market_repository.dart';

enum MarketStatus {
  initial,
  loading,
  ready,
  error,
}

class MarketState {
  const MarketState({
    required this.status,
    required this.tickers,
    required this.myOrders,
    this.errorMessage,
    this.tickersLoaded = false,
    this.myOrdersLoaded = false,
    this.tickerQuery = const MarketTickerQuery(),
    this.tickerTotal = 0,
    this.totalListings = 0,
    this.isLoadingMore = false,
    this.myHistory = const <MarketTradeRecord>[],
    this.myHistoryLoaded = false,
  });

  final MarketStatus status;
  final List<MarketTicker> tickers;
  final List<MarketOrder> myOrders;
  final String? errorMessage;
  final bool tickersLoaded;
  final bool myOrdersLoaded;
  final MarketTickerQuery tickerQuery;
  final int tickerTotal;
  final int totalListings;
  final bool isLoadingMore;
  final List<MarketTradeRecord> myHistory;
  final bool myHistoryLoaded;

  bool get hasMoreTickers => tickers.length < tickerTotal;

  factory MarketState.initial() => const MarketState(
        status: MarketStatus.initial,
        tickers: <MarketTicker>[],
        myOrders: <MarketOrder>[],
      );

  MarketState copyWith({
    MarketStatus? status,
    List<MarketTicker>? tickers,
    List<MarketOrder>? myOrders,
    String? errorMessage,
    bool clearError = false,
    bool? tickersLoaded,
    bool? myOrdersLoaded,
    MarketTickerQuery? tickerQuery,
    int? tickerTotal,
    int? totalListings,
    bool? isLoadingMore,
    List<MarketTradeRecord>? myHistory,
    bool? myHistoryLoaded,
  }) {
    return MarketState(
      status: status ?? this.status,
      tickers: tickers ?? this.tickers,
      myOrders: myOrders ?? this.myOrders,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      tickersLoaded: tickersLoaded ?? this.tickersLoaded,
      myOrdersLoaded: myOrdersLoaded ?? this.myOrdersLoaded,
      tickerQuery: tickerQuery ?? this.tickerQuery,
      tickerTotal: tickerTotal ?? this.tickerTotal,
      totalListings: totalListings ?? this.totalListings,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      myHistory: myHistory ?? this.myHistory,
      myHistoryLoaded: myHistoryLoaded ?? this.myHistoryLoaded,
    );
  }
}

final Provider<MarketRepository> marketRepositoryProvider = Provider<MarketRepository>((Ref ref) {
  return SupabaseMarketRepository();
});

class MarketNotifier extends Notifier<MarketState> {
  MarketRepository get _repository => ref.read(marketRepositoryProvider);

  String? get _currentUserId {
    final authUser = ref.read(authProvider).user;
    if (authUser != null && authUser.id.isNotEmpty) {
      return authUser.id;
    }
    if (SupabaseService.isInitialized) {
      return SupabaseService.client.auth.currentUser?.id;
    }
    return null;
  }

  @override
  MarketState build() => MarketState.initial();

  Future<void> _refreshAll() async {
    await Future.wait(<Future<void>>[
      loadTickers(force: true),
      loadMyOrders(force: true),
      loadMyHistory(force: true),
      ref.read(inventoryProvider.notifier).loadInventory(silent: true),
      ref.read(playerProvider.notifier).loadProfile(),
    ]);
  }

  Future<void> loadTickers({
    bool force = false,
    MarketTickerQuery? query,
  }) async {
    final MarketTickerQuery nextQuery = query ?? state.tickerQuery;
    final bool sameQuery = nextQuery == state.tickerQuery;
    if (!force && state.tickersLoaded && sameQuery) return;

    state = state.copyWith(
      status: MarketStatus.loading,
      clearError: true,
      tickerQuery: nextQuery,
      tickers: sameQuery && !force ? state.tickers : <MarketTicker>[],
      isLoadingMore: false,
    );
    try {
      final MarketTickersPage page = await _repository.fetchTickersPage(
        limit: SupabaseMarketRepository.defaultPageSize,
        offset: 0,
        query: nextQuery,
      );
      state = state.copyWith(
        status: MarketStatus.ready,
        tickers: page.items,
        tickersLoaded: true,
        tickerTotal: page.total,
        totalListings: page.totalListings,
      );
    } on AppException catch (e) {
      state = state.copyWith(status: MarketStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(status: MarketStatus.error, errorMessage: 'Pazar verisi yuklenemedi.');
    }
  }

  Future<void> loadMoreTickers() async {
    if (state.isLoadingMore || !state.hasMoreTickers) return;
    if (state.status == MarketStatus.loading) return;

    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final MarketTickersPage page = await _repository.fetchTickersPage(
        limit: SupabaseMarketRepository.defaultPageSize,
        offset: state.tickers.length,
        query: state.tickerQuery,
      );
      state = state.copyWith(
        status: MarketStatus.ready,
        tickers: <MarketTicker>[...state.tickers, ...page.items],
        tickersLoaded: true,
        tickerTotal: page.total,
        totalListings: page.totalListings,
        isLoadingMore: false,
      );
    } on AppException catch (e) {
      state = state.copyWith(isLoadingMore: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: 'Daha fazla ilan yuklenemedi.',
      );
    }
  }

  Future<void> loadMyOrders({bool force = false}) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      state = state.copyWith(myOrders: <MarketOrder>[], myOrdersLoaded: true);
      return;
    }

    if (!force && state.myOrdersLoaded) return;

    state = state.copyWith(clearError: true);
    try {
      final List<MarketOrder> orders = await _repository.fetchMyOrders(sellerId: userId);
      state = state.copyWith(
        status: MarketStatus.ready,
        myOrders: orders,
        myOrdersLoaded: true,
      );
    } on AppException catch (e) {
      state = state.copyWith(status: MarketStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(status: MarketStatus.error, errorMessage: 'Ilanlar yuklenemedi.');
    }
  }

  Future<void> loadMyHistory({bool force = false}) async {
    if (!force && state.myHistoryLoaded) return;
    try {
      final List<MarketTradeRecord> history = await _repository.fetchMyHistory();
      state = state.copyWith(myHistory: history, myHistoryLoaded: true);
    } on AppException {
      state = state.copyWith(myHistoryLoaded: true);
    } catch (_) {
      state = state.copyWith(myHistoryLoaded: true);
    }
  }

  Future<List<MarketListing>> fetchListingsForItem(String itemId) {
    return _repository.fetchListingsForItem(itemId);
  }

  Future<bool> createOrder({
    required String itemRowId,
    required int quantity,
    required int price,
  }) async {
    try {
      final bool ok = await _repository.createOrder(
        itemRowId: itemRowId,
        quantity: quantity,
        price: price,
      );
      if (ok) {
        await _refreshAll();
      }
      return ok;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Satis ilani olusturulamadi.');
      return false;
    }
  }

  Future<bool> cancelOrder({required String orderId}) async {
    return withdrawListing(orderId: orderId);
  }

  Future<bool> withdrawListing({required String orderId}) async {
    try {
      final bool ok = await _repository.cancelOrder(orderId: orderId);
      if (ok) {
        await _refreshAll();
      }
      return ok;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Ilan geri cekilemedi.');
      return false;
    }
  }

  Future<bool> updateListingPrice({
    required String orderId,
    required int newPrice,
  }) async {
    try {
      final bool ok = await _repository.updateListingPrice(
        orderId: orderId,
        newPrice: newPrice,
      );
      if (ok) {
        await _refreshAll();
      }
      return ok;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Fiyat guncellenemedi.');
      return false;
    }
  }

  Future<bool> purchaseListing({
    required String orderId,
    required String itemId,
    required int quantity,
    required int unitPrice,
    String? sellerId,
  }) async {
    final String? userId = _currentUserId;
    if (userId != null && sellerId != null && userId == sellerId) {
      state = state.copyWith(errorMessage: 'Kendi ilaninizi satin alamazsiniz');
      return false;
    }

    try {
      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      final InventoryAddCheck addCheck = ref.read(inventoryProvider.notifier).canAddItem(
            itemId: itemId,
            quantity: quantity,
          );
      if (!addCheck.canAdd) {
        state = state.copyWith(errorMessage: addCheck.reason ?? 'Envanter dolu!');
        return false;
      }

      final int gold = ref.read(playerProvider).profile?.gold ?? 0;
      if (gold < unitPrice * quantity) {
        state = state.copyWith(errorMessage: 'Yeterli altin yok');
        return false;
      }

      final bool ok = await _repository.purchaseListing(
        orderId: orderId,
        quantity: quantity,
      );
      if (ok) {
        await _refreshAll();
      }
      return ok;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Satin alma basarisiz.');
      return false;
    }
  }
}

final NotifierProvider<MarketNotifier, MarketState> marketProvider =
    NotifierProvider<MarketNotifier, MarketState>(MarketNotifier.new);
