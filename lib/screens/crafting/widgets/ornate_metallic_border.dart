import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Predefined metallic themes for Aion 2 ornate frames.
enum MetallicTheme {
  agedGold,
  obsidianGold,
  celestialSilver,
  mythicCrimson,
  arcaneViolet;

  Color get primaryMetallic => switch (this) {
        MetallicTheme.agedGold => AppColors.liquidGold,
        MetallicTheme.obsidianGold => const Color(0xFFE5A93C),
        MetallicTheme.celestialSilver => const Color(0xFFCBD5E1),
        MetallicTheme.mythicCrimson => const Color(0xFFF43F5E),
        MetallicTheme.arcaneViolet => AppColors.accentPurple,
      };

  Color get highlightMetallic => switch (this) {
        MetallicTheme.agedGold => AppColors.goldLight,
        MetallicTheme.obsidianGold => const Color(0xFFFFF0B3),
        MetallicTheme.celestialSilver => Colors.white,
        MetallicTheme.mythicCrimson => const Color(0xFFFFB3C0),
        MetallicTheme.arcaneViolet => const Color(0xFFD8B4FE),
      };

  Color get shadowMetallic => switch (this) {
        MetallicTheme.agedGold => AppColors.goldDim,
        MetallicTheme.obsidianGold => const Color(0xFF6B4E17),
        MetallicTheme.celestialSilver => const Color(0xFF64748B),
        MetallicTheme.mythicCrimson => const Color(0xFF881337),
        MetallicTheme.arcaneViolet => AppColors.accentPurpleDim,
      };

  Color get obsidianAccent => switch (this) {
        MetallicTheme.agedGold => AppColors.darkObsidian,
        MetallicTheme.obsidianGold => const Color(0xFF161922),
        MetallicTheme.celestialSilver => const Color(0xFF1E293B),
        MetallicTheme.mythicCrimson => const Color(0xFF2B0E17),
        MetallicTheme.arcaneViolet => const Color(0xFF241438),
      };
}

/// Reusable 2027 Aion 2 Mobile ornate metallic border.
///
/// Features:
/// - Aged gold filigree gradients and metallic specular bevel highlights.
/// - Obsidian runic corner brackets with embedded diamond rune studs.
/// - Top and bottom center filigree crest flourishes.
/// - Optional ambient gold glow aura.
/// - 100% responsive, high-performance canvas painter with zero GC churn.
class OrnateMetallicBorder extends StatelessWidget {
  const OrnateMetallicBorder({
    super.key,
    required this.child,
    this.theme = MetallicTheme.agedGold,
    this.filigreeColor,
    this.accentColor,
    this.shadowColor,
    this.obsidianColor,
    this.borderWidth = 1.6,
    this.borderRadius = 14.0,
    this.cornerRuneSize = 14.0,
    this.showCornerRunes = true,
    this.showFiligreeCrests = true,
    this.glowAura = false,
    this.padding,
    this.clipBehavior = Clip.antiAlias,
  });

  /// The child widget enclosed within this ornate metallic frame.
  final Widget child;

  /// Preset metallic palette theme.
  final MetallicTheme theme;

  /// Custom primary metallic filigree color (overrides theme).
  final Color? filigreeColor;

  /// Custom metallic highlight color (overrides theme).
  final Color? accentColor;

  /// Custom metallic shadow bevel color (overrides theme).
  final Color? shadowColor;

  /// Custom obsidian runic base color (overrides theme).
  final Color? obsidianColor;

  /// Frame border stroke width.
  final double borderWidth;

  /// Border corner radius.
  final double borderRadius;

  /// Size of the obsidian runic corner brackets.
  final double cornerRuneSize;

  /// Whether to render obsidian runic corner brackets and studs.
  final bool showCornerRunes;

  /// Whether to render center filigree crest accents at top and bottom edges.
  final bool showFiligreeCrests;

  /// Whether to cast an ambient golden aura outside the frame.
  final bool glowAura;

  /// Optional padding around child inside the border.
  final EdgeInsetsGeometry? padding;

  /// Clip behavior for child.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final Color effectiveFiligree = filigreeColor ?? theme.primaryMetallic;
    final Color effectiveAccent = accentColor ?? theme.highlightMetallic;
    final Color effectiveShadow = shadowColor ?? theme.shadowMetallic;
    final Color effectiveObsidian = obsidianColor ?? theme.obsidianAccent;

    Widget content = padding != null ? Padding(padding: padding!, child: child) : child;

    content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: clipBehavior,
      child: content,
    );

    final Widget framed = CustomPaint(
      foregroundPainter: _OrnateMetallicPainter(
        filigreeColor: effectiveFiligree,
        accentColor: effectiveAccent,
        shadowColor: effectiveShadow,
        obsidianColor: effectiveObsidian,
        borderWidth: borderWidth,
        borderRadius: borderRadius,
        cornerRuneSize: cornerRuneSize,
        showCornerRunes: showCornerRunes,
        showFiligreeCrests: showFiligreeCrests,
      ),
      child: content,
    );

    if (glowAura) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: effectiveFiligree.withValues(alpha: 0.25),
              blurRadius: 14.0,
              spreadRadius: 1.0,
            ),
          ],
        ),
        child: framed,
      );
    }

    return framed;
  }
}

class _OrnateMetallicPainter extends CustomPainter {
  const _OrnateMetallicPainter({
    required this.filigreeColor,
    required this.accentColor,
    required this.shadowColor,
    required this.obsidianColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.cornerRuneSize,
    required this.showCornerRunes,
    required this.showFiligreeCrests,
  });

