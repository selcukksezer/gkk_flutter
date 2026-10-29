import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/social_theme_tokens.dart';

/// High-performance procedural shader & painter simulating 2027 Aion 2 Mobile
/// celestial banner energy flow, holographic iridescent sheen, and gold filigree shimmer.
///
/// Supports direct GPU acceleration via [ui.FragmentShader] compiled from
/// `lib/shaders/social/glsl/celestial_banner.frag` with 17 sequential float uniforms (0..16),
/// and provides an ultra-rich analytical Canvas fallback when running without GPU shaders.
class CelestialBannerPainter extends CustomPainter {
  const CelestialBannerPainter({
    required this.progress,
    this.shader,
    this.time,
    this.primaryEnergyColor = SocialThemeTokens.aetherCyan,
    this.secondaryEnergyColor = SocialThemeTokens.daevaPrismViolet,
    this.goldShimmerColor = SocialThemeTokens.celestialGold,
    this.energyIntensity = 1.0,
    this.borderRadius = 16.0,
    this.showBorderShimmer = true,
    this.showCornerFiligree = true,
    this.showFloatingMotes = true,
    this.isSwallowtail = false,
  });

  /// Total number of uniform float values declared in `celestial_banner.frag`.
  /// Order: uResolution (2), uTime (1), uProgress (1), uEnergyIntensity (1),
  ///        uPrimaryColor (4), uSecondaryColor (4), uGoldColor (4) = 17 floats.
  static const int kUniformFloatCount = 17;

  /// Normalized continuous animation progress [0.0 .. 1.0].
  final double progress;

  /// Optional GPU runtime fragment shader instance (`celestial_banner.frag`).
  final ui.FragmentShader? shader;

  /// Optional explicit time in seconds (defaults to progress * 4.0 for seamless looping).
  final double? time;

  /// Main flowing celestial aether color.
  final Color primaryEnergyColor;

  /// Secondary harmonizing astral hue.
  final Color secondaryEnergyColor;

  /// Gold border accent and glint color.
  final Color goldShimmerColor;

  /// Amplitude of the dynamic energy waves [0.0 .. 1.5].
  final double energyIntensity;

  /// Corner radius for the banner card.
  final double borderRadius;

  /// Whether to render the traveling gold edge glint.
  final bool showBorderShimmer;

  /// Whether to paint ornate celestial corner brackets.
  final bool showCornerFiligree;

  /// Whether floating energy sparks and dust motes are active.
  final bool showFloatingMotes;

  /// Whether bottom edge has a heraldic swallowtail/pennant notch.
  final bool isSwallowtail;

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

  /// Builds a contiguous Float32List containing all 17 uniforms in GLSL declaration order.
  static Float32List packUniforms({
    required Size size,
    required double progress,
    double? time,
    Color primaryEnergyColor = SocialThemeTokens.aetherCyan,
    Color secondaryEnergyColor = SocialThemeTokens.daevaPrismViolet,
    Color goldShimmerColor = SocialThemeTokens.celestialGold,
    double energyIntensity = 1.0,
  }) {
    final Float32List buffer = Float32List(kUniformFloatCount);
    final double activeTime = time ?? (progress * 4.0);

    // 0..1: uResolution (vec2)
    buffer[0] = size.width;
    buffer[1] = size.height;

    // 2: uTime (float)
    buffer[2] = activeTime;

    // 3: uProgress (float)
    buffer[3] = progress;

    // 4: uEnergyIntensity (float)
    buffer[4] = energyIntensity;

    // 5..8: uPrimaryColor (vec4 in linear RGB)
    final (double pr, double pg, double pb, double pa) = colorToLinearRgba(primaryEnergyColor);
    buffer[5] = pr;
    buffer[6] = pg;
    buffer[7] = pb;
    buffer[8] = pa;

    // 9..12: uSecondaryColor (vec4 in linear RGB)
    final (double sr, double sg, double sb, double sa) = colorToLinearRgba(secondaryEnergyColor);
    buffer[9] = sr;
    buffer[10] = sg;
    buffer[11] = sb;
    buffer[12] = sa;

    // 13..16: uGoldColor (vec4 in linear RGB)
    final (double gr, double gg, double gb, double ga) = colorToLinearRgba(goldShimmerColor);
    buffer[13] = gr;
    buffer[14] = gg;
    buffer[15] = gb;
    buffer[16] = ga;

    return buffer;
  }

