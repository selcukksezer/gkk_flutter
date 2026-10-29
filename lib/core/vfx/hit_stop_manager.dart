import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Represents an independent channel for time dilation in the game engine.
///
/// Different subsystems (e.g. attacker, target, camera, particle VFX) can have
/// distinct time scales during combat impact frames. For instance, character
/// models can be micro-frozen at time scale 0.0 while directional camera shake
/// and particle sparks remain fluid at time scale 1.0.
enum TimeDilationChannel {
  /// Global game clock channel affecting the entire scene unless overridden.
  global,

  /// The attacking entity or character initiating the combat strike.
  attacker,

  /// The target / receiver of the impact.
  target,

  /// Camera movement, orbital controls, and directional trauma shakes.
  camera,

  /// Particle VFX, mesh ribbon trails, spark bursts, and decals.
  vfx,

  /// Background scenery, foliage wind displacement, and interactive props.
  environment,

  /// Combat HUD, floating damage numbers, and UI animations.
  ui,

  /// Custom auxiliary channel 1 (e.g. boss limbs, destructible parts).
  custom1,

  /// Custom auxiliary channel 2.
  custom2,

  /// Custom auxiliary channel 3.
  custom3;

  /// Default combat impact channels: attacker and target freeze frame.
  static const Set<TimeDilationChannel> combatPair = <TimeDilationChannel>{
    TimeDilationChannel.attacker,
    TimeDilationChannel.target,
  };

  /// All standard channels combined.
  static const Set<TimeDilationChannel> allStandard = <TimeDilationChannel>{
    TimeDilationChannel.global,
    TimeDilationChannel.attacker,
    TimeDilationChannel.target,
    TimeDilationChannel.camera,
    TimeDilationChannel.vfx,
    TimeDilationChannel.environment,
    TimeDilationChannel.ui,
  };
}

/// Pre-configured AAA hit-stop presets according to R3 combat specs.
enum HitStopPreset {
  /// 30ms light attack micro-freeze (quick jab, light arrow, dagger hit).
  light,

  /// 45ms medium attack impact (sword slash, blunt mace strike).
  medium,

  /// 60ms heavy finisher or critical hit (greatsword smash, executioner chop).
  heavy,

  /// 80ms massive boss shockwave, parry stagger, or cinematic stagger.
  critical,

  /// 15ms glancing deflection / shield block micro-tick.
  glance,

  /// 160ms cinematic bullet-time slow-mo (10% speed).
  bulletTime,
}

/// Curve applied during the resumption phase to transition smoothly back to 1.0.
///
/// Prevents frame pacing jerk, camera snapping, and physics integrator instability.
enum HitStopResumptionCurve {
  /// Instant cut: jumps directly from target time scale to 1.0.
  instant,

  /// Linear interpolation over the ease-out period.
  linear,

  /// Quadratic ease-out: 1 - (1 - t)^2.
  easeOutQuad,

  /// Cubic hermite smoothstep: t * t * (3 - 2 * t).
  smoothStep,

  /// Cubic ease-out: 1 - (1 - t)^3.
  easeOutCubic,
}

/// Policy for handling conflicts when a new hit-stop is triggered on a channel
/// that is already undergoing an active hit-stop.
enum HitStopConflictPolicy {
  /// Extends remaining freeze duration if the new duration is greater than remaining.
  extend,

  /// Immediately interrupts the active hit-stop and starts the new one.
  override,

  /// Appends the new hit-stop into a FIFO queue to execute once the active one finishes.
  queue,

  /// Blends concurrently: takes the minimum time scale and maximum remaining duration.
  blend,

  /// Ignores the new request if the channel is already frozen.
  ignoreIfActive,
}

/// Immutable configuration descriptor for a hit-stop micro-freeze request.
@immutable
class HitStopRequest {
  /// Unique identifier or tag for this hit stop request.
  final String id;

  /// Duration of the absolute freeze phase (timeScale = [targetTimeScale]).
  final Duration freezeDuration;

  /// Duration of the smooth resumption ramp back to 1.0.
  final Duration easeOutDuration;

  /// Target time scale during the freeze phase (0.0 = complete freeze frame).
  final double targetTimeScale;

