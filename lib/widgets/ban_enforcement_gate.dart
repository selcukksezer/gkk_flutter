import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/common/app_messenger.dart';
import '../core/services/app_haptics.dart';
import '../core/services/supabase_service.dart';
import '../core/tutorial/tutorial_modal_suppress.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../routing/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Immutable model representing the active ban and restriction status.
class BanStatus {
  const BanStatus({
    required this.isBanned,
    this.reason,
    this.until,
  });

  final bool isBanned;
  final String? reason;
  final DateTime? until;

  static const BanStatus clear = BanStatus(isBanned: false);
}

/// Polls + realtime ban updates; blocks all gameplay when active.
///
/// Upgraded to 2027 Aion 2 Obsidian-Glass & Security Gate architecture:
/// - Deep obsidian foundation (`0xFF07090E` - `0xFF0F141F`)
/// - Frosted background blur (BackdropFilter sigma 16)
/// - Crimson warning runes & borders (`#FFFF3366`, `#FFFF1744`)
/// - Ethereal cyan sub-glow accents (`#00F0FF`, `#00E5FF`)
/// - Multi-layered gradient containment frame & runic corner brackets
/// - Full SafeArea and MediaQuery view-insets padding protection
/// - Tactile haptic feedback on all interactive touchpoints
class BanEnforcementGate extends ConsumerStatefulWidget {
  const BanEnforcementGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BanEnforcementGate> createState() => _BanEnforcementGateState();
}

