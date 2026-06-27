enum GuildRole { leader, officer, member }

GuildRole _parseGuildRole(dynamic value) {
  switch (value?.toString()) {
    case 'leader':
      return GuildRole.leader;
    case 'officer':
    case 'commander':
      return GuildRole.officer;
    default:
      return GuildRole.member;
  }
}

String _guildRoleToString(GuildRole role) {
  switch (role) {
    case GuildRole.leader:
      return 'leader';
    case GuildRole.officer:
      return 'officer';
    case GuildRole.member:
      return 'member';
  }
}

class GuildRpcResult {
  const GuildRpcResult({
    required this.success,
    this.error,
    this.guild,
  });

  final bool success;
  final String? error;
  final GuildData? guild;

  static GuildRpcResult fromResponse(dynamic response) {
    if (response == null) {
      return const GuildRpcResult(success: false, error: 'Bos yanit');
    }

    final Map<String, dynamic> data = response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);

    if (data['success'] == false) {
      return GuildRpcResult(
        success: false,
        error: (data['error'] ?? data['message'] ?? 'Islem basarisiz').toString(),
      );
    }

    final GuildData? guild = GuildData.tryFromJson(data);
    if (guild != null && guild.isValid) {
      return GuildRpcResult(success: true, guild: guild);
    }

    if (data.containsKey('success') && data['success'] == true) {
      return const GuildRpcResult(success: true);
    }

    if (guild != null && guild.isValid) {
      return GuildRpcResult(success: true, guild: guild);
    }

    return GuildRpcResult(
      success: false,
      error: (data['error'] ?? data['message'] ?? 'Gecersiz lonca yaniti')
          .toString(),
    );
  }
}

class GuildMemberData {
  const GuildMemberData({
    required this.playerId,
    this.userId,
    required this.username,
    required this.level,
    required this.role,
    required this.power,
    this.isOnline,
    this.contribution,
  });

  final String playerId;
  final String? userId;
  final String username;
  final int level;
  final GuildRole role;
  final int power;
  final bool? isOnline;
  final int? contribution;

  factory GuildMemberData.fromJson(Map<String, dynamic> json) {
    return GuildMemberData(
      playerId: (json['player_id'] ?? '').toString(),
      userId: json['user_id']?.toString(),
      username: (json['username'] ?? '').toString(),
      level: _asInt(json['level'], fallback: 1),
      role: _parseGuildRole(json['role']),
      power: _asInt(json['power']),
      isOnline: json['is_online'] == null ? null : json['is_online'] == true,
      contribution: json['contribution'] == null
          ? null
          : _asInt(json['contribution']),
    );
  }

