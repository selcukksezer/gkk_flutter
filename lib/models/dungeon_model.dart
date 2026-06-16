import 'dart:convert';

class DungeonPlayerStats {
  const DungeonPlayerStats({
    this.totalAttempts = 0,
    this.totalSuccesses = 0,
    this.firstClearAt,
    this.todayAttempts = 0,
    this.todayBossAttempts = 0,
    this.runsSinceBestRarity = 0,
  });

  final int totalAttempts;
  final int totalSuccesses;
  final String? firstClearAt;
  final int todayAttempts;
  final int todayBossAttempts;
  final int runsSinceBestRarity;

  bool get hasFirstClear => firstClearAt != null && firstClearAt!.isNotEmpty;

  int get successRatePercent =>
      totalAttempts <= 0 ? 0 : ((totalSuccesses / totalAttempts) * 100).round();

  factory DungeonPlayerStats.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const DungeonPlayerStats();
    return DungeonPlayerStats(
      totalAttempts: _asInt(json['total_attempts']),
      totalSuccesses: _asInt(json['total_successes']),
      firstClearAt: json['first_clear_at']?.toString(),
      todayAttempts: _asInt(json['today_attempts']),
      todayBossAttempts: _asInt(json['today_boss_attempts']),
      runsSinceBestRarity: _asInt(json['runs_since_best_rarity']),
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class DungeonData {
  const DungeonData({
    required this.id,
    required this.dungeonId,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.requiredLevel,
    required this.maxPlayers,
    required this.energyCost,
    required this.minGold,
    required this.maxGold,
    required this.lootTable,
    required this.isGroup,
    this.powerRequirement,
    this.zone = 1,
    this.isBoss = false,
    this.dailyBossLimit = 3,
    this.playerStats,
    this.equipmentDropChance = 0,
    this.resourceDropChance = 0,
    this.scrollDropChance = 0,
    this.catalystDropChance = 0,
    this.rarityWeights = const <String, double>{},
  });

  final String id;
  final String dungeonId;
  final String name;
  final String description;
  final String difficulty;
  final int requiredLevel;
  final int maxPlayers;
  final int energyCost;
  final int minGold;
  final int maxGold;
  final List<String> lootTable;
  final bool isGroup;
  final int? powerRequirement;
  final int zone;
  final bool isBoss;
  final int dailyBossLimit;
  final DungeonPlayerStats? playerStats;
  final double equipmentDropChance;
  final double resourceDropChance;
  final double scrollDropChance;
  final double catalystDropChance;
  final Map<String, double> rarityWeights;

  bool get hasLootPreview =>
      equipmentDropChance > 0 ||
      resourceDropChance > 0 ||
      scrollDropChance > 0 ||
      catalystDropChance > 0 ||
      rarityWeights.isNotEmpty;

  factory DungeonData.fromJson(Map<String, dynamic> json) {
    List<String> loot = _parseLootTable(
      json['loot_table'] ?? json['lootTable'] ?? json['loot'] ?? json['drops'],
    );
    final bool isGroup = _asBool(json['is_group']) ||
        _asInt(json['max_players'], fallback: 1) > 1;

    final List<String> rarityRows = _parseRarityWeights(json['loot_rarity_weights']);
    if (rarityRows.isNotEmpty) {
      loot = <String>[...rarityRows, ...loot];
    }

    if (loot.isEmpty) {
      final double equipmentChance = _asDouble(json['equipment_drop_chance']);
      final double resourceChance = _asDouble(json['resource_drop_chance']);
      final double catalystChance = _asDouble(json['catalyst_drop_chance']);
      final double scrollChance = _asDouble(json['scroll_drop_chance']);

      if (equipmentChance > 0) {
        loot.add('equipment ${(equipmentChance * 100).toStringAsFixed(0)}%');
      }
      if (resourceChance > 0) {
        loot.add('resource ${(resourceChance * 100).toStringAsFixed(0)}%');
      }
      if (catalystChance > 0) {
        loot.add('catalyst ${(catalystChance * 100).toStringAsFixed(0)}%');
      }
      if (scrollChance > 0) {
        loot.add('scroll ${(scrollChance * 100).toStringAsFixed(0)}%');
      }
    }

    final int? rawPowerReq = json['power_requirement'] == null
        ? null
        : _asInt(json['power_requirement']);

    int requiredLevel;
    if (json['required_level'] != null) {
      requiredLevel = _asInt(json['required_level'], fallback: 1);
    } else if (rawPowerReq != null && rawPowerReq > 0) {
      requiredLevel = (rawPowerReq / 500).floor();
      if (requiredLevel < 1) requiredLevel = 1;
    } else {
      requiredLevel = 1;
    }

    final int effectivePower = rawPowerReq ?? (requiredLevel * 500);

    final bool isBoss = json['is_boss'] == true;
    final String difficulty;
    if (isBoss) {
      difficulty = 'dungeon';
    } else if (effectivePower <= 0) {
      difficulty = 'easy';
    } else if (effectivePower < 15000) {
      difficulty = 'easy';
    } else if (effectivePower < 45000) {
      difficulty = 'medium';
    } else {
      difficulty = 'hard';
    }

    return DungeonData(
      id: (json['id'] ?? json['dungeon_id'] ?? '').toString(),
      dungeonId: (json['dungeon_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Dungeon').toString(),
      description: (json['description'] ?? '').toString(),
      difficulty: difficulty,
      requiredLevel: requiredLevel,
      maxPlayers: _asInt(json['max_players'], fallback: 1),
      energyCost: _asInt(json['energy_cost']),
      // Support both naming conventions coming from RPC/table payloads.
      minGold: _asInt(json['min_gold'] ?? json['gold_min']),
      maxGold: _asInt(json['max_gold'] ?? json['gold_max']),
      lootTable: loot,
      isGroup: isGroup,
      powerRequirement: rawPowerReq,
      zone: _asInt(json['zone'], fallback: 1),
      isBoss: json['is_boss'] == true,
      dailyBossLimit: _asInt(json['daily_boss_limit'], fallback: 3),
      equipmentDropChance: _asDouble(json['equipment_drop_chance']),
      resourceDropChance: _asDouble(json['resource_drop_chance']),
      scrollDropChance: _asDouble(json['scroll_drop_chance']),
      catalystDropChance: _asDouble(json['catalyst_drop_chance']),
      rarityWeights: _parseRarityWeightsMap(json['loot_rarity_weights']),
      playerStats: json['total_attempts'] != null || json['player_stats'] != null
          ? DungeonPlayerStats.fromJson(
              json['player_stats'] is Map
                  ? Map<String, dynamic>.from(json['player_stats'] as Map)
                  : json,
            )
          : null,
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String n = value.toLowerCase().trim();
      if (n == 'true' || n == '1' || n == 'yes') return true;
      if (n == 'false' || n == '0' || n == 'no') return false;
    }
    return fallback;
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static List<String> _parseLootTable(dynamic raw) {
    if (raw == null) return <String>[];

    if (raw is List) {
      final List<String> out = <String>[];
      for (final dynamic entry in raw) {
        if (entry == null) continue;
        if (entry is String) {
          out.add(entry);
          continue;
        }
        if (entry is Map) {
          final Map<dynamic, dynamic> map = entry;
          final dynamic named = map['item_name'] ?? map['item_id'] ?? map['name'] ?? map['type'];
          if (named != null) {
            out.add(named.toString());
          }
          continue;
        }
        out.add(entry.toString());
      }
      return out;
    }

    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) return <String>[];
      if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
          (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
        try {
          final dynamic decoded = jsonDecode(trimmed);
          return _parseLootTable(decoded);
        } catch (_) {
          return <String>[trimmed];
        }
      }
      return <String>[trimmed];
    }

    if (raw is Map) {
      final List<String> out = <String>[];
      raw.forEach((key, value) {
        if (value == null) return;
        out.add('$key:$value');
      });
      return out;
    }

    return <String>[raw.toString()];
  }

  static List<String> _parseRarityWeights(dynamic raw) {
    if (raw == null) return <String>[];

    Map<String, dynamic>? map;
    if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) return <String>[];
      try {
        final dynamic decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          map = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return <String>[];
      }
    }

    if (map == null || map.isEmpty) return <String>[];

    const List<String> preferredOrder = <String>[
      'mythic',
      'legendary',
      'epic',
      'rare',
      'uncommon',
      'common',
    ];

    final List<String> rows = <String>[];
    for (final String key in preferredOrder) {
      if (!map.containsKey(key)) continue;
      final double pct = _asDouble(map[key]) * 100;
      if (pct <= 0) continue;
      rows.add('$key ${pct.toStringAsFixed(0)}%');
    }

    map.forEach((dynamic rawKey, dynamic value) {
      final String key = rawKey.toString().toLowerCase();
      if (preferredOrder.contains(key)) return;
      final double pct = _asDouble(value) * 100;
      if (pct <= 0) return;
      rows.add('$key ${pct.toStringAsFixed(0)}%');
    });

    return rows;
  }

