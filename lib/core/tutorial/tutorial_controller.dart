import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../qa/qa_flags.dart';
import 'home_live_flags.dart';
import 'tutorial_anchor_registry.dart';
import 'tutorial_features.dart';
import 'tutorial_modal_suppress.dart';
import 'tutorial_navigation.dart';
import 'tutorial_persistence.dart';
import 'tutorial_step.dart';
import 'tutorial_track.dart';
import 'tutorial_track_registry.dart';

/// Progress flag: user accepted first-home tutorial opt-in.
const String kTutorialOptInAcceptedFlag = 'tutorial_opt_in_accepted';

class TutorialState {
  const TutorialState({
    required this.loaded,
    required this.progress,
    this.activeTrackId,
    this.activeStep,
    this.wrongTapShake = 0,
    this.overlayPaused = false,
    this.coachEpoch = 0,
    this.forceShowManualCta = false,
    this.coachBodyOverride,
  });

  final bool loaded;
  final TutorialProgressState progress;
  final String? activeTrackId;
  final TutorialStepV2? activeStep;
  final int wrongTapShake;

  /// True when an active step exists but current route cannot show it.
  /// Progress kept; overlay hidden until matching route returns.
  final bool overlayPaused;

  /// Bumped on settings replay so coach overlay remounts clean (HUD holes).
  final int coachEpoch;

  /// Screen-driven bypass (e.g. no scroll/item for enhance) → show Devam.
  final bool forceShowManualCta;

  /// Optional body while [forceShowManualCta] is on.
  final String? coachBodyOverride;

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
    int? coachEpoch,
    bool? forceShowManualCta,
    String? coachBodyOverride,
    bool clearCoachBodyOverride = false,
  }) {
    return TutorialState(
      loaded: loaded ?? this.loaded,
      progress: progress ?? this.progress,
      activeTrackId: clearActive ? null : (activeTrackId ?? this.activeTrackId),
      activeStep: clearActive ? null : (activeStep ?? this.activeStep),
      wrongTapShake: wrongTapShake ?? this.wrongTapShake,
      overlayPaused: clearActive ? false : (overlayPaused ?? this.overlayPaused),
      coachEpoch: coachEpoch ?? this.coachEpoch,
      forceShowManualCta:
          clearActive ? false : (forceShowManualCta ?? this.forceShowManualCta),
      coachBodyOverride: clearActive || clearCoachBodyOverride
          ? null
          : (coachBodyOverride ?? this.coachBodyOverride),
    );
  }
}

class TutorialController extends Notifier<TutorialState> {
  String? _lastRoute;
  String? _pendingRoute;
  String? _pendingGameEvent;
  int _playerLevelHint = 0;
  bool _completing = false;
  bool _holdDungeonWinOverlay = false;
  String? _loadedForAuthId;
  bool _initializing = false;

  @override
  TutorialState build() => TutorialState.initial();

  void setPlayerLevelHint(int level) {
    _playerLevelHint = level;
  }

  /// Enhancement (etc.) enables Devam when required items/materials missing.
  void setCoachBypass({required bool enabled, String? body}) {
    if (state.forceShowManualCta == enabled &&
        state.coachBodyOverride == body) {
      return;
    }
    state = state.copyWith(
      forceShowManualCta: enabled,
      coachBodyOverride: body,
      clearCoachBodyOverride: !enabled || body == null,
    );
  }

  @visibleForTesting
  void debugSetState(TutorialState value) {
    state = value;
  }

  @visibleForTesting
  void debugSetLastRoute(String? route) {
    _lastRoute = route;
  }

  /// Test-only: last synced route (must clear on logout / auth switch).
  String? get debugLastRoute => _lastRoute;

  String? get _currentAuthId => TutorialPersistence.currentAuthId;

