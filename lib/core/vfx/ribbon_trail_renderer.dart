import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart' hide CatmullRomSpline;

// -----------------------------------------------------------------------------
// AAA Weapon Swing Mesh & Ribbon Trail System (2027 Cinematic Graphics Pipeline)
//
// Features:
// - Catmull-Rom Spline Interpolation (Centripetal, Uniform, Chordal) for weapon arcs
// - Dynamic Quad Strip Mesh Generation with Float32 vertex buffers
// - Non-linear Width Tapering (blade tip to hilt, head to dissipating tail)
// - Age Attenuation & Power-curve Alpha Decay
// - Additive HDR Emissive Glow modulation with Bloom boost
// - Fragment Shader Uniform Binding & Texture UV scrolling
// - Full 2D Canvas & 3D Vector support
// -----------------------------------------------------------------------------

/// Spline parameterization curve type for Catmull-Rom interpolation.
enum CatmullRomType {
  /// Uniform Catmull-Rom (alpha = 0.0): Fast, standard equidistant parametrization.
  uniform(0.0),

  /// Centripetal Catmull-Rom (alpha = 0.5): Prevents cusps, self-intersections,
  /// and overshoot during high-speed weapon directional changes (AAA standard).
  centripetal(0.5),

  /// Chordal Catmull-Rom (alpha = 1.0): Length-based parametrization.
  chordal(1.0);

  final double alpha;
  const CatmullRomType(this.alpha);
}

/// Lightweight, high-performance 3D vector for weapon arc calculations.
class Vector3D {
  final double x;
  final double y;
  final double z;

  const Vector3D(this.x, this.y, [this.z = 0.0]);

  static const Vector3D zero = Vector3D(0.0, 0.0, 0.0);

  factory Vector3D.fromOffset(Offset offset, [double z = 0.0]) =>
      Vector3D(offset.dx, offset.dy, z);

  Offset toOffset() => Offset(x, y);

  Vector3D operator +(Vector3D v) => Vector3D(x + v.x, y + v.y, z + v.z);
  Vector3D operator -(Vector3D v) => Vector3D(x - v.x, y - v.y, z - v.z);
  Vector3D operator *(double scalar) =>
      Vector3D(x * scalar, y * scalar, z * scalar);
  Vector3D operator /(double scalar) =>
      scalar == 0.0 ? zero : Vector3D(x / scalar, y / scalar, z / scalar);

  double dot(Vector3D v) => x * v.x + y * v.y + z * v.z;

  Vector3D cross(Vector3D v) => Vector3D(
        y * v.z - z * v.y,
        z * v.x - x * v.z,
        x * v.y - y * v.x,
      );

  double get lengthSquared => x * x + y * y + z * z;
  double get length => math.sqrt(lengthSquared);

  Vector3D get normalized {
    final len = length;
    return len > 1e-12 ? this / len : zero;
  }

  double distanceTo(Vector3D other) => (this - other).length;
  double distanceSquaredTo(Vector3D other) => (this - other).lengthSquared;

  Vector3D lerp(Vector3D other, double t) =>
      Vector3D(x + (other.x - x) * t, y + (other.y - y) * t, z + (other.z - z) * t);

  @override
  String toString() => 'Vector3D($x, $y, $z)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vector3D &&
          other.x == x &&
          other.y == y &&
          other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

/// Generic, high-precision Catmull-Rom spline evaluator.
class RibbonCatmullRomSpline {
  const RibbonCatmullRomSpline._();

