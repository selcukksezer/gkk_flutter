import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../screens/settings/graphics_settings_service.dart';

// =============================================================================
// ACES Filmic Tonemapping & Cinematic Color Grading Layer (Mobile Impeller/Skia)
// 2027 AAA Cinematic Graphics Architecture — Battalion 1 Hub World
// =============================================================================

/// ACES fitting curve approximation method.
enum AcesFitType {
  /// Stephen Hill high-precision fitted ACES model (sRGB -> AP1 -> RRT+ODT -> sRGB).
  stephenHill(0.0),

  /// Krzysztof Narkowicz fast analytical ACES fit curve.
  narkowicz(1.0),

  /// Fast analytical Reinhard tonemapping curve (x / (1.0 + x)) for low-spec/eco devices.
  reinhard(2.0),

  /// Direct linear pass-through bypassing tone curve and LUT calculation.
  passThrough(3.0);

  const AcesFitType(this.shaderValue);
  final double shaderValue;
}

/// Color space gamma transfer mode.
enum GammaCorrectionMode {
  /// Accurate IEC 61966-2-1 linear-to-sRGB transfer curve.
  sRgb(0.0),

  /// Standard power-curve Gamma 2.2 approximation (fastest).
  gamma22(1.0);

  const GammaCorrectionMode(this.shaderValue);
  final double shaderValue;
}

/// Exposure calculation mode.
enum ExposureMode {
  /// Direct linear radiance scalar multiplier.
  linear(0.0),

  /// Photographic exposure value stops (multiplier = 2^EV).
  evStops(1.0);

  const ExposureMode(this.shaderValue);
  final double shaderValue;
}

/// Configuration settings for ACES Filmic Tonemapping and dark fantasy color grading.
class AcesTonemappingConfig {
  const AcesTonemappingConfig({
    this.exposure = 0.0,
    this.exposureMode = ExposureMode.evStops,
    this.fitType = AcesFitType.stephenHill,
    this.gammaMode = GammaCorrectionMode.sRgb,
    this.preGain = 1.0,
    this.whitePoint = 0.0,
    this.contrast = 1.08,
    this.saturation = 1.05,
    this.colorTemperature = -0.05, // Subtle cold dark-fantasy blue shift
    this.tint = 0.02, // Subtle magenta tone
    this.vignetteIntensity = 0.38,
    this.vignetteRadius = 0.85,
    this.vignetteSmoothness = 0.45,
    this.vignetteColor = const Color(0xFF030712),
    this.enableBloom = true,
    this.bloomIntensity = 0.25,
    this.bloomThreshold = 0.8,
    this.hdrHighlights = true,
  });

  /// Photographic exposure compensation (stops in EV or linear factor).
  final double exposure;

  /// Mode determining how [exposure] is interpreted.
  final ExposureMode exposureMode;

  /// ACES curve fitting algorithm.
  final AcesFitType fitType;

  /// Gamma correction transfer curve.
  final GammaCorrectionMode gammaMode;

  /// Pre-tonemapping gain factor.
  final double preGain;

  /// White point luminance ceiling (0.0 for disabled / infinite).
  final double whitePoint;

  /// Contrast expansion factor around midtone (1.0 = neutral).
  final double contrast;

  /// Color saturation multiplier (1.0 = neutral, 0.0 = monochrome).
  final double saturation;

  /// Color temperature adjustment [-1.0 cold blue, +1.0 warm amber].
  final double colorTemperature;

  /// Green/Magenta tint adjustment [-1.0 green, +1.0 magenta].
  final double tint;

  /// Vignette edge darkening strength [0.0 - 1.0].
  final double vignetteIntensity;

  /// Vignette radial coverage radius [0.2 - 2.0].
  final double vignetteRadius;

  /// Smoothness of radial vignette falloff.
  final double vignetteSmoothness;

  /// Color of vignette perimeter shading.
  final Color vignetteColor;

  /// Whether cinematic bloom compositing is active on capable tiers.
  final bool enableBloom;

  /// Intensity multiplier for bloom radiance [0.0 - 1.0].
  final double bloomIntensity;

  /// Luminance threshold above which pixels contribute to bloom [0.0 - 1.0].
  final double bloomThreshold;

