import '../models/item_model.dart';

class PlayerBadge {
  const PlayerBadge({
    required this.itemId,
    required this.name,
    required this.rarity,
    required this.icon,
    required this.source,
    required this.earnedAt,
  });

  final String itemId;
  final String name;
  final Rarity rarity;
  final String icon;
  final String source;
  final DateTime earnedAt;

  factory PlayerBadge.fromJson(Map<String, dynamic> json) {
    DateTime earnedAt = DateTime.now();
    final dynamic rawAt = json['earned_at'];
    if (rawAt is String && rawAt.isNotEmpty) {
      earnedAt = DateTime.tryParse(rawAt)?.toLocal() ?? earnedAt;
    }
    return PlayerBadge(
      itemId: (json['item_id'] ?? '').toString(),
      name: (json['name'] ?? json['item_id'] ?? 'Rozet').toString(),
      rarity: RarityParsing.fromValue((json['rarity'] ?? 'epic').toString()),
      icon: (json['icon'] ?? '🏅').toString(),
      source: (json['source'] ?? 'grant').toString(),
      earnedAt: earnedAt,
    );
  }
}
