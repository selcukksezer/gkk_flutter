import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../models/leaderboard_model.dart';
import '../../../shaders/social/theme/social_theme_tokens.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'leaderboard_design.dart';

/// CustomPainter rendering 2027 Aion 2 Animated Celestial Champion Rays.
/// Simulates celestial beacon light shafts, sweeping iridescent rays, and ascending star dust.
class CelestialChampionRaysPainter extends CustomPainter {
  CelestialChampionRaysPainter({
    required this.animationValue,
    required this.accentColor,
  });

  final double animationValue;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    // 1. Cosmic Abyssal Deep Gradient Base
    final Paint bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          SocialThemeTokens.abyssVoid,
          SocialThemeTokens.abyssDeep,
          SocialThemeTokens.abyssCard,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Beacon Origin (centered slightly above middle)
    final Offset beaconCenter = Offset(size.width * 0.5, size.height * 0.45);
    final double maxRayLength = math.sqrt(size.width * size.width + size.height * size.height);

    // 3. Radial Ambient Beacon Glow
    final double pulse = 0.88 + 0.12 * math.sin(animationValue * 2 * math.pi);
    final Paint beaconPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          accentColor.withValues(alpha: 0.35 * pulse),
          SocialThemeTokens.aetherCyan.withValues(alpha: 0.15 * pulse),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: beaconCenter, radius: size.height * 1.2));
    canvas.drawCircle(beaconCenter, size.height * 1.2, beaconPaint);

    // 4. Sweeping Celestial Rays (12 rays rotating smoothly)
    const int numRays = 12;
    const double angleStep = (2 * math.pi) / numRays;
    final double currentAngleOffset = animationValue * 2 * math.pi * 0.35;

    final Paint rayPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (int i = 0; i < numRays; i++) {
      final double baseAngle = (i * angleStep) + currentAngleOffset;
      final double widthVariation = 0.12 + 0.04 * math.sin((animationValue * 4 * math.pi) + i);
      final double rayAlpha = (0.08 + 0.06 * math.sin((animationValue * 2 * math.pi) + i));

      final Path rayPath = Path()
        ..moveTo(beaconCenter.dx, beaconCenter.dy)
        ..lineTo(
          beaconCenter.dx + math.cos(baseAngle - widthVariation) * maxRayLength,
          beaconCenter.dy + math.sin(baseAngle - widthVariation) * maxRayLength,
        )
        ..lineTo(
          beaconCenter.dx + math.cos(baseAngle + widthVariation) * maxRayLength,
          beaconCenter.dy + math.sin(baseAngle + widthVariation) * maxRayLength,
        )
        ..close();

      rayPaint.shader = LinearGradient(
        begin: Alignment.center,
        end: Alignment.bottomCenter,
        colors: <Color>[
          SocialThemeTokens.celestialGoldLight.withValues(alpha: rayAlpha * 1.6),
          accentColor.withValues(alpha: rayAlpha),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: beaconCenter, radius: maxRayLength));

      canvas.drawPath(rayPath, rayPaint);
    }

    // 5. Celestial Star Dust / Aether Sparkles (14 deterministic specks)
    final Paint sparklePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 14; i++) {
      final double seed = (i * 1.618) % 1.0;
      final double t = (animationValue + seed) % 1.0;
      final double angle = (i * 0.897) + (animationValue * 0.2);
      final double dist = (size.width * 0.45) * t;
      final double px = beaconCenter.dx + math.cos(angle) * dist;
      final double py = beaconCenter.dy + math.sin(angle) * (dist * 0.5) - (t * 22);
      final double alpha = math.sin(t * math.pi) * 0.8;
      final double pSize = 1.0 + (seed * 1.8);

      sparklePaint.color = SocialThemeTokens.celestialGoldLight.withValues(alpha: alpha);
      canvas.drawCircle(Offset(px, py), pSize, sparklePaint);
    }

    // 6. Cyber-Celestial Crown / Trophy Constellation Motif (Watermark)
    _drawCrownTrophyMotif(canvas, size, accentColor);

    // 7. Luminous Diagonal Gradient Shimmer Sweep
    _drawLuminousSweep(canvas, size);

    // 8. Bottom Luminous Horizon Line with Iridescent Gradient
    final Paint linePaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Colors.transparent,
          SocialThemeTokens.aetherCyan,
          SocialThemeTokens.celestialGold,
          SocialThemeTokens.daevaPrismViolet,
          Colors.transparent,
        ],
        stops: <double>[0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, size.height - 1.5, size.width, 1.5))
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height - 0.75),
      Offset(size.width, size.height - 0.75),
      linePaint,
    );
  }

  void _drawCrownTrophyMotif(Canvas canvas, Size size, Color accent) {
    final double cx = size.width - 54;
    final double cy = size.height * 0.50;
    final double pulse =
        0.84 + 0.16 * math.sin(animationValue * 2 * math.pi + 1.2);

    // 1. Ambient radiant halo behind crown
    final Paint haloPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          SocialThemeTokens.celestialGold.withValues(alpha: 0.16 * pulse),
          accent.withValues(alpha: 0.08 * pulse),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 46));
    canvas.drawCircle(Offset(cx, cy), 46, haloPaint);

    // 2. Faint Celestial Orbital / Constellation Ring
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = SocialThemeTokens.celestialGold.withValues(alpha: 0.16 * pulse);
    canvas.drawCircle(Offset(cx, cy), 32, ringPaint);

    // 3. Cyber Crown / Trophy Motif Path
    final Path crownPath = Path();
    // Crown Base Bar
    crownPath.moveTo(cx - 20, cy + 12);
    crownPath.lineTo(cx + 20, cy + 12);
    crownPath.lineTo(cx + 17, cy + 7);
    crownPath.lineTo(cx - 17, cy + 7);
    crownPath.close();

    // Crown Peaks: outer left, valley, high center, valley, outer right
    crownPath.moveTo(cx - 17, cy + 7);
    crownPath.lineTo(cx - 22, cy - 8);
    crownPath.lineTo(cx - 11, cy + 1);
    crownPath.lineTo(cx, cy - 18);
    crownPath.lineTo(cx + 11, cy + 1);
    crownPath.lineTo(cx + 22, cy - 8);
    crownPath.lineTo(cx + 17, cy + 7);
    crownPath.close();

    final Paint crownFillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          SocialThemeTokens.celestialGoldLight.withValues(alpha: 0.18 * pulse),
          accent.withValues(alpha: 0.07 * pulse),
        ],
      ).createShader(Rect.fromLTWH(cx - 25, cy - 25, 50, 45))
      ..style = PaintingStyle.fill;
    canvas.drawPath(crownPath, crownFillPaint);

    final Paint crownStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          SocialThemeTokens.celestialGoldLight.withValues(alpha: 0.45 * pulse),
          accent.withValues(alpha: 0.30 * pulse),
          SocialThemeTokens.daevaPrismCyan.withValues(alpha: 0.25 * pulse),
        ],
      ).createShader(Rect.fromLTWH(cx - 25, cy - 25, 50, 45));
    canvas.drawPath(crownPath, crownStrokePaint);

    // 4. Central Diamond Star above Crown
    final Path starPath = Path();
    final double starCy = cy - 23;
    starPath.moveTo(cx, starCy - 5);
    starPath.lineTo(cx + 3, starCy);
    starPath.lineTo(cx, starCy + 5);
    starPath.lineTo(cx - 3, starCy);
    starPath.close();

    final Paint starPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = SocialThemeTokens.celestialGoldLight
          .withValues(alpha: 0.70 * pulse);
    canvas.drawPath(starPath, starPaint);

    // 5. Crown Jewel Nodes
    final Paint jewelPaint = Paint()..style = PaintingStyle.fill;
    jewelPaint.color =
        SocialThemeTokens.aetherCyanLight.withValues(alpha: 0.60 * pulse);
    canvas.drawCircle(Offset(cx - 22, cy - 8), 1.6, jewelPaint);
    canvas.drawCircle(Offset(cx + 22, cy - 8), 1.6, jewelPaint);
    jewelPaint.color =
        SocialThemeTokens.celestialGoldLight.withValues(alpha: 0.75 * pulse);
    canvas.drawCircle(Offset(cx, cy - 18), 2.0, jewelPaint);
  }

  void _drawLuminousSweep(Canvas canvas, Size size) {
    final double sweepWidth = size.width * 0.42;
    final double progress = animationValue;
    final double startX =
        -sweepWidth + ((size.width + sweepWidth * 2) * progress);

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final Path sweepPath = Path()
      ..moveTo(startX - 25, 0)
      ..lineTo(startX + sweepWidth - 25, 0)
      ..lineTo(startX + sweepWidth + 25, size.height)
      ..lineTo(startX + 25, size.height)
      ..close();

    final Paint sweepPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.transparent,
          SocialThemeTokens.aetherCyanLight.withValues(alpha: 0.03),
          SocialThemeTokens.celestialGoldLight.withValues(alpha: 0.14),
          SocialThemeTokens.daevaPrismWhite.withValues(alpha: 0.19),
          SocialThemeTokens.celestialGold.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.25, 0.5, 0.70, 0.85, 1.0],
      ).createShader(
        Rect.fromLTWH(startX - 25, 0, sweepWidth + 50, size.height),
      );

    canvas.drawPath(sweepPath, sweepPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CelestialChampionRaysPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.accentColor != accentColor;
  }
}