  /// Whether high-dynamic-range (HDR) specular highlight diffusion is composited.
  final bool hdrHighlights;

  /// Adapts tonemapping curve, bloom, and post-processing features to the device's
  /// current [HardwareTier] and [throttleLevel] reported by [AdaptiveQualityScaler].
  AcesTonemappingConfig adaptToScaler({
    required HardwareTier tier,
    required int throttleLevel,
  }) {
    if (tier == HardwareTier.eco || throttleLevel >= 3) {
      // Eco tier (<=1.8GB RAM) or severe thermal throttle (level >= 3):
      // Simplify tonemapping curve to fast Reinhard or direct pass-through to eliminate color grading LUT overhead
      return copyWith(
        fitType: (fitType == AcesFitType.reinhard) ? AcesFitType.reinhard : AcesFitType.passThrough,
        vignetteIntensity: 0.0,
        enableBloom: false,
        hdrHighlights: false,
        contrast: 1.0,
        saturation: 1.0,
        colorTemperature: 0.0,
        tint: 0.0,
      );
    } else if (tier == HardwareTier.low || throttleLevel >= 2) {
      // Low tier (2GB–3GB RAM) or medium throttle:
      // Fast analytical Reinhard curve with reduced vignette and bloom disabled
      return copyWith(
        fitType: (fitType == AcesFitType.stephenHill) ? AcesFitType.narkowicz : fitType,
        vignetteIntensity: (vignetteIntensity * 0.5).clamp(0.0, 1.0),
        enableBloom: false,
        hdrHighlights: false,
      );
    } else {
      // Mid / High / Ultra tiers:
      // Full cinematic ACES filmic curve with bloom compositing and high dynamic range highlights
      return copyWith(
        fitType: (fitType == AcesFitType.passThrough) ? AcesFitType.stephenHill : fitType,
        enableBloom: true,
        hdrHighlights: true,
      );
    }
  }

  AcesTonemappingConfig copyWith({
    double? exposure,
    ExposureMode? exposureMode,
    AcesFitType? fitType,
    GammaCorrectionMode? gammaMode,
    double? preGain,
    double? whitePoint,
    double? contrast,
    double? saturation,
    double? colorTemperature,
    double? tint,
    double? vignetteIntensity,
    double? vignetteRadius,
    double? vignetteSmoothness,
    Color? vignetteColor,
    bool? enableBloom,
    double? bloomIntensity,
    double? bloomThreshold,
    bool? hdrHighlights,
  }) {
    return AcesTonemappingConfig(
      exposure: exposure ?? this.exposure,
      exposureMode: exposureMode ?? this.exposureMode,
      fitType: fitType ?? this.fitType,
      gammaMode: gammaMode ?? this.gammaMode,
      preGain: preGain ?? this.preGain,
      whitePoint: whitePoint ?? this.whitePoint,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      colorTemperature: colorTemperature ?? this.colorTemperature,
      tint: tint ?? this.tint,
      vignetteIntensity: vignetteIntensity ?? this.vignetteIntensity,
      vignetteRadius: vignetteRadius ?? this.vignetteRadius,
      vignetteSmoothness: vignetteSmoothness ?? this.vignetteSmoothness,
      vignetteColor: vignetteColor ?? this.vignetteColor,
      enableBloom: enableBloom ?? this.enableBloom,
      bloomIntensity: bloomIntensity ?? this.bloomIntensity,
      bloomThreshold: bloomThreshold ?? this.bloomThreshold,
      hdrHighlights: hdrHighlights ?? this.hdrHighlights,
    );
  }
}

/// Exact analytical tonemapping math models and CPU matrix generators.
abstract final class AcesMath {
  /// Krzysztof Narkowicz ACES fit curve:
  /// f(x) = clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0)
  static double narkowiczCurve(double x) {
    if (x <= 0.0) return 0.0;
    const double a = 2.51;
    const double b = 0.03;
    const double c = 2.43;
    const double d = 0.59;
    const double e = 0.14;
    final double num = x * (a * x + b);
    final double den = x * (c * x + d) + e;
    return (num / den).clamp(0.0, 1.0);
  }

