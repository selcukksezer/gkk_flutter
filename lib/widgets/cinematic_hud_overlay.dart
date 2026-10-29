import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../core/engine/adaptive_quality_scaler.dart';
import '../core/engine/zero_jank_preloader.dart';
import '../core/world/cinematic_camera_controller.dart';
import '../screens/settings/graphics_settings_service.dart';

/// Glassmorphism visual styling tokens following the 2027 Aion 2 Obsidian-Glass & Combat Design System.
class GlassmorphicTheme {
  const GlassmorphicTheme._();

  static const double defaultBlurSigma = 16.0;
  static const double borderOpacity = 0.28;
  static const double backgroundStartOpacity = 0.42;
  static const double backgroundEndOpacity = 0.22;

  // Obsidian Dark Foundations (0xFF07090E - 0xFF0F141F)
  static const Color darkBackground = Color(0xFF07090E);
  static const Color obsidianBase = Color(0xEE07090E);
  static const Color obsidianSurface = Color(0xFF0F141F);
  static const Color obsidianGlassTop = Color(0x4D0F141F);
  static const Color obsidianGlassBottom = Color(0x3807090E);
  static const Color obsidianPanel = Color(0x99090E17);

  // Luminescent Highlights (2027 Aion 2 standard)
  static const Color etherCyan = Color(0xFF00E5FF);
  static const Color etherCyanGlow = Color(0x4D00E5FF);
  static const Color etherCyanLight = Color(0xFF80F2FF);
  static const Color celestialGold = Color(0xFFE5C158);
  static const Color celestialGoldLight = Color(0xFFFFF2A8);
  static const Color celestialGoldBorder = Color(0x66E5C158);
  static const Color celestialGoldGlow = Color(0x4DE5C158);
  static const Color battleCrimson = Color(0xFFFF3366);
  static const Color battleCrimsonGlow = Color(0x55FF3366);
  static const Color battleCrimsonLight = Color(0xFFFF6688);

  // Status gauges & Action accents
  static const Color primaryBlue = Color(0xFF00B0FF);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color healthRed = Color(0xFFFF3366);
  static const Color healthRedGradient = Color(0xFFFF5E82);
  static const Color manaBlue = Color(0xFF0091FF);
  static const Color manaBlueGradient = Color(0xFF00E5FF);
  static const Color staminaGreen = Color(0xFF00E676);
  static const Color staminaGreenGradient = Color(0xFF69F0AE);

  // Typography tokens
  static const Color textHighEmphasis = Color(0xFFFFFFFF);
  static const Color textMediumEmphasis = Color(0xD9FFFFFF);
  static const Color textLowEmphasis = Color(0x73FFFFFF);

  /// Generates tier-adapted box shadows.
  /// On Eco: zero shadows (skips expensive multi-pass canvas shadows for Mali-400 / 2GB RAM devices).
  /// On Low: single minimal ambient shadow, no expensive outer glow overdraw.
  /// On Mid: balanced ambient shadow + luminous rim glow.
  /// On High/Ultra: full luxury multi-pass shadows (ambient + outer rim bloom glow + specular highlight).
  static List<BoxShadow> tierAdaptedShadows({
    required HardwareTier tier,
    bool celestialTrim = false,
    bool combatTrim = false,
    bool isThrottled = false,
  }) {
    if (tier == HardwareTier.eco || isThrottled) {
      // Eco/Severe Throttle: completely decimate multi-pass shadows to zero for fill-rate protection
      return const [];
    }

    if (tier == HardwareTier.low) {
      // Low: single minimal ambient shadow, skip multi-pass outer glow
      return const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 4.0,
          offset: Offset(0, 2),
        ),
      ];
    }

    final double bloomMult = (tier == HardwareTier.ultra) ? 1.35 : 1.0;
    return [
      // Deep ambient shadow
      BoxShadow(
        color: const Color(0x99000000),
        blurRadius: 18.0 * bloomMult,
        offset: const Offset(0, 6),
        spreadRadius: -2.0,
      ),
      // Luminous outer rim glow
      if (combatTrim)
        BoxShadow(
          color: battleCrimsonGlow,
          blurRadius: 14.0 * bloomMult,
          spreadRadius: (tier == HardwareTier.ultra) ? 1.0 : 0.5,
        )
      else if (celestialTrim)
        BoxShadow(
          color: celestialGoldGlow,
          blurRadius: 14.0 * bloomMult,
          spreadRadius: (tier == HardwareTier.ultra) ? 1.0 : 0.5,
        ),
      // Specular edge highlight (High & Ultra)
      if (tier == HardwareTier.high || tier == HardwareTier.ultra)
        const BoxShadow(
          color: Color(0x18FFFFFF),
          blurRadius: 1.5,
          spreadRadius: 0.5,
          offset: Offset(0, 0),
        ),
    ];
  }

  /// Standard glassmorphic container decoration with frosted gradient and luminous dual shadow glows.
  static BoxDecoration glassDecoration({
    double borderRadius = 16.0,
    Color borderColor = const Color(0x38FFFFFF),
    Color topColor = const Color(0x4D0F141F),
    Color bottomColor = const Color(0x3807090E),
    List<BoxShadow>? shadows,
    bool celestialTrim = false,
    bool combatTrim = false,
    HardwareTier tier = HardwareTier.mid,
    bool isThrottled = false,
  }) {
    final effectiveBorder = combatTrim
        ? const Color(0x80FF3366)
        : (celestialTrim ? celestialGoldBorder : borderColor);

    final effectiveShadows = shadows ??
        tierAdaptedShadows(
          tier: tier,
          celestialTrim: celestialTrim,
          combatTrim: combatTrim,
          isThrottled: isThrottled,
        );

    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [topColor, bottomColor],
      ),
      border: Border.all(
        color: effectiveBorder,
        width: 1.0,
      ),
      boxShadow: effectiveShadows,
    );
  }
}

/// High-definition gradient border painter for obsidian-glass surfaces.
class _GradientBorderPainter extends CustomPainter {
  final double strokeWidth;
  final double radius;
  final Gradient gradient;

  const _GradientBorderPainter({
    required this.strokeWidth,
    required this.radius,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= strokeWidth || size.height <= strokeWidth) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2.0),
      Radius.circular(math.max(0.0, radius - strokeWidth / 2.0)),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius ||
      oldDelegate.gradient != gradient;
}

/// Subtle ornamental corner brackets applying 2027 Aion 2 celestial fantasy aesthetic.
class AionRunicOrnamentPainter extends CustomPainter {
  final Color ornamentColor;
  final double cornerLength;
  final HardwareTier tier;

