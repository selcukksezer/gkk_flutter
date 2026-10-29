import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:gkk_flutter/core/engine/adaptive_quality_scaler.dart';
import 'package:gkk_flutter/core/engine/zero_jank_preloader.dart';

/// Extension on [AdaptiveQualityScaler] exposing [throttleLevel] alias.
extension AdaptiveQualityScalerThrottleExtension on AdaptiveQualityScaler {
  int get throttleLevel => currentThrottleLevel;
}

// -----------------------------------------------------------------------------
// Production AAA Combat VFX: Rim-Light Hit Flash & Emissive Silhouette
// -----------------------------------------------------------------------------

/// High-performance preloader and warming pipeline for Rim Hit Flash shader & color LUTs.
/// Hooks directly into [ZeroJankPreloader] to guarantee zero-jank frame times (<2ms budget).
class RimHitFlashPreloader {
  RimHitFlashPreloader._();

  static const String shaderTaskId = 'vfx_rim_hit_flash_shader';
  static const String lutTaskId = 'vfx_rim_hit_flash_luts';
  static const String defaultShaderPath = 'shaders/vfx/rim_hit_flash.frag';

  static ui.FragmentProgram? _cachedProgram;
  static Float32List? _srgbToLinearLut;
  static final Map<ui.Color, (double r, double g, double b)> _linearColorCache =
      <ui.Color, (double r, double g, double b)>{};

  /// Pre-warmed sRGB to Linear float lookup table (256 entries).
  static Float32List get srgbToLinearLut {
    if (_srgbToLinearLut == null) {
      _warmupLutsSync();
    }
    return _srgbToLinearLut!;
  }

  /// Synchronously warms the 256-entry sRGB -> Linear lookup table and preset tints (<0.1ms).
  static void _warmupLutsSync() {
    if (_srgbToLinearLut != null) return;
    final Float32List lut = Float32List(256);
    for (int i = 0; i < 256; i++) {
      final double c = i / 255.0;
      if (c <= 0.04045) {
        lut[i] = c / 12.92;
      } else {
        lut[i] = math.pow((c + 0.055) / 1.055, 2.4).toDouble();
      }
    }
    _srgbToLinearLut = lut;

    // Pre-cache linear RGB tuples for standard combat tints
    const List<ui.Color> tints = <ui.Color>[
      RimFlashTint.white,
      RimFlashTint.bloodRed,
      RimFlashTint.magicalCyan,
      RimFlashTint.poisonGreen,
      RimFlashTint.lightningGold,
      RimFlashTint.voidPurple,
    ];
    for (final ui.Color tint in tints) {
      final int rIndex = (tint.r * 255.0).round().clamp(0, 255);
      final int gIndex = (tint.g * 255.0).round().clamp(0, 255);
      final int bIndex = (tint.b * 255.0).round().clamp(0, 255);
      _linearColorCache[tint] = (lut[rIndex], lut[gIndex], lut[bIndex]);
    }
  }

  /// Looks up linear RGB from pre-warmed LUT for combat math.
  static (double r, double g, double b) getLinearRgb(ui.Color color) {
    final (double r, double g, double b)? cached = _linearColorCache[color];
    if (cached != null) return cached;

    final Float32List lut = srgbToLinearLut;
    final int rIdx = (color.r * 255.0).round().clamp(0, 255);
    final int gIdx = (color.g * 255.0).round().clamp(0, 255);
    final int bIdx = (color.b * 255.0).round().clamp(0, 255);

    final (double r, double g, double b) tuple = (lut[rIdx], lut[gIdx], lut[bIdx]);
    if (_linearColorCache.length < 128) {
      _linearColorCache[color] = tuple;
    }
    return tuple;
  }

