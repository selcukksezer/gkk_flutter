import 'package:intl/intl.dart';

class GuildWarSeason {
  final int season;
  final int week;
  final DateTime? endAt;

  const GuildWarSeason({
    required this.season,
    required this.week,
    this.endAt,
  });

  factory GuildWarSeason.fromJson(Map<String, dynamic> json) {
    return GuildWarSeason(
      season: _asInt(json['season'], fallback: 1),
      week: _asInt(json['week'], fallback: 1),
      endAt: json['end_at'] != null
          ? DateTime.tryParse(json['end_at'].toString())
          : null,
    );
  }
}

class GuildWarTournament {
  final String id;
  final String name;
  final String status;
  final int guildCount;
  final String prizePool;
  final DateTime? startAt;
  final DateTime? endAt;

  const GuildWarTournament({
    required this.id,
    required this.name,
    required this.status,
    this.guildCount = 0,
    this.prizePool = '',
    this.startAt,
    this.endAt,
  });

  bool get isActive => status == 'active';
  bool get isUpcoming => status == 'upcoming';
  bool get isCompleted => status == 'completed';

  factory GuildWarTournament.fromJson(Map<String, dynamic> json) {
    return GuildWarTournament(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      status: (json['status'] ?? 'upcoming').toString(),
      guildCount: _asInt(json['guild_count'] ?? json['guildCount']),
      prizePool: (json['prize_pool'] ?? json['prizePool'] ?? '').toString(),
      startAt: json['start_at'] != null
          ? DateTime.tryParse(json['start_at'].toString())
          : null,
      endAt: json['end_at'] != null
          ? DateTime.tryParse(json['end_at'].toString())
          : null,
    );
  }
}

class GuildWarRanking {
  final int rank;
  final String guildName;
  final String? guildId;
  final int points;
  final int prestige;
  final int rankScore;
  final Map<String, int> breakdown;
  final int wins;
  final int losses;

  const GuildWarRanking({
    required this.rank,
    required this.guildName,
    this.guildId,
    this.points = 0,
    this.prestige = 0,
    this.rankScore = 0,
    this.breakdown = const <String, int>{},
    this.wins = 0,
    this.losses = 0,
  });

  factory GuildWarRanking.fromJson(Map<String, dynamic> json) {
    final Map<String, int> breakdown = <String, int>{};
    final dynamic rawBreakdown = json['breakdown'];
    if (rawBreakdown is Map) {
      rawBreakdown.forEach((Object? key, Object? value) {
        if (key == null) return;
        breakdown[key.toString()] = _asInt(value);
      });
    }
    final int points = _asInt(json['points']);
    final int prestige = _asInt(json['prestige']);
    return GuildWarRanking(
      rank: _asInt(json['rank'], fallback: 0),
      guildName: (json['guild_name'] ?? json['guildName'] ?? '—').toString(),
      guildId: json['guild_id']?.toString(),
      points: points,
      prestige: prestige,
      rankScore: _asInt(json['rank_score'] ?? json['rankScore'], fallback: points + (prestige ~/ 4)),
      breakdown: breakdown,
      wins: _asInt(json['wins']),
      losses: _asInt(json['losses']),
    );
  }
}

class GuildWarParticipant {
  final String id;
  final String guildId;
  final String guildName;
  final DateTime? joinedAt;

  const GuildWarParticipant({
    required this.id,
    required this.guildId,
    required this.guildName,
    this.joinedAt,
  });

  factory GuildWarParticipant.fromJson(Map<String, dynamic> json) {
    return GuildWarParticipant(
      id: (json['id'] ?? '').toString(),
      guildId: (json['guild_id'] ?? '').toString(),
      guildName: (json['guild_name'] ?? '').toString(),
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'].toString())
          : null,
    );
  }
}

class GuildWarTournamentMatch {
  const GuildWarTournamentMatch({
    required this.id,
    required this.guild1Id,
    required this.guild1Name,
    required this.guild2Id,
    required this.guild2Name,
    required this.guild1Score,
    required this.guild2Score,
    required this.winnerGuildId,
    required this.winnerGuildName,
    required this.status,
    this.windowStart,
    this.windowEnd,
  });

