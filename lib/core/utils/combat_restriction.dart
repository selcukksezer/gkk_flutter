import 'restriction_time.dart';
import 'player_health.dart';

/// Client-side combat lock from hospital / prison / low health timers.
/// Server still authoritative via `assert_player_combat_ready`.
String? combatRestrictionMessage({
  String? hospitalUntil,
  String? prisonUntil,
  int? health,
  int? maxHealth,
  DateTime? now,
}) {
  if (isRestrictionActive(hospitalUntil, now: now)) {
    return 'Hastanedeyken savaşamazsın.';
  }
  if (isRestrictionActive(prisonUntil, now: now)) {
    return 'Hapisteyken savaşamazsın.';
  }
  if (health != null &&
      maxHealth != null &&
      maxHealth > 0 &&
      isHealthTooLowForCombat(health: health, maxHealth: maxHealth)) {
    return 'Canın çok düşük — iksir kullan veya dinlen.';
  }
  return null;
}

/// PvP-oriented wrapper including low-health gate for attackers.
String? combatRestrictionForProfile({
  required int health,
  required int maxHealth,
  String? hospitalUntil,
  String? prisonUntil,
  DateTime? now,
}) {
  return combatRestrictionMessage(
    hospitalUntil: hospitalUntil,
    prisonUntil: prisonUntil,
    health: health,
    maxHealth: maxHealth,
    now: now,
  );
}

bool isCombatRestricted({
  String? hospitalUntil,
  String? prisonUntil,
  int? health,
  int? maxHealth,
  DateTime? now,
}) {
  return combatRestrictionMessage(
        hospitalUntil: hospitalUntil,
        prisonUntil: prisonUntil,
        health: health,
        maxHealth: maxHealth,
        now: now,
      ) !=
      null;
}
