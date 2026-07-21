import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/services/connectivity_service.dart';
import 'game_alert_popup.dart';

enum AppMessageType { success, error, warning, info }

/// Kept for call-site compatibility; popups are centered so offset is unused.
const double kAppToastBottomOffset = 96;

/// Game-wide alert messenger.
///
/// Opens tasarim popups instead of bottom toasts. When connectivity gate is
/// already showing slow/offline UX, error/warning spam is suppressed and
/// [ConnectivityService.reportTransportFailure] is notified instead.
abstract final class AppMessenger {
  static OverlayEntry? _entry;

  static GameAlertVariant _toVariant(AppMessageType type) {
    switch (type) {
      case AppMessageType.success:
        return GameAlertVariant.success;
      case AppMessageType.error:
        return GameAlertVariant.error;
      case AppMessageType.warning:
        return GameAlertVariant.warning;
      case AppMessageType.info:
        return GameAlertVariant.info;
    }
  }

  static bool _looksLikeNetworkMessage(String message) {
    final String lower = message.toLowerCase();
    return lower.contains('bağlantı') ||
        lower.contains('internet') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout') ||
        lower.contains('zaman aşımı') ||
        lower.contains('timed out') ||
        lower.contains('host lookup') ||
        lower.contains('offline');
  }

  static void show(
    BuildContext context,
    String message, {
    AppMessageType type = AppMessageType.info,
    String? title,
    String primaryLabel = 'TAMAM',
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    final bool gateBlocking = ConnectivityService.instance.isGateBlocking;
    final bool isAlert =
        type == AppMessageType.error || type == AppMessageType.warning;

    if (gateBlocking && (isAlert || _looksLikeNetworkMessage(message))) {
      ConnectivityService.instance.reportTransportFailure();
      return;
    }

    if (_looksLikeNetworkMessage(message) && isAlert) {
      ConnectivityService.instance.reportTransportFailure();
    }

    _dismiss();

    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!overlay.mounted) return;

      _entry = OverlayEntry(
        builder: (BuildContext ctx) {
          return _PopupBarrier(
            onDismiss: _dismiss,
            child: GameAlertPopup(
              message: message,
              variant: _toVariant(type),
              title: title,
              primaryLabel: primaryLabel,
              secondaryLabel: secondaryLabel,
              onPrimary: _dismiss,
              onSecondary: () {
                onSecondary?.call();
                _dismiss();
              },
            ),
          );
        },
      );
      overlay.insert(_entry!);
    });
  }

  static void showError(BuildContext context, String message, {String? title}) {
    show(context, message, type: AppMessageType.error, title: title);
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
  }) {
    show(context, message, type: AppMessageType.success, title: title);
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
  }) {
    show(context, message, type: AppMessageType.warning, title: title);
  }

  static void showInfo(BuildContext context, String message, {String? title}) {
    show(context, message, type: AppMessageType.info, title: title);
  }

  static void dismiss() => _dismiss();

  static void _dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

class _PopupBarrier extends StatelessWidget {
  const _PopupBarrier({required this.child, required this.onDismiss});

  final Widget child;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ColoredBox(
            color: AppColorsBarrier.scrim,
            child: GestureDetector(
              // Absorb taps on the card so barrier dismiss does not fire.
              onTap: () {},
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Local scrim color — avoids importing full theme only for alpha.
abstract final class AppColorsBarrier {
  static const Color scrim = Color(0xCC080B12);
}
