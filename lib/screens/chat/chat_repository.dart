import '../../core/services/supabase_service.dart';

/// Thin Supabase RPC wrapper for chat operations.
class ChatRepository {
  ChatRepository._();

  static Future<dynamic> rpc(String fn, {Map<String, dynamic>? params}) {
    return SupabaseService.client.rpc(fn, params: params);
  }
}
