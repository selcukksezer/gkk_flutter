import 'package:flutter/material.dart';

/// Tracks UI that must hide the tutorial overlay — popup routes AND
/// inline blockers (policy gate, ban gate, alert popups, etc.).
///
/// Root rule: any fullscreen/modal blocker calls [hold]/[release] (or wraps
/// with [TutorialSuppressScope]). [TutorialHost] hides while suppressed.
/// No per-notification special cases in tutorial code.
final class TutorialModalSuppress extends ChangeNotifier {
  TutorialModalSuppress._();

  static final TutorialModalSuppress instance = TutorialModalSuppress._();

  int _routeDepth = 0;
  final Set<Object> _holds = <Object>{};

  bool get isSuppressed => _routeDepth > 0 || _holds.isNotEmpty;

  /// Manual hold for non-[PopupRoute] blockers (gates, OverlayEntry alerts).
  void hold(Object token) {
    if (_holds.add(token)) {
      notifyListeners();
    }
  }

  void release(Object token) {
    if (_holds.remove(token)) {
      notifyListeners();
    }
  }

  @visibleForTesting
  void debugReset() => resetForReplay();

  /// Clears popup-depth + holds (settings tutorial replay / recovery).
  void resetForReplay() {
    final bool had = isSuppressed;
    _routeDepth = 0;
    _holds.clear();
    if (had) notifyListeners();
  }

  void _pushRoute() {
    _routeDepth++;
    notifyListeners();
  }

  void _popRoute() {
    if (_routeDepth <= 0) return;
    _routeDepth--;
    notifyListeners();
  }
}

/// While [active], holds tutorial suppress — auto release on dispose/false.
class TutorialSuppressScope extends StatefulWidget {
  const TutorialSuppressScope({
    super.key,
    required this.active,
    required this.child,
    this.token,
  });

  final bool active;
  final Widget child;

  /// Stable identity for this hold. Defaults to State instance.
  final Object? token;

  @override
  State<TutorialSuppressScope> createState() => _TutorialSuppressScopeState();
}

class _TutorialSuppressScopeState extends State<TutorialSuppressScope> {
  late final Object _token = widget.token ?? this;
  bool _held = false;

  @override
  void initState() {
    super.initState();
    _sync(widget.active);
  }

  @override
  void didUpdateWidget(covariant TutorialSuppressScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(widget.active);
  }

  @override
  void dispose() {
    _sync(false);
    super.dispose();
  }

  void _sync(bool active) {
    if (active && !_held) {
      TutorialModalSuppress.instance.hold(_token);
      _held = true;
    } else if (!active && _held) {
      TutorialModalSuppress.instance.release(_token);
      _held = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Counts [PopupRoute] pushes on the app root navigator.
final class TutorialModalRouteObserver extends NavigatorObserver {
  TutorialModalRouteObserver._();

  static final TutorialModalRouteObserver instance =
      TutorialModalRouteObserver._();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute<dynamic>) {
      TutorialModalSuppress.instance._pushRoute();
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute<dynamic>) {
      TutorialModalSuppress.instance._popRoute();
    }
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute<dynamic>) {
      TutorialModalSuppress.instance._popRoute();
    }
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute is PopupRoute<dynamic>) {
      TutorialModalSuppress.instance._popRoute();
    }
    if (newRoute is PopupRoute<dynamic>) {
      TutorialModalSuppress.instance._pushRoute();
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
