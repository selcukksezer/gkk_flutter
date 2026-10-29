import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

import '../engine/adaptive_quality_scaler.dart';
import '../engine/zero_jank_preloader.dart';
import '../../screens/settings/graphics_settings_service.dart';

// -----------------------------------------------------------------------------
// Production AAA Open World / Hub: Screen-Space Reflections (SSR) &
// Planar Puddle Reflections Shader Pipeline (R2)
// Compatible with Flutter RuntimeEffect, Impeller, and Skia Pipelines
// -----------------------------------------------------------------------------

/// Immutable 3D vector for camera, normal, and light calculations in world space.
class WorldVector3 {
  const WorldVector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const WorldVector3 zero = WorldVector3(0.0, 0.0, 0.0);
  static const WorldVector3 unitX = WorldVector3(1.0, 0.0, 0.0);
  static const WorldVector3 unitY = WorldVector3(0.0, 1.0, 0.0);
  static const WorldVector3 unitZ = WorldVector3(0.0, 0.0, 1.0);
  static const WorldVector3 up = WorldVector3(0.0, 0.0, 1.0);
  static const WorldVector3 right = WorldVector3(1.0, 0.0, 0.0);
  static const WorldVector3 forward = WorldVector3(0.0, 0.0, -1.0);

  WorldVector3 operator +(WorldVector3 other) =>
      WorldVector3(x + other.x, y + other.y, z + other.z);

  WorldVector3 operator -(WorldVector3 other) =>
      WorldVector3(x - other.x, y - other.y, z - other.z);

  WorldVector3 operator -() => WorldVector3(-x, -y, -z);

  WorldVector3 operator *(double scalar) =>
      WorldVector3(x * scalar, y * scalar, z * scalar);

  WorldVector3 operator /(double scalar) =>
      WorldVector3(x / scalar, y / scalar, z / scalar);

  double dot(WorldVector3 other) => x * other.x + y * other.y + z * other.z;

  WorldVector3 cross(WorldVector3 other) => WorldVector3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  double get lengthSquared => x * x + y * y + z * z;

  double get length => math.sqrt(lengthSquared);

  WorldVector3 get normalized {
    final double len = length;
    if (len < 1e-9) {
      return WorldVector3.up;
    }
    return WorldVector3(x / len, y / len, z / len);
  }

