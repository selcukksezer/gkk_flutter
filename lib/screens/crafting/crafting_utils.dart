import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

Color craftingRarityColor(String rarity) => AppColors.forRarity(rarity);

String formatCraftingDuration(int totalSeconds) {
  if (totalSeconds <= 0) return 'Hazır';
  final int h = totalSeconds ~/ 3600;
  final int m = (totalSeconds % 3600) ~/ 60;
  final int s = totalSeconds % 60;
  if (h > 0) return '${h}s ${m}d ${s}sn';
  if (m > 0) return '${m}d ${s}sn';
  return '${s}sn';
}

double parseCraftSuccessRate(double value) {
  if (value <= 0) return 0.8;
  return value > 1 ? value / 100 : value;
}

/// Prefer [CraftRecipe.normalizedSuccessRate] on recipe instances.