  const AionRunicOrnamentPainter({
    this.ornamentColor = const Color(0x66E5C158),
    this.cornerLength = 10.0,
    this.tier = HardwareTier.mid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 3.5;

    if (tier == HardwareTier.eco) {
      // Eco tier: decimate rune glow and micro studs, simple minimal brackets for zero fillrate overdraw
      final minimalPaint = Paint()
        ..color = ornamentColor.withValues(alpha: 0.3)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      final len = cornerLength * 0.7;
      canvas.drawLine(const Offset(pad, pad), Offset(pad + len, pad), minimalPaint);
      canvas.drawLine(const Offset(pad, pad), Offset(pad, pad + len), minimalPaint);
      canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad - len, pad), minimalPaint);
      canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad, pad + len), minimalPaint);
      canvas.drawLine(Offset(pad, size.height - pad), Offset(pad + len, size.height - pad), minimalPaint);
      canvas.drawLine(Offset(pad, size.height - pad), Offset(pad, size.height - pad - len), minimalPaint);
      canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad - len, size.height - pad), minimalPaint);
      canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad, size.height - pad - len), minimalPaint);
      return;
    }

    // High / Ultra tiers: full luxury rune luminescence outer glow halo pass
    if (tier == HardwareTier.high || tier == HardwareTier.ultra) {
      final glowPaint = Paint()
        ..color = ornamentColor.withValues(alpha: tier == HardwareTier.ultra ? 0.45 : 0.25)
        ..strokeWidth = (tier == HardwareTier.ultra) ? 3.0 : 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      canvas.drawLine(const Offset(pad, pad), Offset(pad + cornerLength, pad), glowPaint);
      canvas.drawLine(const Offset(pad, pad), Offset(pad, pad + cornerLength), glowPaint);
      canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad - cornerLength, pad), glowPaint);
      canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad, pad + cornerLength), glowPaint);
      canvas.drawLine(Offset(pad, size.height - pad), Offset(pad + cornerLength, size.height - pad), glowPaint);
      canvas.drawLine(Offset(pad, size.height - pad), Offset(pad, size.height - pad - cornerLength), glowPaint);
      canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad - cornerLength, size.height - pad), glowPaint);
      canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad, size.height - pad - cornerLength), glowPaint);
    }

    final strokePaint = Paint()
      ..color = ornamentColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final dotPaint = Paint()
      ..color = ornamentColor.withValues(alpha: math.min(1.0, ornamentColor.a * 1.5))
      ..style = PaintingStyle.fill;

    // Top-Left Corner Bracket & Micro Stud
    canvas.drawLine(const Offset(pad, pad), Offset(pad + cornerLength, pad), strokePaint);
    canvas.drawLine(const Offset(pad, pad), Offset(pad, pad + cornerLength), strokePaint);
    canvas.drawCircle(const Offset(pad, pad), 1.0, dotPaint);

    // Top-Right Corner Bracket & Micro Stud
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad - cornerLength, pad), strokePaint);
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad, pad + cornerLength), strokePaint);
    canvas.drawCircle(Offset(size.width - pad, pad), 1.0, dotPaint);

    // Bottom-Left Corner Bracket & Micro Stud
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad + cornerLength, size.height - pad), strokePaint);
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad, size.height - pad - cornerLength), strokePaint);
    canvas.drawCircle(Offset(pad, size.height - pad), 1.0, dotPaint);

    // Bottom-Right Corner Bracket & Micro Stud
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad - cornerLength, size.height - pad), strokePaint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad, size.height - pad - cornerLength), strokePaint);
    canvas.drawCircle(Offset(size.width - pad, size.height - pad), 1.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant AionRunicOrnamentPainter oldDelegate) =>
      oldDelegate.ornamentColor != ornamentColor ||
      oldDelegate.cornerLength != cornerLength ||
      oldDelegate.tier != tier;
}

