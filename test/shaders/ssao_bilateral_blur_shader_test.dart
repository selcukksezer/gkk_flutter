// =============================================================================
// Comprehensive Test Suite: SSAO Bilateral Blur Shader & Dart Wrapper
// 2027 Cinematic AAA Graphics Pipeline - Impeller & RuntimeEffect Compatibility
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/shaders/shader_pipeline.dart';
import 'package:gkk_flutter/core/shaders/shader_registry.dart';
import 'package:gkk_flutter/rendering/postprocess/bilateral_filter.dart';
import 'package:gkk_flutter/rendering/postprocess/postprocess_pipeline.dart';

// -----------------------------------------------------------------------------
// Test Wrapper Abstraction: SsaoBilateralBlurPass & Ping-Pong Pipeline
// -----------------------------------------------------------------------------

/// Direction of the 1D separable bilateral blur pass.
enum BlurPassDirection {
  horizontal,
  vertical,
}

/// Architectural representation of an SSAO Bilateral Blur Pass.
/// Encapsulates parameters, direction normalization, uniform packing,
/// edge-stopping weights, and pass chaining.
class SsaoBilateralBlurPass {
  const SsaoBilateralBlurPass({
    this.blurRadius = 2.5,
    this.depthThreshold = 0.08,
    this.normalThreshold = 0.8,
    this.blurDirection = BlurPassDirection.horizontal,
  });

  /// Spatial Gaussian sigma (spread radius in pixels).
  /// Matches GLSL uniform `float uSpatialSigma` (Float index 4).
  final double blurRadius;

  /// Depth discontinuity sensitivity threshold.
  /// Matches GLSL uniform `float uDepthThreshold` (Float index 5).
  final double depthThreshold;

  /// Surface normal alignment threshold (cosine of max angle between tap normal and center normal).
  /// Rejects taps across sharp geometric creases or dihedral corners.
  final double normalThreshold;

  /// Direction of this 1D blur pass (horizontal or vertical).
  final BlurPassDirection blurDirection;

  /// Returns normalized 2D direction offset vector for this pass.
  ui.Offset get directionVector {
    switch (blurDirection) {
      case BlurPassDirection.horizontal:
        return const ui.Offset(1.0, 0.0);
      case BlurPassDirection.vertical:
        return const ui.Offset(0.0, 1.0);
    }
  }

  /// Whether this pass direction vector is normalized.
  bool get isNormalized {
    final double dist = directionVector.distance;
    return (dist - 1.0).abs() < 1e-6;
  }

  /// Converts this pass configuration into production [BilateralFilterParams].
  BilateralFilterParams toFilterParams({int kernelRadius = 4}) {
    return BilateralFilterParams(
      spatialSigma: blurRadius,
      depthThreshold: depthThreshold,
      kernelRadius: kernelRadius,
    );
  }

  /// Packs uniforms according to the exact 6-float GLSL declaration layout:
  /// `[uResolution.x, uResolution.y, uBlurDirection.x, uBlurDirection.y, uSpatialSigma, uDepthThreshold]`
  Float32List packUniforms(ui.Size viewportSize) {
    return BilateralFilter.packToFloat32List(
      viewportSize: viewportSize,
      blurDirection: directionVector,
      params: toFilterParams(),
    );
  }

  /// Calculates depth-aware, spatial, and normal-aware bilateral weight.
  /// Edge-stopping function: rejects samples across depth silhouettes or surface creases.
  double computeBilateralWeight({
    required double spatialDistance,
    required double depthDelta,
    double normalDot = 1.0,
  }) {
    final double safeRadius = blurRadius > 0.0 ? blurRadius : 2.5;
    final double safeDepth = depthThreshold > 0.0 ? depthThreshold : 0.08;

    // Spatial Gaussian factor: exp(-d_s^2 / (2 * sigma_s^2))
    final double wSpatial =
        math.exp(-(spatialDistance * spatialDistance) / (2.0 * safeRadius * safeRadius));

    // Depth discontinuity factor: exp(-d_z^2 / (2 * sigma_z^2))
    final double wDepth =
        math.exp(-(depthDelta * depthDelta) / (2.0 * safeDepth * safeDepth));

    // Surface normal alignment factor: smooth transition above normalThreshold
    double wNormal = 1.0;
    if (normalThreshold > 0.0 && normalThreshold < 1.0) {
      final double clampedDot = normalDot.clamp(0.0, 1.0);
      wNormal = math.max(0.0, (clampedDot - normalThreshold) / (1.0 - normalThreshold));
    }

    return wSpatial * wDepth * wNormal;
  }
}

/// Simulation handle representing an intermediate offscreen render buffer
/// for multi-pass ping-pong blur execution.
class PingPongBuffer {
  PingPongBuffer({
    required this.id,
    required this.width,
    required this.height,
  });

  final String id;
  final int width;
  final int height;
  bool isBound = false;
  int writeCount = 0;

  void bindAsRenderTarget() {
    isBound = true;
    writeCount++;
  }

  void unbind() {
    isBound = false;
  }
}

