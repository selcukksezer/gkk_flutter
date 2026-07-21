import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../qa/qa_flags.dart';
import 'tutorial_anchor_registry.dart';
import 'tutorial_persistence.dart';
import 'tutorial_step.dart';
import 'tutorial_track.dart';
import 'tutorial_track_registry.dart';

class TutorialState {
  const TutorialState({
    required this.loaded,
    required this.progress,
    this.activeTrackId,
    this.activeStep,
    this.wrongTapShake = 0,
    this.overlayPaused = false,
  });

  final bool loaded;
  final TutorialProgressState progress;
  final String? activeTrackId;
  final TutorialStepV2? activeStep;
  final int wrongTapShake;

  /// True when an active step exists but current route cannot show it.
  /// Progress kept; overlay hidden until matching route returns.
  final bool overlayPaused;

  factory TutorialState.initial() => TutorialState(
        loaded: false,
        progress: TutorialProgressState.initial(),
      );

  TutorialState copyWith({
    bool? loaded,
    TutorialProgressState? progress,
    String? activeTrackId,
    TutorialStepV2? activeStep,
    bool clearActive = false,
    int? wrongTapShake,
    bool? overlayPaused,
  }) {
    return TutorialState(
      loaded: loaded ?? this.loaded,
      progress: progress ?? this.progress,
      activeTrackId: clearActive ? null : (activeTrackId ?? this.activeTrackId),
      activeStep: clearActive ? null : (activeStep ?? this.activeStep),
      wrongTapShake: wrongTapShake ?? this.wrongTapShake,
      overlayPaused: clearActive ? false : (overlayPaused ?? this.overlayPaused),
    );
  }
}

class TutorialController extends Notifier<TutorialState> {
  String? _lastRoute;
  String? _pendingRoute;
  int _playerLevelHint = 0;
  bool _completing = false;

  @override
  TutorialState build() => TutorialState.initial();

  void setPlayerLevelHint(int level) {
    _playerLevelHint = level;
  }

  @visibleForTesting
  void debugSetState(TutorialState value) {
    state = value;
  }

  @visibleForTesting
  void debugSetLastRoute(String? route) {
    _lastRoute = route;
  }

  Future<void> initialize() async {
    if (QaFlags.skipTutorial) {
      state = TutorialState(
        loaded: true,
        progress: TutorialProgressState.initial().skipAll(),
      );
      return;
    }
    final TutorialProgressState progress = await TutorialPersistence.load();
    state = state.copyWith(loaded: true, progress: progress);
    _maybeForceTrack();
    final String? pending = _pendingRoute ?? _lastRoute;
    _pendingRoute = null;
    if (QaFlags.forceTutorialTrack == null &&
        pending != null &&
        state.activeTrackId == null) {
      await onRouteEnter(pending);
    }
  }

  void _maybeForceTrack() {
    final String? forced = QaFlags.forceTutorialTrack;
    if (forced == null || forced.isEmpty) return;
    if (TutorialTrackRegistry.trackById(forced) == null) return;
    _startTrack(forced, force: true);
  }

  bool isTrackComplete(String trackId) =>
      state.progress.isTrackComplete(trackId);

  bool get hasActiveTrack =>
      state.activeTrackId != null && state.activeStep != null;

  Future<void> onRouteEnter(String route) async {
    if (state.progress.skippedAll) return;
    _lastRoute = route;

    if (!state.loaded) {
      _pendingRoute = route;
      return;
    }

    if (hasActiveTrack) {
      final TutorialStepV2 step = state.activeStep!;
      if (_routeMatchesStep(route, step)) {
        if (state.overlayPaused) {
          state = state.copyWith(overlayPaused: false);
        }
        TutorialAnchorRegistry.instance.scheduleRefresh();
        return;
      }

      // Never soft-pause onboarding — keep coaching until dungeon tab done.
      if (state.activeTrackId == TutorialTrackId.onboarding) {
        TutorialAnchorRegistry.instance.scheduleRefresh();
        return;
      }

      // Soft-pause: hide overlay on wrong route, keep step progress.
      if (!state.overlayPaused) {
        state = state.copyWith(overlayPaused: true);
      }
      // Fall through: allow another incomplete track on this route to start
      // only when paused step is not a core-blocking onboarding.
    }

    final String? trackId = TutorialRouteTracks.trackForRoute(route);
    if (trackId == null) return;

    if (trackId == TutorialTrackId.onboarding && route == TutorialRoutes.home) {
      if (!isTrackComplete(TutorialTrackId.onboarding)) {
        if (hasActiveTrack &&
            state.activeTrackId != TutorialTrackId.onboarding) {
          return;
        }
        _startTrack(TutorialTrackId.onboarding);
      }
      return;
    }

    if (!isTrackComplete(TutorialTrackId.onboarding) &&
        trackId != TutorialTrackId.onboarding) {
      return;
    }

    // Soft-paused different track: don't replace until that track resumes
    // or completes — except when paused track != route track and route track
    // is incomplete (user left mid-flow intentionally).
    if (hasActiveTrack && state.overlayPaused) {
      if (state.activeTrackId == trackId) {
        return;
      }
      // Drop paused track from active so route track can start; progress kept.
      state = state.copyWith(clearActive: true);
    }

    if (isTrackComplete(trackId)) return;
    if (hasActiveTrack) return;
    _startTrack(trackId);
  }

