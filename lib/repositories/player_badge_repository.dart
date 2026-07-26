import '../core/services/supabase_service.dart';
import '../models/player_badge_model.dart';

class PlayerBadgeRepository {
  Future<List<PlayerBadge>> fetchBadges() async {
    final dynamic raw = await SupabaseService.client.rpc('get_player_badges');
    if (raw is! Map) return const <PlayerBadge>[];
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    if (map['success'] != true) return const <PlayerBadge>[];
    final dynamic items = map['items'];
    if (items is! List) return const <PlayerBadge>[];
    return items
        .whereType<Map>()
        .map(
          (Map row) => PlayerBadge.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((PlayerBadge b) => b.itemId.isNotEmpty)
        .toList(growable: false);
  }
}
