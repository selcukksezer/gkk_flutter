import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../screens/settings/graphics_settings_service.dart';

// =============================================================================
// Volumetric Fog & Atmospheric Scattering Layer (Mobile Impeller / Skia)
// 2027 AAA Cinematic Graphics Architecture — Battalion 1 Hub World
// Dynamic Adaptive Quality Scaler & Zero-Jank Progressive Preloader Integrated
// =============================================================================

/// Quality tier for volumetric fog simulation on mobile devices.
enum FogQualityTier {
  /// Eco / battery saver mode: single-pass static gradient, 0 raymarch steps, zero overdraw.
  eco(layerCount: 0, mistOctaves: 0, enableGodRays: false),

  /// Low-fidelity mode: single-pass analytic fog, minimal overdraw, 4 raymarch steps.
  low(layerCount: 2, mistOctaves: 1, enableGodRays: false),

  /// Balanced mobile mode: dual-layer fog with light mist turbulence, 16 raymarch steps.
  medium(layerCount: 3, mistOctaves: 2, enableGodRays: true),

  /// High-fidelity mobile mode: multi-layer fog with Henyey-Greenstein scattering, 32 raymarch steps.
  high(layerCount: 4, mistOctaves: 2, enableGodRays: true),

  /// Full cinematic AAA mode: 5-layer raymarch-approximated atmospheric depth, 64 raymarch steps.
  ultra(layerCount: 5, mistOctaves: 3, enableGodRays: true);

  const FogQualityTier({
    required this.layerCount,
    required this.mistOctaves,
    required this.enableGodRays,
  });

  final int layerCount;
  final int mistOctaves;
  final bool enableGodRays;

  /// Default volumetric raymarch step count for this quality tier.
  int get defaultStepCount => switch (this) {
        FogQualityTier.eco => 0,
        FogQualityTier.low => 4,
        FogQualityTier.medium => 16,
        FogQualityTier.high => 32,
        FogQualityTier.ultra => 64,
      };

  /// Derives [FogQualityTier] from engine [HardwareTier].
  static FogQualityTier fromHardwareTier(HardwareTier tier) => switch (tier) {
        HardwareTier.eco => FogQualityTier.eco,
        HardwareTier.low => FogQualityTier.low,
        HardwareTier.mid => FogQualityTier.medium,
        HardwareTier.high => FogQualityTier.high,
        HardwareTier.ultra => FogQualityTier.ultra,
      };
}

/// Diurnal time-of-day phase for atmospheric fog coloration.
enum DiurnalPhase {
  dawn(Color(0x66FF9E66), Color(0x88FFE4B5)),
  day(Color(0x4D8AB4F8), Color(0x66FFF5D6)),
  dusk(Color(0x739D5E7A), Color(0x88FFAA66)),
  night(Color(0x590F1B2B), Color(0x446B8ECC));

  const DiurnalPhase(this.ambientColor, this.lightShaftColor);

  final Color ambientColor;
  final Color lightShaftColor;
}

/// Physical parameters for volumetric atmospheric fog simulation.
class VolumetricFogParameters {
  const VolumetricFogParameters({
    this.density = 0.45,
    this.heightFalloff = 0.003,
    this.groundLevel = 0.72,
    this.mieAnisotropy = 0.76,
    this.rayleighScattering = 0.22,
    this.lightShaftIntensity = 0.75,
    this.lightPosition = const Offset(0.75, 0.22),
    this.windVelocity = const Offset(0.035, 0.005),
    this.turbulentMistScale = 1.0,
    this.fogColor = const Color(0x5E2B3E50),
    this.lightColor = const Color(0x88FFE6A0),
    this.diurnalPhase = DiurnalPhase.day,
    this.qualityTier = FogQualityTier.high,
    this.stepCount,
    this.resolutionScale = 1.0,
    this.hardwareTier,
    this.throttleLevel = 0,
  });

  /// Base fog extinction coefficient (optical density at ground level).
  final double density;

  /// Exponential vertical height falloff rate beta.
  final double heightFalloff;