  /// Loads (or reloads) tutorial for the current auth user.
  /// Call again after login/register/logout so device cache cannot leak.
  Future<void> initialize({bool force = false}) async {
    final String? authId = _currentAuthId;
    if (!force && state.loaded && _loadedForAuthId == authId) {
      return;
    }
    if (_initializing) return;
    _initializing = true;
    try {
      final bool authChanged = _loadedForAuthId != authId;
      // New account / force reload must not inherit prior user's route memory
      // (otherwise pending home → start onboarding → pause banner on class pick).
      if (force || authChanged) {
        _lastRoute = null;
        _pendingRoute = null;
        _pendingGameEvent = null;
        _holdDungeonWinOverlay = false;
      }
      if (!TutorialFeatures.enabled || QaFlags.skipTutorial) {
        _loadedForAuthId = authId;
        final TutorialProgressState killed =
            TutorialProgressState.initial().skipAll();
        // Wipe in-progress coach so it never resumes after re-enable.
        if (!TutorialFeatures.enabled) {
          await TutorialPersistence.save(killed);
        }
        state = TutorialState(
          loaded: true,
          progress: killed,
        );
        return;
      }
      // Drop previous account's active coach before loading.
      state = TutorialState.initial();
      await HomeLiveFlags.load();
      final TutorialProgressState progress = await TutorialPersistence.load();
      _loadedForAuthId = authId;
      state = state.copyWith(loaded: true, progress: progress);
      _maybeForceTrack();
      final String? pending = _pendingRoute ?? _lastRoute;
      _pendingRoute = null;
      if (QaFlags.forceTutorialTrack == null &&
          pending != null &&
          state.activeTrackId == null) {
        await onRouteEnter(pending);
      }
    } finally {
      _initializing = false;
    }
  }

  /// Clears in-memory coach (logout). Prefs stay per-user on disk.
  void clearSession() {
    _loadedForAuthId = null;
    _pendingRoute = null;
    _pendingGameEvent = null;
    _holdDungeonWinOverlay = false;
    _lastRoute = null;
    state = TutorialState.initial();
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

  /// Fresh account on home: ask before starting onboarding coach.
  bool get needsTutorialOptIn {
    if (!state.loaded || state.progress.skippedAll) return false;
    if (state.progress.hasFlag(kTutorialOptInAcceptedFlag)) return false;
    if (isTrackComplete(TutorialTrackId.onboarding)) return false;
    if (hasActiveTrack) return false;
    if (state.progress.completedTracks.isNotEmpty) return false;
    for (final Set<String> steps in state.progress.stepsByTrack.values) {
      if (steps.isNotEmpty) return false;
    }
    return true;
  }

  Future<void> acceptTutorialOptIn() async {
    if (!TutorialFeatures.enabled || state.progress.skippedAll) return;
    await setProgressFlag(kTutorialOptInAcceptedFlag);
    if (_lastRoute == TutorialRoutes.home || _lastRoute == null) {
      _lastRoute = TutorialRoutes.home;
      _startTrack(TutorialTrackId.onboarding, force: true);
    }
  }

  Future<void> declineTutorialOptIn() async {
    await skipAll();
  }

  Future<void> onRouteEnter(String route) async {
    if (!TutorialFeatures.enabled || state.progress.skippedAll) return;
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
          _flushPendingGameEvent();
        }
        TutorialAnchorRegistry.instance.scheduleRefresh();
        return;
      }

      // Soft-pause: hide overlay on wrong route, keep step progress.
      // Onboarding included — core-pin below prevents track drop.
      if (!state.overlayPaused) {
        state = state.copyWith(overlayPaused: true);
      }
      // Fall through: allow another incomplete track on this route to start
      // only when paused step is not a pinned core track.
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

    if (_maybeStartDailyChain(route)) return;

    // Soft-paused different track: don't replace until that track resumes
    // or completes — except when paused track != route track and route track
    // is incomplete (user left mid-flow intentionally).
    // Core tracks stay pinned: never clearActive while paused mid-core.
    if (hasActiveTrack && state.overlayPaused) {
      if (state.activeTrackId == trackId) {
        return;
      }
      if (_isCoreTrack(state.activeTrackId)) {
        return;
      }
      // Drop paused non-core track from active so route track can start;
      // progress kept.
      state = state.copyWith(clearActive: true);
    }

    // Shop complete → optional night market coach on same route.
    if (trackId == TutorialTrackId.shop && isTrackComplete(trackId)) {
      if (!isTrackComplete(TutorialTrackId.nightMarket) && !hasActiveTrack) {
        _startTrack(TutorialTrackId.nightMarket);
      }
      return;
    }

