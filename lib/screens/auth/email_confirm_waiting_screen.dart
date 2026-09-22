import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_spacing.dart';
import 'widgets/auth_design.dart';
import 'widgets/auth_form_shell.dart';

class EmailConfirmWaitingScreen extends ConsumerStatefulWidget {
  const EmailConfirmWaitingScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<EmailConfirmWaitingScreen> createState() =>
      _EmailConfirmWaitingScreenState();
}

class _EmailConfirmWaitingScreenState
    extends ConsumerState<EmailConfirmWaitingScreen> {
  bool _resending = false;

  String? get _email {
    final AuthState auth = ref.watch(authProvider);
    final String? fromState = auth.pendingEmail ?? auth.user?.email;
    if (fromState != null && fromState.isNotEmpty) return fromState;
    final String? fromArg = widget.email?.trim();
    if (fromArg != null && fromArg.isNotEmpty) return fromArg;
    return null;
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      await ref.read(authProvider.notifier).resendSignupConfirmation(
            email: _email,
          );
      if (!mounted) return;
      final AuthState next = ref.read(authProvider);
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        AppMessenger.showError(context, next.errorMessage!);
      } else {
        AppMessenger.showSuccess(context, context.l10n.auth_email_confirm_resent);
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _goLogin() {
    ref.read(authProvider.notifier).acknowledgeTransient();
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? email = _email;
    final bool busy = _resending;

    return AuthFormShell(
      kind: AuthScreenKind.forgotPassword,
      badge: l10n.auth_email_confirm_title,
      title: l10n.krallik_kapisi,
      subtitle: l10n.auth_email_confirm_waiting_subtitle,
      sectionLabel: l10n.auth_form_section,
      footer: AuthGhostLink(
        label: l10n.giris_ekranina_don,
        enabled: !busy,
        onPressed: busy ? null : _goLogin,
        accent: AuthDesign.gold,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AuthDesign.obsidian.withValues(alpha: 0.72),
              border: Border.all(color: AuthDesign.gold.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.auth_email_confirm_body,
                  style: AuthDesign.bodyMuted(color: AuthDesign.textMid),
                ),
                if (email != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    email,
                    style: AuthDesign.bodyMuted(
                      color: AuthDesign.gold,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthGoldButton(
            label: busy
                ? l10n.auth_email_confirm_resend_loading
                : l10n.auth_email_confirm_resend,
            loading: busy,
            icon: Icons.mark_email_unread_outlined,
            onPressed: busy ? null : _resend,
          ),
        ],
      ),
    );
  }
}
