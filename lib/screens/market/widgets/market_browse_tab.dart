import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'gold_coin_particle_burst.dart';
import 'market_design.dart';
import 'market_helpers.dart';
import 'market_item_pedestal.dart';
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
  int _resetKey = 0;
  bool _isPurchasing = false;

  bool get _hasActiveFilters =>
      _search.isNotEmpty || _categoryFilter.isNotEmpty || _rarityFilter.isNotEmpty;

  int get _activeFilterCount {
    int count = 0;
    if (_search.isNotEmpty) count++;
    if (_categoryFilter.isNotEmpty) count++;
    if (_rarityFilter.isNotEmpty) count++;
    return count;
  }

  void _clearFilters() {
    HapticFeedback.selectionClick();
    setState(() {
      _search = '';
      _categoryFilter = '';
      _rarityFilter = '';
      _resetKey++;
    });
    _reloadTickers();
  }

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
              notification is ScrollUpdateNotification &&
              !marketState.isLoadingMore &&
              marketState.hasMoreTickers) {
            ref.read(marketProvider.notifier).loadMoreTickers();
          }
          return false;
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MarketGlassCard(
              borderColor: AppColors.accentCyan.withValues(alpha: 0.32),
              glowColor: AppColors.accentCyan.withValues(alpha: 0.10),
              borderRadius: 16,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentCyan.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          size: 13,
                          color: AppColors.accentCyan,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'FİLTRE VE ARAMA',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Spacer(),
                      if (_hasActiveFilters) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppColors.liquidGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.liquidGold.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            '$_activeFilterCount aktif',
                            style: const TextStyle(
                              color: AppColors.liquidGold,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        MarketPressable(
                          onTap: _clearFilters,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.coralFlare.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.coralFlare.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const <Widget>[
                                Icon(
                                  Icons.close_rounded,
                                  size: 11,
                                  color: AppColors.coralFlare,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Sıfırla',
                                  style: TextStyle(
                                    color: AppColors.coralFlare,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  MarketSearchField(
                    key: ValueKey<int>(_resetKey),
                    onChanged: (String value) {
                      TutorialTriggers.onAnchorTap(
                        ref,
                        TutorialAnchorId.marketBrowseTab,
                      );
                      _onSearchChanged(value);
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'KATEGORİ',
                    style: TextStyle(
                      color: AppColors.mutedTitanium,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MarketPillStrip(
                    options: marketStaticCategoryPillOptions(),
                    selectedKey: _categoryFilter,
                    accent: AppColors.accentCyan,
                    onSelected: _onCategorySelected,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'NADİRLİK',
                    style: TextStyle(
                      color: AppColors.mutedTitanium,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MarketPillStrip(
                    options: marketStaticRarityPillOptions(),
                    selectedKey: _rarityFilter,
                    accent: AppColors.coralFlare,
                    onSelected: _onRaritySelected,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Flexible(
                        child: MarketSortChips(
                          lowSelected: _priceSort == MarketPriceSort.lowToHigh,
                          onLow: () => _onSortChanged(MarketPriceSort.lowToHigh),
                          onHigh: () => _onSortChanged(MarketPriceSort.highToLow),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _priceSort == MarketPriceSort.lowToHigh
                            ? 'Fiyat: En Düşük'
                            : 'Fiyat: En Yüksek',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mutedTitanium.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  if (marketState.status == MarketStatus.loading && tickers.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: const LinearProgressIndicator(
                        minHeight: 2.5,
                        color: AppColors.accentCyan,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            MarketSectionHeader(
              title: 'PAZAR VİTRİNİ',
              subtitle:
                  '${tickers.length}/${marketState.tickerTotal} eşya türü • ${marketState.totalListings} açık ilan',
            ),
            if (marketState.status == MarketStatus.loading && tickers.isEmpty)
              const MarketLoadingSpinner()
            else if (marketState.errorMessage != null && tickers.isEmpty)
              MarketGlassCard(
                borderColor: AppColors.coralFlare.withValues(alpha: 0.35),
                glowColor: AppColors.coralFlare.withValues(alpha: 0.12),
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.coralFlare.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.coralFlare.withValues(alpha: 0.35),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.coralFlare.withValues(alpha: 0.2),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 26,
                        color: AppColors.coralFlare,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'PAZAR VERİSİ YÜKLENEMEDİ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      marketState.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.mutedTitanium,
                        fontSize: 10.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    MarketPressable(
                      onTap: _reloadTickers,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.darkObsidian,
                          border: Border.all(
                            color: AppColors.accentCyan.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const <Widget>[
                            Icon(Icons.refresh_rounded, size: 14, color: AppColors.accentCyan),
                            SizedBox(width: 6),
                            Text(
                              'Yeniden Dene',
                              style: TextStyle(
                                color: AppColors.accentCyan,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (tickers.isEmpty)
              MarketGlassCard(
                borderColor: AppColors.accentCyan.withValues(alpha: 0.25),
                glowColor: AppColors.accentCyan.withValues(alpha: 0.08),
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentCyan.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.accentCyan.withValues(alpha: 0.35),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.accentCyan.withValues(alpha: 0.2),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.search_off_rounded,
                        size: 26,
                        color: AppColors.accentCyan,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ARANAN KRİTERDE İLAN BULUNAMADI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Filtreleri sıfırlayarak vitrindeki tüm eşyalara göz atabilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.mutedTitanium,
                        fontSize: 10.5,
                        height: 1.3,
                      ),
                    ),
                    if (_hasActiveFilters) ...<Widget>[
                      const SizedBox(height: 14),
                      MarketPressable(
                        onTap: _clearFilters,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: MarketDesign.goldGradient,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.liquidGold.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const <Widget>[
                              Icon(Icons.refresh_rounded, size: 14, color: AppColors.carbonVoid),
                              SizedBox(width: 6),
                              Text(
                                'Filtreleri Sıfırla',
                                style: TextStyle(
                                  color: AppColors.carbonVoid,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else ...<Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double maxWidth = constraints.maxWidth;
                  final int crossAxisCount = maxWidth >= 840
                      ? 4
                      : maxWidth >= 540
                          ? 3
                          : 2;

                  return GameFixedGrid(
                    crossAxisCount: crossAxisCount,
                    spacing: 10,
                    itemCount: tickers.length,
                    itemBuilder: (BuildContext context, int index) {
                      final MarketTicker ticker = tickers[index];
                      final bool ownListing = currentUserId != null &&
                          ticker.cheapestSellerId != null &&
                          ticker.cheapestSellerId == currentUserId;
                      final InventoryItem? refItem =
                          _findInventoryRef(inventoryItems, ticker.itemId);
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
                        itemType: refItem?.itemType ??
                            marketItemTypeFromString(ticker.itemType),
                        quantity: ticker.isStackable ? ticker.volume : 1,
                        showQuantity: ticker.isStackable && ticker.volume > 1,
                        ownListing: ownListing,
                        canBuy: canBuy,
                        onInspect: () => _openPedestalInspect(
                          context,
                          ticker: ticker,
                          gold: gold,
                          unitPrice: displayPrice,
                          refItem: refItem,
                          canBuy: canBuy,
                        ),
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
                  );
                },
              ),
              if (marketState.isLoadingMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.carbonVoid.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.liquidGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const <Widget>[
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.liquidGold,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Daha fazla ilan getiriliyor...',
                            style: TextStyle(
                              color: AppColors.mutedTitanium,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (marketState.hasMoreTickers)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: MarketPressable(
                    onTap: () => ref.read(marketProvider.notifier).loadMoreTickers(),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: MarketDesign.obsidianGlassGradient,
                        border: Border.all(
                          color: AppColors.liquidGold.withValues(alpha: 0.4),
                          width: 1.1,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.liquidGold.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(
                            Icons.keyboard_double_arrow_down_rounded,
                            size: 16,
                            color: AppColors.liquidGold,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Daha Fazla İlan Yükle (${tickers.length}/${marketState.tickerTotal})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  void _openPedestalInspect(
    BuildContext context, {
    required MarketTicker ticker,
    required int gold,
    required int unitPrice,
    required InventoryItem? refItem,
    required bool canBuy,
  }) {
    MarketPedestalInspectionSheet.show(
      context,
      itemName: ticker.itemName,
      rarity: ticker.rarity,
      price: unitPrice,
      itemId: ticker.itemId,
      iconValue: refItem?.icon ?? '',
      itemType: refItem?.itemType ?? marketItemTypeFromString(ticker.itemType),
      stockLabel: '${marketRarityLabel(ticker.rarity)} • ${ticker.volume} stok',
      canBuy: canBuy && !_isPurchasing,
      onBuy: () => _openBuySheet(
        context,
        ticker: ticker,
        gold: gold,
        unitPrice: unitPrice,
      ),
    );
  }

  Future<void> _openBuySheet(
    BuildContext context, {
    required MarketTicker ticker,
    required int gold,
    required int unitPrice,
  }) async {
    if (_isPurchasing) return;
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
    if (_isPurchasing) return;

    setState(() => _isPurchasing = true);
    try {
      final bool ok = await ref.read(marketProvider.notifier).purchaseListing(
            orderId: ticker.cheapestOrderId!,
            itemId: ticker.itemId,
            quantity: result.quantity,
            unitPrice: result.unitPrice,
            sellerId: ticker.cheapestSellerId,
          );

      if (!context.mounted) return;
      if (ok) {
        HapticFeedback.selectionClick();
        GoldCoinParticleBurst.trigger(context);
      }
      showMarketSnackBar(
        context,
        ok ? 'Satin alindi' : (ref.read(marketProvider).errorMessage ?? 'Basarisiz'),
        isError: !ok,
      );
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }
}
