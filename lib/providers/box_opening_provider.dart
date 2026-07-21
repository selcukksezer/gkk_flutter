import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';

/// Aktif kutu açılma kaydı.
class BoxOpening {
  const BoxOpening({
    required this.openingId,
    required this.inventoryRowId,
    required this.boxId,
    required this.boxName,
    required this.opensAt,
    required this.payment,
  });

  final String openingId;
  final String inventoryRowId;
  final String boxId;
  final String boxName;
  final DateTime opensAt;
  final String payment;

  bool get isReady => !DateTime.now().toUtc().isBefore(opensAt.toUtc());

  factory BoxOpening.fromJson(Map<String, dynamic> json) {
    return BoxOpening(
      openingId: (json['opening_id'] ?? '').toString(),
      inventoryRowId: (json['inventory_row_id'] ?? '').toString(),
      boxId: (json['box_id'] ?? '').toString(),
      boxName: (json['box_name'] ?? json['box_id'] ?? 'Kutu').toString(),
      opensAt:
          DateTime.tryParse((json['opens_at'] ?? '').toString())?.toUtc() ??
              DateTime.now().toUtc(),
      payment: (json['payment'] ?? 'gems').toString(),
    );
  }
}

/// Kutu açma işlem sonucu (start/claim/cancel).
class BoxOpeningActionResult {
  const BoxOpeningActionResult({
    required this.success,
    this.error,
    this.openingId,
    this.rewardName,
    this.rewardQuantity = 0,
  });

  final bool success;
  final String? error;
  final String? openingId;
  final String? rewardName;
  final int rewardQuantity;
}

List<dynamic> _parseBoxOpeningRows(dynamic res) {
  if (res is List) return res;
  if (res is String) {
    final dynamic decoded = jsonDecode(res);
    if (decoded is List) return decoded;
    if (decoded is Map) return <dynamic>[decoded];
    return const <dynamic>[];
  }
  if (res is Map) {
    if (res['data'] is List) return res['data'] as List;
    if (res.containsKey('opening_id')) return <dynamic>[res];
  }
  return const <dynamic>[];
}

String _mapBoxError(String? raw) {
  final String msg = (raw ?? '').toLowerCase();
  if (msg.contains('already') || msg.contains('zaten')) {
    return 'Zaten bir kutu açılıyor.';
  }
  if (msg.contains('açılma kaydı bulunamadı') ||
      msg.contains('opening record')) {
    return 'Açılma kaydı bulunamadı.';
  }
  if (msg.contains('envanterde yok') || msg.contains('ödül iptal')) {
    return 'Kutu envanterde yok — ödül iptal.';
  }
  if (msg.contains('inventory_full') ||
      msg.contains('envanterin dolu') ||
      msg.contains('envanter dolu')) {
    return 'Envanter dolu.';
  }
  if (msg.contains('not ready') || msg.contains('henüz')) {
    return 'Kutu henüz açılmadı.';
  }
  return raw ?? 'İşlem başarısız.';
}

class BoxOpeningNotifier extends Notifier<List<BoxOpening>> {
  @override
  List<BoxOpening> build() => const <BoxOpening>[];

  Future<void> load() async {
    try {
      final dynamic res =
          await SupabaseService.client.rpc('get_box_openings');
      final List<dynamic> rows = _parseBoxOpeningRows(res);
      state = rows
          .whereType<Map>()
          .map((Map e) => BoxOpening.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (_) {
      // Sessiz geç — envanter ekranı yeniden deneyecek.
    }
  }

  BoxOpening? openingForRow(String rowId) {
    for (final BoxOpening o in state) {
      if (o.inventoryRowId == rowId) return o;
    }
    return null;
  }

  Future<BoxOpeningActionResult> start({
    required String rowId,
    required String payment,
  }) async {
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'start_box_opening',
        params: <String, dynamic>{
          'p_row_id': rowId,
          'p_payment': payment,
        },
      );
      final bool ok = res is Map && res['success'] == true;
      if (!ok) {
        final String? err = res is Map
            ? (res['error'] ?? res['message'])?.toString()
            : null;
        return BoxOpeningActionResult(
          success: false,
          error: _mapBoxError(err),
        );
      }
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(res);
      final String? openingId =
          (data['opening_id'] ?? data['openingId'])?.toString();
      await load();
      return BoxOpeningActionResult(success: true, openingId: openingId);
    } catch (_) {
      return const BoxOpeningActionResult(
          success: false, error: 'Kutu açma başlatılamadı.');
    }
  }

  Future<BoxOpeningActionResult> claim(String openingId) async {
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'claim_box_reward',
        params: <String, dynamic>{'p_opening_id': openingId},
      );
      final bool ok = res is Map && res['success'] == true;
      if (!ok) {
        final String? msg = res is Map
            ? (res['message'] ?? res['error'])?.toString()
            : null;
        await load();
        return BoxOpeningActionResult(success: false, error: _mapBoxError(msg));
      }
      final Map<String, dynamic>? reward =
          res['reward'] is Map ? Map<String, dynamic>.from(res['reward'] as Map) : null;
      await load();
      return BoxOpeningActionResult(
        success: true,
        rewardName: reward?['name']?.toString(),
        rewardQuantity: (reward?['quantity'] as num?)?.toInt() ?? 1,
      );
    } catch (e) {
      return BoxOpeningActionResult(
          success: false, error: _mapBoxError(e.toString()));
    }
  }

  Future<BoxOpeningActionResult> cancel(String openingId) async {
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'cancel_box_opening',
        params: <String, dynamic>{'p_opening_id': openingId},
      );
      final bool ok = res is Map && res['success'] == true;
      if (!ok) {
        final String? err = res is Map
            ? (res['error'] ?? res['message'])?.toString()
            : null;
        await load();
        return BoxOpeningActionResult(
          success: false,
          error: _mapBoxError(err),
        );
      }
      await load();
      return const BoxOpeningActionResult(success: true);
    } catch (_) {
      return const BoxOpeningActionResult(
          success: false, error: 'Kutu silinemedi.');
    }
  }
}

final NotifierProvider<BoxOpeningNotifier, List<BoxOpening>>
    boxOpeningProvider =
    NotifierProvider<BoxOpeningNotifier, List<BoxOpening>>(
        BoxOpeningNotifier.new);
