import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../components/common/app_messenger.dart';
import '../../../models/item_model.dart';
import '../../../models/market_model.dart';
import '../../../theme/app_colors.dart';
import 'market_design.dart';

class MarketFilterOption {
  const MarketFilterOption(this.key, this.label, {this.icon});

  final String key;
  final String label;
  final IconData? icon;
}

enum MarketPriceSort { lowToHigh, highToLow }

const List<MarketFilterOption> marketCategoryFilters = <MarketFilterOption>[
  MarketFilterOption('', 'Tumu', icon: Icons.apps_rounded),
  MarketFilterOption('weapon', 'Silah', icon: Icons.sports_martial_arts_rounded),
  MarketFilterOption('armor', 'Zirh', icon: Icons.shield_rounded),
  MarketFilterOption('consumable', 'Iksir', icon: Icons.science_rounded),
  MarketFilterOption('material', 'Malzeme', icon: Icons.category_rounded),
  MarketFilterOption('accessory', 'Aksesuar', icon: Icons.diamond_rounded),
];

const List<MarketFilterOption> marketRarityFilters = <MarketFilterOption>[
  MarketFilterOption('', 'Tumu'),
  MarketFilterOption('common', 'Yaygin'),
  MarketFilterOption('uncommon', 'Olaganustu'),
  MarketFilterOption('rare', 'Nadir'),
  MarketFilterOption('epic', 'Destansi'),
  MarketFilterOption('legendary', 'Efsanevi'),
  MarketFilterOption('mythic', 'Mitik'),
];

/// Static category pills (counts omitted — server paginates browse data).
List<MarketPillOption> marketStaticCategoryPillOptions() {
  return marketCategoryFilters
      .map(
        (MarketFilterOption f) => MarketPillOption(
          key: f.key,
          label: f.label,
          icon: f.icon,
        ),
      )
      .toList();
}

List<MarketPillOption> marketStaticRarityPillOptions() {
  return marketRarityFilters
      .map(
        (MarketFilterOption f) => MarketPillOption(
          key: f.key,
          label: f.label,
        ),
      )
      .toList();
}

/// Category pills with Turkish labels + counts for browse UI.
List<MarketPillOption> marketCategoryPillOptions(List<MarketTicker> tickers) {
  return <MarketPillOption>[
    MarketPillOption(
      key: '',
      label: 'Tumu',
      count: tickers.length,
      icon: Icons.apps_rounded,
    ),
    MarketPillOption(
      key: 'weapon',
      label: 'Silah',
      count: countMarketByCategory(tickers, 'weapon'),
      icon: Icons.sports_martial_arts_rounded,
    ),
    MarketPillOption(
      key: 'armor',
      label: 'Zirh',
      count: countMarketByCategory(tickers, 'armor'),
      icon: Icons.shield_rounded,
    ),
    MarketPillOption(
      key: 'consumable',
      label: 'Iksir',
      count: countMarketByCategory(tickers, 'consumable'),
      icon: Icons.science_rounded,
    ),
    MarketPillOption(
      key: 'material',
      label: 'Malzeme',
      count: countMarketByCategory(tickers, 'material'),
      icon: Icons.category_rounded,
    ),
    MarketPillOption(
      key: 'accessory',
      label: 'Aksesuar',
      count: countMarketByCategory(tickers, 'accessory'),
      icon: Icons.diamond_rounded,
    ),
  ];
}

List<MarketPillOption> marketRarityPillOptions(List<MarketTicker> tickers) {
  return marketRarityFilters
      .map(
        (MarketFilterOption f) => MarketPillOption(
          key: f.key,
          label: f.label,
          count: f.key.isEmpty ? tickers.length : countMarketByRarity(tickers, f.key),
        ),
      )
      .toList();
}

int countMarketByCategory(List<MarketTicker> tickers, String category) {
  return tickers.where((MarketTicker t) => t.itemType == category).length;
}

int countMarketByRarity(List<MarketTicker> tickers, String rarity) {
  return tickers.where((MarketTicker t) => t.rarity == rarity).length;
}

IconData marketCategoryIcon(String category) {
  switch (category) {
    case 'weapon':
      return Icons.sports_martial_arts_rounded;
    case 'armor':
      return Icons.shield_rounded;
    case 'consumable':
      return Icons.science_rounded;
    case 'material':
      return Icons.category_rounded;
    case 'accessory':
      return Icons.diamond_rounded;
    default:
      return Icons.inventory_2_outlined;
  }
}

ItemType? marketItemTypeFromString(String? value) {
  if (value == null || value.isEmpty) return null;
  return ItemTypeParsing.fromValue(value);
}

String formatMarketGold(int value) {
  return NumberFormat.decimalPattern('tr_TR').format(value);
}

String formatMarketPriceChange(int changeBps) {
  if (changeBps == 0) return '0%';
  final double pct = changeBps / 100;
  final String sign = pct > 0 ? '+' : '';
  return '$sign${pct.toStringAsFixed(pct.abs() >= 10 ? 1 : 2)}%';
}

Color marketPriceChangeColor(int changeBps) {
  if (changeBps > 0) return AppColors.toxicNeon;
  if (changeBps < 0) return AppColors.mysticRuby;
  return AppColors.mutedTitanium;
}

Color marketRarityColor(String rarityName) {
  return AppColors.forRarity(rarityName);
}

Color marketRarityGlowColor(String rarityName) {
  return switch (rarityName.toLowerCase()) {
    'legendary' => AppColors.liquidGold,
    'mythic' => AppColors.cyberFuchsia,
    'epic' => AppColors.accentPurple,
    'rare' => AppColors.coralFlare,
    'uncommon' => AppColors.toxicNeon,
    _ => AppColors.mutedTitanium,
  };
}

String marketRarityLabel(String rarityName) {
  switch (rarityName) {
    case 'common':
      return 'Yaygin';
    case 'uncommon':
      return 'Olaganustu';
    case 'rare':
      return 'Nadir';
    case 'epic':
      return 'Destansi';
    case 'legendary':
      return 'Efsanevi';
    case 'mythic':
      return 'Mitik';
    default:
      return 'Yaygin';
  }
}

void showMarketSnackBar(BuildContext context, String message, {bool isError = false}) {
  AppMessenger.show(
    context,
    message,
    type: isError ? AppMessageType.error : AppMessageType.info,
  );
}
