import 'dart:async';

import 'package:flutter/material.dart';

import '../../../components/layout/game_chrome.dart';

/// Auto-scrolls the bank screen while dragging items near viewport edges.
class BankDragScrollCoordinator {
  BankDragScrollCoordinator({
    required this.scrollController,
    required this.contextProvider,
  });

  final ScrollController scrollController;
  final BuildContext Function() contextProvider;

  Timer? _timer;
  double _dragGlobalY = 0;
  bool _active = false;

  static const double _edgeZone = 72;
  static const double _scrollStep = 12;

  void handleDragStarted() {
    _active = true;
    _timer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tick(),
    );
  }

  void handleDragUpdate(DragUpdateDetails details) {
    _dragGlobalY = details.globalPosition.dy;
  }

  void handleDragEnd(DraggableDetails details) {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    if (!_active || !scrollController.hasClients) return;

    final BuildContext context = contextProvider();
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenHeight = mediaQuery.size.height;
    final double topBound = mediaQuery.padding.top + kToolbarHeight;
    final double bottomBound =
        screenHeight - mediaQuery.padding.bottom - gameBottomBarClearance(context);

    if (_dragGlobalY < topBound + _edgeZone) {
      _scrollBy(-_scrollStep);
    } else if (_dragGlobalY > bottomBound - _edgeZone) {
      _scrollBy(_scrollStep);
    }
  }

  void _scrollBy(double delta) {
    final ScrollPosition position = scrollController.position;
    final double target = (position.pixels + delta).clamp(
      0.0,
      position.maxScrollExtent,
    );
    if (target != position.pixels) {
      scrollController.jumpTo(target);
    }
  }
}
