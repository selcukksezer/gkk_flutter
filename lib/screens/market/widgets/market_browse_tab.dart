import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/inventory_model.dart';
import '../../../models/market_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../theme/app_colors.dart';
import 'market_helpers.dart';
import 'market_item_icon.dart';
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

    final List<MarketTicker> filtered = marketState.tickers.where((MarketTicker ticker) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _compactFilters(),
        const SizedBox(height: 8),
        if (marketState.status == MarketStatus.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentBlue),
              ),
            ),
          )
        else if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Sonuc yok', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
          )
        else
          ...filtered.map((MarketTicker ticker) {
            final bool ownListing = currentUserId != null &&
                ticker.cheapestSellerId != null &&
                ticker.cheapestSellerId == currentUserId;
            final InventoryItem? refItem = _findInventoryRef(inventoryItems, ticker.itemId);

            return MarketListingCard(
              itemName: ticker.itemName,
              rarity: ticker.rarity,
              itemId: ticker.itemId,
              iconValue: refItem?.icon ?? '',
              itemType: refItem?.itemType ?? marketItemTypeFromString(ticker.itemType),
              quantity: ticker.isStackable ? ticker.volume : 1,
              showQuantity: ticker.isStackable && ticker.volume > 1,
              metaLine: '${marketRarityLabel(ticker.rarity)} • ${ticker.volume} stok',
              priceText: '${formatMarketGold(ticker.lowestPrice)} / adet',
              badge: ownListing ? 'Senin' : null,
              onTap: ticker.cheapestOrderId == null || ownListing
                  ? null
                  : () => _openBuySheet(context, ticker: ticker, gold: gold),
              trailing: SizedBox(
                height: 30,
                child: FilledButton(
                  onPressed: ticker.cheapestOrderId == null || ownListing
                      ? null
                      : () => _openBuySheet(context, ticker: ticker, gold: gold),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Al', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            );
          }),
      ],
    );
  }

  InventoryItem? _findInventoryRef(List<InventoryItem> items, String itemId) {
    for (final InventoryItem item in items) {
      if (item.itemId == itemId) return item;
    }
    return null;
  }

  Widget _compactFilters() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: <Widget>[
          TextField(
            onChanged: (String value) => setState(() => _search = value),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Ara...',
              hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textTertiary),
              prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              filled: true,
              fillColor: AppColors.bgDeep,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(child: _miniDropdown(_categoryFilter, marketCategoryFilters, (v) => _categoryFilter = v)),
              const SizedBox(width: 6),
              Expanded(child: _miniDropdown(_rarityFilter, marketRarityFilters, (v) => _rarityFilter = v)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              _sortChip('Ucuz', MarketPriceSort.lowToHigh),
              const SizedBox(width: 6),
              _sortChip('Pahali', MarketPriceSort.highToLow),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortChip(String label, MarketPriceSort sort) {
    final bool selected = _priceSort == sort;
    return GestureDetector(
      onTap: () => setState(() => _priceSort = sort),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentBlueDim : AppColors.bgDeep,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.accentBlue : AppColors.borderDefault,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _miniDropdown(
    String value,
    List<MarketFilterOption> options,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: AppColors.bgCard,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
          items: options
              .map(
                (MarketFilterOption o) => DropdownMenuItem<String>(
                  value: o.key,
                  child: Text(o.label, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (String? next) => setState(() => onChanged(next ?? '')),
        ),
      ),
    );
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
