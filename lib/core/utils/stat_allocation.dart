/// Stat point allocation helpers (mirrors server `stat_point_health_multiplier`).
library;

/// Each stat point spent on health grants this much max/current health.
const int statPointHealthMultiplier = 10;

int statPointHealthGain(int points) {
  if (points <= 0) return 0;
  return points * statPointHealthMultiplier;
}

String statPointHealthPreviewLabel(int pendingPoints) {
  if (pendingPoints <= 0) return '0';
  final int gain = statPointHealthGain(pendingPoints);
  return '+$pendingPoints → +$gain can';
}