  final int id;
  final String? guild1Id;
  final String guild1Name;
  final String? guild2Id;
  final String guild2Name;
  final int guild1Score;
  final int guild2Score;
  final String? winnerGuildId;
  final String winnerGuildName;
  final String status;
  final DateTime? windowStart;
  final DateTime? windowEnd;

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isLive => status == 'live';

  factory GuildWarTournamentMatch.fromJson(Map<String, dynamic> json) {
    return GuildWarTournamentMatch(
      id: _asInt(json['id']),
      guild1Id: json['guild1Id']?.toString(),
      guild1Name: (json['guild1Name'] ?? '?').toString(),
      guild2Id: json['guild2Id']?.toString(),
      guild2Name: (json['guild2Name'] ?? '?').toString(),
      guild1Score: _asInt(json['guild1Score']),
      guild2Score: _asInt(json['guild2Score']),
      winnerGuildId: json['winnerGuildId']?.toString(),
      winnerGuildName: (json['winnerGuildName'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      windowStart: json['windowStart'] != null
          ? DateTime.tryParse(json['windowStart'].toString())
          : (json['window_start'] != null
              ? DateTime.tryParse(json['window_start'].toString())
              : null),
      windowEnd: json['windowEnd'] != null
          ? DateTime.tryParse(json['windowEnd'].toString())
          : (json['window_end'] != null
              ? DateTime.tryParse(json['window_end'].toString())
              : null),
    );
  }
}

class LiveGuildWarClash {
  const LiveGuildWarClash({
    required this.status,
    this.matchId,
    this.tournamentId,
    this.tournamentName,
    this.roundName,
    this.windowStart,
    this.windowEnd,
    this.guild1Id,
    this.guild1Name,
    this.guild1Score = 0,
    this.guild2Id,
    this.guild2Name,
    this.guild2Score = 0,
    this.nextTournamentId,
    this.nextTournamentName,
    this.nextStartAt,
    this.prizePool,
    this.phase,
    this.message,
  });

  final String status;
  final int? matchId;
  final String? tournamentId;
  final String? tournamentName;
  final String? roundName;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final String? guild1Id;
  final String? guild1Name;
  final int guild1Score;
  final String? guild2Id;
  final String? guild2Name;
  final int guild2Score;
  final String? nextTournamentId;
  final String? nextTournamentName;
  final DateTime? nextStartAt;
  final String? prizePool;
  final String? phase;
  final String? message;

  bool get isLive => status == 'live';

  factory LiveGuildWarClash.fromJson(Map<String, dynamic> json) {
    return LiveGuildWarClash(
      status: (json['status'] ?? 'idle').toString(),
      matchId: json['match_id'] != null ? _asInt(json['match_id']) : null,
      tournamentId: json['tournament_id']?.toString() ??
          json['next_tournament_id']?.toString(),
      tournamentName: json['tournament_name']?.toString(),
      roundName: json['round_name']?.toString(),
      windowStart: json['window_start'] != null
          ? DateTime.tryParse(json['window_start'].toString())
          : null,
      windowEnd: json['window_end'] != null
          ? DateTime.tryParse(json['window_end'].toString())
          : null,
      guild1Id: json['guild1_id']?.toString(),
      guild1Name: json['guild1_name']?.toString(),
      guild1Score: _asInt(json['guild1_score']),
      guild2Id: json['guild2_id']?.toString(),
      guild2Name: json['guild2_name']?.toString(),
      guild2Score: _asInt(json['guild2_score']),
      nextTournamentId: json['next_tournament_id']?.toString(),
      nextTournamentName: json['next_tournament_name']?.toString(),
      nextStartAt: json['next_start_at'] != null
          ? DateTime.tryParse(json['next_start_at'].toString())
          : null,
      prizePool: json['prize_pool']?.toString(),
      phase: json['phase']?.toString(),
      message: json['message']?.toString(),
    );
  }
}

class GuildWarTournamentRound {
  const GuildWarTournamentRound({
    required this.title,
    required this.roundNumber,
    required this.matches,
  });

  final String title;
  final int roundNumber;
  final List<GuildWarTournamentMatch> matches;

  factory GuildWarTournamentRound.fromJson(Map<String, dynamic> json) {
    final matchList = (json['matches'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => GuildWarTournamentMatch.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return GuildWarTournamentRound(
      title: (json['title'] ?? '').toString(),
      roundNumber: _asInt(json['roundNumber']),
      matches: matchList,
    );
  }
}

class TerritoryData {
  final String id;
  final String name;
  final String? ownerGuildId;
  final String? ownerGuildName;
  final String? ownerGuildTag;
  final int defensePower;
  final int baseDefensePower;
  final int gemDefenseBoost;
  final int effectiveDefensePower;
  final int defenseLineLevel;
  final String reward;
  final int tradeIncome;
  final int? zoneNumber;
  final String? siegeDungeonId;
  final String? siegeDungeonName;
  final bool hasActiveSiegeSession;
  final int attackGoldCost;
  final int minDefenseGems;
  final String? lootItemId;
  final String? lootItemName;
  final double lootItemChance;
  final double tradeIncomeHourly;
  final TerritoryVaultSummary? vaultSummary;

  const TerritoryData({
    required this.id,
    required this.name,
    this.ownerGuildId,
    this.ownerGuildName,
    this.ownerGuildTag,
    this.defensePower = 0,
    this.baseDefensePower = 1000,
    this.gemDefenseBoost = 0,
    this.effectiveDefensePower = 0,
    this.defenseLineLevel = 0,
    this.reward = '',
    this.tradeIncome = 0,
    this.zoneNumber,
    this.siegeDungeonId,
    this.siegeDungeonName,
    this.hasActiveSiegeSession = false,
    this.attackGoldCost = 0,
    this.minDefenseGems = 5,
    this.lootItemId,
    this.lootItemName,
    this.lootItemChance = 0,
    this.tradeIncomeHourly = 0,
    this.vaultSummary,
  });

  bool get hasTerritoryLoot =>
      lootItemId != null && lootItemId!.isNotEmpty && lootItemChance > 0;

  String get lootChanceLabel => lootItemChance >= 1
      ? '6-7/gün kasaya eşya'
      : '${(lootItemChance * 100).round()}%/gün kasaya eşya';

  bool get isUnclaimed =>
      ownerGuildId == null || ownerGuildName == null || ownerGuildName == 'Sahipsiz';

  int get displayDefensePower =>
      effectiveDefensePower > 0 ? effectiveDefensePower : defensePower + gemDefenseBoost;

  factory TerritoryData.fromJson(Map<String, dynamic> json) {
    final int defensePower = _asInt(json['defense_power']);
    final int gemBoost = _asInt(json['gem_defense_boost']);
    final int effective = _asInt(json['effective_defense_power'], fallback: defensePower + gemBoost);
    return TerritoryData(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      ownerGuildId: json['owner_guild_id']?.toString(),
      ownerGuildName: json['owner_guild']?.toString(),
      ownerGuildTag: json['owner_guild_tag']?.toString(),
      defensePower: defensePower,
      baseDefensePower: _asInt(json['base_defense_power'], fallback: 1000),
      gemDefenseBoost: gemBoost,
      effectiveDefensePower: effective,
      defenseLineLevel: _asInt(json['defense_line_level']),
      reward: (json['reward'] ?? '').toString(),
      tradeIncome: _asInt(json['trade_income']),
      zoneNumber: json['zone_number'] != null ? _asInt(json['zone_number']) : null,
      siegeDungeonId: json['siege_dungeon_id']?.toString(),
      siegeDungeonName: json['siege_dungeon_name']?.toString(),
      hasActiveSiegeSession: json['has_active_siege_session'] == true,
      attackGoldCost: _asInt(json['attack_gold_cost']),
      minDefenseGems: _asInt(json['min_defense_gems'], fallback: 5),
      lootItemId: json['loot_item_id']?.toString(),
      lootItemName: json['loot_item_name']?.toString(),
      lootItemChance: _asDouble(json['loot_item_chance']),
      tradeIncomeHourly: _asDouble(json['trade_income_hourly']),
      vaultSummary: json['vault_summary'] is Map
          ? TerritoryVaultSummary.fromJson(
              Map<String, dynamic>.from(json['vault_summary'] as Map),
            )
          : null,
    );
  }
}

class TerritoryDetail {
  final TerritoryData territory;
  final List<GuildWarAttackLog> recentAttacks;

  const TerritoryDetail({
    required this.territory,
    this.recentAttacks = const [],
  });

  factory TerritoryDetail.fromJson(Map<String, dynamic> json) {
    final territoryJson = json['territory'];
    return TerritoryDetail(
      territory: territoryJson is Map<String, dynamic>
          ? TerritoryData.fromJson(territoryJson)
          : TerritoryData.fromJson(Map<String, dynamic>.from(territoryJson as Map)),
      recentAttacks: _parseAttackLogs(json['recent_attacks']),
    );
  }
}

class GuildWarAttackLog {
  final String id;
  final String territoryId;
  final String? territoryName;
  final String attackerGuildId;
  final String? attackerGuildName;
  final String? defenderGuildId;
  final String? defenderGuildName;
  final int attackPower;
  final int defensePower;
  final bool success;
  final int pointsGained;
  final DateTime createdAt;

  const GuildWarAttackLog({
    required this.id,
    required this.territoryId,
    this.territoryName,
    required this.attackerGuildId,
    this.attackerGuildName,
    this.defenderGuildId,
    this.defenderGuildName,
    this.attackPower = 0,
    this.defensePower = 0,
    required this.success,
    this.pointsGained = 0,
    required this.createdAt,
  });

  factory GuildWarAttackLog.fromJson(Map<String, dynamic> json) {
    return GuildWarAttackLog(
      id: (json['id'] ?? '').toString(),
      territoryId: (json['territory_id'] ?? '').toString(),
      territoryName: json['territory_name']?.toString(),
      attackerGuildId: (json['attacker_guild_id'] ?? '').toString(),
      attackerGuildName: json['attacker_guild_name']?.toString(),
      defenderGuildId: json['defender_guild_id']?.toString(),
      defenderGuildName: json['defender_guild_name']?.toString(),
      attackPower: _asInt(json['attack_power']),
      defensePower: _asInt(json['defense_power']),
      success: json['success'] == true,
      pointsGained: _asInt(json['points_gained']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }
}

enum GuildWarAttackLogFilter {
  all,
  win,
  loss,
}

List<GuildWarAttackLog> filterAttackLogs({
  required List<GuildWarAttackLog> logs,
  required GuildWarAttackLogFilter filter,
  required String? guildId,
}) {
  if (filter == GuildWarAttackLogFilter.all || guildId == null) {
    return logs;
  }
  if (filter == GuildWarAttackLogFilter.win) {
    return logs
        .where(
          (GuildWarAttackLog log) =>
              (log.attackerGuildId == guildId && log.success) ||
              (log.defenderGuildId == guildId && !log.success),
        )
        .toList();
  }
  return logs
      .where(
        (GuildWarAttackLog log) =>
            (log.attackerGuildId == guildId && !log.success) ||
            (log.defenderGuildId == guildId && log.success),
      )
      .toList();
}

class GuildWarAttackResult {
  final bool success;
  final String message;
  final int pointsGained;
  final int attackPower;
  final int attackPowerRaw;
  final double sizeAttackMult;
  final int memberCount;
  final int defensePower;
  final int goldSpent;
  final String? territoryName;
  final String? defenderGuildName;
  final int healthLost;
  final int healthAfter;
  final int maxHealth;
  final String? error;

  const GuildWarAttackResult({
    required this.success,
    required this.message,
    this.pointsGained = 0,
    this.attackPower = 0,
    this.attackPowerRaw = 0,
    this.sizeAttackMult = 1,
    this.memberCount = 0,
    this.defensePower = 0,
    this.goldSpent = 0,
    this.territoryName,
    this.defenderGuildName,
    this.healthLost = 0,
    this.healthAfter = 0,
    this.maxHealth = 0,
    this.error,
  });

  factory GuildWarAttackResult.fromJson(Map<String, dynamic> json) {
    final int attackPower = _asInt(json['attack_power']);
    return GuildWarAttackResult(
      success: json['success'] == true,
      message: (json['message'] ?? '').toString(),
      pointsGained: _asInt(json['points_gained']),
      attackPower: attackPower,
      attackPowerRaw: _asInt(json['attack_power_raw'], fallback: attackPower),
      sizeAttackMult: json['size_attack_mult'] is num
          ? (json['size_attack_mult'] as num).toDouble()
          : 1,
      memberCount: _asInt(json['member_count']),
      defensePower: _asInt(json['defense_power']),
      goldSpent: _asInt(json['gold_spent']),
      territoryName: json['territory_name']?.toString(),
      defenderGuildName: json['defender_guild_name']?.toString(),
      healthLost: _asInt(json['health_lost']),
      healthAfter: _asInt(json['health_after']),
      maxHealth: _asInt(json['max_health']),
      error: json['error']?.toString(),
    );
  }
}

class GuildWarGuildBrief {
  const GuildWarGuildBrief({
    required this.id,
    required this.name,
    this.tag,
  });

  final String id;
  final String name;
  final String? tag;

  String get displayLabel {
    final String? visibleTag = _visibleGuildTag(tag);
    if (visibleTag != null) return '[$visibleTag] $name';
    return name;
  }

  /// Skips color-like junk stored in `guilds.tag` (e.g. `d712bf59`).
  static String? _visibleGuildTag(String? raw) {
    if (raw == null) return null;
    final String tag = raw.trim();
    if (tag.isEmpty || tag.length > 6) return null;
    if (RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(tag)) return null;
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(tag)) return null;
    return tag.toUpperCase();
  }

  factory GuildWarGuildBrief.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const GuildWarGuildBrief(id: '', name: 'Sahipsiz');
    }
    return GuildWarGuildBrief(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '—').toString(),
      tag: json['tag']?.toString(),
    );
  }
}

class TerritoryVaultSummary {
  const TerritoryVaultSummary({
    this.vaultGold = 0,
    this.vaultGoldPending = 0,
    this.isLeader = false,
    this.canCollect = false,
  });

  final int vaultGold;
  final int vaultGoldPending;
  final bool isLeader;
  final bool canCollect;

  factory TerritoryVaultSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TerritoryVaultSummary();
    return TerritoryVaultSummary(
      vaultGold: _asInt(json['vault_gold']),
      vaultGoldPending: _asInt(json['vault_gold_pending']),
      isLeader: json['is_leader'] == true,
      canCollect: json['can_collect'] == true,
    );
  }
}

class TerritoryAttackPreview {
  const TerritoryAttackPreview({
    required this.territoryId,
    required this.territoryName,
    this.tradeIncome = 0,
    this.attackGoldCost = 0,
    this.roiDays,
    this.attackPower = 0,
    this.attackPowerRaw = 0,
    this.sizeAttackMult = 1,
    this.memberCount = 0,
    this.defensePower = 0,
    this.gemAttackBoost = 0,
    this.winChancePct = 0,
    this.vaultGold = 0,
    this.vaultGoldPending = 0,
    this.canAfford = false,
    this.attackerGuild = const GuildWarGuildBrief(id: '', name: '—'),
    this.defenderGuild,
    this.error,
  });

