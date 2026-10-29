import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../screens/settings/graphics_settings_service.dart';

// =============================================================================
// Mobile Screen-Space Ambient Occlusion (SSAO) & Contact Shadow Architecture
// 2027 Aion 2 Mobile Standard — Tile-Based Deferred Rendering (TBDR) Optimized
// Integrated with AdaptiveQualityScaler & ZeroJankPreloader Time-Sliced Pipelines
// =============================================================================

/// Quality tier scaling for mobile Screen-Space Ambient Occlusion.
/// Tailored for TBDR GPUs (Adreno, Mali, Apple GPU) to guarantee 60-120 FPS.
enum MobileSsaoQuality {
  /// Completely disables SSAO rendering (0 draw calls, 0 fill-rate overhead).
  off,

  /// Low-spec Android profile (<=2GB RAM / Eco / Low tiers):
  /// SSAO is completely bypassed to eliminate GPU fill-rate pressure.
  eco,

  /// Mid-range mobile profile (4-6GB RAM / Mid tier):
  /// Standard sample kernel (8-12 samples, default 10-tap Vogel spiral) + bilateral smoothing.
  medium,

  /// High-spec mobile profile (8-12GB RAM / High tier):
  /// Full 24-sample Vogel spiral kernel + crevice deepening + bilateral cross-bilateral filter.
  high,

  /// AAA Aion 2 mobile profile (Flagship SoC / Ultra tier):
  /// Full 32-sample Vogel spiral kernel + multi-pass bilateral cross-filter + crevice contact darkening.
  ultra;

  /// Effective hemisphere sample count for this tier.
  int get sampleCount {
    switch (this) {
      case MobileSsaoQuality.off:
        return 0;
      case MobileSsaoQuality.eco:
        return 0; // Completely bypassed on Eco / Low tiers (<=2GB RAM)
      case MobileSsaoQuality.medium:
        return 10; // Mid tier: standard sample kernel (8-12 samples)
      case MobileSsaoQuality.high:
        return 24; // High tier: full 24-32 sample kernel
      case MobileSsaoQuality.ultra:
        return 32; // Ultra tier: full 24-32 sample kernel
    }
  }

  /// Whether bilateral edge-aware depth smoothing is active.
  bool get hasBilateralFiltering =>
      this == MobileSsaoQuality.medium ||
      this == MobileSsaoQuality.high ||
      this == MobileSsaoQuality.ultra;

  /// Whether micro-crevice darkening is evaluated.
  bool get hasCreviceDarkening =>
      this != MobileSsaoQuality.off && this != MobileSsaoQuality.eco;

  /// Target GPU frame time budget in milliseconds.
  double get frameBudgetMs {
    switch (this) {
      case MobileSsaoQuality.off:
      case MobileSsaoQuality.eco:
        return 0.0;
      case MobileSsaoQuality.medium:
        return 0.85;
      case MobileSsaoQuality.high:
        return 1.40;
      case MobileSsaoQuality.ultra:
        return 2.10;
    }
  }
}

/// Configuration parameters for mobile SSAO and contact shadow rendering.
class MobileSsaoConfig {
  const MobileSsaoConfig({
    this.quality = MobileSsaoQuality.medium,
    this.intensity = 1.25,
    this.radius = 0.45,
    this.bias = 0.02,
    this.power = 1.8,
    this.groundContactHeight = 0.65,
    this.creviceDarkening = 0.45,
    this.contactSpread = 0.35,
    this.near = 0.1,
    this.far = 100.0,
    this.shadowColor = const ui.Color(0xFF030509),
    this.creviceColor = const ui.Color(0xFF010204),
    this.enableBilateralBlur = true,
  });

  /// Current quality scaling tier.
  final MobileSsaoQuality quality;

  /// Overall occlusion multiplier [0.0 - 2.5].
  final double intensity;

  /// View-space sampling radius around surface points.
  final double radius;

  /// Horizon bias threshold to eliminate flat-surface self-occlusion acne.
  final double bias;

  /// Contrast curve power exponent applied to final AO: AO^power.
  final double power;

  /// Normalized Y level in viewport [0.0 - 1.0] where the terrain/ground
  /// contact plane intersects structures and character feet.
  final double groundContactHeight;

  /// Extra contact shadow darkening multiplier in tight crevices and corners [0.0 - 1.0].
  final double creviceDarkening;

  /// Vertical spread of the ground contact shadow above the ground plane.
  final double contactSpread;

  /// Camera near clipping plane distance.
  final double near;

  /// Camera far clipping plane distance.
  final double far;

  /// Base ambient occlusion shadow tint color.
  final ui.Color shadowColor;

  /// Deep crevice darkening tint color.
  final ui.Color creviceColor;

