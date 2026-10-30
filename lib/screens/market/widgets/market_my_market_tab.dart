import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../l10n/l10n.dart';
import '../../../models/inventory_model.dart';
import '../../../models/market_model.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../theme/app_colors.dart';
import 'market_design.dart';
import 'market_helpers.dart';
import 'market_listing_card.dart';
import 'market_price_edit_sheet.dart';

class MarketMyMarketTab extends ConsumerStatefulWidget {
  const MarketMyMarketTab({super.key});

  @override
  ConsumerState<MarketMyMarketTab> createState() => _MarketMyMarketTabState();
}

class _MarketMyMarketTabState extends ConsumerState<MarketMyMarketTab> {
  final Set<String> _pendingOrders = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(marketProvider.notifier).loadMyHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final MarketState market = ref.watch(marketProvider);
    final List<MarketOrder> orders = market.myOrders;
    final List<MarketTradeRecord> history = market.myHistory;
    final List<InventoryItem> inventoryItems = ref.watch(inventoryProvider).items;

    if (!market.myOrdersLoaded && market.status == MarketStatus.loading) {
      return const MarketLoadingSpinner();
    }

    final int totalSellerReceives = orders.fold<int>(
      0,
      (int sum, MarketOrder o) => sum + o.sellerReceives,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _MyMarketOverviewCard(
          activeOrdersCount: orders.length,
          totalExpectedGold: totalSellerReceives,
          historyCount: history.length,
        ),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          const _EmptyOrdersView()
        else ...<Widget>[
          MarketSectionHeader(
            title: 'ILANLARIM',
            subtitle: '${orders.length} acik ilan • %5 vergi',
          ),
          ...List<Widget>.generate(orders.length, (int index) {
            final MarketOrder order = orders[index];
            final InventoryItem? refItem = _findRef(inventoryItems, order.itemId);
            return MarketListingCard(
              index: index,
              itemName: order.itemName,
              rarity: order.rarity,
              itemId: order.itemId,
              iconValue: refItem?.icon ?? '',
              itemType: refItem?.itemType ?? marketItemTypeFromString(order.itemType),
              quantity: order.quantity,
              showQuantity: order.isStackable && order.quantity > 1,
              metaLine: 'Net ${formatMarketGold(order.sellerReceives)} • ${order.quantity} adet',
              priceText: '${formatMarketGold(order.price)} / adet',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _CompactActionButton(
                    label: _pendingOrders.contains(order.orderId) ? '...' : context.l10n.fiyat,
                    icon: Icons.edit_note_rounded,
                    accent: AppColors.accentCyan,
                    onTap: _pendingOrders.contains(order.orderId) ? null : () => _editPrice(context, ref, order),
                  ),
                  const SizedBox(width: 6),
                  _CompactActionButton(
                    label: _pendingOrders.contains(order.orderId) ? '...' : 'Cek',
                    icon: Icons.undo_rounded,
                    accent: AppColors.mysticRuby,
                    onTap: _pendingOrders.contains(order.orderId) ? null : () => _withdraw(context, ref, order),
                  ),
                ],
              ),
            );
          }),
        ],
        if (history.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          MarketSectionHeader(
            title: 'ISLEM GECMISI',
            subtitle: 'Son ${history.length} islem',
          ),
          ...history.asMap().entries.map(
                (MapEntry<int, MarketTradeRecord> entry) => _TradeHistoryRow(
                  trade: entry.value,
                  index: entry.key,
                ),
              ),
        ],
      ],
    );
  }

  InventoryItem? _findRef(List<InventoryItem> items, String itemId) {
    for (final InventoryItem item in items) {
      if (item.itemId == itemId) return item;
    }
    return null;
  }

  Future<void> _editPrice(BuildContext context, WidgetRef ref, MarketOrder order) async {
    if (_pendingOrders.contains(order.orderId)) return;

    final int? newPrice = await MarketPriceEditSheet.show(
      context,
      itemName: order.itemName,
      currentPrice: order.price,
      quantity: order.quantity,
    );

    if (newPrice == null || newPrice == order.price || !context.mounted) return;
    if (_pendingOrders.contains(order.orderId)) return;

    setState(() => _pendingOrders.add(order.orderId));
    try {
      final bool ok = await ref.read(marketProvider.notifier).updateListingPrice(
            orderId: order.orderId,
            newPrice: newPrice,
          );

      if (!context.mounted) return;
      if (ok) HapticFeedback.selectionClick();
      showMarketSnackBar(
        context,
        ok ? 'Fiyat guncellendi' : (ref.read(marketProvider).errorMessage ?? 'Basarisiz'),
        isError: !ok,
      );
    } finally {
      if (mounted) setState(() => _pendingOrders.remove(order.orderId));
    }
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref, MarketOrder order) async {
    final Color rarityColor = marketRarityColor(order.rarity);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.8),
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.mysticRuby.withValues(alpha: 0.45),
                  width: 1.2,
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xF0151C2C),
                    Color(0xF50D111A),
                    Color(0xFA080B12),
                  ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.mysticRuby.withValues(alpha: 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: DotGridPainter(spacing: 12, dotOpacity: 0.04),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.mysticRuby.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.mysticRuby.withValues(alpha: 0.5),
                                width: 1,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.mysticRuby.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.undo_rounded,
                              size: 20,
                              color: AppColors.mysticRuby,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'ILANI GERI CEK',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Pazar vitrininden kaldir',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.mutedTitanium,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.spaceNavy.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: rarityColor.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    order.itemName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: rarityColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${order.quantity} adet • Net ${formatMarketGold(order.sellerReceives)} Altin',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.mutedTitanium,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Bu ilani geri cektiginizde esya envanterinize iade edilecek ve pazardan kaldirilacaktir.',
                        style: TextStyle(
                          color: AppColors.mutedTitanium,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: MarketPressable(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.pop(ctx, false);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.darkObsidian,
                                    width: 1,
                                  ),
                                  color: AppColors.spaceNavy.withValues(alpha: 0.4),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Vazgec',
                                    style: TextStyle(
                                      color: AppColors.mutedTitanium,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MarketPressable(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.pop(ctx, true);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: const LinearGradient(
                                    colors: <Color>[
                                      AppColors.mysticRuby,
                                      Color(0xFFB01717),
                                    ],
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.mysticRuby.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(
                                      Icons.undo_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'Geri Cek',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    if (_pendingOrders.contains(order.orderId)) return;

    setState(() => _pendingOrders.add(order.orderId));
    try {
      final bool ok = await ref.read(marketProvider.notifier).withdrawListing(orderId: order.orderId);

      if (!context.mounted) return;
      if (ok) HapticFeedback.selectionClick();
      showMarketSnackBar(
        context,
        ok ? 'Ilan cekildi' : (ref.read(marketProvider).errorMessage ?? 'Basarisiz'),
        isError: !ok,
      );
    } finally {
      if (mounted) setState(() => _pendingOrders.remove(order.orderId));
    }
  }
}

class _MyMarketOverviewCard extends StatelessWidget {
  const _MyMarketOverviewCard({
    required this.activeOrdersCount,
    required this.totalExpectedGold,
    required this.historyCount,
  });

  final int activeOrdersCount;
  final int totalExpectedGold;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    return MarketGlassCard(
      borderColor: AppColors.liquidGold.withValues(alpha: 0.35),
      glowColor: AppColors.liquidGold.withValues(alpha: 0.16),
      borderRadius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.liquidGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 14,
                  color: AppColors.liquidGold,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PAZAR KASASI & AKTIF DURUM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.darkObsidian.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.25),
                  ),
                ),
                child: const Text(
                  '%5 Vergi Kesintisi',
                  style: TextStyle(
                    color: AppColors.mutedTitanium,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.spaceNavy.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.darkObsidian.withValues(alpha: 0.8),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _StatMetric(
                    label: 'Acik Ilan',
                    value: '$activeOrdersCount Adet',
                    color: AppColors.accentCyan,
                    icon: Icons.storefront_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 26,
                  color: AppColors.darkObsidian,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatMetric(
                    label: 'Beklenen Net',
                    value: '${formatMarketGold(totalExpectedGold)} G',
                    color: AppColors.liquidGold,
                    icon: Icons.monetization_on_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 26,
                  color: AppColors.darkObsidian,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatMetric(
                    label: 'Gecmis Islem',
                    value: '$historyCount Adet',
                    color: AppColors.toxicNeon,
                    icon: Icons.receipt_long_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMetric extends StatelessWidget {
  const _StatMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 11, color: color.withValues(alpha: 0.85)),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.mutedTitanium,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyOrdersView extends StatelessWidget {
  const _EmptyOrdersView();

  @override
  Widget build(BuildContext context) {
    return MarketGlassCard(
      borderColor: AppColors.darkObsidian.withValues(alpha: 0.8),
      glowColor: AppColors.accentCyan.withValues(alpha: 0.08),
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.spaceNavy.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.liquidGold.withValues(alpha: 0.3),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.12),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 26,
                color: AppColors.liquidGold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Henuz Acik Ilan Yok',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Envanterinizdeki esyalari "Esya Sat" sekmesinden listeleyerek oyuncu pazarinda altin kazanabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.mutedTitanium,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.darkObsidian.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.accentCyan.withValues(alpha: 0.25),
                ),
              ),
              child: const Text(
                '%5 Komisyon • 48 Saat Ilan Suresi',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.label,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MarketPressable(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: accent.withValues(alpha: 0.12),
          border: Border.all(
            color: accent.withValues(alpha: 0.45),
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.15),
              blurRadius: 5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: accent,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeHistoryRow extends StatelessWidget {
  const _TradeHistoryRow({
    required this.trade,
    required this.index,
  });

  final MarketTradeRecord trade;
  final int index;

  String _timeLabel() {
    final DateTime? at = trade.tradedAt;
    if (at == null) return '';
    final Duration diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'az once';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk once';
    if (diff.inHours < 24) return '${diff.inHours} sa once';
    return '${diff.inDays} gun once';
  }

  @override
  Widget build(BuildContext context) {
    final bool sale = trade.isSale;
    final Color accent = sale ? AppColors.toxicNeon : AppColors.accentCyan;

    return MarketFadeSlide(
      index: index,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accent.withValues(alpha: 0.24),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.spaceNavy.withValues(alpha: 0.8),
                    AppColors.carbonVoid.withValues(alpha: 0.9),
                  ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: DotGridPainter(spacing: 12, dotOpacity: 0.03),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.4),
                            width: 1,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: accent.withValues(alpha: 0.2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          sale ? Icons.call_made_rounded : Icons.call_received_rounded,
                          size: 16,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${trade.itemName}${trade.quantity > 1 ? ' x${trade.quantity}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    sale ? 'SATIS' : 'ALIM',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${sale ? 'Alici' : 'Satici'}: ${trade.counterparty} • ${_timeLabel()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.mutedTitanium,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '${sale ? '+' : '-'}${formatMarketGold(trade.netAmount)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.monetization_on_rounded,
                              size: 13,
                              color: AppColors.liquidGold,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

