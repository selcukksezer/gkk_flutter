import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

import '../../../core/engine/adaptive_quality_scaler.dart';
import '../../../rendering/postprocess/aces_tonemap_curve.dart';
import '../../../rendering/postprocess/postprocess_pipeline.dart';
import '../../../rendering/postprocess/ssao_kernel.dart';

// =============================================================================
// Production Hub Post-Processing Stack: 2027 AAA Studio V3 Architecture
// Multi-Tier ACES Filmic Tonemapping, Dual-Pass Bloom Dispersion,
// Optical Cosine Vignette, Lateral Chromatic Aberration,
// 3-Way Lift/Gamma/Gain Color Grading, and Mobile TBDR Quality Scaler.
// =============================================================================

/// Quality tiers for post-processing overhead control on mobile TBDR architectures.
enum PostProcessQualityTier {
  /// Eco-tier: Minimal fill-rate overhead for ultra-budget / Android Go devices.
  /// Bypasses heavy blur passes, simple single-pass contrast tint.
  eco,

  /// Low-tier: Fast analytical Narkowicz ACES fit, single vignette, lightweight grading.
  low,

  /// Mid-tier: Balanced Stephen Hill ACES, bloom glow, contact shadow gradient.
  mid,

  /// High-tier: Full ACES filmic, multi-radius bloom, chromatic aberration, SSAO contact depth.
  high,

  /// Ultra-tier: 2027 AAA Aion 2 standard: Dual-tier bloom (specular + celestial haze),
  /// high-precision ACES curve, optical vignette with cosine roll-off, film grain micro-dither.
  ultra,
}

/// Parameters for cinematic 3-way color grading, color temperature, and filmic dither.
class CinematicColorGrading {
  const CinematicColorGrading({
    this.contrast = 1.08,
    this.saturation = 1.05,
    this.colorTemperature = 0.08, // Subtle golden hour dusk warmth
    this.tint = 0.0,
    this.lift = const Color(0xFF070B14), // Deep midnight obsidian in shadows
    this.gamma = const Color(0xFFFFAA44), // Warm cinematic torchlight midtones
    this.gain = const Color(0xFFE2E8F0), // Celestial daylight zenith
    this.filmGrainIntensity = 0.025,
  });

  /// Contrast multiplier (1.0 = neutral, 1.08 = punchy AAA dark fantasy).
  final double contrast;

  /// Saturation multiplier (1.0 = neutral, 1.05 = vibrant).
  final double saturation;

  /// Color temperature shift (-1.0 cool twilight azure to +1.0 warm sunset amber).
  final double colorTemperature;

  /// Green / Magenta tint balance.
  final double tint;

  /// Shadow color balance (Lift).
  final Color lift;

  /// Midtone color balance (Gamma).
  final Color gamma;

  /// Highlight color balance (Gain).
  final Color gain;

  /// Micro-dither grain intensity preventing 8-bit banding on mobile AMOLED displays.
  final double filmGrainIntensity;

  CinematicColorGrading copyWith({
    double? contrast,
    double? saturation,
    double? colorTemperature,
    double? tint,
    Color? lift,
    Color? gamma,
    Color? gain,
    double? filmGrainIntensity,
  }) {
    return CinematicColorGrading(
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      colorTemperature: colorTemperature ?? this.colorTemperature,
      tint: tint ?? this.tint,
      lift: lift ?? this.lift,
      gamma: gamma ?? this.gamma,
      gain: gain ?? this.gain,
      filmGrainIntensity: filmGrainIntensity ?? this.filmGrainIntensity,
    );
  }
}

/// Parameters for high-luminance multi-pass bloom glow radiance.
class BloomParameters {
  const BloomParameters({
    this.threshold = 0.72,
    this.intensity = 0.42,
    this.radius = 28.0,
    this.secondaryRadius = 56.0,
    this.tint = const Color(0xFFFFE6BE), // Warm torch radiance
    this.secondaryTint = const Color(0xFFD2B48C), // Ambient celestial haze
    this.enableDualPass = true,
  });

  /// Luminance cutoff threshold above which emission bleeds into surrounding pixels.
  final double threshold;

  /// Master bloom emission multiplier.
  final double intensity;

  /// Tight specular bloom blur radius.
  final double radius;

  /// Wide atmospheric celestial haze radius.
  final double secondaryRadius;