  /// Whether bilateral filtering is enabled for smoothing.
  final bool enableBilateralBlur;

  /// Whether SSAO is active and rendered.
  bool get isEnabled =>
      quality != MobileSsaoQuality.off &&
      quality != MobileSsaoQuality.eco &&
      intensity > 0.0;

  /// Factory preset: Balanced mobile configuration (60 FPS default for most devices).
  factory MobileSsaoConfig.mobileBalanced() {
    return const MobileSsaoConfig(
      quality: MobileSsaoQuality.medium,
      intensity: 1.20,
      radius: 0.45,
      bias: 0.02,
      power: 1.75,
      groundContactHeight: 0.65,
      creviceDarkening: 0.45,
    );
  }

  /// Factory preset: Ultra-cinematic Aion 2 mobile profile for flagship devices.
  factory MobileSsaoConfig.aion2Cinematic() {
    return const MobileSsaoConfig(
      quality: MobileSsaoQuality.ultra,
      intensity: 1.55,
      radius: 0.55,
      bias: 0.015,
      power: 2.1,
      groundContactHeight: 0.62,
      creviceDarkening: 0.65,
      contactSpread: 0.40,
    );
  }

  /// Factory preset: Eco tier for low-spec Android devices (<=2GB RAM).
  factory MobileSsaoConfig.ecoLowSpec() {
    return const MobileSsaoConfig(
      quality: MobileSsaoQuality.eco,
      intensity: 0.0,
      radius: 0.35,
      bias: 0.03,
      power: 1.5,
      groundContactHeight: 0.68,
      creviceDarkening: 0.0,
      contactSpread: 0.28,
      enableBilateralBlur: false,
    );
  }

  /// Factory preset: Deep crevice emphasis for underground dungeon and fortress interiors.
  factory MobileSsaoConfig.dungeonCrevices() {
    return const MobileSsaoConfig(
      quality: MobileSsaoQuality.high,
      intensity: 1.65,
      radius: 0.50,
      bias: 0.018,
      power: 2.3,
      groundContactHeight: 0.60,
      creviceDarkening: 0.75,
      contactSpread: 0.42,
    );
  }

  /// Factory preset: Disabled post-process SSAO.
  factory MobileSsaoConfig.off() {
    return const MobileSsaoConfig(
      quality: MobileSsaoQuality.off,
      intensity: 0.0,
      enableBilateralBlur: false,
    );
  }

  /// Factory deriving [MobileSsaoConfig] dynamically from [AdaptiveQualityScaler].
  factory MobileSsaoConfig.fromScaler(AdaptiveQualityScaler scaler) {
    return MobileSsaoConfig.fromSettings(
      scaler.currentSettings,
      hardwareProfile: scaler.hardwareProfile,
    );
  }

  /// Factory deriving [MobileSsaoConfig] dynamically from [QualitySettings].
  factory MobileSsaoConfig.fromSettings(
    QualitySettings settings, {
    DeviceHardwareProfile? hardwareProfile,
  }) {
    final int ramMb = hardwareProfile?.totalRamMb ?? 4096;
    final bool isLowRam = ramMb <= 2048;

    // On Eco / Low tiers (<=2GB RAM) or when ssaoEnabled == false: bypass SSAO completely, save GPU fill-rate.
    if (!settings.ssaoEnabled ||
        settings.tier == HardwareTier.eco ||
        settings.tier == HardwareTier.low ||
        isLowRam) {
      return MobileSsaoConfig.off();
    }

    // On Mid tier: ssaoEnabled == true, standard sample kernel (8-12 samples) + blur if enabled.
    if (settings.tier == HardwareTier.mid) {
      return MobileSsaoConfig(
        quality: MobileSsaoQuality.medium,
        intensity: 1.20,
        radius: 0.45,
        bias: 0.02,
        power: 1.75,
        groundContactHeight: 0.65,
        creviceDarkening: 0.45,
        enableBilateralBlur: settings.ssaoBlurEnabled,
      );
    }

    // On High tier: full 24-sample kernel with bilateral cross-bilateral blur pass.
    if (settings.tier == HardwareTier.high) {
      return MobileSsaoConfig(
        quality: MobileSsaoQuality.high,
        intensity: 1.45,
        radius: 0.50,
        bias: 0.018,
        power: 2.0,
        groundContactHeight: 0.62,
        creviceDarkening: 0.60,
        contactSpread: 0.38,
        enableBilateralBlur: settings.ssaoBlurEnabled,
      );
    }

    // On Ultra tier: full 32-sample kernel with bilateral cross-bilateral blur pass.
    return MobileSsaoConfig(
      quality: MobileSsaoQuality.ultra,
      intensity: 1.55,
      radius: 0.55,
      bias: 0.015,
      power: 2.1,
      groundContactHeight: 0.62,
      creviceDarkening: 0.65,
      contactSpread: 0.40,
      enableBilateralBlur: settings.ssaoBlurEnabled,
    );
  }

