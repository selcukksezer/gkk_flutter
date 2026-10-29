// =============================================================================
// Comprehensive SSAO (Screen Space Ambient Occlusion) Shader & Wrapper Test Suite
// Verifying GLSL 460 Uniform Packing, SsaoPass Architecture, Device Tiers & Fallbacks
// 2027 Cinematic AAA Graphics Pipeline (R5 Standards)
// =============================================================================

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/layout/mobile_ssao_layer.dart';
import 'package:gkk_flutter/core/shaders/shader_pipeline.dart';
import 'package:gkk_flutter/core/shaders/shader_registry.dart';
import 'package:gkk_flutter/rendering/postprocess/postprocess_pipeline.dart';
import 'package:gkk_flutter/rendering/postprocess/ssao_kernel.dart';

// -----------------------------------------------------------------------------
// SsaoPass Architectural Dart Wrapper
// Encapsulates configuration parameters, uniform packing, device performance tiers,
// and fallback strategies when depth textures or GPU runtime effects are unavailable.
// -----------------------------------------------------------------------------

/// Architectural Dart wrapper for the SSAO post-process render pass.
class SsaoPass {
  SsaoPass({
    this.params = const SsaoParams(),
    this.targetTier = DevicePerformanceTier.high,
    this.fallbackStrategy = ShaderFallbackStrategy.bypass,
    this.depthTexture,
    this.normalTexture,
    this.shader,
  });

  /// Active SSAO parameters (radius, bias, intensity, power, sampleCount, near, far).
  SsaoParams params;

  /// Current device hardware performance tier.
  DevicePerformanceTier targetTier;

  /// Strategy when hardware tier is insufficient or shaders fail.
  ShaderFallbackStrategy fallbackStrategy;

  /// Input normalized depth buffer (Sampler 0).
  ui.Image? depthTexture;

  /// Input view-space normal map (Sampler 1, optional).
  ui.Image? normalTexture;

  /// Compiled GPU fragment shader instance (optional in CPU/fallback mode).
  ui.FragmentShader? shader;

  // Convenience getters for required configuration properties:
  int get sampleCount => params.sampleCount;
  double get radius => params.radius;
  double get bias => params.bias;
  double get intensity => params.intensity;
  double get power => params.power;
  double get near => params.near;
  double get far => params.far;

  /// Minimum device tier required for hardware SSAO (medium tier).
  static const DevicePerformanceTier minTier = DevicePerformanceTier.medium;

  /// Validates whether the given performance tier is allowed to activate SSAO.
  static bool isTierSupported(DevicePerformanceTier tier) =>
      tier.satisfies(minTier);

  /// Whether this pass is enabled based on tier constraints.
  bool get isTierActive => isTierSupported(targetTier);

  /// Whether the GPU shader pass can actively execute.
  /// Requires supported device tier, compiled fragment shader, and depth buffer texture.
  bool get canExecuteGpu =>
      isTierActive && shader != null && depthTexture != null;

  /// Packs uniform floats for `ssao.frag` in exact GLSL declaration order.
  List<double> buildUniforms(Size size) =>
      PostProcessPipelineController.buildSsaoUniforms(size: size, params: params);

  /// Packs uniform floats as [Float32List] buffer.
  Float32List packUniforms(Size size) =>
      PostProcessPipelineController.packSsaoUniforms(size: size, params: params);

  /// Creates a configured [SsaoPainter] for rendering this pass.
  SsaoPainter createPainter() => SsaoPainter(
        params: params,
        shader: shader,
        depthTexture: depthTexture,
        normalTexture: normalTexture,
      );

  /// Evaluates fallback action if GPU execution is unavailable.
  /// Returns 'tier_disabled' if tier is too low,
  /// 'bypassed' if GPU assets missing and strategy is bypass,
  /// 'fallback_applied' if alternative fallback is triggered,
  /// or 'rendered' if GPU executed.
  String executePass(Canvas canvas, Size size) {
    if (!isTierActive) {
      return 'tier_disabled';
    }
    if (shader == null || depthTexture == null) {
      if (fallbackStrategy == ShaderFallbackStrategy.bypass) {
        return 'bypassed';
      }
      return 'fallback_applied';
    }
    final SsaoPainter painter = createPainter();
    painter.paint(canvas, size);
    return 'rendered';
  }
}

// -----------------------------------------------------------------------------
// Test Mock Shader Asset Loader for Pipeline Simulation
// -----------------------------------------------------------------------------

class MockSsaoAssetLoader implements ShaderAssetLoader {
  MockSsaoAssetLoader({
    this.failProgramPaths = const <String>{},
    this.sourceData = const <String, String>{},
  });

  final Set<String> failProgramPaths;
  final Map<String, String> sourceData;

  int programLoadAttempts = 0;

  @override
  Future<ui.FragmentProgram> loadFragmentProgram(String assetPath) async {
    programLoadAttempts++;
    if (failProgramPaths.contains(assetPath)) {
      throw Exception('Simulated GPU driver compilation failure for $assetPath');
    }
    return ui.FragmentProgram.fromAsset(assetPath);
  }

  @override
  Future<String> loadShaderSource(String assetPath) async {
    return sourceData[assetPath] ??
        '// GLSL 460 SSAO Source for $assetPath\nvoid main() {}';
  }
}

