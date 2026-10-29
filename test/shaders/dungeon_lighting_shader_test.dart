import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show Color, Size, FragmentShader, Image;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/lighting/dungeon_light_system.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_cave_theme.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_cinematic_atmosphere.dart';

// =============================================================================
// Fake FragmentShader for Uniform Buffer Verification
// =============================================================================

class FakeFragmentShader extends Fake implements ui.FragmentShader {
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

  @override
  void dispose() {}
}

// =============================================================================
// Composable Widget & CustomPainter for Dungeon Lighting Shader Testing
// =============================================================================

class DungeonLightingShaderWidget extends StatefulWidget {
  const DungeonLightingShaderWidget({
    super.key,
    required this.system,
    required this.resolution,
    required this.cameraPos,
    this.time = 0.0,
    this.onUniformsBuilt,
  });

  final DungeonLightSystem system;
  final Size resolution;
  final Vector3D cameraPos;
  final double time;
  final void Function(Float32List uniforms)? onUniformsBuilt;

  @override
  State<DungeonLightingShaderWidget> createState() =>
      _DungeonLightingShaderWidgetState();
}

class _DungeonLightingShaderWidgetState
    extends State<DungeonLightingShaderWidget> {
  @override
  Widget build(BuildContext context) {
    final Float32List uniforms = widget.system.buildUniformBuffer(
      resolution: widget.resolution,
      cameraPos: widget.cameraPos,
      time: widget.time,
    );
    widget.onUniformsBuilt?.call(uniforms);

    return CustomPaint(
      size: widget.resolution,
      painter: DungeonLightingTestPainter(
        uniforms: uniforms,
        activeLightCount: uniforms[7].toInt(),
      ),
    );
  }
}

class DungeonLightingTestPainter extends CustomPainter {
  const DungeonLightingTestPainter({
    required this.uniforms,
    required this.activeLightCount,
  });

  final Float32List uniforms;
  final int activeLightCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Paint bgPaint = Paint()
      ..color = Color.fromARGB(
        255,
        (uniforms[3] * 255).toInt().clamp(0, 255),
        (uniforms[4] * 255).toInt().clamp(0, 255),
        (uniforms[5] * 255).toInt().clamp(0, 255),
      );
    canvas.drawRect(Offset.zero & size, bgPaint);

