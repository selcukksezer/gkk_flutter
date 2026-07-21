import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/user_facing_error.dart';
import '../core/services/supabase_service.dart';
import '../models/mekan_model.dart';
import 'mekan_provider.dart';

class MekanDetailState {
  const MekanDetailState({
    required this.mekan,
    this.stock = const <MekanStockEntry>[],
    this.presence = const <Map<String, dynamic>>[],
  });

  final Mekan? mekan;
  final List<MekanStockEntry> stock;
  final List<Map<String, dynamic>> presence;

  bool get isNotFound => mekan == null;
}

Future<List<Map<String, dynamic>>> _fetchPresence(String mekanId) async {
  try {
    final dynamic res = await SupabaseService.client.rpc(
      'get_mekan_presence',
      params: <String, dynamic>{'p_mekan_id': mekanId},
    );
    if (res is List) {
      return res
          .whereType<Map>()
          .map((Map e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
  } catch (_) {
    // presence yüklenemezse bölüm gizli kalır
  }
  return const <Map<String, dynamic>>[];
}

Future<MekanDetailState> _loadMekanDetail(Ref ref, String mekanId) async {
  final MekanRepository repo = ref.read(mekanRepositoryProvider);
  final Mekan? mekan = await repo.fetchMekan(mekanId);
  final List<MekanStockEntry> stock =
      mekan == null ? <MekanStockEntry>[] : await repo.fetchStock(mekanId, onlyAvailable: true);
  final List<Map<String, dynamic>> presence = await _fetchPresence(mekanId);
  return MekanDetailState(mekan: mekan, stock: stock, presence: presence);
}

final mekanDetailProvider = FutureProvider.autoDispose.family<MekanDetailState, String>(
  (Ref ref, String mekanId) async {
    try {
      return await _loadMekanDetail(ref, mekanId);
    } catch (e) {
      throw userFacingErrorMessage(e, fallback: 'Mekan yüklenemedi.');
    }
  },
);

void invalidateMekanDetail(WidgetRef ref, String mekanId) {
  ref.invalidate(mekanDetailProvider(mekanId));
}
