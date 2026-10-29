import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/app_messenger.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../core/utils/auth_validators.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_spacing.dart';
import 'widgets/auth_design.dart';
import 'widgets/auth_form_shell.dart';

/// AAA Cinematic Forgot Password Screen for Aion 2.
///
/// Features:
/// - Frosted glass container with luminous neon gold/amber accents.
/// - Clear, reassuring security recovery feedback protocol.
/// - Responsive email input with real-time format indicator and one-tap clear.
/// - ZeroJankTouchScope integration for seamless frame pacing.
/// - Resend cooldown timer and transitional recovery confirmation.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  bool _isSuccessSent = false;
  String _sentToEmail = '';
  Timer? _resendCooldownTimer;
  int _resendCooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
    _emailFocusNode.addListener(_onFocusChanged);

    ref.listenManual<AuthState>(authProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      if (!mounted) return;

      if (next.status == AuthStatus.passwordResetSent) {
        AppMessenger.showSuccess(
          context,
          context.l10n.auth_forgot_password_sent,
        );
        ref.read(authProvider.notifier).acknowledgeTransient();
        HapticFeedback.mediumImpact();
        setState(() {
          _isSuccessSent = true;
          _sentToEmail = _emailController.text.trim();
          _startResendCooldown();
        });
        return;
      }

      if (next.status == AuthStatus.error && next.errorMessage != null) {
        AppMessenger.showError(context, next.errorMessage!);
      }
    });
  }

  void _onEmailChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _startResendCooldown() {
    _resendCooldownTimer?.cancel();
    setState(() => _resendCooldownSeconds = 60);
    _resendCooldownTimer =
        Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
      } else {
        setState(() => _resendCooldownSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _emailController.removeListener(_onEmailChanged);
    _emailFocusNode.removeListener(_onFocusChanged);
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.lightImpact();
    await ref.read(authProvider.notifier).requestPasswordReset(
          email: _emailController.text.trim(),
        );
  }

  Future<void> _resend() async {
    if (_resendCooldownSeconds > 0) return;
    if (_sentToEmail.isEmpty) return;

    HapticFeedback.lightImpact();
    await ref.read(authProvider.notifier).requestPasswordReset(
          email: _sentToEmail,
        );
    if (!mounted) return;
    AppMessenger.showSuccess(
      context,
      context.l10n.auth_forgot_password_sent,
    );
    _startResendCooldown();
  }

  void _goBackToLogin() {
    HapticFeedback.lightImpact();
    ref.read(authProvider.notifier).acknowledgeTransient();
    context.go(AppRoutes.login);
  }

  void _resetFormForRetry() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSuccessSent = false;
    });
  }

  bool get _isEmailValid {
    final String email = _emailController.text.trim();
    return email.isNotEmpty && AuthValidators.emailPattern.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authProvider);
    final bool isLoading = authState.status == AuthStatus.loading;
    final AppLocalizations l10n = context.l10n;

    return ZeroJankTouchScope(
      child: AuthFormShell(
        kind: AuthScreenKind.forgotPassword,
        badge: l10n.auth_forgot_password_title,
        title: l10n.krallik_kapisi,
        subtitle: _isSuccessSent
            ? 'Şifre sıfırlama talimatları e-posta adresinize iletildi.'
            : l10n.auth_forgot_password_subtitle,
        sectionLabel: l10n.auth_form_section,
        footer: AuthGhostLink(
          label: l10n.giris_ekranina_don,
          enabled: !isLoading,
          onPressed: isLoading ? null : _goBackToLogin,
          accent: AuthDesign.gold,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _isSuccessSent
              ? _buildRecoverySuccessCard(l10n, isLoading)
              : _buildRecoveryRequestForm(l10n, isLoading),
        ),
      ),
    );
  }

  Widget _buildRecoveryRequestForm(AppLocalizations l10n, bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey<String>('recovery_form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildSecurityProtocolBox(),
          const SizedBox(height: AppSpacing.base),
          AuthField(
            controller: _emailController,
            label: l10n.auth_email,
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.email],
            autocorrect: false,
            accent: AuthDesign.gold,
            onFieldSubmitted: (_) {
              if (!isLoading) _submit();
            },
            validator: (String? value) =>
                AuthValidators.validateEmail(value, l10n),
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_isEmailValid)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10B981).withValues(alpha: 0.20),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.60),
                        width: 1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Color(0xFF34D399),
                    ),
                  ),
                if (_emailController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: AuthDesign.titanium,
                    ),
                    tooltip: 'Temizle',
                    splashRadius: 18,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _emailController.clear();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthGoldButton(
            label: isLoading
                ? l10n.auth_forgot_password_loading
                : l10n.auth_forgot_password_button,
            loading: isLoading,
            icon: Icons.send_rounded,
            onPressed: isLoading ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityProtocolBox() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AuthDesign.gold.withValues(alpha: 0.30),
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AuthDesign.navy.withValues(alpha: 0.85),
                AuthDesign.void_.withValues(alpha: 0.92),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AuthDesign.gold.withValues(alpha: 0.12),
                blurRadius: 18,
                spreadRadius: -3,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          AuthDesign.gold.withValues(alpha: 0.28),
                          AuthDesign.obsidian.withValues(alpha: 0.90),
                        ],
                      ),
                      border: Border.all(
                        color: AuthDesign.gold.withValues(alpha: 0.50),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AuthDesign.gold.withValues(alpha: 0.25),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AuthDesign.gold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AuthDesign.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AuthDesign.gold.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'GÜVENLİ KURTARMA PROTOKOLÜ // 256-BIT SSL',
                            style: GoogleFonts.urbanist(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: AuthDesign.gold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aion Muhafız Güvenlik Hattı',
                          style: GoogleFonts.urbanist(
                            color: AuthDesign.textHi,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Kayıtlı e-posta adresinizi girdiğinizde, tek kullanımlık ve zaman sınırlı bir şifre yenileme bağlantısı tarafınıza iletilecektir.',
                style: GoogleFonts.urbanist(
                  color: AuthDesign.textMid,
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildSecurityGuidelineItem(
                icon: Icons.timer_outlined,
                accentColor: const Color(0xFF38BDF8),
                text: 'Kurtarma bağlantısı 15 dakika boyunca aktiftir.',
              ),
              const SizedBox(height: 4),
              _buildSecurityGuidelineItem(
                icon: Icons.mark_email_unread_outlined,
                accentColor: const Color(0xFF38BDF8),
                text:
                    'Gelen kutunuzu ve gereksiz (spam) klasörünüzü kontrol edin.',
              ),
              const SizedBox(height: 4),
              _buildSecurityGuidelineItem(
                icon: Icons.verified_user_outlined,
                accentColor: AuthDesign.gold,
                text: 'Muhafızlar şifrenizi veya bağlantınızı asla talep etmez.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityGuidelineItem({
    required IconData icon,
    required Color accentColor,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 14, color: accentColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.urbanist(
              color: AuthDesign.textMid.withValues(alpha: 0.90),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecoverySuccessCard(AppLocalizations l10n, bool isLoading) {
    return ClipRRect(
      key: const ValueKey<String>('recovery_success'),
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.40),
              width: 1.4,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AuthDesign.navy.withValues(alpha: 0.90),
                AuthDesign.void_.withValues(alpha: 0.95),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.20),
                blurRadius: 24,
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        const Color(0xFF10B981).withValues(alpha: 0.30),
                        const Color(0xFF10B981).withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.60),
                      width: 1.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    color: Color(0xFF34D399),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                'Kurtarma Bağlantısı İletildi',
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  color: AuthDesign.textHi,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Şifre sıfırlama talimatları belirtilen adrese başarıyla gönderildi:',
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  color: AuthDesign.textMid,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AuthDesign.obsidian.withValues(alpha: 0.85),
                  border: Border.all(
                    color: AuthDesign.gold.withValues(alpha: 0.40),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AuthDesign.gold.withValues(alpha: 0.12),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.alternate_email_rounded,
                      color: AuthDesign.gold,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _sentToEmail,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.urbanist(
                          color: AuthDesign.gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildSecurityGuidelineItem(
                      icon: Icons.mark_email_read_outlined,
                      accentColor: const Color(0xFF10B981),
                      text: 'E-postanızdaki güvenli bağlantıya tıklayın.',
                    ),
                    const SizedBox(height: 6),
                    _buildSecurityGuidelineItem(
                      icon: Icons.lock_reset_rounded,
                      accentColor: const Color(0xFF38BDF8),
                      text:
                          'Açılan ekranda yeni güçlü parolanızı belirleyin.',
                    ),
                    const SizedBox(height: 6),
                    _buildSecurityGuidelineItem(
                      icon: Icons.shield_moon_outlined,
                      accentColor: AuthDesign.gold,
                      text:
                          'İşlem tamamlandığında yeni şifrenizle giriş yapın.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AuthGoldButton(
                label: l10n.giris_ekranina_don,
                icon: Icons.arrow_back_rounded,
                onPressed: _goBackToLogin,
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: (_resendCooldownSeconds == 0 && !isLoading)
                      ? _resend
                      : null,
                  child: Text(
                    _resendCooldownSeconds > 0
                        ? 'Tekrar Gönder ($_resendCooldownSeconds sn)'
                        : 'E-postayı Tekrar Gönder',
                    style: GoogleFonts.urbanist(
                      color: _resendCooldownSeconds > 0
                          ? AuthDesign.textLow
                          : AuthDesign.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _resetFormForRetry,
                  child: Text(
                    'Farklı bir e-posta adresi dene',
                    style: GoogleFonts.urbanist(
                      color: AuthDesign.textMid,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