    for (int i = 0; i < activeLightCount; ++i) {
      final double x = uniforms[13 + i * 4 + 0];
      final double y = uniforms[13 + i * 4 + 1];
      final double radius = uniforms[13 + i * 4 + 3];
      final double r = uniforms[45 + i * 4 + 0];
      final double g = uniforms[45 + i * 4 + 1];
      final double b = uniforms[45 + i * 4 + 2];
      final double intensity = uniforms[45 + i * 4 + 3];

      final Paint lightPaint = Paint()
        ..color = Color.fromARGB(
          ((intensity / 5.0).clamp(0.0, 1.0) * 255).toInt(),
          (r * 255).toInt().clamp(0, 255),
          (g * 255).toInt().clamp(0, 255),
          (b * 255).toInt().clamp(0, 255),
        );
      canvas.drawCircle(Offset(x, y), radius, lightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant DungeonLightingTestPainter oldDelegate) {
    return oldDelegate.uniforms != uniforms ||
        oldDelegate.activeLightCount != activeLightCount;
  }
}

// =============================================================================
// Test Suite
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // GROUP 1: buildUniformBuffer() 109-Float Layout Verification
  // ===========================================================================
  group('1. buildUniformBuffer() 109-Float Layout Verification', () {
    test('1.1 Buffer length is strictly 109 continuous floats (13 + 8 * 12)', () {
      final DungeonLightSystem system = DungeonLightSystem();
      final Float32List buffer = system.buildUniformBuffer(
        resolution: const Size(1920.0, 1080.0),
        cameraPos: const Vector3D(960.0, 540.0, 400.0),
        time: 2.5,
      );

      expect(buffer.length, equals(109));
    });

    test('1.2 [0..2]: uResolution (vec2) and uTime (float)', () {
      final DungeonLightSystem system = DungeonLightSystem();
      const Size res = Size(1440.0, 2560.0);
      const double time = 42.125;

      final Float32List buffer = system.buildUniformBuffer(
        resolution: res,
        cameraPos: const Vector3D(0.0, 0.0, 100.0),
        time: time,
      );

      expect(buffer[0], equals(1440.0), reason: 'uResolution.x');
      expect(buffer[1], equals(2560.0), reason: 'uResolution.y');
      expect(buffer[2], equals(42.125), reason: 'uTime');
    });

    test('1.3 [3..6]: uAmbientColor (vec3) and uAmbientIntensity (float)', () {
      final DungeonLightSystem system = DungeonLightSystem(
        ambientColor: const Color(0xFF1E3A8A), // Blue slate
        ambientIntensity: 0.45,
      );

      final Float32List buffer = system.buildUniformBuffer(
        resolution: const Size(800.0, 600.0),
        cameraPos: Vector3D.zero,
      );

      expect(buffer[3], closeTo(system.ambientColor.r, 1e-5), reason: 'ambient.r');
      expect(buffer[4], closeTo(system.ambientColor.g, 1e-5), reason: 'ambient.g');
      expect(buffer[5], closeTo(system.ambientColor.b, 1e-5), reason: 'ambient.b');
      expect(buffer[6], closeTo(0.45, 1e-5), reason: 'ambientIntensity');
    });

    test('1.4 [7]: uActiveLightCount (float) reflects selected light count', () {
      final DungeonLightSystem system = DungeonLightSystem();
      expect(system.buildUniformBuffer(resolution: const Size(100, 100), cameraPos: Vector3D.zero)[7], equals(0.0));

      system.addTorch(id: 't1', position: const Vector3D(10, 10, 0));
      expect(system.buildUniformBuffer(resolution: const Size(100, 100), cameraPos: Vector3D.zero)[7], equals(1.0));

      system.addTorch(id: 't2', position: const Vector3D(20, 20, 0));
      system.addTorch(id: 't3', position: const Vector3D(30, 30, 0));
      expect(system.buildUniformBuffer(resolution: const Size(100, 100), cameraPos: Vector3D.zero)[7], equals(3.0));
    });

    test('1.5 [8..9]: uAoModulation (float) and uShadowSoftness (float)', () {
      final DungeonLightSystem system = DungeonLightSystem(
        aoModulation: 1.35,
        shadowSoftness: 0.85,
      );

      final Float32List buffer = system.buildUniformBuffer(
        resolution: const Size(100, 100),
        cameraPos: Vector3D.zero,
      );

      expect(buffer[8], closeTo(1.35, 1e-5), reason: 'uAoModulation');
      expect(buffer[9], closeTo(0.85, 1e-5), reason: 'uShadowSoftness');
    });

    test('1.6 [10..12]: uCameraPos (vec3) maps x, y, z', () {
      final DungeonLightSystem system = DungeonLightSystem();
      const Vector3D cam = Vector3D(512.5, -256.25, 128.75);

      final Float32List buffer = system.buildUniformBuffer(
        resolution: const Size(100, 100),
        cameraPos: cam,
      );

      expect(buffer[10], closeTo(512.5, 1e-5), reason: 'uCameraPos.x');
      expect(buffer[11], closeTo(-256.25, 1e-5), reason: 'uCameraPos.y');
      expect(buffer[12], closeTo(128.75, 1e-5), reason: 'uCameraPos.z');
    });

    test('1.7 [13..44]: uLightPosRadius[8] maps 8 vec4s (x, y, z, radius)', () {
      final DungeonLightSystem system = DungeonLightSystem();
      system.addLight(
        DungeonLight(
          id: 'test_light_0',
          type: LightType.torch,
          position: const Vector3D(11.0, 22.0, 33.0),
          color: const Color(0xFFFFFFFF),
          intensity: 2.0,
          radius: 150.0,
        ),
      );

      final Float32List buffer = system.buildUniformBuffer(
        resolution: const Size(100, 100),
        cameraPos: Vector3D.zero,
      );

      // Light 0 at [13..16]
      expect(buffer[13], equals(11.0)); // x
      expect(buffer[14], equals(22.0)); // y
      expect(buffer[15], equals(33.0)); // z
      expect(buffer[16], equals(150.0)); // radius

      // Unused light slots [1..7] are zero-filled
      for (int i = 1; i < 8; ++i) {
        final int offset = 13 + i * 4;
        expect(buffer[offset + 0], equals(0.0));
        expect(buffer[offset + 1], equals(0.0));
        expect(buffer[offset + 2], equals(0.0));
        expect(buffer[offset + 3], equals(0.0));
      }
    });

    test('1.8 [45..76]: uLightColorIntensity[8] maps 8 vec4s (r, g, b, intensity)', () {
      final DungeonLightSystem system = DungeonLightSystem();
      const Color customColor = Color(0xFFFF5722); // Deep Orange
      system.addLight(
        DungeonLight(
          id: 'test_light_0',
          type: LightType.point,
          position: Vector3D.zero,
          color: customColor,
          intensity: 3.5,
          radius: 100.0,
        ),
      );

      final Float32List buffer = system.buildUniformBuffer(
        resolution: const Size(100, 100),
        cameraPos: Vector3D.zero,
      );

      // Light 0 at [45..48]
      expect(buffer[45], closeTo(customColor.r, 1e-4), reason: 'color.r');
      expect(buffer[46], closeTo(customColor.g, 1e-4), reason: 'color.g');
      expect(buffer[47], closeTo(customColor.b, 1e-4), reason: 'color.b');
      expect(buffer[48], equals(3.5), reason: 'intensity');

      // Unused light slots [1..7] are zero-filled
      for (int i = 1; i < 8; ++i) {
        final int offset = 45 + i * 4;
        expect(buffer[offset + 0], equals(0.0));
        expect(buffer[offset + 1], equals(0.0));
        expect(buffer[offset + 2], equals(0.0));
        expect(buffer[offset + 3], equals(0.0));
      }
    });

    test('1.9 [77..108]: uLightParams[8] maps 8 vec4s (type, falloff, shadowHardness, specularPower)', () {
      final DungeonLightSystem system = DungeonLightSystem();
      system.addLight(
        DungeonLight(
          id: 'test_light_params',
          type: LightType.fieryExplosion,
          falloffType: FalloffType.smoothstep,
          shadowHardness: 0.65,
          specularPower: 64.0,
          position: Vector3D.zero,
          color: const Color(0xFFFFFFFF),
          intensity: 1.0,
          radius: 100.0,
        ),
      );

      final Float32List buffer = system.buildUniformBuffer(
        resolution: const Size(100, 100),
        cameraPos: Vector3D.zero,
      );

      // Light 0 at [77..80]
      expect(buffer[77], equals(LightType.fieryExplosion.shaderValue)); // 2.0
      expect(buffer[78], equals(FalloffType.smoothstep.shaderValue)); // 1.0
      expect(buffer[79], closeTo(0.65, 1e-5)); // shadowHardness
      expect(buffer[80], equals(64.0)); // specularPower

      // Unused light slots [1..7] are zero-filled
      for (int i = 1; i < 8; ++i) {
        final int offset = 77 + i * 4;
        expect(buffer[offset + 0], equals(0.0));
        expect(buffer[offset + 1], equals(0.0));
        expect(buffer[offset + 2], equals(0.0));
        expect(buffer[offset + 3], equals(0.0));
      }
    });

    test('1.10 Empty system zero-fills all 8 light array slots completely', () {
      final DungeonLightSystem system = DungeonLightSystem();
      final Float32List buffer = system.buildUniformBuffer(
        resolution: const Size(100, 100),
        cameraPos: Vector3D.zero,
      );

      expect(buffer[7], equals(0.0)); // uActiveLightCount

      for (int i = 13; i < 109; ++i) {
        expect(buffer[i], equals(0.0), reason: 'Index $i must be zero-filled when system is empty');
      }
    });

    test('1.11 Partial system (3 lights) populates slots 0..2 and strictly zero-fills slots 3..7', () {
      final DungeonLightSystem system = DungeonLightSystem();
      system.addTorch(id: 't0', position: const Vector3D(10, 0, 0), radius: 100.0);
      system.addTorch(id: 't1', position: const Vector3D(20, 0, 0), radius: 110.0);
      system.addTorch(id: 't2', position: const Vector3D(30, 0, 0), radius: 120.0);

      final Float32List buffer = system.buildUniformBuffer(
        resolution: const Size(100, 100),
        cameraPos: Vector3D.zero,
      );

      expect(buffer[7], equals(3.0));

      // Active lights 0..2
      for (int i = 0; i < 3; ++i) {
        expect(buffer[13 + i * 4 + 3], greaterThan(0.0)); // radius
        expect(buffer[45 + i * 4 + 3], greaterThan(0.0)); // intensity
      }

      // Inactive lights 3..7
      for (int i = 3; i < 8; ++i) {
        expect(buffer[13 + i * 4 + 3], equals(0.0));
        expect(buffer[45 + i * 4 + 3], equals(0.0));
        expect(buffer[77 + i * 4 + 0], equals(0.0));
        expect(buffer[77 + i * 4 + 1], equals(0.0));
        expect(buffer[77 + i * 4 + 2], equals(0.0));
        expect(buffer[77 + i * 4 + 3], equals(0.0));
      }
    });

    test('1.12 Full system (8 lights) populates all 8 slots without trailing zeroes', () {
      final DungeonLightSystem system = DungeonLightSystem();
      for (int i = 0; i < 8; ++i) {
        system.addTorch(
          id: 't_$i',
          position: Vector3D(i * 10.0, 0.0, 0.0),
          baseIntensity: 1.5 + i * 0.1,
          radius: 100.0 + i * 5.0,
        );
      }

      final Float32List buffer = system.buildUniformBuffer(
        resolution: const Size(100, 100),
        cameraPos: Vector3D.zero,
      );

      expect(buffer[7], equals(8.0));
      for (int i = 0; i < 8; ++i) {
        expect(buffer[13 + i * 4 + 3], greaterThan(0.0));
        expect(buffer[45 + i * 4 + 3], greaterThan(0.0));
      }
    });

    test('1.13 All 6 LightType enum shader values map correctly to shader floats', () {
      expect(LightType.torch.shaderValue, equals(0.0));
      expect(LightType.pulsingRune.shaderValue, equals(1.0));
      expect(LightType.fieryExplosion.shaderValue, equals(2.0));
      expect(LightType.etherealSoul.shaderValue, equals(3.0));
      expect(LightType.point.shaderValue, equals(4.0));
      expect(LightType.spot.shaderValue, equals(5.0));
    });

    test('1.14 All 3 FalloffType enum shader values map correctly to shader floats', () {
      expect(FalloffType.windowedInverseSquare.shaderValue, equals(0.0));
      expect(FalloffType.smoothstep.shaderValue, equals(1.0));
      expect(FalloffType.linear.shaderValue, equals(2.0));
    });

    test('1.15 applyToShader() forwards all 109 floats to FragmentShader.setFloat()', () {
      final DungeonLightSystem system = DungeonLightSystem();
      system.addTorch(id: 'torch_test', position: const Vector3D(100, 200, 50));

      final FakeFragmentShader fakeShader = FakeFragmentShader();
      system.applyToShader(
        fakeShader,
        resolution: const Size(1920, 1080),
        cameraPos: const Vector3D(0, 0, 500),
        time: 7.25,
      );

      expect(fakeShader.floats.length, equals(109));

      // Verify header matches
      expect(fakeShader.floats[0], equals(1920.0));
      expect(fakeShader.floats[1], equals(1080.0));
      expect(fakeShader.floats[2], equals(7.25));
      expect(fakeShader.floats[7], equals(1.0)); // active light count

      // Verify light 0
      expect(fakeShader.floats[13], equals(100.0));
      expect(fakeShader.floats[14], equals(200.0));
      expect(fakeShader.floats[15], equals(50.0));
    });
  });

