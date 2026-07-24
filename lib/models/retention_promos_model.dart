class RetentionCodexPromo {
  const RetentionCodexPromo({
    required this.discovered,
    required this.total,
    required this.newEntries24h,
    required this.claimableMilestones,
  });

  final int discovered;
  final int total;
  final int newEntries24h;
  final int claimableMilestones;

  bool get showBanner => claimableMilestones > 0 || newEntries24h > 0;

  factory RetentionCodexPromo.fromJson(Map<String, dynamic> json) {
    return RetentionCodexPromo(
      discovered: (json['discovered'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      newEntries24h: (json['new_entries_24h'] as num?)?.toInt() ?? 0,
      claimableMilestones: (json['claimable_milestones'] as num?)?.toInt() ?? 0,
    );
  }
}

class RetentionNemesisPromo {
  const RetentionNemesisPromo({
    required this.hasRival,
    this.rivalId,
    this.rivalUsername,
    this.losses = 0,
    this.wins = 0,
    this.online = false,
    this.leaderboardGap = 0,
    this.dismissed = false,
    this.shouldNotifyOnline = false,
  });

  final bool hasRival;
  final String? rivalId;
  final String? rivalUsername;
  final int losses;
  final int wins;
  final bool online;
  final int leaderboardGap;
  final bool dismissed;
  final bool shouldNotifyOnline;

  bool get showBanner => hasRival && losses >= 2 && !dismissed;

  factory RetentionNemesisPromo.fromJson(Map<String, dynamic> json) {
    return RetentionNemesisPromo(
      hasRival: json['has_rival'] == true,
      rivalId: json['rival_id']?.toString(),
      rivalUsername: json['rival_username']?.toString(),
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      online: json['online'] == true,
      leaderboardGap: (json['leaderboard_gap'] as num?)?.toInt() ?? 0,
      dismissed: json['dismissed'] == true,
      shouldNotifyOnline: json['should_notify_online'] == true,
    );
  }
}

class RetentionNightMarketPromo {
  const RetentionNightMarketPromo({
    required this.active,
    this.startsAt,
    this.endsAt,
    this.secondsLeft = 0,
  });

  final bool active;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int secondsLeft;

  bool get showBanner => active;

  factory RetentionNightMarketPromo.fromJson(Map<String, dynamic> json) {
    return RetentionNightMarketPromo(
      active: json['active'] == true,
      startsAt: _parseDate(json['starts_at']),
      endsAt: _parseDate(json['ends_at']),
      secondsLeft: (json['seconds_left'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }
}

class RetentionPromos {
  const RetentionPromos({
    required this.codex,
    required this.nemesis,
    required this.nightMarket,
  });

  final RetentionCodexPromo codex;
  final RetentionNemesisPromo nemesis;
  final RetentionNightMarketPromo nightMarket;

  factory RetentionPromos.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> codexMap = json['codex'] is Map
        ? Map<String, dynamic>.from(json['codex'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> nemesisMap = json['nemesis'] is Map
        ? Map<String, dynamic>.from(json['nemesis'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> nightMap = json['night_market'] is Map
        ? Map<String, dynamic>.from(json['night_market'] as Map)
        : <String, dynamic>{};

    return RetentionPromos(
      codex: RetentionCodexPromo.fromJson(codexMap),
      nemesis: RetentionNemesisPromo.fromJson(nemesisMap),
      nightMarket: RetentionNightMarketPromo.fromJson(nightMap),
    );
  }

  static const RetentionPromos empty = RetentionPromos(
    codex: RetentionCodexPromo(
      discovered: 0,
      total: 0,
      newEntries24h: 0,
      claimableMilestones: 0,
    ),
    nemesis: RetentionNemesisPromo(hasRival: false),
    nightMarket: RetentionNightMarketPromo(active: false),
  );
}
