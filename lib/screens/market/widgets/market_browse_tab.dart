import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../theme/app_colors.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../models/inventory_model.dart';
import '../../../models/market_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/inventory_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final marketState = ref.watch(marketProvider);
    final int gold = ref.watch(playerProvider).profile?.gold ?? 0;
    final String? currentUserId = ref.watch(authProvider).user?.id;
    final List<InventoryItem> inventoryItems = ref.watch(inventoryProvider).items;
    final List<MarketTicker> allTickers = marketState.tickers;

    final List<MarketTicker> filtered = allTickers.where((MarketTicker ticker) {
      final String q = _search.trim().toLowerCase();
      if (q.isNotEmpty) {
        if (!ticker.itemName.toLowerCase().contains(q) &&
            !ticker.itemType.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_categoryFilter.isNotEmpty && ticker.itemType != _categoryFilter) return false;
      if (_rarityFilter.isNotEmpty && ticker.rarity != _rarityFilter) return false;
      return true;
    }).toList()
      ..sort((MarketTicker a, MarketTicker b) {
        return _priceSort == MarketPriceSort.lowToHigh
            ? a.lowestPrice.compareTo(b.lowestPrice)
            : b.lowestPrice.compareTo(a.lowestPrice);
      });

    return TutorialAnchorScope(
      id: TutorialAnchorId.marketBrowseTab,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MarketFilterPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                MarketSearchField(onChanged: (String value) => setState(() => _search = value)),
                const SizedBox(height: 10),
                MarketPillStrip(
                  options: marketCategoryPillOptions(allTickers),
                  selectedKey: _categoryFilter,
                  accent: AppColors.accentCyan,
                  onSelected: (String key) => setState(() => _categoryFilter = key),
                ),
                const SizedBox(height: 8),
                MarketPillStrip(
                  options: marketRarityPillOptions(allTickers),
                  selectedKey: _rarityFilter,
                  accent: AppColors.coralFlare,
                  onSelected: (String key) => setState(() => _rarityFilter = key),
                ),
                const SizedBox(height: 10),
                MarketSortChips(
                  lowSelected: _priceSort == MarketPriceSort.lowToHigh,
                  onLow: () => setState(() => _priceSort = MarketPriceSort.lowToHigh),
                  onHigh: () => setState(() => _priceSort = MarketPriceSort.highToLow),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          MarketSectionHeader(
            title: 'PAZAR VITRINI',
            subtitle: '${filtered.length} esya • ${allTickers.length} toplam ilan',
          ),
          if (marketState.status == MarketStatus.loading)
            const MarketLoadingSpinner()
          else if (filtered.isEmpty)
            const MarketEmptyState(message: 'Sonuc yok', icon: Icons.search_off_rounded)
          else
            GameFixedGrid(
              crossAxisCount: 2,
              spacing: 10,
              itemCount: filtered.length,
              itemBuilder: (BuildContext context, int index) {
                final MarketTicker ticker = filtered[index];
                final bool ownListing = currentUserId != null &&
                    ticker.cheapestSellerId != null &&
                    ticker.cheapestSellerId == currentUserId;
                final InventoryItem? refItem = _findInventoryRef(inventoryItems, ticker.itemId);
                final bool canBuy =
                    ticker.cheapestOrderId != null && !ownListing;

                return MarketBrowseGridCard(
                  index: index,
                  itemName: ticker.itemName,
                  rarity: ticker.rarity,
                  price: ticker.lowestPrice,
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
                      ? () => _openBuySheet(context, ticker: ticker, gold: gold)
                      : null,
                );
              },
            ),
        ],
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
  }) async {
    final MarketQuantityResult? result = await MarketQuantitySheet.show(
      context,
      title: ticker.itemName,
      subtitle: '${marketRarityLabel(ticker.rarity)} • Stok: ${ticker.maxAvailableQty}',
      unitPrice: ticker.lowestPrice,
      maxQuantity: ticker.maxAvailableQty.clamp(1, ticker.volume),
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