class _BanEnforcementGateState extends ConsumerState<BanEnforcementGate>
    with SingleTickerProviderStateMixin {
  BanStatus _status = BanStatus.clear;
  bool _loading = false;
  bool _notified = false;
  Timer? _pollTimer;
  RealtimeChannel? _channel;

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

    _bootstrap();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pollTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  String get _accountReference {
    final String? uid = SupabaseService.client.auth.currentUser?.id;
    if (uid != null && uid.length >= 8) {
      return uid.substring(0, 8).toUpperCase();
    }
    return 'SEC-7701';
  }

  Future<void> _bootstrap() async {
    if (!SupabaseService.isInitialized) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());

    SupabaseService.client.auth.onAuthStateChange.listen((_) {
      final session = SupabaseService.client.auth.currentSession;
      if (session == null) {
        if (mounted) {
          setState(() {
            _status = BanStatus.clear;
            _notified = false;
          });
        }
        _channel?.unsubscribe();
        _channel = null;
      } else {
        unawaited(_refresh());
        _subscribeRealtime(session.user.id);
      }
    });

    final session = SupabaseService.client.auth.currentSession;
    if (session != null) {
      await _refresh();
      _subscribeRealtime(session.user.id);
    }
  }

  void _subscribeRealtime(String authId) {
    if (!SupabaseService.isInitialized) return;
    _channel?.unsubscribe();
    _channel = SupabaseService.client
        .channel('ban-watch-$authId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'auth_id',
            value: authId,
          ),
          callback: (_) => unawaited(_refresh()),
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentSession == null ||
        _loading) {
      return;
    }
    _loading = true;
    try {
      final dynamic raw =
          await SupabaseService.client.rpc('get_my_ban_status');
      if (!mounted) return;
      if (raw is! Map) return;

      final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
      if (data['success'] != true) return;

      final bool banned = data['is_banned'] == true;
      final String? reason = data['ban_reason']?.toString();
      final DateTime? until = data['banned_until'] != null
          ? DateTime.tryParse(data['banned_until'].toString())?.toLocal()
          : null;

      final bool wasBanned = _status.isBanned;
      setState(() {
        _status = banned
            ? BanStatus(isBanned: true, reason: reason, until: until)
            : BanStatus.clear;
      });

      if (banned && !wasBanned && !_notified && mounted) {
        _notified = true;
        final String untilLabel = until == null
            ? 'Kalıcı Askıya Alma'
            : '${until.day.toString().padLeft(2, '0')}.${until.month.toString().padLeft(2, '0')}.${until.year} ${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}';
        AppMessenger.showError(
          context,
          'Hesabın askıya alındı.\nSebep: ${reason ?? 'Belirtilmedi'}\nSüre: $untilLabel',
        );
      }
      if (!banned) {
        _notified = false;
      }
    } catch (_) {
      // Offline — keep last known status.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _logout() async {
    await AppHaptics.heavy();
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _copyReference() async {
    await AppHaptics.selection();
    await Clipboard.setData(ClipboardData(text: '#SEC-$_accountReference'));
    if (mounted) {
      AppMessenger.showSuccess(
        context,
        'Denetim referans kodu (#SEC-$_accountReference) panoya kopyalandı.',
      );
    }
  }

  String _formatUntil(DateTime? until) {
    if (until == null) return 'Kalıcı (Süresiz Kısıtlama)';
    return '${until.day.toString().padLeft(2, '0')}.${until.month.toString().padLeft(2, '0')}.${until.year} '
        '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}';
  }

  String? _formatRemaining(DateTime? until) {
    if (until == null) return null;
    final Duration diff = until.difference(DateTime.now());
    if (diff.isNegative) return 'Kısıtlama süresi doldu (doğrulanıyor)';
    if (diff.inDays > 0) {
      return '${diff.inDays} gün ${diff.inHours % 24} saat kaldı';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours} saat ${diff.inMinutes % 60} dakika kaldı';
    }
    return '${diff.inMinutes} dakika kaldı';
  }

  @override
  Widget build(BuildContext context) {
    if (!_status.isBanned) return widget.child;

    return TutorialSuppressScope(
      active: true,
      child: Stack(
        children: <Widget>[
          IgnorePointer(child: widget.child),
          // 2027 Aion 2 Obsidian Backdrop with Sigma 16 Frosted Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xFA07090E),
                      Color(0xFC0B0F19),
                      Color(0xFA07090E),
                    ],
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    // Top Radiant Crimson Ambient Halo
                    Positioned(
                      top: -140,
                      left: -80,
                      right: -80,
                      height: 420,
                      child: IgnorePointer(
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                Color(0x35FF1744),
                                Color(0x18FF3366),
                                Colors.transparent,
                              ],
                              stops: <double>[0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Ethereal Cyan Sub-glow Corner Accents
                    Positioned(
                      bottom: -100,
                      right: -60,
                      width: 300,
                      height: 300,
                      child: IgnorePointer(
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                Color(0x1E00E5FF),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 120,
                      left: -80,
                      width: 220,
                      height: 220,
                      child: IgnorePointer(
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                Color(0x1200F0FF),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Ambient Cyber Security Grid Mesh
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _SecurityGridMeshPainter(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Modal Security Gate Frame with Full SafeArea & View-Insets Protection
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 24,
                    bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (BuildContext context, Widget? child) {
                        final double pulse = _pulseAnimation.value;
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            // High-definition multi-stop gradient border
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                const Color(0xFFFF3366).withValues(alpha: 0.85 + pulse * 0.15),
                                const Color(0xFFFF1744).withValues(alpha: 0.70 + pulse * 0.20),
                                const Color(0x33FF3366),
                                const Color(0xFF00E5FF).withValues(alpha: 0.60 + pulse * 0.25),
                                const Color(0x2200E5FF),
                                const Color(0xFFFF3366).withValues(alpha: 0.80),
                              ],
                              stops: const <double>[0.0, 0.24, 0.50, 0.74, 0.88, 1.0],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: const Color(0xFFFF1744).withValues(
                                  alpha: 0.20 + (pulse * 0.16),
                                ),
                                blurRadius: 40,
                                spreadRadius: 2,
                                offset: const Offset(0, 12),
                              ),
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(
                                  alpha: 0.08 + (pulse * 0.06),
                                ),
                                blurRadius: 28,
                                offset: const Offset(0, -4),
                              ),
                              const BoxShadow(
                                color: Color(0xC0000000),
                                blurRadius: 24,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(1.3),
                          child: child,
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xF7090D16),
                            borderRadius: BorderRadius.all(Radius.circular(23)),
                          ),
                          child: Stack(
                            children: <Widget>[
                              // Specular Rim Highlight Sheen
                              Positioned(
                                top: 0,
                                left: 28,
                                right: 28,
                                height: 1.5,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: <Color>[
                                        Colors.transparent,
                                        Color(0x99FF3366),
                                        Color(0xEEFFFFFF),
                                        Color(0x9900E5FF),
                                        Colors.transparent,
                                      ],
                                      stops: <double>[0.0, 0.25, 0.5, 0.75, 1.0],
                                    ),
                                  ),
                                ),
                              ),

                              // Aion 2 Security Gate Runic Corner Brackets
                              const Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _SecurityGateRunicPainter(
                                      primaryColor: Color(0xFFFF3366),
                                      accentColor: Color(0xFF00E5FF),
                                    ),
                                  ),
                                ),
                              ),

                              // Modal Content Area
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 24,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    _buildSecurityHeader(),
                                    const SizedBox(height: 20),
                                    _buildReasonSection(),
                                    const SizedBox(height: 12),
                                    _buildDurationSection(),
                                    const SizedBox(height: 12),
                                    _buildReferenceCodeSection(),
                                    const SizedBox(height: 20),
                                    _buildActionButtons(),
                                    const SizedBox(height: 14),
                                    _buildSecurityFooterGuidance(),
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
        ],
      ),
    );
  }

  Widget _buildSecurityHeader() {
    return Column(
      children: <Widget>[
        // Ancient Aion Rune Inscription
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (BuildContext context, Widget? _) {
            final double t = _pulseAnimation.value;
            return Text(
              '✦ ᚱ ᛖ ᛊ ᛏ ᚱ ᛁ ᚲ ᛏ ᛖ ᛞ ✦',
              style: GoogleFonts.cinzel(
                fontSize: 9.5,
                letterSpacing: 4.0,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFF3366).withValues(alpha: 0.65 + t * 0.35),
              ),
            );
          },
        ),
        const SizedBox(height: 10),

        // Double-Rimmed Pulsing Shield Crest Hero
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (BuildContext context, Widget? _) {
            final double t = _pulseAnimation.value;
            return Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    const Color(0xFFFF3366),
                    Color.lerp(const Color(0xFFFF1744), const Color(0xFFD50000), t)!,
                    const Color(0xFF4A000E),
                  ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFFFF1744).withValues(alpha: 0.35 + t * 0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0C101B),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // Rotating Rune Ticks Ring
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CircularRuneRingsPainter(
                          color: const Color(0xFFFF3366).withValues(alpha: 0.40 + t * 0.25),
                          rotationAngle: t * (math.pi / 16),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.gpp_bad_rounded,
                      color: Color(0xFFFF3366),
                      size: 42,
                    ),
                    // Ethereal Cyan Active Sentinel Node
                    Positioned(
                      top: 10,
                      right: 14,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF00E5FF),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Color(0xFF00E5FF),
                              blurRadius: 8,
                              spreadRadius: 1.5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        // Protocol Security Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
          decoration: BoxDecoration(
            color: const Color(0xFFFF1744).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: const Color(0xFFFF1744).withValues(alpha: 0.40),
              width: 1,
            ),
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
                      color: const Color(0xFFFF1744),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFFFF1744).withValues(
                            alpha: 0.4 + _pulseAnimation.value * 0.6,
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
                'PROTOKOL: AİON GÜVENLİK MUHAFIZI',
                style: GoogleFonts.urbanist(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                  color: const Color(0xFFFF4D79),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Title
        Text(
          'HESAP ASKIYA ALINDI',
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),

        // Subtitle
        Text(
          'Güvenlik ve adil oyun ilkeleri ihlali nedeniyle bu hesabın sunucu erişimi askıya alınmıştır.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: const Color(0xFFA9B7D0),
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildReasonSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D121F).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF3366).withValues(alpha: 0.28),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.report_gmailerrorred_rounded,
                color: Color(0xFFFF3366),
                size: 16,
              ),
              const SizedBox(width: 7),
              Text(
                'İHLAL GEREKÇESİ',
                style: GoogleFonts.urbanist(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: const Color(0xFFFF5277),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _status.reason ?? 'Topluluk kuralları veya şüpheli işlem ihlali.',
            style: AppTextStyles.bodyBold.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSection() {
    final bool isPermanent = _status.until == null;
    final String? remaining = _formatRemaining(_status.until);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D121F).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF253154).withValues(alpha: 0.85),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.schedule_rounded,
                    color: Color(0xFF00E5FF),
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'GEÇERLİLİK VE SÜRE',
                    style: GoogleFonts.urbanist(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: const Color(0xFF00E5FF),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPermanent
                      ? const Color(0x26FF1744)
                      : const Color(0x2200E5FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isPermanent
                        ? const Color(0x77FF1744)
                        : const Color(0x6600E5FF),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isPermanent ? 'KALICI ENGEL' : 'SÜRELİ ASKI',
                  style: GoogleFonts.urbanist(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: isPermanent
                        ? const Color(0xFFFF3366)
                        : const Color(0xFF00E5FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatUntil(_status.until),
            style: AppTextStyles.bodyBold.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13.5,
            ),
          ),
          if (remaining != null) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.timelapse_rounded,
                  color: Color(0xFF8A9BBE),
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  remaining,
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF8A9BBE),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReferenceCodeSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF090D17).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.fingerprint_rounded,
            color: Color(0xFF00E5FF),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'DENETİM REFERANS KODU',
                  style: GoogleFonts.urbanist(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: const Color(0xFF6B7A99),
                  ),
                ),
                Text(
                  '#SEC-$_accountReference',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          _TactileIconButton(
            tooltip: 'Kodu Kopyala',
            icon: Icons.copy_rounded,
            onTap: _copyReference,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Primary Re-check / Refresh Status Button
        _AionButton(
          label: _loading ? 'DURUM DENETLENİYOR...' : 'ASKI DURUMUNU YENİLE VE KONTROL ET',
          icon: _loading ? null : Icons.refresh_rounded,
          isLoading: _loading,
          isPrimary: false,
          onTap: () async {
            await AppHaptics.medium();
            await _refresh();
          },
        ),
        const SizedBox(height: 10),

        // Destructive Logout Button
        _AionButton(
          label: 'GÜVENLİ ÇIKIŞ YAP',
          icon: Icons.logout_rounded,
          isPrimary: true,
          onTap: _logout,
        ),
      ],
    );
  }

  Widget _buildSecurityFooterGuidance() {
    return Center(
      child: Text(
        'Hatalı bir karar olduğunu düşünüyorsanız referans kodu ile\nMuhafız Destek Birimiyle iletişime geçebilirsiniz.',
        textAlign: TextAlign.center,
        style: AppTextStyles.caption.copyWith(
          color: const Color(0xFF5B6E94),
          fontSize: 11,
          height: 1.45,
        ),
      ),
    );
  }
}

