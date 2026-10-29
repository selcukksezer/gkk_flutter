import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/daily_reward/daily_reward_dialog.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../models/notification_item.dart';
import '../../providers/notification_inbox_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/logout_helper.dart';
import 'notification_center_view.dart';

/// 2027 Aion 2 Mobile Notification Center Screen.
///
/// Top-level route screen mapped to [AppRoutes.notifications].
/// Hosts [GameTopBar], [GameBottomBar], [GameScreenBackground], and binds
/// [notificationInboxProvider] to [NotificationCenterView].
///
/// Features:
/// - Obsidian frosted glass & celestial gold luminous accents.
/// - Full mobile SafeArea integration for top bar and content area.
/// - 390x844 responsive layout scaling with max-width container for tablet/wide screens.
/// - Fluid bouncing scroll physics with bottom navigation bar clearance.
/// - Multi-tier haptic feedback (light for taps, medium for dismissals, heavy for mark all read).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _handleItemTap(
    BuildContext context,
    WidgetRef ref,
    GameNotificationItem item,
  ) async {
    HapticFeedback.lightImpact();
    ref.read(notificationInboxProvider.notifier).dismiss(item.id);

    switch (item.kind) {
      case NotificationKind.dailyReward:
        await showDailyRewardDialog(context, ref, viewOnly: false);
      case NotificationKind.chatMessage:
        await showChatModal(context);
      case NotificationKind.bugReportUpdate:
        if (context.mounted) {
          context.push(AppRoutes.myBugReports);
        }
      default:
        final String? path = item.routePath;
        if (path != null && path.isNotEmpty && context.mounted) {
          context.push(path, extra: item.routeExtra);
        }
    }

    if (context.mounted) {
      await ref.read(notificationInboxProvider.notifier).refresh();
    }
  }

  void _markAllAsRead(BuildContext context, WidgetRef ref) {
    HapticFeedback.heavyImpact();
    ref.read(notificationInboxProvider.notifier).dismissAll();

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isCompact = screenWidth < 390;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.liquidGold.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.done_all_rounded,
                color: AppColors.liquidGold,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tüm bildirimler okundu olarak işaretlendi',
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w700,
                  fontSize: isCompact ? 11.5 : 12.5,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F1523),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: EdgeInsets.fromLTRB(
          isCompact ? 12 : 20,
          0,
          isCompact ? 12 : 20,
          gameBottomBarClearance(context) + (isCompact ? 8 : 12),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.liquidGold.withValues(alpha: 0.45),
            width: 1.1,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NotificationInboxState inbox = ref.watch(notificationInboxProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isCompact = screenWidth < 390;

    return Scaffold(
      appBar: GameTopBar(
        title: 'Bildirim Merkezi',
        onLogout: () async {
          await performLogout(ref);
        },
        trailingActions: <Widget>[
          if (inbox.visibleItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6, left: 2),
              child: InkWell(
                onTap: () => _markAllAsRead(context, ref),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.liquidGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.liquidGold.withValues(alpha: 0.35),
                      width: 1,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.liquidGold.withValues(alpha: 0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.done_all_rounded,
                        color: AppColors.liquidGold,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tümünü Oku',
                        style: GoogleFonts.urbanist(
                          color: AppColors.liquidGold,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.notifications,
        onLogout: () async {
          await performLogout(ref);
        },
      ),
      body: GameScreenBackground(
        child: SafeArea(
          top: false,
          bottom: true,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: NotificationCenterView(
                items: inbox.visibleItems,
                isRefreshing: inbox.isRefreshing,
                padding: GameScrollLayout.padding(
                  context,
                  horizontal: isCompact ? AppSpacing.sm : AppSpacing.base,
                  top: isCompact ? AppSpacing.xs : AppSpacing.sm,
                  bottomExtra: isCompact ? AppSpacing.lg : AppSpacing.xl,
                ),
                onItemTap: (GameNotificationItem item) =>
                    _handleItemTap(context, ref, item),
                onItemDismiss: (GameNotificationItem item) {
                  HapticFeedback.mediumImpact();
                  ref.read(notificationInboxProvider.notifier).dismiss(item.id);
                },
                onMarkAllAsRead: () => _markAllAsRead(context, ref),
                onRefresh: () async {
                  HapticFeedback.lightImpact();
                  await ref.read(notificationInboxProvider.notifier).refresh();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