  void _startTrack(String trackId, {bool force = false}) {
    if (!force && isTrackComplete(trackId)) return;
    if (!force && hasActiveTrack && state.activeTrackId != trackId) return;

    final List<TutorialStepV2> eligible = _eligibleStepsForTrack(trackId);
    if (eligible.isEmpty) {
      _completeTrack(trackId);
      return;
    }
    final TutorialStepV2 step = eligible.first;
    if (!force &&
        step.allowedRoutes.isNotEmpty &&
        _lastRoute != null &&
        !_routeAllowed(_lastRoute!, step.allowedRoutes)) {
      return;
    }
    state = state.copyWith(
      activeTrackId: trackId,
      activeStep: step,
      overlayPaused: false,
    );
    TutorialAnchorRegistry.instance.scheduleRefresh();
  }

  Future<void> onAnchorTap(String anchorId) async {
    final TutorialStepV2? step = state.activeStep;
    if (step == null || state.overlayPaused) return;
    if (step.anchorId != anchorId) return;
    // spotlightTap / highlightOnly / explicit onTapAnchor may complete by tap.
    // onGameEvent steps must not advance from a stray anchor tap.
    if (step.completion == TutorialCompletion.onGameEvent) return;
    if (step.completion != TutorialCompletion.onTapAnchor &&
        step.mode != TutorialMode.spotlightTap &&
        step.mode != TutorialMode.highlightOnly) {
      return;
    }
    await _completeActiveStep();
  }

  Future<void> onGameEvent(String eventId) async {
    final TutorialStepV2? step = state.activeStep;
    if (step == null || state.overlayPaused) return;
    if (step.completion != TutorialCompletion.onGameEvent) return;
    if (step.gameEvent != eventId) return;
    await _completeActiveStep();
  }

  Future<void> completeActiveManual() async {
    final TutorialStepV2? step = state.activeStep;
    if (step == null || state.overlayPaused) return;
    if (step.mode != TutorialMode.narrative &&
        step.completion != TutorialCompletion.onManualDismiss) {
      return;
    }
    await _completeActiveStep();
  }

  Future<void> _completeActiveStep() async {
    if (_completing) return;
    _completing = true;
    try {
      final TutorialStepV2? step = state.activeStep;
      final String? trackId = state.activeTrackId;
      if (step == null || trackId == null) return;

      TutorialProgressState next = state.progress.completeStep(
        trackId: trackId,
        stepId: step.id,
      );

      final List<TutorialStepV2> remaining = TutorialTrackRegistry.eligibleSteps(
        trackId: trackId,
        completedStepIds: next.stepsForTrack(trackId),
        playerLevel: _playerLevelHint,
      );

      if (remaining.isEmpty) {
        next = next.completeTrack(trackId);
        state = state.copyWith(progress: next, clearActive: true);
        await TutorialPersistence.save(next);
        if (_lastRoute != null) {
          await onRouteEnter(_lastRoute!);
        }
        return;
      }

      final TutorialStepV2 nextStep = remaining.first;
      final bool pauseForRoute = nextStep.allowedRoutes.isNotEmpty &&
          _lastRoute != null &&
          !_routeAllowed(_lastRoute!, nextStep.allowedRoutes);

      state = state.copyWith(
        progress: next,
        activeStep: nextStep,
        overlayPaused: pauseForRoute,
      );
      await TutorialPersistence.save(next);
      TutorialAnchorRegistry.instance.scheduleRefresh();
    } finally {
      _completing = false;
    }
  }

