/// Turkish labels for staff audit log entries (dashboard, audit tab, player history).
class StaffAuditLabels {
  StaffAuditLabels._();

  static String formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    final DateTime local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static String formatUntil(dynamic raw) {
    if (raw == null) return 'Kalıcı';
    final DateTime? dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return raw.toString();
    return formatDateTime(dt);
  }

  static String restrictionLabel(String? key) {
    switch (key) {
      case 'chat':
        return 'Chat susturma';
      case 'hospital':
        return 'Hastane';
      case 'prison':
        return 'Hapishane';
      case 'trade':
        return 'Ticaret yasağı';
      case 'account_ban':
        return 'Hesap banı';
      default:
        return key == null || key.isEmpty ? 'Kısıt' : key;
    }
  }

  static String targetTypeLabel(String? type) {
    switch (type) {
      case 'user':
        return 'Oyuncu';
      case 'ticket':
        return 'Destek talebi';
      case 'bug_report':
        return 'Bug raporu';
      case 'chat_report':
        return 'Chat raporu';
      case 'market_order':
        return 'Pazar ilanı';
      case 'item':
        return 'Mağaza eşyası';
      case 'bp_season':
        return 'BP sezonu';
      case 'guild_war_season':
        return 'Lonca savaşı sezonu';
      case 'daily_reward_config':
      case 'daily_reward':
        return 'Günlük ödül';
      case 'night_market':
        return 'Gece pazarı';
      case 'staff_broadcast':
        return 'Duyuru';
      default:
        return type == null || type.isEmpty ? 'Hedef' : type;
    }
  }

  static String currencyLabel(String? currency) {
    switch (currency) {
      case 'gold':
        return 'Altın';
      case 'gems':
        return 'Elmas';
      default:
        return currency == null || currency.isEmpty ? 'Para' : currency;
    }
  }

  static String actionTitle(String action, {Map<String, dynamic>? payload}) {
    final Map<String, dynamic> p = payload ?? const <String, dynamic>{};
    switch (action) {
      case 'set_restriction':
        return '${restrictionLabel(p['restriction']?.toString())} uygulandı';
      case 'clear_restriction':
        return '${restrictionLabel(p['restriction']?.toString())} kaldırıldı';
      case 'adjust_inventory':
        final String item = p['item_id']?.toString() ?? 'eşya';
        final dynamic delta = p['delta'];
        final String sign = delta is num && delta > 0 ? '+' : '';
        return 'Envanter düzenlendi · $item ($sign${delta ?? '?'})';
      case 'grant_currency':
        return '${currencyLabel(p['currency']?.toString())} verildi · ${p['amount'] ?? '?'}';
      case 'ban_player':
        return 'Hesap banlandı';
      case 'unban_player':
        return 'Ban kaldırıldı';
      case 'rename_player':
        return 'İsim değiştirildi · ${p['display_name'] ?? '?'}';
      case 'reply_ticket':
        return 'Destek talebine yanıt verildi';
      case 'assign_ticket':
        return 'Destek talebi atandı';
      case 'update_ticket_status':
        return 'Destek talebi durumu güncellendi';
      case 'suggest_reward':
        return 'Bug ödülü önerildi';
      case 'approve_bug':
        return 'Bug ödülü onaylandı';
      case 'update_bug':
        return 'Bug raporu güncellendi';
      case 'resolve_report':
        return 'Chat raporu sonuçlandırıldı';
      case 'chat_mute_with_delete':
        return 'Chat mesajı silindi + susturma';
      case 'edit_listing':
        return 'Pazar ilanı düzenlendi';
      case 'remove_listing':
        return 'Pazar ilanı kaldırıldı';
      case 'update_shop_item':
        return 'Mağaza eşyası güncellendi';
      case 'assign_gm':
        return 'GM yetkisi verildi';
      case 'revoke_gm':
        return 'GM yetkisi alındı';
      case 'set_permissions':
        return 'GM izinleri güncellendi';
      case 'rotate_bp':
        return 'BP sezonu döndürüldü';
      case 'rotate_gw':
        return 'Lonca savaşı sezonu döndürüldü';
      case 'upsert_daily':
        return 'Günlük ödül ayarlandı';
      case 'upsert_bp_reward':
        return 'BP ödülü ayarlandı';
      case 'upsert_night_market':
        return 'Gece pazarı teklifi ayarlandı';
      case 'delete_night_market':
        return 'Gece pazarı teklifi silindi';
      case 'create_broadcast':
        return 'Canlı duyuru oluşturuldu';
      default:
        if (action.isEmpty) return 'Staff işlemi';
        return 'Staff işlemi · ${action.replaceAll('_', ' ')}';
    }
  }