  /// Evaluates Catmull-Rom spline in 3D using the Barry-Goldman pyramidal formulation.
  /// Guarantees numerical stability and handles coincident control points smoothly.
  static Vector3D evaluate3D(
    Vector3D p0,
    Vector3D p1,
    Vector3D p2,
    Vector3D p3,
    double t, {
    double alpha = 0.5,
  }) {
    if (alpha <= 0.001) {
      // Uniform Catmull-Rom fast analytical evaluation
      final t2 = t * t;
      final t3 = t2 * t;
      return (p1 * 2.0 +
              (p2 - p0) * t +
              (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2 +
              (p0 * -1.0 + p1 * 3.0 - p2 * 3.0 + p3) * t3) *
          0.5;
    }

    double dt(Vector3D a, Vector3D b) {
      final d2 = a.distanceSquaredTo(b);
      return d2 <= 1e-12 ? 0.0 : math.pow(d2, alpha * 0.5).toDouble();
    }

    final t0 = 0.0;
    final t1 = t0 + dt(p0, p1);
    final t2 = t1 + dt(p1, p2);
    final t3 = t2 + dt(p2, p3);

    if (t2 <= t1 + 1e-9) {
      return p1;
    }

    final actualT = t1 + t * (t2 - t1);

    Vector3D remap(Vector3D a, Vector3D b, double ta, double tb, double tc) {
      final span = tb - ta;
      if (span <= 1e-9) return a;
      final factor = (tc - ta) / span;
      return a + (b - a) * factor;
    }

    final a1 = remap(p0, p1, t0, t1, actualT);
    final a2 = remap(p1, p2, t1, t2, actualT);
    final a3 = remap(p2, p3, t2, t3, actualT);

    final b1 = remap(a1, a2, t0, t2, actualT);
    final b2 = remap(a2, a3, t1, t3, actualT);

    return remap(b1, b2, t1, t2, actualT);
  }

  /// Evaluates Catmull-Rom spline in 2D space.
  static Offset evaluate2D(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double t, {
    double alpha = 0.5,
  }) {
    final v0 = Vector3D.fromOffset(p0);
    final v1 = Vector3D.fromOffset(p1);
    final v2 = Vector3D.fromOffset(p2);
    final v3 = Vector3D.fromOffset(p3);
    return evaluate3D(v0, v1, v2, v3, t, alpha: alpha).toOffset();
  }
}

/// A recorded weapon swing cross-section sample.
class RibbonSample {
  final Vector3D tip;
  final Vector3D base;
  final double timestamp;
  final double width;
  final Color? color;
  final double opacity;

  const RibbonSample({
    required this.tip,
    required this.base,
    required this.timestamp,
    required this.width,
    this.color,
    this.opacity = 1.0,
  });

  factory RibbonSample.from2D({
    required Offset tip,
    required Offset base,
    required double timestamp,
    double? width,
    Color? color,
    double opacity = 1.0,
  }) {
    final tip3D = Vector3D.fromOffset(tip);
    final base3D = Vector3D.fromOffset(base);
    final calculatedWidth = width ?? tip3D.distanceTo(base3D);
    return RibbonSample(
      tip: tip3D,
      base: base3D,
      timestamp: timestamp,
      width: calculatedWidth,
      color: color,
      opacity: opacity,
    );
  }

  factory RibbonSample.from3D({
    required Vector3D tip,
    required Vector3D base,
    required double timestamp,
    double? width,
    Color? color,
    double opacity = 1.0,
  }) {
    final calculatedWidth = width ?? tip.distanceTo(base);
    return RibbonSample(
      tip: tip,
      base: base,
      timestamp: timestamp,
      width: calculatedWidth,
      color: color,
      opacity: opacity,
    );
  }

  Offset get tip2D => tip.toOffset();
  Offset get base2D => base.toOffset();
  Vector3D get center => (tip + base) * 0.5;
  Offset get center2D => center.toOffset();
}

/// Configuration settings for ribbon trail generation and visual style.
class RibbonTrailConfig {
  /// Total lifetime in seconds before a swing segment completely fades away.
  final double lifetime;

  /// Number of Catmull-Rom spline subdivisions between discrete samples.
  final int subdivisions;

  /// Width scale at the leading swing edge (u = 0.0, blade tip/head).
  final double startWidthMultiplier;

  /// Width scale at the dissipating tail (u = 1.0, oldest tail).
  final double endWidthMultiplier;

  /// Easing curve controlling width tapering along the trail length.
  final Curve widthTaperCurve;

  /// Easing curve controlling alpha decay as segments age.
  final Curve alphaDecayCurve;

  /// Core trail color (e.g. fiery orange, cyan slash, crimson blood).
  final Color baseColor;

  /// Emissive HDR glow tint.
  final Color glowColor;

  /// Emissive bloom boost radiance multiplier (> 1.0 for HDR bloom passes).
  final double glowIntensity;

  /// Canvas blend mode for rendering (default BlendMode.plus for additive glow).
  final BlendMode blendMode;

  /// Minimum distance in pixels between consecutive samples to prevent clutter.
  final double minSegmentDistance;

  /// Catmull-Rom spline type (Centripetal = 0.5 recommended).
  final CatmullRomType splineType;

  /// Whether to populate 3D vertex position buffers alongside 2D positions.
  final bool generate3D;

  /// UV texture scrolling speed along the arc for runtime shader.
  final double scrollSpeed;

  /// UV distortion strength for plasma/heat shimmer.
  final double distortionStrength;

  /// Spatial frequency of UV distortion waves.
  final double distortionFreq;

  /// Shader longitudinal fade exponent.
  final double fadePower;

  /// Shader transverse edge sharpness exponent.
  final double transversePower;

