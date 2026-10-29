import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/social_theme_tokens.dart';

/// Gemstone color themes for Abyss Crystal.
enum CrystalColorVariant {
  abyssCyan,
  celestialDiamond,
  dragonRuby,
  shadowAmethyst,
  emerald;

  Color get primary => switch (this) {
        CrystalColorVariant.abyssCyan => SocialThemeTokens.aetherCyan,
        CrystalColorVariant.celestialDiamond => SocialThemeTokens.daevaPrismWhite,
        CrystalColorVariant.dragonRuby => SocialThemeTokens.balaurRuby,
        CrystalColorVariant.shadowAmethyst => SocialThemeTokens.asmodianViolet,
        CrystalColorVariant.emerald => const Color(0xFF00E676),
      };

  Color get deep => switch (this) {
        CrystalColorVariant.abyssCyan => const Color(0xFF005080),
        CrystalColorVariant.celestialDiamond => const Color(0xFF607D8B),
        CrystalColorVariant.dragonRuby => const Color(0xFF5A0000),
        CrystalColorVariant.shadowAmethyst => const Color(0xFF311B92),
        CrystalColorVariant.emerald => const Color(0xFF004D20),
      };

  Color get highlight => switch (this) {
        CrystalColorVariant.abyssCyan => SocialThemeTokens.aetherCyanLight,
        CrystalColorVariant.celestialDiamond => Colors.white,
        CrystalColorVariant.dragonRuby => const Color(0xFFFF8A80),
        CrystalColorVariant.shadowAmethyst => const Color(0xFFE1BEE7),
        CrystalColorVariant.emerald => const Color(0xFFB9F6CA),
      };

  /// Index of Refraction (IOR) based on real mineral physics.
  double get refractiveIndex => switch (this) {
        CrystalColorVariant.abyssCyan => 1.76, // Corundum Sapphire / Aether Crystal
        CrystalColorVariant.celestialDiamond => 2.42, // Brilliant Diamond
        CrystalColorVariant.dragonRuby => 1.77, // Corundum Ruby
        CrystalColorVariant.shadowAmethyst => 1.54, // Quartz Amethyst
        CrystalColorVariant.emerald => 1.58, // Beryl Emerald
      };

  /// Chromatic dispersion parameter (differential IOR across spectral wavelengths).
  double get dispersion => switch (this) {
        CrystalColorVariant.abyssCyan => 0.018,
        CrystalColorVariant.celestialDiamond => 0.044, // High fire dispersion of diamond
        CrystalColorVariant.dragonRuby => 0.018,
        CrystalColorVariant.shadowAmethyst => 0.013,
        CrystalColorVariant.emerald => 0.014,
      };

  /// Internal caustic concentration factor.
  double get causticIntensity => switch (this) {
        CrystalColorVariant.abyssCyan => 0.85,
        CrystalColorVariant.celestialDiamond => 1.0,
        CrystalColorVariant.dragonRuby => 0.75,
        CrystalColorVariant.shadowAmethyst => 0.65,
        CrystalColorVariant.emerald => 0.70,
      };
}

/// Precise uniform indices and pack helper for Abyss Crystal runtime effect shader.
///
/// Declared GLSL layout:
/// - uniform vec2  uResolution;         (float indices 0, 1)
/// - uniform float uTime;               (float index 2)
/// - uniform float uProgress;           (float index 3)
/// - uniform float uRefractiveIndex;    (float index 4)  [1.0 .. 2.8]
/// - uniform float uDispersion;         (float index 5)  [0.0 .. 0.1]
/// - uniform float uGlowIntensity;      (float index 6)  [0.0 .. 2.0]
/// - uniform float uShimmerSpeed;       (float index 7)  [0.1 .. 3.0]
/// - uniform float uCausticIntensity;   (float index 8)  [0.0 .. 2.0]
/// - uniform vec4  uPrimaryColor;       (float indices 9, 10, 11, 12)
/// - uniform vec4  uDeepColor;          (float indices 13, 14, 15, 16)
/// - uniform vec4  uHighlightColor;     (float indices 17, 18, 19, 20)
/// Total float count: 21 floats
abstract final class AbyssCrystalUniforms {
  static const int indexResolution = 0;
  static const int indexTime = 2;
  static const int indexProgress = 3;
  static const int indexRefractiveIndex = 4;
  static const int indexDispersion = 5;
  static const int indexGlowIntensity = 6;
  static const int indexShimmerSpeed = 7;
  static const int indexCausticIntensity = 8;
  static const int indexPrimaryColor = 9;
  static const int indexDeepColor = 13;
  static const int indexHighlightColor = 17;
  static const int floatCount = 21;