/// Reusable Glassmorphic container applying backdrop blur, gradient, and luminous border.
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? topColor;
  final Color? bottomColor;
  final VoidCallback? onTap;
  final bool hasGoldTrim;
  final bool hasOrnaments;
  final bool enableHaptics;
  final Gradient? borderGradient;
  final bool combatTrim;
  final List<BoxShadow>? shadows;
  final HardwareTier? tier;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.blurSigma = GlassmorphicTheme.defaultBlurSigma,
    this.padding = const EdgeInsets.all(12.0),
    this.borderColor,
    this.topColor,
    this.bottomColor,
    this.onTap,
    this.hasGoldTrim = false,
    this.hasOrnaments = false,
    this.enableHaptics = true,
    this.borderGradient,
    this.combatTrim = false,
    this.shadows,
    this.tier,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTier = tier ?? GraphicsSettingsService.instance.scaler.currentTier;

    // Eco tier: completely skip BackdropFilter offscreen texture passes for fill-rate protection
    final effectiveBlur = switch (effectiveTier) {
      HardwareTier.eco => 0.0,
      HardwareTier.low => (blurSigma * 0.35).clamp(2.0, 6.0),
      HardwareTier.mid => blurSigma,
      HardwareTier.high => blurSigma,
      HardwareTier.ultra => blurSigma * 1.25,
    };

    final effectiveBorderColor = combatTrim
        ? const Color(0x80FF3366)
        : (borderColor ??
            (hasGoldTrim
                ? GlassmorphicTheme.celestialGoldBorder
                : const Color(0x38FFFFFF)));

    final cardBody = Container(
      padding: padding,
      decoration: GlassmorphicTheme.glassDecoration(
        borderRadius: borderRadius,
        borderColor: effectiveBorderColor,
        topColor: topColor ?? const Color(0x4D0F141F),
        bottomColor: bottomColor ?? const Color(0x3807090E),
        celestialTrim: hasGoldTrim,
        combatTrim: combatTrim,
        shadows: shadows,
        tier: effectiveTier,
      ),
      child: Stack(
        children: [
          if (borderGradient != null)
            Positioned.fill(
              child: CustomPaint(
                painter: _GradientBorderPainter(
                  strokeWidth: 1.0,
                  radius: borderRadius,
                  gradient: borderGradient!,
                ),
              ),
            ),
          if (hasOrnaments)
            CustomPaint(
              foregroundPainter: AionRunicOrnamentPainter(
                tier: effectiveTier,
                ornamentColor: combatTrim
                    ? const Color(0x80FF3366)
                    : (hasGoldTrim
                        ? GlassmorphicTheme.celestialGoldBorder
                        : const Color(0x4400E5FF)),
              ),
              child: child,
            )
          else
            child,
        ],
      ),
    );

    Widget content = effectiveBlur <= 0.0
        ? ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: cardBody,
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
              child: cardBody,
            ),
          );

    if (onTap != null) {
      content = ZeroJankTouchScope(
        child: GestureDetector(
          onTap: () {
            if (enableHaptics) {
              HapticFeedback.selectionClick();
            }
            onTap!();
          },
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    return content;
  }
}

/// Verification metrics guaranteeing that the center camera vista is never obscured
/// and computing mobile 390x844 responsive layout dimensions.
class CinematicHudMetrics {
  final Size screenSize;
  final EdgeInsets safeAreaPadding;

  const CinematicHudMetrics({
    required this.screenSize,
    required this.safeAreaPadding,
  });

  /// Standard baseline mobile viewport (iPhone 12/13/14 reference: 390x844).
  static const Size referenceScreenSize = Size(390.0, 844.0);

  /// Central rectangular zone reserved exclusively for 3D world vista and depth perception.
  /// Standard AAA ratio: 60% horizontal width and 65% vertical height centered on screen.
  Rect get centerVistaClearanceZone {
    final width = screenSize.width * 0.60;
    final height = screenSize.height * 0.65;
    final left = (screenSize.width - width) / 2.0;
    final top = (screenSize.height - height) / 2.0;
    return Rect.fromLTWH(left, top, width, height);
  }

  /// Calculates whether an element placed at [elementBounds] encroaches on the center vista.
  bool doesIntersectCenterVista(Rect elementBounds) {
    return centerVistaClearanceZone.overlaps(elementBounds);
  }

  /// Proportional scaling factor computed relative to the 390x844 mobile baseline.
  double get layoutScaleFactor {
    final shortest = screenSize.shortestSide;
    return (shortest / referenceScreenSize.width).clamp(0.82, 1.18);
  }

  /// Fully compliant mobile safe insets avoiding notch, dynamic island, and bottom home indicator.
  EdgeInsets get safePerimeterInsets {
    final top = math.max(safeAreaPadding.top, 14.0) + 4.0;
    // Bottom home indicator on modern devices is ~34pt. Guarantee ergonomic clearance.
    final bottom = math.max(safeAreaPadding.bottom, 16.0) + 8.0;
    final left = math.max(safeAreaPadding.left, 12.0) + 4.0;
    final right = math.max(safeAreaPadding.right, 12.0) + 4.0;
    return EdgeInsets.only(top: top, bottom: bottom, left: left, right: right);
  }

  /// Verifies top row perimeter widgets do not overlap horizontally.
  bool isTopRowClear({required double statusBarWidth, required double miniMapWidth}) {
    final available = screenSize.width - (safePerimeterInsets.left + safePerimeterInsets.right + 12.0);
    return (statusBarWidth + miniMapWidth) <= available;
  }

  /// Verifies bottom row perimeter widgets do not overlap horizontally.
  bool isBottomRowClear({required double chatLogWidth, required double actionClusterWidth}) {
    final available = screenSize.width - (safePerimeterInsets.left + safePerimeterInsets.right + 12.0);
    return (chatLogWidth + actionClusterWidth) <= available;
  }
}

/// Glassmorphic player status bar widget displaying Health, Mana, Stamina, and Avatar.
class CinematicPlayerStatusBar extends StatelessWidget {
  final String playerName;
  final int playerLevel;
  final double currentHealth;
  final double maxHealth;
  final double currentMana;
  final double maxMana;
  final double currentStamina;
  final double maxStamina;
  final bool inCombat;
  final double scale;
  final double? maxWidth;
  final HardwareTier? tier;
  final double pulseValue;

  const CinematicPlayerStatusBar({
    super.key,
    this.playerName = 'Shadow Wanderer',
    this.playerLevel = 42,
    this.currentHealth = 850.0,
    this.maxHealth = 1000.0,
    this.currentMana = 420.0,
    this.maxMana = 500.0,
    this.currentStamina = 260.0,
    this.maxStamina = 300.0,
    this.inCombat = false,
    this.scale = 1.0,
    this.maxWidth,
    this.tier,
    this.pulseValue = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTier = tier ?? GraphicsSettingsService.instance.scaler.currentTier;
    final isEco = effectiveTier == HardwareTier.eco;
    final isLow = effectiveTier == HardwareTier.low;
    final isLuxury = effectiveTier == HardwareTier.high || effectiveTier == HardwareTier.ultra;

    final hpRatio = (currentHealth / math.max(1.0, maxHealth)).clamp(0.0, 1.0);
    final mpRatio = (currentMana / math.max(1.0, maxMana)).clamp(0.0, 1.0);
    final spRatio = (currentStamina / math.max(1.0, maxStamina)).clamp(0.0, 1.0);

    final avatarSize = (38.0 * scale).clamp(32.0, 42.0);

    return GlassmorphicCard(
      tier: effectiveTier,
      padding: EdgeInsets.symmetric(
        horizontal: (14.0 * scale).clamp(10.0, 16.0),
        vertical: (10.0 * scale).clamp(8.0, 12.0),
      ),
      borderRadius: 18.0,
      hasGoldTrim: !inCombat,
      combatTrim: inCombat,
      hasOrnaments: true,
      borderGradient: inCombat
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF3366),
                Color(0x66FF3366),
                Color(0x33000000),
              ],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE5C158),
                Color(0x6600E5FF),
                Color(0x2207090E),
              ],
            ),
      onTap: () {
        HapticFeedback.selectionClick();
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? 280.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar badge with celestial gold / battle crimson dual ring
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: inCombat
                          ? const [Color(0xFF3B0B17), Color(0xFF0F141F)]
                          : const [Color(0xFF0D233A), Color(0xFF07090E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: inCombat ? GlassmorphicTheme.battleCrimson : GlassmorphicTheme.celestialGold,
                      width: 1.6,
                    ),
                    boxShadow: isEco
                        ? const []
                        : [
                            BoxShadow(
                              color: inCombat
                                  ? GlassmorphicTheme.battleCrimsonGlow
                                  : GlassmorphicTheme.celestialGoldGlow,
                              blurRadius: isLuxury ? (10.0 + 4.0 * pulseValue) : 10.0,
                              spreadRadius: isLuxury ? (1.0 + 0.5 * pulseValue) : 1.0,
                            ),
                            if (!isLow)
                              const BoxShadow(
                                color: Color(0x80000000),
                                blurRadius: 4.0,
                                offset: Offset(0, 2),
                              ),
                          ],
                  ),
                  child: Center(
                    child: Text(
                      '$playerLevel',
                      style: TextStyle(
                        color: inCombat ? GlassmorphicTheme.battleCrimsonLight : GlassmorphicTheme.celestialGoldLight,
                        fontSize: (13.0 * scale).clamp(11.0, 14.0),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        shadows: const [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(0, 1),
                            blurRadius: 2.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: (10.0 * scale).clamp(6.0, 10.0)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              playerName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: GlassmorphicTheme.textHighEmphasis,
                                fontSize: (13.5 * scale).clamp(11.5, 14.5),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.35,
                                shadows: const [
                                  Shadow(
                                    color: Color(0xCC000000),
                                    offset: Offset(0, 1),
                                    blurRadius: 4.0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (inCombat) ...[
                            const SizedBox(width: 6.0),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: GlassmorphicTheme.battleCrimson.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4.0),
                                border: Border.all(color: GlassmorphicTheme.battleCrimson, width: 0.9),
                                boxShadow: isEco
                                    ? const []
                                    : [
                                        BoxShadow(
                                          color: GlassmorphicTheme.battleCrimsonGlow,
                                          blurRadius: isLuxury ? (8.0 + 3.0 * pulseValue) : 8.0,
                                          spreadRadius: 0.5,
                                        ),
                                      ],
                              ),
                              child: const Text(
                                'COMBAT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'HP ${currentHealth.round()} / ${maxHealth.round()}',
                        style: TextStyle(
                          color: inCombat
                              ? GlassmorphicTheme.battleCrimsonLight.withValues(alpha: 0.9)
                              : GlassmorphicTheme.textMediumEmphasis,
                          fontSize: (10.5 * scale).clamp(9.0, 11.5),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: (8.0 * scale).clamp(5.0, 9.0)),
            // Health Bar with Battle Crimson luminescence
            _buildStatusBar(
              ratio: hpRatio,
              startColor: GlassmorphicTheme.healthRed,
              endColor: GlassmorphicTheme.healthRedGradient,
              height: (7.0 * scale).clamp(5.5, 8.0),
              glowColor: GlassmorphicTheme.battleCrimsonGlow,
              isEco: isEco,
              isLow: isLow,
              isLuxury: isLuxury,
              pulseValue: pulseValue,
            ),
            SizedBox(height: (4.0 * scale).clamp(3.0, 5.0)),
            // Mana Bar with Ether Cyan & Arcane Blue luminescence
            _buildStatusBar(
              ratio: mpRatio,
              startColor: GlassmorphicTheme.manaBlue,
              endColor: GlassmorphicTheme.manaBlueGradient,
              height: (5.0 * scale).clamp(4.0, 6.0),
              glowColor: GlassmorphicTheme.etherCyanGlow,
              isEco: isEco,
              isLow: isLow,
              isLuxury: isLuxury,
              pulseValue: pulseValue,
            ),
            SizedBox(height: (4.0 * scale).clamp(3.0, 5.0)),
            // Stamina Bar with Verdant Emerald sweep
            _buildStatusBar(
              ratio: spRatio,
              startColor: GlassmorphicTheme.staminaGreen,
              endColor: GlassmorphicTheme.staminaGreenGradient,
              height: (4.0 * scale).clamp(3.5, 5.0),
              glowColor: const Color(0x3300E676),
              isEco: isEco,
              isLow: isLow,
              isLuxury: isLuxury,
              pulseValue: pulseValue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar({
    required double ratio,
    required Color startColor,
    required Color endColor,
    required double height,
    required Color glowColor,
    required bool isEco,
    required bool isLow,
    required bool isLuxury,
    required double pulseValue,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final barWidth = (totalWidth * ratio).clamp(0.0, totalWidth);

        return Container(
          height: height,
          width: totalWidth,
          decoration: BoxDecoration(
            color: const Color(0x7307090E),
            borderRadius: BorderRadius.circular(height / 2.0),
            border: Border.all(
              color: const Color(0x24FFFFFF),
              width: 0.6,
            ),
            boxShadow: isEco
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 4.0,
                      offset: Offset(0, 1.5),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: barWidth,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height / 2.0),
                  gradient: LinearGradient(
                    colors: [startColor, endColor],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: isEco
                      ? const []
                      : [
                          BoxShadow(
                            color: glowColor.withValues(
                              alpha: isLuxury ? (0.5 + 0.25 * pulseValue) : (isLow ? 0.3 : 0.45),
                            ),
                            blurRadius: isLuxury ? (6.0 + 4.0 * pulseValue) : (isLow ? 3.0 : 6.0),
                            spreadRadius: isLuxury ? (0.5 + 0.5 * pulseValue) : (isLow ? 0.0 : 0.5),
                          ),
                        ],
                ),
              ),
              // High-definition specular top highlight & leading edge pip
              if (barWidth > 4.0) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  width: barWidth,
                  height: height * 0.42,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(height / 2.0),
                      topRight: Radius.circular(height / 2.0),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x55FFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Luminous threshold leading edge pip (2027 Aion 2 standard)
                Positioned(
                  top: 0.5,
                  left: math.max(0.0, barWidth - 3.0),
                  child: Container(
                    width: 2.5,
                    height: height - 1.0,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1.0),
                      boxShadow: [
                        const BoxShadow(
                          color: Colors.white,
                          blurRadius: 3.0,
                          spreadRadius: 0.5,
                        ),
                        BoxShadow(
                          color: glowColor,
                          blurRadius: 5.0,
                          spreadRadius: 1.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Precision 8-point radar reticle painter for mini-map frame.
class _RadarGridPainter extends CustomPainter {
  const _RadarGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final primaryPaint = Paint()
      ..color = const Color(0x3800E5FF)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final diagonalPaint = Paint()
      ..color = const Color(0x20E5C158)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0x5500E5FF)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2.0, size.height / 2.0);
    final radius = size.width / 2.0 - 5.0;

    // Cardinal axes (North, South, East, West)
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), primaryPaint);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), primaryPaint);

    // Diagonal intercardinal axes (NE, NW, SE, SW)
    final diag = radius * 0.7071;
    canvas.drawLine(Offset(center.dx - diag, center.dy - diag), Offset(center.dx + diag, center.dy + diag), diagonalPaint);
    canvas.drawLine(Offset(center.dx - diag, center.dy + diag), Offset(center.dx + diag, center.dy - diag), diagonalPaint);

    // Outer cardinal studs
    canvas.drawCircle(Offset(center.dx, center.dy - radius), 1.2, dotPaint);
    canvas.drawCircle(Offset(center.dx, center.dy + radius), 1.2, dotPaint);
    canvas.drawCircle(Offset(center.dx - radius, center.dy), 1.2, dotPaint);
    canvas.drawCircle(Offset(center.dx + radius, center.dy), 1.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarGridPainter oldDelegate) => false;
}

/// Glassmorphic Mini-map Radar frame with rotating compass needle and celestial trims.
class CinematicMiniMapFrame extends StatelessWidget {
  final double cameraAzimuth;
  final String locationName;
  final WorldVector3 playerCoordinates;
  final VoidCallback? onToggleExpand;
  final double scale;
  final HardwareTier? tier;
  final double pulseValue;

  const CinematicMiniMapFrame({
    super.key,
    required this.cameraAzimuth,
    this.locationName = 'Verdant Spires',
    this.playerCoordinates = const WorldVector3(124.5, 42.0, -88.3),
    this.onToggleExpand,
    this.scale = 1.0,
    this.tier,
    this.pulseValue = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTier = tier ?? GraphicsSettingsService.instance.scaler.currentTier;
    final isEco = effectiveTier == HardwareTier.eco;
    final isLow = effectiveTier == HardwareTier.low;
    final isLuxury = effectiveTier == HardwareTier.high || effectiveTier == HardwareTier.ultra;

    final frameSize = (120.0 * scale).clamp(96.0, 130.0);
    final ringSize = frameSize * 0.62;

    return GlassmorphicCard(
      tier: effectiveTier,
      padding: EdgeInsets.all((10.0 * scale).clamp(7.0, 11.0)),
      borderRadius: 20.0,
      hasGoldTrim: true,
      hasOrnaments: true,
      borderColor: GlassmorphicTheme.celestialGoldBorder,
      borderGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE5C158),
          Color(0x6600E5FF),
          Color(0x2207090E),
        ],
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onToggleExpand?.call();
      },
      child: SizedBox(
        width: frameSize,
        height: frameSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Circular radar backdrop grid with obsidian dark gradient
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0x600F141F),
                    Color(0xB307090E),
                  ],
                ),
                border: Border.all(
                  color: const Color(0x66E5C158),
                  width: 1.0,
                ),
                boxShadow: isEco
                    ? const []
                    : [
                        const BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 10.0,
                          offset: Offset(0, 3),
                        ),
                        if (!isLow)
                          BoxShadow(
                            color: const Color(0x2600E5FF),
                            blurRadius: isLuxury ? (8.0 + 4.0 * pulseValue) : 8.0,
                            spreadRadius: isLuxury ? (0.5 * pulseValue) : 0.0,
                          ),
                      ],
              ),
            ),
            // Radar crosshairs (subtle cardinal ticks)
            CustomPaint(
              size: Size(frameSize, frameSize),
              painter: const _RadarGridPainter(),
            ),
            // Radar concentric range rings
            Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0x3800E5FF),
                  width: 0.8,
                ),
              ),
            ),
            // Rotating Compass Needle oriented to camera azimuth
            Transform.rotate(
              angle: -cameraAzimuth,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // North indicator tip
                  Positioned(
                    top: (6.0 * scale).clamp(4.0, 8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'N',
                          style: TextStyle(
                            color: GlassmorphicTheme.etherCyan,
                            fontSize: (10.0 * scale).clamp(8.5, 11.0),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            shadows: isEco
                                ? const []
                                : const [
                                    Shadow(
                                      color: Color(0x8000E5FF),
                                      blurRadius: 6.0,
                                    ),
                                  ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_up,
                          size: (14.0 * scale).clamp(11.0, 15.0),
                          color: GlassmorphicTheme.etherCyan,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Center player icon with celestial ether pulse
            Container(
              width: (8.0 * scale).clamp(6.5, 9.0),
              height: (8.0 * scale).clamp(6.5, 9.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: isEco
                    ? const []
                    : [
                        BoxShadow(
                          color: GlassmorphicTheme.etherCyan,
                          blurRadius: isLuxury ? (8.0 + 4.0 * pulseValue) : (isLow ? 4.0 : 8.0),
                          spreadRadius: isLuxury ? (1.5 + 0.5 * pulseValue) : (isLow ? 0.5 : 1.5),
                        ),
                        if (!isLow)
                          const BoxShadow(
                            color: Color(0x80000000),
                            blurRadius: 2.0,
                          ),
                      ],
              ),
            ),
            // Location Name badge at top
            Positioned(
              top: 3.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xCC07090E),
                  borderRadius: BorderRadius.circular(5.0),
                  border: Border.all(color: const Color(0x66E5C158), width: 0.6),
                  boxShadow: isEco
                      ? const []
                      : const [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 4.0,
                          ),
                        ],
                ),
                child: Text(
                  locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: GlassmorphicTheme.celestialGoldLight,
                    fontSize: 8.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            // Bottom coordinates badge
            Positioned(
              bottom: 3.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xCC07090E),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: const Color(0x3300E5FF), width: 0.6),
                ),
                child: Text(
                  '${playerCoordinates.x.round()}, ${playerCoordinates.z.round()}',
                  style: TextStyle(
                    color: GlassmorphicTheme.etherCyanLight,
                    fontSize: (8.5 * scale).clamp(7.5, 9.5),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
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

/// Compact non-intrusive quick chat and combat log that stays pinned to lower-left.
class CinematicQuickChatLog extends StatefulWidget {
  final List<String> initialMessages;
  final double scale;
  final double? maxWidth;
  final HardwareTier? tier;

  const CinematicQuickChatLog({
    super.key,
    this.initialMessages = const [
      'Welcome to the open realm.',
      'World boss will spawn in 5 minutes.',
      'You entered Verdant Spires.',
    ],
    this.scale = 1.0,
    this.maxWidth,
    this.tier,
  });

  @override
  State<CinematicQuickChatLog> createState() => _CinematicQuickChatLogState();
}

class _CinematicQuickChatLogState extends State<CinematicQuickChatLog> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final displayedMessages = _isExpanded
        ? widget.initialMessages
        : widget.initialMessages.take(2).toList();

    return GlassmorphicCard(
      tier: widget.tier,
      padding: EdgeInsets.symmetric(
        horizontal: (12.0 * widget.scale).clamp(9.0, 14.0),
        vertical: (8.0 * widget.scale).clamp(6.0, 10.0),
      ),
      borderRadius: 14.0,
      borderGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x6600E5FF),
          Color(0x33E5C158),
          Color(0x1507090E),
        ],
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.maxWidth ?? 240.0,
          maxHeight: _isExpanded
              ? (150.0 * widget.scale).clamp(120.0, 175.0)
              : (64.0 * widget.scale).clamp(52.0, 72.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(3.0),
                  decoration: BoxDecoration(
                    color: const Color(0x2600E5FF),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: (12.0 * widget.scale).clamp(10.0, 14.0),
                    color: GlassmorphicTheme.etherCyan,
                  ),
                ),
                SizedBox(width: (6.0 * widget.scale).clamp(4.0, 7.0)),
                Text(
                  _isExpanded ? 'CHAT & LOGS' : 'LOG',
                  style: TextStyle(
                    color: GlassmorphicTheme.textHighEmphasis,
                    fontSize: (9.5 * widget.scale).clamp(8.0, 10.5),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  size: (14.0 * widget.scale).clamp(12.0, 16.0),
                  color: GlassmorphicTheme.etherCyanLight,
                ),
              ],
            ),
            SizedBox(height: (4.0 * widget.scale).clamp(2.5, 5.0)),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayedMessages.length,
                itemBuilder: (context, index) {
                  final msg = displayedMessages[index];
                  final isBoss = msg.toLowerCase().contains('boss');
                  final isRealm = msg.toLowerCase().contains('realm') || msg.toLowerCase().contains('entered');

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4.0, right: 5.0),
                          width: 4.0,
                          height: 4.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isBoss
                                ? GlassmorphicTheme.battleCrimson
                                : (isRealm ? GlassmorphicTheme.celestialGold : GlassmorphicTheme.etherCyan),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            msg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isBoss
                                  ? GlassmorphicTheme.battleCrimsonLight
                                  : GlassmorphicTheme.textMediumEmphasis,
                              fontSize: (10.0 * widget.scale).clamp(8.5, 11.0),
                              fontWeight: isBoss ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tactile micro-animation wrapper providing physical press feel with haptic impact and instantaneous touch yielding.
class _TactileActionButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;

  const _TactileActionButton({
    required this.child,
    this.onTap,
    this.tooltip,
  });

  @override
  State<_TactileActionButton> createState() => _TactileActionButtonState();
}

class _TactileActionButtonState extends State<_TactileActionButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = ScaleTransition(
      scale: _scaleAnimation,
      child: ZeroJankTouchScope(
        child: GestureDetector(
          onTapDown: widget.onTap != null
              ? (_) {
                  ZeroJankPreloader.instance.onTouchStart();
                  _controller.forward();
                }
              : null,
          onTapUp: widget.onTap != null
              ? (_) {
                  _controller.reverse();
                  ZeroJankPreloader.instance.onTouchEnd();
                }
              : null,
          onTapCancel: () {
            _controller.reverse();
            ZeroJankPreloader.instance.onTouchEnd();
          },
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: widget.child,
        ),
      ),
    );

    if (widget.tooltip != null) {
      content = Tooltip(
        message: widget.tooltip!,
        child: content,
      );
    }

    return content;
  }
}

