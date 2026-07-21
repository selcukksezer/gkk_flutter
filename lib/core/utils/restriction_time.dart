/// Shared restriction timer parsing + countdown formatting (hospital/prison).
DateTime? parseRestrictionUntil(String? raw) {
  if (raw == null) return null;
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final DateTime? parsed = DateTime.tryParse(trimmed) ??
      DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
  if (parsed == null) return null;

  if (parsed.isUtc) return parsed.toLocal();

  final bool hasTimezone = RegExp(
    r'(Z|[+\-]\d{2}:?\d{2})$',
    caseSensitive: false,
  ).hasMatch(trimmed);

  if (!hasTimezone) {
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).toLocal();
  }

  return parsed.toLocal();
}

Duration restrictionRemaining(String? untilRaw, {DateTime? now}) {
  final DateTime? release = parseRestrictionUntil(untilRaw);
  if (release == null) return Duration.zero;
  final DateTime clock = now ?? DateTime.now();
  if (!release.isAfter(clock)) return Duration.zero;
  return release.difference(clock);
}

bool isRestrictionActive(String? untilRaw, {DateTime? now}) {
  return restrictionRemaining(untilRaw, now: now) > Duration.zero;
}

String formatRestrictionCountdown(Duration duration) {
  if (duration <= Duration.zero) return '00:00';
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

String formatRestrictionRelease(DateTime? releaseTime) {
  if (releaseTime == null) return '—';
  return '${releaseTime.year.toString().padLeft(4, '0')}-'
      '${releaseTime.month.toString().padLeft(2, '0')}-'
      '${releaseTime.day.toString().padLeft(2, '0')} '
      '${releaseTime.hour.toString().padLeft(2, '0')}:'
      '${releaseTime.minute.toString().padLeft(2, '0')}:'
      '${releaseTime.second.toString().padLeft(2, '0')}';
}
