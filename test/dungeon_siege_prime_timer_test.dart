import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/dungeon_siege_prime_timer.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(DungeonSiegePrimeSchedule.ensureTimeZones);

  test('shows countdown until next prime between evening windows', () {
    final tz.Location loc = tz.getLocation('Europe/Istanbul');
    final tz.TZDateTime now = tz.TZDateTime(loc, 2026, 7, 22, 21, 30);

    final DungeonSiegePrimeTimerSnapshot snap = DungeonSiegePrimeSchedule.snapshot(
      windows: kDefaultSiegePrimeWindows,
      timezone: 'Europe/Istanbul',
      isEnabled: true,
      nowLocal: now,
    );

    expect(snap.mode, DungeonSiegePrimeTimerMode.untilStart);
    expect(snap.remaining, const Duration(minutes: 30));
    expect(snap.formattedRemaining, contains('30dk'));
  });

  test('shows remaining time during midnight-wrap prime window', () {
    final tz.Location loc = tz.getLocation('Europe/Istanbul');
    final tz.TZDateTime now = tz.TZDateTime(loc, 2026, 7, 22, 23, 0);

    final DungeonSiegePrimeTimerSnapshot snap = DungeonSiegePrimeSchedule.snapshot(
      windows: kDefaultSiegePrimeWindows,
      timezone: 'Europe/Istanbul',
      isEnabled: true,
      nowLocal: now,
    );

    expect(snap.mode, DungeonSiegePrimeTimerMode.untilEnd);
    expect(snap.remaining, const Duration(hours: 1));
  });

  test('shows countdown until morning prime after late night gap', () {
    final tz.Location loc = tz.getLocation('Europe/Istanbul');
    final tz.TZDateTime now = tz.TZDateTime(loc, 2026, 7, 22, 1, 0);

    final DungeonSiegePrimeTimerSnapshot snap = DungeonSiegePrimeSchedule.snapshot(
      windows: kDefaultSiegePrimeWindows,
      timezone: 'Europe/Istanbul',
      isEnabled: true,
      nowLocal: now,
    );

    expect(snap.mode, DungeonSiegePrimeTimerMode.untilStart);
    expect(snap.remaining, const Duration(hours: 18));
  });

  test('hidden when siege disabled', () {
    final tz.Location loc = tz.getLocation('Europe/Istanbul');
    final tz.TZDateTime now = tz.TZDateTime(loc, 2026, 7, 22, 12, 0);

    final DungeonSiegePrimeTimerSnapshot snap = DungeonSiegePrimeSchedule.snapshot(
      windows: kDefaultSiegePrimeWindows,
      timezone: 'Europe/Istanbul',
      isEnabled: false,
      nowLocal: now,
    );

    expect(snap.isVisible, isFalse);
  });
}
