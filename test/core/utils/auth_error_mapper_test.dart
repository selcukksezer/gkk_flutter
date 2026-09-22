import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/utils/auth_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps invalid credentials', () {
    final mapped = AuthErrorMapper.fromAuthException(
      const AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      ),
    );
    expect(mapped.message, contains('E-posta veya şifre'));
  });

  test('maps already registered', () {
    final mapped = AuthErrorMapper.fromAuthException(
      const AuthException(
        'User already registered',
        code: 'user_already_exists',
      ),
    );
    expect(mapped.message, contains('zaten'));
  });

  test('maps username taken', () {
    final mapped = AuthErrorMapper.fromObject(
      Exception('USERNAME_TAKEN'),
    );
    expect(mapped.message, contains('kullanıcı adı'));
  });

  test('maps users_username_key', () {
    final mapped = AuthErrorMapper.fromObject(
      Exception('duplicate key value violates unique constraint users_username_key'),
    );
    expect(mapped.message, contains('kullanıcı adı'));
  });
}