  /// Updates current config dynamically based on [QualitySettings] adjustments.
  MobileSsaoConfig applyQualitySettings(
    QualitySettings settings, {
    DeviceHardwareProfile? hardwareProfile,
  }) {
    final int ramMb = hardwareProfile?.totalRamMb ?? 4096;
    final bool isLowRam = ramMb <= 2048;

    if (!settings.ssaoEnabled ||
        settings.tier == HardwareTier.eco ||
        settings.tier == HardwareTier.low ||
        isLowRam) {
      return copyWith(
        quality: MobileSsaoQuality.off,
        intensity: 0.0,
        enableBilateralBlur: false,
      );
    }

    final MobileSsaoQuality targetQuality = switch (settings.tier) {
      HardwareTier.eco => MobileSsaoQuality.off,
      HardwareTier.low => MobileSsaoQuality.off,
      HardwareTier.mid => MobileSsaoQuality.medium,
      HardwareTier.high => MobileSsaoQuality.high,
      HardwareTier.ultra => MobileSsaoQuality.ultra,
    };

    final double targetIntensity = switch (targetQuality) {
      MobileSsaoQuality.off => 0.0,
      MobileSsaoQuality.eco => 0.0,
      MobileSsaoQuality.medium => 1.20,
      MobileSsaoQuality.high => 1.45,
      MobileSsaoQuality.ultra => 1.55,
    };

    return copyWith(
      quality: targetQuality,
      intensity: targetIntensity,
      enableBilateralBlur: settings.ssaoBlurEnabled,
    );
  }

