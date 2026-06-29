import 'package:flutter/foundation.dart';

import 'app_exception.dart';

/// Maps thrown values to short Turkish copy safe for players.
String userFacingErrorMessage(
  Object error, {
  String fallback = 'İşlem tamamlanamadı.',
}) {
  if (kDebugMode) {
    debugPrint('UserFacingError: $error');
  }

  if (error is AppException) {
    return error.message;
  }

  final String raw = _extractMessage(error);
  if (raw.isEmpty) return fallback;

  final String lower = raw.toLowerCase();

  if (lower.contains('insufficient_energy') ||
      (lower.contains('energy') && lower.contains('insufficient'))) {
    return 'Enerji yetersiz.';
  }
  if (lower.contains('in_hospital')) {
    return 'Hastanedeyken bu işlem yapılamaz.';
  }
  if (lower.contains('in_prison')) {
    return 'Hapisteyken bu işlem yapılamaz.';
  }
  if (lower.contains('boss_daily_limit')) {
    return 'Boss günlük deneme limitine ulaştın.';
  }
  if (lower.contains('jwt expired') || lower.contains('invalid jwt')) {
    return 'Oturum süresi doldu. Tekrar giriş yap.';
  }
  if (lower.contains('row-level security') || lower.contains('rls policy')) {
    return 'Bu işlem için yetkin yok.';
  }
  if (lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('connection refused') ||
      lower.contains('failed host lookup')) {
    return 'Bağlantı hatası. İnternetini kontrol et.';
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'İstek zaman aşımına uğradı.';
  }

  if (_looksUserFriendly(raw)) return raw.trim();

  return fallback;
}

String _extractMessage(Object error) {
  if (error is AppException) return error.message;

  final dynamic dynamicError = error;
  if (dynamicError is Exception) {
    final Object? message = _readMessageProperty(dynamicError);
    if (message != null && message.toString().trim().isNotEmpty) {
      return message.toString();
    }
  }

  final String text = error.toString();
  if (text.startsWith('Exception: ')) return text.substring(11);
  if (text.startsWith('AppException: ')) return text.substring(14);

  final RegExpMatch? coded = RegExp(r'^AppException\([^)]*\): (.+)$').firstMatch(text);
  if (coded != null) return coded.group(1)!;

  return text;
}

Object? _readMessageProperty(Object error) {
  try {
    return (error as dynamic).message;
  } catch (_) {
    return null;
  }
}

bool _looksUserFriendly(String raw) {
  if (raw.length > 120) return false;

  final String lower = raw.toLowerCase();
  const technical = <String>[
    'postgrest',
    'postgres',
    'exception',
    'stack trace',
    'pgrst',
    'sqlstate',
    '42703',
    '23505',
    '23503',
    'permission denied',
    'schema cache',
  ];

  for (final String token in technical) {
    if (lower.contains(token)) return false;
  }

  return true;
}
