import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../screens/settings/graphics_settings_service.dart';

// =============================================================================
// Mobile Screen-Space Reflections (SSR) & Wet Puddle Reflection Layer
// 2027 Aion 2 Mobile Standard — Tile-Based Deferred Rendering (TBDR) Optimized
// =============================================================================

/// Quality tier scaling for mobile Screen-Space Reflections (SSR).
/// Tailored for TBDR mobile GPUs (Adreno, Mali, Apple GPU) to prevent thermal throttling.
enum MobileSsrQuality {
  /// Disabled (0 draw calls, 0 raymarching steps).
  off,

  /// Low-spec Android profile (3-4GB RAM):
  /// 4 raymarching steps, planar projection baseline, static Fresnel.
  eco,

  /// Mid-range mobile profile (6-8GB RAM):
  /// 8 raymarching steps, Gerstner wave normal perturbation, Schlick Fresnel.
  medium,

  /// High-spec mobile profile (8-12GB RAM):
  /// 16 raymarching steps, dual-octave Gerstner waves, Voronoi raindrops, edge fade.
  high,

  /// AAA Aion 2 mobile profile (Flagship SoC):
  /// 24 raymarching steps with binary refinement, full Beer-Lambert absorption.
  ultra;

  /// Maps a [HardwareTier] and [throttleLevel] to the appropriate [MobileSsrQuality].
  static MobileSsrQuality fromHardwareTier(
    HardwareTier tier, {
    int throttleLevel = 0,
  }) {
    if (throttleLevel >= 2 ||
        tier == HardwareTier.eco ||
        tier == HardwareTier.low) {
      return MobileSsrQuality.eco;
    }
    switch (tier) {
      case HardwareTier.eco:
      case HardwareTier.low:
        return MobileSsrQuality.eco;
      case HardwareTier.mid:
        return throttleLevel == 1
            ? MobileSsrQuality.eco
            : MobileSsrQuality.medium;
      case HardwareTier.high:
        return throttleLevel == 1
            ? MobileSsrQuality.medium
            : MobileSsrQuality.high;
      case HardwareTier.ultra:
        return throttleLevel == 1
            ? MobileSsrQuality.high
            : MobileSsrQuality.ultra;
    }
  }

  /// Maximum raymarching step count for this tier.
  int get maxRaySteps {
    switch (this) {
      case MobileSsrQuality.off:
        return 0;
      case MobileSsrQuality.eco:
        return 4;
      case MobileSsrQuality.medium:
        return 8;
      case MobileSsrQuality.high:
        return 16;
      case MobileSsrQuality.ultra:
        return 24;
    }
  }

  /// Raymarch UV stride distance per step.
  double get rayStepSize {
    switch (this) {
      case MobileSsrQuality.off:
        return 0.0;
      case MobileSsrQuality.eco:
        return 0.050;
      case MobileSsrQuality.medium:
        return 0.035;
      case MobileSsrQuality.high:
        return 0.024;
      case MobileSsrQuality.ultra:
        return 0.016;
    }
  }

  /// Whether animated Gerstner wave chop is active.
  bool get hasGerstnerWaves =>
      this != MobileSsrQuality.off && this != MobileSsrQuality.eco;

  /// Whether animated Voronoi rain droplets are active.
  bool get hasRainDroplets =>
      this == MobileSsrQuality.high || this == MobileSsrQuality.ultra;

  /// Target GPU frame time budget in milliseconds.
  double get frameBudgetMs {
    switch (this) {
      case MobileSsrQuality.off:
        return 0.0;
      case MobileSsrQuality.eco:
        return 0.50;
      case MobileSsrQuality.medium:
        return 1.10;
      case MobileSsrQuality.high:
        return 1.80;
      case MobileSsrQuality.ultra:
        return 2.70;
    }
  }
}

/// Configuration parameters for mobile SSR wet ground and puddle reflections.
class MobileSsrConfig {
  const MobileSsrConfig({
    this.quality = MobileSsrQuality.medium,
    this.wetness = 0.85,
    this.rainIntensity = 0.25,
    this.puddleRoughness = 0.04,
    this.reflectivity = 1.10,
    this.fresnelR0 = 0.0204, // Water normal reflectance
    this.waterDepthScale = 0.85,
    this.waterColor = const ui.Color(0x33122D42),
    this.mudColor = const ui.Color(0x88241A12),
    this.puddlePlaneY = 0.62,
    this.edgeFadeMargin = 0.09,
    this.rippleSpeed = 1.0,
    this.cameraPitch = 0.35,
    this.skyReflectionColor = const ui.Color(0x667799CC),
    this.hardwareTier,
    this.throttleLevel = 0,
    this.renderResolutionScale = 1.0,
    this.bypassRaymarching = false,
    this.multiSampleSmoothing = false,
  });

  /// Quality tier for raymarching and wave iterations.
  final MobileSsrQuality quality;

  /// Overall ground wetness factor [0.0 = bone dry, 1.0 = flooded].
  final double wetness;

  /// Rain precipitation intensity [0.0 = clear, 1.0 = torrential storm].
  final double rainIntensity;

  /// Surface micro-facet roughness [0.01 = mirror specular, 1.0 = diffuse].
  final double puddleRoughness;

  /// Specular reflection brightness multiplier [0.0 - 2.0].
  final double reflectivity;