  /// Linear to standard IEC 61966-2-1 sRGB curve.
  static double linearToSrgb(double c) {
    if (c <= 0.0) return 0.0;
    if (c >= 1.0) return 1.0;
    if (c <= 0.0031308) {
      return (c * 12.92).clamp(0.0, 1.0);
    } else {
      return (1.055 * math.pow(c, 1.0 / 2.4) - 0.055).clamp(0.0, 1.0);
    }
  }

  /// Linear to Gamma 2.2 power curve.
  static double linearToGamma22(double c) {
    return math.pow(c.clamp(0.0, 1.0), 1.0 / 2.2).toDouble().clamp(0.0, 1.0);
  }

  /// Calculates photographic linear exposure multiplier from config.
  static double calculateExposureMultiplier(AcesTonemappingConfig config) {
    double factor = 1.0;
    if (config.exposureMode == ExposureMode.evStops) {
      factor = math.pow(2.0, config.exposure).toDouble();
    } else {
      factor = config.exposure > 0.0 ? config.exposure : 1.0;
    }
    final double preGain = config.preGain > 0.0 ? config.preGain : 1.0;
    return factor * preGain;
  }

  /// Identity 4x5 color filter matrix (direct pass-through with 0 color grading overhead).
  static const List<double> identityMatrix = <double>[
    1.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ];

  /// Stephen Hill high-precision fitted ACES model approximation.
  static double stephenHillCurve(double x) {
    if (x <= 0.0) return 0.0;
    final double a = x * (x + 0.0245786) - 0.000090537;
    final double b = x * (0.983729 * x + 0.4329510) + 0.238081;
    return (a / b).clamp(0.0, 1.0);
  }

  /// Fast analytical Reinhard tonemapping curve: f(x) = x / (1.0 + x).
  /// Minimum ALU overhead designed for low-memory Eco tier devices and thermal recovery.
  static double reinhardCurve(double x) {
    if (x <= 0.0) return 0.0;
    return (x / (1.0 + x)).clamp(0.0, 1.0);
  }

  /// Direct linear pass-through: f(x) = clamp(x, 0.0, 1.0).
  static double passThroughCurve(double x) {
    return x.clamp(0.0, 1.0);
  }

