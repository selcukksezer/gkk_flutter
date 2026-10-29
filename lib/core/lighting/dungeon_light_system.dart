import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Size, FragmentShader, Image;

/// ----------------------------------------------------------------------------
/// Production-Ready Dungeon Atmospheric Lighting & Dynamic Shadow System
/// 2027 Cinematic AAA Graphics Pipeline (R3 Dark Fantasy Standard)
/// ----------------------------------------------------------------------------

/// Type of light source determining behavior, flicker, and atmospheric aura.
enum LightType {
  /// Procedural warm torch with multi-harmonic sine flicker and position wobble.
  torch(0.0),

  /// Ancient arcane rune pulsing with rhythmic breathing and chromatic aura.
  pulsingRune(1.0),

  /// High-energy explosive fireball flare with shockwave expansion and blackbody decay.
  fieryExplosion(2.0),

  /// Floating spectral soul entity with 3D harmonic orbit and phantom shimmer.
  etherealSoul(3.0),

  /// Standard directional/static point light.
  point(4.0),

  /// Directional spot light with downward conic beam.
  spot(5.0);

  const LightType(this.shaderValue);
  final double shaderValue;
}

/// Attenuation curve model for distance falloff.
enum FalloffType {
  /// Unreal Engine 4/5 windowed inverse-square: (1 - (d/r)^4)^2 / (d^2 + 1).
  windowedInverseSquare(0.0),

  /// Smooth Hermite cubic polynomial window: (1 - 3t^2 + 2t^3) / (d + 1).
  smoothstep(1.0),

  /// Fast artistic linear falloff: clamp(1 - d/r, 0, 1).
  linear(2.0);

  const FalloffType(this.shaderValue);
  final double shaderValue;
}

