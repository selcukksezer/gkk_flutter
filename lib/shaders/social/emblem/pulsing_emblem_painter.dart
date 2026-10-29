import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/social_theme_tokens.dart';

/// Total count of float uniform slots declared in `emblem_aura.frag`:
/// - 0..1:   uResolution (vec2)
/// - 2:      uTime (float)
/// - 3:      uProgress (float)
/// - 4..7:   uAuraColor (vec4, linear RGBA)
/// - 8..11:  uCoreColor (vec4, linear RGBA)
/// - 12:     uPulseSpeed (float)
/// - 13:     uAuraRadius (float)
const int kEmblemAuraUniformFloatCount = 14;

/// Faction and heraldry archetypes for social emblems.
enum EmblemFaction {
  elyos,
  asmodian,
  balaur,
  daeva,
  guildShield;

  String get displayName => switch (this) {
        EmblemFaction.elyos => 'Elyos Celestial',
        EmblemFaction.asmodian => 'Asmodian Shadow',
        EmblemFaction.balaur => 'Balaur Ascendant',
        EmblemFaction.daeva => 'Daeva Sovereign',
        EmblemFaction.guildShield => 'Guild Legion Shield',
      };

  Color get primaryAura => switch (this) {
        EmblemFaction.elyos => SocialThemeTokens.elyosGold,
        EmblemFaction.asmodian => SocialThemeTokens.asmodianViolet,
        EmblemFaction.balaur => SocialThemeTokens.balaurFlame,
        EmblemFaction.daeva => SocialThemeTokens.aetherCyan,
        EmblemFaction.guildShield => SocialThemeTokens.celestialGold,
      };

  Color get coreColor => switch (this) {
        EmblemFaction.elyos => SocialThemeTokens.elyosRadiance,
        EmblemFaction.asmodian => SocialThemeTokens.asmodianCrimson,
        EmblemFaction.balaur => SocialThemeTokens.balaurRuby,
        EmblemFaction.daeva => SocialThemeTokens.daevaPrismWhite,
        EmblemFaction.guildShield => SocialThemeTokens.celestialGoldLight,
      };
}

/// CustomPainter that renders a 2027 Aion 2 Mobile pulsing emblem with multi-layered
/// harmonic radial aura glow, rotating radiant rays, orbiting particle radiance,
/// and vector faction/guild crest heraldry.
///
/// Supports hardware-accelerated Impeller rendering via [shader] (`emblem_aura.frag`)
/// as well as pure Canvas 2D fallback rendering.
class PulsingEmblemPainter extends CustomPainter {
  /// Number of uniform floats passed to `emblem_aura.frag`.
  static const int kEmblemAuraUniformFloatCount = 14;

  const PulsingEmblemPainter({
    required this.progress,
    this.faction = EmblemFaction.elyos,
    this.customPrimaryColor,
    this.customCoreColor,
    this.auraIntensity = 1.0,
    this.showOrbitingParticles = true,
    this.showRadiantRays = true,
    this.showInnerGlow = true,
    this.shader,
    this.time,
    this.pulseSpeed = 1.0,
    this.auraRadius,
  });

  /// Normalized continuous animation progress [0.0 .. 1.0].
  final double progress;

  /// Faction crest style.
  final EmblemFaction faction;

  /// Optional override for aura glow color.
  final Color? customPrimaryColor;

  /// Optional override for core emblem color.
  final Color? customCoreColor;

  /// Overall glow amplitude factor [0.0 .. 2.0].
  final double auraIntensity;

  /// Whether orbiting celestial sparks and star motes are drawn.
  final bool showOrbitingParticles;

  /// Whether rotating celestial rays are painted.
  final bool showRadiantRays;

  /// Whether inner crest bevel glow is enabled.
  final bool showInnerGlow;

  /// Optional GPU runtime fragment shader (`emblem_aura.frag`).
  final ui.FragmentShader? shader;

  /// Optional absolute animation time in seconds. Defaults to `progress * 2 * pi`.
  final double? time;

  /// Harmonic aura breathing pulse speed multiplier. Defaults to 1.0.
  final double pulseSpeed;

  /// Normalized aura outer glow radius [0.0 .. 1.0]. Defaults to 0.42.
  final double? auraRadius;

  Color get _auraColor => customPrimaryColor ?? faction.primaryAura;
  Color get _coreColor => customCoreColor ?? faction.coreColor;

