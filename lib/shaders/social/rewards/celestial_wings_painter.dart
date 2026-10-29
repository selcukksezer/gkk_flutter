import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/social_theme_tokens.dart';

/// Exact uniform layout constants and float offsets for Celestial Wings shader.
///
/// Declared GLSL layout:
/// - uniform vec2  uResolution;            (floats 0, 1)
/// - uniform float uTime;                  (float 2)
/// - uniform float uProgress;              (float 3)
/// - uniform float uFlap;                  (float 4)
/// - uniform float uGlowIntensity;         (float 5)
/// - uniform float uFeatherDisplacement;   (float 6)
/// - uniform vec4  uPrimaryColor;          (floats 7, 8, 9, 10 - linear RGBA)
/// - uniform vec4  uAccentColor;           (floats 11, 12, 13, 14 - linear RGBA)
/// - uniform vec4  uCoreJewelColor;        (floats 15, 16, 17, 18 - linear RGBA)
/// Total: 19 float uniforms.
abstract final class CelestialWingsUniforms {
  static const int indexResolution = 0;
  static const int indexTime = 2;
  static const int indexProgress = 3;
  static const int indexFlap = 4;
  static const int indexGlowIntensity = 5;
  static const int indexFeatherDisplacement = 6;
  static const int indexPrimaryColor = 7;
  static const int indexAccentColor = 11;
  static const int indexCoreJewelColor = 15;
  static const int floatCount = 19;

  /// Converts standard sRGB channel to linear RGB for photometrically accurate GLSL shading.
  static double sRgbToLinear(double c) {
    return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Converts a Flutter [Color] to a 4-float linear RGBA tuple.
  static (double, double, double, double) colorToLinearRgba(Color color) {
    return (
      sRgbToLinear(color.r),
      sRgbToLinear(color.g),
      sRgbToLinear(color.b),
      color.a,
    );
  }

  /// Packs uniform floats into a [Float32List] buffer in the exact order expected by the shader.
  static Float32List buildUniforms({
    required Size size,
    required double time,
    required double progress,
    required double flap,
    required double glowIntensity,
    required double featherDisplacement,
    required Color primaryColor,
    required Color accentColor,
    required Color coreJewelColor,
    bool useLinearColors = true,
  }) {
    final Float32List buffer = Float32List(floatCount);
    buffer[0] = size.width;
    buffer[1] = size.height;
    buffer[2] = time;
    buffer[3] = progress;
    buffer[4] = flap;
    buffer[5] = glowIntensity;
    buffer[6] = featherDisplacement;

    if (useLinearColors) {
      final (double pr, double pg, double pb, double pa) = colorToLinearRgba(primaryColor);
      buffer[7] = pr;
      buffer[8] = pg;
      buffer[9] = pb;
      buffer[10] = pa;

      final (double ar, double ag, double ab, double aa) = colorToLinearRgba(accentColor);
      buffer[11] = ar;
      buffer[12] = ag;
      buffer[13] = ab;
      buffer[14] = aa;

      final (double cr, double cg, double cb, double ca) = colorToLinearRgba(coreJewelColor);
      buffer[15] = cr;
      buffer[16] = cg;
      buffer[17] = cb;
      buffer[18] = ca;
    } else {
      buffer[7] = primaryColor.r;
      buffer[8] = primaryColor.g;
      buffer[9] = primaryColor.b;
      buffer[10] = primaryColor.a;

      buffer[11] = accentColor.r;
      buffer[12] = accentColor.g;
      buffer[13] = accentColor.b;
      buffer[14] = accentColor.a;

      buffer[15] = coreJewelColor.r;
      buffer[16] = coreJewelColor.g;
      buffer[17] = coreJewelColor.b;
      buffer[18] = coreJewelColor.a;
    }

    return buffer;
  }

  /// Directly applies uniforms onto a [ui.FragmentShader].
  static void apply(
    ui.FragmentShader shader, {
    required Size size,
    required double time,
    required double progress,
    required double flap,
    required double glowIntensity,
    required double featherDisplacement,
    required Color primaryColor,
    required Color accentColor,
    required Color coreJewelColor,
    bool useLinearColors = true,
  }) {
    final Float32List uniforms = buildUniforms(
      size: size,
      time: time,
      progress: progress,
      flap: flap,
      glowIntensity: glowIntensity,
      featherDisplacement: featherDisplacement,
      primaryColor: primaryColor,
      accentColor: accentColor,
      coreJewelColor: coreJewelColor,
      useLinearColors: useLinearColors,
    );
    for (int i = 0; i < floatCount; i++) {
      shader.setFloat(i, uniforms[i]);
    }
  }
}

/// Authentic 2027 Aion 2 Mobile Celestial Archon Wings vector painter.
///
/// Features multi-tiered feathered plumage, flowing ethereal energy tips,
/// a central glowing aether keystone, and smooth breathing flap dynamics.
class CelestialWingsPainter extends CustomPainter {
  const CelestialWingsPainter({
    required this.progress,
    this.time,
    this.primaryColor = SocialThemeTokens.aetherCyan,
    this.accentColor = SocialThemeTokens.celestialGoldLight,
    this.coreJewelColor = SocialThemeTokens.celestialGold,
    this.glowIntensity = 1.0,
    this.featherDisplacementFactor = 1.0,
    this.shader,
  });

