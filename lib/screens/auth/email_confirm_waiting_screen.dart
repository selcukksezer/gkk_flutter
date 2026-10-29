import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/app_messenger.dart';
import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../settings/graphics_settings_provider.dart';
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
    extends ConsumerState<EmailConfirmWaitingScreen>
    with SingleTickerProviderStateMixin {
  bool _resending = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );

    // Warmup HUD telemetry and preloader caches
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ZeroJankPreloader.instance.preloadAtomic<bool>(
        id: 'auth_email_confirm_hud_warmup',
        priority: PreloadPriority.criticalHud,
        loader: () async => true,
        tags: const <String>{'auth', 'email_confirm'},
      );
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  String? get _email {
    final AuthState auth = ref.watch(authProvider);
    final String? fromState = auth.pendingEmail ?? auth.user?.email;
    if (fromState != null && fromState.isNotEmpty) return fromState;
    final String? fromArg = widget.email?.trim();
    if (fromArg != null && fromArg.isNotEmpty) return fromArg;
    return null;
  }

  Future<void> _resend() async {
    if (_resending || _cooldownSeconds > 0) return;
    HapticFeedback.lightImpact();
    ZeroJankPreloader.instance.onTouchStart();
    setState(() => _resending = true);
    try {
      await ref.read(authProvider.notifier).resendSignupConfirmation(
            email: _email,
          );
      if (!mounted) return;
      final AuthState next = ref.read(authProvider);
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        HapticFeedback.heavyImpact();
        AppMessenger.showError(context, next.errorMessage!);
      } else {
        HapticFeedback.mediumImpact();
        _startCooldown(60);
        AppMessenger.showSuccess(context, context.l10n.auth_email_confirm_resent);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        AppMessenger.showError(context, e.toString());
      }
    } finally {
      ZeroJankPreloader.instance.onTouchEnd();
      if (mounted) setState(() => _resending = false);
    }
  }

  void _goLogin() {
    HapticFeedback.selectionClick();
    ref.read(authProvider.notifier).acknowledgeTransient();
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? email = _email;
    final bool busy = _resending;
    final bool onCooldown = _cooldownSeconds > 0;

    // Adaptive performance tier hook for glass blur optimization
    final ScalerTelemetry telemetry = ref.watch(scalerTelemetryProvider);
    final bool isLowTier = telemetry.tier == HardwareTier.eco ||
        telemetry.tier == HardwareTier.low;
    final double blurSigma = isLowTier ? 4.0 : 16.0;

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
          // Pulsing Hourglass / Chronometer Badge
          _PulsingHourglassBadge(
            pulseAnimation: _pulseAnimation,
            accentColor: AuthDesign.gold,
            glowColor: const Color(0xFF38BDF8),
          ),
          const SizedBox(height: AppSpacing.md),

          // Status Chip: Awaiting Confirmation
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: LinearGradient(
                  colors: <Color>[
                    AuthDesign.gold.withValues(alpha: 0.16),
                    const Color(0xFF38BDF8).withValues(alpha: 0.10),
                  ],
                ),
                border: Border.all(
                  color: AuthDesign.gold.withValues(alpha: 0.45),
                  width: 1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AuthDesign.gold.withValues(alpha: 0.15),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (BuildContext context, Widget? _) {
                      return Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AuthDesign.gold,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AuthDesign.gold.withValues(
                                alpha: 0.5 + _pulseAnimation.value * 0.5,
                              ),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.auth_email_confirm_title.toUpperCase(),
                    style: AuthDesign.sectionCaps(color: AuthDesign.gold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Frosted Glass Bento Container
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xEE0B1222), // Deep Obsidian Astral Navy
                      Color(0xF804060E), // Celestial Void
                    ],
                  ),
                  border: Border.all(
                    color: AuthDesign.gold.withValues(alpha: 0.32),
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AuthDesign.gold.withValues(alpha: 0.10),
                      blurRadius: 28,
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: <Widget>[
                    // Top specular highlight line
                    Positioned(
                      top: 0,
                      left: 18,
                      right: 18,
                      child: IgnorePointer(
                        child: Container(
                          height: 1.2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                Colors.transparent,
                                AuthDesign.gold.withValues(alpha: 0.70),
                                const Color(0xFF38BDF8).withValues(alpha: 0.50),
                                Colors.transparent,
                              ],
                              stops: const <double>[0.0, 0.45, 0.55, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Inner card contents
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            l10n.auth_email_confirm_body,
                            style: AuthDesign.bodyMuted(color: AuthDesign.textMid),
                          ),
                          if (email != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.base),
                            // Recipient email capsule
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.base,
                                vertical: AppSpacing.sm + 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black.withValues(alpha: 0.45),
                                border: Border.all(
                                  color: AuthDesign.gold.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: AuthDesign.gold.withValues(alpha: 0.14),
                                    ),
                                    child: const Icon(
                                      Icons.mail_outline_rounded,
                                      color: AuthDesign.gold,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: SelectableText(
                                      email,
                                      style: GoogleFonts.urbanist(
                                        color: AuthDesign.textHi,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.base),
                          // Security notice & tip
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(
                                Icons.info_outline_rounded,
                                size: 15,
                                color: AuthDesign.textLow,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Spam / gereksiz kutunuzu kontrol etmeyi unutmayınız. Doğrulama bağlantısı 24 saat geçerlidir.',
                                  style: GoogleFonts.urbanist(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AuthDesign.textLow,
                                    height: 1.35,
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
          const SizedBox(height: AppSpacing.lg),

          // Resend Cooldown Progress Bar
          if (onCooldown) ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (60 - _cooldownSeconds) / 60.0,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(AuthDesign.gold),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Clean Action Button: Resend Confirmation
          AuthGoldButton(
            label: busy
                ? l10n.auth_email_confirm_resend_loading
                : onCooldown
                    ? '${l10n.auth_email_confirm_resend} (${_cooldownSeconds}s)'
                    : l10n.auth_email_confirm_resend,
            loading: busy,
            icon: onCooldown
                ? Icons.timer_outlined
                : Icons.mark_email_unread_outlined,
            onPressed: (busy || onCooldown) ? null : _resend,
          ),
        ],
      ),
    );
  }
}

class _PulsingHourglassBadge extends StatelessWidget {
  const _PulsingHourglassBadge({
    required this.pulseAnimation,
    required this.accentColor,
    required this.glowColor,
  });

  final Animation<double> pulseAnimation;
  final Color accentColor;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (BuildContext context, Widget? _) {
        final double pulse = pulseAnimation.value;
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // 1. Ambient pulsing aura
              Container(
                width: 92 + pulse * 14,
                height: 92 + pulse * 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      glowColor.withValues(alpha: 0.16 + pulse * 0.14),
                      accentColor.withValues(alpha: 0.08 + pulse * 0.10),
                      Colors.transparent,
                    ],
                    stops: const <double>[0.0, 0.65, 1.0],
                  ),
                ),
              ),
              // 2. Outer glowing ring
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.40 + pulse * 0.35),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.20 + pulse * 0.20),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              // 3. Inner glass orb with obsidian fill
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AuthDesign.obsidian.withValues(alpha: 0.95),
                      AuthDesign.navy.withValues(alpha: 0.90),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: math.sin(pulse * math.pi) * 0.08,
                    child: Transform.scale(
                      scale: 1.0 + pulse * 0.06,
                      child: Icon(
                        Icons.hourglass_top_rounded,
                        color: accentColor,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

