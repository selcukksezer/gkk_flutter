import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/social_theme_tokens.dart';

/// Authentic 2027 Aion 2 Mobile Ancient Enchantment Stone vector painter.
///
/// Features a floating mystical monolith with glowing carved celestial glyphs,
/// fractured aether cracks, and two rotating concentric runic orbital rings.
///
/// Supports direct GPU acceleration via [ui.FragmentShader] with 20 sequential
/// float uniforms (indices 0..19), mana rune pulse, elemental aura floats,
/// and provides an ultra-rich analytical Canvas fallback when running without GPU shaders.
class EnchantmentStonePainter extends CustomPainter {
  const EnchantmentStonePainter({
    required this.progress,
    this.shader,
    this.time,
    this.glyphColor = SocialThemeTokens.aetherCyan,
    this.secondaryGlow = SocialThemeTokens.daevaPrismViolet,
    this.stoneBaseColor = const Color(0xFF1E2838),
    this.showOrbitingRings = true,
    this.glowIntensity = 1.0,
    this.manaRunePulse,
    this.elementalAura,
  });

  /// Total number of uniform float values expected by the runtime shader pipeline.
  /// Order:
  /// - 0..1: uResolution (vec2)
  /// - 2: uTime (float)
  /// - 3: uProgress (float)
  /// - 4: uGlowIntensity (float)
  /// - 5: uManaRunePulse (float)
  /// - 6: uElementalAura (float)
  /// - 7..10: uGlyphColor (vec4 in linear RGBA)
  /// - 11..14: uSecondaryGlow (vec4 in linear RGBA)
  /// - 15..18: uStoneBaseColor (vec4 in linear RGBA)
  /// - 19: uOrbitRingAngle (float)
  /// Total: 20 floats
  static const int kUniformFloatCount = 20;

  static const int indexResolution = 0;
  static const int indexTime = 2;
  static const int indexProgress = 3;
  static const int indexGlowIntensity = 4;
  static const int indexManaRunePulse = 5;
  static const int indexElementalAura = 6;
  static const int indexGlyphColor = 7;
  static const int indexSecondaryGlow = 11;
  static const int indexStoneBaseColor = 15;
  static const int indexOrbitRingAngle = 19;

  final double progress;
  final ui.FragmentShader? shader;
  final double? time;
  final Color glyphColor;
  final Color secondaryGlow;
  final Color stoneBaseColor;
  final bool showOrbitingRings;
  final double glowIntensity;
  final double? manaRunePulse;
  final double? elementalAura;

  /// Effective mana rune pulse oscillating between [0.4 .. 1.0].
  double get effectiveManaRunePulse =>
      manaRunePulse ?? (0.7 + 0.3 * math.sin(progress * 3 * math.pi));

  /// Effective elemental levitation aura pulse oscillating between [0.0 .. 1.0].
  double get effectiveElementalAura =>
      elementalAura ?? (0.5 + 0.5 * math.sin(progress * 2 * math.pi));