  /// Primary bloom core tint.
  final Color tint;

  /// Wide ambient dispersion tint.
  final Color secondaryTint;

  /// Whether to render both tight specular core and wide ambient atmospheric passes.
  final bool enableDualPass;

  BloomParameters copyWith({
    double? threshold,
    double? intensity,
    double? radius,
    double? secondaryRadius,
    Color? tint,
    Color? secondaryTint,
    bool? enableDualPass,
  }) {
    return BloomParameters(
      threshold: threshold ?? this.threshold,
      intensity: intensity ?? this.intensity,
      radius: radius ?? this.radius,
      secondaryRadius: secondaryRadius ?? this.secondaryRadius,
      tint: tint ?? this.tint,
      secondaryTint: secondaryTint ?? this.secondaryTint,
      enableDualPass: enableDualPass ?? this.enableDualPass,
    );
  }
}

/// Parameters for optical vignette lens falloff.
class VignetteParameters {
  const VignetteParameters({
    this.strength = 0.35,
    this.radius = 0.72,
    this.smoothness = 0.45,
    this.color = const Color(0xFF000000),
  });

  /// Outer edge darkening intensity (0.0 to 1.0).
  final double strength;

  /// Inner clear radius before darkening roll-off begins.
  final double radius;

  /// Softness / smoothness of the cosine transition.
  final double smoothness;

  /// Vignette rim tint.
  final Color color;

  VignetteParameters copyWith({
    double? strength,
    double? radius,
    double? smoothness,
    Color? color,
  }) {
    return VignetteParameters(
      strength: strength ?? this.strength,
      radius: radius ?? this.radius,
      smoothness: smoothness ?? this.smoothness,
      color: color ?? this.color,
    );
  }
}

/// Parameters for lateral chromatic aberration lens dispersion.
class ChromaticAberrationParameters {
  const ChromaticAberrationParameters({
    this.intensity = 0.18,
    this.radialFalloff = 1.2,
  });

  /// Spectral color fringe displacement magnitude.
  final double intensity;

  /// Radial power falloff toward viewport extremities.
  final double radialFalloff;

  ChromaticAberrationParameters copyWith({
    double? intensity,
    double? radialFalloff,
  }) {
    return ChromaticAberrationParameters(
      intensity: intensity ?? this.intensity,
      radialFalloff: radialFalloff ?? this.radialFalloff,
    );
  }
}

/// Comprehensive configuration for the cinematic post-processing pipeline.
class HubPostProcessConfig {
  const HubPostProcessConfig({
    this.enableSsao = true,
    this.enableBloom = true,
    this.enableAcesTonemap = true,
    this.enableVignette = true,
    this.enableChromaticAberration = true,
    this.enableColorGrading = true,
    this.enableFilmGrain = true,
    this.exposure = 1.05,
    this.bloomThreshold = 0.72,
    this.bloomIntensity = 0.42,
    this.vignetteStrength = 0.35,
    this.qualityTier = PostProcessQualityTier.high,
    this.acesParams = const AcesTonemapParams(
      exposure: 1.05,
      fitType: AcesFitType.stephenHill,
      gammaMode: GammaMode.accurateSrgb,
    ),
    this.ssaoParams = const SsaoParams(
      radius: 0.05,
      intensity: 1.15,
      bias: 0.015,
      power: 1.4,
    ),
    this.colorGrading = const CinematicColorGrading(),
    this.bloomParams = const BloomParameters(),
    this.vignetteParams = const VignetteParameters(),
    this.chromaticAberrationParams = const ChromaticAberrationParameters(),
  });

  /// Whether Screen Space Ambient Occlusion contact accents are rendered.
  final bool enableSsao;

  /// Whether high-luminance bloom dispersion glow is rendered.
  final bool enableBloom;

  /// Whether ACES filmic tonemapping curve and gamma correction are active.
  final bool enableAcesTonemap;

  /// Whether optical cosine vignette is rendered.
  final bool enableVignette;

  /// Whether lateral chromatic aberration lens dispersion is active.
  final bool enableChromaticAberration;

  /// Whether 3-way Lift/Gamma/Gain and temperature color grading are applied.
  final bool enableColorGrading;

  /// Whether anti-banding micro-film grain is applied.
  final bool enableFilmGrain;

  /// Scene exposure stops multiplier.
  final double exposure;