  // ===========================================================================
  // GROUP 2: Dynamic Point Light Priority Sorting & Nearest 8 Selection
  // ===========================================================================
  group('2. Dynamic Point Light Priority Sorting & Nearest 8 Selection', () {
    test('2.1 selectTopActiveLights returns all lights when activeCount <= maxLights', () {
      final DungeonLightSystem system = DungeonLightSystem(maxLights: 8);
      for (int i = 0; i < 5; ++i) {
        system.addLight(
          DungeonLight(
            id: 'light_$i',
            type: LightType.point,
            position: Vector3D(i * 100.0, 0, 0),
            color: const Color(0xFFFFFFFF),
            intensity: 1.0,
            radius: 100.0,
          ),
        );
      }

      final List<DungeonLight> selected = system.selectTopActiveLights(Vector3D.zero);
      expect(selected.length, equals(5));
    });

    test('2.2 Lights with identical intensity and radius prioritize nearest distance to camera', () {
      final DungeonLightSystem system = DungeonLightSystem(maxLights: 8);

      // Create 12 equidistant lights along X axis: 100, 200, 300, ..., 1200
      for (int i = 0; i < 12; ++i) {
        system.addLight(
          DungeonLight(
            id: 'light_$i',
            type: LightType.point,
            position: Vector3D((i + 1) * 100.0, 0, 0),
            color: const Color(0xFFFFFFFF),
            intensity: 2.0,
            radius: 150.0,
          ),
        );
      }

      // Camera at (0, 0, 0)
      final List<DungeonLight> selected = system.selectTopActiveLights(Vector3D.zero);

      expect(selected.length, equals(8));
      // Top lights must be the closest: light_0 (100) through light_7 (800)
      for (int i = 0; i < 8; ++i) {
        expect(selected[i].id, equals('light_$i'));
      }
    });

    test('2.3 Lights at identical distance prioritize higher intensity', () {
      final DungeonLightSystem system = DungeonLightSystem(maxLights: 8);

      // 10 lights on a ring of radius 100 from camera (0,0,0)
      for (int i = 0; i < 10; ++i) {
        final double angle = (i * 2.0 * math.pi) / 10.0;
        system.addLight(
          DungeonLight(
            id: 'ring_light_$i',
            type: LightType.point,
            position: Vector3D(math.cos(angle) * 100.0, math.sin(angle) * 100.0, 0),
            color: const Color(0xFFFFFFFF),
            intensity: (i + 1) * 1.0, // 1.0 to 10.0
            radius: 100.0,
          ),
        );
      }

      final List<DungeonLight> selected = system.selectTopActiveLights(Vector3D.zero);
      expect(selected.length, equals(8));

      // Highest intensity lights (i = 9 down to 2) must be selected
      expect(selected.first.id, equals('ring_light_9')); // intensity 10.0
      expect(selected[1].id, equals('ring_light_8')); // intensity 9.0
      expect(selected.last.id, equals('ring_light_2')); // intensity 3.0

      // Ring light 0 and 1 (intensities 1.0, 2.0) should be dropped
      expect(selected.any((DungeonLight l) => l.id == 'ring_light_0'), isFalse);
      expect(selected.any((DungeonLight l) => l.id == 'ring_light_1'), isFalse);
    });

    test('2.4 Lights at identical distance and intensity prioritize larger radius (quadratic impact weighting)', () {
      final DungeonLightSystem system = DungeonLightSystem(maxLights: 8);

      for (int i = 0; i < 10; ++i) {
        system.addLight(
          DungeonLight(
            id: 'rad_light_$i',
            type: LightType.point,
            position: const Vector3D(100.0, 0, 0),
            color: const Color(0xFFFFFFFF),
            intensity: 2.0,
            radius: 50.0 + i * 20.0, // 50 to 230
          ),
        );
      }

      final List<DungeonLight> selected = system.selectTopActiveLights(Vector3D.zero);
      expect(selected.length, equals(8));

      // Largest radii prioritized
      expect(selected.first.id, equals('rad_light_9')); // radius 230
      expect(selected[1].id, equals('rad_light_8')); // radius 210
    });

    test('2.5 Moving camera dynamically shifts top 8 selection', () {
      final DungeonLightSystem system = DungeonLightSystem(maxLights: 8);

      // Group A at X = 0..400 (5 lights)
      for (int i = 0; i < 5; ++i) {
        system.addLight(
          DungeonLight(
            id: 'group_a_$i',
            type: LightType.point,
            position: Vector3D(i * 100.0, 0, 0),
            color: const Color(0xFFFFFFFF),
            intensity: 2.0,
            radius: 100.0,
          ),
        );
      }

      // Group B at X = 1000..1400 (5 lights)
      for (int i = 0; i < 5; ++i) {
        system.addLight(
          DungeonLight(
            id: 'group_b_$i',
            type: LightType.point,
            position: Vector3D(1000.0 + i * 100.0, 0, 0),
            color: const Color(0xFFFFFFFF),
            intensity: 2.0,
            radius: 100.0,
          ),
        );
      }

      // Total 10 lights
      expect(system.lightCount, equals(10));

      // Camera near Group A at (0, 0, 0)
      final List<DungeonLight> nearA = system.selectTopActiveLights(const Vector3D(0, 0, 0));
      expect(nearA.where((DungeonLight l) => l.id.startsWith('group_a')).length, equals(5));
      expect(nearA.where((DungeonLight l) => l.id.startsWith('group_b')).length, equals(3));

      // Camera near Group B at (1400, 0, 0)
      final List<DungeonLight> nearB = system.selectTopActiveLights(const Vector3D(1400, 0, 0));
      expect(nearB.where((DungeonLight l) => l.id.startsWith('group_b')).length, equals(5));
      expect(nearB.where((DungeonLight l) => l.id.startsWith('group_a')).length, equals(3));
    });

    test('2.6 Singularity protection at distSq == 0 clamps denominator to 1.0 without NaN', () {
      final DungeonLightSystem system = DungeonLightSystem(maxLights: 8);
      system.addLight(
        DungeonLight(
          id: 'zero_dist_light',
          type: LightType.point,
          position: const Vector3D(100.0, 100.0, 50.0),
          color: const Color(0xFFFFFFFF),
          intensity: 3.0,
          radius: 120.0,
        ),
      );

      // Camera exactly at light position
      const Vector3D cam = Vector3D(100.0, 100.0, 50.0);
      final List<DungeonLight> selected = system.selectTopActiveLights(cam);

      expect(selected.length, equals(1));
      expect(selected.first.id, equals('zero_dist_light'));

      final Float32List buffer = system.buildUniformBuffer(
        resolution: const Size(100, 100),
        cameraPos: cam,
      );
      expect(buffer[7], equals(1.0));
      expect(buffer[13].isNaN, isFalse);
    });
  });