  /// Reflects this incoming vector across a unit normal [n].
  /// Formula: R = I - 2 * (I . N) * N
  WorldVector3 reflect(WorldVector3 n) {
    final double d = dot(n);
    return this - (n * (2.0 * d));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorldVector3 &&
          (x - other.x).abs() < 1e-6 &&
          (y - other.y).abs() < 1e-6 &&
          (z - other.z).abs() < 1e-6;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() =>
      'WorldVector3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

// -----------------------------------------------------------------------------
// 1. Schlick's Fresnel Approximation Model
// -----------------------------------------------------------------------------

/// Analytical Schlick's Fresnel reflection coefficient calculator.
///
/// Modulates specular reflection intensity by view incidence angle:
/// F(theta) = F0 + (max(1 - roughness, F0) - F0) * (1 - cos(theta))^5
class SchlickFresnel {
  SchlickFresnel._();

  /// Standard normal-incidence reflectance F0 for air-to-water interface.
  /// (n1 = 1.000293, n2 = 1.333) -> ((n1 - n2) / (n1 + n2))^2 ~= 0.0204
  static const double waterF0 = 0.0204;

  /// Pure glass / quartz normal reflectance F0.
  static const double glassF0 = 0.0400;

  /// Computes the exact Fresnel reflection factor for a given cosine of incident angle.
  ///
  /// - [cosTheta]: The dot product (N . V) clamped to [0.0, 1.0].
  /// - [f0]: Normal incidence reflectance (typically 0.02 for water).
  /// - [roughness]: Surface micro-roughness [0.0 = smooth mirror, 1.0 = matte].
  static double evaluate({
    required double cosTheta,
    double f0 = waterF0,
    double roughness = 0.0,
  }) {
    final double clampedCos = cosTheta.clamp(0.0, 1.0);
    final double clampedF0 = f0.clamp(0.0, 1.0);
    final double clampedRoughness = roughness.clamp(0.0, 1.0);

    final double oneMinusCos = 1.0 - clampedCos;
    final double oneMinusCos5 = oneMinusCos *
        oneMinusCos *
        oneMinusCos *
        oneMinusCos *
        oneMinusCos;

    final double maxReflectance = math.max(1.0 - clampedRoughness, clampedF0);
    return clampedF0 + (maxReflectance - clampedF0) * oneMinusCos5;
  }

  /// Calculates F0 from refractive indices of medium 1 [n1] and medium 2 [n2].
  static double calculateF0({required double n1, required double n2}) {
    if ((n1 + n2).abs() < 1e-9) return waterF0;
    final double ratio = (n1 - n2) / (n1 + n2);
    return (ratio * ratio).clamp(0.0, 1.0);
  }
}

// -----------------------------------------------------------------------------
// 2. Dual-Octave Gerstner Wave Math
// -----------------------------------------------------------------------------

/// Parameter descriptor for an individual directional Gerstner wave octave.
class GerstnerWaveOctave {
  const GerstnerWaveOctave({
    required this.direction,
    required this.waveLength,
    required this.amplitude,
    required this.speed,
    this.steepness = 0.5,
  });

  /// Propagation direction in 2D horizontal plane (normalized).
  final ui.Offset direction;

  /// Spatial wavelength in world units (meters/pixels).
  final double waveLength;

  /// Crest-to-trough vertical wave amplitude.
  final double amplitude;

  /// Wave phase speed multiplier.
  final double speed;

  /// Gerstner crest sharpness / trochoid factor Q in [0.0, 1.0].
  final double steepness;

  /// Spatial frequency k = 2 * pi / wavelength.
  double get waveNumber => (2.0 * math.pi) / math.max(waveLength, 0.001);

  /// Angular frequency omega = sqrt(g * k) (gravity dispersion relation).
  double get angularFrequency => math.sqrt(9.81 * waveNumber) * speed;
}

/// Analytical dual-octave Gerstner wave surface calculator mirroring GLSL shader.
class GerstnerWaveMath {
  GerstnerWaveMath._();

  /// Default Octave 1: Primary wind chop wave.
  static const GerstnerWaveOctave defaultOctave1 = GerstnerWaveOctave(
    direction: ui.Offset(0.7071068, 0.7071068),
    waveLength: 0.314159, // k = 20.0
    amplitude: 0.015,
    speed: 2.4,
    steepness: 0.5,
  );

  /// Default Octave 2: Cross-wind secondary capillary wave.
  static const GerstnerWaveOctave defaultOctave2 = GerstnerWaveOctave(
    direction: ui.Offset(-0.8, 0.6),
    waveLength: 0.149599, // k = 42.0
    amplitude: 0.008,
    speed: 3.8,
    steepness: 0.4,
  );

  /// Evaluates surface normal vector perturbation for dual-octave Gerstner waves.
  ///
  /// Returns a normalized [WorldVector3] tangent-space normal (Z is up).
  static WorldVector3 evaluateNormal({
    required ui.Offset uv,
    required double time,
    double intensity = 1.0,
    double rippleSpeed = 1.0,
    GerstnerWaveOctave octave1 = defaultOctave1,
    GerstnerWaveOctave octave2 = defaultOctave2,
  }) {
    if (intensity <= 1e-4) {
      return WorldVector3.up;
    }

    // Octave 1
    final double k1 = octave1.waveNumber;
    final double w1 = octave1.speed * rippleSpeed;
    final double a1 = octave1.amplitude * intensity;
    final double phase1 = (octave1.direction.dx * uv.dx + octave1.direction.dy * uv.dy) * k1 - time * w1;
    final double cos1 = math.cos(phase1);
    final double sin1 = math.sin(phase1);

    // Octave 2
    final double k2 = octave2.waveNumber;
    final double w2 = octave2.speed * rippleSpeed;
    final double a2 = octave2.amplitude * intensity;
    final double phase2 = (octave2.direction.dx * uv.dx + octave2.direction.dy * uv.dy) * k2 - time * w2;
    final double cos2 = math.cos(phase2);
    final double sin2 = math.sin(phase2);

    final double nx = -(octave1.direction.dx * k1 * a1 * cos1 + octave2.direction.dx * k2 * a2 * cos2);
    final double ny = -(octave1.direction.dy * k1 * a1 * cos1 + octave2.direction.dy * k2 * a2 * cos2);
    final double nz = 1.0 - (octave1.steepness * k1 * a1 * sin1 + octave2.steepness * k2 * a2 * sin2);

    return WorldVector3(nx, ny, math.max(nz, 0.1)).normalized;
  }

  /// Evaluates surface height elevation displacement z at [uv].
  static double evaluateHeight({
    required ui.Offset uv,
    required double time,
    double intensity = 1.0,
    double rippleSpeed = 1.0,
    GerstnerWaveOctave octave1 = defaultOctave1,
    GerstnerWaveOctave octave2 = defaultOctave2,
  }) {
    if (intensity <= 1e-4) return 0.0;

    final double k1 = octave1.waveNumber;
    final double w1 = octave1.speed * rippleSpeed;
    final double a1 = octave1.amplitude * intensity;
    final double phase1 = (octave1.direction.dx * uv.dx + octave1.direction.dy * uv.dy) * k1 - time * w1;

    final double k2 = octave2.waveNumber;
    final double w2 = octave2.speed * rippleSpeed;
    final double a2 = octave2.amplitude * intensity;
    final double phase2 = (octave2.direction.dx * uv.dx + octave2.direction.dy * uv.dy) * k2 - time * w2;

    return a1 * math.sin(phase1) + a2 * math.sin(phase2);
  }
}

// -----------------------------------------------------------------------------
// 3. Dual-Octave Voronoi Rain Ripple Math
// -----------------------------------------------------------------------------

/// Analytical procedural hash functions matching GLSL shader.
class VoronoiRippleMath {
  VoronoiRippleMath._();

  static double _fract(double v) => v - v.floorToDouble();

  /// 2D to 1D pseudo-random hash matching GLSL hash12(p).
  static double hash12(ui.Offset p) {
    final double px = _fract(p.dx * 0.1031);
    final double py = _fract(p.dy * 0.1031);
    final double pz = _fract(p.dx * 0.1031);

    final double dotVal = px * (py + 33.33) + py * (pz + 33.33) + pz * (px + 33.33);
    final double x = px + dotVal;
    final double y = py + dotVal;
    final double z = pz + dotVal;
    return _fract((x + y) * z);
  }

  /// 2D to 2D pseudo-random hash matching GLSL hash22(p).
  static ui.Offset hash22(ui.Offset p) {
    final double px = _fract(p.dx * 0.1031);
    final double py = _fract(p.dy * 0.1030);
    final double pz = _fract(p.dx * 0.0973);

    final double dotVal = px * (py + 33.33) + py * (pz + 33.33) + pz * (px + 33.33);
    final double x = px + dotVal;
    final double y = py + dotVal;
    final double z = pz + dotVal;

    final double outX = _fract(x * y);
    final double outY = _fract(z * y);
    return ui.Offset(outX, outY);
  }

  /// Evaluates an individual Voronoi rain ripple octave at [uv].
  ///
  /// Returns a [WorldVector3] where (x, y) is normal offset and z is wave amplitude.
  static WorldVector3 evaluateOctave({
    required ui.Offset uv,
    required double time,
    required double speed,
    required double gridScale,
    required double waveFreq,
    required double maxRadius,
  }) {
    final double px = uv.dx * gridScale;
    final double py = uv.dy * gridScale;

    final int cellX = px.floor();
    final int cellY = py.floor();

    final double fracX = px - cellX;
    final double fracY = py - cellY;

    double normalDx = 0.0;
    double normalDy = 0.0;
    double totalHeight = 0.0;

    for (int y = -1; y <= 1; y++) {
      for (int x = -1; x <= 1; x++) {
        final ui.Offset neighbor = ui.Offset(x.toDouble(), y.toDouble());
        final ui.Offset cellCoord = ui.Offset(cellX + neighbor.dx, cellY + neighbor.dy);

        final ui.Offset rnd = hash22(cellCoord);
        final ui.Offset dropCenter = ui.Offset(rnd.dx * 0.8 + 0.1, rnd.dy * 0.8 + 0.1);
        final double dropSeed = hash12(cellCoord);

        final double dropAge = _fract(time * speed + dropSeed);

        final double diffX = fracX - (neighbor.dx + dropCenter.dx);
        final double diffY = fracY - (neighbor.dy + dropCenter.dy);
        final double dist = math.sqrt(diffX * diffX + diffY * diffY);

        final double frontRadius = dropAge * maxRadius;
        final double distToFront = dist - frontRadius;

        final double wave = math.sin(2.0 * math.pi * (waveFreq * distToFront - dropAge * 4.0));
        final double edge = (0.18 - distToFront.abs()) / 0.18;
        final double smooth = edge.clamp(0.0, 1.0);
        final double envelope = math.exp(-4.0 * dropAge) * (smooth * smooth * (3.0 - 2.0 * smooth));

        final double rippleAmp = wave * envelope;
        totalHeight += rippleAmp;

        if (dist > 0.001) {
          final double dirX = diffX / dist;
          final double dirY = diffY / dist;
          final double ageFactor = 1.0 - dropAge;
          normalDx += dirX * rippleAmp * ageFactor;
          normalDy += dirY * rippleAmp * ageFactor;
        }
      }
    }

    return WorldVector3(normalDx, normalDy, totalHeight);
  }

  /// Evaluates the complete dual-octave Voronoi rain ripple perturbation.
  static WorldVector3 evaluateDualOctave({
    required ui.Offset uv,
    required double time,
    required double speed,
    required double intensity,
  }) {
    if (intensity <= 1e-4) {
      return WorldVector3.zero;
    }

    // Octave 1: Major raindrops
    final WorldVector3 oct1 = evaluateOctave(
      uv: uv,
      time: time,
      speed: speed * 0.85,
      gridScale: 4.5,
      waveFreq: 3.0,
      maxRadius: 0.75,
    );

    // Octave 2: Fine rain mist / micro-droplets
    final WorldVector3 oct2 = evaluateOctave(
      uv: ui.Offset(uv.dx + 0.37, uv.dy + 0.63),
      time: time * 1.3,
      speed: speed * 1.25,
      gridScale: 9.0,
      waveFreq: 5.0,
      maxRadius: 0.55,
    );

    final double nx = (oct1.x * 0.65 + oct2.x * 0.35) * intensity;
    final double ny = (oct1.y * 0.65 + oct2.y * 0.35) * intensity;
    final double nz = (oct1.z * 0.65 + oct2.z * 0.35) * intensity;

    return WorldVector3(nx, ny, nz);
  }
}

// -----------------------------------------------------------------------------
// 4. Screen-Space Reflections (SSR) & Planar Raymarch Math
// -----------------------------------------------------------------------------

/// Analytical SSR Raymarch stepping and planar reflection mapping engine.
class SSRRaymarchMath {
  SSRRaymarchMath._();

  /// Calculates the inverted planar reflection UV coordinates across water plane [planeY].
  static ui.Offset calculatePlanarUV({
    required ui.Offset uv,
    required double planeY,
    ui.Offset normalPerturbation = ui.Offset.zero,
    double roughness = 0.0,
  }) {
    final double mirroredY = 2.0 * planeY - uv.dy;
    final double jitterX = normalPerturbation.dx * (0.02 + roughness * 0.03);
    final double jitterY = normalPerturbation.dy * (0.02 + roughness * 0.03);

    return ui.Offset(
      (uv.dx + jitterX).clamp(0.001, 0.999),
      (mirroredY + jitterY).clamp(0.001, 0.999),
    );
  }

  /// Calculates screen edge attenuation factor to prevent reflection boundary popping.
  static double calculateEdgeFade({
    required ui.Offset uv,
    double margin = 0.08,
  }) {
    if (margin <= 1e-4) return 1.0;

    final double distLeft = uv.dx;
    final double distRight = 1.0 - uv.dx;
    final double distTop = uv.dy;
    final double distBottom = 1.0 - uv.dy;

    final double minDist = math.min(
      math.min(distLeft, distRight),
      math.min(distTop, distBottom),
    );

    final double t = (minDist / margin).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t); // smoothstep
  }

  /// Simulates SSR linear raymarching along screen reflection trajectory.
  ///
  /// Returns a list of sampled UV points along the ray trajectory until
  /// max steps reached or boundary exited.
  static List<ui.Offset> marchRayPath({
    required ui.Offset startUV,
    required ui.Offset screenReflectDir,
    required double stepSize,
    required int maxSteps,
  }) {
    final List<ui.Offset> path = <ui.Offset>[];
    ui.Offset current = startUV;

    final double dirLen = math.sqrt(
      screenReflectDir.dx * screenReflectDir.dx +
          screenReflectDir.dy * screenReflectDir.dy,
    );
    final ui.Offset normDir = dirLen > 1e-6
        ? ui.Offset(screenReflectDir.dx / dirLen, screenReflectDir.dy / dirLen)
        : const ui.Offset(0.0, -1.0);

    final ui.Offset stepVector = ui.Offset(normDir.dx * stepSize, normDir.dy * stepSize);

    for (int i = 1; i <= maxSteps; i++) {
      current = ui.Offset(current.dx + stepVector.dx, current.dy + stepVector.dy);

      if (current.dx < 0.0 || current.dx > 1.0 || current.dy < 0.0 || current.dy > 1.0) {
        break;
      }

      path.add(current);
    }

    return path;
  }

  /// Beer-Lambert water extinction transmittance factor:
  /// T = exp(-extinction * depth)
  static double calculateBeerLambertTransmittance({
    required double waterDepth,
    required double extinctionCoeff,
    double depthScale = 1.0,
  }) {
    final double effectiveDepth = math.max(waterDepth * depthScale, 0.0);
    final double sigma = math.max(extinctionCoeff, 0.05);
    return math.exp(-sigma * effectiveDepth * 3.5).clamp(0.0, 1.0);
  }
}

// -----------------------------------------------------------------------------
// 5. Configuration & Presets
// -----------------------------------------------------------------------------

/// Configuration data class for the Puddle SSR shader uniforms and visual tuning.
class PuddleReflectionConfig {
  const PuddleReflectionConfig({
    this.rainIntensity = 0.5,
    this.rippleSpeed = 1.0,
    this.puddleRoughness = 0.04,
    this.reflectivity = 1.0,
    this.fresnelR0 = SchlickFresnel.waterF0,
    this.waterDepthScale = 1.0,
    this.waterColor = const ui.Color(0x33103045), // Deep aquatic blue-gray with absorption
    this.mudColor = const ui.Color(0x882A1E14),   // Muddy silt basin bed
    this.maxRaySteps = 24.0,
    this.rayStepSize = 0.025,
    this.planarReflectionHeight = 0.65,
    this.edgeFadeMargin = 0.08,
    this.cameraPosition = const WorldVector3(0.0, 1.8, 3.5),
    this.cameraDirection = const WorldVector3(0.0, -0.35, -0.93),
    this.hardwareTier,
    this.throttleLevel = 0,
    this.renderResolutionScale = 1.0,
    this.bypassRaymarching = false,
    this.bypassRippleAnimation = false,
    this.isStaticDarkWater = false,
    this.periodicRippleInterval = 0.0,
    this.enableSpecularHighlights = true,
  });

