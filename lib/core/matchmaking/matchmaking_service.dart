import '../services/supabase_service.dart';
import 'matchmaking_offer.dart';

/// Unified server-authoritative opponent discovery (Arena + Duel).
class MatchmakingService {
  const MatchmakingService();

  static const String modeArena = 'arena';
  static const String modeDuel = 'duel';

  Future<MatchmakingOffersResult> fetchOffers(String mode) async {
    final String rpc = mode == modeArena
        ? 'get_arena_opponent_offers'
        : 'get_pvp_opponent_offers';
    final dynamic res = await SupabaseService.client.rpc(rpc);
    if (res is! Map) {
      return MatchmakingOffersResult.empty;
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(res);
    if (map['success'] == false) {
      throw MatchmakingException(
        map['error']?.toString() ?? 'Rakip listesi alınamadı.',
      );
    }
    return MatchmakingOffersResult.fromJson(map);
  }
}

class MatchmakingException implements Exception {
  const MatchmakingException(this.message);
  final String message;
  @override
  String toString() => message;
}