  // ===========================================================================
  // GROUP 3: Procedural Torch Flicker Engine & Perlin Noise Generator Determinism
  // ===========================================================================
  group('3. Procedural Torch Flicker Engine & Perlin Noise Determinism', () {
    test('3.1 PerlinNoiseGenerator is deterministic with identical seed', () {
      final PerlinNoiseGenerator genA = PerlinNoiseGenerator(seed: 1337);
      final PerlinNoiseGenerator genB = PerlinNoiseGenerator(seed: 1337);

      for (double x = -10.0; x <= 10.0; x += 0.5) {
        expect(genA.noise1D(x), equals(genB.noise1D(x)));
        expect(genA.noise2D(x, x * 1.5), equals(genB.noise2D(x, x * 1.5)));
        expect(genA.fbm1D(x, octaves: 4), equals(genB.fbm1D(x, octaves: 4)));
      }
    });

    test('3.2 Different seeds produce distinct noise outputs', () {
      final PerlinNoiseGenerator genA = PerlinNoiseGenerator(seed: 1111);
      final PerlinNoiseGenerator genB = PerlinNoiseGenerator(seed: 9999);

      int diffCount = 0;
      for (double x = 0.0; x <= 10.0; x += 0.5) {
        if ((genA.noise1D(x) - genB.noise1D(x)).abs() > 0.01) {
          diffCount++;
        }
      }
      expect(diffCount, greaterThan(15));
    });

    test('3.3 Noise values strictly stay within [-1.0, 1.0] across all coordinates', () {
      final PerlinNoiseGenerator gen = PerlinNoiseGenerator(seed: 42);

      for (double x = -20.0; x <= 20.0; x += 0.5) {
        final double n1 = gen.noise1D(x);
        expect(n1, greaterThanOrEqualTo(-1.0));
        expect(n1, lessThanOrEqualTo(1.0));

        for (double y = -5.0; y <= 5.0; y += 1.0) {
          final double n2 = gen.noise2D(x, y);
          expect(n2, greaterThanOrEqualTo(-1.0));
          expect(n2, lessThanOrEqualTo(1.0));
        }

        final double fbm = gen.fbm1D(x, octaves: 3);
        expect(fbm, greaterThanOrEqualTo(-1.0));
        expect(fbm, lessThanOrEqualTo(1.0));
      }
    });

    test('3.4 PerlinNoiseGenerator C2 quintic fade ensures smooth continuity', () {
      final PerlinNoiseGenerator gen = PerlinNoiseGenerator(seed: 2027);
      const double dx = 0.0001;

      for (double x = 0.0; x < 5.0; x += 0.25) {
        final double y0 = gen.noise1D(x);
        final double y1 = gen.noise1D(x + dx);
        final double delta = (y1 - y0).abs();
        expect(delta, lessThan(0.01), reason: 'Noise must be continuous without jump discontinuities');
      }
    });

    test('3.5 TorchFlickerEngine evaluates deterministically given identical time and parameters', () {
      final TorchFlickerEngine engineA = TorchFlickerEngine(noiseGenerator: PerlinNoiseGenerator(seed: 777));
      final TorchFlickerEngine engineB = TorchFlickerEngine(noiseGenerator: PerlinNoiseGenerator(seed: 777));

      final TorchFlickerSample sA = engineA.evaluate(
        t: 3.1415,
        baseIntensity: 2.0,
        minIntensity: 1.0,
        maxIntensity: 3.0,
        maxWobbleRadius: 5.0,
        baseColor: const Color(0xFFFF9800),
        phase: 1.23,
      );

      final TorchFlickerSample sB = engineB.evaluate(
        t: 3.1415,
        baseIntensity: 2.0,
        minIntensity: 1.0,
        maxIntensity: 3.0,
        maxWobbleRadius: 5.0,
        baseColor: const Color(0xFFFF9800),
        phase: 1.23,
      );

      expect(sA.intensity, equals(sB.intensity));
      expect(sA.positionOffset.x, equals(sB.positionOffset.x));
      expect(sA.positionOffset.y, equals(sB.positionOffset.y));
      expect(sA.positionOffset.z, equals(sB.positionOffset.z));
      expect(sA.colorTint, equals(sB.colorTint));
    });

    test('3.6 TorchFlickerEngine strictly clamps intensity to [minIntensity, maxIntensity]', () {
      final TorchFlickerEngine engine = TorchFlickerEngine();
      const double minI = 1.2;
      const double maxI = 2.4;

      for (double t = 0.0; t <= 15.0; t += 0.1) {
        final TorchFlickerSample sample = engine.evaluate(
          t: t,
          baseIntensity: 1.8,
          minIntensity: minI,
          maxIntensity: maxI,
          maxWobbleRadius: 6.0,
          baseColor: const Color(0xFFFF9800),
        );

        expect(sample.intensity, greaterThanOrEqualTo(minI));
        expect(sample.intensity, lessThanOrEqualTo(maxI));
      }
    });

    test('3.7 TorchFlickerEngine strictly constrains 3D wobble radius within spherical bound', () {
      final TorchFlickerEngine engine = TorchFlickerEngine();
      const double maxWobble = 8.5;

      for (double t = 0.0; t <= 20.0; t += 0.1) {
        final TorchFlickerSample sample = engine.evaluate(
          t: t,
          baseIntensity: 2.0,
          minIntensity: 1.0,
          maxIntensity: 3.0,
          maxWobbleRadius: maxWobble,
          baseColor: const Color(0xFFFF9800),
          phase: t * 0.5,
        );

        final double distance = sample.positionOffset.length;
        expect(distance, lessThanOrEqualTo(maxWobble + 1e-6));
      }
    });

    test('3.8 Phase offset desynchronizes neighboring torches', () {
      final TorchFlickerEngine engine = TorchFlickerEngine();

      final List<double> torch1 = <double>[];
      final List<double> torch2 = <double>[];

      for (double t = 0.0; t <= 2.0; t += 0.1) {
        final TorchFlickerSample s1 = engine.evaluate(
          t: t,
          baseIntensity: 2.0,
          minIntensity: 1.0,
          maxIntensity: 3.0,
          maxWobbleRadius: 5.0,
          baseColor: const Color(0xFFFF9800),
          phase: 0.0,
        );
        final TorchFlickerSample s2 = engine.evaluate(
          t: t,
          baseIntensity: 2.0,
          minIntensity: 1.0,
          maxIntensity: 3.0,
          maxWobbleRadius: 5.0,
          baseColor: const Color(0xFFFF9800),
          phase: 33.7,
        );

        torch1.add(s1.intensity);
        torch2.add(s2.intensity);
      }

      bool hasDiscrepancy = false;
      for (int i = 0; i < torch1.length; ++i) {
        if ((torch1[i] - torch2[i]).abs() > 0.05) {
          hasDiscrepancy = true;
          break;
        }
      }
      expect(hasDiscrepancy, isTrue, reason: 'Different phase offsets must produce decorrelated flicker');
    });

    test('3.9 Color temperature tint shifts between cooler amber and warmer golden yellow', () {
      final TorchFlickerEngine engine = TorchFlickerEngine();

      final TorchFlickerSample coolSample = engine.evaluate(
        t: 0.0,
        baseIntensity: 1.0,
        minIntensity: 1.0,
        maxIntensity: 5.0,
        maxWobbleRadius: 5.0,
        baseColor: const Color(0xFFFF9800),
      );

      final TorchFlickerSample hotSample = engine.evaluate(
        t: 0.0,
        baseIntensity: 5.0,
        minIntensity: 1.0,
        maxIntensity: 5.0,
        maxWobbleRadius: 5.0,
        baseColor: const Color(0xFFFF9800),
      );

      expect(coolSample.colorTint, isNotNull);
      expect(hotSample.colorTint, isNotNull);
      expect(coolSample.colorTint, isNot(equals(hotSample.colorTint)));
    });
  });

