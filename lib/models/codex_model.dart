class CodexMilestone {
  const CodexMilestone({
    required this.threshold,
    required this.claimed,
    required this.claimable,
    this.rewardGold = 0,
    this.rewardGems = 0,
    this.rewardLabel,
    this.rewardKind,
  });

  final int threshold;
  final bool claimed;
  final bool claimable;
  final int rewardGold;
  final int rewardGems;
  final String? rewardLabel;
  final String? rewardKind;

  String get label {
    if (rewardLabel != null && rewardLabel!.isNotEmpty) {
      return '$threshold keşif — $rewardLabel';
    }
    return switch (threshold) {
      10 => '10 keşif — 100.000 Altın',
      20 => '20 keşif — 150.000 Altın',
      30 => '30 keşif — 200.000 Altın',
      40 => '40 keşif — 300.000 Altın + 1 Elmas',
      50 => '50 keşif — 400.000 Altın + 3 Elmas + loot şansı',
      75 => '75 keşif — 500.000 Altın + 5 Elmas',
      100 => '100 keşif — 750.000 Altın + 8 Elmas',
      125 => '125 keşif — 1M Altın + 10 Elmas',
      150 => '150 keşif — 1.25M Altın + 12 Elmas',
      200 => '200 keşif — 1.5M Altın + 15 Elmas',
      250 => '250 keşif — 2M Altın + 18 Elmas',
      300 => '300 keşif — 2.5M Altın + 25 Elmas',
      350 => '350 keşif — 3.5M Altın + 30 Elmas',
      400 => '400 keşif — 5M Altın + 45 Elmas + rozet',
      _ => '$threshold keşif',
    };
  }

  String get shortRewardLabel {
    if (rewardLabel != null && rewardLabel!.isNotEmpty) return rewardLabel!;
    if (rewardGems > 0 && rewardGold > 0) {
      return '${_fmtGold(rewardGold)} + $rewardGems💎';
    }
    if (rewardGems > 0) return '$rewardGems Elmas';
    if (rewardGold > 0) return '${_fmtGold(rewardGold)} Altın';
    return 'Ödül';
  }

  static String _fmtGold(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(0)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return '$value';
  }

  factory CodexMilestone.fromJson(Map<String, dynamic> json) {
    return CodexMilestone(
      threshold: (json['threshold'] as num?)?.toInt() ?? 0,
      claimed: json['claimed'] == true,
      claimable: json['claimable'] == true,
      rewardGold: (json['reward_gold'] as num?)?.toInt() ?? 0,
      rewardGems: (json['reward_gems'] as num?)?.toInt() ?? 0,
      rewardLabel: json['reward_label']?.toString(),
      rewardKind: json['reward_kind']?.toString(),
    );
  }
}

class CodexDashboard {
  const CodexDashboard({
    required this.discovered,
    required this.total,
    required this.newEntries24h,
    required this.claimableMilestones,
    required this.luckBonus,
    required this.milestones,
  });

  final int discovered;
  final int total;
  final int newEntries24h;
  final int claimableMilestones;
  final int luckBonus;
  final List<CodexMilestone> milestones;

  double get progress => total <= 0 ? 0 : discovered / total;

  factory CodexDashboard.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawMs = json['milestones'] is List
        ? json['milestones'] as List
        : const <dynamic>[];
    return CodexDashboard(
      discovered: (json['discovered'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      newEntries24h: (json['new_entries_24h'] as num?)?.toInt() ?? 0,
      claimableMilestones: (json['claimable_milestones'] as num?)?.toInt() ?? 0,
      luckBonus: (json['luck_bonus'] as num?)?.toInt() ?? 0,
      milestones: rawMs
          .whereType<Map>()
          .map((dynamic m) => CodexMilestone.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
    );
  }
}

/// Turkish label for codex catalog `zone` hint (item type or dungeon zone key).
String codexHintLabel(String? hint, {required String entryType}) {
  final String raw = (hint ?? '').trim().toLowerCase();
  if (raw.isEmpty) return entryType == 'item' ? 'Genel' : 'Bilinmiyor';

  if (raw.startsWith('zone_')) {
    final String zoneNum = raw.replaceFirst('zone_', '');
    return 'Bölge $zoneNum';
  }

  return switch (raw) {
    'weapon' => 'Silah',
    'armor' => 'Zırh',
    'potion' => 'İksir',
    'consumable' => 'Sarf',
    'material' => 'Malzeme',
    'scroll' => 'Parşömen',
    'rune' => 'Rün',
    'recipe' => 'Tarif',
    'cosmetic' => 'Kozmetik',
    'accessory' => 'Aksesuar',
    'genel' => 'Genel',
    'boss' => 'Boss',
    'normal' => 'Zindan',
    _ => _titleCaseHint(raw),
  };
}

String _titleCaseHint(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

String codexRarityLabel(String? rarity) {
  return switch ((rarity ?? '').toLowerCase()) {
    'common' => 'Yaygın',
    'uncommon' => 'Olağanüstü',
    'rare' => 'Nadir',
    'epic' => 'Destansı',
    'legendary' => 'Efsanevi',
    'mythic' => 'Mitik',
    'boss' => 'Boss',
    'normal' => 'Normal',
    _ => rarity == null || rarity.isEmpty ? '' : _titleCaseHint(rarity),
  };
}

class CodexEntry {
  const CodexEntry({
    required this.entryType,
    required this.entryKey,
    required this.displayName,
    this.rarity,
    this.zone,
    required this.isDiscovered,
    this.discoveredAt,
  });

  final String entryType;
  final String entryKey;
  final String displayName;
  final String? rarity;
  final String? zone;
  final bool isDiscovered;
  final DateTime? discoveredAt;

  String get hintLabel => codexHintLabel(zone, entryType: entryType);

  bool get showsZonePin =>
      (zone ?? '').trim().toLowerCase().startsWith('zone_') ||
      entryType == 'dungeon' ||
      entryType == 'boss';

  factory CodexEntry.fromJson(Map<String, dynamic> json) {
    return CodexEntry(
      entryType: (json['entry_type'] ?? '').toString(),
      entryKey: (json['entry_key'] ?? '').toString(),
      displayName: (json['display_name'] ?? json['entry_key'] ?? '').toString(),
      rarity: json['rarity']?.toString(),
      zone: json['zone']?.toString(),
      isDiscovered: json['is_discovered'] == true,
      discoveredAt: json['discovered_at'] == null
          ? null
          : DateTime.tryParse(json['discovered_at'].toString()),
    );
  }
}

class CodexDiscovery {
  const CodexDiscovery({
    required this.entryType,
    required this.entryKey,
    required this.displayName,
    this.rarity,
  });

  final String entryType;
  final String entryKey;
  final String displayName;
  final String? rarity;

  factory CodexDiscovery.fromJson(Map<String, dynamic> json) {
    return CodexDiscovery(
      entryType: (json['entry_type'] ?? '').toString(),
      entryKey: (json['entry_key'] ?? '').toString(),
      displayName: (json['display_name'] ?? json['entry_key'] ?? '').toString(),
      rarity: json['rarity']?.toString(),
    );
  }
}