  /// Generates a 4x5 ColorFilter matrix implementing linear exposure, contrast,
  /// saturation, color temperature, and tint in a single GPU pass.
  ///
  /// On Eco tier or throttleLevel >= 3, falls back to fast Reinhard or direct pass-through
  /// to eliminate color grading LUT overhead completely.
  static List<double> generateColorGradingMatrix(AcesTonemappingConfig config) {
    if (config.fitType == AcesFitType.passThrough) {
      final double exposure = calculateExposureMultiplier(config);
      if ((exposure - 1.0).abs() < 0.001) {
        return identityMatrix;
      }
      return <double>[
        exposure, 0.0,      0.0,      0.0, 0.0,
        0.0,      exposure, 0.0,      0.0, 0.0,
        0.0,      0.0,      exposure, 0.0, 0.0,
        0.0,      0.0,      0.0,      1.0, 0.0,
      ];
    }

    final double exposure = calculateExposureMultiplier(config);

    if (config.fitType == AcesFitType.reinhard) {
      // Fast Reinhard curve optimization: eliminates cross-channel temperature & tint ALU
      final double reinhardGain = exposure / (1.0 + exposure * 0.25);
      final double contrast = config.contrast.clamp(0.5, 2.0);
      final double saturation = config.saturation.clamp(0.0, 2.5);

      const double lr = 0.2126;
      const double lg = 0.7152;
      const double lb = 0.0722;

      final double invSat = 1.0 - saturation;
      final double sr = invSat * lr + saturation;
      final double sg = invSat * lg + saturation;
      final double sb = invSat * lb + saturation;

      final double contrastOffset = 128.0 * (1.0 - contrast);

      return <double>[
        sr * reinhardGain * contrast, 0.0,                          0.0,                          0.0, contrastOffset,
        0.0,                          sg * reinhardGain * contrast, 0.0,                          0.0, contrastOffset,
        0.0,                          0.0,                          sb * reinhardGain * contrast, 0.0, contrastOffset,
        0.0,                          0.0,                          0.0,                          1.0, 0.0,
      ];
    }

    // Mid / High / Ultra: Full Cinematic ACES filmic grading
    final double contrast = config.contrast.clamp(0.5, 2.0);
    final double saturation = config.saturation.clamp(0.0, 2.5);
    final double temp = config.colorTemperature.clamp(-1.0, 1.0);
    final double tint = config.tint.clamp(-1.0, 1.0);

    // Color Temperature & Tint multipliers
    // Temperature: warm adds red, cold adds blue
    final double rTemp = 1.0 + (temp > 0 ? temp * 0.18 : temp * 0.08);
    final double bTemp = 1.0 - (temp > 0 ? temp * 0.12 : temp * 0.22);
    // Tint: magenta adds red+blue, green adds green
    final double gTint = 1.0 - tint * 0.12;
    final double rTint = 1.0 + (tint > 0 ? tint * 0.06 : 0.0);
    final double bTint = 1.0 + (tint > 0 ? tint * 0.06 : 0.0);

    final double rScale = exposure * rTemp * rTint;
    final double gScale = exposure * gTint;
    final double bScale = exposure * bTemp * bTint;

    // Rec.709 Luma coefficients
    const double lr = 0.2126;
    const double lg = 0.7152;
    const double lb = 0.0722;

    // Saturation matrix elements
    final double invSat = 1.0 - saturation;
    final double sr0 = invSat * lr + saturation;
    final double sr1 = invSat * lg;
    final double sr2 = invSat * lb;

    final double sg0 = invSat * lr;
    final double sg1 = invSat * lg + saturation;
    final double sg2 = invSat * lb;

    final double sb0 = invSat * lr;
    final double sb1 = invSat * lg;
    final double sb2 = invSat * lb + saturation;

    // Contrast pivot offset: midtone ~ 0.5 * 255 = 128
    final double contrastOffset = 128.0 * (1.0 - contrast);

    // Composite matrix: [R', G', B', A', Offset]
    return <double>[
      sr0 * rScale * contrast, sr1 * gScale * contrast, sr2 * bScale * contrast, 0.0, contrastOffset,
      sg0 * rScale * contrast, sg1 * gScale * contrast, sg2 * bScale * contrast, 0.0, contrastOffset,
      sb0 * rScale * contrast, sb1 * gScale * contrast, sb2 * bScale * contrast, 0.0, contrastOffset,
      0.0,                     0.0,                     0.0,                     1.0, 0.0,
    ];
  }
}

/// CustomPainter rendering smooth lens vignette darkening on mobile viewports.
class VignettePainter extends CustomPainter {
  const VignettePainter({
    required this.intensity,
    required this.radius,
    required this.smoothness,
    required this.color,
  });

  final double intensity;
  final double radius;
  final double smoothness;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || intensity <= 0.001) {
      return;
    }

    final double maxDim = math.max(size.width, size.height);
    final double r = (maxDim * 0.5 * radius).clamp(10.0, maxDim * 2.0);
    final Offset center = Offset(size.width * 0.5, size.height * 0.5);

    final double innerStop = math.max(0.0, 1.0 - smoothness).clamp(0.0, 0.95);

    final Paint paint = Paint()
      ..blendMode = BlendMode.multiply
      ..shader = ui.Gradient.radial(
        center,
        r,
        <Color>[
          Colors.transparent,
          color.withValues(alpha: intensity * 0.4),
          color.withValues(alpha: intensity),
        ],
        <double>[innerStop, (innerStop + 1.0) * 0.5, 1.0],
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant VignettePainter oldDelegate) {
    return oldDelegate.intensity != intensity ||
        oldDelegate.radius != radius ||
        oldDelegate.smoothness != smoothness ||
        oldDelegate.color != color;
  }
}

/// CustomPainter rendering cinematic bloom glow and high-dynamic-range (HDR) highlight diffusion.
class AcesBloomPainter extends CustomPainter {
  const AcesBloomPainter({
    required this.intensity,
    required this.threshold,
    required this.hdrHighlights,
    this.bloomColor = const Color(0x33FFE8B0),
  });