  // ===========================================================================
  // GROUP 4: Light Lifetime, Expiration, and Removal Loop
  // ===========================================================================
  group('4. Light Lifetime, Expiration, and Removal Loop', () {
    test('4.1 Permanent light (lifetime == null) never expires and maintains normalizedLifeProgress 0.0', () {
      final DungeonLight light = DungeonLight(
        id: 'torch_perm',
        type: LightType.torch,
        position: Vector3D.zero,
        color: const Color(0xFFFF9800),
        intensity: 2.0,
        radius: 100.0,
        lifetime: null,
      );

      expect(light.isExpired, isFalse);
      expect(light.normalizedLifeProgress, equals(0.0));

      final DungeonLightSystem system = DungeonLightSystem();
      system.addLight(light);

      // Advance by 100 seconds
      system.update(100.0);
      expect(light.isExpired, isFalse);
      expect(system.getLight('torch_perm'), isNotNull);
      expect(system.lightCount, equals(1));
    });

    test('4.2 Temporary light tracks normalizedLifeProgress and marks isExpired true at end of life', () {
      final DungeonLight light = DungeonLight(
        id: 'rune_spell',
        type: LightType.pulsingRune,
        position: Vector3D.zero,
        color: const Color(0xFF9C27B0),
        intensity: 2.0,
        radius: 100.0,
        lifetime: 4.0,
      );

      expect(light.isExpired, isFalse);
      expect(light.normalizedLifeProgress, equals(0.0));

      light.elapsedAge = 2.0;
      expect(light.isExpired, isFalse);
      expect(light.normalizedLifeProgress, closeTo(0.5, 1e-5));

      light.elapsedAge = 4.0;
      expect(light.isExpired, isTrue);
      expect(light.normalizedLifeProgress, equals(1.0));

      light.elapsedAge = 6.0;
      expect(light.isExpired, isTrue);
      expect(light.normalizedLifeProgress, equals(1.0)); // clamped to 1.0
    });

    test('4.3 update(dt) removal loop automatically prunes expired lights', () {
      final DungeonLightSystem system = DungeonLightSystem();

      system.addLight(
        DungeonLight(
          id: 'temp_1',
          type: LightType.point,
          position: Vector3D.zero,
          color: const Color(0xFFFFFFFF),
          intensity: 1.0,
          radius: 100.0,
          lifetime: 2.0,
        ),
      );

      system.addLight(
        DungeonLight(
          id: 'perm_1',
          type: LightType.point,
          position: Vector3D.zero,
          color: const Color(0xFFFFFFFF),
          intensity: 1.0,
          radius: 100.0,
          lifetime: null,
        ),
      );

      expect(system.lightCount, equals(2));

      // Advance 1.0s (temp_1 age = 1.0, lifetime = 2.0 -> active)
      system.update(1.0);
      expect(system.lightCount, equals(2));
      expect(system.getLight('temp_1'), isNotNull);

      // Advance another 1.5s (temp_1 age = 2.5 > 2.0 -> pruned)
      system.update(1.5);
      expect(system.lightCount, equals(1));
      expect(system.getLight('temp_1'), isNull);
      expect(system.getLight('perm_1'), isNotNull);
    });

    test('4.4 Multiple lights expiring in the same frame are pruned cleanly without ConcurrentModificationError', () {
      final DungeonLightSystem system = DungeonLightSystem();

      for (int i = 0; i < 10; ++i) {
        system.addLight(
          DungeonLight(
            id: 'batch_exp_$i',
            type: LightType.point,
            position: Vector3D(i * 10.0, 0, 0),
            color: const Color(0xFFFFFFFF),
            intensity: 1.0,
            radius: 50.0,
            lifetime: 1.0,
          ),
        );
      }

      expect(system.lightCount, equals(10));

      // Step past expiration
      expect(() => system.update(1.5), returnsNormally);
      expect(system.lightCount, equals(0));
    });

    test('4.5 Fiery explosion light expands, decays, and auto-expires', () {
      final DungeonLightSystem system = DungeonLightSystem();
      final DungeonLight explosion = system.castFieryExplosion(
        id: 'fireball_boom',
        position: const Vector3D(50, 50, 0),
        peakIntensity: 8.0,
        maxRadius: 300.0,
        duration: 1.2,
      );

      expect(system.lightCount, equals(1));

      // 1. Attack phase: peak flare at 15% (0.18s)
      system.update(0.18, currentTime: 0.18);
      expect(explosion.currentIntensity, greaterThan(3.0));

      // 2. Decay phase: intensity decreases, radius expands
      system.update(0.5, currentTime: 0.68);
      expect(explosion.currentRadius, greaterThan(explosion.initialExplosionRadius));

      // 3. Complete duration -> pruned
      system.update(0.6, currentTime: 1.28);
      expect(system.getLight('fireball_boom'), isNull);
      expect(system.lightCount, equals(0));
    });

    test('4.6 Pulsing rune oscillates intensity and radius', () {
      final DungeonLightSystem system = DungeonLightSystem();
      final DungeonLight rune = system.castPulsingRune(
        id: 'rune_altar',
        position: const Vector3D(10, 10, 0),
        baseIntensity: 2.0,
        radius: 100.0,
        pulseFreq: 1.0,
      );

      system.update(0.0, currentTime: 0.0);
      final double intA = rune.currentIntensity;

      system.update(0.25, currentTime: 0.25);
      final double intB = rune.currentIntensity;

      expect(intA, isNot(equals(intB)));
    });

    test('4.7 Ethereal soul wanders on 3D Lissajous orbit trajectory', () {
      final DungeonLightSystem system = DungeonLightSystem();
      const Vector3D origin = Vector3D(100.0, 100.0, 50.0);
      final DungeonLight soul = system.castEtherealSoul(
        id: 'soul_spirit',
        origin: origin,
        orbitRadius: 40.0,
      );

      system.update(0.0, currentTime: 0.0);
      final Vector3D pos0 = soul.currentPosition;

      system.update(1.5, currentTime: 1.5);
      final Vector3D pos1 = soul.currentPosition;

      expect(pos0.distanceTo(pos1), greaterThan(5.0));
      expect(pos1.distanceTo(origin), lessThanOrEqualTo(40.0 * 1.35));
    });

    test('4.8 Container operations: add, get, remove, clear', () {
      final DungeonLightSystem system = DungeonLightSystem();

      final DungeonLight l1 = DungeonLight(
        id: 'L1',
        type: LightType.point,
        position: Vector3D.zero,
        color: const Color(0xFFFFFFFF),
        intensity: 1.0,
        radius: 10.0,
      );

      system.addLight(l1);
      expect(system.lightCount, equals(1));
      expect(system.getLight('L1'), equals(l1));

      final DungeonLight? removed = system.removeLight('L1');
      expect(removed, equals(l1));
      expect(system.lightCount, equals(0));
      expect(system.getLight('L1'), isNull);

      system.addLight(l1);
      system.clear();
      expect(system.lightCount, equals(0));
    });
  });