  /// Converts standard sRGB channel to linear RGB for photometrically accurate GLSL shading.
  static double sRgbToLinear(double c) {
    return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Converts a Flutter [Color] to a 4-float linear RGBA list.
  static List<double> colorToLinearFloats(Color color) {
    return <double>[
      sRgbToLinear(color.r),
      sRgbToLinear(color.g),
      sRgbToLinear(color.b),
      color.a,
    ];
  }

  /// Packs uniform floats in the exact order expected by the crystal shader.
  static List<double> buildUniforms({
    required Size size,
    required double time,
    required double progress,
    required double refractiveIndex,
    required double dispersion,
    required double glowIntensity,
    required double shimmerSpeed,
    required double causticIntensity,
    required Color primaryColor,
    required Color deepColor,
    required Color highlightColor,
    bool useLinearColors = true,
  }) {
    final List<double> primary = useLinearColors
        ? colorToLinearFloats(primaryColor)
        : <double>[primaryColor.r, primaryColor.g, primaryColor.b, primaryColor.a];
    final List<double> deep = useLinearColors
        ? colorToLinearFloats(deepColor)
        : <double>[deepColor.r, deepColor.g, deepColor.b, deepColor.a];
    final List<double> highlight = useLinearColors
        ? colorToLinearFloats(highlightColor)
        : <double>[highlightColor.r, highlightColor.g, highlightColor.b, highlightColor.a];

    return <double>[
      size.width,          // 0: uResolution.x
      size.height,         // 1: uResolution.y
      time,                // 2: uTime
      progress,            // 3: uProgress
      refractiveIndex,     // 4: uRefractiveIndex
      dispersion,          // 5: uDispersion
      glowIntensity,       // 6: uGlowIntensity
      shimmerSpeed,        // 7: uShimmerSpeed
      causticIntensity,    // 8: uCausticIntensity
      primary[0],          // 9: uPrimaryColor.r
      primary[1],          // 10: uPrimaryColor.g
      primary[2],          // 11: uPrimaryColor.b
      primary[3],          // 12: uPrimaryColor.a
      deep[0],             // 13: uDeepColor.r
      deep[1],             // 14: uDeepColor.g
      deep[2],             // 15: uDeepColor.b
      deep[3],             // 16: uDeepColor.a
      highlight[0],        // 17: uHighlightColor.r
      highlight[1],        // 18: uHighlightColor.g
      highlight[2],        // 19: uHighlightColor.b
      highlight[3],        // 20: uHighlightColor.a
    ];
  }

  /// Applies all uniforms to a [ui.FragmentShader] instance.
  static void apply(
    ui.FragmentShader shader, {
    required Size size,
    required double time,
    required double progress,
    required double refractiveIndex,
    required double dispersion,
    required double glowIntensity,
    required double shimmerSpeed,
    required double causticIntensity,
    required Color primaryColor,
    required Color deepColor,
    required Color highlightColor,
    bool useLinearColors = true,
  }) {
    final List<double> uniforms = buildUniforms(
      size: size,
      time: time,
      progress: progress,
      refractiveIndex: refractiveIndex,
      dispersion: dispersion,
      glowIntensity: glowIntensity,
      shimmerSpeed: shimmerSpeed,
      causticIntensity: causticIntensity,
      primaryColor: primaryColor,
      deepColor: deepColor,
      highlightColor: highlightColor,
      useLinearColors: useLinearColors,
    );
    for (int i = 0; i < uniforms.length; ++i) {
      shader.setFloat(i, uniforms[i]);
    }
  }
}

/// Authentic 2027 Aion 2 Mobile Abyss Crystal / Diamond Gem vector painter.
///
/// Features a multi-faceted 3D brilliant-cut gemstone with refractive internal caustics,
/// a rotating vertex star lens flare, and orbiting miniature crystal shards.
class AbyssCrystalPainter extends CustomPainter {
  const AbyssCrystalPainter({
    required this.progress,
    this.variant = CrystalColorVariant.abyssCyan,
    this.customColor,
    this.showOrbitingShards = true,
    this.showStarFlare = true,
    this.glowIntensity = 1.0,
    this.refractiveIndex,
    this.dispersion,
    this.shimmerSpeed = 1.0,
    this.causticIntensity,
    this.shader,
  });