  static Map<String, double> _parseRarityWeightsMap(dynamic raw) {
    if (raw == null) return const <String, double>{};

    Map<String, dynamic>? map;
    if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) return const <String, double>{};
      try {
        final dynamic decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          map = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return const <String, double>{};
      }
    }

    if (map == null || map.isEmpty) return const <String, double>{};

    final Map<String, double> out = <String, double>{};
    map.forEach((dynamic rawKey, dynamic value) {
      final double weight = _asDouble(value);
      if (weight <= 0) return;
      out[rawKey.toString().toLowerCase()] = weight;
    });
    return out;
  }
}

class DungeonItemDrop {
  const DungeonItemDrop({
    required this.itemId,
    required this.name,
    required this.rarity,
    required this.type,
  });

  final String itemId;
  final String name;
  final String rarity;
  final String type;

  factory DungeonItemDrop.fromJson(Map<String, dynamic> json) {
    final String itemId = (json['item_id'] ?? json['itemId'] ?? '').toString();
    return DungeonItemDrop(
      itemId: itemId,
      name: (json['name'] ?? json['item_name'] ?? itemId).toString(),
      rarity: (json['rarity'] ?? 'common').toString(),
      type: (json['type'] ?? '').toString(),
    );
  }
}

class DungeonMilestoneReward {
  const DungeonMilestoneReward({
    required this.milestone,
    required this.label,
    this.gold = 0,
    this.itemName,
  });

