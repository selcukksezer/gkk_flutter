import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/social_theme_tokens.dart';

/// Precise uniform indices and pack helper for procedural and GLSL Honor Insignia shaders.
///
/// Declared GLSL layout:
/// - uniform vec2  uResolution;          (float indices 0, 1)
/// - uniform float uTime;                (float index 2)
/// - uniform float uProgress;            (float index 3)
/// - uniform float uGlowIntensity;       (float index 4)
/// - uniform float uStarCount;           (float index 5)
/// - uniform vec4  uRibbonColor;         (float indices 6, 7, 8, 9, linear RGBA)
/// - uniform vec4  uGoldColor;           (float indices 10, 11, 12, 13, linear RGBA)
/// - uniform float uCrestShimmer;        (float index 14)
/// - uniform float uMetallicReflection;  (float index 15)
/// Total float count: 16
abstract final class HonorInsigniaUniforms {
  static const int indexResolution = 0;
  static const int indexTime = 2;
  static const int indexProgress = 3;
  static const int indexGlowIntensity = 4;
  static const int indexStarCount = 5;
  static const int indexRibbonColor = 6;
  static const int indexGoldColor = 10;
  static const int indexCrestShimmer = 14;
  static const int indexMetallicReflection = 15;
  static const int floatCount = 16;

  /// Builds a contiguous [Float32List] buffer with all 16 uniform floats in declaration order.
  static Float32List buildUniforms({
    required Size size,
    required double progress,
    double? time,
    int starCount = 3,
    Color ribbonColor = SocialThemeTokens.balaurRuby,
    Color goldColor = SocialThemeTokens.celestialGold,
    double glowIntensity = 1.0,
    double crestShimmer = 1.0,
    double metallicReflection = 1.0,
    bool useLinearColors = true,
  }) {
    final Float32List buffer = Float32List(floatCount);
    final double activeTime = time ?? (progress * 3.0);

    // 0..1: uResolution (vec2)
    buffer[0] = size.width;
    buffer[1] = size.height;

    // 2: uTime (float)
    buffer[2] = activeTime;

    // 3: uProgress (float)
    buffer[3] = progress;

    // 4: uGlowIntensity (float)
    buffer[4] = glowIntensity;

    // 5: uStarCount (float)
    buffer[5] = starCount.toDouble();

    // 6..9: uRibbonColor (vec4 in linear RGBA)
    if (useLinearColors) {
      SocialThemeTokens.packVec4(buffer, indexRibbonColor, ribbonColor, linear: true);
    } else {
      buffer[6] = ribbonColor.r;
      buffer[7] = ribbonColor.g;
      buffer[8] = ribbonColor.b;
      buffer[9] = ribbonColor.a;
    }

    // 10..13: uGoldColor (vec4 in linear RGBA)
    if (useLinearColors) {
      SocialThemeTokens.packVec4(buffer, indexGoldColor, goldColor, linear: true);
    } else {
      buffer[10] = goldColor.r;
      buffer[11] = goldColor.g;
      buffer[12] = goldColor.b;
      buffer[13] = goldColor.a;
    }

    // 14: uCrestShimmer (float)
    buffer[14] = crestShimmer;

    // 15: uMetallicReflection (float)
    buffer[15] = metallicReflection;

    return buffer;
  }

  /// Binds all 16 uniform floats directly to a Flutter [ui.FragmentShader] instance.
  static void apply(
    ui.FragmentShader shader, {
    required Size size,
    required double progress,
    double? time,
    int starCount = 3,
    Color ribbonColor = SocialThemeTokens.balaurRuby,
    Color goldColor = SocialThemeTokens.celestialGold,
    double glowIntensity = 1.0,
    double crestShimmer = 1.0,
    double metallicReflection = 1.0,
    bool useLinearColors = true,
  }) {
    final Float32List uniforms = buildUniforms(
      size: size,
      progress: progress,
      time: time,
      starCount: starCount,
      ribbonColor: ribbonColor,
      goldColor: goldColor,
      glowIntensity: glowIntensity,
      crestShimmer: crestShimmer,
      metallicReflection: metallicReflection,
      useLinearColors: useLinearColors,
    );
    for (int i = 0; i < floatCount; ++i) {
      shader.setFloat(i, uniforms[i]);
    }
  }
}