  /// Set of channels affected by this hit stop.
  final Set<TimeDilationChannel> channels;

  /// Resumption easing curve.
  final HitStopResumptionCurve resumptionCurve;

  /// Conflict resolution policy.
  final HitStopConflictPolicy conflictPolicy;

  /// Priority of this request. Higher priority requests preempt lower priority ones.
  final int priority;

  /// Optional custom easing curve function `(double t) -> double`.
  final double Function(double t)? customCurve;

  /// Callback when hit stop begins.
  final VoidCallback? onStart;

  /// Callback when hit stop completes its full duration.
  final VoidCallback? onComplete;

  const HitStopRequest({
    required this.id,
    required this.freezeDuration,
    this.easeOutDuration = const Duration(milliseconds: 15),
    this.targetTimeScale = 0.0,
    this.channels = TimeDilationChannel.combatPair,
    this.resumptionCurve = HitStopResumptionCurve.smoothStep,
    this.conflictPolicy = HitStopConflictPolicy.extend,
    this.priority = 0,
    this.customCurve,
    this.onStart,
    this.onComplete,
  })  : assert(targetTimeScale >= 0.0, 'targetTimeScale must be non-negative'),
        assert(priority >= 0, 'priority must be non-negative');

  /// Total duration including freeze and ease-out phases.
  Duration get totalDuration => freezeDuration + easeOutDuration;

  /// Freeze duration in seconds.
  double get freezeSeconds => freezeDuration.inMicroseconds / 1000000.0;

  /// Ease out duration in seconds.
  double get easeOutSeconds => easeOutDuration.inMicroseconds / 1000000.0;

  /// Total duration in seconds.
  double get totalSeconds => totalDuration.inMicroseconds / 1000000.0;

  /// Creates a [HitStopRequest] from a predefined [HitStopPreset].
  factory HitStopRequest.fromPreset(
    HitStopPreset preset, {
    String? id,
    Set<TimeDilationChannel>? channels,
    HitStopConflictPolicy? conflictPolicy,
    int? priority,
    VoidCallback? onStart,
    VoidCallback? onComplete,
  }) {
    final String reqId = id ?? 'preset_${preset.name}_${DateTime.now().microsecondsSinceEpoch}';
    final Set<TimeDilationChannel> targetChannels = channels ?? TimeDilationChannel.combatPair;

    switch (preset) {
      case HitStopPreset.light:
        return HitStopRequest(
          id: reqId,
          freezeDuration: const Duration(milliseconds: 25),
          easeOutDuration: const Duration(milliseconds: 10), // Total 35ms (~30ms target)
          targetTimeScale: 0.0,
          channels: targetChannels,
          resumptionCurve: HitStopResumptionCurve.smoothStep,
          conflictPolicy: conflictPolicy ?? HitStopConflictPolicy.extend,
          priority: priority ?? 1,
          onStart: onStart,
          onComplete: onComplete,
        );
      case HitStopPreset.medium:
        return HitStopRequest(
          id: reqId,
          freezeDuration: const Duration(milliseconds: 35),
          easeOutDuration: const Duration(milliseconds: 15), // Total 50ms (~45ms target)
          targetTimeScale: 0.0,
          channels: targetChannels,
          resumptionCurve: HitStopResumptionCurve.smoothStep,
          conflictPolicy: conflictPolicy ?? HitStopConflictPolicy.extend,
          priority: priority ?? 2,
          onStart: onStart,
          onComplete: onComplete,
        );
      case HitStopPreset.heavy:
        return HitStopRequest(
          id: reqId,
          freezeDuration: const Duration(milliseconds: 45),
          easeOutDuration: const Duration(milliseconds: 18), // Total 63ms (~60ms target)
          targetTimeScale: 0.0,
          channels: targetChannels,
          resumptionCurve: HitStopResumptionCurve.easeOutCubic,
          conflictPolicy: conflictPolicy ?? HitStopConflictPolicy.override,
          priority: priority ?? 3,
          onStart: onStart,
          onComplete: onComplete,
        );
      case HitStopPreset.critical:
        return HitStopRequest(
          id: reqId,
          freezeDuration: const Duration(milliseconds: 60),
          easeOutDuration: const Duration(milliseconds: 20), // Total 80ms
          targetTimeScale: 0.0,
          channels: targetChannels,
          resumptionCurve: HitStopResumptionCurve.easeOutCubic,
          conflictPolicy: conflictPolicy ?? HitStopConflictPolicy.override,
          priority: priority ?? 4,
          onStart: onStart,
          onComplete: onComplete,
        );
      case HitStopPreset.glance:
        return HitStopRequest(
          id: reqId,
          freezeDuration: const Duration(milliseconds: 10),
          easeOutDuration: const Duration(milliseconds: 5), // Total 15ms
          targetTimeScale: 0.2, // Partial micro-slowdown
          channels: targetChannels,
          resumptionCurve: HitStopResumptionCurve.easeOutQuad,
          conflictPolicy: conflictPolicy ?? HitStopConflictPolicy.extend,
          priority: priority ?? 0,
          onStart: onStart,
          onComplete: onComplete,
        );
      case HitStopPreset.bulletTime:
        return HitStopRequest(
          id: reqId,
          freezeDuration: const Duration(milliseconds: 120),
          easeOutDuration: const Duration(milliseconds: 40), // Total 160ms
          targetTimeScale: 0.1, // 10% slow motion
          channels: targetChannels,
          resumptionCurve: HitStopResumptionCurve.smoothStep,
          conflictPolicy: conflictPolicy ?? HitStopConflictPolicy.override,
          priority: priority ?? 5,
          onStart: onStart,
          onComplete: onComplete,
        );
    }
  }