  void _completeTrack(String trackId) {
    if (isTrackComplete(trackId)) return;
    final TutorialProgressState next = state.progress.completeTrack(trackId);
    state = state.copyWith(progress: next, clearActive: true);
    TutorialPersistence.save(next);
  }

  void registerWrongTap() {
    state = state.copyWith(wrongTapShake: state.wrongTapShake + 1);
  }

  Future<void> skipAll() async {
    TutorialProgressState next = state.progress;
    for (final TutorialTrack track in TutorialTrackRegistry.tracks) {
      next = next.completeTrack(track.id);
    }
    next = next.skipAll();
    state = state.copyWith(progress: next, clearActive: true);
    await TutorialPersistence.save(next);
  }

  /// Starts a track only when nothing else is active (or same track).
  /// Does not interrupt onboarding / mid-flow coaching.
  Future<void> startTrack(String trackId) async {
    if (!state.loaded || state.progress.skippedAll) return;
    if (hasActiveTrack && state.activeTrackId != trackId) return;
    if (!isTrackComplete(TutorialTrackId.onboarding) &&
        trackId != TutorialTrackId.onboarding) {
      return;
    }
    _startTrack(trackId, force: true);
  }

  List<TutorialStepV2> _eligibleStepsForTrack(String trackId) {
    return TutorialTrackRegistry.eligibleSteps(
      trackId: trackId,
      completedStepIds: state.progress.stepsForTrack(trackId),
      playerLevel: _playerLevelHint,
    );
  }

  bool allowsNavTab(int tabIndex) {
    final TutorialStepV2? step = state.activeStep;
    if (step == null || state.overlayPaused) return true;

    // Spotlight on a nav tab → only that tab is tappable.
    if (step.anchorId != null && step.anchorId!.startsWith('nav.')) {
      return anchorForNavIndex(tabIndex) == step.anchorId;
    }

    if (step.trackId != TutorialTrackId.onboarding) return true;
    return false;
  }

  /// Returns true if navigation to [route] should be blocked during tutorial.
  bool blocksNavigation(String route) {
    final TutorialStepV2? step = state.activeStep;
    if (step == null || state.overlayPaused) return false;
    if (step.trackId != TutorialTrackId.onboarding) return false;
    if (step.id != 'onboarding_tap_dungeon_tab') return true;
    return route != TutorialRoutes.dungeon &&
        route != TutorialRoutes.home &&
        !route.startsWith('${TutorialRoutes.dungeon}/');
  }

  String? anchorForNavIndex(int index) {
    switch (index) {
      case 1:
        return TutorialAnchorId.navInventoryTab;
      case 2:
        return TutorialAnchorId.navDungeonTab;
      case 3:
        return TutorialAnchorId.navCharacterTab;
      case 4:
        return TutorialAnchorId.navMenuTab;
      default:
        return null;
    }
  }

  static bool _routeAllowed(String route, List<String> allowed) {
    if (allowed.isEmpty) return true;
    for (final String a in allowed) {
      if (route == a || route.startsWith('$a/')) return true;
    }
    return false;
  }

  static bool _routeMatchesStep(String route, TutorialStepV2 step) {
    if (step.allowedRoutes.isNotEmpty) {
      return _routeAllowed(route, step.allowedRoutes);
    }
    // Battle / confirm steps live under dungeon without explicit allow-list.
    if (step.trackId == TutorialTrackId.dungeon) {
      return route == TutorialRoutes.dungeon ||
          route.startsWith('${TutorialRoutes.dungeon}/');
    }
    if (step.trackId == TutorialTrackId.inventory) {
      return route == TutorialRoutes.inventory;
    }
    if (step.trackId == TutorialTrackId.onboarding) {
      return route == TutorialRoutes.home;
    }
    final String? trackRoute = TutorialTrackRegistry.trackById(step.trackId)
        ?.triggerRoute;
    if (trackRoute == null) return true;
    return route == trackRoute || route.startsWith('$trackRoute/');
  }
}

final NotifierProvider<TutorialController, TutorialState> tutorialProvider =
    NotifierProvider<TutorialController, TutorialState>(TutorialController.new);
