import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../components/notifications/notification_inbox_ui.dart';
import '../../providers/notification_inbox_provider.dart';
import '../../routing/app_router.dart';
import '../../utils/logout_helper.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(notificationInboxProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GameTopBar(
        title: 'Bildirimler',
        onLogout: () async {
          await performLogout(ref);
        },
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.notifications,
        onLogout: () async {
          await performLogout(ref);
        },
      ),
      body: GameScreenBackground(
        child: NotificationInboxList(
          scrollController: _scrollController,
          compact: false,
        ),
      ),
    );
  }
}