  Map<String, dynamic> toJson() => {
        'player_id': playerId,
        'user_id': userId,
        'username': username,
        'level': level,
        'role': _guildRoleToString(role),
        'power': power,
        'is_online': isOnline,
        'contribution': contribution,
      };

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class GuildData {
  const GuildData({
    required this.guildId,
    required this.name,
    this.description,
    required this.level,
    required this.leaderId,
    required this.memberCount,
    required this.maxMembers,
    required this.totalPower,
    required this.monumentLevel,
    required this.monumentStructural,
    required this.monumentMystical,
    required this.monumentCritical,
    required this.monumentGoldPool,
    this.minJoinPower = 0,
    this.members,
    this.loadError,
  });

  final String guildId;
  final String name;
  final String? description;
  final int level;
  final String leaderId;
  final int memberCount;
  final int maxMembers;
  final int totalPower;
  final int monumentLevel;
  final int monumentStructural;
  final int monumentMystical;
  final int monumentCritical;
  final int monumentGoldPool;
  final int minJoinPower;
  final List<GuildMemberData>? members;
  final String? loadError;

  bool get isValid => guildId.isNotEmpty && name.isNotEmpty;

  bool get hasMembers => members != null && members!.isNotEmpty;

  static GuildData? tryFromJson(Map<String, dynamic> json) {
    if (json['success'] == false) return null;

    final String guildId =
        (json['guild_id'] ?? json['id'] ?? '').toString().trim();
    if (guildId.isEmpty) return null;

    return GuildData.fromJson(json);
  }

  factory GuildData.fromJson(Map<String, dynamic> json) {
    final dynamic membersRaw = json['members'];
    final List<GuildMemberData>? members = membersRaw is List
        ? membersRaw
            .whereType<Map<String, dynamic>>()
            .map(GuildMemberData.fromJson)
            .toList()
        : null;

    return GuildData(
      guildId: (json['guild_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      level: _asInt(json['level'], fallback: 1),
      leaderId: (json['leader_id'] ?? '').toString(),
      memberCount: _asInt(json['member_count']),
      maxMembers: _asInt(json['max_members'], fallback: 50),
      totalPower: _asInt(json['total_power']),
      monumentLevel: _asInt(json['monument_level']),
      monumentStructural: _asInt(json['monument_structural']),
      monumentMystical: _asInt(json['monument_mystical']),
      monumentCritical: _asInt(json['monument_critical']),
      monumentGoldPool: _asInt(json['monument_gold_pool']),
      minJoinPower: _asInt(json['min_join_power']),
      members: members,
      loadError: json['error']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'guild_id': guildId,
        'name': name,
        'description': description,
        'level': level,
        'leader_id': leaderId,
        'member_count': memberCount,
        'max_members': maxMembers,
        'total_power': totalPower,
        'monument_level': monumentLevel,
        'monument_structural': monumentStructural,
        'monument_mystical': monumentMystical,
        'monument_critical': monumentCritical,
        'monument_gold_pool': monumentGoldPool,
        'min_join_power': minJoinPower,
        'members': members?.map((m) => m.toJson()).toList(),
      };

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

/// PLAN_10 §3.0 lonca boyut çarpanı.
double guildSizeMultiplier(int memberCount) {
  if (memberCount <= 10) return 0.35;
  if (memberCount <= 20) return 0.55;
  if (memberCount <= 30) return 0.75;
  if (memberCount <= 40) return 0.90;
  return 1.00;
}

String guildSizeLabel(int memberCount) {
  if (memberCount <= 10) return 'Küçük Lonca (0.35x)';
  if (memberCount <= 20) return 'Orta Lonca (0.55x)';
  if (memberCount <= 30) return 'Büyük Lonca (0.75x)';
  if (memberCount <= 40) return 'Çok Büyük Lonca (0.90x)';
  return 'Maksimum Lonca (1.00x)';
}

/// PLAN_10 §5.1 milestone bonusları (UI ile SQL uyumlu).
const List<(int level, String title, String effect)> kMonumentBonuses = [
  (5, 'Lonca XP Bonusu', '+%5 XP'),
  (10, 'Lonca Gold Bonusu', '+%3 Gold'),
  (15, 'Enerji Bonusu', '+5 Max Enerji'),
  (20, 'Overdose Koruması', '-%10 Overdose'),
  (25, 'Tesis Hız', '-%5 Üretim Süresi'),
  (30, 'Zindan Luck', '+10 Loot Şansı'),
  (35, 'Crafting Bonusu', '+%3 Craft Başarısı'),
  (40, 'PvP Kalkanı', '-%10 PvP Gold Kaybı'),
  (45, 'Enhancement Bonusu', '-%3 Enhancement Gold'),
  (50, 'Büyük Milestone', '+10 Enerji, +%5 XP'),
  (55, 'Boss Hasarı', '+%5 Boss Başarısı'),
  (60, 'Hastane Azaltma', '-%10 Hastane Süresi'),
  (65, 'Enhancement Shield', '+%2 Koruma'),
  (70, 'Reputation Bonusu', '+%5 Rep'),
  (75, 'Büyük Milestone', '+15 Enerji, +%8 XP'),
  (80, 'Phoenix Gücü', 'Günlük Overdose Kurtarışı'),
  (85, 'Leviathan Gücü', '-%2 Zindan Enerji'),
  (90, 'Titan Gücü', '-%5 Enhancement Gold'),
  (95, 'World Eater', '+%3 Tüm Stat'),
  (100, 'ETERNAL', '+20 Enerji, +%5 Stat, Aura'),
];

bool canUpgradeMonument(String? guildRole) {
  return guildRole == 'leader' ||
      guildRole == 'officer' ||
      guildRole == 'commander';
}
