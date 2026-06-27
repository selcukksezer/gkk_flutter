import '../core/services/supabase_service.dart';
import '../models/daily_reward_model.dart';

class DailyRewardRepository {
  final _client = SupabaseService.client;

  Future<DailyRewardStatus?> getStatus() async {
    final response = await _client.rpc('get_daily_reward_status');
    final Map<String, dynamic> data = Map<String, dynamic>.from(response as Map);
    if (data['success'] != true) {
      throw Exception(data['error'] as String? ?? 'Günlük ödül durumu alınamadı.');
    }
    return DailyRewardStatus.fromJson(data);
  }

  Future<DailyRewardClaimResult> claim() async {
    final response = await _client.rpc('claim_daily_reward');
    return DailyRewardClaimResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }
}