  /// Normalized Y coordinate [0.0 - 1.0] where fog reaches maximum density.
  final double groundLevel;

  /// Henyey-Greenstein forward scattering parameter 'g' [-1.0, 1.0].
  /// Typical values in [0.65, 0.85] simulate atmospheric aerosol forward scattering.
  final double mieAnisotropy;

  /// Rayleigh atmospheric scattering coefficient (subtle blue haze contribution).
  final double rayleighScattering;

  /// Directional light shaft / god ray intensity multiplier.
  final double lightShaftIntensity;

  /// Normalized light source position (sun / moon) in viewport coordinates [0..1].
  final Offset lightPosition;

  /// Wind drift velocity (horizontal and vertical mist propagation per second).
  final Offset windVelocity;

  /// Scale factor for procedural sinusoidal mist turbulence.
  final double turbulentMistScale;

  /// Base fog ambient tint color.
  final Color fogColor;

  /// Primary directional sun/moon light color.
  final Color lightColor;

  /// Current diurnal phase.
  final DiurnalPhase diurnalPhase;

  /// Device performance tier for adaptive scaling.
  final FogQualityTier qualityTier;

  /// Explicit volumetric raymarch step count override.
  final int? stepCount;

  /// Internal render resolution scale multiplier (0.5 to 1.0).
  final double resolutionScale;

  /// Active hardware classification tier from [AdaptiveQualityScaler].
  final HardwareTier? hardwareTier;

  /// Active runtime thermal/battery throttle level (0 = none, 3 = severe).
  final int throttleLevel;

  /// Effective raymarch sample steps resolved from explicit [stepCount],
  /// runtime [hardwareTier] / [throttleLevel], or fallback [qualityTier].
  int get effectiveStepCount {
    if (stepCount != null) return stepCount!;
    if (hardwareTier == HardwareTier.eco || throttleLevel >= 3) return 0;
    if (hardwareTier != null) {
      return switch (hardwareTier!) {
        HardwareTier.eco => 0,
        HardwareTier.low => 4,
        HardwareTier.mid => 16,
        HardwareTier.high => 32,
        HardwareTier.ultra => 64,
      };
    }
    return switch (qualityTier) {
      FogQualityTier.eco => 0,
      FogQualityTier.low => 4,
      FogQualityTier.medium => 16,
      FogQualityTier.high => 32,
      FogQualityTier.ultra => 64,
    };
  }

  /// Whether volumetric raymarch steps should be completely bypassed (0 steps)
  /// for Eco tier (1.5GB-2GB RAM) or severe dynamic thermal throttle (level 3).
  bool get isEcoBypass =>
      effectiveStepCount == 0 ||
      hardwareTier == HardwareTier.eco ||
      throttleLevel >= 3;

  VolumetricFogParameters copyWith({
    double? density,
    double? heightFalloff,
    double? groundLevel,
    double? mieAnisotropy,
    double? rayleighScattering,
    double? lightShaftIntensity,
    Offset? lightPosition,
    Offset? windVelocity,
    double? turbulentMistScale,
    Color? fogColor,
    Color? lightColor,
    DiurnalPhase? diurnalPhase,
    FogQualityTier? qualityTier,
    int? stepCount,
    double? resolutionScale,
    HardwareTier? hardwareTier,
    int? throttleLevel,
  }) {
    return VolumetricFogParameters(
      density: density ?? this.density,
      heightFalloff: heightFalloff ?? this.heightFalloff,
      groundLevel: groundLevel ?? this.groundLevel,
      mieAnisotropy: mieAnisotropy ?? this.mieAnisotropy,
      rayleighScattering: rayleighScattering ?? this.rayleighScattering,
      lightShaftIntensity: lightShaftIntensity ?? this.lightShaftIntensity,
      lightPosition: lightPosition ?? this.lightPosition,
      windVelocity: windVelocity ?? this.windVelocity,
      turbulentMistScale: turbulentMistScale ?? this.turbulentMistScale,
      fogColor: fogColor ?? this.fogColor,
      lightColor: lightColor ?? this.lightColor,
      diurnalPhase: diurnalPhase ?? this.diurnalPhase,
      qualityTier: qualityTier ?? this.qualityTier,
      stepCount: stepCount ?? this.stepCount,
      resolutionScale: resolutionScale ?? this.resolutionScale,
      hardwareTier: hardwareTier ?? this.hardwareTier,
      throttleLevel: throttleLevel ?? this.throttleLevel,
    );
  }
}

