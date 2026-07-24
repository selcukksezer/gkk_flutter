import '../core/services/supabase_service.dart';
import '../models/comeback_summary_model.dart';

class ComebackSummaryRepository {
  final _client = SupabaseService.client;

  Future<ComebackSummary?> fetchSummary() async {
    final dynamic response = await _client.rpc('get_comeback_summary');
    final Map<String, dynamic> data = Map<String, dynamic>.from(response as Map);
    if (data['success'] != true) {
      throw Exception(data['error'] as String? ?? 'Geri dönüş özeti alınamadı.');
    }
    return ComebackSummary.fromJson(data);
  }

  Future<void> markSeen() async {
    await _client.rpc('mark_comeback_summary_seen');
  }
}
