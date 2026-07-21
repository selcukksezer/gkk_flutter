import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Global anchor key registry for spotlight positioning.
class TutorialAnchorRegistry extends ChangeNotifier {
  TutorialAnchorRegistry._();
  static final TutorialAnchorRegistry instance = TutorialAnchorRegistry._();

  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};
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

  GlobalKey? keyFor(String id) => _keys[id];

  Rect? rectFor(String id, {EdgeInsets padding = EdgeInsets.zero}) {
    final GlobalKey? key = _keys[id];
    if (key == null) return null;
    final BuildContext? ctx = key.currentContext;
    if (ctx == null) return null;
    final RenderObject? renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final Offset topLeft = renderObject.localToGlobal(Offset.zero);
    final Rect raw = topLeft & renderObject.size;
    if (padding == EdgeInsets.zero) return raw;
    return Rect.fromLTRB(
      raw.left - padding.left,
      raw.top - padding.top,
      raw.right + padding.right,
      raw.bottom + padding.bottom,
    );
  }

  void scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      notifyListeners();
    });
  }
}
