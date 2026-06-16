import '../../models/inventory_model.dart';
import '../../models/player_model.dart';

class PowerBreakdown {
  const PowerBreakdown({
    required this.totalPower,
    required this.equipmentPower,
    required this.levelPower,
    required this.reputationPower,
    required this.luckPower,
  });

  final int totalPower;
  final int equipmentPower;
  final int levelPower;
  final int reputationPower;
  final int luckPower;
}

PowerBreakdown calculateTotalPower({
  required PlayerProfile player,
  required Iterable<InventoryItem?> equippedItems,
}) {
  int equipmentPower = 0;
  for (final InventoryItem? item in equippedItems) {
    if (item == null) continue;
    final double base =
        item.attack + item.defense + (item.health / 10.0) + (item.luck * 2.0);
    final double multiplier = 1 + (item.enhancementLevel * 0.15);
    equipmentPower += (base * multiplier).floor();
  }

  final int levelPower = player.level * 500;
  final int reputationPower = ((player.reputation ?? 0) * 0.1).floor();
  final int luckPower = ((player.luck ?? 0) * 50).floor();

  return PowerBreakdown(
    totalPower: equipmentPower + levelPower + reputationPower + luckPower,
    equipmentPower: equipmentPower,
    levelPower: levelPower,
    reputationPower: reputationPower,
    luckPower: luckPower,
  );
}

double calculateDungeonSuccessRate({
  required int playerTotalPower,
  required int dungeonPowerRequirement,
  required int playerLuck,
  required int reputation,
  required CharacterClass? characterClass,
  int guildLevel = 0,
  double seasonModifier = 0,
}) {
  if (dungeonPowerRequirement <= 0) {
    return 1.0;
  }

  final double ratio = playerTotalPower <= 0
      ? 0
      : playerTotalPower / dungeonPowerRequirement;

  double rate;
  if (ratio >= 1.5) {
    rate = 0.95;
  } else if (ratio >= 1.0) {
    rate = 0.70 + (ratio - 1.0) * 0.50;
  } else if (ratio >= 0.5) {
    rate = 0.25 + (ratio - 0.5) * 0.90;
  } else if (ratio >= 0.25) {
    rate = 0.10 + (ratio - 0.25) * 0.60;
  } else {
    rate = (ratio * 0.40).clamp(0.05, 0.95);
  }

  rate += (playerLuck * 0.001).clamp(0.0, 0.05);
  rate += (reputation * 0.0005).clamp(0.0, 0.025);
  rate += (guildLevel * 0.01).clamp(0.0, 0.05);

  if (characterClass == CharacterClass.warrior) {
    rate += 0.05;
  }

  rate += seasonModifier.clamp(0.0, 0.10);

  return rate.clamp(0.05, 0.95);
}

/// Parses dungeon number from id like `dng_001` → 1.
int parseDungeonNumber(String dungeonId) {
  final RegExpMatch? match = RegExp(r'dng_0*(\d+)').firstMatch(dungeonId);
  if (match == null) return 0;
  return int.tryParse(match.group(1)!) ?? 0;
}

/// Hospital risk on failure (%). First 3 dungeons always 0.
double calculateHospitalRiskPct({
  required int dungeonNumber,
  required double successRate,
  int playerLuck = 0,
}) {
  if (dungeonNumber <= 3) return 0;
  double chance = (1.0 - successRate).clamp(0.05, 0.90);
  chance *= 1 - (playerLuck * 0.003).clamp(0.0, 0.30);
  return (chance * 100).clamp(0.0, 90.0);
}

/// Farm reward multiplier preview for overleveled / high-success farming.
double calculateDungeonRewardMultiplier({
  required int playerLevel,
  required int dungeonPowerRequirement,
  required double successRate,
  bool isFirstClear = false,
}) {
  final int recLevel = (dungeonPowerRequirement / 500).floor().clamp(1, 999);
  final int levelGap = (playerLevel - recLevel).clamp(0, 999);
  final double levelMult = (1.0 / (1.0 + levelGap * 0.08)).clamp(0.20, 1.0);
  double successMult = 1.0;
  if (successRate >= 0.90) {
    successMult = (1.0 - ((successRate - 0.90) / 0.05) * 0.55).clamp(0.45, 1.0);
  }
  final double firstClearMult = isFirstClear ? 1.75 : 1.0;
  return levelMult * successMult * firstClearMult;
}

/// Whether current hospital stay qualifies for free discharge (falls 1–2).
bool canFreeHospitalDischarge(int hospitalLifetimeCount) {
  return hospitalLifetimeCount > 0 && hospitalLifetimeCount <= 2;
}

/// Free discharges left after current stay (falls 1–2 are free).
int freeHospitalDischargesRemaining(int hospitalLifetimeCount) {
  if (hospitalLifetimeCount <= 0) return 2;
  return (2 - hospitalLifetimeCount).clamp(0, 2);
}