  final String territoryId;
  final String territoryName;
  final int tradeIncome;
  final int attackGoldCost;
  final double? roiDays;
  final int attackPower;
  final int attackPowerRaw;
  final double sizeAttackMult;
  final int memberCount;
  final int defensePower;
  final int gemAttackBoost;
  final double winChancePct;
  final int vaultGold;
  final int vaultGoldPending;
  final bool canAfford;
  final GuildWarGuildBrief attackerGuild;
  final GuildWarGuildBrief? defenderGuild;
  final String? error;

  factory TerritoryAttackPreview.fromJson(Map<String, dynamic> json) {
    if (json['success'] == false) {
      return TerritoryAttackPreview(
        territoryId: '',
        territoryName: '',
        error: json['error']?.toString(),
      );
    }
    final Map<String, dynamic>? defenderMap = json['defender_guild'] is Map
        ? Map<String, dynamic>.from(json['defender_guild'] as Map)
        : null;
    final int attackPower = _asInt(json['attack_power']);
    return TerritoryAttackPreview(
      territoryId: (json['territory_id'] ?? '').toString(),
      territoryName: (json['territory_name'] ?? '').toString(),
      tradeIncome: _asInt(json['trade_income']),
      attackGoldCost: _asInt(json['attack_gold_cost']),
      roiDays: json['roi_days'] is num ? (json['roi_days'] as num).toDouble() : null,
      attackPower: attackPower,
      attackPowerRaw: _asInt(json['attack_power_raw'], fallback: attackPower),
      sizeAttackMult: json['size_attack_mult'] is num
          ? (json['size_attack_mult'] as num).toDouble()
          : 1,
      memberCount: _asInt(json['member_count']),
      defensePower: _asInt(json['defense_power']),
      gemAttackBoost: _asInt(json['gem_attack_boost']),
      winChancePct: json['win_chance_pct'] is num
          ? (json['win_chance_pct'] as num).toDouble()
          : (json['win_chance'] is num
              ? (json['win_chance'] as num).toDouble() * 100
              : 0),
      vaultGold: _asInt(json['vault_gold']),
      vaultGoldPending: _asInt(json['vault_gold_pending']),
      canAfford: json['can_afford'] == true ||
          _asInt(json['vault_gold']) >= _asInt(json['attack_gold_cost']),
      attackerGuild: GuildWarGuildBrief.fromJson(
        json['attacker_guild'] is Map
            ? Map<String, dynamic>.from(json['attacker_guild'] as Map)
            : null,
      ),
      defenderGuild: defenderMap != null ? GuildWarGuildBrief.fromJson(defenderMap) : null,
    );
  }
}

class TradeDistributionLog {
  final String id;
  final String territoryId;
  final String? territoryName;
  final int totalIncome;
  final int distributedAmount;
  final DateTime distributedAt;

