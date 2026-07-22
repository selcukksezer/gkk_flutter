/// Kuşatma boss zindanları (DB config fallback).
const Set<String> kSiegeDungeonIds = <String>{
  'dng_010',
  'dng_020',
  'dng_030',
  'dng_040',
  'dng_050',
  'dng_060',
  'dng_065',
};

class DungeonSiegeConfig {
  const DungeonSiegeConfig({
    required this.isEnabled,
    required this.slotCount,
    required this.slotDurationMinutes,
    required this.challengeGoldCost,
    required this.lootBonusPct,
    required this.goldBonusPct,
    required this.repBonusPct,
    required this.inPrimeWindow,
    this.banDurationMinutes = 45,
    this.siegeDungeonIds = kSiegeDungeonIds,
    this.holdMinMembers = 3,
    this.holdBonusPct = 0.15,
    this.holdBreakWinsRequired = 3,
    this.territoryReserveSlotCount = 1,
  });

  final bool isEnabled;
  final int slotCount;
  final int slotDurationMinutes;
  final int challengeGoldCost;
  final double lootBonusPct;
  final double goldBonusPct;
  final double repBonusPct;
  final bool inPrimeWindow;
  final int banDurationMinutes;
  final Set<String> siegeDungeonIds;
  final int holdMinMembers;
  final double holdBonusPct;
  final int holdBreakWinsRequired;
  final int territoryReserveSlotCount;

  bool get isLive => isEnabled && inPrimeWindow;

  factory DungeonSiegeConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const DungeonSiegeConfig(
        isEnabled: false,
        slotCount: 5,
        slotDurationMinutes: 20,
        challengeGoldCost: 500,
        lootBonusPct: 0.4,
        goldBonusPct: 0.25,
        repBonusPct: 0.15,
        inPrimeWindow: false,
      );
    }
    return DungeonSiegeConfig(
      isEnabled: json['is_enabled'] == true,
      slotCount: _asInt(json['slot_count'], fallback: 5),
      slotDurationMinutes: _asInt(json['slot_duration_minutes'], fallback: 20),
      challengeGoldCost: _asInt(json['challenge_gold_cost'], fallback: 500),
      lootBonusPct: _asDouble(json['loot_bonus_pct'], fallback: 0.4),
      goldBonusPct: _asDouble(json['gold_bonus_pct'], fallback: 0.25),
      repBonusPct: _asDouble(json['rep_bonus_pct'], fallback: 0.15),
      inPrimeWindow: json['in_prime_window'] == true,
      banDurationMinutes: _asInt(json['ban_duration_minutes'], fallback: 45),
      siegeDungeonIds: _parseDungeonIds(json['siege_dungeon_ids']),
      holdMinMembers: _asInt(json['hold_min_members'], fallback: 3),
      holdBonusPct: _asDouble(json['hold_bonus_pct'], fallback: 0.15),
      holdBreakWinsRequired: _asInt(json['hold_break_wins_required'], fallback: 3),
      territoryReserveSlotCount: _asInt(json['territory_reserve_slot_count'], fallback: 1),
    );
  }

  static Set<String> _parseDungeonIds(dynamic raw) {
    if (raw is List) {
      return raw.map((dynamic e) => e.toString()).toSet();
    }
    if (raw is String && raw.startsWith('{') && raw.endsWith('}')) {
      return raw
          .substring(1, raw.length - 1)
          .split(',')
          .map((String s) => s.trim().replaceAll('"', ''))
          .where((String s) => s.isNotEmpty)
          .toSet();
    }
    return kSiegeDungeonIds;
  }

  static int _asInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _asDouble(dynamic value, {required double fallback}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}

class DungeonSiegeHold {
  const DungeonSiegeHold({
    required this.holdId,
    required this.guildId,
    this.guildName,
    this.breakProgress = 0,
    this.breakRequired = 3,
    this.memberSlots = 0,
    this.startedAt,
  });

