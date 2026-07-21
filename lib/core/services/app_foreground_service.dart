import 'package:flutter/widgets.dart';

/// App foreground gate — pause timers/polling when backgrounded.
class AppForegroundService with WidgetsBindingObserver {
  AppForegroundService._();

  static final AppForegroundService instance = AppForegroundService._();

  bool _started = false;
  bool _foreground = true;

  bool get isForeground => _foreground;

  final List<VoidCallback> _listeners = <VoidCallback>[];

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed ||
        WidgetsBinding.instance.lifecycleState == null;
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _listeners.clear();
  }

  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool next = state == AppLifecycleState.resumed;
    if (next == _foreground) return;
    _foreground = next;
    for (final VoidCallback listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }
}

/// Pauses/resumes a repeating [AnimationController] with app lifecycle.
mixin LifecycleAnimationPause<T extends StatefulWidget> on State<T> {
  AnimationController? get lifecycleAnimationController;

  void attachLifecycleAnimationPause() {
    AppForegroundService.instance.addListener(_syncLifecycleAnimation);
  }

  void detachLifecycleAnimationPause() {
    AppForegroundService.instance.removeListener(_syncLifecycleAnimation);
  }

  void _syncLifecycleAnimation() {
    final AnimationController? controller = lifecycleAnimationController;
    if (controller == null || !mounted) return;
    if (AppForegroundService.instance.isForeground) {
      if (!controller.isAnimating) {
        controller.repeat(reverse: true);
      }
    } else {
      controller.stop();
    }
  }
}