  /// Continuous animation progress [0.0 .. 1.0].
  final double progress;

  /// Optional absolute animation elapsed time in seconds.
  /// If null, derived automatically as `progress * 4.0`.
  final double? time;

  /// Main ethereal feather plumage color.
  final Color primaryColor;

  /// Tip and ribbing highlight accent.
  final Color accentColor;

  /// Central keystone jewel color.
  final Color coreJewelColor;

  /// Glow intensity multiplier.
  final double glowIntensity;

  /// Dynamic feather aerodynamic flex and displacement scale [0.0 .. 2.0].
  final double featherDisplacementFactor;

  /// Optional hardware-accelerated [ui.FragmentShader].
  /// When provided, uniforms are synchronized and painted as an ethereal background aura.
  final ui.FragmentShader? shader;

  /// Total float uniforms bound for this painter (19 floats).
  static const int kUniformFloatCount = CelestialWingsUniforms.floatCount;

  /// Active simulation time in seconds.
  double get activeTime => time ?? (progress * 4.0);

  /// Active wing flapping oscillation angle.
  double get activeFlap => math.sin(progress * 2 * math.pi) * 0.06;

  /// Builds a [Float32List] buffer with all 19 uniforms matching the GLSL declaration order.
  Float32List toUniformFloats(Size size) {
    return CelestialWingsUniforms.buildUniforms(
      size: size,
      time: activeTime,
      progress: progress,
      flap: activeFlap,
      glowIntensity: glowIntensity,
      featherDisplacement: featherDisplacementFactor,
      primaryColor: primaryColor,
      accentColor: accentColor,
      coreJewelColor: coreJewelColor,
    );
  }

  /// Binds all 19 uniforms sequentially to a target [ui.FragmentShader].
  void applyUniforms(ui.FragmentShader targetShader, Size size) {
    CelestialWingsUniforms.apply(
      targetShader,
      size: size,
      time: activeTime,
      progress: progress,
      flap: activeFlap,
      glowIntensity: glowIntensity,
      featherDisplacement: featherDisplacementFactor,
      primaryColor: primaryColor,
      accentColor: accentColor,
      coreJewelColor: coreJewelColor,
    );
  }

  /// Applies a pre-packed [Float32List] uniform buffer onto a [ui.FragmentShader].
  static void applyPackedUniforms(ui.FragmentShader targetShader, Float32List buffer) {
    assert(buffer.length >= kUniformFloatCount);
    for (int i = 0; i < kUniformFloatCount; i++) {
      targetShader.setFloat(i, buffer[i]);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 0. Hardware Shader Backing Layer (if available)
    if (shader != null) {
      applyUniforms(shader!, size);
      final Paint shaderPaint = Paint()
        ..shader = shader
        ..blendMode = BlendMode.screen;
      canvas.drawRect(Offset.zero & size, shaderPaint);
    }

    final Offset center = Offset(size.width * 0.5, size.height * 0.55);
    final double span = size.width * 0.46;
    final double h = size.height * 0.44;

    // Breathing flap oscillation
    final double flap = activeFlap;

    // 1. Ethereal Back Aura
    _paintBackAura(canvas, center, span, h);

    // 2. Left Wing (mirrored coordinate system)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-flap);
    _paintSingleWing(canvas, span, h, isLeft: true);
    canvas.restore();

    // 3. Right Wing
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(flap);
    _paintSingleWing(canvas, span, h, isLeft: false);
    canvas.restore();

    // 4. Central Archon Keystone Jewel & Clasp
    _paintCentralKeystone(canvas, center, size.width * 0.12);

    // 5. Floating Aether Dust Particles
    _paintFloatingDust(canvas, center, span, h);
  }

  void _paintBackAura(Canvas canvas, Offset center, double span, double h) {
    // Harmonic ethereal glow timing: dual-frequency sinusoidal breathing oscillation
    final double glowPulse = 0.65 + 0.35 * math.sin(progress * 2 * math.pi);
    final double secondaryPulse = 0.5 + 0.5 * math.cos(progress * 4 * math.pi + 0.5);
    final double timedAuraAlpha = (0.35 * glowPulse * glowIntensity).clamp(0.0, 1.0);
    final double timedAccentAlpha = (0.18 * secondaryPulse * glowIntensity).clamp(0.0, 1.0);

    final double timedSpan = span * (2.1 + 0.15 * glowPulse);
    final double timedH = h * (1.7 + 0.15 * glowPulse);

    final Paint auraPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: timedAuraAlpha),
          accentColor.withValues(alpha: timedAccentAlpha),
          Colors.transparent,
        ],
        stops: const [0.1, 0.55, 1.0],
      ).createShader(Rect.fromCenter(center: center, width: timedSpan, height: timedH * 1.1));

