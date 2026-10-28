import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/app_messenger.dart';
import '../../core/services/device_identity_service.dart';
import '../../core/services/saved_credentials_service.dart';
import '../../core/utils/auth_validators.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_spacing.dart';
import 'widgets/auth_design.dart';
import 'widgets/auth_form_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  SavedLoginCredentials _saved = const SavedLoginCredentials();
  bool _appleAvailable = false;
  bool _appleChecked = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final SavedLoginCredentials loaded = await SavedCredentialsService.load();
    if (!mounted) return;
    setState(() {
      _saved = loaded;
      _rememberMe = loaded.rememberMe;
      if (loaded.hasSavedAccount) {
        if (_emailController.text.trim().isEmpty) {
          _emailController.text = loaded.email;
        }
        if (_passwordController.text.isEmpty) {
          _passwordController.text = loaded.password;
        }
      }
    });
  }

  Future<void> _toggleRememberMe(bool nextValue) async {
    setState(() {
      _rememberMe = nextValue;
      if (!nextValue) {
        _saved = SavedLoginCredentials(
          rememberMe: false,
          knownUsernameEmails: _saved.knownUsernameEmails,
        );
      }
    });
    await SavedCredentialsService.setRememberMe(nextValue);
  }

  Future<void> _forgetSavedAccount() async {
    await SavedCredentialsService.clearSavedAccount(
      keepRememberEnabled: _rememberMe,
    );
    if (!mounted) return;
    setState(() {
      _saved = SavedLoginCredentials(
        rememberMe: _rememberMe,
        knownUsernameEmails: _saved.knownUsernameEmails,
      );
      _emailController.clear();
      _passwordController.clear();
    });
  }

  Future<void> _quickSignInSavedAccount() async {
    if (!_saved.hasSavedAccount) return;
    _emailController.text = _saved.email;
    _passwordController.text = _saved.password;
    await _submitLogin();
  }

  Future<void> _submitLogin() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final String resolvedEmail = SavedCredentialsService.resolveIdentifier(
      _emailController.text,
      _saved.knownUsernameEmails,
    );

    final String deviceId = await DeviceIdentityService.currentId();
    await ref.read(authProvider.notifier).login(
          email: resolvedEmail,
          password: _passwordController.text,
          deviceId: deviceId,
        );
  }

  Future<void> _submitApple() async {
    if (!_appleAvailable) {
      AppMessenger.showError(context, context.l10n.auth_apple_unavailable);
      return;
    }
    final String deviceId = await DeviceIdentityService.currentId();
    await ref.read(authProvider.notifier).signInWithApple(deviceId: deviceId);
  }

  Future<void> _probeApple() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      if (mounted) {
        setState(() {
          _appleAvailable = false;
          _appleChecked = true;
        });
      }
      return;
    }
    final bool available =
        await ref.read(authProvider.notifier).isAppleSignInAvailable();
    if (!mounted) return;
    setState(() {
      _appleAvailable = available;
      _appleChecked = true;
    });
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedCredentials());
    WidgetsBinding.instance.addPostFrameCallback((_) => _probeApple());
    ref.listenManual<AuthState>(authProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      if (!mounted) return;

      if (next.status == AuthStatus.authenticated) {
        // Trigger native OS / Browser Password Manager save & cross-device sync.
        TextInput.finishAutofillContext(shouldSave: _rememberMe);

        final String resolvedEmail =
            (next.user?.email.trim().isNotEmpty ?? false)
                ? next.user!.email.trim()
                : SavedCredentialsService.resolveIdentifier(
                    _emailController.text,
                    _saved.knownUsernameEmails,
                  );
        final String? resolvedUsername =
            (next.user?.username.trim().isNotEmpty ?? false)
                ? next.user!.username.trim()
                : _saved.username;

        if (_passwordController.text.isNotEmpty) {
          unawaited(
            SavedCredentialsService.save(
              email: resolvedEmail,
              password: _passwordController.text,
              username: resolvedUsername,
              rememberMe: _rememberMe,
            ),
          );
        }
        return;
      }

      // Navigation = GoRouter redirect (onAuthStateChange refresh). No context.go.
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        AppMessenger.showError(context, next.errorMessage!);
        return;
      }

      if (next.status == AuthStatus.unauthenticated &&
          next.errorMessage != null &&
          next.errorMessage!.isNotEmpty) {
        AppMessenger.showError(context, next.errorMessage!);
      }
    });
  }

  Widget _buildSavedAccountBanner(AppLocalizations l10n, bool isLoading) {
    if (!_saved.hasSavedAccount) {
      return const SizedBox.shrink();
    }
    final String primaryTitle = _saved.displayHandle;
    final bool showEmailSub =
        _saved.username != null &&
        _saved.username!.trim().isNotEmpty &&
        !_saved.username!.contains('@');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AuthDesign.gold.withValues(alpha: 0.14),
              AuthDesign.obsidian.withValues(alpha: 0.86),
            ],
          ),
          border: Border.all(color: AuthDesign.gold.withValues(alpha: 0.40)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AuthDesign.gold.withValues(alpha: 0.16),
                border: Border.all(
                  color: AuthDesign.gold.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                size: 18,
                color: AuthDesign.gold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.auth_saved_account_label.toUpperCase(),
                    style: AuthDesign.sectionCaps(color: AuthDesign.gold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    primaryTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.urbanist(
                      color: AuthDesign.textHi,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (showEmailSub)
                    Text(
                      _saved.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(
                        color: AuthDesign.textMid,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AuthPressable(
              enabled: !isLoading,
              onTap: isLoading ? null : _quickSignInSavedAccount,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: AuthDesign.goldGradient,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.bolt_rounded,
                      size: 15,
                      color: AuthDesign.void_,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      l10n.auth_quick_login_cta,
                      style: GoogleFonts.urbanist(
                        color: AuthDesign.void_,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: l10n.auth_forget_saved_account,
              onPressed: isLoading ? null : _forgetSavedAccount,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AuthDesign.titanium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRememberMeRow(AppLocalizations l10n, bool isLoading) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isLoading ? null : () => _toggleRememberMe(!_rememberMe),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: _rememberMe ? AuthDesign.goldGradient : null,
                color: _rememberMe
                    ? null
                    : AuthDesign.obsidian.withValues(alpha: 0.8),
                border: Border.all(
                  color: _rememberMe
                      ? AuthDesign.gold
                      : Colors.white.withValues(alpha: 0.22),
                  width: 1.2,
                ),
              ),
              child: _rememberMe
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: AuthDesign.void_,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.auth_remember_me,
                style: GoogleFonts.urbanist(
                  color: _rememberMe ? AuthDesign.textHi : AuthDesign.textMid,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authProvider);
    final bool isLoading = authState.status == AuthStatus.loading;
    final AppLocalizations l10n = context.l10n;
    final bool showApple = _appleChecked && _appleAvailable;

    return AuthFormShell(
      kind: AuthScreenKind.login,
      badge: l10n.login,
      title: l10n.krallik_kapisi,
      subtitle: l10n.hesabina_giris_yap_ve_lonca_gelismelerini_canli_ta,
      sectionLabel: l10n.auth_form_section,
      footer: Column(
        children: <Widget>[
          AuthGhostLink(
            label: l10n.auth_forgot_password_link,
            enabled: !isLoading,
            onPressed: isLoading
                ? null
                : () => context.push(AppRoutes.forgotPassword),
            accent: AuthDesign.titanium,
          ),
          const SizedBox(height: AppSpacing.sm),
          AuthGhostLink(
            label: l10n.hesabin_yok_mu_kayit_ol,
            enabled: !isLoading,
            onPressed: isLoading ? null : () => context.push(AppRoutes.register),
            accent: AuthDesign.fuchsia,
          ),
        ],
      ),
      child: AutofillGroup(
        onDisposeAction: AutofillContextAction.cancel,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildSavedAccountBanner(l10n, isLoading),
              AuthField(
                controller: _emailController,
                label: _saved.knownUsernameEmails.isNotEmpty
                    ? l10n.auth_email_or_username
                    : l10n.auth_email,
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                autocorrect: false,
                validator: (String? value) =>
                    AuthValidators.validateLoginIdentifier(
                      value,
                      l10n,
                      knownUsernameEmails: _saved.knownUsernameEmails,
                    ),
              ),
              const SizedBox(height: AppSpacing.base),
              AuthField(
                controller: _passwordController,
                label: l10n.auth_password,
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.password],
                autocorrect: false,
                enableSuggestions: false,
                onFieldSubmitted: (_) {
                  if (!isLoading) _submitLogin();
                },
                validator: (String? value) =>
                    AuthValidators.validatePasswordLogin(value, l10n),
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  tooltip: _obscurePassword
                      ? l10n.auth_toggle_password_show
                      : l10n.auth_toggle_password_hide,
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AuthDesign.titanium,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildRememberMeRow(l10n, isLoading),
              const SizedBox(height: AppSpacing.base),
              AuthGoldButton(
                label: isLoading ? l10n.auth_login_loading : l10n.auth_login_button,
                loading: isLoading,
                onPressed: isLoading ? null : _submitLogin,
              ),
              if (showApple) ...<Widget>[
                const SizedBox(height: AppSpacing.base),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Divider(
                        color: AuthDesign.textLow.withValues(alpha: 0.5),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('veya', style: AuthDesign.bodyMuted()),
                    ),
                    Expanded(
                      child: Divider(
                        color: AuthDesign.textLow.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _submitApple,
                  icon: const Icon(Icons.apple, size: 22),
                  label: Text(l10n.auth_apple_button),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AuthDesign.textHi,
                    side: BorderSide(
                      color: AuthDesign.titanium.withValues(alpha: 0.55),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
