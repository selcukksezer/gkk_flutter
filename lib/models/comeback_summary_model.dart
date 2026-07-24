import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum ComebackItemKind {
  facilityReady,
  boxReady,
  hospital,
  prison,
  guildWar,
  guildSiege,
  friendRequest,
  referralReward,
  dailyReward,
  questReward,
  weeklyContract,
  energy,
  codexMilestone,
  nemesisRevenge,
  nightMarket,
}

extension ComebackItemKindX on ComebackItemKind {
  static ComebackItemKind fromString(String raw) => switch (raw) {
        'facility_ready' => ComebackItemKind.facilityReady,
        'box_ready' => ComebackItemKind.boxReady,
        'hospital' => ComebackItemKind.hospital,
        'prison' => ComebackItemKind.prison,
        'guild_war' => ComebackItemKind.guildWar,
        'guild_siege' => ComebackItemKind.guildSiege,
        'friend_request' => ComebackItemKind.friendRequest,
        'referral_reward' => ComebackItemKind.referralReward,
        'daily_reward' => ComebackItemKind.dailyReward,
        'quest_reward' => ComebackItemKind.questReward,
        'weekly_contract' => ComebackItemKind.weeklyContract,
        'energy' => ComebackItemKind.energy,
        'codex_milestone' => ComebackItemKind.codexMilestone,
        'nemesis_revenge' => ComebackItemKind.nemesisRevenge,
        'night_market' => ComebackItemKind.nightMarket,
        _ => ComebackItemKind.energy,
      };

  IconData get icon => switch (this) {
        ComebackItemKind.facilityReady => Icons.factory_rounded,
        ComebackItemKind.boxReady => Icons.inventory_2_rounded,
        ComebackItemKind.hospital => Icons.local_hospital_rounded,
        ComebackItemKind.prison => Icons.gavel_rounded,
        ComebackItemKind.guildWar => Icons.shield_rounded,
        ComebackItemKind.guildSiege => Icons.castle_rounded,
        ComebackItemKind.friendRequest => Icons.person_add_alt_1_rounded,
        ComebackItemKind.referralReward => Icons.card_giftcard_rounded,
        ComebackItemKind.dailyReward => Icons.calendar_today_rounded,
        ComebackItemKind.questReward => Icons.task_alt_rounded,
        ComebackItemKind.weeklyContract => Icons.assignment_rounded,
        ComebackItemKind.energy => Icons.bolt_rounded,
        ComebackItemKind.codexMilestone => Icons.menu_book_rounded,
        ComebackItemKind.nemesisRevenge => Icons.sports_mma_rounded,
        ComebackItemKind.nightMarket => Icons.nights_stay_rounded,
      };

  Color get accentColor => switch (this) {
        ComebackItemKind.facilityReady => AppColors.liquidGold,
        ComebackItemKind.boxReady => AppColors.warningSolar,
        ComebackItemKind.hospital => AppColors.mysticRuby,
        ComebackItemKind.prison => AppColors.coralFlare,
        ComebackItemKind.guildWar => AppColors.cyberFuchsia,
        ComebackItemKind.guildSiege => AppColors.cyberFuchsia,
        ComebackItemKind.friendRequest => AppColors.cyberFuchsia,
        ComebackItemKind.referralReward => AppColors.warningSolar,
        ComebackItemKind.dailyReward => AppColors.liquidGold,
        ComebackItemKind.questReward => AppColors.toxicNeon,
        ComebackItemKind.weeklyContract => AppColors.accentPurple,
        ComebackItemKind.energy => AppColors.accentCyan,
        ComebackItemKind.codexMilestone => AppColors.liquidGold,
        ComebackItemKind.nemesisRevenge => AppColors.mysticRuby,
        ComebackItemKind.nightMarket => AppColors.warningSolar,
      };
}

class ComebackSummaryItem {
  const ComebackSummaryItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.priority,
    required this.ctaLabel,
  });

  final String id;
  final ComebackItemKind kind;
  final String title;
  final String subtitle;
  final String route;
  final int priority;
  final String ctaLabel;

  factory ComebackSummaryItem.fromJson(Map<String, dynamic> json) {
    return ComebackSummaryItem(
      id: (json['id'] ?? '').toString(),
      kind: ComebackItemKindX.fromString((json['kind'] ?? '').toString()),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      route: (json['route'] ?? '').toString(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      ctaLabel: (json['cta_label'] ?? 'Git').toString(),
    );
  }
}

class ComebackSummary {
  const ComebackSummary({
    required this.showSummary,
    required this.offlineHours,
    required this.pendingCount,
    required this.items,
  });

  final bool showSummary;
  final double offlineHours;
  final int pendingCount;
  final List<ComebackSummaryItem> items;

  List<ComebackSummaryItem> get actionableItems =>
      items.where((ComebackSummaryItem i) => i.kind != ComebackItemKind.energy).toList(growable: false);

  factory ComebackSummary.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawItems = json['items'] is List
        ? json['items'] as List
        : const <dynamic>[];
    return ComebackSummary(
      showSummary: json['show_summary'] == true,
      offlineHours: (json['offline_hours'] as num?)?.toDouble() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      items: rawItems
          .whereType<Map>()
          .map((dynamic row) => ComebackSummaryItem.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false),
    );
  }
}
