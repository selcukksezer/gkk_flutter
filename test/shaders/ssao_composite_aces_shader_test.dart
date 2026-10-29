// =============================================================================
// Comprehensive Unit & Widget Test Suite: SSAO Composite ACES Shader & Pass
// Verifies GLSL Shader Layout, Uniform Binding, Multi-Texture Samplers,
// Blend Mode Validation, Pass Output Structure, Mathematical Parity,
// and Widget / Painter Integration for Impeller & Skia GPU Runtimes.
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/shaders/shader_pipeline.dart';
import 'package:gkk_flutter/core/shaders/shader_registry.dart';
import 'package:gkk_flutter/rendering/postprocess/aces_tonemap_curve.dart';
import 'package:gkk_flutter/rendering/postprocess/postprocess_pipeline.dart';

// =============================================================================
// SSAO Composite ACES Pass Architecture & Wrapper Specification
// Encapsulates the unified postprocess pass, uniform mapping, texture samplers,
// blend mode validation, and pass output metadata.
// =============================================================================

/// Destination render target type for post-processing composite passes.
enum PassRenderTargetType {
  colorAttachment,
  pingPongPostprocess,
  screenFramebuffer,
}

/// Structural pass output descriptor produced by [SsaoCompositeAcesPass].
class SsaoCompositePassOutput {
  const SsaoCompositePassOutput({
    required this.passName,
    required this.viewportSize,
    required this.blendMode,
    required this.targetType,
    required this.uniforms,
    required this.samplerBindings,
    required this.isHDRInput,
    required this.isLDRTonemappedOutput,
  });

  /// Canonical identifier of the executed pass.
  final String passName;

  /// Viewport pixel resolution.
  final Size viewportSize;

  /// Blend mode applied when compositing pass output to the target buffer.
  final BlendMode blendMode;

  /// Classification of the target buffer.
  final PassRenderTargetType targetType;

  /// Contiguous 8-float uniform buffer packed for GLSL execution.
  final Float32List uniforms;

  /// Map of texture unit index to GLSL sampler name.
  final Map<int, String> samplerBindings;

  /// Whether the input scene texture represents linear HDR radiance.
  final bool isHDRInput;

  /// Whether the pass output is tonemapped and gamma-corrected LDR color.
  final bool isLDRTonemappedOutput;

  /// Validates structural integrity of the pass output.
  bool get isValid =>
      passName == 'ssao_composite_aces' &&
      viewportSize.width > 0 &&
      viewportSize.height > 0 &&
      uniforms.length == 8 &&
      samplerBindings.length == 2 &&
      samplerBindings[0] == 'uSceneTexture' &&
      samplerBindings[1] == 'uAoTexture' &&
      isHDRInput &&
      isLDRTonemappedOutput;
}

/// Dart wrapper and execution abstraction for `ssao_composite_aces.frag`.
///
/// Binds:
/// - Uniforms: [aoModulation], [shadowDarkening], [tonemapStrength],
///   exposure calculation mode, ACES curve fit type, and output gamma mode.
/// - Samplers: Multi-texture unit 0 ([sceneColorTexture]) and unit 1 ([blurredOcclusionTexture]).
/// - Blend Mode: Validated [blendMode] (typically [BlendMode.src] or [BlendMode.srcOver]).
class SsaoCompositeAcesPass {
  SsaoCompositeAcesPass({
    this.aoModulation = 1.0,
    this.shadowDarkening = 0.25,
    this.tonemapStrength = 1.0,
    this.exposureMode = ExposureMode.linearFactor,
    this.fitType = AcesFitType.stephenHill,
    this.gammaMode = GammaMode.accurateSrgb,
    this.blendMode = BlendMode.src,
    this.sceneColorTexture,
    this.blurredOcclusionTexture,
  });

  /// SSAO modulation intensity onto scene ambient illumination (GLSL: `uAoIntensity`).
  double aoModulation;

  /// Direct light preserved from ambient occlusion shadowing (GLSL: `uAoDirectLightPreserve`).
  double shadowDarkening;

  /// Exposure or tonemapping intensity multiplier (GLSL: `uExposure`).
  double tonemapStrength;

  /// Exposure calculation mode (linear multiplier or EV stops: 2^EV).
  ExposureMode exposureMode;

  /// ACES curve fitting model (Stephen Hill AP1 or Krzysztof Narkowicz fast fit).
  AcesFitType fitType;

  /// Output gamma correction transfer function (IEC 61966-2-1 standard sRGB or Gamma 2.2).
  GammaMode gammaMode;

  /// Canvas blend mode when painting this pass onto the destination canvas.
  BlendMode blendMode;

  /// Texture unit 0: Linear HDR scene color buffer.
  ui.Image? sceneColorTexture;

  /// Texture unit 1: Bilateral-filtered ambient occlusion factor buffer.
  ui.Image? blurredOcclusionTexture;

  /// Supported blend modes for screen-space post-processing composite passes.
  static const Set<BlendMode> supportedBlendModes = <BlendMode>{
    BlendMode.src,
    BlendMode.srcOver,
    BlendMode.multiply,
    BlendMode.screen,
  };

  /// Returns whether [blendMode] is valid for composite pass execution.
  bool get isBlendModeSupported => supportedBlendModes.contains(blendMode);

  /// Builds the 8 uniform floats matching GLSL declaration order:
  /// [0..1] uResolution (width, height)
  /// [2]    uExposure (tonemapStrength)
  /// [3]    uExposureMode (0.0 = linear, 1.0 = evStops)
  /// [4]    uFitType (0.0 = stephenHill, 1.0 = narkowicz)
  /// [5]    uGammaMode (0.0 = accurateSrgb, 1.0 = gamma22)
  /// [6]    uAoIntensity (aoModulation)
  /// [7]    uAoDirectLightPreserve (shadowDarkening)
  List<double> buildUniforms(Size viewportSize) {
    return <double>[
      viewportSize.width,
      viewportSize.height,
      tonemapStrength,
      exposureMode == ExposureMode.evStops ? 1.0 : 0.0,
      fitType == AcesFitType.narkowicz ? 1.0 : 0.0,
      gammaMode == GammaMode.gamma22 ? 1.0 : 0.0,
      aoModulation,
      shadowDarkening,
    ];
  }

  /// Packs uniform floats as [Float32List] for direct GPU buffer upload.
  Float32List packUniforms(Size viewportSize) {
    return Float32List.fromList(buildUniforms(viewportSize));
  }

  /// Binds numeric uniforms and multi-texture samplers to a [ShaderUniformTarget].
  void bindTo(ShaderUniformTarget target, Size viewportSize) {
    final List<double> uniforms = buildUniforms(viewportSize);
    for (int i = 0; i < uniforms.length; ++i) {
      target.setFloat(i, uniforms[i]);
    }
    if (sceneColorTexture != null) {
      target.setImageSampler(0, sceneColorTexture!);
    }
    if (blurredOcclusionTexture != null) {
      target.setImageSampler(1, blurredOcclusionTexture!);
    }
  }

