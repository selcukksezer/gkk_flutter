/// Server-issued opponent offer for Arena / PvP duel discovery.
class MatchmakingOffer {
  const MatchmakingOffer({
    required this.offerId,
    required this.authId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.level,
    required this.power,
    required this.pvpRating,
    this.attack = 0,
    this.defense = 0,
    this.expiresAt,
  });

  final String offerId;
  final String authId;
  final String username;
  final String displayName;
  final String avatarUrl;
  final int level;
  final int power;
  final int pvpRating;
  final int attack;
  final int defense;
  final DateTime? expiresAt;

  factory MatchmakingOffer.fromJson(Map<String, dynamic> json) {
    final String username = (json['username'] ?? '?').toString();
    final String display = (json['display_name'] ?? '').toString();
    final int attack = (json['attack'] as num?)?.toInt() ?? 0;
    final int defense = (json['defense'] as num?)?.toInt() ?? 0;
    final int powerFromFields = attack + defense;
    final int power = (json['power'] as num?)?.toInt() ?? powerFromFields;
    return MatchmakingOffer(
      offerId: (json['offer_id'] ?? '').toString(),
      authId: (json['auth_id'] ?? '').toString(),
      username: username,
      displayName: display.isNotEmpty ? display : username,
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      power: power,
      pvpRating: (json['pvp_rating'] as num?)?.toInt() ?? 1000,
      attack: attack,
      defense: defense,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse(json['expires_at'].toString()),
    );
  }
}

class MatchmakingOffersResult {
  const MatchmakingOffersResult({
    required this.offers,
    required this.refreshCooldownSec,
    required this.canRefresh,
    required this.refreshInSec,
    this.nextRefreshAt,
    this.bandTierUsed,
    this.error,
  });

  final List<MatchmakingOffer> offers;
  final int refreshCooldownSec;
  final bool canRefresh;
  final int refreshInSec;
  final DateTime? nextRefreshAt;
  final int? bandTierUsed;
  final String? error;

  factory MatchmakingOffersResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['offers'] as List?) ??
        (json['opponents'] as List?) ??
        const <dynamic>[];
    return MatchmakingOffersResult(
      offers: raw
          .whereType<Map>()
          .map(
            (Map e) => MatchmakingOffer.fromJson(Map<String, dynamic>.from(e)),
          )
          .where((MatchmakingOffer o) => o.offerId.isNotEmpty && o.authId.isNotEmpty)
          .toList(growable: false),
      refreshCooldownSec: (json['refresh_cooldown_sec'] as num?)?.toInt() ?? 45,
      canRefresh: json['can_refresh'] == true,
      refreshInSec: (json['refresh_in_sec'] as num?)?.toInt() ?? 0,
      nextRefreshAt: json['next_refresh_at'] == null
          ? null
          : DateTime.tryParse(json['next_refresh_at'].toString()),
      bandTierUsed: (json['band_tier_used'] as num?)?.toInt(),
      error: json['error']?.toString(),
    );
  }

  static const MatchmakingOffersResult empty = MatchmakingOffersResult(
    offers: <MatchmakingOffer>[],
    refreshCooldownSec: 45,
    canRefresh: true,
    refreshInSec: 0,
  );
}