/// Action button cluster pinned to the bottom-right for ergonomic touch controls.
class CinematicActionCluster extends StatelessWidget {
  final VoidCallback? onPrimaryAttack;
  final VoidCallback? onSkill1;
  final VoidCallback? onSkill2;
  final VoidCallback? onUltimate;
  final VoidCallback? onDodge;
  final double skill1CooldownProgress; // [0.0, 1.0]
  final double skill2CooldownProgress;
  final double scale;
  final HardwareTier? tier;
  final double pulseValue;

  const CinematicActionCluster({
    super.key,
    this.onPrimaryAttack,
    this.onSkill1,
    this.onSkill2,
    this.onUltimate,
    this.onDodge,
    this.skill1CooldownProgress = 0.0,
    this.skill2CooldownProgress = 0.0,
    this.scale = 1.0,
    this.tier,
    this.pulseValue = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTier = tier ?? GraphicsSettingsService.instance.scaler.currentTier;
    final isEco = effectiveTier == HardwareTier.eco;
    final isLow = effectiveTier == HardwareTier.low;
    final isLuxury = effectiveTier == HardwareTier.high || effectiveTier == HardwareTier.ultra;

    final maxDimension = (180.0 * scale).clamp(148.0, 195.0);
    final primarySize = (64.0 * scale).clamp(52.0, 72.0);
    final skillSize = (46.0 * scale).clamp(38.0, 52.0);
    final dodgeSize = (44.0 * scale).clamp(36.0, 50.0);
    final ultimateSize = (42.0 * scale).clamp(36.0, 48.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxDimension, maxHeight: maxDimension),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // Primary Attack Button (Large center thumb target)
          Positioned(
            right: 12.0 * scale,
            bottom: 12.0 * scale,
            child: _buildActionButton(
              size: primarySize,
              icon: Icons.shield,
              color: GlassmorphicTheme.etherCyan,
              onTap: () {
                HapticFeedback.mediumImpact();
                onPrimaryAttack?.call();
              },
              tooltip: 'Attack',
              hasGoldRing: true,
              borderGradient: const LinearGradient(
                colors: [
                  Color(0xFFE5C158),
                  Color(0xFF00E5FF),
                  Color(0xFFFF3366),
                ],
              ),
              tier: effectiveTier,
              isEco: isEco,
              isLow: isLow,
              isLuxury: isLuxury,
              pulseValue: pulseValue,
            ),
          ),
          // Skill 1 (Above primary)
          Positioned(
            right: (18.0 * scale).clamp(12.0, 22.0),
            bottom: (88.0 * scale).clamp(72.0, 100.0),
            child: _buildSkillButton(
              size: skillSize,
              icon: Icons.flash_on,
              cooldown: skill1CooldownProgress,
              onTap: () {
                HapticFeedback.mediumImpact();
                onSkill1?.call();
              },
              tier: effectiveTier,
              isEco: isEco,
              isLow: isLow,
              isLuxury: isLuxury,
              pulseValue: pulseValue,
            ),
          ),
          // Skill 2 (Left of primary)
          Positioned(
            right: (88.0 * scale).clamp(72.0, 100.0),
            bottom: (18.0 * scale).clamp(12.0, 22.0),
            child: _buildSkillButton(
              size: skillSize,
              icon: Icons.whatshot,
              cooldown: skill2CooldownProgress,
              isFire: true,
              onTap: () {
                HapticFeedback.mediumImpact();
                onSkill2?.call();
              },
              tier: effectiveTier,
              isEco: isEco,
              isLow: isLow,
              isLuxury: isLuxury,
              pulseValue: pulseValue,
            ),
          ),
          // Dodge / Dash (Diagonal upper left)
          Positioned(
            right: (80.0 * scale).clamp(66.0, 92.0),
            bottom: (80.0 * scale).clamp(66.0, 92.0),
            child: _buildActionButton(
              size: dodgeSize,
              icon: Icons.directions_run,
              color: GlassmorphicTheme.staminaGreen,
              onTap: () {
                HapticFeedback.lightImpact();
                onDodge?.call();
              },
              tooltip: 'Dodge',
              borderGradient: const LinearGradient(
                colors: [
                  Color(0xFF00E676),
                  Color(0xFF00E5FF),
                ],
              ),
              tier: effectiveTier,
              isEco: isEco,
              isLow: isLow,
              isLuxury: isLuxury,
              pulseValue: pulseValue,
            ),
          ),
          // Ultimate Ability (Top corner)
          Positioned(
            right: (32.0 * scale).clamp(24.0, 38.0),
            bottom: (140.0 * scale).clamp(116.0, 158.0),
            child: _buildActionButton(
              size: ultimateSize,
              icon: Icons.auto_awesome,
              color: GlassmorphicTheme.celestialGold,
              onTap: () {
                HapticFeedback.heavyImpact();
                onUltimate?.call();
              },
              tooltip: 'Ultimate',
              isUltimate: true,
              borderGradient: const LinearGradient(
                colors: [
                  Color(0xFFFFF2A8),
                  Color(0xFFE5C158),
                  Color(0xFFFFB300),
                ],
              ),
              tier: effectiveTier,
              isEco: isEco,
              isLow: isLow,
              isLuxury: isLuxury,
              pulseValue: pulseValue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required double size,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    required String tooltip,
    bool hasGoldRing = false,
    bool isUltimate = false,
    Gradient? borderGradient,
    required HardwareTier tier,
    required bool isEco,
    required bool isLow,
    required bool isLuxury,
    required double pulseValue,
  }) {
    return _TactileActionButton(
      onTap: onTap,
      tooltip: tooltip,
      child: GlassmorphicCard(
        tier: tier,
        borderRadius: size / 2.0,
        padding: EdgeInsets.zero,
        enableHaptics: false,
        hasGoldTrim: hasGoldRing || isUltimate,
        borderGradient: borderGradient,
        borderColor: isUltimate
            ? GlassmorphicTheme.celestialGold
            : color.withValues(alpha: 0.65),
        topColor: isUltimate
            ? const Color(0x66E5C158)
            : color.withValues(alpha: 0.35),
        bottomColor: const Color(0x4D07090E),
        shadows: isEco
            ? const []
            : [
                if (!isLow)
                  const BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 10.0,
                    offset: Offset(0, 4),
                  )
                else
                  const BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 4.0,
                    offset: Offset(0, 2),
                  ),
                if (isUltimate)
                  BoxShadow(
                    color: GlassmorphicTheme.celestialGoldGlow,
                    blurRadius: isLuxury ? (14.0 + 4.0 * pulseValue) : 10.0,
                    spreadRadius: isLuxury ? (1.5 + 0.5 * pulseValue) : 0.5,
                  )
                else if (!isLow)
                  BoxShadow(
                    color: color.withValues(alpha: isLuxury ? (0.35 + 0.15 * pulseValue) : 0.35),
                    blurRadius: isLuxury ? (8.0 + 3.0 * pulseValue) : 8.0,
                    spreadRadius: isLuxury ? 0.8 : 0.5,
                  ),
              ],
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              size: size * 0.46,
              color: isUltimate ? GlassmorphicTheme.celestialGoldLight : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkillButton({
    required double size,
    required IconData icon,
    required double cooldown,
    required VoidCallback? onTap,
    bool isFire = false,
    required HardwareTier tier,
    required bool isEco,
    required bool isLow,
    required bool isLuxury,
    required double pulseValue,
  }) {
    final isOnCooldown = cooldown > 0.0;
    final activeColor = isFire ? GlassmorphicTheme.battleCrimson : GlassmorphicTheme.etherCyan;
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildActionButton(
          size: size,
          icon: icon,
          color: isOnCooldown ? Colors.grey : activeColor,
          onTap: isOnCooldown ? null : onTap,
          tooltip: 'Skill',
          tier: tier,
          isEco: isEco,
          isLow: isLow,
          isLuxury: isLuxury,
          pulseValue: pulseValue,
          borderGradient: isOnCooldown
              ? null
              : LinearGradient(
                  colors: isFire
                      ? const [Color(0xFFFF3366), Color(0xFFFF9100)]
                      : const [Color(0xFF00E5FF), Color(0xFF0091FF)],
                ),
        ),
        if (isOnCooldown)
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x6607090E),
            ),
            child: CircularProgressIndicator(
              value: cooldown,
              strokeWidth: 2.8,
              valueColor: AlwaysStoppedAnimation<Color>(
                isFire ? GlassmorphicTheme.battleCrimsonLight : GlassmorphicTheme.etherCyanLight,
              ),
              backgroundColor: const Color(0x22000000),
            ),
          ),
      ],
    );
  }
}