  /// Rain precipitation intensity factor [0.0 = clear/calm, 1.0 = heavy storm].
  final double rainIntensity;

  /// Temporal speed multiplier for ripple propagation and wind chop.
  final double rippleSpeed;

  /// Surface micro-facet roughness [0.0 = mirror, 1.0 = matte/diffuse].
  final double puddleRoughness;

  /// Reflection brightness multiplier [0.0 - 2.0].
  final double reflectivity;

  /// Schlick Fresnel F0 normal reflectance (water ≈ 0.0204).
  final double fresnelR0;

  /// Water volume extinction scaling factor for Beer-Lambert absorption.
  final double waterDepthScale;

  /// Aquatic body color (RGB) and absorption alpha (A).
  final ui.Color waterColor;

  /// Silt / muddy basin bottom color (RGB) and edge ground mix (A).
  final ui.Color mudColor;

  /// Maximum raymarching step iterations (e.g. 16.0 - 32.0).
  final double maxRaySteps;

  /// UV stride distance per raymarch step.
  final double rayStepSize;

  /// Water surface plane Y level in normalized viewport space [0.0 - 1.0].
  final double planarReflectionHeight;

  /// Margin for fading screen edge reflections to prevent popping.
  final double edgeFadeMargin;

  /// 3D camera position in world/view space.
  final WorldVector3 cameraPosition;