  /// Shader texture blend mix (0.0 = procedural energy, 1.0 = texture).
  final double textureMix;

  const RibbonTrailConfig({
    this.lifetime = 0.35,
    this.subdivisions = 6,
    this.startWidthMultiplier = 1.0,
    this.endWidthMultiplier = 0.0,
    this.widthTaperCurve = Curves.easeInOut,
    this.alphaDecayCurve = Curves.easeInQuad,
    this.baseColor = const Color(0xFFFF6600),
    this.glowColor = const Color(0xFFFFDD44),
    this.glowIntensity = 2.5,
    this.blendMode = BlendMode.plus,
    this.minSegmentDistance = 1.5,
    this.splineType = CatmullRomType.centripetal,
    this.generate3D = true,
    this.scrollSpeed = 1.2,
    this.distortionStrength = 0.08,
    this.distortionFreq = 2.5,
    this.fadePower = 1.4,
    this.transversePower = 2.0,
    this.textureMix = 0.0,
  });

  RibbonTrailConfig copyWith({
    double? lifetime,
    int? subdivisions,
    double? startWidthMultiplier,
    double? endWidthMultiplier,
    Curve? widthTaperCurve,
    Curve? alphaDecayCurve,
    Color? baseColor,
    Color? glowColor,
    double? glowIntensity,
    BlendMode? blendMode,
    double? minSegmentDistance,
    CatmullRomType? splineType,
    bool? generate3D,
    double? scrollSpeed,
    double? distortionStrength,
    double? distortionFreq,
    double? fadePower,
    double? transversePower,
    double? textureMix,
  }) {
    return RibbonTrailConfig(
      lifetime: lifetime ?? this.lifetime,
      subdivisions: subdivisions ?? this.subdivisions,
      startWidthMultiplier: startWidthMultiplier ?? this.startWidthMultiplier,
      endWidthMultiplier: endWidthMultiplier ?? this.endWidthMultiplier,
      widthTaperCurve: widthTaperCurve ?? this.widthTaperCurve,
      alphaDecayCurve: alphaDecayCurve ?? this.alphaDecayCurve,
      baseColor: baseColor ?? this.baseColor,
      glowColor: glowColor ?? this.glowColor,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      blendMode: blendMode ?? this.blendMode,
      minSegmentDistance: minSegmentDistance ?? this.minSegmentDistance,
      splineType: splineType ?? this.splineType,
      generate3D: generate3D ?? this.generate3D,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      distortionStrength: distortionStrength ?? this.distortionStrength,
      distortionFreq: distortionFreq ?? this.distortionFreq,
      fadePower: fadePower ?? this.fadePower,
      transversePower: transversePower ?? this.transversePower,
      textureMix: textureMix ?? this.textureMix,
    );
  }
}

/// Generated GPU-ready vertex buffers and mesh descriptors for the ribbon trail.
class RibbonTrailMesh {
  /// 2D positions: Interleaved [x0, y0, x1, y1, ...] for Flutter canvas / ui.Vertices.
  final Float32List positions;

  /// Optional 3D positions: Interleaved [x0, y0, z0, x1, y1, z1, ...] for 3D renderers.
  final Float32List? positions3D;

  /// UV coordinates: Interleaved [u0, v0, u1, v1, ...] where u in [0, 1] along arc, v in [0, 1] width.
  final Float32List texCoords;

  /// Vertex colors: 32-bit ARGB packed integers for ui.Vertices colors.
  final Int32List colors;

  /// Triangle indices for ui.VertexMode.triangles.
  final Uint16List indices;

  /// Number of vertices in the mesh buffer.
  final int vertexCount;

  /// Number of triangles in the mesh buffer.
  final int triangleCount;

  /// Axis-aligned bounding box enclosing all vertex positions.
  final Rect bounds;

  const RibbonTrailMesh({
    required this.positions,
    this.positions3D,
    required this.texCoords,
    required this.colors,
    required this.indices,
    required this.vertexCount,
    required this.triangleCount,
    required this.bounds,
  });

  factory RibbonTrailMesh.empty() {
    return RibbonTrailMesh(
      positions: Float32List(0),
      positions3D: Float32List(0),
      texCoords: Float32List(0),
      colors: Int32List(0),
      indices: Uint16List(0),
      vertexCount: 0,
      triangleCount: 0,
      bounds: Rect.zero,
    );
  }

  bool get isEmpty => vertexCount == 0 || triangleCount == 0;
  bool get isNotEmpty => !isEmpty;

