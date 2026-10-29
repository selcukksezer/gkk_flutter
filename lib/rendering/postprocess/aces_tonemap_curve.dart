import 'dart:math' as math;
import 'dart:ui' show Color;

/// Supported ACES Tonemapping curve approximations.
enum AcesFitType {
  /// Stephen Hill & Stephen Black fitted model with sRGB <-> ACEScg matrices.
  /// Highest visual accuracy matching Academy Color Encoding System standard.
  stephenHill,

  /// Krzysztof Narkowicz fast curve fit.
  /// Highly optimized analytical approximation for mobile and high-framerate.
  narkowicz,
}

/// Transfer function for linear to display gamma correction.
enum GammaMode {
  /// IEC 61966-2-1 standard piecewise transfer function.
  accurateSrgb,

  /// Fast power-law approximation: C^(1 / 2.2).
  gamma22,
}

/// Exposure calculation mode.
enum ExposureMode {
  /// Direct linear factor (e.g. 1.0, 1.5).
  linearFactor,

  /// Photographic exposure value stops (multiplier = 2^EV).
  evStops,
}

/// Configuration parameters for ACES Filmic Tonemapping & Gamma Correction.
class AcesTonemapParams {
  const AcesTonemapParams({
    this.exposure = 0.0,
    this.exposureMode = ExposureMode.evStops,
    this.fitType = AcesFitType.stephenHill,
    this.gammaMode = GammaMode.accurateSrgb,
    this.preGain = 1.0,
    this.whitePoint = 0.0,
  });

  /// Photographic exposure stops (when evStops) or linear multiplier (when linearFactor).
  final double exposure;

  /// Mode of exposure calculation.
  final ExposureMode exposureMode;

  /// Selected ACES curve algorithm.
  final AcesFitType fitType;

  /// Selected gamma transfer function.
  final GammaMode gammaMode;

  /// Linear pre-tonemap gain multiplier.
  final double preGain;

  /// Optional luminance ceiling / clamp (0.0 means unconstrained HDR headroom).
  final double whitePoint;

  /// Computes the effective linear multiplier from [exposure] and [exposureMode].
  double get effectiveExposureMultiplier {
    switch (exposureMode) {
      case ExposureMode.evStops:
        return math.pow(2.0, exposure).toDouble();
      case ExposureMode.linearFactor:
        return (exposure > 0.0) ? exposure : 1.0;
    }
  }

  /// Effective pre-gain multiplier (defaulting to 1.0 if <= 0.0, matching GLSL).
  double get effectivePreGain => (preGain > 0.0) ? preGain : 1.0;

  /// Packs parameters into 8 uniform floats matching `aces_tonemap.frag` layout:
  /// [0..1] resolution (width, height), [2] exposure, [3] exposureMode,
  /// [4] fitType, [5] gammaMode, [6] preGain, [7] whitePoint.
  List<double> toUniformList({required double width, required double height}) {
    return <double>[
      width,
      height,
      exposure,
      exposureMode == ExposureMode.evStops ? 1.0 : 0.0,
      fitType == AcesFitType.narkowicz ? 1.0 : 0.0,
      gammaMode == GammaMode.gamma22 ? 1.0 : 0.0,
      effectivePreGain,
      whitePoint,
    ];
  }

  AcesTonemapParams copyWith({
    double? exposure,
    ExposureMode? exposureMode,
    AcesFitType? fitType,
    GammaMode? gammaMode,
    double? preGain,
    double? whitePoint,
  }) {
    return AcesTonemapParams(
      exposure: exposure ?? this.exposure,
      exposureMode: exposureMode ?? this.exposureMode,
      fitType: fitType ?? this.fitType,
      gammaMode: gammaMode ?? this.gammaMode,
      preGain: preGain ?? this.preGain,
      whitePoint: whitePoint ?? this.whitePoint,
    );
  }
}

/// Mathematical implementation of ACES Filmic tonemapping curves,
/// matching shaders/postprocess/aces_tonemap.frag for testing and CPU pipelines.
class AcesTonemapCurve {
  const AcesTonemapCurve._();

  // ---------------------------------------------------------------------------
  // GLSL Uniform Layout Constants matching `shaders/postprocess/aces_tonemap.frag`
  // ---------------------------------------------------------------------------
  /// Total uniform float count for aces_tonemap.frag (vec2 resolution + 6 scalar floats = 8 floats).
  static const int uniformFloatCount = 8;

