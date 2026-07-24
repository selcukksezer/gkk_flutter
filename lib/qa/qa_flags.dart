/// Compile-time QA flags for integration tests and screenshot audits.
abstract final class QaFlags {
  const QaFlags._();

  static bool _isTruthy(String value) => value == 'true' || value == '1';

  /// When true, [HomeScreen] does not auto-open the daily reward dialog.
  static bool get skipDailyRewardDialog {
    const String value = String.fromEnvironment('QA_SKIP_DAILY_REWARD');
    return _isTruthy(value);
  }

  /// When true, [HomeScreen] does not auto-open the comeback summary dialog.
  static bool get skipComebackSummaryDialog {
    const String value = String.fromEnvironment('QA_SKIP_COMEBACK_SUMMARY');
    return _isTruthy(value);
  }

  /// When true, tutorial overlays are suppressed.
  static bool get skipTutorial {
    const String value = String.fromEnvironment('QA_SKIP_TUTORIAL');
    return _isTruthy(value);
  }

  /// Force a specific tutorial step id (legacy v1 QA hook).
  static String? get forceTutorialStep {
    const String value = String.fromEnvironment('QA_FORCE_TUTORIAL_STEP');
    return value.isEmpty ? null : value;
  }

  /// Force a tutorial track id (e.g. onboarding, dungeon, season).
  static String? get forceTutorialTrack {
    const String value = String.fromEnvironment('QA_FORCE_TUTORIAL_TRACK');
    return value.isEmpty ? null : value;
  }

  /// When true, authenticated users can open `/onboarding/character-select`
  /// for screenshot audits (normally redirected to home).
  static bool get forceCharacterSelectRoute {
    const String value = String.fromEnvironment('QA_FORCE_CHARACTER_SELECT');
    return _isTruthy(value);
  }

  /// Screenshot audits: keep betting board visible instead of live overlay.
  static bool get skipHorseRaceLiveOverlay {
    const String value = String.fromEnvironment('QA_SKIP_HORSE_RACE_LIVE');
    return _isTruthy(value);
  }

  /// Allow [MockAdService] to grant rewards outside debug (integration tests).
  /// Release/profile builds ignore this unless explicitly set.
  static bool get allowMockAds {
    const String value = String.fromEnvironment('QA_ALLOW_MOCK_ADS');
    return _isTruthy(value);
  }

  /// Night market smoke: call RPC `qa_force_night_market(true)` once per test run.
  /// Server-side bypass lives in `_night_market_window` (`night_market_schedule.qa_force_open`).
  static bool get forceNightMarketOpen {
    const String value = String.fromEnvironment('QA_FORCE_NIGHT_MARKET');
    return _isTruthy(value);
  }
}