  // ===========================================================================
  // GROUP 5: GLSL Shader Structure & Math Parity
  // ===========================================================================
  group('5. GLSL Shader Structure & Math Parity', () {
    late File shaderFile;
    late String shaderCode;

    setUpAll(() {
      shaderFile = File('shaders/lighting/dungeon_lighting.frag');
      expect(shaderFile.existsSync(), isTrue, reason: 'dungeon_lighting.frag must exist');
      shaderCode = shaderFile.readAsStringSync();
    });

    test('5.1 Shader begins with version 460 core and flutter runtime include', () {
      expect(shaderCode, contains('#version 460 core'));
      expect(shaderCode, contains('#include <flutter/runtime_effect.glsl>'));
    });

    test('5.2 Uniform declarations match exact 109-float layout and sequence', () {
      expect(shaderCode, contains('uniform vec2 uResolution;'));
      expect(shaderCode, contains('uniform float uTime;'));
      expect(shaderCode, contains('uniform vec3 uAmbientColor;'));
      expect(shaderCode, contains('uniform float uAmbientIntensity;'));
      expect(shaderCode, contains('uniform float uLightCount;'));
      expect(shaderCode, contains('uniform float uAoModulation;'));
      expect(shaderCode, contains('uniform float uShadowSoftness;'));
      expect(shaderCode, contains('uniform vec3 uCameraPos;'));
      expect(shaderCode, contains('uniform vec4 uLightPosRadius[8];'));
      expect(shaderCode, contains('uniform vec4 uLightColorIntensity[8];'));
      expect(shaderCode, contains('uniform vec4 uLightParams[8];'));
    });

    test('5.3 Sampler uTexture is declared strictly after all numeric uniforms', () {
      final int paramIdx = shaderCode.indexOf('uLightParams[8]');
      final int samplerIdx = shaderCode.indexOf('uniform sampler2D uTexture');
      expect(paramIdx, greaterThan(-1));
      expect(samplerIdx, greaterThan(paramIdx), reason: 'uTexture sampler must follow numeric uniforms in Flutter runtime effects');
    });

    test('5.4 UE4 Windowed inverse square falloff reaches 0.0 at dist >= radius', () {
      const double radius = 120.0;
      expect(LightingAttenuationEngine.evaluateWindowedInverseSquare(0.0, radius), closeTo(1.0, 1e-4));
      expect(LightingAttenuationEngine.evaluateWindowedInverseSquare(60.0, radius), greaterThan(0.0));
      expect(LightingAttenuationEngine.evaluateWindowedInverseSquare(radius, radius), equals(0.0));
      expect(LightingAttenuationEngine.evaluateWindowedInverseSquare(radius + 20.0, radius), equals(0.0));
    });

    test('5.5 Hermite smoothstep falloff reaches 0.0 at dist >= radius', () {
      const double radius = 100.0;
      expect(LightingAttenuationEngine.evaluateSmoothstepFalloff(0.0, radius), closeTo(1.0, 1e-4));
      expect(LightingAttenuationEngine.evaluateSmoothstepFalloff(radius, radius), equals(0.0));
    });

    test('5.6 Linear falloff scales strictly linearly', () {
      const double radius = 100.0;
      expect(LightingAttenuationEngine.evaluateLinearFalloff(0.0, radius), equals(1.0));
      expect(LightingAttenuationEngine.evaluateLinearFalloff(25.0, radius), closeTo(0.75, 1e-5));
      expect(LightingAttenuationEngine.evaluateLinearFalloff(50.0, radius), closeTo(0.50, 1e-5));
      expect(LightingAttenuationEngine.evaluateLinearFalloff(100.0, radius), equals(0.0));
    });

    test('5.7 ACES Filmic tonemapping compresses high values into [0, 1]', () {
      double aces(double x) {
        const double a = 2.51;
        const double b = 0.03;
        const double c = 2.43;
        const double d = 0.59;
        const double e = 0.14;
        return ((x * (a * x + b)) / (x * (c * x + d) + e)).clamp(0.0, 1.0);
      }

      expect(aces(0.0), closeTo(0.0, 1e-4));
      expect(aces(1.0), closeTo(0.803, 0.02));
      expect(aces(10.0), greaterThan(0.98));
      expect(aces(1000.0), lessThanOrEqualTo(1.0));
    });
  });