  const TradeDistributionLog({
    required this.id,
    required this.territoryId,
    this.territoryName,
    required this.totalIncome,
    required this.distributedAmount,
    required this.distributedAt,
  });

  factory TradeDistributionLog.fromJson(Map<String, dynamic> json) {
    return TradeDistributionLog(
      id: (json['id'] ?? '').toString(),
      territoryId: (json['territory_id'] ?? '').toString(),
      territoryName: json['territory_name']?.toString(),
      totalIncome: _asInt(json['total_income']),
      distributedAmount: _asInt(json['distributed_amount']),
      distributedAt: json['distributed_at'] != null
          ? DateTime.parse(json['distributed_at'].toString())
          : DateTime.now(),
    );
  }
}

List<GuildWarAttackLog> _parseAttackLogs(dynamic data) {
  if (data is! List) return const [];
  return data
      .map((e) => GuildWarAttackLog.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// Formats numeric chunks inside backend prize strings (e.g. `250000 Altın`).
String formatGuildWarPrizePool(String prizePool) {
  if (prizePool.trim().isEmpty) return '—';
  final NumberFormat formatter = NumberFormat.decimalPattern('tr_TR');
  final RegExp pattern = RegExp(r'\d[\d.,]*');
  return prizePool.replaceAllMapped(pattern, (Match match) {
    final String raw = match.group(0)!;
    final String digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    final int? value = int.tryParse(digits);
    if (value == null) return raw;
    return formatter.format(value);
  });
}
