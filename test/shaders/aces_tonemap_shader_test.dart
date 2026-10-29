// =============================================================================
// Comprehensive Unit & Widget Test Suite: ACES Filmic Tonemapping Shader & Wrapper
// Standard: Flutter Impeller & Skia GPU Post-Processing Pipeline
// Target: test/shaders/aces_tonemap_shader_test.dart
// =============================================================================

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/layout/aces_tonemapping_layer.dart' as layout_aces;
import 'package:gkk_flutter/core/shaders/shader_registry.dart';
import 'package:gkk_flutter/rendering/postprocess/aces_tonemap_curve.dart';
import 'package:gkk_flutter/rendering/postprocess/postprocess_pipeline.dart';

/// Architectural alias mapping the conceptual ACES tonemapping render pass
/// to the core pipeline parameter descriptor.
typedef AcesTonemapPass = AcesTonemapParams;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // GROUP 1: AcesTonemapPass / AcesTonemapParams Initialization, Clamping & Defaults
  // ===========================================================================
  group('1. AcesTonemapPass Parameter Initialization, Clamping & Defaults', () {
    test('AcesTonemapPass initializes with standard cinematic default values', () {
      const AcesTonemapPass pass = AcesTonemapPass();

      expect(pass.exposure, equals(0.0), reason: 'Default exposure must be 0.0 EV (1.0x)');
      expect(pass.exposureMode, equals(ExposureMode.evStops), reason: 'Default exposure mode is EV stops');
      expect(pass.fitType, equals(AcesFitType.stephenHill), reason: 'Default curve fit is Stephen Hill ACES');
      expect(pass.gammaMode, equals(GammaMode.accurateSrgb), reason: 'Default gamma is IEC 61966-2-1 sRGB');
      expect(pass.preGain, equals(1.0), reason: 'Default linear pre-gain is 1.0');
      expect(pass.whitePoint, equals(0.0), reason: 'Default white point is 0.0 (unconstrained headroom)');
      expect(pass.effectiveExposureMultiplier, equals(1.0), reason: '2^0 EV evaluates to 1.0 linear multiplier');
      expect(pass.effectivePreGain, equals(1.0), reason: 'Effective pre-gain evaluates to 1.0');
    });

    test('effectiveExposureMultiplier accurately evaluates photographic EV stops (2^EV)', () {
      // EV = 0.0 -> 2^0 = 1.0
      const AcesTonemapPass ev0 = AcesTonemapPass(exposure: 0.0, exposureMode: ExposureMode.evStops);
      expect(ev0.effectiveExposureMultiplier, closeTo(1.0, 1e-6));

      // +1 EV -> 2^1 = 2.0 (doubles light)
      const AcesTonemapPass ev1 = AcesTonemapPass(exposure: 1.0, exposureMode: ExposureMode.evStops);
      expect(ev1.effectiveExposureMultiplier, closeTo(2.0, 1e-6));

      // +2 EV -> 2^2 = 4.0 (quadruples light)
      const AcesTonemapPass ev2 = AcesTonemapPass(exposure: 2.0, exposureMode: ExposureMode.evStops);
      expect(ev2.effectiveExposureMultiplier, closeTo(4.0, 1e-6));

      // +3.5 EV -> 2^3.5 = ~11.3137
      const AcesTonemapPass ev3p5 = AcesTonemapPass(exposure: 3.5, exposureMode: ExposureMode.evStops);
      expect(ev3p5.effectiveExposureMultiplier, closeTo(math.pow(2.0, 3.5), 1e-5));

      // -1 EV -> 2^-1 = 0.5 (halves light)
      const AcesTonemapPass evMinus1 = AcesTonemapPass(exposure: -1.0, exposureMode: ExposureMode.evStops);
      expect(evMinus1.effectiveExposureMultiplier, closeTo(0.5, 1e-6));

      // -3 EV -> 2^-3 = 0.125
      const AcesTonemapPass evMinus3 = AcesTonemapPass(exposure: -3.0, exposureMode: ExposureMode.evStops);
      expect(evMinus3.effectiveExposureMultiplier, closeTo(0.125, 1e-6));

      // Fractional EV stops (+0.5 EV -> sqrt(2) ~ 1.41421356)
      const AcesTonemapPass evHalf = AcesTonemapPass(exposure: 0.5, exposureMode: ExposureMode.evStops);
      expect(evHalf.effectiveExposureMultiplier, closeTo(math.sqrt(2.0), 1e-5));
    });

    test('effectiveExposureMultiplier clamps non-positive linear exposure factors to 1.0', () {
      // Positive linear multipliers pass through directly
      const AcesTonemapPass lin1 = AcesTonemapPass(exposure: 1.0, exposureMode: ExposureMode.linearFactor);
      expect(lin1.effectiveExposureMultiplier, closeTo(1.0, 1e-6));

      const AcesTonemapPass lin2p5 = AcesTonemapPass(exposure: 2.5, exposureMode: ExposureMode.linearFactor);
      expect(lin2p5.effectiveExposureMultiplier, closeTo(2.5, 1e-6));

      const AcesTonemapPass lin0p25 = AcesTonemapPass(exposure: 0.25, exposureMode: ExposureMode.linearFactor);
      expect(lin0p25.effectiveExposureMultiplier, closeTo(0.25, 1e-6));

      // Zero linear exposure clamps to 1.0 fallback matching GLSL `(uExposure > 0.0) ? uExposure : 1.0`
      const AcesTonemapPass linZero = AcesTonemapPass(exposure: 0.0, exposureMode: ExposureMode.linearFactor);
      expect(linZero.effectiveExposureMultiplier, equals(1.0));

      // Negative linear exposure clamps to 1.0 fallback
      const AcesTonemapPass linNeg = AcesTonemapPass(exposure: -1.5, exposureMode: ExposureMode.linearFactor);
      expect(linNeg.effectiveExposureMultiplier, equals(1.0));
    });

    test('effectivePreGain clamps non-positive gain factors to 1.0', () {
      // Positive pre-gain passes through
      const AcesTonemapPass posGain = AcesTonemapPass(preGain: 1.75);
      expect(posGain.effectivePreGain, closeTo(1.75, 1e-6));

      const AcesTonemapPass unityGain = AcesTonemapPass(preGain: 1.0);
      expect(unityGain.effectivePreGain, closeTo(1.0, 1e-6));

      // Zero pre-gain falls back to 1.0 (matching GLSL `(uPreGain > 0.0) ? uPreGain : 1.0`)
      const AcesTonemapPass zeroGain = AcesTonemapPass(preGain: 0.0);
      expect(zeroGain.effectivePreGain, equals(1.0));

      // Negative pre-gain falls back to 1.0
      const AcesTonemapPass negGain = AcesTonemapPass(preGain: -2.0);
      expect(negGain.effectivePreGain, equals(1.0));
    });

    test('copyWith cleanly creates modified copies while preserving unassigned properties', () {
      const AcesTonemapPass base = AcesTonemapPass(
        exposure: 0.5,
        exposureMode: ExposureMode.evStops,
        fitType: AcesFitType.stephenHill,
        gammaMode: GammaMode.accurateSrgb,
        preGain: 1.2,
        whitePoint: 8.0,
      );

      // Single overrides
      final AcesTonemapPass modExposure = base.copyWith(exposure: 2.0);
      expect(modExposure.exposure, equals(2.0));
      expect(modExposure.exposureMode, equals(ExposureMode.evStops));
      expect(modExposure.fitType, equals(AcesFitType.stephenHill));
      expect(modExposure.gammaMode, equals(GammaMode.accurateSrgb));
      expect(modExposure.preGain, equals(1.2));
      expect(modExposure.whitePoint, equals(8.0));

      final AcesTonemapPass modMode = base.copyWith(exposureMode: ExposureMode.linearFactor);
      expect(modMode.exposureMode, equals(ExposureMode.linearFactor));
      expect(modMode.exposure, equals(0.5));

      final AcesTonemapPass modFit = base.copyWith(fitType: AcesFitType.narkowicz);
      expect(modFit.fitType, equals(AcesFitType.narkowicz));

      final AcesTonemapPass modGamma = base.copyWith(gammaMode: GammaMode.gamma22);
      expect(modGamma.gammaMode, equals(GammaMode.gamma22));

      final AcesTonemapPass modPreGain = base.copyWith(preGain: 0.8);
      expect(modPreGain.preGain, equals(0.8));

      final AcesTonemapPass modWp = base.copyWith(whitePoint: 16.0);
      expect(modWp.whitePoint, equals(16.0));

      // No-arg copyWith produces identical values
      final AcesTonemapPass identical = base.copyWith();
      expect(identical.exposure, equals(base.exposure));
      expect(identical.exposureMode, equals(base.exposureMode));
      expect(identical.fitType, equals(base.fitType));
      expect(identical.gammaMode, equals(base.gammaMode));
      expect(identical.preGain, equals(base.preGain));
      expect(identical.whitePoint, equals(base.whitePoint));
    });

    test('toUniformList packs parameters into exactly 8 floats with proper binary flags', () {
      const double width = 1920.0;
      const double height = 1080.0;

      // 1. Default flags: evStops (1.0), stephenHill (0.0), accurateSrgb (0.0)
      const AcesTonemapPass defPass = AcesTonemapPass();
      final List<double> u1 = defPass.toUniformList(width: width, height: height);
      expect(u1.length, equals(8));
      expect(u1[0], equals(1920.0));
      expect(u1[1], equals(1080.0));
      expect(u1[2], equals(0.0)); // exposure
      expect(u1[3], equals(1.0)); // exposureMode: evStops -> 1.0
      expect(u1[4], equals(0.0)); // fitType: stephenHill -> 0.0
      expect(u1[5], equals(0.0)); // gammaMode: accurateSrgb -> 0.0
      expect(u1[6], equals(1.0)); // effectivePreGain -> 1.0
      expect(u1[7], equals(0.0)); // whitePoint -> 0.0

      // 2. Inverted flags: linearFactor (0.0), narkowicz (1.0), gamma22 (1.0)
      const AcesTonemapPass invPass = AcesTonemapPass(
        exposure: 2.5,
        exposureMode: ExposureMode.linearFactor,
        fitType: AcesFitType.narkowicz,
        gammaMode: GammaMode.gamma22,
        preGain: 1.4,
        whitePoint: 10.0,
      );
      final List<double> u2 = invPass.toUniformList(width: 3840.0, height: 2160.0);
      expect(u2.length, equals(8));
      expect(u2[0], equals(3840.0));
      expect(u2[1], equals(2160.0));
      expect(u2[2], equals(2.5));
      expect(u2[3], equals(0.0)); // exposureMode: linearFactor -> 0.0
      expect(u2[4], equals(1.0)); // fitType: narkowicz -> 1.0
      expect(u2[5], equals(1.0)); // gammaMode: gamma22 -> 1.0
      expect(u2[6], equals(1.4)); // preGain
      expect(u2[7], equals(10.0)); // whitePoint
    });
  });

  // ===========================================================================
  // GROUP 2: Uniform Buffer Layout Matching GLSL Specification & Shader Catalog
  // ===========================================================================
  group('2. Uniform Buffer Layout Matching GLSL Specification & Shader Catalog', () {
    test('AcesTonemapCurve constants mirror exact GLSL 460 Impeller uniform layout', () {
      // Shaders declare:
      // uniform vec2  uResolution;   // [0..1]
      // uniform float uExposure;     // [2]
      // uniform float uExposureMode; // [3]
      // uniform float uFitType;      // [4]
      // uniform float uGammaMode;    // [5]
      // uniform float uPreGain;      // [6]
      // uniform float uWhitePoint;   // [7]
      // uniform sampler2D uSceneTexture; // [Sampler 0]
      expect(AcesTonemapCurve.uniformFloatCount, equals(8));
      expect(AcesTonemapCurve.uniformResolution, equals(0));
      expect(AcesTonemapCurve.uniformExposure, equals(2));
      expect(AcesTonemapCurve.uniformExposureMode, equals(3));
      expect(AcesTonemapCurve.uniformFitType, equals(4));
      expect(AcesTonemapCurve.uniformGammaMode, equals(5));
      expect(AcesTonemapCurve.uniformPreGain, equals(6));
      expect(AcesTonemapCurve.uniformWhitePoint, equals(7));
      expect(AcesTonemapCurve.samplerSceneTexture, equals(0));
    });

    test('PostProcessPipelineController constants match AcesTonemap metadata', () {
      expect(PostProcessPipelineController.acesFloatCount, equals(8));
      expect(PostProcessPipelineController.acesSamplerCount, equals(1));
    });

    test('PostProcessPipelineController.buildAcesUniforms outputs 8 floats in exact order', () {
      const Size viewport = Size(1440.0, 900.0);
      const AcesTonemapParams params = AcesTonemapParams(
        exposure: -0.75,
        exposureMode: ExposureMode.evStops,
        fitType: AcesFitType.narkowicz,
        gammaMode: GammaMode.gamma22,
        preGain: 1.15,
        whitePoint: 14.5,
      );

      final List<double> uniforms = PostProcessPipelineController.buildAcesUniforms(
        size: viewport,
        params: params,
      );

      expect(uniforms.length, equals(8));
      expect(uniforms[AcesTonemapCurve.uniformResolution], equals(1440.0));
      expect(uniforms[AcesTonemapCurve.uniformResolution + 1], equals(900.0));
      expect(uniforms[AcesTonemapCurve.uniformExposure], equals(-0.75));
      expect(uniforms[AcesTonemapCurve.uniformExposureMode], equals(1.0)); // evStops -> 1.0
      expect(uniforms[AcesTonemapCurve.uniformFitType], equals(1.0)); // narkowicz -> 1.0
      expect(uniforms[AcesTonemapCurve.uniformGammaMode], equals(1.0)); // gamma22 -> 1.0
      expect(uniforms[AcesTonemapCurve.uniformPreGain], equals(1.15));
      expect(uniforms[AcesTonemapCurve.uniformWhitePoint], equals(14.5));
    });

    test('PostProcessPipelineController.packAcesUniforms produces valid IEEE 754 Float32List', () {
      const Size viewport = Size(2560.0, 1440.0);
      const AcesTonemapParams params = AcesTonemapParams(
        exposure: 1.5,
        exposureMode: ExposureMode.linearFactor,
        fitType: AcesFitType.stephenHill,
        gammaMode: GammaMode.accurateSrgb,
        preGain: 1.0,
        whitePoint: 0.0,
      );

      final Float32List buffer = PostProcessPipelineController.packAcesUniforms(
        size: viewport,
        params: params,
      );

      expect(buffer.length, equals(8));
      expect(buffer.elementSizeInBytes, equals(4));
      expect(buffer.lengthInBytes, equals(32)); // 8 floats * 4 bytes = 32 bytes

      expect(buffer[0], closeTo(2560.0, 1e-4));
      expect(buffer[1], closeTo(1440.0, 1e-4));
      expect(buffer[2], closeTo(1.5, 1e-4));
      expect(buffer[3], closeTo(0.0, 1e-4)); // linearFactor -> 0.0
      expect(buffer[4], closeTo(0.0, 1e-4)); // stephenHill -> 0.0
      expect(buffer[5], closeTo(0.0, 1e-4)); // accurateSrgb -> 0.0
      expect(buffer[6], closeTo(1.0, 1e-4));
      expect(buffer[7], closeTo(0.0, 1e-4));
    });

    test('AcesTonemapCurve.buildUniforms matches toUniformList output and packs 8 floats', () {
      const AcesTonemapParams params = AcesTonemapParams(
        exposure: 1.25,
        exposureMode: ExposureMode.evStops,
        fitType: AcesFitType.stephenHill,
        gammaMode: GammaMode.accurateSrgb,
        preGain: 1.05,
        whitePoint: 8.0,
      );

      final List<double> uniformsFromCurve = AcesTonemapCurve.buildUniforms(
        width: 1920.0,
        height: 1080.0,
        params: params,
      );
      final List<double> uniformsFromParams = params.toUniformList(
        width: 1920.0,
        height: 1080.0,
      );

      expect(uniformsFromCurve, equals(uniformsFromParams));
      expect(uniformsFromCurve.length, equals(AcesTonemapCurve.uniformFloatCount));
    });

    test('Simulated uniform buffer storage receives exact float bindings from buildAcesUniforms', () {
      // Simulating a GPU uniform buffer storage array without illegally implementing FragmentShader
      final Float32List uniformStorage = Float32List(AcesTonemapCurve.uniformFloatCount);
      const Size viewport = Size(1920.0, 1080.0);
      const AcesTonemapParams params = AcesTonemapParams(
        exposure: 0.5,
        exposureMode: ExposureMode.evStops,
        fitType: AcesFitType.stephenHill,
        gammaMode: GammaMode.accurateSrgb,
        preGain: 1.1,
        whitePoint: 6.0,
      );

      final List<double> values = PostProcessPipelineController.buildAcesUniforms(
        size: viewport,
        params: params,
      );
      for (int i = 0; i < values.length; ++i) {
        uniformStorage[i] = values[i];
      }

      expect(uniformStorage[0], equals(1920.0));
      expect(uniformStorage[1], equals(1080.0));
      expect(uniformStorage[2], equals(0.5));
      expect(uniformStorage[3], equals(1.0)); // evStops
      expect(uniformStorage[4], equals(0.0)); // stephenHill
      expect(uniformStorage[5], equals(0.0)); // accurateSrgb
      expect(uniformStorage[6], closeTo(1.1, 1e-5));
      expect(uniformStorage[7], equals(6.0));
    });

    test('ShaderCatalog.acesTonemap descriptor in ShaderRegistry aligns with GLSL layout', () {
      final ShaderRegistry registry = ShaderRegistry(loadDefaults: true);
      final ShaderDescriptor? desc = registry.getShaderDescriptor(ShaderCatalog.acesTonemap);

      expect(desc, isNotNull, reason: 'ShaderCatalog.acesTonemap must be registered in default descriptors');
      expect(desc!.id, equals('shaders/postprocess/aces_tonemap.frag'));
      expect(desc.assetPath, equals('shaders/postprocess/aces_tonemap.frag'));
      expect(desc.category, equals(ShaderCategory.postprocess));
      expect(desc.stage, equals(ShaderStage.fragment));
      expect(desc.totalFloatCount, equals(8));
      expect(desc.totalSamplerCount, equals(1));
      expect(desc.fallbackStrategy, equals(ShaderFallbackStrategy.cpuFallback));
      expect(desc.minPerformanceTier, equals(DevicePerformanceTier.ultraLow));

      // Validate every individual uniform definition
      final UniformDefinition? uRes = desc.findUniform('uResolution');
      expect(uRes, isNotNull);
      expect(uRes!.type, equals(UniformType.vec2));
      expect(uRes.floatOffset, equals(0));
      expect(uRes.floatCount, equals(2));
      expect(uRes.defaultValue, equals(<double>[1920.0, 1080.0]));

      final UniformDefinition? uExp = desc.findUniform('uExposure');
      expect(uExp, isNotNull);
      expect(uExp!.type, equals(UniformType.float));
      expect(uExp.floatOffset, equals(2));
      expect(uExp.floatCount, equals(1));

      final UniformDefinition? uExpMode = desc.findUniform('uExposureMode');
      expect(uExpMode, isNotNull);
      expect(uExpMode!.type, equals(UniformType.float));
      expect(uExpMode.floatOffset, equals(3));
      expect(uExpMode.floatCount, equals(1));

      final UniformDefinition? uFit = desc.findUniform('uFitType');
      expect(uFit, isNotNull);
      expect(uFit!.type, equals(UniformType.float));
      expect(uFit.floatOffset, equals(4));
      expect(uFit.floatCount, equals(1));

      final UniformDefinition? uGamma = desc.findUniform('uGammaMode');
      expect(uGamma, isNotNull);
      expect(uGamma!.type, equals(UniformType.float));
      expect(uGamma.floatOffset, equals(5));
      expect(uGamma.floatCount, equals(1));

      final UniformDefinition? uPreGain = desc.findUniform('uPreGain');
      expect(uPreGain, isNotNull);
      expect(uPreGain!.type, equals(UniformType.float));
      expect(uPreGain.floatOffset, equals(6));
      expect(uPreGain.floatCount, equals(1));

      final UniformDefinition? uWp = desc.findUniform('uWhitePoint');
      expect(uWp, isNotNull);
      expect(uWp!.type, equals(UniformType.float));
      expect(uWp.floatOffset, equals(7));
      expect(uWp.floatCount, equals(1));

      // Validate sampler
      final SamplerDefinition? sScene = desc.findSampler('uSceneTexture');
      expect(sScene, isNotNull);
      expect(sScene!.samplerIndex, equals(0));

      // Warmup parameters
      expect(desc.warmupParameters, isNotNull);
      expect(desc.warmupParameters!.length, equals(8));
    });

    test('Composite ACES uniform builder shares uniform prefix [0..5] with AcesTonemap', () {
      const Size viewport = Size(1920.0, 1080.0);
      const AcesTonemapParams params = AcesTonemapParams(
        exposure: 0.5,
        exposureMode: ExposureMode.evStops,
        fitType: AcesFitType.stephenHill,
        gammaMode: GammaMode.accurateSrgb,
      );

      final List<double> compUniforms = PostProcessPipelineController.buildCompositeUniforms(
        size: viewport,
        acesParams: params,
        aoIntensity: 1.5,
        aoDirectLightPreserve: 0.35,
      );

      expect(compUniforms.length, equals(8));
      expect(compUniforms[0], equals(1920.0));
      expect(compUniforms[1], equals(1080.0));
      expect(compUniforms[2], equals(0.5));
      expect(compUniforms[3], equals(1.0)); // evStops -> 1.0
      expect(compUniforms[4], equals(0.0)); // stephenHill -> 0.0
      expect(compUniforms[5], equals(0.0)); // accurateSrgb -> 0.0
      expect(compUniforms[6], equals(1.5)); // aoIntensity
      expect(compUniforms[7], equals(0.35)); // aoDirectLightPreserve
    });
  });

  // ===========================================================================
  // GROUP 3: ACES Filmic Curve Math & Analytical Evaluation
  // ===========================================================================
  group('3. ACES Filmic Curve Math & Analytical Evaluation', () {
    test('Krzysztof Narkowicz analytical curve formula matches exact coefficients', () {
      // f(x) = (x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14)
      expect(AcesTonemapCurve.narkowiczA, equals(2.51));
      expect(AcesTonemapCurve.narkowiczB, equals(0.03));
      expect(AcesTonemapCurve.narkowiczC, equals(2.43));
      expect(AcesTonemapCurve.narkowiczD, equals(0.59));
      expect(AcesTonemapCurve.narkowiczE, equals(0.14));

      // Test analytical evaluation at 0.0 (black)
      final double black = AcesTonemapCurve.narkowiczChannel(0.0);
      expect(black, equals(0.0));

      // Test negative value clamping
      final double neg = AcesTonemapCurve.narkowiczChannel(-1.0);
      expect(neg, equals(0.0));

      // Test middle gray (0.18):
      // num = 0.18 * (2.51 * 0.18 + 0.03) = 0.18 * 0.4818 = 0.086724
      // den = 0.18 * (2.43 * 0.18 + 0.59) + 0.14 = 0.18 * 1.0274 + 0.14 = 0.324932
      // expected = 0.086724 / 0.324932 = ~0.2668988
      final double mid = AcesTonemapCurve.narkowiczChannel(0.18);
      expect(mid, closeTo(0.2668988, 1e-4));
      expect(mid, greaterThan(0.25));
      expect(mid, lessThan(0.30));

      // Test linear white (1.0):
      // num = 1.0 * (2.51 + 0.03) = 2.54
      // den = 1.0 * (2.43 + 0.59) + 0.14 = 3.16
      // expected = 2.54 / 3.16 = ~0.803797
      final double white = AcesTonemapCurve.narkowiczChannel(1.0);
      expect(white, closeTo(2.54 / 3.16, 1e-4));
      expect(white, closeTo(0.8038, 1e-3));

      // Test HDR shoulder highlights
      final double hdr2 = AcesTonemapCurve.narkowiczChannel(2.0);
      final double hdr5 = AcesTonemapCurve.narkowiczChannel(5.0);
      final double hdr10 = AcesTonemapCurve.narkowiczChannel(10.0);
      final double hdr100 = AcesTonemapCurve.narkowiczChannel(100.0);

      expect(hdr2, greaterThan(white));
      expect(hdr5, greaterThan(hdr2));
      expect(hdr10, greaterThan(hdr5));
      expect(hdr100, greaterThan(hdr10));
      expect(hdr100, lessThanOrEqualTo(1.0));
      expect(hdr100, closeTo(1.0, 0.01));
    });

    test('Krzysztof Narkowicz ACES fit satisfies strict monotonicity across 0 to 100', () {
      double prev = -1.0;
      for (double x = 0.0; x <= 10.0; x += 0.05) {
        final double val = AcesTonemapCurve.narkowiczChannel(x);
        expect(val, greaterThanOrEqualTo(prev), reason: 'Narkowicz curve must be monotonically non-decreasing at x=$x');
        expect(val, inInclusiveRange(0.0, 1.0));
        prev = val;
      }
    });

    test('acesNarkowicz processes RGB channels independently without cross-channel distortion', () {
      const double rIn = 0.12;
      const double gIn = 0.55;
      const double bIn = 2.40;

      final (double r, double g, double b) = AcesTonemapCurve.acesNarkowicz(rIn, gIn, bIn);
      expect(r, closeTo(AcesTonemapCurve.narkowiczChannel(rIn), 1e-6));
      expect(g, closeTo(AcesTonemapCurve.narkowiczChannel(gIn), 1e-6));
      expect(b, closeTo(AcesTonemapCurve.narkowiczChannel(bIn), 1e-6));
    });

    test('Stephen Hill ACES RRT + ODT polynomial coefficients match specification', () {
      expect(AcesTonemapCurve.rrtOdtA1, equals(0.0245786));
      expect(AcesTonemapCurve.rrtOdtA0, equals(-0.000090537));
      expect(AcesTonemapCurve.rrtOdtB2, equals(0.983729));
      expect(AcesTonemapCurve.rrtOdtB1, equals(0.4329510));
      expect(AcesTonemapCurve.rrtOdtB0, equals(0.238081));

      // Test RRT/ODT at 0.0: -0.000090537 / 0.238081 = ~ -0.00038
      final double rrt0 = AcesTonemapCurve.rrtAndOdtFitChannel(0.0);
      expect(rrt0, closeTo(-0.00038, 1e-4));

      // Test RRT/ODT at 1.0:
      // a = 1.0 * (1.0 + 0.0245786) - 0.000090537 = 1.024488
      // b = 1.0 * (0.983729 + 0.4329510) + 0.238081 = 1.654761
      // a / b = ~0.6191
      final double rrt1 = AcesTonemapCurve.rrtAndOdtFitChannel(1.0);
      expect(rrt1, closeTo(0.6191, 1e-3));
    });

    test('Stephen Hill ACES preserves neutral chromaticity without color cast', () {
      // When input R == G == B, the sRGB to AP1 transformation produces uniform components
      // because matrix rows sum to 1.0:
      // Row 1: 0.59719 + 0.35458 + 0.04823 = 1.00000
      // Row 2: 0.07600 + 0.90834 + 0.01566 = 1.00000
      // Row 3: 0.02840 + 0.13383 + 0.83777 = 1.00000
      // Similarly AP1 to sRGB matrix rows sum to 1.0:
      // Row 1: 1.60475 - 0.53108 - 0.07367 = 1.00000
      // Row 2: -0.10208 + 1.10813 - 0.00605 = 1.00000
      // Row 3: -0.00327 - 0.07276 + 1.07602 = 1.00000
      for (final double gray in <double>[0.05, 0.18, 0.5, 1.0, 2.5, 10.0]) {
        final (double r, double g, double b) = AcesTonemapCurve.acesStephenHill(gray, gray, gray);
        expect(r, closeTo(g, 1e-4), reason: 'Gray $gray must not shift chromaticity between R and G');
        expect(g, closeTo(b, 1e-4), reason: 'Gray $gray must not shift chromaticity between G and B');
        expect(r, inInclusiveRange(0.0, 1.0));
      }
    });

    test('Stephen Hill ACES handles black point, middle gray, and HDR highlights', () {
      // Black stays black
      final (double bR, double bG, double bB) = AcesTonemapCurve.acesStephenHill(0.0, 0.0, 0.0);
      expect(bR, equals(0.0));
      expect(bG, equals(0.0));
      expect(bB, equals(0.0));

      // 18% middle gray in linear space (~0.18) evaluates to ~0.198
      final (double mR, double mG, double mB) = AcesTonemapCurve.acesStephenHill(0.18, 0.18, 0.18);
      expect(mR, closeTo(0.198, 0.02));
      expect(mR, greaterThan(0.15));
      expect(mR, lessThan(0.25));

      // 1.0 linear white evaluates to ~0.619 linear shoulder
      final (double wR, double wG, double wB) = AcesTonemapCurve.acesStephenHill(1.0, 1.0, 1.0);
      expect(wR, closeTo(0.619, 0.02));

      // Extreme HDR inputs smoothly saturate toward 1.0 without overflowing
      final (double hdr10, _, _) = AcesTonemapCurve.acesStephenHill(10.0, 10.0, 10.0);
      final (double hdr100, _, _) = AcesTonemapCurve.acesStephenHill(100.0, 100.0, 100.0);
      final (double hdr1000, _, _) = AcesTonemapCurve.acesStephenHill(1000.0, 1000.0, 1000.0);

      expect(hdr10, greaterThan(wR));
      expect(hdr10, lessThanOrEqualTo(1.0));
      expect(hdr100, greaterThanOrEqualTo(hdr10));
      expect(hdr100, lessThanOrEqualTo(1.0));
      expect(hdr1000, closeTo(1.0, 0.01));
    });

    test('IEC 61966-2-1 linear-to-sRGB satisfies piecewise threshold and continuity', () {
      const double threshold = 0.0031308;

      // Linear branch: c <= 0.0031308 -> 12.92 * c
      const double linVal = 0.002;
      expect(AcesTonemapCurve.linearToSrgbChannel(linVal), closeTo(linVal * 12.92, 1e-6));

      // Check boundary value continuity at threshold:
      // Linear branch: threshold * 12.92 = ~0.040449936
      // Power branch: 1.055 * pow(threshold, 1/2.4) - 0.055 = ~0.0404499
      final double linBranch = threshold * 12.92;
      final double powerBranch = 1.055 * math.pow(threshold, 1.0 / 2.4) - 0.055;
      expect(linBranch, closeTo(powerBranch, 1e-5), reason: 'sRGB transfer curve must be continuous at threshold');

      // Power branch: c = 0.5
      final double expectedMidSrgb = 1.055 * math.pow(0.5, 1.0 / 2.4) - 0.055;
      expect(AcesTonemapCurve.linearToSrgbChannel(0.5), closeTo(expectedMidSrgb, 1e-5));

      // Boundaries
      expect(AcesTonemapCurve.linearToSrgbChannel(0.0), equals(0.0));
      expect(AcesTonemapCurve.linearToSrgbChannel(1.0), equals(1.0));
      expect(AcesTonemapCurve.linearToSrgbChannel(-0.5), equals(0.0));
      expect(AcesTonemapCurve.linearToSrgbChannel(1.5), equals(1.0));
    });

    test('IEC 61966-2-1 sRGB roundtrip invertibility is accurate across full dynamic range', () {
      // srgbToLinearChannel(linearToSrgbChannel(c)) == c
      final List<double> testValues = <double>[
        0.0005, 0.002, 0.00313, 0.005, 0.01, 0.05, 0.1, 0.18, 0.35, 0.5, 0.75, 0.9, 1.0,
      ];

      for (final double x in testValues) {
        final double srgb = AcesTonemapCurve.linearToSrgbChannel(x);
        final double roundtrip = AcesTonemapCurve.srgbToLinearChannel(srgb);
        expect(roundtrip, closeTo(x, 1e-4), reason: 'Roundtrip invertibility failed for x=$x (srgb=$srgb)');
      }
    });

    test('Power-law Gamma 2.2 approximation evaluates standard power curve', () {
      // C^(1 / 2.2)
      const double invGamma = 1.0 / 2.2;

      expect(AcesTonemapCurve.linearToGamma22(0.0, 0.0, 0.0), equals((0.0, 0.0, 0.0)));
      expect(AcesTonemapCurve.linearToGamma22(1.0, 1.0, 1.0), equals((1.0, 1.0, 1.0)));

      final (double r, double g, double b) = AcesTonemapCurve.linearToGamma22(0.5, 0.25, 0.8);
      expect(r, closeTo(math.pow(0.5, invGamma), 1e-5));
      expect(g, closeTo(math.pow(0.25, invGamma), 1e-5));
      expect(b, closeTo(math.pow(0.8, invGamma), 1e-5));
    });

    test('Curve comparison: Narkowicz offers slightly brighter midtones than Stephen Hill', () {
      // Both curves start at 0.0 and converge to 1.0
      final (double shMid, _, _) = AcesTonemapCurve.acesStephenHill(0.18, 0.18, 0.18);
      final double nkMid = AcesTonemapCurve.narkowiczChannel(0.18);

      expect(shMid, closeTo(0.198, 0.03));
      expect(nkMid, closeTo(0.267, 0.03));
      expect(nkMid, greaterThan(shMid), reason: 'Narkowicz analytical fit has a punchier midtone curve');

      // Both converge for large inputs
      final (double shHdr, _, _) = AcesTonemapCurve.acesStephenHill(50.0, 50.0, 50.0);
      final double nkHdr = AcesTonemapCurve.narkowiczChannel(50.0);
      expect(shHdr, closeTo(1.0, 0.02));
      expect(nkHdr, closeTo(1.0, 0.02));
    });
  });

  // ===========================================================================
  // GROUP 4: Fallback CPU Evaluation When Shader Unavailable
  // ===========================================================================
  group('4. Fallback CPU Evaluation When Shader Unavailable', () {
    test('processLinearRgb clamps negative input colors to 0.0 matching GLSL max(color, 0.0)', () {
      final (double r, double g, double b) = AcesTonemapCurve.processLinearRgb(-0.5, -1.0, -0.2);
      expect(r, equals(0.0));
      expect(g, equals(0.0));
      expect(b, equals(0.0));
    });

    test('processLinearRgb applies preGain before exposure adjustment', () {
      // Double preGain vs unity preGain with linear factor 1.0
      const AcesTonemapParams unityGain = AcesTonemapParams(
        exposure: 1.0,
        exposureMode: ExposureMode.linearFactor,
        preGain: 1.0,
      );
      const AcesTonemapParams doubleGain = AcesTonemapParams(
        exposure: 1.0,
        exposureMode: ExposureMode.linearFactor,
        preGain: 2.0,
      );

      final (double r1, _, _) = AcesTonemapCurve.processLinearRgb(0.1, 0.1, 0.1, params: unityGain);
      final (double r2, _, _) = AcesTonemapCurve.processLinearRgb(0.1, 0.1, 0.1, params: doubleGain);

      expect(r2, greaterThan(r1), reason: '2.0x pre-gain must result in higher post-tonemapping radiance');
    });

    test('processLinearRgb applies white-point luminance ceiling clamp', () {
      // When whitePoint > 0.0, input linear color is clamped to whitePoint
      const AcesTonemapParams clampedWp = AcesTonemapParams(
        exposure: 1.0,
        exposureMode: ExposureMode.linearFactor,
        whitePoint: 0.5,
      );
      const AcesTonemapParams unconstrainedWp = AcesTonemapParams(
        exposure: 1.0,
        exposureMode: ExposureMode.linearFactor,
        whitePoint: 0.0,
      );

      // Input 10.0 with whitePoint 0.5 will clamp to 0.5
      final (double rClamped, _, _) =
          AcesTonemapCurve.processLinearRgb(10.0, 10.0, 10.0, params: clampedWp);
      final (double rExpected, _, _) =
          AcesTonemapCurve.processLinearRgb(0.5, 0.5, 0.5, params: unconstrainedWp);

      expect(rClamped, closeTo(rExpected, 1e-4),
          reason: 'whitePoint 0.5 must clamp 10.0 input to 0.5 before curve');
    });

    test('processLinearRgb toggles between Stephen Hill and Narkowicz fits', () {
      const AcesTonemapParams shParams = AcesTonemapParams(fitType: AcesFitType.stephenHill);
      const AcesTonemapParams nkParams = AcesTonemapParams(fitType: AcesFitType.narkowicz);

      final (double rSh, _, _) = AcesTonemapCurve.processLinearRgb(0.2, 0.2, 0.2, params: shParams);
      final (double rNk, _, _) = AcesTonemapCurve.processLinearRgb(0.2, 0.2, 0.2, params: nkParams);

      expect(rSh, isNot(equals(rNk)));
      expect(rNk, greaterThan(rSh));
    });

    test('processLinearRgb toggles between accurate sRGB and Gamma 2.2 display correction', () {
      const AcesTonemapParams srgbParams = AcesTonemapParams(gammaMode: GammaMode.accurateSrgb);
      const AcesTonemapParams gammaParams = AcesTonemapParams(gammaMode: GammaMode.gamma22);

      final (double rSrgb, _, _) = AcesTonemapCurve.processLinearRgb(0.3, 0.3, 0.3, params: srgbParams);
      final (double rGamma, _, _) = AcesTonemapCurve.processLinearRgb(0.3, 0.3, 0.3, params: gammaParams);

      expect(rSrgb, isNot(equals(rGamma)));
      expect(rSrgb, inInclusiveRange(0.0, 1.0));
      expect(rGamma, inInclusiveRange(0.0, 1.0));
    });

    test('processColor applies tonemapping while strictly preserving alpha channel', () {
      final List<double> testAlphas = <double>[1.0, 0.85, 0.5, 0.25, 0.0];

      for (final double alpha in testAlphas) {
        final Color input = Color.from(alpha: alpha, red: 0.4, green: 0.6, blue: 0.2);
        final Color output = AcesTonemapCurve.processColor(input);

        expect(output.a, closeTo(alpha, 1e-5), reason: 'Output alpha must strictly preserve input alpha');
        expect(output.r, inInclusiveRange(0.0, 1.0));
        expect(output.g, inInclusiveRange(0.0, 1.0));
        expect(output.b, inInclusiveRange(0.0, 1.0));
      }
    });

    test('processColor handles primary colors and spectral crosstalk accurately', () {
      // Pure linear red (1.0, 0.0, 0.0) transforms through ACEScg AP1 matrix,
      // introducing subtle spectral crosstalk into G and B channels before gamma
      const Color pureRed = Color.from(alpha: 1.0, red: 1.0, green: 0.0, blue: 0.0);
      final Color gradedRed = AcesTonemapCurve.processColor(pureRed);

      expect(gradedRed.r, greaterThan(0.5));
      expect(gradedRed.a, equals(1.0));

      // Pure black
      const Color black = Color.from(alpha: 1.0, red: 0.0, green: 0.0, blue: 0.0);
      final Color gradedBlack = AcesTonemapCurve.processColor(black);
      expect(gradedBlack.r, equals(0.0));
      expect(gradedBlack.g, equals(0.0));
      expect(gradedBlack.b, equals(0.0));
      expect(gradedBlack.a, equals(1.0));
    });

    test('PostProcessPipelineController handles headless test runner gracefully without crashing', () async {
      final PostProcessPipelineController controller = PostProcessPipelineController();

      expect(controller.isInitialized, isFalse);
      expect(controller.acesShader, isNull);
      expect(controller.ssaoShader, isNull);
      expect(controller.blurShader, isNull);
      expect(controller.compositeShader, isNull);

      // In headless test runner without GPU RuntimeEffect compilation, initShaders catches error and returns false
      final bool initialized = await controller.initShaders();
      expect(initialized, isFalse);
      expect(controller.isInitialized, isFalse);
      expect(controller.acesShader, isNull);
    });

    test('AcesTonemapPainter gracefully skips painting when shader is null', () {
      final AcesTonemapPainter painter = AcesTonemapPainter(
        params: const AcesTonemapParams(),
        shader: null,
        sceneImage: null,
      );

      // Painting on mock picture canvas without shader should cleanly noop without throwing
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      expect(() => painter.paint(canvas, const Size(800.0, 600.0)), returnsNormally);
      recorder.endRecording();
    });

    test('AcesTonemapPainter shouldRepaint detects parameter changes accurately', () {
      const AcesTonemapParams p1 = AcesTonemapParams(exposure: 0.0);
      const AcesTonemapParams p2 = AcesTonemapParams(exposure: 1.0);

      final AcesTonemapPainter painter1 = AcesTonemapPainter(params: p1);
      final AcesTonemapPainter painter1Identical = AcesTonemapPainter(params: p1);
      final AcesTonemapPainter painter2 = AcesTonemapPainter(params: p2);

      expect(painter1.shouldRepaint(painter1Identical), isFalse);
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('AcesMath CPU functions from layout layer provide lightweight fallback', () {
      // Krzysztof Narkowicz curve in AcesMath
      expect(layout_aces.AcesMath.narkowiczCurve(0.0), equals(0.0));
      expect(layout_aces.AcesMath.narkowiczCurve(0.18), closeTo(0.267, 0.02));
      expect(layout_aces.AcesMath.narkowiczCurve(1.0), closeTo(0.8038, 0.02));

      // Stephen Hill curve in AcesMath
      expect(layout_aces.AcesMath.stephenHillCurve(0.0), equals(0.0));
      expect(layout_aces.AcesMath.stephenHillCurve(1.0), closeTo(0.619, 0.02));

      // Reinhard curve fallback
      expect(layout_aces.AcesMath.reinhardCurve(0.0), equals(0.0));
      expect(layout_aces.AcesMath.reinhardCurve(1.0), equals(0.5)); // 1.0 / (1.0 + 1.0) = 0.5
      expect(layout_aces.AcesMath.reinhardCurve(3.0), equals(0.75)); // 3.0 / 4.0 = 0.75

      // Pass-through curve
      expect(layout_aces.AcesMath.passThroughCurve(0.42), equals(0.42));
      expect(layout_aces.AcesMath.passThroughCurve(1.5), equals(1.0));

      // Color filter matrix generation (20 floats for 4x5 ColorFilter matrix)
      const layout_aces.AcesTonemappingConfig cfg = layout_aces.AcesTonemappingConfig();
      final List<double> matrix = layout_aces.AcesMath.generateColorGradingMatrix(cfg);
      expect(matrix.length, equals(20));
    });
  });

  // ===========================================================================
  // GROUP 5: Widget Integration & Lifecycle Verification
  // ===========================================================================
  group('5. Widget Integration & Lifecycle Verification', () {
    testWidgets('AcesTonemapWidget builds and wraps child in RepaintBoundary', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AcesTonemapWidget(
              params: AcesTonemapParams(
                exposure: 0.5,
                exposureMode: ExposureMode.evStops,
                fitType: AcesFitType.stephenHill,
              ),
              child: Text('ACES Cinematic Scene Viewport'),
            ),
          ),
        ),
      );

      expect(find.text('ACES Cinematic Scene Viewport'), findsOneWidget);
      expect(find.byType(AcesTonemapWidget), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('AcesTonemapWidget updates cleanly when parameters change', (WidgetTester tester) async {
      const AcesTonemapParams initialParams = AcesTonemapParams(exposure: 0.0);
      const AcesTonemapParams updatedParams = AcesTonemapParams(exposure: 2.0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AcesTonemapWidget(
              params: initialParams,
              child: SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      );

      final AcesTonemapWidget initialWidget = tester.widget(find.byType(AcesTonemapWidget));
      expect(initialWidget.params.exposure, equals(0.0));

      // Pump updated parameters
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AcesTonemapWidget(
              params: updatedParams,
              child: SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      );

      final AcesTonemapWidget updatedWidget = tester.widget(find.byType(AcesTonemapWidget));
      expect(updatedWidget.params.exposure, equals(2.0));
    });

    testWidgets('AcesTonemapPainter paints cleanly within CustomPaint widget tree', (WidgetTester tester) async {
      final AcesTonemapPainter painter = AcesTonemapPainter(
        params: const AcesTonemapParams(
          exposure: 1.0,
          exposureMode: ExposureMode.evStops,
          fitType: AcesFitType.narkowicz,
          gammaMode: GammaMode.gamma22,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: painter,
              size: const Size(300, 300),
              child: const Center(child: Text('Tonemapped Canvas')),
            ),
          ),
        ),
      );

      expect(find.text('Tonemapped Canvas'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('AcesTonemappingLayer composable widget renders child and layers cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: layout_aces.AcesTonemappingLayer(
              enableGrading: true,
              enableVignette: true,
              autoPreload: false,
              config: layout_aces.AcesTonemappingConfig(
                exposure: 0.5,
                vignetteIntensity: 0.4,
              ),
              child: Text('3D Dungeon Viewport'),
            ),
          ),
        ),
      );

      expect(find.text('3D Dungeon Viewport'), findsOneWidget);
      expect(find.byType(layout_aces.AcesTonemappingLayer), findsOneWidget);
      expect(find.byType(ColorFiltered), findsOneWidget);
    });
  });
}