  /// Converts an sRGB color component [0.0 .. 1.0] to linear RGB space.
  static double sRgbToLinear(double c) {
    final double normalized = c > 1.0 ? c / 255.0 : c;
    return (normalized <= 0.04045)
        ? (normalized / 12.92)
        : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
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

  /// Packs all 14 uniforms into a contiguous [Float32List] matching GLSL declaration order:
  /// - 0..1:   uResolution (vec2)
  /// - 2:      uTime (float)
  /// - 3:      uProgress (float)
  /// - 4..7:   uAuraColor (vec4 in linear RGBA)
  /// - 8..11:  uCoreColor (vec4 in linear RGBA)
  /// - 12:     uPulseSpeed (float)
  /// - 13:     uAuraRadius (float)
  static Float32List packUniforms({
    required Size size,
    required double progress,
    double? time,
    Color auraColor = SocialThemeTokens.elyosGold,
    Color coreColor = SocialThemeTokens.elyosRadiance,
    double auraIntensity = 1.0,
    double pulseSpeed = 1.0,
    double auraRadius = 0.42,
  }) {
    final Float32List buffer = Float32List(kEmblemAuraUniformFloatCount);
    final double activeTime = time ?? (progress * 2.0 * math.pi);

    // 0..1: uResolution (vec2)
    buffer[0] = size.width;
    buffer[1] = size.height;

    // 2: uTime (float)
    buffer[2] = activeTime;

    // 3: uProgress (float)
    buffer[3] = progress;

    // 4..7: uAuraColor (vec4 in linear RGBA)
    final (double ar, double ag, double ab, double aa) = colorToLinearRgba(auraColor);
    buffer[4] = ar;
    buffer[5] = ag;
    buffer[6] = ab;
    buffer[7] = aa * auraIntensity.clamp(0.0, 2.0);

    // 8..11: uCoreColor (vec4 in linear RGBA)
    final (double cr, double cg, double cb, double ca) = colorToLinearRgba(coreColor);
    buffer[8] = cr;
    buffer[9] = cg;
    buffer[10] = cb;
    buffer[11] = ca * auraIntensity.clamp(0.0, 2.0);

    // 12: uPulseSpeed (float)
    buffer[12] = pulseSpeed;

    // 13: uAuraRadius (float)
    buffer[13] = auraRadius;

    return buffer;
  }

  /// Binds all 14 uniforms to a Flutter [ui.FragmentShader] matching GLSL declaration order:
  /// - 0..1:   uResolution (vec2)
  /// - 2:      uTime (float)
  /// - 3:      uProgress (float)
  /// - 4..7:   uAuraColor (vec4, linear RGBA)
  /// - 8..11:  uCoreColor (vec4, linear RGBA)
  /// - 12:     uPulseSpeed (float)
  /// - 13:     uAuraRadius (float)
  void applyUniforms(ui.FragmentShader targetShader, Size size) {
    final double activeTime = time ?? (progress * 2.0 * math.pi);
    final double activeRadius = auraRadius ?? 0.42;

    // 0..1: uniform vec2 uResolution;
    targetShader.setFloat(0, size.width);
    targetShader.setFloat(1, size.height);

    // 2: uniform float uTime;
    targetShader.setFloat(2, activeTime);

    // 3: uniform float uProgress;
    targetShader.setFloat(3, progress);

    // 4..7: uniform vec4 uAuraColor; (linear RGBA)
    final (double ar, double ag, double ab, double aa) = colorToLinearRgba(_auraColor);
    targetShader.setFloat(4, ar);
    targetShader.setFloat(5, ag);
    targetShader.setFloat(6, ab);
    targetShader.setFloat(7, aa * auraIntensity.clamp(0.0, 2.0));

    // 8..11: uniform vec4 uCoreColor; (linear RGBA)
    final (double cr, double cg, double cb, double ca) = colorToLinearRgba(_coreColor);
    targetShader.setFloat(8, cr);
    targetShader.setFloat(9, cg);
    targetShader.setFloat(10, cb);
    targetShader.setFloat(11, ca * auraIntensity.clamp(0.0, 2.0));

    // 12: uniform float uPulseSpeed;
    targetShader.setFloat(12, pulseSpeed);

    // 13: uniform float uAuraRadius;
    targetShader.setFloat(13, activeRadius);
  }

  /// Binds all 14 uniforms to a generic uniform target supporting `setFloat(int, double)`.
  void applyToTarget(dynamic target, Size size) {
    final double activeTime = time ?? (progress * 2.0 * math.pi);
    final double activeRadius = auraRadius ?? 0.42;

    target.setFloat(0, size.width);
    target.setFloat(1, size.height);
    target.setFloat(2, activeTime);
    target.setFloat(3, progress);

    final (double ar, double ag, double ab, double aa) = colorToLinearRgba(_auraColor);
    target.setFloat(4, ar);
    target.setFloat(5, ag);
    target.setFloat(6, ab);
    target.setFloat(7, aa * auraIntensity.clamp(0.0, 2.0));

    final (double cr, double cg, double cb, double ca) = colorToLinearRgba(_coreColor);
    target.setFloat(8, cr);
    target.setFloat(9, cg);
    target.setFloat(10, cb);
    target.setFloat(11, ca * auraIntensity.clamp(0.0, 2.0));

    target.setFloat(12, pulseSpeed);
    target.setFloat(13, activeRadius);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Offset center = Offset(size.width * 0.5, size.height * 0.5);
    final double radius = math.min(size.width, size.height) * 0.42;

    // 1..3. GPU Aura Shader or Canvas 2D Fallback
    if (shader != null) {
      applyUniforms(shader!, size);
      final Paint shaderPaint = Paint()..shader = shader;
      canvas.drawRect(Offset.zero & size, shaderPaint);
    } else {
      // 1. Pulsing Harmonic Outer Aura Glow
      _paintAuraGlow(canvas, center, radius);

      // 2. Rotating Radiant Rays
      if (showRadiantRays) {
        _paintRadiantRays(canvas, center, radius);
      }

      // 3. Orbiting Particle Radiance
      if (showOrbitingParticles) {
        _paintOrbitingParticles(canvas, center, radius);
      }
    }

    // 4. Crest Heraldry Outer Frame & Bevel
    _paintCrestFrame(canvas, center, radius);

    // 5. Authentic Faction Crest Vector Motif
    _paintCrestMotif(canvas, center, radius * 0.68);

    // 6. Central Keystone & Diamond Flare
    _paintKeystoneHighlight(canvas, center, radius);
  }

  void _paintAuraGlow(Canvas canvas, Offset center, double radius) {
    final double pulse = 0.5 + 0.5 * math.sin(progress * 2 * math.pi);
    final double breathingRadius = radius * (1.15 + 0.18 * pulse * auraIntensity);

    // Outer soft atmospheric glow
    final Paint outerGlowPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        colors: [
          _auraColor.withValues(alpha: 0.38 * auraIntensity),
          _auraColor.withValues(alpha: 0.12 * auraIntensity),
          Colors.transparent,
        ],
        stops: const [0.2, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: breathingRadius));
    canvas.drawCircle(center, breathingRadius, outerGlowPaint);

    // Inner intense core glow
    final Paint coreGlowPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        colors: [
          _coreColor.withValues(alpha: 0.65 * auraIntensity),
          _auraColor.withValues(alpha: 0.35 * auraIntensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.75));
    canvas.drawCircle(center, radius * 0.75, coreGlowPaint);
  }

