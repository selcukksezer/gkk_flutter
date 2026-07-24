import 'dungeon_siege_prime_timer.dart';

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

/// Kuşatma zone numarası → o bölgenin boss zindanı (zindan sekmeleriyle aynı 1–7).
const Map<int, String> kSiegeCapstoneByZone = <int, String>{
  1: 'dng_010',
  2: 'dng_020',
  3: 'dng_030',
  4: 'dng_040',
  5: 'dng_050',
  6: 'dng_060',
  7: 'dng_065',
};

String? siegeCapstoneForZone(int zoneNumber) => kSiegeCapstoneByZone[zoneNumber];

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
    this.challengeCooldownMinutes = 10,
    this.inactiveReleaseMinutes = 10,
    this.powerBandPct = 0.30,
    this.sessionDurationMinutes = 180,
    this.holdReholdCooldownMinutes = 15,
    this.timezone = 'Europe/Istanbul',
    this.primeWindows = kDefaultSiegePrimeWindows,
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
  final int challengeCooldownMinutes;
  final int inactiveReleaseMinutes;
  final double powerBandPct;
  final int sessionDurationMinutes;
  final int holdReholdCooldownMinutes;
  final String timezone;
  final List<DungeonSiegePrimeWindow> primeWindows;

  bool get isLive => isEnabled && inPrimeWindow;

  static int repPerRun(DungeonSiegeConfig config) =>
      (20 * config.repBonusPct).floor().clamp(1, 99);

  /// Bölge `defense_power` → owner lonca kuşatma bonusu (1000 güç = +25%, tavan %25).
  static double territoryDefenseSiegeBonusPct(int defensePower) =>
      (defensePower / 4000.0).clamp(0.0, 0.25);

  static String territoryDefenseSummary(int defensePower, {bool ownerOnly = true}) {
    if (defensePower <= 0) return 'Savunma yok';
    final int pct = (territoryDefenseSiegeBonusPct(defensePower) * 100).round();
    if (ownerOnly) {
      return '🛡 $defensePower · owner slot +$pct% (max %25)';
    }
    return '🛡 $defensePower · kuşatma +$pct%';
  }

  /// Kuşatma oturum kartı / panel — owner vs diğer lonca metni.
  static String territoryDefenseSessionLabel({
    required int defensePower,
    required int myBonusPercent,
    required int maxBonusPercent,
    required bool receivesBonus,
  }) {
    if (defensePower <= 0) return '';
    if (receivesBonus && myBonusPercent > 0) {
      return 'Bölge savunması $defensePower · loncan +$myBonusPercent% slot gücü';
    }
    if (maxBonusPercent > 0) {
      return 'Bölge savunması $defensePower · owner lonca +$maxBonusPercent% (sen alamazsın)';
    }
    return 'Bölge savunması $defensePower';
  }

  static String farmBonusSummary(DungeonSiegeConfig config, {bool holdBonus = false}) {
    final int lootPct =
        ((config.lootBonusPct + (holdBonus ? config.holdBonusPct : 0)) * 100).round();
    final int goldPct =
        ((config.goldBonusPct + (holdBonus ? config.holdBonusPct : 0)) * 100).round();
    final int rep = repPerRun(config);
    return '+$lootPct% loot, +$goldPct% altın, +$rep itibar/koşu';
  }

  /// Sunucu `challenge_siege_slot` güç bandı — shadow çarpanı dahil.
  static int siegeChallengePower(int basePower, {bool shadowClass = false}) {
    var power = basePower;
    if (power <= 0) return 0;
    if (shadowClass) power = (power * 1.15).round();
    return power;
  }

  /// `abs(att - def) > max(def, 1) * powerBandPct` (sunucu ile aynı kural).
  static bool exceedsChallengePowerBand({
    required int attackerPower,
    required int defenderPower,
    required double powerBandPct,
  }) {
    if (powerBandPct <= 0) return false;
    final int def = defenderPower > 0 ? defenderPower : 1;
    return (attackerPower - defenderPower).abs() > def * powerBandPct;
  }

  static String challengePowerBandError(double powerBandPct) {
    final int pct = (powerBandPct * 100).round();
    return 'Güç farkı çok yüksek (±$pct%).';
  }

  factory DungeonSiegeConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const DungeonSiegeConfig(
        isEnabled: false,
        slotCount: 5,
        slotDurationMinutes: 20,
        challengeGoldCost: 250000,
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
      challengeGoldCost: _asInt(json['challenge_gold_cost'], fallback: 250000),
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
      challengeCooldownMinutes: _asInt(json['challenge_cooldown_minutes'], fallback: 10),
      inactiveReleaseMinutes: _asInt(json['inactive_release_minutes'], fallback: 10),
      powerBandPct: _asDouble(json['power_band_pct'], fallback: 0.30),
      sessionDurationMinutes: _asInt(json['session_duration_minutes'], fallback: 180),
      holdReholdCooldownMinutes: _asInt(json['hold_rehold_cooldown_minutes'], fallback: 15),
      timezone: json['timezone']?.toString() ?? 'Europe/Istanbul',
      primeWindows: _parsePrimeWindows(json['prime_windows']),
    );
  }

  static List<DungeonSiegePrimeWindow> _parsePrimeWindows(dynamic raw) {
    if (raw is List) {
      final List<DungeonSiegePrimeWindow> parsed = raw
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> row) => DungeonSiegePrimeWindow(
              start: row['start']?.toString() ?? '19:00',
              end: row['end']?.toString() ?? '21:00',
            ),
          )
          .toList();
      if (parsed.isNotEmpty) return parsed;
    }
    return kDefaultSiegePrimeWindows;
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

  static int _asInt(dynamic value, {int fallback = 0}) {
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

/// Kuşatma prime slot bonusu — tek koşu sonucu (attack_dungeon siege_bonus).
class DungeonSiegeRunBonus {
  const DungeonSiegeRunBonus({
    this.active = false,
    this.primeActive = false,
    this.hasSlot = false,
    this.applied = false,
    this.hasHoldBonus = false,
    this.lootBonusPct = 0,
    this.goldBonusPct = 0,
    this.slotLootBonusPct = 0,
    this.slotGoldBonusPct = 0,
    this.holdBonusPct = 0,
    this.repGained = 0,
  });

  final bool active;
  final bool primeActive;
  final bool hasSlot;
  final bool applied;
  final bool hasHoldBonus;
  final int lootBonusPct;
  final int goldBonusPct;
  final int slotLootBonusPct;
  final int slotGoldBonusPct;
  final int holdBonusPct;
  final int repGained;

  bool get shouldShowOnResult =>
      applied && hasSlot && (lootBonusPct > 0 || goldBonusPct > 0 || repGained > 0);

  /// Prime + kuşatma zindanı + slot yok → normal ödül uyarısı.
  bool get shouldShowNoSlotWarning => applied && active && primeActive && !hasSlot;

  bool get shouldShowAny => shouldShowOnResult || shouldShowNoSlotWarning;

  String noSlotWarningText({required int slotLootPct, required int slotGoldPct}) =>
      'Prime aktif — slot yok: normal ödül. Slot alsaydın +$slotLootPct% loot, +$slotGoldPct% altın.';

  String resultSummary() {
    final List<String> parts = <String>[
      '+$lootBonusPct% loot',
      '+$goldBonusPct% altın',
    ];
    if (repGained > 0) parts.add('+$repGained itibar');
    return parts.join(', ');
  }

  String? holdExtraLine() {
    if (!hasHoldBonus || holdBonusPct <= 0) return null;
    return 'Hold bonusu: +$holdBonusPct% loot & altın (lonca tutuyor)';
  }

  factory DungeonSiegeRunBonus.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const DungeonSiegeRunBonus();
    return DungeonSiegeRunBonus(
      active: json['active'] == true,
      primeActive: json['prime_active'] == true,
      hasSlot: json['has_slot'] == true,
      applied: json['applied'] == true,
      hasHoldBonus: json['has_hold_bonus'] == true,
      lootBonusPct: _asInt(json['loot_bonus_pct']),
      goldBonusPct: _asInt(json['gold_bonus_pct']),
      slotLootBonusPct: _asInt(json['slot_loot_bonus_pct']),
      slotGoldBonusPct: _asInt(json['slot_gold_bonus_pct']),
      holdBonusPct: _asInt(json['hold_bonus_pct']),
      repGained: _asInt(json['rep_gained']),
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
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
    this.guildId,
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
  final String? guildId;
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
      guildId: json['guild_id']?.toString(),
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
    this.territoryOwnerGuildId,
    this.territoryDefensePower = 0,
    this.territoryDefenseSiegeBonusPct = 0,
    this.territoryDefenseMaxBonusPct = 0,
    this.guildSlots = 0,
    this.hold,
  });

  final String sessionId;
  final String dungeonId;
  final int zoneNumber;
  final String? endsAt;
  final List<DungeonSiegeSlot> slots;
  final String? territoryOwnerGuildName;
  final String? territoryOwnerGuildId;
  final int territoryDefensePower;
  final double territoryDefenseSiegeBonusPct;
  final double territoryDefenseMaxBonusPct;
  final int guildSlots;
  final DungeonSiegeHold? hold;

  int get territoryDefenseSiegeBonusPercent => (territoryDefenseSiegeBonusPct * 100).round();

  int get territoryDefenseMaxBonusPercent => (territoryDefenseMaxBonusPct * 100).round();

  bool receivesTerritoryDefenseBonus(String? myGuildId) =>
      myGuildId != null &&
      hasTerritoryOwner &&
      myGuildId == territoryOwnerGuildId &&
      territoryDefenseSiegeBonusPct > 0;

  bool slotReceivesTerritoryDefenseBonus(DungeonSiegeSlot slot) =>
      hasTerritoryOwner &&
      slot.guildId != null &&
      slot.guildId!.isNotEmpty &&
      slot.guildId == territoryOwnerGuildId &&
      territoryDefenseMaxBonusPct > 0;

  /// Meydan okumada sunucunun uyguladığı slot savunucu gücü (bölge bonusu dahil).
  int effectiveSiegePowerForSlot(DungeonSiegeSlot slot) {
    if (!slot.isOccupied) return 0;
    final double bonus = slotReceivesTerritoryDefenseBonus(slot)
        ? territoryDefenseMaxBonusPct
        : 0.0;
    return (slot.holderPower * (1 + bonus)).round();
  }

  bool get hasTerritoryOwner =>
      territoryOwnerGuildId != null && territoryOwnerGuildId!.isNotEmpty;

  int holdMinRequired(DungeonSiegeConfig config, {String? myGuildId}) =>
      config.holdMinMembers;

  bool canStartHold(DungeonSiegeConfig config, {String? myGuildId}) {
    if (hasTerritoryOwner && (myGuildId == null || myGuildId != territoryOwnerGuildId)) {
      return false;
    }
    return guildSlots >= config.holdMinMembers;
  }

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
      territoryOwnerGuildId: json['territory_owner_guild_id']?.toString(),
      territoryDefensePower: DungeonSiegeConfig._asInt(json['territory_defense_power']),
      territoryDefenseSiegeBonusPct: DungeonSiegeConfig._asDouble(
        json['territory_defense_siege_bonus_pct'],
        fallback: 0,
      ),
      territoryDefenseMaxBonusPct: DungeonSiegeConfig._asDouble(
        json['territory_defense_max_bonus_pct'],
        fallback: DungeonSiegeConfig.territoryDefenseSiegeBonusPct(
          DungeonSiegeConfig._asInt(json['territory_defense_power']),
        ),
      ),
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
    this.mySlotGlobalDungeonId,
    this.holdsSlotElsewhere = false,
    this.bannedDungeonIds = const <String>[],
  });

  final bool enabled;
  final bool inPrimeWindow;
  final bool siegeActive;
  final bool isBanned;
  final DungeonSiegeConfig config;
  final List<DungeonSiegeSession> sessions;
  final String? mySlotId;
  final int? mySlotNumber;
  final String? mySlotGlobalDungeonId;
  final bool holdsSlotElsewhere;
  final List<String> bannedDungeonIds;

  bool isBannedForDungeon(String dungeonId) {
    if (dungeonId.isEmpty) return isBanned;
    if (bannedDungeonIds.contains(dungeonId)) return true;
    return isBanned;
  }

  DungeonSiegeStatus copyWith({
    bool? enabled,
    bool? inPrimeWindow,
    bool? siegeActive,
    bool? isBanned,
    DungeonSiegeConfig? config,
    List<DungeonSiegeSession>? sessions,
    String? mySlotId,
    int? mySlotNumber,
    String? mySlotGlobalDungeonId,
    bool? holdsSlotElsewhere,
    List<String>? bannedDungeonIds,
  }) {
    return DungeonSiegeStatus(
      enabled: enabled ?? this.enabled,
      inPrimeWindow: inPrimeWindow ?? this.inPrimeWindow,
      siegeActive: siegeActive ?? this.siegeActive,
      isBanned: isBanned ?? this.isBanned,
      config: config ?? this.config,
      sessions: sessions ?? this.sessions,
      mySlotId: mySlotId ?? this.mySlotId,
      mySlotNumber: mySlotNumber ?? this.mySlotNumber,
      mySlotGlobalDungeonId: mySlotGlobalDungeonId ?? this.mySlotGlobalDungeonId,
      holdsSlotElsewhere: holdsSlotElsewhere ?? this.holdsSlotElsewhere,
      bannedDungeonIds: bannedDungeonIds ?? this.bannedDungeonIds,
    );
  }

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
    final Map<String, dynamic>? mySlotGlobal = json['my_slot_global'] is Map
        ? Map<String, dynamic>.from(json['my_slot_global'] as Map)
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
      mySlotGlobalDungeonId: mySlotGlobal?['dungeon_id']?.toString(),
      holdsSlotElsewhere: json['holds_slot_elsewhere'] == true,
      bannedDungeonIds: (json['banned_dungeon_ids'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic id) => id.toString())
          .where((String id) => id.isNotEmpty)
          .toList(growable: false),
    );
  }

  DungeonSiegeSession? sessionForDungeon(String dungeonId) {
    for (final DungeonSiegeSession session in sessions) {
      if (session.dungeonId == dungeonId) return session;
    }
    return null;
  }

  bool hasSlotInDungeon(String dungeonId) {
    final DungeonSiegeSession? session = sessionForDungeon(dungeonId);
    if (session == null) return false;
    return session.slots.any((DungeonSiegeSlot slot) => slot.isMine);
  }

  bool canChallengeSlot(String dungeonId, DungeonSiegeSlot slot) {
    if (!siegeActive) return false;
    if (isBannedForDungeon(dungeonId)) return false;
    if (!slot.isOccupied || slot.isMine) return false;
    if (hasSlotInDungeon(dungeonId)) return false;
    return true;
  }
}