  /// Pre-warms the rim flash shader and flash color LUTs via [ZeroJankPreloader.instance.preloadShader].
  ///
  /// Strictly respects the <2ms time-slice frame budget, yielding cooperatively to
  /// touch interactions and UI frame deadlines.
  static Future<ui.FragmentProgram?> warmUp({
    String shaderAssetPath = defaultShaderPath,
    ZeroJankPreloader? preloader,
  }) async {
    final ZeroJankPreloader pj = preloader ?? ZeroJankPreloader.instance;

    // 1. Check preloader VRAM cache
    final dynamic cached = pj.getCached(shaderTaskId, CacheTarget.vram);
    if (cached is ui.FragmentProgram) {
      _cachedProgram = cached;
      return cached;
    }

    if (_cachedProgram != null) {
      return _cachedProgram;
    }

    try {
      final ui.FragmentProgram program = await pj.preloadShader<ui.FragmentProgram>(
        id: shaderTaskId,
        priority: PreloadPriority.criticalHud,
        targetCache: CacheTarget.vram,
        estimatedSizeBytes: 128 * 1024,
        tags: const <String>{'vfx', 'combat', 'rim_flash'},
        shaderWarmupLoader: (PreloadExecutionContext ctx) async {
          // Slice 1: Warmup color LUTs (<0.2ms)
          _warmupLutsSync();
          ctx.reportProgress(0.3);

          if (ctx.shouldYield()) {
            await ctx.yieldControl();
          }

          // Slice 2: Asynchronously load fragment program (<1.5ms)
          final ui.FragmentProgram prog =
              await ui.FragmentProgram.fromAsset(shaderAssetPath);
          ctx.reportProgress(0.8);

          if (ctx.shouldYield()) {
            await ctx.yieldControl();
          }

          // Pre-instantiate fragment shader to warm GPU driver pipeline cache
          try {
            final ui.FragmentShader shaderInstance = prog.fragmentShader();
            shaderInstance.setFloat(0, 1.0);
          } catch (_) {}

          ctx.reportProgress(1.0);
          return prog;
        },
      );

      _cachedProgram = program;
      return program;
    } catch (_) {
      // Graceful fallback for test or mock environments
      _warmupLutsSync();
      return null;
    }
  }

  /// Pre-warms flash color LUTs into [ZeroJankPreloader] RAM cache.
  static Future<Float32List> preloadColorLuts({
    ZeroJankPreloader? preloader,
  }) async {
    final ZeroJankPreloader pj = preloader ?? ZeroJankPreloader.instance;

    final dynamic cached = pj.getCached(lutTaskId, CacheTarget.ram);
    if (cached is Float32List) {
      _srgbToLinearLut = cached;
      return cached;
    }

    return pj.preloadAtomic<Float32List>(
      id: lutTaskId,
      priority: PreloadPriority.criticalHud,
      targetCache: CacheTarget.ram,
      estimatedSizeBytes: 1024,
      tags: const <String>{'vfx', 'combat', 'color_lut'},
      isPinned: true,
      loader: () async {
        _warmupLutsSync();
        return _srgbToLinearLut!;
      },
    );
  }

  /// Cached [ui.FragmentProgram] if pre-warmed, otherwise null.
  static ui.FragmentProgram? get cachedProgram => _cachedProgram;
}


/// Preset combat flash tint colors according to R3 combat specs.
class RimFlashTint {
  RimFlashTint._();

  /// Pure physical / blunt / blade impact white flash.
  static const ui.Color white = ui.Color(0xFFFFFFFF);

  /// Critical strike / bleeding / flesh damage blood-red flash.
  static const ui.Color bloodRed = ui.Color(0xFFFF2222);

  /// Arcane / frost / elemental magic strike cyan flash.
  static const ui.Color magicalCyan = ui.Color(0xFF22E5FF);

  /// Poison / venom / acid corrosion green flash.
  static const ui.Color poisonGreen = ui.Color(0xFF33FF55);

  /// Lightning / holy impact gold flash.
  static const ui.Color lightningGold = ui.Color(0xFFFFDF22);

  /// Void / shadow / curse impact purple flash.
  static const ui.Color voidPurple = ui.Color(0xFFA533FF);
}

/// Normal calculation mode for the rim fragment shader.
enum RimFlashNormalMode {
  /// Mode 0: Analytical edge gradient from alpha / luminance (Sobel filter).
  /// Ideal for 2D sprites, rendered character cutouts, and UI cards.
  silhouetteGradient(0.0),

  /// Mode 1: Sample from tangent-space normal map.
  /// Ideal for 3D meshes and normal-mapped sprites.
  normalMap(1.0),

  /// Mode 2: Analytical spherical billboard dome normal.
  /// Ideal for 3D billboard characters and spherical particles.
  sphericalDome(2.0);

  const RimFlashNormalMode(this.shaderValue);
  final double shaderValue;
}