    if (isTrackComplete(trackId)) return;
    if (hasActiveTrack) return;
    _startTrack(trackId);
  }

  void _startTrack(String trackId, {bool force = false}) {
    if (!TutorialFeatures.enabled) return;
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
    if (_lastRoute != null &&
        step.allowedRoutes.isNotEmpty &&
        !_routeAllowed(_lastRoute!, step.allowedRoutes)) {
      state = state.copyWith(overlayPaused: true);
      _maybeAutoNavigate(step);
    }
  }

  Future<void> onAnchorTap(String anchorId) async {
    final TutorialStepV2? step = state.activeStep;
    if (step == null || state.overlayPaused) return;
    if (step.anchorId != anchorId) return;
    // spotlightTap / highlightOnly / explicit onTapAnchor may complete by tap.
    // onGameEvent steps must not advance from a stray anchor tap.
    if (step.completion == TutorialCompletion.onGameEvent) return;
    if (step.completion == TutorialCompletion.onManualDismiss) return;
    if (step.completion != TutorialCompletion.onTapAnchor &&
        step.mode != TutorialMode.spotlightTap &&
        step.mode != TutorialMode.highlightOnly) {
      return;
    }
    await _completeActiveStep();
  }

  Future<void> onGameEvent(String eventId) async {
    final TutorialStepV2? step = state.activeStep;
    if (step == null || state.overlayPaused) {
      _pendingGameEvent = eventId;
      return;
    }
    if (step.completion != TutorialCompletion.onGameEvent) {
      _pendingGameEvent = eventId;
      return;
    }
    if (step.gameEvent != eventId) return;
    _pendingGameEvent = null;
    await _completeActiveStep();
  }

  void _flushPendingGameEvent() {
    final String? pending = _pendingGameEvent;
    if (pending == null) return;
    final TutorialStepV2? step = state.activeStep;
    if (step == null ||
        step.completion != TutorialCompletion.onGameEvent ||
        step.gameEvent != pending) {
      if (step != null && step.completion != TutorialCompletion.onGameEvent) {
        _pendingGameEvent = null;
      }
      return;
    }
    _pendingGameEvent = null;
    unawaited(_completeActiveStep());
  }

  /// Shows [dungeon_first_win] after battle success when confirm step deferred it.
  Future<bool> revealHeldDungeonWin() async {
    if (!_holdDungeonWinOverlay) return false;
    final TutorialStepV2? step =
        TutorialTrackRegistry.stepById('dungeon_first_win');
    if (step == null) {
      _holdDungeonWinOverlay = false;
      return false;
    }
    _holdDungeonWinOverlay = false;
    state = state.copyWith(
      activeTrackId: TutorialTrackId.dungeon,
      activeStep: step,
      overlayPaused: false,
    );
    TutorialAnchorRegistry.instance.scheduleRefresh();
    return true;
  }

  /// Battle loss — keep win-hold armed so a later win still reveals
  /// [dungeon_first_win]. (Attack coach step removed; nothing to restore.)
  void cancelHeldDungeonWin() {}

  Future<void> completeActiveManual() async {
    final TutorialStepV2? step = state.activeStep;
    if (step == null || state.overlayPaused) return;
    if (step.requiresNavTap) return;
    if (step.anchorId == TutorialAnchorId.dungeonZone1Tab) return;
    final bool manualMode = step.mode == TutorialMode.narrative ||
        step.completion == TutorialCompletion.onManualDismiss ||
        state.forceShowManualCta;
    if (!manualMode) return;
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
        homeLive: HomeLiveFlags.livelinessHome,
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

      // After confirm → battle; hide coach until win (no "tap Saldır" step).
      if (step.id == 'dungeon_confirm_enter') {
        _holdDungeonWinOverlay = true;
        state = state.copyWith(progress: next, clearActive: true);
        await TutorialPersistence.save(next.clearHardResetFlag());
        TutorialAnchorRegistry.instance.scheduleRefresh();
        return;
      }

      final bool pauseForRoute = nextStep.allowedRoutes.isNotEmpty &&
          _lastRoute != null &&
          !_routeAllowed(_lastRoute!, nextStep.allowedRoutes);

      state = state.copyWith(
        progress: next,
        activeStep: nextStep,
        overlayPaused: pauseForRoute,
        forceShowManualCta: false,
        clearCoachBodyOverride: true,
      );
      await TutorialPersistence.save(next.clearHardResetFlag());
      TutorialAnchorRegistry.instance.scheduleRefresh();
      if (pauseForRoute) {
        _maybeAutoNavigate(nextStep);
      }
      _flushPendingGameEvent();
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

  /// Resume coach at the first incomplete core step (settings).
  ///
  /// Does NOT wipe progress — avoids replay loops (e.g. enhance again when
  /// already upgraded). Skipped-all falls back to [resetAndReplay].
  ///
  /// Returns the route navigated to, or null if core already complete.
  Future<String?> resumeFromProgress() async {
    TutorialModalSuppress.instance.resetForReplay();
    _pendingRoute = null;
    _pendingGameEvent = null;
    _holdDungeonWinOverlay = false;
    _completing = false;
    TutorialAnchorRegistry.instance.pruneDetached();

    if (!state.loaded) {
      await initialize(force: true);
    }

    if (state.progress.skippedAll) {
      await resetAndReplay();
      return TutorialRoutes.home;
    }

    // Prefer current active step (user dismissed / left mid-flow).
    TutorialStepV2? step = state.activeStep;
    String? trackId = state.activeTrackId;
    if (step == null ||
        trackId == null ||
        state.progress.isTrackComplete(trackId)) {
      trackId = null;
      step = null;
      for (final String id in TutorialTrackId.coreTracks) {
        if (state.progress.isTrackComplete(id)) continue;
        final List<TutorialStepV2> eligible = _eligibleStepsForTrack(id);
        if (eligible.isEmpty) continue;
        trackId = id;
        step = eligible.first;
        break;
      }
    }

    if (trackId == null || step == null) {
      state = state.copyWith(clearActive: true);
      return null;
    }

    final String route =
        step.navigateToRoute ?? step.preferredRoute ?? TutorialRoutes.home;

    _lastRoute = route;
    state = state.copyWith(
      clearActive: true,
      loaded: true,
      overlayPaused: false,
      coachEpoch: state.coachEpoch + 1,
    );
    _startTrack(trackId, force: true);
    if (state.overlayPaused) {
      state = state.copyWith(overlayPaused: false);
    }

    await TutorialNavigationBridge.go(route);
    _lastRoute = route;
    await onRouteEnter(route);
    // Ensure pause cleared after route enter soft-pause edge cases.
    if (state.activeStep != null &&
        state.activeStep!.allowedRoutes.isNotEmpty &&
        _routeAllowed(route, state.activeStep!.allowedRoutes)) {
      state = state.copyWith(overlayPaused: false);
    }
    TutorialAnchorRegistry.instance.scheduleRefresh();
    return route;
  }

  /// Clears progress and restarts onboarding (settings hard reset).
  ///
  /// Call AFTER navigating to home so HUD anchors exist when coaching starts.
  Future<void> resetAndReplay({String trackId = TutorialTrackId.onboarding}) async {
    // Dialog/route suppress can leak across settings confirm → hide coach or
    // leave stale hit-test. Always clear on replay.
    TutorialModalSuppress.instance.resetForReplay();

    // Mid-flow leftovers from the previous run must not survive replay.
    _pendingRoute = null;
    _pendingGameEvent = null;
    _holdDungeonWinOverlay = false;
    _completing = false;
    // Pretend we are already on home BEFORE startTrack — otherwise lastRoute
    // still points at /settings → overlayPaused + broken holes.
    _lastRoute = TutorialRoutes.home;

    await TutorialPersistence.hardReset();
    await HomeLiveFlags.load();
    TutorialAnchorRegistry.instance.pruneDetached();
    final TutorialProgressState next =
        TutorialProgressState.initial(hardReset: true)
            .withFlag(kTutorialOptInAcceptedFlag);
    state = state.copyWith(
      progress: next,
      clearActive: true,
      loaded: true,
      overlayPaused: false,
      coachEpoch: state.coachEpoch + 1,
    );
    TutorialAnchorRegistry.instance.scheduleRefresh();
    _startTrack(trackId, force: true);
    // Defensive: startTrack must not leave coach paused on home.
    if (state.overlayPaused) {
      state = state.copyWith(overlayPaused: false);
    }
    await TutorialPersistence.save(state.progress.clearHardResetFlag());
    TutorialAnchorRegistry.instance.scheduleRefresh();
  }

  /// Call after navigating home from settings replay.
  Future<void> ensureVisibleOnRoute(String route) async {
    _lastRoute = route;
    if (state.progress.skippedAll) return;
    TutorialModalSuppress.instance.resetForReplay();
    _holdDungeonWinOverlay = false;
    _completing = false;
    if (!hasActiveTrack) {
      _startTrack(TutorialTrackId.onboarding, force: true);
    }
    state = state.copyWith(overlayPaused: false);
    TutorialAnchorRegistry.instance.scheduleRefresh();
    await onRouteEnter(route);
    // Second refresh after home chrome / HUD chips lay out.
    TutorialAnchorRegistry.instance.scheduleRefresh();
  }

  Future<void> navigateToActiveStepRoute() async {
    final TutorialStepV2? step = state.activeStep;
    if (step == null) return;
    final String? route = step.navigateToRoute ?? step.preferredRoute;
    if (route == null) return;
    await TutorialNavigationBridge.go(route);
    // Prefer real router sync; still apply immediately so pause clears even if
    // ListenableBuilder is late one frame.
    _lastRoute = route;
    await onRouteEnter(route);
  }

  String? get pausedRouteHint {
    if (!state.overlayPaused || state.activeStep == null) return null;
    final String? route =
        state.activeStep!.navigateToRoute ?? state.activeStep!.preferredRoute;
    if (route == null) return null;
    return TutorialRouteLabels.labelFor(route);
  }

  void _maybeAutoNavigate(TutorialStepV2 step) {
    if (!step.autoNavigateWhenPaused) return;
    final String? route = step.navigateToRoute ?? step.preferredRoute;
    if (route == null || _lastRoute == null) return;
    if (_routeAllowed(_lastRoute!, <String>[route])) return;
    TutorialNavigationBridge.go(route);
  }

  /// Marks a progress flag (e.g. bank full dialog) without completing a step.
  Future<void> setProgressFlag(String flag) async {
    if (state.progress.hasFlag(flag)) return;
    final TutorialProgressState next = state.progress.withFlag(flag);
    state = state.copyWith(progress: next);
    await TutorialPersistence.save(next);
  }

  bool hasProgressFlag(String flag) => state.progress.hasFlag(flag);

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
      homeLive: HomeLiveFlags.livelinessHome,
    );
  }

  bool _maybeStartDailyChain(String route) {
    if (state.progress.skippedAll) return false;
    if (!state.progress.coreCompleted) return false;
    if (isTrackComplete(TutorialTrackId.dailyChain)) return false;
    if (hasActiveTrack && !state.overlayPaused) return false;

    final TutorialStepV2? next = TutorialTrackRegistry.nextDailyChainStep(
      state.progress.stepsForTrack(TutorialTrackId.dailyChain),
    );
    if (next == null) {
      _completeTrack(TutorialTrackId.dailyChain);
      return false;
    }
    if (!_routeAllowed(route, next.allowedRoutes)) return false;

    if (hasActiveTrack && state.overlayPaused) {
      if (_isCoreTrack(state.activeTrackId)) {
        return false;
      }
      state = state.copyWith(clearActive: true);
    }
    _startTrack(TutorialTrackId.dailyChain, force: true);
    return true;
  }

  bool allowsNavTab(int tabIndex) {
    final TutorialStepV2? step = state.activeStep;
    if (step == null || state.overlayPaused) return true;

    if (step.anchorId != null && step.anchorId!.startsWith('nav.')) {
      return anchorForNavIndex(tabIndex) == step.anchorId;
    }

    if (step.trackId != TutorialTrackId.onboarding) return true;

    // Onboarding: lock bottom tabs until dungeon-tab step (or matching nav).
    return false;
  }

  /// Returns true if navigation to [route] should be blocked during tutorial.
  bool blocksNavigation(String route) {
    final TutorialStepV2? step = state.activeStep;
    if (step == null || state.overlayPaused) return false;
    if (step.trackId != TutorialTrackId.onboarding) return false;
    if (step.id == 'onboarding_tap_dungeon_tab') {
      return route != TutorialRoutes.dungeon &&
          route != TutorialRoutes.home &&
          !route.startsWith('${TutorialRoutes.dungeon}/');
    }
    // Other onboarding steps stay on home.
    return route != TutorialRoutes.home;
  }

  static bool _isCoreTrack(String? trackId) {
    if (trackId == null) return false;
    return TutorialTrackId.coreTracks.contains(trackId);
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
    // Nav-tab coach marks: stay live on any main shell route (bottom bar).
    // Pause-banner + Git is only for steps that require a different screen body.
    if (step.anchorId != null && step.anchorId!.startsWith('nav.')) {
      return _isShellRoute(route);
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

  static bool _isShellRoute(String route) {
    return route == TutorialRoutes.home ||
        route == TutorialRoutes.inventory ||
        route == TutorialRoutes.dungeon ||
        route == TutorialRoutes.character ||
        route.startsWith('${TutorialRoutes.dungeon}/');
  }
}

final NotifierProvider<TutorialController, TutorialState> tutorialProvider =
    NotifierProvider<TutorialController, TutorialState>(TutorialController.new);
