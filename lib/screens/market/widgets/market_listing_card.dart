import 'package:flutter/material.dart';

import '../../../models/item_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'market_helpers.dart';
import 'market_item_icon.dart';

class MarketListingCard extends StatelessWidget {
  const MarketListingCard({
    super.key,
    required this.itemName,
    required this.rarity,
    required this.metaLine,
    required this.priceText,
    this.itemId,
    this.iconValue = '',
    this.itemType,
    this.quantity,
    this.showQuantity = true,
    this.badge,
    this.trailing,
    this.onTap,
  });

  final String itemName;
  final String rarity;
  final String metaLine;
  final String priceText;
  final String? itemId;
  final String iconValue;
  final ItemType? itemType;
  final int? quantity;
  final bool showQuantity;
  final String? badge;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = marketRarityColor(rarity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderDefault.withValues(alpha: 0.85)),
          ),
          child: Row(
            children: <Widget>[
              MarketItemIcon(
                rarity: rarity,
                iconValue: iconValue,
                itemId: itemId,
                itemType: itemType,
                quantity: quantity,
                showQuantity: showQuantity,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: rarityColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (badge != null) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.goldGlow,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metaLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      priceText,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 6),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
