import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../components/common/app_messenger.dart';
import '../../../theme/app_colors.dart';

class MarketFilterOption {
  const MarketFilterOption(this.key, this.label);

  final String key;
  final String label;
}

enum MarketPriceSort { lowToHigh, highToLow }

const List<MarketFilterOption> marketCategoryFilters = <MarketFilterOption>[
  MarketFilterOption('', 'Tum Kategoriler'),
  MarketFilterOption('weapon', 'Silah'),
  MarketFilterOption('armor', 'Zirh'),
  MarketFilterOption('consumable', 'Iksir'),
  MarketFilterOption('material', 'Malzeme'),
  MarketFilterOption('accessory', 'Aksesuar'),
];

const List<MarketFilterOption> marketRarityFilters = <MarketFilterOption>[
  MarketFilterOption('', 'Tum Nadirlik'),
  MarketFilterOption('common', 'Yaygin'),
  MarketFilterOption('uncommon', 'Olaganustu'),
  MarketFilterOption('rare', 'Nadir'),
  MarketFilterOption('epic', 'Destansi'),
  MarketFilterOption('legendary', 'Efsanevi'),
  MarketFilterOption('mythic', 'Mitik'),
];

String formatMarketGold(int value) {
  return NumberFormat.decimalPattern('tr_TR').format(value);
}

Color marketRarityColor(String rarityName) {
  return AppColors.forRarity(rarityName);
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
