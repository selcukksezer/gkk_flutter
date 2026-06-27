import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/market_model.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../theme/app_colors.dart';
import 'market_helpers.dart';
import '../../../models/inventory_model.dart';
import 'market_item_icon.dart';
import 'market_listing_card.dart';
import 'market_price_edit_sheet.dart';
import '../../../l10n/l10n.dart';

class MarketMyMarketTab extends ConsumerWidget {
  const MarketMyMarketTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<MarketOrder> orders = ref.watch(marketProvider).myOrders;
    final List<InventoryItem> inventoryItems = ref.watch(inventoryProvider).items;

    if (orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('Acik ilan yok', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: orders.map((MarketOrder order) {
        final InventoryItem? refItem = _findRef(inventoryItems, order.itemId);
        return MarketListingCard(
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
              _miniAction(
                label: context.l10n.fiyat,
                color: AppColors.accentBlue,
                onTap: () => _editPrice(context, ref, order),
              ),
              const SizedBox(width: 4),
              _miniAction(
                label: 'Cek',
                color: AppColors.danger,
                onTap: () => _withdraw(context, ref, order),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  InventoryItem? _findRef(List<InventoryItem> items, String itemId) {
    for (final InventoryItem item in items) {
      if (item.itemId == itemId) return item;
    }
    return null;
  }

  Widget _miniAction({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.45)),
          color: color.withValues(alpha: 0.12),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ),
    );
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
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Geri cek?', style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        content: Text(
          '${order.itemName} envantere doner.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgec')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