  /// Converts an sRGB color component [0.0 .. 1.0] to linear RGB space.
  static double sRgbToLinear(double c) {
    return (c <= 0.04045)
        ? (c / 12.92)
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Converts a Flutter [Color] into 4 linear RGBA floats [r, g, b, a].
  static (double, double, double, double) colorToLinearRgba(Color color) {
    return (
      sRgbToLinear(color.r),
      sRgbToLinear(color.g),
      sRgbToLinear(color.b),
      color.a,
    );
  }

  /// Builds a contiguous Float32List containing all 20 uniforms in GLSL declaration order.
  static Float32List packUniforms({
    required Size size,
    required double progress,
    double? time,
    Color glyphColor = SocialThemeTokens.aetherCyan,
    Color secondaryGlow = SocialThemeTokens.daevaPrismViolet,
    Color stoneBaseColor = const Color(0xFF1E2838),
    double glowIntensity = 1.0,
    double? manaRunePulse,
    double? elementalAura,
  }) {
    final Float32List buffer = Float32List(kUniformFloatCount);
    final double activeTime = time ?? (progress * 4.0);
    final double activeRunePulse =
        manaRunePulse ?? (0.7 + 0.3 * math.sin(progress * 3 * math.pi));
    final double activeElementalAura =
        elementalAura ?? (0.5 + 0.5 * math.sin(progress * 2 * math.pi));
    final double ringAngle = progress * 2 * math.pi * 0.6;

    // 0..1: uResolution (vec2)
    buffer[0] = size.width;
    buffer[1] = size.height;

    // 2: uTime (float)
    buffer[2] = activeTime;

    // 3: uProgress (float)
    buffer[3] = progress;

    // 4: uGlowIntensity (float)
    buffer[4] = glowIntensity;

    // 5: uManaRunePulse (float)
    buffer[5] = activeRunePulse;

    // 6: uElementalAura (float)
    buffer[6] = activeElementalAura;

    // 7..10: uGlyphColor (vec4 in linear RGB)
    final (double gr, double gg, double gb, double ga) = colorToLinearRgba(glyphColor);
    buffer[7] = gr;
    buffer[8] = gg;
    buffer[9] = gb;
    buffer[10] = ga;

    // 11..14: uSecondaryGlow (vec4 in linear RGB)
    final (double sr, double sg, double sb, double sa) = colorToLinearRgba(secondaryGlow);
    buffer[11] = sr;
    buffer[12] = sg;
    buffer[13] = sb;
    buffer[14] = sa;

    // 15..18: uStoneBaseColor (vec4 in linear RGB)
    final (double br, double bg, double bb, double ba) = colorToLinearRgba(stoneBaseColor);
    buffer[15] = br;
    buffer[16] = bg;
    buffer[17] = bb;
    buffer[18] = ba;

    // 19: uOrbitRingAngle (float)
    buffer[19] = ringAngle;

    return buffer;
  }

  /// Binds all 20 uniforms to a Flutter [ui.FragmentShader] matching GLSL declaration order:
  /// - 0..1: uResolution (vec2)
  /// - 2: uTime (float)
  /// - 3: uProgress (float)
  /// - 4: uGlowIntensity (float)
  /// - 5: uManaRunePulse (float)
  /// - 6: uElementalAura (float)
  /// - 7..10: uGlyphColor (vec4, linear RGBA)
  /// - 11..14: uSecondaryGlow (vec4, linear RGBA)
  /// - 15..18: uStoneBaseColor (vec4, linear RGBA)
  /// - 19: uOrbitRingAngle (float)
  void applyUniforms(ui.FragmentShader targetShader, Size size) {
    final double activeTime = time ?? (progress * 4.0);

    // 0..1: uniform vec2 uResolution;
    targetShader.setFloat(0, size.width);
    targetShader.setFloat(1, size.height);

    // 2: uniform float uTime;
    targetShader.setFloat(2, activeTime);

    // 3: uniform float uProgress;
    targetShader.setFloat(3, progress);

    // 4: uniform float uGlowIntensity;
    targetShader.setFloat(4, glowIntensity);

    // 5: uniform float uManaRunePulse;
    targetShader.setFloat(5, effectiveManaRunePulse);

    // 6: uniform float uElementalAura;
    targetShader.setFloat(6, effectiveElementalAura);

    // 7..10: uniform vec4 uGlyphColor;
    final (double gr, double gg, double gb, double ga) = colorToLinearRgba(glyphColor);
    targetShader.setFloat(7, gr);
    targetShader.setFloat(8, gg);
    targetShader.setFloat(9, gb);
    targetShader.setFloat(10, ga);

    // 11..14: uniform vec4 uSecondaryGlow;
    final (double sr, double sg, double sb, double sa) = colorToLinearRgba(secondaryGlow);
    targetShader.setFloat(11, sr);
    targetShader.setFloat(12, sg);
    targetShader.setFloat(13, sb);
    targetShader.setFloat(14, sa);

    // 15..18: uniform vec4 uStoneBaseColor;
    final (double br, double bg, double bb, double ba) = colorToLinearRgba(stoneBaseColor);
    targetShader.setFloat(15, br);
    targetShader.setFloat(16, bg);
    targetShader.setFloat(17, bb);
    targetShader.setFloat(18, ba);

    // 19: uniform float uOrbitRingAngle;
    targetShader.setFloat(19, progress * 2 * math.pi * 0.6);
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

    final double bobY = math.sin(progress * 2 * math.pi) * 5.0;
    final Offset center = Offset(size.width * 0.5, size.height * 0.5 + bobY);
    final double w = size.width * 0.52;
    final double h = size.height * 0.68;

    if (shader != null) {
      // 1. GPU Runtime FragmentShader path (20 uniforms synchronized)
      applyUniforms(shader!, size);
      final Paint shaderPaint = Paint()..shader = shader!;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), shaderPaint);
    } else {
      // 2. High-fidelity analytical Canvas CPU fallback
      _paintLevitationAura(canvas, center, w, h);
    }