  HitStopRequest copyWith({
    String? id,
    Duration? freezeDuration,
    Duration? easeOutDuration,
    double? targetTimeScale,
    Set<TimeDilationChannel>? channels,
    HitStopResumptionCurve? resumptionCurve,
    HitStopConflictPolicy? conflictPolicy,
    int? priority,
    double Function(double t)? customCurve,
    VoidCallback? onStart,
    VoidCallback? onComplete,
  }) {
    return HitStopRequest(
      id: id ?? this.id,
      freezeDuration: freezeDuration ?? this.freezeDuration,
      easeOutDuration: easeOutDuration ?? this.easeOutDuration,
      targetTimeScale: targetTimeScale ?? this.targetTimeScale,
      channels: channels ?? this.channels,
      resumptionCurve: resumptionCurve ?? this.resumptionCurve,
      conflictPolicy: conflictPolicy ?? this.conflictPolicy,
      priority: priority ?? this.priority,
      customCurve: customCurve ?? this.customCurve,
      onStart: onStart ?? this.onStart,
      onComplete: onComplete ?? this.onComplete,
    );
  }
}

/// Runtime instance tracking the progression of an active hit stop.
class ActiveHitStopInstance {
  final HitStopRequest request;
  double _elapsedSeconds = 0.0;
  bool _isStarted = false;
  bool _isCompleted = false;

  ActiveHitStopInstance(this.request);

  String get id => request.id;
  double get elapsedSeconds => _elapsedSeconds;
  double get freezeSeconds => request.freezeSeconds;
  double get easeOutSeconds => request.easeOutSeconds;
  double get totalSeconds => request.totalSeconds;
  double get remainingSeconds => math.max(0.0, totalSeconds - _elapsedSeconds);
  double get remainingFreezeSeconds => math.max(0.0, freezeSeconds - _elapsedSeconds);

  bool get isStarted => _isStarted;
  bool get isCompleted => _isCompleted;
  bool get isInFreezePhase => _elapsedSeconds < freezeSeconds;
  bool get isInEaseOutPhase => _elapsedSeconds >= freezeSeconds && _elapsedSeconds < totalSeconds;

  void markStarted() {
    if (!_isStarted) {
      _isStarted = true;
      request.onStart?.call();
    }
  }

  void markCompleted() {
    if (!_isCompleted) {
      _isCompleted = true;
      request.onComplete?.call();
    }
  }

  /// Advances time by [dtSeconds].
  void advance(double dtSeconds) {
    if (_isCompleted) return;
    _elapsedSeconds += dtSeconds;
    if (_elapsedSeconds >= totalSeconds) {
      markCompleted();
    }
  }

