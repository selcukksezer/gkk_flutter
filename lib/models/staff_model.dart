class StaffProfile {
  const StaffProfile({
    required this.isStaff,
    this.role,
    this.badge,
    this.permissions = const <String>[],
  });

  final bool isStaff;
  final String? role;
  final String? badge;
  final List<String> permissions;

  bool get isAdmin => role == 'admin';

  bool has(String permission) =>
      isAdmin || permissions.contains(permission);

  bool get hasLiveOpsAccess => isAdmin;

  factory StaffProfile.fromJson(Map<String, dynamic> json) {
    if (json['is_staff'] != true) {
      return const StaffProfile(isStaff: false);
    }
    final dynamic rawPerms = json['permissions'];
    final List<String> perms = <String>[];
    if (rawPerms is List) {
      for (final dynamic p in rawPerms) {
        perms.add(p.toString());
      }
    }
    return StaffProfile(
      isStaff: true,
      role: json['role']?.toString(),
      badge: json['badge']?.toString(),
      permissions: perms,
    );
  }

  static const StaffProfile none = StaffProfile(isStaff: false);
}

class StaffDashboard {
  const StaffDashboard({
    this.openTickets = 0,
    this.pendingBugs = 0,
    this.pendingGemRewards = 0,
    this.openChatReports = 0,
    this.recentAudit = const <StaffAuditBrief>[],
  });

  final int openTickets;
  final int pendingBugs;
  final int pendingGemRewards;
  final int openChatReports;
  final List<StaffAuditBrief> recentAudit;

