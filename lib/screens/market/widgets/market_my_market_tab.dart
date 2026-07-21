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

class MarketMyMarketTab extends ConsumerWidget {
  const MarketMyMarketTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<MarketOrder> orders = ref.watch(marketProvider).myOrders;
    final List<InventoryItem> inventoryItems = ref.watch(inventoryProvider).items;

    if (orders.isEmpty) {
      return const MarketEmptyState(
        message: 'Acik ilan yok',
        icon: Icons.store_mall_directory_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
