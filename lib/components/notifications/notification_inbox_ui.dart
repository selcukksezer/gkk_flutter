import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/daily_reward/daily_reward_dialog.dart';
import '../../components/layout/game_chrome.dart';
import '../../models/notification_item.dart';
import '../../providers/notification_inbox_provider.dart';
import '../../routing/app_router.dart';
import '../../components/layout/game_screen_background.dart';
import '../../theme/app_spacing.dart';
import 'notification_design.dart';

Future<void> handleNotificationTap(
  BuildContext context,
  WidgetRef ref,
  GameNotificationItem item,
) async {
  ref.read(notificationInboxProvider.notifier).dismiss(item.id);

  switch (item.kind) {
    case NotificationKind.dailyReward:
      await showDailyRewardDialog(context, ref, viewOnly: false);
    case NotificationKind.chatMessage:
      await showChatModal(context);
    default:
      final String? path = item.routePath;
      if (path != null && path.isNotEmpty) {
        context.push(path);
      }
  }

  await ref.read(notificationInboxProvider.notifier).refresh();
}

class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NotificationInboxState inbox = ref.watch(notificationInboxProvider);
    final int count = inbox.unreadCount;
    final bool active = count > 0;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: NotificationPressable(
        onTap: () => showNotificationInboxSheet(context, ref),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                NotificationDesign.obsidian.withValues(alpha: 0.95),
                NotificationDesign.navy.withValues(alpha: 0.92),
              ],
            ),
            border: Border.all(
              color: active
                  ? NotificationDesign.gold.withValues(alpha: 0.55)
                  : NotificationDesign.titanium.withValues(alpha: 0.22),
              width: active ? 1.4 : 1,
            ),
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: NotificationDesign.fuchsia.withValues(alpha: 0.28),
                      blurRadius: 14,
                    ),
                    BoxShadow(
                      color: NotificationDesign.gold.withValues(alpha: 0.18),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Icon(
                active ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                color: active ? NotificationDesign.gold : NotificationDesign.titanium,
                size: 22,
              ),
              if (active)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      gradient: NotificationDesign.fuchsiaGradient,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: NotificationDesign.void_, width: 1.2),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: NotificationDesign.fuchsia.withValues(alpha: 0.45),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showNotificationInboxSheet(BuildContext context, WidgetRef ref) {
  unawaited(ref.read(notificationInboxProvider.notifier).refresh());
  final GoRouter router = GoRouter.of(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: NotificationDesign.void_.withValues(alpha: 0.72),
    builder: (BuildContext sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.74,
        minChildSize: 0.46,
        maxChildSize: 0.92,
        expand: false,
        builder: (BuildContext context, ScrollController scrollController) {
          return NotificationGlassShell(
            child: _NotificationPanel(
              scrollController: scrollController,
              compact: true,
              onSeeAll: () {
                Navigator.of(sheetContext).pop();
                router.push(AppRoutes.notifications);
              },
            ),
          );
        },
      );
    },
  );
}

class NotificationInboxList extends ConsumerWidget {
  const NotificationInboxList({
    super.key,
    required this.scrollController,
    this.compact = false,
    this.onSeeAll,
  });

  final ScrollController scrollController;
  final bool compact;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) {
      return _NotificationPanel(
        scrollController: scrollController,
        compact: compact,
        onSeeAll: onSeeAll,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xl),
      child: NotificationGlassShell(
        compactTopRadius: false,
        child: _NotificationPanel(
          scrollController: scrollController,
          compact: compact,
          onSeeAll: onSeeAll,
        ),
      ),
    );
  }
}

class _NotificationPanel extends ConsumerWidget {
  const _NotificationPanel({
    required this.scrollController,
    required this.compact,
    this.onSeeAll,
  });

  final ScrollController scrollController;
  final bool compact;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NotificationInboxState inbox = ref.watch(notificationInboxProvider);
    final List<GameNotificationItem> items = inbox.visibleItems;
    final Map<String, List<GameNotificationItem>> grouped = <String, List<GameNotificationItem>>{};

    for (final GameNotificationItem item in items) {
      grouped.putIfAbsent(item.kind.sectionLabel, () => <GameNotificationItem>[]).add(item);
    }

