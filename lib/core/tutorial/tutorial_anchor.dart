import 'package:flutter/material.dart';

import 'tutorial_anchor_registry.dart';

/// Registers a widget rect as a tutorial spotlight target.
class TutorialAnchorScope extends StatefulWidget {
  const TutorialAnchorScope({
    super.key,
    required this.id,
    required this.child,
  });

  final String id;
  final Widget child;

  @override
  State<TutorialAnchorScope> createState() => _TutorialAnchorScopeState();
}

class _TutorialAnchorScopeState extends State<TutorialAnchorScope> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    TutorialAnchorRegistry.instance.register(widget.id, _key);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TutorialAnchorRegistry.instance.scheduleRefresh();
    });
  }

  @override
  void didUpdateWidget(TutorialAnchorScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      TutorialAnchorRegistry.instance.unregister(oldWidget.id, _key);
      TutorialAnchorRegistry.instance.register(widget.id, _key);
    }
  }

  @override
  void dispose() {
    TutorialAnchorRegistry.instance.unregister(widget.id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
