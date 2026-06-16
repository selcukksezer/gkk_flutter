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
  });

  final MarketStatus status;
  final List<MarketTicker> tickers;
  final List<MarketOrder> myOrders;
  final String? errorMessage;

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
  }) {
    return MarketState(
      status: status ?? this.status,
      tickers: tickers ?? this.tickers,
      myOrders: myOrders ?? this.myOrders,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
      loadTickers(),
      loadMyOrders(),
      ref.read(inventoryProvider.notifier).loadInventory(silent: true),
      ref.read(playerProvider.notifier).loadProfile(),
    ]);
  }

  Future<void> loadTickers() async {
    state = state.copyWith(status: MarketStatus.loading, clearError: true);
    try {
      final List<MarketTicker> tickers = await _repository.fetchTickers();
      state = state.copyWith(status: MarketStatus.ready, tickers: tickers);
    } on AppException catch (e) {
      state = state.copyWith(status: MarketStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(status: MarketStatus.error, errorMessage: 'Pazar verisi yuklenemedi.');
    }
  }

  Future<void> loadMyOrders() async {
    final String? userId = _currentUserId;
    if (userId == null) {
      state = state.copyWith(myOrders: <MarketOrder>[]);
      return;
    }

    state = state.copyWith(clearError: true);
    try {
      final List<MarketOrder> orders = await _repository.fetchMyOrders(sellerId: userId);
      state = state.copyWith(status: MarketStatus.ready, myOrders: orders);
    } on AppException catch (e) {
      state = state.copyWith(status: MarketStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(status: MarketStatus.error, errorMessage: 'Ilanlar yuklenemedi.');
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