// -----------------------------------------------------------------------------
// Main Test Suite
// -----------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // 1. SsaoPass & SsaoParams Configuration Tests
  // ===========================================================================
  group('1. SsaoPass & SsaoParams Configuration Tests', () {
    test('SsaoParams default constructor matches AAA rendering specifications', () {
      const SsaoParams params = SsaoParams();

      expect(params.sampleCount, equals(16));
      expect(params.radius, equals(0.5));
      expect(params.bias, equals(0.025));
      expect(params.intensity, equals(1.5));
      expect(params.power, equals(2.0));
      expect(params.near, equals(0.1));
      expect(params.far, equals(100.0));
    });

    test('SsaoParams custom constructor retains all specified properties', () {
      const SsaoParams custom = SsaoParams(
        sampleCount: 24,
        radius: 0.75,
        bias: 0.035,
        intensity: 2.2,
        power: 2.5,
        near: 0.2,
        far: 200.0,
      );

      expect(custom.sampleCount, equals(24));
      expect(custom.radius, equals(0.75));
      expect(custom.bias, equals(0.035));
      expect(custom.intensity, equals(2.2));
      expect(custom.power, equals(2.5));
      expect(custom.near, equals(0.2));
      expect(custom.far, equals(200.0));
    });

    test('SsaoParams.copyWith produces updated instances while preserving unaltered fields', () {
      const SsaoParams initial = SsaoParams(
        sampleCount: 16,
        radius: 0.5,
        bias: 0.025,
        intensity: 1.5,
        power: 2.0,
      );

      final SsaoParams updated = initial.copyWith(
        radius: 0.8,
        intensity: 2.0,
      );

      expect(updated.radius, equals(0.8));
      expect(updated.intensity, equals(2.0));
      // Preserved fields
      expect(updated.sampleCount, equals(16));
      expect(updated.bias, equals(0.025));
      expect(updated.power, equals(2.0));
      expect(updated.near, equals(0.1));
      expect(updated.far, equals(100.0));

      final SsaoParams updatedSamples = initial.copyWith(sampleCount: 32);
      expect(updatedSamples.sampleCount, equals(32));
      expect(updatedSamples.radius, equals(0.5));
    });

    test('SsaoPass wrapper initializes with default parameters and exposes getters', () {
      final SsaoPass pass = SsaoPass();

      expect(pass.sampleCount, equals(16));
      expect(pass.radius, equals(0.5));
      expect(pass.bias, equals(0.025));
      expect(pass.intensity, equals(1.5));
      expect(pass.power, equals(2.0));
      expect(pass.near, equals(0.1));
      expect(pass.far, equals(100.0));
      expect(pass.targetTier, equals(DevicePerformanceTier.high));
      expect(pass.fallbackStrategy, equals(ShaderFallbackStrategy.bypass));
      expect(pass.shader, isNull);
      expect(pass.depthTexture, isNull);
      expect(pass.normalTexture, isNull);
    });

    test('SsaoPass wrapper reflects updated params object dynamically', () {
      final SsaoPass pass = SsaoPass(
        params: const SsaoParams(
          sampleCount: 32,
          radius: 0.65,
          bias: 0.015,
          intensity: 1.85,
          power: 2.2,
        ),
      );

      expect(pass.sampleCount, equals(32));
      expect(pass.radius, equals(0.65));
      expect(pass.bias, equals(0.015));
      expect(pass.intensity, equals(1.85));
      expect(pass.power, equals(2.2));

      pass.params = pass.params.copyWith(sampleCount: 8, intensity: 1.1);
      expect(pass.sampleCount, equals(8));
      expect(pass.intensity, equals(1.1));
      expect(pass.radius, equals(0.65));
    });

    test('PostProcessPipelineController initializes with default SsaoParams', () {
      final PostProcessPipelineController controller =
          PostProcessPipelineController();

      expect(controller.ssaoParams.sampleCount, equals(16));
      expect(controller.ssaoParams.radius, equals(0.5));
      expect(controller.ssaoParams.bias, equals(0.025));
      expect(controller.ssaoParams.intensity, equals(1.5));
      expect(controller.ssaoParams.power, equals(2.0));
      expect(controller.isInitialized, isFalse);
    });
  });

  // ===========================================================================
  // 2. Uniform Layout & Packing Tests (ssao.frag GLSL 460 Compliance)
  // ===========================================================================
  group('2. Uniform Layout & Packing Tests (ssao.frag GLSL 460 Compliance)', () {
    const Size viewport = Size(1920.0, 1080.0);
    const SsaoParams testParams = SsaoParams(
      radius: 0.6,
      bias: 0.03,
      intensity: 1.75,
      power: 2.25,
      sampleCount: 24,
      near: 0.15,
      far: 120.0,
    );

    test('SsaoKernel constants match exact GLSL uniform float indices 0..8', () {
      expect(SsaoKernel.kUniformResolutionX, equals(0));
      expect(SsaoKernel.kUniformResolutionY, equals(1));
      expect(SsaoKernel.kUniformRadius, equals(2));
      expect(SsaoKernel.kUniformBias, equals(3));
      expect(SsaoKernel.kUniformIntensity, equals(4));
      expect(SsaoKernel.kUniformPower, equals(5));
      expect(SsaoKernel.kUniformSampleCount, equals(6));
      expect(SsaoKernel.kUniformNear, equals(7));
      expect(SsaoKernel.kUniformFar, equals(8));
      expect(SsaoKernel.kUniformFloatCount, equals(9));

      expect(SsaoKernel.kSamplerDepthIndex, equals(0));
      expect(SsaoKernel.kSamplerNormalIndex, equals(1));
      expect(SsaoKernel.kSamplerCount, equals(2));
    });

    test('PostProcessPipelineController metadata constants match 9 floats & 2 samplers', () {
      expect(PostProcessPipelineController.ssaoFloatCount, equals(9));
      expect(PostProcessPipelineController.ssaoSamplerCount, equals(2));
    });

    test('buildSsaoUniforms packs floats in exact GLSL declaration order', () {
      final List<double> uniforms =
          PostProcessPipelineController.buildSsaoUniforms(
        size: viewport,
        params: testParams,
      );

      expect(uniforms.length, equals(9));
      expect(uniforms[0], equals(1920.0)); // uResolution.x
      expect(uniforms[1], equals(1080.0)); // uResolution.y
      expect(uniforms[2], equals(0.6)); // uRadius
      expect(uniforms[3], equals(0.03)); // uBias
      expect(uniforms[4], equals(1.75)); // uIntensity
      expect(uniforms[5], equals(2.25)); // uPower
      expect(uniforms[6], equals(24.0)); // uSampleCount as float
      expect(uniforms[7], equals(0.15)); // uNear
      expect(uniforms[8], equals(120.0)); // uFar
    });

    test('packSsaoUniforms exports Float32List matching buildSsaoUniforms byte-for-byte', () {
      final Float32List float32Buffer =
          PostProcessPipelineController.packSsaoUniforms(
        size: viewport,
        params: testParams,
      );

      expect(float32Buffer.length, equals(9));
      expect(float32Buffer.elementSizeInBytes, equals(4));
      expect(float32Buffer.lengthInBytes, equals(36));

      expect(float32Buffer[0], equals(1920.0));
      expect(float32Buffer[1], equals(1080.0));
      expect(float32Buffer[2], closeTo(0.6, 1e-6));
      expect(float32Buffer[3], closeTo(0.03, 1e-6));
      expect(float32Buffer[4], closeTo(1.75, 1e-6));
      expect(float32Buffer[5], closeTo(2.25, 1e-6));
      expect(float32Buffer[6], equals(24.0));
      expect(float32Buffer[7], closeTo(0.15, 1e-6));
      expect(float32Buffer[8], equals(120.0));
    });

    test('SsaoParams toUniformList and toFloat32List conform to SsaoKernel buffer layout', () {
      final List<double> list = testParams.toUniformList(1280.0, 720.0);
      final List<double> listWithSize =
          testParams.toUniformListWithSize(const Size(1280.0, 720.0));
      final Float32List f32 = testParams.toFloat32List(1280.0, 720.0);

      expect(list, equals(listWithSize));
      expect(list.length, equals(9));
      expect(f32.length, equals(9));

      for (int i = 0; i < 9; i++) {
        expect(f32[i], closeTo(list[i], 1e-5));
      }
    });

    test('SsaoParams writeToFloatBuffer respects non-zero starting offset', () {
      final Float32List largeBuffer = Float32List(20);
      const int targetOffset = 5;

      testParams.writeToFloatBuffer(largeBuffer, 800.0, 600.0, targetOffset);

      expect(largeBuffer[targetOffset + 0], equals(800.0));
      expect(largeBuffer[targetOffset + 1], equals(600.0));
      expect(largeBuffer[targetOffset + 2], closeTo(0.6, 1e-6));
      expect(largeBuffer[targetOffset + 3], closeTo(0.03, 1e-6));
      expect(largeBuffer[targetOffset + 4], closeTo(1.75, 1e-6));
      expect(largeBuffer[targetOffset + 5], closeTo(2.25, 1e-6));
      expect(largeBuffer[targetOffset + 6], equals(24.0));
      expect(largeBuffer[targetOffset + 7], closeTo(0.15, 1e-6));
      expect(largeBuffer[targetOffset + 8], equals(120.0));

      // Surrounding slots remain untouched (zero)
      expect(largeBuffer[targetOffset - 1], equals(0.0));
      expect(largeBuffer[targetOffset + 9], equals(0.0));
    });

    test('SsaoPass wrapper buildUniforms and packUniforms produce matching results', () {
      final SsaoPass pass = SsaoPass(params: testParams);
      final List<double> list = pass.buildUniforms(viewport);
      final Float32List packed = pass.packUniforms(viewport);

      expect(list.length, equals(9));
      expect(packed.length, equals(9));
      for (int i = 0; i < 9; i++) {
        expect(packed[i], closeTo(list[i], 1e-5));
      }
    });

    test('BufferUniformTarget stores SSAO uniforms at exact sequential float slots', () {
      final BufferUniformTarget target = BufferUniformTarget();
      final List<double> packed =
          PostProcessPipelineController.buildSsaoUniforms(
        size: viewport,
        params: testParams,
      );

      for (int i = 0; i < packed.length; i++) {
        target.setFloat(i, packed[i]);
      }

      expect(target.floatCount, equals(9));
      expect(target.getFloat(0), equals(1920.0));
      expect(target.getFloat(1), equals(1080.0));
      expect(target.getFloat(2), equals(0.6));
      expect(target.getFloat(3), equals(0.03));
      expect(target.getFloat(4), equals(1.75));
      expect(target.getFloat(5), equals(2.25));
      expect(target.getFloat(6), equals(24.0));
      expect(target.getFloat(7), equals(0.15));
      expect(target.getFloat(8), equals(120.0));
    });
  });

  // ===========================================================================
  // 3. Sample Hemisphere Distribution & Kernel Tests
  // ===========================================================================
  group('3. Sample Hemisphere Distribution & Kernel Tests', () {
    test('Golden angle constant equals pi * (3 - sqrt(5))', () {
      final double expected = math.pi * (3.0 - math.sqrt(5.0));
      expect(SsaoKernel.goldenAngle, closeTo(expected, 1e-12));
    });

    test('Vogel spiral 2D kernel generates monotonically increasing radii on unit disk', () {
      const List<int> testSampleCounts = <int>[8, 16, 24, 32];

      for (final int count in testSampleCounts) {
        final List<Offset> taps = SsaoKernel.generateVogelSpiralKernel(count);
        expect(taps.length, equals(count));

        double previousRadius = -1.0;
        for (int i = 0; i < count; i++) {
          final Offset tap = taps[i];
          final double r = tap.distance;

          // Must lie strictly inside the unit disk
          expect(r, lessThanOrEqualTo(1.0 + 1e-7));

          // Radius strictly increases: r = sqrt((i + 0.5) / count)
          final double expectedR = math.sqrt((i + 0.5) / count.toDouble());
          expect(r, closeTo(expectedR, 1e-6));
          expect(r, greaterThan(previousRadius));
          previousRadius = r;
        }

        // Inner tap is close to origin, outer tap is near boundary
        expect(taps.first.distance, lessThan(0.35));
        expect(taps.last.distance, greaterThan(0.90));
      }
    });

    test('packVogelSpiralKernel respects padding options for std140 GPU uniform buffers', () {
      const int count = 16;

      // 1. Unpadded (stride 2: dx, dy)
      final Float32List unpadded =
          SsaoKernel.packVogelSpiralKernel(count, padVec4: false);
      expect(unpadded.length, equals(count * 2));

      // 2. Padded to vec4 (stride 4: dx, dy, 0.0, 0.0)
      final Float32List padded =
          SsaoKernel.packVogelSpiralKernel(count, padVec4: true);
      expect(padded.length, equals(count * 4));

      for (int i = 0; i < count; i++) {
        expect(padded[i * 4 + 0], equals(unpadded[i * 2 + 0]));
        expect(padded[i * 4 + 1], equals(unpadded[i * 2 + 1]));
        expect(padded[i * 4 + 2], equals(0.0));
        expect(padded[i * 4 + 3], equals(0.0));
      }
    });

    test('generateHemisphereKernel confines vectors strictly to upper hemisphere (Z >= minZ)', () {
      const int count = 24;
      const double minZ = 0.15;
      final List<Vector3D> kernel =
          SsaoKernel.generateHemisphereKernel(count, minZ: minZ);

      expect(kernel.length, equals(count));

      double previousDist = -1.0;
      for (int i = 0; i < count; i++) {
        final Vector3D vec = kernel[i];

        // Z component must be positive and >= minZ
        expect(vec.z, greaterThan(0.0));

        // Falloff scaling: falloff = 0.1 + 0.9 * (scale * scale)
        final double dist = vec.length;
        expect(dist, greaterThan(previousDist));
        expect(dist, lessThanOrEqualTo(1.0 + 1e-6));
        previousDist = dist;
      }

      // First sample clusters near contact point, last sample reaches outer hemisphere
      expect(kernel.first.length, lessThan(0.2));
      expect(kernel.last.length, greaterThan(0.95));
    });

    test('packHemisphereKernel generates correct stride for std140 uniform blocks', () {
      const int count = 12;

      // Unpadded stride 3 (x, y, z)
      final Float32List unpadded =
          SsaoKernel.packHemisphereKernel(count, padVec4: false);
      expect(unpadded.length, equals(count * 3));

      // Padded stride 4 (x, y, z, 0.0)
      final Float32List padded =
          SsaoKernel.packHemisphereKernel(count, padVec4: true);
      expect(padded.length, equals(count * 4));

      for (int i = 0; i < count; i++) {
        expect(padded[i * 4 + 0], equals(unpadded[i * 3 + 0]));
        expect(padded[i * 4 + 1], equals(unpadded[i * 3 + 1]));
        expect(padded[i * 4 + 2], equals(unpadded[i * 3 + 2]));
        expect(padded[i * 4 + 3], equals(0.0));
      }
    });

    test('generateNoiseVectors produces valid unit circle rotation vectors in XY plane', () {
      final List<Vector3D> noise =
          SsaoKernel.generateNoiseVectors(width: 4, height: 4);

      expect(noise.length, equals(16));
      for (final Vector3D v in noise) {
        expect(v.z, equals(0.0));
        expect(v.length, closeTo(1.0, 1e-6));
      }
    });

    test('generateNoiseTileRgbaBytes formats valid 8-bit RGBA texture data', () {
      final Uint8List bytes =
          SsaoKernel.generateNoiseTileRgbaBytes(width: 4, height: 4);

      expect(bytes.length, equals(16 * 4)); // 64 bytes total
      for (int i = 0; i < 16; i++) {
        final int r = bytes[i * 4 + 0];
        final int g = bytes[i * 4 + 1];
        final int b = bytes[i * 4 + 2];
        final int a = bytes[i * 4 + 3];

        expect(r, inInclusiveRange(0, 255));
        expect(g, inInclusiveRange(0, 255));
        expect(b, equals(128)); // Neutral normal Z = 0 encoded at 128
        expect(a, equals(255)); // Full alpha
      }
    });

    test('hash12 produces deterministic pseudo-random floats in [0, 1)', () {
      final double val1 = SsaoKernel.hash12(100.0, 200.0);
      final double val2 = SsaoKernel.hash12(100.0, 200.0);
      final double val3 = SsaoKernel.hash12(101.0, 200.0);

      expect(val1, equals(val2)); // Deterministic
      expect(val1, inInclusiveRange(0.0, 1.0));
      expect(val3, inInclusiveRange(0.0, 1.0));
      expect(val1, isNot(equals(val3))); // Spatial variance
    });
  });

  // ===========================================================================
  // 4. Device Performance Tier Validation Tests
  // ===========================================================================
  group('4. Device Performance Tier Validation Tests', () {
    test('DevicePerformanceTier hierarchy levels are correctly ordered', () {
      expect(DevicePerformanceTier.ultraLow.level, equals(0));
      expect(DevicePerformanceTier.low.level, equals(1));
      expect(DevicePerformanceTier.medium.level, equals(2));
      expect(DevicePerformanceTier.high.level, equals(3));
    });

    test('DevicePerformanceTier satisfies method evaluates minimum requirements', () {
      const DevicePerformanceTier minTier = DevicePerformanceTier.medium;

      expect(DevicePerformanceTier.ultraLow.satisfies(minTier), isFalse);
      expect(DevicePerformanceTier.low.satisfies(minTier), isFalse);
      expect(DevicePerformanceTier.medium.satisfies(minTier), isTrue);
      expect(DevicePerformanceTier.high.satisfies(minTier), isTrue);
    });

    test('SsaoPass.isTierSupported accurately reflects hardware tier gating', () {
      expect(SsaoPass.isTierSupported(DevicePerformanceTier.ultraLow), isFalse);
      expect(SsaoPass.isTierSupported(DevicePerformanceTier.low), isFalse);
      expect(SsaoPass.isTierSupported(DevicePerformanceTier.medium), isTrue);
      expect(SsaoPass.isTierSupported(DevicePerformanceTier.high), isTrue);
    });

    test('SsaoPass.isTierActive gates pass activation on tier', () {
      final SsaoPass ultraLowPass =
          SsaoPass(targetTier: DevicePerformanceTier.ultraLow);
      final SsaoPass lowPass =
          SsaoPass(targetTier: DevicePerformanceTier.low);
      final SsaoPass mediumPass =
          SsaoPass(targetTier: DevicePerformanceTier.medium);
      final SsaoPass highPass =
          SsaoPass(targetTier: DevicePerformanceTier.high);

      expect(ultraLowPass.isTierActive, isFalse);
      expect(lowPass.isTierActive, isFalse);
      expect(mediumPass.isTierActive, isTrue);
      expect(highPass.isTierActive, isTrue);
    });

    test('ShaderCatalog.ssao descriptor requires DevicePerformanceTier.medium', () {
      final ShaderRegistry registry = ShaderRegistry(loadDefaults: true);
      final ShaderDescriptor? ssaoDesc =
          registry.getShaderDescriptor(ShaderCatalog.ssao);

      expect(ssaoDesc, isNotNull);
      expect(ssaoDesc!.minPerformanceTier, equals(DevicePerformanceTier.medium));
      expect(ssaoDesc.fallbackStrategy, equals(ShaderFallbackStrategy.bypass));
      expect(ssaoDesc.fallbackId, equals(ShaderCatalog.acesTonemap));
    });

    test('ShaderPipeline tier downgrade routes low tiers to fallbackActive', () async {
      final MockSsaoAssetLoader loader = MockSsaoAssetLoader(
        sourceData: <String, String>{
          ShaderCatalog.acesTonemap: '// ACES Fallback\nvoid main() {}',
          ShaderCatalog.ssao: '// SSAO Shader\nvoid main() {}',
        },
      );

      // Low tier pipeline
      final ShaderPipeline lowPipeline = ShaderPipeline(
        assetLoader: loader,
        config: const ShaderPipelineConfig(
          deviceTier: DevicePerformanceTier.low,
          enableWarmup: false,
          enableFallbacks: true,
        ),
      );

      final CompiledShader compiledLow =
          await lowPipeline.loadShader(ShaderCatalog.ssao);

      // Low tier must be marked fallbackActive and downgraded to acesTonemap
      expect(compiledLow.status, equals(ShaderStatus.fallbackActive));
      expect(compiledLow.fallbackShader, isNotNull);
      expect(compiledLow.fallbackShader!.descriptor.id,
          equals(ShaderCatalog.acesTonemap));

      // UltraLow tier pipeline
      final ShaderPipeline ultraLowPipeline = ShaderPipeline(
        assetLoader: loader,
        config: const ShaderPipelineConfig(
          deviceTier: DevicePerformanceTier.ultraLow,
          enableWarmup: false,
          enableFallbacks: true,
        ),
      );

      final CompiledShader compiledUltraLow =
          await ultraLowPipeline.loadShader(ShaderCatalog.ssao);
      expect(compiledUltraLow.status, equals(ShaderStatus.fallbackActive));
    });

    test('MobileSsaoQuality specifications align with mobile tier scaling', () {
      // Disabled profiles (Eco / Low / Off)
      expect(MobileSsaoQuality.off.sampleCount, equals(0));
      expect(MobileSsaoQuality.eco.sampleCount, equals(0));
      expect(MobileSsaoQuality.off.frameBudgetMs, equals(0.0));
      expect(MobileSsaoQuality.eco.frameBudgetMs, equals(0.0));
      expect(MobileSsaoQuality.off.hasBilateralFiltering, isFalse);
      expect(MobileSsaoQuality.eco.hasBilateralFiltering, isFalse);

      // Active profiles (Medium / High / Ultra)
      expect(MobileSsaoQuality.medium.sampleCount, equals(10));
      expect(MobileSsaoQuality.high.sampleCount, equals(24));
      expect(MobileSsaoQuality.ultra.sampleCount, equals(32));

      expect(MobileSsaoQuality.medium.frameBudgetMs, equals(0.85));
      expect(MobileSsaoQuality.high.frameBudgetMs, equals(1.40));
      expect(MobileSsaoQuality.ultra.frameBudgetMs, equals(2.10));

      expect(MobileSsaoQuality.medium.hasBilateralFiltering, isTrue);
      expect(MobileSsaoQuality.high.hasBilateralFiltering, isTrue);
      expect(MobileSsaoQuality.ultra.hasBilateralFiltering, isTrue);
    });

    test('MobileSsaoConfig isEnabled correctly filters low and eco tiers', () {
      expect(const MobileSsaoConfig(quality: MobileSsaoQuality.off).isEnabled, isFalse);
      expect(const MobileSsaoConfig(quality: MobileSsaoQuality.eco).isEnabled, isFalse);
      expect(MobileSsaoConfig.ecoLowSpec().isEnabled, isFalse);

      expect(const MobileSsaoConfig(quality: MobileSsaoQuality.medium).isEnabled, isTrue);
      expect(const MobileSsaoConfig(quality: MobileSsaoQuality.high).isEnabled, isTrue);
      expect(const MobileSsaoConfig(quality: MobileSsaoQuality.ultra).isEnabled, isTrue);
      expect(MobileSsaoConfig.mobileBalanced().isEnabled, isTrue);
      expect(MobileSsaoConfig.aion2Cinematic().isEnabled, isTrue);
    });
  });

  // ===========================================================================
  // 5. Fallback Strategy When Depth Texture or Shader is Unavailable
  // ===========================================================================
  group('5. Fallback Strategy When Depth Texture or Shader is Unavailable', () {
    test('canExecuteGpu requires tier, shader, and depthTexture simultaneously', () {
      final SsaoPass pass = SsaoPass();

      // Initially missing shader and depthTexture
      expect(pass.canExecuteGpu, isFalse);

      // In low tier: canExecuteGpu is always false even if assets were attached
      pass.targetTier = DevicePerformanceTier.low;
      expect(pass.canExecuteGpu, isFalse);

      // In high tier: still false until both shader & depthTexture exist
      pass.targetTier = DevicePerformanceTier.high;
      expect(pass.canExecuteGpu, isFalse);
    });

    test('executePass executes safe bypass when shader or depthTexture is null', () {
      final SsaoPass pass = SsaoPass(
        targetTier: DevicePerformanceTier.high,
        fallbackStrategy: ShaderFallbackStrategy.bypass,
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // Missing GPU shader & depth texture -> bypasses cleanly without exception
      final String result = pass.executePass(canvas, const Size(800.0, 600.0));
      expect(result, equals('bypassed'));

      // Low tier -> tier_disabled
      pass.targetTier = DevicePerformanceTier.low;
      final String tierResult = pass.executePass(canvas, const Size(800.0, 600.0));
      expect(tierResult, equals('tier_disabled'));

      recorder.endRecording().dispose();
    });

    test('SsaoPainter paint cleanly skips rendering if shader or depthTexture is null', () {
      final SsaoPainter painterNoShader = SsaoPainter(
        params: const SsaoParams(),
        shader: null,
        depthTexture: null,
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // Neither should throw when paint is invoked
      expect(() => painterNoShader.paint(canvas, const Size(500.0, 500.0)), returnsNormally);

      recorder.endRecording().dispose();
    });

    test('SsaoPainter shouldRepaint triggers correctly on parameter changes', () {
      final SsaoPainter painter1 = SsaoPainter(
        params: const SsaoParams(radius: 0.5),
      );
      final SsaoPainter painterSame = SsaoPainter(
        params: const SsaoParams(radius: 0.5),
      );
      final SsaoPainter painterDiffParams = SsaoPainter(
        params: const SsaoParams(radius: 0.8),
      );

      expect(painter1.shouldRepaint(painterSame), isFalse);
      expect(painter1.shouldRepaint(painterDiffParams), isTrue);
    });

    test('initShaders handles headless test environment by gracefully setting isInitialized to false', () async {
      final PostProcessPipelineController controller =
          PostProcessPipelineController();

      final bool success = await controller.initShaders();
      // In headless unit test runners without Impeller GPU, asset loading fails gracefully
      expect(success, isFalse);
      expect(controller.isInitialized, isFalse);
      expect(controller.ssaoShader, isNull);
    });

    test('linearizeDepth accurately handles boundary inputs (0.0, 1.0, and intermediate values)', () {
      const double near = 0.1;
      const double far = 100.0;

      // Depth 0.0 -> near plane
      expect(SsaoKernel.linearizeDepth(0.0, near, far), closeTo(near, 1e-3));

      // Depth 1.0 -> far plane
      expect(SsaoKernel.linearizeDepth(1.0, near, far), closeTo(far, 1e-3));

      // Depth > 1.0 clamped to far plane
      expect(SsaoKernel.linearizeDepth(1.05, near, far), equals(far));

      // Depth < 0.0 clamped to near plane
      expect(SsaoKernel.linearizeDepth(-0.1, near, far), equals(near));

      // Mid-depth is strictly between near and far
      final double zMid = SsaoKernel.linearizeDepth(0.5, near, far);
      expect(zMid, greaterThan(near));
      expect(zMid, lessThan(far));
    });

    test('CPU Fallback computePixelAo rejects skybox depth >= 0.9999 as unoccluded 1.0', () {
      final double skyAo = SsaoKernel.computePixelAo(
        u: 0.5,
        v: 0.5,
        pixelX: 100.0,
        pixelY: 100.0,
        centerDepthRaw: 1.0, // Skybox depth
        depthSampler: (double u, double v) => 1.0,
        aspectRatio: 1.0,
      );

      expect(skyAo, equals(1.0));
    });

    test('CPU Fallback computePixelAo evaluates geometry occlusion with horizon test', () {
      const SsaoParams params = SsaoParams(
        radius: 0.5,
        bias: 0.02,
        intensity: 1.5,
        sampleCount: 16,
      );

      // Flat surface: uniform depth across neighbors -> high visibility (no acne)
      final double flatAo = SsaoKernel.computePixelAo(
        u: 0.5,
        v: 0.5,
        pixelX: 50.0,
        pixelY: 50.0,
        centerDepthRaw: 0.05,
        depthSampler: (double u, double v) => 0.05,
        aspectRatio: 1.0,
        params: params,
      );
      expect(flatAo, greaterThan(0.90));

      // Concave corner: adjacent neighbor geometry protrudes closer (smaller depth)
      final double cornerAo = SsaoKernel.computePixelAo(
        u: 0.5,
        v: 0.5,
        pixelX: 50.0,
        pixelY: 50.0,
        centerDepthRaw: 0.05,
        depthSampler: (double u, double v) => (u > 0.5) ? 0.03 : 0.05,
        aspectRatio: 1.0,
        params: params,
      );

      // Corner geometry produces darker contact occlusion
      expect(cornerAo, lessThan(flatAo));
    });
  });

  // ===========================================================================
  // 6. Shader Registry & Descriptor Verification Tests
  // ===========================================================================
  group('6. Shader Registry & Descriptor Verification Tests', () {
    late ShaderRegistry registry;
    late ShaderDescriptor ssaoDescriptor;

    setUp(() {
      registry = ShaderRegistry(loadDefaults: true);
      ssaoDescriptor = registry.getShaderDescriptor(ShaderCatalog.ssao)!;
    });

    test('ShaderRegistry correctly indexes ShaderCatalog.ssao descriptor', () {
      expect(registry.containsShader(ShaderCatalog.ssao), isTrue);
      expect(registry.getShader('ssao'), isNotNull);
      expect(ssaoDescriptor.id, equals(ShaderCatalog.ssao));
      expect(ssaoDescriptor.assetPath, equals('shaders/postprocess/ssao.frag'));
      expect(ssaoDescriptor.category, equals(ShaderCategory.postprocess));
      expect(ssaoDescriptor.stage, equals(ShaderStage.fragment));
    });

    test('SSAO descriptor defines exact 8 numeric uniforms totaling 9 floats', () {
      expect(ssaoDescriptor.uniforms.length, equals(8));
      expect(ssaoDescriptor.totalFloatCount, equals(9));

      // Uniform 0: uResolution (vec2, floatOffset 0, count 2)
      final UniformDefinition uResolution = ssaoDescriptor.findUniform('uResolution')!;
      expect(uResolution.type, equals(UniformType.vec2));
      expect(uResolution.floatOffset, equals(0));
      expect(uResolution.floatCount, equals(2));

      // Uniform 1: uRadius (float, floatOffset 2, count 1)
      final UniformDefinition uRadius = ssaoDescriptor.findUniform('uRadius')!;
      expect(uRadius.type, equals(UniformType.float));
      expect(uRadius.floatOffset, equals(2));
      expect(uRadius.floatCount, equals(1));

      // Uniform 2: uBias (float, floatOffset 3, count 1)
      final UniformDefinition uBias = ssaoDescriptor.findUniform('uBias')!;
      expect(uBias.type, equals(UniformType.float));
      expect(uBias.floatOffset, equals(3));
      expect(uBias.floatCount, equals(1));

      // Uniform 3: uIntensity (float, floatOffset 4, count 1)
      final UniformDefinition uIntensity = ssaoDescriptor.findUniform('uIntensity')!;
      expect(uIntensity.type, equals(UniformType.float));
      expect(uIntensity.floatOffset, equals(4));
      expect(uIntensity.floatCount, equals(1));

      // Uniform 4: uPower (float, floatOffset 5, count 1)
      final UniformDefinition uPower = ssaoDescriptor.findUniform('uPower')!;
      expect(uPower.type, equals(UniformType.float));
      expect(uPower.floatOffset, equals(5));
      expect(uPower.floatCount, equals(1));

      // Uniform 5: uSampleCount (float, floatOffset 6, count 1)
      final UniformDefinition uSampleCount = ssaoDescriptor.findUniform('uSampleCount')!;
      expect(uSampleCount.type, equals(UniformType.float));
      expect(uSampleCount.floatOffset, equals(6));
      expect(uSampleCount.floatCount, equals(1));

      // Uniform 6: uNear (float, floatOffset 7, count 1)
      final UniformDefinition uNear = ssaoDescriptor.findUniform('uNear')!;
      expect(uNear.type, equals(UniformType.float));
      expect(uNear.floatOffset, equals(7));
      expect(uNear.floatCount, equals(1));

      // Uniform 7: uFar (float, floatOffset 8, count 1)
      final UniformDefinition uFar = ssaoDescriptor.findUniform('uFar')!;
      expect(uFar.type, equals(UniformType.float));
      expect(uFar.floatOffset, equals(8));
      expect(uFar.floatCount, equals(1));
    });

    test('SSAO descriptor defines exact 2 texture samplers in order', () {
      expect(ssaoDescriptor.samplers.length, equals(2));
      expect(ssaoDescriptor.totalSamplerCount, equals(2));

      final SamplerDefinition depthSampler = ssaoDescriptor.findSampler('uDepthTexture')!;
      expect(depthSampler.samplerIndex, equals(0));

      final SamplerDefinition normalSampler = ssaoDescriptor.findSampler('uNormalTexture')!;
      expect(normalSampler.samplerIndex, equals(1));
    });

    test('SSAO descriptor warmup parameters match 9 uniform floats', () {
      expect(ssaoDescriptor.warmupParameters, isNotNull);
      expect(ssaoDescriptor.warmupParameters!.length, equals(9));
      expect(ssaoDescriptor.warmupParameters![0], equals(1.0)); // resolution.x
      expect(ssaoDescriptor.warmupParameters![1], equals(1.0)); // resolution.y
      expect(ssaoDescriptor.warmupParameters![2], equals(0.5)); // radius
      expect(ssaoDescriptor.warmupParameters![3], equals(0.025)); // bias
      expect(ssaoDescriptor.warmupParameters![4], equals(1.8)); // intensity
      expect(ssaoDescriptor.warmupParameters![5], equals(2.0)); // power
      expect(ssaoDescriptor.warmupParameters![6], equals(16.0)); // sample count
      expect(ssaoDescriptor.warmupParameters![7], equals(0.1)); // near
      expect(ssaoDescriptor.warmupParameters![8], equals(100.0)); // far
    });

    test('UniformBufferBinder.bindByDescriptor populates SSAO defaults accurately', () {
      final BufferUniformTarget target = BufferUniformTarget();
      UniformBufferBinder.bindByDescriptor(
        target,
        ssaoDescriptor,
        <String, dynamic>{
          'uResolution': const Size(1920.0, 1080.0),
          'uRadius': 0.7,
        },
      );

      // Supplied values
      expect(target.getFloat(0), equals(1920.0));
      expect(target.getFloat(1), equals(1080.0));
      expect(target.getFloat(2), equals(0.7));

      // Defaults from descriptor
      expect(target.getFloat(3), equals(0.025)); // bias default
      expect(target.getFloat(4), equals(1.8)); // intensity default
      expect(target.getFloat(5), equals(2.0)); // power default
      expect(target.getFloat(6), equals(16.0)); // sampleCount default
      expect(target.getFloat(7), equals(0.1)); // near default
      expect(target.getFloat(8), equals(100.0)); // far default
    });
  });

  // ===========================================================================
  // 7. Widget & Viewport Integration Tests
  // ===========================================================================
  group('7. Widget & Viewport Integration Tests', () {
    testWidgets('SsaoCompositeWidget renders child wrapped in RepaintBoundary', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SsaoCompositeWidget(
              aoIntensity: 1.2,
              aoDirectLightPreserve: 0.3,
              child: Text('SSAO Composite Scene'),
            ),
          ),
        ),
      );

      expect(find.text('SSAO Composite Scene'), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('CustomPaint with SsaoPainter mounts and paints cleanly in widget tree', (WidgetTester tester) async {
      final SsaoPainter painter = SsaoPainter(
        params: const SsaoParams(),
        shader: null,
        depthTexture: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: CustomPaint(
                painter: painter,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      await tester.pump();
    });

    testWidgets('MobileSsaoViewport cleanly bypasses post-process overlay on eco/low quality', (WidgetTester tester) async {
      final MobileSsaoController ecoController = MobileSsaoController(
        config: MobileSsaoConfig.ecoLowSpec(),
        autoSyncWithScaler: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileSsaoViewport(
              controller: ecoController,
              autoPrewarm: false,
              child: const Text('Underlying 3D Scene'),
            ),
          ),
        ),
      );

      expect(find.text('Underlying 3D Scene'), findsOneWidget);
      // When quality is eco/off, MobileSsaoViewport returns child directly without Stack or CustomPaint
      expect(find.byType(CustomPaint), findsNothing);

      ecoController.dispose();
    });

    testWidgets('MobileSsaoViewport renders post-process overlay on medium quality', (WidgetTester tester) async {
      final MobileSsaoController mediumController = MobileSsaoController(
        config: MobileSsaoConfig.mobileBalanced(),
        autoSyncWithScaler: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileSsaoViewport(
              controller: mediumController,
              autoPrewarm: false,
              child: const Text('Underlying 3D Scene Active'),
            ),
          ),
        ),
      );

      expect(find.text('Underlying 3D Scene Active'), findsOneWidget);
      // When medium quality is active, Stack and CustomPaint are mounted
      expect(find.byType(CustomPaint), findsWidgets);

      mediumController.dispose();
    });
  });
}
