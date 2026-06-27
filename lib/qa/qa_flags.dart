/// Compile-time QA flags for integration tests and screenshot audits.
abstract final class QaFlags {
  const QaFlags._();

  static bool _isTruthy(String value) => value == 'true' || value == '1';

  /// When true, [HomeScreen] does not auto-open the daily reward dialog.
  static bool get skipDailyRewardDialog {
    const String value = String.fromEnvironment('QA_SKIP_DAILY_REWARD');
    return _isTruthy(value);
  }

  /// When true, authenticated users can open `/onboarding/character-select`
  /// for screenshot audits (normally redirected to home).
  static bool get forceCharacterSelectRoute {
    const String value = String.fromEnvironment('QA_FORCE_CHARACTER_SELECT');
    return _isTruthy(value);
  }
}
