import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (orders.isEmpty)
          const MarketEmptyState(
            message: 'Acik ilan yok',
            icon: Icons.store_mall_directory_outlined,
          )
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
                  MarketSecondaryButton(
                    label: context.l10n.fiyat,
                    accent: AppColors.accentCyan,
                    compact: true,
                    onPressed: () => _editPrice(context, ref, order),
                  ),
                  const SizedBox(width: 6),
                  MarketSecondaryButton(
                    label: 'Cek',
                    accent: AppColors.mysticRuby,
                    compact: true,
                    onPressed: () => _withdraw(context, ref, order),
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
          ...history.map((MarketTradeRecord trade) => _TradeHistoryRow(trade: trade)),
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
    final int? newPrice = await MarketPriceEditSheet.show(
      context,
      itemName: order.itemName,
      currentPrice: order.price,
      quantity: order.quantity,
    );

    if (newPrice == null || newPrice == order.price || !context.mounted) return;

    final bool ok = await ref.read(marketProvider.notifier).updateListingPrice(
          orderId: order.orderId,
          newPrice: newPrice,
        );

    if (!context.mounted) return;
    showMarketSnackBar(
      context,
      ok ? 'Fiyat guncellendi' : (ref.read(marketProvider).errorMessage ?? 'Basarisiz'),
      isError: !ok,
    );
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref, MarketOrder order) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.75),
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.spaceNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.mysticRuby.withValues(alpha: 0.35)),
        ),
        title: const Text('Geri cek?', style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        content: Text(
          '${order.itemName} envantere doner.',
          style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgec', style: TextStyle(color: AppColors.mutedTitanium)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.mysticRuby),
            child: const Text('Cek'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final bool ok = await ref.read(marketProvider.notifier).withdrawListing(orderId: order.orderId);

    if (!context.mounted) return;
    showMarketSnackBar(
      context,
      ok ? 'Ilan cekildi' : (ref.read(marketProvider).errorMessage ?? 'Basarisiz'),
      isError: !ok,
    );
  }
}

class _TradeHistoryRow extends StatelessWidget {
  const _TradeHistoryRow({required this.trade});

  final MarketTradeRecord trade;

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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.spaceNavy.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${sale ? 'Alici' : 'Satici'}: ${trade.counterparty} • ${_timeLabel()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedTitanium,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${sale ? '+' : '-'}${formatMarketGold(trade.netAmount)}',
            style: TextStyle(
              color: accent,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