/// Compact tactile icon button with scale feedback
class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) => setState(() => _isDown = false),
      onTapCancel: () => setState(() => _isDown = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isDown ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF141B2A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: const Color(0xFF00E5FF),
          ),
        ),
      ),
    );
  }
}

/// Tactical Aion 2 obsidian-glass button with haptic press physics
class _AionButton extends StatefulWidget {
  const _AionButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.isLoading = false,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isLoading;
  final bool isPrimary;

  @override
  State<_AionButton> createState() => _AionButtonState();
}

class _AionButtonState extends State<_AionButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) => setState(() => _isDown = false),
      onTapCancel: () => setState(() => _isDown = false),
      onTap: widget.isLoading ? null : widget.onTap,
      child: AnimatedScale(
        scale: _isDown ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: widget.isPrimary
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFFFF3366),
                      Color(0xFFFF1744),
                      Color(0xFFB71C1C),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF141B2A),
                      Color(0xFF0D121D),
                    ],
                  ),
            border: Border.all(
              color: widget.isPrimary
                  ? const Color(0xFFFF5277)
                  : const Color(0xFF00E5FF).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: widget.isPrimary
                ? <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFFF1744).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : <BoxShadow>[
                    const BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                  ),
                )
              else if (widget.icon != null) ...<Widget>[
                Icon(
                  widget.icon,
                  size: 18,
                  color: widget.isPrimary
                      ? Colors.white
                      : const Color(0xFF00E5FF),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: GoogleFonts.urbanist(
                  color: widget.isPrimary ? Colors.white : AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter rendering cyber security grid mesh
class _SecurityGridMeshPainter extends CustomPainter {
  const _SecurityGridMeshPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = const Color(0xFF253154).withValues(alpha: 0.10)
      ..strokeWidth = 1.0;

    const double step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Aion 2 Angular Security Gate Runic Border with chamfered corners and tick marks
class _SecurityGateRunicPainter extends CustomPainter {
  const _SecurityGateRunicPainter({
    required this.primaryColor,
    required this.accentColor,
  });

  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint runePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.65)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final Paint accentPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.fill;

    const double bracketSize = 22.0;
    const double inset = 10.0;

    // Top-Left Runic Bracket
    final Path tlPath = Path()
      ..moveTo(inset, inset + bracketSize)
      ..lineTo(inset, inset + 6)
      ..lineTo(inset + 6, inset)
      ..lineTo(inset + bracketSize, inset);
    canvas.drawPath(tlPath, runePaint);
    canvas.drawCircle(Offset(inset + 6, inset), 2.0, accentPaint);

    // Top-Right Runic Bracket
    final Path trPath = Path()
      ..moveTo(size.width - inset - bracketSize, inset)
      ..lineTo(size.width - inset - 6, inset)
      ..lineTo(size.width - inset, inset + 6)
      ..lineTo(size.width - inset, inset + bracketSize);
    canvas.drawPath(trPath, runePaint);
    canvas.drawCircle(Offset(size.width - inset - 6, inset), 2.0, accentPaint);

    // Bottom-Left Runic Bracket
    final Path blPath = Path()
      ..moveTo(inset, size.height - inset - bracketSize)
      ..lineTo(inset, size.height - inset - 6)
      ..lineTo(inset + 6, size.height - inset)
      ..lineTo(inset + bracketSize, size.height - inset);
    canvas.drawPath(blPath, runePaint);
    canvas.drawCircle(Offset(inset + 6, size.height - inset), 2.0, accentPaint);

    // Bottom-Right Runic Bracket
    final Path brPath = Path()
      ..moveTo(size.width - inset - bracketSize, size.height - inset)
      ..lineTo(size.width - inset - 6, size.height - inset)
      ..lineTo(size.width - inset, size.height - inset - 6)
      ..lineTo(size.width - inset, size.height - inset - bracketSize);
    canvas.drawPath(brPath, runePaint);
    canvas.drawCircle(Offset(size.width - inset - 6, size.height - inset), 2.0, accentPaint);

    // Cardinal tick markers
    final Paint tickPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    // Top center tick
    canvas.drawLine(
      Offset(size.width / 2 - 8, inset),
      Offset(size.width / 2 + 8, inset),
      tickPaint,
    );
    // Bottom center tick
    canvas.drawLine(
      Offset(size.width / 2 - 8, size.height - inset),
      Offset(size.width / 2 + 8, size.height - inset),
      tickPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SecurityGateRunicPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.accentColor != accentColor;
}

/// Circular Rune Ring Painter for shield crest with smooth rotational animation
class _CircularRuneRingsPainter extends CustomPainter {
  const _CircularRuneRingsPainter({
    required this.color,
    this.rotationAngle = 0.0,
  });

  final Color color;
  final double rotationAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width / 2) - 4;

    final Paint ringPaint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, ringPaint);

    final Paint tickPaint = Paint()
      ..color = color
      ..strokeWidth = 1.4;

    // 8 cardinal and diagonal rune ticks rotated smoothly
    for (int i = 0; i < 8; i++) {
      final double angle = rotationAngle + ((i * 45) * math.pi / 180);
      final double innerR = radius - 3.5;
      final double outerR = radius;
      final Offset p1 = Offset(
        center.dx + innerR * math.cos(angle),
        center.dy + innerR * math.sin(angle),
      );
      final Offset p2 = Offset(
        center.dx + outerR * math.cos(angle),
        center.dy + outerR * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularRuneRingsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.rotationAngle != rotationAngle;
}