class DungeonSiegeActionResult {
  const DungeonSiegeActionResult({
    required this.success,
    this.error,
    this.message,
    this.youWon,
    this.holdBroken,
    this.holdBreakProgress,
    this.goldSpent,
    this.banMinutes,
    this.territoryReserved,
    this.slotId,
    this.slotNumber,
    this.expiresAt,
  });

  final bool success;
  final String? error;
  final String? message;
  final bool? youWon;
  final bool? holdBroken;
  final int? holdBreakProgress;
  final int? goldSpent;
  final int? banMinutes;
  final bool? territoryReserved;
  final String? slotId;
  final int? slotNumber;
  final String? expiresAt;

  factory DungeonSiegeActionResult.fromJson(Map<String, dynamic> json) {
    return DungeonSiegeActionResult(
      success: json['success'] == true,
      error: json['error']?.toString(),
      message: json['message']?.toString(),
      youWon: json['you_won'] as bool?,
      holdBroken: json['hold_broken'] as bool?,
      holdBreakProgress: json['hold_break_progress'] != null
          ? DungeonSiegeConfig._asInt(json['hold_break_progress'])
          : null,
      goldSpent: json['gold_spent'] != null ? DungeonSiegeConfig._asInt(json['gold_spent']) : null,
      banMinutes: json['ban_minutes'] != null ? DungeonSiegeConfig._asInt(json['ban_minutes']) : null,
      territoryReserved: json['territory_reserved'] as bool?,
      slotId: json['slot_id']?.toString(),
      slotNumber: json['slot_number'] != null ? DungeonSiegeConfig._asInt(json['slot_number']) : null,
      expiresAt: json['expires_at']?.toString(),
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
    this.territoryId,
    this.ownerGuildId,
    this.ownerGuildName,
    this.siegeDungeonId,
    this.defensePower = 0,
    this.gemDefenseBoost = 0,
    this.defenseSiegeBonusPct = 0,
  });

