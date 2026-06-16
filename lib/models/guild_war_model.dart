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
  final int wins;
  final int losses;

  const GuildWarRanking({
    required this.rank,
    required this.guildName,
    this.guildId,
    this.points = 0,
    this.wins = 0,
    this.losses = 0,
  });

  factory GuildWarRanking.fromJson(Map<String, dynamic> json) {
    return GuildWarRanking(
      rank: _asInt(json['rank'], fallback: 0),
      guildName: (json['guild_name'] ?? json['guildName'] ?? '—').toString(),
      guildId: json['guild_id']?.toString(),
      points: _asInt(json['points']),
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

class TerritoryData {
  final String id;
  final String name;
  final String? ownerGuildId;
  final String? ownerGuildName;
  final int defensePower;
  final int baseDefensePower;
  final int defenseLineLevel;
  final String reward;
  final int tradeIncome;

  const TerritoryData({
    required this.id,
    required this.name,
    this.ownerGuildId,
    this.ownerGuildName,
    this.defensePower = 0,
    this.baseDefensePower = 1000,
    this.defenseLineLevel = 0,
    this.reward = '',
    this.tradeIncome = 0,
  });

  bool get isUnclaimed =>
      ownerGuildId == null || ownerGuildName == null || ownerGuildName == 'Sahipsiz';

  factory TerritoryData.fromJson(Map<String, dynamic> json) {
    return TerritoryData(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      ownerGuildId: json['owner_guild_id']?.toString(),
      ownerGuildName: json['owner_guild']?.toString(),
      defensePower: _asInt(json['defense_power']),
      baseDefensePower: _asInt(json['base_defense_power'], fallback: 1000),
      defenseLineLevel: _asInt(json['defense_line_level']),
      reward: (json['reward'] ?? '').toString(),
      tradeIncome: _asInt(json['trade_income']),
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

class GuildWarAttackResult {
  final bool success;
  final String message;
  final int pointsGained;
  final int attackPower;
  final int defensePower;
  final String? territoryName;
  final String? error;

  const GuildWarAttackResult({
    required this.success,
    required this.message,
    this.pointsGained = 0,
    this.attackPower = 0,
    this.defensePower = 0,
    this.territoryName,
    this.error,
  });

  factory GuildWarAttackResult.fromJson(Map<String, dynamic> json) {
    return GuildWarAttackResult(
      success: json['success'] == true,
      message: (json['message'] ?? '').toString(),
      pointsGained: _asInt(json['points_gained']),
      attackPower: _asInt(json['attack_power']),
      defensePower: _asInt(json['defense_power']),
      territoryName: json['territory_name']?.toString(),
      error: json['error']?.toString(),
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
