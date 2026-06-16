import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../models/item_model.dart';
import 'market_helpers.dart';

/// Inventory-matched item icon cell (grid tile proportions).
class MarketItemIcon extends StatelessWidget {
  const MarketItemIcon({
    super.key,
    required this.rarity,
    this.iconValue = '',
    this.itemId,
    this.itemType,
    this.quantity,
    this.showQuantity = true,
    this.size = 56,
  });

  final String rarity;
  final String iconValue;
  final String? itemId;
  final ItemType? itemType;
  final int? quantity;
  final bool showQuantity;
  final double size;

  static const double _iconInnerSize = 42;

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = marketRarityColor(rarity);
    final bool showQty = showQuantity && quantity != null && quantity! > 1;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rarityColor.withValues(alpha: 0.55), width: 1.2),
          color: const Color(0xFF0D1424),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: rarityColor.withValues(alpha: 0.1),
              blurRadius: 6,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: <Color>[
                        rarityColor.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                      radius: 0.75,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ItemIconView(
                  iconValue: iconValue,
                  itemId: itemId,
                  itemType: itemType,
                  size: _iconInnerSize,
                  expand: true,
                ),
              ),
            ),
            if (showQty)
              Positioned(
                right: 3,
                bottom: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xE6080D1A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: rarityColor.withValues(alpha: 0.45),
                      width: 0.7,
                    ),
                  ),
                  child: Text(
                    'x$quantity',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: rarityColor,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

ItemType? marketItemTypeFromString(String? value) {
  if (value == null || value.isEmpty) return null;
  return ItemTypeParsing.fromValue(value);
}