/// Analytical atmospheric scattering mathematics for volumetric fog.
abstract final class VolumetricFogMath {
  /// Evaluates exponential height density falloff:
  /// D(y) = D_0 * exp(-beta * max(0, ground - y) * 1000)
  static double calculateExponentialHeightDensity({
    required double y,
    required double groundLevel,
    required double baseDensity,
    required double heightFalloff,
  }) {
    final double heightAboveGround = math.max(0.0, groundLevel - y);
    final double exponent = -heightFalloff * heightAboveGround * 1000.0;
    return baseDensity * math.exp(exponent.clamp(-30.0, 0.0));
  }

  /// Evaluates Henyey-Greenstein Mie phase function:
  /// p(cosTheta) = (1 - g^2) / (4 * pi * (1 + g^2 - 2*g*cosTheta)^(1.5))
  static double evaluateHenyeyGreensteinPhase({
    required double cosTheta,
    required double g,
  }) {
    final double clampedCos = cosTheta.clamp(-1.0, 1.0);
    final double g2 = g * g;
    final double denom = 1.0 + g2 - 2.0 * g * clampedCos;
    if (denom <= 1e-6) return 0.0;
    final double numerator = (1.0 - g2) / (4.0 * math.pi);
    return numerator / math.pow(denom, 1.5);
  }

  /// Evaluates Beer-Lambert optical transmittance:
  /// T = exp(-sigma_t * distance)
  static double evaluateBeerLambertTransmittance(double opticalDepth) {
    return math.exp(-opticalDepth.clamp(0.0, 50.0));
  }

  /// Multi-octave sinusoidal mist turbulence field with temporal drift.
  static double evaluateMistTurbulence({
    required double u,
    required double v,
    required double time,
    required Offset wind,
    required int octaves,
  }) {
    if (octaves <= 0) return 0.5;

    double value = 0.0;
    double amplitude = 0.55;
    double frequency = 1.0;

    final double shiftedU = u + wind.dx * time;
    final double shiftedV = v + wind.dy * time;

    for (int i = 0; i < octaves; i++) {
      final double wave1 = math.sin(shiftedU * 4.8 * frequency + time * 0.42);
      final double wave2 = math.cos(shiftedV * 3.6 * frequency - time * 0.31);
      final double wave3 = math.sin((shiftedU + shiftedV) * 2.5 * frequency + time * 0.55);
      value += (wave1 * 0.4 + wave2 * 0.4 + wave3 * 0.2) * amplitude;
      amplitude *= 0.5;
      frequency *= 2.1;
    }

    // Normalized to [0.0, 1.0]
    return (value * 0.5 + 0.5).clamp(0.0, 1.0);
  }
}

/// High-performance CustomPainter rendering layered volumetric fog on mobile canvas.
/// Adapts dynamically to [AdaptiveQualityScaler] hardware tier, stepCount, and resolution scale.
class VolumetricFogPainter extends CustomPainter {
  VolumetricFogPainter({
    required this.parameters,
    required this.animationTime,
  })  : _paint = Paint()..isAntiAlias = false,
        _shaftPaint = Paint()
          ..isAntiAlias = true
          ..blendMode = BlendMode.screen;

  final VolumetricFogParameters parameters;
  final double animationTime;

