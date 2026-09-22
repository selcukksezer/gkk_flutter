import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/auth_model.dart';

void main() {
  test('AuthResponse fromJson/toJson works', () {
    final Map<String, dynamic> payload = <String, dynamic>{
      'session': <String, dynamic>{
        'access_token': 'acc',
        'refresh_token': 'ref',
        'expires_at': 123,
      },
      'user': <String, dynamic>{
        'id': 'u1',
        'username': 'selcuk',
        'email': 'x@y.z',
        'level': 1,
        'gold': 100,
        'gems': 5,
        'energy': 50,
        'max_energy': 100,
        'attack': 10,
        'defense': 8,
        'health': 90,
        'max_health': 100,
        'power': 20,
        'guild_id': null,
        'guild_role': null,
      },
    };

    final AuthResponse parsed = AuthResponse.fromJson(payload);
    expect(parsed.user.username, 'selcuk');
    expect(parsed.session?.expiresAt, 123);
    expect(parsed.hasSession, isTrue);
    expect(parsed.toJson()['user'], payload['user']);
    expect(parsed.toJson()['session'], payload['session']);
  });

  test('AuthResponse supports email-confirmation without session', () {
    final AuthResponse parsed = AuthResponse.fromJson(<String, dynamic>{
      'user': <String, dynamic>{
        'id': 'u1',
        'username': 'selcuk',
        'email': 'x@y.z',
        'level': 1,
        'gold': 0,
        'gems': 0,
        'energy': 50,
        'max_energy': 100,
        'attack': 0,
        'defense': 0,
        'health': 90,
        'max_health': 100,
        'power': 0,
        'guild_id': null,
        'guild_role': null,
      },
      'requires_email_confirmation': true,
    });
    expect(parsed.hasSession, isFalse);
    expect(parsed.requiresEmailConfirmation, isTrue);
  });
}