/// Configuration parameters for a rim hit flash effect.
class RimHitFlashConfig {
  const RimHitFlashConfig({
    this.duration = const Duration(milliseconds: 100),
    this.tint = RimFlashTint.white,
    this.rimPower = 3.5,
    this.rimIntensity = 2.0,
    this.innerFlash = 0.4,
    this.edgeBleedWidth = 2.0,
    this.edgeBleedIntensity = 1.2,
    this.bloomMultiplier = 2.5,
    this.normalMode = RimFlashNormalMode.silhouetteGradient,
    this.decayLambda = 4.60517, // e^(-4.60517) ~= 0.01 (1% residual at end of duration)
    this.hitStopDuration = Duration.zero,
    this.enableChromaticAberration = true,
    this.chromaticAberrationOffset = 1.5,
    this.enableMultiPassBlur = true,
    this.blurPasses = 1,
    this.dynamicBloomBurst = false,
  });

  /// Total duration of the flash effect (typically 80-120ms; 15ms on Eco/Low).
  final Duration duration;

  /// Tint color for the hit flash and emissive rim.
  final ui.Color tint;

  /// Fresnel sharpness exponent: higher values yield sharper edge highlights.
  final double rimPower;

  /// Multiplier for the Fresnel rim highlight contribution.
  final double rimIntensity;

  /// Direct full-body inner emissive flash factor [0.0, 1.0].
  final double innerFlash;

  /// Silhouette edge bleed kernel radius in texels.
  final double edgeBleedWidth;

  /// Multiplier for the silhouette edge bleed / glow halo.
  final double edgeBleedIntensity;

  /// HDR luminance overdrive factor for downstream bloom passes.
  final double bloomMultiplier;

  /// Normal reconstruction mode.
  final RimFlashNormalMode normalMode;

  /// Exponential decay coefficient.
  final double decayLambda;

  /// Hit-stop animation freeze duration (e.g. 30-50ms on Ultra) where flash holds peak.
  final Duration hitStopDuration;

  /// Whether secondary chromatic aberration edge fringe is enabled.
  /// Strictly eliminated on Eco/Low tiers (<=2GB RAM) to minimize draw passes.
  final bool enableChromaticAberration;

  /// Texel offset for secondary chromatic fringe. 0.0 on Eco/Low; 2.5 on Ultra.
  final double chromaticAberrationOffset;

  /// Whether multi-pass blur glow is enabled.
  /// Strictly skipped on Eco/Low tiers (<=2GB RAM) for zero-jank 60 FPS.
  final bool enableMultiPassBlur;

  /// Number of blur passes for dynamic bloom burst (0 on Eco/Low, 2 on Ultra).
  final int blurPasses;

  /// Whether dynamic bloom burst overdriving is active (Ultra tier exclusive).
  final bool dynamicBloomBurst;

  /// Factory adapting configuration dynamically to [AdaptiveQualityScaler].
  factory RimHitFlashConfig.adaptive({
    required AdaptiveQualityScaler scaler,
    RimHitFlashConfig base = const RimHitFlashConfig(),
  }) {
    return adaptToScaler(base, scaler);
  }

  /// Adapts a [RimHitFlashConfig] to the host device's [HardwareTier] and runtime [throttleLevel].
  static RimHitFlashConfig adaptToScaler(
    RimHitFlashConfig config,
    AdaptiveQualityScaler scaler,
  ) {
    final HardwareTier tier = scaler.currentTier;
    final int throttle = scaler.throttleLevel;

    // Eco / Low tiers (<=2GB RAM) or severe thermal throttling:
    // - Reduce rim flash duration to 15ms
    // - Eliminate secondary chromatic aberration
    // - Skip multi-pass blur
    if (tier == HardwareTier.eco || tier == HardwareTier.low || throttle >= 2) {
      return config.copyWith(
        duration: const Duration(milliseconds: 15),
        hitStopDuration: Duration.zero,
        enableChromaticAberration: false,
        chromaticAberrationOffset: 0.0,
        enableMultiPassBlur: false,
        blurPasses: 0,
        dynamicBloomBurst: false,
        edgeBleedWidth: math.min(config.edgeBleedWidth, 1.0),
        bloomMultiplier: math.min(config.bloomMultiplier, 1.5),
      );
    }

    // Ultra tier: full 30-50ms hit stop rim flash with chromatic fringe and dynamic bloom burst
    if (tier == HardwareTier.ultra && throttle == 0) {
      return config.copyWith(
        duration: const Duration(milliseconds: 120),
        hitStopDuration: const Duration(milliseconds: 40), // 30-50ms hit stop
        enableChromaticAberration: true,
        chromaticAberrationOffset: 2.5,
        enableMultiPassBlur: true,
        blurPasses: 2,
        dynamicBloomBurst: true,
        bloomMultiplier: 3.5,
      );
    }

    // High tier
    if (tier == HardwareTier.high && throttle < 2) {
      return config.copyWith(
        duration: const Duration(milliseconds: 90),
        hitStopDuration: const Duration(milliseconds: 25),
        enableChromaticAberration: true,
        chromaticAberrationOffset: 1.5,
        enableMultiPassBlur: true,
        blurPasses: 1,
        dynamicBloomBurst: false,
      );
    }

    // Mid tier (standard baseline)
    return config.copyWith(
      duration: const Duration(milliseconds: 60),
      hitStopDuration: Duration.zero,
      enableChromaticAberration: false,
      chromaticAberrationOffset: 0.0,
      enableMultiPassBlur: false,
      blurPasses: 0,
      dynamicBloomBurst: false,
    );
  }

