/// PLAN_06 ekonomi skalası — K/M/B kısa altın gösterimi.
String formatCompactGold(int value) {
  final int abs = value.abs();
  final String sign = value < 0 ? '-' : '';
  if (abs >= 1000000000) {
    return '$sign${(abs / 1000000000).toStringAsFixed(1)}B';
  }
  if (abs >= 1000000) {
    return '$sign${(abs / 1000000).toStringAsFixed(1)}M';
  }
  if (abs >= 1000) {
    return '$sign${(abs / 1000).toStringAsFixed(1)}K';
  }
  return '$value';
}

String formatCompactGoldRange(int minGold, int maxGold) =>
    '${formatCompactGold(minGold)}-${formatCompactGold(maxGold)}';