  /// Creates a native Flutter [ui.Vertices] instance for Canvas.drawVertices.
  ui.Vertices? toVertices({ui.VertexMode vertexMode = ui.VertexMode.triangles}) {
    if (isEmpty) return null;

    final offsets = <Offset>[];
    for (int i = 0; i < positions.length; i += 2) {
      offsets.add(Offset(positions[i], positions[i + 1]));
    }

    final textureCoordinates = <Offset>[];
    for (int i = 0; i < texCoords.length; i += 2) {
      textureCoordinates.add(Offset(texCoords[i], texCoords[i + 1]));
    }

    final colorList = <Color>[];
    for (int i = 0; i < colors.length; i++) {
      colorList.add(Color(colors[i]));
    }

    return ui.Vertices(
      vertexMode,
      offsets,
      textureCoordinates: textureCoordinates,
      colors: colorList,
      indices: indices,
    );
  }
}

/// Core algorithmic mesh generator converting weapon swing history into smooth quad strips.
class RibbonTrailMeshGenerator {
  const RibbonTrailMeshGenerator._();

  /// Generates a [RibbonTrailMesh] from the provided samples and config at [currentTime].
  static RibbonTrailMesh generate({
    required List<RibbonSample> samples,
    required double currentTime,
    required RibbonTrailConfig config,
  }) {
    if (samples.length < 2) {
      return RibbonTrailMesh.empty();
    }

    // 1. Filter out expired samples based on lifetime
    final active = <RibbonSample>[];
    for (final s in samples) {
      final age = currentTime - s.timestamp;
      if (age <= config.lifetime && age >= -0.001) {
        active.add(s);
      }
    }

    if (active.length < 2) {
      return RibbonTrailMesh.empty();
    }

    // 2. Perform Catmull-Rom spline interpolation along weapon swing arcs
    final smoothed = _interpolateSamples(
      active,
      subdivisions: config.subdivisions,
      alpha: config.splineType.alpha,
      lifetime: config.lifetime,
    );

    if (smoothed.length < 2) {
      return RibbonTrailMesh.empty();
    }

    final sliceCount = smoothed.length;
    final vertexCount = sliceCount * 2;
    final quadCount = sliceCount - 1;
    final triangleCount = quadCount * 2;
    final indexCount = triangleCount * 3;

    final positions = Float32List(vertexCount * 2);
    final positions3D = config.generate3D ? Float32List(vertexCount * 3) : null;
    final texCoords = Float32List(vertexCount * 2);
    final colors = Int32List(vertexCount);
    final indices = Uint16List(indexCount);

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    void updateBounds(double x, double y) {
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    // 3. Generate vertices with dynamic width tapering, alpha decay, and emissive glow
    for (int i = 0; i < sliceCount; i++) {
      final slice = smoothed[i];

      // u coordinate: 0.0 at newest leading edge (i = 0), 1.0 at oldest dissipating tail (i = sliceCount - 1)
      final u = i / (sliceCount - 1);

      // Width tapering calculation
      final taperFactor = config.widthTaperCurve.transform(u);
      final widthMult = config.startWidthMultiplier +
          (config.endWidthMultiplier - config.startWidthMultiplier) * taperFactor;

      // Center point of the blade slice
      final center = (slice.tip + slice.base) * 0.5;
      final halfVec = (slice.tip - slice.base) * (0.5 * widthMult);

      final taperedTip = center + halfVec;
      final taperedBase = center - halfVec;

      // Age attenuation & alpha decay
      final age = (currentTime - slice.timestamp).clamp(0.0, config.lifetime);
      final ageRatio = (age / config.lifetime).clamp(0.0, 1.0);
      final decay = (1.0 - config.alphaDecayCurve.transform(ageRatio)).clamp(0.0, 1.0);

      // Longitudinal head-to-tail decay
      final longitudinalDecay = math.pow((1.0 - u).clamp(0.0, 1.0), config.fadePower).toDouble();

      // Combined alpha
      final sampleAlpha = slice.opacity * decay * longitudinalDecay;
      final finalAlpha = (sampleAlpha * _colorAlpha(config.baseColor)).clamp(0.0, 1.0);

      // Additive Emissive Glow & Color Modulation
      // Head and core center are brightened with glowColor and glowIntensity
      final glowMix = math.pow((1.0 - u).clamp(0.0, 1.0), 1.2).toDouble();
      final coreColor = Color.lerp(config.baseColor, config.glowColor, glowMix) ?? config.baseColor;
      final sliceColor = slice.color != null
          ? Color.lerp(coreColor, slice.color!, 0.5)!
          : coreColor;

      // Vertex color packing (ARGB32)
      final tipPackedColor = _packColor(sliceColor, finalAlpha, edgeAttenuation: 0.85);
      final basePackedColor = _packColor(sliceColor, finalAlpha, edgeAttenuation: 0.85);

      final vTipIdx = i * 2;
      final vBaseIdx = vTipIdx + 1;

      // Tip vertex (v = 0.0)
      positions[vTipIdx * 2] = taperedTip.x;
      positions[vTipIdx * 2 + 1] = taperedTip.y;
      texCoords[vTipIdx * 2] = u;
      texCoords[vTipIdx * 2 + 1] = 0.0;
      colors[vTipIdx] = tipPackedColor;
      updateBounds(taperedTip.x, taperedTip.y);

      // Base vertex (v = 1.0)
      positions[vBaseIdx * 2] = taperedBase.x;
      positions[vBaseIdx * 2 + 1] = taperedBase.y;
      texCoords[vBaseIdx * 2] = u;
      texCoords[vBaseIdx * 2 + 1] = 1.0;
      colors[vBaseIdx] = basePackedColor;
      updateBounds(taperedBase.x, taperedBase.y);

      if (positions3D != null) {
        positions3D[vTipIdx * 3] = taperedTip.x;
        positions3D[vTipIdx * 3 + 1] = taperedTip.y;
        positions3D[vTipIdx * 3 + 2] = taperedTip.z;

        positions3D[vBaseIdx * 3] = taperedBase.x;
        positions3D[vBaseIdx * 3 + 1] = taperedBase.y;
        positions3D[vBaseIdx * 3 + 2] = taperedBase.z;
      }
    }

    // 4. Generate indexed quad strip triangles
    int idx = 0;
    for (int i = 0; i < quadCount; i++) {
      final v0 = i * 2;
      final v1 = v0 + 1;
      final v2 = v0 + 2;
      final v3 = v0 + 3;

      // Triangle 1 (v0, v1, v2)
      indices[idx++] = v0;
      indices[idx++] = v1;
      indices[idx++] = v2;

      // Triangle 2 (v1, v3, v2)
      indices[idx++] = v1;
      indices[idx++] = v3;
      indices[idx++] = v2;
    }

    final bounds = minX <= maxX && minY <= maxY
        ? Rect.fromLTRB(minX, minY, maxX, maxY)
        : Rect.zero;

    return RibbonTrailMesh(
      positions: positions,
      positions3D: positions3D,
      texCoords: texCoords,
      colors: colors,
      indices: indices,
      vertexCount: vertexCount,
      triangleCount: triangleCount,
      bounds: bounds,
    );
  }

  /// Interpolates discrete samples using Catmull-Rom splines for both tip and base paths.
  static List<RibbonSample> _interpolateSamples(
    List<RibbonSample> samples, {
    required int subdivisions,
    required double alpha,
    required double lifetime,
  }) {
    if (samples.length < 2) return samples;

    final n = samples.length;
    final result = <RibbonSample>[];

    // For linear two-point fallback
    if (n == 2 || subdivisions <= 1) {
      final s0 = samples[0];
      final s1 = samples[1];
      final steps = math.max(1, subdivisions);
      for (int step = 0; step <= steps; step++) {
        final t = step / steps;
        result.add(RibbonSample(
          tip: s0.tip.lerp(s1.tip, t),
          base: s0.base.lerp(s1.base, t),
          timestamp: s0.timestamp + (s1.timestamp - s0.timestamp) * t,
          width: s0.width + (s1.width - s0.width) * t,
          color: Color.lerp(s0.color ?? const Color(0xFFFFFFFF), s1.color ?? const Color(0xFFFFFFFF), t),
          opacity: s0.opacity + (s1.opacity - s0.opacity) * t,
        ));
      }
      return result;
    }

    // Multi-segment Catmull-Rom interpolation
    for (int i = 0; i < n - 1; i++) {
      // Extrapolate endpoints for phantom control points P0 and P3
      final p0Sample = i > 0 ? samples[i - 1] : _extrapolatePrev(samples[0], samples[1]);
      final p1Sample = samples[i];
      final p2Sample = samples[i + 1];
      final p3Sample = i + 2 < n ? samples[i + 2] : _extrapolateNext(samples[n - 2], samples[n - 1]);

      final steps = subdivisions;
      final isLastSegment = i == n - 2;

      for (int step = 0; step < (isLastSegment ? steps + 1 : steps); step++) {
        final t = step / steps;

        final interpolatedTip = RibbonCatmullRomSpline.evaluate3D(
          p0Sample.tip,
          p1Sample.tip,
          p2Sample.tip,
          p3Sample.tip,
          t,
          alpha: alpha,
        );

        final interpolatedBase = RibbonCatmullRomSpline.evaluate3D(
          p0Sample.base,
          p1Sample.base,
          p2Sample.base,
          p3Sample.base,
          t,
          alpha: alpha,
        );

        final interpolatedTime =
            p1Sample.timestamp + (p2Sample.timestamp - p1Sample.timestamp) * t;
        final interpolatedWidth =
            p1Sample.width + (p2Sample.width - p1Sample.width) * t;
        final interpolatedOpacity =
            p1Sample.opacity + (p2Sample.opacity - p1Sample.opacity) * t;

        Color? interpolatedColor;
        if (p1Sample.color != null && p2Sample.color != null) {
          interpolatedColor = Color.lerp(p1Sample.color, p2Sample.color, t);
        } else {
          interpolatedColor = p1Sample.color ?? p2Sample.color;
        }

        result.add(RibbonSample(
          tip: interpolatedTip,
          base: interpolatedBase,
          timestamp: interpolatedTime,
          width: interpolatedWidth,
          color: interpolatedColor,
          opacity: interpolatedOpacity,
        ));
      }
    }

    return result;
  }

  static RibbonSample _extrapolatePrev(RibbonSample s0, RibbonSample s1) {
    return RibbonSample(
      tip: s0.tip * 2.0 - s1.tip,
      base: s0.base * 2.0 - s1.base,
      timestamp: s0.timestamp * 2.0 - s1.timestamp,
      width: s0.width * 2.0 - s1.width,
      color: s0.color,
      opacity: s0.opacity,
    );
  }

  static RibbonSample _extrapolateNext(RibbonSample sNMinus1, RibbonSample sN) {
    return RibbonSample(
      tip: sN.tip * 2.0 - sNMinus1.tip,
      base: sN.base * 2.0 - sNMinus1.base,
      timestamp: sN.timestamp * 2.0 - sNMinus1.timestamp,
      width: sN.width * 2.0 - sNMinus1.width,
      color: sN.color,
      opacity: sN.opacity,
    );
  }

  static double _colorAlpha(Color c) {
    return ((c.toARGB32() >> 24) & 0xFF) / 255.0;
  }

  static int _packColor(Color color, double alpha, {double edgeAttenuation = 1.0}) {
    final effectiveAlpha = (alpha * edgeAttenuation).clamp(0.0, 1.0);
    final a = (effectiveAlpha * 255.0).round().clamp(0, 255);
    final argb = color.toARGB32();
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return (a << 24) | (r << 16) | (g << 8) | b;
  }
}

/// Active ribbon trail manager tracking weapon history and simulation time.
class RibbonTrail {
  RibbonTrailConfig config;
  final List<RibbonSample> _samples = [];
  double _currentTime = 0.0;
  RibbonTrailMesh? _cachedMesh;
  bool _isDirty = true;

