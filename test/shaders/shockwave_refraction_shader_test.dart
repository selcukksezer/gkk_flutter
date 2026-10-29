// =============================================================================
// Shockwave Refraction Shader & Dart VFX Pipeline Comprehensive Test Suite
// Production AAA Combat VFX (Impeller & Skia Compatible)
//
// Verifies:
// 1. shaders/vfx/shockwave_refraction.frag GLSL declaration and specification
// 2. Central ShaderRegistry descriptor parity and 18-float uniform buffer binding
// 3. RefractionParams, RefractionMath, RefractionShaderController (RefractionEffectController)
// 4. Wavefront expansion animation (radius expansion from center across modes)
// 5. Wave ring thickness, Hann window envelope, and distortion magnitude
// 6. Radial chromatic dispersion with channel offsets (Red, Green, Blue)
// 7. Complete shockwave lifecycle from trigger to dissipation
// 8. CustomPainter rendering, software fallback, and widget integration
// 9. Adversarial edge cases, boundary conditions, and resilience
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/shaders/shader_pipeline.dart';
import 'package:gkk_flutter/core/shaders/shader_registry.dart';
import 'package:gkk_flutter/core/vfx/refraction_effect.dart';

/// Semantic alias for [RefractionShaderController] adhering to the specification contract.
typedef RefractionEffectController = RefractionShaderController;

/// Fake uniform storage capturing uniform floats and texture sampler assignments
/// for headless verification without implementing the Dart 3 base class [ui.FragmentShader].
class FakeUniformStorage implements ShaderUniformTarget {
  final Map<int, double> floats = <int, double>{};
  final Map<int, ui.Image> samplers = <int, ui.Image>{};

  @override
  void setFloat(int index, double value) {
    floats[index] = value;
  }

  @override
  void setImageSampler(int index, ui.Image image) {
    samplers[index] = image;
  }

  /// Populates this storage directly from controller uniform list.
  void populateFromController(RefractionEffectController controller, ui.Size size) {
    final List<double> uniforms = controller.buildUniformList(size);
    for (int i = 0; i < uniforms.length; i++) {
      setFloat(i, uniforms[i]);
    }
  }
}