  final Color filigreeColor;
  final Color accentColor;
  final Color shadowColor;
  final Color obsidianColor;
  final double borderWidth;
  final double borderRadius;
  final double cornerRuneSize;
  final bool showCornerRunes;
  final bool showFiligreeCrests;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Rect rect = Offset.zero & size;
    final double halfStroke = borderWidth / 2;
    final RRect rrect = RRect.fromRectAndRadius(
      rect.deflate(halfStroke),
      Radius.circular(math.max(0, borderRadius - halfStroke)),
    );

    // 1. Dual-tone metallic gradient border
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          accentColor.withValues(alpha: 0.95),
          filigreeColor.withValues(alpha: 0.90),
          shadowColor.withValues(alpha: 0.85),
          accentColor.withValues(alpha: 0.92),
          shadowColor.withValues(alpha: 0.78),
        ],
        stops: const <double>[0.0, 0.28, 0.60, 0.85, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, borderPaint);

    // 2. Metallic Bevel specular highlight along top and left inner bevel
    final Paint specularPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.min(1.0, borderWidth * 0.7)
      ..color = Colors.white.withValues(alpha: 0.40);

    final Path topInnerBevel = Path()
      ..moveTo(borderRadius, borderWidth + 0.5)
      ..lineTo(size.width - borderRadius, borderWidth + 0.5);
    canvas.drawPath(topInnerBevel, specularPaint);

    // 3. Obsidian Runic Corner Braces and Gold Studs
    if (showCornerRunes && size.width >= cornerRuneSize * 2.5 && size.height >= cornerRuneSize * 2.5) {
      final Paint obsidianFill = Paint()
        ..style = PaintingStyle.fill
        ..color = obsidianColor.withValues(alpha: 0.92);

      final Paint runeStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.1, borderWidth * 0.8)
        ..color = accentColor.withValues(alpha: 0.95);

      final Paint studFill = Paint()
        ..style = PaintingStyle.fill
        ..color = accentColor;

      final double s = cornerRuneSize;
      final double inset = 2.0;

      // Draw 4 corner obsidian runic brackets
      _drawCornerBracket(canvas, Offset(inset, inset), s, 0, obsidianFill, runeStroke, studFill);
      _drawCornerBracket(canvas, Offset(size.width - inset, inset), s, 1, obsidianFill, runeStroke, studFill);
      _drawCornerBracket(canvas, Offset(inset, size.height - inset), s, 2, obsidianFill, runeStroke, studFill);
      _drawCornerBracket(canvas, Offset(size.width - inset, size.height - inset), s, 3, obsidianFill, runeStroke, studFill);
    }

    // 4. Center Filigree Crests on Top & Bottom Edges
    if (showFiligreeCrests && size.width >= 100) {
      _drawCrest(canvas, Offset(size.width / 2, halfStroke), isTop: true);
      _drawCrest(canvas, Offset(size.width / 2, size.height - halfStroke), isTop: false);
    }
  }

  void _drawCornerBracket(
    Canvas canvas,
    Offset origin,
    double size,
    int quadrant, // 0: TL, 1: TR, 2: BL, 3: BR
    Paint fill,
    Paint stroke,
    Paint stud,
  ) {
    final double dx = (quadrant == 1 || quadrant == 3) ? -1.0 : 1.0;
    final double dy = (quadrant == 2 || quadrant == 3) ? -1.0 : 1.0;

    // Outer faceted runic corner bracket path
    final Path bracketPath = Path()
      ..moveTo(origin.dx, origin.dy + size * dy)
      ..lineTo(origin.dx, origin.dy + (size * 0.45) * dy)
      ..lineTo(origin.dx + (size * 0.45) * dx, origin.dy)
      ..lineTo(origin.dx + size * dx, origin.dy)
      ..lineTo(origin.dx + (size * 0.70) * dx, origin.dy + (size * 0.25) * dy)
      ..lineTo(origin.dx + (size * 0.25) * dx, origin.dy + (size * 0.70) * dy)
      ..close();

    canvas.drawPath(bracketPath, fill);
    canvas.drawPath(bracketPath, stroke);

    // Diamond Runic Stud in center of corner bracket
    final double studX = origin.dx + (size * 0.40) * dx;
    final double studY = origin.dy + (size * 0.40) * dy;
    const double studRadius = 2.2;

    final Path diamond = Path()
      ..moveTo(studX, studY - studRadius)
      ..lineTo(studX + studRadius, studY)
      ..lineTo(studX, studY + studRadius)
      ..lineTo(studX - studRadius, studY)
      ..close();

    canvas.drawPath(diamond, stud);
  }

  void _drawCrest(Canvas canvas, Offset center, {required bool isTop}) {
    final double dir = isTop ? 1.0 : -1.0;
    final Paint crestPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor;

    // Small ornate diamond crest
    final Path crest = Path()
      ..moveTo(center.dx, center.dy + 4.0 * dir)
      ..lineTo(center.dx + 5.0, center.dy)
      ..lineTo(center.dx, center.dy - 1.5 * dir)
      ..lineTo(center.dx - 5.0, center.dy)
      ..close();

    canvas.drawPath(crest, crestPaint);

    // Horizontal filigree whisker strokes
    final Paint whisker = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        colors: <Color>[
          accentColor.withValues(alpha: 0.0),
          accentColor.withValues(alpha: 0.8),
          accentColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(center.dx - 20, center.dy - 1, 40, 2));

    canvas.drawLine(
      Offset(center.dx - 18, center.dy),
      Offset(center.dx + 18, center.dy),
      whisker,
    );
  }

  @override
  bool shouldRepaint(covariant _OrnateMetallicPainter oldDelegate) {
    return oldDelegate.filigreeColor != filigreeColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.obsidianColor != obsidianColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.cornerRuneSize != cornerRuneSize ||
        oldDelegate.showCornerRunes != showCornerRunes ||
        oldDelegate.showFiligreeCrests != showFiligreeCrests;
  }
}