  /// Audit tab işlem filtresi seçenekleri (action key → kısa etiket).
  static const List<String?> auditActionFilterKeys = <String?>[
    null,
    'ban_player',
    'unban_player',
    'set_restriction',
    'clear_restriction',
    'assign_gm',
    'revoke_gm',
    'set_permissions',
    'reply_ticket',
    'assign_ticket',
    'update_bug',
    'approve_bug',
    'suggest_reward',
    'resolve_report',
    'chat_mute_with_delete',
    'adjust_inventory',
    'grant_currency',
    'rename_player',
    'edit_listing',
    'remove_listing',
    'create_broadcast',
    'upsert_daily',
    'upsert_bp_reward',
    'upsert_night_market',
    'delete_night_market',
    'rotate_bp',
    'rotate_gw',
  ];

  static String auditActionFilterLabel(String? action) {
    if (action == null) return 'İşlem: tümü';
    return actionTitle(action);
  }

  static String buildSubtitle({
    String? actorUsername,
    String? actorRole,
    String? targetType,
    String? targetId,
    String? targetUsername,
    DateTime? createdAt,
    Map<String, dynamic>? payload,
  }) {
    final List<String> parts = <String>[];
    if (actorUsername != null && actorUsername.isNotEmpty) {
      final String role = actorRole == 'admin'
          ? 'Admin'
          : actorRole == 'gm'
              ? 'GM'
              : '';
      parts.add(role.isEmpty ? '@$actorUsername' : '$role @$actorUsername');
    }
    if (targetUsername != null && targetUsername.isNotEmpty) {
      parts.add('→ @$targetUsername');
    } else if (targetType != null && targetType.isNotEmpty) {
      parts.add(targetTypeLabel(targetType));
    }
    final String? hint = _payloadHint(payload);
    if (hint != null) parts.add(hint);
    final String when = formatDateTime(createdAt);
    if (when.isNotEmpty) parts.add(when);
    return parts.isEmpty ? 'Staff işlemi' : parts.join(' · ');
  }

