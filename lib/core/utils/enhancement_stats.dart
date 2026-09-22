import '../../models/inventory_model.dart';

/// Stat inflation Faz 2 — mirrors SQL `enhancement_stat_multiplier`.
/// ≤6: 1 + enh×0.12; +7..+10: 1.72 + (enh-6)×0.08 (+10 → 2.04).
double enhancementMultiplier(int enhancementLevel) {
  final int level = enhancementLevel.clamp(0, 10);
  if (level <= 0) return 1.0;
  if (level <= 6) return 1.0 + (level * 0.12);
  return 1.72 + ((level - 6) * 0.08);
}

int enhancedStat(int baseStat, int enhancementLevel) {
  if (baseStat == 0) return 0;
  return (baseStat * enhancementMultiplier(enhancementLevel)).floor();
}

/// Combat contribution for one item at [enhancementLevel] (defaults to item level).
int enhancedItemPowerContribution(
  InventoryItem item, {
  int? enhancementLevel,
}) {
  final int level = enhancementLevel ?? item.enhancementLevel;
  final double base =
      item.attack + item.defense + (item.health / 10.0) + (item.luck * 2.0);
  return (base * enhancementMultiplier(level)).floor();
}

/// Display helper — effective enhanced value only (no base→ arrow).
String formatEnhancedStat(int baseStat, int enhancementLevel) {
  return '${enhancedStat(baseStat, enhancementLevel)}';
}