  RibbonTrail({RibbonTrailConfig? config})
      : config = config ?? const RibbonTrailConfig();

  List<RibbonSample> get samples => List.unmodifiable(_samples);
  int get sampleCount => _samples.length;
  double get currentTime => _currentTime;
  bool get isEmpty => _samples.isEmpty;
  bool get isNotEmpty => _samples.isNotEmpty;

  /// Adds a new weapon swing 2D sample at [tip] and [base].
  void addSample({
    required Offset tip,
    required Offset base,
    double? timestamp,
    double? width,
    Color? color,
    double opacity = 1.0,
  }) {
    final time = timestamp ?? _currentTime;
    _currentTime = math.max(_currentTime, time);

    final newTip3D = Vector3D.fromOffset(tip);
    final newBase3D = Vector3D.fromOffset(base);

    // Distance culling to avoid redundant stationary samples
    if (_samples.isNotEmpty) {
      final last = _samples.first;
      final distTip = last.tip.distanceTo(newTip3D);
      final distBase = last.base.distanceTo(newBase3D);
      if (distTip < config.minSegmentDistance && distBase < config.minSegmentDistance) {
        return;
      }
    }

    final sample = RibbonSample.from2D(
      tip: tip,
      base: base,
      timestamp: time,
      width: width,
      color: color,
      opacity: opacity,
    );

    // Newest samples inserted at head (index 0)
    _samples.insert(0, sample);
    _isDirty = true;
    _pruneExpired();
  }

