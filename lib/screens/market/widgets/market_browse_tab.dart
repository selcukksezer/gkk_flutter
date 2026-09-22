import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../theme/app_colors.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../core/tutorial/tutorial_triggers.dart';
import '../../../models/inventory_model.dart';
import '../../../models/market_model.dart';
import '../../../models/kingdom_market_blessing_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/kingdom_market_blessing_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/player_provider.dart';
import 'market_design.dart';
import 'market_helpers.dart';
import 'market_listing_card.dart';
import 'market_quantity_sheet.dart';

class MarketBrowseTab extends ConsumerStatefulWidget {
  const MarketBrowseTab({super.key});

  @override
  ConsumerState<MarketBrowseTab> createState() => _MarketBrowseTabState();
}

class _MarketBrowseTabState extends ConsumerState<MarketBrowseTab> {
  String _search = '';
  String _categoryFilter = '';
  String _rarityFilter = '';
  MarketPriceSort _priceSort = MarketPriceSort.lowToHigh;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  MarketTickerQuery _buildQuery() {
    return MarketTickerQuery(
      search: _search.trim(),
      itemType: _categoryFilter,
      rarity: _rarityFilter,
      sortKey: _priceSort == MarketPriceSort.highToLow ? 'price_desc' : 'price_asc',
    );
  }