  RimHitFlashConfig copyWith({
    Duration? duration,
    ui.Color? tint,
    double? rimPower,
    double? rimIntensity,
    double? innerFlash,
    double? edgeBleedWidth,
    double? edgeBleedIntensity,
    double? bloomMultiplier,
    RimFlashNormalMode? normalMode,
    double? decayLambda,
    Duration? hitStopDuration,
    bool? enableChromaticAberration,
    double? chromaticAberrationOffset,
    bool? enableMultiPassBlur,
    int? blurPasses,
    bool? dynamicBloomBurst,
  }) {
    return RimHitFlashConfig(
      duration: duration ?? this.duration,
      tint: tint ?? this.tint,
      rimPower: rimPower ?? this.rimPower,
      rimIntensity: rimIntensity ?? this.rimIntensity,
      innerFlash: innerFlash ?? this.innerFlash,
      edgeBleedWidth: edgeBleedWidth ?? this.edgeBleedWidth,
      edgeBleedIntensity: edgeBleedIntensity ?? this.edgeBleedIntensity,
      bloomMultiplier: bloomMultiplier ?? this.bloomMultiplier,
      normalMode: normalMode ?? this.normalMode,
      decayLambda: decayLambda ?? this.decayLambda,
      hitStopDuration: hitStopDuration ?? this.hitStopDuration,
      enableChromaticAberration:
          enableChromaticAberration ?? this.enableChromaticAberration,
      chromaticAberrationOffset:
          chromaticAberrationOffset ?? this.chromaticAberrationOffset,
      enableMultiPassBlur: enableMultiPassBlur ?? this.enableMultiPassBlur,
      blurPasses: blurPasses ?? this.blurPasses,
      dynamicBloomBurst: dynamicBloomBurst ?? this.dynamicBloomBurst,
    );
  }
}

/// Analytical mathematical envelope evaluator for hit flash VFX.
///
/// Contains pure mathematical implementations of Fresnel rim falloff,
/// exponential decay envelopes, color transformations, and emissive calculations
/// matching the GLSL fragment shader (`shaders/vfx/rim_hit_flash.frag`).
class RimHitFlashEnvelope {
  RimHitFlashEnvelope._();

  /// Converts an sRGB Color channel to linear RGB space.
  static double srgbToLinearChannel(double c) {
    if (c <= 0.04045) {
      return c / 12.92;
    } else {
      return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }
  }

  /// Converts a [ui.Color] to linear RGB components `(r, g, b)`.
  /// Uses pre-warmed color LUT for sub-millisecond combat performance.
  static (double r, double g, double b) colorToLinearRgb(ui.Color color) {
    return RimHitFlashPreloader.getLinearRgb(color);
  }

  /// Converts linear RGB components back to an sRGB [ui.Color].
  static ui.Color linearRgbToColor(double r, double g, double b, [double a = 1.0]) {
    double toSrgb(double c) {
      final double clamped = c.clamp(0.0, 1.0);
      if (clamped <= 0.0031308) {
        return clamped * 12.92;
      } else {
        return 1.055 * math.pow(clamped, 1.0 / 2.4) - 0.055;
      }
    }

    return ui.Color.fromARGB(
      (a.clamp(0.0, 1.0) * 255.0).round(),
      (toSrgb(r) * 255.0).round(),
      (toSrgb(g) * 255.0).round(),
      (toSrgb(b) * 255.0).round(),
    );
  }