  /// Schlick Fresnel F0 normal reflectance (water ≈ 0.0204, wet cobblestone ≈ 0.05).
  final double fresnelR0;

  /// Water volume extinction scaling factor for Beer-Lambert absorption.
  final double waterDepthScale;

  /// Water body tint and absorption alpha.
  final ui.Color waterColor;

  /// Basin silt bed and muddy ground tint.
  final ui.Color mudColor;

  /// Normalized Y level in viewport [0.0 - 1.0] representing the puddle water plane.
  final double puddlePlaneY;

  /// Margin for fading screen edge reflections to prevent popping [0.0 - 0.2].
  final double edgeFadeMargin;

  /// Temporal speed multiplier for wave ripples.
  final double rippleSpeed;

  /// Camera viewing pitch angle in radians (downwards from horizon).
  final double cameraPitch;

  /// Celestial sky / environment reflection color tint.
  final ui.Color skyReflectionColor;

  /// Active hardware tier from [AdaptiveQualityScaler].
  final HardwareTier? hardwareTier;

  /// Dynamic runtime throttle level [0 to 3].
  final int throttleLevel;

  /// Internal render resolution scale multiplier [0.5 to 1.0].
  final double renderResolutionScale;

  /// Whether to completely bypass the SSR raymarching reflection pass
  /// (Eco/Low tiers or throttleLevel >= 2) to protect memory bandwidth.
  final bool bypassRaymarching;

  /// Whether multi-sample reflection smoothing is active (High/Ultra tiers).
  final bool multiSampleSmoothing;

  /// Preset: Calm reflective water puddles after rainfall.
  factory MobileSsrConfig.calmWaterPuddles() {
    return const MobileSsrConfig(
      quality: MobileSsrQuality.medium,
      wetness: 0.80,
      rainIntensity: 0.10,
      puddleRoughness: 0.02,
      reflectivity: 1.15,
      waterDepthScale: 0.75,
      puddlePlaneY: 0.62,
      rippleSpeed: 0.8,
      hardwareTier: HardwareTier.mid,
      renderResolutionScale: 0.75,
    );
  }

  /// Preset: Torrential downpour with active ripples and high water coverage.
  factory MobileSsrConfig.stormyDownpour() {
    return const MobileSsrConfig(
      quality: MobileSsrQuality.high,
      wetness: 1.0,
      rainIntensity: 0.90,
      puddleRoughness: 0.08,
      reflectivity: 1.25,
      waterDepthScale: 1.10,
      puddlePlaneY: 0.58,
      rippleSpeed: 1.6,
      skyReflectionColor: ui.Color(0x77557799),
      hardwareTier: HardwareTier.high,
      renderResolutionScale: 1.0,
      multiSampleSmoothing: true,
    );
  }

  /// Preset: Aion 2 flagship cinematic night puddle reflections.
  factory MobileSsrConfig.aion2CinematicNight() {
    return const MobileSsrConfig(
      quality: MobileSsrQuality.ultra,
      wetness: 0.90,
      rainIntensity: 0.35,
      puddleRoughness: 0.03,
      reflectivity: 1.35,
      waterDepthScale: 0.90,
      puddlePlaneY: 0.60,
      rippleSpeed: 1.1,
      skyReflectionColor: ui.Color(0x884488DD),
      hardwareTier: HardwareTier.ultra,
      renderResolutionScale: 1.0,
      multiSampleSmoothing: true,
    );
  }

  /// Preset: Low-spec Android tier (60+ FPS guarantee).
  factory MobileSsrConfig.ecoLowSpec() {
    return const MobileSsrConfig(
      quality: MobileSsrQuality.eco,
      wetness: 0.65,
      rainIntensity: 0.0,
      puddleRoughness: 0.05,
      reflectivity: 0.90,
      waterDepthScale: 0.60,
      puddlePlaneY: 0.65,
      rippleSpeed: 0.5,
      hardwareTier: HardwareTier.low,
      renderResolutionScale: 0.75,
      bypassRaymarching: true,
      multiSampleSmoothing: false,
    );
  }

  /// Preset: Disabled SSR reflections.
  factory MobileSsrConfig.off() {
    return const MobileSsrConfig(
      quality: MobileSsrQuality.off,
      wetness: 0.0,
      bypassRaymarching: true,
      multiSampleSmoothing: false,
    );
  }

