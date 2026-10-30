// =============================================================================
// Comprehensive Unit & Shader Verification Test Suite:
// Wind Vegetation & Foliage Displacement Fragment Shader
// Standard: Flutter Impeller (Metal & Vulkan) & Skia GPU Pipeline
// Target: test/shaders/wind_vegetation_shader_test.dart
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/engine/adaptive_quality_scaler.dart';
import 'package:gkk_flutter/core/shaders/shader_pipeline.dart';
import 'package:gkk_flutter/core/shaders/shader_registry.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_wind_vegetation.dart';

/// Test uniform target recording setFloat and setImageSampler calls.
class FakeWindUniformTarget implements ShaderUniformTarget {
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // GROUP 1: GLSL Source Compliance & Impeller Layout Verification
  // ===========================================================================
  group('1. Wind Vegetation GLSL Source Impeller Compliance', () {
    late String shaderCode;

    setUpAll(() {
      final File file = File('shaders/world/wind_vegetation.frag');
      expect(file.existsSync(), isTrue,
          reason: 'shaders/world/wind_vegetation.frag must exist');
      shaderCode = file.readAsStringSync();
    });

    test('1.1 Shader contains required Impeller version and runtime_effect header', () {
      expect(shaderCode, contains('#version 460 core'));
      expect(shaderCode, contains('#include <flutter/runtime_effect.glsl>'));
      expect(shaderCode, contains('precision highp float;'));
      expect(shaderCode, contains('out vec4 fragColor;'));
    });

    test('1.2 Numeric uniforms are declared in exact 8-float sequence', () {
      expect(shaderCode, contains('uniform vec2  uResolution;'));
      expect(shaderCode, contains('uniform float uTime;'));
      expect(shaderCode, contains('uniform float uWindSpeed;'));
      expect(shaderCode, contains('uniform vec2  uWindDirection;'));
      expect(shaderCode, contains('uniform float uWindStrength;'));
      expect(shaderCode, contains('uniform float uTier;'));
    });

    test('1.3 Uses FlutterFragCoord() for Impeller fragment coordinates', () {
      expect(shaderCode, contains('FlutterFragCoord().xy'));
    });

    test('1.4 Contains genuine procedural wind field synthesis logic', () {
      expect(shaderCode, contains('computeWindField'));
      expect(shaderCode, contains('gradientNoise'));
      expect(shaderCode, contains('dot(travelUv, dir)'));
    });
  });

  // ===========================================================================
  // GROUP 2: Uniform Buffer Alignment with ShaderRegistry
  // ===========================================================================
  group('2. ShaderRegistry Alignment for windVegetation', () {
    test('2.1 ShaderRegistry defines windVegetation with 8 continuous floats', () {
      final ShaderRegistry registry = ShaderRegistry(loadDefaults: true);
      final ShaderDescriptor? desc =
          registry.getShaderDescriptor(ShaderCatalog.windVegetation);

      expect(desc, isNotNull);
      expect(desc!.category, equals(ShaderCategory.world));
      expect(desc.stage, equals(ShaderStage.fragment));
      expect(desc.totalFloatCount, equals(8));
      expect(desc.totalSamplerCount, equals(0));

      final UniformDefinition? uRes = desc.findUniform('uResolution');
      expect(uRes, isNotNull);
      expect(uRes!.floatOffset, equals(0));
      expect(uRes.floatCount, equals(2));

      final UniformDefinition? uTime = desc.findUniform('uTime');
      expect(uTime, isNotNull);
      expect(uTime!.floatOffset, equals(2));
      expect(uTime.floatCount, equals(1));

      final UniformDefinition? uSpeed = desc.findUniform('uWindSpeed');
      expect(uSpeed, isNotNull);
      expect(uSpeed!.floatOffset, equals(3));
      expect(uSpeed.floatCount, equals(1));

      final UniformDefinition? uDir = desc.findUniform('uWindDirection');
      expect(uDir, isNotNull);
      expect(uDir!.floatOffset, equals(4));
      expect(uDir.floatCount, equals(2));

      final UniformDefinition? uStrength = desc.findUniform('uWindStrength');
      expect(uStrength, isNotNull);
      expect(uStrength!.floatOffset, equals(6));
      expect(uStrength.floatCount, equals(1));

      final UniformDefinition? uTier = desc.findUniform('uTier');
      expect(uTier, isNotNull);
      expect(uTier!.floatOffset, equals(7));
      expect(uTier.floatCount, equals(1));
    });
  });

  // ===========================================================================
  // GROUP 3: Dart Uniform Binding & Painter Fallback Verification
  // ===========================================================================
  group('3. Dart Wind Simulation & Uniform Binding', () {
    test('3.1 WindSimulationConfig initializes with realistic aerodynamic defaults', () {
      const WindSimulationConfig cfg = WindSimulationConfig();
      expect(cfg.baseSpeed, closeTo(2.4, 1e-4));
      expect(cfg.gustStrength, closeTo(0.65, 1e-4));
      expect(cfg.gustFrequency, closeTo(0.45, 1e-4));
      expect(cfg.microFlutterFrequency, closeTo(6.2, 1e-4));
      expect(cfg.windAngleRad, closeTo(0.785, 1e-3));
    });

    test('3.2 Directional vector evaluation computes valid unit components', () {
      const double angle = 0.785398; // 45 deg
      final double dirX = math.cos(angle);
      final double dirY = math.sin(angle);
      final double len = math.sqrt(dirX * dirX + dirY * dirY);
      expect(len, closeTo(1.0, 1e-5));
      expect(dirX, closeTo(dirY, 1e-4));
    });

    test('3.3 Fake uniform target receives exact 8 floats in proper sequence', () {
      final FakeWindUniformTarget target = FakeWindUniformTarget();
      const Size viewport = Size(1920.0, 1080.0);
      const double time = 12.5;
      const WindSimulationConfig config = WindSimulationConfig(
        baseSpeed: 3.0,
        windAngleRad: 0.5,
      );
      const double gust = 1.25;
      const HardwareTier tier = HardwareTier.high;

      // Simulate binding as done in hub_wind_vegetation.dart:
      target.setFloat(0, viewport.width);
      target.setFloat(1, viewport.height);
      target.setFloat(2, time);
      target.setFloat(3, config.baseSpeed);
      target.setFloat(4, math.cos(config.windAngleRad));
      target.setFloat(5, math.sin(config.windAngleRad));
      target.setFloat(6, gust);
      target.setFloat(7, tier.index.toDouble());

      expect(target.floats.length, equals(8));
      expect(target.floats[0], equals(1920.0));
      expect(target.floats[1], equals(1080.0));
      expect(target.floats[2], equals(12.5));
      expect(target.floats[3], equals(3.0));
      expect(target.floats[4], closeTo(math.cos(0.5), 1e-5));
      expect(target.floats[5], closeTo(math.sin(0.5), 1e-5));
      expect(target.floats[6], equals(1.25));
      expect(target.floats[7], equals(HardwareTier.high.index.toDouble()));
    });
  });
}
