import 'package:flutter/material.dart';

import '../../../models/live_ticker_model.dart';
import '../../../theme/app_colors.dart';

/// Announcement category / type.
enum AnnouncementType {
  event,
  patchNotes,
  maintenance,
  broadcast,
  liveTicker,
}

/// Status of a time-limited event.
enum EventStatus {
  upcoming,
  active,
  endingSoon,
  ended,
}

/// Item reward for claimable event gifts.
class EventRewardItem {
  const EventRewardItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.quantity,
    this.rarity = 'rare',
    this.description = '',
  });

  final String id;
  final String name;
  final String icon;
  final int quantity;
  final String rarity;
  final String description;

  Color get rarityColor => AppColors.forRarity(rarity);
}

/// Complete data model for an Announcement or Event.
class AnnouncementItem {
  const AnnouncementItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.contentMarkdown,
    required this.type,
    required this.publishedAt,
    this.accentColor = AppColors.liquidGold,
    this.badgeLabel = 'DUYURU',
    this.eventStartTime,
    this.eventEndTime,
    this.isHeroBanner = false,
    this.bannerGradient = const <Color>[
      Color(0xFF1E1535),
      Color(0xFF0F1A30),
      Color(0xFF080B12),
    ],
    this.rewards = const <EventRewardItem>[],
    this.isClaimable = false,
    this.versionTag,
    this.author = 'Aion 2 Komutanlığı',
  });

  final String id;
  final String title;
  final String subtitle;
  final String contentMarkdown;
  final AnnouncementType type;
  final DateTime publishedAt;
  final Color accentColor;
  final String badgeLabel;
  final DateTime? eventStartTime;
  final DateTime? eventEndTime;
  final bool isHeroBanner;
  final List<Color> bannerGradient;
  final List<EventRewardItem> rewards;
  final bool isClaimable;
  final String? versionTag;
  final String author;

  bool get hasEventSchedule => eventEndTime != null;

  EventStatus get eventStatus {
    if (eventEndTime == null) return EventStatus.ended;
    final DateTime now = DateTime.now();
    if (eventStartTime != null && now.isBefore(eventStartTime!)) {
      return EventStatus.upcoming;
    }
    if (now.isAfter(eventEndTime!)) {
      return EventStatus.ended;
    }
    final Duration remaining = eventEndTime!.difference(now);
    if (remaining.inHours < 6) {
      return EventStatus.endingSoon;
    }
    return EventStatus.active;
  }

  /// Maps a live server ticker item into a unified AnnouncementItem.
  factory AnnouncementItem.fromLiveTickerItem(LiveTickerItem ticker) {
    Color accent = AppColors.liquidGold;
    String badge = 'SUNUCU';
    String icon = '📢';

    switch (ticker.type) {
      case 'dungeon_clear':
        accent = AppColors.mysticRuby;
        badge = 'BOSS TEMİZLENDİ';
        icon = '⚔️';
        break;
      case 'enhance_success':
        accent = AppColors.liquidGold;
        badge = '+8 GÜÇLENDİRME';
        icon = '✨';
        break;
      case 'loot_rare':
        accent = AppColors.cyberFuchsia;
        badge = 'NADİR LOOT';
        icon = '🎁';
        break;
      case 'guild_war':
        accent = AppColors.toxicNeon;
        badge = 'LONCA SAVAŞI';
        icon = '🛡️';
        break;
      case 'siege_win':
      case 'siege_soon':
      case 'siege_start':
      case 'siege_live':
        accent = AppColors.mysticRuby;
        badge = 'KUŞATMA';
        icon = '🔥';
        break;
      case 'night_market':
        accent = AppColors.cyberFuchsia;
        badge = 'GECE PAZARI';
        icon = '🌙';
        break;
      case 'king_blessing':
      case 'king_gift':
        accent = AppColors.liquidGold;
        badge = 'KRALİYET LÜTFU';
        icon = '👑';
        break;
      case 'staff_broadcast':
        accent = AppColors.accentCyan;
        badge = 'RESMİ YAYIN';
        icon = '📢';
        break;
      case 'player_ban':
        accent = AppColors.danger;
        badge = 'YARGI İNFAZ';
        icon = '🚫';
        break;
    }

    return AnnouncementItem(
      id: ticker.id,
      title: '$icon $badge',
      subtitle: ticker.text,
      contentMarkdown: '''
### $badge
**Yayın Zamanı:** ${ticker.createdAt != null ? ticker.createdAt!.toLocal().toString().split('.').first : 'Canlı'}

> ${ticker.text}

---
*Bu bildirim Aion 2 sunucu ağından anlık olarak iletilmiştir.*
''',
      type: AnnouncementType.liveTicker,
      publishedAt: ticker.createdAt ?? DateTime.now(),
      accentColor: accent,
      badgeLabel: badge,
      author: 'Sunucu Gözcüsü',
    );
  }
}
