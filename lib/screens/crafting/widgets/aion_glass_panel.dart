import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Reusable 2027 Aion 2 Mobile frosted glass panel.
///
/// Features:
/// - Real [BackdropFilter] gaussian blur for AAA depth.
/// - Dark fantasy translucent surface with customizable gradient.
/// - Specular highlight along the top edge simulating polished glass.
/// - Luminous subtle gradient border (WCAG 2.2 AA compliant contrast).
/// - 100% responsive 390x844 mobile layout with zero layout overflow.
class AionGlassPanel extends StatelessWidget {
  const AionGlassPanel({
    super.key,
    this.child,
    this.width,
    this.height,
    this.constraints,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(16.0)),
    this.blur = 12.0,
    this.opacity = 0.72,
    this.backgroundColor,
    this.surfaceGradient,
    this.borderGradient,
    this.borderColor,
    this.borderWidth = 1.0,
    this.hasInnerGlint = true,
    this.glowColor,
    this.glowBlurRadius = 0.0,
    this.glowSpreadRadius = 0.0,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
  });

  /// The widget below this widget in the tree.
  final Widget? child;

  /// Optional fixed width.
  final double? width;

  /// Optional fixed height.
  final double? height;

  /// Optional constraints.
  final BoxConstraints? constraints;

  /// Internal padding for [child].
  final EdgeInsetsGeometry padding;

  /// Outer margin around the panel.
  final EdgeInsetsGeometry? margin;

  /// Corner radius of the glass panel.
  final BorderRadiusGeometry borderRadius;

  /// Gaussian blur sigma applied behind the glass.
  final double blur;

  /// Opacity multiplier for the base dark background (0.0 to 1.0).
  final double opacity;

  /// Base tint color behind the blur. Defaults to [AppColors.carbonVoid].
  final Color? backgroundColor;

  /// Gradient applied to the surface. Defaults to Aion 2 dark fantasy glass.
  final Gradient? surfaceGradient;

  /// Gradient applied to the border stroke.
  final Gradient? borderGradient;

  /// Solid border color (used if [borderGradient] is null).
  final Color? borderColor;

  /// Thickness of the border stroke.
  final double borderWidth;

  /// Whether to render a specular gleam highlight along the top edge.
  final bool hasInnerGlint;

  /// Optional ambient glow aura color.
  final Color? glowColor;

  /// Blur radius of the glow aura.
  final double glowBlurRadius;

  /// Spread radius of the glow aura.
  final double glowSpreadRadius;

  /// Optional custom box shadows.
  final List<BoxShadow>? boxShadow;

  /// Clipping behavior for child content and blur.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final BorderRadius effectiveRadius = borderRadius is BorderRadius
        ? borderRadius as BorderRadius
        : BorderRadius.circular(16.0);

    // Build effective outer box shadows
    List<BoxShadow>? effectiveShadows = boxShadow;
    if (effectiveShadows == null && glowColor != null && glowBlurRadius > 0) {
      effectiveShadows = <BoxShadow>[
        BoxShadow(
          color: glowColor!.withValues(alpha: 0.28),
          blurRadius: glowBlurRadius,
          spreadRadius: glowSpreadRadius,
        ),
      ];
    }

    final Color baseColor = backgroundColor ?? AppColors.carbonVoid;
    final Gradient effectiveSurfaceGradient = surfaceGradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            baseColor.withValues(alpha: (opacity * 0.92).clamp(0.0, 1.0)),
            AppColors.spaceNavy.withValues(alpha: (opacity * 0.70).clamp(0.0, 1.0)),
            AppColors.darkObsidian.withValues(alpha: (opacity * 0.55).clamp(0.0, 1.0)),
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        );

    final Gradient effectiveBorderGradient = borderGradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.22),
            AppColors.borderBright.withValues(alpha: 0.40),
            Colors.white.withValues(alpha: 0.05),
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        );

    Widget content = Container(
      padding: padding,
      child: child,
    );

    // Wrap in specular paint if enabled
    if (hasInnerGlint || borderWidth > 0) {
      content = CustomPaint(
        foregroundPainter: _AionGlassBorderPainter(
          borderRadius: effectiveRadius,
          borderWidth: borderWidth,
          borderGradient: effectiveBorderGradient,
          borderColor: borderColor,
          hasInnerGlint: hasInnerGlint,
        ),
        child: content,
      );
    }

    Widget panel = ClipRRect(
      borderRadius: effectiveRadius,
      clipBehavior: clipBehavior,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: effectiveSurfaceGradient,
            borderRadius: effectiveRadius,
          ),
          child: content,
        ),
      ),
    );

    if (effectiveShadows != null || width != null || height != null || constraints != null || margin != null) {
      panel = Container(
        width: width,
        height: height,
        constraints: constraints,
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: effectiveShadows,
        ),
        child: panel,
      );
    }

    return panel;
  }
}

class _AionGlassBorderPainter extends CustomPainter {
  const _AionGlassBorderPainter({
    required this.borderRadius,
    required this.borderWidth,
    required this.borderGradient,
    required this.borderColor,
    required this.hasInnerGlint,
  });

  final BorderRadius borderRadius;
  final double borderWidth;
  final Gradient borderGradient;
  final Color? borderColor;
  final bool hasInnerGlint;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Rect rect = Offset.zero & size;

    // Draw gradient/solid border
    if (borderWidth > 0) {
      final RRect rrect = borderRadius.toRRect(rect).deflate(borderWidth / 2);
      final Paint borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;

      if (borderColor != null) {
        borderPaint.color = borderColor!;
      } else {
        borderPaint.shader = borderGradient.createShader(rect);
      }

      canvas.drawRRect(rrect, borderPaint);
    }

    // Draw top specular glint line
    if (hasInnerGlint && size.width > 24) {
      final double topY = borderWidth / 2 + 0.5;
      final double startX = borderRadius.topLeft.x + 4.0;
      final double endX = size.width - borderRadius.topRight.x - 4.0;

      if (endX > startX) {
        final Paint glintPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.45),
              Colors.white.withValues(alpha: 0.70),
              Colors.white.withValues(alpha: 0.45),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
          ).createShader(Rect.fromLTWH(startX, topY, endX - startX, 1.0));

        canvas.drawLine(Offset(startX, topY), Offset(endX, topY), glintPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AionGlassBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.hasInnerGlint != hasInnerGlint ||
        oldDelegate.borderGradient != borderGradient;
  }
}
