class DungeonSiegeConfig {
  const DungeonSiegeConfig({
    required this.isEnabled,
    required this.slotCount,
    required this.slotDurationMinutes,
    required this.challengeGoldCost,
    required this.lootBonusPct,
    required this.goldBonusPct,
    required this.inPrimeWindow,
    this.banDurationMinutes = 45,
  });

  final bool isEnabled;
  final int slotCount;
  final int slotDurationMinutes;
  final int challengeGoldCost;
  final double lootBonusPct;
  final double goldBonusPct;
  final bool inPrimeWindow;
  final int banDurationMinutes;

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
      inPrimeWindow: json['in_prime_window'] == true,
      banDurationMinutes: _asInt(json['ban_duration_minutes'], fallback: 45),
    );
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
  });

  final String slotId;
  final int slotNumber;
  final String? holderId;
  final String? holderName;
  final int holderPower;
  final String? guildName;
  final String? expiresAt;
  final bool isMine;

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
  });

  final String sessionId;
  final String dungeonId;
  final int zoneNumber;
  final String? endsAt;
  final List<DungeonSiegeSlot> slots;

  factory DungeonSiegeSession.fromJson(Map<String, dynamic> json) {
    final List<DungeonSiegeSlot> slots = (json['slots'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map>()
        .map((Map<dynamic, dynamic> row) => DungeonSiegeSlot.fromJson(Map<String, dynamic>.from(row)))
        .toList();

    return DungeonSiegeSession(
      sessionId: (json['session_id'] ?? '').toString(),
      dungeonId: (json['dungeon_id'] ?? '').toString(),
      zoneNumber: DungeonSiegeConfig._asInt(json['zone_number']),
      endsAt: json['ends_at']?.toString(),
      slots: slots,
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

/// Kuşatma boss zindanları (DB config ile aynı).
const Set<String> kSiegeDungeonIds = <String>{
  'dng_010',
  'dng_020',
  'dng_030',
  'dng_040',
  'dng_050',
  'dng_060',
  'dng_065',
};

bool isSiegeDungeon(String dungeonId) => kSiegeDungeonIds.contains(dungeonId);