    canvas.drawOval(
      Rect.fromCenter(center: center - Offset(0, h * 0.15), width: timedSpan, height: timedH),
      auraPaint,
    );
  }

  void _paintSingleWing(Canvas canvas, double span, double h, {required bool isLeft}) {
    final double dir = isLeft ? -1.0 : 1.0;

    // 3 tiers of feather plumage: primary (outer), secondary (mid), scapular (inner)
    final featherTiers = [
      // Primary outer flight feathers
      (length: span, curvature: 0.85, width: h * 0.22, alpha: 0.75, offsetAngle: -0.35),
      (length: span * 0.92, curvature: 0.70, width: h * 0.20, alpha: 0.85, offsetAngle: -0.15),
      (length: span * 0.82, curvature: 0.55, width: h * 0.18, alpha: 0.90, offsetAngle: 0.05),
      // Secondary mid-tier covert feathers
      (length: span * 0.68, curvature: 0.40, width: h * 0.16, alpha: 0.95, offsetAngle: 0.25),
      (length: span * 0.52, curvature: 0.25, width: h * 0.15, alpha: 0.98, offsetAngle: 0.42),
      // Inner scapular base
      (length: span * 0.36, curvature: 0.15, width: h * 0.14, alpha: 1.0, offsetAngle: 0.58),
    ];

    for (int i = 0; i < featherTiers.length; i++) {
      final f = featherTiers[i];
      final Path path = Path();

      // Dynamic feather displacement lag and tip flex per tier
      final double tierFlex = (featherTiers.length - i) / featherTiers.length;
      final double tierDisplacement = math.sin(progress * 2 * math.pi - i * 0.3) *
          0.045 *
          tierFlex *
          featherDisplacementFactor;
      final double dynamicAngle = f.offsetAngle + tierDisplacement;

      final double endX = dir * f.length * math.cos(dynamicAngle);
      final double endY = -f.length * math.sin(dynamicAngle) - (h * 0.15) + (tierDisplacement * h * 0.35);

      final double ctrlX1 = dir * (f.length * 0.45);
      final double ctrlY1 = -h * 0.65 + (tierDisplacement * h * 0.2);
      final double ctrlX2 = dir * (f.length * 0.85);
      final double ctrlY2 = -h * 0.55 + (tierDisplacement * h * 0.45);

      path.moveTo(0, 0);
      path.cubicTo(ctrlX1, ctrlY1, ctrlX2, ctrlY2, endX, endY);
      path.cubicTo(
        ctrlX2 - (dir * f.width),
        ctrlY2 + (h * 0.2),
        ctrlX1 - (dir * f.width * 0.5),
        ctrlY1 + (h * 0.3),
        0,
        0,
      );
      path.close();

      // Feather gradient: ethereal core to luminous golden/cyan tip
      final Paint featherPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: isLeft ? Alignment.topLeft : Alignment.topRight,
          colors: [
            SocialThemeTokens.abyssCardHighlight,
            primaryColor.withValues(alpha: f.alpha),
            accentColor.withValues(alpha: f.alpha * 0.9),
            Colors.white.withValues(alpha: f.alpha),
          ],
          stops: const [0.0, 0.45, 0.82, 1.0],
        ).createShader(Rect.fromLTWH(dir < 0 ? endX : 0, -h, f.length, h));

      canvas.drawPath(path, featherPaint);

      // Feather shaft / spine ribbing
      final Paint ribPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = accentColor.withValues(alpha: 0.8);
      canvas.drawLine(Offset.zero, Offset(endX * 0.82, endY * 0.82), ribPaint);
    }
  }

  void _paintCentralKeystone(Canvas canvas, Offset center, double size) {
    // Ornate gold mounting plate
    final Rect mountRect = Rect.fromCenter(center: center, width: size * 1.3, height: size * 1.3);
    final Paint mountPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          SocialThemeTokens.celestialGoldLight,
          SocialThemeTokens.celestialGold,
          SocialThemeTokens.celestialGoldDark,
        ],
      ).createShader(mountRect);

    final Path starMount = Path();
    for (int i = 0; i < 8; i++) {
      final double a = (i * math.pi) / 4 - (math.pi / 2);
      final double r = (i % 2 == 0) ? size * 0.65 : size * 0.35;
      final double x = center.dx + math.cos(a) * r;
      final double y = center.dy + math.sin(a) * r;
      if (i == 0) {
        starMount.moveTo(x, y);
      } else {
        starMount.lineTo(x, y);
      }
    }
    starMount.close();
    canvas.drawPath(starMount, mountPaint);

    // Inner diamond gemstone
    final Path gemPath = Path()
      ..moveTo(center.dx, center.dy - size * 0.45)
      ..lineTo(center.dx + size * 0.45, center.dy)
      ..lineTo(center.dx, center.dy + size * 0.45)
      ..lineTo(center.dx - size * 0.45, center.dy)
      ..close();

    final Paint gemPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          coreJewelColor,
          SocialThemeTokens.celestialAmber,
        ],
      ).createShader(mountRect);
    canvas.drawPath(gemPath, gemPaint);

    // Glint flare with ethereal breathing pulse
    final double flarePulse = 0.7 + 0.3 * math.sin(progress * 3 * math.pi);
    final Paint flarePaint = Paint()
      ..blendMode = BlendMode.screen
      ..color = Colors.white.withValues(alpha: (0.9 * flarePulse).clamp(0.0, 1.0));
    canvas.drawCircle(center - Offset(size * 0.1, size * 0.1), 2.2 * flarePulse, flarePaint);
  }

  void _paintFloatingDust(Canvas canvas, Offset center, double span, double h) {
    final Paint dustPaint = Paint()..blendMode = BlendMode.plus;
    const int count = 10;

    for (int i = 0; i < count; i++) {
      final double seed = (i * 31.7) % 1.0;
      final double t = (progress * (0.8 + seed * 0.5) + seed) % 1.0;
      final double side = (i % 2 == 0) ? -1.0 : 1.0;

      final double x = center.dx + side * (span * (0.3 + seed * 0.65));
      final double y = center.dy - (h * (0.2 + seed * 0.8)) - (t * 20.0);
      final double alpha = math.sin(t * math.pi) * 0.75 * glowIntensity;

      dustPaint.color = accentColor.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 1.5, dustPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CelestialWingsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.time != time ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.coreJewelColor != coreJewelColor ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.featherDisplacementFactor != featherDisplacementFactor ||
        oldDelegate.shader != shader;
  }

  @override
  bool shouldRebuildSemantics(covariant CelestialWingsPainter oldDelegate) => false;
}

