import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'notification_category.dart';

/// 2027 Aion 2 Mobile Stylized Runic Empty-State Illustration.
///
/// Features a procedural animated arcane runic sigil with breathing celestial glow,
/// rotating astrolabe geometry, obsidian frosted glassmorphism, responsive 390x844 scaling,
/// multi-tier haptic feedback, and lore-grounded status messaging per category.
class NotificationRunicEmptyState extends StatefulWidget {
  const NotificationRunicEmptyState({
    super.key,
    required this.category,
    this.onRefresh,
    this.onResetCategory,
  });

  final NotificationCategory category;
  final VoidCallback? onRefresh;
  final VoidCallback? onResetCategory;

  @override
  State<NotificationRunicEmptyState> createState() => _NotificationRunicEmptyStateState();
}

class _NotificationRunicEmptyStateState extends State<NotificationRunicEmptyState>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  late final AnimationController _rotationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 24000),
  )..repeat();

  late final AnimationController _tapController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  late final Listenable _mergedAnimation = Listenable.merge(<Listenable>[
    _pulseController,
    _rotationController,
    _tapController,
  ]);

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _onSigilTapped() {
    HapticFeedback.selectionClick();
    _tapController.forward(from: 0.0);
  }

  void _onTapDown(TapDownDetails _) {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.category.accentColor;

    final (String title, String subtitle, String tapPrompt) = switch (widget.category) {
      NotificationCategory.all => (
          'KUSURSUZ SESSİZLİK',
          'Atreia semalarında şu an bekleyen bir fısıltı veya kutsal çağrı yok.',
          'Arkan mühre dokunarak yankı uyandır',
        ),
      NotificationCategory.system => (
          'SİSTEM DENGEDE',
          'Tesisler, pazar ve zanaat atölyelerinde tüm süreçler sakin ilerliyor.',
          'Mühre dokunarak sistem frekansını sına',
        ),
      NotificationCategory.combat => (
          'SAVAŞ ALANI DURGUN',
          'Bekleyen bir PvP düellosu veya intikam yemini bulunmuyor.',
          'Mühre dokunarak savaş borusunu sına',
        ),
      NotificationCategory.social => (
          'YALNIZ SEYYAH',
          'Yeni bir arkadaşlık isteği veya fısıltı mesajı henüz ulaşmadı.',
          'Mühre dokunarak dostluk teline dokun',
        ),
      NotificationCategory.rewards => (
          'HAZİNE SANDIĞI BOŞ',
          'Şu anda toplanmayı bekleyen yeni bir ödül veya sandık yok.',
          'Mühre dokunarak şans aurasını tazele',
        ),
    };

    return SafeArea(
      top: false,
      bottom: true,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Responsive scaling tuned for 390x844 mobile viewports
          final double maxCardWidth = math.min(352.0, constraints.maxWidth - 32.0);
          final bool isCompact = constraints.maxHeight < 580;
          final double sigilSize = isCompact ? 144.0 : 168.0;

          return Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxCardWidth),
                child: AnimatedBuilder(
                  animation: _mergedAnimation,
                  builder: (BuildContext context, Widget? child) {
                    final double pulse = _pulseController.value;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: isCompact ? AppSpacing.lg : AppSpacing.xl,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                AppColors.bgCardElevated.withValues(alpha: 0.72),
                                AppColors.bgSurface.withValues(alpha: 0.55),
                                AppColors.bgDeep.withValues(alpha: 0.82),
                              ],
                            ),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.28 + (pulse * 0.16)),
                              width: 1.2,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: accent.withValues(alpha: 0.12 + (pulse * 0.08)),
                                blurRadius: 36,
                                spreadRadius: -2,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Interactive Animated Runic Sigil
                      AnimatedBuilder(
                        animation: _mergedAnimation,
                        builder: (BuildContext context, Widget? child) {
                          final double pulse = _pulseController.value;
                          final double rotation = _rotationController.value * 2 * math.pi;
                          final double tapVal = _tapController.value;
                          final double bounceScale = 1.0 - (math.sin(tapVal * math.pi) * 0.12);

                          return GestureDetector(
                            onTapDown: _onTapDown,
                            onTap: _onSigilTapped,
                            behavior: HitTestBehavior.opaque,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: SizedBox(
                                width: sigilSize,
                                height: sigilSize,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: <Widget>[
                                    // Ambient Radial Aura
                                    Container(
                                      width: (sigilSize * 0.82) + (pulse * (sigilSize * 0.12)),
                                      height: (sigilSize * 0.82) + (pulse * (sigilSize * 0.12)),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: <Color>[
                                            accent.withValues(
                                              alpha: 0.25 + (pulse * 0.14) + (tapVal * 0.12),
                                            ),
                                            accent.withValues(alpha: 0.06),
                                            Colors.transparent,
                                          ],
                                          stops: const <double>[0.0, 0.65, 1.0],
                                        ),
                                      ),
                                    ),
                                    // Procedural Runic Geometry Canvas
                                    CustomPaint(
                                      size: Size(sigilSize * 0.94, sigilSize * 0.94),
                                      painter: _AionRunicSigilPainter(
                                        accentColor: accent,
                                        pulse: pulse,
                                        rotation: rotation,
                                        tapResonance: tapVal,
                                      ),
                                    ),
                                    // Central Category Glyph with spring bounce
                                    Transform.scale(
                                      scale: bounceScale,
                                      child: Container(
                                        width: sigilSize * 0.32,
                                        height: sigilSize * 0.32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.bgDeep.withValues(alpha: 0.92),
                                          border: Border.all(
                                            color: accent.withValues(
                                              alpha: 0.5 + (pulse * 0.3) + (tapVal * 0.2),
                                            ),
                                            width: 1.5,
                                          ),
                                          boxShadow: <BoxShadow>[
                                            BoxShadow(
                                              color: accent.withValues(
                                                alpha: 0.28 + (pulse * 0.22) + (tapVal * 0.25),
                                              ),
                                              blurRadius: 18 + (tapVal * 12),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          widget.category.icon,
                                          color: accent.withValues(alpha: 0.92 + (pulse * 0.08)),
                                          size: sigilSize * 0.16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.lg),

                      // Category Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          color: accent.withValues(alpha: 0.14),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.38),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.85),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.category.label.toUpperCase(),
                              style: GoogleFonts.urbanist(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isCompact ? AppSpacing.sm : AppSpacing.md),

                      // Title
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.urbanist(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      // Subtitle
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 290),
                        child: Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.urbanist(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Interactive Tap Resonance Hint
                      GestureDetector(
                        onTapDown: _onTapDown,
                        onTap: _onSigilTapped,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              color: accent.withValues(alpha: 0.08),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.22),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.touch_app_rounded,
                                  size: 13,
                                  color: accent.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    tapPrompt,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.urbanist(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.4,
                                      color: accent.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.lg),

                      // Action Buttons with multi-tier haptics
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (widget.category != NotificationCategory.all &&
                              widget.onResetCategory != null) ...<Widget>[
                            OutlinedButton.icon(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                widget.onResetCategory?.call();
                              },
                              icon: const Icon(Icons.apps_rounded, size: 16),
                              label: const Text('TÜMÜNE DÖN'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: BorderSide(
                                  color: AppColors.borderBright.withValues(alpha: 0.5),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                textStyle: GoogleFonts.urbanist(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          if (widget.onRefresh != null)
                            ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                widget.onRefresh?.call();
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('YENİLE'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.bgCardElevated,
                                foregroundColor: accent,
                                side: BorderSide(color: accent.withValues(alpha: 0.4)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                textStyle: GoogleFonts.urbanist(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                shadowColor: accent.withValues(alpha: 0.3),
                                elevation: 4,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter rendering an intricate Aion-2 arcane runic circle with dynamic rotation and tap resonance.
class _AionRunicSigilPainter extends CustomPainter {
  const _AionRunicSigilPainter({
    required this.accentColor,
    required this.pulse,
    required this.rotation,
    required this.tapResonance,
  });

  final Color accentColor;
  final double pulse;
  final double rotation;
  final double tapResonance;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;

    // 0. Tap Resonance Shockwave
    if (tapResonance > 0.0 && tapResonance < 1.0) {
      final double shockRadius = 28.0 + (radius - 28.0) * tapResonance;
      final double shockAlpha = (1.0 - tapResonance) * 0.55;
      final Paint shockPaint = Paint()
        ..color = accentColor.withValues(alpha: shockAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1.0 - tapResonance * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(center, shockRadius, shockPaint);
    }

    final Paint ringPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.35 + (pulse * 0.2))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final Paint faintRingPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.16 + (pulse * 0.08))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final Paint glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.18 + (pulse * 0.15))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    // 1. Outermost Ring with subtle luminous aura
    canvas.drawCircle(center, radius - 4, glowPaint);
    canvas.drawCircle(center, radius - 4, ringPaint);

    // 2. Cardinal Rune Arc Breaks on Outer Perimeter
    final Paint arcAccentPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.65 + (pulse * 0.25))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const int arcSegments = 4;
    for (int i = 0; i < arcSegments; i++) {
      final double startAngle = (i * math.pi / 2) + (math.pi / 8) + (rotation * 0.15);
      const double sweepAngle = (math.pi / 2) - (math.pi / 4);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle,
        sweepAngle,
        false,
        arcAccentPaint,
      );
    }

    // 3. Middle decorative dotted ring (Astrolabe celestial markers)
    final double dottedRadius = radius - 15;
    const int dotCount = 32;
    final Paint microDotPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.28 + (pulse * 0.15))
      ..style = PaintingStyle.fill;
    for (int i = 0; i < dotCount; i++) {
      final double dotAngle = (i * 2 * math.pi / dotCount) - (rotation * 0.2);
      final Offset dotPos = Offset(
        center.dx + dottedRadius * math.cos(dotAngle),
        center.dy + dottedRadius * math.sin(dotAngle),
      );
      canvas.drawCircle(dotPos, 1.0, microDotPaint);
    }

    // 4. Inner concentric ring
    canvas.drawCircle(center, radius - 28, ringPaint);

    // 5. Arcane Ticks & Celestial Notches on Outer Ring (16 ticks)
    final Paint tickPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.6 + (pulse * 0.3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    const int tickCount = 16;
    for (int i = 0; i < tickCount; i++) {
      final double angle = (i * 2 * math.pi) / tickCount + (rotation * 0.05);
      final bool isMajor = i % 4 == 0;
      final double tickLength = isMajor ? 7.0 : 4.0;
      final double outerR = radius - 4;
      final double innerR = outerR - tickLength;

      final Offset p1 = Offset(
        center.dx + outerR * math.cos(angle),
        center.dy + outerR * math.sin(angle),
      );
      final Offset p2 = Offset(
        center.dx + innerR * math.cos(angle),
        center.dy + innerR * math.sin(angle),
      );
      canvas.drawLine(p1, p2, isMajor ? tickPaint : faintRingPaint);
    }

    // 6. Eight-pointed Star / Cardinal Geometric Diamonds with dynamic rotation
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final Path starPath = Path();
    const int points = 8;
    for (int i = 0; i < points; i++) {
      final double outerAngle = (i * 2 * math.pi) / points - (math.pi / 2);
      final double innerAngle = outerAngle + (math.pi / points);
      final double rOut = radius - 16;
      final double rIn = radius - 34;

      final double x1 = rOut * math.cos(outerAngle);
      final double y1 = rOut * math.sin(outerAngle);
      final double x2 = rIn * math.cos(innerAngle);
      final double y2 = rIn * math.sin(innerAngle);

      if (i == 0) {
        starPath.moveTo(x1, y1);
      } else {
        starPath.lineTo(x1, y1);
      }
      starPath.lineTo(x2, y2);
    }
    starPath.close();

    final Paint starPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.22 + (pulse * 0.2))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawPath(starPath, starPaint);

    // Star point micro glyphs
    final Paint starPointPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.8 + (pulse * 0.2))
      ..style = PaintingStyle.fill;
    for (int i = 0; i < points; i++) {
      final double outerAngle = (i * 2 * math.pi) / points - (math.pi / 2);
      final double rOut = radius - 16;
      final Offset pt = Offset(rOut * math.cos(outerAngle), rOut * math.sin(outerAngle));
      canvas.drawCircle(pt, 1.6, starPointPaint);
    }

    canvas.restore();

    // 7. Counter-rotating Cardinal Floating Rune Diamonds
    final Paint diamondPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.75 + (pulse * 0.25))
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final double angle = (i * math.pi / 2) - (rotation * 0.6);
      final double dotR = radius - 8;
      final double cx = center.dx + dotR * math.cos(angle);
      final double cy = center.dy + dotR * math.sin(angle);

      // Draw mini diamond
      final Path diamond = Path()
        ..moveTo(cx, cy - 2.5)
        ..lineTo(cx + 2.5, cy)
        ..lineTo(cx, cy + 2.5)
        ..lineTo(cx - 2.5, cy)
        ..close();
      canvas.drawPath(diamond, diamondPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AionRunicSigilPainter oldDelegate) =>
      oldDelegate.pulse != pulse ||
      oldDelegate.rotation != rotation ||
      oldDelegate.tapResonance != tapResonance ||
      oldDelegate.accentColor != accentColor;
}