/// Authentic 2027 Aion 2 Mobile Faction Honor Insignia vector & shader painter.
///
/// Features a draped double-tailed silk ribbon, sculpted gold laurel wreath,
/// crossed ceremonial celestial swords, an embossed faction crest medallion,
/// customizable honor stars (1 to 5), and GPU runtime shader uniform synchronization
/// (16 floats covering resolution, time, progress, glow, stars, ribbon/gold colors,
/// crest shimmer, and metallic reflection).
class HonorInsigniaPainter extends CustomPainter {
  const HonorInsigniaPainter({
    required this.progress,
    this.shader,
    this.time,
    this.starCount = 3,
    this.ribbonColor = SocialThemeTokens.balaurRuby,
    this.goldColor = SocialThemeTokens.celestialGold,
    this.glowIntensity = 1.0,
    this.crestShimmer = 1.0,
    this.metallicReflection = 1.0,
  }) : assert(starCount >= 1 && starCount <= 5, 'starCount must be between 1 and 5');

  /// Total number of uniform float values declared for the Honor Insignia shader:
  /// - 0..1: uResolution (vec2)
  /// - 2: uTime (float)
  /// - 3: uProgress (float)
  /// - 4: uGlowIntensity (float)
  /// - 5: uStarCount (float)
  /// - 6..9: uRibbonColor (vec4 in linear RGBA)
  /// - 10..13: uGoldColor (vec4 in linear RGBA)
  /// - 14: uCrestShimmer (float)
  /// - 15: uMetallicReflection (float)
  /// Total: 16 floats (0..15).
  static const int kUniformFloatCount = HonorInsigniaUniforms.floatCount;

  final double progress;
  final ui.FragmentShader? shader;
  final double? time;
  final int starCount;
  final Color ribbonColor;
  final Color goldColor;
  final double glowIntensity;
  final double crestShimmer;
  final double metallicReflection;

  /// Builds a contiguous Float32List containing all 16 uniforms in GLSL declaration order.
  static Float32List packUniforms({
    required Size size,
    required double progress,
    double? time,
    int starCount = 3,
    Color ribbonColor = SocialThemeTokens.balaurRuby,
    Color goldColor = SocialThemeTokens.celestialGold,
    double glowIntensity = 1.0,
    double crestShimmer = 1.0,
    double metallicReflection = 1.0,
  }) {
    return HonorInsigniaUniforms.buildUniforms(
      size: size,
      progress: progress,
      time: time,
      starCount: starCount,
      ribbonColor: ribbonColor,
      goldColor: goldColor,
      glowIntensity: glowIntensity,
      crestShimmer: crestShimmer,
      metallicReflection: metallicReflection,
    );
  }

  /// Binds all 16 uniform floats directly to [targetShader].
  void applyUniforms(ui.FragmentShader targetShader, Size size) {
    HonorInsigniaUniforms.apply(
      targetShader,
      size: size,
      progress: progress,
      time: time,
      starCount: starCount,
      ribbonColor: ribbonColor,
      goldColor: goldColor,
      glowIntensity: glowIntensity,
      crestShimmer: crestShimmer,
      metallicReflection: metallicReflection,
    );
  }