    if (showOrbitingRings) {
      _paintRunicRing(canvas, center, w * 1.5, h * 0.55, isForeground: false);
    }

    _paintMonolithBody(canvas, center, w, h);
    _paintGlyphsAndCracks(canvas, center, w, h);

    if (showOrbitingRings) {
      _paintRunicRing(canvas, center, w * 1.5, h * 0.55, isForeground: true);
    }

    _paintAscendingEmbers(canvas, center, w, h);
  }

  void _paintLevitationAura(Canvas canvas, Offset center, double w, double h) {
    final double pulse = effectiveElementalAura;
    final Paint auraPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        colors: [
          glyphColor.withValues(alpha: 0.38 * pulse * glowIntensity),
          secondaryGlow.withValues(alpha: 0.18 * pulse * glowIntensity),
          Colors.transparent,
        ],
        stops: const [0.2, 0.65, 1.0],
      ).createShader(Rect.fromCenter(center: center, width: w * 2.2, height: h * 1.8));

    canvas.drawOval(
      Rect.fromCenter(center: center, width: w * 2.2, height: h * 1.8),
      auraPaint,
    );
  }

  void _paintMonolithBody(Canvas canvas, Offset center, double w, double h) {
    final Path stonePath = Path();
    final double halfW = w * 0.5;
    final double halfH = h * 0.5;
    final double taper = w * 0.15;

    stonePath.moveTo(center.dx - halfW + taper, center.dy - halfH);
    stonePath.lineTo(center.dx + halfW - taper, center.dy - halfH);
    stonePath.lineTo(center.dx + halfW, center.dy - halfH * 0.3);
    stonePath.lineTo(center.dx + halfW - taper * 0.5, center.dy + halfH);
    stonePath.lineTo(center.dx - halfW + taper * 0.5, center.dy + halfH);
    stonePath.lineTo(center.dx - halfW, center.dy - halfH * 0.3);
    stonePath.close();

    final Paint stonePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFF2C394F),
          Color(0xFF1E2838),
          Color(0xFF141C28),
        ],
      ).createShader(Rect.fromCenter(center: center, width: w, height: h));
    canvas.drawPath(stonePath, stonePaint);

    final Paint edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF637B9F),
          glyphColor.withValues(alpha: 0.5),
          const Color(0xFF0F1520),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCenter(center: center, width: w, height: h));
    canvas.drawPath(stonePath, edgePaint);
  }

  void _paintGlyphsAndCracks(Canvas canvas, Offset center, double w, double h) {
    final double pulse = effectiveManaRunePulse;

    final Paint glowPaint = Paint()
      ..blendMode = BlendMode.screen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white,
          glyphColor,
          secondaryGlow,
        ],
      ).createShader(Rect.fromCenter(center: center, width: w, height: h));

    final Path glyphPath = Path();
    final double gy = center.dy - h * 0.12;

    glyphPath.moveTo(center.dx, gy - h * 0.18);
    glyphPath.lineTo(center.dx + w * 0.22, gy);
    glyphPath.lineTo(center.dx, gy + h * 0.18);
    glyphPath.lineTo(center.dx - w * 0.22, gy);
    glyphPath.close();

    glyphPath.moveTo(center.dx - w * 0.15, gy);
    glyphPath.lineTo(center.dx + w * 0.15, gy);

    final double lowY = center.dy + h * 0.22;
    glyphPath.moveTo(center.dx, lowY - h * 0.08);
    glyphPath.lineTo(center.dx, lowY + h * 0.12);
    glyphPath.moveTo(center.dx - w * 0.14, lowY - h * 0.04);
    glyphPath.lineTo(center.dx, lowY + h * 0.04);
    glyphPath.lineTo(center.dx + w * 0.14, lowY - h * 0.04);

    final Path crackPath = Path();
    crackPath.moveTo(center.dx - w * 0.35, center.dy - h * 0.25);
    crackPath.lineTo(center.dx - w * 0.18, center.dy - h * 0.15);
    crackPath.lineTo(center.dx - w * 0.24, center.dy + h * 0.05);
    crackPath.lineTo(center.dx - w * 0.10, center.dy + h * 0.22);
    crackPath.lineTo(center.dx - w * 0.16, center.dy + h * 0.38);

    canvas.drawPath(glyphPath, glowPaint);
    canvas.drawPath(crackPath, glowPaint);

    final Paint bloomPaint = Paint()
      ..blendMode = BlendMode.screen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..color = glyphColor.withValues(alpha: 0.35 * pulse * glowIntensity);
    canvas.drawPath(glyphPath, bloomPaint);
  }

  void _paintRunicRing(Canvas canvas, Offset center, double ringW, double ringH, {required bool isForeground}) {
    final double tiltAngle = 0.38;
    final double rot = progress * 2 * math.pi * 0.6;

    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..blendMode = BlendMode.screen
      ..color = secondaryGlow.withValues(alpha: (isForeground ? 0.75 : 0.35) * glowIntensity);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tiltAngle);

    final Rect ringRect = Rect.fromCenter(center: Offset.zero, width: ringW, height: ringH);
    canvas.drawOval(ringRect, ringPaint);

    const int nodes = 6;
    for (int i = 0; i < nodes; i++) {
      final double a = rot + (i * 2 * math.pi / nodes);
      final double x = (ringW * 0.5) * math.cos(a);
      final double y = (ringH * 0.5) * math.sin(a);

      if ((isForeground && y >= 0) || (!isForeground && y < 0)) {
        final Paint nodePaint = Paint()
          ..blendMode = BlendMode.plus
          ..color = glyphColor.withValues(alpha: 0.9 * glowIntensity);
        canvas.drawCircle(Offset(x, y), 2.2, nodePaint);

        nodePaint.color = Colors.white;
        canvas.drawCircle(Offset(x, y), 1.0, nodePaint);
      }
    }

    canvas.restore();
  }

  void _paintAscendingEmbers(Canvas canvas, Offset center, double w, double h) {
    final Paint emberPaint = Paint()..blendMode = BlendMode.plus;
    const int count = 8;

    for (int i = 0; i < count; i++) {
      final double seed = (i * 41.3) % 1.0;
      final double t = (progress * (0.8 + seed * 0.5) + seed) % 1.0;
      final double x = center.dx + (seed - 0.5) * w * 0.8;
      final double y = center.dy + h * 0.45 - (t * h * 0.95);
      final double alpha = math.sin(t * math.pi) * 0.75 * glowIntensity;

      emberPaint.color = glyphColor.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 1.5, emberPaint);
    }
  }

  @override
  bool shouldRepaint(covariant EnchantmentStonePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.shader != shader ||
        oldDelegate.time != time ||
        oldDelegate.glyphColor != glyphColor ||
        oldDelegate.secondaryGlow != secondaryGlow ||
        oldDelegate.stoneBaseColor != stoneBaseColor ||
        oldDelegate.showOrbitingRings != showOrbitingRings ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.manaRunePulse != manaRunePulse ||
        oldDelegate.elementalAura != elementalAura;
  }
}