  /// Extends remaining freeze duration to at least [newFreezeSeconds].
  void extendFreeze(double newFreezeSeconds) {
    final double targetTotalFreeze = _elapsedSeconds + newFreezeSeconds;
    if (targetTotalFreeze > freezeSeconds) {
      // Re-anchor so remaining freeze equals newFreezeSeconds
      final double diff = targetTotalFreeze - freezeSeconds;
      _elapsedSeconds = math.max(0.0, _elapsedSeconds - diff);
    }
  }

  /// Evaluates current time scale (range [targetTimeScale, 1.0]).
  double evaluateCurrentTimeScale() {
    if (_isCompleted) return 1.0;

    if (isInFreezePhase) {
      return request.targetTimeScale;
    }

    if (easeOutSeconds <= 0.000001) {
      return 1.0;
    }

    final double t = math.min(
      1.0,
      math.max(0.0, (_elapsedSeconds - freezeSeconds) / easeOutSeconds),
    );

    final double easedFactor = _evaluateCurve(t, request.resumptionCurve, request.customCurve);
    return request.targetTimeScale + (1.0 - request.targetTimeScale) * easedFactor;
  }

  static double _evaluateCurve(
    double t,
    HitStopResumptionCurve curve,
    double Function(double t)? customCurve,
  ) {
    if (customCurve != null) {
      return customCurve(t).clamp(0.0, 1.0);
    }
    switch (curve) {
      case HitStopResumptionCurve.instant:
        return t >= 1.0 ? 1.0 : 0.0;
      case HitStopResumptionCurve.linear:
        return t;
      case HitStopResumptionCurve.easeOutQuad:
        return t * (2.0 - t);
      case HitStopResumptionCurve.smoothStep:
        return t * t * (3.0 - 2.0 * t);
      case HitStopResumptionCurve.easeOutCubic:
        final double inv = 1.0 - t;
        return 1.0 - (inv * inv * inv);
    }
  }
}

/// Production-ready Hit-Stop and Time Dilation Manager for AAA Combat feel.
///
/// Implements configurable micro freeze-frames (30-50ms), independent subsystem
/// channels (attacker, target, camera, VFX), smooth non-linear resumption curves
/// to eliminate frame pacing stutter, and robust queue/concurrency policies.
class HitStopManager extends ChangeNotifier {
  static HitStopManager? _instance;

  /// Shared singleton instance.
  static HitStopManager get instance => _instance ??= HitStopManager();

  /// Visible for testing or modular dependency injection.
  HitStopManager({bool isGlobalInstance = false}) {
    if (isGlobalInstance) {
      _instance = this;
    }
  }

  /// Base time scale multipliers per channel (e.g. for bullet-time or environmental speed modifier).
  final Map<TimeDilationChannel, double> _baseTimeScales = <TimeDilationChannel, double>{};

  /// Active hit-stops currently advancing.
  final List<ActiveHitStopInstance> _activeHitStops = <ActiveHitStopInstance>[];

  /// Queued hit-stops waiting for channel clearance.
  final List<HitStopRequest> _queuedRequests = <HitStopRequest>[];

  /// Cache of current channel time scales.
  final Map<TimeDilationChannel, double> _cachedTimeScales = <TimeDilationChannel, double>{};

  /// Optional Flutter Ticker for auto-frame stepping.
  Ticker? _ticker;
  Duration _lastTickTimestamp = Duration.zero;

  // ---------------------------------------------------------------------------
  // Queries & State Inspection
  // ---------------------------------------------------------------------------

  /// Number of actively playing hit-stops.
  int get activeCount => _activeHitStops.length;

  /// Number of queued hit-stops.
  int get queuedCount => _queuedRequests.length;

  /// Read-only view of active hit stop instances.
  List<ActiveHitStopInstance> get activeHitStops => List<ActiveHitStopInstance>.unmodifiable(_activeHitStops);

  /// Read-only view of queued requests.
  List<HitStopRequest> get queuedRequests => List<HitStopRequest>.unmodifiable(_queuedRequests);