  /// Binds all 17 uniforms to a Flutter [ui.FragmentShader] matching GLSL declaration order:
  /// - 0..1: uResolution (vec2)
  /// - 2: uTime (float)
  /// - 3: uProgress (float)
  /// - 4: uEnergyIntensity (float)
  /// - 5..8: uPrimaryColor (vec4, linear RGBA)
  /// - 9..12: uSecondaryColor (vec4, linear RGBA)
  /// - 13..16: uGoldColor (vec4, linear RGBA)
  void applyUniforms(ui.FragmentShader targetShader, Size size) {
    final double activeTime = time ?? (progress * 4.0);

    // 0..1: uniform vec2 uResolution;
    targetShader.setFloat(0, size.width);
    targetShader.setFloat(1, size.height);

    // 2: uniform float uTime;
    targetShader.setFloat(2, activeTime);

    // 3: uniform float uProgress;
    targetShader.setFloat(3, progress);

    // 4: uniform float uEnergyIntensity;
    targetShader.setFloat(4, energyIntensity);

    // 5..8: uniform vec4 uPrimaryColor;
    final (double pr, double pg, double pb, double pa) = colorToLinearRgba(primaryEnergyColor);
    targetShader.setFloat(5, pr);
    targetShader.setFloat(6, pg);
    targetShader.setFloat(7, pb);
    targetShader.setFloat(8, pa);

    // 9..12: uniform vec4 uSecondaryColor;
    final (double sr, double sg, double sb, double sa) = colorToLinearRgba(secondaryEnergyColor);
    targetShader.setFloat(9, sr);
    targetShader.setFloat(10, sg);
    targetShader.setFloat(11, sb);
    targetShader.setFloat(12, sa);

    // 13..16: uniform vec4 uGoldColor;
    final (double gr, double gg, double gb, double ga) = colorToLinearRgba(goldShimmerColor);
    targetShader.setFloat(13, gr);
    targetShader.setFloat(14, gg);
    targetShader.setFloat(15, gb);
    targetShader.setFloat(16, ga);
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

    final Rect rect = Offset.zero & size;
    final Path clipPath = _createBannerPath(rect);

    canvas.save();
    canvas.clipPath(clipPath);

    if (shader != null) {
      // 1. GPU Runtime FragmentShader path (17 uniforms synchronized)
      applyUniforms(shader!, size);
      final Paint shaderPaint = Paint()..shader = shader!;
      canvas.drawRect(rect, shaderPaint);
    } else {
      // 2. High-fidelity analytical Canvas CPU fallback
      // 1. Abyssal base gradient
      _paintBaseGradient(canvas, rect);

      // 2. Flowing celestial energy ribbons (multi-harmonic plasma waves)
      if (energyIntensity > 0.01) {
        _paintCelestialEnergyRibbons(canvas, rect);
      }

      // 3. Floating celestial motes / energy dust
      if (showFloatingMotes) {
        _paintCelestialMotes(canvas, rect);
      }

      // 4. Iridescent holographic sheen sweep
      _paintIridescentSheen(canvas, rect);

      // 5. Edge vignette for readability contrast
      _paintVignette(canvas, rect);
    }

    canvas.restore();

    // 6. Gold border shimmer & ornate corner filigree (drawn unclipped on top)
    _paintGoldBorderAndShimmer(canvas, clipPath, rect);

    if (showCornerFiligree) {
      _paintCornerFiligree(canvas, rect);
    }
  }

  Path _createBannerPath(Rect rect) {
    final Path path = Path();
    final double r = borderRadius;

    if (!isSwallowtail) {
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
      return path;
    }

    // Heraldic swallowtail pennant bottom
    final double notchDepth = rect.height * 0.15;
    path.moveTo(rect.left + r, rect.top);
    path.lineTo(rect.right - r, rect.top);
    path.arcToPoint(Offset(rect.right, rect.top + r), radius: Radius.circular(r));
    path.lineTo(rect.right, rect.bottom - r);
    path.arcToPoint(Offset(rect.right - r, rect.bottom), radius: Radius.circular(r));
    // Swallowtail center apex
    path.lineTo(rect.center.dx, rect.bottom - notchDepth);
    path.lineTo(rect.left + r, rect.bottom);
    path.arcToPoint(Offset(rect.left, rect.bottom - r), radius: Radius.circular(r));
    path.lineTo(rect.left, rect.top + r);
    path.arcToPoint(Offset(rect.left + r, rect.top), radius: Radius.circular(r));
    path.close();
    return path;
  }