/// Standalone Widget adapter for Ancient Enchantment Stone.
class AncientEnchantmentStoneWidget extends StatefulWidget {
  const AncientEnchantmentStoneWidget({
    super.key,
    this.size = 88.0,
    this.shader,
    this.time,
    this.glyphColor = SocialThemeTokens.aetherCyan,
    this.secondaryGlow = SocialThemeTokens.daevaPrismViolet,
    this.stoneBaseColor = const Color(0xFF1E2838),
    this.showOrbitingRings = true,
    this.glowIntensity = 1.0,
    this.manaRunePulse,
    this.elementalAura,
    this.duration = const Duration(seconds: 4),
  });

  final double size;
  final ui.FragmentShader? shader;
  final double? time;
  final Color glyphColor;
  final Color secondaryGlow;
  final Color stoneBaseColor;
  final bool showOrbitingRings;
  final double glowIntensity;
  final double? manaRunePulse;
  final double? elementalAura;
  final Duration duration;

  @override
  State<AncientEnchantmentStoneWidget> createState() => _AncientEnchantmentStoneWidgetState();
}

class _AncientEnchantmentStoneWidgetState extends State<AncientEnchantmentStoneWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void didUpdateWidget(covariant AncientEnchantmentStoneWidget oldWidget) {
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
        final double currentProgress = _controller.value;
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: EnchantmentStonePainter(
            progress: currentProgress,
            shader: widget.shader,
            time: widget.time ?? (currentProgress * 4.0),
            glyphColor: widget.glyphColor,
            secondaryGlow: widget.secondaryGlow,
            stoneBaseColor: widget.stoneBaseColor,
            showOrbitingRings: widget.showOrbitingRings,
            glowIntensity: widget.glowIntensity,
            manaRunePulse: widget.manaRunePulse,
            elementalAura: widget.elementalAura,
          ),
        );
      },
    );
  }
}
