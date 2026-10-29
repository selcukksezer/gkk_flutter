import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

/// 2027 Aion-2 inspired supreme obsidian frosted glassmorphic card container.
///
/// Features:
/// - Multi-layered Gaussian backdrop blur (`BackdropFilter`)
/// - Deep dark obsidian glass gradient (0xFF07090E void to 0xFF0F1522 abyss)
/// - Luminous celestial gold (`0xFFE5C158`) & ether cyan (`0xFF00E5FF`) border sheen
/// - Specular top-edge diamond highlight line with celestial luminescence
/// - Ambient cyan ether and celestial gold outer glow shadows
/// - High-fidelity interactive tap handling with `HapticFeedback.lightImpact()`
/// - Optional responsive mobile `SafeArea` integration for full-bleed layouts
class KingdomGlassCard extends StatelessWidget {
  const KingdomGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16.0,
    this.blurSigma = 14.0,
    this.borderColor,
    this.borderGradient,
    this.backgroundGradient,
    this.accentGlowColor,
    this.onTap,
    this.elevation = 6.0,
    this.clipBehavior = Clip.antiAlias,
    this.borderWidth = 1.2,
    this.useSafeArea = false,
    this.safeAreaMinimum = EdgeInsets.zero,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.safeAreaLeft = true,
    this.safeAreaRight = true,
    this.enableHaptics = true,
  });

  /// The widget content rendered inside the obsidian glass card.
  final Widget child;

  /// Internal padding for the card content. Defaults to `EdgeInsets.all(16)`.
  final EdgeInsetsGeometry padding;

  /// Outer margin surrounding the card container.
  final EdgeInsetsGeometry? margin;

  /// Corner radius for the card and clip geometry. Defaults to 16.0.
  final double borderRadius;

  /// Blur intensity (sigma) applied to background content behind the card. Defaults to 14.0.
  final double blurSigma;

  /// Optional solid border color override. If provided when [borderGradient] is null,
  /// generates a subtle luminous gradient using this tint.
  final Color? borderColor;

  /// Optional custom border gradient. Overrides the default Aion 2 luminescent border.
  final Gradient? borderGradient;

  /// Optional custom background gradient. Overrides the default Aion 2 obsidian glass gradient.
  final Gradient? backgroundGradient;

  /// Optional accent glow color for box shadows and border luminescence.
  final Color? accentGlowColor;

  /// Optional tap callback. When provided, card responds to touch with ink ripples and haptic feedback.
  final VoidCallback? onTap;

  /// Elevation depth factor governing shadow blur and spread. Defaults to 6.0.
  final double elevation;

  /// Clipping behavior for child content and backdrop filter. Defaults to [Clip.antiAlias].
  final Clip clipBehavior;

  /// Stroke width for the luminous gradient border. Defaults to 1.2.
  final double borderWidth;

  /// Whether to wrap the inner child within a [SafeArea]. Defaults to false.
  final bool useSafeArea;

  /// Minimum insets when [useSafeArea] is true. Defaults to [EdgeInsets.zero].
  final EdgeInsets safeAreaMinimum;

  /// Whether to avoid system intrusions at the top when [useSafeArea] is true.
  final bool safeAreaTop;

  /// Whether to avoid system intrusions at the bottom when [useSafeArea] is true.
  final bool safeAreaBottom;

  /// Whether to avoid system intrusions at the left when [useSafeArea] is true.
  final bool safeAreaLeft;

  /// Whether to avoid system intrusions at the right when [useSafeArea] is true.
  final bool safeAreaRight;

  /// Whether to trigger [HapticFeedback.lightImpact] on tap when [onTap] is provided. Defaults to true.
  final bool enableHaptics;

  // ──────────────────────────── 2027 Aion 2 Design Language ─────────────────────────

  /// Obsidian Void base token (deep obsidian background).
  static const Color obsidianVoid = Color(0xFF07090E);

  /// Deep Obsidian Abyss token (subtle atmospheric gradient shift).
  static const Color obsidianAbyss = Color(0xFF0F1522);

  /// Celestial Gold token for luminescent border and specular sheen.
  static const Color celestialGold = Color(0xFFE5C158);

  /// Ether Cyan token for luminescent rim and ambient outer glow.
  static const Color etherCyan = Color(0xFF00E5FF);

  /// Default cyan accent fallback from design system [AppColors].
  static const Color defaultCyanAccent = AppColors.accentCyan;

  /// Default gold accent fallback from design system [AppColors].
  static const Color defaultGoldAccent = AppColors.liquidGold;

  @override
  Widget build(BuildContext context) {
    // 2027 Aion 2 Luminescent Border Sheen (0xFF00E5FF cyan & 0xFFE5C158 gold)
    final effectiveBorderGradient = borderGradient ??
        (borderColor != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  borderColor!,
                  borderColor!.withValues(alpha: 0.45),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  (accentGlowColor ?? etherCyan).withValues(alpha: 0.70),
                  Colors.white.withValues(alpha: 0.28),
                  (accentGlowColor ?? celestialGold).withValues(alpha: 0.52),
                  (accentGlowColor ?? etherCyan).withValues(alpha: 0.22),
                  obsidianVoid.withValues(alpha: 0.12),
                ],
                stops: const <double>[0.0, 0.25, 0.58, 0.82, 1.0],
              ));

    // 2027 Aion 2 Obsidian Glass Gradient (0xFF07090E & 0xFF0F1522)
    final effectiveBackgroundGradient = backgroundGradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            obsidianVoid.withValues(alpha: 0.85),
            obsidianAbyss.withValues(alpha: 0.76),
            obsidianVoid.withValues(alpha: 0.94),
          ],
          stops: const <double>[0.0, 0.52, 1.0],
        );

    // Optional responsive mobile SafeArea protection
    Widget contentChild = child;
    if (useSafeArea) {
      contentChild = SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        left: safeAreaLeft,
        right: safeAreaRight,
        minimum: safeAreaMinimum,
        child: contentChild,
      );
    }

    Widget content = Container(
      decoration: BoxDecoration(
        gradient: effectiveBackgroundGradient,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: padding,
      child: contentChild,
    );

    if (blurSigma > 0) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      );
    }

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );

    Widget cardBody = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: <BoxShadow>[
          // Deep foundation shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: elevation * 2.2,
            offset: Offset(0, elevation * 0.75),
          ),
          // 2027 Aion 2 Ether Cyan & Celestial Gold Luminescence
          if (accentGlowColor != null)
            BoxShadow(
              color: accentGlowColor!.withValues(alpha: 0.20),
              blurRadius: elevation * 3.2,
              spreadRadius: 1.0,
            )
          else ...[
            // Subtle outer cyan ether glow
            BoxShadow(
              color: etherCyan.withValues(alpha: 0.08),
              blurRadius: elevation * 3.0,
              spreadRadius: 0.5,
              offset: const Offset(0, 1),
            ),
            // Subtle celestial gold ambient luminescence
            BoxShadow(
              color: celestialGold.withValues(alpha: 0.04),
              blurRadius: elevation * 4.2,
              spreadRadius: -0.5,
              offset: const Offset(0, -1),
            ),
          ],
        ],
      ),
      child: CustomPaint(
        foregroundPainter: _LuminousBorderPainter(
          borderRadius: borderRadius,
          borderGradient: effectiveBorderGradient,
          borderWidth: borderWidth,
          specularGlow: accentGlowColor != null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          clipBehavior: clipBehavior,
          child: content,
        ),
      ),
    );

    if (onTap != null) {
      cardBody = Material(
        color: Colors.transparent,
        shape: cardShape,
        child: InkWell(
          onTap: () {
            if (enableHaptics) {
              HapticFeedback.lightImpact();
            }
            onTap!();
          },
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: (accentGlowColor ?? etherCyan).withValues(alpha: 0.16),
          highlightColor: (accentGlowColor ?? celestialGold).withValues(alpha: 0.08),
          hoverColor: etherCyan.withValues(alpha: 0.04),
          child: cardBody,
        ),
      );
    }

    return cardBody;
  }
}