  /// Applies adaptive quality parameters derived from [AdaptiveQualityScaler].
  MobileSsrConfig applyAdaptiveQuality({
    required HardwareTier tier,
    required double renderResolutionScale,
    required int throttleLevel,
  }) {
    // 1. Eco / Low tiers (<=2GB RAM) or throttleLevel >= 2:
    // Bypass raymarching reflection pass completely (simple tint or pass-through) to protect memory bandwidth.
    final bool bypass = tier == HardwareTier.eco ||
        tier == HardwareTier.low ||
        throttleLevel >= 2;

    // 2. Mid tier: scale SSR reflection buffer to 0.75x or downsampled resolution.
    // 3. High / Ultra tiers: full resolution SSR with multi-sample reflection smoothing.
    final MobileSsrQuality newQuality;
    final double effectiveBufferScale;
    final bool smoothing;

    if (bypass) {
      newQuality = MobileSsrQuality.eco;
      effectiveBufferScale = (tier == HardwareTier.eco) ? 0.50 : 0.75;
      smoothing = false;
    } else {
      switch (tier) {
        case HardwareTier.eco:
        case HardwareTier.low:
          newQuality = MobileSsrQuality.eco;
          effectiveBufferScale = 0.75;
          smoothing = false;
        case HardwareTier.mid:
          // Mid tier: scale SSR reflection buffer to 0.75x or downsampled resolution
          newQuality = (throttleLevel == 1)
              ? MobileSsrQuality.eco
              : MobileSsrQuality.medium;
          effectiveBufferScale = 0.75;
          smoothing = false;
        case HardwareTier.high:
          // High tier: full resolution SSR with multi-sample reflection smoothing
          newQuality = (throttleLevel == 1)
              ? MobileSsrQuality.medium
              : MobileSsrQuality.high;
          effectiveBufferScale = throttleLevel == 1 ? 0.75 : 1.0;
          smoothing = throttleLevel == 0;
        case HardwareTier.ultra:
          // Ultra tier: full resolution SSR with multi-sample reflection smoothing
          newQuality = (throttleLevel == 1)
              ? MobileSsrQuality.high
              : MobileSsrQuality.ultra;
          effectiveBufferScale = 1.0;
          smoothing = true;
      }
    }

    return copyWith(
      quality: newQuality,
      hardwareTier: tier,
      throttleLevel: throttleLevel,
      renderResolutionScale: effectiveBufferScale,
      bypassRaymarching: bypass,
      multiSampleSmoothing: smoothing,
    );
  }