  /// Adds a new weapon swing 3D sample at [tip] and [base].
  void addSample3D({
    required Vector3D tip,
    required Vector3D base,
    double? timestamp,
    double? width,
    Color? color,
    double opacity = 1.0,
  }) {
    final time = timestamp ?? _currentTime;
    _currentTime = math.max(_currentTime, time);

    if (_samples.isNotEmpty) {
      final last = _samples.first;
      final distTip = last.tip.distanceTo(tip);
      final distBase = last.base.distanceTo(base);
      if (distTip < config.minSegmentDistance && distBase < config.minSegmentDistance) {
        return;
      }
    }

    final sample = RibbonSample.from3D(
      tip: tip,
      base: base,
      timestamp: time,
      width: width,
      color: color,
      opacity: opacity,
    );

    _samples.insert(0, sample);
    _isDirty = true;
    _pruneExpired();
  }

  /// Advances the simulation clock by [dt] seconds and prunes dead samples.
  void update(double dt) {
    if (dt <= 0.0) return;
    _currentTime += dt;
    _pruneExpired();
    _isDirty = true;
  }

  /// Sets absolute simulation time.
  void setTime(double time) {
    _currentTime = time;
    _pruneExpired();
    _isDirty = true;
  }

  /// Clears all recorded samples.
  void clear() {
    _samples.clear();
    _cachedMesh = null;
    _isDirty = true;
  }