  /// Evaluates the instantaneous onset and exponential decay envelope at [elapsedMs].
  ///
  /// - At `elapsedMs <= 0.0`, returns `1.0` (instant onset on hit).
  /// - During hit stop (`elapsedMs <= hitStopMs`), holds peak `1.0`.
  /// - For `elapsedMs > hitStopMs`, decays as `exp(-lambda * (t_decay / duration_decay))`.
  /// - For `elapsedMs >= totalDurationMs`, returns `0.0`.
  static double evaluateDecay({
    required double elapsedMs,
    required double totalDurationMs,
    double lambda = 4.60517,
    double hitStopMs = 0.0,
  }) {
    if (elapsedMs <= 0.0) {
      return 1.0;
    }
    if (totalDurationMs <= 0.0 || elapsedMs >= totalDurationMs) {
      return 0.0;
    }

    // Hit-stop window: hold maximum peak intensity
    if (hitStopMs > 0.0 && elapsedMs <= hitStopMs) {
      return 1.0;
    }

    final double effectiveElapsed = hitStopMs > 0.0 ? (elapsedMs - hitStopMs) : elapsedMs;
    final double effectiveDuration = hitStopMs > 0.0 ? (totalDurationMs - hitStopMs) : totalDurationMs;

    if (effectiveDuration <= 0.0) {
      return 0.0;
    }

    final double progress = (effectiveElapsed / effectiveDuration).clamp(0.0, 1.0);
    return math.exp(-lambda * progress);
  }

  /// Computes view-angle dot normal Fresnel rim factor with exponential falloff.
  ///
  /// - [nDotV]: Dot product between surface normal and view ray (clamped to [0.0, 1.0]).
  /// - [rimPower]: Exponential sharpness exponent (default 3.5).
  /// - [rimIntensity]: Multiplier for the rim term.
  static double computeFresnel({
    required double nDotV,
    required double rimPower,
    double rimIntensity = 1.0,
  }) {
    final double clampedNdotV = nDotV.clamp(0.0, 1.0);
    final double safePower = math.max(rimPower, 0.01);
    final double grazingFactor = 1.0 - clampedNdotV;
    return math.pow(grazingFactor, safePower).toDouble() * rimIntensity;
  }

  /// Computes the complete analytical emissive highlight RGB contribution matching GLSL.
  static (double r, double g, double b) computeEmissiveHighlight({
    required double nDotV,
    required ui.Color tint,
    required double intensity,
    double rimPower = 3.5,
    double rimIntensity = 2.0,
    double innerFlash = 0.4,
    double edgeBleed = 0.0,
    double bloomMultiplier = 2.5,
    double baseAlpha = 1.0,
  }) {
    final double fresnel = computeFresnel(
      nDotV: nDotV,
      rimPower: rimPower,
      rimIntensity: rimIntensity,
    );

    final double inner = baseAlpha * innerFlash;
    final double highlightFactor = (fresnel * baseAlpha + edgeBleed + inner) * intensity;
    final double totalMultiplier = highlightFactor * bloomMultiplier;

    final (double tr, double tg, double tb) = colorToLinearRgb(tint);
    return (
      tr * totalMultiplier,
      tg * totalMultiplier,
      tb * totalMultiplier,
    );
  }
}

/// State controller managing damage hit flash events and shader uniform generation.
/// Directly wired to [AdaptiveQualityScaler] for tier-based runtime scaling.
class RimHitFlashController extends ChangeNotifier {
  RimHitFlashController({
    RimHitFlashConfig? defaultConfig,
    AdaptiveQualityScaler? scaler,
  })  : _rawConfig = defaultConfig ?? const RimHitFlashConfig(),
        _scaler = scaler {
    _applyScaler();
    _scaler?.addListener(_onScalerChanged);
  }

  AdaptiveQualityScaler? _scaler;

  /// Active [AdaptiveQualityScaler] instance if wired.
  AdaptiveQualityScaler? get scaler => _scaler;

  /// Wire or switch [AdaptiveQualityScaler] at runtime.
  set scaler(AdaptiveQualityScaler? newScaler) {
    if (_scaler == newScaler) return;
    _scaler?.removeListener(_onScalerChanged);
    _scaler = newScaler;
    _scaler?.addListener(_onScalerChanged);
    _applyScaler();
  }

