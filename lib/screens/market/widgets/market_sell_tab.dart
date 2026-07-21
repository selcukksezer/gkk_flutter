import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/inventory_model.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/market_provider.dart';
import 'market_design.dart';
import 'market_helpers.dart';
import 'market_listing_card.dart';
import 'market_quantity_sheet.dart';

class MarketSellTab extends ConsumerWidget {
  const MarketSellTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<InventoryItem> tradeableItems = ref
        .watch(inventoryProvider)
        .items
        .where((InventoryItem item) => item.isTradeable && !item.isEquipped)
        .toList();

    if (tradeableItems.isEmpty) {
      return const MarketEmptyState(
        message: 'Satilabilir esya yok',
        icon: Icons.block_rounded,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const MarketSectionHeader(
          title: 'SATILACAK ESYALAR',
          subtitle: 'Envanterinden ilana koy',
        ),
        ...List<Widget>.generate(tradeableItems.length, (int index) {
          final InventoryItem item = tradeableItems[index];
          final bool locked = item.isMarketTradeable == false || item.isHanOnly == true;
          return MarketListingCard(
            index: index,
            itemName: item.name,
            rarity: item.rarity.name,
            itemId: item.itemId,
            iconValue: item.icon,
            itemType: item.itemType,
            quantity: item.quantity,
            showQuantity: item.isStackable && item.quantity > 1,
            metaLine: locked ? 'Pazarda satilamaz' : marketRarityLabel(item.rarity.name),
            priceText: locked ? '—' : 'Listele',
            onTap: locked ? null : () => _openSellSheet(context, ref, item),
            trailing: MarketPrimaryButton(
              label: 'Sat',
              icon: Icons.sell_rounded,
              compact: true,
              onPressed: locked ? null : () => _openSellSheet(context, ref, item),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _openSellSheet(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
  ) async {
    final int initialPrice = item.basePrice > 0 ? item.basePrice : 100;

    final MarketQuantityResult? result = await MarketQuantitySheet.show(
      context,
      title: item.name,
      subtitle: item.isStackable ? '${item.quantity} adet' : 'Tekil',
      unitPrice: initialPrice,
      maxQuantity: item.quantity,
      isStackable: item.isStackable,
      mode: MarketQuantityMode.sell,
      confirmLabel: 'Ilana Koy',
      allowPriceEdit: true,
    );

    if (result == null || !context.mounted) return;

    final bool ok = await ref.read(marketProvider.notifier).createOrder(
          itemRowId: item.rowId,
          quantity: result.quantity,
          price: result.unitPrice,
        );

    if (!context.mounted) return;
    showMarketSnackBar(
      context,
      ok ? 'Ilan olusturuldu' : (ref.read(marketProvider).errorMessage ?? 'Basarisiz'),
      isError: !ok,
    );
  }
}