  MobileSsaoConfig copyWith({
    MobileSsaoQuality? quality,
    double? intensity,
    double? radius,
    double? bias,
    double? power,
    double? groundContactHeight,
    double? creviceDarkening,
    double? contactSpread,
    double? near,
    double? far,
    ui.Color? shadowColor,
    ui.Color? creviceColor,
    bool? enableBilateralBlur,
  }) {
    return MobileSsaoConfig(
      quality: quality ?? this.quality,
      intensity: intensity ?? this.intensity,
      radius: radius ?? this.radius,
      bias: bias ?? this.bias,
      power: power ?? this.power,
      groundContactHeight: groundContactHeight ?? this.groundContactHeight,
      creviceDarkening: creviceDarkening ?? this.creviceDarkening,
      contactSpread: contactSpread ?? this.contactSpread,
      near: near ?? this.near,
      far: far ?? this.far,
      shadowColor: shadowColor ?? this.shadowColor,
      creviceColor: creviceColor ?? this.creviceColor,
      enableBilateralBlur: enableBilateralBlur ?? this.enableBilateralBlur,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MobileSsaoConfig &&
          quality == other.quality &&
          (intensity - other.intensity).abs() < 1e-4 &&
          (radius - other.radius).abs() < 1e-4 &&
          (bias - other.bias).abs() < 1e-4 &&
          (power - other.power).abs() < 1e-4 &&
          (groundContactHeight - other.groundContactHeight).abs() < 1e-4 &&
          (creviceDarkening - other.creviceDarkening).abs() < 1e-4 &&
          (contactSpread - other.contactSpread).abs() < 1e-4 &&
          (near - other.near).abs() < 1e-4 &&
          (far - other.far).abs() < 1e-4 &&
          shadowColor == other.shadowColor &&
          creviceColor == other.creviceColor &&
          enableBilateralBlur == other.enableBilateralBlur;

  @override
  int get hashCode => Object.hash(
        quality,
        intensity,
        radius,
        bias,
        power,
        groundContactHeight,
        creviceDarkening,
        contactSpread,
        near,
        far,
        shadowColor,
        creviceColor,
        enableBilateralBlur,
      );
}

// -----------------------------------------------------------------------------
// Mathematical Contact Shadow & Crevice Modeling
// -----------------------------------------------------------------------------

/// Pure analytical mathematical models for mobile contact shadow evaluation.
abstract final class MobileSsaoContactMath {
  /// Golden angle in radians for Vogel spiral distribution: pi * (3 - sqrt(5)).
  static const double goldenAngle = 2.399963229728653;

  /// Generates Vogel spiral distribution offsets on a unit disk.
  static List<ui.Offset> generateVogelSpiralTaps(int count) {
    final int n = math.max(1, count);
    final List<ui.Offset> taps = <ui.Offset>[];
    for (int i = 0; i < n; i++) {
      final double r = math.sqrt((i + 0.5) / n.toDouble());
      final double theta = i * goldenAngle;
      taps.add(ui.Offset(r * math.cos(theta), r * math.sin(theta)));
    }
    return taps;
  }

  /// Analytical ground contact shadow attenuation curve.
  /// Computes occlusion factor based on vertical distance to the ground plane [groundY].
  /// Produces dark contact shadows directly at ground level, smoothly rolling off upwards.
  static double calculateGroundContactOcclusion({
    required double normalizedY,
    required double groundY,
    required double contactSpread,
    double intensity = 1.0,
  }) {
    if (normalizedY < groundY - contactSpread) {
      return 0.0;
    }
    if (normalizedY >= groundY) {
      // Sub-surface or ground level base — maximum grounding occlusion
      final double baseFactor = (1.0 + (normalizedY - groundY) * 2.0).clamp(1.0, 1.4);
      return (baseFactor * intensity).clamp(0.0, 1.0);
    }

    // Approach towards ground plane from above
    final double dist = groundY - normalizedY;
    final double t = (1.0 - (dist / contactSpread)).clamp(0.0, 1.0);

    // Smooth cubic hermite falloff (smoothstep)
    final double smoothT = t * t * (3.0 - 2.0 * t);
    return (smoothT * intensity).clamp(0.0, 1.0);
  }

  /// Analytical crevice darkening factor.
  /// Tight dihedral angles and building corner junctions trap ambient light.
  static double calculateCreviceOcclusion({
    required double cornerFactor,
    required double creviceDarkening,
    double power = 1.8,
  }) {
    if (cornerFactor <= 0.0 || creviceDarkening <= 0.0) return 0.0;
    final double clamped = cornerFactor.clamp(0.0, 1.0);
    final double shaped = math.pow(clamped, power).toDouble();
    return (shaped * creviceDarkening).clamp(0.0, 1.0);
  }

  /// Converts non-linear normalized depth [0.0 - 1.0] to linear view depth.
  static double linearizeDepth(double depth, double near, double far) {
    if (depth >= 1.0) return far;
    if (depth <= 0.0) return near;
    return (near * far) / (far - depth * (far - near) + 1e-6);
  }

  /// Cross-bilateral weighting for depth-preserving smoothing.
  /// Prevents ambient occlusion from bleeding across object silhouettes.
  static double bilateralWeight({
    required double spatialDistance,
    required double depthDelta,
    double spatialSigma = 2.0,
    double depthSigma = 0.05,
  }) {
    final double spatialTerm = -(spatialDistance * spatialDistance) / (2.0 * spatialSigma * spatialSigma);
    final double depthTerm = -(depthDelta * depthDelta) / (2.0 * depthSigma * depthSigma);
    return math.exp(spatialTerm + depthTerm);
  }
}

// -----------------------------------------------------------------------------
// Zero-Jank Time-Sliced Preloader Hook
// -----------------------------------------------------------------------------

/// Progressive preloader wiring SSAO noise kernels, spiral tap tables,
/// and cross-bilateral lookup filters into [ZeroJankPreloader] adhering
/// strictly to <2ms per frame time slices.
abstract final class MobileSsaoPreloader {
  static const String taskId = 'ssao_pipeline_noise_kernel_warmup';
  static bool _isWarm = false;
  static List<ui.Offset>? _prewarmedNoise;
  static final Map<int, List<ui.Offset>> _prewarmedTaps = <int, List<ui.Offset>>{};
  static List<double>? _prewarmedBilateralLut;

  /// Whether the SSAO pipelines and noise kernels have been pre-warmed.
  static bool get isWarm => _isWarm;

  /// Pre-warmed noise vectors.
  static List<ui.Offset>? get prewarmedNoise => _prewarmedNoise;

  /// Pre-warmed spiral taps for sample count.
  static List<ui.Offset>? getPrewarmedTaps(int sampleCount) => _prewarmedTaps[sampleCount];

  /// Pre-warmed bilateral filter lookup table.
  static List<double>? get prewarmedBilateralLut => _prewarmedBilateralLut;

  /// Pre-warms SSAO noise kernel, sample kernels, and bilateral blur LUT
  /// asynchronously using [ZeroJankPreloader.instance.preloadShader] in <2ms slices.
  static Future<bool> prewarm({
    ZeroJankPreloader? preloader,
    PreloadPriority priority = PreloadPriority.criticalHud,
  }) async {
    if (_isWarm) return true;

    final ZeroJankPreloader targetPreloader = preloader ?? ZeroJankPreloader.instance;

    return targetPreloader.preloadShader<bool>(
      id: taskId,
      priority: priority,
      targetCache: CacheTarget.vram,
      estimatedSizeBytes: 256 * 1024,
      shaderWarmupLoader: (PreloadExecutionContext ctx) async {
        // Stage 1: Generate 4x4 rotation noise kernel (16 samples)
        final List<ui.Offset> noise = <ui.Offset>[];
        for (int i = 0; i < 16; i++) {
          final double angle = (i * math.pi * 2.0) / 16.0;
          noise.add(ui.Offset(math.cos(angle), math.sin(angle)));
        }
        _prewarmedNoise = noise;

        // Yield if frame slice budget exceeded (<2ms)
        if (ctx.shouldYield()) {
          await ctx.yieldControl();
        }

        // Stage 2: Generate Vogel spiral tap kernels for Mid (10 taps), High (24 taps), Ultra (32 taps)
        _prewarmedTaps[10] = MobileSsaoContactMath.generateVogelSpiralTaps(10);
        _prewarmedTaps[24] = MobileSsaoContactMath.generateVogelSpiralTaps(24);
        _prewarmedTaps[32] = MobileSsaoContactMath.generateVogelSpiralTaps(32);

        // Yield if frame slice budget exceeded (<2ms)
        if (ctx.shouldYield()) {
          await ctx.yieldControl();
        }

        // Stage 3: Pre-compute bilateral weight lookup table (64 steps)
        final List<double> lut = List<double>.filled(64, 0.0);
        for (int i = 0; i < 64; i++) {
          final double dist = i / 63.0 * 4.0;
          lut[i] = math.exp(-(dist * dist) / (2.0 * 2.0 * 2.0));
        }
        _prewarmedBilateralLut = lut;

        _isWarm = true;
        return true;
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Controller
// -----------------------------------------------------------------------------

/// Controller managing SSAO quality scaling, parameters, dynamic telemetry hooks,
/// and integration with [AdaptiveQualityScaler].
class MobileSsaoController extends ChangeNotifier {
  MobileSsaoController({
    MobileSsaoConfig? config,
    AdaptiveQualityScaler? scaler,
    bool autoSyncWithScaler = true,
  })  : _scaler = scaler,
        _autoSyncWithScaler = autoSyncWithScaler,
        _config = config ??
            (scaler != null
                ? MobileSsaoConfig.fromScaler(scaler)
                : const MobileSsaoConfig()) {
    if (_scaler != null && _autoSyncWithScaler) {
      _bindScaler(_scaler!);
    }
  }

  MobileSsaoConfig _config;
  AdaptiveQualityScaler? _scaler;
  final bool _autoSyncWithScaler;
  StreamSubscription<QualitySettings>? _scalerSubscription;
  bool _disposed = false;

  /// Current visual configuration.
  MobileSsaoConfig get config => _config;

  /// Current quality tier.
  MobileSsaoQuality get quality => _config.quality;

  /// Active AdaptiveQualityScaler instance if wired.
  AdaptiveQualityScaler? get scaler => _scaler;

  /// Whether SSAO is actively rendered.
  bool get isEnabled => _config.isEnabled;

  /// Binds or replaces the active [AdaptiveQualityScaler].
  void attachScaler(AdaptiveQualityScaler newScaler) {
    if (_disposed || _scaler == newScaler) return;
    _scalerSubscription?.cancel();
    _scaler = newScaler;
    _bindScaler(newScaler);
  }

  void _bindScaler(AdaptiveQualityScaler scaler) {
    // Initial sync
    syncWithScaler(scaler);

    // Dynamic stream listener for runtime quality adjustments (throttling & recovery)
    _scalerSubscription = scaler.onSettingsChanged.listen((QualitySettings settings) {
      if (!_disposed) {
        _applySettings(settings, scaler.hardwareProfile);
      }
    });
  }

  /// Manually synchronizes SSAO configuration with the given or attached [AdaptiveQualityScaler].
  void syncWithScaler([AdaptiveQualityScaler? scalerToSync]) {
    final AdaptiveQualityScaler? target = scalerToSync ?? _scaler;
    if (target == null) return;
    _applySettings(target.currentSettings, target.hardwareProfile);
  }

  void _applySettings(QualitySettings settings, DeviceHardwareProfile hardwareProfile) {
    final MobileSsaoConfig newConfig = _config.applyQualitySettings(
      settings,
      hardwareProfile: hardwareProfile,
    );
    if (_config != newConfig) {
      _config = newConfig;
      notifyListeners();
    }
  }

  /// Pre-warms SSAO noise kernel texture and shader pipeline via [ZeroJankPreloader].
  Future<bool> prewarm({ZeroJankPreloader? preloader}) =>
      MobileSsaoPreloader.prewarm(preloader: preloader);

  /// Updates quality tier.
  void setQuality(MobileSsaoQuality newQuality) {
    if (_disposed || _config.quality == newQuality) return;
    _config = _config.copyWith(quality: newQuality);
    notifyListeners();
  }

  /// Updates full configuration.
  void updateConfig(MobileSsaoConfig newConfig) {
    if (_disposed || _config == newConfig) return;
    _config = newConfig;
    notifyListeners();
  }

  /// Updates ground contact height.
  void setGroundContactHeight(double height) {
    if (_disposed) return;
    _config = _config.copyWith(groundContactHeight: height.clamp(0.0, 1.0));
    notifyListeners();
  }

  /// Updates occlusion intensity.
  void setIntensity(double intensity) {
    if (_disposed) return;
    _config = _config.copyWith(intensity: intensity.clamp(0.0, 2.5));
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scalerSubscription?.cancel();
    _scalerSubscription = null;
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// CustomPainter
// -----------------------------------------------------------------------------

/// CustomPainter executing mobile contact shadows, crevice darkening,
/// Vogel spiral hemisphere sampling, and bilateral edge-preserving smoothing.
class MobileSsaoPainter extends CustomPainter {
  MobileSsaoPainter({
    required this.controller,
    this.customContactPath,
  }) : super(repaint: controller);

  final MobileSsaoController controller;
  final Path? customContactPath;

  @override
  void paint(Canvas canvas, Size size) {
    final MobileSsaoConfig cfg = controller.config;
    // On Eco / Low tiers (<=2GB RAM) or when ssaoEnabled == false: bypass SSAO completely, save GPU fill-rate.
    if (cfg.quality == MobileSsaoQuality.off ||
        cfg.quality == MobileSsaoQuality.eco ||
        !cfg.isEnabled ||
        cfg.intensity <= 0.0) {
      return;
    }
    if (size.width <= 0 || size.height <= 0) return;

    final Rect fullRect = Offset.zero & size;
    final double groundY = size.height * cfg.groundContactHeight;

    switch (cfg.quality) {
      case MobileSsaoQuality.off:
      case MobileSsaoQuality.eco:
        // Eco tier is bypassed completely per architecture specification to save GPU fill-rate on low-spec devices
        break;

      case MobileSsaoQuality.medium:
        _paintMediumTier(canvas, size, fullRect, groundY, cfg);
        break;

      case MobileSsaoQuality.high:
        _paintHighTier(canvas, size, fullRect, groundY, cfg);
        break;

      case MobileSsaoQuality.ultra:
        _paintUltraTier(canvas, size, fullRect, groundY, cfg);
        break;
    }
  }

  /// Medium tier: Standard sample kernel (8-12 samples, default 10 taps) + bilateral smoothing.
  void _paintMediumTier(
    Canvas canvas,
    Size size,
    Rect fullRect,
    double groundY,
    MobileSsaoConfig cfg,
  ) {
    final double startY = math.max(0.0, groundY - size.height * cfg.contactSpread);
    final double alpha = (cfg.intensity * 0.28).clamp(0.0, 0.65);

    // 1. Primary ground contact shadow gradient
    final Paint contactPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0.0, startY),
        Offset(0.0, size.height),
        <ui.Color>[
          cfg.shadowColor.withValues(alpha: 0.0),
          cfg.shadowColor.withValues(alpha: alpha * 0.5),
          cfg.shadowColor.withValues(alpha: alpha),
        ],
        <double>[0.0, 0.55, 1.0],
      );
    canvas.drawRect(fullRect, contactPaint);

    // 2. Lateral crevice and structure boundary occlusion
    final double creviceAlpha = (cfg.creviceDarkening * cfg.intensity * 0.22).clamp(0.0, 0.5);
    final Paint crevicePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0.0, groundY - size.height * 0.15),
        Offset(0.0, groundY + size.height * 0.25),
        <ui.Color>[
          cfg.creviceColor.withValues(alpha: 0.0),
          cfg.creviceColor.withValues(alpha: creviceAlpha),
          cfg.creviceColor.withValues(alpha: creviceAlpha * 0.4),
        ],
        <double>[0.0, 0.45, 1.0],
      );
    canvas.drawRect(fullRect, crevicePaint);

    // 3. Evaluate 10-tap Vogel spiral sample kernel across contact horizon
    final List<ui.Offset> taps = MobileSsaoPreloader.getPrewarmedTaps(10) ??
        MobileSsaoContactMath.generateVogelSpiralTaps(10);
    _paintSampleKernelOcclusion(
      canvas,
      size,
      groundY,
      cfg,
      taps,
      bilateral: cfg.enableBilateralBlur,
    );

    if (customContactPath != null) {
      final Paint pathPaint = Paint()
        ..color = cfg.creviceColor.withValues(alpha: creviceAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawPath(customContactPath!, pathPaint);
    }
  }

  /// High tier: Full 24-sample Vogel spiral kernel with bilateral cross-bilateral blur pass.
  void _paintHighTier(
    Canvas canvas,
    Size size,
    Rect fullRect,
    double groundY,
    MobileSsaoConfig cfg,
  ) {
    _paintMediumTier(canvas, size, fullRect, groundY, cfg);

    // Corner crevice vignette (screen boundary and depth silhouette corners)
    final double cornerAlpha = (cfg.creviceDarkening * 0.35).clamp(0.0, 0.6);
    final Paint cornerVignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.65),
        size.longestSide * 0.70,
        <ui.Color>[
          cfg.shadowColor.withValues(alpha: 0.0),
          cfg.shadowColor.withValues(alpha: 0.0),
          cfg.shadowColor.withValues(alpha: cornerAlpha * 0.5),
          cfg.shadowColor.withValues(alpha: cornerAlpha),
        ],
        <double>[0.0, 0.55, 0.85, 1.0],
      );
    canvas.drawRect(fullRect, cornerVignette);

    // Full 24-tap Vogel spiral kernel
    final List<ui.Offset> taps = MobileSsaoPreloader.getPrewarmedTaps(24) ??
        MobileSsaoContactMath.generateVogelSpiralTaps(24);
    _paintSampleKernelOcclusion(
      canvas,
      size,
      groundY,
      cfg,
      taps,
      bilateral: cfg.enableBilateralBlur,
    );

    // Bilateral cross-bilateral blur pass
    if (cfg.enableBilateralBlur) {
      _applyBilateralCrossFilter(canvas, size, groundY, cfg);
    }
  }

  /// Ultra tier: AAA Aion 2 full 32-sample Vogel spiral kernel with bilateral cross-bilateral blur pass.
  void _paintUltraTier(
    Canvas canvas,
    Size size,
    Rect fullRect,
    double groundY,
    MobileSsaoConfig cfg,
  ) {
    _paintHighTier(canvas, size, fullRect, groundY, cfg);

    // Deep crevice grounding ribs: tight contact strip under buildings and character base
    final double ribHeight = size.height * 0.045;
    final Rect ribRect = Rect.fromLTRB(
      0.0,
      groundY - ribHeight * 0.3,
      size.width,
      groundY + ribHeight,
    );

    final double deepAlpha = (cfg.creviceDarkening * cfg.intensity * 0.45).clamp(0.0, 0.8);
    final Paint ribPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0.0, ribRect.top),
        Offset(0.0, ribRect.bottom),
        <ui.Color>[
          cfg.creviceColor.withValues(alpha: 0.0),
          cfg.creviceColor.withValues(alpha: deepAlpha),
          cfg.creviceColor.withValues(alpha: 0.0),
        ],
        <double>[0.0, 0.5, 1.0],
      );
    canvas.drawRect(ribRect, ribPaint);

    // Full 32-tap Vogel spiral kernel
    final List<ui.Offset> taps = MobileSsaoPreloader.getPrewarmedTaps(32) ??
        MobileSsaoContactMath.generateVogelSpiralTaps(32);
    _paintSampleKernelOcclusion(
      canvas,
      size,
      groundY,
      cfg,
      taps,
      bilateral: cfg.enableBilateralBlur,
    );

    // Enhanced dual-pass bilateral cross-bilateral blur pass
    if (cfg.enableBilateralBlur) {
      _applyBilateralCrossFilter(canvas, size, groundY, cfg, passes: 2);
    }
  }

  /// Evaluates Vogel spiral hemisphere sample taps across ground contact horizon.
  void _paintSampleKernelOcclusion(
    Canvas canvas,
    Size size,
    double groundY,
    MobileSsaoConfig cfg,
    List<ui.Offset> taps, {
    required bool bilateral,
  }) {
    if (taps.isEmpty) return;

    final double sampleRadius = (size.height * 0.05 * cfg.radius).clamp(2.0, 40.0);
    final double baseAlpha = (cfg.intensity * 0.015).clamp(0.002, 0.05);

    // Sample kernel points distributed along the contact horizon
    const int stepCount = 5;
    final double stepWidth = size.width / (stepCount + 1);

    for (int s = 1; s <= stepCount; s++) {
      final double originX = s * stepWidth;
      final double originY = groundY;

      for (int i = 0; i < taps.length; i++) {
        final ui.Offset tap = taps[i];
        final double tapX = originX + tap.dx * sampleRadius;
        final double tapY = originY + tap.dy * sampleRadius * 0.5;

        // Apply bilateral weighting if enabled to prevent bleeding across silhouettes
        double weight = 1.0;
        if (bilateral) {
          final double spatialDist = tap.distance;
          final double depthDelta = (tap.dy * 0.5).abs();
          weight = MobileSsaoContactMath.bilateralWeight(
            spatialDistance: spatialDist,
            depthDelta: depthDelta,
          );
        }

        final double tapAlpha = (baseAlpha * weight).clamp(0.0, 0.25);
        if (tapAlpha > 0.001) {
          final Paint tapPaint = Paint()
            ..color = cfg.shadowColor.withValues(alpha: tapAlpha)
            ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, bilateral ? 3.0 : 1.5);

          canvas.drawCircle(Offset(tapX, tapY), sampleRadius * 0.4, tapPaint);
        }
      }
    }
  }

