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
import '../../theme/app_spacing.dart';
import 'notification_design.dart';

Future<void> handleNotificationTap(
  BuildContext context,
  WidgetRef ref,
  GameNotificationItem item,
) async {
  await HapticFeedback.lightImpact();
  ref.read(notificationInboxProvider.notifier).dismiss(item.id);

  switch (item.kind) {
    case NotificationKind.dailyReward:
      await showDailyRewardDialog(context, ref, viewOnly: false);
    case NotificationKind.chatMessage:
      await showChatModal(context);
    case NotificationKind.bugReportUpdate:
      context.push(AppRoutes.myBugReports);
    default:
      final String? path = item.routePath;
      if (path != null && path.isNotEmpty) {
        context.push(path, extra: item.routeExtra);
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
        onTap: () {
          HapticFeedback.lightImpact();
          showNotificationInboxSheet(context, ref);
        },
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
  HapticFeedback.lightImpact();
  unawaited(ref.read(notificationInboxProvider.notifier).refresh());
  final GoRouter router = GoRouter.of(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: NotificationDesign.void_.withValues(alpha: 0.78),
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.74,
        minChildSize: 0.44,
        maxChildSize: 0.90,
        expand: false,
        builder: (BuildContext context, ScrollController scrollController) {
          return NotificationGlassShell(
            child: _NotificationPanel(
              scrollController: scrollController,
              compact: true,
              onSeeAll: () {
                HapticFeedback.lightImpact();
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
      return SafeArea(
        top: false,
        child: _NotificationPanel(
          scrollController: scrollController,
          compact: compact,
          onSeeAll: onSeeAll,
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xl),
            child: NotificationGlassShell(
              compactTopRadius: false,
              child: _NotificationPanel(
                scrollController: scrollController,
                compact: compact,
                onSeeAll: onSeeAll,
              ),
            ),
          ),
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

    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    int tileIndex = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (compact) ...<Widget>[
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                gradient: NotificationDesign.goldGradient,
                borderRadius: BorderRadius.circular(99),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: NotificationDesign.gold.withValues(alpha: 0.45),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.base,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: <Color>[
                      NotificationDesign.gold.withValues(alpha: 0.25),
                      NotificationDesign.fuchsia.withValues(alpha: 0.15),
                    ],
                  ),
                  border: Border.all(
                    color: NotificationDesign.gold.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: NotificationDesign.gold.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: NotificationDesign.gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'BİLDİRİMLER',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NotificationDesign.panelTitle(),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      items.isEmpty ? 'Güncel — temiz' : '${items.length} yeni bildirim',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NotificationDesign.tileBody(
                        color: items.isEmpty
                            ? NotificationDesign.titanium
                            : NotificationDesign.gold.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              if (inbox.isRefreshing)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: NotificationDesign.gold.withValues(alpha: 0.9),
                    ),
                  ),
                )
              else
                _HeaderIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Yenile',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref.read(notificationInboxProvider.notifier).refresh();
                  },
                ),
              if (items.isNotEmpty)
                _HeaderIconButton(
                  icon: Icons.done_all_rounded,
                  tooltip: 'Tümünü Temizle',
                  accentColor: NotificationDesign.gold,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(notificationInboxProvider.notifier).dismissAll();
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? _EmptyNotifications(
                  isRefreshing: inbox.isRefreshing,
                  bottomInset: compact && onSeeAll == null ? bottomInset : 0,
                )
              : RefreshIndicator(
                  color: NotificationDesign.gold,
                  backgroundColor: NotificationDesign.navy,
                  onRefresh: () async {
                    HapticFeedback.lightImpact();
                    await ref.read(notificationInboxProvider.notifier).refresh();
                  },
                  child: ListView(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.base,
                      0,
                      AppSpacing.base,
                      compact && onSeeAll != null
                          ? AppSpacing.sm
                          : (AppSpacing.xl + bottomInset),
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
                              onDismiss: () {
                                HapticFeedback.mediumImpact();
                                ref.read(notificationInboxProvider.notifier).dismiss(item.id);
                              },
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.xs,
                AppSpacing.base,
                AppSpacing.sm,
              ),
              child: NotificationGoldButton(
                label: 'Tümünü gör',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onSeeAll?.call();
                },
              ),
            ),
          )
        else if (compact && bottomInset > 0)
          SizedBox(height: bottomInset),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accentColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final Color tint = accentColor ?? NotificationDesign.titanium;

    return Tooltip(
      message: tooltip,
      child: NotificationPressable(
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: NotificationDesign.obsidian.withValues(alpha: 0.8),
            border: Border.all(
              color: accentColor != null
                  ? accentColor!.withValues(alpha: 0.38)
                  : NotificationDesign.titanium.withValues(alpha: 0.22),
            ),
            boxShadow: accentColor != null
                ? <BoxShadow>[
                    BoxShadow(
                      color: accentColor!.withValues(alpha: 0.16),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, size: 18, color: tint),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({
    required this.isRefreshing,
    this.bottomInset = 0,
  });

  final bool isRefreshing;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    NotificationDesign.gold.withValues(alpha: 0.18),
                    NotificationDesign.void_.withValues(alpha: 0.24),
                  ],
                ),
                border: Border.all(
                  color: NotificationDesign.gold.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: NotificationDesign.gold.withValues(alpha: 0.18),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                isRefreshing ? Icons.hourglass_top_rounded : Icons.notifications_off_outlined,
                size: 34,
                color: isRefreshing ? NotificationDesign.gold : NotificationDesign.titanium,
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(
              isRefreshing ? 'Taranıyor...' : 'Yeni bildirim yok',
              style: NotificationDesign.tileTitle(color: NotificationDesign.textHi),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                'Ödül, görev, davet ve mesajlar burada görünür.',
                textAlign: TextAlign.center,
                style: NotificationDesign.tileBody(),
              ),
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
      child: Dismissible(
        key: ValueKey<String>('inbox_tile_${item.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDismiss(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                Colors.transparent,
                NotificationDesign.ruby.withValues(alpha: 0.4),
                NotificationDesign.ruby.withValues(alpha: 0.8),
              ],
            ),
            border: Border.all(
              color: NotificationDesign.ruby.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'SİL',
                style: GoogleFonts.urbanist(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
        child: NotificationPressable(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  NotificationDesign.obsidian.withValues(alpha: 0.92),
                  NotificationDesign.navy.withValues(alpha: 0.76),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.14),
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
                              accent.withValues(alpha: 0.26),
                              accent.withValues(alpha: 0.08),
                            ],
                          ),
                          border: Border.all(color: accent.withValues(alpha: 0.42)),
                          boxShadow: <BoxShadow>[
                            BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 10),
                          ],
                        ),
                        child: Icon(item.kind.icon, color: accent, size: 21),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.title.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: NotificationDesign.tileTitle(),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: NotificationDesign.tileBody(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      NotificationPressable(
                        onTap: onDismiss,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            color: NotificationDesign.void_.withValues(alpha: 0.65),
                            border: Border.all(
                              color: NotificationDesign.titanium.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: NotificationDesign.titanium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