  final double progress;
  final CrystalColorVariant variant;
  final Color? customColor;
  final bool showOrbitingShards;
  final bool showStarFlare;
  final double glowIntensity;
  final double? refractiveIndex;
  final double? dispersion;
  final double shimmerSpeed;
  final double? causticIntensity;
  final ui.FragmentShader? shader;

  Color get _primary => customColor ?? variant.primary;
  Color get _deep => variant.deep;
  Color get _highlight => variant.highlight;
  double get _ior => refractiveIndex ?? variant.refractiveIndex;
  double get _disp => dispersion ?? variant.dispersion;
  double get _caustics => causticIntensity ?? variant.causticIntensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // If a hardware runtime FragmentShader is attached, apply uniforms
    if (shader != null) {
      final double timeSeconds = progress * (2.0 * math.pi / shimmerSpeed);
      AbyssCrystalUniforms.apply(
        shader!,
        size: size,
        time: timeSeconds,
        progress: progress,
        refractiveIndex: _ior,
        dispersion: _disp,
        glowIntensity: glowIntensity,
        shimmerSpeed: shimmerSpeed,
        causticIntensity: _caustics,
        primaryColor: _primary,
        deepColor: _deep,
        highlightColor: _highlight,
      );
    }

    final Offset center = Offset(size.width * 0.5, size.height * 0.5);
    final double w = size.width * 0.56;
    final double h = size.height * 0.72;

    // 1. Core Radiance Aura
    _paintAura(canvas, center, w, h);

    // 2. Multi-Faceted Gemstone Body
    _paintFacetedGem(canvas, center, w, h);

    // 3. Orbiting Miniature Crystal Shards
    if (showOrbitingShards) {
      _paintOrbitingShards(canvas, center, w, h);
    }

    // 4. Rotating Apex Star Flare
    if (showStarFlare) {
      _paintStarFlare(canvas, center, w, h);
    }
  }

  void _paintAura(Canvas canvas, Offset center, double w, double h) {
    final double pulse = 0.5 + 0.5 * math.sin(progress * shimmerSpeed * 2 * math.pi);
    final Paint auraPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        colors: [
          _primary.withValues(alpha: 0.42 * pulse * glowIntensity),
          _deep.withValues(alpha: 0.18 * pulse * glowIntensity),
          Colors.transparent,
        ],
        stops: const [0.15, 0.65, 1.0],
      ).createShader(Rect.fromCenter(center: center, width: w * 2.2, height: h * 1.8));

