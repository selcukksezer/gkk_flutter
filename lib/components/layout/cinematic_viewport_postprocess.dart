import 'package:flutter/material.dart';

import 'aces_tonemapping_layer.dart';
import 'volumetric_fog_layer.dart';

// =============================================================================
// Cinematic Viewport Post-Process Pipeline Wrapper (Impeller / Skia TBDR)
// 2027 AAA Cinematic Graphics Architecture — Battalion 1 Hub World
// =============================================================================

/// Quality profile for cinematic viewport post-processing.
enum ViewportQualityPreset {
  /// Low-end mobile devices (3GB RAM Android): basic fog, no god rays, fast color grading.
  low,

  /// Balanced mobile devices (Standard 60fps target).
  medium,

  /// High-end mobile devices (Full volumetric fog, god rays, ACES grading).
  high,

  /// AAA Ultra mode (Maximum ray steps and mist detail).
  ultra,
}

/// Unified composable wrapper providing 3D viewports and scene layouts with
/// volumetric fog, directional light scattering, ACES filmic tonemapping,
/// and dark fantasy color grading.
class CinematicViewportPostProcess extends StatelessWidget {
  const CinematicViewportPostProcess({
    super.key,
    required this.child,
    this.fogParameters = const VolumetricFogParameters(),
    this.tonemapConfig = const AcesTonemappingConfig(),
    this.enableFog = true,
    this.enableTonemapping = true,
    this.enableVignette = true,
    this.qualityPreset = ViewportQualityPreset.high,
    this.isAnimated = true,
  });

  /// The underlying 3D viewport, scene canvas, or world UI.
  final Widget child;

  /// Volumetric fog atmospheric parameters.
  final VolumetricFogParameters fogParameters;

  /// ACES filmic tonemapping and color grading configuration.
  final AcesTonemappingConfig tonemapConfig;

  /// Whether volumetric fog is rendered over the viewport.
  final bool enableFog;

  /// Whether ACES filmic tonemapping is applied.
  final bool enableTonemapping;

  /// Whether cinematic lens vignette is applied.
  final bool enableVignette;

  /// Overall quality preset for mobile scaling.
  final ViewportQualityPreset qualityPreset;

  /// Whether fog mist turbulence animation loop is active.
  final bool isAnimated;

  /// Resolves the corresponding [FogQualityTier] from [qualityPreset].
  FogQualityTier get _effectiveFogTier {
    switch (qualityPreset) {
      case ViewportQualityPreset.low:
        return FogQualityTier.low;
      case ViewportQualityPreset.medium:
        return FogQualityTier.medium;
      case ViewportQualityPreset.high:
        return FogQualityTier.high;
      case ViewportQualityPreset.ultra:
        return FogQualityTier.ultra;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    // 1. Layer Volumetric Fog directly over 3D Viewport
    if (enableFog) {
      content = VolumetricFogLayer(
        parameters: fogParameters.copyWith(
          qualityTier: _effectiveFogTier,
        ),
        isAnimated: isAnimated,
        child: content,
      );
    }

    // 2. Wrap with ACES Filmic Tonemapping & Color Grading
    if (enableTonemapping || enableVignette) {
      content = AcesTonemappingLayer(
        config: tonemapConfig,
        enableGrading: enableTonemapping,
        enableVignette: enableVignette,
        child: content,
      );
    }

    return content;
  }
}
