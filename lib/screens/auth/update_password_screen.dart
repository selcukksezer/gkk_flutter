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

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    await ref.read(authProvider.notifier).updatePassword(
          newPassword: _passwordController.text,
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

      if (previous?.status == AuthStatus.loading &&
          next.status == AuthStatus.unauthenticated &&
          next.errorMessage == null) {
        AppMessenger.showSuccess(
          context,
          context.l10n.auth_update_password_success,
        );
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
      kind: AuthScreenKind.updatePassword,
      badge: l10n.auth_update_password_title,
      title: l10n.krallik_kapisi,
      subtitle: l10n.auth_update_password_subtitle,
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
              controller: _passwordController,
              label: l10n.auth_password,
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              autocorrect: false,
              enableSuggestions: false,
              validator: (String? value) =>
                  AuthValidators.validatePassword(value, l10n),
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
            const SizedBox(height: AppSpacing.base),
            AuthField(
              controller: _confirmController,
              label: l10n.auth_password_confirm,
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.newPassword],
              autocorrect: false,
              enableSuggestions: false,
              onFieldSubmitted: (_) {
                if (!isLoading) _submit();
              },
              validator: (String? value) => AuthValidators.validatePasswordConfirm(
                    value,
                    _passwordController.text,
                    l10n,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthGoldButton(
              label: isLoading
                  ? l10n.auth_update_password_loading
                  : l10n.auth_update_password_button,
              loading: isLoading,
              onPressed: isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