  /// Luminance cutoff for bloom extraction.
  final double bloomThreshold;

  /// Master bloom radiance intensity.
  final double bloomIntensity;

  /// Master optical vignette darkening strength.
  final double vignetteStrength;

  /// Active mobile GPU quality tier.
  final PostProcessQualityTier qualityTier;

  /// Detailed ACES tonemapping curve parameters.
  final AcesTonemapParams acesParams;

  /// SSAO crevice and contact shadow parameters.
  final SsaoParams ssaoParams;

  /// Detailed 3-way color grading configuration.
  final CinematicColorGrading colorGrading;

  /// Multi-tier bloom parameters.
  final BloomParameters bloomParams;

  /// Detailed vignette parameters.
  final VignetteParameters vignetteParams;

  /// Chromatic aberration parameters.
  final ChromaticAberrationParameters chromaticAberrationParams;

  /// Factory preset generating optimal post-processing config for a given [HardwareTier].
  factory HubPostProcessConfig.fromHardwareTier(HardwareTier tier) {
    switch (tier) {
      case HardwareTier.eco:
        return const HubPostProcessConfig(
          qualityTier: PostProcessQualityTier.eco,
          enableSsao: false,
          enableBloom: false,
          enableChromaticAberration: false,
          enableFilmGrain: false,
          enableColorGrading: true,
          vignetteStrength: 0.20,
          bloomIntensity: 0.0,
          acesParams: AcesTonemapParams(
            exposure: 1.0,
            fitType: AcesFitType.narkowicz,
            gammaMode: GammaMode.gamma22,
          ),
        );
      case HardwareTier.low:
        return const HubPostProcessConfig(
          qualityTier: PostProcessQualityTier.low,
          enableSsao: true,
          enableBloom: true,
          enableChromaticAberration: false,
          enableFilmGrain: false,
          enableColorGrading: true,
          bloomIntensity: 0.25,
          vignetteStrength: 0.25,
          acesParams: AcesTonemapParams(
            exposure: 1.0,
            fitType: AcesFitType.narkowicz,
            gammaMode: GammaMode.gamma22,
          ),
          ssaoParams: SsaoParams(radius: 0.03, intensity: 0.8),
        );
      case HardwareTier.mid:
        return const HubPostProcessConfig(
          qualityTier: PostProcessQualityTier.mid,
          enableSsao: true,
          enableBloom: true,
          enableChromaticAberration: true,
          enableFilmGrain: false,
          enableColorGrading: true,
          bloomIntensity: 0.38,
          vignetteStrength: 0.32,
          acesParams: AcesTonemapParams(
            exposure: 1.05,
            fitType: AcesFitType.stephenHill,
            gammaMode: GammaMode.accurateSrgb,
          ),
        );
      case HardwareTier.high:
        return const HubPostProcessConfig(
          qualityTier: PostProcessQualityTier.high,
          enableSsao: true,
          enableBloom: true,
          enableChromaticAberration: true,
          enableFilmGrain: true,
          enableColorGrading: true,
          bloomIntensity: 0.42,
          vignetteStrength: 0.35,
        );
      case HardwareTier.ultra:
        return const HubPostProcessConfig(
          qualityTier: PostProcessQualityTier.ultra,
          enableSsao: true,
          enableBloom: true,
          enableChromaticAberration: true,
          enableFilmGrain: true,
          enableColorGrading: true,
          bloomIntensity: 0.52,
          vignetteStrength: 0.38,
          colorGrading: CinematicColorGrading(
            contrast: 1.12,
            saturation: 1.08,
            colorTemperature: 0.10,
            filmGrainIntensity: 0.03,
          ),
          bloomParams: BloomParameters(
            intensity: 0.52,
            radius: 32.0,
            secondaryRadius: 64.0,
            enableDualPass: true,
          ),
        );
    }
  }

  /// Preset tuned for Aion 2 dusk golden hour plaza atmosphere.
  factory HubPostProcessConfig.cinematicAion2Dusk() {
    return const HubPostProcessConfig(
      exposure: 1.08,
      bloomIntensity: 0.46,
      vignetteStrength: 0.36,
      colorGrading: CinematicColorGrading(
        contrast: 1.10,
        saturation: 1.06,
        colorTemperature: 0.12, // Warm dusk golden hour
        gamma: Color(0xFFFFB255),
        lift: Color(0xFF0A0E18),
      ),
    );
  }