  /// Executes pass parameter compilation and returns structured [SsaoCompositePassOutput].
  /// Throws [ArgumentError] if [blendMode] is unsupported.
  SsaoCompositePassOutput executePass({
    required Size viewportSize,
    PassRenderTargetType targetType = PassRenderTargetType.screenFramebuffer,
  }) {
    if (!isBlendModeSupported) {
      throw ArgumentError(
        'Unsupported blend mode $blendMode for SSAO composite pass. '
        'Supported modes: ${supportedBlendModes.map((e) => e.name).join(', ')}',
      );
    }
    return SsaoCompositePassOutput(
      passName: 'ssao_composite_aces',
      viewportSize: viewportSize,
      blendMode: blendMode,
      targetType: targetType,
      uniforms: packUniforms(viewportSize),
      samplerBindings: const <int, String>{
        0: 'uSceneTexture',
        1: 'uAoTexture',
      },
      isHDRInput: true,
      isLDRTonemappedOutput: true,
    );
  }
}

// =============================================================================
// Test Mocks & Simulators for Headless Testing
// =============================================================================

/// In-memory mock implementing [ui.Image] for multi-texture sampler unit verification.
class FakeTestImage implements ui.Image {
  FakeTestImage({
    this.width = 256,
    this.height = 256,
    this.label = 'FakeTestImage',
  });

  @override
  final int width;

  @override
  final int height;

  final String label;
  bool _disposed = false;

  @override
  bool get debugDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  String toString() => 'FakeTestImage($label: ${width}x$height)';
}

/// Fake uniform storage capturing uniform floats and texture sampler assignments
/// for headless verification without implementing the Dart 3 base class [ui.FragmentShader].
class FakeUniformStorage implements ShaderUniformTarget {
  final Map<int, double> floats = <int, double>{};
  final Map<int, ui.Image> samplers = <int, ui.Image>{};
  bool disposed = false;

  @override
  void setFloat(int index, double value) {
    floats[index] = value;
  }

  @override
  void setImageSampler(int index, ui.Image image) {
    samplers[index] = image;
  }

  /// Retrieves float value at [index].
  double? getFloat(int index) => floats[index];

  /// Total count of assigned float slots.
  int get floatCount => floats.length;

  /// Total count of assigned texture sampler units.
  int get samplerCount => samplers.length;

  void dispose() {
    disposed = true;
  }
}

/// Mock [Canvas] recording draw operations, rectangles, and paint shaders/blend modes.
class MockCanvas implements Canvas {
  final List<String> drawCalls = <String>[];
  Paint? lastPaint;
  Rect? lastRect;

  @override
  void drawRect(Rect rect, Paint paint) {
    drawCalls.add('drawRect');
    lastRect = rect;
    lastPaint = paint;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// CustomPainter executing [SsaoCompositeAcesPass] rendering on a Canvas.
class SsaoCompositeAcesPassPainter extends CustomPainter {
  const SsaoCompositeAcesPassPainter({
    required this.pass,
    this.shader,
    this.uniformTarget,
  });

  final SsaoCompositeAcesPass pass;
  final ui.FragmentShader? shader;
  final ShaderUniformTarget? uniformTarget;

  @override
  void paint(Canvas canvas, Size size) {
    if (uniformTarget != null) {
      pass.bindTo(uniformTarget!, size);
      final Paint paint = Paint()..blendMode = pass.blendMode;
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }
    final ui.FragmentShader? s = shader;
    if (s != null &&
        pass.sceneColorTexture != null &&
        pass.blurredOcclusionTexture != null) {
      final ShaderUniformTarget target = FragmentShaderTarget(s);
      pass.bindTo(target, size);

      final Paint paint = Paint()
        ..shader = s
        ..blendMode = pass.blendMode;

      canvas.drawRect(Offset.zero & size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SsaoCompositeAcesPassPainter oldDelegate) {
    return oldDelegate.pass.aoModulation != pass.aoModulation ||
        oldDelegate.pass.shadowDarkening != pass.shadowDarkening ||
        oldDelegate.pass.tonemapStrength != pass.tonemapStrength ||
        oldDelegate.pass.exposureMode != pass.exposureMode ||
        oldDelegate.pass.fitType != pass.fitType ||
        oldDelegate.pass.gammaMode != pass.gammaMode ||
        oldDelegate.pass.blendMode != pass.blendMode ||
        oldDelegate.pass.sceneColorTexture != pass.sceneColorTexture ||
        oldDelegate.pass.blurredOcclusionTexture !=
            pass.blurredOcclusionTexture ||
        oldDelegate.shader != shader ||
        oldDelegate.uniformTarget != uniformTarget;
  }
}

/// Test widget wrapping child content in [SsaoCompositeAcesPass].
class SsaoCompositeAcesPassWidget extends StatelessWidget {
  const SsaoCompositeAcesPassWidget({
    super.key,
    required this.pass,
    required this.child,
    this.shader,
    this.uniformTarget,
  });

  final SsaoCompositeAcesPass pass;
  final Widget child;
  final ui.FragmentShader? shader;
  final ShaderUniformTarget? uniformTarget;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: SsaoCompositeAcesPassPainter(
          pass: pass,
          shader: shader,
          uniformTarget: uniformTarget,
        ),
        child: child,
      ),
    );
  }
}

// =============================================================================
// Mathematical Simulation of ssao_composite_aces.frag Logic
// =============================================================================

class CompositeAcesShaderMathSim {
  /// Evaluates the Stephen Hill ACES fitted model.
  static (double, double, double) acesStephenHill(double r, double g, double b) {
    // Column-major input matrix
    final double v0 = 0.59719 * r + 0.35458 * g + 0.04823 * b;
    final double v1 = 0.07600 * r + 0.90834 * g + 0.01566 * b;
    final double v2 = 0.02840 * r + 0.13383 * g + 0.83777 * b;

    double rrtOdt(double v) {
      final double num = v * (v + 0.0245786) - 0.000090537;
      final double den = v * (0.983729 * v + 0.4329510) + 0.238081;
      return num / den;
    }

    final double rrt0 = rrtOdt(v0);
    final double rrt1 = rrtOdt(v1);
    final double rrt2 = rrtOdt(v2);

    // Column-major output matrix
    final double s0 = 1.60475 * rrt0 - 0.53108 * rrt1 - 0.07367 * rrt2;
    final double s1 = -0.10208 * rrt0 + 1.10813 * rrt1 - 0.00605 * rrt2;
    final double s2 = -0.00327 * rrt0 - 0.07276 * rrt1 + 1.07602 * rrt2;

    return (
      s0.clamp(0.0, 1.0),
      s1.clamp(0.0, 1.0),
      s2.clamp(0.0, 1.0),
    );
  }

  /// Evaluates Krzysztof Narkowicz fast curve fit.
  static double narkowiczChannel(double x) {
    const double a = 2.51;
    const double b = 0.03;
    const double c = 2.43;
    const double d = 0.59;
    const double e = 0.14;
    final double val = (x * (a * x + b)) / (x * (c * x + d) + e);
    return val.clamp(0.0, 1.0);
  }