/// 3D Vector for world, view, and light positions in dungeon space.
class Vector3D {
  const Vector3D(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const Vector3D zero = Vector3D(0.0, 0.0, 0.0);
  static const Vector3D unitZ = Vector3D(0.0, 0.0, 1.0);

  double get lengthSquared => x * x + y * y + z * z;
  double get length => math.sqrt(lengthSquared);

  Vector3D normalized() {
    final double l = length;
    if (l < 1e-7) return unitZ;
    return Vector3D(x / l, y / l, z / l);
  }

  double dot(Vector3D o) => x * o.x + y * o.y + z * o.z;

  Vector3D cross(Vector3D o) {
    return Vector3D(
      y * o.z - z * o.y,
      z * o.x - x * o.z,
      x * o.y - y * o.x,
    );
  }

  double distanceTo(Vector3D o) {
    final double dx = x - o.x;
    final double dy = y - o.y;
    final double dz = z - o.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  double distanceSquaredTo(Vector3D o) {
    final double dx = x - o.x;
    final double dy = y - o.y;
    final double dz = z - o.z;
    return dx * dx + dy * dy + dz * dz;
  }

  Vector3D operator +(Vector3D o) => Vector3D(x + o.x, y + o.y, z + o.z);
  Vector3D operator -(Vector3D o) => Vector3D(x - o.x, y - o.y, z - o.z);
  Vector3D operator *(double s) => Vector3D(x * s, y * s, z * s);
  Vector3D operator /(double s) => Vector3D(x / s, y / s, z / s);
  Vector3D operator -() => Vector3D(-x, -y, -z);

  Vector3D lerp(Vector3D target, double t) {
    return Vector3D(
      x + (target.x - x) * t,
      y + (target.y - y) * t,
      z + (target.z - z) * t,
    );
  }

  @override
  String toString() => 'Vector3D(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

/// Coherent Gradient & Perlin Noise Generator.
/// Produces deterministic, continuous C2-smooth noise without external dependencies.
class PerlinNoiseGenerator {
  PerlinNoiseGenerator({int seed = 1337}) {
    _initPermutation(seed);
  }

  final List<int> _p = List<int>.filled(512, 0);

  void _initPermutation(int seed) {
    final List<int> permutation = List<int>.generate(256, (int i) => i);
    // Linear congruential generator for deterministic shuffle
    int s = seed & 0x7fffffff;
    for (int i = 255; i > 0; --i) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      final int j = s % (i + 1);
      final int temp = permutation[i];
      permutation[i] = permutation[j];
      permutation[j] = temp;
    }
    for (int i = 0; i < 256; ++i) {
      _p[i] = permutation[i];
      _p[256 + i] = permutation[i];
    }
  }

  // Quintic Hermite interpolant: 6t^5 - 15t^4 + 10t^3
  static double _fade(double t) => t * t * t * (t * (t * 6.0 - 15.0) + 10.0);

  static double _grad1D(int hash, double x) {
    return (hash & 1) == 0 ? x : -x;
  }

  static double _grad2D(int hash, double x, double y) {
    final int h = hash & 3;
    switch (h) {
      case 0:
        return x + y;
      case 1:
        return -x + y;
      case 2:
        return x - y;
      default:
        return -x - y;
    }
  }

  /// 1D Coherent Perlin Noise in range [-1.0, 1.0].
  double noise1D(double x) {
    final int xi = x.floor() & 255;
    final double xf = x - x.floor();
    final double u = _fade(xf);

    final double g0 = _grad1D(_p[xi], xf);
    final double g1 = _grad1D(_p[xi + 1], xf - 1.0);

    return (g0 + u * (g1 - g0)) * 2.0;
  }

  /// 2D Coherent Perlin Noise in range [-1.0, 1.0].
  double noise2D(double x, double y) {
    final int xi = x.floor() & 255;
    final int yi = y.floor() & 255;
    final double xf = x - x.floor();
    final double yf = y - y.floor();

    final double u = _fade(xf);
    final double v = _fade(yf);

    final int aa = _p[_p[xi] + yi];
    final int ab = _p[_p[xi] + yi + 1];
    final int ba = _p[_p[xi + 1] + yi];
    final int bb = _p[_p[xi + 1] + yi + 1];

    final double x1 = _grad2D(aa, xf, yf) + u * (_grad2D(ba, xf - 1.0, yf) - _grad2D(aa, xf, yf));
    final double x2 = _grad2D(ab, xf, yf - 1.0) + u * (_grad2D(bb, xf - 1.0, yf - 1.0) - _grad2D(ab, xf, yf - 1.0));

    return x1 + v * (x2 - x1);
  }

  /// Multi-octave Fractal Brownian Motion (fBm) noise.
  double fbm1D(double x, {int octaves = 3, double lacunarity = 2.0, double gain = 0.5}) {
    double sum = 0.0;
    double freq = 1.0;
    double amp = 1.0;
    double maxAmp = 0.0;

    for (int i = 0; i < octaves; ++i) {
      sum += noise1D(x * freq) * amp;
      maxAmp += amp;
      freq *= lacunarity;
      amp *= gain;
    }
    return sum / maxAmp;
  }
}

/// Torch Flicker Calculation Result containing modulated intensity, position wobble, and temperature tint.
class TorchFlickerSample {
  const TorchFlickerSample({
    required this.intensity,
    required this.positionOffset,
    required this.colorTint,
  });

  /// Final dynamic light intensity.
  final double intensity;

  /// Spatial displacement offset around the anchor point.
  final Vector3D positionOffset;

  /// Dynamic color shifted by temperature (cooler amber when dipping, hotter gold when flaring).
  final Color colorTint;
}

/// Procedural Torch Flicker Engine.
/// Combines multiple harmonic sine oscillators with low-frequency Perlin noise jitter
/// for natural air draft turbulence and bounded flame position wobble.
class TorchFlickerEngine {
  TorchFlickerEngine({
    PerlinNoiseGenerator? noiseGenerator,
    this.primaryFreq = 1.85,
    this.secondaryFreq = 4.23,
    this.tertiaryFreq = 8.67,
    this.quaternaryFreq = 14.19,
    this.noiseFreq = 0.75,
    this.primaryAmp = 0.12,
    this.secondaryAmp = 0.07,
    this.tertiaryAmp = 0.04,
    this.quaternaryAmp = 0.02,
    this.noiseAmp = 0.14,
  }) : noise = noiseGenerator ?? PerlinNoiseGenerator();

  final PerlinNoiseGenerator noise;

  final double primaryFreq;
  final double secondaryFreq;
  final double tertiaryFreq;
  final double quaternaryFreq;
  final double noiseFreq;

  final double primaryAmp;
  final double secondaryAmp;
  final double tertiaryAmp;
  final double quaternaryAmp;
  final double noiseAmp;

  /// Evaluates torch flicker state at time [t] seconds with phase offset [phase].
  TorchFlickerSample evaluate({
    required double t,
    required double baseIntensity,
    required double minIntensity,
    required double maxIntensity,
    required double maxWobbleRadius,
    required Color baseColor,
    double phase = 0.0,
    double wobbleSpeed = 1.0,
  }) {
    final double timeWithPhase = t + phase;

    // 1. Multi-harmonic sine oscillators
    final double h1 = math.sin(2.0 * math.pi * primaryFreq * timeWithPhase) * primaryAmp;
    final double h2 = math.sin(2.0 * math.pi * secondaryFreq * timeWithPhase + 1.25) * secondaryAmp;
    final double h3 = math.sin(2.0 * math.pi * tertiaryFreq * timeWithPhase + 2.80) * tertiaryAmp;
    final double h4 = math.sin(2.0 * math.pi * quaternaryFreq * timeWithPhase + 4.10) * quaternaryAmp;

    // 2. Low-frequency coherent Perlin noise jitter
    final double noiseVal = noise.fbm1D(timeWithPhase * noiseFreq, octaves: 2) * noiseAmp;

    // Total intensity modulation
    final double modulationFactor = 1.0 + h1 + h2 + h3 + h4 + noiseVal;
    final double rawIntensity = baseIntensity * modulationFactor;
    final double clampedIntensity = rawIntensity.clamp(minIntensity, maxIntensity);

    // 3. 3D Flame Position Wobble
    final double wobbleTime = timeWithPhase * wobbleSpeed;
    final double nx = noise.noise2D(wobbleTime * 1.5, phase);
    final double ny = noise.noise2D(phase + 17.3, wobbleTime * 1.8);
    final double nz = noise.noise1D(wobbleTime * 2.1 + phase * 2.0);

    final double sx = math.sin(2.0 * math.pi * 2.3 * wobbleTime) * 0.4;
    final double sy = math.cos(2.0 * math.pi * 3.1 * wobbleTime) * 0.4;
    final double sz = math.sin(2.0 * math.pi * 1.7 * wobbleTime) * 0.2;

    double wx = (nx * 0.6 + sx) * maxWobbleRadius;
    double wy = (ny * 0.6 + sy) * maxWobbleRadius;
    double wz = (nz * 0.6 + sz) * (maxWobbleRadius * 0.4);

    // Enforce strict spherical wobble radius constraint
    final double wLenSq = wx * wx + wy * wy + wz * wz;
    if (wLenSq > maxWobbleRadius * maxWobbleRadius && maxWobbleRadius > 1e-6) {
      final double scale = maxWobbleRadius / math.sqrt(wLenSq);
      wx *= scale;
      wy *= scale;
      wz *= scale;
    }
    final Vector3D wobbleOffset = Vector3D(wx, wy, wz);

    // 4. Color temperature modulation
    // When dipping dimmer -> cooler amber/red (0xFFE65100)
    // When peaking brighter -> hot golden white (0xFFFFF176)
    final double normalizedIntensity = (maxIntensity > minIntensity)
        ? ((clampedIntensity - minIntensity) / (maxIntensity - minIntensity)).clamp(0.0, 1.0)
        : 0.5;

    final Color coolTint = const Color(0xFFFF6D00); // Deep amber
    final Color hotTint = const Color(0xFFFFF59D); // Golden yellow
    final Color tintedColor = _lerpColor(coolTint, hotTint, normalizedIntensity);

    // Blend base color with temperature tint
    final Color finalColor = _blendColors(baseColor, tintedColor, 0.45);

    return TorchFlickerSample(
      intensity: clampedIntensity,
      positionOffset: wobbleOffset,
      colorTint: finalColor,
    );
  }

  static Color _lerpColor(Color a, Color b, double t) {
    final double clampedT = t.clamp(0.0, 1.0);
    final int r = (a.r * 255.0 + (b.r * 255.0 - a.r * 255.0) * clampedT).round().clamp(0, 255);
    final int g = (a.g * 255.0 + (b.g * 255.0 - a.g * 255.0) * clampedT).round().clamp(0, 255);
    final int bl = (a.b * 255.0 + (b.b * 255.0 - a.b * 255.0) * clampedT).round().clamp(0, 255);
    final int al = (a.a * 255.0 + (b.a * 255.0 - a.a * 255.0) * clampedT).round().clamp(0, 255);
    return Color.fromARGB(al, r, g, bl);
  }

  static Color _blendColors(Color a, Color b, double ratio) {
    return _lerpColor(a, b, ratio);
  }
}

/// Dynamic Dungeon Light Entity.
class DungeonLight {
  DungeonLight({
    required this.id,
    required this.type,
    required this.position,
    required this.color,
    required this.intensity,
    required this.radius,
    this.falloffType = FalloffType.windowedInverseSquare,
    this.shadowHardness = 0.75,
    this.specularPower = 32.0,
    this.maxWobbleRadius = 8.0,
    this.minIntensity,
    this.maxIntensity,
    this.lifetime,
    this.flickerPhase = 0.0,
    this.flickerSpeed = 1.0,
    this.runePulseFreq = 0.8,
    this.soulOrbitRadius = 35.0,
    this.soulOrbitSpeed = 0.9,
    this.initialExplosionRadius = 20.0,
  })  : currentPosition = position,
        currentColor = color,
        currentIntensity = intensity,
        currentRadius = radius,
        effectiveMinIntensity = minIntensity ?? (intensity * 0.65),
        effectiveMaxIntensity = maxIntensity ?? (intensity * 1.45),
        elapsedAge = 0.0;

  final String id;
  final LightType type;
  final Vector3D position;
  final Color color;
  final double intensity;
  final double radius;
  final FalloffType falloffType;
  final double shadowHardness;
  final double specularPower;
  final double maxWobbleRadius;
  final double? minIntensity;
  final double? maxIntensity;
  final double effectiveMinIntensity;
  final double effectiveMaxIntensity;
  final double? lifetime;
  final double flickerPhase;
  final double flickerSpeed;

  // Spell-specific parameters
  final double runePulseFreq;
  final double soulOrbitRadius;
  final double soulOrbitSpeed;
  final double initialExplosionRadius;

  // Mutable dynamic simulation state
  Vector3D currentPosition;
  Color currentColor;
  double currentIntensity;
  double currentRadius;
  double elapsedAge;

  bool get isExpired {
    if (lifetime == null) return false;
    return elapsedAge >= lifetime!;
  }

  double get normalizedLifeProgress {
    if (lifetime == null || lifetime! <= 0.0) return 0.0;
    return (elapsedAge / lifetime!).clamp(0.0, 1.0);
  }
}

/// Analytical calculations for attenuation, shadow penumbra, and ambient occlusion.
class LightingAttenuationEngine {
  const LightingAttenuationEngine._();

  /// Unreal Engine 4/5 windowed inverse-square attenuation.
  static double evaluateWindowedInverseSquare(double dist, double radius) {
    if (dist >= radius || radius <= 1e-5) return 0.0;
    final double norm = dist / radius;
    final double norm4 = norm * norm * norm * norm;
    final double window = (1.0 - norm4).clamp(0.0, 1.0);
    final double windowSq = window * window;
    return windowSq / (dist * dist + 1.0);
  }

  /// Hermite cubic smoothstep falloff.
  static double evaluateSmoothstepFalloff(double dist, double radius) {
    if (dist >= radius || radius <= 1e-5) return 0.0;
    final double t = (dist / radius).clamp(0.0, 1.0);
    final double smoothCutoff = 1.0 - t * t * (3.0 - 2.0 * t);
    return smoothCutoff / (dist + 1.0);
  }

  /// Linear falloff.
  static double evaluateLinearFalloff(double dist, double radius) {
    if (dist >= radius || radius <= 1e-5) return 0.0;
    return (1.0 - (dist / radius)).clamp(0.0, 1.0);
  }

  /// Evaluates distance falloff based on model.
  static double evaluateFalloff(double dist, double radius, FalloffType type) {
    switch (type) {
      case FalloffType.windowedInverseSquare:
        return evaluateWindowedInverseSquare(dist, radius);
      case FalloffType.smoothstep:
        return evaluateSmoothstepFalloff(dist, radius);
      case FalloffType.linear:
        return evaluateLinearFalloff(dist, radius);
    }
  }

  /// Evaluates 2D/3D shadow attenuation with soft penumbra.
  static double evaluateShadowAttenuation({
    required Vector3D fragPos,
    required Vector3D lightPos,
    required double lightRadius,
    required double shadowHardness,
    double shadowMask = 1.0,
    double shadowSoftness = 1.0,
  }) {
    if (shadowHardness <= 0.001) return 1.0;

    final double distToLight = fragPos.distanceTo(lightPos);
    if (distToLight >= lightRadius) return 0.0;

    final double penumbraScale = math.max(0.1, shadowSoftness * (1.0 - shadowHardness * 0.7));
    final double softShadow = (1.0 - shadowHardness) + shadowHardness * shadowMask;

    final double depthDiff = math.max(0.0, fragPos.z - lightPos.z);
    final double depthShadow = math.exp(-depthDiff * 0.15 * shadowHardness);

    final double radiusFactor = (1.0 - (distToLight / math.max(lightRadius, 1e-5))).clamp(0.0, 1.0);
    final double clampedNorm = (radiusFactor / penumbraScale).clamp(0.0, 1.0);
    final double penumbraMod = clampedNorm * clampedNorm * (3.0 - 2.0 * clampedNorm);

    return (softShadow * depthShadow * penumbraMod).clamp(0.0, 1.0);
  }

  /// Evaluates ambient light modulation by screen-space AO and cavity factor.
  static double evaluateAoModulation({
    required double aoRaw,
    required double aoModulation,
    double cavity = 1.0,
  }) {
    final double aoFactor = aoRaw.clamp(0.0, 1.0);
    final double aoPower = 1.0 + (2.2 - 1.0) * aoModulation.clamp(0.0, 1.0);
    double ambientAoMod = math.pow(aoFactor, aoPower).toDouble();

    if (cavity < 1.0) {
      final double cavityBlend = 1.0 + (cavity - 1.0) * (aoModulation * 0.7).clamp(0.0, 1.0);
      ambientAoMod *= cavityBlend;
    }
    return ambientAoMod.clamp(0.0, 1.0);
  }

  /// CPU-side analytical illumination calculation for a surface point.
  static Vector3D computeAnalyticalIllumination({
    required Vector3D surfacePos,
    required Vector3D surfaceNormal,
    required double surfaceAo,
    required Vector3D ambientColor,
    required double ambientIntensity,
    required List<DungeonLight> lights,
    required Vector3D cameraPos,
    double aoModulation = 1.0,
    double shadowSoftness = 1.0,
  }) {
    // 1. Ambient
    final double ambientAoMod = evaluateAoModulation(
      aoRaw: surfaceAo,
      aoModulation: aoModulation,
    );
    Vector3D accum = ambientColor * (ambientIntensity * ambientAoMod);

    final Vector3D viewDir = (cameraPos - surfacePos).normalized();

    // 2. Direct light accumulation
    for (final DungeonLight light in lights) {
      final double dist = surfacePos.distanceTo(light.currentPosition);
      if (dist >= light.currentRadius || light.currentRadius <= 0.0) continue;

      final double falloff = evaluateFalloff(dist, light.currentRadius, light.falloffType);
      final double shadow = evaluateShadowAttenuation(
        fragPos: surfacePos,
        lightPos: light.currentPosition,
        lightRadius: light.currentRadius,
        shadowHardness: light.shadowHardness,
        shadowSoftness: shadowSoftness,
      );

      final double directAo = 1.0 - (1.0 - surfaceAo) * (aoModulation * 0.4).clamp(0.0, 1.0);
      final Vector3D lightDir = (light.currentPosition - surfacePos).normalized();

      // Diffuse Lambertian
      final double nDotL = math.max(0.0, surfaceNormal.dot(lightDir));

      // Specular Blinn-Phong
      final Vector3D halfDir = (lightDir + viewDir).normalized();
      final double nDotH = math.max(0.0, surfaceNormal.dot(halfDir));
      final double spec = math.pow(nDotH, light.specularPower).toDouble();

      final double lightR = light.currentColor.r;
      final double lightG = light.currentColor.g;
      final double lightB = light.currentColor.b;
      final Vector3D lightRgb = Vector3D(lightR, lightG, lightB);

      final double flux = falloff * light.currentIntensity * shadow * directAo;
      final Vector3D diffuse = lightRgb * (nDotL * flux);
      final Vector3D specular = lightRgb * (spec * flux * 0.3);

      accum = accum + diffuse + specular;
    }

    return accum;
  }
}

/// Precise uniform layout indices and metadata matching `shaders/lighting/dungeon_lighting.frag`.
///
/// Total float count: 109 (indices 0..108).
/// Numeric uniforms layout:
/// - [0..1]:   vec2 uResolution
/// - [2]:      float uTime
/// - [3..5]:   vec3 uAmbientColor
/// - [6]:      float uAmbientIntensity
/// - [7]:      float uLightCount
/// - [8]:      float uAoModulation
/// - [9]:      float uShadowSoftness
/// - [10..12]: vec3 uCameraPos
/// - [13..44]: vec4 uLightPosRadius[8] (8 * 4 = 32 floats)
/// - [45..76]: vec4 uLightColorIntensity[8] (8 * 4 = 32 floats)
/// - [77..108]: vec4 uLightParams[8] (8 * 4 = 32 floats)
/// Sampler:
/// - Sampler index 0: uniform sampler2D uTexture (FragmentShader.setImageSampler(0, ...))
abstract final class DungeonLightingUniforms {
  /// Canonical shader asset path.
  static const String shaderAssetPath = 'shaders/lighting/dungeon_lighting.frag';

  // Global uniform float indices
  static const int indexResolution = 0;          // vec2: [0..1]
  static const int indexTime = 2;                // float: [2]
  static const int indexAmbientColor = 3;        // vec3: [3..5]
  static const int indexAmbientIntensity = 6;   // float: [6]
  static const int indexLightCount = 7;          // float: [7]
  static const int indexAoModulation = 8;        // float: [8]
  static const int indexShadowSoftness = 9;      // float: [9]
  static const int indexCameraPos = 10;          // vec3: [10..12]

  // Dynamic light array uniform float bases
  static const int indexLightPosRadius = 13;     // vec4[8]: [13..44]
  static const int indexLightColorIntensity = 45;// vec4[8]: [45..76]
  static const int indexLightParams = 77;        // vec4[8]: [77..108]

  // Dimensional metrics
  static const int globalFloatCount = 13;
  static const int maxLights = 8;
  static const int floatsPerLightVec4 = 4;
  static const int lightArrayCount = 3;          // posRadius, colorIntensity, params
  static const int floatsPerLightTotal = 12;     // 3 * 4 floats
  static const int lightArrayFloats = 96;        // 8 * 12 floats
  static const int floatCount = 109;             // 13 + 96 = 109 floats (indices 0..108)

  // Sampler index
  static const int samplerTexture = 0;           // uTexture
}

/// Central Production Dungeon Atmospheric Lighting & Dynamic Shadow System.
class DungeonLightSystem {
  DungeonLightSystem({
    this.maxLights = 8,
    this.ambientColor = const Color(0xFF101826), // Cold slate abyssal ambient
    this.ambientIntensity = 0.25,
    this.aoModulation = 1.0,
    this.shadowSoftness = 1.0,
    TorchFlickerEngine? flickerEngine,
  }) : flickerEngine = flickerEngine ?? TorchFlickerEngine();

  /// Maximum dynamic lights passed to GPU shader uniform array (default 8).
  final int maxLights;

  /// Global dungeon ambient color.
  Color ambientColor;

  /// Global dungeon ambient intensity multiplier.
  double ambientIntensity;

  /// Global screen-space ambient occlusion modulation factor.
  double aoModulation;

  /// Global shadow penumbra softness scale.
  double shadowSoftness;

  /// Torch flicker math simulation engine.
  final TorchFlickerEngine flickerEngine;

  final Map<String, DungeonLight> _lights = <String, DungeonLight>{};

  /// Read-only view of active lights.
  Iterable<DungeonLight> get lights => _lights.values;

  /// Active light count.
  int get lightCount => _lights.length;

  /// Adds a custom light entity to the simulation.
  void addLight(DungeonLight light) {
    _lights[light.id] = light;
  }

  /// Removes light by id.
  DungeonLight? removeLight(String id) {
    return _lights.remove(id);
  }

  /// Retrieves light by id.
  DungeonLight? getLight(String id) => _lights[id];

  /// Clears all dynamic lights.
  void clear() {
    _lights.clear();
  }

  // ---------------------------------------------------------------------------
  // Specialized Light Spawners
  // ---------------------------------------------------------------------------

  /// Spawns a procedural wall or standing torch with harmonic flicker & position wobble.
  DungeonLight addTorch({
    required String id,
    required Vector3D position,
    Color baseColor = const Color(0xFFFF9800), // Vibrant torch amber
    double baseIntensity = 1.8,
    double radius = 180.0,
    double maxWobbleRadius = 6.0,
    double flickerSpeed = 1.0,
    double? flickerPhase,
    double shadowHardness = 0.8,
  }) {
    final double phase = flickerPhase ?? (math.Random(id.hashCode).nextDouble() * 100.0);
    final DungeonLight torch = DungeonLight(
      id: id,
      type: LightType.torch,
      position: position,
      color: baseColor,
      intensity: baseIntensity,
      radius: radius,
      falloffType: FalloffType.windowedInverseSquare,
      shadowHardness: shadowHardness,
      maxWobbleRadius: maxWobbleRadius,
      flickerPhase: phase,
      flickerSpeed: flickerSpeed,
    );
    addLight(torch);
    return torch;
  }

  /// Casts a magical pulsing rune light with rhythmic breathing.
  DungeonLight castPulsingRune({
    required String id,
    required Vector3D position,
    Color runeColor = const Color(0xFF9C27B0), // Mystic violet
    double baseIntensity = 2.2,
    double radius = 140.0,
    double pulseFreq = 0.75,
    double? lifetime,
    double shadowHardness = 0.5,
  }) {
    final DungeonLight rune = DungeonLight(
      id: id,
      type: LightType.pulsingRune,
      position: position,
      color: runeColor,
      intensity: baseIntensity,
      radius: radius,
      falloffType: FalloffType.smoothstep,
      shadowHardness: shadowHardness,
      runePulseFreq: pulseFreq,
      lifetime: lifetime,
    );
    addLight(rune);
    return rune;
  }

  /// Casts a high-energy fiery explosion blast with shockwave expansion and blackbody decay.
  DungeonLight castFieryExplosion({
    required String id,
    required Vector3D position,
    double peakIntensity = 6.0,
    double maxRadius = 320.0,
    double duration = 1.0,
    Color coreColor = const Color(0xFFFFEB3B), // White-yellow core
    double shadowHardness = 0.9,
  }) {
    final DungeonLight explosion = DungeonLight(
      id: id,
      type: LightType.fieryExplosion,
      position: position,
      color: coreColor,
      intensity: peakIntensity,
      radius: maxRadius,
      initialExplosionRadius: maxRadius * 0.25,
      falloffType: FalloffType.windowedInverseSquare,
      shadowHardness: shadowHardness,
      lifetime: duration,
    );
    addLight(explosion);
    return explosion;
  }

  /// Spawns a floating ethereal soul orb with 3D harmonic orbit trajectory.
  DungeonLight castEtherealSoul({
    required String id,
    required Vector3D origin,
    Color spectralColor = const Color(0xFF00E5FF), // Phantom cyan
    double intensity = 1.6,
    double radius = 150.0,
    double orbitRadius = 40.0,
    double orbitSpeed = 0.85,
    double? lifetime,
    double shadowHardness = 0.4,
  }) {
    final DungeonLight soul = DungeonLight(
      id: id,
      type: LightType.etherealSoul,
      position: origin,
      color: spectralColor,
      intensity: intensity,
      radius: radius,
      falloffType: FalloffType.smoothstep,
      shadowHardness: shadowHardness,
      soulOrbitRadius: orbitRadius,
      soulOrbitSpeed: orbitSpeed,
      lifetime: lifetime,
    );
    addLight(soul);
    return soul;
  }

  /// Spawns a directional spot light with downward conic beam matching GLSL Type 5.0.
  DungeonLight addSpotLight({
    required String id,
    required Vector3D position,
    Color color = const Color(0xFFFFF8E7), // Warm halogen/sunbeam
    double intensity = 2.5,
    double radius = 220.0,
    double shadowHardness = 0.85,
    double specularPower = 48.0,
  }) {
    final DungeonLight spot = DungeonLight(
      id: id,
      type: LightType.spot,
      position: position,
      color: color,
      intensity: intensity,
      radius: radius,
      falloffType: FalloffType.windowedInverseSquare,
      shadowHardness: shadowHardness,
      specularPower: specularPower,
    );
    addLight(spot);
    return spot;
  }

  // ---------------------------------------------------------------------------
  // Simulation Update Loop
  // ---------------------------------------------------------------------------

  /// Advances all dynamic lights by [dt] seconds at global time [time].
  void update(double dt, {double? currentTime}) {
    final double now = currentTime ?? dt;
    final List<String> toRemove = <String>[];

    for (final DungeonLight light in _lights.values) {
      light.elapsedAge += dt;

      if (light.isExpired) {
        toRemove.add(light.id);
        continue;
      }

      switch (light.type) {
        case LightType.torch:
          _updateTorchLight(light, now);
          break;

        case LightType.pulsingRune:
          _updatePulsingRuneLight(light, now);
          break;

        case LightType.fieryExplosion:
          _updateFieryExplosionLight(light);
          break;

        case LightType.etherealSoul:
          _updateEtherealSoulLight(light, now);
          break;

        case LightType.point:
        case LightType.spot:
          // Point and spot lights maintain static properties unless externally modified
          break;
      }
    }

    for (final String id in toRemove) {
      _lights.remove(id);
    }
  }

  void _updateTorchLight(DungeonLight light, double time) {
    final TorchFlickerSample sample = flickerEngine.evaluate(
      t: time,
      baseIntensity: light.intensity,
      minIntensity: light.effectiveMinIntensity,
      maxIntensity: light.effectiveMaxIntensity,
      maxWobbleRadius: light.maxWobbleRadius,
      baseColor: light.color,
      phase: light.flickerPhase,
      wobbleSpeed: light.flickerSpeed,
    );

    light.currentIntensity = sample.intensity;
    light.currentPosition = light.position + sample.positionOffset;
    light.currentColor = sample.colorTint;
  }

  void _updatePulsingRuneLight(DungeonLight light, double time) {
    final double theta = 2.0 * math.pi * light.runePulseFreq * (time + light.flickerPhase);
    // Non-linear pulse wave: sharp runic flash with gentle dwell
    final double rawSine = math.sin(theta);
    final double pulse = rawSine * rawSine * rawSine * 0.5 + 0.5;

    // Intensity oscillates between 60% and 130%
    light.currentIntensity = light.intensity * (0.6 + pulse * 0.7);

    // Subtle radius breathing
    light.currentRadius = light.radius * (0.85 + pulse * 0.25);

    // Chromatic runic aura shift between core violet and cyan rim
    final Color coreViolet = light.color;
    final Color cyanAura = const Color(0xFF00E5FF);
    light.currentColor = TorchFlickerEngine._lerpColor(coreViolet, cyanAura, pulse * 0.65);
  }

  void _updateFieryExplosionLight(DungeonLight light) {
    final double p = light.normalizedLifeProgress; // 0.0 -> 1.0

    // Explosion attack / decay envelope:
    // Fast rise to peak flare in first 15%, followed by exponential decay
    const double attackRatio = 0.15;
    double intensityFactor;
    if (p < attackRatio) {
      final double t = p / attackRatio;
      intensityFactor = 1.0 + (light.intensity - 1.0) * (t * t);
    } else {
      final double t = (p - attackRatio) / (1.0 - attackRatio);
      // Exponential / quadratic decay
      intensityFactor = light.intensity * math.exp(-3.5 * t);
    }
    light.currentIntensity = math.max(0.0, intensityFactor);

    // Shockwave expansion: rapid expansion in first half, stabilizing in second
    final double radiusCurve = 1.0 - math.pow(1.0 - p, 2.5).toDouble();
    light.currentRadius = light.initialExplosionRadius +
        (light.radius - light.initialExplosionRadius) * radiusCurve;

    // Blackbody thermal color cooling:
    // White-hot (p=0.0) -> Golden yellow -> Flame orange -> Deep charcoal red (p=1.0)
    final Color whiteHot = const Color(0xFFFFFFFF);
    final Color flameYellow = const Color(0xFFFFD54F);
    final Color flameOrange = const Color(0xFFFF6D00);
    final Color darkEmber = const Color(0xFF8B0000);

    Color currentRgb;
    if (p < 0.2) {
      currentRgb = TorchFlickerEngine._lerpColor(whiteHot, flameYellow, p / 0.2);
    } else if (p < 0.6) {
      currentRgb = TorchFlickerEngine._lerpColor(flameYellow, flameOrange, (p - 0.2) / 0.4);
    } else {
      currentRgb = TorchFlickerEngine._lerpColor(flameOrange, darkEmber, (p - 0.6) / 0.4);
    }
    light.currentColor = currentRgb;
  }

  void _updateEtherealSoulLight(DungeonLight light, double time) {
    final double t = time * light.soulOrbitSpeed + light.flickerPhase;

    // 3D Lissajous wandering trajectory
    // Frequencies with non-integer ratio (1.0, 1.414, 0.707) produce organic wandering
    final double ox = math.sin(t) * light.soulOrbitRadius;
    final double oy = math.cos(t * 1.414) * (light.soulOrbitRadius * 0.75);
    final double oz = math.sin(t * 0.707) * (light.soulOrbitRadius * 0.35);

    light.currentPosition = light.position + Vector3D(ox, oy, oz);

    // Whispering luminosity modulation
    final double shimmer = math.sin(t * 3.8) * 0.15 + math.cos(t * 6.2) * 0.08;
    light.currentIntensity = math.max(0.1, light.intensity * (1.0 + shimmer));
  }

  // ---------------------------------------------------------------------------
  // GPU Multi-Light Buffer Packing & Priority Culling
  // ---------------------------------------------------------------------------

  /// Selects the top [maxLights] most impactful lights relative to [cameraPos].
  /// Perceptual impact metric: (Intensity * Radius^2) / max(1.0, DistanceSquared).
  List<DungeonLight> selectTopActiveLights(Vector3D cameraPos) {
    final List<DungeonLight> active = _lights.values.toList();
    if (active.length <= maxLights) {
      return active;
    }

    active.sort((DungeonLight a, DungeonLight b) {
      final double distSqA = cameraPos.distanceSquaredTo(a.currentPosition);
      final double distSqB = cameraPos.distanceSquaredTo(b.currentPosition);

      final double impactA = (a.currentIntensity * a.currentRadius * a.currentRadius) / math.max(1.0, distSqA);
      final double impactB = (b.currentIntensity * b.currentRadius * b.currentRadius) / math.max(1.0, distSqB);

      return impactB.compareTo(impactA); // Descending
    });

    return active.take(maxLights).toList();
  }

  /// Builds a continuous Float32List uniform buffer matching `dungeon_lighting.frag` exactly.
  ///
  /// Uniform Layout:
  /// - [0..1]:   vec2 uResolution
  /// - [2]:      float uTime
  /// - [3..5]:   vec3 uAmbientColor
  /// - [6]:      float uAmbientIntensity
  /// - [7]:      float uLightCount
  /// - [8]:      float uAoModulation
  /// - [9]:      float uShadowSoftness
  /// - [10..12]: vec3 uCameraPos
  /// - [13..44]: vec4 uLightPosRadius[8] (8 * 4 = 32 floats)
  /// - [45..76]: vec4 uLightColorIntensity[8] (8 * 4 = 32 floats)
  /// - [77..108]: vec4 uLightParams[8] (8 * 4 = 32 floats)
  /// Total: 109 floats.
  Float32List buildUniformBuffer({
    required Size resolution,
    required Vector3D cameraPos,
    double time = 0.0,
  }) {
    final Float32List buffer = Float32List(DungeonLightingUniforms.floatCount);

    // Global uniforms: indices 0..12
    buffer[DungeonLightingUniforms.indexResolution + 0] = resolution.width;
    buffer[DungeonLightingUniforms.indexResolution + 1] = resolution.height;
    buffer[DungeonLightingUniforms.indexTime] = time;

    buffer[DungeonLightingUniforms.indexAmbientColor + 0] = ambientColor.r;
    buffer[DungeonLightingUniforms.indexAmbientColor + 1] = ambientColor.g;
    buffer[DungeonLightingUniforms.indexAmbientColor + 2] = ambientColor.b;
    buffer[DungeonLightingUniforms.indexAmbientIntensity] = ambientIntensity;

    final List<DungeonLight> selectedLights = selectTopActiveLights(cameraPos);
    final int activeCount = selectedLights.length;
    buffer[DungeonLightingUniforms.indexLightCount] = activeCount.toDouble();

    buffer[DungeonLightingUniforms.indexAoModulation] = aoModulation;
    buffer[DungeonLightingUniforms.indexShadowSoftness] = shadowSoftness;

    buffer[DungeonLightingUniforms.indexCameraPos + 0] = cameraPos.x;
    buffer[DungeonLightingUniforms.indexCameraPos + 1] = cameraPos.y;
    buffer[DungeonLightingUniforms.indexCameraPos + 2] = cameraPos.z;

    // Per-light uniform arrays (8 lights * 4 floats each = 32 floats per array):
    // uLightPosRadius:          [13..44]
    // uLightColorIntensity:     [45..76]
    // uLightParams:             [77..108]
    const int posRadiusBase = DungeonLightingUniforms.indexLightPosRadius;
    const int colorIntensityBase = DungeonLightingUniforms.indexLightColorIntensity;
    const int paramsBase = DungeonLightingUniforms.indexLightParams;

    for (int i = 0; i < DungeonLightingUniforms.maxLights; ++i) {
      final int posOffset = posRadiusBase + i * DungeonLightingUniforms.floatsPerLightVec4;
      final int colOffset = colorIntensityBase + i * DungeonLightingUniforms.floatsPerLightVec4;
      final int parOffset = paramsBase + i * DungeonLightingUniforms.floatsPerLightVec4;

      if (i < activeCount) {
        final DungeonLight light = selectedLights[i];

        // uLightPosRadius[i] = vec4(x, y, z, radius)
        buffer[posOffset + 0] = light.currentPosition.x;
        buffer[posOffset + 1] = light.currentPosition.y;
        buffer[posOffset + 2] = light.currentPosition.z;
        buffer[posOffset + 3] = light.currentRadius;

        // uLightColorIntensity[i] = vec4(r, g, b, intensity)
        buffer[colOffset + 0] = light.currentColor.r;
        buffer[colOffset + 1] = light.currentColor.g;
        buffer[colOffset + 2] = light.currentColor.b;
        buffer[colOffset + 3] = light.currentIntensity;

        // uLightParams[i] = vec4(lightType, falloffType, shadowHardness, specularPower)
        buffer[parOffset + 0] = light.type.shaderValue;
        buffer[parOffset + 1] = light.falloffType.shaderValue;
        buffer[parOffset + 2] = light.shadowHardness;
        buffer[parOffset + 3] = light.specularPower;
      } else {
        // Zero-fill unused light slots
        buffer[posOffset + 0] = 0.0;
        buffer[posOffset + 1] = 0.0;
        buffer[posOffset + 2] = 0.0;
        buffer[posOffset + 3] = 0.0;

        buffer[colOffset + 0] = 0.0;
        buffer[colOffset + 1] = 0.0;
        buffer[colOffset + 2] = 0.0;
        buffer[colOffset + 3] = 0.0;

        buffer[parOffset + 0] = 0.0;
        buffer[parOffset + 1] = 0.0;
        buffer[parOffset + 2] = 0.0;
        buffer[parOffset + 3] = 0.0;
      }
    }

    return buffer;
  }

  /// Sets all 109 uniform floats and optional texture sampler onto a Flutter [FragmentShader] instance.
  void applyToShader(
    FragmentShader shader, {
    required Size resolution,
    required Vector3D cameraPos,
    double time = 0.0,
    Image? texture,
  }) {
    final Float32List buffer = buildUniformBuffer(
      resolution: resolution,
      cameraPos: cameraPos,
      time: time,
    );
    for (int i = 0; i < buffer.length; ++i) {
      shader.setFloat(i, buffer[i]);
    }
    if (texture != null) {
      shader.setImageSampler(DungeonLightingUniforms.samplerTexture, texture);
    }
  }
}