    canvas.drawOval(
      Rect.fromCenter(center: center, width: w * 2.2, height: h * 1.8),
      auraPaint,
    );
  }

  void _paintFacetedGem(Canvas canvas, Offset center, double w, double h) {
    final double topY = center.dy - h * 0.45;
    final double girdleY = center.dy - h * 0.05;
    final double bottomY = center.dy + h * 0.48;

    final double tableW = w * 0.55;
    final double girdleW = w * 0.95;

    // Physical Fresnel reflection coefficient at normal incidence (F0)
    final double f0 = math.pow((1.0 - _ior) / (1.0 + _ior), 2.0).toDouble();
    // Dynamic optical shimmer timing
    final double shimmer = math.sin((progress * shimmerSpeed + 0.25) * 2 * math.pi) * 0.5 + 0.5;

    // Table facet vertices (flat top horizontal facet)
    final Offset t1 = Offset(center.dx - tableW * 0.5, topY);
    final Offset t2 = Offset(center.dx + tableW * 0.5, topY);

    // Girdle vertices (widest mid-line)
    final Offset gL = Offset(center.dx - girdleW * 0.5, girdleY);
    final Offset gML = Offset(center.dx - girdleW * 0.22, girdleY + 2);
    final Offset gMR = Offset(center.dx + girdleW * 0.22, girdleY + 2);
    final Offset gR = Offset(center.dx + girdleW * 0.5, girdleY);

    // Culet bottom vertex
    final Offset culet = Offset(center.dx, bottomY);

    // --- Lower Pavilion Facets (Tapering from girdle down to culet) ---
    // Lower Left Facet
    final Path pavL = Path()..moveTo(gL.dx, gL.dy)..lineTo(gML.dx, gML.dy)..lineTo(culet.dx, culet.dy)..close();
    _drawFacet(canvas, pavL, _deep, 0.85, fresnelF0: f0, shimmer: shimmer);

    // Lower Center-Left Facet (internal refractive caustics)
    final Path pavCL = Path()..moveTo(gML.dx, gML.dy)..lineTo(center.dx, girdleY + 6)..lineTo(culet.dx, culet.dy)..close();
    _drawFacet(canvas, pavCL, _primary, (0.95 * _caustics).clamp(0.0, 1.0), fresnelF0: f0, shimmer: shimmer);

    // Lower Center-Right Facet (refractive highlight with internal total reflection)
    final Path pavCR = Path()..moveTo(center.dx, girdleY + 6)..lineTo(gMR.dx, gMR.dy)..lineTo(culet.dx, culet.dy)..close();
    _drawFacet(canvas, pavCR, _highlight, (0.75 * _caustics).clamp(0.0, 1.0), hasReflection: true, fresnelF0: f0, shimmer: shimmer);

    // Lower Right Facet
    final Path pavR = Path()..moveTo(gMR.dx, gMR.dy)..lineTo(gR.dx, gR.dy)..lineTo(culet.dx, culet.dy)..close();
    _drawFacet(canvas, pavR, _deep, 0.90, fresnelF0: f0, shimmer: shimmer);

    // --- Upper Crown Facets (From table down to girdle) ---
    // Upper Left Kite
    final Path crownL = Path()..moveTo(t1.dx, t1.dy)..lineTo(gL.dx, gL.dy)..lineTo(gML.dx, gML.dy)..close();
    _drawFacet(canvas, crownL, _deep, 0.70, fresnelF0: f0, shimmer: shimmer);

    // Upper Center Facet
    final Path crownC = Path()..moveTo(t1.dx, t1.dy)..lineTo(t2.dx, t2.dy)..lineTo(gMR.dx, gMR.dy)..lineTo(gML.dx, gML.dy)..close();
    _drawFacet(canvas, crownC, _primary, 0.90, hasReflection: true, fresnelF0: f0, shimmer: shimmer);

    // Upper Right Kite
    final Path crownR = Path()..moveTo(t2.dx, t2.dy)..lineTo(gMR.dx, gMR.dy)..lineTo(gR.dx, gR.dy)..close();
    _drawFacet(canvas, crownR, _highlight, 0.82, fresnelF0: f0, shimmer: shimmer);

    // --- Flat Table Polygon ---
    final Path table = Path()
      ..moveTo(t1.dx + 4, topY - 3)
      ..lineTo(t2.dx - 4, topY - 3)
      ..lineTo(t2.dx, topY)
      ..lineTo(t1.dx, topY)
      ..close();
    _drawFacet(canvas, table, Colors.white, 0.92, hasReflection: true, fresnelF0: f0, shimmer: shimmer);

    // Facet Ridge Line Outlines
    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: (0.55 + 0.25 * f0).clamp(0.0, 1.0));

    canvas.drawPath(pavL, linePaint);
    canvas.drawPath(pavCL, linePaint);
    canvas.drawPath(pavCR, linePaint);
    canvas.drawPath(pavR, linePaint);
    canvas.drawPath(crownL, linePaint);
    canvas.drawPath(crownC, linePaint);
    canvas.drawPath(crownR, linePaint);
    canvas.drawPath(table, linePaint);
  }

  void _drawFacet(
    Canvas canvas,
    Path path,
    Color baseColor,
    double alpha, {
    bool hasReflection = false,
    double fresnelF0 = 0.05,
    double shimmer = 0.5,
  }) {
    final Rect bounds = path.getBounds();
    final double reflectionBoost = hasReflection ? (0.2 + fresnelF0 * 1.5) : (fresnelF0 * 0.8);
    final double shimmerAlpha = (alpha * (0.85 + 0.15 * shimmer) * glowIntensity).clamp(0.0, 1.0);

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          hasReflection
              ? Colors.white.withValues(alpha: (0.95 + reflectionBoost * 0.05).clamp(0.0, 1.0))
              : _highlight.withValues(alpha: shimmerAlpha),
          baseColor.withValues(alpha: shimmerAlpha),
          _deep.withValues(alpha: (shimmerAlpha * 0.9).clamp(0.0, 1.0)),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bounds);

    canvas.drawPath(path, fillPaint);
  }

  void _paintOrbitingShards(Canvas canvas, Offset center, double w, double h) {
    const int shardCount = 3;
    final Paint shardPaint = Paint()..blendMode = BlendMode.screen;

    for (int i = 0; i < shardCount; i++) {
      final double speed = 1.0 * shimmerSpeed;
      final double angle = (progress * 2 * math.pi * speed) + (i * (2 * math.pi / shardCount));
      final double orbitX = center.dx + math.cos(angle) * (w * 0.85);
      final double orbitY = center.dy + math.sin(angle) * (h * 0.42);

      final Path shard = Path()
        ..moveTo(orbitX, orbitY - 6)
        ..lineTo(orbitX + 4, orbitY)
        ..lineTo(orbitX, orbitY + 6)
        ..lineTo(orbitX - 4, orbitY)
        ..close();

      shardPaint.color = _highlight.withValues(alpha: 0.85 * glowIntensity);
      canvas.drawPath(shard, shardPaint);

      // Trailing spark
      final Paint sparkPaint = Paint()..color = Colors.white.withValues(alpha: 0.7);
      canvas.drawCircle(Offset(orbitX, orbitY), 1.2, sparkPaint);
    }
  }

  void _paintStarFlare(Canvas canvas, Offset center, double w, double h) {
    final Offset flarePos = Offset(center.dx + w * 0.12, center.dy - h * 0.38);
    final double rot = progress * shimmerSpeed * 2 * math.pi * 0.5;
    final double pulse = 0.7 + 0.3 * math.sin(progress * shimmerSpeed * 4 * math.pi);
    final double armLen = (14.0 * pulse * (1.0 + _disp * 5.0)).clamp(8.0, 26.0);

    final Paint flarePaint = Paint()
      ..blendMode = BlendMode.screen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          _highlight,
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: flarePos, radius: armLen));

    canvas.save();
    canvas.translate(flarePos.dx, flarePos.dy);
    canvas.rotate(rot);

    // 4-point cross flare
    canvas.drawLine(Offset(-armLen, 0), Offset(armLen, 0), flarePaint);
    canvas.drawLine(Offset(0, -armLen), Offset(0, armLen), flarePaint);

    // Diagonal smaller rays
    canvas.rotate(math.pi / 4);
    final Paint diagPaint = Paint()
      ..blendMode = BlendMode.screen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawLine(Offset(-armLen * 0.5, 0), Offset(armLen * 0.5, 0), diagPaint);
    canvas.drawLine(Offset(0, -armLen * 0.5), Offset(0, armLen * 0.5), diagPaint);

    canvas.restore();

    // Central flash dot
    final Paint dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(flarePos, 2.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant AbyssCrystalPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.variant != variant ||
        oldDelegate.customColor != customColor ||
        oldDelegate.showOrbitingShards != showOrbitingShards ||
        oldDelegate.showStarFlare != showStarFlare ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.refractiveIndex != refractiveIndex ||
        oldDelegate.dispersion != dispersion ||
        oldDelegate.shimmerSpeed != shimmerSpeed ||
        oldDelegate.causticIntensity != causticIntensity ||
        oldDelegate.shader != shader;
  }
}

