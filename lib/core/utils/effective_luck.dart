import 'dart:math' as math;

import '../../models/player_model.dart';

/// Mirrors SQL `equip_luck_effective` / `effective_player_luck`
/// (stat inflation Faz 0 — RAPOR 20260731).
///
/// `equip_eff = 500 * (1 - exp(-raw/1000))`, hard cap effective ≤ 1500.
double equipLuckEffective(num equipLuckRaw) {
  final double raw = equipLuckRaw.toDouble();
  if (raw <= 0) return 0;
  return 500.0 * (1.0 - math.exp(-raw / 1000.0));
}

int effectivePlayerLuck({
  required int baseLuck,
  required int equipLuckRaw,
}) {
  final double total =
      baseLuck.clamp(0, 1 << 30) + equipLuckEffective(equipLuckRaw);
  return total.clamp(0, 1500).round();
}

/// After Faz 1 unbake: [PlayerProfile.luck] is base-only.
int effectivePlayerLuckFromProfile(PlayerProfile profile) {
  return effectivePlayerLuck(
    baseLuck: profile.luck ?? 0,
    equipLuckRaw: profile.equipBonusLuck,
  );
}