  /// Prunes samples older than [config.lifetime].
  void _pruneExpired() {
    _samples.removeWhere((s) => (_currentTime - s.timestamp) > config.lifetime);
  }

  /// Generates or retrieves the cached [RibbonTrailMesh].
  RibbonTrailMesh generateMesh() {
    if (!_isDirty && _cachedMesh != null) {
      return _cachedMesh!;
    }

    _cachedMesh = RibbonTrailMeshGenerator.generate(
      samples: _samples,
      currentTime: _currentTime,
      config: config,
    );
    _isDirty = false;
    return _cachedMesh!;
  }
}

/// Renderer responsible for drawing ribbon trail meshes and configuring shaders.
class RibbonTrailRenderer {
  const RibbonTrailRenderer._();

  static ui.Image? _fallbackWhiteImage;

  /// Cached static 1x1 solid white [ui.Image] used as a fallback texture
  /// when shaders require an active sampler in slot 0.
  static ui.Image? get fallbackWhiteImage {
    if (_fallbackWhiteImage != null) return _fallbackWhiteImage;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1, 1));
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1, 1),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      final picture = recorder.endRecording();
      _fallbackWhiteImage = picture.toImageSync(1, 1);
      picture.dispose();
    } catch (_) {
      // In headless test environments where rasterizer is unavailable
      _fallbackWhiteImage = null;
    }
    return _fallbackWhiteImage;
  }

  /// Explicit setter for custom or pre-warmed fallback white texture.
  static set fallbackWhiteImage(ui.Image? image) {
    _fallbackWhiteImage = image;
  }

  /// Asynchronously creates a 1x1 white [ui.Image] if synchronous creation fails.
  static Future<ui.Image?> initFallbackWhiteImage() async {
    if (_fallbackWhiteImage != null) return _fallbackWhiteImage;
    final cached = fallbackWhiteImage;
    if (cached != null) return cached;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1, 1));
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1, 1),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      final picture = recorder.endRecording();
      _fallbackWhiteImage = await picture.toImage(1, 1);
      picture.dispose();
    } catch (_) {
      _fallbackWhiteImage = null;
    }
    return _fallbackWhiteImage;
  }

  /// Renders a [RibbonTrailMesh] using native Flutter [Canvas.drawVertices].
  static void renderMesh(
    Canvas canvas,
    RibbonTrailMesh mesh, {
    Paint? paint,
    BlendMode blendMode = BlendMode.plus,
  }) {
    if (mesh.isEmpty) return;

    final vertices = mesh.toVertices(vertexMode: ui.VertexMode.triangles);
    if (vertices == null) return;

    final renderPaint = paint ?? Paint()
      ..blendMode = blendMode
      ..isAntiAlias = true;

    canvas.drawVertices(vertices, blendMode, renderPaint);
  }

  /// Renders an active [RibbonTrail] directly onto [Canvas].
  static void renderTrail(
    Canvas canvas,
    RibbonTrail trail, {
    Paint? paint,
    BlendMode? blendMode,
    ui.FragmentShader? shader,
    Size? resolution,
    double? shaderTime,
    ui.Image? texture,
  }) {
    final mesh = trail.generateMesh();
    if (mesh.isEmpty) return;

    final effectiveBlend = blendMode ?? trail.config.blendMode;
    final effectiveTexture = texture ?? fallbackWhiteImage;

    if (shader != null && effectiveTexture != null) {
      applyShaderUniforms(
        shader,
        resolution: resolution ?? (mesh.bounds.size.isEmpty ? const Size(1920, 1080) : mesh.bounds.size),
        bounds: mesh.bounds,
        time: shaderTime ?? trail.currentTime,
        config: trail.config,
        texture: texture,
        fallbackImage: effectiveTexture,
      );

      final shaderPaint = (paint ?? Paint())
        ..shader = shader
        ..blendMode = effectiveBlend
        ..isAntiAlias = true;

      renderMesh(canvas, mesh, paint: shaderPaint, blendMode: effectiveBlend);
    } else {
      // Fallback cleanly to rendering vertices with vertex colors / default paint
      // when no active texture can be bound to shader sampler slot 0 or shader is null.
      renderMesh(canvas, mesh, paint: paint, blendMode: effectiveBlend);
    }
  }

  /// Binds configuration and animation uniforms to the `ribbon_trail.frag` shader.
  /// Accepts either a [ui.FragmentShader] or any target implementing [setFloat]
  /// and [setImageSampler].
  static void applyShaderUniforms(
    dynamic shader, {
    required Size resolution,
    required Rect bounds,
    required double time,
    required RibbonTrailConfig config,
    ui.Image? texture,
    ui.Image? fallbackImage,
  }) {
    final baseColor = config.baseColor;
    final glowColor = config.glowColor;

    final baseArgb = baseColor.toARGB32();
    final glowArgb = glowColor.toARGB32();

    final baseR = ((baseArgb >> 16) & 0xFF) / 255.0;
    final baseG = ((baseArgb >> 8) & 0xFF) / 255.0;
    final baseB = (baseArgb & 0xFF) / 255.0;
    final baseA = ((baseArgb >> 24) & 0xFF) / 255.0;

    final glowR = ((glowArgb >> 16) & 0xFF) / 255.0;
    final glowG = ((glowArgb >> 8) & 0xFF) / 255.0;
    final glowB = (glowArgb & 0xFF) / 255.0;
    final glowA = ((glowArgb >> 24) & 0xFF) / 255.0;

    // Uniform 0, 1: uResolution
    shader.setFloat(0, resolution.width);
    shader.setFloat(1, resolution.height);

    // Uniform 2: uTime
    shader.setFloat(2, time);

    // Uniform 3..6: uBaseColor
    shader.setFloat(3, baseR);
    shader.setFloat(4, baseG);
    shader.setFloat(5, baseB);
    shader.setFloat(6, baseA);

    // Uniform 7..10: uGlowColor
    shader.setFloat(7, glowR);
    shader.setFloat(8, glowG);
    shader.setFloat(9, glowB);
    shader.setFloat(10, glowA);

    // Uniform 11..14: uBounds (minX, minY, width, height)
    shader.setFloat(11, bounds.left);
    shader.setFloat(12, bounds.top);
    shader.setFloat(13, bounds.width);
    shader.setFloat(14, bounds.height);

    // Uniform 15: uScrollSpeed
    shader.setFloat(15, config.scrollSpeed);

    // Uniform 16: uDistortionStrength
    shader.setFloat(16, config.distortionStrength);

    // Uniform 17: uDistortionFreq
    shader.setFloat(17, config.distortionFreq);

    // Uniform 18: uGlowIntensity
    shader.setFloat(18, config.glowIntensity);

    // Uniform 19: uFadePower
    shader.setFloat(19, config.fadePower);

    // Uniform 20: uTransversePower
    shader.setFloat(20, config.transversePower);

    // Uniform 21: uTextureMix
    shader.setFloat(21, texture != null ? config.textureMix : 0.0);

    // Sampler 0: uTrailTexture
    final effectiveTexture = texture ?? fallbackImage ?? fallbackWhiteImage;
    if (effectiveTexture != null) {
      shader.setImageSampler(0, effectiveTexture);
    }
  }
}

/// CustomPainter adapter for embedding dynamic weapon trails in the Flutter widget tree.
class RibbonTrailPainter extends CustomPainter {
  final RibbonTrail trail;
  final ui.FragmentShader? shader;
  final ui.Image? texture;
  final BlendMode? blendMode;

  RibbonTrailPainter({
    required this.trail,
    this.shader,
    this.texture,
    this.blendMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    RibbonTrailRenderer.renderTrail(
      canvas,
      trail,
      shader: shader,
      resolution: size,
      texture: texture,
      blendMode: blendMode,
    );
  }

  @override
  bool shouldRepaint(covariant RibbonTrailPainter oldDelegate) {
    return true; // Dynamic continuous swing animation repaints each frame
  }
}