  /// Normalized camera forward viewing direction.
  final WorldVector3 cameraDirection;

  /// Target hardware tier determined by [AdaptiveQualityScaler].
  final HardwareTier? hardwareTier;

  /// Dynamic runtime throttle level (0 = baseline, 1 = light, 2 = medium, 3 = severe).
  final int throttleLevel;

  /// Internal render resolution scale multiplier [0.5 to 1.0].
  final double renderResolutionScale;

  /// Whether raymarched SSR reflections are bypassed (Eco/Low tiers).
  final bool bypassRaymarching;

  /// Whether dynamic water ripple animation loops are bypassed (Eco/Low tiers).
  final bool bypassRippleAnimation;

  /// Whether static dark water tint is rendered to protect frame pacing.
  final bool isStaticDarkWater;

  /// Interval in seconds for periodic ripple updates (0.0 = continuous, 0.033 = 30Hz periodic).
  final double periodicRippleInterval;

  /// Whether specular puddle reflection highlights are enabled (Ultra tier).
  final bool enableSpecularHighlights;

  /// Derives tier-tailored configuration using [AdaptiveQualityScaler] metrics.
  factory PuddleReflectionConfig.fromScaler(
    AdaptiveQualityScaler scaler, {
    PuddleReflectionConfig? base,
  }) {
    return PuddleReflectionConfig.fromTierAndThrottle(
      tier: scaler.currentTier,
      throttleLevel: scaler.currentThrottleLevel,
      renderResolutionScale: scaler.currentResolutionScale,
      base: base,
    );
  }

  /// Configures tier-tailored graphics settings adhering to mobile hardware constraints.
  factory PuddleReflectionConfig.fromTierAndThrottle({
    required HardwareTier tier,
    int throttleLevel = 0,
    double? renderResolutionScale,
    PuddleReflectionConfig? base,
  }) {
    final PuddleReflectionConfig b = base ?? const PuddleReflectionConfig();

    // Eco and Low tiers (<= 2GB RAM) or severe thermal throttle (level >= 2):
    // Strict decimation to protect 60/30 FPS frame pacing.
    if (tier == HardwareTier.eco || tier == HardwareTier.low || throttleLevel >= 2) {
      return b.copyWith(
        hardwareTier: tier,
        throttleLevel: throttleLevel,
        renderResolutionScale: renderResolutionScale ?? 0.5,
        maxRaySteps: 0.0,
        bypassRaymarching: true,
        bypassRippleAnimation: true,
        isStaticDarkWater: true,
        periodicRippleInterval: 0.0,
        enableSpecularHighlights: false,
        rainIntensity: 0.0,
        waterColor: const ui.Color(0xEE0B141D), // Static dark water tint
        mudColor: const ui.Color(0x991B130E),
      );
    }

    // Mid tier (4GB-6GB RAM):
    // 0.75x downsampled reflection buffer with periodic ripple updates (30Hz cadence).
    if (tier == HardwareTier.mid || throttleLevel == 1) {
      return b.copyWith(
        hardwareTier: tier,
        throttleLevel: throttleLevel,
        renderResolutionScale: renderResolutionScale ?? 0.75,
        maxRaySteps: 14.0,
        rayStepSize: 0.035,
        bypassRaymarching: false,
        bypassRippleAnimation: false,
        isStaticDarkWater: false,
        periodicRippleInterval: 0.033, // 30Hz periodic updates
        enableSpecularHighlights: false,
        reflectivity: 0.95,
      );
    }

    // Ultra tier (16GB+ RAM / 2027 AAA flagship):
    // Full 60/120 FPS real-time animated ripple normals with specular puddle reflections.
    if (tier == HardwareTier.ultra) {
      return b.copyWith(
        hardwareTier: tier,
        throttleLevel: throttleLevel,
        renderResolutionScale: renderResolutionScale ?? 1.0,
        maxRaySteps: 32.0,
        rayStepSize: 0.018,
        bypassRaymarching: false,
        bypassRippleAnimation: false,
        isStaticDarkWater: false,
        periodicRippleInterval: 0.0, // Continuous 60/120 FPS updates
        enableSpecularHighlights: true,
        reflectivity: 1.35,
        puddleRoughness: 0.02,
      );
    }

    // High tier (8GB-12GB RAM):
    return b.copyWith(
      hardwareTier: tier,
      throttleLevel: throttleLevel,
      renderResolutionScale: renderResolutionScale ?? 1.0,
      maxRaySteps: 24.0,
      rayStepSize: 0.025,
      bypassRaymarching: false,
      bypassRippleAnimation: false,
      isStaticDarkWater: false,
      periodicRippleInterval: 0.0,
      enableSpecularHighlights: true,
      reflectivity: 1.15,
    );
  }

  /// Preset: Eco/Low tier static dark water for <= 2GB RAM devices.
  factory PuddleReflectionConfig.ecoStatic() {
    return const PuddleReflectionConfig(
      rainIntensity: 0.0,
      rippleSpeed: 0.0,
      puddleRoughness: 0.1,
      reflectivity: 0.4,
      waterColor: ui.Color(0xEE0D1620),
      mudColor: ui.Color(0x991C140F),
      maxRaySteps: 0.0,
      hardwareTier: HardwareTier.eco,
      throttleLevel: 0,
      renderResolutionScale: 0.5,
      bypassRaymarching: true,
      bypassRippleAnimation: true,
      isStaticDarkWater: true,
      periodicRippleInterval: 0.0,
      enableSpecularHighlights: false,
    );
  }

  /// Preset: Mid-tier balanced 0.75x downsampled reflection with periodic ripple updates.
  factory PuddleReflectionConfig.midSpec() {
    return const PuddleReflectionConfig(
      rainIntensity: 0.4,
      rippleSpeed: 0.85,
      puddleRoughness: 0.05,
      reflectivity: 0.95,
      maxRaySteps: 14.0,
      rayStepSize: 0.035,
      hardwareTier: HardwareTier.mid,
      throttleLevel: 0,
      renderResolutionScale: 0.75,
      bypassRaymarching: false,
      bypassRippleAnimation: false,
      isStaticDarkWater: false,
      periodicRippleInterval: 0.033,
      enableSpecularHighlights: false,
    );
  }

