import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bildirim kategorileri — ana ekran çanı / inbox.
enum NotificationKind {
  friendRequest,
  friendRequestAccepted,
  friendRequestRejected,
  referralReward,
  dailyReward,
  questReward,
  pvpInvite,
  pvpResult,
  tradeInvite,
  chatMessage,
  boxReady,
  facilityReady,
  hospital,
  prison,
  lowHealth,
}

extension NotificationKindX on NotificationKind {
  IconData get icon => switch (this) {
        NotificationKind.friendRequest => Icons.person_add_alt_1_rounded,
        NotificationKind.friendRequestAccepted => Icons.person_pin_rounded,
        NotificationKind.friendRequestRejected => Icons.person_off_outlined,
        NotificationKind.referralReward => Icons.card_giftcard_rounded,
        NotificationKind.dailyReward => Icons.calendar_today_rounded,
        NotificationKind.questReward => Icons.task_alt_rounded,
        NotificationKind.pvpInvite => Icons.sports_mma_rounded,
        NotificationKind.pvpResult => Icons.emoji_events_rounded,
        NotificationKind.tradeInvite => Icons.handshake_rounded,
        NotificationKind.chatMessage => Icons.chat_bubble_rounded,
        NotificationKind.boxReady => Icons.inventory_2_rounded,
        NotificationKind.facilityReady => Icons.factory_rounded,
        NotificationKind.hospital => Icons.local_hospital_rounded,
        NotificationKind.prison => Icons.gavel_rounded,
        NotificationKind.lowHealth => Icons.favorite_border_rounded,
      };

  Color get accentColor => switch (this) {
        NotificationKind.friendRequest => AppColors.cyberFuchsia,
        NotificationKind.friendRequestAccepted => AppColors.toxicNeon,
        NotificationKind.friendRequestRejected => AppColors.coralFlare,
        NotificationKind.referralReward => AppColors.warningSolar,
        NotificationKind.dailyReward => AppColors.liquidGold,
        NotificationKind.questReward => AppColors.toxicNeon,
        NotificationKind.pvpInvite => AppColors.cyberFuchsia,
        NotificationKind.pvpResult => AppColors.coralFlare,
        NotificationKind.tradeInvite => AppColors.liquidGold,
        NotificationKind.chatMessage => AppColors.cyberFuchsia,
        NotificationKind.boxReady => AppColors.warningSolar,
        NotificationKind.facilityReady => AppColors.liquidGold,
        NotificationKind.hospital => AppColors.mysticRuby,
        NotificationKind.prison => AppColors.coralFlare,
        NotificationKind.lowHealth => AppColors.mysticRuby,
      };

  String get sectionLabel => switch (this) {
        NotificationKind.friendRequest => 'Arkadaşlık',
        NotificationKind.friendRequestAccepted => 'Arkadaşlık',
        NotificationKind.friendRequestRejected => 'Arkadaşlık',
        NotificationKind.referralReward => 'Referans',
        NotificationKind.dailyReward => 'Günlük ödül',
        NotificationKind.questReward => 'Görevler',
        NotificationKind.pvpInvite => 'PvP',
        NotificationKind.pvpResult => 'PvP',
        NotificationKind.tradeInvite => 'Ticaret',
        NotificationKind.chatMessage => 'Mesajlar',
        NotificationKind.boxReady => 'Kasa',
        NotificationKind.facilityReady => 'Tesisler',
        NotificationKind.hospital => 'Hastane',
        NotificationKind.prison => 'Hapishane',
        NotificationKind.lowHealth => 'Sağlık',
      };
}

/// Tek bildirim satırı.
class GameNotificationItem {
  const GameNotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.routePath,
    this.routeExtra,
    this.priority = 0,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? routePath;
  final Map<String, String>? routeExtra;
  final int priority;

  bool get isActionable => routePath != null;
}
