import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tutorial/tutorial_controller.dart';
import '../providers/auth_provider.dart';
import '../providers/crafting_provider.dart';
import '../providers/daily_reward_provider.dart';
import '../providers/facilities_provider.dart';
import '../providers/guild_provider.dart';
import '../providers/guild_war_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/player_provider.dart';
import '../providers/policy_provider.dart';
import '../providers/pvp_provider.dart';
import '../providers/dungeon_siege_provider.dart';

/// Clears in-memory game state so the next login never sees stale data.
void clearGameSessionProviders(WidgetRef ref) {
  ref.read(playerProvider.notifier).clear();
  ref.read(inventoryProvider.notifier).clear();
  ref.read(guildProvider.notifier).clear();
  ref.read(facilitiesProvider.notifier).clear();
  ref.read(craftingProvider.notifier).clear();
  ref.read(dailyRewardProvider.notifier).clear();
  ref.read(tutorialProvider.notifier).clearSession();
  ref.invalidate(policyProvider);
  ref.invalidate(guildWarProvider);
  ref.invalidate(pvpDashboardProvider);
  ref.invalidate(pvpHistoryProvider);
  ref.invalidate(pvpTournamentProvider);
  ref.invalidate(dungeonSiegeProvider);
}

/// Signs out and clears all session providers — use from any screen logout handler.
Future<void> performLogout(WidgetRef ref) async {
  // Clear BEFORE auth logout — logout redirects/unmounts caller → WidgetRef dies.
  clearGameSessionProviders(ref);
  await ref.read(authProvider.notifier).logout();
}
