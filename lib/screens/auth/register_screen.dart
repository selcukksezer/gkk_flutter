import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../core/services/device_identity_service.dart';
import '../../core/utils/auth_validators.dart';
import '../../l10n/l10n.dart';
import '../../models/policy_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/policy_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_spacing.dart';
import 'widgets/auth_design.dart';
import 'widgets/auth_form_shell.dart';
import 'widgets/community_rules_gate.dart';
import 'widgets/register_legal_consent.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  bool _obscurePassword = true;
  LegalDocument? _communityDoc;
  CommunityRulesDecision _communityDecision = CommunityRulesDecision.pending;
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _rulesDialogShown = false;

  bool get _canRegister =>
      _communityDecision == CommunityRulesDecision.accepted &&
      _termsAccepted &&
      _privacyAccepted;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _loadAndShowCommunityRules() async {
    if (_rulesDialogShown || !mounted) return;
    _rulesDialogShown = true;

    final LegalDocument? doc =
        await ref.read(policyProvider.notifier).fetchCommunityDocumentPublic();
    if (!mounted) return;

    if (doc == null) {
      AppMessenger.showError(context, 'Topluluk Kuralları yüklenemedi.');
      return;
    }

    setState(() => _communityDoc = doc);

    final CommunityRulesDecision? decision = await showRegisterCommunityRulesDialog(
      context,
      document: doc,
    );
    if (!mounted || decision == null) return;

    setState(() => _communityDecision = decision);
    if (decision == CommunityRulesDecision.rejected) {
      AppMessenger.showError(context, 'Kayıt için Topluluk Kurallarını kabul etmelisin.');
    }
  }

  Future<void> _reviewCommunityRules() async {
    final LegalDocument? doc = _communityDoc ??
        await ref.read(policyProvider.notifier).fetchCommunityDocumentPublic();
    if (!mounted) return;
    if (doc == null) {
      AppMessenger.showError(context, 'Topluluk Kuralları yüklenemedi.');
      return;
    }

    setState(() => _communityDoc = doc);

    final CommunityRulesDecision? decision = await showRegisterCommunityRulesDialog(
      context,
      document: doc,
    );
    if (!mounted || decision == null) return;

    setState(() => _communityDecision = decision);
    if (decision == CommunityRulesDecision.rejected) {
      AppMessenger.showError(context, 'Kayıt için Topluluk Kurallarını kabul etmelisin.');
    }
  }

  Future<void> _submitRegister() async {
    if (!_canRegister) {
      AppMessenger.showError(context, 'Kayıt için tüm sözleşmeleri kabul et.');
      return;
    }

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final String deviceId = await DeviceIdentityService.currentId();
    await ref.read(authProvider.notifier).register(
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          deviceId: deviceId,
          referralCode: _referralController.text.trim().isEmpty
              ? null
              : _referralController.text.trim(),
        );
  }

  Future<void> _onRegistered() async {
    final String? err = await ref.read(policyProvider.notifier).acceptAll();
    if (!mounted) return;
    if (err != null) {
      AppMessenger.showError(context, 'Sözleşme kaydı başarısız: $err');
    }
    context.go(AppRoutes.home);
  }

  void _goToLogin() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.push(AppRoutes.login);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAndShowCommunityRules());

    ref.listenManual<AuthState>(authProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      if (!mounted) return;

      if (next.status == AuthStatus.authenticated) {
        _onRegistered();
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
      kind: AuthScreenKind.register,
      badge: l10n.kayit,
      title: l10n.krallik_kapisi,
      subtitle: l10n.auth_register_subtitle,
      sectionLabel: l10n.auth_form_section,
      footer: AuthGhostLink(
        label: l10n.giris_ekranina_don,
        enabled: !isLoading,
        onPressed: isLoading ? null : _goToLogin,
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
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              autocorrect: false,
              accent: AuthDesign.fuchsia,
              validator: (String? value) => AuthValidators.validateEmail(value, l10n),
            ),
            const SizedBox(height: AppSpacing.base),
            AuthField(
              controller: _usernameController,
              label: l10n.auth_username,
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.username],
              autocorrect: false,
              accent: AuthDesign.fuchsia,
              validator: (String? value) => AuthValidators.validateUsername(value, l10n),
            ),
            const SizedBox(height: AppSpacing.base),
            AuthField(
              controller: _passwordController,
              label: l10n.auth_password,
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              autocorrect: false,
              enableSuggestions: false,
              accent: AuthDesign.fuchsia,
              validator: (String? value) => AuthValidators.validatePassword(value, l10n),
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
            const SizedBox(height: AppSpacing.base),
            AuthField(
              controller: _referralController,
              label: l10n.auth_referral_code,
              icon: Icons.card_giftcard_outlined,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              accent: AuthDesign.gold,
              onFieldSubmitted: (_) {
                if (!isLoading && _canRegister) _submitRegister();
              },
            ),
            const SizedBox(height: AppSpacing.base),
            RegisterLegalConsent(
              termsAccepted: _termsAccepted,
              privacyAccepted: _privacyAccepted,
              onTermsChanged: (bool? v) => setState(() => _termsAccepted = v == true),
              onPrivacyChanged: (bool? v) => setState(() => _privacyAccepted = v == true),
            ),
            CommunityRulesStatusBanner(
              decision: _communityDecision,
              onReviewAgain: _reviewCommunityRules,
            ),
            const SizedBox(height: AppSpacing.sm),
            AuthGoldButton(
              label: isLoading ? l10n.auth_register_loading : l10n.auth_register_button,
              loading: isLoading,
              icon: Icons.person_add_rounded,
              onPressed: isLoading || !_canRegister ? null : _submitRegister,
            ),
          ],
        ),
      ),
    );
  }
}