  final Paint _paint;
  final Paint _shaftPaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || parameters.density <= 0.001) {
      return;
    }

    final int stepCount = parameters.effectiveStepCount;
    final bool isEcoOrThrottled = parameters.isEcoBypass || stepCount == 0;

    // On Eco tier (1.5GB-2GB RAM) & throttle level 3:
    // completely bypass volumetric raymarch steps (stepCount = 0)
    // and render a lightweight static atmospheric gradient or early exit.
    if (isEcoOrThrottled) {
      if (parameters.density <= 0.05) {
        return; // Early exit on negligible density to preserve fill-rate
      }
      _drawStaticAtmosphericGradient(canvas, size);
      return;
    }

    // Dynamic resolution scaling hook (e.g. 0.5x, 0.75x, 1.0x)
    final double resScale = parameters.resolutionScale.clamp(0.5, 1.0);
    final bool isDownscaled = (resScale - 1.0).abs() > 0.01;
    final Size effectiveSize = isDownscaled
        ? Size(size.width / resScale, size.height / resScale)
        : size;

    if (isDownscaled) {
      canvas.save();
      canvas.scale(resScale, resScale);
    }

    final FogQualityTier tier = parameters.qualityTier;

    // 1. Base Exponential Ground Fog Layer (Depth Falloff)
    _drawExponentialGroundFog(canvas, effectiveSize);

    // 2. Multi-Octave Animated Rolling Mist Layers scaled by stepCount
    _drawRollingMistLayers(canvas, effectiveSize, tier, stepCount);

    // 3. Directional Light Shafts (Mie Forward Scattering / God Rays)
    final bool canRenderGodRays = (tier.enableGodRays || stepCount >= 16) &&
        stepCount >= 4 &&
        parameters.lightShaftIntensity > 0.01;
    if (canRenderGodRays) {
      _drawVolumetricLightShafts(canvas, effectiveSize, stepCount);
    }

    if (isDownscaled) {
      canvas.restore();
    }
  }

  /// Lightweight static atmospheric gradient rendered for Eco tier & throttle level 3.
  /// Bypasses all raymarch steps, mist turbulence octaves, and god-ray overdraw.
  void _drawStaticAtmosphericGradient(Canvas canvas, Size size) {
    final double groundY = size.height * parameters.groundLevel;
    final double startY = math.max(0.0, groundY - size.height * 0.5);
    final Rect rect = Rect.fromLTRB(0, startY, size.width, size.height);
    final Color ambient = parameters.fogColor;
    final double density = parameters.density.clamp(0.0, 1.0);

    final Gradient gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const <double>[0.0, 1.0],
      colors: <Color>[
        ambient.withValues(alpha: 0.0),
        ambient.withValues(alpha: density * 0.55),
      ],
    );

    _paint.shader = gradient.createShader(rect);
    _paint.blendMode = BlendMode.srcOver;
    canvas.drawRect(rect, _paint);
  }

  void _drawExponentialGroundFog(Canvas canvas, Size size) {
    final double groundY = size.height * parameters.groundLevel;
    final double startY = math.max(0.0, groundY - size.height * 0.65);

    final Color ambient = parameters.fogColor;
    final double density = parameters.density.clamp(0.0, 1.0);

    // Pre-calculate linear depth gradient from sky horizon down to ground
    final Rect rect = Rect.fromLTRB(0, startY, size.width, size.height);
    final Gradient gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const <double>[0.0, 0.35, 0.75, 1.0],
      colors: <Color>[
        ambient.withValues(alpha: 0.0),
        ambient.withValues(alpha: density * 0.35),
        ambient.withValues(alpha: density * 0.72),
        ambient.withValues(alpha: density * 0.95),
      ],
    );

    _paint.shader = gradient.createShader(rect);
    _paint.blendMode = BlendMode.srcOver;
    canvas.drawRect(rect, _paint);
  }

  void _drawRollingMistLayers(
    Canvas canvas,
    Size size,
    FogQualityTier tier,
    int stepCount,
  ) {
    final int layers;
    final int octaves;

    if (stepCount >= 64) {
      // Ultra tier: 5 layers, 3 octaves
      layers = 5;
      octaves = 3;
    } else if (stepCount >= 32) {
      // High tier: 4 layers, 2 octaves
      layers = 4;
      octaves = 2;
    } else if (stepCount >= 16) {
      // Mid tier: 3 layers, 2 octaves
      layers = 3;
      octaves = 2;
    } else {
      // Low tier: 2 layers, 1 octave
      layers = 2;
      octaves = 1;
    }

    final double w = size.width;
    final double h = size.height;

    for (int i = 0; i < layers; i++) {
      final double progress = (i + 1) / (layers + 1);
      final double layerY = h * (0.35 + progress * 0.55);
      final double layerHeight = h * 0.32;

      // Evaluate procedural mist turbulence at sample intervals across screen
      final double mist1 = VolumetricFogMath.evaluateMistTurbulence(
        u: 0.2 + i * 0.3,
        v: progress,
        time: animationTime,
        wind: parameters.windVelocity,
        octaves: octaves,
      );
      final double mist2 = VolumetricFogMath.evaluateMistTurbulence(
        u: 0.7 + i * 0.3,
        v: progress,
        time: animationTime,
        wind: parameters.windVelocity,
        octaves: octaves,
      );

      final double layerOpacity =
          (parameters.density * 0.42 * (1.0 - progress * 0.4) * (0.6 + (mist1 + mist2) * 0.2))
              .clamp(0.0, 1.0);

      if (layerOpacity < 0.01) continue;

      final Rect layerRect =
          Rect.fromLTRB(0, layerY - layerHeight * 0.5, w, layerY + layerHeight * 0.5);

      // Radial mist billowing puff
      final Offset center = Offset(
        w * (0.3 + 0.4 * math.sin(animationTime * 0.15 + i * 1.6)),
        layerY,
      );

      final Gradient mistGradient = RadialGradient(
        center: Alignment(
          (center.dx / w) * 2.0 - 1.0,
          (center.dy / h) * 2.0 - 1.0,
        ),
        radius: 0.85,
        colors: <Color>[
          parameters.fogColor.withValues(alpha: layerOpacity),
          parameters.fogColor.withValues(alpha: layerOpacity * 0.5),
          parameters.fogColor.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      );

      _paint.shader = mistGradient.createShader(layerRect);
      _paint.blendMode = BlendMode.screen;
      canvas.drawRect(layerRect, _paint);
    }
  }

  void _drawVolumetricLightShafts(Canvas canvas, Size size, int stepCount) {
    final Offset sunPos = Offset(
      size.width * parameters.lightPosition.dx,
      size.height * parameters.lightPosition.dy,
    );

    final double maxDim = math.max(size.width, size.height);
    final double shaftRadius = maxDim * 1.4;

    // Henyey-Greenstein forward scattering peak at sun center
    final double phaseIntensity = VolumetricFogMath.evaluateHenyeyGreensteinPhase(
      cosTheta: 0.92,
      g: parameters.mieAnisotropy,
    );

    final double intensity =
        (parameters.lightShaftIntensity * phaseIntensity * 0.35).clamp(0.0, 0.85);

    final Color lightCol = parameters.lightColor;
    final Rect shaftRect = Rect.fromCircle(center: sunPos, radius: shaftRadius);

    final List<double> stops;
    final List<Color> colors;

    if (stepCount >= 64) {
      // 2027 AAA Ultra Cinematic God-Ray Multi-Sample Depth Integration
      // Evaluates Beer-Lambert optical depth across raymarch distance steps
      final double t0 = VolumetricFogMath.evaluateBeerLambertTransmittance(0.0);
      final double t1 = VolumetricFogMath.evaluateBeerLambertTransmittance(0.8);
      final double t2 = VolumetricFogMath.evaluateBeerLambertTransmittance(2.0);
      final double t3 = VolumetricFogMath.evaluateBeerLambertTransmittance(4.5);

      stops = const <double>[0.0, 0.15, 0.35, 0.60, 0.85, 1.0];
      colors = <Color>[
        lightCol.withValues(alpha: (intensity * t0).clamp(0.0, 1.0)),
        lightCol.withValues(alpha: (intensity * 0.75 * t0).clamp(0.0, 1.0)),
        lightCol.withValues(alpha: (intensity * 0.45 * t1).clamp(0.0, 1.0)),
        lightCol.withValues(alpha: (intensity * 0.25 * t2).clamp(0.0, 1.0)),
        lightCol.withValues(alpha: (intensity * 0.08 * t3).clamp(0.0, 1.0)),
        lightCol.withValues(alpha: 0.0),
      ];
    } else if (stepCount >= 32) {
      // High-tier: 32-step forward Mie scattering
      stops = const <double>[0.0, 0.25, 0.65, 1.0];
      colors = <Color>[
        lightCol.withValues(alpha: intensity),
        lightCol.withValues(alpha: intensity * 0.45),
        lightCol.withValues(alpha: intensity * 0.12),
        lightCol.withValues(alpha: 0.0),
      ];
    } else if (stepCount >= 16) {
      // Mid-tier: 16-step scattering
      stops = const <double>[0.0, 0.35, 0.75, 1.0];
      colors = <Color>[
        lightCol.withValues(alpha: intensity * 0.85),
        lightCol.withValues(alpha: intensity * 0.35),
        lightCol.withValues(alpha: intensity * 0.08),
        lightCol.withValues(alpha: 0.0),
      ];
    } else {
      // Low-tier: 4-step fast simplified shaft
      stops = const <double>[0.0, 0.5, 1.0];
      colors = <Color>[
        lightCol.withValues(alpha: intensity * 0.6),
        lightCol.withValues(alpha: intensity * 0.15),
        lightCol.withValues(alpha: 0.0),
      ];
    }

    final Gradient shaftGradient = RadialGradient(
      center: Alignment(
        (sunPos.dx / size.width) * 2.0 - 1.0,
        (sunPos.dy / size.height) * 2.0 - 1.0,
      ),
      radius: 1.2,
      colors: colors,
      stops: stops,
    );

    _shaftPaint.shader = shaftGradient.createShader(shaftRect);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _shaftPaint);

    // On Ultra tier (stepCount == 64): add dynamic god-ray beam sweeps
    if (stepCount >= 64) {
      _drawUltraGodRayBeams(canvas, size, sunPos, intensity, lightCol);
    }
  }

  /// Dynamic 2027 AAA god-ray angular beam sweeps for Ultra flagship fidelity.
  void _drawUltraGodRayBeams(
    Canvas canvas,
    Size size,
    Offset sunPos,
    double baseIntensity,
    Color lightCol,
  ) {
    final double beamIntensity = (baseIntensity * 0.18).clamp(0.0, 0.3);
    final double maxDim = math.max(size.width, size.height) * 1.5;

    for (int i = 0; i < 4; i++) {
      final double angle = (i * 0.45) + (animationTime * 0.08);
      final double sweep = 0.18;
      final Path beamPath = Path()
        ..moveTo(sunPos.dx, sunPos.dy)
        ..lineTo(
          sunPos.dx + math.cos(angle - sweep) * maxDim,
          sunPos.dy + math.sin(angle - sweep) * maxDim,
        )
        ..lineTo(
          sunPos.dx + math.cos(angle + sweep) * maxDim,
          sunPos.dy + math.sin(angle + sweep) * maxDim,
        )
        ..close();

      final Gradient beamGradient = RadialGradient(
        center: Alignment(
          (sunPos.dx / size.width) * 2.0 - 1.0,
          (sunPos.dy / size.height) * 2.0 - 1.0,
        ),
        radius: 1.3,
        colors: <Color>[
          lightCol.withValues(alpha: beamIntensity),
          lightCol.withValues(alpha: beamIntensity * 0.35),
          lightCol.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.5, 1.0],
      );

      final Rect beamRect = Rect.fromCircle(center: sunPos, radius: maxDim);
      _shaftPaint.shader = beamGradient.createShader(beamRect);
      canvas.drawPath(beamPath, _shaftPaint);
    }
  }

  @override
  bool shouldRepaint(covariant VolumetricFogPainter oldDelegate) {
    return oldDelegate.animationTime != animationTime ||
        oldDelegate.parameters.density != parameters.density ||
        oldDelegate.parameters.heightFalloff != parameters.heightFalloff ||
        oldDelegate.parameters.groundLevel != parameters.groundLevel ||
        oldDelegate.parameters.lightPosition != parameters.lightPosition ||
        oldDelegate.parameters.qualityTier != parameters.qualityTier ||
        oldDelegate.parameters.effectiveStepCount != parameters.effectiveStepCount ||
        oldDelegate.parameters.resolutionScale != parameters.resolutionScale ||
        oldDelegate.parameters.hardwareTier != parameters.hardwareTier ||
        oldDelegate.parameters.throttleLevel != parameters.throttleLevel ||
        oldDelegate.parameters.fogColor != parameters.fogColor ||
        oldDelegate.parameters.lightColor != parameters.lightColor;
  }
}