  final int milestone;
  final String label;
  final int gold;
  final String? itemName;

  factory DungeonMilestoneReward.fromJson(Map<String, dynamic> json) {
    return DungeonMilestoneReward(
      milestone: _asInt(json['milestone']),
      label: (json['label'] ?? '').toString(),
      gold: _asInt(json['gold']),
      itemName: json['item_name']?.toString(),
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class DungeonResult {
  const DungeonResult({
    required this.success,
    this.error,
    this.isCritical = false,
    this.isFirstClear = false,
    this.goldEarned = 0,
    this.xpEarned = 0,
    this.items = const <String>[],
    this.itemDetails = const <DungeonItemDrop>[],
    this.hospitalized = false,
    this.hospitalUntil,
    this.hospitalDurationSeconds,
    this.rewardMultiplier,
    this.hospitalRiskPct,
    this.inventoryFull = false,
    this.milestoneRewards = const <DungeonMilestoneReward>[],
  });

  final bool success;
  final String? error;
  final bool isCritical;
  final bool isFirstClear;
  final int goldEarned;
  final int xpEarned;
  final List<String> items;
  final List<DungeonItemDrop> itemDetails;
  final bool hospitalized;
  final String? hospitalUntil;
  final int? hospitalDurationSeconds;
  final double? rewardMultiplier;
  final double? hospitalRiskPct;
  final bool inventoryFull;
  final List<DungeonMilestoneReward> milestoneRewards;

  factory DungeonResult.fromJson(Map<String, dynamic> json) {
    final dynamic itemsRaw = json['items'] ?? json['items_dropped'] ?? json['item_details'];
    final List<String> itemList = <String>[];
    final List<DungeonItemDrop> itemDetails = <DungeonItemDrop>[];

    if (itemsRaw is List) {
      for (final dynamic e in itemsRaw) {
        if (e is Map) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(e);
          final DungeonItemDrop drop = DungeonItemDrop.fromJson(map);
          itemDetails.add(drop);
          itemList.add(drop.name.isNotEmpty ? drop.name : drop.itemId);
        } else {
          final String s = e.toString();
          itemList.add(s);
          itemDetails.add(DungeonItemDrop(
            itemId: s,
            name: s,
            rarity: 'common',
            type: '',
          ));
        }
      }
    }

    final dynamic milestoneRaw = json['milestone_rewards'];
    final List<DungeonMilestoneReward> milestones = <DungeonMilestoneReward>[];
    if (milestoneRaw is List) {
      for (final dynamic e in milestoneRaw) {
        if (e is Map) {
          milestones.add(DungeonMilestoneReward.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }

    return DungeonResult(
      success: (json['success'] as bool?) ?? false,
      error: json['error'] as String?,
      isCritical: (json['is_critical'] as bool?) ?? false,
      isFirstClear: (json['is_first_clear'] as bool?) ?? false,
      goldEarned: _asInt(json['gold_earned'] ?? json['gold']),
      xpEarned: _asInt(json['xp_earned'] ?? json['xp']),
      items: itemList,
      itemDetails: itemDetails,
      hospitalized: (json['hospitalized'] as bool?) ?? false,
      hospitalUntil: json['hospital_until'] as String?,
      hospitalDurationSeconds: json['hospital_duration'] == null
          ? null
          : _asInt(json['hospital_duration']),
      rewardMultiplier: json['reward_multiplier'] == null
          ? null
          : _asDouble(json['reward_multiplier']),
      hospitalRiskPct: json['hospital_risk_pct'] == null
          ? null
          : _asDouble(json['hospital_risk_pct']),
      inventoryFull: json['inventory_full'] == true,
      milestoneRewards: milestones,
    );
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