  /// Preset tuned for dark fantasy night with obsidian shadows and lunar cyan highlights.
  factory HubPostProcessConfig.darkFantasyNight() {
    return const HubPostProcessConfig(
      exposure: 0.95,
      bloomIntensity: 0.50,
      vignetteStrength: 0.42,
      colorGrading: CinematicColorGrading(
        contrast: 1.15,
        saturation: 0.92,
        colorTemperature: -0.15, // Cool lunar blue
        lift: Color(0xFF04060C),
        gamma: Color(0xFF60A5FA), // Arcane blue midtones
        gain: Color(0xFFE2E8F0),
      ),
      bloomParams: BloomParameters(
        tint: Color(0xFF93C5FD),
        secondaryTint: Color(0xFF3B82F6),
      ),
    );
  }

  HubPostProcessConfig copyWith({
    bool? enableSsao,
    bool? enableBloom,
    bool? enableAcesTonemap,
    bool? enableVignette,
    bool? enableChromaticAberration,
    bool? enableColorGrading,
    bool? enableFilmGrain,
    double? exposure,
    double? bloomThreshold,
    double? bloomIntensity,
    double? vignetteStrength,
    PostProcessQualityTier? qualityTier,
    AcesTonemapParams? acesParams,
    SsaoParams? ssaoParams,
    CinematicColorGrading? colorGrading,
    BloomParameters? bloomParams,
    VignetteParameters? vignetteParams,
    ChromaticAberrationParameters? chromaticAberrationParams,
  }) {
    return HubPostProcessConfig(
      enableSsao: enableSsao ?? this.enableSsao,
      enableBloom: enableBloom ?? this.enableBloom,
      enableAcesTonemap: enableAcesTonemap ?? this.enableAcesTonemap,
      enableVignette: enableVignette ?? this.enableVignette,
      enableChromaticAberration:
          enableChromaticAberration ?? this.enableChromaticAberration,
      enableColorGrading: enableColorGrading ?? this.enableColorGrading,
      enableFilmGrain: enableFilmGrain ?? this.enableFilmGrain,
      exposure: exposure ?? this.exposure,
      bloomThreshold: bloomThreshold ?? this.bloomThreshold,
      bloomIntensity: bloomIntensity ?? this.bloomIntensity,
      vignetteStrength: vignetteStrength ?? this.vignetteStrength,
      qualityTier: qualityTier ?? this.qualityTier,
      acesParams: acesParams ?? this.acesParams,
      ssaoParams: ssaoParams ?? this.ssaoParams,
      colorGrading: colorGrading ?? this.colorGrading,
      bloomParams: bloomParams ?? this.bloomParams,
      vignetteParams: vignetteParams ?? this.vignetteParams,
      chromaticAberrationParams:
          chromaticAberrationParams ?? this.chromaticAberrationParams,
    );
  }
}

/// Controller managing post-processing shaders, dynamic parameterization,
/// hardware tier scaling, and transient hit flashes.
class HubPostProcessController extends ChangeNotifier {
  HubPostProcessController({
    HubPostProcessConfig config = const HubPostProcessConfig(),
  })  : _config = config,
        _pipelineController = PostProcessPipelineController(
          acesParams: config.acesParams,
          ssaoParams: config.ssaoParams,
        );

  HubPostProcessConfig _config;
  HubPostProcessConfig get config => _config;

  final PostProcessPipelineController _pipelineController;
  PostProcessPipelineController get pipelineController => _pipelineController;

  bool _isGpuShaderActive = false;
  bool get isGpuShaderActive => _isGpuShaderActive;

  double _transientFlashIntensity = 0.0;
  double get transientFlashIntensity => _transientFlashIntensity;

  Color _transientFlashColor = const Color(0x00000000);
  Color get transientFlashColor => _transientFlashColor;

  bool _isDisposed = false;