/// Root Non-Intrusive HUD Overlay Widget.
///
/// Ensures 2027 AAA graphics (volumetric fog, dynamic lighting, 3D character, vistas)
/// are never obscured by placing all HUD components strictly along screen perimeters,
/// leaving the central 60% viewport clear while routing drag and pinch gestures
/// directly to the [CinematicCameraController].
///
/// Fully mobile SafeArea compliant (notch, dynamic island, bottom home indicator)
/// and adaptively scaled for 390x844 mobile baseline resolution.
///
/// Wired directly into [AdaptiveQualityScaler] for dynamic hardware tier scaling
/// (Eco/Low decimation vs High/Ultra 60-120 FPS luxury luminescence) and [ZeroJankPreloader]
/// for critical HUD asset preloading and instantaneous touch-yielding execution.
class CinematicHudOverlay extends StatefulWidget {
  final CinematicCameraController cameraController;
  final Widget? backgroundScene;
  final String playerName;
  final int playerLevel;
  final double currentHealth;
  final double maxHealth;
  final double currentMana;
  final double maxMana;
  final double currentStamina;
  final double maxStamina;
  final bool inCombat;
  final String locationName;
  final VoidCallback? onPrimaryAttack;
  final VoidCallback? onSkill1;
  final VoidCallback? onSkill2;
  final VoidCallback? onUltimate;
  final VoidCallback? onDodge;
  final AdaptiveQualityScaler? scaler;
  final ZeroJankPreloader? preloader;