  /// Preset: Ultra 2027 AAA flagship 60 FPS animated ripple normals & specular reflections.
  factory PuddleReflectionConfig.ultraSpec() {
    return const PuddleReflectionConfig(
      rainIntensity: 0.7,
      rippleSpeed: 1.1,
      puddleRoughness: 0.02,
      reflectivity: 1.35,
      maxRaySteps: 32.0,
      rayStepSize: 0.018,
      hardwareTier: HardwareTier.ultra,
      throttleLevel: 0,
      renderResolutionScale: 1.0,
      bypassRaymarching: false,
      bypassRippleAnimation: false,
      isStaticDarkWater: false,
      periodicRippleInterval: 0.0,
      enableSpecularHighlights: true,
    );
  }

  /// Preset: Calm puddle reflection after light rainfall.
  factory PuddleReflectionConfig.calmAfterRain() {
    return const PuddleReflectionConfig(
      rainIntensity: 0.15,
      rippleSpeed: 0.7,
      puddleRoughness: 0.02,
      reflectivity: 1.15,
      fresnelR0: SchlickFresnel.waterF0,
      waterDepthScale: 0.8,
      waterColor: ui.Color(0x28122D40),
      mudColor: ui.Color(0x77281B12),
      maxRaySteps: 28.0,
      rayStepSize: 0.02,
      planarReflectionHeight: 0.65,
      edgeFadeMargin: 0.08,
      cameraPosition: WorldVector3(0.0, 1.6, 3.2),
      cameraDirection: WorldVector3(0.0, -0.32, -0.95),
    );
  }

  /// Preset: Heavy torrential rainstorm with aggressive ripples and droplets.
  factory PuddleReflectionConfig.heavyDownpour() {
    return const PuddleReflectionConfig(
      rainIntensity: 0.95,
      rippleSpeed: 1.5,
      puddleRoughness: 0.12,
      reflectivity: 0.85,
      fresnelR0: SchlickFresnel.waterF0,
      waterDepthScale: 1.4,
      waterColor: ui.Color(0x440B2233),
      mudColor: ui.Color(0x9923170E),
      maxRaySteps: 20.0,
      rayStepSize: 0.03,
      planarReflectionHeight: 0.65,
      edgeFadeMargin: 0.1,
      cameraPosition: WorldVector3(0.0, 1.8, 3.5),
      cameraDirection: WorldVector3(0.0, -0.38, -0.92),
    );
  }

  /// Preset: Cinematic night hub with glowing streetlights and neon reflections.
  factory PuddleReflectionConfig.nightHubReflections() {
    return const PuddleReflectionConfig(
      rainIntensity: 0.35,
      rippleSpeed: 0.9,
      puddleRoughness: 0.03,
      reflectivity: 1.35,
      fresnelR0: 0.025,
      waterDepthScale: 1.2,
      waterColor: ui.Color(0x380A1526),
      mudColor: ui.Color(0x881E1510),
      maxRaySteps: 32.0,
      rayStepSize: 0.018,
      planarReflectionHeight: 0.62,
      edgeFadeMargin: 0.07,
      cameraPosition: WorldVector3(0.0, 1.5, 3.0),
      cameraDirection: WorldVector3(0.0, -0.3, -0.95),
    );
  }

  PuddleReflectionConfig copyWith({
    double? rainIntensity,
    double? rippleSpeed,
    double? puddleRoughness,
    double? reflectivity,
    double? fresnelR0,
    double? waterDepthScale,
    ui.Color? waterColor,
    ui.Color? mudColor,
    double? maxRaySteps,
    double? rayStepSize,
    double? planarReflectionHeight,
    double? edgeFadeMargin,
    WorldVector3? cameraPosition,
    WorldVector3? cameraDirection,
    HardwareTier? hardwareTier,
    int? throttleLevel,
    double? renderResolutionScale,
    bool? bypassRaymarching,
    bool? bypassRippleAnimation,
    bool? isStaticDarkWater,
    double? periodicRippleInterval,
    bool? enableSpecularHighlights,
  }) {
    return PuddleReflectionConfig(
      rainIntensity: rainIntensity ?? this.rainIntensity,
      rippleSpeed: rippleSpeed ?? this.rippleSpeed,
      puddleRoughness: puddleRoughness ?? this.puddleRoughness,
      reflectivity: reflectivity ?? this.reflectivity,
      fresnelR0: fresnelR0 ?? this.fresnelR0,
      waterDepthScale: waterDepthScale ?? this.waterDepthScale,
      waterColor: waterColor ?? this.waterColor,
      mudColor: mudColor ?? this.mudColor,
      maxRaySteps: maxRaySteps ?? this.maxRaySteps,
      rayStepSize: rayStepSize ?? this.rayStepSize,
      planarReflectionHeight: planarReflectionHeight ?? this.planarReflectionHeight,
      edgeFadeMargin: edgeFadeMargin ?? this.edgeFadeMargin,
      cameraPosition: cameraPosition ?? this.cameraPosition,
      cameraDirection: cameraDirection ?? this.cameraDirection,
      hardwareTier: hardwareTier ?? this.hardwareTier,
      throttleLevel: throttleLevel ?? this.throttleLevel,
      renderResolutionScale: renderResolutionScale ?? this.renderResolutionScale,
      bypassRaymarching: bypassRaymarching ?? this.bypassRaymarching,
      bypassRippleAnimation: bypassRippleAnimation ?? this.bypassRippleAnimation,
      isStaticDarkWater: isStaticDarkWater ?? this.isStaticDarkWater,
      periodicRippleInterval: periodicRippleInterval ?? this.periodicRippleInterval,
      enableSpecularHighlights: enableSpecularHighlights ?? this.enableSpecularHighlights,
    );
  }

  /// Builds the exact 27-float uniform array corresponding to GLSL shader layout.
  List<double> buildUniformList({
    required ui.Size viewportSize,
    required double time,
  }) {
    final WorldVector3 normCamDir = cameraDirection.normalized;
    final double effMaxSteps = bypassRaymarching ? 0.0 : maxRaySteps;

    return <double>[
      // 0, 1: uResolution (vec2) scaled by renderResolutionScale
      viewportSize.width * renderResolutionScale,
      viewportSize.height * renderResolutionScale,

      // 2: uTime (float)
      time,

      // 3, 4, 5: uCameraPos (vec3)
      cameraPosition.x,
      cameraPosition.y,
      cameraPosition.z,

      // 6, 7, 8: uCameraDir (vec3)
      normCamDir.x,
      normCamDir.y,
      normCamDir.z,

      // 9: uRainIntensity (float)
      rainIntensity.clamp(0.0, 1.0),

      // 10: uRippleSpeed (float)
      rippleSpeed,

      // 11: uPuddleRoughness (float)
      puddleRoughness.clamp(0.0, 1.0),

      // 12: uReflectivity (float)
      reflectivity,

      // 13: uFresnelR0 (float)
      fresnelR0,

      // 14: uWaterDepthScale (float)
      waterDepthScale,

      // 15, 16, 17, 18: uWaterColor (vec4)
      waterColor.r,
      waterColor.g,
      waterColor.b,
      waterColor.a,

      // 19, 20, 21, 22: uMudColor (vec4)
      mudColor.r,
      mudColor.g,
      mudColor.b,
      mudColor.a,

      // 23: uMaxRaySteps (float)
      effMaxSteps,

      // 24: uRayStepSize (float)
      rayStepSize,

      // 25: uPlanarReflectionHeight (float)
      planarReflectionHeight,

      // 26: uEdgeFadeMargin (float)
      edgeFadeMargin,
    ];
  }

