import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../core/services/device_identity_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/auth_validators.dart';
import '../../l10n/l10n.dart';
import '../../models/policy_model.dart';
import '../../models/referral_preview_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/policy_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_spacing.dart';
import '../../utils/logout_helper.dart';
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
  bool _policyBusy = false;
  bool _usernameTaken = false;
  bool _checkingUsername = false;
  Timer? _usernameDebounce;
  Timer? _referralDebounce;
  bool _referralChecking = false;
  ReferralPreview? _referralPreview;

  bool get _canRegister =>
      _communityDecision == CommunityRulesDecision.accepted &&
      _termsAccepted &&
      _privacyAccepted &&
      !_usernameTaken;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _referralDebounce?.cancel();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    setState(() {
      _usernameTaken = false;
      _checkingUsername = value.trim().length >= 3;
    });
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      final String trimmed = value.trim();
      if (trimmed.length < 3 ||
          AuthValidators.validateUsername(trimmed, context.l10n) != null) {
        if (mounted) setState(() => _checkingUsername = false);
        return;
      }
      final bool available =
          await ref.read(authProvider.notifier).isUsernameAvailable(trimmed);
      if (!mounted) return;
      setState(() {
        _checkingUsername = false;
        _usernameTaken = !available;
      });
    });
  }

  void _onReferralChanged(String value) {
    _referralDebounce?.cancel();
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _referralChecking = false;
        _referralPreview = null;
      });
      return;
    }
    setState(() => _referralChecking = true);
    _referralDebounce = Timer(const Duration(milliseconds: 500), () async {
      final ReferralPreview preview =
          await ref.read(authProvider.notifier).validateReferralCode(trimmed);
      if (!mounted) return;
      setState(() {
        _referralChecking = false;
        _referralPreview = preview;
      });
    });
  }

  Future<void> _loadAndShowCommunityRules() async {
    if (_rulesDialogShown || !mounted) return;
    _rulesDialogShown = true;

    final LegalDocument doc =
        await ref.read(policyProvider.notifier).fetchCommunityDocumentPublic();
    if (!mounted) return;

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
    final LegalDocument doc = _communityDoc ??
        await ref.read(policyProvider.notifier).fetchCommunityDocumentPublic();
    if (!mounted) return;

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

    if (_usernameTaken) {
      AppMessenger.showError(context, context.l10n.auth_username_taken);
      return;
    }

    final ReferralPreview? refPreview = _referralPreview;
    if (_referralController.text.trim().isNotEmpty &&
        refPreview != null &&
        !refPreview.empty &&
        !refPreview.valid) {
      AppMessenger.showError(context, context.l10n.auth_referral_invalid);
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
    setState(() => _policyBusy = true);
    try {
      // Wait briefly so JWT/session is usable by RPCs after signUp.
      for (int i = 0; i < 10; i++) {
        if (SupabaseService.client.auth.currentSession != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      final String? err = await ref.read(policyProvider.notifier).acceptAll();
      if (!mounted) return;
      if (err != null) {
        await _showPolicyStuckDialog(err);
        return;
      }
      context.go(AppRoutes.home);
    } finally {
      if (mounted) setState(() => _policyBusy = false);
    }
  }

  Future<void> _showPolicyStuckDialog(String err) async {
    final AppLocalizations l10n = context.l10n;
    final bool? retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(l10n.auth_policy_stuck_title),
          content: Text(err),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.auth_policy_logout),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.auth_policy_retry),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (retry == true) {
      await _onRegistered();
      return;
    }
    await performLogout(ref);
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  void _goToLogin() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.push(AppRoutes.login);
  }

  Widget _referralHint(AppLocalizations l10n) {
    if (_referralChecking) {
      return Text(
        l10n.auth_referral_validating,
        style: AuthDesign.bodyMuted(color: AuthDesign.titanium),
      );
    }
    final ReferralPreview? preview = _referralPreview;
    if (preview == null || preview.empty) {
      return const SizedBox.shrink();
    }
    if (!preview.valid) {
      return Text(
        l10n.auth_referral_invalid,
        style: AuthDesign.bodyMuted(color: AuthDesign.fuchsia),
      );
    }
    return Text(
      l10n.auth_referral_bonus_preview(
        preview.unlockLevel,
        preview.referredGems,
        preview.referrerGems,
      ),
      style: AuthDesign.bodyMuted(color: AuthDesign.gold),
    );
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

      if (next.status == AuthStatus.pendingEmailConfirmation) {
        final String email = next.pendingEmail ??
            next.user?.email ??
            _emailController.text.trim();
        context.go(
          '${AppRoutes.emailConfirm}?email=${Uri.encodeComponent(email)}',
        );
        return;
      }

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
    final bool isLoading =
        authState.status == AuthStatus.loading || _policyBusy;
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
              onChanged: _onUsernameChanged,
              validator: (String? value) {
                final String? base = AuthValidators.validateUsername(value, l10n);
                if (base != null) return base;
                if (_usernameTaken) return l10n.auth_username_taken;
                return null;
              },
            ),
            if (_checkingUsername || _usernameTaken) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                _usernameTaken
                    ? l10n.auth_username_taken
                    : '...',
                style: AuthDesign.bodyMuted(
                  color: _usernameTaken ? AuthDesign.fuchsia : AuthDesign.titanium,
                ),
              ),
            ],
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
              onChanged: _onReferralChanged,
              onFieldSubmitted: (_) {
                if (!isLoading && _canRegister) _submitRegister();
              },
            ),
            const SizedBox(height: 6),
            _referralHint(l10n),
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