/// Orchestrates 2-pass separable bilateral blur chaining with ping-pong buffers.
class SsaoBilateralBlurPingPongPipeline {
  SsaoBilateralBlurPingPongPipeline({
    required this.viewportSize,
    this.blurRadius = 2.5,
    this.depthThreshold = 0.08,
    this.normalThreshold = 0.8,
  })  : bufferA = PingPongBuffer(
          id: 'ping_pong_buffer_a',
          width: math.max(1, viewportSize.width.toInt()),
          height: math.max(1, viewportSize.height.toInt()),
        ),
        bufferB = PingPongBuffer(
          id: 'ping_pong_buffer_b',
          width: math.max(1, viewportSize.width.toInt()),
          height: math.max(1, viewportSize.height.toInt()),
        );

  final ui.Size viewportSize;
  final double blurRadius;
  final double depthThreshold;
  final double normalThreshold;

  final PingPongBuffer bufferA;
  final PingPongBuffer bufferB;

  late final SsaoBilateralBlurPass horizontalPass = SsaoBilateralBlurPass(
    blurRadius: blurRadius,
    depthThreshold: depthThreshold,
    normalThreshold: normalThreshold,
    blurDirection: BlurPassDirection.horizontal,
  );

  late final SsaoBilateralBlurPass verticalPass = SsaoBilateralBlurPass(
    blurRadius: blurRadius,
    depthThreshold: depthThreshold,
    normalThreshold: normalThreshold,
    blurDirection: BlurPassDirection.vertical,
  );

  /// Executes separable ping-pong blur chaining.
  /// Pass 1 (horizontal): reads from bufferA (source AO) -> writes to bufferB
  /// Pass 2 (vertical): reads from bufferB -> writes to bufferA (final filtered AO)
  PingPongBuffer executeSeparableBlur({int iterations = 1}) {
    PingPongBuffer readBuffer = bufferA;
    PingPongBuffer writeBuffer = bufferB;

    for (int i = 0; i < iterations; i++) {
      // 1. Horizontal pass
      writeBuffer.bindAsRenderTarget();
      writeBuffer.unbind();
      // Swap buffers
      final PingPongBuffer temp1 = readBuffer;
      readBuffer = writeBuffer;
      writeBuffer = temp1;

      // 2. Vertical pass
      writeBuffer.bindAsRenderTarget();
      writeBuffer.unbind();
      // Swap buffers
      final PingPongBuffer temp2 = readBuffer;
      readBuffer = writeBuffer;
      writeBuffer = temp2;
    }

    return readBuffer;
  }
}