  /// Exports packed [Float32List] for native shader buffer uploads.
  Float32List toUniformFloat32List({
    required ui.Size viewportSize,
    required double time,
  }) {
    final List<double> uniforms = buildUniformList(
      viewportSize: viewportSize,
      time: time,
    );
    final Float32List buffer = Float32List(uniforms.length);
    for (int i = 0; i < uniforms.length; i++) {
      buffer[i] = uniforms[i];
    }
    return buffer;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PuddleReflectionConfig &&
          (rainIntensity - other.rainIntensity).abs() < 1e-4 &&
          (rippleSpeed - other.rippleSpeed).abs() < 1e-4 &&
          (puddleRoughness - other.puddleRoughness).abs() < 1e-4 &&
          (reflectivity - other.reflectivity).abs() < 1e-4 &&
          (fresnelR0 - other.fresnelR0).abs() < 1e-4 &&
          (waterDepthScale - other.waterDepthScale).abs() < 1e-4 &&
          waterColor == other.waterColor &&
          mudColor == other.mudColor &&
          (maxRaySteps - other.maxRaySteps).abs() < 1e-4 &&
          (rayStepSize - other.rayStepSize).abs() < 1e-4 &&
          (planarReflectionHeight - other.planarReflectionHeight).abs() < 1e-4 &&
          (edgeFadeMargin - other.edgeFadeMargin).abs() < 1e-4 &&
          cameraPosition == other.cameraPosition &&
          cameraDirection == other.cameraDirection &&
          hardwareTier == other.hardwareTier &&
          throttleLevel == other.throttleLevel &&
          (renderResolutionScale - other.renderResolutionScale).abs() < 1e-4 &&
          bypassRaymarching == other.bypassRaymarching &&
          bypassRippleAnimation == other.bypassRippleAnimation &&
          isStaticDarkWater == other.isStaticDarkWater &&
          (periodicRippleInterval - other.periodicRippleInterval).abs() < 1e-4 &&
          enableSpecularHighlights == other.enableSpecularHighlights;

  @override
  int get hashCode => Object.hash(
        rainIntensity,
        rippleSpeed,
        puddleRoughness,
        reflectivity,
        fresnelR0,
        waterDepthScale,
        waterColor,
        mudColor,
        maxRaySteps,
        rayStepSize,
        planarReflectionHeight,
        edgeFadeMargin,
        cameraPosition,
        cameraDirection,
        hardwareTier,
        throttleLevel,
        renderResolutionScale,
        bypassRaymarching,
        bypassRippleAnimation,
        isStaticDarkWater,
      );
}

// -----------------------------------------------------------------------------
// 6. Controller & Preloader
// -----------------------------------------------------------------------------

/// Dedicated progressive prewarmer utilizing [ZeroJankPreloader] to pre-calculate
/// water ripple normal maps within the strictly enforced < 2.0ms frame slice budget.
class WaterRippleNormalPreloader {
  WaterRippleNormalPreloader._();

  /// Preload task identifier in ZeroJankPreloader registry.
  static const String taskId = 'puddle_ripple_normal_maps';

  static Float32List? _prewarmedNormalMap;
  static bool _isPrewarmed = false;

  /// Returns cached pre-warmed normal map buffer, or null if not yet pre-warmed.
  static Float32List? get prewarmedNormalMap => _prewarmedNormalMap;

  /// True when ripple normal maps have completed progressive pre-warming.
  static bool get isPrewarmed => _isPrewarmed;

  /// Pre-warms water ripple normal maps via [ZeroJankPreloader.instance.preloadAtomic]
  /// with a 64x64 normal lookup table (< 2.0ms execution budget, ~49KB RAM target).
  static Future<Float32List> prewarm({
    int resolution = 64,
    ZeroJankPreloader? preloader,
  }) {
    final ZeroJankPreloader loader = preloader ?? ZeroJankPreloader.instance;

    return loader.preloadAtomic<Float32List>(
      id: taskId,
      priority: PreloadPriority.nearbyLod0,
      targetCache: CacheTarget.ram,
      estimatedSizeBytes: resolution * resolution * 3 * 4,
      isPinned: false,
      tags: const <String>{'world', 'water', 'normals', 'puddle'},
      loader: () async {
        final int totalElements = resolution * resolution * 3;
        final Float32List buffer = Float32List(totalElements);
        int idx = 0;

        for (int y = 0; y < resolution; y++) {
          final double v = y / (resolution - 1.0);
          for (int x = 0; x < resolution; x++) {
            final double u = x / (resolution - 1.0);
            final WorldVector3 normal = GerstnerWaveMath.evaluateNormal(
              uv: ui.Offset(u, v),
              time: 0.0,
              intensity: 1.0,
            );
            buffer[idx++] = normal.x;
            buffer[idx++] = normal.y;
            buffer[idx++] = normal.z;
          }
        }

        _prewarmedNormalMap = buffer;
        _isPrewarmed = true;
        return buffer;
      },
    );
  }

  /// Clears in-memory prewarmed buffer.
  static void clear() {
    _prewarmedNormalMap = null;
    _isPrewarmed = false;
  }
}

/// State controller managing real-time simulation updates, rain modulation,
/// and camera viewpoints for puddle reflections.
class PuddleReflectionController extends ChangeNotifier {
  PuddleReflectionController({
    PuddleReflectionConfig config = const PuddleReflectionConfig(),
    AdaptiveQualityScaler? scaler,
  })  : _config = config,
        _scaler = scaler {
    _initScaler();
  }

  PuddleReflectionConfig _config;
  final AdaptiveQualityScaler? _scaler;
  StreamSubscription<QualitySettings>? _scalerSubscription;
  double _time = 0.0;
  double _accumulatedDt = 0.0;
  bool _disposed = false;

  void _initScaler() {
    final AdaptiveQualityScaler targetScaler =
        _scaler ?? GraphicsSettingsService.instance.scaler;
    adaptToScaler(targetScaler);
    _scalerSubscription = targetScaler.onSettingsChanged.listen((_) {
      adaptToScaler(targetScaler);
    });
  }

  /// Current visual configuration.
  PuddleReflectionConfig get config => _config;

  /// Continuous simulation elapsed time in seconds.
  double get time => _time;

  /// Current rain precipitation intensity.
  double get rainIntensity => _config.rainIntensity;

