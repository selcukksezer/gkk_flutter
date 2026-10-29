import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/app_messenger.dart';
import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../core/legal/legal_document_content.dart';
import '../../core/services/device_identity_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/auth_validators.dart';
import '../../l10n/l10n.dart';
import '../../models/policy_model.dart';
import '../../models/referral_preview_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/policy_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/logout_helper.dart';
import '../settings/graphics_settings_service.dart';
import 'widgets/aion_portal_tabs.dart';
import 'widgets/aion_rune_frame.dart';
import 'widgets/aion_sky_particles.dart';
import 'widgets/auth_design.dart';
import 'widgets/auth_legal_document_dialog.dart';
import 'widgets/community_rules_gate.dart';

/// 2027 Aion 2 Mobile Registration Portal (AAA Luxury Dark Edition).
/// Features atmospheric sky, animated particle embers, glowing rune borders,
/// responsive real-time form validators, modern Switch & Checkbox controls,
/// and ZeroJankPreloader & AdaptiveQualityScaler integration.
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
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _referralController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _guildDispatchAlerts = true;

  LegalDocument? _communityDoc;
  CommunityRulesDecision _communityDecision = CommunityRulesDecision.pending;
  bool _rulesDialogShown = false;
  bool _policyBusy = false;

  bool _usernameTaken = false;
  bool _checkingUsername = false;
  Timer? _usernameDebounce;

  bool _referralChecking = false;
  ReferralPreview? _referralPreview;
  Timer? _referralDebounce;

  bool get _canRegister =>
      _communityDecision == CommunityRulesDecision.accepted &&
      _termsAccepted &&
      _privacyAccepted &&
      !_usernameTaken &&
      !_policyBusy;

  @override
  void initState() {
    super.initState();

    // Zero-Jank background asset warmup for registration & subsequent character creation HUD
    ZeroJankPreloader.instance.preloadAtomic<bool>(
      id: 'hud_register_character_assets',
      priority: PreloadPriority.criticalHud,
      loader: () async => true,
      tags: const <String>{'auth', 'register', 'character_select'},
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndShowCommunityRules();
    });

    ref.listenManual<AuthState>(authProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      if (!mounted) return;

      // Email confirmation redirect
      if (next.status == AuthStatus.pendingEmailConfirmation) {
        final String email = next.pendingEmail ??
            next.user?.email ??
            _emailController.text.trim();
        context.go('${AppRoutes.emailConfirm}?email=$email');
        return;
      }

      // Registration authenticated handler
      if (next.status == AuthStatus.authenticated) {
        _onRegistered();
        return;
      }

      // Error messages
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
  void dispose() {
    _usernameDebounce?.cancel();
    _referralDebounce?.cancel();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

    final CommunityRulesDecision? decision =
        await showRegisterCommunityRulesDialog(
      context,
      document: doc,
    );
    if (!mounted || decision == null) return;

    setState(() => _communityDecision = decision);
    if (decision == CommunityRulesDecision.rejected) {
      AppMessenger.showError(
        context,
        'Kayıt için Topluluk Kurallarını kabul etmelisin.',
      );
    }
  }

  Future<void> _reviewCommunityRules() async {
    HapticFeedback.selectionClick();
    final LegalDocument doc = _communityDoc ??
        await ref.read(policyProvider.notifier).fetchCommunityDocumentPublic();
    if (!mounted) return;

    setState(() => _communityDoc = doc);

    final CommunityRulesDecision? decision =
        await showRegisterCommunityRulesDialog(
      context,
      document: doc,
    );
    if (!mounted || decision == null) return;

    setState(() => _communityDecision = decision);
    if (decision == CommunityRulesDecision.rejected) {
      AppMessenger.showError(
        context,
        'Kayıt için Topluluk Kurallarını kabul etmelisin.',
      );
    }
  }

  void _openDocument(String type) {
    HapticFeedback.selectionClick();
    final LegalDocument doc = LegalDocumentContent.resolve(
      LegalDocument(type: type, version: 1, title: '', bodyMd: ''),
    );
    showAuthLegalDocumentDialog(context, document: doc);
  }

  Future<void> _submitRegister() async {
    HapticFeedback.mediumImpact();
    if (!_canRegister) {
      if (_communityDecision != CommunityRulesDecision.accepted) {
        AppMessenger.showError(
          context,
          'Kayıt için Topluluk Kurallarını kabul etmelisin.',
        );
      } else {
        AppMessenger.showError(
          context,
          'Kayıt için tüm sözleşmeleri ve koşulları kabul etmelisin.',
        );
      }
      return;
    }

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      HapticFeedback.vibrate();
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      HapticFeedback.vibrate();
      AppMessenger.showError(
        context,
        'Girdiğin şifreler birbiriyle eşleşmiyor.',
      );
      return;
    }

    if (_usernameTaken) {
      HapticFeedback.vibrate();
      AppMessenger.showError(context, context.l10n.auth_username_taken);
      return;
    }

    final ReferralPreview? refPreview = _referralPreview;
    if (_referralController.text.trim().isNotEmpty &&
        refPreview != null &&
        !refPreview.empty &&
        !refPreview.valid) {
      HapticFeedback.vibrate();
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
          backgroundColor: AuthDesign.obsidian,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: AuthDesign.gold.withValues(alpha: 0.35)),
          ),
          title: Text(
            l10n.auth_policy_stuck_title,
            style: GoogleFonts.urbanist(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            err,
            style: GoogleFonts.urbanist(color: const Color(0xFFCBD5E1)),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                l10n.auth_policy_logout,
                style: GoogleFonts.urbanist(color: const Color(0xFF94A3B8)),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AuthDesign.gold),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                l10n.auth_policy_retry,
                style: GoogleFonts.urbanist(
                  color: AuthDesign.void_,
                  fontWeight: FontWeight.w700,
                ),
              ),
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

  Widget _buildConsentRow({
    required BuildContext context,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    required String docType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: value,
                  onChanged: (bool? v) {
                    HapticFeedback.selectionClick();
                    onChanged(v);
                  },
                  activeColor: AppColors.cyberFuchsia,
                  checkColor: Colors.white,
                  fillColor: WidgetStateProperty.resolveWith<Color>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.cyberFuchsia;
                      }
                      return Colors.transparent;
                    },
                  ),
                  side: BorderSide(
                    color: value
                        ? AppColors.cyberFuchsia
                        : Colors.white.withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AuthDesign.bodyMuted(color: AuthDesign.textMid)
                        .copyWith(fontSize: 13),
                    children: <InlineSpan>[
                      TextSpan(text: '$label '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openDocument(docType),
                          child: Text(
                            '(oku)',
                            style: GoogleFonts.urbanist(
                              color: AppColors.cyberFuchsia,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.cyberFuchsia,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationConsentSwitch() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.notifications_active_outlined,
            color: AppColors.cyberFuchsia.withValues(alpha: 0.85),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Lonca Sefer & Ganimet Bildirimleri',
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Canlı baskın ve ödül uyarılarını anında al.',
                  style: GoogleFonts.urbanist(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _guildDispatchAlerts,
            onChanged: (bool value) {
              HapticFeedback.selectionClick();
              setState(() => _guildDispatchAlerts = value);
            },
            activeColor: AppColors.cyberFuchsia,
            activeTrackColor: AppColors.cyberFuchsia.withValues(alpha: 0.38),
            thumbColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFFFF4D8D);
                }
                return const Color(0xFF94A3B8);
              },
            ),
            trackColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.cyberFuchsia.withValues(alpha: 0.45);
                }
                return const Color(0xFF0F172A);
              },
            ),
            trackOutlineColor: WidgetStateProperty.all(
              Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAionHeader(AppLocalizations l10n) {
    const Color emblemAccent = AppColors.cyberFuchsia;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Glowing celestial crest
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                emblemAccent.withValues(alpha: 0.35),
                const Color(0xFF0F172A),
              ],
            ),
            border: Border.all(
              color: emblemAccent.withValues(alpha: 0.55),
              width: 1.4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: emblemAccent.withValues(alpha: 0.28),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_alt_1_rounded,
            color: emblemAccent,
            size: 30,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.krallik_kapisi.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.auth_register_subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(
            color: const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authProvider);
    final bool isLoading = authState.status == AuthStatus.loading || _policyBusy;
    final AppLocalizations l10n = context.l10n;

    // Hardware tier adaptive scaling
    final QualitySettings qualitySettings =
        GraphicsSettingsService.instance.scaler.currentSettings;
    final bool isLowSpec = qualitySettings.tier == HardwareTier.eco ||
        qualitySettings.tier == HardwareTier.low ||
        qualitySettings.throttleLevel >= 2;

    return Listener(
      // Zero-Jank: yields background worker budget during user touch
      onPointerDown: (_) => ZeroJankPreloader.instance.onTouchStart(),
      onPointerUp: (_) => ZeroJankPreloader.instance.onTouchEnd(),
      onPointerCancel: (_) => ZeroJankPreloader.instance.onTouchEnd(),
      child: Scaffold(
        backgroundColor: const Color(0xFF030712),
        body: AionSkyParticlesBackground(
          showRays: !isLowSpec,
          primaryAura: const Color(0xFF831843),
          secondaryAura: const Color(0xFF4C0519),
          accentEmissive: AppColors.cyberFuchsia,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.base,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AuthFadeSlide(
                    child: AionRuneCard(
                      accentColor: AppColors.cyberFuchsia,
                      glowColor: const Color(0xFFFF2D55),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // Emblem Header
                          _buildAionHeader(l10n),
                          const SizedBox(height: AppSpacing.base),

                          // Segmented Tabs: switch to login on index 0
                          AionPortalTabs(
                            selectedIndex: 1,
                            onTabChanged: (int index) {
                              if (isLoading) return;
                              if (index == 0) {
                                HapticFeedback.lightImpact();
                                context.go(AppRoutes.login);
                              }
                            },
                            loginLabel: l10n.login.toUpperCase(),
                            registerLabel: l10n.kayit.toUpperCase(),
                            accentColor: AppColors.cyberFuchsia,
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Registration Form
                          Form(
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
                                  autofillHints: const <String>[
                                    AutofillHints.email,
                                  ],
                                  autocorrect: false,
                                  accent: AppColors.cyberFuchsia,
                                  validator: (String? value) =>
                                      AuthValidators.validateEmail(value, l10n),
                                ),
                                const SizedBox(height: AppSpacing.base),
                                AuthField(
                                  controller: _usernameController,
                                  label: l10n.auth_username,
                                  icon: Icons.person_outline_rounded,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const <String>[
                                    AutofillHints.username,
                                  ],
                                  autocorrect: false,
                                  accent: AppColors.cyberFuchsia,
                                  onChanged: _onUsernameChanged,
                                  validator: (String? value) {
                                    final String? base =
                                        AuthValidators.validateUsername(
                                      value,
                                      l10n,
                                    );
                                    if (base != null) return base;
                                    if (_usernameTaken) {
                                      return l10n.auth_username_taken;
                                    }
                                    return null;
                                  },
                                ),
                                if (_checkingUsername ||
                                    _usernameTaken) ...<Widget>[
                                  const SizedBox(height: 6),
                                  Text(
                                    _usernameTaken
                                        ? l10n.auth_username_taken
                                        : '...',
                                    style: AuthDesign.bodyMuted(
                                      color: _usernameTaken
                                          ? AppColors.cyberFuchsia
                                          : AuthDesign.titanium,
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
                                  autofillHints: const <String>[
                                    AutofillHints.newPassword,
                                  ],
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  accent: AppColors.cyberFuchsia,
                                  validator: (String? value) =>
                                      AuthValidators.validatePassword(
                                    value,
                                    l10n,
                                  ),
                                  suffix: IconButton(
                                    onPressed: () => setState(
                                      () => _obscurePassword =
                                          !_obscurePassword,
                                    ),
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
                                  controller: _confirmPasswordController,
                                  label: 'ŞİFRE TEKRAR',
                                  icon: Icons.lock_reset_rounded,
                                  obscureText: _obscureConfirmPassword,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  accent: AppColors.cyberFuchsia,
                                  validator: (String? value) =>
                                      AuthValidators.validatePasswordConfirm(
                                    value,
                                    _passwordController.text,
                                    l10n,
                                  ),
                                  suffix: IconButton(
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                    tooltip: _obscureConfirmPassword
                                        ? l10n.auth_toggle_password_show
                                        : l10n.auth_toggle_password_hide,
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
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
                                  accent: const Color(0xFFFFD700),
                                  onChanged: _onReferralChanged,
                                  onFieldSubmitted: (_) {
                                    if (!isLoading && _canRegister) {
                                      _submitRegister();
                                    }
                                  },
                                ),
                                const SizedBox(height: 6),
                                _referralHint(l10n),
                                const SizedBox(height: AppSpacing.base),

                                // Legal consent & agreements
                                _buildConsentRow(
                                  context: context,
                                  value: _termsAccepted,
                                  onChanged: (bool? v) => setState(
                                    () => _termsAccepted = v == true,
                                  ),
                                  label: 'Kullanım Koşullarını kabul ediyorum',
                                  docType: 'terms',
                                ),
                                _buildConsentRow(
                                  context: context,
                                  value: _privacyAccepted,
                                  onChanged: (bool? v) => setState(
                                    () => _privacyAccepted = v == true,
                                  ),
                                  label: 'Gizlilik Politikasını kabul ediyorum',
                                  docType: 'privacy',
                                ),
                                _buildNotificationConsentSwitch(),
                                const SizedBox(height: AppSpacing.xs),

                                // Community rules gate banner
                                CommunityRulesStatusBanner(
                                  decision: _communityDecision,
                                  onReviewAgain: _reviewCommunityRules,
                                ),
                                const SizedBox(height: AppSpacing.sm),

                                // Register Action Button
                                AuthGoldButton(
                                  label: isLoading
                                      ? l10n.auth_register_loading
                                      : l10n.auth_register_button,
                                  loading: isLoading,
                                  icon: Icons.person_add_rounded,
                                  onPressed: isLoading || !_canRegister
                                      ? null
                                      : _submitRegister,
                                ),
                                const SizedBox(height: AppSpacing.base),

                                // Navigation to Login
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      'Zaten bir hesabın var mı? ',
                                      style: GoogleFonts.urbanist(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        context.go(AppRoutes.login);
                                      },
                                      child: Text(
                                        'Giriş Yap',
                                        style: GoogleFonts.urbanist(
                                          color: const Color(0xFFFFD700),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                          decorationColor:
                                              const Color(0xFFFFD700),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