  factory StaffDashboard.fromJson(Map<String, dynamic> json) {
    final List<StaffAuditBrief> audit = <StaffAuditBrief>[];
    final dynamic raw = json['recent_audit'];
    if (raw is List) {
      for (final dynamic row in raw) {
        if (row is Map) {
          audit.add(StaffAuditBrief.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }
    return StaffDashboard(
      openTickets: (json['open_tickets'] as num?)?.toInt() ?? 0,
      pendingBugs: (json['pending_bugs'] as num?)?.toInt() ?? 0,
      pendingGemRewards: (json['pending_gem_rewards'] as num?)?.toInt() ?? 0,
      openChatReports: (json['open_chat_reports'] as num?)?.toInt() ?? 0,
      recentAudit: audit,
    );
  }
}

class GemRewardPendingItem {
  const GemRewardPendingItem({
    required this.id,
    required this.playerId,
    required this.category,
    required this.title,
    required this.status,
    this.username,
    this.displayName,
    this.suggestedGems,
    this.suggestedAt,
    this.suggesterUsername,
    this.createdAt,
  });

  final String id;
  final String playerId;
  final String category;
  final String title;
  final String status;
  final String? username;
  final String? displayName;
  final int? suggestedGems;
  final DateTime? suggestedAt;
  final String? suggesterUsername;
  final DateTime? createdAt;

  factory GemRewardPendingItem.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String key) {
      final dynamic raw = json[key];
      if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
      return null;
    }

    return GemRewardPendingItem(
      id: (json['id'] ?? '').toString(),
      playerId: (json['player_id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      username: json['username']?.toString(),
      displayName: json['display_name']?.toString(),
      suggestedGems: (json['suggested_gems'] as num?)?.toInt(),
      suggestedAt: parse('suggested_at'),
      suggesterUsername: json['suggester_username']?.toString(),
      createdAt: parse('created_at'),
    );
  }
}

class GemRewardHistoryItem {
  const GemRewardHistoryItem({
    required this.id,
    required this.playerId,
    required this.category,
    required this.title,
    this.username,
    this.displayName,
    this.rewardGemsApproved,
    this.suggestedGems,
    this.reviewedAt,
    this.reviewerUsername,
    this.suggesterUsername,
    this.reviewNote,
  });

  final String id;
  final String playerId;
  final String category;
  final String title;
  final String? username;
  final String? displayName;
  final int? rewardGemsApproved;
  final int? suggestedGems;
  final DateTime? reviewedAt;
  final String? reviewerUsername;
  final String? suggesterUsername;
  final String? reviewNote;

  factory GemRewardHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? reviewedAt;
    final dynamic raw = json['reviewed_at'];
    if (raw is String && raw.isNotEmpty) reviewedAt = DateTime.tryParse(raw);

    return GemRewardHistoryItem(
      id: (json['id'] ?? '').toString(),
      playerId: (json['player_id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      username: json['username']?.toString(),
      displayName: json['display_name']?.toString(),
      rewardGemsApproved: (json['reward_gems_approved'] as num?)?.toInt(),
      suggestedGems: (json['suggested_gems'] as num?)?.toInt(),
      reviewedAt: reviewedAt,
      reviewerUsername: json['reviewer_username']?.toString(),
      suggesterUsername: json['suggester_username']?.toString(),
      reviewNote: json['review_note']?.toString(),
    );
  }
}

class StaffAuditBrief {
  const StaffAuditBrief({
    required this.action,
    this.createdAt,
    this.targetType,
    this.actorUsername,
  });

  final String action;
  final DateTime? createdAt;
  final String? targetType;
  final String? actorUsername;

  factory StaffAuditBrief.fromJson(Map<String, dynamic> json) {
    DateTime? at;
    final dynamic raw = json['created_at'];
    if (raw is String) at = DateTime.tryParse(raw);
    return StaffAuditBrief(
      action: (json['action'] ?? '').toString(),
      createdAt: at,
      targetType: json['target_type']?.toString(),
      actorUsername: json['actor_username']?.toString(),
    );
  }
}

class StaffAuditEntry {
  const StaffAuditEntry({
    required this.id,
    required this.action,
    this.actorUsername,
    this.actorDisplayName,
    this.actorRole,
    this.actorBadge,
    this.permissionKey,
    this.targetType,
    this.targetId,
    this.targetUsername,
    this.payload,
    this.result,
    this.createdAt,
  });

  final String id;
  final String action;
  final String? actorUsername;
  final String? actorDisplayName;
  final String? actorRole;
  final String? actorBadge;
  final String? permissionKey;
  final String? targetType;
  final String? targetId;
  final String? targetUsername;
  final Map<String, dynamic>? payload;
  final Map<String, dynamic>? result;
  final DateTime? createdAt;

  factory StaffAuditEntry.fromJson(Map<String, dynamic> json) {
    DateTime? at;
    final dynamic raw = json['created_at'];
    if (raw is String) at = DateTime.tryParse(raw);
    return StaffAuditEntry(
      id: (json['id'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      actorUsername: json['actor_username']?.toString(),
      actorDisplayName: json['actor_display_name']?.toString(),
      actorRole: json['actor_role']?.toString(),
      actorBadge: json['actor_badge']?.toString(),
      permissionKey: json['permission_key']?.toString(),
      targetType: json['target_type']?.toString(),
      targetId: json['target_id']?.toString(),
      targetUsername: json['target_username']?.toString(),
      payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload'] as Map) : null,
      result: json['result'] is Map ? Map<String, dynamic>.from(json['result'] as Map) : null,
      createdAt: at,
    );
  }
}

class ChatReportEntry {
  const ChatReportEntry({
    required this.id,
    required this.messageId,
    required this.reason,
    this.details,
    this.status,
    this.reporterUsername,
    this.senderUsername,
    this.senderAuthId,
    this.messagePreview,
    this.channel,
    this.createdAt,
  });

  final String id;
  final String messageId;
  final String reason;
  final String? details;
  final String? status;
  final String? reporterUsername;
  final String? senderUsername;
  final String? senderAuthId;
  final String? messagePreview;
  final String? channel;
  final DateTime? createdAt;

  factory ChatReportEntry.fromJson(Map<String, dynamic> json) {
    DateTime? at;
    final dynamic raw = json['created_at'];
    if (raw is String) at = DateTime.tryParse(raw);
    return ChatReportEntry(
      id: (json['id'] ?? '').toString(),
      messageId: (json['message_id'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      details: json['details']?.toString(),
      status: json['status']?.toString(),
      reporterUsername: json['reporter_username']?.toString(),
      senderUsername: json['sender_username']?.toString(),
      senderAuthId: json['sender_auth_id']?.toString(),
      messagePreview: json['message_preview']?.toString(),
      channel: json['channel']?.toString(),
      createdAt: at,
    );
  }
}

class GmRosterEntry {
  const GmRosterEntry({
    required this.authId,
    required this.username,
    this.displayName,
    this.grantedAt,
    this.permissions = const <String>[],
  });

  final String authId;
  final String username;
  final String? displayName;
  final DateTime? grantedAt;
  final List<String> permissions;

  factory GmRosterEntry.fromJson(Map<String, dynamic> json) {
    DateTime? at;
    final dynamic raw = json['granted_at'];
    if (raw is String) at = DateTime.tryParse(raw);
    final List<String> perms = <String>[];
    if (json['permissions'] is List) {
      for (final dynamic p in json['permissions'] as List) {
        perms.add(p.toString());
      }
    }
    return GmRosterEntry(
      authId: (json['auth_id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      displayName: json['display_name']?.toString(),
      grantedAt: at,
      permissions: perms,
    );
  }
}

class StaffInventoryRow {
  const StaffInventoryRow({
    required this.rowId,
    required this.itemId,
    required this.name,
    required this.quantity,
    this.isEquipped = false,
    this.equippedSlot,
    this.enhancementLevel = 0,
    this.isStackable = false,
    this.maxStack = 999,
    this.rarity,
    this.itemType,
  });

  final String rowId;
  final String itemId;
  final String name;
  final int quantity;
  final bool isEquipped;
  final String? equippedSlot;
  final int enhancementLevel;
  final bool isStackable;
  final int maxStack;
  final String? rarity;
  final String? itemType;

  factory StaffInventoryRow.fromJson(Map<String, dynamic> json) {
    return StaffInventoryRow(
      rowId: (json['row_id'] ?? '').toString(),
      itemId: (json['item_id'] ?? '').toString(),
      name: (json['name'] ?? json['item_id'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      isEquipped: json['is_equipped'] == true,
      equippedSlot: json['equipped_slot']?.toString(),
      enhancementLevel: (json['enhancement_level'] as num?)?.toInt() ?? 0,
      isStackable: json['is_stackable'] == true,
      maxStack: (json['max_stack'] as num?)?.toInt() ?? 999,
      rarity: json['rarity']?.toString(),
      itemType: json['item_type']?.toString(),
    );
  }
}

class StaffItemCatalogEntry {
  const StaffItemCatalogEntry({
    required this.id,
    required this.name,
    this.itemType,
    this.rarity,
    this.isStackable = false,
    this.maxStack = 999,
  });

  final String id;
  final String name;
  final String? itemType;
  final String? rarity;
  final bool isStackable;
  final int maxStack;

  factory StaffItemCatalogEntry.fromJson(Map<String, dynamic> json) {
    return StaffItemCatalogEntry(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['id'] ?? '').toString(),
      itemType: json['item_type']?.toString(),
      rarity: json['rarity']?.toString(),
      isStackable: json['is_stackable'] == true,
      maxStack: (json['max_stack'] as num?)?.toInt() ?? 999,
    );
  }
}

class StaffPlayerBrief {
  const StaffPlayerBrief({
    required this.authId,
    required this.username,
    this.displayName,
    this.level,
    this.isBanned = false,
    this.staffBadge,
  });

  final String authId;
  final String username;
  final String? displayName;
  final int? level;
  final bool isBanned;
  final String? staffBadge;

  factory StaffPlayerBrief.fromJson(Map<String, dynamic> json) {
    return StaffPlayerBrief(
      authId: (json['auth_id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      displayName: json['display_name']?.toString(),
      level: (json['level'] as num?)?.toInt(),
      isBanned: json['is_banned'] == true,
      staffBadge: json['staff_badge']?.toString(),
    );
  }
}

class StaffPlayerDetail {
  const StaffPlayerDetail({
    required this.authId,
    required this.username,
    this.displayName,
    this.email,
    this.characterClass,
    this.level,
    this.xp,
    this.gold,
    this.gems,
    this.energy,
    this.maxEnergy,
    this.health,
    this.maxHealth,
    this.attack,
    this.defense,
    this.power,
    this.luck,
    this.statPoints,
    this.reputation,
    this.pvpRating,
    this.pvpWins,
    this.pvpLosses,
    this.addictionLevel,
    this.tolerance,
    this.guildId,
    this.guildName,
    this.guildRole,
    this.isOnline = false,
    this.isBanned = false,
    this.banReason,
    this.bannedUntil,
    this.inHospital = false,
    this.hospitalUntil,
    this.hospitalReason,
    this.inPrison = false,
    this.prisonUntil,
    this.prisonReason,
    this.tradeBannedUntil,
    this.chatMutedUntil,
    this.inventorySlotsUsed,
    this.inventoryItemRows,
    this.inventoryCapacity = 20,
    this.lastLoginAt,
    this.lastActiveAt,
    this.createdAt,
    this.totalPlaytimeSeconds,
    this.staffBadge,
    this.kingBadge,
    this.isProtectedAdmin = false,
  });

  final String authId;
  final String username;
  final String? displayName;
  final String? email;
  final String? characterClass;
  final int? level;
  final int? xp;
  final num? gold;
  final num? gems;
  final int? energy;
  final int? maxEnergy;
  final int? health;
  final int? maxHealth;
  final int? attack;
  final int? defense;
  final int? power;
  final int? luck;
  final int? statPoints;
  final int? reputation;
  final int? pvpRating;
  final int? pvpWins;
  final int? pvpLosses;
  final int? addictionLevel;
  final int? tolerance;
  final String? guildId;
  final String? guildName;
  final String? guildRole;
  final bool isOnline;
  final bool isBanned;
  final String? banReason;
  final DateTime? bannedUntil;
  final bool inHospital;
  final DateTime? hospitalUntil;
  final String? hospitalReason;
  final bool inPrison;
  final DateTime? prisonUntil;
  final String? prisonReason;
  final DateTime? tradeBannedUntil;
  final DateTime? chatMutedUntil;
  final int? inventorySlotsUsed;
  final int? inventoryItemRows;
  final int inventoryCapacity;
  final DateTime? lastLoginAt;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;
  final int? totalPlaytimeSeconds;
  final String? staffBadge;
  final String? kingBadge;
  final bool isProtectedAdmin;

  bool get isTradeBanned =>
      tradeBannedUntil != null && tradeBannedUntil!.isAfter(DateTime.now());

  bool get isChatMuted =>
      chatMutedUntil != null && chatMutedUntil!.isAfter(DateTime.now());

  bool get isAccountBanned =>
      isBanned && (bannedUntil == null || bannedUntil!.isAfter(DateTime.now()));

  String get classLabelTr {
    switch (characterClass) {
      case 'warrior':
        return 'Savaşçı';
      case 'alchemist':
        return 'Simyacı';
      case 'shadow':
        return 'Gölge';
      default:
        return characterClass ?? '—';
    }
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  factory StaffPlayerDetail.fromJson(Map<String, dynamic> json) {
    return StaffPlayerDetail(
      authId: (json['auth_id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      displayName: json['display_name']?.toString(),
      email: json['email']?.toString(),
      characterClass: json['character_class']?.toString(),
      level: (json['level'] as num?)?.toInt(),
      xp: (json['xp'] as num?)?.toInt(),
      gold: json['gold'] as num?,
      gems: json['gems'] as num?,
      energy: (json['energy'] as num?)?.toInt(),
      maxEnergy: (json['max_energy'] as num?)?.toInt(),
      health: (json['health'] as num?)?.toInt(),
      maxHealth: (json['max_health'] as num?)?.toInt(),
      attack: (json['attack'] as num?)?.toInt(),
      defense: (json['defense'] as num?)?.toInt(),
      power: (json['power'] as num?)?.toInt(),
      luck: (json['luck'] as num?)?.toInt(),
      statPoints: (json['stat_points'] as num?)?.toInt(),
      reputation: (json['reputation'] as num?)?.toInt(),
      pvpRating: (json['pvp_rating'] as num?)?.toInt(),
      pvpWins: (json['pvp_wins'] as num?)?.toInt(),
      pvpLosses: (json['pvp_losses'] as num?)?.toInt(),
      addictionLevel: (json['addiction_level'] as num?)?.toInt(),
      tolerance: (json['tolerance'] as num?)?.toInt(),
      guildId: json['guild_id']?.toString(),
      guildName: json['guild_name']?.toString(),
      guildRole: json['guild_role']?.toString(),
      isOnline: json['is_online'] == true,
      isBanned: json['is_banned'] == true,
      banReason: json['ban_reason']?.toString(),
      bannedUntil: _parseDate(json['banned_until']),
      inHospital: json['in_hospital'] == true,
      hospitalUntil: _parseDate(json['hospital_until']),
      hospitalReason: json['hospital_reason']?.toString(),
      inPrison: json['in_prison'] == true,
      prisonUntil: _parseDate(json['prison_until']),
      prisonReason: json['prison_reason']?.toString(),
      tradeBannedUntil: _parseDate(json['trade_banned_until']),
      chatMutedUntil: _parseDate(json['chat_muted_until']),
      inventorySlotsUsed: (json['inventory_slots_used'] as num?)?.toInt(),
      inventoryItemRows: (json['inventory_item_rows'] as num?)?.toInt(),
      inventoryCapacity: (json['inventory_capacity'] as num?)?.toInt() ?? 20,
      lastLoginAt: _parseDate(json['last_login_at']),
      lastActiveAt: _parseDate(json['last_active_at']),
      createdAt: _parseDate(json['created_at']),
      totalPlaytimeSeconds: (json['total_playtime_seconds'] as num?)?.toInt(),
      staffBadge: json['staff_badge']?.toString(),
      kingBadge: json['king_badge']?.toString(),
      isProtectedAdmin: json['is_protected_admin'] == true,
    );
  }
}

class PermissionCatalogItem {
  const PermissionCatalogItem({
    required this.key,
    required this.category,
    required this.labelTr,
    this.descriptionTr = '',
    this.minRole = 'gm',
    this.isDangerous = false,
  });

  final String key;
  final String category;
  final String labelTr;
  final String descriptionTr;
  final String minRole;
  final bool isDangerous;

  factory PermissionCatalogItem.fromJson(Map<String, dynamic> json) {
    return PermissionCatalogItem(
      key: (json['key'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      labelTr: (json['label_tr'] ?? '').toString(),
      descriptionTr: (json['description_tr'] ?? '').toString(),
      minRole: (json['min_role'] ?? 'gm').toString(),
      isDangerous: json['is_dangerous'] == true,
    );
  }
}
