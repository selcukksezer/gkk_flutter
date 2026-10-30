import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../components/common/app_messenger.dart';
import '../core/services/app_foreground_service.dart';
import '../core/services/app_haptics.dart';
import '../core/services/device_session_service.dart';
import '../core/services/supabase_service.dart';
import '../core/tutorial/tutorial_modal_suppress.dart';
import '../routing/app_router.dart';
import '../theme/app_colors.dart';
import '../utils/logout_helper.dart';

// ── 2027 Aion 2 Obsidian-Glass & Luminescence Design Tokens ─────────────────
const Color _kObsidianVoid = Color(0xFF07090E);
const Color _kObsidianSurface = Color(0xFF0F141F);
const Color _kObsidianElevated = Color(0xFF141B2A);
const Color _kObsidianBorder = Color(0xFF1C2538);

const Color _kEtherCyan = Color(0xFF00E5FF);
const Color _kEtherCyanDeep = Color(0xFF007A8A);
const Color _kEtherCyanGlow = Color(0x3300E5FF);

const Color _kAmberAlert = Color(0xFFFFB300);
const Color _kAmberAlertDeep = Color(0xFFB26A00);
const Color _kAmberAlertGlow = Color(0x33FFB300);

const Color _kTitanium = Color(0xFF8E9CAE);
const Color _kTextHigh = Color(0xFFF0F4FF);
const Color _kTextMuted = Color(0xFF6B7A99);

/// 2027 Aion 2 Obsidian-Glass Session Enforcement Gate (V2 Polish).
///
/// Ensures single-device account integrity through real-time Postgres changes
/// and active epoch verification. When a session conflict or takeover occurs,
/// gameplay interaction is securely sealed behind frosted obsidian glass
/// (sigma 16), luminous ether cyan radar sweep, amber collision alert, and
/// tactile reconnect controls protected against layout overflows and lifecycle leaks.
class SessionEnforcementGate extends ConsumerStatefulWidget {
  const SessionEnforcementGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionEnforcementGate> createState() =>
      _SessionEnforcementGateState();
}

