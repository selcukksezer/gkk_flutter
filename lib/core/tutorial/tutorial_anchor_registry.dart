import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Global anchor key registry for spotlight positioning + optional tap actions.
class TutorialAnchorRegistry extends ChangeNotifier {
  TutorialAnchorRegistry._();
  static final TutorialAnchorRegistry instance = TutorialAnchorRegistry._();

  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};
  final Map<String, FutureOr<void> Function()> _tapActions =
      <String, FutureOr<void> Function()>{};
  bool _refreshScheduled = false;

  void register(String id, GlobalKey key) {
    _keys[id] = key;
    scheduleRefresh();
  }

  void unregister(String id, GlobalKey key) {
    final GlobalKey? existing = _keys[id];
    if (existing == key) {
      _keys.remove(id);
      scheduleRefresh();
    }
  }

  /// Registers a tap handler the overlay invokes when the spotlight hole is
  /// tapped — avoids fragile hit-test fall-through (DragTarget / overlays).
  void registerTapAction(String id, FutureOr<void> Function() action) {
    _tapActions[id] = action;
  }

  void unregisterTapAction(String id, FutureOr<void> Function() action) {
    if (_tapActions[id] == action) {
      _tapActions.remove(id);
    }
  }

  bool hasTapAction(String id) => _tapActions.containsKey(id);

  /// Returns true if a handler ran.
  Future<bool> invokeTapAction(String id) async {
    final FutureOr<void> Function()? action = _tapActions[id];
    if (action == null) return false;
    await action();
    return true;
  }

  GlobalKey? keyFor(String id) => _keys[id];

  Rect? rectFor(String id, {EdgeInsets padding = EdgeInsets.zero}) {
    final GlobalKey? key = _keys[id];
    if (key == null) return null;
    final BuildContext? ctx = key.currentContext;
    // Deactivated / mid-route-swap contexts (settings → home replay) → null.
    if (ctx == null || !ctx.mounted) return null;
    final RenderObject? renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        !renderObject.attached) {
      return null;
    }
    final Offset topLeft = renderObject.localToGlobal(Offset.zero);
    final Rect raw = topLeft & renderObject.size;
    if (raw.width <= 0 || raw.height <= 0) return null;
    if (padding == EdgeInsets.zero) return raw;
    return Rect.fromLTRB(
      raw.left - padding.left,
      raw.top - padding.top,
      raw.right + padding.right,
      raw.bottom + padding.bottom,
    );
  }

  /// Drop dead keys/actions (replay / route swap). Safe to call often.
  void pruneDetached() {
    final List<String> deadKeys = <String>[];
    _keys.forEach((String id, GlobalKey key) {
      final BuildContext? ctx = key.currentContext;
      if (ctx == null || !ctx.mounted) {
        deadKeys.add(id);
        return;
      }
      final RenderObject? ro = ctx.findRenderObject();
      if (ro == null || !ro.attached) {
        deadKeys.add(id);
      }
    });
    for (final String id in deadKeys) {
      _keys.remove(id);
    }
    if (deadKeys.isNotEmpty) {
      scheduleRefresh();
    }
  }

  void scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      notifyListeners();
    });
  }

  @visibleForTesting
  void debugClearTapActions() => _tapActions.clear();

  @visibleForTesting
  void debugClearKeys() => _keys.clear();
}
