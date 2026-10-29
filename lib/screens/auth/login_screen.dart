import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/app_messenger.dart';
import '../../core/services/device_identity_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/auth_validators.dart';
import '../../l10n/l10n.dart';
import '../../models/policy_model.dart';
import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../core/services/app_haptics.dart';
import '../../models/referral_preview_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/policy_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/logout_helper.dart';
import '../settings/graphics_settings_service.dart';
import 'widgets/aion_guest_dialog.dart';
import 'widgets/aion_portal_tabs.dart';
import 'widgets/aion_rune_frame.dart';
import 'widgets/aion_sky_particles.dart';
import 'widgets/auth_design.dart';
import 'widgets/community_rules_gate.dart';
import 'widgets/register_legal_consent.dart';

/// 2027 Aion 2 Mobile Cinematic Login Portal.
/// Features atmospheric sky, animated particle embers, glowing rune borders,
/// dual login/register tabs, guest login CTA, and mobile keyboard safe area (390x844).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.initialTab = 0,
  });

  final int initialTab;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Tabs: 0 = Giriş Yap, 1 = Yeni Kayıt
  late int _selectedTab = widget.initialTab;

  // Login form controllers & state
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  bool _loginObscurePassword = true;
  bool _appleAvailable = false;
  bool _appleChecked = false;
  bool _guestLoading = false;
  bool _rememberMe = true;
  bool _biometricEnabled = false;
  String? _inlineError;

  // Register form controllers & state
  final GlobalKey<FormState> _registerFormKey = GlobalKey<FormState>();
  final TextEditingController _registerEmailController = TextEditingController();
  final TextEditingController _registerUsernameController = TextEditingController();
  final TextEditingController _registerPasswordController = TextEditingController();
  final TextEditingController _registerReferralController = TextEditingController();
  bool _registerObscurePassword = true;
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
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerUsernameController.dispose();
    _registerPasswordController.dispose();
    _registerReferralController.dispose();
    ZeroJankPreloader.instance.cancelByTag('auth_login');
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _probeApple();
      if (_selectedTab == 1) {
        _loadAndShowCommunityRules();
      }
      _prewarmSession();
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
            _registerEmailController.text.trim();
        context.go(
          '${AppRoutes.emailConfirm}?email=${Uri.encodeComponent(email)}',
        );
        return;
      }

      // Registration authenticated handler
      if (next.status == AuthStatus.authenticated) {
        AppHaptics.success();
        if (_selectedTab == 1) {
          _onRegistered();
        }
        return;
      }

      // Error messages
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        AppHaptics.vibrate();
        setState(() => _inlineError = next.errorMessage);
        AppMessenger.showError(context, next.errorMessage!);
        return;
      }

      if (next.status == AuthStatus.unauthenticated &&
          next.errorMessage != null &&
          next.errorMessage!.isNotEmpty) {
        AppHaptics.vibrate();
        setState(() => _inlineError = next.errorMessage);
        AppMessenger.showError(context, next.errorMessage!);
      }
    });
  }

  void _prewarmSession() {
    ZeroJankPreloader.instance.preloadAtomic<void>(
      id: 'auth_login_hud_warmup',
      priority: PreloadPriority.criticalHud,
      targetCache: CacheTarget.ram,
      estimatedSizeBytes: 32 * 1024,
      loader: () async {
        // Fast-path memory cache warmup for post-login screens
      },
      tags: const <String>{'auth_login'},
    );
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

  Future<void> _submitLogin() async {
    final FormState? form = _loginFormKey.currentState;
    if (form == null || !form.validate()) {
      AppHaptics.vibrate();
      return;
    }

    AppHaptics.medium();
    setState(() => _inlineError = null);
    final String deviceId = await DeviceIdentityService.currentId();
    await ref.read(authProvider.notifier).login(
          email: _loginEmailController.text.trim(),
          password: _loginPasswordController.text,
          deviceId: deviceId,
        );
  }

  Future<void> _submitApple() async {
    if (!_appleAvailable) {
      AppMessenger.showError(context, context.l10n.auth_apple_unavailable);
      return;
    }
    AppHaptics.medium();
    setState(() => _inlineError = null);
    final String deviceId = await DeviceIdentityService.currentId();
    await ref.read(authProvider.notifier).signInWithApple(deviceId: deviceId);
  }

  Future<void> _onGuestTapped() async {
    final bool? confirmed = await showAionGuestDialog(context);
    if (confirmed != true || !mounted) return;

    AppHaptics.light();
    setState(() {
      _guestLoading = true;
      _inlineError = null;
    });
    try {
      final String deviceId = await DeviceIdentityService.currentId();
      final String cleanId = deviceId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final String shortId = cleanId.length > 8 ? cleanId.substring(0, 8) : cleanId;
      final String guestEmail = 'guest_@guest.gkk.internal';
      final String guestUser = 'Gezgin_';
      final String guestPass = 'Guest#${shortId.toUpperCase()}2027!';

      // Attempt login first
      await ref.read(authProvider.notifier).login(
            email: guestEmail,
            password: guestPass,
            deviceId: deviceId,
          );

      final AuthState stateAfterLogin = ref.read(authProvider);
      if (stateAfterLogin.status == AuthStatus.authenticated) {
        return;
      }

      // If account does not exist, register device-bound guest
      await ref.read(authProvider.notifier).register(
            email: guestEmail,
            username: guestUser,
            password: guestPass,
            deviceId: deviceId,
          );
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(
          context,
          'Misafir girişi hazırlığı tamamlanamadı. Lütfen doğrudan giriş yapın veya kayıt olun.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _guestLoading = false);
      }
    }
  }

  // --- Register Flow Methods ---
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
      AppHaptics.vibrate();
      AppMessenger.showError(context, 'Kayıt için tüm sözleşmeleri kabul et.');
      return;
    }

    final FormState? form = _registerFormKey.currentState;
    if (form == null || !form.validate()) {
      AppHaptics.vibrate();
      return;
    }

    AppHaptics.medium();
    setState(() => _inlineError = null);

    if (_usernameTaken) {
      AppMessenger.showError(context, context.l10n.auth_username_taken);
      return;
    }

    final ReferralPreview? refPreview = _referralPreview;
    if (_registerReferralController.text.trim().isNotEmpty &&
        refPreview != null &&
        !refPreview.empty &&
        !refPreview.valid) {
      AppMessenger.showError(context, context.l10n.auth_referral_invalid);
      return;
    }

    final String deviceId = await DeviceIdentityService.currentId();
    await ref.read(authProvider.notifier).register(
          email: _registerEmailController.text.trim(),
          username: _registerUsernameController.text.trim(),
          password: _registerPasswordController.text,
          deviceId: deviceId,
          referralCode: _registerReferralController.text.trim().isEmpty
              ? null
              : _registerReferralController.text.trim(),
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
    setState(() => _selectedTab = 0);
  }

  Widget _referralHint(AppLocalizations l10n) {
    Widget child = const SizedBox.shrink();
    if (_referralChecking) {
      child = Text(
        l10n.auth_referral_validating,
        key: const ValueKey<String>('ref_validating'),
        style: AuthDesign.bodyMuted(color: AuthDesign.titanium),
      );
    } else {
      final ReferralPreview? preview = _referralPreview;
      if (preview != null && !preview.empty) {
        if (!preview.valid) {
          child = Text(
            l10n.auth_referral_invalid,
            key: const ValueKey<String>('ref_invalid'),
            style: AuthDesign.bodyMuted(color: AuthDesign.fuchsia),
          );
        } else {
          child = Text(
            l10n.auth_referral_bonus_preview(
              preview.unlockLevel,
              preview.referredGems,
              preview.referrerGems,
            ),
            key: const ValueKey<String>('ref_bonus'),
            style: AuthDesign.bodyMuted(color: AuthDesign.gold),
          );
        }
      }
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authProvider);
    final bool isLoading = authState.status == AuthStatus.loading ||
        _policyBusy ||
        _guestLoading;
    final AppLocalizations l10n = context.l10n;
    final bool showApple = _appleChecked && _appleAvailable;

    // Adaptive Quality Scaler: Scale back atmospheric particles on low-tier/eco hardware
    final bool isLowTier =
        GraphicsSettingsService.instance.scaler.currentTier == HardwareTier.eco ||
        GraphicsSettingsService.instance.scaler.currentTier == HardwareTier.low;

    return Listener(
      // Zero-Jank Touch Yielding: Immediately pause background preloader on user touch
      onPointerDown: (_) => ZeroJankPreloader.instance.onTouchStart(),
      onPointerUp: (_) => ZeroJankPreloader.instance.onTouchEnd(),
      onPointerCancel: (_) => ZeroJankPreloader.instance.onTouchEnd(),
      child: Scaffold(
        backgroundColor: const Color(0xFF030712),
        body: AionSkyParticlesBackground(
          showRays: !isLowTier,
          primaryAura: _selectedTab == 0
              ? const Color(0xFF1E3A8A)
              : const Color(0xFF831843),
          secondaryAura: _selectedTab == 0
              ? const Color(0xFF581C87)
              : const Color(0xFF4C0519),
          accentEmissive: _selectedTab == 0
              ? const Color(0xFFFFD700)
              : AppColors.cyberFuchsia,
          child: SafeArea(
            // Mobile safe area for 390x844 viewport (notch & gesture insets)
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.base,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AuthFadeSlide(
                    child: AionRuneCard(
                      accentColor: _selectedTab == 0
                          ? const Color(0xFFFFD700)
                          : AppColors.cyberFuchsia,
                      glowColor: _selectedTab == 0
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFFFF2D55),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // Cinematic Emblem Header
                          _buildAionHeader(l10n),
                          const SizedBox(height: AppSpacing.base),

                          // Dual Login/Register Segmented Tabs
                          AionPortalTabs(
                            selectedIndex: _selectedTab,
                            onTabChanged: (int index) {
                              if (isLoading) return;
                              AppHaptics.selection();
                              setState(() {
                                _selectedTab = index;
                                _inlineError = null;
                              });
                              if (index == 1) {
                                _loadAndShowCommunityRules();
                              }
                            },
                            loginLabel: l10n.login.toUpperCase(),
                            registerLabel: l10n.kayit.toUpperCase(),
                            accentColor: _selectedTab == 0
                                ? const Color(0xFFFFD700)
                                : AppColors.cyberFuchsia,
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Form body based on active tab
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 260),
                            firstCurve: Curves.easeOutCubic,
                            secondCurve: Curves.easeInCubic,
                            crossFadeState: _selectedTab == 0
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            firstChild: _buildLoginForm(l10n, isLoading, showApple),
                            secondChild: _buildRegisterForm(l10n, isLoading),
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

  Widget _buildAionHeader(AppLocalizations l10n) {
    final Color emblemAccent = _selectedTab == 0
        ? const Color(0xFFFFD700)
        : AppColors.cyberFuchsia;

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
          child: Icon(
            _selectedTab == 0 ? Icons.castle_rounded : Icons.person_add_alt_1_rounded,
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
          _selectedTab == 0
              ? l10n.hesabina_giris_yap_ve_lonca_gelismelerini_canli_ta
              : l10n.auth_register_subtitle,
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

  Widget _buildLoginForm(AppLocalizations l10n, bool isLoading, bool showApple) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Glassmorphic Inline Error Banner
          if (_inlineError != null) ...<Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.cyberFuchsia.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.cyberFuchsia.withValues(alpha: 0.45),
                  width: 1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.cyberFuchsia.withValues(alpha: 0.16),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.cyberFuchsia,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _inlineError!,
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _inlineError = null),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],

          AuthField(
            controller: _loginEmailController,
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
            controller: _loginPasswordController,
            label: l10n.auth_password,
            icon: Icons.lock_outline_rounded,
            obscureText: _loginObscurePassword,
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
              onPressed: () => setState(() => _loginObscurePassword = !_loginObscurePassword),
              tooltip: _loginObscurePassword
                  ? l10n.auth_toggle_password_show
                  : l10n.auth_toggle_password_hide,
              icon: Icon(
                _loginObscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AuthDesign.titanium,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Remember Me & Forgot Password Row
          Row(
            children: <Widget>[
              Transform.scale(
                scale: 0.82,
                alignment: Alignment.centerLeft,
                child: Switch.adaptive(
                  value: _rememberMe,
                  activeColor: const Color(0xFFFFD700),
                  activeTrackColor: const Color(0xFFFFD700).withValues(alpha: 0.38),
                  inactiveThumbColor: AuthDesign.titanium,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                  onChanged: isLoading
                      ? null
                      : (bool val) {
                          AppHaptics.selection();
                          setState(() => _rememberMe = val);
                        },
                ),
              ),
              GestureDetector(
                onTap: isLoading
                    ? null
                    : () {
                        AppHaptics.selection();
                        setState(() => _rememberMe = !_rememberMe);
                      },
                child: Text(
                  'Beni Hatırla',
                  style: GoogleFonts.urbanist(
                    color: const Color(0xFFCBD5E1),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              AuthGhostLink(
                label: l10n.auth_forgot_password_link,
                enabled: !isLoading,
                onPressed: isLoading
                    ? null
                    : () {
                        AppHaptics.light();
                        context.push(AppRoutes.forgotPassword);
                      },
                accent: AuthDesign.titanium,
              ),
            ],
          ),

          // Optional Biometric fast login toggle
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withValues(alpha: 0.03),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.fingerprint_rounded,
                    color: _biometricEnabled ? const Color(0xFF38BDF8) : AuthDesign.titanium,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Biyometrik Hızlı Giriş',
                      style: GoogleFonts.urbanist(
                        color: AuthDesign.textMid,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.75,
                    alignment: Alignment.centerRight,
                    child: Switch.adaptive(
                      value: _biometricEnabled,
                      activeColor: const Color(0xFF38BDF8),
                      activeTrackColor: const Color(0xFF38BDF8).withValues(alpha: 0.38),
                      inactiveThumbColor: AuthDesign.titanium,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                      onChanged: isLoading
                          ? null
                          : (bool val) {
                              AppHaptics.selection();
                              setState(() => _biometricEnabled = val);
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AuthGoldButton(
            label: isLoading ? l10n.auth_login_loading : l10n.auth_login_button,
            loading: isLoading && !_guestLoading,
            onPressed: isLoading ? null : _submitLogin,
          ),
          if (showApple) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.base),

          // Divider with runic diamond
          Row(
            children: <Widget>[
              Expanded(
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.12),
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'V E Y A',
                  style: GoogleFonts.urbanist(
                    color: const Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.12),
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),

          // Aion 2 Mobile Guest Login CTA Button
          AionGuestLoginCta(
            loading: _guestLoading,
            onPressed: isLoading ? null : _onGuestTapped,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(AppLocalizations l10n, bool isLoading) {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Glassmorphic Inline Error Banner
          if (_inlineError != null) ...<Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.cyberFuchsia.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.cyberFuchsia.withValues(alpha: 0.45),
                  width: 1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.cyberFuchsia.withValues(alpha: 0.16),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.cyberFuchsia,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _inlineError!,
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _inlineError = null),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],

          AuthField(
            controller: _registerEmailController,
            label: l10n.auth_email,
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.email],
            autocorrect: false,
            accent: AppColors.cyberFuchsia,
            validator: (String? value) => AuthValidators.validateEmail(value, l10n),
          ),
          const SizedBox(height: AppSpacing.base),
          AuthField(
            controller: _registerUsernameController,
            label: l10n.auth_username,
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.username],
            autocorrect: false,
            accent: AppColors.cyberFuchsia,
            onChanged: _onUsernameChanged,
            validator: (String? value) {
              final String? base = AuthValidators.validateUsername(value, l10n);
              if (base != null) return base;
              if (_usernameTaken) return l10n.auth_username_taken;
              return null;
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: _checkingUsername || _usernameTaken
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _usernameTaken
                          ? l10n.auth_username_taken
                          : '...',
                      style: AuthDesign.bodyMuted(
                        color: _usernameTaken ? AppColors.cyberFuchsia : AuthDesign.titanium,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.base),
          AuthField(
            controller: _registerPasswordController,
            label: l10n.auth_password,
            icon: Icons.lock_outline_rounded,
            obscureText: _registerObscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.newPassword],
            autocorrect: false,
            enableSuggestions: false,
            accent: AppColors.cyberFuchsia,
            validator: (String? value) => AuthValidators.validatePassword(value, l10n),
            suffix: IconButton(
              onPressed: () => setState(() => _registerObscurePassword = !_registerObscurePassword),
              tooltip: _registerObscurePassword
                  ? l10n.auth_toggle_password_show
                  : l10n.auth_toggle_password_hide,
              icon: Icon(
                _registerObscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AuthDesign.titanium,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          AuthField(
            controller: _registerReferralController,
            label: l10n.auth_referral_code,
            icon: Icons.card_giftcard_outlined,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            accent: const Color(0xFFFFD700),
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
    );
  }
}