/// Semantic alias for uniform storage verification.
typedef MockFragmentShader = FakeUniformStorage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // GROUP 1: GLSL Shader Source File Verification (shockwave_refraction.frag)
  // ===========================================================================
  group('Shockwave Refraction Shader (GLSL) File Integrity & Specification', () {
    late File shaderFile;
    late String shaderSource;

    setUpAll(() {
      shaderFile = File('shaders/vfx/shockwave_refraction.frag');
      expect(shaderFile.existsSync(), isTrue,
          reason: 'shockwave_refraction.frag must exist in shaders/vfx/');
      shaderSource = shaderFile.readAsStringSync();
    });

    test('Header declares #version 460 core and flutter runtime_effect include', () {
      expect(shaderSource, contains('#version 460 core'));
      expect(shaderSource, contains('#include <flutter/runtime_effect.glsl>'));
      expect(shaderSource, contains('precision highp float;'));
    });

    test('Declares all 13 numeric uniforms in exact GLSL declaration order (18 floats)', () {
      expect(shaderSource, contains('uniform vec2 uResolution;')); // 0..1
      expect(shaderSource, contains('uniform vec2 uCenter;')); // 2..3
      expect(shaderSource, contains('uniform float uProgress;')); // 4
      expect(shaderSource, contains('uniform float uTime;')); // 5
      expect(shaderSource, contains('uniform float uMaxRadius;')); // 6
      expect(shaderSource, contains('uniform float uThickness;')); // 7
      expect(shaderSource, contains('uniform float uRefractionStrength;')); // 8
      expect(shaderSource, contains('uniform float uChromaticAberration;')); // 9
      expect(shaderSource, contains('uniform float uDampening;')); // 10
      expect(shaderSource, contains('uniform float uFrequency;')); // 11
      expect(shaderSource, contains('uniform float uMode;')); // 12
      expect(shaderSource, contains('uniform float uUseNormalMap;')); // 13
      expect(shaderSource, contains('uniform vec4 uTint;')); // 14..17
    });

    test('Texture samplers are strictly declared after all numeric uniforms for Impeller', () {
      expect(shaderSource, contains('uniform sampler2D uSceneTexture;'));
      expect(shaderSource, contains('uniform sampler2D uNormalMapTexture;'));

      final int tintIdx = shaderSource.indexOf('uniform vec4 uTint;');
      final int sceneTexIdx = shaderSource.indexOf('uniform sampler2D uSceneTexture;');
      final int normalTexIdx = shaderSource.indexOf('uniform sampler2D uNormalMapTexture;');

      expect(sceneTexIdx, greaterThan(tintIdx),
          reason: 'uSceneTexture sampler must follow all numeric uniforms');
      expect(normalTexIdx, greaterThan(sceneTexIdx),
          reason: 'uNormalMapTexture must follow uSceneTexture');
    });

    test('Declares fragment color output and core analytical algorithms', () {
      expect(shaderSource, contains('out vec4 fragColor;'));
      expect(shaderSource, contains('FlutterFragCoord().xy'));
      expect(shaderSource, contains('uMode < 0.5')); // Mode 0: Blast shockwave
      expect(shaderSource, contains('uMode < 1.5')); // Mode 1: Critical hit
      expect(shaderSource, contains('uMode < 2.5')); // Mode 2: Heat haze
      expect(shaderSource, contains('uUseNormalMap > 0.5')); // Normal map sampling
      expect(shaderSource, contains('chromaticOffset')); // Radial chromatic dispersion
      expect(shaderSource, contains('fragColor = vec4(finalRgb, a);'));
    });

    test('Aspect ratio correction preserves isotropic circular wavefront geometry', () {
      expect(shaderSource, contains('float minDim = min(uResolution.x, uResolution.y);'));
      expect(shaderSource, contains('vec2 aspectScale = uResolution / max(minDim, 1.0);'));
      expect(shaderSource, contains('vec2 delta = (uv - uCenter) * aspectScale;'));
    });
  });

  // ===========================================================================
  // GROUP 2: Central Shader Registry & Descriptor Parity
  // ===========================================================================
  group('Shader Registry & Catalog Parity for Shockwave Refraction', () {
    late ShaderRegistry registry;

    setUp(() {
      registry = ShaderRegistry(loadDefaults: true);
    });

    test('ShaderCatalog.shockwaveRefraction is registered and configured properly', () {
      expect(registry.containsShader(ShaderCatalog.shockwaveRefraction), isTrue);

      final ShaderDescriptor? desc =
          registry.getShaderDescriptor(ShaderCatalog.shockwaveRefraction);
      expect(desc, isNotNull);
      expect(desc!.category, equals(ShaderCategory.vfx));
      expect(desc.stage, equals(ShaderStage.fragment));
      expect(desc.assetPath, equals('shaders/vfx/shockwave_refraction.frag'));
      expect(desc.totalFloatCount, equals(18));
      expect(desc.totalSamplerCount, equals(2));
    });

    test('ShaderDescriptor defines exact uniform offsets, counts, and samplers', () {
      final ShaderDescriptor desc =
          registry.getShaderDescriptor(ShaderCatalog.shockwaveRefraction)!;

      // Verify uniform offsets matching GLSL
      final UniformDefinition uRes = desc.findUniform('uResolution')!;
      expect(uRes.floatOffset, equals(0));
      expect(uRes.floatCount, equals(2));

      final UniformDefinition uCenter = desc.findUniform('uCenter')!;
      expect(uCenter.floatOffset, equals(2));
      expect(uCenter.floatCount, equals(2));

      final UniformDefinition uProgress = desc.findUniform('uProgress')!;
      expect(uProgress.floatOffset, equals(4));
      expect(uProgress.floatCount, equals(1));

      final UniformDefinition uTime = desc.findUniform('uTime')!;
      expect(uTime.floatOffset, equals(5));
      expect(uTime.floatCount, equals(1));

      final UniformDefinition uMaxRadius = desc.findUniform('uMaxRadius')!;
      expect(uMaxRadius.floatOffset, equals(6));
      expect(uMaxRadius.floatCount, equals(1));

      final UniformDefinition uThickness = desc.findUniform('uThickness')!;
      expect(uThickness.floatOffset, equals(7));
      expect(uThickness.floatCount, equals(1));

      final UniformDefinition uStrength = desc.findUniform('uRefractionStrength')!;
      expect(uStrength.floatOffset, equals(8));
      expect(uStrength.floatCount, equals(1));

      final UniformDefinition uChroma = desc.findUniform('uChromaticAberration')!;
      expect(uChroma.floatOffset, equals(9));
      expect(uChroma.floatCount, equals(1));

      final UniformDefinition uDampening = desc.findUniform('uDampening')!;
      expect(uDampening.floatOffset, equals(10));
      expect(uDampening.floatCount, equals(1));

      final UniformDefinition uFreq = desc.findUniform('uFrequency')!;
      expect(uFreq.floatOffset, equals(11));
      expect(uFreq.floatCount, equals(1));

      final UniformDefinition uMode = desc.findUniform('uMode')!;
      expect(uMode.floatOffset, equals(12));
      expect(uMode.floatCount, equals(1));

      final UniformDefinition uNorm = desc.findUniform('uUseNormalMap')!;
      expect(uNorm.floatOffset, equals(13));
      expect(uNorm.floatCount, equals(1));

      final UniformDefinition uTint = desc.findUniform('uTint')!;
      expect(uTint.floatOffset, equals(14));
      expect(uTint.floatCount, equals(4));

      // Verify samplers
      expect(desc.findSampler('uSceneTexture')!.samplerIndex, equals(0));
      expect(desc.findSampler('uNormalMapTexture')!.samplerIndex, equals(1));
    });

    test('UniformBufferBinder.bindByDescriptor populates shockwave parameters', () {
      final ShaderDescriptor desc =
          registry.getShaderDescriptor(ShaderCatalog.shockwaveRefraction)!;
      final BufferUniformTarget target = BufferUniformTarget();

      final Map<String, dynamic> params = <String, dynamic>{
        'uResolution': const ui.Size(1920.0, 1080.0),
        'uCenter': const ui.Offset(0.3, 0.7),
        'uProgress': 0.65,
        'uTime': 1.8,
        'uMaxRadius': 0.9,
        'uThickness': 0.11,
        'uRefractionStrength': 0.075,
        'uChromaticAberration': 0.035,
        'uDampening': 2.8,
        'uFrequency': 6.0,
        'uMode': 1.0,
        'uUseNormalMap': 0.0,
        'uTint': const ui.Color.fromRGBO(255, 128, 0, 0.8),
      };

      UniformBufferBinder.bindByDescriptor(target, desc, params);

      expect(target.getFloat(0), equals(1920.0));
      expect(target.getFloat(1), equals(1080.0));
      expect(target.getFloat(2), equals(0.3));
      expect(target.getFloat(3), equals(0.7));
      expect(target.getFloat(4), equals(0.65));
      expect(target.getFloat(5), equals(1.8));
      expect(target.getFloat(6), equals(0.9));
      expect(target.getFloat(7), equals(0.11));
      expect(target.getFloat(8), equals(0.075));
      expect(target.getFloat(9), equals(0.035));
      expect(target.getFloat(10), equals(2.8));
      expect(target.getFloat(11), equals(6.0));
      expect(target.getFloat(12), equals(1.0));
      expect(target.getFloat(13), equals(0.0));
      expect(target.getFloat(14), closeTo(1.0, 0.01));
      expect(target.getFloat(15), closeTo(0.5, 0.01));
      expect(target.getFloat(16), closeTo(0.0, 0.01));
      expect(target.getFloat(17), closeTo(0.8, 0.01));
    });

    test('Material registry defines default mat_spell_shockwave', () {
      final MaterialDescriptor? mat = registry.getMaterial('mat_spell_shockwave');
      expect(mat, isNotNull);
      expect(mat!.shaderId, equals(ShaderCatalog.shockwaveRefraction));
      expect(mat.category, equals(ShaderCategory.vfx));
      expect(mat.isTransparent, isTrue);
      expect(mat.properties['uRefractionStrength'], equals(0.08));
      expect(mat.properties['uChromaticAberration'], equals(0.03));
    });
  });

  // ===========================================================================
  // GROUP 3: Uniform Binding & Memory Layout (Dart Wrapper to GLSL)
  // ===========================================================================
  group('Uniform Binding & Memory Layout (Dart Wrapper to GLSL Uniforms)', () {
    test('RefractionParams.toUniformList serializes exactly 18 contiguous floats', () {
      const ui.Size size = ui.Size(1280.0, 720.0);
      final RefractionParams params = RefractionParams(
        center: const ui.Offset(0.25, 0.75),
        progress: 0.42,
        time: 2.15,
        maxRadius: 0.88,
        thickness: 0.10,
        refractionStrength: 0.065,
        chromaticAberration: 0.032,
        dampening: 3.1,
        frequency: 4.8,
        mode: RefractionEffectMode.criticalHit,
        useNormalMap: true,
        tint: const ui.Color.fromRGBO(100, 200, 255, 0.6),
      );

      final List<double> list = params.toUniformList(size: size);
      expect(list.length, equals(18));

      expect(list[0], equals(1280.0));
      expect(list[1], equals(720.0));
      expect(list[2], equals(0.25));
      expect(list[3], equals(0.75));
      expect(list[4], equals(0.42));
      expect(list[5], equals(2.15));
      expect(list[6], equals(0.88));
      expect(list[7], equals(0.10));
      expect(list[8], equals(0.065));
      expect(list[9], equals(0.032));
      expect(list[10], equals(3.1));
      expect(list[11], equals(4.8));
      expect(list[12], equals(1.0)); // criticalHit shaderValue
      expect(list[13], equals(1.0)); // useNormalMap = true
      expect(list[14], closeTo(100 / 255.0, 0.01));
      expect(list[15], closeTo(200 / 255.0, 0.01));
      expect(list[16], closeTo(255 / 255.0, 0.01));
      expect(list[17], closeTo(0.6, 0.01));
    });

    test('Controller buildUniformList and toUniformFloat32List are synchronized', () {
      final RefractionEffectController controller = RefractionEffectController();
      controller.triggerShockwave(
        center: const ui.Offset(0.6, 0.4),
        maxRadius: 0.75,
        thickness: 0.08,
      );

      const ui.Size size = ui.Size(1000.0, 1000.0);
      final List<double> doubleList = controller.buildUniformList(size);
      final Float32List float32List = controller.toUniformFloat32List(size);

      expect(doubleList.length, equals(18));
      expect(float32List.length, equals(18));

      for (int i = 0; i < 18; i++) {
        expect(float32List[i], closeTo(doubleList[i], 1e-5),
            reason: 'Uniform buffer index $i must match between List<double> and Float32List');
      }
    });

    test('controller builds and binds all 18 uniforms to FakeUniformStorage', () {
      final RefractionEffectController controller = RefractionEffectController();
      controller.triggerShockwave(
        center: const ui.Offset(0.5, 0.5),
        maxRadius: 0.8,
        thickness: 0.09,
        strength: 0.05,
      );

      final MockFragmentShader mockShader = MockFragmentShader();
      const ui.Size size = ui.Size(1920.0, 1080.0);

      mockShader.populateFromController(controller, size);

      expect(mockShader.floats.length, equals(18));
      expect(mockShader.floats[0], equals(1920.0));
      expect(mockShader.floats[1], equals(1080.0));
      expect(mockShader.floats[2], equals(0.5));
      expect(mockShader.floats[3], equals(0.5));
      expect(mockShader.floats[4], equals(0.0)); // initial progress
      expect(mockShader.floats[6], equals(0.8)); // maxRadius
      expect(mockShader.floats[7], equals(0.09)); // thickness
      expect(mockShader.floats[8], equals(0.05)); // strength
      expect(mockShader.floats[12], equals(0.0)); // shockwave mode
    });

    test('Mode shaderValues match exact GLSL numeric identifiers', () {
      expect(RefractionEffectMode.shockwave.shaderValue, equals(0.0));
      expect(RefractionEffectMode.criticalHit.shaderValue, equals(1.0));
      expect(RefractionEffectMode.heatHaze.shaderValue, equals(2.0));
      expect(RefractionEffectMode.magicalShield.shaderValue, equals(3.0));
    });

    test('Normal map toggle correctly sets index 13 to 0.0 or 1.0', () {
      const RefractionParams withoutNormal = RefractionParams(useNormalMap: false);
      const RefractionParams withNormal = RefractionParams(useNormalMap: true);

      const ui.Size size = ui.Size(100.0, 100.0);
      expect(withoutNormal.toUniformList(size: size)[13], equals(0.0));
      expect(withNormal.toUniformList(size: size)[13], equals(1.0));
    });
  });

  // ===========================================================================
  // GROUP 4: Expansion Animation (Radius Expansion from Center)
  // ===========================================================================
  group('Wavefront Expansion Animation (Radius Expansion from Center)', () {
    test('Mode 0 (Shockwave) expands with linear progression from origin', () {
      const RefractionParams params = RefractionParams(
        mode: RefractionEffectMode.shockwave,
        maxRadius: 0.8,
      );

      expect(RefractionMath.calculateCurrentRadius(params.copyWith(progress: 0.0)), equals(0.0));
      expect(RefractionMath.calculateCurrentRadius(params.copyWith(progress: 0.25)), closeTo(0.20, 1e-4));
      expect(RefractionMath.calculateCurrentRadius(params.copyWith(progress: 0.50)), closeTo(0.40, 1e-4));
      expect(RefractionMath.calculateCurrentRadius(params.copyWith(progress: 0.75)), closeTo(0.60, 1e-4));
      expect(RefractionMath.calculateCurrentRadius(params.copyWith(progress: 1.00)), closeTo(0.80, 1e-4));
    });

    test('Mode 1 (Critical Hit) expands with square-root violent attack curve', () {
      const RefractionParams params = RefractionParams(
        mode: RefractionEffectMode.criticalHit,
        maxRadius: 1.0,
      );

      // sqrt(0.04) = 0.2 -> radius = 0.2 (5x faster than linear 0.04)
      final double rEarly = RefractionMath.calculateCurrentRadius(params.copyWith(progress: 0.04));
      expect(rEarly, closeTo(0.20, 1e-4));

      // sqrt(0.25) = 0.5 -> radius = 0.5 (2x faster than linear 0.25)
      final double rQuarter = RefractionMath.calculateCurrentRadius(params.copyWith(progress: 0.25));
      expect(rQuarter, closeTo(0.50, 1e-4));

      // sqrt(1.0) = 1.0 -> radius = 1.0
      final double rFull = RefractionMath.calculateCurrentRadius(params.copyWith(progress: 1.0));
      expect(rFull, equals(1.0));

      // Strict inequality: Critical hit radius is strictly greater than linear shockwave for 0 < progress < 1
      const RefractionParams linear = RefractionParams(
        mode: RefractionEffectMode.shockwave,
        maxRadius: 1.0,
      );
      for (double p = 0.05; p < 0.95; p += 0.1) {
        final double critR = RefractionMath.calculateCurrentRadius(params.copyWith(progress: p));
        final double linR = RefractionMath.calculateCurrentRadius(linear.copyWith(progress: p));
        expect(critR, greaterThan(linR),
            reason: 'Critical hit expansion must precede linear expansion at progress $p');
      }
    });

    test('Mode 3 (Magical Shield) expands linearly and Mode 2 (Heat Haze) is stationary', () {
      const RefractionParams shield = RefractionParams(
        mode: RefractionEffectMode.magicalShield,
        maxRadius: 0.85,
      );
      expect(RefractionMath.calculateCurrentRadius(shield.copyWith(progress: 0.4)), closeTo(0.34, 1e-4));

      const RefractionParams haze = RefractionParams(
        mode: RefractionEffectMode.heatHaze,
        maxRadius: 0.70,
      );
      expect(RefractionMath.calculateCurrentRadius(haze.copyWith(progress: 0.0)), equals(0.70));
      expect(RefractionMath.calculateCurrentRadius(haze.copyWith(progress: 0.5)), equals(0.70));
      expect(RefractionMath.calculateCurrentRadius(haze.copyWith(progress: 1.0)), equals(0.70));
    });

    test('Expansion from varied origin centers (corners, center, and arbitrary coords)', () {
      const ui.Size size = ui.Size(800.0, 800.0);
      final List<ui.Offset> testCenters = <ui.Offset>[
        const ui.Offset(0.5, 0.5),   // Screen center
        const ui.Offset(0.0, 0.0),   // Top-left corner
        const ui.Offset(1.0, 1.0),   // Bottom-right corner
        const ui.Offset(0.25, 0.80), // Asymmetric ground impact point
      ];

      for (final ui.Offset center in testCenters) {
        final RefractionParams params = RefractionParams(
          center: center,
          progress: 0.5,
          maxRadius: 0.6, // currentRadius = 0.3
          thickness: 0.1,  // halfThick = 0.05 (active from 0.25 to 0.35)
        );

        // Point exactly on wavefront crest along X axis
        final ui.Offset onCrest = ui.Offset(center.dx + 0.3, center.dy);
        expect(RefractionMath.isWithinWavefront(uv: onCrest, size: size, params: params), isTrue);

        // Point ahead of wavefront (dist = 0.45 > 0.35)
        final ui.Offset aheadOfWave = ui.Offset(center.dx + 0.45, center.dy);
        expect(RefractionMath.isWithinWavefront(uv: aheadOfWave, size: size, params: params), isFalse);

        // Point behind wavefront (dist = 0.15 < 0.25)
        final ui.Offset behindWave = ui.Offset(center.dx + 0.15, center.dy);
        expect(RefractionMath.isWithinWavefront(uv: behindWave, size: size, params: params), isFalse);
      }
    });

    test('Aspect ratio correction preserves isotropic circular shape on widescreen and portrait', () {
      // Widescreen 16:9 (1920x1080): aspectX = 1920/1080 = 1.7778, aspectY = 1.0
      const ui.Size wideSize = ui.Size(1920.0, 1080.0);
      const RefractionParams params = RefractionParams(
        center: ui.Offset(0.5, 0.5),
        progress: 0.5,
        maxRadius: 0.4, // radius = 0.2 in min dimension (1080) -> 216 px
        thickness: 0.08,
      );

      // A circular wavefront must have equal pixel radius horizontally and vertically.
      // On X axis: deltaUV = 216 / 1920 = 0.1125
      // On Y axis: deltaUV = 216 / 1080 = 0.2000
      final ui.Offset crestX = const ui.Offset(0.5 + 216.0 / 1920.0, 0.5);
      final ui.Offset crestY = const ui.Offset(0.5, 0.5 + 216.0 / 1080.0);

      expect(RefractionMath.isWithinWavefront(uv: crestX, size: wideSize, params: params), isTrue);
      expect(RefractionMath.isWithinWavefront(uv: crestY, size: wideSize, params: params), isTrue);

      // Portrait 9:16 (1080x2400)
      const ui.Size portraitSize = ui.Size(1080.0, 2400.0);
      final ui.Offset portCrestX = const ui.Offset(0.5 + 216.0 / 1080.0, 0.5);
      final ui.Offset portCrestY = const ui.Offset(0.5, 0.5 + 216.0 / 2400.0);

      expect(RefractionMath.isWithinWavefront(uv: portCrestX, size: portraitSize, params: params), isTrue);
      expect(RefractionMath.isWithinWavefront(uv: portCrestY, size: portraitSize, params: params), isTrue);
    });
  });

  // ===========================================================================
  // GROUP 5: Wave Ring Thickness, Hann Envelope, and Distortion Magnitude
  // ===========================================================================
  group('Wave Ring Thickness, Hann Envelope, & Distortion Magnitude', () {
    test('Hann window envelope satisfies boundary and peak symmetry', () {
      const double thickness = 0.10;
      // halfThick = 0.05

      // Exact wave crest (distToFront = 0.0) -> envelope == 1.0
      expect(RefractionMath.calculateHannEnvelope(distToFront: 0.0, thickness: thickness),
          closeTo(1.0, 1e-5));

      // Quarter distance outward (distToFront = 0.025) -> x = 0.5 -> 0.5 * (1 + cos(0.5*pi)) = 0.5
      expect(RefractionMath.calculateHannEnvelope(distToFront: 0.025, thickness: thickness),
          closeTo(0.5, 1e-4));

      // Quarter distance inward (distToFront = -0.025) -> symmetric 0.5
      expect(RefractionMath.calculateHannEnvelope(distToFront: -0.025, thickness: thickness),
          closeTo(0.5, 1e-4));

      // Boundaries (distToFront = ±0.05) -> envelope == 0.0
      expect(RefractionMath.calculateHannEnvelope(distToFront: 0.05, thickness: thickness),
          equals(0.0));
      expect(RefractionMath.calculateHannEnvelope(distToFront: -0.05, thickness: thickness),
          equals(0.0));

      // Outside envelope (|distToFront| > 0.05) -> 0.0
      expect(RefractionMath.calculateHannEnvelope(distToFront: 0.12, thickness: thickness),
          equals(0.0));
    });

    test('Wave ring thickness parameter dictates the active band width', () {
      const ui.Size size = ui.Size(600.0, 600.0);

      // Narrow ring (thickness = 0.02, halfThick = 0.01)
      const RefractionParams narrow = RefractionParams(
        center: ui.Offset(0.5, 0.5),
        progress: 0.5,
        maxRadius: 0.6, // radius = 0.3
        thickness: 0.02,
      );
      // Point at 0.305 is inside
      expect(RefractionMath.isWithinWavefront(uv: const ui.Offset(0.805, 0.5), size: size, params: narrow), isTrue);
      // Point at 0.320 is outside narrow ring
      expect(RefractionMath.isWithinWavefront(uv: const ui.Offset(0.820, 0.5), size: size, params: narrow), isFalse);

      // Wide ring (thickness = 0.10, halfThick = 0.05)
      const RefractionParams wide = RefractionParams(
        center: ui.Offset(0.5, 0.5),
        progress: 0.5,
        maxRadius: 0.6, // radius = 0.3
        thickness: 0.10,
      );
      // Point at 0.320 is inside wide ring
      expect(RefractionMath.isWithinWavefront(uv: const ui.Offset(0.820, 0.5), size: size, params: wide), isTrue);
    });

    test('Mode 0 sinusoidal oscillation produces alternating inward and outward displacement', () {
      const ui.Size size = ui.Size(800.0, 800.0);
      const RefractionParams params = RefractionParams(
        center: ui.Offset(0.5, 0.5),
        progress: 0.5,
        maxRadius: 0.8, // radius = 0.4
        thickness: 0.1,  // halfThick = 0.05
        refractionStrength: 0.05,
        frequency: 2.0,
      );

      // Point ahead of wave crest (distToFront = +0.025)
      final ui.Offset aheadSample = const ui.Offset(0.5 + 0.425, 0.5);
      final ui.Offset dispAhead = RefractionMath.calculateDisplacement(
        uv: aheadSample,
        size: size,
        params: params,
      );

      // Point behind wave crest (distToFront = -0.025)
      final ui.Offset behindSample = const ui.Offset(0.5 + 0.375, 0.5);
      final ui.Offset dispBehind = RefractionMath.calculateDisplacement(
        uv: behindSample,
        size: size,
        params: params,
      );

      // Signs must be opposing across the wave node
      expect(dispAhead.dx * dispBehind.dx, lessThan(0.0),
          reason: 'Displacement must reverse direction across the sinusoidal wave cycle');

      // Radial displacement on the horizontal ray has dy == 0
      expect(dispAhead.dy, closeTo(0.0, 1e-6));
      expect(dispBehind.dy, closeTo(0.0, 1e-6));
    });

    test('Displacement scales linearly with refractionStrength', () {
      const ui.Size size = ui.Size(600.0, 600.0);
      const RefractionParams base = RefractionParams(
        center: ui.Offset(0.5, 0.5),
        progress: 0.4,
        maxRadius: 0.8,
        thickness: 0.1,
        refractionStrength: 0.04,
      );
      final RefractionParams doubled = base.copyWith(refractionStrength: 0.08);

      final ui.Offset samplePt = const ui.Offset(0.5 + 0.34, 0.5);
      final ui.Offset dispBase = RefractionMath.calculateDisplacement(
        uv: samplePt,
        size: size,
        params: base,
      );
      final ui.Offset dispDoubled = RefractionMath.calculateDisplacement(
        uv: samplePt,
        size: size,
        params: doubled,
      );

      expect(dispDoubled.dx, closeTo(dispBase.dx * 2.0, 1e-5));
    });

    test('Mode 1 Critical Hit dual harmonics create asymmetric sharper attack wavefront', () {
      const ui.Size size = ui.Size(500.0, 500.0);
      const RefractionParams critParams = RefractionParams(
        center: ui.Offset(0.5, 0.5),
        progress: 0.25,
        maxRadius: 0.8, // radius = 0.8 * sqrt(0.25) = 0.4
        thickness: 0.1,
        refractionStrength: 0.08,
        mode: RefractionEffectMode.criticalHit,
      );

      final ui.Offset samplePt = const ui.Offset(0.5 + 0.42, 0.5);
      final ui.Offset disp = RefractionMath.calculateDisplacement(
        uv: samplePt,
        size: size,
        params: critParams,
      );

      expect(disp.dx.abs(), greaterThan(0.0));
      expect(disp.dy, closeTo(0.0, 1e-6));
    });
  });

  // ===========================================================================
  // GROUP 6: Chromatic Dispersion & Channel Offset Verification
  // ===========================================================================
  group('Chromatic Dispersion & Radial Channel Offset Verification', () {
    test('calculateChromaticUvs separates Red and Blue channels along radial ray', () {
      const ui.Size size = ui.Size(800.0, 800.0);
      const RefractionParams params = RefractionParams(
        center: ui.Offset(0.5, 0.5),
        progress: 0.5,
        maxRadius: 0.8, // radius = 0.4
        thickness: 0.1,
        refractionStrength: 0.06,
        chromaticAberration: 0.03,
        mode: RefractionEffectMode.shockwave,
      );

      // Sample along the positive X radial ray
      final ui.Offset sampleUv = const ui.Offset(0.5 + 0.42, 0.5);
      final chromatic = RefractionMath.calculateChromaticUvs(
        uv: sampleUv,
        size: size,
        params: params,
      );

      // Red channel is offset further along the radial normal (+radialDir)
      expect(chromatic.red.dx, greaterThan(chromatic.green.dx));

      // Blue channel is pulled backward opposite the radial normal (-radialDir)
      expect(chromatic.blue.dx, lessThan(chromatic.green.dx));

      // Green UV is the base displaced coordinate
      expect(chromatic.green.dy, closeTo(0.5, 1e-5));
      expect(chromatic.red.dy, closeTo(0.5, 1e-5));
      expect(chromatic.blue.dy, closeTo(0.5, 1e-5));
    });

    test('Diagonal chromatic dispersion splits channels along diagonal radial vector', () {
      const ui.Size size = ui.Size(600.0, 600.0);
      const RefractionParams params = RefractionParams(
        center: ui.Offset(0.5, 0.5),
        progress: 0.5,
        maxRadius: 0.8,
        thickness: 0.1,
        refractionStrength: 0.05,
        chromaticAberration: 0.02,
      );

      // Sample along 45 degree diagonal (X > 0.5, Y > 0.5)
      final double offsetDist = 0.4 / math.sqrt(2.0);
      final ui.Offset diagUv = ui.Offset(0.5 + offsetDist, 0.5 + offsetDist);

      final chromatic = RefractionMath.calculateChromaticUvs(
        uv: diagUv,
        size: size,
        params: params,
      );

      // Both X and Y of Red channel must be pushed further along the diagonal than Green
      expect(chromatic.red.dx, greaterThan(chromatic.green.dx));
      expect(chromatic.red.dy, greaterThan(chromatic.green.dy));

      // Both X and Y of Blue channel must be pulled backward
      expect(chromatic.blue.dx, lessThan(chromatic.green.dx));
      expect(chromatic.blue.dy, lessThan(chromatic.green.dy));
    });

    test('Critical hit mode applies 2.5x chromatic dispersion multiplier', () {
      const ui.Size size = ui.Size(800.0, 800.0);
      const RefractionParams shockwave = RefractionParams(
        center: ui.Offset(0.5, 0.5),
        progress: 0.5,
        maxRadius: 0.8,
        thickness: 0.1,
        refractionStrength: 0.06,
        chromaticAberration: 0.02,
        mode: RefractionEffectMode.shockwave,
      );

      final RefractionParams critHit = shockwave.copyWith(
        mode: RefractionEffectMode.criticalHit,
      );

      final ui.Offset sampleUv = const ui.Offset(0.5 + 0.42, 0.5);

      final chromaShock = RefractionMath.calculateChromaticUvs(
        uv: sampleUv,
        size: size,
        params: shockwave,
      );
      final chromaCrit = RefractionMath.calculateChromaticUvs(
        uv: sampleUv,
        size: size,
        params: critHit,
      );

      final double shockSpread = chromaShock.red.dx - chromaShock.blue.dx;
      final double critSpread = chromaCrit.red.dx - chromaCrit.blue.dx;

      expect(critSpread, greaterThan(shockSpread),
          reason: 'Critical hit mode must produce wider chromatic dispersion');
    });

    test('Chromatic UVs clamp within valid [0.0, 1.0] viewport bounds', () {
      const ui.Size size = ui.Size(400.0, 400.0);
      const RefractionParams params = RefractionParams(
        center: ui.Offset(0.95, 0.95), // Near corner
        progress: 0.1,
        maxRadius: 0.8,
        thickness: 0.2,
        refractionStrength: 0.3, // Strong distortion
        chromaticAberration: 0.2, // Huge dispersion
      );

      final chromatic = RefractionMath.calculateChromaticUvs(
        uv: const ui.Offset(0.99, 0.99),
        size: size,
        params: params,
      );

      expect(chromatic.red.dx, inInclusiveRange(0.0, 1.0));
      expect(chromatic.red.dy, inInclusiveRange(0.0, 1.0));
      expect(chromatic.blue.dx, inInclusiveRange(0.0, 1.0));
      expect(chromatic.blue.dy, inInclusiveRange(0.0, 1.0));
    });
  });

  // ===========================================================================
  // GROUP 7: Complete Shockwave Lifecycle (Trigger -> Expansion -> Dissipation)
  // ===========================================================================
  group('Complete Shockwave Lifecycle (Trigger, Propagation, & Dissipation)', () {
    test('Lifecycle phases: Idle -> Trigger -> Update -> Dissipation', () {
      final RefractionEffectController controller = RefractionEffectController();

      // Phase 1: Idle
      expect(controller.isActive, isFalse);
      expect(controller.params.progress, equals(0.0));
      expect(controller.elapsedTimeSeconds, equals(0.0));

      // Phase 2: Trigger shockwave
      controller.triggerShockwave(
        center: const ui.Offset(0.5, 0.5),
        maxRadius: 0.8,
        duration: const Duration(milliseconds: 600),
      );

      expect(controller.isActive, isTrue);
      expect(controller.params.progress, equals(0.0));
      expect(controller.params.mode, equals(RefractionEffectMode.shockwave));

      // Phase 3: Propagation
      // Advance by 150ms (25%)
      controller.update(0.15);
      expect(controller.isActive, isTrue);
      expect(controller.params.progress, closeTo(0.25, 0.01));

      // Advance by 150ms (50%)
      controller.update(0.15);
      expect(controller.isActive, isTrue);
      expect(controller.params.progress, closeTo(0.50, 0.01));

      // Advance by 150ms (75%)
      controller.update(0.15);
      expect(controller.isActive, isTrue);
      expect(controller.params.progress, closeTo(0.75, 0.01));

      // Phase 4: Dissipation (reach 600ms = 100%)
      controller.update(0.15);
      expect(controller.isActive, isFalse);
      expect(controller.params.progress, equals(1.0));

      // Further updates while inactive have no effect
      controller.update(0.10);
      expect(controller.isActive, isFalse);
      expect(controller.params.progress, equals(1.0));
    });

    test('Decay factor monotonically decreases and vanishes at progress=1.0', () {
      const RefractionParams params = RefractionParams(
        mode: RefractionEffectMode.shockwave,
        dampening: 2.2,
      );

      double prevDecay = RefractionMath.calculateDecay(params.copyWith(progress: 0.0));
      expect(prevDecay, equals(1.0)); // exp(0) * (1 - 0) = 1.0

      for (double p = 0.1; p <= 0.9; p += 0.1) {
        final double decay = RefractionMath.calculateDecay(params.copyWith(progress: p));
        expect(decay, lessThan(prevDecay),
            reason: 'Decay must strictly decrease as progress advances');
        prevDecay = decay;
      }

      // At progress 1.0, decay is strictly 0.0 (full dissipation)
      expect(RefractionMath.calculateDecay(params.copyWith(progress: 1.0)), equals(0.0));

      // Zero displacement everywhere when decayed
      const ui.Size size = ui.Size(400.0, 400.0);
      final ui.Offset dispEnd = RefractionMath.calculateDisplacement(
        uv: const ui.Offset(0.9, 0.5),
        size: size,
        params: params.copyWith(progress: 1.0),
      );
      expect(dispEnd, equals(ui.Offset.zero));
    });

    test('Manual stop() immediately terminates active effect and resets progress', () {
      final RefractionEffectController controller = RefractionEffectController();
      controller.triggerShockwave(duration: const Duration(seconds: 1));

      controller.update(0.35);
      expect(controller.isActive, isTrue);
      expect(controller.params.progress, closeTo(0.35, 0.01));

      controller.stop();
      expect(controller.isActive, isFalse);
      expect(controller.params.progress, equals(0.0));
    });

    test('Re-triggering shockwave resets animation cleanly without glitches', () {
      final RefractionEffectController controller = RefractionEffectController();
      controller.triggerShockwave(duration: const Duration(seconds: 1));
      controller.update(0.7);

      expect(controller.params.progress, closeTo(0.7, 0.01));

      // Re-trigger before first one completes
      controller.triggerCriticalHit(
        center: const ui.Offset(0.3, 0.3),
        strength: 0.09,
      );

      expect(controller.isActive, isTrue);
      expect(controller.params.progress, equals(0.0));
      expect(controller.params.center, equals(const ui.Offset(0.3, 0.3)));
      expect(controller.params.mode, equals(RefractionEffectMode.criticalHit));
    });

    test('Continuous Heat Haze advances continuous time without terminating', () {
      final RefractionEffectController controller = RefractionEffectController();
      controller.startContinuousHeatHaze(strength: 0.03);

      expect(controller.isActive, isTrue);
      expect(controller.isContinuous, isTrue);

      controller.update(1.2);
      expect(controller.params.time, closeTo(1.2, 1e-4));
      expect(controller.isActive, isTrue);

      controller.update(3.5);
      expect(controller.params.time, closeTo(4.7, 1e-4));
      expect(controller.isActive, isTrue);

      controller.stop();
      expect(controller.isActive, isFalse);
      expect(controller.isContinuous, isFalse);
    });

    test('Consecutive mode transitions operate reliably in sequence', () {
      final RefractionEffectController controller = RefractionEffectController();

      // 1. Shockwave
      controller.triggerShockwave();
      expect(controller.params.mode, equals(RefractionEffectMode.shockwave));
      controller.update(1.0);
      expect(controller.isActive, isFalse);

      // 2. Critical Hit
      controller.triggerCriticalHit();
      expect(controller.params.mode, equals(RefractionEffectMode.criticalHit));
      controller.update(1.0);
      expect(controller.isActive, isFalse);

      // 3. Magical Shield
      controller.triggerMagicalShield();
      expect(controller.params.mode, equals(RefractionEffectMode.magicalShield));
      controller.update(1.0);
      expect(controller.isActive, isFalse);
    });
  });

  // ===========================================================================
  // GROUP 8: Widget & CustomPainter Rendering Integration
  // ===========================================================================
  group('Widget & CustomPainter Rendering Integration', () {
    test('RefractionEffectPainter paints software fallback shockwave', () {
      final RefractionEffectController controller = RefractionEffectController();
      controller.triggerShockwave();
      controller.update(0.35);

      final RefractionEffectPainter painter = RefractionEffectPainter(
        controller: controller,
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      painter.paint(canvas, const ui.Size(400.0, 400.0));

      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('RefractionEffectPainter paints critical hit flare in software fallback', () {
      final RefractionEffectController controller = RefractionEffectController();
      controller.triggerCriticalHit();
      controller.update(0.15); // progress < 0.4 triggers core flare

      final RefractionEffectPainter painter = RefractionEffectPainter(
        controller: controller,
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      painter.paint(canvas, const ui.Size(300.0, 300.0));

      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('RefractionEffectPainter handles idle state without painting effect', () {
      final RefractionEffectController controller = RefractionEffectController();
      final RefractionEffectPainter painter = RefractionEffectPainter(
        controller: controller,
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      // Idle paint call should exit early
      painter.paint(canvas, const ui.Size(200.0, 200.0));

      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('shouldRepaint returns true when controller or shader reference changes', () {
      final RefractionEffectController ctrl1 = RefractionEffectController();
      final RefractionEffectController ctrl2 = RefractionEffectController();

      final RefractionEffectPainter p1 = RefractionEffectPainter(controller: ctrl1);
      final RefractionEffectPainter p2 = RefractionEffectPainter(controller: ctrl2);

      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p1), isFalse);
    });

    test('RefractionShaderWarmUp primes canvas rasterizer', () async {
      final RefractionEffectController controller = RefractionEffectController();
      final RefractionShaderWarmUp warmUp = RefractionShaderWarmUp(
        controller: controller,
        warmUpSize: const ui.Size(64.0, 64.0),
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      await warmUp.warmUpOnCanvas(canvas);

      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('RefractionTextureHelper synthesizes and caches neutral 2x2 normal map', () async {
      final ui.Image normalMap = await RefractionTextureHelper.getNeutralNormalTexture();
      expect(normalMap.width, equals(2));
      expect(normalMap.height, equals(2));

      final ui.Image cached = await RefractionTextureHelper.getNeutralNormalTexture();
      expect(identical(normalMap, cached), isTrue);
    });

    testWidgets('RefractionEffectWidget runs animation lifecycle within widget tree',
        (WidgetTester tester) async {
      final RefractionEffectController controller = RefractionEffectController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RefractionEffectWidget(
            controller: controller,
            child: const SizedBox(
              width: 300,
              height: 300,
              child: Center(child: Text('Shockwave Target')),
            ),
          ),
        ),
      );

      expect(find.text('Shockwave Target'), findsOneWidget);
      expect(controller.isActive, isFalse);

      // Trigger shockwave and verify ticker starts
      controller.triggerShockwave(duration: const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.isActive, isTrue);
      expect(controller.params.progress, greaterThan(0.0));

      // Pump to completion
      await tester.pump(const Duration(milliseconds: 450));
      expect(controller.isActive, isFalse);
      expect(controller.params.progress, equals(1.0));
    });
  });

  // ===========================================================================
  // GROUP 9: Adversarial, Boundary & Resilience Stress Tests
  // ===========================================================================
  group('Adversarial Edge Cases & Boundary Resilience', () {
    test('Zero and negative delta time updates are ignored safely', () {
      final RefractionEffectController controller = RefractionEffectController();
      controller.triggerShockwave(duration: const Duration(milliseconds: 500));

      controller.update(0.0);
      expect(controller.elapsedTimeSeconds, equals(0.0));

      controller.update(-0.25);
      expect(controller.params.progress, equals(0.0));
    });

    test('Extreme delta time jump handles frame skips gracefully without overshoot', () {
      final RefractionEffectController controller = RefractionEffectController();
      controller.triggerShockwave(duration: const Duration(milliseconds: 500));

      // Jump 5 seconds in a single frame
      controller.update(5.0);

      expect(controller.isActive, isFalse);
      expect(controller.params.progress, equals(1.0));
    });

    test('Zero duration clamps safely to minimum duration to avoid division by zero', () {
      final RefractionEffectController controller = RefractionEffectController();
      controller.triggerShockwave(duration: Duration.zero);

      expect(controller.isActive, isTrue);
      controller.update(0.05);

      expect(controller.isActive, isFalse);
      expect(controller.params.progress, equals(1.0));
    });

    test('Extreme frequency, radius, and strength parameters do not produce NaN or Infinity', () {
      const ui.Size size = ui.Size(500.0, 500.0);
      const RefractionParams extreme = RefractionParams(
        center: ui.Offset(0.5, 0.5),
        progress: 0.5,
        maxRadius: 100.0,
        thickness: 50.0,
        refractionStrength: 10.0,
        frequency: 200.0,
        dampening: 50.0,
      );

      final ui.Offset disp = RefractionMath.calculateDisplacement(
        uv: const ui.Offset(0.6, 0.6),
        size: size,
        params: extreme,
      );

      expect(disp.dx.isNaN, isFalse);
      expect(disp.dx.isInfinite, isFalse);
      expect(disp.dy.isNaN, isFalse);
      expect(disp.dy.isInfinite, isFalse);
    });

    test('Multiple controller listeners receive synchronous change notifications', () {
      final RefractionEffectController controller = RefractionEffectController();
      int listener1Count = 0;
      int listener2Count = 0;

      controller.addListener(() => listener1Count++);
      controller.addListener(() => listener2Count++);

      controller.triggerShockwave();
      expect(listener1Count, equals(1));
      expect(listener2Count, equals(1));

      controller.update(0.1);
      expect(listener1Count, equals(2));
      expect(listener2Count, equals(2));

      controller.stop();
      expect(listener1Count, equals(3));
      expect(listener2Count, equals(3));
    });

    test('copyWith handles empty overrides retaining exact original state', () {
      final RefractionParams original = RefractionParams.criticalHit(
        center: const ui.Offset(0.1, 0.9),
      );
      final RefractionParams copy = original.copyWith();

      expect(copy, equals(original));
      expect(copy.hashCode, equals(original.hashCode));
    });
  });
}