  /// Returns base time scale for [channel] (default 1.0).
  double getBaseTimeScale(TimeDilationChannel channel) {
    return _baseTimeScales[channel] ?? 1.0;
  }

  /// Sets base time scale for [channel].
  void setBaseTimeScale(TimeDilationChannel channel, double scale) {
    assert(scale >= 0.0, 'scale must be non-negative');
    if (_baseTimeScales[channel] != scale) {
      _baseTimeScales[channel] = scale;
      _invalidateCache();
      notifyListeners();
    }
  }

  /// Resets all base time scales to 1.0.
  void resetBaseTimeScales() {
    _baseTimeScales.clear();
    _invalidateCache();
    notifyListeners();
  }

  /// Evaluates effective time scale for [channel].
  ///
  /// Combines global hit-stop factor, channel-specific hit-stop factor,
  /// and channel base time scale.
  double getTimeScale([TimeDilationChannel channel = TimeDilationChannel.global]) {
    final double? cached = _cachedTimeScales[channel];
    if (cached != null) return cached;

    final double computed = _computeTimeScaleForChannel(channel);
    _cachedTimeScales[channel] = computed;
    return computed;
  }

  /// Computes effective delta time for an update loop: `dt * getTimeScale(channel)`.
  double getEffectiveDeltaTime(double dt, [TimeDilationChannel channel = TimeDilationChannel.global]) {
    return dt * getTimeScale(channel);
  }

  /// Checks if [channel] is currently frozen (effective time scale <= [threshold]).
  bool isChannelFrozen(TimeDilationChannel channel, [double threshold = 0.05]) {
    return getTimeScale(channel) <= threshold;
  }