  void _reloadTickers() {
    ref.read(marketProvider.notifier).loadTickers(
          force: true,
          query: _buildQuery(),
        );
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _reloadTickers);
  }

  void _onCategorySelected(String key) {
    setState(() => _categoryFilter = key);
    _reloadTickers();
  }

  void _onRaritySelected(String key) {
    setState(() => _rarityFilter = key);
    _reloadTickers();
  }

  void _onSortChanged(MarketPriceSort sort) {
    setState(() => _priceSort = sort);
    _reloadTickers();
  }

  @override
  Widget build(BuildContext context) {
    final marketState = ref.watch(marketProvider);
    final KingdomMarketBlessingStatus blessing = ref.watch(kingdomMarketBlessingProvider);
    final int gold = ref.watch(playerProvider).profile?.gold ?? 0;
    final String? currentUserId = ref.watch(authProvider).user?.id;
    final List<InventoryItem> inventoryItems = ref.watch(inventoryProvider).items;
    final List<MarketTicker> tickers = marketState.tickers;

    return TutorialAnchorScope(
      id: TutorialAnchorId.marketBrowseTab,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 280 &&
              notification is ScrollUpdateNotification) {
            ref.read(marketProvider.notifier).loadMoreTickers();
          }
          return false;
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MarketFilterPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  MarketSearchField(
                    onChanged: (String value) {
                      TutorialTriggers.onAnchorTap(
                        ref,
                        TutorialAnchorId.marketBrowseTab,
                      );
                      _onSearchChanged(value);
                    },
                  ),
                  const SizedBox(height: 10),
                  MarketPillStrip(
                    options: marketStaticCategoryPillOptions(),
                    selectedKey: _categoryFilter,
                    accent: AppColors.accentCyan,
                    onSelected: _onCategorySelected,
                  ),
                  const SizedBox(height: 8),
                  MarketPillStrip(
                    options: marketStaticRarityPillOptions(),
                    selectedKey: _rarityFilter,
                    accent: AppColors.coralFlare,
                    onSelected: _onRaritySelected,
                  ),
                  const SizedBox(height: 10),
                  MarketSortChips(
                    lowSelected: _priceSort == MarketPriceSort.lowToHigh,
                    onLow: () => _onSortChanged(MarketPriceSort.lowToHigh),
                    onHigh: () => _onSortChanged(MarketPriceSort.highToLow),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            MarketSectionHeader(
              title: 'PAZAR VITRINI',
              subtitle:
                  '${tickers.length}/${marketState.tickerTotal} esya turu • ${marketState.totalListings} acik ilan',
            ),
            if (marketState.status == MarketStatus.loading && tickers.isEmpty)
              const MarketLoadingSpinner()
            else if (marketState.errorMessage != null && tickers.isEmpty)
              MarketEmptyState(
                message: marketState.errorMessage!,
                icon: Icons.error_outline_rounded,
              )
            else if (tickers.isEmpty)
              const MarketEmptyState(message: 'Sonuc yok', icon: Icons.search_off_rounded)
            else ...<Widget>[
              GameFixedGrid(
                crossAxisCount: 2,
                spacing: 10,
                itemCount: tickers.length,
                itemBuilder: (BuildContext context, int index) {
                  final MarketTicker ticker = tickers[index];
                  final bool ownListing = currentUserId != null &&
                      ticker.cheapestSellerId != null &&
                      ticker.cheapestSellerId == currentUserId;
                  final InventoryItem? refItem = _findInventoryRef(inventoryItems, ticker.itemId);
                  final bool canBuy =
                      ticker.cheapestOrderId != null && !ownListing;
                  final int basePrice = ticker.lowestPrice;
                  final int displayPrice = blessing.applyDiscount(basePrice, 'gold');

                  return MarketBrowseGridCard(
                    index: index,
                    itemName: ticker.itemName,
                    rarity: ticker.rarity,
                    price: displayPrice,
                    priceChangeBps: ticker.priceChange,
                    stockLabel:
                        '${marketRarityLabel(ticker.rarity)} • ${ticker.volume} stok',
                    itemId: ticker.itemId,
                    iconValue: refItem?.icon ?? '',
                    itemType: refItem?.itemType ?? marketItemTypeFromString(ticker.itemType),
                    quantity: ticker.isStackable ? ticker.volume : 1,
                    showQuantity: ticker.isStackable && ticker.volume > 1,
                    ownListing: ownListing,
                    canBuy: canBuy,
                    onBuy: canBuy
                        ? () => _openBuySheet(
                              context,
                              ticker: ticker,
                              gold: gold,
                              unitPrice: displayPrice,
                            )
                        : null,
                  );
                },
              ),
              if (marketState.isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (marketState.hasMoreTickers)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: OutlinedButton(
                    onPressed: () => ref.read(marketProvider.notifier).loadMoreTickers(),
                    child: Text(
                      'Daha fazla yukle (${tickers.length}/${marketState.tickerTotal})',
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  InventoryItem? _findInventoryRef(List<InventoryItem> items, String itemId) {
    for (final InventoryItem item in items) {
      if (item.itemId == itemId) return item;
    }
    return null;
  }

  Future<void> _openBuySheet(
    BuildContext context, {
    required MarketTicker ticker,
    required int gold,
    required int unitPrice,
  }) async {
    if (ticker.cheapestOrderId == null || ticker.maxAvailableQty <= 0) return;

    final MarketQuantityResult? result = await MarketQuantitySheet.show(
      context,
      title: ticker.itemName,
      subtitle: '${marketRarityLabel(ticker.rarity)} • Stok: ${ticker.maxAvailableQty}',
      unitPrice: unitPrice,
      maxQuantity: ticker.maxAvailableQty.clamp(1, 9999),
      isStackable: ticker.isStackable,
      mode: MarketQuantityMode.buy,
      confirmLabel: 'Satin Al',
      playerGold: gold,
    );

    if (result == null || !context.mounted) return;

    final bool ok = await ref.read(marketProvider.notifier).purchaseListing(
          orderId: ticker.cheapestOrderId!,
          itemId: ticker.itemId,
          quantity: result.quantity,
          unitPrice: result.unitPrice,
          sellerId: ticker.cheapestSellerId,
        );

    if (!context.mounted) return;
    showMarketSnackBar(
      context,
      ok ? 'Satin alindi' : (ref.read(marketProvider).errorMessage ?? 'Basarisiz'),
      isError: !ok,
    );
  }
}