  /// Applies a packed [Float32List] buffer onto a [ui.FragmentShader].
  static void applyPackedUniforms(ui.FragmentShader targetShader, Float32List buffer) {
    assert(buffer.length >= kUniformFloatCount);
    for (int i = 0; i < kUniformFloatCount; i++) {
      targetShader.setFloat(i, buffer[i]);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Offset center = Offset(size.width * 0.5, size.height * 0.58);
    final double medalR = math.min(size.width, size.height) * 0.28;

    // 0. Optional GPU Runtime FragmentShader path
    if (shader != null) {
      applyUniforms(shader!, size);
      final Paint shaderPaint = Paint()..shader = shader!;
      canvas.drawRect(Offset.zero & size, shaderPaint);
    }

    // 1. Prestigious Radiance Aura
    _paintAura(canvas, center, medalR);

    // 2. Draped Silk Ribbon (Top)
    _paintDrapedRibbon(canvas, Offset(center.dx, size.height * 0.22), size.width * 0.54, size.height * 0.32);

    // 3. Crossed Celestial Swords (Behind medal)
    _paintCrossedSwords(canvas, center, medalR * 1.55);

    // 4. Gilded Sculpted Laurel Wreath
    _paintLaurelWreath(canvas, center, medalR * 1.25);

    // 5. Central Embossed Medal & Enamel
    _paintMedallion(canvas, center, medalR);

    // 6. Traveling Diagonal Glint
    _paintGlint(canvas, center, medalR);

    // 7. Honor Stars (1 to 5)
    _paintHonorStars(canvas, Offset(center.dx, center.dy + medalR * 0.88), medalR * 0.32);
  }

  void _paintAura(Canvas canvas, Offset center, double r) {
    final double pulse = 0.5 + 0.5 * math.sin(progress * 2 * math.pi);
    final Paint auraPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        colors: [
          goldColor.withValues(alpha: 0.38 * pulse * glowIntensity),
          ribbonColor.withValues(alpha: 0.18 * pulse * glowIntensity),
          Colors.transparent,
        ],
        stops: const [0.2, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r * 2.1));
    canvas.drawCircle(center, r * 2.1, auraPaint);
  }