  void _paintBaseGradient(Canvas canvas, Rect rect) {
    final Paint bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.4),
        radius: 1.2,
        colors: [
          Color.lerp(SocialThemeTokens.abyssCardSurface, primaryEnergyColor, 0.12)!,
          SocialThemeTokens.abyssCard,
          SocialThemeTokens.abyssVoid,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);
  }

  void _paintCelestialEnergyRibbons(Canvas canvas, Rect rect) {
    final double w = rect.width;
    final double h = rect.height;
    final double t = progress * 2 * math.pi;

    // Harmonic wave parameters (frequency, amplitude, phase, color, opacity)
    final waves = [
      (freq: 2.2, amp: h * 0.22 * energyIntensity, speed: 1.0, color: primaryEnergyColor, alpha: 0.35, yOffset: h * 0.45),
      (freq: 3.5, amp: h * 0.16 * energyIntensity, speed: -1.3, color: secondaryEnergyColor, alpha: 0.28, yOffset: h * 0.60),
      (freq: 1.6, amp: h * 0.28 * energyIntensity, speed: 0.7, color: SocialThemeTokens.aetherCyanLight, alpha: 0.42, yOffset: h * 0.35),
    ];

    for (final wave in waves) {
      final Path path = Path();
      path.moveTo(0, h);

      final int steps = (w / 8).clamp(30, 80).toInt();
      for (int i = 0; i <= steps; i++) {
        final double x = (i / steps) * w;
        final double normX = x / w;

        // Dual sinusoidal harmonic interference
        final double y = wave.yOffset +
            wave.amp * math.sin(normX * wave.freq * 2 * math.pi + t * wave.speed) +
            (wave.amp * 0.4) * math.cos(normX * 4.8 * math.pi - t * 0.8);

        if (i == 0) {
          path.lineTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      path.lineTo(w, h);
      path.close();

      final Paint wavePaint = Paint()
        ..blendMode = BlendMode.screen
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            wave.color.withValues(alpha: wave.alpha),
            wave.color.withValues(alpha: wave.alpha * 0.3),
            Colors.transparent,
          ],
        ).createShader(rect);

      canvas.drawPath(path, wavePaint);
    }
  }

  void _paintCelestialMotes(Canvas canvas, Rect rect) {
    final double w = rect.width;
    final double h = rect.height;
    final Paint motePaint = Paint()..blendMode = BlendMode.plus;

    const int moteCount = 14;
    for (int i = 0; i < moteCount; i++) {
      // Deterministic pseudo-random seed per mote
      final double seed = (i * 73.13) % 1.0;
      final double speed = 0.5 + ((i * 37.1) % 0.8);
      final double localT = (progress * speed + seed) % 1.0;

      final double x = (seed * w + (math.sin(localT * 2 * math.pi + i) * 24.0)) % w;
      final double y = h * (1.0 - localT);
      final double radius = 1.2 + (((i % 4) + 1) * 0.6);
      final double alpha = math.sin(localT * math.pi).clamp(0.0, 1.0) * 0.75;

      motePaint.color = (i % 2 == 0 ? primaryEnergyColor : SocialThemeTokens.celestialGoldLight)
          .withValues(alpha: alpha);

      canvas.drawCircle(Offset(x, y), radius, motePaint);

      // Subtle star core glow for larger motes
      if (radius > 2.0) {
        motePaint.color = Colors.white.withValues(alpha: alpha * 0.8);
        canvas.drawCircle(Offset(x, y), radius * 0.45, motePaint);
      }
    }
  }

  void _paintIridescentSheen(Canvas canvas, Rect rect) {
    final double w = rect.width;
    final double h = rect.height;

    // Sweeping beam across banner width with 25-degree tilt
    final double totalSpan = w + h * 1.5;
    final double beamX = (progress * totalSpan) - (h * 0.5);
    final double beamWidth = w * 0.35;

    final Paint sheenPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          SocialThemeTokens.aetherCyan.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.22),
          SocialThemeTokens.celestialGold.withValues(alpha: 0.15),
          SocialThemeTokens.daevaPrismViolet.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.70, 0.88, 1.0],
      ).createShader(
        Rect.fromLTWH(beamX - beamWidth * 0.5, 0, beamWidth, h),
      );

    canvas.drawRect(
      Rect.fromLTWH(beamX - beamWidth * 0.5, 0, beamWidth, h),
      sheenPaint,
    );
  }

  void _paintVignette(Canvas canvas, Rect rect) {
    final Paint vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: const [
          Colors.transparent,
          Color(0x33050811),
          Color(0x88050811),
        ],
        stops: const [0.4, 0.8, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignettePaint);
  }

  void _paintGoldBorderAndShimmer(Canvas canvas, Path borderPath, Rect rect) {
    // 1. Subtle dark drop glow
    final Paint shadowPaint = Paint()
      ..color = SocialThemeTokens.celestialGold.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawPath(borderPath, shadowPaint);

    // 2. Base metallic gold frame
    final Paint goldFramePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          SocialThemeTokens.celestialGoldLight,
          goldShimmerColor,
          SocialThemeTokens.celestialGoldDark,
          goldShimmerColor,
          SocialThemeTokens.celestialGoldLight,
        ],
        stops: const [0.0, 0.28, 0.55, 0.80, 1.0],
      ).createShader(rect);
    canvas.drawPath(borderPath, goldFramePaint);

    // 3. Traveling specular shimmer glint
    if (showBorderShimmer) {
      final double t = (progress * 1.5) % 1.0;
      final double glintWidth = rect.width * 0.28;
      final double glintX = (t * (rect.width + glintWidth)) - glintWidth;

      final Paint glintPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..blendMode = BlendMode.screen
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.9),
            SocialThemeTokens.celestialGoldLight.withValues(alpha: 0.85),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 0.65, 1.0],
        ).createShader(
          Rect.fromLTWH(glintX, 0, glintWidth, rect.height),
        );
      canvas.drawPath(borderPath, glintPaint);
    }
  }

  void _paintCornerFiligree(Canvas canvas, Rect rect) {
    final Paint filigreePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = SocialThemeTokens.celestialGoldLight;

    final Paint dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = SocialThemeTokens.celestialGold;

    const double cornerOffset = 6.0;
    const double armLength = 14.0;

    // Top-Left
    final Path tl = Path()
      ..moveTo(rect.left + cornerOffset, rect.top + cornerOffset + armLength)
      ..lineTo(rect.left + cornerOffset, rect.top + cornerOffset)
      ..lineTo(rect.left + cornerOffset + armLength, rect.top + cornerOffset);
    canvas.drawPath(tl, filigreePaint);
    canvas.drawCircle(Offset(rect.left + cornerOffset + 2, rect.top + cornerOffset + 2), 1.8, dotPaint);

    // Top-Right
    final Path tr = Path()
      ..moveTo(rect.right - cornerOffset - armLength, rect.top + cornerOffset)
      ..lineTo(rect.right - cornerOffset, rect.top + cornerOffset)
      ..lineTo(rect.right - cornerOffset, rect.top + cornerOffset + armLength);
    canvas.drawPath(tr, filigreePaint);
    canvas.drawCircle(Offset(rect.right - cornerOffset - 2, rect.top + cornerOffset + 2), 1.8, dotPaint);

    // Bottom-Left
    final Path bl = Path()
      ..moveTo(rect.left + cornerOffset, rect.bottom - cornerOffset - armLength)
      ..lineTo(rect.left + cornerOffset, rect.bottom - cornerOffset)
      ..lineTo(rect.left + cornerOffset + armLength, rect.bottom - cornerOffset);
    canvas.drawPath(bl, filigreePaint);

    // Bottom-Right
    final Path br = Path()
      ..moveTo(rect.right - cornerOffset - armLength, rect.bottom - cornerOffset)
      ..lineTo(rect.right - cornerOffset, rect.bottom - cornerOffset)
      ..lineTo(rect.right - cornerOffset, rect.bottom - cornerOffset - armLength);
    canvas.drawPath(br, filigreePaint);
  }

  @override
  bool shouldRepaint(covariant CelestialBannerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.shader != shader ||
        oldDelegate.time != time ||
        oldDelegate.primaryEnergyColor != primaryEnergyColor ||
        oldDelegate.secondaryEnergyColor != secondaryEnergyColor ||
        oldDelegate.goldShimmerColor != goldShimmerColor ||
        oldDelegate.energyIntensity != energyIntensity ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.showBorderShimmer != showBorderShimmer ||
        oldDelegate.showCornerFiligree != showCornerFiligree ||
        oldDelegate.showFloatingMotes != showFloatingMotes ||
        oldDelegate.isSwallowtail != isSwallowtail;
  }
}