/// 2027 Aion 2 Animated Header Banner with Celestial Champion Rays Shader.
///
/// Features:
/// - Luminous gradient sweep and celestial trophy/crown constellation motif.
/// - Frosted glass backdrop with dynamic ambient beacon glow.
/// - Season reset countdown timer pill with tabular monospace digits.
/// - Elevated Cyber-Fantasy luxury typography and champion crest.
class LeaderboardAnimatedHeaderBanner extends StatefulWidget {
  const LeaderboardAnimatedHeaderBanner({
    super.key,
    required this.category,
    required this.weekly,
    required this.totalEntries,
    required this.isLoading,
    required this.onRefresh,
    this.seasonTitle,
    this.seasonResetDate,
    this.seasonResetDuration,
  });

  final LeaderboardCategory category;
  final bool weekly;
  final int totalEntries;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final String? seasonTitle;
  final DateTime? seasonResetDate;
  final Duration? seasonResetDuration;

  @override
  State<LeaderboardAnimatedHeaderBanner> createState() =>
      _LeaderboardAnimatedHeaderBannerState();
}

class _LeaderboardAnimatedHeaderBannerState
    extends State<LeaderboardAnimatedHeaderBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _raysCtrl;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _raysCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    )..repeat();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _raysCtrl.dispose();
    super.dispose();
  }

  Duration _getRemainingTime() {
    if (widget.seasonResetDate != null) {
      final Duration diff = widget.seasonResetDate!.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    }
    if (widget.seasonResetDuration != null) {
      return widget.seasonResetDuration!;
    }
    final DateTime now = DateTime.now().toUtc();
    if (widget.weekly) {
      // Weekly reset: Next Monday 00:00 UTC
      final int daysUntilMonday =
          ((8 - now.weekday) % 7) == 0 ? 7 : ((8 - now.weekday) % 7);
      final DateTime nextMonday =
          DateTime.utc(now.year, now.month, now.day + daysUntilMonday);
      final Duration remaining = nextMonday.difference(now);
      return remaining.isNegative ? Duration.zero : remaining;
    } else {
      // Seasonal reset: End of current month UTC
      final DateTime seasonEnd = DateTime.utc(now.year, now.month + 1, 1);
      final Duration remaining = seasonEnd.difference(now);
      return remaining.isNegative ? Duration.zero : remaining;
    }
  }

  String _formatDuration(Duration duration) {
    final int days = duration.inDays;
    final int hours = duration.inHours % 24;
    final int minutes = duration.inMinutes % 60;
    final int seconds = duration.inSeconds % 60;

    if (days > 0) {
      return '${days}g ${hours.toString().padLeft(2, '0')}s ${minutes.toString().padLeft(2, '0')}d';
    }
    return '${hours.toString().padLeft(2, '0')}s ${minutes.toString().padLeft(2, '0')}d ${seconds.toString().padLeft(2, '0')}sn';
  }

  @override
  Widget build(BuildContext context) {
    final Color categoryAccent =
        LeaderboardDesign.accentForCategory(widget.category.key);
    final Duration remaining = _getRemainingTime();
    final String formattedRemaining = _formatDuration(remaining);

    return AnimatedBuilder(
      animation: _raysCtrl,
      builder: (BuildContext context, Widget? child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: categoryAccent.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: categoryAccent.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: <Widget>[
                // Animated Celestial Champion Rays & Trophy Shader Background
                Positioned.fill(
                  child: CustomPaint(
                    painter: CelestialChampionRaysPainter(
                      animationValue: _raysCtrl.value,
                      accentColor: categoryAccent,
                    ),
                  ),
                ),
                // Frosted Glass Blur Overlay
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.28),
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Row(
                      children: <Widget>[
                        // Pulsing Champion Category Crest with Crown Jewel
                        _buildCategoryCrest(categoryAccent),
                        const SizedBox(width: 12),
                        // Title & Subtitle Metadata with Countdown Pill
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              // Season Badge and Live Status Pill
                              _buildSeasonHeaderTag(categoryAccent),
                              const SizedBox(height: 3),
                              // Primary Title
                              Text(
                                '${widget.category.label} Sıralaması',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.h3.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                  shadows: <Shadow>[
                                    Shadow(
                                      color:
                                          categoryAccent.withValues(alpha: 0.7),
                                      blurRadius: 8,
                                    ),
                                    Shadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.95),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 5),
                              // Season Reset Countdown Pill with Glass Backdrop
                              _buildSeasonResetPill(
                                accent: categoryAccent,
                                remainingText: formattedRemaining,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Luxury Tactile Refresh Button
                        _buildRefreshButton(categoryAccent),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeasonHeaderTag(Color accent) {
    final String seasonLabel = widget.seasonTitle?.toUpperCase() ??
        (widget.weekly ? 'HAFTALIK LİG' : 'SEZON IV • ELYSIAN DAWN');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Season Crown Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                SocialThemeTokens.celestialGold.withValues(alpha: 0.28),
                SocialThemeTokens.celestialGoldDark.withValues(alpha: 0.14),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: SocialThemeTokens.celestialGold.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.workspace_premium_rounded,
                size: 10,
                color: SocialThemeTokens.celestialGoldLight,
              ),
              const SizedBox(width: 3),
              Text(
                seasonLabel,
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: SocialThemeTokens.celestialGoldLight,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Active Pulse Dot
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SocialThemeTokens.aetherCyan,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: SocialThemeTokens.aetherCyan.withValues(alpha: 0.8),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'CANLI',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: SocialThemeTokens.aetherCyanLight,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonResetPill({
    required Color accent,
    required String remainingText,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: SocialThemeTokens.abyssVoid.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: accent.withValues(alpha: 0.35),
            width: 0.8,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.hourglass_bottom_rounded,
              size: 11,
              color: SocialThemeTokens.celestialGoldLight,
            ),
            const SizedBox(width: 4),
            Text(
              widget.weekly ? 'Sıfırlanma: ' : 'Bitiş: ',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              remainingText,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: SocialThemeTokens.celestialGoldLight,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                letterSpacing: 0.2,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const Icon(
              Icons.group_rounded,
              size: 10.5,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 3),
            Text(
              '${widget.totalEntries} Daeva',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCrest(Color accent) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                accent.withValues(alpha: 0.5),
                SocialThemeTokens.abyssVoid.withValues(alpha: 0.9),
              ],
              stops: const <double>[0.2, 1.0],
            ),
            border: Border.all(
              color: accent.withValues(alpha: 0.85),
              width: 1.6,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.40),
                blurRadius: 14,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.category.icon,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        // Mini Celestial Crown Badge at top-right
        Positioned(
          top: -3,
          right: -2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  SocialThemeTokens.celestialGoldLight,
                  SocialThemeTokens.celestialGoldDark,
                ],
              ),
              border: Border.all(
                color: Colors.black,
                width: 1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: SocialThemeTokens.celestialGold.withValues(alpha: 0.6),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 10,
              color: SocialThemeTokens.abyssVoid,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRefreshButton(Color accent) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.isLoading ? null : widget.onRefresh,
        borderRadius: BorderRadius.circular(22),
        splashColor: accent.withValues(alpha: 0.25),
        highlightColor: accent.withValues(alpha: 0.12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SocialThemeTokens.abyssCardSurface.withValues(alpha: 0.85),
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.16),
                blurRadius: 8,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                )
              : Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: accent,
                ),
        ),
      ),
    );
  }
}
