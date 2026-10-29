import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../models/item_model.dart';
import '../../../theme/app_colors.dart';
import 'market_design.dart';
import 'market_helpers.dart';
import 'market_item_icon.dart';
import 'market_item_pedestal.dart';

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
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: glow.withValues(alpha: 0.32),
                width: 1.1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: glow.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: AppColors.carbonVoid.withValues(alpha: 0.70),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.spaceNavy.withValues(alpha: 0.94),
                        AppColors.carbonVoid.withValues(alpha: 0.98),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      const Positioned.fill(
                        child: CustomPaint(
                          painter: DotGridPainter(spacing: 12, dotOpacity: 0.04),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 12,
                        right: 12,
                        height: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                Colors.transparent,
                                glow.withValues(alpha: 0.45),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -12,
                        left: -8,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                glow.withValues(alpha: 0.22),
                                glow.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
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
                                          letterSpacing: 0.2,
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                    if (badge != null) ...<Widget>[
                                      const SizedBox(width: 6),
                                      Flexible(
                                        flex: 0,
                                        child: _badge(badge!, AppColors.liquidGold),
                                      ),
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
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  priceText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.liquidGold,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 0.2,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (trailing != null) ...<Widget>[
                            const SizedBox(width: 8),
                            Flexible(
                              flex: 0,
                              child: trailing!,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
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
    this.onInspect,
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
  final VoidCallback? onInspect;
  final int index;

  @override
  Widget build(BuildContext context) {
    final Color glow = marketRarityGlowColor(rarity);
    final Color rarityColor = marketRarityColor(rarity);
    final Color changeColor = marketPriceChangeColor(priceChangeBps);
    final String changeText = formatMarketPriceChange(priceChangeBps);
    final VoidCallback? cardAction = onInspect ?? (canBuy ? onBuy : null);

    return MarketFadeSlide(
      index: index,
      child: MarketPressable(
        enabled: cardAction != null,
        onTap: cardAction,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: glow.withValues(alpha: 0.38), width: 1.2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                AppColors.spaceNavy.withValues(alpha: 0.94),
                AppColors.carbonVoid.withValues(alpha: 0.98),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: glow.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.carbonVoid.withValues(alpha: 0.85),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Stack(
                children: <Widget>[
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: DotGridPainter(spacing: 12, dotOpacity: 0.05),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 18,
                    right: 18,
                    height: 1.2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.transparent,
                            glow.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              glow.withValues(alpha: 0.30),
                              glow.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          height: 20,
                          child: Row(
                            children: <Widget>[
                              if (ownListing)
                                Flexible(
                                  child: _cornerBadge(
                                    'Senin',
                                    AppColors.warningSolar,
                                    icon: Icons.person_rounded,
                                  ),
                                )
                              else
                                const Spacer(),
                              if (ownListing && priceChangeBps != 0)
                                const SizedBox(width: 4),
                              if (priceChangeBps != 0) ...<Widget>[
                                if (ownListing) const Spacer(),
                                Flexible(
                                  child: _cornerBadge(
                                    changeText,
                                    changeColor,
                                    icon: priceChangeBps > 0
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: MarketItemPedestal(
                            rarity: rarity,
                            iconValue: iconValue,
                            itemId: itemId,
                            itemType: itemType,
                            itemName: itemName,
                            size: 76,
                            interactive: false,
                            autoRotate: true,
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
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
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
                            fontSize: 9.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: AppColors.liquidGold.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.liquidGold.withValues(alpha: 0.22),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                Icons.monetization_on_rounded,
                                size: 12,
                                color: AppColors.liquidGold.withValues(alpha: 0.95),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  formatMarketGold(price),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.liquidGold,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11.5,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
      ),
    );
  }

  Widget _cornerBadge(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 9, color: color),
            const SizedBox(width: 2.5),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
