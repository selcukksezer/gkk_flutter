import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class ReputationTier {
  const ReputationTier({required this.title, required this.color});

  final String title;
  final Color color;
}

/// Shared reputation thresholds — home + character must match.
ReputationTier reputationTierFor(int reputation) {
  final int rep = reputation < 0 ? 0 : reputation;
  if (rep <= 5000) {
    return const ReputationTier(title: 'Acemi', color: AppColors.rarityCommon);
  }
  if (rep <= 20000) {
    return const ReputationTier(
      title: 'Tanınan',
      color: AppColors.rarityUncommon,
    );
  }
  if (rep <= 80000) {
    return const ReputationTier(title: 'Saygın', color: AppColors.rarityRare);
  }
  if (rep <= 170000) {
    return const ReputationTier(title: 'Ünlü', color: AppColors.rarityEpic);
  }
  if (rep <= 280000) {
    return const ReputationTier(title: 'Efsanevi', color: AppColors.warning);
  }
  if (rep <= 356000) {
    return const ReputationTier(title: 'Destansı', color: AppColors.danger);
  }
  return const ReputationTier(title: 'İmparator', color: AppColors.gold);
}