  /// Uniform float indices in the packed Float32Buffer for Impeller/Skia runtime effect.
  static const int uniformResolution = 0; // vec2 (slots 0, 1): physical viewport resolution
  static const int uniformExposure = 2; // float: EV stops or linear factor
  static const int uniformExposureMode = 3; // float: 0.0 = linear factor, 1.0 = EV stops (2^EV)
  static const int uniformFitType = 4; // float: 0.0 = Stephen Hill, 1.0 = Krzysztof Narkowicz
  static const int uniformGammaMode = 5; // float: 0.0 = IEC 61966-2-1 sRGB, 1.0 = Gamma 2.2
  static const int uniformPreGain = 6; // float: pre-tonemap linear multiplier
  static const int uniformWhitePoint = 7; // float: HDR luminance ceiling (0.0 = unconstrained)

  /// Texture sampler unit index for high-dynamic range scene texture.
  static const int samplerSceneTexture = 0;

  // ---------------------------------------------------------------------------
  // Curve Fit Rational Polynomial Coefficients
  // ---------------------------------------------------------------------------
  /// Krzysztof Narkowicz analytical curve fit coefficients:
  /// f(x) = (x * (a * x + b)) / (x * (c * x + d) + e)
  static const double narkowiczA = 2.51;
  static const double narkowiczB = 0.03;
  static const double narkowiczC = 2.43;
  static const double narkowiczD = 0.59;
  static const double narkowiczE = 0.14;

  /// Stephen Hill RRT + ODT rational polynomial fit coefficients:
  /// a = v * (v + a1) + a0
  /// b = v * (b2 * v + b1) + b0
  static const double rrtOdtA1 = 0.0245786;
  static const double rrtOdtA0 = -0.000090537;
  static const double rrtOdtB2 = 0.983729;
  static const double rrtOdtB1 = 0.4329510;
  static const double rrtOdtB0 = 0.238081;

  // ---------------------------------------------------------------------------
  // Stephen Hill ACES Fitted Matrices (column-major in GLSL, row-major in Dart)
  // ---------------------------------------------------------------------------
  // sRGB to ACEScg (AP1) matrix
  // [0.59719, 0.35458, 0.04823]
  // [0.07600, 0.90834, 0.01566]
  // [0.02840, 0.13383, 0.83777]
  static const double _m1_00 = 0.59719, _m1_01 = 0.35458, _m1_02 = 0.04823;
  static const double _m1_10 = 0.07600, _m1_11 = 0.90834, _m1_12 = 0.01566;
  static const double _m1_20 = 0.02840, _m1_21 = 0.13383, _m1_22 = 0.83777;

  // ACEScg to sRGB matrix
  // [ 1.60475, -0.53108, -0.07367]
  // [-0.10208,  1.10813, -0.00605]
  // [-0.00327, -0.07276,  1.07602]
  static const double _m2_00 = 1.60475, _m2_01 = -0.53108, _m2_02 = -0.07367;
  static const double _m2_10 = -0.10208, _m2_11 = 1.10813, _m2_12 = -0.00605;
  static const double _m2_20 = -0.00327, _m2_21 = -0.07276, _m2_22 = 1.07602;

  /// RRT (Reference Rendering Transform) and ODT (Output Device Transform)
  /// rational polynomial curve fit by Stephen Hill.
  static double rrtAndOdtFitChannel(double v) {
    final double a = v * (v + rrtOdtA1) + rrtOdtA0;
    final double b = v * (rrtOdtB2 * v + rrtOdtB1) + rrtOdtB0;
    return a / b;
  }

  /// Evaluates Stephen Hill's ACES curve for RGB channels in linear space.
  static (double, double, double) acesStephenHill(double r, double g, double b) {
    // 1. Transform sRGB to ACEScg AP1
    final double vR = _m1_00 * r + _m1_01 * g + _m1_02 * b;
    final double vG = _m1_10 * r + _m1_11 * g + _m1_12 * b;
    final double vB = _m1_20 * r + _m1_21 * g + _m1_22 * b;

    // 2. Apply RRT + ODT curve fit
    final double rrtR = rrtAndOdtFitChannel(vR);
    final double rrtG = rrtAndOdtFitChannel(vG);
    final double rrtB = rrtAndOdtFitChannel(vB);

    // 3. Transform ACEScg back to sRGB
    final double outR = _m2_00 * rrtR + _m2_01 * rrtG + _m2_02 * rrtB;
    final double outG = _m2_10 * rrtR + _m2_11 * rrtG + _m2_12 * rrtB;
    final double outB = _m2_20 * rrtR + _m2_21 * rrtG + _m2_22 * rrtB;

    return (
      outR.clamp(0.0, 1.0),
      outG.clamp(0.0, 1.0),
      outB.clamp(0.0, 1.0),
    );
  }

