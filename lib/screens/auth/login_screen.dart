import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../core/services/device_identity_service.dart';
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
  bool _appleAvailable = false;
  bool _appleChecked = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final String deviceId = await DeviceIdentityService.currentId();
    await ref.read(authProvider.notifier).login(
          email: _emailController.text.trim(),
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _probeApple());
    ref.listenManual<AuthState>(authProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      if (!mounted) return;

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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AuthField(
              controller: _emailController,
              label: l10n.auth_email,
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              autocorrect: false,
              validator: (String? value) => AuthValidators.validateEmail(value, l10n),
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
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                tooltip: _obscurePassword ? l10n.auth_toggle_password_show : l10n.auth_toggle_password_hide,
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AuthDesign.titanium,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthGoldButton(
              label: isLoading ? l10n.auth_login_loading : l10n.auth_login_button,
              loading: isLoading,
              onPressed: isLoading ? null : _submitLogin,
            ),
            if (showApple) ...<Widget>[
              const SizedBox(height: AppSpacing.base),
              Row(
                children: <Widget>[
                  Expanded(child: Divider(color: AuthDesign.textLow.withValues(alpha: 0.5))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('veya', style: AuthDesign.bodyMuted()),
                  ),
                  Expanded(child: Divider(color: AuthDesign.textLow.withValues(alpha: 0.5))),
                ],
              ),
              const SizedBox(height: AppSpacing.base),
              OutlinedButton.icon(
                onPressed: isLoading ? null : _submitApple,
                icon: const Icon(Icons.apple, size: 22),
                label: Text(l10n.auth_apple_button),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AuthDesign.textHi,
                  side: BorderSide(color: AuthDesign.titanium.withValues(alpha: 0.55)),
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
    );
  }
}
