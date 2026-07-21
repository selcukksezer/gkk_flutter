import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/game_notification_scheduler.dart';
import '../../providers/notification_inbox_provider.dart';

/// Oturum açıkken bildirim polling'ini canlı tutar; app resume'da yeniler.
/// Arka plandayken önemli inbox olaylarını telefona düşürür.
class NotificationInboxHost extends ConsumerStatefulWidget {
  const NotificationInboxHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationInboxHost> createState() => _NotificationInboxHostState();
}

class _NotificationInboxHostState extends ConsumerState<NotificationInboxHost>
    with WidgetsBindingObserver {
  bool _foreground = true;
  final Set<String> _pushedPhoneIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      _pushedPhoneIds.clear();
      unawaited(ref.read(notificationInboxProvider.notifier).refresh());
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pushBackgroundNotifications(null, ref.read(notificationInboxProvider));
    }
  }

  void _pushBackgroundNotifications(
    NotificationInboxState? previous,
    NotificationInboxState current,
  ) {
    if (_foreground) return;

    final Set<String> previousIds = previous == null
        ? const <String>{}
        : previous.items.map((item) => item.id).toSet();

    for (final item in current.visibleItems) {
      if (previousIds.contains(item.id)) continue;
      if (_pushedPhoneIds.contains(item.id)) continue;
      _pushedPhoneIds.add(item.id);
      unawaited(GameNotificationScheduler.instance.pushInboxItemIfBackground(item));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NotificationInboxState>(notificationInboxProvider, (
      NotificationInboxState? previous,
      NotificationInboxState next,
    ) {
      if (!_foreground) {
        _pushBackgroundNotifications(previous, next);
      }
    });
    ref.watch(notificationInboxProvider);
    return widget.child;
  }
}