  void _paintDrapedRibbon(Canvas canvas, Offset topCenter, double w, double h) {
    // Upper ribbon mount bar
    final Rect barRect = Rect.fromCenter(center: topCenter - Offset(0, h * 0.35), width: w * 0.85, height: 8);
    final Paint barPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          SocialThemeTokens.celestialGoldLight,
          goldColor,
          SocialThemeTokens.celestialGoldDark,
        ],
      ).createShader(barRect);
    canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(3.0)), barPaint);

    // Left and Right Ribbon Tails
    final Paint ribbonPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          ribbonColor,
          Color.lerp(ribbonColor, Colors.black, 0.35)!,
        ],
      ).createShader(Rect.fromCenter(center: topCenter, width: w, height: h));

    // Left tail
    final Path leftTail = Path()
      ..moveTo(topCenter.dx - w * 0.38, barRect.bottom)
      ..lineTo(topCenter.dx - w * 0.05, barRect.bottom)
      ..lineTo(topCenter.dx - w * 0.10, topCenter.dy + h * 0.45)
      ..lineTo(topCenter.dx - w * 0.28, topCenter.dy + h * 0.32)
      ..lineTo(topCenter.dx - w * 0.45, topCenter.dy + h * 0.45)
      ..close();
    canvas.drawPath(leftTail, ribbonPaint);

    // Right tail
    final Path rightTail = Path()
      ..moveTo(topCenter.dx + w * 0.05, barRect.bottom)
      ..lineTo(topCenter.dx + w * 0.38, barRect.bottom)
      ..lineTo(topCenter.dx + w * 0.45, topCenter.dy + h * 0.45)
      ..lineTo(topCenter.dx + w * 0.28, topCenter.dy + h * 0.32)
      ..lineTo(topCenter.dx + w * 0.10, topCenter.dy + h * 0.45)
      ..close();
    canvas.drawPath(rightTail, ribbonPaint);

    // Gold hem border trim on ribbon tails
    final Paint goldTrimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = SocialThemeTokens.celestialGoldLight;
    canvas.drawPath(leftTail, goldTrimPaint);
    canvas.drawPath(rightTail, goldTrimPaint);
  }

  void _paintCrossedSwords(Canvas canvas, Offset center, double swordLen) {
    final Color bladeColor = Color.lerp(
      const Color(0xFFCFD8DC),
      Colors.white,
      (0.35 * metallicReflection).clamp(0.0, 1.0),
    )!;

    final Paint bladePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = bladeColor;

    final Color hiltColor = Color.lerp(
      goldColor,
      SocialThemeTokens.celestialGoldLight,
      (0.5 * metallicReflection).clamp(0.0, 1.0),
    )!;

    final Paint hiltPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = hiltColor;

    for (final angle in [-0.785, 0.785]) {
      // 45 degrees
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      // Blade
      canvas.drawLine(Offset(0, -swordLen), Offset(0, swordLen * 0.75), bladePaint);

      // Crossguard
      canvas.drawLine(Offset(-7, swordLen * 0.55), Offset(7, swordLen * 0.55), bladePaint);

      // Pommel
      canvas.drawCircle(Offset(0, swordLen * 0.75), 2.5, hiltPaint);

      canvas.restore();
    }
  }

  void _paintLaurelWreath(Canvas canvas, Offset center, double wreathR) {
    final Color wreathLight = Color.lerp(
      goldColor,
      SocialThemeTokens.celestialGoldLight,
      (0.6 * metallicReflection).clamp(0.0, 1.0),
    )!;
    final Color wreathDark = Color.lerp(
      goldColor,
      SocialThemeTokens.celestialGoldDark,
      (0.6 * metallicReflection).clamp(0.0, 1.0),
    )!;

    final Paint leafPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          wreathLight,
          goldColor,
          wreathDark,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: wreathR));

    const int leafPairs = 8;
    for (int i = 0; i < leafPairs; i++) {
      final double progressNorm = i / (leafPairs - 1);
      final double angle = math.pi * 0.65 + progressNorm * (math.pi * 0.7);

      // Left branch leaf
      final Offset posL = center + Offset(math.cos(angle), math.sin(angle)) * wreathR;
      _drawSingleLeaf(canvas, posL, angle + 0.3, leafPaint);

      // Right branch leaf (mirrored angle)
      final double angleR = math.pi * 0.35 - progressNorm * (math.pi * 0.7);
      final Offset posR = center + Offset(math.cos(angleR), math.sin(angleR)) * wreathR;
      _drawSingleLeaf(canvas, posR, angleR - 0.3, leafPaint);
    }
  }

  void _drawSingleLeaf(Canvas canvas, Offset pos, double angle, Paint paint) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);

    final Path leaf = Path()
      ..moveTo(0, -7)
      ..quadraticBezierTo(4, 0, 0, 7)
      ..quadraticBezierTo(-4, 0, 0, -7)
      ..close();
    canvas.drawPath(leaf, paint);

    canvas.restore();
  }

  void _paintMedallion(Canvas canvas, Offset center, double r) {
    final double activeTime = time ?? (progress * 2 * math.pi);
    final Color rimHighlight = Color.lerp(
      goldColor,
      SocialThemeTokens.celestialGoldLight,
      (0.65 * metallicReflection).clamp(0.0, 1.0),
    )!;
    final Color rimShadow = Color.lerp(
      goldColor,
      SocialThemeTokens.celestialGoldDark,
      (0.7 * metallicReflection).clamp(0.0, 1.0),
    )!;

    // Outer beveled gold rim with dynamic metallic reflection
    final Paint rimPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          rimHighlight,
          goldColor,
          rimShadow,
          goldColor,
          rimHighlight,
        ],
        transform: GradientRotation(activeTime),
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, rimPaint);

    // Inner red/blue guilloche sunburst enamel disc
    final Paint enamelPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          ribbonColor,
          Color.lerp(ribbonColor, Colors.black, 0.4)!,
          Colors.black,
        ],
        stops: const [0.0, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.82));
    canvas.drawCircle(center, r * 0.82, enamelPaint);

    // Sunburst guilloche radiating rays modulated by crest shimmer
    final Paint rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = rimHighlight.withValues(alpha: (0.35 * crestShimmer).clamp(0.0, 1.0));

    const int rayCount = 16;
    for (int i = 0; i < rayCount; i++) {
      final double a = (i * 2 * math.pi) / rayCount;
      canvas.drawLine(center, center + Offset(math.cos(a), math.sin(a)) * (r * 0.75), rayPaint);
    }

    // Central embossed 8-point gold star of valor
    final Path star = Path();
    const int pts = 8;
    for (int i = 0; i < pts * 2; i++) {
      final double a = (i * math.pi) / pts - (math.pi / 2);
      final double radius = (i % 2 == 0) ? r * 0.52 : r * 0.22;
      final double x = center.dx + math.cos(a) * radius;
      final double y = center.dy + math.sin(a) * radius;
      if (i == 0) {
        star.moveTo(x, y);
      } else {
        star.lineTo(x, y);
      }
    }
    star.close();

    final Paint starPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          rimHighlight,
          goldColor,
          rimShadow,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.52));
    canvas.drawPath(star, starPaint);
  }

  void _paintGlint(Canvas canvas, Offset center, double r) {
    if (crestShimmer <= 0.001) return;
    final double activeProgress = (time != null) ? ((time! / 2.0) % 1.0) : progress;
    final double t = (activeProgress * 1.5) % 1.0;
    final double glintX = center.dx - r + (t * r * 2.5);

    final Paint glintPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: (0.65 * crestShimmer).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(glintX - 10, center.dy - r, 20, r * 2));

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));
    canvas.drawRect(Rect.fromCircle(center: center, radius: r), glintPaint);
    canvas.restore();
  }

  void _paintHonorStars(Canvas canvas, Offset bottomCenter, double barWidth) {
    final Color starColor = Color.lerp(
      goldColor,
      SocialThemeTokens.celestialGoldLight,
      (0.6 * metallicReflection).clamp(0.0, 1.0),
    )!;
    final Paint starPaint = Paint()..color = starColor;
    final Paint shadowPaint = Paint()..color = Colors.black87;

    final double spacing = barWidth / (starCount + 1);
    final double startX = bottomCenter.dx - (barWidth * 0.5);

    for (int s = 1; s <= starCount; s++) {
      final Offset starPos = Offset(startX + (s * spacing), bottomCenter.dy);
      // Shadow
      _draw5PointStar(canvas, starPos + const Offset(0, 1), 4.2, shadowPaint);
      // Star
      _draw5PointStar(canvas, starPos, 4.0, starPaint);
    }
  }

  void _draw5PointStar(Canvas canvas, Offset c, double r, Paint paint) {
    final Path path = Path();
    for (int i = 0; i < 10; i++) {
      final double a = (i * math.pi) / 5 - (math.pi / 2);
      final double rad = (i % 2 == 0) ? r : r * 0.45;
      final double x = c.dx + math.cos(a) * rad;
      final double y = c.dy + math.sin(a) * rad;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HonorInsigniaPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.shader != shader ||
        oldDelegate.time != time ||
        oldDelegate.starCount != starCount ||
        oldDelegate.ribbonColor != ribbonColor ||
        oldDelegate.goldColor != goldColor ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.crestShimmer != crestShimmer ||
        oldDelegate.metallicReflection != metallicReflection;
  }
}

