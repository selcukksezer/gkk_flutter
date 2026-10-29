import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../core/services/app_haptics.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/support_provider.dart';
import '../../routing/app_router.dart';
import '../../screens/settings/graphics_settings_provider.dart';
import '../../screens/settings/graphics_settings_service.dart';
import '../../screens/settings/widgets/settings_design.dart';
import '../../screens/support/widgets/support_design.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// AAA authoritative security enforcement screen for suspended / banned accounts.
///
/// Implements deep ruby/crimson ambient lighting, frosted glass shield hero with
/// Aion realm rune accents, detailed sanction reason breakdown, in-screen appeal
/// bottom sheet submission, live ban status re-evaluation, and ZeroJank preloader hooks.
class BannedScreen extends ConsumerStatefulWidget {
  const BannedScreen({super.key});

  @override
  ConsumerState<BannedScreen> createState() => _BannedScreenState();
}

class _BannedScreenState extends ConsumerState<BannedScreen>
    with SingleTickerProviderStateMixin {
  String? _reason;
  DateTime? _until;
  bool _loading = true;
  bool _checking = false;
  bool _loggingOut = false;

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
        id: 'auth_banned_screen_hud_warmup',
        priority: PreloadPriority.criticalHud,
        loader: () async => true,
        tags: const <String>{'auth', 'banned'},
      );
    });

    unawaited(_load());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _accountReference {
    final String? uid = SupabaseService.client.auth.currentUser?.id;
    if (uid != null && uid.length >= 8) {
      return uid.substring(0, 8).toUpperCase();
    }
    return 'SEC-7701';
  }

  Future<void> _load() async {
    try {
      final dynamic raw = await SupabaseService.client.rpc('get_my_ban_status');
      if (raw is Map && raw['success'] == true && raw['is_banned'] == true) {
        if (mounted) {
          setState(() {
            _reason = raw['ban_reason']?.toString();
            _until = raw['banned_until'] != null
                ? DateTime.tryParse(raw['banned_until'].toString())?.toLocal()
                : null;
            _loading = false;
          });
        }
        return;
      }
      if (mounted) context.go(AppRoutes.home);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkStatus() async {
    if (_checking) return;
    setState(() => _checking = true);
    AppHaptics.selection();
    ZeroJankPreloader.instance.onTouchStart();
    try {
      final dynamic raw = await SupabaseService.client.rpc('get_my_ban_status');
      if (raw is Map && raw['success'] == true) {
        if (raw['is_banned'] != true) {
          AppHaptics.success();
          if (mounted) {
            AppMessenger.showSuccess(
              context,
              'Askı durumu kaldırıldı! Oyuna yönlendiriliyorsunuz...',
            );
            context.go(AppRoutes.home);
          }
          return;
        } else {
          AppHaptics.heavy();
          if (mounted) {
            setState(() {
              _reason = raw['ban_reason']?.toString();
              _until = raw['banned_until'] != null
                  ? DateTime.tryParse(raw['banned_until'].toString())?.toLocal()
                  : null;
            });
            AppMessenger.showInfo(
              context,
              'Hesap kısıtlama durumu halen aktiftir.',
            );
          }
        }
      } else {
        if (mounted) {
          AppMessenger.showWarning(
            context,
            'Sunucu yanıt vermedi. Lütfen tekrar deneyiniz.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(
          context,
          'Durum kontrolü gerçekleştirilemedi: $e',
        );
      }
    } finally {
      ZeroJankPreloader.instance.onTouchEnd();
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    AppHaptics.selection();
    ZeroJankPreloader.instance.onTouchStart();
    try {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
      if (mounted) context.go(AppRoutes.login);
    } finally {
      ZeroJankPreloader.instance.onTouchEnd();
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _copyReferenceCode() async {
    await Clipboard.setData(ClipboardData(text: '#BAN-$_accountReference'));
    AppHaptics.selection();
    if (mounted) {
      AppMessenger.showSuccess(
        context,
        'Denetim referans kodu panoya kopyalandı.',
      );
    }
  }

  void _openAppealSheet() {
    AppHaptics.selection();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _BanAppealSheet(
          accountReference: _accountReference,
          banReason: _reason,
          until: _until,
        );
      },
    );
  }

  String _formatUntil(DateTime? until) {
    if (until == null) return 'Kalıcı (Süresiz Kısıtlama)';
    return '${until.day.toString().padLeft(2, '0')}.${until.month.toString().padLeft(2, '0')}.${until.year} '
        '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final GraphicsConfigData graphicsConfig = ref.watch(graphicsSettingsProvider);
    final bool isLowSpec = graphicsConfig.tier == GraphicsQualityTier.eco ||
        graphicsConfig.tier == GraphicsQualityTier.low;
    final double blurSigma = isLowSpec ? 0.0 : 12.0;

    if (_loading) {
      return Scaffold(
        backgroundColor: SettingsPalette.void_,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(
                color: SettingsPalette.ruby,
                strokeWidth: 2.4,
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                'GÜVENLİK PROTOKOLÜ DENETLENİYOR...',
                style: AppTextStyles.caption.copyWith(
                  color: SettingsPalette.titanium,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SettingsPalette.void_,
      body: GameScreenBackground(
        showAmbientGlow: false,
        child: Stack(
          children: <Widget>[
            // Top Crimson Ambient Aura
            Positioned(
              top: -120,
              right: -80,
              child: IgnorePointer(
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        SettingsPalette.ruby.withValues(alpha: isLowSpec ? 0.08 : 0.20),
                        SettingsPalette.ruby.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Mystic Fuchsia Ambient Aura
            Positioned(
              bottom: -140,
              left: -100,
              child: IgnorePointer(
                child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        SettingsPalette.fuchsia.withValues(alpha: isLowSpec ? 0.06 : 0.15),
                        SettingsPalette.fuchsia.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Subtle Vertical Security Grid Beam
            Positioned(
              top: 0,
              bottom: 0,
              left: MediaQuery.sizeOf(context).width * 0.5 - 0.75,
              child: IgnorePointer(
                child: Container(
                  width: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        SettingsPalette.ruby.withValues(alpha: 0.25),
                        SettingsPalette.ruby.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Main Content Area
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // Pulsing Ruby Frosted Shield Hero
                        _PulsingRubyShieldHero(
                          pulseAnimation: _pulseAnimation,
                          blurSigma: blurSigma,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Realm Protocol Status Chip
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              gradient: LinearGradient(
                                colors: <Color>[
                                  SettingsPalette.ruby.withValues(alpha: 0.22),
                                  SettingsPalette.obsidian.withValues(alpha: 0.65),
                                ],
                              ),
                              border: Border.all(
                                color: SettingsPalette.ruby.withValues(alpha: 0.55),
                                width: 1.1,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: SettingsPalette.ruby.withValues(alpha: 0.22),
                                  blurRadius: 12,
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
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: SettingsPalette.ruby,
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(
                                            color: SettingsPalette.ruby.withValues(
                                              alpha: 0.5 + _pulseAnimation.value * 0.5,
                                            ),
                                            blurRadius: 8,
                                            spreadRadius: 1.5,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'GÜVENLİK PROTOKOLÜ // SEVİYE 4 ASKI',
                                  style: GoogleFonts.urbanist(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                    color: SettingsPalette.ruby,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Screen Title & Subtitle
                        Text(
                          'HESAP ASKIYA ALINDI',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.urbanist(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                            color: SettingsPalette.textHi,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Krallık Muhafızları tarafından hesap erişimi geçici veya kalıcı olarak durdurulmuştur.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: SettingsPalette.textMid,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Sanction Reason Breakdown Glass Card
                        _ReasonBreakdownCard(
                          reason: _reason,
                          untilFormatted: _formatUntil(_until),
                          isPermanent: _until == null,
                          accountReference: _accountReference,
                          blurSigma: blurSigma,
                          onCopyReference: _copyReferenceCode,
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Appeal CTA Button
                        SettingsPressable(
                          onTap: _openAppealSheet,
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  Color(0xFFE52E2E),
                                  Color(0xFFB51A45),
                                ],
                              ),
                              border: Border.all(
                                color: const Color(0xFFFF5252).withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: SettingsPalette.ruby.withValues(alpha: 0.40),
                                  blurRadius: 18,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(
                                  Icons.assignment_late_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'İTİRAZ TALEBİ OLUŞTUR',
                                  style: GoogleFonts.urbanist(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm + 2),

                        // Re-check Status Button
                        SettingsOutlineButton(
                          label: _checking ? 'KONTROL EDİLİYOR...' : 'ASKI DURUMUNU KONTROL ET',
                          icon: Icons.refresh_rounded,
                          accent: SettingsPalette.gold,
                          onPressed: _checking ? null : _checkStatus,
                        ),
                        const SizedBox(height: AppSpacing.sm + 2),

                        // Logout Danger Button
                        SettingsDangerButton(
                          label: _loggingOut ? 'ÇIKIŞ YAPILIYOR...' : 'GÜVENLİ ÇIKIŞ YAP',
                          icon: Icons.logout_rounded,
                          onPressed: _loggingOut ? null : _logout,
                        ),
                        const SizedBox(height: AppSpacing.base),

                        // Footer Guidance Note
                        Center(
                          child: Text(
                            'İtiraz başvuruları 24-48 saat içerisinde değerlendirilir.\nKararlar Krallık Güvenlik Standartlarına tabidir.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              color: SettingsPalette.titanium.withValues(alpha: 0.75),
                              fontSize: 11,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing Frosted Glass Shield Hero Widget with ancient Aion runic sigils.
class _PulsingRubyShieldHero extends StatelessWidget {
  const _PulsingRubyShieldHero({
    required this.pulseAnimation,
    required this.blurSigma,
  });

  final Animation<double> pulseAnimation;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: pulseAnimation,
        builder: (BuildContext context, Widget? child) {
          final double t = pulseAnimation.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Aion Realm Runic Inscription Top
              Text(
                '✦ ᚱ ᛖ ᛊ ᛏ ᚱ ᛁ ᚲ ᛏ ᛖ ᛞ ✦',
                style: GoogleFonts.cinzel(
                  fontSize: 10,
                  letterSpacing: 3.5,
                  fontWeight: FontWeight.w700,
                  color: SettingsPalette.ruby.withValues(alpha: 0.65 + t * 0.35),
                ),
              ),
              const SizedBox(height: 8),

              // Shield Glass Orb
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      SettingsPalette.ruby.withValues(alpha: 0.28 + t * 0.16),
                      SettingsPalette.void_.withValues(alpha: 0.85),
                    ],
                  ),
                  border: Border.all(
                    color: SettingsPalette.ruby.withValues(alpha: 0.55 + t * 0.35),
                    width: 1.8,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: SettingsPalette.ruby.withValues(alpha: 0.25 + t * 0.30),
                      blurRadius: 26,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                    child: Center(
                      child: Icon(
                        Icons.gpp_bad_rounded,
                        size: 46,
                        color: SettingsPalette.ruby,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Aion Realm Runic Inscription Bottom
              Text(
                'ᛟ ᚱ ᚦ ᚲ',
                style: GoogleFonts.cinzel(
                  fontSize: 9,
                  letterSpacing: 4.0,
                  fontWeight: FontWeight.w600,
                  color: SettingsPalette.titanium.withValues(alpha: 0.55),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bento-style Glass Breakdown Card for sanction details.
class _ReasonBreakdownCard extends StatelessWidget {
  const _ReasonBreakdownCard({
    required this.reason,
    required this.untilFormatted,
    required this.isPermanent,
    required this.accountReference,
    required this.blurSigma,
    required this.onCopyReference,
  });

  final String? reason;
  final String untilFormatted;
  final bool isPermanent;
  final String accountReference;
  final double blurSigma;
  final VoidCallback onCopyReference;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                SettingsPalette.navy.withValues(alpha: 0.94),
                SettingsPalette.void_.withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(
              color: SettingsPalette.ruby.withValues(alpha: 0.40),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: SettingsPalette.ruby.withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              // Specular Top Highlight Line
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Container(
                    height: 1.2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          SettingsPalette.ruby.withValues(alpha: 0.75),
                          SettingsPalette.fuchsia.withValues(alpha: 0.50),
                          Colors.transparent,
                        ],
                        stops: const <double>[0.0, 0.4, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // Card Inner Layout
              Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SettingsSectionHeader(
                      icon: Icons.gavel_rounded,
                      title: 'YAPTIRIM BİLGİLERİ',
                      subtitle: 'Muhafız Konseyi ve Güvenlik Dökümü',
                      accent: SettingsPalette.ruby,
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // Violation Reason Row
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: SettingsPalette.obsidian.withValues(alpha: 0.65),
                        border: Border.all(
                          color: SettingsPalette.ruby.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.report_gmailerrorred_rounded,
                                size: 16,
                                color: SettingsPalette.ruby,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'İHLAL NEDENİ',
                                style: GoogleFonts.urbanist(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: SettingsPalette.titanium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reason ?? 'Topluluk Kuralları ve Hizmet Şartları İhlali',
                            style: AppTextStyles.body.copyWith(
                              color: SettingsPalette.textHi,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),

                    // Sanction Period Row
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: SettingsPalette.obsidian.withValues(alpha: 0.50),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: isPermanent
                                ? SettingsPalette.ruby
                                : SettingsPalette.gold,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'GEÇERLİLİK SÜRESİ',
                                  style: GoogleFonts.urbanist(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: SettingsPalette.titanium,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  untilFormatted,
                                  style: AppTextStyles.captionBold.copyWith(
                                    color: SettingsPalette.textHi,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: (isPermanent
                                      ? SettingsPalette.ruby
                                      : SettingsPalette.gold)
                                  .withValues(alpha: 0.18),
                              border: Border.all(
                                color: (isPermanent
                                        ? SettingsPalette.ruby
                                        : SettingsPalette.gold)
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              isPermanent ? 'KALICI MEN' : 'GEÇİCİ ASKI',
                              style: GoogleFonts.urbanist(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: isPermanent
                                    ? SettingsPalette.ruby
                                    : SettingsPalette.gold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),

                    // Audit Reference ID Row with Copy Action
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: SettingsPalette.obsidian.withValues(alpha: 0.50),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.fingerprint_rounded,
                            size: 16,
                            color: SettingsPalette.titanium,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'DENETİM PROTOKOL REFERANSI',
                                  style: GoogleFonts.urbanist(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: SettingsPalette.titanium,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '#BAN-$accountReference',
                                  style: GoogleFonts.sourceCodePro(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: SettingsPalette.gold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: onCopyReference,
                            icon: const Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: SettingsPalette.titanium,
                            ),
                            tooltip: 'Referans Kodunu Kopyala',
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// In-screen Modal Bottom Sheet allowing banned players to lodge formal appeals.
class _BanAppealSheet extends ConsumerStatefulWidget {
  const _BanAppealSheet({
    required this.accountReference,
    required this.banReason,
    required this.until,
  });

  final String accountReference;
  final String? banReason;
  final DateTime? until;

  @override
  ConsumerState<_BanAppealSheet> createState() => _BanAppealSheetState();
}

class _BanAppealSheetState extends ConsumerState<_BanAppealSheet> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  String _category = 'account_ban_mistake';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _subjectController.text = 'Hesap Askı İtirazı [REF: #${widget.accountReference}]';
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submitAppeal() async {
    final String description = _bodyController.text.trim();
    if (description.length < 20) {
      AppHaptics.heavy();
      AppMessenger.showWarning(
        context,
        'Lütfen itirazınızı en az 20 karakter ile detaylandırınız.',
      );
      return;
    }

    setState(() => _submitting = true);
    AppHaptics.selection();
    ZeroJankPreloader.instance.onTouchStart();

    try {
      final String formattedBody = '''
İtiraz Türü: $_category
Referans: #BAN-${widget.accountReference}
Askı Gerekçesi: ${widget.banReason ?? 'Belirtilmedi'}
Bitiş Tarihi: ${widget.until?.toIso8601String() ?? 'Kalıcı'}

Oyuncu Beyanı:
$description
''';

      final String? err = await ref.read(supportProvider.notifier).createTicket(
            category: 'account',
            subject: _subjectController.text.trim(),
            body: formattedBody,
          );

      if (!mounted) return;

      if (err != null) {
        AppHaptics.heavy();
        AppMessenger.showError(context, 'İtiraz iletilemedi: $err');
      } else {
        AppHaptics.success();
        Navigator.of(context).pop();
        AppMessenger.showSuccess(
          context,
          'İtiraz talebiniz Muhafız Denetim Masasına iletildi. İnceleme başlatıldı.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.heavy();
        AppMessenger.showError(context, 'Beklenmeyen hata: $e');
      }
    } finally {
      ZeroJankPreloader.instance.onTouchEnd();
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final GraphicsConfigData graphicsConfig = ref.watch(graphicsSettingsProvider);
    final bool isLowSpec = graphicsConfig.tier == GraphicsQualityTier.eco ||
        graphicsConfig.tier == GraphicsQualityTier.low;
    final double blurSigma = isLowSpec ? 0.0 : 12.0;

    return Container(
      decoration: BoxDecoration(
        color: SettingsPalette.void_.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: SettingsPalette.ruby.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.base,
              right: AppSpacing.base,
              top: AppSpacing.md,
              bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: SettingsPalette.titanium.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Header with Close Button
                  Row(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: SettingsPalette.ruby.withValues(alpha: 0.18),
                          border: Border.all(
                            color: SettingsPalette.ruby.withValues(alpha: 0.45),
                          ),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: SettingsPalette.ruby,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'YAPTIRIM İTİRAZ FORMU',
                              style: GoogleFonts.urbanist(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: SettingsPalette.textHi,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Referans: #BAN-${widget.accountReference}',
                              style: AppTextStyles.caption.copyWith(
                                color: SettingsPalette.titanium,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: SettingsPalette.titanium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Category Selector
                  DropdownButtonFormField<String>(
                    value: _category,
                    dropdownColor: SettingsPalette.navy,
                    style: supportBodyStyle,
                    decoration: supportInputDecoration(label: 'İtiraz Kategorisi'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'account_ban_mistake',
                        child: Text('Hatalı Tespit / Kural İhlali Yok'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'account_hijack',
                        child: Text('Yetkisiz Erişim / Hesap Çalınması'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'account_mitigation',
                        child: Text('Özür ve Durum Açıklaması'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'account_other',
                        child: Text('Diğer Güvenlik İtirazı'),
                      ),
                    ],
                    onChanged: (String? v) =>
                        setState(() => _category = v ?? 'account_ban_mistake'),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Subject Input
                  TextField(
                    controller: _subjectController,
                    style: supportBodyStyle,
                    decoration: supportInputDecoration(
                      label: 'Başlık',
                      hint: 'İtiraz özeti',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Statement Input
                  TextField(
                    controller: _bodyController,
                    style: supportBodyStyle,
                    minLines: 4,
                    maxLines: 6,
                    decoration: supportInputDecoration(
                      label: 'İtiraz Açıklaması (Min. 20 Karakter)',
                      hint: 'Durumu, olayın gerçekleşme şeklini ve varsa kanıtlarınızı detaylıca açıklayınız...',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Submit Button
                  SettingsPressable(
                    enabled: !_submitting,
                    onTap: _submitting ? null : _submitAppeal,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: <Color>[
                            SettingsPalette.ruby,
                            SettingsPalette.fuchsia,
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: SettingsPalette.ruby.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'İTİRAZI GÖNDER',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

