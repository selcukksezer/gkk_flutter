import '../core/services/supabase_service.dart';
import '../models/enhancement_config_model.dart';

class EnhancementRepository {
  const EnhancementRepository();

  Future<EnhancementConfig> fetchConfig() async {
    try {
      final dynamic raw = await SupabaseService.client.rpc('get_enhancement_config');
      if (raw is Map<String, dynamic>) {
        return EnhancementConfig.fromRpc(raw);
      }
      if (raw is Map) {
        return EnhancementConfig.fromRpc(Map<String, dynamic>.from(raw));
      }
    } catch (_) {
      // Offline / migration not applied yet → fallback.
    }
    return EnhancementConfig.fallback;
  }
}

const EnhancementRepository enhancementRepository = EnhancementRepository();