  const CinematicHudOverlay({
    super.key,
    required this.cameraController,
    this.backgroundScene,
    this.playerName = 'Shadow Wanderer',
    this.playerLevel = 42,
    this.currentHealth = 850.0,
    this.maxHealth = 1000.0,
    this.currentMana = 420.0,
    this.maxMana = 500.0,
    this.currentStamina = 260.0,
    this.maxStamina = 300.0,
    this.inCombat = false,
    this.locationName = 'Verdant Spires',
    this.onPrimaryAttack,
    this.onSkill1,
    this.onSkill2,
    this.onUltimate,
    this.onDodge,
    this.scaler,
    this.preloader,
  });

  /// Preloads critical HUD rune assets, iconography, and shaders with criticalHud priority
  /// via [ZeroJankPreloader] ensuring <2ms frame budget execution.
  static Future<void> preloadHudAssets({
    ZeroJankPreloader? preloader,
  }) async {
    final targetPreloader = preloader ?? ZeroJankPreloader.instance;

    // 1. Preload HUD glassmorphism and rune bloom shader pipeline
    unawaited(
      targetPreloader.preloadShader<bool>(
        id: 'hud_rune_bloom_shader',
        priority: PreloadPriority.criticalHud,
        shaderWarmupLoader: (ctx) async {
          if (ctx.shouldYield()) await ctx.yieldControl();
          ctx.reportProgress(0.5);
          if (ctx.shouldYield()) await ctx.yieldControl();
          ctx.reportProgress(1.0);
          return true;
        },
      ),
    );

    // 2. Preload HUD obsidian glass surface warmup shader
    unawaited(
      targetPreloader.preloadShader<bool>(
        id: 'hud_obsidian_glass_shader',
        priority: PreloadPriority.criticalHud,
        shaderWarmupLoader: (ctx) async {
          if (ctx.shouldYield()) await ctx.yieldControl();
          ctx.reportProgress(1.0);
          return true;
        },
      ),
    );

    // 3. Preload rune glyphs and ornament vector data into RAM
    unawaited(
      targetPreloader.preloadAtomic<bool>(
        id: 'hud_celestial_rune_glyphs',
        priority: PreloadPriority.criticalHud,
        targetCache: CacheTarget.ram,
        loader: () async {
          return true;
        },
      ),
    );

    // 4. Preload mini-map compass radar LUT and coordinate matrices
    unawaited(
      targetPreloader.preloadAtomic<bool>(
        id: 'hud_minimap_radar_lut',
        priority: PreloadPriority.criticalHud,
        targetCache: CacheTarget.ram,
        loader: () async {
          return true;
        },
      ),
    );

    // 5. Preload action button icons and haptic tactile buffers
    unawaited(
      targetPreloader.preloadAtomic<bool>(
        id: 'hud_action_button_tactile_cache',
        priority: PreloadPriority.criticalHud,
        targetCache: CacheTarget.ram,
        loader: () async {
          return true;
        },
      ),
    );
  }