/// Custom painter to draw 2027 Aion-2 high-definition luminous border gradients
/// with top-edge specular illumination and subtle inner bevel refraction.
class _LuminousBorderPainter extends CustomPainter {
  const _LuminousBorderPainter({
    required this.borderRadius,
    required this.borderGradient,
    required this.borderWidth,
    required this.specularGlow,
  });

  final double borderRadius;
  final Gradient borderGradient;
  final double borderWidth;
  final bool specularGlow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(borderWidth / 2),
      Radius.circular(math.max(0.0, borderRadius - borderWidth / 2)),
    );

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = borderGradient.createShader(rect);

    canvas.drawRRect(rrect, borderPaint);

    // Specular highlight line along top edge with gold & cyan luminescence
    final topSpecularPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.transparent,
          KingdomGlassCard.etherCyan.withValues(alpha: specularGlow ? 0.60 : 0.40),
          Colors.white.withValues(alpha: specularGlow ? 0.85 : 0.65),
          KingdomGlassCard.celestialGold.withValues(alpha: specularGlow ? 0.60 : 0.40),
          Colors.transparent,
        ],
        stops: const <double>[0.05, 0.28, 0.50, 0.72, 0.95],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2));

    final startX = math.min(borderRadius, size.width / 2);
    final endX = math.max(startX, size.width - borderRadius);
    if (endX > startX) {
      final topPath = Path()
        ..moveTo(startX, borderWidth / 2)
        ..lineTo(endX, borderWidth / 2);

      canvas.drawPath(topPath, topSpecularPaint);
    }

    // Subtle inner bevel refraction for 2027 Aion 2 obsidian-glass depth
    if (borderRadius > 2 && size.width > borderWidth * 4 && size.height > borderWidth * 4) {
      final innerRRect = RRect.fromRectAndRadius(
        rect.deflate(borderWidth + 0.6),
        Radius.circular(math.max(0.0, borderRadius - borderWidth - 0.6)),
      );
      final innerBevelPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.12),
            KingdomGlassCard.etherCyan.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.35, 1.0],
        ).createShader(rect);
      canvas.drawRRect(innerRRect, innerBevelPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LuminousBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.specularGlow != specularGlow ||
        oldDelegate.borderGradient != borderGradient;
  }
}
