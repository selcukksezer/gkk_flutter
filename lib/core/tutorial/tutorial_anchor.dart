import 'dart:async';

import 'package:flutter/material.dart';

import 'tutorial_anchor_registry.dart';

/// Registers a widget rect as a tutorial spotlight target.
///
/// Optional [onTutorialTap]: overlay hole catcher invokes this instead of
/// relying on hit-test pass-through (needed for DragTarget / dense lists).
class TutorialAnchorScope extends StatefulWidget {
  const TutorialAnchorScope({
    super.key,
    required this.id,
    required this.child,
    this.onTutorialTap,
  });

  final String id;
  final Widget child;
  final FutureOr<void> Function()? onTutorialTap;

  @override
  State<TutorialAnchorScope> createState() => _TutorialAnchorScopeState();
}

class _TutorialAnchorScopeState extends State<TutorialAnchorScope> {
  final GlobalKey _key = GlobalKey();
  FutureOr<void> Function()? _registeredAction;

  @override
  void initState() {
    super.initState();
    TutorialAnchorRegistry.instance.register(widget.id, _key);
    _syncTapAction();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TutorialAnchorRegistry.instance.scheduleRefresh();
    });
  }

  @override
  void didUpdateWidget(TutorialAnchorScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      TutorialAnchorRegistry.instance.unregister(oldWidget.id, _key);
      if (_registeredAction != null) {
        TutorialAnchorRegistry.instance.unregisterTapAction(
          oldWidget.id,
          _registeredAction!,
        );
        _registeredAction = null;
      }
      TutorialAnchorRegistry.instance.register(widget.id, _key);
    }
    _syncTapAction();
  }

  @override
  void dispose() {
    if (_registeredAction != null) {
      TutorialAnchorRegistry.instance.unregisterTapAction(
        widget.id,
        _registeredAction!,
      );
      _registeredAction = null;
    }
    TutorialAnchorRegistry.instance.unregister(widget.id, _key);
    super.dispose();
  }

  void _syncTapAction() {
    final FutureOr<void> Function()? next = widget.onTutorialTap;
    if (_registeredAction == next) return;
    if (_registeredAction != null) {
      TutorialAnchorRegistry.instance.unregisterTapAction(
        widget.id,
        _registeredAction!,
      );
    }
    _registeredAction = next;
    if (next != null) {
      TutorialAnchorRegistry.instance.registerTapAction(widget.id, next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
