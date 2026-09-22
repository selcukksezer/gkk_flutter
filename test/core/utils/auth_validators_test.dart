import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/utils/auth_validators.dart';
import 'package:gkk_flutter/l10n/app_localizations_en.dart';

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();

  test('username rejects short / invalid charset', () {
    expect(AuthValidators.validateUsername('ab', l10n), isNotNull);
    expect(AuthValidators.validateUsername('bad name!', l10n), isNotNull);
    expect(AuthValidators.validateUsername('good_user1', l10n), isNull);
  });

  test('password strength requires 8 + letter + digit', () {
    expect(AuthValidators.validatePassword('short1', l10n), isNotNull);
    expect(AuthValidators.validatePassword('longpassword', l10n), isNotNull);
    expect(AuthValidators.validatePassword('12345678', l10n), isNotNull);
    expect(AuthValidators.validatePassword('Abcdef12', l10n), isNull);
  });

  test('login password only requires non-empty', () {
    expect(AuthValidators.validatePasswordLogin('', l10n), isNotNull);
    expect(AuthValidators.validatePasswordLogin('x', l10n), isNull);
  });
}
