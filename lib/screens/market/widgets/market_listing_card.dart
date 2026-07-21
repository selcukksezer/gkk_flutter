import 'package:flutter/material.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../models/item_model.dart';
import '../../../theme/app_colors.dart';
import 'market_design.dart';
import 'market_helpers.dart';
import 'market_item_icon.dart';

/// Row card — sell / my-market tabs.
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
    this.index = 0,
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
  final int index;

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = marketRarityColor(rarity);
    final Color glow = marketRarityGlowColor(rarity);

    return MarketFadeSlide(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: MarketPressable(
          enabled: onTap != null,
          onTap: onTap,
          child: DottedPanel(
            borderColor: glow.withValues(alpha: 0.28),
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: <Widget>[
                MarketItemIcon(
                  rarity: rarity,
                  iconValue: iconValue,
                  itemId: itemId,
                  itemType: itemType,
                  quantity: quantity,
                  showQuantity: showQuantity,
                  size: 52,
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
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                height: 1.1,
                              ),
                            ),
                          ),
                          if (badge != null) ...<Widget>[
                            const SizedBox(width: 6),
                            _badge(badge!, AppColors.liquidGold),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        metaLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.mutedTitanium,
                          fontSize: 10,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        priceText,
                        style: const TextStyle(
                          color: AppColors.liquidGold,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900),
      ),
    );
  }
}

/// 2-column vault grid card — browse tab (ref image 3).
class MarketBrowseGridCard extends StatelessWidget {
  const MarketBrowseGridCard({
    super.key,
    required this.itemName,
    required this.rarity,
    required this.price,
    required this.priceChangeBps,
    required this.stockLabel,
    this.itemId,
    this.iconValue = '',
    this.itemType,
    this.quantity,
    this.showQuantity = false,
    this.ownListing = false,
    this.canBuy = true,
    this.onBuy,
    this.index = 0,
  });

  final String itemName;
  final String rarity;
  final int price;
  final int priceChangeBps;
  final String stockLabel;
  final String? itemId;
  final String iconValue;
  final ItemType? itemType;
  final int? quantity;
  final bool showQuantity;
  final bool ownListing;
  final bool canBuy;
  final VoidCallback? onBuy;
  final int index;

  @override
  Widget build(BuildContext context) {
    final Color glow = marketRarityGlowColor(rarity);
    final Color rarityColor = marketRarityColor(rarity);
    final Color changeColor = marketPriceChangeColor(priceChangeBps);
    final String changeText = formatMarketPriceChange(priceChangeBps);

    return MarketFadeSlide(
      index: index,
      child: MarketPressable(
        enabled: canBuy && onBuy != null,
        onTap: canBuy ? onBuy : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: glow.withValues(alpha: 0.35), width: 1.2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                AppColors.spaceNavy.withValues(alpha: 0.95),
                AppColors.carbonVoid.withValues(alpha: 0.98),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: glow.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: <Widget>[
                const Positioned.fill(
                  child: CustomPaint(
                    painter: DotGridPainter(spacing: 12, dotOpacity: 0.06),
                  ),
                ),
                Positioned(
                  top: -20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            glow.withValues(alpha: 0.35),
                            glow.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (ownListing)
                            _cornerBadge('Senin', AppColors.warningSolar)
                          else
                            const Spacer(),
                          const Spacer(),
                          if (priceChangeBps != 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: changeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: changeColor.withValues(alpha: 0.35)),
                              ),
                              child: Text(
                                changeText,
                                style: TextStyle(
                                  color: changeColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: MarketItemIcon(
                          rarity: rarity,
                          iconValue: iconValue,
                          itemId: itemId,
                          itemType: itemType,
                          quantity: quantity,
                          showQuantity: showQuantity,
                          size: 64,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: rarityColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stockLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.mutedTitanium,
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.monetization_on_rounded,
                            size: 12,
                            color: AppColors.liquidGold.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              formatMarketGold(price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.liquidGold,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: MarketPrimaryButton(
                          label: ownListing ? 'Senin' : 'Al',
                          icon: ownListing ? Icons.person_rounded : Icons.shopping_cart_rounded,
                          compact: true,
                          onPressed: canBuy && !ownListing ? onBuy : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cornerBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900),
      ),
    );
  }
}
