import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class ReputationTier {
  const ReputationTier({required this.title, required this.color});

  final String title;
  final Color color;
}

class ReputationTierProgress {
  const ReputationTierProgress({
    required this.progress,
    required this.nextTierTitle,
  });

  final double progress;
  final String nextTierTitle;
}

/// Progress toward the next tier (0–1) and its title.
ReputationTierProgress reputationTierProgressFor(int reputation) {
  const List<int> thresholds = <int>[
    5000,
    20000,
    80000,
    170000,
    280000,
    356000,
  ];
  const List<String> names = <String>[
    'Tanınan',
    'Saygın',
    'Ünlü',
    'Efsanevi',
    'Destansı',
    'İmparator',
  ];
  final int rep = reputation < 0 ? 0 : reputation;
  if (rep >= 356000) {
    return const ReputationTierProgress(progress: 1.0, nextTierTitle: 'Maksimum');
  }
  int prev = 0;
  for (int i = 0; i < thresholds.length; i++) {
    if (rep < thresholds[i]) {
      final double p = (rep - prev) / (thresholds[i] - prev);
      return ReputationTierProgress(progress: p, nextTierTitle: names[i]);
    }
    prev = thresholds[i];
  }
  return const ReputationTierProgress(progress: 1.0, nextTierTitle: 'İmparator');
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