  /// Checks if any combat channel is currently in hit-stop.
  bool get isAnyFrozen {
    for (final ActiveHitStopInstance hitStop in _activeHitStops) {
      if (!hitStop.isCompleted && hitStop.evaluateCurrentTimeScale() < 0.99) {
        return true;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Trigger API
  // ---------------------------------------------------------------------------

  /// Triggers a hit stop from a predefined [HitStopPreset].
  ActiveHitStopInstance triggerPreset(
    HitStopPreset preset, {
    String? id,
    Set<TimeDilationChannel>? channels,
    HitStopConflictPolicy? conflictPolicy,
    int? priority,
    VoidCallback? onStart,
    VoidCallback? onComplete,
  }) {
    final HitStopRequest request = HitStopRequest.fromPreset(
      preset,
      id: id,
      channels: channels,
      conflictPolicy: conflictPolicy,
      priority: priority,
      onStart: onStart,
      onComplete: onComplete,
    );
    return trigger(request);
  }

  /// Convenience trigger for light attack (30ms micro freeze).
  ActiveHitStopInstance triggerLight({
    Set<TimeDilationChannel>? channels,
    HitStopConflictPolicy? conflictPolicy,
    VoidCallback? onComplete,
  }) {
    return triggerPreset(
      HitStopPreset.light,
      channels: channels,
      conflictPolicy: conflictPolicy,
      onComplete: onComplete,
    );
  }

  /// Convenience trigger for medium attack (45ms impact freeze).
  ActiveHitStopInstance triggerMedium({
    Set<TimeDilationChannel>? channels,
    HitStopConflictPolicy? conflictPolicy,
    VoidCallback? onComplete,
  }) {
    return triggerPreset(
      HitStopPreset.medium,
      channels: channels,
      conflictPolicy: conflictPolicy,
      onComplete: onComplete,
    );
  }

  /// Convenience trigger for heavy attack / critical finisher (60ms freeze).
  ActiveHitStopInstance triggerHeavy({
    Set<TimeDilationChannel>? channels,
    HitStopConflictPolicy? conflictPolicy,
    VoidCallback? onComplete,
  }) {
    return triggerPreset(
      HitStopPreset.heavy,
      channels: channels,
      conflictPolicy: conflictPolicy,
      onComplete: onComplete,
    );
  }

  /// Convenience trigger for critical shockwave / boss stagger (80ms freeze).
  ActiveHitStopInstance triggerCritical({
    Set<TimeDilationChannel>? channels,
    HitStopConflictPolicy? conflictPolicy,
    VoidCallback? onComplete,
  }) {
    return triggerPreset(
      HitStopPreset.critical,
      channels: channels,
      conflictPolicy: conflictPolicy,
      onComplete: onComplete,
    );
  }

  /// Triggers a custom or fully configured [HitStopRequest].
  ActiveHitStopInstance trigger(HitStopRequest request) {
    // 1. Check for active conflicts across the request channels
    final List<ActiveHitStopInstance> conflicting = _findConflictingActive(request.channels);

    if (conflicting.isNotEmpty) {
      // Check priority preempt
      final int maxActivePriority = conflicting.map((ActiveHitStopInstance a) => a.request.priority).reduce(math.max);
      if (request.priority > maxActivePriority) {
        // High priority preempts existing lower priority hit stops
        for (final ActiveHitStopInstance c in conflicting) {
          c.markCompleted();
          _activeHitStops.remove(c);
        }
      } else {
        // Apply conflict policy
        switch (request.conflictPolicy) {
          case HitStopConflictPolicy.ignoreIfActive:
            final ActiveHitStopInstance dummy = ActiveHitStopInstance(request);
            dummy.markCompleted();
            return dummy;

          case HitStopConflictPolicy.queue:
            _queuedRequests.add(request);
            return ActiveHitStopInstance(request);

          case HitStopConflictPolicy.extend:
            for (final ActiveHitStopInstance c in conflicting) {
              c.extendFreeze(request.freezeSeconds);
            }
            _invalidateCache();
            notifyListeners();
            return conflicting.first;

          case HitStopConflictPolicy.override:
            for (final ActiveHitStopInstance c in conflicting) {
              c.markCompleted();
              _activeHitStops.remove(c);
            }
            break;

          case HitStopConflictPolicy.blend:
            break;
        }
      }
    }

    // 2. Launch new active instance
    final ActiveHitStopInstance instance = ActiveHitStopInstance(request);
    instance.markStarted();
    _activeHitStops.add(instance);
    _invalidateCache();
    notifyListeners();
    return instance;
  }

  // ---------------------------------------------------------------------------
  // Cancellation & Clean-up
  // ---------------------------------------------------------------------------

  /// Cancels all active and queued hit-stops immediately, resetting all channels to base scale.
  void cancelAll() {
    for (final ActiveHitStopInstance instance in _activeHitStops) {
      instance.markCompleted();
    }
    _activeHitStops.clear();
    _queuedRequests.clear();
    _invalidateCache();
    notifyListeners();
  }

  /// Cancels hit-stops affecting [channel].
  void cancelChannel(TimeDilationChannel channel) {
    final List<ActiveHitStopInstance> toRemove = <ActiveHitStopInstance>[];
    for (final ActiveHitStopInstance instance in _activeHitStops) {
      if (instance.request.channels.contains(channel) ||
          instance.request.channels.contains(TimeDilationChannel.global)) {
        instance.markCompleted();
        toRemove.add(instance);
      }
    }
    for (final ActiveHitStopInstance r in toRemove) {
      _activeHitStops.remove(r);
    }
    _queuedRequests.removeWhere((HitStopRequest req) =>
        req.channels.contains(channel) || req.channels.contains(TimeDilationChannel.global));
    _invalidateCache();
    notifyListeners();
  }

  /// Cancels an active or queued hit stop by its [id].
  bool cancelById(String id) {
    bool removed = false;
    final int activeIdx = _activeHitStops.indexWhere((ActiveHitStopInstance a) => a.id == id);
    if (activeIdx != -1) {
      _activeHitStops[activeIdx].markCompleted();
      _activeHitStops.removeAt(activeIdx);
      removed = true;
    }
    final int queuedIdx = _queuedRequests.indexWhere((HitStopRequest r) => r.id == id);
    if (queuedIdx != -1) {
      _queuedRequests.removeAt(queuedIdx);
      removed = true;
    }
    if (removed) {
      _invalidateCache();
      notifyListeners();
    }
    return removed;
  }

  // ---------------------------------------------------------------------------
  // Time Step & Clock Updates
  // ---------------------------------------------------------------------------

  /// Advances hit-stop simulation by [dtSeconds].
  ///
  /// This deterministic method is ideal for unit tests, fixed-step physics loops,
  /// or game engines (e.g. Flame, custom render loops).
  void update(double dtSeconds) {
    if (dtSeconds <= 0.0) return;
    if (_activeHitStops.isEmpty && _queuedRequests.isEmpty) return;

    final List<ActiveHitStopInstance> completed = <ActiveHitStopInstance>[];

    // Advance active instances
    for (final ActiveHitStopInstance active in _activeHitStops) {
      active.advance(dtSeconds);
      if (active.isCompleted) {
        completed.add(active);
      }
    }

    // Remove completed instances
    if (completed.isNotEmpty) {
      for (final ActiveHitStopInstance c in completed) {
        _activeHitStops.remove(c);
      }
    }

    // Process queued requests if channels are now free
    if (_queuedRequests.isNotEmpty) {
      final List<HitStopRequest> toStart = <HitStopRequest>[];
      for (final HitStopRequest queued in _queuedRequests) {
        final List<ActiveHitStopInstance> activeConflicts = _findConflictingActive(queued.channels);
        if (activeConflicts.isEmpty) {
          toStart.add(queued);
        }
      }
      for (final HitStopRequest req in toStart) {
        _queuedRequests.remove(req);
        final ActiveHitStopInstance newInstance = ActiveHitStopInstance(req);
        newInstance.markStarted();
        _activeHitStops.add(newInstance);
      }
    }

    _invalidateCache();
    notifyListeners();
  }

  /// Advances hit-stop simulation by a [Duration].
  void tick(Duration delta) {
    update(delta.inMicroseconds / 1000000.0);
  }

  // ---------------------------------------------------------------------------
  // Flutter Ticker Integration
  // ---------------------------------------------------------------------------

  /// Binds an automatic Flutter [Ticker] to drive [update] from frame vsync.
  void bindTicker(TickerProvider vsync) {
    unbindTicker();
    _lastTickTimestamp = Duration.zero;
    _ticker = vsync.createTicker((Duration elapsed) {
      if (_lastTickTimestamp == Duration.zero) {
        _lastTickTimestamp = elapsed;
        return;
      }
      final Duration delta = elapsed - _lastTickTimestamp;
      _lastTickTimestamp = elapsed;
      tick(delta);
    });
    _ticker!.start();
  }

  /// Unbinds and disposes the automatic ticker.
  void unbindTicker() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _lastTickTimestamp = Duration.zero;
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  List<ActiveHitStopInstance> _findConflictingActive(Set<TimeDilationChannel> channels) {
    final List<ActiveHitStopInstance> conflicts = <ActiveHitStopInstance>[];
    final bool includesGlobal = channels.contains(TimeDilationChannel.global);

    for (final ActiveHitStopInstance active in _activeHitStops) {
      if (active.isCompleted) continue;
      if (includesGlobal ||
          active.request.channels.contains(TimeDilationChannel.global) ||
          active.request.channels.any(channels.contains)) {
        conflicts.add(active);
      }
    }
    return conflicts;
  }

  double _computeTimeScaleForChannel(TimeDilationChannel channel) {
    double minHitStopScale = 1.0;

    for (final ActiveHitStopInstance active in _activeHitStops) {
      if (active.isCompleted) continue;

      final bool channelAffected = active.request.channels.contains(channel) ||
          active.request.channels.contains(TimeDilationChannel.global);

      if (channelAffected) {
        final double scale = active.evaluateCurrentTimeScale();
        if (scale < minHitStopScale) {
          minHitStopScale = scale;
        }
      }
    }

    final double baseScale = getBaseTimeScale(channel);
    final double effectiveBaseScale = channel == TimeDilationChannel.global
        ? baseScale
        : baseScale * getBaseTimeScale(TimeDilationChannel.global);

    return (minHitStopScale * effectiveBaseScale).clamp(0.0, 100.0);
  }

  void _invalidateCache() {
    _cachedTimeScales.clear();
  }

  @override
  void dispose() {
    unbindTicker();
    cancelAll();
    super.dispose();
  }
}