  /// Evaluates Krzysztof Narkowicz's ACES curve for single channel.
  static double narkowiczChannel(double x) {
    final double cx = math.max(0.0, x);
    final double val =
        (cx * (narkowiczA * cx + narkowiczB)) /
        (cx * (narkowiczC * cx + narkowiczD) + narkowiczE);
    return val.clamp(0.0, 1.0);
  }

  /// Evaluates Krzysztof Narkowicz's ACES curve for RGB channels.
  static (double, double, double) acesNarkowicz(double r, double g, double b) {
    return (
      narkowiczChannel(r),
      narkowiczChannel(g),
      narkowiczChannel(b),
    );
  }

  /// Converts a single linear channel to sRGB via IEC 61966-2-1 standard.
  static double linearToSrgbChannel(double c) {
    final double clamped = c.clamp(0.0, 1.0);
    if (clamped <= 0.0031308) {
      return clamped * 12.92;
    } else {
      return 1.055 * math.pow(clamped, 1.0 / 2.4) - 0.055;
    }
  }

  /// Converts a single sRGB display channel back to linear scene value.
  static double srgbToLinearChannel(double s) {
    final double clamped = s.clamp(0.0, 1.0);
    if (clamped <= 0.04045) {
      return clamped / 12.92;
    } else {
      return math.pow((clamped + 0.055) / 1.055, 2.4).toDouble();
    }
  }

  /// Converts linear RGB to sRGB using accurate IEC standard.
  static (double, double, double) linearToSrgb(double r, double g, double b) {
    return (
      linearToSrgbChannel(r).clamp(0.0, 1.0),
      linearToSrgbChannel(g).clamp(0.0, 1.0),
      linearToSrgbChannel(b).clamp(0.0, 1.0),
    );
  }

  /// Converts linear RGB to display using simple gamma 2.2 approximation.
  static (double, double, double) linearToGamma22(double r, double g, double b) {
    const double invGamma = 1.0 / 2.2;
    return (
      math.pow(r.clamp(0.0, 1.0), invGamma).toDouble(),
      math.pow(g.clamp(0.0, 1.0), invGamma).toDouble(),
      math.pow(b.clamp(0.0, 1.0), invGamma).toDouble(),
    );
  }

  /// Evaluates the complete ACES pipeline for an input RGB tuple in linear space.
  static (double, double, double) processLinearRgb(
    double r,
    double g,
    double b, {
    AcesTonemapParams params = const AcesTonemapParams(),
  }) {
    // 1. Pre-gain with non-negative clamping matching GLSL:
    //    vec3 linearColor = max(sampleColor.rgb, vec3(0.0));
    //    float preGain = (uPreGain > 0.0) ? uPreGain : 1.0;
    final double preGain = params.effectivePreGain;
    double inR = math.max(0.0, r) * preGain;
    double inG = math.max(0.0, g) * preGain;
    double inB = math.max(0.0, b) * preGain;

    // 2. Exposure adjustment (2^EV or linear factor)
    final double exposureMult = params.effectiveExposureMultiplier;
    inR *= exposureMult;
    inG *= exposureMult;
    inB *= exposureMult;

    // 3. Optional white-point ceiling
    if (params.whitePoint > 0.0) {
      inR = math.min(inR, params.whitePoint);
      inG = math.min(inG, params.whitePoint);
      inB = math.min(inB, params.whitePoint);
    }

    // 4. ACES Curve fit
    final (double tmR, double tmG, double tmB) = switch (params.fitType) {
      AcesFitType.stephenHill => acesStephenHill(inR, inG, inB),
      AcesFitType.narkowicz => acesNarkowicz(inR, inG, inB),
    };

    // 5. Gamma correction
    return switch (params.gammaMode) {
      GammaMode.accurateSrgb => linearToSrgb(tmR, tmG, tmB),
      GammaMode.gamma22 => linearToGamma22(tmR, tmG, tmB),
    };
  }

  /// Applies ACES tonemapping and gamma correction to a Flutter [Color].
  static Color processColor(
    Color linearColor, {
    AcesTonemapParams params = const AcesTonemapParams(),
  }) {
    final double r = linearColor.r;
    final double g = linearColor.g;
    final double b = linearColor.b;

    final (double outR, double outG, double outB) =
        processLinearRgb(r, g, b, params: params);

    return Color.from(
      alpha: linearColor.a,
      red: outR,
      green: outG,
      blue: outB,
    );
  }

  /// Builds uniform float list for `aces_tonemap.frag` (total 8 floats).
  static List<double> buildUniforms({
    required double width,
    required double height,
    AcesTonemapParams params = const AcesTonemapParams(),
  }) {
    return params.toUniformList(width: width, height: height);
  }
}
