import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/connectivity_service.dart';
import '../../theme/app_colors.dart';
import '../layout/game_screen_background.dart';

// ============================================================================
// BAĞLANTI KAPISI
// MaterialApp.builder içine sarılır.
// - slow  → loading overlay (yalnız pending user op ≥ ~3s; probe RTT asla)
// - offline → disconnect ekranı (probe fail debounce)
// - reconnected → kısa onay bandı
// ============================================================================

class ConnectivityGate extends StatefulWidget {
  const ConnectivityGate({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    ConnectivityService.instance.start();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await ConnectivityService.instance.retryNow();
    if (mounted) setState(() => _retrying = false);
  }

  /// Overlay MaterialApp.builder seviyesinde çizildiği için Material ata
  /// yok; Material(transparency) olmadan tüm Text'ler sarı alt çizgili çıkar.
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
    return ValueListenableBuilder<ConnectivityStatus>(
      valueListenable: ConnectivityService.instance.status,
      builder: (BuildContext context, ConnectivityStatus status, Widget? _) {
        return Stack(
          textDirection: TextDirection.ltr,
          fit: StackFit.expand,
          children: <Widget>[
            widget.child,
            if (status == ConnectivityStatus.slow)
              _buildSlowOverlay()
            else if (status == ConnectivityStatus.offline)
              _buildOfflineOverlay()
            else if (status == ConnectivityStatus.reconnected)
              _buildReconnectedBanner(),
          ],
        );
      },
    );
  }

  // ── Slow: translucent loading (child stays visible underneath) ─────────────
  Widget _buildSlowOverlay() {
    return _overlayShell(
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 200),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  AppColors.carbonVoid.withValues(alpha: 0.42),
                  AppColors.spaceNavy.withValues(alpha: 0.48),
                ],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const CustomPaint(
                  painter: DotGridPainter(
                    spacing: 22,
                    dotRadius: 1.0,
                    dotOpacity: 0.07,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (BuildContext context, Widget? _) {
                          final double t = _pulseCtrl.value;
                          final double pulse =
                              0.5 + 0.5 * math.sin(t * math.pi * 2);
                          return Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  AppColors.darkObsidian.withValues(alpha: 0.85),
                              border: Border.all(
                                color: AppColors.liquidGold
                                    .withValues(alpha: 0.45 + 0.4 * pulse),
                                width: 2,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.liquidGold
                                      .withValues(alpha: 0.22 + 0.18 * pulse),
                                  blurRadius: 26,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                color: AppColors.liquidGold,
                                backgroundColor: AppColors.liquidGold
                                    .withValues(alpha: 0.15),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 26),
                      Text(
                        'BAĞLANTI YAVAŞ',
                        style: GoogleFonts.urbanist(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Ağ yanıtı gecikiyor.\nLütfen bekle...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.urbanist(
                          color: AppColors.mutedTitanium,
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
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
    );
  }

  // ── Offline: translucent blur + reconnect (child still readable) ───────────
  Widget _buildOfflineOverlay() {
    return _overlayShell(
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 250),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  AppColors.carbonVoid.withValues(alpha: 0.52),
                  AppColors.spaceNavy.withValues(alpha: 0.58),
                ],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const CustomPaint(
                  painter: DotGridPainter(
                    spacing: 22,
                    dotRadius: 1.0,
                    dotOpacity: 0.07,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (BuildContext context, Widget? _) {
                          final double t = _pulseCtrl.value;
                          final double pulse =
                              0.5 + 0.5 * math.sin(t * math.pi * 2);
                          return Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Container(
                                width: 90 + 40 * t,
                                height: 90 + 40 * t,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.mysticRuby.withValues(
                                      alpha: 0.5 * (1 - t),
                                    ),
                                    width: 2,
                                  ),
                                ),
                              ),
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.carbonVoid
                                      .withValues(alpha: 0.9),
                                  border: Border.all(
                                    color: AppColors.mysticRuby.withValues(
                                      alpha: 0.4 + 0.4 * pulse,
                                    ),
                                    width: 2,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.mysticRuby.withValues(
                                        alpha: 0.25 + 0.2 * pulse,
                                      ),
                                      blurRadius: 26,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.wifi_off_rounded,
                                  color: AppColors.mysticRuby,
                                  size: 38,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 26),
                      Text(
                        'BAĞLANTI KESİLDİ',
                        style: GoogleFonts.urbanist(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'İnternet bağlantın koptu.\nYeniden bağlanmaya çalışıyoruz...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.urbanist(
                          color: AppColors.mutedTitanium,
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: AppColors.liquidGold,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          ValueListenableBuilder<int>(
                            valueListenable:
                                ConnectivityService.instance.retryCount,
                            builder:
                                (BuildContext context, int count, Widget? _) {
                              return Text(
                                count > 1
                                    ? 'YENİDEN BAĞLANIYOR... ($count)'
                                    : 'YENİDEN BAĞLANIYOR...',
                                style: GoogleFonts.urbanist(
                                  color: AppColors.liquidGold
                                      .withValues(alpha: 0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      _RetryButton(
                        retrying: _retrying,
                        onPressed: _retrying ? null : _retry,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Reconnected: üstte kısa yeşil bant ─────────────────────────────────────
  Widget _buildReconnectedBanner() {
    return _overlayShell(
      child: Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double t, Widget? child) {
              return Transform.translate(
                offset: Offset(0, -30 * (1 - t)),
                child: Opacity(opacity: t, child: child),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: AppColors.spaceNavy,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.toxicNeon.withValues(alpha: 0.6),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.toxicNeon.withValues(alpha: 0.25),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.wifi_rounded,
                    color: AppColors.toxicNeon,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Bağlantı kuruldu',
                    style: GoogleFonts.urbanist(
                      color: AppColors.toxicNeon,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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

class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.retrying, required this.onPressed});

  final bool retrying;
  final VoidCallback? onPressed;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null && !widget.retrying;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.liquidGold.withValues(alpha: enabled ? 1 : 0.45),
                Color.lerp(
                      AppColors.liquidGold,
                      Colors.black,
                      0.22,
                    )!
                    .withValues(alpha: enabled ? 1 : 0.45),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.liquidGold.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.retrying)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: AppColors.carbonVoid,
                    strokeWidth: 2,
                  ),
                )
              else
                const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: AppColors.carbonVoid,
                ),
              const SizedBox(width: 8),
              Text(
                'Tekrar Dene',
                style: GoogleFonts.urbanist(
                  color: AppColors.carbonVoid,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