class _SessionEnforcementGateState extends ConsumerState<SessionEnforcementGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  Timer? _pollTimer;
  StreamSubscription<supa.AuthState>? _authSub;
  supa.RealtimeChannel? _channel;

  bool _checking = false;
  bool _kicked = false;
  int _verifyFailures = 0;

  bool _isEnforced = false;
  bool _isReconnecting = false;
  DeviceSessionReason? _conflictReason;
  String _enforcementTitle = 'OTURUM ÇAKIŞMASI TESPİT EDİLDİ';
  String _enforcementMessage =
      'Hesabınız başka bir cihazda aktif hale getirildi. Tek cihaz politikası uyarınca bu cihazdaki erişim kısıtlandı.';
  int? _activeEpoch;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _bootstrap();
    AppForegroundService.instance.addListener(_onAppResume);
  }

  @override
  void dispose() {
    AppForegroundService.instance.removeListener(_onAppResume);
    _pollTimer?.cancel();
    _authSub?.cancel();
    _authSub = null;
    _channel?.unsubscribe();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onAppResume() {
    unawaited(_verifySession(showMessage: true));
  }

  Future<void> _bootstrap() async {
    if (!SupabaseService.isInitialized) return;

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_verifySession(showMessage: true));
    });

    _authSub?.cancel();
    _authSub = SupabaseService.client.auth.onAuthStateChange.listen(
      (supa.AuthState data) {
        if (data.session == null) {
          _channel?.unsubscribe();
          _channel = null;
          if (mounted) {
            setState(() {
              _isEnforced = false;
              _conflictReason = null;
            });
          }
          return;
        }
        unawaited(_verifySession(showMessage: false));
        _subscribeRealtime(data.session!.user.id);
      },
    );

    final session = SupabaseService.client.auth.currentSession;
    if (session != null) {
      await _verifySession(showMessage: false);
      _subscribeRealtime(session.user.id);
    }
  }

  void _subscribeRealtime(String authId) {
    if (!SupabaseService.isInitialized) return;
    _channel?.unsubscribe();
    _channel = SupabaseService.client
        .channel('device-session-$authId')
        .onPostgresChanges(
          event: supa.PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: supa.PostgresChangeFilter(
            type: supa.PostgresChangeFilterType.eq,
            column: 'auth_id',
            value: authId,
          ),
          callback: (_) => unawaited(_verifySession(showMessage: true)),
        )
        .subscribe();
  }

  Future<void> _verifySession({required bool showMessage}) async {
    // Concurrency guard: avoid interfering while reconnect or active check in flight
    if (!mounted || _kicked || _checking || _isReconnecting) return;
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentSession == null) {
      return;
    }

    _checking = true;
    try {
      final DeviceSessionVerifyResult result =
          await DeviceSessionService.verifyCurrentDevice();
      if (!mounted) return;

      if (result.valid) {
        _verifyFailures = 0;
        _activeEpoch = result.sessionEpoch;
        if (_isEnforced) {
          setState(() {
            _isEnforced = false;
            _conflictReason = null;
          });
        }
        return;
      }

      if (result.reason == DeviceSessionReason.otherDevice ||
          result.reason == DeviceSessionReason.superseded) {
        _activeEpoch = result.sessionEpoch;
        _triggerEnforcement(
          reason: result.reason,
          title: result.reason == DeviceSessionReason.otherDevice
              ? 'BAŞKA CİHAZDA GİRİŞ YAPILDI'
              : 'YENİ OTURUM DEVREDİLDİ',
          message: result.reason == DeviceSessionReason.otherDevice
              ? 'Hesabınız başka bir cihazda aktif hale getirildi. Güvenliğiniz ve tek cihaz kuralı uyarınca bu oturum askıya alındı.'
              : 'Hesabınız için daha yeni bir oturum tespit edildi. Bu cihazdaki oturum devredildi.',
          showMessage: showMessage,
        );
      }
    } catch (_) {
      _verifyFailures++;
      if (_verifyFailures >= 3 && mounted && !_kicked) {
        _triggerEnforcement(
          reason: DeviceSessionReason.error,
          title: 'OTURUM DOĞRULANAMADI',
          message:
              'Cihaz güvenlik anahtarı sunucuyla doğrulanamadı. Ağ bağlantınızı kontrol edip tekrar deneyin veya yeniden giriş yapın.',
          showMessage: showMessage,
        );
      }
    } finally {
      _checking = false;
    }
  }

  void _triggerEnforcement({
    required DeviceSessionReason reason,
    required String title,
    required String message,
    required bool showMessage,
  }) {
    if (!mounted) return;
    setState(() {
      _isEnforced = true;
      _conflictReason = reason;
      _enforcementTitle = title;
      _enforcementMessage = message;
    });

    if (showMessage) {
      AppMessenger.showWarning(context, title);
    }
  }

  Future<void> _handleReconnect() async {
    if (_isReconnecting) return;
    setState(() => _isReconnecting = true);

    await AppHaptics.medium();
    await HapticFeedback.mediumImpact();

    try {
      final int claimedEpoch = await DeviceSessionService.claimActiveDevice();
      final DeviceSessionVerifyResult result =
          await DeviceSessionService.verifyCurrentDevice();

      if (!mounted) return;

      if (result.valid) {
        await AppHaptics.success();
        setState(() {
          _isEnforced = false;
          _verifyFailures = 0;
          _isReconnecting = false;
          _conflictReason = null;
          _activeEpoch = claimedEpoch;
        });
        if (mounted) {
          AppMessenger.showSuccess(
            context,
            'Oturum başarıyla yetkilendirildi ve bu cihaza bağlandı.',
          );
        }
        return;
      }

      await AppHaptics.heavy();
      await HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _isReconnecting = false;
          _conflictReason = result.reason;
        });
        AppMessenger.showError(
          context,
          'Oturum bu cihaz için doğrulanamadı. Lütfen tekrar giriş yapın.',
        );
      }
    } catch (_) {
      await AppHaptics.heavy();
      await HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _isReconnecting = false);
        AppMessenger.showError(
          context,
          'Yeniden bağlantı sağlanamadı. Bağlantınızı kontrol edin.',
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    await AppHaptics.light();
    await HapticFeedback.lightImpact();
    await _forceLogout(
      message: 'Oturum kapatıldı.',
      showMessage: false,
    );
  }

  Future<void> _forceLogout({
    required String message,
    required bool showMessage,
  }) async {
    if (_kicked) return;
    _kicked = true;
    await performLogout(ref);
    if (!mounted) return;
    if (showMessage) {
      final navContext = appRootNavigatorKey.currentContext ?? context;
      AppMessenger.showError(navContext, message);
    }
    final navContext = appRootNavigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      navContext.go(AppRoutes.login);
    } else {
      context.go(AppRoutes.login);
    }
  }

  Widget _overlayShell({required Widget child}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEnforced) {
      return widget.child;
    }

    return TutorialSuppressScope(
      active: true,
      child: _overlayShell(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Freeze underlying gameplay child
            IgnorePointer(child: widget.child),

            // Frosted blur sigma 16 with obsidian dark foundation
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        _kObsidianVoid.withValues(alpha: 0.90),
                        _kObsidianSurface.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Ambient session pulse radar sweep & orbital rings
            Positioned.fill(
              child: _buildAmbientSessionPulse(),
            ),

            // Centered Glassmorphic Enforcement Card with SafeArea
            SafeArea(
              maintainBottomViewPadding: true,
              child: Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: math.max(
                      16,
                      MediaQuery.viewInsetsOf(context).bottom + 16,
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _buildEnforcementCard(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientSessionPulse() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (BuildContext context, Widget? _) {
        final double t = _pulseCtrl.value;
        return CustomPaint(
          painter: _SessionRadarPainter(
            progress: t,
            isAmber: _conflictReason != null,
            accentColor: _conflictReason != null ? _kAmberAlert : _kEtherCyan,
          ),
        );
      },
    );
  }

  Widget _buildEnforcementCard() {
    final bool isAmber = _conflictReason != null;
    final Color primaryGlow = isAmber ? _kAmberAlert : _kEtherCyan;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (BuildContext context, Widget? _) {
        final double t = _pulseCtrl.value;
        final double pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            // High-definition gradient border simulation
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                primaryGlow.withValues(alpha: 0.65 + 0.35 * pulse),
                _kObsidianBorder.withValues(alpha: 0.4),
                primaryGlow.withValues(alpha: 0.25 + 0.2 * pulse),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: primaryGlow.withValues(alpha: 0.18 + 0.14 * pulse),
                blurRadius: 40,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: _kObsidianVoid.withValues(alpha: 0.90),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            // 1.5px border thickness
            padding: const EdgeInsets.all(1.5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22.5),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        _kObsidianSurface.withValues(alpha: 0.94),
                        _kObsidianVoid.withValues(alpha: 0.98),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      // Top specular crystalline highlight rim
                      Positioned(
                        top: 0,
                        left: 24,
                        right: 24,
                        height: 1.5,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                Colors.transparent,
                                primaryGlow.withValues(alpha: 0.65),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Main Card Content
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 26,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            // Top Status Pill
                            Center(
                              child: _buildStatusPill(
                                isAmber: isAmber,
                                pulse: pulse,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Animated Radar Icon Hub
                            Center(
                              child: _buildPulseOrb(
                                isAmber: isAmber,
                                pulse: pulse,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Enforcement Title with dual glow
                            Text(
                              _enforcementTitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.urbanist(
                                color: _kTextHigh,
                                fontSize: 18.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                height: 1.25,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: primaryGlow.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Enforcement Message
                            Text(
                              _enforcementMessage,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.urbanist(
                                color: _kTitanium,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.48,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Overflow-safe Device & Epoch Meta Chip
                            _buildMetadataChip(),
                            const SizedBox(height: 24),

                            // Reconnect Action Button (Ether Cyan Glow)
                            _LuminousActionButton(
                              label: _isReconnecting
                                  ? 'YETKİLENDİRİLİYOR...'
                                  : 'BU CİHAZI YETKİLENDİR & BAĞLAN',
                              icon: Icons.sync_rounded,
                              isPrimary: true,
                              isLoading: _isReconnecting,
                              accentColor: _kEtherCyan,
                              onPressed:
                                  _isReconnecting ? null : _handleReconnect,
                            ),
                            const SizedBox(height: 12),

                            // Sign Out Button (Dark Glass Surface)
                            _LuminousActionButton(
                              label: 'GÜVENLİ ÇIKIŞ YAP',
                              icon: Icons.logout_rounded,
                              isPrimary: false,
                              accentColor: _kTitanium,
                              onPressed: _handleLogout,
                            ),
                            const SizedBox(height: 18),

                            // Security Tagline
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.shield_outlined,
                                    size: 13,
                                    color: _kTextMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'AION-2 SECURITY PROTOCOL • EPOCH VERIFIED',
                                    style: GoogleFonts.urbanist(
                                      color: _kTextMuted,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusPill({required bool isAmber, required double pulse}) {
    final Color badgeColor = isAmber ? _kAmberAlert : _kEtherCyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35 + 0.35 * pulse),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badgeColor,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.7),
                  blurRadius: 8,
                  spreadRadius: 1.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isAmber ? 'GÜVENLİK PROTOKOLÜ DEVREDE' : 'OTURUM SENKRONİZASYONU',
            style: GoogleFonts.urbanist(
              color: badgeColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseOrb({required bool isAmber, required double pulse}) {
    final Color accent = isAmber ? _kAmberAlert : _kEtherCyan;
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        // Outer pulsing energy wave
        Container(
          width: 78 + 16 * pulse,
          height: 78 + 16 * pulse,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: accent.withValues(alpha: 0.3 * (1 - pulse)),
              width: 1.5,
            ),
          ),
        ),
        // Secondary orbital ring
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: accent.withValues(alpha: 0.12 + 0.1 * pulse),
              width: 1,
            ),
          ),
        ),
        // Central glass orb
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kObsidianVoid.withValues(alpha: 0.90),
            border: Border.all(
              color: accent.withValues(alpha: 0.55 + 0.45 * pulse),
              width: 2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.25 + 0.22 * pulse),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            isAmber
                ? Icons.phonelink_lock_rounded
                : Icons.security_update_good_rounded,
            color: accent,
            size: 34,
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataChip() {
    final String platform = DeviceSessionService.platformLabel().toUpperCase();
    final String epochTag =
        _activeEpoch != null ? 'EPOCH #$_activeEpoch' : 'SYNC-IDLE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _kObsidianElevated.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _kObsidianBorder.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.devices_other_rounded,
            size: 15,
            color: _kTitanium,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cihaz: $platform',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.urbanist(
                color: _kTextHigh,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kObsidianVoid,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _kEtherCyan.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Text(
              epochTag,
              style: GoogleFonts.urbanist(
                color: _kEtherCyan,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Interactive Luminous Action Button with Immediate Tactile Haptics ────────
class _LuminousActionButton extends StatefulWidget {
  const _LuminousActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.isPrimary = true,
    this.accentColor = _kEtherCyan,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPrimary;
  final Color accentColor;

  @override
  State<_LuminousActionButton> createState() => _LuminousActionButtonState();
}

class _LuminousActionButtonState extends State<_LuminousActionButton> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _pressed = true);
    unawaited(AppHaptics.selection());
  }

  void _onTapUp(TapUpDetails _) {
    if (_pressed) {
      setState(() => _pressed = false);
    }
  }

  void _onTapCancel() {
    if (_pressed) {
      setState(() => _pressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: enabled ? _onTapDown : null,
      onTapUp: enabled ? _onTapUp : null,
      onTapCancel: enabled ? _onTapCancel : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: widget.isPrimary
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      widget.accentColor
                          .withValues(alpha: enabled ? 1.0 : 0.45),
                      _kEtherCyanDeep.withValues(alpha: enabled ? 1.0 : 0.45),
                    ],
                  )
                : null,
            color: widget.isPrimary
                ? null
                : _kObsidianElevated.withValues(alpha: enabled ? 0.85 : 0.4),
            border: Border.all(
              color: widget.isPrimary
                  ? widget.accentColor.withValues(alpha: enabled ? 0.85 : 0.3)
                  : _kObsidianBorder.withValues(alpha: enabled ? 0.85 : 0.3),
              width: 1.2,
            ),
            boxShadow: widget.isPrimary && enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        widget.isPrimary ? _kObsidianVoid : widget.accentColor,
                  ),
                )
              else
                Icon(
                  widget.icon,
                  size: 18,
                  color: widget.isPrimary ? _kObsidianVoid : widget.accentColor,
                ),
              const SizedBox(width: 9),
              Text(
                widget.label,
                style: GoogleFonts.urbanist(
                  color: widget.isPrimary ? _kObsidianVoid : _kTextHigh,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Background Radar Scanner Painter (Orbital Sweep & Grid) ─────────────────
class _SessionRadarPainter extends CustomPainter {
  const _SessionRadarPainter({
    required this.progress,
    required this.isAmber,
    required this.accentColor,
  });

  final double progress;
  final bool isAmber;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = math.min(size.width, size.height) * 0.78;

    // Outer expanding wave 1
    final double r1 = maxRadius * progress;
    final double alpha1 = (1.0 - progress).clamp(0.0, 1.0) * 0.16;
    final Paint wavePaint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accentColor.withValues(alpha: alpha1);
    canvas.drawCircle(center, r1, wavePaint1);

    // Outer expanding wave 2 (phase offset by 0.5)
    final double p2 = (progress + 0.5) % 1.0;
    final double r2 = maxRadius * p2;
    final double alpha2 = (1.0 - p2).clamp(0.0, 1.0) * 0.16;
    final Paint wavePaint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accentColor.withValues(alpha: alpha2);
    canvas.drawCircle(center, r2, wavePaint2);

    // Rotating radar sweep line
    final double angle = progress * 2 * math.pi;
    final double sweepRadius = maxRadius * 0.85;
    final Offset sweepEnd = Offset(
      center.dx + sweepRadius * math.cos(angle),
      center.dy + sweepRadius * math.sin(angle),
    );
    final Paint sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = ui.Gradient.linear(
        center,
        sweepEnd,
        <Color>[
          accentColor.withValues(alpha: 0.0),
          accentColor.withValues(alpha: 0.18),
        ],
      );
    canvas.drawLine(center, sweepEnd, sweepPaint);

    // Cardinal radar tick marks
    final Paint tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = accentColor.withValues(alpha: 0.09);

    canvas.drawLine(
      Offset(center.dx - 48, center.dy),
      Offset(center.dx + 48, center.dy),
      tickPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 48),
      Offset(center.dx, center.dy + 48),
      tickPaint,
    );

    // Subtle orbital node dots at 45 degree diagonals
    for (int i = 0; i < 4; i++) {
      final double nodeAngle = (math.pi / 4) + (i * math.pi / 2);
      final double nodeDist = maxRadius * 0.5;
      final Offset nodePos = Offset(
        center.dx + nodeDist * math.cos(nodeAngle),
        center.dy + nodeDist * math.sin(nodeAngle),
      );
      canvas.drawCircle(
        nodePos,
        1.5,
        Paint()..color = accentColor.withValues(alpha: 0.14),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SessionRadarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isAmber != isAmber ||
        oldDelegate.accentColor != accentColor;
  }
}
