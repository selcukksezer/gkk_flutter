import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';

/// Maps Supabase [AuthException] (+ common strings) → TR [AppException].
abstract final class AuthErrorMapper {
  static AppException fromAuthException(AuthException e) {
    final String code = (e.code ?? '').toLowerCase();
    final String message = e.message.toLowerCase();
    final String mapped = _map(
      code: code,
      message: message,
      fallback: e.message,
    );
    return AppException(mapped, code: e.code ?? 'AUTH_ERROR');
  }

  static AppException fromObject(Object error) {
    if (error is AppException) return error;
    if (error is AuthException) return fromAuthException(error);
    final String raw = error.toString();
    return AppException(
      _map(code: '', message: raw.toLowerCase(), fallback: raw),
      code: 'AUTH_UNEXPECTED',
    );
  }

  static String _map({
    required String code,
    required String message,
    required String fallback,
  }) {
    if (code == 'invalid_credentials' ||
        message.contains('invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      return 'E-posta henüz onaylanmadı. Gelen kutunu kontrol et.';
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        message.contains('user already registered') ||
        message.contains('already been registered')) {
      return 'Bu e-posta ile zaten bir hesap var. Giriş yap veya şifre sıfırla.';
    }
    if (code == 'username_taken' ||
        message.contains('username_taken') ||
        message.contains('users_username_key') ||
        (message.contains('duplicate key') && message.contains('username')) ||
        message.contains('username already') ||
        message.contains('already been taken')) {
      return 'Bu kullanıcı adı alınmış. Başka bir ad dene.';
    }
    if (message.contains('database error saving new user') &&
        (message.contains('username') || message.contains('23505'))) {
      return 'Bu kullanıcı adı alınmış. Başka bir ad dene.';
    }
    if (code == 'weak_password' || message.contains('weak password')) {
      return 'Şifre çok zayıf. En az 8 karakter, harf ve rakam kullan.';
    }
    if (code == 'over_request_rate_limit' ||
        message.contains('rate limit') ||
        message.contains('too many requests')) {
      return 'Çok fazla deneme. Bir süre sonra tekrar dene.';
    }
    if (code == 'user_not_found' || message.contains('user not found')) {
      return 'Bu e-posta ile hesap bulunamadı.';
    }
    if (code == 'same_password' || message.contains('same password')) {
      return 'Yeni şifre eskisiyle aynı olamaz.';
    }
    if (message.contains('network') || message.contains('socket')) {
      return 'Ağ hatası. Bağlantını kontrol edip tekrar dene.';
    }
    if (fallback.trim().isEmpty ||
        message.contains('authapiexception') ||
        message.contains('exception:')) {
      return 'Kimlik doğrulama başarısız. Bilgilerini kontrol edip tekrar dene.';
    }
    return fallback;
  }
}