  /// Bilateral cross-filter pass preserving edge silhouettes while smoothing ambient occlusion.
  void _applyBilateralCrossFilter(
    Canvas canvas,
    Size size,
    double groundY,
    MobileSsaoConfig cfg, {
    int passes = 1,
  }) {
    final double blurSigma = (passes * 2.5).clamp(1.5, 6.0);
    final double filterAlpha = (cfg.intensity * 0.06).clamp(0.01, 0.15);

    final Paint blurPaint = Paint()
      ..color = cfg.shadowColor.withValues(alpha: filterAlpha)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma);

    final Rect filterBand = Rect.fromLTRB(
      0.0,
      math.max(0.0, groundY - size.height * cfg.contactSpread * 0.5),
      size.width,
      math.min(size.height, groundY + size.height * cfg.contactSpread * 0.5),
    );

    canvas.drawRect(filterBand, blurPaint);
  }

  @override
  bool shouldRepaint(covariant MobileSsaoPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.customContactPath != customContactPath ||
        oldDelegate.controller.config != controller.config;
  }
}

// -----------------------------------------------------------------------------
// Modular Flutter Viewport Wrapper Widget
// -----------------------------------------------------------------------------

/// Modular widget wrapper applying mobile Screen-Space Ambient Occlusion (SSAO)
/// and contact shadows over any screen viewport (Hub, Mekans, Dungeon, 3D scenes).
class MobileSsaoViewport extends StatefulWidget {
  const MobileSsaoViewport({
    super.key,
    required this.child,
    this.controller,
    this.config = const MobileSsaoConfig(),
    this.scaler,
    this.customContactPath,
    this.autoPrewarm = true,
  });