  final int zoneNumber;
  final String territoryName;
  final String? territoryId;
  final String? ownerGuildId;
  final String? ownerGuildName;
  final String? siegeDungeonId;
  final int defensePower;
  final int gemDefenseBoost;
  final double defenseSiegeBonusPct;

  int get defenseSiegeBonusPercent => (defenseSiegeBonusPct * 100).round();

  factory DungeonSiegeTerritoryLink.fromJson(Map<String, dynamic> json) {
    final int defensePower = DungeonSiegeConfig._asInt(json['defense_power']);
    return DungeonSiegeTerritoryLink(
      zoneNumber: DungeonSiegeConfig._asInt(json['zone_number']),
      territoryName: (json['territory_name'] ?? '').toString(),
      territoryId: json['territory_id']?.toString(),
      ownerGuildId: json['owner_guild_id']?.toString(),
      ownerGuildName: json['owner_guild_name']?.toString(),
      siegeDungeonId: json['siege_dungeon_id']?.toString(),
      defensePower: defensePower,
      gemDefenseBoost: DungeonSiegeConfig._asInt(json['gem_defense_boost']),
      defenseSiegeBonusPct: DungeonSiegeConfig._asDouble(
        json['defense_siege_bonus_pct'],
        fallback: DungeonSiegeConfig.territoryDefenseSiegeBonusPct(defensePower),
      ),
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
    this.payload = const <String, dynamic>{},
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? createdAt;
  final bool isUnread;
  final Map<String, dynamic> payload;

  String? get dungeonIdFromPayload => payload['dungeon_id']?.toString();

  factory DungeonSiegeNotification.fromJson(Map<String, dynamic> json) {
    return DungeonSiegeNotification(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt: json['created_at']?.toString(),
      isUnread: json['is_unread'] == true,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const <String, dynamic>{},
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