  RimHitFlashConfig _rawConfig;
  RimHitFlashConfig _config = const RimHitFlashConfig();

  /// Currently active resolved configuration (adapted to current hardware tier).
  RimHitFlashConfig get config => _config;

  bool _isFlashing = false;
  bool get isFlashing => _isFlashing;

  double _elapsedTimeMs = 0.0;
  double get elapsedTimeMs => _elapsedTimeMs;

  double _currentIntensity = 0.0;
  double get currentIntensity => _currentIntensity;

  double _intensityMultiplier = 1.0;

  void _onScalerChanged() {
    _applyScaler();
  }

  void _applyScaler({bool notify = true}) {
    if (_scaler != null) {
      _config = RimHitFlashConfig.adaptToScaler(_rawConfig, _scaler!);
    } else {
      _config = _rawConfig;
    }
    if (notify) {
      notifyListeners();
    }
  }

  /// Trigger an instantaneous hit flash.
  ///
  /// If already flashing, instantly resets elapsed time to 0 and reapplies
  /// parameters for high-tempo combat combo responsiveness.
  void triggerHit({
    RimHitFlashConfig? config,
    ui.Color? tint,
    double intensityMultiplier = 1.0,
    Duration? duration,
    Duration? hitStopDuration,
    AdaptiveQualityScaler? scalerOverride,
  }) {
    if (scalerOverride != null && scalerOverride != _scaler) {
      _scaler?.removeListener(_onScalerChanged);
      _scaler = scalerOverride;
      _scaler?.addListener(_onScalerChanged);
    }

    if (config != null) {
      _rawConfig = config;
    }
    if (tint != null || duration != null || hitStopDuration != null) {
      _rawConfig = _rawConfig.copyWith(
        tint: tint,
        duration: duration,
        hitStopDuration: hitStopDuration,
      );
    }

    _applyScaler(notify: false);

    _intensityMultiplier = intensityMultiplier;
    _elapsedTimeMs = 0.0;
    _isFlashing = true;
    _currentIntensity = 1.0 * _intensityMultiplier;

    notifyListeners();
  }

  /// Advance time by [dtSeconds] and update the exponential decay envelope.
  void update(double dtSeconds) {
    if (!_isFlashing) return;

    _elapsedTimeMs += dtSeconds * 1000.0;
    final double totalDurationMs = _config.duration.inMicroseconds / 1000.0;
    final double hitStopMs = _config.hitStopDuration.inMicroseconds / 1000.0;

    if (_elapsedTimeMs >= totalDurationMs) {
      _isFlashing = false;
      _currentIntensity = 0.0;
      _elapsedTimeMs = totalDurationMs;
    } else {
      final double decay = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: _elapsedTimeMs,
        totalDurationMs: totalDurationMs,
        lambda: _config.decayLambda,
        hitStopMs: hitStopMs,
      );
      _currentIntensity = decay * _intensityMultiplier;
    }

    notifyListeners();
  }

  /// Immediately resets the flash state.
  void reset() {
    _isFlashing = false;
    _elapsedTimeMs = 0.0;
    _currentIntensity = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _scaler?.removeListener(_onScalerChanged);
    super.dispose();
  }

  /// Packs uniform floats for `shaders/vfx/rim_hit_flash.frag` in exact GLSL layout order:
  ///
  /// 0..1:   uResolution (vec2)
  /// 2:      uIntensity (float)
  /// 3..5:   uTintColor (vec3, linear RGB)
  /// 6:      uRimPower (float)
  /// 7:      uRimIntensity (float)
  /// 8:      uInnerFlash (float)
  /// 9:      uEdgeBleedWidth (float)
  /// 10:     uEdgeBleedIntensity (float)
  /// 11:     uBloomMultiplier (float)
  /// 12:     uNormalMode (float)
  ///
  /// Total: 13 float values.
  List<double> buildUniformList(ui.Size size) {
    final (double tr, double tg, double tb) =
        RimHitFlashEnvelope.colorToLinearRgb(_config.tint);

    return <double>[
      size.width,
      size.height,
      _currentIntensity,
      tr,
      tg,
      tb,
      _config.rimPower,
      _config.rimIntensity,
      _config.innerFlash,
      _config.edgeBleedWidth,
      _config.edgeBleedIntensity,
      _config.bloomMultiplier,
      _config.normalMode.shaderValue,
    ];
  }

  /// Returns a [Float32List] buffer formatted for [ui.FragmentShader.setFloat].
  Float32List toUniformFloat32List(ui.Size size) {
    final List<double> uniforms = buildUniformList(size);
    final Float32List buffer = Float32List(uniforms.length);
    for (int i = 0; i < uniforms.length; i++) {
      buffer[i] = uniforms[i];
    }
    return buffer;
  }
}

