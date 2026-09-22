class GuildVaultItem {
  const GuildVaultItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    this.rarity,
    this.icon = '',
    this.itemType = 'misc',
    this.enhancementLevel = 0,
    this.sourceType,
    this.createdAt,
  });

  final String id;
  final String itemId;
  final String itemName;
  final int quantity;
  final String? rarity;
  final String icon;
  final String itemType;
  final int enhancementLevel;
  final String? sourceType;
  final DateTime? createdAt;

  factory GuildVaultItem.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final dynamic raw = json['created_at'];
    if (raw is String && raw.isNotEmpty) {
      createdAt = DateTime.tryParse(raw);
    }
    return GuildVaultItem(
      id: (json['id'] ?? '').toString(),
      itemId: (json['item_id'] ?? '').toString(),
      itemName: (json['item_name'] ?? json['item_id'] ?? '—').toString(),
      quantity: _asInt(json['quantity'], fallback: 1),
      rarity: json['rarity']?.toString(),
      icon: (json['icon'] ?? '').toString(),
      itemType: (json['item_type'] ?? json['type'] ?? 'misc').toString(),
      enhancementLevel: _asInt(json['enhancement_level']),
      sourceType: json['source_type']?.toString(),
      createdAt: createdAt,
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class GuildVaultLedgerEntry {
  const GuildVaultLedgerEntry({
    required this.id,
    required this.action,
    this.payload = const <String, dynamic>{},
    this.createdAt,
    this.actorId,
    this.actorName,
  });

  final String id;
  final String action;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;
  final String? actorId;
  final String? actorName;

  factory GuildVaultLedgerEntry.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final dynamic raw = json['created_at'];
    if (raw is String && raw.isNotEmpty) {
      createdAt = DateTime.tryParse(raw);
    }
    return GuildVaultLedgerEntry(
      id: (json['id'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const <String, dynamic>{},
      createdAt: createdAt,
      actorId: json['actor_id']?.toString(),
      actorName: json['actor_name']?.toString(),
    );
  }
}

class GuildVaultTerritorySummary {
  const GuildVaultTerritorySummary({
    required this.id,
    required this.name,
    this.tradeIncome = 0,
    this.zoneNumber,
    this.lootItemId,
    this.lootItemChance,
  });

  final String id;
  final String name;
  final int tradeIncome;
  final int? zoneNumber;
  final String? lootItemId;
  final double? lootItemChance;

  factory GuildVaultTerritorySummary.fromJson(Map<String, dynamic> json) {
    return GuildVaultTerritorySummary(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      tradeIncome: GuildVaultItem._asInt(json['trade_income']),
      zoneNumber: json['zone_number'] != null
          ? GuildVaultItem._asInt(json['zone_number'])
          : null,
      lootItemId: json['loot_item_id']?.toString(),
      lootItemChance: json['loot_item_chance'] is num
          ? (json['loot_item_chance'] as num).toDouble()
          : double.tryParse(json['loot_item_chance']?.toString() ?? ''),
    );
  }
}

class GuildVaultState {
  const GuildVaultState({
    this.isLoading = false,
    this.hydrated = false,
    this.vaultGold = 0,
    this.vaultGoldPending = 0,
    this.monumentGoldPool = 0,
    this.isLeader = false,
    this.isOfficer = false,
    this.canManage = false,
    this.canCollect = false,
    this.vaultAutoPayoutWeekly = false,
    this.vaultTaxRate = 0.05,
    this.guildRole,
    this.items = const <GuildVaultItem>[],
    this.ledger = const <GuildVaultLedgerEntry>[],
    this.territories = const <GuildVaultTerritorySummary>[],
    this.error,
  });

  final bool isLoading;
  /// True after at least one successful [GuildVaultNotifier.load].
  final bool hydrated;
  final int vaultGold;
  final int vaultGoldPending;
  final int monumentGoldPool;
  final bool isLeader;
  final bool isOfficer;
  final bool canManage;
  final bool canCollect;
  final bool vaultAutoPayoutWeekly;
  final double vaultTaxRate;
  final String? guildRole;
  final List<GuildVaultItem> items;
  final List<GuildVaultLedgerEntry> ledger;
  final List<GuildVaultTerritorySummary> territories;
  final String? error;

  int get totalGold => vaultGold;

  factory GuildVaultState.initial() => const GuildVaultState();

  GuildVaultState copyWith({
    bool? isLoading,
    bool? hydrated,
    int? vaultGold,
    int? vaultGoldPending,
    int? monumentGoldPool,
    bool? isLeader,
    bool? isOfficer,
    bool? canManage,
    bool? canCollect,
    bool? vaultAutoPayoutWeekly,
    double? vaultTaxRate,
    String? guildRole,
    List<GuildVaultItem>? items,
    List<GuildVaultLedgerEntry>? ledger,
    List<GuildVaultTerritorySummary>? territories,
    String? error,
    bool clearError = false,
  }) {
    return GuildVaultState(
      isLoading: isLoading ?? this.isLoading,
      hydrated: hydrated ?? this.hydrated,
      vaultGold: vaultGold ?? this.vaultGold,
      vaultGoldPending: vaultGoldPending ?? this.vaultGoldPending,
      monumentGoldPool: monumentGoldPool ?? this.monumentGoldPool,
      isLeader: isLeader ?? this.isLeader,
      isOfficer: isOfficer ?? this.isOfficer,
      canManage: canManage ?? this.canManage,
      canCollect: canCollect ?? this.canCollect,
      vaultAutoPayoutWeekly: vaultAutoPayoutWeekly ?? this.vaultAutoPayoutWeekly,
      vaultTaxRate: vaultTaxRate ?? this.vaultTaxRate,
      guildRole: guildRole ?? this.guildRole,
      items: items ?? this.items,
      ledger: ledger ?? this.ledger,
      territories: territories ?? this.territories,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory GuildVaultState.fromJson(Map<String, dynamic> json) {
    final List<GuildVaultItem> items = (json['items'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map>()
        .map((Map<dynamic, dynamic> e) => GuildVaultItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final List<GuildVaultLedgerEntry> ledger =
        (json['ledger'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map>()
            .map((Map<dynamic, dynamic> e) =>
                GuildVaultLedgerEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
    final List<GuildVaultTerritorySummary> territories =
        (json['territories'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map>()
            .map((Map<dynamic, dynamic> e) =>
                GuildVaultTerritorySummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();

    final bool isLeader = json['is_leader'] == true;
    final bool isOfficer = json['is_officer'] == true;
    return GuildVaultState(
      hydrated: true,
      vaultGold: GuildVaultItem._asInt(json['vault_gold']),
      vaultGoldPending: GuildVaultItem._asInt(json['vault_gold_pending']),
      monumentGoldPool: GuildVaultItem._asInt(json['monument_gold_pool']),
      isLeader: isLeader,
      isOfficer: isOfficer,
      canManage: json['can_manage'] == true || isLeader,
      canCollect: false,
      vaultAutoPayoutWeekly: json['vault_auto_payout_weekly'] == true,
      vaultTaxRate: json['vault_tax_rate'] is num
          ? (json['vault_tax_rate'] as num).toDouble()
          : 0.05,
      guildRole: json['guild_role']?.toString(),
      items: items,
      ledger: ledger,
      territories: territories,
    );
  }
}
