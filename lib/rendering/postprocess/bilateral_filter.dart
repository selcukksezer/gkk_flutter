import 'dart:math' as math;
import 'dart:typed_data' show Float32List;
import 'dart:ui' as ui;

/// Configuration parameters for Bilateral Depth-Aware Smoothing Filter.
/// Synchronized with `shaders/postprocess/ssao_bilateral_blur.frag`.
class BilateralFilterParams {
  const BilateralFilterParams({
    this.spatialSigma = 2.5,
    this.depthThreshold = 0.08,
    this.kernelRadius = 4,
  });

  /// Standard deviation of the spatial Gaussian weight (pixel space).
  /// Matches GLSL uniform `float uSpatialSigma` (Float index 4, default 2.5).
  final double spatialSigma;

  /// Depth discontinuity threshold (stops blur from bleeding across depth edges).
  /// Matches GLSL uniform `float uDepthThreshold` (Float index 5, default 0.08).
  final double depthThreshold;

  /// Tap radius on either side of the center pixel (kernel size = 2 * radius + 1).
  /// Matches GLSL `const int KERNEL_RADIUS = 4` (total 9 taps: -4..+4).
  final int kernelRadius;

  BilateralFilterParams copyWith({
    double? spatialSigma,
    double? depthThreshold,
    int? kernelRadius,
  }) {
    return BilateralFilterParams(
      spatialSigma: spatialSigma ?? this.spatialSigma,
      depthThreshold: depthThreshold ?? this.depthThreshold,
      kernelRadius: kernelRadius ?? this.kernelRadius,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'spatialSigma': spatialSigma,
      'depthThreshold': depthThreshold,
      'kernelRadius': kernelRadius,
    };
  }