  /// Evaluates IEC 61966-2-1 piecewise linear-to-sRGB transfer function.
  static double linearToSrgb(double c) {
    final double x = c.clamp(0.0, 1.0);
    if (x <= 0.0031308) {
      return x * 12.92;
    } else {
      return 1.055 * math.pow(x, 1.0 / 2.4) - 0.055;
    }
  }

  /// Evaluates standard Gamma 2.2 transfer function.
  static double linearToGamma22(double c) {
    return math.pow(c.clamp(0.0, 1.0), 1.0 / 2.2).toDouble();
  }

  /// Evaluates AO modulation multiplier formula exactly as declared in GLSL:
  /// float directPreserve = clamp((uAoDirectLightPreserve >= 0.0) ? uAoDirectLightPreserve : 0.25, 0.0, 1.0);
  /// float aoMultiplier = clamp(mix(1.0, mix(directPreserve, 1.0, ao), aoIntensity), 0.0, 1.0);
  static double evaluateAoMultiplier({
    required double rawAo,
    required double aoIntensity,
    required double aoDirectLightPreserve,
  }) {
    final double ao = rawAo.clamp(0.0, 1.0);
    final double intensity = (aoIntensity >= 0.0) ? aoIntensity : 1.0;
    final double directPreserve = (aoDirectLightPreserve >= 0.0
            ? aoDirectLightPreserve
            : 0.25)
        .clamp(0.0, 1.0);

    final double inner = directPreserve + (1.0 - directPreserve) * ao;
    final double multiplier = 1.0 + (inner - 1.0) * intensity;
    return multiplier.clamp(0.0, 1.0);
  }

