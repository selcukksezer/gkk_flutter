import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../core/utils/auth_validators.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_spacing.dart';
import 'widgets/auth_design.dart';
import 'widgets/auth_form_shell.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    await ref.read(authProvider.notifier).requestPasswordReset(
          email: _emailController.text.trim(),
        );
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual<AuthState>(authProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      if (!mounted) return;

      if (next.status == AuthStatus.passwordResetSent) {
        AppMessenger.showSuccess(context, context.l10n.auth_forgot_password_sent);
        ref.read(authProvider.notifier).acknowledgeTransient();
        context.go(AppRoutes.login);
        return;
      }

      if (next.status == AuthStatus.error && next.errorMessage != null) {
        AppMessenger.showError(context, next.errorMessage!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authProvider);
    final bool isLoading = authState.status == AuthStatus.loading;
    final AppLocalizations l10n = context.l10n;

    return AuthFormShell(
      kind: AuthScreenKind.forgotPassword,
      badge: l10n.auth_forgot_password_title,
      title: l10n.krallik_kapisi,
      subtitle: l10n.auth_forgot_password_subtitle,
      sectionLabel: l10n.auth_form_section,
      footer: AuthGhostLink(
        label: l10n.giris_ekranina_don,
        enabled: !isLoading,
        onPressed: isLoading ? null : () => context.go(AppRoutes.login),
        accent: AuthDesign.gold,
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
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.email],
              autocorrect: false,
              onFieldSubmitted: (_) {
                if (!isLoading) _submit();
              },
              validator: (String? value) =>
                  AuthValidators.validateEmail(value, l10n),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthGoldButton(
              label: isLoading
                  ? l10n.auth_forgot_password_loading
                  : l10n.auth_forgot_password_button,
              loading: isLoading,
              onPressed: isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