  final String holdId;
  final String guildId;
  final String? guildName;
  final int breakProgress;
  final int breakRequired;
  final int memberSlots;
  final String? startedAt;

  factory DungeonSiegeHold.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const DungeonSiegeHold(holdId: '', guildId: '');
    }
    return DungeonSiegeHold(
      holdId: (json['hold_id'] ?? '').toString(),
      guildId: (json['guild_id'] ?? '').toString(),
      guildName: json['guild_name']?.toString(),
      breakProgress: DungeonSiegeConfig._asInt(json['break_progress']),
      breakRequired: DungeonSiegeConfig._asInt(json['break_required'], fallback: 3),
      memberSlots: DungeonSiegeConfig._asInt(json['member_slots']),
      startedAt: json['started_at']?.toString(),
    );
  }
}

class DungeonSiegeSlot {
  const DungeonSiegeSlot({
    required this.slotId,
    required this.slotNumber,
    this.holderId,
    this.holderName,
    this.holderPower = 0,
    this.guildName,
    this.expiresAt,
    this.isMine = false,
    this.isTerritoryReserved = false,
  });

  final String slotId;
  final int slotNumber;
  final String? holderId;
  final String? holderName;
  final int holderPower;
  final String? guildName;
  final String? expiresAt;
  final bool isMine;
  final bool isTerritoryReserved;

  bool get isOccupied => holderId != null && holderId!.isNotEmpty;

  factory DungeonSiegeSlot.fromJson(Map<String, dynamic> json) {
    return DungeonSiegeSlot(
      slotId: (json['slot_id'] ?? '').toString(),
      slotNumber: DungeonSiegeConfig._asInt(json['slot_number'], fallback: 0),
      holderId: json['holder_id']?.toString(),
      holderName: json['holder_name']?.toString(),
      holderPower: DungeonSiegeConfig._asInt(json['holder_power']),
      guildName: json['guild_name']?.toString(),
      expiresAt: json['expires_at']?.toString(),
      isMine: json['is_mine'] == true,
      isTerritoryReserved: json['is_territory_reserved'] == true,
    );
  }
}

class DungeonSiegeSession {
  const DungeonSiegeSession({
    required this.sessionId,
    required this.dungeonId,
    required this.zoneNumber,
    required this.endsAt,
    required this.slots,
    this.territoryOwnerGuildName,
    this.guildSlots = 0,
    this.hold,
  });

  final String sessionId;
  final String dungeonId;
  final int zoneNumber;
  final String? endsAt;
  final List<DungeonSiegeSlot> slots;
  final String? territoryOwnerGuildName;
  final int guildSlots;
  final DungeonSiegeHold? hold;

