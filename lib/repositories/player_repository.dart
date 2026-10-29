import '../core/errors/app_exception.dart';
import '../core/services/supabase_service.dart';
import '../models/player_model.dart';

abstract class PlayerRepository {
  Future<PlayerProfile> loadCurrentPlayer();
}

class SupabasePlayerRepository implements PlayerRepository {
  @override
  Future<PlayerProfile> loadCurrentPlayer() async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) {
      throw AppException('Aktif kullanici bulunamadi.', code: 'AUTH_REQUIRED');
    }

    try {
      // Passiveive regen: empty → max_energy over 24h (server-side).
      try {
        await SupabaseService.client.rpc('apply_energy_regen');
      } catch (_) {
        // Presence heartbeat also applies regen; profile load still works.
      }
      try {
        await SupabaseService.client.rpc('apply_health_regen');
      } catch (_) {
        // Same as energy — optional until migration applied.
      }

      final response = await SupabaseService.client
          .from('users')
          .select()
          .eq('auth_id', currentUser.id)
          .single();

      final json = Map<String, dynamic>.from(response as Map);
      return PlayerProfile.fromJson(json);
    } catch (_) {
      throw AppException('Oyuncu profili yüklenemedi.', code: 'PLAYER_LOAD_FAILED');
    }
  }
}
