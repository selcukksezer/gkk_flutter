/// Master switch for in-game tutorial / coach overlays.
abstract final class TutorialFeatures {
  const TutorialFeatures._();

  /// Off in production — no coach, no opt-in, no settings replay.
  /// Tests may set `true` in `setUp` to exercise controller logic.
  static bool enabled = false;
}
