import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../core/utils/provider_scheduling.dart';
import '../../providers/auth_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../settings/graphics_settings_service.dart';
import 'widgets/aion_rune_frame.dart';
import 'widgets/aion_sky_particles.dart';
import 'widgets/auth_design.dart';

/// 2027 AAA Cinematic Splash & Engine Warmup Screen.
///
/// Coordinates:
/// - [AdaptiveQualityScaler] hardware tier detection & early boot configuration.
/// - [ZeroJankPreloader] critical HUD asset caching & telemetry warmup.
/// - Frosted runic glassmorphism UI ([AionSkyParticlesBackground] & [AionRuneCard]).
/// - Robust error recovery handling with retry & fallback navigation options.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  // Boot sequence state
  bool _bootSequenceFinished = false;
  VoidCallback? _pendingNavigation;
  String _statusMessage = 'Gök Kurt evreni başlatılıyor...';
  String? _errorMessage;
  double _warmupProgress = 0.15;
  HardwareTier _detectedTier = HardwareTier.mid;
  double _targetFps = 60.0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseAnim = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );

    ref.listenManual<AuthState>(authProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      if (!mounted) return;

      // Session already persisted → refresh router so redirect is the single source.
      if (next.status == AuthStatus.authenticated) {
        if (_bootSequenceFinished) {
          GoRouter.of(context).refresh();
        } else {
          _pendingNavigation = () {
            if (mounted) GoRouter.of(context).refresh();
          };
        }
        return;
      }

      if (next.status == AuthStatus.unauthenticated) {
        if (_bootSequenceFinished) {
          context.go(AppRoutes.login);
        } else {
          _pendingNavigation = () {
            if (mounted) context.go(AppRoutes.login);
          };
        }
        return;
      }

      if (next.status == AuthStatus.error) {
        setState(() {
          _errorMessage = next.errorMessage ??
              'Oturum bilgileri doğrulanamadı. Bağlantınızı kontrol edip tekrar deneyiniz.';
        });
      }
    });

    deferProviderUpdate(() {
      _runEarlyBootSequence();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runEarlyBootSequence() async {
    try {
      // Step 1: Early boot AdaptiveQualityScaler initialization & hardware tier auto-detection
      if (mounted) {
        setState(() {
          _statusMessage = 'Grafik motoru donanım profili taranıyor...';
          _warmupProgress = 0.35;
        });
      }

      final GraphicsSettingsService graphicsService = GraphicsSettingsService.instance;
      if (!graphicsService.isLoaded) {
        await graphicsService.load();
      }

      final AdaptiveQualityScaler scaler = graphicsService.scaler;
      final HardwareTier hardwareTier = scaler.currentTier;
      final double targetFps = scaler.targetFps;

      if (mounted) {
        setState(() {
          _detectedTier = hardwareTier;
          _targetFps = targetFps;
          _statusMessage = 'Sıfır gecikme önbelleği ısıtılıyor...';
          _warmupProgress = 0.65;
        });
      }

      // Step 2: ZeroJankPreloader warmup hook
      final ZeroJankPreloader preloader = ZeroJankPreloader.instance;
      await preloader.preloadAtomic<bool>(
        id: 'splash_early_boot_warmup',
        priority: PreloadPriority.criticalHud,
        loader: () async {
          // Record baseline frame telemetry into scaler
          scaler.recordFrameTime(1000.0 / targetFps);
          return true;
        },
      );

      if (mounted) {
        setState(() {
          _statusMessage = 'Kullanıcı oturumu doğrulanıyor...';
          _warmupProgress = 0.90;
        });
      }

      // Step 3: Trigger auth session load
      await ref.read(authProvider.notifier).loadSession();

      if (mounted) {
        setState(() {
          _warmupProgress = 1.0;
          _bootSequenceFinished = true;
        });

        if (_pendingNavigation != null) {
          final VoidCallback nav = _pendingNavigation!;
          _pendingNavigation = null;
          nav();
        } else {
          final AuthStatus currentStatus = ref.read(authProvider).status;
          if (currentStatus == AuthStatus.authenticated) {
            GoRouter.of(context).refresh();
          } else if (currentStatus == AuthStatus.unauthenticated) {
            context.go(AppRoutes.login);
          } else if (currentStatus == AuthStatus.error) {
            setState(() {
              _errorMessage = ref.read(authProvider).errorMessage ??
                  'Oturum bilgileri doğrulanamadı. Bağlantınızı kontrol edip tekrar deneyiniz.';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Başlatma sırasında beklenmeyen bir hata oluştu: $e';
        });
      }
    }
  }

  void _retryBoot() {
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      _statusMessage = 'Yeniden bağlanılıyor ve motor hazırlanıyor...';
      _warmupProgress = 0.20;
      _bootSequenceFinished = false;
      _pendingNavigation = null;
    });
    _runEarlyBootSequence();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: AionSkyParticlesBackground(
        showRays: true,
        primaryAura: const Color(0xFF0F1E3D),
        secondaryAura: const Color(0xFF28103A),
        accentEmissive: AppColors.liquidGold,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AionRuneCard(
                borderRadius: 24,
                accentColor: AppColors.liquidGold,
                glowColor: AppColors.accentCyan,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _buildCrest(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildBrandTypography(),
                    const SizedBox(height: AppSpacing.xl),
                    if (_errorMessage != null)
                      _buildErrorRecovery()
                    else
                      _buildWarmupProgress(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildEngineTierBadge(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCrest() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (BuildContext context, Widget? child) {
        final double scale = 1.0 + (_pulseAnim.value * 0.04);
        final double glowAlpha = 0.25 + (_pulseAnim.value * 0.25);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  AppColors.liquidGold.withValues(alpha: 0.35),
                  AppColors.bgSurface.withValues(alpha: 0.95),
                ],
              ),
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.60),
                width: 1.8,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.liquidGold.withValues(alpha: glowAlpha),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppColors.accentCyan.withValues(alpha: glowAlpha * 0.5),
                  blurRadius: 32,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.liquidGold,
              size: 42,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBrandTypography() {
    return Column(
      children: <Widget>[
        Text(
          'GÖK KURT',
          style: GoogleFonts.cinzel(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 4.0,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'KRALLIK ÇAĞI • 2027',
          style: GoogleFonts.urbanist(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: AppColors.liquidGold,
          ),
        ),
      ],
    );
  }

  Widget _buildWarmupProgress() {
    return Column(
      children: <Widget>[
        _buildProgressBar(),
        const SizedBox(height: AppSpacing.md),
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 8,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.borderDefault.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0.05, end: _warmupProgress.clamp(0.05, 1.0)),
          builder: (BuildContext context, double value, Widget? child) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: <Color>[
                      AppColors.accentCyan,
                      AppColors.liquidGold,
                      AppColors.goldLight,
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorRecovery() {
    return Column(
      children: <Widget>[
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.danger.withValues(alpha: 0.16),
            border: Border.all(
              color: AppColors.danger.withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.danger.withValues(alpha: 0.35),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.danger,
            size: 30,
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Text(
          'BAĞLANTI GEREKİYOR',
          style: GoogleFonts.urbanist(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AuthGoldButton(
          label: 'YENİDEN DENE',
          icon: Icons.refresh_rounded,
          onPressed: _retryBoot,
        ),
        const SizedBox(height: AppSpacing.sm),
        AuthPressable(
          onTap: () {
            HapticFeedback.selectionClick();
            context.go(AppRoutes.login);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              'GİRİŞ EKRANINA DEVAM ET',
              style: GoogleFonts.urbanist(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: AppColors.liquidGold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEngineTierBadge() {
    final String tierName = _detectedTier.name.toUpperCase();
    final int fpsInt = _targetFps.toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.borderBright.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.speed_rounded,
            size: 13,
            color: _detectedTier == HardwareTier.high
                ? AppColors.accentCyan
                : (_detectedTier == HardwareTier.mid
                    ? AppColors.liquidGold
                    : AppColors.textSecondary),
          ),
          const SizedBox(width: 6),
          Text(
            'ENGINE TIER $tierName • $fpsInt FPS • ZERO-JANK',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