  // ===========================================================================
  // GROUP 6: Widget & CustomPainter Tests for Dungeon Lighting
  // ===========================================================================
  group('6. Widget & CustomPainter Tests for Dungeon Lighting', () {
    testWidgets('6.1 DungeonLightingShaderWidget builds uniform buffer and renders canvas', (tester) async {
      final DungeonLightSystem system = DungeonLightSystem();
      system.addTorch(id: 'torch_w1', position: const Vector3D(50, 50, 20), radius: 80.0);
      system.addTorch(id: 'torch_w2', position: const Vector3D(150, 150, 20), radius: 100.0);

      Float32List? capturedUniforms;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DungeonLightingShaderWidget(
                system: system,
                resolution: const Size(300, 300),
                cameraPos: const Vector3D(150, 150, 200),
                time: 1.0,
                onUniformsBuilt: (Float32List u) => capturedUniforms = u,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DungeonLightingShaderWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(capturedUniforms, isNotNull);
      expect(capturedUniforms!.length, equals(109));
      expect(capturedUniforms![7], equals(2.0)); // 2 lights
    });

    testWidgets('6.2 Repainting widget updates uniforms when light positions or counts change', (tester) async {
      final DungeonLightSystem system = DungeonLightSystem();
      Float32List? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DungeonLightingShaderWidget(
              system: system,
              resolution: const Size(200, 200),
              cameraPos: Vector3D.zero,
              onUniformsBuilt: (Float32List u) => captured = u,
            ),
          ),
        ),
      );

      expect(captured![7], equals(0.0));

      // Add a dynamic rune light
      system.castPulsingRune(id: 'dynamic_rune', position: const Vector3D(80, 80, 10));

      // Trigger rebuild
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DungeonLightingShaderWidget(
              system: system,
              resolution: const Size(200, 200),
              cameraPos: Vector3D.zero,
              onUniformsBuilt: (Float32List u) => captured = u,
            ),
          ),
        ),
      );

      expect(captured![7], equals(1.0));
      expect(captured![13], equals(80.0)); // lightPos.x
      expect(captured![14], equals(80.0)); // lightPos.y
    });

    test('6.3 DungeonLightingTestPainter.shouldRepaint returns true on change, false on identical state', () {
      final Float32List b1 = Float32List(109);
      final Float32List b2 = Float32List(109);
      b2[0] = 500.0;

      const DungeonLightingTestPainter p1 = DungeonLightingTestPainter(uniforms: b1, activeLightCount: 1);
      const DungeonLightingTestPainter p2 = DungeonLightingTestPainter(uniforms: b2, activeLightCount: 1);
      const DungeonLightingTestPainter p3 = DungeonLightingTestPainter(uniforms: b1, activeLightCount: 1);
      const DungeonLightingTestPainter p4 = DungeonLightingTestPainter(uniforms: b1, activeLightCount: 2);

      expect(p1.shouldRepaint(p2), isTrue, reason: 'Different buffer instance returns true');
      expect(p1.shouldRepaint(p3), isFalse, reason: 'Identical buffer and count returns false');
      expect(p1.shouldRepaint(p4), isTrue, reason: 'Different active light count returns true');
    });

    testWidgets('6.4 DungeonCinematicAtmosphere mounts with CaveCardTheme and pumps animation ticks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: DungeonCinematicAtmosphere(
                theme: CaveCardTheme.fungalVortex,
                child: Text('Dungeon Arena Overlay'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Dungeon Arena Overlay'), findsOneWidget);
      expect(find.byType(DungeonCinematicAtmosphere), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Advance frames
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Dungeon Arena Overlay'), findsOneWidget);
    });

    testWidgets('6.5 Spells cast in DungeonAtmosphereController update lightSystem inside widget tree', (tester) async {
      final DungeonAtmosphereController controller = DungeonAtmosphereController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DungeonCinematicAtmosphere(
              controller: controller,
              theme: CaveCardTheme.fungalVortex,
            ),
          ),
        ),
      );

      // Initially torches are seeded
      final int initialLightCount = controller.lightSystem.lightCount;
      expect(initialLightCount, greaterThan(0));

      // Trigger a spell fireball explosion
      controller.triggerMagicSpellFlare();
      expect(controller.lightSystem.lightCount, greaterThan(initialLightCount));

      // Advance simulation
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));

      controller.dispose();
    });

    testWidgets('6.6 DungeonCinematicAtmosphere cleanly disposes tickers and controllers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DungeonCinematicAtmosphere(
              theme: CaveCardTheme.fungalVortex,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      // Unmount
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(DungeonCinematicAtmosphere), findsNothing);
    });
  });
}