  /// Dynamically updates configuration based on [AdaptiveQualityScaler] tier and throttle level.
  void adaptToScaler(AdaptiveQualityScaler scaler) {
    if (_disposed) return;
    final PuddleReflectionConfig newConfig = PuddleReflectionConfig.fromScaler(
      scaler,
      base: _config,
    );
    if (_config != newConfig) {
      _config = newConfig;
      notifyListeners();
    }
  }

  /// Advances continuous simulation time by [dt] seconds.
  void update(double dt) {
    if (_disposed || dt <= 0.0) return;

    // Eco / Low tiers (<=2GB RAM): bypass dynamic water ripple animation loops
    // to protect 60/30 FPS frame pacing.
    if (_config.bypassRippleAnimation) {
      return;
    }

    // Mid tier: periodic ripple updates (e.g. 30 FPS / 33ms interval)
    if (_config.periodicRippleInterval > 0.0) {
      _accumulatedDt += dt;
      if (_accumulatedDt < _config.periodicRippleInterval) {
        return;
      }
      _time += _accumulatedDt;
      _accumulatedDt = 0.0;
    } else {
      // High & Ultra tiers: 60/120 FPS continuous real-time ripple normal updates
      _time += dt;
    }

    notifyListeners();
  }

  /// Sets configuration and notifies listeners.
  void setConfig(PuddleReflectionConfig newConfig) {
    if (_disposed || _config == newConfig) return;
    _config = newConfig;
    notifyListeners();
  }

  /// Modulates rain intensity directly.
  void setRainIntensity(double intensity) {
    setConfig(_config.copyWith(rainIntensity: intensity.clamp(0.0, 1.0)));
  }

  /// Modulates surface roughness directly.
  void setRoughness(double roughness) {
    setConfig(_config.copyWith(puddleRoughness: roughness.clamp(0.0, 1.0)));
  }

  /// Updates camera viewpoint in world space.
  void setCamera({
    required WorldVector3 position,
    required WorldVector3 direction,
  }) {
    setConfig(_config.copyWith(
      cameraPosition: position,
      cameraDirection: direction,
    ));
  }

  /// Resets simulation time to zero.
  void reset() {
    _time = 0.0;
    _accumulatedDt = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scalerSubscription?.cancel();
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// 7. CustomPainter & Flutter Widget Integration
// -----------------------------------------------------------------------------

/// CustomPainter executing either native GPU FragmentShader or high-fidelity
/// fallback canvas rendering.
class PuddleReflectionPainter extends CustomPainter {
  PuddleReflectionPainter({
    required this.controller,
    this.fragmentProgram,
    this.sceneImage,
    this.puddleMaskImage,
    this.customPuddlePath,
  }) : super(repaint: controller);

  final PuddleReflectionController controller;
  final ui.FragmentProgram? fragmentProgram;
  final ui.Image? sceneImage;
  final ui.Image? puddleMaskImage;
  final Path? customPuddlePath;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final PuddleReflectionConfig cfg = controller.config;

    // Eco / Low tiers (<=2GB RAM): bypass dynamic water ripples and raymarched reflections;
    // render static dark water tint to protect 60/30 FPS frame pacing.
    if (cfg.isStaticDarkWater ||
        cfg.bypassRaymarching ||
        cfg.hardwareTier == HardwareTier.eco ||
        (cfg.hardwareTier == HardwareTier.low && cfg.throttleLevel >= 1)) {
      _paintStaticDarkWater(canvas, size, cfg);
      return;
    }

    // Check if GPU fragment shader and both textures are ready
    if (fragmentProgram != null && sceneImage != null && puddleMaskImage != null) {
      _paintShader(canvas, size, cfg);
    } else {
      _paintCpuFallback(canvas, size, cfg);
    }
  }

  void _paintStaticDarkWater(Canvas canvas, Size size, PuddleReflectionConfig cfg) {
    // Ultra-lightweight static water pass for <= 2GB RAM devices (Eco / Low).
    // Bypasses raymarching, normal perturbation, and ripple loops entirely.
    final double planeY = size.height * cfg.planarReflectionHeight;
    final Path path = customPuddlePath ?? _generateDefaultPuddlePath(size, planeY);

    // 1. Silt & Mud Bed
    final Paint mudPaint = Paint()
      ..color = cfg.mudColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, mudPaint);

    // 2. Static Dark Water Tint (Beer-Lambert absorption approximated without per-pixel march)
    final Paint waterPaint = Paint()
      ..color = cfg.waterColor.withValues(alpha: 0.88)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, waterPaint);

    // 3. Static subtle sky reflection tint (zero raymarching / zero ripple loops)
    final Paint staticReflectPaint = Paint()
      ..color = const ui.Color(0x33446688)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, staticReflectPaint);
  }

  void _paintShader(Canvas canvas, Size size, PuddleReflectionConfig cfg) {
    final ui.FragmentShader shader = fragmentProgram!.fragmentShader();
    final List<double> uniforms = cfg.buildUniformList(
      viewportSize: size,
      time: controller.time,
    );

    for (int i = 0; i < uniforms.length; i++) {
      shader.setFloat(i, uniforms[i]);
    }

    // Bind samplers
    shader.setImageSampler(0, sceneImage!);
    shader.setImageSampler(1, puddleMaskImage!);

    final Paint paint = Paint()..shader = shader;

    // Mid tier: 0.75x downsampled reflection buffer
    if (cfg.renderResolutionScale < 0.99) {
      canvas.save();
      canvas.scale(1.0 / cfg.renderResolutionScale, 1.0 / cfg.renderResolutionScale);
      final Size scaledSize = Size(
        size.width * cfg.renderResolutionScale,
        size.height * cfg.renderResolutionScale,
      );
      canvas.drawRect(Offset.zero & scaledSize, paint);
      canvas.restore();
    } else {
      canvas.drawRect(Offset.zero & size, paint);
    }
  }

  void _paintCpuFallback(Canvas canvas, Size size, PuddleReflectionConfig cfg) {
    // High-fidelity CPU fallback:
    // Paints puddle basin with Fresnel modulation, Gerstner ripples, and planar reflection.
    final double planeY = size.height * cfg.planarReflectionHeight;

    // Default puddle basin path if none provided
    final Path path = customPuddlePath ?? _generateDefaultPuddlePath(size, planeY);

    // 1. Silt & Mud Bed
    final Paint mudPaint = Paint()
      ..color = cfg.mudColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, mudPaint);