    int tileIndex = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (compact) ...<Widget>[
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                gradient: NotificationDesign.goldGradient,
                borderRadius: BorderRadius.circular(99),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: NotificationDesign.gold.withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.sm, AppSpacing.sm),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: <Color>[
                      NotificationDesign.gold.withValues(alpha: 0.22),
                      NotificationDesign.fuchsia.withValues(alpha: 0.12),
                    ],
                  ),
                  border: Border.all(color: NotificationDesign.gold.withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.notifications_rounded, color: NotificationDesign.gold, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('BİLDİRİMLER', style: NotificationDesign.panelTitle()),
                    Text(
                      items.isEmpty ? 'Güncel — temiz' : '${items.length} yeni olay',
                      style: NotificationDesign.tileBody(),
                    ),
                  ],
                ),
              ),
              if (inbox.isRefreshing)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NotificationDesign.gold.withValues(alpha: 0.9),
                  ),
                )
              else
                _HeaderIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Yenile',
                  onPressed: () => ref.read(notificationInboxProvider.notifier).refresh(),
                ),
              if (items.isNotEmpty)
                _HeaderIconButton(
                  icon: Icons.done_all_rounded,
                  tooltip: 'Temizle',
                  onPressed: () => ref.read(notificationInboxProvider.notifier).dismissAll(),
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? _EmptyNotifications(isRefreshing: inbox.isRefreshing)
              : RefreshIndicator(
                  color: NotificationDesign.gold,
                  backgroundColor: NotificationDesign.navy,
                  onRefresh: () => ref.read(notificationInboxProvider.notifier).refresh(),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.base,
                      0,
                      AppSpacing.base,
                      AppSpacing.xl,
                    ),
                    children: <Widget>[
                      for (final MapEntry<String, List<GameNotificationItem>> section in grouped.entries) ...<Widget>[
                        NotificationSectionHeader(label: section.key),
                        for (final GameNotificationItem item in section.value)
                          NotificationFadeSlide(
                            index: tileIndex++,
                            child: _NotificationTile(
                              item: item,
                              onTap: () async {
                                if (compact) Navigator.of(context).pop();
                                await handleNotificationTap(context, ref, item);
                              },
                              onDismiss: () =>
                                  ref.read(notificationInboxProvider.notifier).dismiss(item.id),
                            ),
                          ),
                      ],
                      if (!compact) GameScrollLayout.bottomSpacer(context),
                    ],
                  ),
                ),
        ),
        if (compact && onSeeAll != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
              child: NotificationGoldButton(
                label: 'Tümünü gör',
                onPressed: onSeeAll,
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return NotificationPressable(
      onTap: onPressed,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: NotificationDesign.obsidian.withValues(alpha: 0.7),
          border: Border.all(color: NotificationDesign.titanium.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, size: 18, color: NotificationDesign.titanium),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.isRefreshing});

  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    NotificationDesign.gold.withValues(alpha: 0.16),
                    NotificationDesign.void_.withValues(alpha: 0.2),
                  ],
                ),
                border: Border.all(color: NotificationDesign.gold.withValues(alpha: 0.25)),
              ),
              child: Icon(
                isRefreshing ? Icons.hourglass_top_rounded : Icons.notifications_off_outlined,
                size: 34,
                color: NotificationDesign.titanium,
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(
              isRefreshing ? 'Taranıyor...' : 'Yeni bildirim yok',
              style: NotificationDesign.tileTitle(color: NotificationDesign.textHi),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ödül, görev, davet ve mesajlar burada görünür.',
              textAlign: TextAlign.center,
              style: NotificationDesign.tileBody(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onDismiss,
  });

  final GameNotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final Color accent = item.kind.accentColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: NotificationPressable(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                NotificationDesign.obsidian.withValues(alpha: 0.88),
                NotificationDesign.navy.withValues(alpha: 0.72),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.32), width: 1.1),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 14,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: CustomPaint(
                  painter: DotGridPainter(spacing: 18, dotOpacity: 0.04),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        gradient: LinearGradient(
                          colors: <Color>[
                            accent.withValues(alpha: 0.24),
                            accent.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(color: accent.withValues(alpha: 0.38)),
                        boxShadow: <BoxShadow>[
                          BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 10),
                        ],
                      ),
                      child: Icon(item.kind.icon, color: accent, size: 21),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(item.title.toUpperCase(), style: NotificationDesign.tileTitle()),
                          const SizedBox(height: 4),
                          Text(item.body, style: NotificationDesign.tileBody()),
                        ],
                      ),
                    ),
                    NotificationPressable(
                      onTap: onDismiss,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: NotificationDesign.void_.withValues(alpha: 0.55),
                          border: Border.all(color: NotificationDesign.titanium.withValues(alpha: 0.2)),
                        ),
                        child: Icon(Icons.close_rounded, size: 16, color: NotificationDesign.titanium),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
