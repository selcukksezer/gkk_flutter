import 'package:flutter/material.dart';

import '../../models/notification_item.dart';
import '../../theme/app_colors.dart';

/// 2027 Aion 2 Mobile Notification Center Categories.
///
/// Categorizes notifications into 5 distinct channels:
/// - All: Complete overview
/// - System: Server updates, facilities, crafting, hospital, prison, market
/// - Combat: PvP duels, nemesis rivals, health alerts, class buffs
/// - Social: Friend requests, chat messages, trade invitations
/// - Rewards: Daily login rewards, quest rewards, referrals, chests/boxes, codex
enum NotificationCategory {
  all,
  system,
  combat,
  social,
  rewards,
}

extension NotificationCategoryX on NotificationCategory {
  /// Localized Turkish display label.
  String get label => switch (this) {
        NotificationCategory.all => 'Tümü',
        NotificationCategory.system => 'Sistem',
        NotificationCategory.combat => 'Savaş',
        NotificationCategory.social => 'Sosyal',
        NotificationCategory.rewards => 'Ödüller',
      };

  /// Primary icon representing the category.
  IconData get icon => switch (this) {
        NotificationCategory.all => Icons.auto_awesome_mosaic_rounded,
        NotificationCategory.system => Icons.shield_outlined,
        NotificationCategory.combat => Icons.sports_mma_rounded,
        NotificationCategory.social => Icons.groups_rounded,
        NotificationCategory.rewards => Icons.card_giftcard_rounded,
      };

  /// Luminous accent color for borders, glows, and badges.
  Color get accentColor => switch (this) {
        NotificationCategory.all => AppColors.liquidGold,
        NotificationCategory.system => AppColors.accentCyan,
        NotificationCategory.combat => AppColors.mysticRuby,
        NotificationCategory.social => AppColors.cyberFuchsia,
        NotificationCategory.rewards => AppColors.warningSolar,
      };

  /// Determines whether a given [NotificationKind] belongs to this category.
  bool matches(NotificationKind kind) {
    if (this == NotificationCategory.all) return true;

    return switch (this) {
      NotificationCategory.all => true,
      NotificationCategory.system => switch (kind) {
          NotificationKind.facilityReady ||
          NotificationKind.hospital ||
          NotificationKind.hospitalDischarge ||
          NotificationKind.prison ||
          NotificationKind.nightMarketOpen ||
          NotificationKind.nightMarketEnding ||
          NotificationKind.bugReportUpdate ||
          NotificationKind.marketSale ||
          NotificationKind.craftReady =>
            true,
          _ => false,
        },
      NotificationCategory.combat => switch (kind) {
          NotificationKind.pvpInvite ||
          NotificationKind.pvpResult ||
          NotificationKind.nemesisRevenge ||
          NotificationKind.nemesisOnline ||
          NotificationKind.lowHealth ||
          NotificationKind.healthFull ||
          NotificationKind.classBuff =>
            true,
          _ => false,
        },
      NotificationCategory.social => switch (kind) {
          NotificationKind.friendRequest ||
          NotificationKind.friendRequestAccepted ||
          NotificationKind.friendRequestRejected ||
          NotificationKind.tradeInvite ||
          NotificationKind.chatMessage =>
            true,
          _ => false,
        },
      NotificationCategory.rewards => switch (kind) {
          NotificationKind.dailyReward ||
          NotificationKind.questReward ||
          NotificationKind.referralReward ||
          NotificationKind.boxReady ||
          NotificationKind.codexNewEntry ||
          NotificationKind.codexMilestone =>
            true,
          _ => false,
        },
    };
  }

  /// Filters a list of notification items to only those belonging to this category.
  List<GameNotificationItem> filter(Iterable<GameNotificationItem> items) {
    if (this == NotificationCategory.all) {
      return items.toList(growable: false);
    }
    return items.where((GameNotificationItem item) => matches(item.kind)).toList(growable: false);
  }

  /// Calculates the count of unread (visible) notifications in this category.
  int countUnread(Iterable<GameNotificationItem> items) {
    if (this == NotificationCategory.all) {
      return items.length;
    }
    int count = 0;
    for (final GameNotificationItem item in items) {
      if (matches(item.kind)) count++;
    }
    return count;
  }
}