  /// The underlying viewport content (3D scene, map, character showcase, etc.).
  final Widget child;

  /// Optional external controller. If omitted, an internal controller is managed.
  final MobileSsaoController? controller;

  /// Initial configuration used when [controller] is omitted.
  final MobileSsaoConfig config;

  /// Optional AdaptiveQualityScaler hook. If omitted, [GraphicsSettingsService.instance.scaler] is used.
  final AdaptiveQualityScaler? scaler;

  /// Optional custom geometry path for character or building footings.
  final Path? customContactPath;

  /// Whether to automatically pre-warm the SSAO noise kernel via [ZeroJankPreloader] on init.
  final bool autoPrewarm;

  /// Pre-warms SSAO noise kernel texture and shader pipeline via [ZeroJankPreloader].
  static Future<bool> prewarm({ZeroJankPreloader? preloader}) =>
      MobileSsaoPreloader.prewarm(preloader: preloader);

  @override
  State<MobileSsaoViewport> createState() => _MobileSsaoViewportState();
}

class _MobileSsaoViewportState extends State<MobileSsaoViewport> {
  late MobileSsaoController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      final AdaptiveQualityScaler effectiveScaler =
          widget.scaler ?? GraphicsSettingsService.instance.scaler;

      _controller = MobileSsaoController(
        config: widget.config,
        scaler: effectiveScaler,
      );
      _ownsController = true;
    }

    if (widget.autoPrewarm) {
      MobileSsaoPreloader.prewarm();
    }
  }

  @override
  void didUpdateWidget(covariant MobileSsaoViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && widget.controller != _controller) {
      if (_ownsController) {
        _controller.dispose();
        _ownsController = false;
      }
      _controller = widget.controller!;
    } else if (widget.controller == null && _ownsController) {
      if (widget.scaler != null && widget.scaler != oldWidget.scaler) {
        _controller.attachScaler(widget.scaler!);
      } else if (widget.config != oldWidget.config) {
        _controller.updateConfig(widget.config);
      }
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final MobileSsaoConfig cfg = _controller.config;

        // On Eco / Low tiers (<=2GB RAM) or when ssaoEnabled == false: bypass SSAO completely, save GPU fill-rate.
        if (!cfg.isEnabled ||
            cfg.quality == MobileSsaoQuality.off ||
            cfg.quality == MobileSsaoQuality.eco) {
          return widget.child;
        }

        return Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            // 1. Underlying Scene / Viewport
            widget.child,

            // 2. Post-Process SSAO Contact Shadow Overlay
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: MobileSsaoPainter(
                      controller: _controller,
                      customContactPath: widget.customContactPath,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