// -----------------------------------------------------------------------------
// MAIN TEST SUITE
// -----------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SSAO Bilateral Blur GLSL Fragment Shader Verification', () {
    late File shaderFile;
    late String shaderCode;

    setUpAll(() {
      shaderFile = File('shaders/postprocess/ssao_bilateral_blur.frag');
      expect(shaderFile.existsSync(), isTrue,
          reason: 'ssao_bilateral_blur.frag must exist in shaders/postprocess/');
      shaderCode = shaderFile.readAsStringSync();
    });

    test('Shader header declares version 460 core and flutter runtime_effect include', () {
      expect(shaderCode, contains('#version 460 core'));
      expect(shaderCode, contains('#include <flutter/runtime_effect.glsl>'));
      expect(shaderCode, contains('precision highp float;'));
    });

    test('Shader declares exact numeric uniforms matching 6-float layout', () {
      expect(shaderCode, contains('uniform vec2 uResolution;'));
      expect(shaderCode, contains('uniform vec2 uBlurDirection;'));
      expect(shaderCode, contains('uniform float uSpatialSigma;'));
      expect(shaderCode, contains('uniform float uDepthThreshold;'));

      // Validate relative declaration order of numeric uniforms
      final int resIdx = shaderCode.indexOf('uniform vec2 uResolution;');
      final int dirIdx = shaderCode.indexOf('uniform vec2 uBlurDirection;');
      final int sigmaIdx = shaderCode.indexOf('uniform float uSpatialSigma;');
      final int depthIdx = shaderCode.indexOf('uniform float uDepthThreshold;');

      expect(resIdx, greaterThan(-1));
      expect(dirIdx, greaterThan(resIdx), reason: 'uBlurDirection must follow uResolution');
      expect(sigmaIdx, greaterThan(dirIdx), reason: 'uSpatialSigma must follow uBlurDirection');
      expect(depthIdx, greaterThan(sigmaIdx), reason: 'uDepthThreshold must follow uSpatialSigma');
    });

    test('Shader declares samplers strictly after numeric uniforms', () {
      expect(shaderCode, contains('uniform sampler2D uAoTexture;'));
      expect(shaderCode, contains('uniform sampler2D uDepthTexture;'));

      final int depthIdx = shaderCode.indexOf('uniform float uDepthThreshold;');
      final int aoSamplerIdx = shaderCode.indexOf('uniform sampler2D uAoTexture;');
      final int depthSamplerIdx = shaderCode.indexOf('uniform sampler2D uDepthTexture;');

      expect(aoSamplerIdx, greaterThan(depthIdx),
          reason: 'Samplers must follow numeric uniforms for Impeller/Flutter compatibility');
      expect(depthSamplerIdx, greaterThan(aoSamplerIdx),
          reason: 'uDepthTexture must follow uAoTexture');
    });

    test('Shader implements 9-tap bilateral filter kernel with depth-aware rejection', () {
      expect(shaderCode, contains('const int KERNEL_RADIUS = 4;'));
      expect(shaderCode, contains('for (int i = -KERNEL_RADIUS; i <= KERNEL_RADIUS; ++i)'));
      expect(shaderCode, contains('vec2 stepVec = uBlurDirection * texelSize;'));

      // Spatial Gaussian calculation
      expect(shaderCode, contains('float wSpatial = exp(-spatialDistSq / twoSigmaSpatialSq);'));

      // Depth discontinuity rejection
      expect(shaderCode, contains('float depthDiff = abs(tapZ - centerZ);'));
      expect(shaderCode, contains('float wDepth = exp(-(depthDiff * depthDiff) / twoSigmaDepthSq);'));

      // Normalization and fallback to center AO
      expect(shaderCode, contains('float weight = wSpatial * wDepth;'));
      expect(shaderCode, contains('clamp((totalWeight > 0.0001) ? (filteredAo / totalWeight) : centerAo, 0.0, 1.0)'));

      // Output packing
      expect(shaderCode, contains('fragColor = vec4(finalAo, centerZ, centerSample.b, centerSample.a);'));
    });
  });

  group('Shader Registry & Catalog Descriptors', () {
    late ShaderRegistry registry;

    setUp(() {
      registry = ShaderRegistry(loadDefaults: true);
    });

    test('ShaderCatalog.ssaoBilateralBlur constant points to correct asset path', () {
      expect(ShaderCatalog.ssaoBilateralBlur,
          equals('shaders/postprocess/ssao_bilateral_blur.frag'));
    });

    test('ShaderRegistry registers ssaoBilateralBlur with postprocess classification', () {
      final ShaderDescriptor? desc =
          registry.getShaderDescriptor(ShaderCatalog.ssaoBilateralBlur);

      expect(desc, isNotNull);
      expect(desc!.id, equals(ShaderCatalog.ssaoBilateralBlur));
      expect(desc.assetPath, equals('shaders/postprocess/ssao_bilateral_blur.frag'));
      expect(desc.category, equals(ShaderCategory.postprocess));
      expect(desc.stage, equals(ShaderStage.fragment));
      expect(desc.fallbackStrategy, equals(ShaderFallbackStrategy.bypass));
      expect(desc.minPerformanceTier, equals(DevicePerformanceTier.medium));
    });

    test('ShaderRegistry descriptor defines exact 6-float layout and 2 samplers', () {
      final ShaderDescriptor desc =
          registry.getShaderDescriptor(ShaderCatalog.ssaoBilateralBlur)!;

      expect(desc.totalFloatCount, equals(6));
      expect(desc.totalSamplerCount, equals(2));

      // Uniforms
      final UniformDefinition? uRes = desc.findUniform('uResolution');
      expect(uRes, isNotNull);
      expect(uRes!.type, equals(UniformType.vec2));
      expect(uRes.floatOffset, equals(0));
      expect(uRes.floatCount, equals(2));

      final UniformDefinition? uDir = desc.findUniform('uBlurDirection');
      expect(uDir, isNotNull);
      expect(uDir!.type, equals(UniformType.vec2));
      expect(uDir.floatOffset, equals(2));
      expect(uDir.floatCount, equals(2));

      final UniformDefinition? uSigma = desc.findUniform('uSpatialSigma');
      expect(uSigma, isNotNull);
      expect(uSigma!.type, equals(UniformType.float));
      expect(uSigma.floatOffset, equals(4));
      expect(uSigma.floatCount, equals(1));

      final UniformDefinition? uDepth = desc.findUniform('uDepthThreshold');
      expect(uDepth, isNotNull);
      expect(uDepth!.type, equals(UniformType.float));
      expect(uDepth.floatOffset, equals(5));
      expect(uDepth.floatCount, equals(1));

      // Samplers
      final SamplerDefinition? sAo = desc.findSampler('uAoTexture');
      expect(sAo, isNotNull);
      expect(sAo!.samplerIndex, equals(0));

      final SamplerDefinition? sDepth = desc.findSampler('uDepthTexture');
      expect(sDepth, isNotNull);
      expect(sDepth!.samplerIndex, equals(1));

      // Warmup parameters
      expect(desc.warmupParameters, isNotNull);
      expect(desc.warmupParameters!.length, equals(6));
      expect(desc.warmupParameters![0], equals(1.0)); // res.x
      expect(desc.warmupParameters![1], equals(1.0)); // res.y
      expect(desc.warmupParameters![2], equals(1.0)); // dir.x
      expect(desc.warmupParameters![3], equals(0.0)); // dir.y
      expect(desc.warmupParameters![4], equals(2.5)); // sigma
      expect(desc.warmupParameters![5], equals(0.1)); // depthThreshold
    });
  });

  group('BilateralFilterParams & BilateralFilter Core Math', () {
    test('BilateralFilterParams provides expected defaults and immutable copyWith', () {
      const BilateralFilterParams params = BilateralFilterParams();
      expect(params.spatialSigma, equals(2.5));
      expect(params.depthThreshold, equals(0.08));
      expect(params.kernelRadius, equals(4));

      final BilateralFilterParams custom = params.copyWith(
        spatialSigma: 3.2,
        depthThreshold: 0.05,
        kernelRadius: 6,
      );
      expect(custom.spatialSigma, equals(3.2));
      expect(custom.depthThreshold, equals(0.05));
      expect(custom.kernelRadius, equals(6));

      // Immutability of untouched fields
      final BilateralFilterParams partial = params.copyWith(spatialSigma: 4.0);
      expect(partial.spatialSigma, equals(4.0));
      expect(partial.depthThreshold, equals(0.08));
      expect(partial.kernelRadius, equals(4));
    });

    test('BilateralFilterParams JSON serialization roundtrip and equality parity', () {
      const BilateralFilterParams original = BilateralFilterParams(
        spatialSigma: 3.5,
        depthThreshold: 0.12,
        kernelRadius: 5,
      );

      final Map<String, dynamic> json = original.toJson();
      final BilateralFilterParams restored = BilateralFilterParams.fromJson(json);

      expect(restored, equals(original));
      expect(restored.hashCode, equals(original.hashCode));
      expect(original.toString(), contains('spatialSigma: 3.5'));
      expect(original.toString(), contains('depthThreshold: 0.12'));
    });

    test('BilateralFilter constants match GLSL layout and directions', () {
      expect(BilateralFilter.uniformResolutionX, equals(0));
      expect(BilateralFilter.uniformResolutionY, equals(1));
      expect(BilateralFilter.uniformBlurDirectionX, equals(2));
      expect(BilateralFilter.uniformBlurDirectionY, equals(3));
      expect(BilateralFilter.uniformSpatialSigma, equals(4));
      expect(BilateralFilter.uniformDepthThreshold, equals(5));
      expect(BilateralFilter.totalUniformFloats, equals(6));

      expect(BilateralFilter.samplerAoTexture, equals(0));
      expect(BilateralFilter.samplerDepthTexture, equals(1));
      expect(BilateralFilter.totalSamplers, equals(2));

      expect(BilateralFilter.horizontalDirection, equals(const ui.Offset(1.0, 0.0)));
      expect(BilateralFilter.verticalDirection, equals(const ui.Offset(0.0, 1.0)));
    });

    test('Spatial Gaussian weight behaves monotonically with distance and sigma fallback', () {
      const double sigma = 2.0;

      final double w0 = BilateralFilter.computeSpatialWeight(0.0, sigma);
      final double w1 = BilateralFilter.computeSpatialWeight(1.0, sigma);
      final double w2 = BilateralFilter.computeSpatialWeight(2.0, sigma);
      final double w4 = BilateralFilter.computeSpatialWeight(4.0, sigma);

      expect(w0, closeTo(1.0, 1e-6));
      expect(w1, lessThan(w0));
      expect(w2, lessThan(w1));
      expect(w4, lessThan(w2));
      expect(w4, greaterThan(0.0));

      // At distance = sigma, weight is exp(-0.5) ~ 0.60653
      expect(w2, closeTo(math.exp(-0.5), 1e-4));

      // Fallback when sigma <= 0 uses default 2.5
      final double wFallback = BilateralFilter.computeSpatialWeight(0.0, 0.0);
      expect(wFallback, closeTo(1.0, 1e-6));
      final double wFallbackDist = BilateralFilter.computeSpatialWeight(2.5, -1.0);
      expect(wFallbackDist, closeTo(math.exp(-0.5), 1e-4));
    });

    test('Depth similarity weight sharply cuts off across geometric discontinuities', () {
      const double threshold = 0.05;

      // Small depth delta (continuous surface)
      final double wContinuous = BilateralFilter.computeDepthWeight(0.005, threshold);
      expect(wContinuous, greaterThan(0.95));

      // Moderate depth delta
      final double wModerate = BilateralFilter.computeDepthWeight(0.05, threshold);
      expect(wModerate, closeTo(math.exp(-0.5), 1e-4));

      // Large depth delta (silhouette edge / separate objects)
      final double wSilhouette = BilateralFilter.computeDepthWeight(0.25, threshold);
      expect(wSilhouette, lessThan(0.0001));

      // Sign invariance: depthDiff can be positive or negative
      final double wPositive = BilateralFilter.computeDepthWeight(0.03, threshold);
      final double wNegative = BilateralFilter.computeDepthWeight(-0.03, threshold);
      expect(wPositive, closeTo(wNegative, 1e-6));
    });

    test('computeStepOffsets calculates symmetric normalized UV coordinates', () {
      const ui.Size viewport = ui.Size(1920.0, 1080.0);
      const int radius = 4;

      // Horizontal pass
      final List<ui.Offset> hOffsets = BilateralFilter.computeStepOffsets(
        blurDirection: const ui.Offset(1.0, 0.0),
        viewportSize: viewport,
        kernelRadius: radius,
      );

      expect(hOffsets.length, equals(2 * radius + 1)); // 9 taps (-4..+4)
      expect(hOffsets[radius], equals(ui.Offset.zero)); // Center tap

      for (int i = 0; i <= radius; i++) {
        final ui.Offset left = hOffsets[radius - i];
        final ui.Offset right = hOffsets[radius + i];

        expect(left.dy, equals(0.0));
        expect(right.dy, equals(0.0));
        expect(left.dx, closeTo(-right.dx, 1e-7));
      }

      // Vertical pass
      final List<ui.Offset> vOffsets = BilateralFilter.computeStepOffsets(
        blurDirection: const ui.Offset(0.0, 1.0),
        viewportSize: viewport,
        kernelRadius: radius,
      );

      expect(vOffsets.length, equals(9));
      expect(vOffsets[radius], equals(ui.Offset.zero));

      for (int i = 0; i <= radius; i++) {
        final ui.Offset top = vOffsets[radius - i];
        final ui.Offset bottom = vOffsets[radius + i];

        expect(top.dx, equals(0.0));
        expect(bottom.dx, equals(0.0));
        expect(top.dy, closeTo(-bottom.dy, 1e-7));
      }
    });

    test('1D Bilateral filtering preserves foreground silhouette while smoothing noise', () {
      const BilateralFilterParams params = BilateralFilterParams(
        spatialSigma: 2.0,
        depthThreshold: 0.05,
        kernelRadius: 4,
      );

      // Scenario A: Sharp silhouette step
      // Pixel 0 is foreground (depth = 0.2, AO = 0.15)
      // Neighbor pixels (>= 1) are background (depth = 0.8, AO = 0.95)
      final double edgeFiltered = BilateralFilter.filter1D(
        centerCoord: 0,
        centerAo: 0.15,
        centerDepth: 0.2,
        aoSampler: (int coord) => (coord <= 0) ? 0.15 : 0.95,
        depthSampler: (int coord) => (coord <= 0) ? 0.2 : 0.8,
        params: params,
      );

      // The filtered foreground pixel must stay close to 0.15 and not bleed the 0.95 background
      expect(edgeFiltered, closeTo(0.15, 0.02));

      // Scenario B: Continuous planar surface with high-frequency noise spike
      // Center has dark noise artifact (0.2), but true surrounding AO is 0.7 at constant depth 0.5
      final double noiseFiltered = BilateralFilter.filter1D(
        centerCoord: 0,
        centerAo: 0.2,
        centerDepth: 0.5,
        aoSampler: (int coord) => (coord == 0) ? 0.2 : 0.7,
        depthSampler: (int coord) => 0.5,
        params: params,
      );

      // Noise artifact is smoothed out significantly towards surrounding average (0.7)
      expect(noiseFiltered, greaterThan(0.5));
    });

    test('2D Bilateral filtering smooths planar noise and rejects cross-edge boundary taps', () {
      const BilateralFilterParams params = BilateralFilterParams(
        spatialSigma: 2.0,
        depthThreshold: 0.05,
        kernelRadius: 3,
      );

      // Center pixel at (0, 0) with depth = 0.3, AO = 0.4
      // Left half (x <= 0) is same depth 0.3, AO = 0.4
      // Right half (x > 0) is distant background with depth 2.0, AO = 1.0
      final double filtered2D = BilateralFilter.filter2D(
        centerX: 0,
        centerY: 0,
        centerAo: 0.4,
        centerDepth: 0.3,
        aoSampler: (int x, int y) => (x <= 0) ? 0.4 : 1.0,
        depthSampler: (int x, int y) => (x <= 0) ? 0.3 : 2.0,
        params: params,
      );

      // Edge rejection keeps the result strictly near 0.4
      expect(filtered2D, closeTo(0.4, 0.01));
    });
  });

  group('PostProcessPipelineController Bilateral Uniform Integration', () {
    test('buildBilateralUniforms produces exact 6-float array for horizontal pass', () {
      const ui.Size size = ui.Size(2560.0, 1440.0);
      const BilateralFilterParams params = BilateralFilterParams(
        spatialSigma: 3.0,
        depthThreshold: 0.075,
      );

      final List<double> uniforms = PostProcessPipelineController.buildBilateralUniforms(
        size: size,
        direction: const ui.Offset(1.0, 0.0),
        params: params,
      );

      expect(uniforms.length, equals(6));
      expect(uniforms[0], equals(2560.0)); // uResolution.x
      expect(uniforms[1], equals(1440.0)); // uResolution.y
      expect(uniforms[2], equals(1.0));    // uBlurDirection.x
      expect(uniforms[3], equals(0.0));    // uBlurDirection.y
      expect(uniforms[4], equals(3.0));    // uSpatialSigma
      expect(uniforms[5], equals(0.075));  // uDepthThreshold
    });

    test('buildBilateralUniforms produces exact 6-float array for vertical pass', () {
      const ui.Size size = ui.Size(1920.0, 1080.0);
      const BilateralFilterParams params = BilateralFilterParams(
        spatialSigma: 2.0,
        depthThreshold: 0.09,
      );

      final List<double> uniforms = PostProcessPipelineController.buildBilateralUniforms(
        size: size,
        direction: const ui.Offset(0.0, 1.0),
        params: params,
      );

      expect(uniforms.length, equals(6));
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));
      expect(uniforms[2], equals(0.0));    // uBlurDirection.x
      expect(uniforms[3], equals(1.0));    // uBlurDirection.y
      expect(uniforms[4], equals(2.0));
      expect(uniforms[5], equals(0.09));
    });

    test('packBilateralUniforms returns valid contiguous Float32List', () {
      const ui.Size size = ui.Size(1280.0, 720.0);
      const BilateralFilterParams params = BilateralFilterParams(
        spatialSigma: 2.5,
        depthThreshold: 0.08,
      );

      final Float32List buffer = PostProcessPipelineController.packBilateralUniforms(
        size: size,
        direction: const ui.Offset(1.0, 0.0),
        params: params,
      );

      expect(buffer, isA<Float32List>());
      expect(buffer.length, equals(6));
      expect(buffer[0], equals(1280.0));
      expect(buffer[1], equals(720.0));
      expect(buffer[2], equals(1.0));
      expect(buffer[3], equals(0.0));
      expect(buffer[4], closeTo(2.5, 1e-5));
      expect(buffer[5], closeTo(0.08, 1e-5));
    });

    test('BufferUniformTarget captures all 6 bilateral float uniforms', () {
      const ui.Size size = ui.Size(1920.0, 1080.0);
      const BilateralFilterParams params = BilateralFilterParams(
        spatialSigma: 2.5,
        depthThreshold: 0.08,
      );

      final List<double> uniforms = PostProcessPipelineController.buildBilateralUniforms(
        size: size,
        direction: const ui.Offset(0.0, 1.0),
        params: params,
      );

      final BufferUniformTarget target = BufferUniformTarget();
      for (int i = 0; i < uniforms.length; ++i) {
        target.setFloat(i, uniforms[i]);
      }

      expect(target.floatCount, equals(6));
      expect(target.getFloat(0), equals(1920.0));
      expect(target.getFloat(1), equals(1080.0));
      expect(target.getFloat(2), equals(0.0));
      expect(target.getFloat(3), equals(1.0));
      expect(target.getFloat(4), equals(2.5));
      expect(target.getFloat(5), equals(0.08));

      final List<double> exported = target.toFloatList(minLength: 6);
      expect(exported, equals(uniforms));
    });

    test('Pipeline controller constants match GLSL specification', () {
      expect(PostProcessPipelineController.bilateralFloatCount, equals(6));
      expect(PostProcessPipelineController.bilateralSamplerCount, equals(2));
    });
  });

  group('SsaoBilateralBlurPass Architecture & Parameter Tests', () {
    test('SsaoBilateralBlurPass instantiates with standard postprocess defaults', () {
      const SsaoBilateralBlurPass pass = SsaoBilateralBlurPass();

      expect(pass.blurRadius, equals(2.5));
      expect(pass.depthThreshold, equals(0.08));
      expect(pass.normalThreshold, equals(0.8));
      expect(pass.blurDirection, equals(BlurPassDirection.horizontal));
      expect(pass.directionVector, equals(const ui.Offset(1.0, 0.0)));
      expect(pass.isNormalized, isTrue);
    });

    test('SsaoBilateralBlurPass direction vector aligns horizontal vs vertical passes', () {
      const SsaoBilateralBlurPass hPass = SsaoBilateralBlurPass(
        blurDirection: BlurPassDirection.horizontal,
      );
      expect(hPass.directionVector.dx, equals(1.0));
      expect(hPass.directionVector.dy, equals(0.0));

      const SsaoBilateralBlurPass vPass = SsaoBilateralBlurPass(
        blurDirection: BlurPassDirection.vertical,
      );
      expect(vPass.directionVector.dx, equals(0.0));
      expect(vPass.directionVector.dy, equals(1.0));

      // Both vectors are unit length
      expect(hPass.directionVector.distance, closeTo(1.0, 1e-7));
      expect(vPass.directionVector.distance, closeTo(1.0, 1e-7));
    });

    test('SsaoBilateralBlurPass packs uniforms into Float32List matching GLSL shader offsets', () {
      const SsaoBilateralBlurPass pass = SsaoBilateralBlurPass(
        blurRadius: 3.5,
        depthThreshold: 0.12,
        blurDirection: BlurPassDirection.horizontal,
      );
      const ui.Size viewport = ui.Size(3840.0, 2160.0);

      final Float32List uniforms = pass.packUniforms(viewport);

      expect(uniforms.length, equals(6));
      expect(uniforms[0], equals(3840.0)); // Offset 0: uResolution.x
      expect(uniforms[1], equals(2160.0)); // Offset 1: uResolution.y
      expect(uniforms[2], equals(1.0));    // Offset 2: uBlurDirection.x
      expect(uniforms[3], equals(0.0));    // Offset 3: uBlurDirection.y
      expect(uniforms[4], closeTo(3.5, 1e-5));  // Offset 4: uSpatialSigma
      expect(uniforms[5], closeTo(0.12, 1e-5)); // Offset 5: uDepthThreshold
    });

    test('computeBilateralWeight suppresses cross-edge bleeding and crease artifacts', () {
      const SsaoBilateralBlurPass pass = SsaoBilateralBlurPass(
        blurRadius: 2.5,
        depthThreshold: 0.08,
        normalThreshold: 0.7,
      );

      // Case 1: Identical depth, collinear normal, center pixel (dist = 0)
      final double wCenter = pass.computeBilateralWeight(
        spatialDistance: 0.0,
        depthDelta: 0.0,
        normalDot: 1.0,
      );
      expect(wCenter, closeTo(1.0, 1e-5));

      // Case 2: Continuous planar surface within kernel radius
      final double wNeighbor = pass.computeBilateralWeight(
        spatialDistance: 1.5,
        depthDelta: 0.01,
        normalDot: 0.98,
      );
      expect(wNeighbor, greaterThan(0.7));

      // Case 3: Geometric silhouette jump (large depth delta)
      final double wSilhouette = pass.computeBilateralWeight(
        spatialDistance: 1.0,
        depthDelta: 0.5, // 0.5 >> depthThreshold 0.08
        normalDot: 1.0,
      );
      expect(wSilhouette, lessThan(1e-6),
          reason: 'Silhouette depth discontinuity must be rejected to prevent AO halo bleeding');

      // Case 4: Sharp dihedral corner / normal crease (normalDot below threshold)
      final double wCrease = pass.computeBilateralWeight(
        spatialDistance: 1.0,
        depthDelta: 0.01,
        normalDot: 0.5, // 0.5 < normalThreshold 0.7
      );
      expect(wCrease, equals(0.0),
          reason: 'Geometric crease must be preserved without blurring across orthogonal faces');
    });
  });

  group('Pass Chaining & Ping-Pong Buffer Logic', () {
    test('PingPongBuffer initializes with specified dimensions and tracks bindings', () {
      final PingPongBuffer buffer = PingPongBuffer(
        id: 'test_buffer',
        width: 1920,
        height: 1080,
      );

      expect(buffer.id, equals('test_buffer'));
      expect(buffer.width, equals(1920));
      expect(buffer.height, equals(1080));
      expect(buffer.isBound, isFalse);
      expect(buffer.writeCount, equals(0));

      buffer.bindAsRenderTarget();
      expect(buffer.isBound, isTrue);
      expect(buffer.writeCount, equals(1));

      buffer.unbind();
      expect(buffer.isBound, isFalse);
    });

    test('SsaoBilateralBlurPingPongPipeline initializes matched buffer pair and passes', () {
      const ui.Size viewport = ui.Size(1280.0, 720.0);
      final SsaoBilateralBlurPingPongPipeline pipeline =
          SsaoBilateralBlurPingPongPipeline(viewportSize: viewport);

      expect(pipeline.bufferA.width, equals(1280));
      expect(pipeline.bufferA.height, equals(720));
      expect(pipeline.bufferB.width, equals(1280));
      expect(pipeline.bufferB.height, equals(720));

      expect(pipeline.horizontalPass.blurDirection, equals(BlurPassDirection.horizontal));
      expect(pipeline.verticalPass.blurDirection, equals(BlurPassDirection.vertical));
    });

    test('Separable 2-pass blur execution ping-pongs buffers and ends in target buffer', () {
      const ui.Size viewport = ui.Size(1920.0, 1080.0);
      final SsaoBilateralBlurPingPongPipeline pipeline =
          SsaoBilateralBlurPingPongPipeline(viewportSize: viewport);

      // Single iteration = 1 horizontal pass (A -> B) + 1 vertical pass (B -> A)
      final PingPongBuffer result = pipeline.executeSeparableBlur(iterations: 1);

      // Buffer B received 1 write (horizontal pass)
      expect(pipeline.bufferB.writeCount, equals(1));
      // Buffer A received 1 write (vertical pass)
      expect(pipeline.bufferA.writeCount, equals(1));

      // After 2 passes (even count), the result resides back in Buffer A
      expect(result.id, equals(pipeline.bufferA.id));
      expect(result.writeCount, equals(1));
    });

    test('Multi-pass ping-pong blur scales write count deterministically without buffer allocation', () {
      const ui.Size viewport = ui.Size(1920.0, 1080.0);
      final SsaoBilateralBlurPingPongPipeline pipeline =
          SsaoBilateralBlurPingPongPipeline(viewportSize: viewport);

      const int iterations = 3; // 3 x (Horizontal + Vertical) = 6 total passes
      final PingPongBuffer result = pipeline.executeSeparableBlur(iterations: iterations);

      expect(pipeline.bufferA.writeCount, equals(3));
      expect(pipeline.bufferB.writeCount, equals(3));
      expect(result.id, equals(pipeline.bufferA.id));
    });

    test('Buffer dimensions match viewport exactly preventing resampling artifacts', () {
      const ui.Size viewport = ui.Size(800.0, 600.0);
      final SsaoBilateralBlurPingPongPipeline pipeline =
          SsaoBilateralBlurPingPongPipeline(viewportSize: viewport);

      expect(pipeline.bufferA.width, equals(800));
      expect(pipeline.bufferA.height, equals(600));
      expect(pipeline.bufferB.width, equals(800));
      expect(pipeline.bufferB.height, equals(600));
    });
  });

  group('SsaoBilateralBlurPainter Widget & Canvas Tests', () {
    testWidgets('SsaoBilateralBlurPainter renders inside CustomPaint without crashing in headless mode', (WidgetTester tester) async {
      const BilateralFilterParams params = BilateralFilterParams(
        spatialSigma: 2.5,
        depthThreshold: 0.08,
      );

      final SsaoBilateralBlurPainter painter = SsaoBilateralBlurPainter(
        params: params,
        direction: const ui.Offset(1.0, 0.0),
        shader: null,     // In headless test runner, FragmentShader is null
        aoTexture: null,  // Headless test runner without GPU textures
        depthTexture: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: painter,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    test('SsaoBilateralBlurPainter shouldRepaint triggers correctly on property mutations', () {
      const BilateralFilterParams paramsA = BilateralFilterParams(
        spatialSigma: 2.0,
        depthThreshold: 0.05,
      );
      const BilateralFilterParams paramsB = BilateralFilterParams(
        spatialSigma: 3.0,
        depthThreshold: 0.1,
      );

      final SsaoBilateralBlurPainter painterOriginal = SsaoBilateralBlurPainter(
        params: paramsA,
        direction: const ui.Offset(1.0, 0.0),
      );

      // Identical delegate -> shouldRepaint is false
      final SsaoBilateralBlurPainter painterIdentical = SsaoBilateralBlurPainter(
        params: paramsA,
        direction: const ui.Offset(1.0, 0.0),
      );
      expect(painterOriginal.shouldRepaint(painterIdentical), isFalse);

      // Direction changed (horizontal -> vertical) -> shouldRepaint is true
      final SsaoBilateralBlurPainter painterDirChanged = SsaoBilateralBlurPainter(
        params: paramsA,
        direction: const ui.Offset(0.0, 1.0),
      );
      expect(painterOriginal.shouldRepaint(painterDirChanged), isTrue);

      // Params changed -> shouldRepaint is true
      final SsaoBilateralBlurPainter painterParamsChanged = SsaoBilateralBlurPainter(
        params: paramsB,
        direction: const ui.Offset(1.0, 0.0),
      );
      expect(painterOriginal.shouldRepaint(painterParamsChanged), isTrue);
    });
  });

  group('Adversarial Verification & Edge Conditions', () {
    test('Zero or negative viewport dimensions clamp safely in uniform construction', () {
      final List<ui.Offset> offsetsZero = BilateralFilter.computeStepOffsets(
        blurDirection: const ui.Offset(1.0, 0.0),
        viewportSize: ui.Size.zero,
      );

      expect(offsetsZero.length, equals(9));
      expect(offsetsZero[4], equals(ui.Offset.zero));

      // No NaN or Infinite coordinates
      for (final ui.Offset offset in offsetsZero) {
        expect(offset.dx.isFinite, isTrue);
        expect(offset.dy.isFinite, isTrue);
      }
    });

    test('Zero or negative spatialSigma and depthThreshold fallback safely without NaN', () {
      final double wSpatialZero = BilateralFilter.computeSpatialWeight(1.0, 0.0);
      expect(wSpatialZero.isFinite, isTrue);
      expect(wSpatialZero, greaterThan(0.0));

      final double wSpatialNeg = BilateralFilter.computeSpatialWeight(1.0, -5.0);
      expect(wSpatialNeg.isFinite, isTrue);
      expect(wSpatialNeg, greaterThan(0.0));

      final double wDepthZero = BilateralFilter.computeDepthWeight(0.1, 0.0);
      expect(wDepthZero.isFinite, isTrue);
      expect(wDepthZero, greaterThan(0.0));

      final double wDepthNeg = BilateralFilter.computeDepthWeight(0.1, -2.0);
      expect(wDepthNeg.isFinite, isTrue);
      expect(wDepthNeg, greaterThan(0.0));
    });

    test('Extreme depth discontinuities yield zero weight preventing arithmetic overflow', () {
      const double threshold = 0.08;

      final double wExtreme = BilateralFilter.computeDepthWeight(1000.0, threshold);
      expect(wExtreme, equals(0.0));
      expect(wExtreme.isFinite, isTrue);

      final double wTiny = BilateralFilter.computeDepthWeight(1e-9, threshold);
      expect(wTiny, closeTo(1.0, 1e-6));
    });

    test('1D Bilateral filtering on uniform white or black image preserves exact bounds [0, 1]', () {
      // Uniform black (all 0.0)
      final double blackResult = BilateralFilter.filter1D(
        centerCoord: 0,
        centerAo: 0.0,
        centerDepth: 1.0,
        aoSampler: (_) => 0.0,
        depthSampler: (_) => 1.0,
      );
      expect(blackResult, equals(0.0));

      // Uniform white (all 1.0)
      final double whiteResult = BilateralFilter.filter1D(
        centerCoord: 0,
        centerAo: 1.0,
        centerDepth: 1.0,
        aoSampler: (_) => 1.0,
        depthSampler: (_) => 1.0,
      );
      expect(whiteResult, closeTo(1.0, 1e-5));
    });

    test('Zero total weight condition falls back safely to center AO', () {
      // In pathological case where all taps have zero weight, fallback returns centerAo
      final double fallbackResult = BilateralFilter.filter1D(
        centerCoord: 0,
        centerAo: 0.42,
        centerDepth: 0.0,
        aoSampler: (_) => 1.0,
        depthSampler: (_) => 100000.0, // Every neighbor is infinitely distant
        params: const BilateralFilterParams(depthThreshold: 0.000001),
      );

      // Center tap itself has depthDiff = 0, so weight for center tap is wSpatial(0)*wDepth(0) = 1.0
      // Thus filtered output stays centerAo = 0.42
      expect(fallbackResult, closeTo(0.42, 1e-4));
    });
  });
}
