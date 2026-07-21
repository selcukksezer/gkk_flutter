import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import 'app_foreground_service.dart';

/// Network UX states for [ConnectivityGate].
///
/// - [online]: healthy (also optimistic default before first probe)
/// - [slow]: in-flight user request aged past threshold — loading overlay
/// - [offline]: confirmed disconnect — show disconnect UI
/// - [reconnected]: brief success banner after offline recovery
///
/// Background TCP/DNS probes never set [slow]. Probe only drives
/// online / offline / reconnected. Slow UI is pending-op tracking only.
enum ConnectivityStatus { online, slow, offline, reconnected }

/// App-wide reachability + pending-request tracker.
///
/// Probe: TCP to Supabase host. Sustained failure (~1.5s debounce) →
/// [ConnectivityStatus.offline]. Idle high RTT never flashes slow UI.
///
/// Slow overlay: [beginRequest]/[endRequest] (or [trackRequest]) when
/// `pendingUserOps > 0` and oldest pending age ≥ [_slowPendingThreshold].
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  static const Duration _onlineInterval = Duration(seconds: 3);
  static const Duration _degradedInterval = Duration(seconds: 2);
  static const Duration _probeTimeout = Duration(milliseconds: 1800);
  static const Duration _offlineDebounce = Duration(milliseconds: 1500);
  static const Duration _slowPendingThreshold = Duration(milliseconds: 3000);

  final ValueNotifier<ConnectivityStatus> status =
      ValueNotifier<ConnectivityStatus>(ConnectivityStatus.online);

  /// Offline retry counter for overlay copy.
  final ValueNotifier<int> retryCount = ValueNotifier<int>(0);

  Timer? _timer;
  Timer? _offlineTimer;
  Timer? _slowTimer;
  bool _probing = false;
  bool _started = false;
  bool _firstProbeCompleted = false;
  DateTime? _degradedSince;
  int _consecutiveFailures = 0;

  int _pendingUserOps = 0;
  DateTime? _pendingSince;

  /// Gate owns UX — messenger should not spam when not fully online.
  bool get isGateBlocking {
    final ConnectivityStatus s = status.value;
    return s == ConnectivityStatus.offline || s == ConnectivityStatus.slow;
  }

  bool get isOffline => status.value == ConnectivityStatus.offline;

  int get pendingUserOps => _pendingUserOps;

  String get _probeHost {
    final Uri uri = Uri.tryParse(AppConstants.supabaseUrl) ?? Uri();
    return uri.host.isNotEmpty ? uri.host : 'one.one.one.one';
  }

  int get _probePort {
    final Uri uri = Uri.tryParse(AppConstants.supabaseUrl) ?? Uri();
    if (uri.hasPort) return uri.port;
    return uri.scheme == 'http' ? 80 : 443;
  }

  /// Start (or re-arm) probing. Always clears pending/slow/offline UX so hot
  /// restart / gate remount never inherits a stuck covering overlay.
  void start() {
    _resetSessionState();
    if (!_started) {
      _started = true;
      AppForegroundService.instance.addListener(_onForegroundChanged);
    }
    _scheduleNext(immediate: true);
  }

  void stop() {
    _started = false;
    _firstProbeCompleted = false;
    _timer?.cancel();
    _timer = null;
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _slowTimer?.cancel();
    _slowTimer = null;
    _probing = false;
    _degradedSince = null;
    _consecutiveFailures = 0;
    _pendingUserOps = 0;
    _pendingSince = null;
    retryCount.value = 0;
    status.value = ConnectivityStatus.online;
    AppForegroundService.instance.removeListener(_onForegroundChanged);
  }

  /// Clears transient counters/timers and forces optimistic [online].
  void _resetSessionState() {
    _timer?.cancel();
    _timer = null;
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _slowTimer?.cancel();
    _slowTimer = null;
    _probing = false;
    _firstProbeCompleted = false;
    _degradedSince = null;
    _consecutiveFailures = 0;
    _pendingUserOps = 0;
    _pendingSince = null;
    retryCount.value = 0;
    if (status.value != ConnectivityStatus.online) {
      status.value = ConnectivityStatus.online;
    }
  }

  /// Manual retry from disconnect overlay.
  Future<void> retryNow() => _probe();

  /// Mark a user-triggered in-flight op (API / navigation load).
  /// Pair with [endRequest]. Alias: [reportPendingOp].
  void beginRequest() {
    _pendingUserOps++;
    _pendingSince ??= DateTime.now();
    _armSlowPendingTimer();
  }

  /// Same as [beginRequest] — call when a user op starts.
  void reportPendingOp() => beginRequest();

  /// Clear one pending op. Clears slow UI when counter hits zero.
  void endRequest() {
    if (_pendingUserOps <= 0) return;
    _pendingUserOps--;
    if (_pendingUserOps == 0) {
      _pendingSince = null;
      _slowTimer?.cancel();
      _slowTimer = null;
      _clearSlowIfIdle();
    }
  }

  /// Wrap a user-triggered async call so slow overlay can track it.
  Future<T> trackRequest<T>(Future<T> Function() action) async {
    beginRequest();
    try {
      return await action();
    } finally {
      endRequest();
    }
  }

  /// API / messenger saw a transport failure — accelerate offline path.
  /// Does not show slow UI (pending ops own that).
  /// Offline still waits for first probe + debounce (no boot black flash).
  void reportTransportFailure() {
    if (!_started) return;
    if (status.value == ConnectivityStatus.offline) return;
    _consecutiveFailures++;
    _degradedSince ??= DateTime.now();
    _armOfflineDebounce();
    _scheduleNext(immediate: true);
  }

  void _onForegroundChanged() {
    if (!_started) return;
    if (AppForegroundService.instance.isForeground) {
      _scheduleNext(immediate: true);
    }
  }

  void _scheduleNext({bool immediate = false}) {
    if (!_started) return;
    _timer?.cancel();
    final bool degraded = status.value == ConnectivityStatus.offline ||
        status.value == ConnectivityStatus.slow;
    final Duration delay = immediate
        ? Duration.zero
        : (degraded ? _degradedInterval : _onlineInterval);
    _timer = Timer(delay, _probe);
  }

  Future<void> _probe() async {
    if (_probing || !_started) return;
    if (!AppForegroundService.instance.isForeground &&
        status.value == ConnectivityStatus.online) {
      _scheduleNext();
      return;
    }

    _probing = true;
    final bool reachable = await _checkReachable();
    _probing = false;
    _firstProbeCompleted = true;

    if (!_started) return;

    if (reachable) {
      _onReachable();
    } else {
      _onUnreachable();
    }
    _scheduleNext();
  }

  Future<bool> _checkReachable() async {
    try {
      // TCP connect is a better "can talk to host" signal than DNS alone.
      final Socket socket = await Socket.connect(
        _probeHost,
        _probePort,
        timeout: _probeTimeout,
      );
      socket.destroy();
      return true;
    } catch (_) {
      // Fall back to DNS — some networks block raw TCP probes oddly.
      try {
        final List<InternetAddress> result =
            await InternetAddress.lookup(_probeHost).timeout(_probeTimeout);
        return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  void _onReachable() {
    _consecutiveFailures = 0;
    retryCount.value = 0;
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _degradedSince = null;

    if (status.value == ConnectivityStatus.offline) {
      status.value = ConnectivityStatus.reconnected;
      Timer(const Duration(milliseconds: 1600), () {
        if (status.value == ConnectivityStatus.reconnected) {
          // After banner: restore slow if a long pending op is still open.
          if (_shouldShowSlowFromPending()) {
            status.value = ConnectivityStatus.slow;
          } else {
            status.value = ConnectivityStatus.online;
          }
        }
      });
      return;
    }

    // Probe never sets slow. Only clear probe-unrelated slow when idle.
    if (_shouldShowSlowFromPending()) {
      if (status.value != ConnectivityStatus.slow &&
          status.value != ConnectivityStatus.reconnected) {
        status.value = ConnectivityStatus.slow;
      }
      return;
    }

    if (status.value == ConnectivityStatus.slow) {
      status.value = ConnectivityStatus.online;
      return;
    }

    if (status.value != ConnectivityStatus.reconnected) {
      status.value = ConnectivityStatus.online;
    }
  }

  void _onUnreachable() {
    _consecutiveFailures++;
    // Idle / probe fail → no slow flash. Debounce straight toward offline.
    _degradedSince ??= DateTime.now();
    _armOfflineDebounce();
    if (status.value == ConnectivityStatus.offline) {
      retryCount.value = _consecutiveFailures;
    }
  }

  void _armOfflineDebounce() {
    if (status.value == ConnectivityStatus.offline) return;
    _offlineTimer?.cancel();
    final DateTime since = _degradedSince ?? DateTime.now();
    _degradedSince = since;
    final Duration elapsed = DateTime.now().difference(since);
    final Duration remaining = _offlineDebounce - elapsed;
    if (remaining <= Duration.zero) {
      _confirmOffline();
      return;
    }
    _offlineTimer = Timer(remaining, _confirmOffline);
  }

  void _confirmOffline() {
    if (!_started) return;
    // Never paint offline gate before the first probe finishes — avoids
    // black fullscreen during hot restart / boot while APIs fail early.
    if (!_firstProbeCompleted) return;
    if (_consecutiveFailures < 1) return;
    if (status.value == ConnectivityStatus.offline) return;
    _slowTimer?.cancel();
    _slowTimer = null;
    status.value = ConnectivityStatus.offline;
    retryCount.value = _consecutiveFailures;
  }

  void _armSlowPendingTimer() {
    if (status.value == ConnectivityStatus.offline) return;
    if (_pendingUserOps <= 0 || _pendingSince == null) return;

    _slowTimer?.cancel();
    final Duration elapsed = DateTime.now().difference(_pendingSince!);
    final Duration remaining = _slowPendingThreshold - elapsed;
    if (remaining <= Duration.zero) {
      _enterSlowFromPending();
      return;
    }
    _slowTimer = Timer(remaining, _enterSlowFromPending);
  }

  void _enterSlowFromPending() {
    if (!_shouldShowSlowFromPending()) return;
    if (status.value == ConnectivityStatus.offline ||
        status.value == ConnectivityStatus.reconnected) {
      return;
    }
    if (status.value != ConnectivityStatus.slow) {
      status.value = ConnectivityStatus.slow;
    }
  }

  bool _shouldShowSlowFromPending() {
    if (_pendingUserOps <= 0 || _pendingSince == null) return false;
    return DateTime.now().difference(_pendingSince!) >= _slowPendingThreshold;
  }

  void _clearSlowIfIdle() {
    if (status.value != ConnectivityStatus.slow) return;
    if (_pendingUserOps > 0) return;
    status.value = ConnectivityStatus.online;
  }
}
