import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/errors/app_exception.dart';
import 'package:gkk_flutter/models/auth_model.dart';
import 'package:gkk_flutter/models/referral_preview_model.dart';
import 'package:gkk_flutter/providers/auth_provider.dart';
import 'package:gkk_flutter/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.session,
    this.loginResponse,
    this.registerResponse,
    this.loginError,
    this.registerError,
    this.profileUser,
    this.usernameAvailable = true,
  });

  final AuthSession? session;
  final AuthResponse? loginResponse;
  final AuthResponse? registerResponse;
  final Object? loginError;
  final Object? registerError;
  final AuthUser? profileUser;
  final bool usernameAvailable;

  bool logoutCalled = false;
  int passwordResetCalls = 0;
  int resendCalls = 0;
  String? lastResetEmail;
  String? lastUpdatedPassword;
  String? lastResendEmail;

  @override
  Future<AuthSession?> currentSession() async => session;

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    if (loginError != null) throw loginError!;
    if (loginResponse == null) {
      throw Exception('No fake login response');
    }
    return loginResponse!;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    if (registerError != null) throw registerError!;
    if (registerResponse == null) {
      throw UnimplementedError();
    }
    return registerResponse!;
  }

  @override
  Future<AuthResponse> signInWithApple({required String deviceId}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    passwordResetCalls++;
    lastResetEmail = email;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    lastUpdatedPassword = newPassword;
  }

  @override
  Future<void> resendSignupConfirmation(String email) async {
    resendCalls++;
    lastResendEmail = email;
  }

  @override
  Future<AuthUser?> fetchProfileUser(String authId) async => profileUser;

  @override
  Future<bool> isUsernameAvailable(String username) async => usernameAvailable;

  @override
  Future<ReferralPreview> validateReferralCode(String code) async {
    return ReferralPreview.empty();
  }

  @override
  Future<bool> isAppleSignInAvailable() async => false;
}

AuthUser _sampleUser({String id = 'u1'}) => AuthUser(
      id: id,
      username: 'selcuk',
      email: 's@example.com',
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

void main() {
  test('loadSession sets unauthenticated when no session exists', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(session: null)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).loadSession();

    final AuthState state = container.read(authProvider);
    expect(state.status, AuthStatus.unauthenticated);
  });

  test('login success → authenticated', () async {
    final AuthUser user = _sampleUser();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            loginResponse: AuthResponse(
              session: const AuthSession(
                accessToken: 'a',
                refreshToken: 'r',
                expiresAt: 1,
              ),
              user: user,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).login(
          email: 's@example.com',
          password: 'secret12',
          deviceId: 'device-id-123456',
        );

    final AuthState state = container.read(authProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.user?.username, 'selcuk');
  });

  test('login AppException → error status', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            loginError: AppException('bad', code: 'X'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).login(
          email: 's@example.com',
          password: 'secret12',
          deviceId: 'device-id-123456',
        );

    expect(container.read(authProvider).status, AuthStatus.error);
    expect(container.read(authProvider).errorMessage, 'bad');
  });

  test('register without session → pendingEmailConfirmation', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            registerResponse: AuthResponse(
              user: _sampleUser(),
              requiresEmailConfirmation: true,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).register(
          email: 's@example.com',
          username: 'selcuk',
          password: 'secret12',
          deviceId: 'device-id-123456',
        );

    expect(container.read(authProvider).status, AuthStatus.pendingEmailConfirmation);
    expect(container.read(authProvider).pendingEmail, 's@example.com');
  });

  test('resendSignupConfirmation keeps pending status', () async {
    final FakeAuthRepository fake = FakeAuthRepository(
      registerResponse: AuthResponse(
        user: _sampleUser(),
        requiresEmailConfirmation: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).register(
          email: 's@example.com',
          username: 'selcuk',
          password: 'secret12',
          deviceId: 'device-id-123456',
        );
    await container.read(authProvider.notifier).resendSignupConfirmation();

    expect(fake.resendCalls, 1);
    expect(fake.lastResendEmail, 's@example.com');
    expect(container.read(authProvider).status, AuthStatus.pendingEmailConfirmation);
  });

  test('requestPasswordReset → passwordResetSent', () async {
    final FakeAuthRepository fake = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container
        .read(authProvider.notifier)
        .requestPasswordReset(email: 's@example.com');

    expect(fake.passwordResetCalls, 1);
    expect(container.read(authProvider).status, AuthStatus.passwordResetSent);
  });
}
