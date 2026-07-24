import 'package:flutter/material.dart';

/// Static earn-source definitions for the reputation hub UI.
class ReputationEarnSource {
  const ReputationEarnSource({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.repRange,
    this.accent,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final String repRange;
  final Color? accent;
}

/// Faction row from server.
class FactionReputation {
  const FactionReputation({
    required this.factionId,
    required this.reputation,
  });

  final String factionId;
  final int reputation;

  factory FactionReputation.fromJson(Map<String, dynamic> json) => FactionReputation(
        factionId: (json['faction_id'] ?? json['id'] ?? '').toString(),
        reputation: _asInt(json['reputation'] ?? json['rep']),
      );

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Shop catalog item.
class ReputationShopItem {
  const ReputationShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.iconKey,
    required this.costType,
    required this.costAmount,
    required this.rarity,
    required this.effectKey,
    this.effectValue = const <String, dynamic>{},
    this.durationMinutes,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String description;
  final String iconKey;
  final String costType; // global | faction
  final int costAmount;
  final String rarity;
  final String effectKey;
  final Map<String, dynamic> effectValue;
  final int? durationMinutes;
  final int sortOrder;

  bool get usesFactionRep => costType == 'faction';

  factory ReputationShopItem.fromJson(Map<String, dynamic> json) => ReputationShopItem(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        iconKey: (json['icon_key'] ?? 'bolt').toString(),
        costType: (json['cost_type'] ?? 'global').toString(),
        costAmount: _asInt(json['cost_amount']),
        rarity: (json['rarity'] ?? 'common').toString(),
        effectKey: (json['effect_key'] ?? '').toString(),
        effectValue: json['effect_value'] is Map
            ? Map<String, dynamic>.from(json['effect_value'] as Map)
            : const <String, dynamic>{},
        durationMinutes: json['duration_minutes'] == null
            ? null
            : _asInt(json['duration_minutes']),
        sortOrder: _asInt(json['sort_order']),
      );

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Active timed buff from shop purchase.
class ReputationActiveBuff {
  const ReputationActiveBuff({
    required this.buffKey,
    required this.buffValue,
    required this.expiresAt,
  });

  final String buffKey;
  final double buffValue;
  final DateTime? expiresAt;

  factory ReputationActiveBuff.fromJson(Map<String, dynamic> json) {
    final String raw = (json['expires_at'] ?? '').toString();
    return ReputationActiveBuff(
      buffKey: (json['buff_key'] ?? '').toString(),
      buffValue: _asDouble(json['buff_value']),
      expiresAt: raw.isEmpty ? null : DateTime.tryParse(raw),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String label() {
    switch (buffKey) {
      case 'gold_boost':
        return 'Altın +${buffValue.toInt()}%';
      case 'drop_boost':
        return 'Loot +${buffValue.toInt()}%';
      case 'siege_rep_boost':
        return 'Kuşatma itibar +${buffValue.toInt()}%';
      default:
        return buffKey;
    }
  }
}

/// Activity log entry.
class ReputationActivityEntry {
  const ReputationActivityEntry({
    required this.id,
    required this.activityType,
    required this.source,
    required this.amount,
    required this.currency,
    this.factionId,
    this.createdAt,
  });

  final String id;
  final String activityType; // earn | spend
  final String source;
  final int amount;
  final String currency;
  final String? factionId;
  final DateTime? createdAt;

  bool get isEarn => activityType == 'earn';

  factory ReputationActivityEntry.fromJson(Map<String, dynamic> json) {
    final String raw = (json['created_at'] ?? '').toString();
    return ReputationActivityEntry(
      id: (json['id'] ?? '').toString(),
      activityType: (json['activity_type'] ?? 'earn').toString(),
      source: (json['source'] ?? '').toString(),
      amount: _asInt(json['amount']),
      currency: (json['currency'] ?? 'global').toString(),
      factionId: json['faction_id']?.toString(),
      createdAt: raw.isEmpty ? null : DateTime.tryParse(raw),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String displaySource() {
    if (source.startsWith('shop:')) {
      return 'Mağaza: ${source.replaceFirst('shop:', '')}';
    }
    if (source.startsWith('perk:')) {
      return 'Harca: ${source.replaceFirst('perk:', '')}';
    }
    switch (source) {
      case 'donation':
        return 'Altın bağışı';
      case 'pvp':
        return 'PvP';
      case 'dungeon':
        return 'Zindan';
      case 'siege':
        return 'Kuşatma';
      case 'quest':
        return 'Görev';
      case 'guild_war':
        return 'Lonca savaşı';
      case 'cosmetic_title':
        return 'Kozmetik unvan';
      default:
        return source;
    }
  }
}

/// Full overview payload.
class ReputationOverview {
  const ReputationOverview({
    required this.globalReputation,
    required this.factions,
    required this.activity,
    required this.activeBuffs,
    required this.shopItems,
  });

  final int globalReputation;
  final List<FactionReputation> factions;
  final List<ReputationActivityEntry> activity;
  final List<ReputationActiveBuff> activeBuffs;
  final List<ReputationShopItem> shopItems;

  factory ReputationOverview.empty() => const ReputationOverview(
        globalReputation: 0,
        factions: <FactionReputation>[],
        activity: <ReputationActivityEntry>[],
        activeBuffs: <ReputationActiveBuff>[],
        shopItems: <ReputationShopItem>[],
      );

  factory ReputationOverview.fromOverviewJson(Map<String, dynamic> overview) {
    final List<FactionReputation> factions = (overview['factions'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((Map e) => FactionReputation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final List<ReputationActivityEntry> activity =
        (overview['activity'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((Map e) => ReputationActivityEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
    final List<ReputationActiveBuff> buffs = (overview['active_buffs'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((Map e) => ReputationActiveBuff.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ReputationOverview(
      globalReputation: _asInt(overview['global_reputation']),
      factions: factions,
      activity: activity,
      activeBuffs: buffs,
      shopItems: const <ReputationShopItem>[],
    );
  }

  factory ReputationOverview.merge({
    required ReputationOverview overview,
    required List<ReputationShopItem> shopItems,
  }) =>
      ReputationOverview(
        globalReputation: overview.globalReputation,
        factions: overview.factions,
        activity: overview.activity,
        activeBuffs: overview.activeBuffs,
        shopItems: shopItems,
      );

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Faction metadata for UI.
class ReputationFactionDef {
  const ReputationFactionDef({
    required this.id,
    required this.icon,
    required this.name,
    required this.description,
    required this.accent,
  });

  final String id;
  final String icon;
  final String name;
  final String description;
  final Color accent;
}

const List<ReputationFactionDef> kReputationFactions = <ReputationFactionDef>[
  ReputationFactionDef(
    id: 'tuccarlar',
    icon: '🏪',
    name: 'Tüccarlar Birliği',
    description: 'Ticaret ve pazar indirimleri.',
    accent: Color(0xFFFFB800),
  ),
  ReputationFactionDef(
    id: 'zanaatkarlar',
    icon: '⚒️',
    name: 'Zanaatkarlar Loncası',
    description: 'Üretim ve ekipman bonusları.',
    accent: Color(0xFF00B4FF),
  ),
  ReputationFactionDef(
    id: 'maceracilar',
    icon: '⚔️',
    name: 'Maceracılar Rehberi',
    description: 'Zindan ve keşif görevleri.',
    accent: Color(0xFF00FF66),
  ),
  ReputationFactionDef(
    id: 'muhafizlar',
    icon: '🛡️',
    name: 'Şehir Muhafızları',
    description: 'Güvenlik ve ceza indirimleri.',
    accent: Color(0xFF8E9CAE),
  ),
  ReputationFactionDef(
    id: 'suc_orgutu',
    icon: '🗡️',
    name: 'Suç Örgütü',
    description: 'Gölge işler ve yüksek risk.',
    accent: Color(0xFFE01E5A),
  ),
];

ReputationFactionDef? factionDefFor(String id) {
  for (final ReputationFactionDef f in kReputationFactions) {
    if (f.id == id) return f;
  }
  return null;
}

/// Client-side earn catalog (linked routes).
List<ReputationEarnSource> defaultEarnSources() => const <ReputationEarnSource>[
      ReputationEarnSource(
        id: 'pvp',
        title: 'PvP & Arena',
        subtitle: 'Mekan düelloları, rating maçları',
        icon: Icons.sports_mma_rounded,
        route: '/pvp',
        repRange: '+50 – +250',
        accent: Color(0xFFE01E5A),
      ),
      ReputationEarnSource(
        id: 'dungeon',
        title: 'Zindan',
        subtitle: 'Temizleme, boss, ilk geçiş bonusu',
        icon: Icons.castle_rounded,
        route: '/dungeon',
        repRange: '+10 – +100',
        accent: Color(0xFF00B4FF),
      ),
      ReputationEarnSource(
        id: 'siege',
        title: 'Kuşatma Prime',
        subtitle: 'Slot tutarken ek itibar',
        icon: Icons.flag_rounded,
        route: '/dungeon/siege',
        repRange: '+3 – +30',
        accent: Color(0xFFFFB800),
      ),
      ReputationEarnSource(
        id: 'guild_war',
        title: 'Lonca Savaşı',
        subtitle: 'Saldırı ve savunma katkıları',
        icon: Icons.groups_rounded,
        route: '/guild-war',
        repRange: '+20 – +150',
        accent: Color(0xFF8A2BE2),
      ),
      ReputationEarnSource(
        id: 'quests',
        title: 'Günlük Görevler',
        subtitle: 'Quest tamamlama ödülleri',
        icon: Icons.task_alt_rounded,
        route: '/quests',
        repRange: '+50 – +200',
      ),
      ReputationEarnSource(
        id: 'mekan',
        title: 'Han PvP',
        subtitle: 'Mekan arenasında dövüş',
        icon: Icons.storefront_rounded,
        route: '/mekans',
        repRange: '+30 – +150',
        accent: Color(0xFF00FF66),
      ),
    ];

Color rarityBorderColor(String rarity) {
  switch (rarity) {
    case 'legendary':
      return const Color(0xFFFFB800);
    case 'epic':
      return const Color(0xFFE01E5A);
    case 'rare':
      return const Color(0xFF00B4FF);
    case 'uncommon':
      return const Color(0xFF00FF66);
    default:
      return const Color(0xFF8E9CAE);
  }
}

IconData shopIconForKey(String key) {
  switch (key) {
    case 'gold':
      return Icons.monetization_on_rounded;
    case 'loot':
      return Icons.inventory_2_rounded;
    case 'siege':
      return Icons.flag_rounded;
    case 'title':
      return Icons.military_tech_rounded;
    case 'bolt':
    default:
      return Icons.bolt_rounded;
  }
}

String factionTierLabel(int rep) {
  if (rep < 20) return 'Düşman';
  if (rep < 40) return 'Nötr';
  if (rep < 60) return 'Dostane';
  if (rep < 80) return 'Saygın';
  return 'Onurlu';
}

Color factionTierColor(int rep) {
  if (rep < 20) return const Color(0xFFE52E2E);
  if (rep < 40) return const Color(0xFF8E9CAE);
  if (rep < 60) return const Color(0xFF00B4FF);
  if (rep < 80) return const Color(0xFF00FF66);
  return const Color(0xFFFFB800);
}

/// Applies a percentage shop buff to a base reward value (gold, drop chance, etc.).
double applyReputationBuffPct({
  required double base,
  required double buffPct,
}) {
  if (buffPct <= 0) return base;
  return base * (1 + buffPct / 100.0);
}

/// Siege rep with Kuşatma Morali shop buff.
int computeSiegeRepGain({
  required double repBonusPct,
  int baseRep = 20,
  double siegeMoralePct = 0,
}) {
  if (repBonusPct <= 0) return 0;
  final double raw = baseRep * repBonusPct * (1 + siegeMoralePct / 100.0);
  return raw.floor().clamp(1, 999999);
}

/// Validates purchase affordability client-side (server is source of truth).
bool canAffordShopItem({
  required ReputationShopItem item,
  required int globalRep,
  required int factionRep,
}) {
  if (item.usesFactionRep) {
    return factionRep >= item.costAmount;
  }
  return globalRep >= item.costAmount;
}