    // 2. Water Body Extinction (Beer-Lambert depth layer)
    final double depthTransmittance = SSRRaymarchMath.calculateBeerLambertTransmittance(
      waterDepth: 0.5,
      extinctionCoeff: cfg.waterColor.a,
      depthScale: cfg.waterDepthScale,
    );
    final Paint waterPaint = Paint()
      ..color = cfg.waterColor.withValues(alpha: (1.0 - depthTransmittance).clamp(0.2, 0.85))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, waterPaint);

    // 3. Fresnel Reflectance Highlight
    // View incidence angle: look down from camera pos (y=1.8, z=3.5)
    final double viewAngleCos = math.max(cfg.cameraDirection.z.abs(), 0.1);
    final double fresnel = SchlickFresnel.evaluate(
      cosTheta: viewAngleCos,
      f0: cfg.fresnelR0,
      roughness: cfg.puddleRoughness,
    );

    // Sky / Environment reflection tint
    final Paint reflectPaint = Paint()
      ..color = const ui.Color(0xFF88BBEE).withValues(
        alpha: (fresnel * cfg.reflectivity * 0.7).clamp(0.1, 0.9),
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, reflectPaint);

    // 4. Animated Gerstner & Rain Droplet Wave Ripples
    // Bypassed on Eco/Low, periodic on Mid, 60 FPS on Ultra
    if (!cfg.bypassRippleAnimation && cfg.rainIntensity > 0.05) {
      final Paint rippleStroke = Paint()
        ..color = const ui.Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cfg.hardwareTier == HardwareTier.ultra ? 1.8 : 1.2;

      final double time = controller.time;
      // Ultra tier: full ripple count (8); Mid tier: throttled ripple count (4)
      final int baseRippleCount = cfg.hardwareTier == HardwareTier.ultra ? 8 : 4;
      final int rippleCount = (cfg.rainIntensity * baseRippleCount).ceil();

      for (int i = 0; i < rippleCount; i++) {
        final double phase = (time * cfg.rippleSpeed * 0.8 + i * 0.37) % 1.0;
        final double radius = phase * (size.width * 0.15);
        final double centerNormX = 0.25 + (i * 0.18) % 0.55;
        final double centerNormY = 0.65 + (i * 0.11) % 0.2;
        final Offset center = Offset(size.width * centerNormX, size.height * centerNormY);

        rippleStroke.color = const ui.Color(0xFFFFFFFF).withValues(
          alpha: ((1.0 - phase) * 0.4 * cfg.rainIntensity).clamp(0.0, 1.0),
        );

        canvas.drawCircle(center, radius, rippleStroke);
      }
    }

    // 5. Specular Puddle Reflections (Ultra tier 60 FPS highlight)
    if (cfg.enableSpecularHighlights && cfg.hardwareTier == HardwareTier.ultra) {
      final WorldVector3 sunDir = const WorldVector3(0.577, 0.577, 0.577).normalized;
      final WorldVector3 viewDir = (-cfg.cameraDirection).normalized;
      final WorldVector3 halfVector = (sunDir + viewDir).normalized;
      final double nDotH = math.max(0.0, WorldVector3.up.dot(halfVector));
      final double specularPower = math.pow(nDotH, 48.0).toDouble();

      if (specularPower > 0.02) {
        final Paint specPaint = Paint()
          ..color = const ui.Color(0xFFFFFFFF).withValues(
            alpha: (specularPower * 0.75 * cfg.reflectivity).clamp(0.0, 0.9),
          )
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, specPaint);
      }
    }
  }

  Path _generateDefaultPuddlePath(Size size, double planeY) {
    final Path path = Path();
    final double left = size.width * 0.15;
    final double right = size.width * 0.85;
    final double top = planeY - size.height * 0.05;
    final double bottom = planeY + size.height * 0.25;

    final Rect rect = Rect.fromLTRB(left, top, right, bottom);
    path.addOval(rect);
    return path;
  }

  @override
  bool shouldRepaint(covariant PuddleReflectionPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.fragmentProgram != fragmentProgram ||
        oldDelegate.sceneImage != sceneImage ||
        oldDelegate.puddleMaskImage != puddleMaskImage ||
        oldDelegate.customPuddlePath != customPuddlePath;
  }
}

/// Production Flutter Layer Widget rendering Screen-Space Reflections (SSR)
/// and rain puddle reflections for Open World and Hub scenes.
class PuddleReflectionLayer extends StatefulWidget {
  const PuddleReflectionLayer({
    super.key,
    required this.controller,
    this.scaler,
    this.child,
    this.sceneImage,
    this.puddleMaskImage,
    this.customPuddlePath,
    this.shaderAssetPath = 'shaders/world/puddle_ssr.frag',
    this.enablePreload = true,
  });

  /// Simulation state and uniform controller.
  final PuddleReflectionController controller;

  /// Optional adaptive quality scaler override.
  final AdaptiveQualityScaler? scaler;

  /// Optional underlying scene widget.
  final Widget? child;

  /// Rendered background scene image for SSR raymarching.
  final ui.Image? sceneImage;

  /// Mask image indicating puddle locations and depth.
  final ui.Image? puddleMaskImage;

  /// Custom geometric puddle basin boundary for CPU fallback painter.
  final Path? customPuddlePath;

  /// Asset path for runtime effect fragment shader.
  final String shaderAssetPath;

  /// Whether to automatically warm up water ripple normal maps via [ZeroJankPreloader].
  final bool enablePreload;

  @override
  State<PuddleReflectionLayer> createState() => _PuddleReflectionLayerState();
}

class _PuddleReflectionLayerState extends State<PuddleReflectionLayer> {
  ui.FragmentProgram? _program;
  bool _loadFailed = false;
  StreamSubscription<QualitySettings>? _scalerSubscription;

  @override
  void initState() {
    super.initState();
    _loadShader();
    if (widget.enablePreload) {
      WaterRippleNormalPreloader.prewarm();
    }
    _listenToScaler();
  }

  void _listenToScaler() {
    final AdaptiveQualityScaler scaler =
        widget.scaler ?? GraphicsSettingsService.instance.scaler;
    widget.controller.adaptToScaler(scaler);
    _scalerSubscription = scaler.onSettingsChanged.listen((_) {
      if (mounted) {
        widget.controller.adaptToScaler(scaler);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PuddleReflectionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shaderAssetPath != widget.shaderAssetPath) {
      _loadShader();
    }
    if (oldWidget.scaler != widget.scaler) {
      _scalerSubscription?.cancel();
      _listenToScaler();
    }
  }

  Future<void> _loadShader() async {
    try {
      final ui.FragmentProgram program =
          await ui.FragmentProgram.fromAsset(widget.shaderAssetPath);
      if (mounted) {
        setState(() {
          _program = program;
          _loadFailed = false;
        });
      }
    } catch (_) {
      // In test environments or when shader asset is mocked, fallback path activates seamlessly.
      if (mounted) {
        setState(() {
          _loadFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _scalerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget painter = CustomPaint(
      painter: PuddleReflectionPainter(
        controller: widget.controller,
        fragmentProgram: _loadFailed ? null : _program,
        sceneImage: widget.sceneImage,
        puddleMaskImage: widget.puddleMaskImage,
        customPuddlePath: widget.customPuddlePath,
      ),
      size: Size.infinite,
    );

    if (widget.child == null) {
      return painter;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child!,
        Positioned.fill(child: painter),
      ],
    );
  }
}