  void _paintRadiantRays(Canvas canvas, Offset center, double radius) {
    final Paint rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..blendMode = BlendMode.screen;

    const int rayCount = 12;
    final double angleStep = (2 * math.pi) / rayCount;
    final double rotation = progress * 2 * math.pi * 0.25;

    for (int i = 0; i < rayCount; i++) {
      final double angle = i * angleStep + rotation;
      final double rayLen = radius * (1.05 + 0.25 * ((i % 2 == 0) ? 1.0 : 0.45));
      final Offset start = center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.75);
      final Offset end = center + Offset(math.cos(angle), math.sin(angle)) * rayLen;

      final double alpha = (0.25 + 0.25 * math.sin(progress * 4 * math.pi + i)) * auraIntensity;
      rayPaint.color = _coreColor.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawLine(start, end, rayPaint);
    }
  }

  void _paintOrbitingParticles(Canvas canvas, Offset center, double radius) {
    final Paint pPaint = Paint()..blendMode = BlendMode.plus;

    const int particleCount = 12;
    for (int i = 0; i < particleCount; i++) {
      final double seed = (i * 47.19) % 1.0;
      final double speed = 0.6 + ((i * 19.3) % 0.8);
      final double dir = (i % 2 == 0) ? 1.0 : -1.0;
      final double orbitRadius = radius * (0.85 + 0.35 * seed);
      final double angle = (progress * 2 * math.pi * speed * dir) + (i * (2 * math.pi / particleCount));

      final Offset pPos = center + Offset(math.cos(angle), math.sin(angle)) * orbitRadius;
      final double sparkle = 0.5 + 0.5 * math.sin(progress * 6 * math.pi + i);
      final double pSize = 1.2 + 1.2 * sparkle;
      final double alpha = (0.4 + 0.6 * sparkle) * auraIntensity;

      pPaint.color = _coreColor.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(pPos, pSize, pPaint);

      // Star sparkle cross
      if (pSize > 1.8) {
        final Paint crossPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white.withValues(alpha: alpha * 0.8);
        canvas.drawLine(pPos - const Offset(2.5, 0), pPos + const Offset(2.5, 0), crossPaint);
        canvas.drawLine(pPos - const Offset(0, 2.5), pPos + const Offset(0, 2.5), crossPaint);
      }
    }
  }

  void _paintCrestFrame(Canvas canvas, Offset center, double radius) {
    // Abyssal back disc
    final Paint backDiscPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          SocialThemeTokens.abyssCardHighlight,
          SocialThemeTokens.abyssCard,
          SocialThemeTokens.abyssVoid,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, backDiscPaint);

    // Ornate gold filigree concentric rings
    final Paint outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = SweepGradient(
        colors: const [
          SocialThemeTokens.celestialGoldLight,
          SocialThemeTokens.celestialGoldDark,
          SocialThemeTokens.celestialGold,
          SocialThemeTokens.celestialGoldLight,
        ],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, outerRingPaint);

    final Paint innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = SocialThemeTokens.celestialGold.withValues(alpha: 0.75);
    canvas.drawCircle(center, radius * 0.85, innerRingPaint);

    // 4 Cardinal studs
    for (int i = 0; i < 4; i++) {
      final double a = i * (math.pi / 2);
      final Offset studPos = center + Offset(math.cos(a), math.sin(a)) * radius;
      final Paint studPaint = Paint()..color = SocialThemeTokens.celestialGoldLight;
      canvas.drawCircle(studPos, 2.8, studPaint);
      studPaint.color = Colors.white;
      canvas.drawCircle(studPos, 1.2, studPaint);
    }
  }

  void _paintCrestMotif(Canvas canvas, Offset center, double r) {
    final Paint motifPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _coreColor,
          _auraColor,
          _auraColor.withValues(alpha: 0.8),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r));

    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.85);

    switch (faction) {
      case EmblemFaction.elyos:
        _paintElyosWingedSun(canvas, center, r, motifPaint, strokePaint);
      case EmblemFaction.asmodian:
        _paintAsmodianCrescent(canvas, center, r, motifPaint, strokePaint);
      case EmblemFaction.balaur:
        _paintBalaurEye(canvas, center, r, motifPaint, strokePaint);
      case EmblemFaction.daeva:
        _paintDaevaStar(canvas, center, r, motifPaint, strokePaint);
      case EmblemFaction.guildShield:
        _paintGuildShield(canvas, center, r, motifPaint, strokePaint);
    }
  }

  void _paintElyosWingedSun(Canvas canvas, Offset center, double r, Paint fill, Paint stroke) {
    final Path path = Path();
    // Central solar circle
    path.addOval(Rect.fromCircle(center: center, radius: r * 0.28));

    // Left archon wing feather
    path.moveTo(center.dx - r * 0.2, center.dy);
    path.cubicTo(
      center.dx - r * 0.6,
      center.dy - r * 0.8,
      center.dx - r * 0.9,
      center.dy - r * 0.4,
      center.dx - r * 0.8,
      center.dy + r * 0.2,
    );
    path.quadraticBezierTo(center.dx - r * 0.4, center.dy + r * 0.1, center.dx - r * 0.2, center.dy);

    // Right archon wing feather
    path.moveTo(center.dx + r * 0.2, center.dy);
    path.cubicTo(
      center.dx + r * 0.6,
      center.dy - r * 0.8,
      center.dx + r * 0.9,
      center.dy - r * 0.4,
      center.dx + r * 0.8,
      center.dy + r * 0.2,
    );
    path.quadraticBezierTo(center.dx + r * 0.4, center.dy + r * 0.1, center.dx + r * 0.2, center.dy);

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _paintAsmodianCrescent(Canvas canvas, Offset center, double r, Paint fill, Paint stroke) {
    final Path path = Path();
    // Curved demon horn / crescent moon
    path.moveTo(center.dx, center.dy - r * 0.85);
    path.cubicTo(
      center.dx + r * 0.75,
      center.dy - r * 0.6,
      center.dx + r * 0.8,
      center.dy + r * 0.6,
      center.dx,
      center.dy + r * 0.85,
    );
    path.cubicTo(
      center.dx + r * 0.35,
      center.dy + r * 0.45,
      center.dx + r * 0.35,
      center.dy - r * 0.45,
      center.dx,
      center.dy - r * 0.85,
    );

    // Symmetrical left horn
    path.moveTo(center.dx, center.dy - r * 0.85);
    path.cubicTo(
      center.dx - r * 0.75,
      center.dy - r * 0.6,
      center.dx - r * 0.8,
      center.dy + r * 0.6,
      center.dx,
      center.dy + r * 0.85,
    );
    path.cubicTo(
      center.dx - r * 0.35,
      center.dy + r * 0.45,
      center.dx - r * 0.35,
      center.dy - r * 0.45,
      center.dx,
      center.dy - r * 0.85,
    );

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _paintBalaurEye(Canvas canvas, Offset center, double r, Paint fill, Paint stroke) {
    final Path path = Path();
    // Draconic eye contour
    path.moveTo(center.dx - r * 0.85, center.dy);
    path.cubicTo(center.dx - r * 0.3, center.dy - r * 0.65, center.dx + r * 0.3, center.dy - r * 0.65, center.dx + r * 0.85, center.dy);
    path.cubicTo(center.dx + r * 0.3, center.dy + r * 0.65, center.dx - r * 0.3, center.dy + r * 0.65, center.dx - r * 0.85, center.dy);

    // Vertical slit pupil
    path.addOval(Rect.fromCenter(center: center, width: r * 0.22, height: r * 0.8));

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _paintDaevaStar(Canvas canvas, Offset center, double r, Paint fill, Paint stroke) {
    final Path path = Path();
    // 8-pointed star of Aion
    const int points = 8;
    for (int i = 0; i < points * 2; i++) {
      final double a = (i * math.pi) / points - (math.pi / 2);
      final double radius = (i % 2 == 0) ? r * 0.85 : r * 0.35;
      final double x = center.dx + math.cos(a) * radius;
      final double y = center.dy + math.sin(a) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _paintGuildShield(Canvas canvas, Offset center, double r, Paint fill, Paint stroke) {
    final Path path = Path();
    // Medieval heraldic escutcheon
    path.moveTo(center.dx - r * 0.65, center.dy - r * 0.7);
    path.lineTo(center.dx + r * 0.65, center.dy - r * 0.7);
    path.lineTo(center.dx + r * 0.65, center.dy + r * 0.1);
    path.cubicTo(
      center.dx + r * 0.65,
      center.dy + r * 0.6,
      center.dx,
      center.dy + r * 0.85,
      center.dx,
      center.dy + r * 0.85,
    );
    path.cubicTo(
      center.dx,
      center.dy + r * 0.85,
      center.dx - r * 0.65,
      center.dy + r * 0.6,
      center.dx - r * 0.65,
      center.dy + r * 0.1,
    );
    path.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    // Crossed ceremonial halberds / swords
    final Paint swordPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = SocialThemeTokens.celestialGoldLight;
    canvas.drawLine(center - Offset(r * 0.35, r * 0.35), center + Offset(r * 0.35, r * 0.35), swordPaint);
    canvas.drawLine(center - Offset(-r * 0.35, r * 0.35), center + Offset(-r * 0.35, -r * 0.35), swordPaint);
  }

  void _paintKeystoneHighlight(Canvas canvas, Offset center, double radius) {
    final Paint flarePaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.9),
          _coreColor.withValues(alpha: 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.25));
    canvas.drawCircle(center, radius * 0.25, flarePaint);
  }

  @override
  bool shouldRepaint(covariant PulsingEmblemPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.faction != faction ||
        oldDelegate.customPrimaryColor != customPrimaryColor ||
        oldDelegate.customCoreColor != customCoreColor ||
        oldDelegate.auraIntensity != auraIntensity ||
        oldDelegate.showOrbitingParticles != showOrbitingParticles ||
        oldDelegate.showRadiantRays != showRadiantRays ||
        oldDelegate.showInnerGlow != showInnerGlow ||
        oldDelegate.shader != shader ||
        oldDelegate.time != time ||
        oldDelegate.pulseSpeed != pulseSpeed ||
        oldDelegate.auraRadius != auraRadius;
  }
}