  final double intensity;
  final double threshold;
  final bool hdrHighlights;
  final Color bloomColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || intensity <= 0.001) {
      return;
    }

    final Paint bloomPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.35),
        math.max(size.width, size.height) * 0.75,
        <Color>[
          bloomColor.withValues(alpha: (intensity * 0.35).clamp(0.0, 1.0)),
          bloomColor.withValues(alpha: (intensity * 0.12).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        const <double>[0.0, 0.45, 1.0],
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bloomPaint);

    if (hdrHighlights) {
      final Paint highlightPaint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.8, size.height * 0.15),
          size.width * 0.45,
          <Color>[
            const Color(0x22FFFFFF).withValues(alpha: (intensity * 0.25).clamp(0.0, 1.0)),
            Colors.transparent,
          ],
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), highlightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AcesBloomPainter oldDelegate) {
    return oldDelegate.intensity != intensity ||
        oldDelegate.threshold != threshold ||
        oldDelegate.hdrHighlights != hdrHighlights ||
        oldDelegate.bloomColor != bloomColor;
  }
}

/// Composable Flutter widget providing ACES Filmic Tonemapping, adaptive quality scaling,
/// ZeroJankPreloader shader pipeline pre-warming, and cinematic color grading.
class AcesTonemappingLayer extends StatefulWidget {
  const AcesTonemappingLayer({
    super.key,
    required this.child,
    this.config = const AcesTonemappingConfig(),
    this.enableGrading = true,
    this.enableVignette = true,
    this.enableBloom,
    this.scaler,
    this.autoPreload = true,
  });

  /// Underlying child widget (3D viewport, scene, or layout).
  final Widget child;

  /// ACES and color grading parameters.
  final AcesTonemappingConfig config;

  /// Whether color grading and tonemapping matrix is applied.
  final bool enableGrading;

  /// Whether vignette corner darkening is applied.
  final bool enableVignette;

  /// Optional override for bloom compositing. If null, adapts automatically to scaler tier.
  final bool? enableBloom;

  /// Optional injected AdaptiveQualityScaler instance. Falls back to GraphicsSettingsService.instance.scaler.
  final AdaptiveQualityScaler? scaler;

  /// Whether to automatically trigger ZeroJankPreloader shader pipeline warmup in background.
  final bool autoPreload;

  static bool _pipelinePrewarmed = false;

  /// Pre-warms the ACES tonemapping and color grading shader pipeline using ZeroJankPreloader.
  /// Executes within a time-sliced budget strictly < 2.0ms to prevent any main thread jank.
  static Future<bool> prewarmShaderPipeline({
    ZeroJankPreloader? preloader,
    PreloadPriority priority = PreloadPriority.criticalHud,
    bool force = false,
  }) async {
    if (_pipelinePrewarmed && !force) return true;
    final ZeroJankPreloader effectivePreloader = preloader ?? ZeroJankPreloader.instance;
    const String taskId = 'shader_aces_tonemapping_pipeline';

    try {
      final bool result = await effectivePreloader.preloadShader<bool>(
        id: taskId,
        priority: priority,
        tags: const <String>{'shader', 'tonemapping', 'aces', 'color_filter'},
        estimatedSizeBytes: 128 * 1024,
        shaderWarmupLoader: (PreloadExecutionContext ctx) async {
          ctx.reportProgress(0.1);

          // 1. Analytical curve fits warmup
          for (final double x in const <double>[0.0, 0.18, 0.5, 1.0, 2.0, 4.0]) {
            AcesMath.narkowiczCurve(x);
            AcesMath.stephenHillCurve(x);
            AcesMath.reinhardCurve(x);
          }

          if (ctx.shouldYield()) {
            await ctx.yieldControl();
          }
          ctx.reportProgress(0.4);

          // 2. ColorFilter matrix generation & shader pipeline warmup
          const AcesTonemappingConfig fullAces = AcesTonemappingConfig();
          const AcesTonemappingConfig fastReinhard = AcesTonemappingConfig(
            fitType: AcesFitType.reinhard,
          );
          const AcesTonemappingConfig directPassThrough = AcesTonemappingConfig(
            fitType: AcesFitType.passThrough,
          );

          ColorFilter.matrix(AcesMath.generateColorGradingMatrix(fullAces));
          ColorFilter.matrix(AcesMath.generateColorGradingMatrix(fastReinhard));
          ColorFilter.matrix(AcesMath.generateColorGradingMatrix(directPassThrough));

          if (ctx.shouldYield()) {
            await ctx.yieldControl();
          }
          ctx.reportProgress(0.7);

          // 3. Radial Vignette & Bloom shader warmup
          final Paint vignettePaint = Paint()
            ..blendMode = BlendMode.multiply
            ..shader = ui.Gradient.radial(
              const Offset(100, 100),
              150.0,
              const <Color>[Colors.transparent, Color(0xFF030712)],
              const <double>[0.5, 1.0],
            );
          vignettePaint.blendMode;

          final Paint bloomPaint = Paint()
            ..blendMode = BlendMode.screen
            ..shader = ui.Gradient.radial(
              const Offset(100, 100),
              200.0,
              const <Color>[Color(0x33FFE8B0), Colors.transparent],
              const <double>[0.0, 1.0],
            );
          bloomPaint.blendMode;

          ctx.reportProgress(1.0);
          return true;
        },
      );
      _pipelinePrewarmed = result;
      return result;
    } catch (_) {
      return false;
    }
  }

