import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/player_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import 'power_formula.dart';

/// Authoritative combat power for HUD / inventory / overlays.
/// Prefers server [PlayerProfile.power] (`users.power`); client recalc only if unset.
int readPlayerTotalPower(WidgetRef ref) {
  final PlayerProfile? profile = ref.read(playerProvider).profile;
  if (profile == null) return 0;
  return resolveDungeonCombatPower(
    profile: profile,
    equippedItems: ref.read(inventoryProvider).equippedItems.values,
  );
}

String formatPowerValue(int value) {
  final String raw = value.abs().toString();
  if (raw.length <= 3) return '$value';
  final StringBuffer buffer = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(raw[i]);
  }
  return buffer.toString();
}