  factory BilateralFilterParams.fromJson(Map<String, dynamic> json) {
    return BilateralFilterParams(
      spatialSigma: (json['spatialSigma'] as num?)?.toDouble() ?? 2.5,
      depthThreshold: (json['depthThreshold'] as num?)?.toDouble() ?? 0.08,
      kernelRadius: (json['kernelRadius'] as num?)?.toInt() ?? 4,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BilateralFilterParams &&
          runtimeType == other.runtimeType &&
          (spatialSigma - other.spatialSigma).abs() < 1e-5 &&
          (depthThreshold - other.depthThreshold).abs() < 1e-5 &&
          kernelRadius == other.kernelRadius;

  @override
  int get hashCode => Object.hash(
        (spatialSigma * 1000).round(),
        (depthThreshold * 1000).round(),
        kernelRadius,
      );

  @override
  String toString() =>
      'BilateralFilterParams(spatialSigma: $spatialSigma, depthThreshold: $depthThreshold, kernelRadius: $kernelRadius)';
}

/// Bilateral Depth-Aware Cross-Filter implementation.
/// Eliminates SSAO high-frequency noise while preserving object boundaries and silhouette edges.
/// Provides exact mathematical parity, uniform buffer packing, and shader bindings for
/// `shaders/postprocess/ssao_bilateral_blur.frag`.
class BilateralFilter {
  const BilateralFilter._();

  // ---------------------------------------------------------------------------
  // GLSL Uniform Layout Specification for shaders/postprocess/ssao_bilateral_blur.frag
  // ---------------------------------------------------------------------------
  // Float Uniform Indices (6 floats total, 0..5):
  // 0..1: uResolution (vec2)      - Viewport resolution in pixels
  // 2..3: uBlurDirection (vec2)   - Direction vector (1,0 horizontal or 0,1 vertical)
  // 4:    uSpatialSigma (float)   - Spatial Gaussian sigma (default 2.5)
  // 5:    uDepthThreshold (float) - Depth edge sensitivity (default 0.08)
  static const int uniformResolutionX = 0;
  static const int uniformResolutionY = 1;
  static const int uniformBlurDirectionX = 2;
  static const int uniformBlurDirectionY = 3;
  static const int uniformSpatialSigma = 4;
  static const int uniformDepthThreshold = 5;
  static const int totalUniformFloats = 6;

  // Sampler Indices (2 samplers total, 0..1):
  // Slot 0: uAoTexture    - Raw SSAO in R, Linear Depth in G
  // Slot 1: uDepthTexture - Fallback Linear Depth Buffer
  static const int samplerAoTexture = 0;
  static const int samplerDepthTexture = 1;
  static const int totalSamplers = 2;

  // Default shader constants
  static const double defaultSpatialSigma = 2.5;
  static const double defaultDepthThreshold = 0.08;
  static const int defaultKernelRadius = 4;
  static const ui.Offset horizontalDirection = ui.Offset(1.0, 0.0);
  static const ui.Offset verticalDirection = ui.Offset(0.0, 1.0);

  /// Computes spatial Gaussian weight: exp(-d^2 / (2 * sigma_s^2)).
  /// Fallback matches GLSL: `(uSpatialSigma > 0.0) ? uSpatialSigma : 2.5`.
  static double computeSpatialWeight(double distPixels, double sigma) {
    final double safeSigma = (sigma > 0.0) ? sigma : defaultSpatialSigma;
    return math.exp(-(distPixels * distPixels) / (2.0 * safeSigma * safeSigma));
  }

  /// Computes depth similarity weight: exp(-|deltaZ|^2 / (2 * sigma_d^2)).
  /// When depth difference is large, weight drops to near 0, preserving the edge.
  /// Fallback matches GLSL: `(uDepthThreshold > 0.0) ? uDepthThreshold : 0.08`.
  static double computeDepthWeight(double depthDiff, double threshold) {
    final double safeThreshold = (threshold > 0.0) ? threshold : defaultDepthThreshold;
    final double d = depthDiff.abs();
    return math.exp(-(d * d) / (2.0 * safeThreshold * safeThreshold));
  }

  /// Computes normalized UV step offsets for a given blur direction, texel size, and kernel radius.
  /// Matches GLSL step calculation: `stepVec * offset` where `stepVec = uBlurDirection / safeRes`.
  static List<ui.Offset> computeStepOffsets({
    required ui.Offset blurDirection,
    required ui.Size viewportSize,
    int kernelRadius = defaultKernelRadius,
  }) {
    final double safeWidth = math.max(viewportSize.width, 1.0);
    final double safeHeight = math.max(viewportSize.height, 1.0);
    final double texelX = 1.0 / safeWidth;
    final double texelY = 1.0 / safeHeight;

    final List<ui.Offset> offsets = <ui.Offset>[];
    for (int i = -kernelRadius; i <= kernelRadius; ++i) {
      final double step = i.toDouble();
      offsets.add(ui.Offset(
        blurDirection.dx * texelX * step,
        blurDirection.dy * texelY * step,
      ));
    }
    return offsets;
  }

  /// Evaluates 1D bilateral filter along an axis (horizontal or vertical).
  /// Clamps final result to [0.0, 1.0] matching GLSL line 79.
  static double filter1D({
    required int centerCoord,
    required double centerAo,
    required double centerDepth,
    required double Function(int coord) aoSampler,
    required double Function(int coord) depthSampler,
    BilateralFilterParams params = const BilateralFilterParams(),
  }) {
    final int radius = params.kernelRadius;
    double weightedAoSum = 0.0;
    double totalWeight = 0.0;

    for (int i = -radius; i <= radius; ++i) {
      final int tapCoord = centerCoord + i;
      final double tapAo = aoSampler(tapCoord);
      final double tapDepth = depthSampler(tapCoord);

      final double wSpatial =
          computeSpatialWeight(i.toDouble().abs(), params.spatialSigma);
      final double depthDiff = tapDepth - centerDepth;
      final double wDepth = computeDepthWeight(depthDiff, params.depthThreshold);

      final double weight = wSpatial * wDepth;
      weightedAoSum += tapAo * weight;
      totalWeight += weight;
    }

    if (totalWeight < 0.00001) return centerAo.clamp(0.0, 1.0);
    return (weightedAoSum / totalWeight).clamp(0.0, 1.0);
  }

  /// Evaluates 2D bilateral filter over a (2R+1) x (2R+1) kernel.
  /// Clamps final result to [0.0, 1.0] matching GLSL line 79.
  static double filter2D({
    required int centerX,
    required int centerY,
    required double centerAo,
    required double centerDepth,
    required double Function(int x, int y) aoSampler,
    required double Function(int x, int y) depthSampler,
    BilateralFilterParams params = const BilateralFilterParams(),
  }) {
    final int radius = params.kernelRadius;
    double weightedAoSum = 0.0;
    double totalWeight = 0.0;

    for (int dy = -radius; dy <= radius; ++dy) {
      for (int dx = -radius; dx <= radius; ++dx) {
        final int tapX = centerX + dx;
        final int tapY = centerY + dy;
        final double tapAo = aoSampler(tapX, tapY);
        final double tapDepth = depthSampler(tapX, tapY);

        final double dist = math.sqrt((dx * dx + dy * dy).toDouble());
        final double wSpatial = computeSpatialWeight(dist, params.spatialSigma);
        final double depthDiff = tapDepth - centerDepth;
        final double wDepth = computeDepthWeight(depthDiff, params.depthThreshold);

        final double weight = wSpatial * wDepth;
        weightedAoSum += tapAo * weight;
        totalWeight += weight;
      }
    }

    if (totalWeight < 0.00001) return centerAo.clamp(0.0, 1.0);
    return (weightedAoSum / totalWeight).clamp(0.0, 1.0);
  }

  /// Builds a [List<double>] containing exactly 6 floats in GLSL uniform declaration order:
  /// `[uResolution.x, uResolution.y, uBlurDirection.x, uBlurDirection.y, uSpatialSigma, uDepthThreshold]`.
  static List<double> buildUniformList({
    required ui.Size viewportSize,
    required ui.Offset blurDirection,
    BilateralFilterParams params = const BilateralFilterParams(),
  }) {
    return <double>[
      viewportSize.width,
      viewportSize.height,
      blurDirection.dx,
      blurDirection.dy,
      params.spatialSigma,
      params.depthThreshold,
    ];
  }

  /// Packs uniforms into a [Float32List] buffer for high-performance GPU upload.
  static Float32List packToFloat32List({
    required ui.Size viewportSize,
    required ui.Offset blurDirection,
    BilateralFilterParams params = const BilateralFilterParams(),
  }) {
    final List<double> uniforms = buildUniformList(
      viewportSize: viewportSize,
      blurDirection: blurDirection,
      params: params,
    );
    final Float32List buffer = Float32List(totalUniformFloats);
    for (int i = 0; i < totalUniformFloats; i++) {
      buffer[i] = uniforms[i];
    }
    return buffer;
  }

  /// Binds all 6 float uniforms and samplers to the compiled [ui.FragmentShader].
  /// Matches `ssao_bilateral_blur.frag` uniform layout:
  /// - Floats 0..1: uResolution (vec2)
  /// - Floats 2..3: uBlurDirection (vec2)
  /// - Float 4: uSpatialSigma (float)
  /// - Float 5: uDepthThreshold (float)
  /// - Sampler 0: uAoTexture (sampler2D)
  /// - Sampler 1: uDepthTexture (sampler2D)
  static void bindToShader(
    ui.FragmentShader shader, {
    required ui.Size viewportSize,
    required ui.Offset blurDirection,
    BilateralFilterParams params = const BilateralFilterParams(),
    ui.Image? aoTexture,
    ui.Image? depthTexture,
  }) {
    final List<double> uniforms = buildUniformList(
      viewportSize: viewportSize,
      blurDirection: blurDirection,
      params: params,
    );

    for (int i = 0; i < uniforms.length; i++) {
      shader.setFloat(i, uniforms[i]);
    }

    if (aoTexture != null) {
      shader.setImageSampler(samplerAoTexture, aoTexture);
    }
    if (depthTexture != null) {
      shader.setImageSampler(samplerDepthTexture, depthTexture);
    }
  }
}