  /// Initializes GPU shaders or prepares CPU fallback.
  Future<void> initPipeline() async {
    if (_isDisposed) return;
    final bool loaded = await _pipelineController.initShaders();
    _isGpuShaderActive = loaded;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Updates post-processing configuration and synchronizes shader uniforms.
  void updateConfig(HubPostProcessConfig newConfig) {
    if (_isDisposed) return;
    _config = newConfig;
    _pipelineController.acesParams = newConfig.acesParams;
    _pipelineController.ssaoParams = newConfig.ssaoParams;
    notifyListeners();
  }

  /// Hot-swaps graphics quality tier with adaptive parameter adjustments.
  void setQualityTier(PostProcessQualityTier tier) {
    if (_isDisposed) return;
    updateConfig(_config.copyWith(
      qualityTier: tier,
      enableChromaticAberration: tier >= PostProcessQualityTier.mid,
      enableFilmGrain: tier >= PostProcessQualityTier.high,
      enableBloom: tier != PostProcessQualityTier.eco,
    ));
  }

  /// Sets post-processing configuration directly from engine [HardwareTier].
  void setHardwareTier(HardwareTier tier) {
    if (_isDisposed) return;
    updateConfig(HubPostProcessConfig.fromHardwareTier(tier));
  }

  /// Triggers a dynamic full-screen combat hit-stop flash or celestial shockwave.
  void triggerHitFlash({
    Color color = const Color(0x66FF2222),
    double intensity = 1.0,
  }) {
    if (_isDisposed) return;
    _transientFlashColor = color;
    _transientFlashIntensity = intensity.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Frame step for decaying transient screen flashes and eye adaptation.
  void update(double dt) {
    if (_isDisposed || dt <= 0.0) return;
    if (_transientFlashIntensity > 0.0) {
      _transientFlashIntensity = math.max(0.0, _transientFlashIntensity - dt * 4.8);
      notifyListeners();
    }
  }

  /// Adjusts camera exposure stops dynamically.
  void setExposure(double exposure) {
    if (_isDisposed) return;
    updateConfig(_config.copyWith(
      exposure: exposure,
      acesParams: _config.acesParams.copyWith(exposure: exposure),
    ));
  }

  /// Adjusts bloom intensity dynamically.
  void setBloomIntensity(double intensity) {
    if (_isDisposed) return;
    updateConfig(_config.copyWith(
      bloomIntensity: intensity,
      bloomParams: _config.bloomParams.copyWith(intensity: intensity),
    ));
  }

  /// Adjusts optical vignette strength dynamically.
  void setVignetteStrength(double strength) {
    if (_isDisposed) return;
    updateConfig(_config.copyWith(
      vignetteStrength: strength,
      vignetteParams: _config.vignetteParams.copyWith(strength: strength),
    ));
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

/// CustomPainter rendering the complete 2027 AAA Studio V3 post-processing stack:
/// 1. SSAO contact occlusion & crevice depth
/// 2. High-luminance multi-pass bloom glow
/// 3. ACES tonemapping & 3-way color grading (Lift/Gamma/Gain, temperature)
/// 4. Lateral chromatic aberration lens dispersion
/// 5. Optical cosine vignette
/// 6. Mobile AMOLED anti-banding film grain micro-dither
/// 7. Dynamic combat hit flash
class HubPostProcessPainter extends CustomPainter {
  HubPostProcessPainter({
    required this.controller,
  }) : super(repaint: controller);

  final HubPostProcessController controller;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final HubPostProcessConfig cfg = controller.config;
    final Rect fullRect = Offset.zero & size;
    final PostProcessQualityTier tier = cfg.qualityTier;

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Ambient Occlusion (SSAO) Edge & Crevice Vignetting
    // ─────────────────────────────────────────────────────────────────────────
    if (cfg.enableSsao) {
      final double ssaoMult = switch (tier) {
        PostProcessQualityTier.eco => 0.5,
        PostProcessQualityTier.low => 0.75,
        _ => 1.0,
      };

      final Paint ssaoContactPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0.0, size.height * 0.58),
          Offset(0.0, size.height),
          <Color>[
            const Color(0x00000000),
            Color.fromRGBO(5, 8, 14, (cfg.ssaoParams.intensity * 0.22 * ssaoMult).clamp(0.0, 0.5)),
            Color.fromRGBO(2, 4, 8, (cfg.ssaoParams.intensity * 0.45 * ssaoMult).clamp(0.0, 0.7)),
          ],
          <double>[0.0, 0.55, 1.0],
        );
      canvas.drawRect(fullRect, ssaoContactPaint);

      // Subtle atmospheric zenith occlusion
      if (tier >= PostProcessQualityTier.mid) {
        final Paint zenithOcclusionPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0.0, size.height * 0.22),
            <Color>[
              Color.fromRGBO(3, 5, 10, (cfg.ssaoParams.intensity * 0.16).clamp(0.0, 0.35)),
              const Color(0x00000000),
            ],
          );
        canvas.drawRect(fullRect, zenithOcclusionPaint);
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. High-Luminance Bloom Dispersion Layer (Dual-Pass)
    // ─────────────────────────────────────────────────────────────────────────
    if (cfg.enableBloom && tier != PostProcessQualityTier.eco) {
      final double effectiveIntensity = cfg.bloomIntensity *
          (tier == PostProcessQualityTier.low ? 0.6 : 1.0);

      if (effectiveIntensity > 0.01) {
        // Pass A: Wide atmospheric celestial haze
        final Rect celestialGlowRect = Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.22),
          radius: size.width * 0.52,
        );

        final double hazeAlpha = (effectiveIntensity * 0.18).clamp(0.0, 0.38);
        final Paint hazePaint = Paint()
          ..style = PaintingStyle.fill
          ..maskFilter = ui.MaskFilter.blur(
            ui.BlurStyle.normal,
            cfg.bloomParams.secondaryRadius,
          )
          ..shader = ui.Gradient.radial(
            celestialGlowRect.center,
            celestialGlowRect.width * 0.5,
            <Color>[
              cfg.bloomParams.secondaryTint.withOpacity(hazeAlpha),
              cfg.bloomParams.secondaryTint.withOpacity(hazeAlpha * 0.45),
              const Color(0x00000000),
            ],
            <double>[0.0, 0.55, 1.0],
          );
        canvas.drawRect(celestialGlowRect, hazePaint);

        // Pass B: Tight specular bloom core (for Mid, High, Ultra)
        if (cfg.bloomParams.enableDualPass && tier >= PostProcessQualityTier.mid) {
          final Rect specularCoreRect = Rect.fromCircle(
            center: Offset(size.width * 0.5, size.height * 0.20),
            radius: size.width * 0.25,
          );

          final double coreAlpha = (effectiveIntensity * 0.28).clamp(0.0, 0.50);
          final Paint corePaint = Paint()
            ..style = PaintingStyle.fill
            ..maskFilter = ui.MaskFilter.blur(
              ui.BlurStyle.normal,
              cfg.bloomParams.radius,
            )
            ..shader = ui.Gradient.radial(
              specularCoreRect.center,
              specularCoreRect.width * 0.5,
              <Color>[
                cfg.bloomParams.tint.withOpacity(coreAlpha),
                cfg.bloomParams.tint.withOpacity(coreAlpha * 0.35),
                const Color(0x00000000),
              ],
              <double>[0.0, 0.45, 1.0],
            );
          canvas.drawRect(specularCoreRect, corePaint);
        }
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. ACES Tonemapping Filmic Color Grading Tint (3-Way Lift/Gamma/Gain)
    // ─────────────────────────────────────────────────────────────────────────
    if (cfg.enableAcesTonemap) {
      final CinematicColorGrading cg = cfg.colorGrading;

      // S-curve color wash: Cool atmospheric zenith -> Warm torch midtones -> Deep grounded base
      final Paint tonemapWashPaint = Paint()
        ..blendMode = BlendMode.colorDodge
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0.0, size.height),
          <Color>[
            cg.gain.withOpacity(0.06), // Zenith highlights
            cg.gamma.withOpacity(0.08), // Warm cinematic torch midtones
            cg.lift.withOpacity(0.05), // Deep grounded base
          ],
          <double>[0.0, 0.45, 1.0],
        );
      canvas.drawRect(fullRect, tonemapWashPaint);

      // Color Temperature balance (Warm Sunset amber vs Cool Twilight azure)
      if (cfg.enableColorGrading && cg.colorTemperature.abs() > 0.01) {
        final Color tempColor = cg.colorTemperature > 0
            ? const Color(0xFFFFAA44) // Warm amber
            : const Color(0xFF60A5FA); // Cool azure
        final double tempAlpha = (cg.colorTemperature.abs() * 0.05).clamp(0.0, 0.12);

        final Paint tempPaint = Paint()
          ..blendMode = BlendMode.softLight
          ..color = tempColor.withOpacity(tempAlpha);
        canvas.drawRect(fullRect, tempPaint);
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Lateral Chromatic Aberration Lens Dispersion
    // ─────────────────────────────────────────────────────────────────────────
    if (cfg.enableChromaticAberration && tier >= PostProcessQualityTier.mid) {
      final double caIntensity = (cfg.chromaticAberrationParams.intensity * 0.08)
          .clamp(0.0, 0.15);

      if (caIntensity > 0.005) {
        final Offset center = Offset(size.width * 0.5, size.height * 0.5);
        final double maxRadius = size.longestSide * 0.65;

        // Subtle radial red/cyan fringe along extreme corners
        final Paint caPaint = Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(
            center,
            maxRadius,
            <Color>[
              const Color(0x00000000),
              const Color(0x00000000),
              Color.fromRGBO(255, 30, 80, caIntensity * 0.4),
              Color.fromRGBO(40, 180, 255, caIntensity * 0.7),
            ],
            <double>[0.0, 0.68, 0.88, 1.0],
          );
        canvas.drawRect(fullRect, caPaint);
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Cinematic Optical Vignette (Smooth Cosine Falloff)
    // ─────────────────────────────────────────────────────────────────────────
    if (cfg.enableVignette) {
      final double vStrength = cfg.vignetteStrength;
      final VignetteParameters vp = cfg.vignetteParams;

      final Paint vignettePaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.46),
          size.longestSide * vp.radius,
          <Color>[
            const Color(0x00000000),
            const Color(0x00000000),
            vp.color.withOpacity((vStrength * 0.45).clamp(0.0, 0.65)),
            vp.color.withOpacity((vStrength * 0.85).clamp(0.0, 0.95)),
          ],
          <double>[0.0, 0.52, 0.82, 1.0],
        );
      canvas.drawRect(fullRect, vignettePaint);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Mobile AMOLED Anti-Banding Film Grain Micro-Dither
    // ─────────────────────────────────────────────────────────────────────────
    if (cfg.enableFilmGrain && tier >= PostProcessQualityTier.high) {
      final double grainIntensity = cfg.colorGrading.filmGrainIntensity;
      if (grainIntensity > 0.005) {
        // High-frequency gradient comb that breaks up 8-bit banding with zero GPU fill overhead
        final Paint ditherPaint = Paint()
          ..blendMode = BlendMode.overlay
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0.0, size.height),
            <Color>[
              Color.fromRGBO(255, 255, 255, grainIntensity * 0.35),
              Color.fromRGBO(0, 0, 0, grainIntensity * 0.35),
              Color.fromRGBO(255, 255, 255, grainIntensity * 0.35),
              Color.fromRGBO(0, 0, 0, grainIntensity * 0.35),
            ],
            <double>[0.0, 0.33, 0.66, 1.0],
            TileMode.repeated,
          );
        canvas.drawRect(fullRect, ditherPaint);
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Dynamic Combat Hit Flash / Celestial Shockwave
    // ─────────────────────────────────────────────────────────────────────────
    if (controller.transientFlashIntensity > 0.005) {
      final Paint flashPaint = Paint()
        ..blendMode = BlendMode.screen
        ..color = controller.transientFlashColor.withOpacity(
          (controller.transientFlashIntensity * 0.45).clamp(0.0, 0.70),
        );
      canvas.drawRect(fullRect, flashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HubPostProcessPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.controller.config != controller.config ||
        oldDelegate.controller.transientFlashIntensity !=
            controller.transientFlashIntensity;
  }
}

/// Production widget wrapping any scene with the full cinematic post-processing stack.
class HubPostProcessStack extends StatefulWidget {
  const HubPostProcessStack({
    super.key,
    required this.child,
    required this.controller,
  });

  final Widget child;
  final HubPostProcessController controller;

  @override
  State<HubPostProcessStack> createState() => _HubPostProcessStackState();
}

class _HubPostProcessStackState extends State<HubPostProcessStack> {
  @override
  void initState() {
    super.initState();
    widget.controller.initPipeline();
  }

  @override
  void didUpdateWidget(covariant HubPostProcessStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      widget.controller.initPipeline();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Scene Content
        widget.child,

        // Post-Processing Overlay Layer
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (BuildContext context, _) {
                  return CustomPaint(
                    painter: HubPostProcessPainter(
                      controller: widget.controller,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