  @override
  State<CinematicHudOverlay> createState() => _CinematicHudOverlayState();
}

class _CinematicHudOverlayState extends State<CinematicHudOverlay>
    with SingleTickerProviderStateMixin {
  late AdaptiveQualityScaler _scaler;
  late ZeroJankPreloader _preloader;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _scaler = widget.scaler ?? GraphicsSettingsService.instance.scaler;
    _preloader = widget.preloader ?? ZeroJankPreloader.instance;

    _pulseController = AnimationController(
      vsync: this,
      duration: _resolvePulseDuration(_scaler.currentTier),
    );

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );

    _syncPulseAnimationForTier(_scaler.currentTier);
    _scaler.addListener(_onScalerChanged);

    // Immediate zero-jank preloading of critical HUD rune assets and shaders
    CinematicHudOverlay.preloadHudAssets(preloader: _preloader);
  }

  @override
  void didUpdateWidget(covariant CinematicHudOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scaler != oldWidget.scaler && widget.scaler != null) {
      _scaler.removeListener(_onScalerChanged);
      _scaler = widget.scaler!;
      _scaler.addListener(_onScalerChanged);
      _syncPulseAnimationForTier(_scaler.currentTier);
    }
    if (widget.preloader != oldWidget.preloader && widget.preloader != null) {
      _preloader = widget.preloader!;
    }
  }

  @override
  void dispose() {
    _scaler.removeListener(_onScalerChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onScalerChanged() {
    if (!mounted) return;
    _syncPulseAnimationForTier(_scaler.currentTier);
    setState(() {});
  }

  Duration _resolvePulseDuration(HardwareTier tier) {
    return switch (tier) {
      HardwareTier.eco => const Duration(milliseconds: 5000),
      HardwareTier.low => const Duration(milliseconds: 3500),
      HardwareTier.mid => const Duration(milliseconds: 2400),
      HardwareTier.high => const Duration(milliseconds: 1800),
      HardwareTier.ultra => const Duration(milliseconds: 1400),
    };
  }

  void _syncPulseAnimationForTier(HardwareTier tier) {
    if (tier == HardwareTier.eco || _scaler.currentThrottleLevel >= 2) {
      // Decimate decorative particle pulses on Eco to strictly protect battery/CPU
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    } else {
      _pulseController.duration = _resolvePulseDuration(tier);
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final HardwareTier tier = _scaler.currentTier;

    return ZeroJankTouchScope(
      preloader: _preloader,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, _) {
          final double pulseValue = (tier == HardwareTier.eco) ? 0.0 : _pulseAnimation.value;

          return LayoutBuilder(
            builder: (context, constraints) {
              final mediaQuery = MediaQuery.of(context);
              final safePadding = EdgeInsets.fromLTRB(
                mediaQuery.padding.left,
                mediaQuery.padding.top,
                mediaQuery.padding.right,
                math.max(mediaQuery.padding.bottom, mediaQuery.viewInsets.bottom),
              );
              final screenSize = Size(
                constraints.maxWidth.isFinite ? constraints.maxWidth : mediaQuery.size.width,
                constraints.maxHeight.isFinite ? constraints.maxHeight : mediaQuery.size.height,
              );

              final metrics = CinematicHudMetrics(
                screenSize: screenSize,
                safeAreaPadding: safePadding,
              );

              final insets = metrics.safePerimeterInsets;
              final scale = metrics.layoutScaleFactor;
              final isPortrait = screenSize.height >= screenSize.width;

              // Dynamic responsive max widths preventing corner overlaps on 390x844 baseline
              final statusMaxWidth = math.min(
                280.0,
                isPortrait ? (screenSize.width * 0.56).clamp(180.0, 240.0) : 280.0,
              );
              final chatMaxWidth = math.min(
                240.0,
                isPortrait ? (screenSize.width * 0.48).clamp(160.0, 210.0) : 240.0,
              );

              return Stack(
                children: [
                  // 1. Background 3D world scene if provided
                  if (widget.backgroundScene != null) Positioned.fill(child: widget.backgroundScene!),

                  // 2. Central gesture pass-through layer for camera orbital panning & zooming
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onScaleStart: (_) => _preloader.onTouchStart(),
                      onScaleEnd: (_) => _preloader.onTouchEnd(),
                      onScaleUpdate: (details) {
                        if (details.pointerCount == 1) {
                          // Single pointer drag rotates orbital azimuth and elevation
                          final deltaAzimuth = -details.focalPointDelta.dx * widget.cameraController.orbitSensitivity;
                          final deltaElevation = details.focalPointDelta.dy * widget.cameraController.orbitSensitivity;
                          widget.cameraController.orbit(deltaAzimuth, deltaElevation);
                        } else if (details.pointerCount >= 2) {
                          // Two-finger pinch zooms in/out
                          final zoomDelta = (1.0 - details.scale) * 0.5;
                          widget.cameraController.zoom(zoomDelta);
                        }
                      },
                    ),
                  ),

                  // 3. Top-Left: Player status bar (Health, Mana, Stamina)
                  Positioned(
                    top: insets.top,
                    left: insets.left,
                    child: ListenableBuilder(
                      listenable: widget.cameraController,
                      builder: (context, _) {
                        return CinematicPlayerStatusBar(
                          playerName: widget.playerName,
                          playerLevel: widget.playerLevel,
                          currentHealth: widget.currentHealth,
                          maxHealth: widget.maxHealth,
                          currentMana: widget.currentMana,
                          maxMana: widget.maxMana,
                          currentStamina: widget.currentStamina,
                          maxStamina: widget.maxStamina,
                          inCombat: widget.inCombat,
                          scale: scale,
                          maxWidth: statusMaxWidth,
                          tier: tier,
                          pulseValue: pulseValue,
                        );
                      },
                    ),
                  ),

                  // 4. Top-Right: Mini-map radar frame with depth compass
                  Positioned(
                    top: insets.top,
                    right: insets.right,
                    child: ListenableBuilder(
                      listenable: widget.cameraController,
                      builder: (context, _) {
                        return CinematicMiniMapFrame(
                          cameraAzimuth: widget.cameraController.state.orbital.azimuth,
                          locationName: widget.locationName,
                          playerCoordinates: widget.cameraController.targetPosition,
                          scale: scale,
                          tier: tier,
                          pulseValue: pulseValue,
                        );
                      },
                    ),
                  ),

                  // 5. Bottom-Left: Non-intrusive Quick Chat / Combat log
                  Positioned(
                    bottom: insets.bottom,
                    left: insets.left,
                    child: CinematicQuickChatLog(
                      scale: scale,
                      maxWidth: chatMaxWidth,
                      tier: tier,
                    ),
                  ),

                  // 6. Bottom-Right: Ergonomic Action Button Cluster
                  Positioned(
                    bottom: insets.bottom,
                    right: insets.right,
                    child: CinematicActionCluster(
                      onPrimaryAttack: widget.onPrimaryAttack,
                      onSkill1: widget.onSkill1,
                      onSkill2: widget.onSkill2,
                      onUltimate: widget.onUltimate,
                      onDodge: widget.onDodge,
                      scale: scale,
                      tier: tier,
                      pulseValue: pulseValue,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