  static String? _payloadHint(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) return null;
    final dynamic reason = payload['reason'] ?? payload['note'];
    if (reason == null) return null;
    final String text = reason.toString().trim();
    if (text.isEmpty) return null;
    return text.length > 36 ? '${text.substring(0, 36)}…' : text;
  }

  static List<String> detailLines({
    required String action,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? result,
    String? targetType,
    String? targetId,
    String? permissionKey,
  }) {
    final List<String> lines = <String>[];
    final Map<String, dynamic> p = payload ?? const <String, dynamic>{};

    if (permissionKey != null && permissionKey.isNotEmpty) {
      lines.add('Yetki: $permissionKey');
    }
    if (targetType != null && targetType.isNotEmpty) {
      final String idSuffix = targetId != null && targetId.isNotEmpty ? ' · $targetId' : '';
      lines.add('Hedef: ${targetTypeLabel(targetType)}$idSuffix');
    }

    if (action == 'set_restriction' || action == 'clear_restriction') {
      lines.add('Kısıt türü: ${restrictionLabel(p['restriction']?.toString())}');
      if (action == 'set_restriction' || p['until'] != null) {
        lines.add('Süre: ${formatUntil(p['until'])}');
      }
      if (p['reason'] != null && p['reason'].toString().trim().isNotEmpty) {
        lines.add('Sebep: ${p['reason']}');
      }
      if (p['note'] != null && p['note'].toString().trim().isNotEmpty) {
        lines.add('Not: ${p['note']}');
      }
    } else if (action == 'adjust_inventory') {
      lines.add('Eşya: ${p['item_id'] ?? '?'}');
      lines.add('Değişim: ${p['delta'] ?? '?'}');
      if (p['reason'] != null) lines.add('Sebep: ${p['reason']}');
    } else if (action == 'grant_currency') {
      lines.add('Para birimi: ${currencyLabel(p['currency']?.toString())}');
      lines.add('Miktar: ${p['amount'] ?? '?'}');
      if (p['reason'] != null) lines.add('Sebep: ${p['reason']}');
    } else if (action == 'ban_player') {
      if (p['reason'] != null) lines.add('Sebep: ${p['reason']}');
      lines.add('Süre: ${formatUntil(p['until'] ?? p['banned_until'])}');
    } else if (action == 'unban_player') {
      if (p['note'] != null && p['note'].toString().trim().isNotEmpty) {
        lines.add('Not: ${p['note']}');
      }
    } else if (action == 'rename_player') {
      lines.add('Yeni isim: ${p['display_name'] ?? '?'}');
      if (p['reason'] != null) lines.add('Sebep: ${p['reason']}');
    } else if (action == 'resolve_report') {
      if (p['action'] != null) lines.add('Karar: ${_resolveActionLabel(p['action']?.toString())}');
      if (p['note'] != null) lines.add('Not: ${p['note']}');
    } else if (action == 'update_ticket_status') {
      if (p['status'] != null) lines.add('Yeni durum: ${_ticketStatusLabel(p['status']?.toString())}');
    } else if (action == 'suggest_reward' || action == 'approve_bug') {
      if (p['reward_gems'] != null) lines.add('Önerilen ödül: ${p['reward_gems']} elmas');
      if (p['status'] != null) lines.add('Durum: ${p['status']}');
    } else if (p.isNotEmpty) {
      for (final MapEntry<String, dynamic> entry in p.entries) {
        if (entry.value == null) continue;
        lines.add('${_fieldLabel(entry.key)}: ${entry.value}');
      }
    }

    if (result != null && result.isNotEmpty && result['success'] == false) {
      lines.add('Sonuç: ${result['error'] ?? 'başarısız'}');
    }

    return lines;
  }

  static String _resolveActionLabel(String? action) {
    switch (action) {
      case 'reviewed':
        return 'İncelendi';
      case 'action_taken':
        return 'İşlem uygulandı';
      case 'dismissed':
        return 'Reddedildi';
      default:
        return action ?? '?';
    }
  }

  static String _ticketStatusLabel(String? status) {
    switch (status) {
      case 'open':
        return 'Açık';
      case 'waiting_player':
        return 'Oyuncu bekleniyor';
      case 'staff_reply':
        return 'Staff yanıtı';
      case 'resolved':
        return 'Çözüldü';
      case 'closed':
        return 'Kapatıldı';
      default:
        return status ?? '?';
    }
  }

  static String _fieldLabel(String key) {
    const Map<String, String> labels = <String, String>{
      'reason': 'Sebep',
      'note': 'Not',
      'status': 'Durum',
      'action': 'Karar',
      'amount': 'Miktar',
      'delta': 'Değişim',
      'item_id': 'Eşya',
      'currency': 'Para birimi',
      'display_name': 'İsim',
      'restriction': 'Kısıt',
      'until': 'Bitiş',
      'reward_gems': 'Elmas ödülü',
    };
    return labels[key] ?? key;
  }

  /// One-line summary for player enforcement history cards.
  static String historyLine(Map<String, dynamic> row) {
    final String action = row['action']?.toString() ?? '';
    final Map<String, dynamic> payload = row['payload'] is Map
        ? Map<String, dynamic>.from(row['payload'] as Map)
        : <String, dynamic>{};
    return actionTitle(action, payload: payload);
  }
}