/// Standalone Widget adapter for Celestial Archon Wings.
class CelestialArchonWingsWidget extends StatefulWidget {
  const CelestialArchonWingsWidget({
    super.key,
    this.size = 96.0,
    this.time,
    this.primaryColor = SocialThemeTokens.aetherCyan,
    this.accentColor = SocialThemeTokens.celestialGoldLight,
    this.coreJewelColor = SocialThemeTokens.celestialGold,
    this.glowIntensity = 1.0,
    this.featherDisplacementFactor = 1.0,
    this.shader,
    this.duration = const Duration(seconds: 3),
  });

  final double size;
  final double? time;
  final Color primaryColor;
  final Color accentColor;
  final Color coreJewelColor;
  final double glowIntensity;
  final double featherDisplacementFactor;
  final ui.FragmentShader? shader;
  final Duration duration;

  @override
  State<CelestialArchonWingsWidget> createState() => _CelestialArchonWingsWidgetState();
}

class _CelestialArchonWingsWidgetState extends State<CelestialArchonWingsWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void didUpdateWidget(covariant CelestialArchonWingsWidget oldWidget) {
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
          painter: CelestialWingsPainter(
            progress: _controller.value,
            time: widget.time,
            primaryColor: widget.primaryColor,
            accentColor: widget.accentColor,
            coreJewelColor: widget.coreJewelColor,
            glowIntensity: widget.glowIntensity,
            featherDisplacementFactor: widget.featherDisplacementFactor,
            shader: widget.shader,
          ),
        );
      },
    );
  }
}
