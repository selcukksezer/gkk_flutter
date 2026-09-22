import 'dart:math' as math;

/// Pure helpers mirroring System 2 server math (B/D/C) for unit tests + UI previews.
abstract final class System2RestrictionMath {
  /// Guard bribe gold: max(25000, remainingMinutes * 1500).
  static int prisonGuardBribeCost(int remainingMinutes) {
    final int rem = remainingMinutes < 1 ? 1 : remainingMinutes;
    return math.max(25000, rem * 1500);
  }

  /// Base 45% + shadow 10pp + lawyer 5pp − suspicion/10 pp; softcap 60%; floor 5%.
  static double prisonGuardSuccessChance({
    required int suspicion,
    required bool isShadow,
    required bool lawyerUsedThisStay,
  }) {
    double chance = 0.45;
    if (isShadow) chance += 0.10;
    if (lawyerUsedThisStay) chance += 0.05;
    chance -= (math.max(0, suspicion) / 10.0) * 0.01;
    if (chance > 0.60) chance = 0.60;
    if (chance < 0.05) chance = 0.05;
    return chance;
  }

  /// Success cut: 20% of remaining, clamp 10..60 minutes.
  static int prisonGuardSuccessCutMinutes(int remainingMinutes) {
    final int rem = remainingMinutes < 1 ? 1 : remainingMinutes;
    final int cut = (rem * 0.20).ceil();
    return cut.clamp(10, 60);
  }

  /// Gem/bail billable minutes: max(remaining, ceil(admit * 0.5)).
  static int gemBillableMinutes({
    required int remainingMinutes,
    int? admitMinutes,
  }) {
    final int rem = remainingMinutes < 1 ? 1 : remainingMinutes;
    if (admitMinutes == null || admitMinutes <= 0) return rem;
    final int floor = (admitMinutes * 0.5).ceil();
    return math.max(rem, floor);
  }

  /// Clinic cut %: 5% at L1 → 18% at L100.
  static double clinicCutPct(int clinicLevel) {
    if (clinicLevel < 1) return 0;
    if (clinicLevel >= 100) return 0.18;
    return 0.05 + ((clinicLevel - 1) / 99.0) * 0.13;
  }

  /// Clinic cut minutes: pct of remaining, clamp 5..45; never clears (leave ≥1).
  static int clinicCutMinutes({
    required int remainingMinutes,
    required int clinicLevel,
    required int monumentLevel,
  }) {
    if (clinicLevel < 1 || remainingMinutes < 1) return 0;
    double pct = clinicCutPct(clinicLevel);
    if (monumentLevel >= 60) pct *= 0.9;
    final int cut = (remainingMinutes * pct).ceil().clamp(5, 45);
    // Never instant: keep at least 1 minute of remaining after cut.
    if (cut >= remainingMinutes) {
      return math.max(0, remainingMinutes - 1);
    }
    return cut;
  }

  /// Doctor visit outcome buckets (roll in [0,1)).
  static String doctorOutcomeFromRoll(double roll) {
    if (roll < 0.45) return 'cut_20';
    if (roll < 0.75) return 'cut_10';
    return 'noop';
  }

  static int doctorCutMinutes(String outcome) {
    return switch (outcome) {
      'cut_20' => 20,
      'cut_10' => 10,
      _ => 0,
    };
  }

  /// Broad board time band — never exact minutes.
  static String wardTimeBand(Duration remaining) {
    if (remaining.inSeconds < 3600) return '<1h';
    if (remaining.inSeconds < 10800) return '1-3h';
    return '3h+';
  }
}