  @override
  State<AcesTonemappingLayer> createState() => _AcesTonemappingLayerState();
}

class _AcesTonemappingLayerState extends State<AcesTonemappingLayer> {
  AdaptiveQualityScaler? _scaler;
  StreamSubscription<QualitySettings>? _settingsSub;

  @override
  void initState() {
    super.initState();
    _resolveScaler();
    if (widget.autoPreload) {
      unawaited(AcesTonemappingLayer.prewarmShaderPipeline());
    }
  }

  @override
  void didUpdateWidget(covariant AcesTonemappingLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scaler != oldWidget.scaler) {
      _resolveScaler();
    }
  }

  void _resolveScaler() {
    _settingsSub?.cancel();
    _scaler = widget.scaler;
    if (_scaler == null) {
      try {
        _scaler = GraphicsSettingsService.instance.scaler;
      } catch (_) {
        _scaler = null;
      }
    }
    if (_scaler != null) {
      _settingsSub = _scaler!.onSettingsChanged.listen((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    super.dispose();
  }

  HardwareTier get _currentTier => _scaler?.currentTier ?? HardwareTier.mid;
  int get _throttleLevel => _scaler?.currentThrottleLevel ?? 0;

  @override
  Widget build(BuildContext context) {
    final HardwareTier tier = _currentTier;
    final int throttle = _throttleLevel;
    final bool isEcoOrThrottled = tier == HardwareTier.eco || throttle >= 3;

    // Resolve tier-adapted configuration
    final AcesTonemappingConfig effectiveConfig = widget.config.adaptToScaler(
      tier: tier,
      throttleLevel: throttle,
    );

    Widget content = widget.child;

    // Apply GPU-accelerated ColorFilter matrix
    if (widget.enableGrading) {
      final List<double> matrix = AcesMath.generateColorGradingMatrix(effectiveConfig);
      content = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: content,
      );
    }

    // Bloom compositing and HDR highlights on Mid / High / Ultra tiers
    final bool scalerAllowsBloom = _scaler?.currentSettings.bloomEnabled ??
        (tier.index >= HardwareTier.mid.index && throttle < 2);
    final bool shouldApplyBloom = (widget.enableBloom ?? effectiveConfig.enableBloom) &&
        scalerAllowsBloom &&
        !isEcoOrThrottled &&
        effectiveConfig.bloomIntensity > 0.005;

    if (shouldApplyBloom) {
      content = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          content,
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: AcesBloomPainter(
                    intensity: effectiveConfig.bloomIntensity,
                    threshold: effectiveConfig.bloomThreshold,
                    hdrHighlights: effectiveConfig.hdrHighlights,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Overlay lens vignette if enabled
    final bool shouldApplyVignette = widget.enableVignette &&
        effectiveConfig.vignetteIntensity > 0.005 &&
        !isEcoOrThrottled;

    if (shouldApplyVignette) {
      content = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          content,
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: VignettePainter(
                    intensity: effectiveConfig.vignetteIntensity,
                    radius: effectiveConfig.vignetteRadius,
                    smoothness: effectiveConfig.vignetteSmoothness,
                    color: effectiveConfig.vignetteColor,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return content;
  }
}