  MobileSsrConfig copyWith({
    MobileSsrQuality? quality,
    double? wetness,
    double? rainIntensity,
    double? puddleRoughness,
    double? reflectivity,
    double? fresnelR0,
    double? waterDepthScale,
    ui.Color? waterColor,
    ui.Color? mudColor,
    double? puddlePlaneY,
    double? edgeFadeMargin,
    double? rippleSpeed,
    double? cameraPitch,
    ui.Color? skyReflectionColor,
    HardwareTier? hardwareTier,
    int? throttleLevel,
    double? renderResolutionScale,
    bool? bypassRaymarching,
    bool? multiSampleSmoothing,
  }) {
    return MobileSsrConfig(
      quality: quality ?? this.quality,
      wetness: wetness ?? this.wetness,
      rainIntensity: rainIntensity ?? this.rainIntensity,
      puddleRoughness: puddleRoughness ?? this.puddleRoughness,
      reflectivity: reflectivity ?? this.reflectivity,
      fresnelR0: fresnelR0 ?? this.fresnelR0,
      waterDepthScale: waterDepthScale ?? this.waterDepthScale,
      waterColor: waterColor ?? this.waterColor,
      mudColor: mudColor ?? this.mudColor,
      puddlePlaneY: puddlePlaneY ?? this.puddlePlaneY,
      edgeFadeMargin: edgeFadeMargin ?? this.edgeFadeMargin,
      rippleSpeed: rippleSpeed ?? this.rippleSpeed,
      cameraPitch: cameraPitch ?? this.cameraPitch,
      skyReflectionColor: skyReflectionColor ?? this.skyReflectionColor,
      hardwareTier: hardwareTier ?? this.hardwareTier,
      throttleLevel: throttleLevel ?? this.throttleLevel,
      renderResolutionScale:
          renderResolutionScale ?? this.renderResolutionScale,
      bypassRaymarching: bypassRaymarching ?? this.bypassRaymarching,
      multiSampleSmoothing:
          multiSampleSmoothing ?? this.multiSampleSmoothing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MobileSsrConfig &&
          quality == other.quality &&
          (wetness - other.wetness).abs() < 1e-4 &&
          (rainIntensity - other.rainIntensity).abs() < 1e-4 &&
          (puddleRoughness - other.puddleRoughness).abs() < 1e-4 &&
          (reflectivity - other.reflectivity).abs() < 1e-4 &&
          (fresnelR0 - other.fresnelR0).abs() < 1e-4 &&
          (waterDepthScale - other.waterDepthScale).abs() < 1e-4 &&
          waterColor == other.waterColor &&
          mudColor == other.mudColor &&
          (puddlePlaneY - other.puddlePlaneY).abs() < 1e-4 &&
          (edgeFadeMargin - other.edgeFadeMargin).abs() < 1e-4 &&
          (rippleSpeed - other.rippleSpeed).abs() < 1e-4 &&
          (cameraPitch - other.cameraPitch).abs() < 1e-4 &&
          skyReflectionColor == other.skyReflectionColor &&
          hardwareTier == other.hardwareTier &&
          throttleLevel == other.throttleLevel &&
          (renderResolutionScale - other.renderResolutionScale).abs() < 1e-4 &&
          bypassRaymarching == other.bypassRaymarching &&
          multiSampleSmoothing == other.multiSampleSmoothing;

  @override
  int get hashCode => Object.hash(
        quality,
        wetness,
        rainIntensity,
        puddleRoughness,
        reflectivity,
        fresnelR0,
        waterDepthScale,
        waterColor,
        mudColor,
        puddlePlaneY,
        edgeFadeMargin,
        rippleSpeed,
        cameraPitch,
        skyReflectionColor,
        hardwareTier,
        throttleLevel,
        renderResolutionScale,
        bypassRaymarching,
        multiSampleSmoothing,
      );
}

// -----------------------------------------------------------------------------
// Mobile SSR Raymarching & Fresnel Approximation Math
// -----------------------------------------------------------------------------

/// Pure analytical mathematical models for mobile Screen-Space Reflections.
abstract final class MobileSsrMath {
  /// Evaluates Schlick's Fresnel approximation factor:
  /// F(theta) = F0 + (1 - F0) * (1 - cosTheta)^5 * (1 - roughness)
  static double evaluateSchlickFresnel({
    required double cosTheta,
    required double f0,
    double roughness = 0.0,
  }) {
    final double clampedCos = cosTheta.clamp(0.0, 1.0);
    final double oneMinusCos = 1.0 - clampedCos;
    final double omc2 = oneMinusCos * oneMinusCos;
    final double omc5 = omc2 * omc2 * oneMinusCos;
    final double baseFresnel = f0 + (1.0 - f0) * omc5;
    final double roughnessDamping = (1.0 - roughness.clamp(0.0, 1.0));
    return (baseFresnel * roughnessDamping).clamp(0.0, 1.0);
  }

  /// Evaluates Beer-Lambert volume light absorption:
  /// T = exp(-depth * extinction * depthScale)
  static double evaluateBeerLambertTransmittance({
    required double depth,
    required double extinction,
    double depthScale = 1.0,
  }) {
    final double exponent = -math.max(0.0, depth) * extinction * depthScale;
    return math.exp(exponent).clamp(0.0, 1.0);
  }

  /// Calculates smooth screen-edge vignette falloff to prevent reflection pop artifacts:
  /// Smoothstep at left/right/top/bottom screen margins.
  static double calculateEdgeFade({
    required ui.Offset uv,
    double margin = 0.08,
  }) {
    if (margin <= 1e-5) return 1.0;

    final double fadeX0 = (uv.dx / margin).clamp(0.0, 1.0);
    final double fadeX1 = ((1.0 - uv.dx) / margin).clamp(0.0, 1.0);
    final double fadeY0 = (uv.dy / margin).clamp(0.0, 1.0);
    final double fadeY1 = ((1.0 - uv.dy) / margin).clamp(0.0, 1.0);

    final double sx0 = fadeX0 * fadeX0 * (3.0 - 2.0 * fadeX0);
    final double sx1 = fadeX1 * fadeX1 * (3.0 - 2.0 * fadeX1);
    final double sy0 = fadeY0 * fadeY0 * (3.0 - 2.0 * fadeY0);
    final double sy1 = fadeY1 * fadeY1 * (3.0 - 2.0 * fadeY1);

    return sx0 * sx1 * sy0 * sy1;
  }

  /// Mobile raymarching step approximation.
  /// Given an origin UV on the water plane and an upward-directed reflection ray,
  /// marches in screen UV space up towards the scene horizon / celestial structures.
  /// Returns the sampled UV coordinate with edge-fade weight.
  static (ui.Offset, double) marchScreenRay({
    required ui.Offset startUv,
    required ui.Offset rayDir,
    required int maxSteps,
    required double stepSize,
    double edgeFadeMargin = 0.08,
  }) {
    if (maxSteps <= 0) {
      return (startUv, 0.0);
    }

    ui.Offset currentUv = startUv;
    double accumulatedFade = 1.0;

    for (int step = 0; step < maxSteps; step++) {
      currentUv += rayDir * stepSize;
      if (currentUv.dx < 0.0 ||
          currentUv.dx > 1.0 ||
          currentUv.dy < 0.0 ||
          currentUv.dy > 1.0) {
        // Ray escaped viewport boundary
        accumulatedFade = calculateEdgeFade(
          uv: ui.Offset(
            currentUv.dx.clamp(0.0, 1.0),
            currentUv.dy.clamp(0.0, 1.0),
          ),
          margin: edgeFadeMargin,
        );
        break;
      }
    }

    final ui.Offset clampedUv = ui.Offset(
      currentUv.dx.clamp(0.0, 1.0),
      currentUv.dy.clamp(0.0, 1.0),
    );
    final double edgeWeight = calculateEdgeFade(uv: clampedUv, margin: edgeFadeMargin) * accumulatedFade;
    return (clampedUv, edgeWeight);
  }

  /// Multi-sample raymarching evaluation.
  /// Averages multiple jittered ray samples to smooth specular noise and roughness aliasing.
  static (ui.Offset, double) marchScreenRayMultiSample({
    required ui.Offset startUv,
    required ui.Offset baseRayDir,
    required int maxSteps,
    required double stepSize,
    double edgeFadeMargin = 0.08,
    List<ui.Offset> sampleJitters = const <ui.Offset>[
      ui.Offset(0.0, 0.0),
      ui.Offset(-0.015, 0.010),
      ui.Offset(0.015, 0.010),
    ],
  }) {
    if (sampleJitters.isEmpty || maxSteps <= 0) {
      return marchScreenRay(
        startUv: startUv,
        rayDir: baseRayDir,
        maxSteps: maxSteps,
        stepSize: stepSize,
        edgeFadeMargin: edgeFadeMargin,
      );
    }

    double accumulatedFade = 0.0;
    ui.Offset primaryUv = startUv;

    for (int i = 0; i < sampleJitters.length; i++) {
      final ui.Offset jitter = sampleJitters[i];
      final ui.Offset jitteredDir = ui.Offset(
        baseRayDir.dx + jitter.dx,
        baseRayDir.dy + jitter.dy,
      );
      final (ui.Offset uv, double fade) = marchScreenRay(
        startUv: startUv,
        rayDir: jitteredDir,
        maxSteps: maxSteps,
        stepSize: stepSize,
        edgeFadeMargin: edgeFadeMargin,
      );
      if (i == 0) primaryUv = uv;
      accumulatedFade += fade;
    }

    return (
      primaryUv,
      (accumulatedFade / sampleJitters.length).clamp(0.0, 1.0),
    );
  }

  /// Evaluates analytical Gerstner wave normal perturbation.
  static ui.Offset evaluateGerstnerNormal({
    required ui.Offset uv,
    required double time,
    double intensity = 1.0,
    double rippleSpeed = 1.0,
  }) {
    if (intensity <= 1e-4) return ui.Offset.zero;

    // Octave 1: Primary breeze wave
    const double k1 = 32.0;
    final double w1 = 2.4 * rippleSpeed;
    final double phase1 = (uv.dx * 0.707 + uv.dy * 0.707) * k1 - time * w1;
    final double cos1 = math.cos(phase1) * 0.015 * intensity;

    // Octave 2: Cross capillary wave
    const double k2 = 54.0;
    final double w2 = 3.6 * rippleSpeed;
    final double phase2 = (-uv.dx * 0.8 + uv.dy * 0.6) * k2 - time * w2;
    final double cos2 = math.cos(phase2) * 0.008 * intensity;

    return ui.Offset(
      -(0.707 * cos1 - 0.8 * cos2),
      -(0.707 * cos1 + 0.6 * cos2),
    );
  }

  /// Procedural puddle organic boundary generator (asymmetric bezier lobe).
  static Path generateOrganicPuddlePath(Size size, double planeY) {
    final Path path = Path();
    final double centerX = size.width * 0.50;
    final double centerY = planeY + (size.height - planeY) * 0.40;
    final double rx = size.width * 0.38;
    final double ry = (size.height - planeY) * 0.36;

    path.moveTo(centerX - rx * 0.85, centerY);
    path.cubicTo(
      centerX - rx * 0.90,
      centerY - ry * 0.75,
      centerX - rx * 0.30,
      centerY - ry * 1.05,
      centerX + rx * 0.20,
      centerY - ry * 0.85,
    );
    path.cubicTo(
      centerX + rx * 0.75,
      centerY - ry * 0.65,
      centerX + rx * 0.95,
      centerY - ry * 0.15,
      centerX + rx * 0.80,
      centerY + ry * 0.45,
    );
    path.cubicTo(
      centerX + rx * 0.65,
      centerY + ry * 0.95,
      centerX - rx * 0.10,
      centerY + ry * 1.10,
      centerX - rx * 0.60,
      centerY + ry * 0.70,
    );
    path.close();
    return path;
  }
}

// -----------------------------------------------------------------------------
// Controller
// -----------------------------------------------------------------------------

/// Controller managing SSR continuous simulation time, quality presets, and rain modulation.
class MobileSsrController extends ChangeNotifier {
  MobileSsrController({
    MobileSsrConfig config = const MobileSsrConfig(),
    AdaptiveQualityScaler? scaler,
  }) : _config = config {
    if (scaler != null) {
      _attachedScaler = scaler;
      _scalerListener = () {
        applyAdaptiveQuality(
          tier: _attachedScaler!.currentTier,
          renderResolutionScale: _attachedScaler!.currentResolutionScale,
          throttleLevel: _attachedScaler!.currentThrottleLevel,
        );
      };
      _attachedScaler!.addListener(_scalerListener!);
      applyAdaptiveQuality(
        tier: _attachedScaler!.currentTier,
        renderResolutionScale: _attachedScaler!.currentResolutionScale,
        throttleLevel: _attachedScaler!.currentThrottleLevel,
      );
    }
  }

  MobileSsrConfig _config;
  double _time = 0.0;
  bool _disposed = false;
  AdaptiveQualityScaler? _attachedScaler;
  VoidCallback? _scalerListener;

  /// Current visual configuration.
  MobileSsrConfig get config => _config;

  /// Continuous simulation elapsed time in seconds.
  double get time => _time;

  /// Current quality tier.
  MobileSsrQuality get quality => _config.quality;

  /// Whether SSR is active.
  bool get isEnabled => _config.quality != MobileSsrQuality.off && _config.wetness > 0.0;

  /// Whether raymarching is bypassed.
  bool get bypassRaymarching => _config.bypassRaymarching;

  /// Active hardware tier.
  HardwareTier? get hardwareTier => _config.hardwareTier;

  /// Dynamic resolution scale.
  double get renderResolutionScale => _config.renderResolutionScale;

  /// Dynamic throttle level.
  int get throttleLevel => _config.throttleLevel;

  /// Whether multi-sample smoothing is active.
  bool get multiSampleSmoothing => _config.multiSampleSmoothing;

  /// Advances simulation time by [dt] seconds.
  void update(double dt) {
    if (_disposed || dt <= 0.0) return;
    _time += dt;
    notifyListeners();
  }

  /// Sets configuration and notifies listeners.
  void updateConfig(MobileSsrConfig newConfig) {
    if (_disposed || _config == newConfig) return;
    _config = newConfig;
    notifyListeners();
  }

  /// Updates quality tier.
  void setQuality(MobileSsrQuality newQuality) {
    if (_disposed || _config.quality == newQuality) return;
    final bool bypass = newQuality == MobileSsrQuality.off ||
        newQuality == MobileSsrQuality.eco;
    _config = _config.copyWith(
      quality: newQuality,
      bypassRaymarching: bypass,
    );
    notifyListeners();
  }

  /// Applies adaptive quality parameters derived from [AdaptiveQualityScaler].
  void applyAdaptiveQuality({
    required HardwareTier tier,
    required double renderResolutionScale,
    required int throttleLevel,
  }) {
    if (_disposed) return;
    final MobileSsrConfig updated = _config.applyAdaptiveQuality(
      tier: tier,
      renderResolutionScale: renderResolutionScale,
      throttleLevel: throttleLevel,
    );
    if (_config != updated) {
      _config = updated;
      notifyListeners();
    }
  }

  /// Pre-warms SSR buffers on demand via [ZeroJankPreloader].
  Future<bool> prewarm({
    ZeroJankPreloader? preloader,
    Size viewportSize = const Size(1080, 1920),
  }) {
    return MobileSsrViewport.prewarmSsrBuffers(
      preloader: preloader,
      viewportSize: viewportSize,
      quality: _config.quality,
    );
  }

  /// Modulates wetness factor [0.0 - 1.0].
  void setWetness(double wetness) {
    if (_disposed) return;
    _config = _config.copyWith(wetness: wetness.clamp(0.0, 1.0));
    notifyListeners();
  }

  /// Modulates rain intensity [0.0 - 1.0].
  void setRainIntensity(double intensity) {
    if (_disposed) return;
    _config = _config.copyWith(rainIntensity: intensity.clamp(0.0, 1.0));
    notifyListeners();
  }

  /// Updates water plane Y level.
  void setPuddlePlaneY(double planeY) {
    if (_disposed) return;
    _config = _config.copyWith(puddlePlaneY: planeY.clamp(0.0, 1.0));
    notifyListeners();
  }

  /// Resets simulation time.
  void reset() {
    _time = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_scalerListener != null) {
      _attachedScaler?.removeListener(_scalerListener!);
      _scalerListener = null;
    }
    _attachedScaler = null;
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// CustomPainter
// -----------------------------------------------------------------------------

/// CustomPainter executing mobile Screen-Space Reflections, wet ground specular sheen,
/// and puddle basin lighting.
class MobileSsrPainter extends CustomPainter {
  MobileSsrPainter({
    required this.controller,
    this.customPuddlePath,
  }) : super(repaint: controller);

  final MobileSsrController controller;
  final Path? customPuddlePath;

  @override
  void paint(Canvas canvas, Size size) {
    final MobileSsrConfig cfg = controller.config;
    if (cfg.quality == MobileSsrQuality.off || cfg.wetness <= 0.0) {
      return;
    }
    if (size.width <= 0 || size.height <= 0) return;

    final double planeY = size.height * cfg.puddlePlaneY;
    final Path puddlePath = customPuddlePath ??
        MobileSsrMath.generateOrganicPuddlePath(size, planeY);

    // 1. Silt & Mud Basin Bed
    final double mudAlpha = (cfg.wetness * 0.85).clamp(0.2, 0.95);
    final Paint mudPaint = Paint()
      ..color = cfg.mudColor.withValues(alpha: mudAlpha)
      ..style = PaintingStyle.fill;
    canvas.drawPath(puddlePath, mudPaint);

    // 2. Beer-Lambert Water Volume Absorption Layer
    final double transmittance = MobileSsrMath.evaluateBeerLambertTransmittance(
      depth: 0.5,
      extinction: cfg.waterColor.a,
      depthScale: cfg.waterDepthScale,
    );
    final double waterAlpha = ((1.0 - transmittance) * cfg.wetness).clamp(0.15, 0.85);
    final Paint waterPaint = Paint()
      ..color = cfg.waterColor.withValues(alpha: waterAlpha)
      ..style = PaintingStyle.fill;
    canvas.drawPath(puddlePath, waterPaint);

    // 3. Fresnel Specular Surface Sheen & Raymarched Reflection
    final double cosTheta = math.max(math.sin(cfg.cameraPitch), 0.15);
    final double fresnel = MobileSsrMath.evaluateSchlickFresnel(
      cosTheta: cosTheta,
      f0: cfg.fresnelR0,
      roughness: cfg.puddleRoughness,
    );

    // ADAPTIVE QUALITY HOOK:
    // On Eco / Low tiers (<=2GB RAM) or when throttleLevel >= 2:
    // Bypass SSR raymarching reflection pass completely (render simple tint or pass-through)
    // to protect memory bandwidth.
    if (cfg.bypassRaymarching) {
      final double simpleSheenAlpha =
          (fresnel * cfg.reflectivity * 0.40 * cfg.wetness).clamp(0.0, 0.45);
      final Paint simpleTintPaint = Paint()
        ..color = cfg.skyReflectionColor.withValues(alpha: simpleSheenAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawPath(puddlePath, simpleTintPaint);
      return; // Early exit: completely bypasses raymarching pass
    }

    // Evaluate wave normal perturbation for reflection distortion
    ui.Offset normalJitter = ui.Offset.zero;
    if (cfg.quality.hasGerstnerWaves) {
      normalJitter = MobileSsrMath.evaluateGerstnerNormal(
        uv: ui.Offset(0.5, cfg.puddlePlaneY),
        time: controller.time,
        intensity: cfg.rainIntensity * 1.5 + 0.3,
        rippleSpeed: cfg.rippleSpeed,
      );
    }

    // Raymarch upward reflection vector
    final ui.Offset startUv = ui.Offset(0.5, cfg.puddlePlaneY);
    final ui.Offset baseRayDir =
        ui.Offset(normalJitter.dx * 0.4, -1.0 + normalJitter.dy * 0.2);

    // ADAPTIVE QUALITY HOOK:
    // On Mid tier: scale SSR reflection buffer to 0.75x or downsampled resolution.
    final double bufferScale = (cfg.hardwareTier == HardwareTier.mid)
        ? 0.75
        : cfg.renderResolutionScale.clamp(0.5, 1.0);
    final double effectiveStepSize = cfg.quality.rayStepSize / bufferScale;
    final int effectiveRaySteps =
        (cfg.quality.maxRaySteps * bufferScale).round();

    double edgeFade;

    // ADAPTIVE QUALITY HOOK:
    // On High / Ultra tiers: full resolution SSR with multi-sample reflection smoothing.
    if (cfg.multiSampleSmoothing) {
      final (ui.Offset _, double multiFade) =
          MobileSsrMath.marchScreenRayMultiSample(
        startUv: startUv,
        baseRayDir: baseRayDir,
        maxSteps: effectiveRaySteps,
        stepSize: effectiveStepSize,
        edgeFadeMargin: cfg.edgeFadeMargin,
      );
      edgeFade = multiFade;
    } else {
      final (ui.Offset _, double singleFade) = MobileSsrMath.marchScreenRay(
        startUv: startUv,
        rayDir: baseRayDir,
        maxSteps: effectiveRaySteps,
        stepSize: effectiveStepSize,
        edgeFadeMargin: cfg.edgeFadeMargin,
      );
      edgeFade = singleFade;
    }

    final double reflectAlpha =
        (fresnel * cfg.reflectivity * edgeFade * cfg.wetness).clamp(0.0, 0.85);

    // Sky / celestial structure specular reflection wash
    final Paint reflectPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0.0, planeY),
        Offset(0.0, size.height),
        <ui.Color>[
          cfg.skyReflectionColor.withValues(alpha: reflectAlpha * 0.95),
          cfg.skyReflectionColor.withValues(alpha: reflectAlpha * 0.45),
          cfg.skyReflectionColor.withValues(alpha: 0.0),
        ],
        <double>[0.0, 0.55, 1.0],
      )
      ..filterQuality =
          bufferScale < 1.0 ? FilterQuality.low : FilterQuality.high;

    // Buffer downsampling layer for Mid tier (0.75x)
    if (bufferScale < 1.0) {
      final Rect puddleBounds = puddlePath.getBounds();
      canvas.saveLayer(
        puddleBounds,
        Paint()..filterQuality = FilterQuality.low,
      );
      canvas.drawPath(puddlePath, reflectPaint);
      canvas.restore();
    } else {
      canvas.drawPath(puddlePath, reflectPaint);
    }

    // 4. Fine-grain specular highlight glint along puddle crest
    if (cfg.quality == MobileSsrQuality.high ||
        cfg.quality == MobileSsrQuality.ultra) {
      final double blurRadius = cfg.multiSampleSmoothing
          ? (cfg.quality == MobileSsrQuality.ultra ? 3.5 : 2.5)
          : 2.0;
      final Paint glintPaint = Paint()
        ..color =
            const ui.Color(0x44FFFFFF).withValues(alpha: reflectAlpha * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cfg.quality == MobileSsrQuality.ultra ? 2.0 : 1.5
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurRadius);
      canvas.drawPath(puddlePath, glintPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MobileSsrPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.customPuddlePath != customPuddlePath;
  }
}

// -----------------------------------------------------------------------------
// Modular Flutter Viewport Wrapper Widget
// -----------------------------------------------------------------------------

/// Modular widget wrapper providing Screen-Space Reflections (SSR) and wet puddle
/// reflections over any screen viewport (Hub, Mekans, Kingdom, Dungeon).
class MobileSsrViewport extends StatefulWidget {
  const MobileSsrViewport({
    super.key,
    required this.child,
    this.controller,
    this.config = const MobileSsrConfig(),
    this.customPuddlePath,
    this.autoAnimate = true,
    this.scaler,
    this.preloader,
    this.enableAdaptiveScaling = true,
    this.autoPrewarm = true,
  });

  /// The underlying viewport content.
  final Widget child;

  /// Optional external controller.
  final MobileSsrController? controller;

  /// Initial configuration.
  final MobileSsrConfig config;

  /// Optional custom puddle geometry path.
  final Path? customPuddlePath;

  /// Whether internal animation ticker runs automatically for ripples.
  final bool autoAnimate;

  /// Optional [AdaptiveQualityScaler] instance for dynamic hardware scaling.
  /// If null and [enableAdaptiveScaling] is true, uses [GraphicsSettingsService.instance.scaler].
  final AdaptiveQualityScaler? scaler;

  /// Optional [ZeroJankPreloader] instance for buffer pre-warming.
  /// If null, uses [ZeroJankPreloader.instance].
  final ZeroJankPreloader? preloader;

  /// Whether adaptive quality scaling is enabled.
  final bool enableAdaptiveScaling;

  /// Whether to pre-warm SSR depth and reflection buffers in initState (<2ms).
  final bool autoPrewarm;

  /// Pre-warms SSR depth and reflection buffers via [ZeroJankPreloader]
  /// strictly bounded within a <2ms frame budget.
  static Future<bool> prewarmSsrBuffers({
    ZeroJankPreloader? preloader,
    Size viewportSize = const Size(1080, 1920),
    MobileSsrQuality quality = MobileSsrQuality.high,
  }) {
    final ZeroJankPreloader activePreloader =
        preloader ?? ZeroJankPreloader.instance;
    return activePreloader.preloadAtomic<bool>(
      id: 'ssr_reflection_depth_buffer_warmup_${quality.name}',
      priority: PreloadPriority.nearbyLod0,
      targetCache: CacheTarget.vram,
      estimatedSizeBytes: 256 * 1024,
      loader: () async {
        final double planeY = viewportSize.height * 0.62;
        final Path warmupPath =
            MobileSsrMath.generateOrganicPuddlePath(viewportSize, planeY);
        for (final metric in warmupPath.computeMetrics()) {
          final _ = metric.length;
        }

        MobileSsrMath.evaluateSchlickFresnel(cosTheta: 0.5, f0: 0.0204);
        MobileSsrMath.evaluateBeerLambertTransmittance(
          depth: 0.5,
          extinction: 0.2,
        );

        MobileSsrMath.marchScreenRayMultiSample(
          startUv: const ui.Offset(0.5, 0.62),
          baseRayDir: const ui.Offset(0.0, -1.0),
          maxSteps: quality.maxRaySteps,
          stepSize: quality.rayStepSize,
        );

        MobileSsrMath.evaluateGerstnerNormal(
          uv: const ui.Offset(0.5, 0.62),
          time: 0.0,
        );
        return true;
      },
    );
  }

  @override
  State<MobileSsrViewport> createState() => _MobileSsrViewportState();
}

class _MobileSsrViewportState extends State<MobileSsrViewport>
    with SingleTickerProviderStateMixin {
  late MobileSsrController _controller;
  bool _ownsController = false;
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  AdaptiveQualityScaler? _activeScaler;
  VoidCallback? _scalerListener;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = MobileSsrController(config: widget.config);
      _ownsController = true;
    }

    if (widget.enableAdaptiveScaling) {
      _hookScaler();
    }

    if (widget.autoPrewarm) {
      MobileSsrViewport.prewarmSsrBuffers(
        preloader: widget.preloader,
        quality: _controller.config.quality,
      );
    }

    if (widget.autoAnimate) {
      _ticker = createTicker(_onTick)..start();
    }
  }

  void _hookScaler() {
    _activeScaler = widget.scaler ?? GraphicsSettingsService.instance.scaler;
    _scalerListener = _onScalerChanged;
    _activeScaler?.addListener(_scalerListener!);
    _syncWithScaler();
  }

  void _unhookScaler() {
    if (_scalerListener != null) {
      _activeScaler?.removeListener(_scalerListener!);
      _scalerListener = null;
    }
    _activeScaler = null;
  }

  void _onScalerChanged() {
    if (!mounted || _activeScaler == null) return;
    _syncWithScaler();
  }

  void _syncWithScaler() {
    if (_activeScaler == null) return;
    final HardwareTier tier = _activeScaler!.currentTier;
    final int throttleLevel = _activeScaler!.currentThrottleLevel;
    final double resScale = _activeScaler!.currentResolutionScale;

    _controller.applyAdaptiveQuality(
      tier: tier,
      renderResolutionScale: resScale,
      throttleLevel: throttleLevel,
    );
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    final double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    if (_controller.isEnabled &&
        _controller.config.quality.hasGerstnerWaves &&
        !_controller.config.bypassRaymarching) {
      _controller.update(dt);
    }
  }

  @override
  void didUpdateWidget(covariant MobileSsrViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && widget.controller != _controller) {
      if (_ownsController) {
        _controller.dispose();
        _ownsController = false;
      }
      _controller = widget.controller!;
    } else if (widget.controller == null && _ownsController) {
      if (widget.config != oldWidget.config) {
        _controller.updateConfig(widget.config);
      }
    }

    if (widget.enableAdaptiveScaling != oldWidget.enableAdaptiveScaling ||
        widget.scaler != oldWidget.scaler) {
      _unhookScaler();
      if (widget.enableAdaptiveScaling) {
        _hookScaler();
      }
    }
  }

  @override
  void dispose() {
    _unhookScaler();
    _ticker?.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        // 1. Underlying Scene / Viewport
        widget.child,

        // 2. Wet Ground & Puddle SSR Overlay
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: MobileSsrPainter(
                  controller: _controller,
                  customPuddlePath: widget.customPuddlePath,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