/// Custom painter rendering the rim hit flash effect.
///
/// Uses [ui.FragmentShader] when available, or provides a software blend fallback
/// for test environments or non-GPU pipelines.
///
/// Fully supports Ultra-tier chromatic fringe and dynamic bloom burst,
/// and skips multi-pass blur and chromatic aberration on Eco/Low tiers for zero-jank performance.
class RimHitFlashPainter extends CustomPainter {
  RimHitFlashPainter({
    required this.controller,
    this.shader,
    this.targetImage,
    this.normalMapImage,
  }) : super(repaint: controller);

  final RimHitFlashController controller;
  final ui.FragmentShader? shader;
  final ui.Image? targetImage;
  final ui.Image? normalMapImage;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (!controller.isFlashing || controller.currentIntensity <= 0.001) {
      return;
    }

    final ui.FragmentShader? activeShader = shader;
    if (activeShader != null && targetImage != null) {
      final List<double> uniforms = controller.buildUniformList(size);
      for (int i = 0; i < uniforms.length; i++) {
        activeShader.setFloat(i, uniforms[i]);
      }
      activeShader.setImageSampler(0, targetImage!);
      activeShader.setImageSampler(1, normalMapImage ?? targetImage!);

      final ui.Paint paint = ui.Paint()..shader = activeShader;
      canvas.drawRect(ui.Offset.zero & size, paint);

      // Ultra tier enhancement: Chromatic fringe (secondary aberration)
      // Strictly eliminated on Eco / Low tiers (<=2GB RAM)
      if (controller.config.enableChromaticAberration &&
          controller.config.chromaticAberrationOffset > 0.0) {
        final double offset = controller.config.chromaticAberrationOffset *
            controller.currentIntensity;
        final ui.Paint fringePaint = ui.Paint()
          ..blendMode = ui.BlendMode.screen
          ..color = controller.config.tint.withOpacity(
            (0.35 * controller.currentIntensity).clamp(0.0, 1.0),
          );
        canvas.save();
        canvas.translate(offset, 0);
        canvas.drawRect(ui.Offset.zero & size, fringePaint);
        canvas.restore();
      }

      // Ultra tier enhancement: Multi-pass blur for dynamic bloom burst
      // Strictly skipped on Eco / Low tiers (<=2GB RAM)
      if (controller.config.enableMultiPassBlur &&
          controller.config.blurPasses > 0 &&
          controller.config.dynamicBloomBurst) {
        for (int p = 1; p <= controller.config.blurPasses; p++) {
          final double blurSigma = p * 4.0 * controller.currentIntensity;
          final ui.Paint blurPaint = ui.Paint()
            ..blendMode = ui.BlendMode.plus
            ..color = controller.config.tint.withOpacity(
              (0.20 * controller.currentIntensity / p).clamp(0.0, 1.0),
            )
            ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma);
          canvas.drawRect(ui.Offset.zero & size, blurPaint);
        }
      }
    } else {
      // Software fallback for headless/test environments or direct widget overlays
      final (double tr, double tg, double tb) =
          RimHitFlashEnvelope.colorToLinearRgb(controller.config.tint);
      final double effectiveAlpha = (controller.currentIntensity * 0.85).clamp(0.0, 1.0);
      final ui.Color fallbackColor = ui.Color.fromRGBO(
        (tr * 255).round().clamp(0, 255),
        (tg * 255).round().clamp(0, 255),
        (tb * 255).round().clamp(0, 255),
        effectiveAlpha,
      );

      final ui.Paint fallbackPaint = ui.Paint()
        ..color = fallbackColor
        ..blendMode = ui.BlendMode.screen;

      canvas.drawRect(ui.Offset.zero & size, fallbackPaint);

      // Software chromatic fringe on Ultra tier
      if (controller.config.enableChromaticAberration &&
          controller.config.chromaticAberrationOffset > 0.0) {
        final double offset = controller.config.chromaticAberrationOffset;
        final ui.Paint redFringe = ui.Paint()
          ..color = const ui.Color(0xFFFF0000).withOpacity(
            (effectiveAlpha * 0.35).clamp(0.0, 1.0),
          )
          ..blendMode = ui.BlendMode.screen;
        canvas.save();
        canvas.translate(offset, 0);
        canvas.drawRect(ui.Offset.zero & size, redFringe);
        canvas.restore();

        final ui.Paint blueFringe = ui.Paint()
          ..color = const ui.Color(0xFF0000FF).withOpacity(
            (effectiveAlpha * 0.35).clamp(0.0, 1.0),
          )
          ..blendMode = ui.BlendMode.screen;
        canvas.save();
        canvas.translate(-offset, 0);
        canvas.drawRect(ui.Offset.zero & size, blueFringe);
        canvas.restore();
      }

      // Software multi-pass blur on Ultra tier
      if (controller.config.enableMultiPassBlur &&
          controller.config.blurPasses > 0 &&
          controller.config.dynamicBloomBurst) {
        for (int p = 1; p <= controller.config.blurPasses; p++) {
          final ui.Paint bloomBurstPaint = ui.Paint()
            ..color = fallbackColor.withOpacity(
              (effectiveAlpha * 0.3 / p).clamp(0.0, 1.0),
            )
            ..blendMode = ui.BlendMode.plus
            ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, p * 6.0);
          canvas.drawRect(ui.Offset.zero & size, bloomBurstPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant RimHitFlashPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.shader != shader ||
        oldDelegate.targetImage != targetImage ||
        oldDelegate.normalMapImage != normalMapImage;
  }
}

/// Production widget wrapping any target (sprite, character, or billboard)
/// with the rim-light hit flash and emissive silhouette highlight effect.
///
/// Automatically warms shader pipelines via [ZeroJankPreloader] (<2ms budget)
/// and connects to [AdaptiveQualityScaler] for dynamic tier-based quality adjustments.
class RimHitFlashWidget extends StatefulWidget {
  const RimHitFlashWidget({
    super.key,
    required this.child,
    required this.controller,
    this.targetImage,
    this.normalMapImage,
    this.shaderAssetPath = RimHitFlashPreloader.defaultShaderPath,
    this.scaler,
  });

  final Widget child;
  final RimHitFlashController controller;
  final ui.Image? targetImage;
  final ui.Image? normalMapImage;
  final String shaderAssetPath;
  final AdaptiveQualityScaler? scaler;

  @override
  State<RimHitFlashWidget> createState() => _RimHitFlashWidgetState();
}

class _RimHitFlashWidgetState extends State<RimHitFlashWidget> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    if (widget.scaler != null && widget.controller.scaler == null) {
      widget.controller.scaler = widget.scaler;
    }
    _loadShader();
  }

  @override
  void didUpdateWidget(covariant RimHitFlashWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scaler != oldWidget.scaler && widget.scaler != null) {
      widget.controller.scaler = widget.scaler;
    }
    if (widget.shaderAssetPath != oldWidget.shaderAssetPath) {
      _loadShader();
    }
  }

  Future<void> _loadShader() async {
    // 1. Instant cache hit from ZeroJankPreloader or preloader cache
    final ui.FragmentProgram? prewarmed =
        RimHitFlashPreloader.cachedProgram ??
        (ZeroJankPreloader.instance.getCached(RimHitFlashPreloader.shaderTaskId, CacheTarget.vram)
            as ui.FragmentProgram?);

    if (prewarmed != null) {
      if (mounted) {
        setState(() {
          _shader = prewarmed.fragmentShader();
        });
      }
      return;
    }

    // 2. Progressive pre-warm via ZeroJankPreloader (<2ms budget)
    try {
      final ui.FragmentProgram? program = await RimHitFlashPreloader.warmUp(
        shaderAssetPath: widget.shaderAssetPath,
      );
      if (mounted && program != null) {
        setState(() {
          _shader = program.fragmentShader();
        });
      }
    } catch (_) {
      // In headless test environments or asset-less mock environments,
      // fallback software painting is seamlessly employed.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          foregroundPainter: RimHitFlashPainter(
            controller: widget.controller,
            shader: _shader,
            targetImage: widget.targetImage,
            normalMapImage: widget.normalMapImage,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
