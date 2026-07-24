class NemesisRival {
  const NemesisRival({
    required this.hasRival,
    this.rivalId,
    this.rivalUsername,
    this.losses = 0,
    this.wins = 0,
    this.online = false,
    this.level = 1,
    this.power = 0,
    this.pvpRating = 1000,
    this.leaderboardGap = 0,
    this.dismissed = false,
    this.lastMatchAt,
  });

  final bool hasRival;
  final String? rivalId;
  final String? rivalUsername;
  final int losses;
  final int wins;
  final bool online;
  final int level;
  final int power;
  final int pvpRating;
  final int leaderboardGap;
  final bool dismissed;
  final DateTime? lastMatchAt;

  int get nemesisScore => losses * 3 + wins;

  factory NemesisRival.fromJson(Map<String, dynamic> json) {
    return NemesisRival(
      hasRival: json['has_rival'] == true,
      rivalId: json['rival_id']?.toString(),
      rivalUsername: json['rival_username']?.toString(),
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      online: json['online'] == true,
      level: (json['level'] as num?)?.toInt() ?? 1,
      power: (json['power'] as num?)?.toInt() ?? 0,
      pvpRating: (json['pvp_rating'] as num?)?.toInt() ?? 1000,
      leaderboardGap: (json['leaderboard_gap'] as num?)?.toInt() ?? 0,
      dismissed: json['dismissed'] == true,
      lastMatchAt: json['last_match_at'] == null
          ? null
          : DateTime.tryParse(json['last_match_at'].toString()),
    );
  }

  static const NemesisRival none = NemesisRival(hasRival: false);
}
