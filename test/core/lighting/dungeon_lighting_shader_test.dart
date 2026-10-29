import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/lighting/dungeon_light_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dungeon Lighting Shader GLSL File Verification', () {
    late File shaderFile;
    late String shaderContent;

    setUpAll(() {
      shaderFile = File('shaders/lighting/dungeon_lighting.frag');
      expect(shaderFile.existsSync(), isTrue, reason: 'dungeon_lighting.frag must exist');
      shaderContent = shaderFile.readAsStringSync();
    });

    test('Shader header has version 460 core and flutter runtime_effect include', () {
      expect(shaderContent, contains('#version 460 core'));
      expect(shaderContent, contains('#include <flutter/runtime_effect.glsl>'));
    });

    test('Shader declares all global uniforms matching 13-float header', () {
      expect(shaderContent, contains('uniform vec2 uResolution;'));
      expect(shaderContent, contains('uniform float uTime;'));
      expect(shaderContent, contains('uniform vec3 uAmbientColor;'));
      expect(shaderContent, contains('uniform float uAmbientIntensity;'));
      expect(shaderContent, contains('uniform float uLightCount;'));
      expect(shaderContent, contains('uniform float uAoModulation;'));
      expect(shaderContent, contains('uniform float uShadowSoftness;'));
      expect(shaderContent, contains('uniform vec3 uCameraPos;'));
    });

    test('Shader declares all 8-element uniform arrays matching 96 floats', () {
      expect(shaderContent, contains('uniform vec4 uLightPosRadius[8];'));
      expect(shaderContent, contains('uniform vec4 uLightColorIntensity[8];'));
      expect(shaderContent, contains('uniform vec4 uLightParams[8];'));
    });

    test('Shader declares sampler2D uTexture after numeric uniforms', () {
      expect(shaderContent, contains('uniform sampler2D uTexture;'));
      final int lastArrayIdx = shaderContent.indexOf('uLightParams[8]');
      final int samplerIdx = shaderContent.indexOf('uniform sampler2D uTexture');
      expect(samplerIdx, greaterThan(lastArrayIdx),
          reason: 'Samplers in Flutter runtime effects must follow numeric uniforms');
    });

    test('Shader implements ACES tonemapping and multi-model falloffs', () {
      expect(shaderContent, contains('computeWindowedInverseSquare'));
      expect(shaderContent, contains('computeSmoothstepFalloff'));
      expect(shaderContent, contains('computeLinearFalloff'));
      expect(shaderContent, contains('evaluateShadowAttenuation'));
      expect(shaderContent, contains('acesTonemap'));
      expect(shaderContent, contains('fragColor = vec4(finalRgb, texSample.a);'));
    });
  });

  group('Dungeon Lighting Shader Mathematical Logic Parity', () {
    // Krzysztof Narkowicz ACES fit
    double acesNarkowiczScalar(double x) {
      const double a = 2.51;
      const double b = 0.03;
      const double c = 2.43;
      const double d = 0.59;
      const double e = 0.14;
      return ((x * (a * x + b)) / (x * (c * x + d) + e)).clamp(0.0, 1.0);
    }

    test('ACES tonemapping compresses high dynamic range values gracefully into [0, 1]', () {
      expect(acesNarkowiczScalar(0.0), closeTo(0.0, 1e-4));
      expect(acesNarkowiczScalar(1.0), closeTo(0.803, 0.02));
      expect(acesNarkowiczScalar(5.0), greaterThan(0.95));
      expect(acesNarkowiczScalar(50.0), lessThanOrEqualTo(1.0));
      expect(acesNarkowiczScalar(100.0), lessThanOrEqualTo(1.0));
    });

    test('Windowed inverse-square attenuation satisfies UE4/Filament curve', () {
      const double radius = 100.0;
      // At dist = 0, window is 1.0, value is 1.0 / (0 + 1) = 1.0
      final double att0 = LightingAttenuationEngine.evaluateWindowedInverseSquare(0.0, radius);
      expect(att0, closeTo(1.0, 1e-5));

      // At dist = radius, exactly 0.0
      final double attMax = LightingAttenuationEngine.evaluateWindowedInverseSquare(radius, radius);
      expect(attMax, equals(0.0));

      // Half distance
      final double attMid = LightingAttenuationEngine.evaluateWindowedInverseSquare(50.0, radius);
      expect(attMid, greaterThan(0.0));
      expect(attMid, lessThan(att0));
    });

    test('Smoothstep falloff satisfies Hermite cubic window', () {
      const double radius = 100.0;
      final double s0 = LightingAttenuationEngine.evaluateSmoothstepFalloff(0.0, radius);
      expect(s0, closeTo(1.0, 1e-5));

      final double sHalf = LightingAttenuationEngine.evaluateSmoothstepFalloff(50.0, radius);
      expect(sHalf, greaterThan(0.0));
      expect(sHalf, lessThan(s0));

      final double sEnd = LightingAttenuationEngine.evaluateSmoothstepFalloff(radius, radius);
      expect(sEnd, equals(0.0));
    });

    test('Linear falloff strictly scales linearly from 1.0 to 0.0', () {
      const double radius = 100.0;
      expect(LightingAttenuationEngine.evaluateLinearFalloff(0.0, radius), equals(1.0));
      expect(LightingAttenuationEngine.evaluateLinearFalloff(50.0, radius), closeTo(0.5, 1e-5));
      expect(LightingAttenuationEngine.evaluateLinearFalloff(100.0, radius), equals(0.0));
    });

    test('Pseudo-3D shadow penumbra scales with hardness and depth difference', () {
      const Vector3D lightPos = Vector3D(100.0, 100.0, 40.0);
      const Vector3D fragPosFloor = Vector3D(100.0, 100.0, 0.0);
      const Vector3D fragPosWall = Vector3D(100.0, 100.0, 80.0);

      // Floor (light is above fragment -> depthDiff = 0)
      final double floorShadow = LightingAttenuationEngine.evaluateShadowAttenuation(
        fragPos: fragPosFloor,
        lightPos: lightPos,
        lightRadius: 150.0,
        shadowHardness: 0.8,
      );
      expect(floorShadow, greaterThan(0.5));

      // Wall (fragment is elevated above light -> depthDiff = 40)
      final double wallShadow = LightingAttenuationEngine.evaluateShadowAttenuation(
        fragPos: fragPosWall,
        lightPos: lightPos,
        lightRadius: 150.0,
        shadowHardness: 0.8,
      );
      // Fragment with positive depthDiff has exponential depth darkening
      expect(wallShadow, lessThan(floorShadow));
    });
  });

  group('Dungeon Light System 109-Float Buffer Layout Integration', () {
    test('System builds continuous 109 floats with correct offsets and values', () {
      final DungeonLightSystem system = DungeonLightSystem(
        ambientColor: const Color(0xFF0D1B2A),
        ambientIntensity: 0.2,
        aoModulation: 1.0,
        shadowSoftness: 1.5,
      );

      // Add all 4 distinct specialized light types
      system.addTorch(
        id: 'torch_wall_1',
        position: const Vector3D(50.0, 50.0, 25.0),
        baseIntensity: 2.2,
        radius: 120.0,
      );

      system.castPulsingRune(
        id: 'rune_altar',
        position: const Vector3D(200.0, 150.0, 5.0),
        runeColor: const Color(0xFF8A2BE2),
        baseIntensity: 1.8,
        radius: 90.0,
      );

      system.castFieryExplosion(
        id: 'fireball_hit',
        position: const Vector3D(300.0, 250.0, 10.0),
        peakIntensity: 4.5,
        maxRadius: 220.0,
      );

      system.castEtherealSoul(
        id: 'soul_specter',
        origin: const Vector3D(400.0, 350.0, 40.0),
        spectralColor: const Color(0xFF00CED1),
        intensity: 1.5,
        radius: 110.0,
      );

      expect(system.lightCount, equals(4));

      final Float32List buffer = system.buildUniformBuffer(
        resolution: const Size(1080.0, 2400.0),
        cameraPos: const Vector3D(540.0, 1200.0, 600.0),
        time: 1.25,
      );

      expect(buffer.length, equals(109));

      // Header verification
      expect(buffer[0], equals(1080.0));
      expect(buffer[1], equals(2400.0));
      expect(buffer[2], equals(1.25));
      expect(buffer[7], equals(4.0)); // active light count = 4
      expect(buffer[8], equals(1.0)); // aoModulation
      expect(buffer[9], equals(1.5)); // shadowSoftness
      expect(buffer[10], equals(540.0));
      expect(buffer[11], equals(1200.0));
      expect(buffer[12], equals(600.0));

      // 4 active lights populated
      for (int i = 0; i < 4; ++i) {
        final int posOffset = 13 + i * 4;
        final int colOffset = 45 + i * 4;
        final int parOffset = 77 + i * 4;

        expect(buffer[posOffset + 3], greaterThan(0.0), reason: 'Radius > 0 for light $i');
        expect(buffer[colOffset + 3], greaterThan(0.0), reason: 'Intensity > 0 for light $i');
        expect(buffer[parOffset + 2], greaterThan(0.0), reason: 'ShadowHardness > 0 for light $i');
      }

      // Remaining 4 light slots zero-filled
      for (int i = 4; i < 8; ++i) {
        final int posOffset = 13 + i * 4;
        final int colOffset = 45 + i * 4;
        final int parOffset = 77 + i * 4;

        expect(buffer[posOffset + 3], equals(0.0));
        expect(buffer[colOffset + 3], equals(0.0));
        expect(buffer[parOffset + 0], equals(0.0));
        expect(buffer[parOffset + 1], equals(0.0));
      }
    });

    test('Shader offline compilation test via impellerc succeeds if tool is present', () {
      final String impellercPath =
          'F:\\flutter\\bin\\cache\\artifacts\\engine\\windows-x64\\impellerc.exe';
      final File impellercFile = File(impellercPath);

      if (impellercFile.existsSync()) {
        final ProcessResult result = Process.runSync(
          impellercPath,
          <String>[
            '--sksl',
            '--iplr',
            '--sl=shaders/lighting/dungeon_lighting.iplr.tmp',
            '--spirv=shaders/lighting/dungeon_lighting.spirv.tmp',
            '--input=shaders/lighting/dungeon_lighting.frag',
            '--include=F:\\flutter\\bin\\cache\\artifacts\\engine\\windows-x64\\shader_lib',
          ],
        );

        // Clean up temporary compilation outputs
        final File tmpIplr = File('shaders/lighting/dungeon_lighting.iplr.tmp');
        final File tmpSpirv = File('shaders/lighting/dungeon_lighting.spirv.tmp');
        if (tmpIplr.existsSync()) tmpIplr.deleteSync();
        if (tmpSpirv.existsSync()) tmpSpirv.deleteSync();

        expect(result.exitCode, equals(0),
            reason: 'impellerc compilation failed: ${result.stderr}\n${result.stdout}');
      }
    });
  });
}