  factory DungeonSiegeSession.fromJson(Map<String, dynamic> json) {
    final List<DungeonSiegeSlot> slots = (json['slots'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map>()
        .map((Map<dynamic, dynamic> row) => DungeonSiegeSlot.fromJson(Map<String, dynamic>.from(row)))
        .toList();

    final Map<String, dynamic>? holdMap = json['hold'] is Map
        ? Map<String, dynamic>.from(json['hold'] as Map)
        : null;

    return DungeonSiegeSession(
      sessionId: (json['session_id'] ?? '').toString(),
      dungeonId: (json['dungeon_id'] ?? '').toString(),
      zoneNumber: DungeonSiegeConfig._asInt(json['zone_number']),
      endsAt: json['ends_at']?.toString(),
      slots: slots,
      territoryOwnerGuildName: json['territory_owner_guild_name']?.toString(),
      guildSlots: DungeonSiegeConfig._asInt(json['guild_slots']),
      hold: holdMap != null ? DungeonSiegeHold.fromJson(holdMap) : null,
    );
  }
}

class DungeonSiegeStatus {
  const DungeonSiegeStatus({
    required this.enabled,
    required this.inPrimeWindow,
    required this.siegeActive,
    required this.isBanned,
    required this.config,
    required this.sessions,
    this.mySlotId,
    this.mySlotNumber,
  });

  final bool enabled;
  final bool inPrimeWindow;
  final bool siegeActive;
  final bool isBanned;
  final DungeonSiegeConfig config;
  final List<DungeonSiegeSession> sessions;
  final String? mySlotId;
  final int? mySlotNumber;

  factory DungeonSiegeStatus.empty() {
    return DungeonSiegeStatus(
      enabled: false,
      inPrimeWindow: false,
      siegeActive: false,
      isBanned: false,
      config: DungeonSiegeConfig.fromJson(null),
      sessions: const <DungeonSiegeSession>[],
    );
  }

  factory DungeonSiegeStatus.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? configMap = json['config'] is Map
        ? Map<String, dynamic>.from(json['config'] as Map)
        : null;

    final List<DungeonSiegeSession> sessions =
        (json['sessions'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map>()
            .map(
              (Map<dynamic, dynamic> row) =>
                  DungeonSiegeSession.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList();

    final Map<String, dynamic>? mySlot = json['my_slot'] is Map
        ? Map<String, dynamic>.from(json['my_slot'] as Map)
        : null;

    return DungeonSiegeStatus(
      enabled: json['enabled'] == true,
      inPrimeWindow: json['in_prime_window'] == true,
      siegeActive: json['siege_active'] == true,
      isBanned: json['is_banned'] == true,
      config: DungeonSiegeConfig.fromJson(configMap),
      sessions: sessions,
      mySlotId: mySlot?['slot_id']?.toString(),
      mySlotNumber: mySlot?['slot_number'] != null
          ? DungeonSiegeConfig._asInt(mySlot!['slot_number'])
          : null,
    );
  }

  DungeonSiegeSession? sessionForDungeon(String dungeonId) {
    for (final DungeonSiegeSession session in sessions) {
      if (session.dungeonId == dungeonId) return session;
    }
    return null;
  }
}

class DungeonSiegeActionResult {
  const DungeonSiegeActionResult({
    required this.success,
    this.error,
    this.message,
    this.youWon,
  });

  final bool success;
  final String? error;
  final String? message;
  final bool? youWon;

  factory DungeonSiegeActionResult.fromJson(Map<String, dynamic> json) {
    return DungeonSiegeActionResult(
      success: json['success'] == true,
      error: json['error']?.toString(),
      message: json['message']?.toString(),
      youWon: json['you_won'] as bool?,
    );
  }
}

bool isSiegeDungeon(String dungeonId, {DungeonSiegeStatus? status}) {
  final Set<String> ids = status?.config.siegeDungeonIds ?? kSiegeDungeonIds;
  if (ids.isEmpty) return kSiegeDungeonIds.contains(dungeonId);
  return ids.contains(dungeonId);
}

class DungeonSiegeLeaderboardEntry {
  const DungeonSiegeLeaderboardEntry({
    required this.rank,
    required this.playerName,
    this.playerId,
    this.guildName,
    this.points = 0,
    this.challengesWon = 0,
    this.slotMinutes = 0,
  });

  final int rank;
  final String? playerId;
  final String playerName;
  final String? guildName;
  final int points;
  final int challengesWon;
  final int slotMinutes;

  factory DungeonSiegeLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return DungeonSiegeLeaderboardEntry(
      rank: DungeonSiegeConfig._asInt(json['rank'], fallback: 0),
      playerId: json['player_id']?.toString(),
      playerName: (json['player_name'] ?? '—').toString(),
      guildName: json['guild_name']?.toString(),
      points: DungeonSiegeConfig._asInt(json['points']),
      challengesWon: DungeonSiegeConfig._asInt(json['challenges_won']),
      slotMinutes: DungeonSiegeConfig._asInt(json['slot_minutes']),
    );
  }
}

class DungeonSiegeRecentChallenge {
  const DungeonSiegeRecentChallenge({
    required this.id,
    required this.dungeonId,
    required this.challengerName,
    required this.defenderName,
    required this.winnerName,
    this.resolvedAt,
    this.youWereInvolved = false,
  });

  final String id;
  final String dungeonId;
  final String challengerName;
  final String defenderName;
  final String winnerName;
  final String? resolvedAt;
  final bool youWereInvolved;

  factory DungeonSiegeRecentChallenge.fromJson(Map<String, dynamic> json) {
    return DungeonSiegeRecentChallenge(
      id: (json['id'] ?? '').toString(),
      dungeonId: (json['dungeon_id'] ?? '').toString(),
      challengerName: (json['challenger_name'] ?? '—').toString(),
      defenderName: (json['defender_name'] ?? '—').toString(),
      winnerName: (json['winner_name'] ?? '—').toString(),
      resolvedAt: json['resolved_at']?.toString(),
      youWereInvolved: json['you_were_involved'] == true,
    );
  }
}

class DungeonSiegeTerritoryLink {
  const DungeonSiegeTerritoryLink({
    required this.zoneNumber,
    required this.territoryName,
    this.ownerGuildName,
  });

  final int zoneNumber;
  final String territoryName;
  final String? ownerGuildName;

  factory DungeonSiegeTerritoryLink.fromJson(Map<String, dynamic> json) {
    return DungeonSiegeTerritoryLink(
      zoneNumber: DungeonSiegeConfig._asInt(json['zone_number']),
      territoryName: (json['territory_name'] ?? '').toString(),
      ownerGuildName: json['owner_guild_name']?.toString(),
    );
  }
}

class DungeonSiegeNotification {
  const DungeonSiegeNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.createdAt,
    this.isUnread = false,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? createdAt;
  final bool isUnread;

  factory DungeonSiegeNotification.fromJson(Map<String, dynamic> json) {
    return DungeonSiegeNotification(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt: json['created_at']?.toString(),
      isUnread: json['is_unread'] == true,
    );
  }
}

class DungeonSiegeHub {
  const DungeonSiegeHub({
    required this.weekKey,
    required this.status,
    required this.leaderboard,
    required this.recentChallenges,
    required this.territories,
  });

  final String weekKey;
  final DungeonSiegeStatus status;
  final List<DungeonSiegeLeaderboardEntry> leaderboard;
  final List<DungeonSiegeRecentChallenge> recentChallenges;
  final List<DungeonSiegeTerritoryLink> territories;

  factory DungeonSiegeHub.empty() {
    return DungeonSiegeHub(
      weekKey: '',
      status: DungeonSiegeStatus.empty(),
      leaderboard: const <DungeonSiegeLeaderboardEntry>[],
      recentChallenges: const <DungeonSiegeRecentChallenge>[],
      territories: const <DungeonSiegeTerritoryLink>[],
    );
  }

  factory DungeonSiegeHub.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? statusMap = json['status'] is Map
        ? Map<String, dynamic>.from(json['status'] as Map)
        : null;

    return DungeonSiegeHub(
      weekKey: (json['week_key'] ?? '').toString(),
      status: statusMap != null
          ? DungeonSiegeStatus.fromJson(statusMap)
          : DungeonSiegeStatus.empty(),
      leaderboard: _parseList(json['leaderboard'], DungeonSiegeLeaderboardEntry.fromJson),
      recentChallenges: _parseList(json['recent_challenges'], DungeonSiegeRecentChallenge.fromJson),
      territories: _parseList(json['territories'], DungeonSiegeTerritoryLink.fromJson),
    );
  }

  static List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic> json) mapper,
  ) {
    return (raw as List<dynamic>? ?? <dynamic>[])
        .whereType<Map>()
        .map((Map<dynamic, dynamic> row) => mapper(Map<String, dynamic>.from(row)))
        .toList();
  }
}
