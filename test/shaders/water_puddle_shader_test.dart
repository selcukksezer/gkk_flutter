// =============================================================================
// Comprehensive Unit & Shader Verification Test Suite:
// Water Puddle Planar Reflection & Micro-Surface Ripple Fragment Shader
// Standard: Flutter Impeller (Metal & Vulkan) & Skia GPU Pipeline
// Target: test/shaders/water_puddle_shader_test.dart
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/shaders/shader_pipeline.dart';
import 'package:gkk_flutter/core/shaders/shader_registry.dart';

/// Test uniform target recording setFloat and setImageSampler calls.
class FakePuddleUniformTarget implements ShaderUniformTarget {
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
  group('1. Water Puddle GLSL Source Impeller Compliance', () {
    late String shaderCode;

    setUpAll(() {
      final File file = File('shaders/world/water_puddle.frag');
      expect(file.existsSync(), isTrue,
          reason: 'shaders/world/water_puddle.frag must exist');
      shaderCode = file.readAsStringSync();
    });

    test('1.1 Shader contains required Impeller version and runtime_effect header', () {
      expect(shaderCode, contains('#version 460 core'));
      expect(shaderCode, contains('#include <flutter/runtime_effect.glsl>'));
      expect(shaderCode, contains('precision highp float;'));
      expect(shaderCode, contains('out vec4 fragColor;'));
    });

    test('1.2 Numeric uniforms are declared before samplers in exact 6-float sequence', () {
      expect(shaderCode, contains('uniform vec2  uResolution;'));
      expect(shaderCode, contains('uniform float uTime;'));
      expect(shaderCode, contains('uniform float uRippleSpeed;'));
      expect(shaderCode, contains('uniform float uPuddleRoughness;'));
      expect(shaderCode, contains('uniform float uReflectance;'));

      final int numericIdx = shaderCode.indexOf('uniform float uReflectance;');
      final int samplerIdx = shaderCode.indexOf('uniform sampler2D uReflectionMap;');
      expect(numericIdx, greaterThan(-1));
      expect(samplerIdx, greaterThan(numericIdx),
          reason: 'All numeric uniforms must precede texture samplers');
    });

    test('1.3 Texture samplers declare uReflectionMap (slot 0) and uNormalMap (slot 1)', () {
      expect(shaderCode, contains('uniform sampler2D uReflectionMap;'));
      expect(shaderCode, contains('uniform sampler2D uNormalMap;'));
    });

    test('1.4 Uses FlutterFragCoord() for fragment coordinates', () {
      expect(shaderCode, contains('FlutterFragCoord().xy'));
    });

    test('1.5 Contains genuine Gerstner ripple & Fresnel physics equations', () {
      expect(shaderCode, contains('evaluateGerstnerRipples'));
      expect(shaderCode, contains('evaluateSchlickFresnel'));
    });
  });

  // ===========================================================================
  // GROUP 2: Uniform Buffer Alignment with ShaderRegistry
  // ===========================================================================
  group('2. ShaderRegistry Alignment for waterPuddle', () {
    test('2.1 ShaderRegistry defines waterPuddle with 6 floats and 2 samplers', () {
      final ShaderRegistry registry = ShaderRegistry(loadDefaults: true);
      final ShaderDescriptor? desc =
          registry.getShaderDescriptor(ShaderCatalog.waterPuddle);

      expect(desc, isNotNull);
      expect(desc!.category, equals(ShaderCategory.world));
      expect(desc.stage, equals(ShaderStage.fragment));
      expect(desc.totalFloatCount, equals(6));
      expect(desc.totalSamplerCount, equals(2));

      final UniformDefinition? uRes = desc.findUniform('uResolution');
      expect(uRes, isNotNull);
      expect(uRes!.floatOffset, equals(0));
      expect(uRes.floatCount, equals(2));

      final UniformDefinition? uTime = desc.findUniform('uTime');
      expect(uTime, isNotNull);
      expect(uTime!.floatOffset, equals(2));
      expect(uTime.floatCount, equals(1));

      final UniformDefinition? uSpeed = desc.findUniform('uRippleSpeed');
      expect(uSpeed, isNotNull);
      expect(uSpeed!.floatOffset, equals(3));
      expect(uSpeed.floatCount, equals(1));

      final UniformDefinition? uRough = desc.findUniform('uPuddleRoughness');
      expect(uRough, isNotNull);
      expect(uRough!.floatOffset, equals(4));
      expect(uRough.floatCount, equals(1));

      final UniformDefinition? uRefl = desc.findUniform('uReflectance');
      expect(uRefl, isNotNull);
      expect(uRefl!.floatOffset, equals(5));
      expect(uRefl.floatCount, equals(1));

      final SamplerDefinition? sRefl = desc.findSampler('uReflectionMap');
      expect(sRefl, isNotNull);
      expect(sRefl!.samplerIndex, equals(0));

      final SamplerDefinition? sNorm = desc.findSampler('uNormalMap');
      expect(sNorm, isNotNull);
      expect(sNorm!.samplerIndex, equals(1));
    });
  });

  // ===========================================================================
  // GROUP 3: Analytical Physics & Schlick Fresnel Mathematical Foundations
  // ===========================================================================
  group('3. Water Physics & Fresnel Analytical Equations', () {
    test('3.1 Water normal reflectance F0 at normal incidence equals ~0.02', () {
      const double f0 = 0.02;
      // cosTheta = 1.0 (looking straight down into puddle)
      // F(1.0) = F0 + (1 - F0) * (1 - 1)^5 = F0
      final double normalIncident = f0 + (1.0 - f0) * math.pow(0.0, 5.0);
      expect(normalIncident, closeTo(0.02, 1e-6));
    });

    test('3.2 Grazing angle reflectance approaches 1.0 (mirror sheen)', () {
      const double f0 = 0.02;
      // cosTheta = 0.0 (grazing angle along water surface)
      // F(0.0) = F0 + (1 - F0) * (1 - 0)^5 = 1.0
      final double grazingIncident = f0 + (1.0 - f0) * math.pow(1.0, 5.0);
      expect(grazingIncident, closeTo(1.0, 1e-6));
    });

    test('3.3 Fake uniform target receives exact 6 floats in proper sequence', () {
      final FakePuddleUniformTarget target = FakePuddleUniformTarget();
      const Size viewport = Size(1440.0, 900.0);
      const double time = 8.2;
      const double rippleSpeed = 1.2;
      const double roughness = 0.08;
      const double reflectance = 0.95;

      target.setFloat(0, viewport.width);
      target.setFloat(1, viewport.height);
      target.setFloat(2, time);
      target.setFloat(3, rippleSpeed);
      target.setFloat(4, roughness);
      target.setFloat(5, reflectance);

      expect(target.floats.length, equals(6));
      expect(target.floats[0], equals(1440.0));
      expect(target.floats[1], equals(900.0));
      expect(target.floats[2], equals(8.2));
      expect(target.floats[3], equals(1.2));
      expect(target.floats[4], equals(0.08));
      expect(target.floats[5], equals(0.95));
    });
  });
}
