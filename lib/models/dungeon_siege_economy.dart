import 'dungeon_model.dart';

/// Kuşatma ekonomisi — PLAN_06 + boss zindan gold ortalaması.
abstract final class DungeonSiegeEconomy {
  /// Meydan okuma: ~%35 ortalama boss koşu altını, min 50K (hastane bandı), max 10M.
  static int challengeGoldForDungeon(DungeonData dungeon) =>
      challengeGoldForRange(goldMin: dungeon.minGold, goldMax: dungeon.maxGold);

  static int challengeGoldForRange({required int goldMin, required int goldMax}) {
    final int avg = (goldMin + goldMax) ~/ 2;
    final int scaled = (avg * 0.35).round();
    return scaled.clamp(50000, 10000000);
  }
}