/// Standalone Widget adapter for Abyss Crystal.
class AbyssCrystalWidget extends StatefulWidget {
  const AbyssCrystalWidget({
    super.key,
    this.size = 80.0,
    this.variant = CrystalColorVariant.abyssCyan,
    this.customColor,
    this.showOrbitingShards = true,
    this.showStarFlare = true,
    this.glowIntensity = 1.0,
    this.refractiveIndex,
    this.dispersion,
    this.shimmerSpeed = 1.0,
    this.causticIntensity,
    this.shader,
    this.duration = const Duration(seconds: 3),
  });

  final double size;
  final CrystalColorVariant variant;
  final Color? customColor;
  final bool showOrbitingShards;
  final bool showStarFlare;
  final double glowIntensity;
  final double? refractiveIndex;
  final double? dispersion;
  final double shimmerSpeed;
  final double? causticIntensity;
  final ui.FragmentShader? shader;
  final Duration duration;

  @override
  State<AbyssCrystalWidget> createState() => _AbyssCrystalWidgetState();
}

class _AbyssCrystalWidgetState extends State<AbyssCrystalWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
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
          painter: AbyssCrystalPainter(
            progress: _controller.value,
            variant: widget.variant,
            customColor: widget.customColor,
            showOrbitingShards: widget.showOrbitingShards,
            showStarFlare: widget.showStarFlare,
            glowIntensity: widget.glowIntensity,
            refractiveIndex: widget.refractiveIndex,
            dispersion: widget.dispersion,
            shimmerSpeed: widget.shimmerSpeed,
            causticIntensity: widget.causticIntensity,
            shader: widget.shader,
          ),
        );
      },
    );
  }
}
