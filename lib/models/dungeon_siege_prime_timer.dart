import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// DB `prime_windows` satırı (`start` / `end` → `HH:mm`).
class DungeonSiegePrimeWindow {
  const DungeonSiegePrimeWindow({
    required this.start,
    required this.end,
  });

  final String start;
  final String end;

  int get startMinutes => _parseMinutes(start);
  int get endMinutes => _parseMinutes(end);

  static int _parseMinutes(String hhmm) {
    final List<String> parts = hhmm.split(':');
    if (parts.length < 2) return 0;
    final int h = int.tryParse(parts[0]) ?? 0;
    final int m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }
}

const List<DungeonSiegePrimeWindow> kDefaultSiegePrimeWindows = <DungeonSiegePrimeWindow>[
  DungeonSiegePrimeWindow(start: '19:00', end: '21:00'),
  DungeonSiegePrimeWindow(start: '22:00', end: '00:00'),
];

enum DungeonSiegePrimeTimerMode {
  hidden,
  untilStart,
  untilEnd,
}

class DungeonSiegePrimeTimerSnapshot {
  const DungeonSiegePrimeTimerSnapshot({
    required this.mode,
    this.remaining,
  });

  final DungeonSiegePrimeTimerMode mode;
  final Duration? remaining;

  bool get isVisible =>
      mode != DungeonSiegePrimeTimerMode.hidden &&
      remaining != null &&
      remaining! > Duration.zero;

  String get labelPrefix => mode == DungeonSiegePrimeTimerMode.untilEnd ? 'Bitiş' : 'Prime';

  String get formattedRemaining =>
      remaining == null ? '' : DungeonSiegePrimeSchedule.format(remaining!);
}

class DungeonSiegePrimeSchedule {
  static bool _tzInitialized = false;

  static void ensureTimeZones() {
    if (_tzInitialized) return;
    tz_data.initializeTimeZones();
    _tzInitialized = true;
  }

  static tz.Location resolveLocation(String timezone) {
    ensureTimeZones();
    try {
      return tz.getLocation(timezone);
    } catch (_) {
      return tz.getLocation('Europe/Istanbul');
    }
  }

  static DungeonSiegePrimeTimerSnapshot snapshot({
    required List<DungeonSiegePrimeWindow> windows,
    required String timezone,
    required bool isEnabled,
    tz.TZDateTime? nowLocal,
  }) {
    if (!isEnabled || windows.isEmpty) {
      return const DungeonSiegePrimeTimerSnapshot(mode: DungeonSiegePrimeTimerMode.hidden);
    }

    final tz.Location location = resolveLocation(timezone);
    final tz.TZDateTime now = nowLocal ?? tz.TZDateTime.now(location);
    final int nowMinutes = now.hour * 60 + now.minute;
    final bool inPrimeWindow =
        windows.any((DungeonSiegePrimeWindow w) => isMinutesInWindow(nowMinutes, w));

    if (inPrimeWindow) {
      final Duration? remaining = _remainingInActiveWindow(windows, now, nowMinutes);
      if (remaining == null || remaining <= Duration.zero) {
        return const DungeonSiegePrimeTimerSnapshot(mode: DungeonSiegePrimeTimerMode.hidden);
      }
      return DungeonSiegePrimeTimerSnapshot(
        mode: DungeonSiegePrimeTimerMode.untilEnd,
        remaining: remaining,
      );
    }

    final Duration? untilStart = _untilNextStart(windows, now, nowMinutes);
    if (untilStart == null || untilStart <= Duration.zero) {
      return const DungeonSiegePrimeTimerSnapshot(mode: DungeonSiegePrimeTimerMode.hidden);
    }
    return DungeonSiegePrimeTimerSnapshot(
      mode: DungeonSiegePrimeTimerMode.untilStart,
      remaining: untilStart,
    );
  }

  static bool isMinutesInWindow(int nowMinutes, DungeonSiegePrimeWindow window) {
    final int start = window.startMinutes;
    final int end = window.endMinutes;
    if (start == end) return false;
    if (end > start) {
      return nowMinutes >= start && nowMinutes < end;
    }
    return nowMinutes >= start || nowMinutes < end;
  }

  static Duration? _remainingInActiveWindow(
    List<DungeonSiegePrimeWindow> windows,
    tz.TZDateTime now,
    int nowMinutes,
  ) {
    Duration? best;
    for (final DungeonSiegePrimeWindow window in windows) {
      if (!isMinutesInWindow(nowMinutes, window)) continue;
      final Duration candidate = _durationUntilWindowEnd(now, nowMinutes, window);
      if (best == null || candidate < best) {
        best = candidate;
      }
    }
    return best;
  }

  static Duration _durationUntilWindowEnd(
    tz.TZDateTime now,
    int nowMinutes,
    DungeonSiegePrimeWindow window,
  ) {
    final int start = window.startMinutes;
    final int end = window.endMinutes;
    if (end > start) {
      return Duration(minutes: end - nowMinutes);
    }
    // Gece yarısı saran pencere (ör. 22:00 → 00:00).
    if (nowMinutes >= start) {
      return Duration(minutes: (24 * 60 - nowMinutes) + end);
    }
    return Duration(minutes: end - nowMinutes);
  }

  static Duration? _untilNextStart(
    List<DungeonSiegePrimeWindow> windows,
    tz.TZDateTime now,
    int nowMinutes,
  ) {
    Duration? best;
    for (final DungeonSiegePrimeWindow window in windows) {
      if (isMinutesInWindow(nowMinutes, window)) continue;
      final Duration candidate = _durationUntilWindowStart(nowMinutes, window);
      if (best == null || candidate < best) {
        best = candidate;
      }
    }
    return best;
  }

  static Duration _durationUntilWindowStart(int nowMinutes, DungeonSiegePrimeWindow window) {
    final int start = window.startMinutes;
    final int end = window.endMinutes;

    if (end > start) {
      if (nowMinutes < start) {
        return Duration(minutes: start - nowMinutes);
      }
      return Duration(minutes: (24 * 60 - nowMinutes) + start);
    }

    // Gece saran pencere — aktif değilken sadece start..end arası boşluk kalır.
    if (nowMinutes >= end && nowMinutes < start) {
      return Duration(minutes: start - nowMinutes);
    }
    if (nowMinutes < end) {
      return Duration(minutes: start - nowMinutes);
    }
    return Duration(minutes: (24 * 60 - nowMinutes) + start);
  }

  static String format(Duration duration) {
    final int totalSeconds = duration.inSeconds.clamp(0, 7 * 24 * 3600);
    final int days = totalSeconds ~/ 86400;
    final int hours = (totalSeconds % 86400) ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    if (days > 0) {
      return '${days}g ${hours}s';
    }
    if (hours > 0) {
      return '${hours}s ${minutes.toString().padLeft(2, '0')}dk';
    }
    if (minutes > 0) {
      return '${minutes}dk ${seconds.toString().padLeft(2, '0')}sn';
    }
    return '${seconds}sn';
  }
}
