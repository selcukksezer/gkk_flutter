import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

enum AppMessageType { success, error, warning, info }

/// Height clearance above [GameBottomBar] + safe area padding.
const double kAppToastBottomOffset = 96;

/// Non-blocking toast overlay. New message replaces previous instantly.
abstract final class AppMessenger {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    AppMessageType type = AppMessageType.info,
    Duration duration = const Duration(milliseconds: 2000),
    double bottomOffset = kAppToastBottomOffset,
  }) {
    _dismiss();

    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _entry = OverlayEntry(
      builder: (ctx) => _ToastOverlay(
        message: message,
        type: type,
        bottomOffset: bottomOffset,
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(duration, _dismiss);
  }

  static void showError(BuildContext context, String message) {
    show(context, message, type: AppMessageType.error);
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message, type: AppMessageType.success);
  }

  static void showWarning(BuildContext context, String message) {
    show(context, message, type: AppMessageType.warning);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message, type: AppMessageType.info);
  }

  static void dismiss() => _dismiss();

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastOverlay extends StatelessWidget {
  const _ToastOverlay({
    required this.message,
    required this.type,
    required this.bottomOffset,
  });

  final String message;
  final AppMessageType type;
  final double bottomOffset;

  Color get _background {
    switch (type) {
      case AppMessageType.success:
        return AppColors.success;
      case AppMessageType.error:
        return AppColors.danger;
      case AppMessageType.warning:
        return AppColors.goldDim;
      case AppMessageType.info:
        return AppColors.bgCardElevated;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottom =
        MediaQuery.paddingOf(context).bottom + bottomOffset;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.circular(12),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
