import 'restriction_time.dart';

/// Client-side combat lock from hospital / prison timers.
/// Server still authoritative via `assert_player_combat_ready`.
String? combatRestrictionMessage({
  String? hospitalUntil,
  String? prisonUntil,
  DateTime? now,
}) {
  if (isRestrictionActive(hospitalUntil, now: now)) {
    return 'Hastanedeyken savaşamazsın.';
  }
  if (isRestrictionActive(prisonUntil, now: now)) {
    return 'Hapisteyken savaşamazsın.';
  }
  return null;
}

bool isCombatRestricted({
  String? hospitalUntil,
  String? prisonUntil,
  DateTime? now,
}) {
  return combatRestrictionMessage(
        hospitalUntil: hospitalUntil,
        prisonUntil: prisonUntil,
        now: now,
      ) !=
      null;
}
