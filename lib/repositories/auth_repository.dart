import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthResponse, AuthUser;

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/services/device_identity_service.dart';
import '../core/services/device_session_service.dart';
import '../core/services/presence_service.dart';
import '../core/services/supabase_service.dart';
import '../core/utils/auth_error_mapper.dart';
import '../models/auth_model.dart';
import '../models/referral_preview_model.dart';

abstract class AuthRepository {
  Future<AuthSession?> currentSession();
  Future<AuthResponse> login(LoginRequest request);
  Future<AuthResponse> register(RegisterRequest request);
  Future<AuthResponse> signInWithApple({required String deviceId});
  Future<void> logout();
  Future<void> requestPasswordReset(String email);
  Future<void> updatePassword(String newPassword);
  Future<void> resendSignupConfirmation(String email);
  Future<AuthUser?> fetchProfileUser(String authId);
  Future<bool> isUsernameAvailable(String username);
  Future<ReferralPreview> validateReferralCode(String code);
  Future<bool> isAppleSignInAvailable();
}

class SupabaseAuthRepository implements AuthRepository {
  @override
  Future<AuthSession?> currentSession() async {
    if (!SupabaseService.isConfigured) return null;

    final session = SupabaseService.client.auth.currentSession;
    if (session == null) return null;

    return AuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
      expiresAt: session.expiresAt ?? 0,
    );
  }

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    _ensureConfigured();

    return DeviceSessionService.runAuthHandshake<AuthResponse>(() async {
      try {
        final result = await SupabaseService.client.auth.signInWithPassword(
          email: request.email,
          password: request.password,
        );

        final session = result.session;
        final user = result.user;
        if (session == null || user == null) {
          throw AppException(
            'Giris basarisiz. Oturum olusturulamadi.',
            code: 'AUTH_LOGIN_FAILED',
          );
        }

        await _enforceSingleDeviceSession(request.deviceId);

        final AuthUser fallback = _userFromAuthMetadata(user);
        final AuthUser profile =
            await fetchProfileUser(user.id) ?? fallback;

        return AuthResponse(
          session: AuthSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken ?? '',
            expiresAt: session.expiresAt ?? 0,
          ),
          user: profile,
        );
      } on AppException {
        rethrow;
      } on AuthException catch (e) {
        throw AuthErrorMapper.fromAuthException(e);
      } catch (e) {
        throw AuthErrorMapper.fromObject(e);
      }
    });
  }

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    _ensureConfigured();

    return DeviceSessionService.runAuthHandshake<AuthResponse>(() async {
      try {
        final bool available = await isUsernameAvailable(request.username);
        if (!available) {
          throw AppException(
            'Bu kullanıcı adı alınmış. Başka bir ad dene.',
            code: 'username_taken',
          );
        }

        final result = await SupabaseService.client.auth.signUp(
          email: request.email,
          password: request.password,
          emailRedirectTo: AppConstants.authRedirectUrl,
          data: <String, dynamic>{
            'username': request.username,
            if (request.referralCode != null &&
                request.referralCode!.trim().isNotEmpty)
              'referral_code': request.referralCode!.trim().toUpperCase(),
          },
        );

        final session = result.session;
        final user = result.user;
        if (user == null) {
          throw AppException(
            'Kayit basarisiz. Kullanici olusturulamadi.',
            code: 'AUTH_REGISTER_FAILED',
          );
        }

        final AuthUser fallback = AuthUser(
          id: user.id,
          username: request.username,
          email: user.email ?? request.email,
          level: 1,
          gold: 0,
          gems: 0,
          energy: 100,
          maxEnergy: 100,
          attack: 0,
          defense: 0,
          health: 100,
          maxHealth: 100,
          power: 0,
          guildId: null,
          guildRole: null,
        );

        // Email confirm on → no session. Do not fake authenticated.
        if (session == null) {
          return AuthResponse(
            user: fallback,
            requiresEmailConfirmation: true,
          );
        }

        await _enforceSingleDeviceSession(request.deviceId);

        final AuthUser profile =
            await fetchProfileUser(user.id) ?? fallback;

        return AuthResponse(
          session: AuthSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken ?? '',
            expiresAt: session.expiresAt ?? 0,
          ),
          user: profile,
        );
      } on AppException {
        rethrow;
      } on AuthException catch (e) {
        throw AuthErrorMapper.fromAuthException(e);
      } catch (e) {
        throw AuthErrorMapper.fromObject(e);
      }
    });
  }

  @override
  Future<bool> isAppleSignInAvailable() async {
    if (kIsWeb) return false;
    try {
      return await SignInWithApple.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AuthResponse> signInWithApple({required String deviceId}) async {
    _ensureConfigured();

    return DeviceSessionService.runAuthHandshake<AuthResponse>(() async {
      try {
        final bool available = await isAppleSignInAvailable();
        if (!available) {
          throw AppException(
            'Apple ile giriş bu cihazda kullanılamıyor.',
            code: 'APPLE_UNAVAILABLE',
          );
        }

        final String rawNonce = _generateNonce();
        final String hashedNonce =
            sha256.convert(utf8.encode(rawNonce)).toString();

        final AuthorizationCredentialAppleID credential =
            await SignInWithApple.getAppleIDCredential(
          scopes: <AppleIDAuthorizationScopes>[
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: hashedNonce,
        );

        final String? idToken = credential.identityToken;
        if (idToken == null || idToken.isEmpty) {
          throw AppException(
            'Apple kimlik doğrulaması başarısız.',
            code: 'APPLE_NO_TOKEN',
          );
        }

        final result = await SupabaseService.client.auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: idToken,
          nonce: rawNonce,
        );

        final session = result.session;
        final user = result.user;
        if (session == null || user == null) {
          throw AppException(
            'Apple ile giriş başarısız. Oturum oluşturulamadı.',
            code: 'APPLE_LOGIN_FAILED',
          );
        }

        // Best-effort: seed display name from Apple on first sign-in.
        final String? given = credential.givenName;
        final String? family = credential.familyName;
        if ((given != null && given.isNotEmpty) ||
            (family != null && family.isNotEmpty)) {
          final String displayName =
              <String?>[given, family].whereType<String>().join(' ').trim();
          if (displayName.isNotEmpty) {
            try {
              await SupabaseService.client.auth.updateUser(
                UserAttributes(
                  data: <String, dynamic>{'display_name': displayName},
                ),
              );
            } catch (_) {}
          }
        }

        await _enforceSingleDeviceSession(deviceId);

        final AuthUser fallback = _userFromAuthMetadata(user);
        final AuthUser profile = await fetchProfileUser(user.id) ?? fallback;

        return AuthResponse(
          session: AuthSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken ?? '',
            expiresAt: session.expiresAt ?? 0,
          ),
          user: profile,
        );
      } on AppException {
        rethrow;
      } on SignInWithAppleAuthorizationException catch (e) {
        if (e.code == AuthorizationErrorCode.canceled) {
          throw AppException('Apple girişi iptal edildi.', code: 'APPLE_CANCELED');
        }
        throw AppException(
          'Apple ile giriş başarısız.',
          code: 'APPLE_AUTH_ERROR',
        );
      } on AuthException catch (e) {
        throw AuthErrorMapper.fromAuthException(e);
      } catch (e) {
        throw AuthErrorMapper.fromObject(e);
      }
    });
  }

  @override
  Future<void> logout() async {
    if (!SupabaseService.isConfigured) return;
    await PresenceService.instance.goOfflineBeforeSignOut();
    await DeviceSessionService.clearEpoch();
    await SupabaseService.client.auth.signOut();
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    _ensureConfigured();
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: AppConstants.authRedirectUrl,
      );
    } on AuthException catch (e) {
      throw AuthErrorMapper.fromAuthException(e);
    } catch (e) {
      throw AuthErrorMapper.fromObject(e);
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    _ensureConfigured();
    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw AuthErrorMapper.fromAuthException(e);
    } catch (e) {
      throw AuthErrorMapper.fromObject(e);
    }
  }

  @override
  Future<void> resendSignupConfirmation(String email) async {
    _ensureConfigured();
    try {
      await SupabaseService.client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: AppConstants.authRedirectUrl,
      );
    } on AuthException catch (e) {
      throw AuthErrorMapper.fromAuthException(e);
    } catch (e) {
      throw AuthErrorMapper.fromObject(e);
    }
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    if (!SupabaseService.isConfigured) return true;
    try {
      final dynamic response = await SupabaseService.client.rpc(
        'check_username_available',
        params: <String, dynamic>{'p_username': username.trim()},
      );
      if (response is Map && response['available'] == true) return true;
      return false;
    } catch (_) {
      // Fail open on network — server still enforces uniqueness.
      return true;
    }
  }

  @override
  Future<ReferralPreview> validateReferralCode(String code) async {
    if (!SupabaseService.isConfigured) return ReferralPreview.empty();
    final String trimmed = code.trim();
    if (trimmed.isEmpty) return ReferralPreview.empty();
    try {
      final dynamic response = await SupabaseService.client.rpc(
        'validate_referral_code',
        params: <String, dynamic>{'p_code': trimmed},
      );
      if (response is Map) {
        return ReferralPreview.fromJson(Map<String, dynamic>.from(response));
      }
      return ReferralPreview.empty();
    } catch (_) {
      return ReferralPreview.empty();
    }
  }

  @override
  Future<AuthUser?> fetchProfileUser(String authId) async {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      return null;
    }
    try {
      final dynamic response = await SupabaseService.client
          .from('users')
          .select(
            'auth_id, username, email, level, gold, gems, energy, max_energy, '
            'attack, defense, health, max_health, power, guild_id, guild_role',
          )
          .eq('auth_id', authId)
          .maybeSingle();
      if (response == null) return null;
      final Map<String, dynamic> row = Map<String, dynamic>.from(response as Map);
      return AuthUser(
        id: (row['auth_id'] as String?) ?? authId,
        username: (row['username'] as String?) ?? 'unknown',
        email: (row['email'] as String?) ?? '',
        level: (row['level'] as num?)?.toInt() ?? 1,
        gold: (row['gold'] as num?)?.toInt() ?? 0,
        gems: (row['gems'] as num?)?.toInt() ?? 0,
        energy: (row['energy'] as num?)?.toInt() ?? 100,
        maxEnergy: (row['max_energy'] as num?)?.toInt() ?? 100,
        attack: (row['attack'] as num?)?.toInt() ?? 0,
        defense: (row['defense'] as num?)?.toInt() ?? 0,
        health: (row['health'] as num?)?.toInt() ?? 100,
        maxHealth: (row['max_health'] as num?)?.toInt() ?? 100,
        power: (row['power'] as num?)?.toInt() ?? 0,
        guildId: row['guild_id'] as String?,
        guildRole: row['guild_role'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  void _ensureConfigured() {
    if (!SupabaseService.isConfigured) {
      throw AppException(
        'Supabase baglantisi ayarlanmadi. app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }
  }

  AuthUser _userFromAuthMetadata(User user) {
    return AuthUser(
      id: user.id,
      username: user.userMetadata?['username'] as String? ?? user.email ?? 'unknown',
      email: user.email ?? '',
      level: (user.userMetadata?['level'] as num?)?.toInt() ?? 1,
      gold: (user.userMetadata?['gold'] as num?)?.toInt() ?? 0,
      gems: (user.userMetadata?['gems'] as num?)?.toInt() ?? 0,
      energy: (user.userMetadata?['energy'] as num?)?.toInt() ?? 100,
      maxEnergy: (user.userMetadata?['max_energy'] as num?)?.toInt() ?? 100,
      attack: (user.userMetadata?['attack'] as num?)?.toInt() ?? 0,
      defense: (user.userMetadata?['defense'] as num?)?.toInt() ?? 0,
      health: (user.userMetadata?['health'] as num?)?.toInt() ?? 100,
      maxHealth: (user.userMetadata?['max_health'] as num?)?.toInt() ?? 100,
      power: (user.userMetadata?['power'] as num?)?.toInt() ?? 0,
      guildId: user.userMetadata?['guild_id'] as String?,
      guildRole: user.userMetadata?['guild_role'] as String?,
    );
  }

  String _generateNonce([int length = 32]) {
    const String charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final Random random = Random.secure();
    return List<String>.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Claim device; on any failure roll back auth session (no orphan JWT).
  Future<void> _enforceSingleDeviceSession(String deviceId) async {
    try {
      if (deviceId.trim().length < 8) {
        throw AppException('Gecersiz cihaz kimligi.', code: 'INVALID_DEVICE_ID');
      }
      final String currentId = await DeviceIdentityService.currentId();
      if (deviceId.trim() != currentId) {
        throw AppException('Cihaz kimligi eslesmiyor.', code: 'DEVICE_ID_MISMATCH');
      }
      await DeviceSessionService.claimActiveDevice();
      await DeviceSessionService.syncRequestHeaders();
    } catch (e) {
      try {
        await DeviceSessionService.clearEpoch();
        await SupabaseService.client.auth.signOut();
      } catch (_) {
        // Best-effort rollback.
      }
      if (e is AppException) rethrow;
      throw AuthErrorMapper.fromObject(e);
    }

    // Best-effort revoke of refresh tokens on other devices after our epoch claim succeeded.
    // Never roll back the newly claimed local session if GoTrue `scope=others` errors!
    try {
      await SupabaseService.client.auth.signOut(scope: SignOutScope.others);
    } catch (_) {}
  }
}