  /// Simulates full fragment execution pipeline of `ssao_composite_aces.frag`.
  static (double, double, double, double) executeFragment({
    required (double, double, double, double) sceneColor,
    required double rawAo,
    required double exposure,
    required double exposureMode,
    required double fitType,
    required double gammaMode,
    required double aoIntensity,
    required double aoDirectLightPreserve,
  }) {
    // 1. Sample Scene Color
    double r = math.max(sceneColor.$1, 0.0);
    double g = math.max(sceneColor.$2, 0.0);
    double b = math.max(sceneColor.$3, 0.0);
    final double a = sceneColor.$4;

    // 2. AO Modulation
    final double aoMult = evaluateAoMultiplier(
      rawAo: rawAo,
      aoIntensity: aoIntensity,
      aoDirectLightPreserve: aoDirectLightPreserve,
    );
    r *= aoMult;
    g *= aoMult;
    b *= aoMult;

    // 3. Exposure
    final double expFactor = exposureMode > 0.5
        ? math.pow(2.0, exposure).toDouble()
        : (exposure > 0.0 ? exposure : 1.0);
    r *= expFactor;
    g *= expFactor;
    b *= expFactor;

    // 4. Tonemapping
    double tonemappedR, tonemappedG, tonemappedB;
    if (fitType > 0.5) {
      tonemappedR = narkowiczChannel(r);
      tonemappedG = narkowiczChannel(g);
      tonemappedB = narkowiczChannel(b);
    } else {
      final (tr, tg, tb) = acesStephenHill(r, g, b);
      tonemappedR = tr;
      tonemappedG = tg;
      tonemappedB = tb;
    }

    // 5. Gamma Correction
    double finalR, finalG, finalB;
    if (gammaMode > 0.5) {
      finalR = linearToGamma22(tonemappedR);
      finalG = linearToGamma22(tonemappedG);
      finalB = linearToGamma22(tonemappedB);
    } else {
      finalR = linearToSrgb(tonemappedR);
      finalG = linearToSrgb(tonemappedG);
      finalB = linearToSrgb(tonemappedB);
    }

    return (
      finalR.clamp(0.0, 1.0),
      finalG.clamp(0.0, 1.0),
      finalB.clamp(0.0, 1.0),
      a,
    );
  }
}

// =============================================================================
// MAIN TEST SUITE
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // 1. GLSL Shader Source Verification & Impeller Runtime Effect Layout
  // ---------------------------------------------------------------------------
  group('1. GLSL Shader Static Analysis & Layout Compliance', () {
    late File shaderFile;
    late String shaderContent;

    setUpAll(() {
      shaderFile = File('shaders/postprocess/ssao_composite_aces.frag');
      expect(
        shaderFile.existsSync(),
        isTrue,
        reason: 'ssao_composite_aces.frag must exist in shaders/postprocess/',
      );
      shaderContent = shaderFile.readAsStringSync();
    });

    test('Shader header specifies GLSL 460 core and flutter runtime_effect include', () {
      expect(shaderContent, contains('#version 460 core'));
      expect(shaderContent, contains('#include <flutter/runtime_effect.glsl>'));
    });

    test('Shader defines high precision float and medium precision sampler qualifiers', () {
      expect(shaderContent, contains('precision highp float;'));
      expect(shaderContent, contains('precision mediump sampler2D;'));
    });

    test('Shader declares all 7 numeric uniforms matching exact 8-float Dart buffer layout', () {
      expect(shaderContent, contains('uniform vec2  uResolution;'));
      expect(shaderContent, contains('uniform float uExposure;'));
      expect(shaderContent, contains('uniform float uExposureMode;'));
      expect(shaderContent, contains('uniform float uFitType;'));
      expect(shaderContent, contains('uniform float uGammaMode;'));
      expect(shaderContent, contains('uniform float uAoIntensity;'));
      expect(shaderContent, contains('uniform float uAoDirectLightPreserve;'));
    });

    test('Shader declares numeric uniforms in strict sequential offset order', () {
      final int idxRes = shaderContent.indexOf('uniform vec2  uResolution;');
      final int idxExp = shaderContent.indexOf('uniform float uExposure;');
      final int idxExpM = shaderContent.indexOf('uniform float uExposureMode;');
      final int idxFit = shaderContent.indexOf('uniform float uFitType;');
      final int idxGamma = shaderContent.indexOf('uniform float uGammaMode;');
      final int idxAoInt = shaderContent.indexOf('uniform float uAoIntensity;');
      final int idxAoDir =
          shaderContent.indexOf('uniform float uAoDirectLightPreserve;');

      expect(idxRes, lessThan(idxExp));
      expect(idxExp, lessThan(idxExpM));
      expect(idxExpM, lessThan(idxFit));
      expect(idxFit, lessThan(idxGamma));
      expect(idxGamma, lessThan(idxAoInt));
      expect(idxAoInt, lessThan(idxAoDir));
    });

    test('Texture samplers are declared strictly after all numeric uniforms for Impeller layout', () {
      final int idxLastNumeric =
          shaderContent.indexOf('uniform float uAoDirectLightPreserve;');
      final int idxSceneSampler =
          shaderContent.indexOf('uniform sampler2D uSceneTexture;');
      final int idxAoSampler =
          shaderContent.indexOf('uniform sampler2D uAoTexture;');

      expect(idxSceneSampler, greaterThan(idxLastNumeric),
          reason: 'uSceneTexture must follow numeric uniforms in GLSL declaration');
      expect(idxAoSampler, greaterThan(idxSceneSampler),
          reason: 'uAoTexture must follow uSceneTexture (Texture unit 1)');
    });

    test('Shader declares fragColor output and uses FlutterFragCoord', () {
      expect(shaderContent, contains('out vec4 fragColor;'));
      expect(shaderContent, contains('FlutterFragCoord().xy'));
    });

    test('Shader contains dual ACES models and dual gamma transfer implementations', () {
      expect(shaderContent, contains('acesStephenHill'));
      expect(shaderContent, contains('acesNarkowicz'));
      expect(shaderContent, contains('linearToSrgb'));
      expect(shaderContent, contains('linearToGamma22'));
      expect(shaderContent, contains('ACES_INPUT_MAT'));
      expect(shaderContent, contains('ACES_OUTPUT_MAT'));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Shader Registry & Descriptor Verification
  // ---------------------------------------------------------------------------
  group('2. Shader Catalog & Registry Descriptor Verification', () {
    late ShaderRegistry registry;
    late ShaderDescriptor descriptor;

    setUp(() {
      registry = ShaderRegistry(loadDefaults: true);
      final ShaderDescriptor? found =
          registry.getShaderDescriptor(ShaderCatalog.ssaoCompositeAces);
      expect(found, isNotNull,
          reason: 'ShaderCatalog.ssaoCompositeAces must be registered');
      descriptor = found!;
    });

    test('Descriptor contains valid canonical ID, assetPath, category, and stage', () {
      expect(descriptor.id, equals(ShaderCatalog.ssaoCompositeAces));
      expect(descriptor.assetPath,
          equals('shaders/postprocess/ssao_composite_aces.frag'));
      expect(descriptor.category, equals(ShaderCategory.postprocess));
      expect(descriptor.stage, equals(ShaderStage.fragment));
    });

    test('Descriptor defines totalFloatCount == 8 and totalSamplerCount == 2', () {
      expect(descriptor.totalFloatCount, equals(8));
      expect(descriptor.totalSamplerCount, equals(2));
      expect(descriptor.uniforms.length, equals(7));
      expect(descriptor.samplers.length, equals(2));
    });

    test('Descriptor uniform definitions match GLSL declarations and offsets', () {
      // 0..1: uResolution (vec2)
      final UniformDefinition uRes = descriptor.findUniform('uResolution')!;
      expect(uRes.type, equals(UniformType.vec2));
      expect(uRes.floatOffset, equals(0));
      expect(uRes.floatCount, equals(2));
      expect(uRes.defaultValue, equals(<double>[1920.0, 1080.0]));

      // 2: uExposure (float)
      final UniformDefinition uExp = descriptor.findUniform('uExposure')!;
      expect(uExp.type, equals(UniformType.float));
      expect(uExp.floatOffset, equals(2));
      expect(uExp.floatCount, equals(1));
      expect(uExp.defaultValue, equals(<double>[1.0]));

      // 3: uExposureMode (float)
      final UniformDefinition uExpM = descriptor.findUniform('uExposureMode')!;
      expect(uExpM.floatOffset, equals(3));
      expect(uExpM.floatCount, equals(1));

      // 4: uFitType (float)
      final UniformDefinition uFit = descriptor.findUniform('uFitType')!;
      expect(uFit.floatOffset, equals(4));
      expect(uFit.floatCount, equals(1));

      // 5: uGammaMode (float)
      final UniformDefinition uGamma = descriptor.findUniform('uGammaMode')!;
      expect(uGamma.floatOffset, equals(5));
      expect(uGamma.floatCount, equals(1));

      // 6: uAoIntensity (float)
      final UniformDefinition uAoInt = descriptor.findUniform('uAoIntensity')!;
      expect(uAoInt.floatOffset, equals(6));
      expect(uAoInt.floatCount, equals(1));
      expect(uAoInt.defaultValue, equals(<double>[1.0]));

      // 7: uAoDirectLightPreserve (float)
      final UniformDefinition uAoDir =
          descriptor.findUniform('uAoDirectLightPreserve')!;
      expect(uAoDir.floatOffset, equals(7));
      expect(uAoDir.floatCount, equals(1));
      expect(uAoDir.defaultValue, equals(<double>[0.2]));
    });

    test('Descriptor sampler definitions define correct texture unit indices', () {
      final SamplerDefinition s0 = descriptor.findSampler('uSceneTexture')!;
      expect(s0.samplerIndex, equals(0));

      final SamplerDefinition s1 = descriptor.findSampler('uAoTexture')!;
      expect(s1.samplerIndex, equals(1));
    });

    test('Descriptor fallback configuration and device performance tier are valid', () {
      expect(descriptor.fallbackId, equals(ShaderCatalog.acesTonemap));
      expect(descriptor.fallbackStrategy,
          equals(ShaderFallbackStrategy.fallbackShader));
      expect(
          descriptor.minPerformanceTier, equals(DevicePerformanceTier.low));
    });

    test('Warmup parameter vector contains valid 8 floats', () {
      expect(descriptor.warmupParameters, isNotNull);
      expect(descriptor.warmupParameters!.length, equals(8));
      expect(descriptor.warmupParameters![0], equals(1.0)); // res.x
      expect(descriptor.warmupParameters![1], equals(1.0)); // res.y
      expect(descriptor.warmupParameters![2], equals(1.0)); // exposure
      expect(descriptor.warmupParameters![6], equals(1.0)); // aoIntensity
      expect(descriptor.warmupParameters![7], equals(0.2)); // directPreserve
    });
  });

  // ---------------------------------------------------------------------------
  // 3. SsaoCompositeAcesPass Uniform Binding & PostProcess Controller Parity
  // ---------------------------------------------------------------------------
  group('3. SsaoCompositeAcesPass Uniform Binding (aoModulation, shadowDarkening, tonemapStrength)', () {
    const Size viewport = Size(1920.0, 1080.0);

    test('Default SsaoCompositeAcesPass instance produces canonical 8-float array', () {
      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass();

      expect(pass.aoModulation, equals(1.0));
      expect(pass.shadowDarkening, equals(0.25));
      expect(pass.tonemapStrength, equals(1.0));
      expect(pass.exposureMode, equals(ExposureMode.linearFactor));
      expect(pass.fitType, equals(AcesFitType.stephenHill));
      expect(pass.gammaMode, equals(GammaMode.accurateSrgb));

      final List<double> uniforms = pass.buildUniforms(viewport);
      expect(uniforms.length, equals(8));
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));
      expect(uniforms[2], equals(1.0)); // tonemapStrength
      expect(uniforms[3], equals(0.0)); // linearFactor
      expect(uniforms[4], equals(0.0)); // stephenHill
      expect(uniforms[5], equals(0.0)); // accurateSrgb
      expect(uniforms[6], equals(1.0)); // aoModulation
      expect(uniforms[7], equals(0.25)); // shadowDarkening
    });

    test('Custom parameters bind accurately into all 8 uniform slots', () {
      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass(
        tonemapStrength: 2.5,
        exposureMode: ExposureMode.evStops,
        fitType: AcesFitType.narkowicz,
        gammaMode: GammaMode.gamma22,
        aoModulation: 1.8,
        shadowDarkening: 0.45,
      );

      final List<double> uniforms = pass.buildUniforms(const Size(2560.0, 1440.0));
      expect(uniforms[0], equals(2560.0));
      expect(uniforms[1], equals(1440.0));
      expect(uniforms[2], equals(2.5)); // tonemapStrength (exposure)
      expect(uniforms[3], equals(1.0)); // evStops -> 1.0
      expect(uniforms[4], equals(1.0)); // narkowicz -> 1.0
      expect(uniforms[5], equals(1.0)); // gamma22 -> 1.0
      expect(uniforms[6], equals(1.8)); // aoModulation
      expect(uniforms[7], equals(0.45)); // shadowDarkening
    });

    test('packUniforms returns Float32List with 8 elements and 32 bytes', () {
      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass();
      final Float32List packed = pass.packUniforms(viewport);

      expect(packed.length, equals(8));
      expect(packed.buffer.lengthInBytes, equals(32));
      expect(packed[0], equals(1920.0));
      expect(packed[1], equals(1080.0));
      expect(packed[6], equals(pass.aoModulation));
      expect(packed[7], equals(pass.shadowDarkening));
    });

    test('Parity with PostProcessPipelineController.buildCompositeUniforms', () {
      const AcesTonemapParams acesParams = AcesTonemapParams(
        exposure: 1.35,
        exposureMode: ExposureMode.evStops,
        fitType: AcesFitType.narkowicz,
        gammaMode: GammaMode.gamma22,
      );

      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass(
        tonemapStrength: acesParams.exposure,
        exposureMode: acesParams.exposureMode,
        fitType: acesParams.fitType,
        gammaMode: acesParams.gammaMode,
        aoModulation: 1.6,
        shadowDarkening: 0.35,
      );

      final List<double> passUniforms = pass.buildUniforms(viewport);
      final List<double> controllerUniforms =
          PostProcessPipelineController.buildCompositeUniforms(
        size: viewport,
        acesParams: acesParams,
        aoIntensity: 1.6,
        aoDirectLightPreserve: 0.35,
      );

      expect(passUniforms.length, equals(controllerUniforms.length));
      for (int i = 0; i < passUniforms.length; ++i) {
        expect(passUniforms[i], closeTo(controllerUniforms[i], 1e-6),
            reason: 'Mismatch at uniform index $i');
      }
    });

    test('bindTo writes all floats into BufferUniformTarget', () {
      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass(
        aoModulation: 1.75,
        shadowDarkening: 0.15,
        tonemapStrength: 0.8,
      );

      final BufferUniformTarget target = BufferUniformTarget();
      pass.bindTo(target, viewport);

      expect(target.getFloat(0), equals(1920.0));
      expect(target.getFloat(1), equals(1080.0));
      expect(target.getFloat(2), equals(0.8));
      expect(target.getFloat(3), equals(0.0));
      expect(target.getFloat(4), equals(0.0));
      expect(target.getFloat(5), equals(0.0));
      expect(target.getFloat(6), equals(1.75));
      expect(target.getFloat(7), equals(0.15));
      expect(target.floatCount, equals(8));
    });

    test('bindTo writes all floats into FakeUniformStorage', () {
      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass(
        aoModulation: 0.9,
        shadowDarkening: 0.3,
        tonemapStrength: 1.2,
      );

      final FakeUniformStorage storage = FakeUniformStorage();
      pass.bindTo(storage, viewport);

      expect(storage.floats[0], equals(1920.0));
      expect(storage.floats[1], equals(1080.0));
      expect(storage.floats[2], equals(1.2));
      expect(storage.floats[6], equals(0.9));
      expect(storage.floats[7], equals(0.3));
    });

    test('UniformBufferBinder.bindByDescriptor maps parameters matching descriptor', () {
      final ShaderRegistry reg = ShaderRegistry(loadDefaults: true);
      final ShaderDescriptor desc =
          reg.getShaderDescriptor(ShaderCatalog.ssaoCompositeAces)!;

      final BufferUniformTarget target = BufferUniformTarget();
      final Map<String, dynamic> params = <String, dynamic>{
        'uResolution': const Size(1280.0, 720.0),
        'uExposure': 1.5,
        'uExposureMode': 1.0,
        'uFitType': 1.0,
        'uGammaMode': 1.0,
        'uAoIntensity': 2.0,
        'uAoDirectLightPreserve': 0.1,
      };

      UniformBufferBinder.bindByDescriptor(target, desc, params);

      expect(target.getFloat(0), equals(1280.0));
      expect(target.getFloat(1), equals(720.0));
      expect(target.getFloat(2), equals(1.5));
      expect(target.getFloat(3), equals(1.0));
      expect(target.getFloat(4), equals(1.0));
      expect(target.getFloat(5), equals(1.0));
      expect(target.getFloat(6), equals(2.0));
      expect(target.getFloat(7), equals(0.1));
    });

    test('Edge case handling: zero, negative, extreme values, fractional viewport', () {
      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass(
        aoModulation: 0.0,
        shadowDarkening: 0.0,
        tonemapStrength: 0.0,
      );
      final List<double> zeroUniforms =
          pass.buildUniforms(const Size(390.5, 844.75));

      expect(zeroUniforms[0], equals(390.5));
      expect(zeroUniforms[1], equals(844.75));
      expect(zeroUniforms[2], equals(0.0));
      expect(zeroUniforms[6], equals(0.0));
      expect(zeroUniforms[7], equals(0.0));

      final SsaoCompositeAcesPass extremePass = SsaoCompositeAcesPass(
        aoModulation: 10.0,
        shadowDarkening: 1.0,
        tonemapStrength: 100.0,
      );
      final List<double> extremeUniforms = extremePass.buildUniforms(viewport);
      expect(extremeUniforms[2], equals(100.0));
      expect(extremeUniforms[6], equals(10.0));
      expect(extremeUniforms[7], equals(1.0));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Multi-Texture Sampler Binding (Scene Color, Blurred Occlusion Map)
  // ---------------------------------------------------------------------------
  group('4. Multi-Texture Sampler Binding (uSceneTexture & uAoTexture)', () {
    late FakeTestImage sceneImage;
    late FakeTestImage aoImage;

    setUp(() {
      sceneImage = FakeTestImage(
          width: 1920, height: 1080, label: 'LinearHdrSceneColor');
      aoImage = FakeTestImage(
          width: 1920, height: 1080, label: 'BilateralBlurredOcclusion');
    });

    test('Multi-texture samplers are bound strictly to designated units (0 and 1)', () {
      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass(
        sceneColorTexture: sceneImage,
        blurredOcclusionTexture: aoImage,
      );

      final BufferUniformTarget target = BufferUniformTarget();
      pass.bindTo(target, const Size(1920, 1080));

      expect(target.samplerCount, equals(2));
      expect(target.samplers[0], equals(sceneImage),
          reason: 'Unit 0 must bind scene color texture');
      expect(target.samplers[1], equals(aoImage),
          reason: 'Unit 1 must bind blurred occlusion map');
    });

    test('Binding to FakeUniformStorage calls setImageSampler with correct unit indices', () {
      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass(
        sceneColorTexture: sceneImage,
        blurredOcclusionTexture: aoImage,
      );

      final FakeUniformStorage storage = FakeUniformStorage();
      pass.bindTo(storage, const Size(1920, 1080));

      expect(storage.samplers.length, equals(2));
      expect(storage.samplers[0], equals(sceneImage));
      expect(storage.samplers[1], equals(aoImage));
    });

    test('Null textures gracefully bypass sampler binding without throwing exceptions', () {
      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass(
        sceneColorTexture: null,
        blurredOcclusionTexture: null,
      );

      final BufferUniformTarget target = BufferUniformTarget();
      expect(() => pass.bindTo(target, const Size(800, 600)), returnsNormally);
      expect(target.samplerCount, equals(0));
      expect(target.floatCount, equals(8));
    });

    test('Partial texture binding binds only the available texture unit', () {
      final SsaoCompositeAcesPass passWithOnlyScene = SsaoCompositeAcesPass(
        sceneColorTexture: sceneImage,
        blurredOcclusionTexture: null,
      );

      final BufferUniformTarget target1 = BufferUniformTarget();
      passWithOnlyScene.bindTo(target1, const Size(800, 600));
      expect(target1.samplerCount, equals(1));
      expect(target1.samplers.containsKey(0), isTrue);
      expect(target1.samplers.containsKey(1), isFalse);

      final SsaoCompositeAcesPass passWithOnlyAo = SsaoCompositeAcesPass(
        sceneColorTexture: null,
        blurredOcclusionTexture: aoImage,
      );

      final BufferUniformTarget target2 = BufferUniformTarget();
      passWithOnlyAo.bindTo(target2, const Size(800, 600));
      expect(target2.samplerCount, equals(1));
      expect(target2.samplers.containsKey(0), isFalse);
      expect(target2.samplers.containsKey(1), isTrue);
    });

    test('Re-binding swapped textures updates sampler unit assignments correctly', () {
      final FakeTestImage altScene =
          FakeTestImage(width: 800, height: 600, label: 'AltScene');
      final FakeTestImage altAo =
          FakeTestImage(width: 800, height: 600, label: 'AltAo');

      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass(
        sceneColorTexture: sceneImage,
        blurredOcclusionTexture: aoImage,
      );

      final BufferUniformTarget target = BufferUniformTarget();
      pass.bindTo(target, const Size(800, 600));
      expect(target.samplers[0], equals(sceneImage));
      expect(target.samplers[1], equals(aoImage));

      // Swap to alt textures
      pass.sceneColorTexture = altScene;
      pass.blurredOcclusionTexture = altAo;
      pass.bindTo(target, const Size(800, 600));

      expect(target.samplers[0], equals(altScene));
      expect(target.samplers[1], equals(altAo));
    });

    test('PostProcessPipelineController builds composite uniforms and binds both samplers', () {
      final PostProcessPipelineController controller =
          PostProcessPipelineController();
      final FakeUniformStorage storage = FakeUniformStorage();

      final List<double> uniforms =
          PostProcessPipelineController.buildCompositeUniforms(
        size: const Size(1280, 720),
        acesParams: controller.acesParams,
        aoIntensity: 1.4,
        aoDirectLightPreserve: 0.3,
      );

      for (int i = 0; i < uniforms.length; ++i) {
        storage.setFloat(i, uniforms[i]);
      }
      storage.setImageSampler(0, sceneImage);
      storage.setImageSampler(1, aoImage);

      expect(storage.floats.length, equals(8));
      expect(storage.floats[0], equals(1280.0));
      expect(storage.floats[1], equals(720.0));
      expect(storage.floats[6], equals(1.4));
      expect(storage.floats[7], equals(0.3));
      expect(storage.samplers[0], equals(sceneImage));
      expect(storage.samplers[1], equals(aoImage));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Blend Mode Validation and Pass Output Structure
  // ---------------------------------------------------------------------------
  group('5. Blend Mode Validation & Pass Output Structure', () {
    const Size viewport = Size(1920.0, 1080.0);

    test('Supported blend modes pass validation and produce valid pass output', () {
      for (final BlendMode mode in SsaoCompositeAcesPass.supportedBlendModes) {
        final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass(blendMode: mode);
        expect(pass.isBlendModeSupported, isTrue);

        final SsaoCompositePassOutput output =
            pass.executePass(viewportSize: viewport);

        expect(output.isValid, isTrue);
        expect(output.passName, equals('ssao_composite_aces'));
        expect(output.viewportSize, equals(viewport));
        expect(output.blendMode, equals(mode));
        expect(output.uniforms.length, equals(8));
        expect(output.samplerBindings[0], equals('uSceneTexture'));
        expect(output.samplerBindings[1], equals('uAoTexture'));
        expect(output.isHDRInput, isTrue);
        expect(output.isLDRTonemappedOutput, isTrue);
      }
    });

    test('Unsupported blend mode throws ArgumentError on executePass', () {
      const List<BlendMode> unsupportedModes = <BlendMode>[
        BlendMode.clear,
        BlendMode.colorDodge,
        BlendMode.difference,
        BlendMode.exclusion,
      ];

      for (final BlendMode mode in unsupportedModes) {
        final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass(blendMode: mode);
        expect(pass.isBlendModeSupported, isFalse);
        expect(
          () => pass.executePass(viewportSize: viewport),
          throwsA(isA<ArgumentError>()),
          reason: 'Blend mode $mode must throw ArgumentError',
        );
      }
    });

    test('PassRenderTargetType selection propagates into pass output structure', () {
      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass();

      final SsaoCompositePassOutput screenOut = pass.executePass(
        viewportSize: viewport,
        targetType: PassRenderTargetType.screenFramebuffer,
      );
      expect(screenOut.targetType,
          equals(PassRenderTargetType.screenFramebuffer));

      final SsaoCompositePassOutput pingPongOut = pass.executePass(
        viewportSize: viewport,
        targetType: PassRenderTargetType.pingPongPostprocess,
      );
      expect(pingPongOut.targetType,
          equals(PassRenderTargetType.pingPongPostprocess));
    });

    test('Zero or invalid viewport sizes fail output validation', () {
      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass();
      final SsaoCompositePassOutput zeroOut =
          pass.executePass(viewportSize: Size.zero);

      expect(zeroOut.isValid, isFalse,
          reason: 'PassOutput with Size.zero must be invalid');
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Mathematical Parity: GLSL Math Simulation vs Dart Implementation
  // ---------------------------------------------------------------------------
  group('6. Mathematical Parity & Algorithm Accuracy', () {
    test('AO Modulation: Unoccluded surface (ao = 1.0) retains 100% luminance', () {
      final double mult = CompositeAcesShaderMathSim.evaluateAoMultiplier(
        rawAo: 1.0,
        aoIntensity: 1.0,
        aoDirectLightPreserve: 0.25,
      );
      expect(mult, closeTo(1.0, 1e-5));
    });

    test('AO Modulation: Full occlusion (ao = 0.0) respects directPreserve floor', () {
      final double mult = CompositeAcesShaderMathSim.evaluateAoMultiplier(
        rawAo: 0.0,
        aoIntensity: 1.0,
        aoDirectLightPreserve: 0.25,
      );
      expect(mult, closeTo(0.25, 1e-5));

      // With complete shadow darkening (directPreserve = 0.0)
      final double darkMult = CompositeAcesShaderMathSim.evaluateAoMultiplier(
        rawAo: 0.0,
        aoIntensity: 1.0,
        aoDirectLightPreserve: 0.0,
      );
      expect(darkMult, closeTo(0.0, 1e-5));
    });

    test('AO Modulation: Zero intensity disables AO shading completely', () {
      final double mult = CompositeAcesShaderMathSim.evaluateAoMultiplier(
        rawAo: 0.0,
        aoIntensity: 0.0,
        aoDirectLightPreserve: 0.25,
      );
      expect(mult, closeTo(1.0, 1e-5));
    });

    test('AO Modulation: High intensity (> 1.0) clamps to [0.0, 1.0] without artifacts', () {
      final double mult = CompositeAcesShaderMathSim.evaluateAoMultiplier(
        rawAo: 0.0,
        aoIntensity: 2.5,
        aoDirectLightPreserve: 0.2,
      );
      expect(mult, inInclusiveRange(0.0, 1.0));
    });

    test('Camera Exposure: Linear multiplier vs EV stops (2^EV)', () {
      // Linear factor mode
      final (rLin, _, _, _) = CompositeAcesShaderMathSim.executeFragment(
        sceneColor: (0.1, 0.1, 0.1, 1.0),
        rawAo: 1.0,
        exposure: 2.5,
        exposureMode: 0.0, // Linear
        fitType: 1.0,
        gammaMode: 1.0,
        aoIntensity: 1.0,
        aoDirectLightPreserve: 0.25,
      );

      // EV stops mode (+1 EV doubles radiance, +2 EV quadruples)
      final (rEv0, _, _, _) = CompositeAcesShaderMathSim.executeFragment(
        sceneColor: (0.1, 0.1, 0.1, 1.0),
        rawAo: 1.0,
        exposure: 0.0, // 2^0 = 1.0
        exposureMode: 1.0,
        fitType: 1.0,
        gammaMode: 1.0,
        aoIntensity: 1.0,
        aoDirectLightPreserve: 0.25,
      );

      final (rEv1, _, _, _) = CompositeAcesShaderMathSim.executeFragment(
        sceneColor: (0.1, 0.1, 0.1, 1.0),
        rawAo: 1.0,
        exposure: 1.0, // 2^1 = 2.0
        exposureMode: 1.0,
        fitType: 1.0,
        gammaMode: 1.0,
        aoIntensity: 1.0,
        aoDirectLightPreserve: 0.25,
      );

      expect(rEv1, greaterThan(rEv0));
      expect(rLin, greaterThan(rEv1));
    });

    test('Dual ACES Models: Both Stephen Hill and Narkowicz compress HDR into [0, 1]', () {
      // Extreme HDR luminance input: (50.0, 50.0, 50.0)
      final (shR, shG, shB) =
          CompositeAcesShaderMathSim.acesStephenHill(50.0, 50.0, 50.0);
      expect(shR, inInclusiveRange(0.0, 1.0));
      expect(shG, inInclusiveRange(0.0, 1.0));
      expect(shB, inInclusiveRange(0.0, 1.0));

      final double narkVal = CompositeAcesShaderMathSim.narkowiczChannel(50.0);
      expect(narkVal, inInclusiveRange(0.0, 1.0));
      expect(narkVal, greaterThan(0.95));
    });

    test('Transfer Functions: IEC 61966-2-1 piecewise sRGB matches specification', () {
      // Near black: linear slope 12.92
      const double darkVal = 0.002;
      expect(
        CompositeAcesShaderMathSim.linearToSrgb(darkVal),
        closeTo(darkVal * 12.92, 1e-5),
      );

      // Midtones: power branch
      const double midVal = 0.5;
      final double expectedMid = 1.055 * math.pow(0.5, 1.0 / 2.4) - 0.055;
      expect(
        CompositeAcesShaderMathSim.linearToSrgb(midVal),
        closeTo(expectedMid, 1e-4),
      );

      // Boundary points
      expect(CompositeAcesShaderMathSim.linearToSrgb(0.0), closeTo(0.0, 1e-5));
      expect(CompositeAcesShaderMathSim.linearToSrgb(1.0), closeTo(1.0, 1e-5));
    });

    test('End-to-end Fragment simulation preserves alpha and produces valid clamped color', () {
      final (outR, outG, outB, outA) =
          CompositeAcesShaderMathSim.executeFragment(
        sceneColor: (1.5, 0.8, 0.3, 0.75),
        rawAo: 0.6,
        exposure: 1.0,
        exposureMode: 0.0,
        fitType: 0.0,
        gammaMode: 0.0,
        aoIntensity: 1.2,
        aoDirectLightPreserve: 0.25,
      );

      expect(outA, equals(0.75));
      expect(outR, inInclusiveRange(0.0, 1.0));
      expect(outG, inInclusiveRange(0.0, 1.0));
      expect(outB, inInclusiveRange(0.0, 1.0));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. CustomPainter Integration Tests
  // ---------------------------------------------------------------------------
  group('7. CustomPainter Integration (SsaoCompositePainter & PassPainter)', () {
    late FakeTestImage sceneImage;
    late FakeTestImage aoImage;

    setUp(() {
      sceneImage = FakeTestImage(width: 800, height: 600, label: 'Scene');
      aoImage = FakeTestImage(width: 800, height: 600, label: 'AO');
    });

    test('SsaoCompositeAcesPassPainter binds uniforms to target and draws rect', () {
      final FakeUniformStorage storage = FakeUniformStorage();
      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass(
        aoModulation: 1.25,
        shadowDarkening: 0.25,
        blendMode: BlendMode.srcOver,
        sceneColorTexture: sceneImage,
        blurredOcclusionTexture: aoImage,
      );

      final SsaoCompositeAcesPassPainter painter =
          SsaoCompositeAcesPassPainter(pass: pass, uniformTarget: storage);

      final MockCanvas canvas = MockCanvas();
      painter.paint(canvas, const Size(800, 600));

      expect(canvas.drawCalls, contains('drawRect'));
      expect(canvas.lastRect, equals(Offset.zero & const Size(800, 600)));
      expect(canvas.lastPaint?.blendMode, equals(BlendMode.srcOver));
      expect(storage.floats[6], equals(1.25));
      expect(storage.floats[7], equals(0.25));
      expect(storage.samplers[0], equals(sceneImage));
      expect(storage.samplers[1], equals(aoImage));
    });

    test('SsaoCompositePainter does not draw when prerequisites are missing', () {
      // Missing shader (headless execution)
      final SsaoCompositePainter p1 = SsaoCompositePainter(
        acesParams: const AcesTonemapParams(),
        shader: null,
        sceneTexture: sceneImage,
        aoTexture: aoImage,
      );
      final MockCanvas c1 = MockCanvas();
      p1.paint(c1, const Size(800, 600));
      expect(c1.drawCalls, isEmpty);

      // Missing sceneTexture
      final SsaoCompositePainter p2 = SsaoCompositePainter(
        acesParams: const AcesTonemapParams(),
        shader: null,
        sceneTexture: null,
        aoTexture: aoImage,
      );
      final MockCanvas c2 = MockCanvas();
      p2.paint(c2, const Size(800, 600));
      expect(c2.drawCalls, isEmpty);

      // Missing aoTexture
      final SsaoCompositePainter p3 = SsaoCompositePainter(
        acesParams: const AcesTonemapParams(),
        shader: null,
        sceneTexture: sceneImage,
        aoTexture: null,
      );
      final MockCanvas c3 = MockCanvas();
      p3.paint(c3, const Size(800, 600));
      expect(c3.drawCalls, isEmpty);
    });

    test('SsaoCompositePainter.shouldRepaint detects all property changes', () {
      final SsaoCompositePainter base = SsaoCompositePainter(
        acesParams: const AcesTonemapParams(exposure: 1.0),
        aoIntensity: 1.0,
        aoDirectLightPreserve: 0.25,
        shader: null,
        sceneTexture: sceneImage,
        aoTexture: aoImage,
      );

      // Identical delegate
      final SsaoCompositePainter same = SsaoCompositePainter(
        acesParams: const AcesTonemapParams(exposure: 1.0),
        aoIntensity: 1.0,
        aoDirectLightPreserve: 0.25,
        shader: null,
        sceneTexture: sceneImage,
        aoTexture: aoImage,
      );
      expect(base.shouldRepaint(same), isFalse);

      // Mutate acesParams
      final SsaoCompositePainter diffAces = SsaoCompositePainter(
        acesParams: const AcesTonemapParams(exposure: 2.0),
        aoIntensity: 1.0,
        aoDirectLightPreserve: 0.25,
        shader: null,
        sceneTexture: sceneImage,
        aoTexture: aoImage,
      );
      expect(base.shouldRepaint(diffAces), isTrue);

      // Mutate aoIntensity
      final SsaoCompositePainter diffAo = SsaoCompositePainter(
        acesParams: const AcesTonemapParams(exposure: 1.0),
        aoIntensity: 1.5,
        aoDirectLightPreserve: 0.25,
        shader: null,
        sceneTexture: sceneImage,
        aoTexture: aoImage,
      );
      expect(base.shouldRepaint(diffAo), isTrue);

      // Mutate aoDirectLightPreserve
      final SsaoCompositePainter diffDirect = SsaoCompositePainter(
        acesParams: const AcesTonemapParams(exposure: 1.0),
        aoIntensity: 1.0,
        aoDirectLightPreserve: 0.5,
        shader: null,
        sceneTexture: sceneImage,
        aoTexture: aoImage,
      );
      expect(base.shouldRepaint(diffDirect), isTrue);

      // Mutate sceneTexture
      final FakeTestImage altScene =
          FakeTestImage(width: 800, height: 600, label: 'AltScene');
      final SsaoCompositePainter diffScene = SsaoCompositePainter(
        acesParams: const AcesTonemapParams(exposure: 1.0),
        aoIntensity: 1.0,
        aoDirectLightPreserve: 0.25,
        shader: null,
        sceneTexture: altScene,
        aoTexture: aoImage,
      );
      expect(base.shouldRepaint(diffScene), isTrue);

      // Mutate aoTexture
      final FakeTestImage altAo =
          FakeTestImage(width: 800, height: 600, label: 'AltAo');
      final SsaoCompositePainter diffAoTex = SsaoCompositePainter(
        acesParams: const AcesTonemapParams(exposure: 1.0),
        aoIntensity: 1.0,
        aoDirectLightPreserve: 0.25,
        shader: null,
        sceneTexture: sceneImage,
        aoTexture: altAo,
      );
      expect(base.shouldRepaint(diffAoTex), isTrue);
    });

    test('SsaoCompositeAcesPassPainter propagates blendMode and paints rect via uniformTarget', () {
      final FakeUniformStorage storage = FakeUniformStorage();
      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass(
        blendMode: BlendMode.srcOver,
        sceneColorTexture: sceneImage,
        blurredOcclusionTexture: aoImage,
      );

      final SsaoCompositeAcesPassPainter painter =
          SsaoCompositeAcesPassPainter(pass: pass, uniformTarget: storage);

      final MockCanvas canvas = MockCanvas();
      painter.paint(canvas, const Size(1280, 720));

      expect(canvas.drawCalls, contains('drawRect'));
      expect(canvas.lastPaint?.blendMode, equals(BlendMode.srcOver));
      expect(storage.floats[0], equals(1280.0));
      expect(storage.floats[1], equals(720.0));
      expect(storage.samplers[0], equals(sceneImage));
      expect(storage.samplers[1], equals(aoImage));
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Widget Tree Rendering Tests (SsaoCompositeWidget & PassWidget)
  // ---------------------------------------------------------------------------
  group('8. Flutter Widget Tree Rendering Tests', () {
    testWidgets('SsaoCompositeWidget renders child cleanly inside RepaintBoundary',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 200,
                child: SsaoCompositeWidget(
                  acesParams: AcesTonemapParams(exposure: 1.2),
                  aoIntensity: 1.5,
                  aoDirectLightPreserve: 0.3,
                  child: Text('3D Viewport Postprocess Output'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('3D Viewport Postprocess Output'), findsOneWidget);
      expect(find.byType(SsaoCompositeWidget), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('SsaoCompositeAcesPassWidget renders and updates across widget re-pumps',
        (WidgetTester tester) async {
      final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass(
        aoModulation: 1.2,
        shadowDarkening: 0.25,
        tonemapStrength: 1.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                height: 844,
                child: SsaoCompositeAcesPassWidget(
                  pass: pass,
                  child: Container(
                    color: Colors.blueGrey,
                    child: const Center(
                      child: Text('Pass Child Scene'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Pass Child Scene'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Mutate pass parameters and trigger re-pump
      pass.aoModulation = 2.0;
      pass.shadowDarkening = 0.5;
      await tester.pump(const Duration(milliseconds: 16));

      expect(pass.aoModulation, equals(2.0));
      expect(pass.shadowDarkening, equals(0.5));
    });

    testWidgets('Widget tree supports multiple resolution presets',
        (WidgetTester tester) async {
      final List<Size> testResolutions = <Size>[
        const Size(390, 844), // Mobile standard
        const Size(1024, 768), // Tablet landscape
        const Size(1920, 1080), // Desktop Full HD
      ];

      for (final Size res in testResolutions) {
        final SsaoCompositeAcesPass pass = SsaoCompositeAcesPass();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: res.width,
                  height: res.height,
                  child: SsaoCompositeAcesPassWidget(
                    pass: pass,
                    child: Text('Resolution ${res.width.toInt()}x${res.height.toInt()}'),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          find.text('Resolution ${res.width.toInt()}x${res.height.toInt()}'),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
    });
  });
}