/// Standalone Widget adapter for Faction Honor Insignia.
class FactionHonorInsigniaWidget extends StatefulWidget {
  const FactionHonorInsigniaWidget({
    super.key,
    this.shader,
    this.size = 88.0,
    this.starCount = 3,
    this.ribbonColor = SocialThemeTokens.balaurRuby,
    this.goldColor = SocialThemeTokens.celestialGold,
    this.glowIntensity = 1.0,
    this.crestShimmer = 1.0,
    this.metallicReflection = 1.0,
    this.duration = const Duration(seconds: 3),
  });

  final ui.FragmentShader? shader;
  final double size;
  final int starCount;
  final Color ribbonColor;
  final Color goldColor;
  final double glowIntensity;
  final double crestShimmer;
  final double metallicReflection;
  final Duration duration;

  @override
  State<FactionHonorInsigniaWidget> createState() => _FactionHonorInsigniaWidgetState();
}

class _FactionHonorInsigniaWidgetState extends State<FactionHonorInsigniaWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void didUpdateWidget(covariant FactionHonorInsigniaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: HonorInsigniaPainter(
            progress: _controller.value,
            shader: widget.shader,
            starCount: widget.starCount,
            ribbonColor: widget.ribbonColor,
            goldColor: widget.goldColor,
            glowIntensity: widget.glowIntensity,
            crestShimmer: widget.crestShimmer,
            metallicReflection: widget.metallicReflection,
          ),
        );
      },
    );
  }
}
