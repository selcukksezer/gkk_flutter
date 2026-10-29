import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/services/device_session_service.dart';
import '../core/services/supabase_service.dart';
import '../models/auth_model.dart';
import '../models/referral_preview_model.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  pendingEmailConfirmation,
  passwordResetSent,
  error,
}

class AuthState {
  const AuthState({
    required this.status,
    this.session,
    this.user,
    this.errorMessage,
    this.pendingEmail,
  });

  final AuthStatus status;
  final AuthSession? session;
  final AuthUser? user;
  final String? errorMessage;
  final String? pendingEmail;

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    AuthUser? user,
    String? errorMessage,
    String? pendingEmail,
    bool clearSession = false,
    bool clearUser = false,
    bool clearError = false,
    bool clearPendingEmail = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingEmail:
          clearPendingEmail ? null : (pendingEmail ?? this.pendingEmail),
    );
  }
}

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return SupabaseAuthRepository();
});

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() => AuthState.initial();

  Future<void> loadSession() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final session = await _repository.currentSession();
      if (session == null || session.accessToken.isEmpty) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          clearSession: true,
          clearUser: true,
        );
        return;
      }

      final DeviceSessionVerifyResult deviceCheck =
          await DeviceSessionService.verifyCurrentDevice();
      if (!deviceCheck.valid &&
          deviceCheck.reason != DeviceSessionReason.noAuth) {
        await _repository.logout();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          clearSession: true,
          clearUser: true,
          errorMessage: _deviceSessionMessage(deviceCheck.reason),
        );
        return;
      }

      final String? authId = SupabaseService.isInitialized
          ? SupabaseService.client.auth.currentUser?.id
          : null;
      AuthUser? user;
      if (authId != null) {
        user = await _repository.fetchProfileUser(authId);
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: session,
        user: user,
      );
      await DeviceSessionService.syncRequestHeaders();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
    required String deviceId,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final response = await _repository.login(
        LoginRequest(email: email, password: password, deviceId: deviceId),
      );

      if (!response.hasSession) {
        state = state.copyWith(
          status: AuthStatus.error,
          clearSession: true,
          errorMessage: 'Giriş başarısız. Oturum oluşturulamadı.',
        );
        return;
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: response.session,
        user: response.user,
        clearPendingEmail: true,
      );
      await DeviceSessionService.syncRequestHeaders();
    } on AppException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Giris sirasinda beklenmeyen bir hata oluştu.',
      );
    }
  }

  Future<void> signInWithApple({required String deviceId}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final response = await _repository.signInWithApple(deviceId: deviceId);
      if (!response.hasSession) {
        state = state.copyWith(
          status: AuthStatus.error,
          clearSession: true,
          errorMessage: 'Apple ile giriş başarısız.',
        );
        return;
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: response.session,
        user: response.user,
        clearPendingEmail: true,
      );
      await DeviceSessionService.syncRequestHeaders();
    } on AppException catch (e) {
      if (e.code == 'APPLE_CANCELED') {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          clearError: true,
        );
        return;
      }
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Apple ile giriş sırasında hata oluştu.',
      );
    }
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String deviceId,
    String? referralCode,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final response = await _repository.register(
        RegisterRequest(
          email: email,
          username: username,
          password: password,
          deviceId: deviceId,
          referralCode: referralCode,
        ),
      );

      if (response.requiresEmailConfirmation || !response.hasSession) {
        state = state.copyWith(
          status: AuthStatus.pendingEmailConfirmation,
          clearSession: true,
          user: response.user,
          pendingEmail: email.trim(),
          clearError: true,
        );
        return;
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: response.session,
        user: response.user,
        clearPendingEmail: true,
      );
      await DeviceSessionService.syncRequestHeaders();
    } on AppException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Kayit sirasinda beklenmeyen bir hata oluştu.',
      );
    }
  }

  Future<void> requestPasswordReset({required String email}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _repository.requestPasswordReset(email);
      state = state.copyWith(
        status: AuthStatus.passwordResetSent,
        clearSession: true,
        clearUser: true,
      );
    } on AppException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Sifre sıfırlama istegi gonderilemedi.',
      );
    }
  }

  Future<void> updatePassword({required String newPassword}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _repository.updatePassword(newPassword);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearSession: true,
        clearUser: true,
        clearError: true,
      );
      // Force re-login with new password (recovery session discarded).
      try {
        await _repository.logout();
      } catch (_) {}
    } on AppException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Şifre güncellenemedi.',
      );
    }
  }

  Future<void> resendSignupConfirmation({String? email}) async {
    final String? target = (email ?? state.pendingEmail ?? state.user?.email)
        ?.trim();
    if (target == null || target.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Onay e-postası için adres bulunamadı.',
      );
      return;
    }
    try {
      await _repository.resendSignupConfirmation(target);
      state = state.copyWith(
        status: AuthStatus.pendingEmailConfirmation,
        pendingEmail: target,
        clearError: true,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.pendingEmailConfirmation,
        pendingEmail: target,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.pendingEmailConfirmation,
        pendingEmail: target,
        errorMessage: 'Onay e-postası yeniden gönderilemedi.',
      );
    }
  }

  Future<bool> isUsernameAvailable(String username) {
    return _repository.isUsernameAvailable(username);
  }

  Future<ReferralPreview> validateReferralCode(String code) {
    return _repository.validateReferralCode(code);
  }

  Future<bool> isAppleSignInAvailable() {
    return _repository.isAppleSignInAvailable();
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _repository.logout();
    } catch (_) {
      // Oturum sunucuda zaten düşmüş olabilir; istemci durumunu yine de temizle.
    } finally {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearSession: true,
        clearUser: true,
        clearPendingEmail: true,
      );
    }
  }

  /// Clears error / transient statuses back to unauthenticated (forms).
  void acknowledgeTransient() {
    if (state.status == AuthStatus.passwordResetSent ||
        state.status == AuthStatus.pendingEmailConfirmation ||
        state.status == AuthStatus.error) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearError: true,
        clearPendingEmail: true,
      );
    }
  }

  String _deviceSessionMessage(DeviceSessionReason reason) {
    switch (reason) {
      case DeviceSessionReason.otherDevice:
        return 'Hesabın başka bir cihazda açıldı. Güvenlik için bu oturum sonlandırıldı.';
      case DeviceSessionReason.superseded:
        return 'Oturumun süresi doldu veya yeni giriş yapıldı. Tekrar giriş yap.';
      default:
        return 'Oturum doğrulanamadı. Tekrar giriş yap.';
    }
  }
}

final NotifierProvider<AuthNotifier, AuthState> authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