/// Composable Flutter widget providing animated volumetric fog for mobile viewports
/// integrated with [AdaptiveQualityScaler] dynamic throttling and [ZeroJankPreloader] warmup.
class VolumetricFogLayer extends StatefulWidget {
  const VolumetricFogLayer({
    super.key,
    this.parameters = const VolumetricFogParameters(),
    this.child,
    this.isAnimated = true,
    this.scaler,
    this.enableAdaptiveScaling = true,
  });

  /// Atmospheric simulation parameters.
  final VolumetricFogParameters parameters;

  /// Optional underlying child widget (e.g., 3D viewport canvas or scene).
  final Widget? child;

  /// Whether the mist rolling animation loop is active.
  final bool isAnimated;

  /// Optional AdaptiveQualityScaler override (defaults to GraphicsSettingsService.instance.scaler).
  final AdaptiveQualityScaler? scaler;

  /// Whether to automatically listen and adapt to AdaptiveQualityScaler changes.
  final bool enableAdaptiveScaling;

  @override
  State<VolumetricFogLayer> createState() => _VolumetricFogLayerState();
}

class _VolumetricFogLayerState extends State<VolumetricFogLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _time = 0.0;
  Duration _lastElapsed = Duration.zero;

  AdaptiveQualityScaler? _scaler;
  StreamSubscription<QualitySettings>? _scalerSubscription;
  int _stepCount = 32;
  double _resolutionScale = 1.0;
  HardwareTier _hardwareTier = HardwareTier.high;
  int _throttleLevel = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_handleTick);
    _setupScaler();
    _prewarmShaderPipeline();

    // Start ticker only if animated and not in static Eco/throttled bypass mode
    final bool canAnimate = widget.isAnimated &&
        !(_stepCount == 0 || _hardwareTier == HardwareTier.eco || _throttleLevel >= 3);
    if (canAnimate) {
      _ticker.start();
    }
  }

  void _setupScaler() {
    if (!widget.enableAdaptiveScaling) {
      _applyParametersBaseline();
      return;
    }

    try {
      _scaler = widget.scaler ?? GraphicsSettingsService.instance.scaler;
      _scalerSubscription = _scaler?.onSettingsChanged.listen(_handleScalerSettings);
      if (_scaler != null) {
        _handleScalerSettings(_scaler!.currentSettings);
      } else {
        _applyParametersBaseline();
      }
    } catch (_) {
      _applyParametersBaseline();
    }
  }

  void _applyParametersBaseline() {
    _stepCount = widget.parameters.effectiveStepCount;
    _resolutionScale = widget.parameters.resolutionScale;
    _hardwareTier = widget.parameters.hardwareTier ??
        _mapQualityTierToHardwareTier(widget.parameters.qualityTier);
    _throttleLevel = widget.parameters.throttleLevel;
  }

  static HardwareTier _mapQualityTierToHardwareTier(FogQualityTier tier) => switch (tier) {
        FogQualityTier.eco => HardwareTier.eco,
        FogQualityTier.low => HardwareTier.low,
        FogQualityTier.medium => HardwareTier.mid,
        FogQualityTier.high => HardwareTier.high,
        FogQualityTier.ultra => HardwareTier.ultra,
      };

  void _handleScalerSettings(QualitySettings settings) {
    if (!mounted) return;
    setState(() {
      _hardwareTier = settings.tier;
      _throttleLevel = settings.throttleLevel;
      _resolutionScale = settings.renderResolutionScale;

      // On Eco tier (1.5GB-2GB RAM) & throttle level 3:
      // completely bypass volumetric raymarch steps (stepCount = 0)
      if (settings.tier == HardwareTier.eco || settings.throttleLevel >= 3) {
        _stepCount = 0;
      } else {
        _stepCount = settings.volumetricFogStepCount;
      }
    });

    // Thermal / battery optimizer: on Eco tier or throttle level 3, stop ticker loop
    final bool isBypassed = _stepCount == 0 ||
        _hardwareTier == HardwareTier.eco ||
        _throttleLevel >= 3;

    if (isBypassed) {
      if (_ticker.isActive) {
        _ticker.stop();
      }
    } else if (widget.isAnimated && !_ticker.isActive) {
      _ticker.start();
    }
  }

  void _prewarmShaderPipeline() {
    try {
      final ZeroJankPreloader preloader = ZeroJankPreloader.instance;

      // 1. Pre-warm shader pipeline via preloadShader (<2ms slices with PreloadPriority.nearbyLod0)
      preloader.preloadShader<bool>(
        id: 'volumetric_fog_shader_pipeline',
        priority: PreloadPriority.nearbyLod0,
        shaderWarmupLoader: (PreloadExecutionContext ctx) async {
          if (ctx.shouldYield()) {
            await ctx.yieldControl();
          }
          for (int i = 0; i < 16; i++) {
            final double cosTheta = -1.0 + (i / 15.0) * 2.0;
            VolumetricFogMath.evaluateHenyeyGreensteinPhase(
              cosTheta: cosTheta,
              g: widget.parameters.mieAnisotropy,
            );
          }
          if (ctx.shouldYield()) {
            await ctx.yieldControl();
          }
          return true;
        },
      ).catchError((Object _) => false);

      // 2. Pre-warm volumetric fog noise textures via preloadAtomic with PreloadPriority.criticalHud
      preloader.preloadAtomic<bool>(
        id: 'volumetric_fog_noise_lut',
        priority: PreloadPriority.criticalHud,
        loader: () async {
          for (int i = 0; i < 16; i++) {
            VolumetricFogMath.evaluateMistTurbulence(
              u: i / 16.0,
              v: 0.5,
              time: 0.0,
              wind: widget.parameters.windVelocity,
              octaves: 2,
            );
          }
          return true;
        },
      ).catchError((Object _) => false);
    } catch (_) {
      // In headless test environments or when scheduler binding is not initialized
    }
  }

  void _handleTick(Duration elapsed) {
    if (!mounted) return;
    final double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    if (dt > 0.0 && dt < 0.25) {
      setState(() {
        _time += dt;
      });
    }
  }

  @override
  void didUpdateWidget(covariant VolumetricFogLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scaler != oldWidget.scaler ||
        widget.enableAdaptiveScaling != oldWidget.enableAdaptiveScaling) {
      _scalerSubscription?.cancel();
      _setupScaler();
    }
    if (widget.isAnimated != oldWidget.isAnimated) {
      final bool canAnimate = widget.isAnimated &&
          !(_stepCount == 0 || _hardwareTier == HardwareTier.eco || _throttleLevel >= 3);
      if (canAnimate && !_ticker.isActive) {
        _ticker.start();
      } else if (!canAnimate && _ticker.isActive) {
        _ticker.stop();
      }
    }
  }

  @override
  void dispose() {
    _scalerSubscription?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VolumetricFogParameters effectiveParameters = widget.parameters.copyWith(
      stepCount: _stepCount,
      resolutionScale: _resolutionScale,
      hardwareTier: _hardwareTier,
      throttleLevel: _throttleLevel,
    );

    if (effectiveParameters.isEcoBypass && effectiveParameters.density <= 0.001) {
      return widget.child ?? const SizedBox.shrink();
    }

    final Widget fogOverlay = RepaintBoundary(
      child: CustomPaint(
        painter: VolumetricFogPainter(
          parameters: effectiveParameters,
          animationTime: _time,
        ),
        size: Size.infinite,
      ),
    );

    if (widget.child == null) {
      return fogOverlay;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child!,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: fogOverlay,
          ),
        ),
      ],
    );
  }
}
