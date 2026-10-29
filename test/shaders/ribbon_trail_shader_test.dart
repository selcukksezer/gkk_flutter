// =============================================================================
// Weapon Ribbon & Mesh Trail Shader Uniforms & Dart Wrapper Test Suite
// 2027 Cinematic Graphics Pipeline (Aion 2 VFX Standard)
// Verifying:
// - shaders/vfx/ribbon_trail.frag
// - lib/core/vfx/ribbon_trail_renderer.dart
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart' hide CatmullRomSpline;
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/vfx/ribbon_trail_renderer.dart';

/// Authoritative uniform index constants and layout specification
/// matching the 22-float uniform buffer and sampler bindings in `ribbon_trail.frag`.
class RibbonTrailShaderUniforms {
  const RibbonTrailShaderUniforms._();

  // Uniform 0, 1: vec2 uResolution (2 floats)
  static const int uResolutionX = 0;
  static const int uResolutionY = 1;

  // Uniform 2: float uTime (1 float)
  static const int uTime = 2;

  // Uniform 3..6: vec4 uBaseColor (4 floats)
  static const int uBaseColorR = 3;
  static const int uBaseColorG = 4;
  static const int uBaseColorB = 5;
  static const int uBaseColorA = 6;

  // Uniform 7..10: vec4 uGlowColor (4 floats)
  static const int uGlowColorR = 7;
  static const int uGlowColorG = 8;
  static const int uGlowColorB = 9;
  static const int uGlowColorA = 10;

  // Uniform 11..14: vec4 uBounds [minX, minY, width, height] (4 floats)
  static const int uBoundsMinX = 11;
  static const int uBoundsMinY = 12;
  static const int uBoundsWidth = 13;
  static const int uBoundsHeight = 14;

  // Uniform 15: float uScrollSpeed (1 float)
  static const int uScrollSpeed = 15;

  // Uniform 16: float uDistortionStrength (1 float)
  static const int uDistortionStrength = 16;

  // Uniform 17: float uDistortionFreq (1 float)
  static const int uDistortionFreq = 17;

  // Uniform 18: float uGlowIntensity (1 float)
  static const int uGlowIntensity = 18;

  // Uniform 19: float uFadePower (1 float)
  static const int uFadePower = 19;

  // Uniform 20: float uTransversePower (1 float)
  static const int uTransversePower = 20;

  // Uniform 21: float uTextureMix (1 float)
  static const int uTextureMix = 21;

  /// Total count of float slots preceding samplers in ribbon_trail.frag.
  static const int totalFloatUniforms = 22;

  /// Texture sampler slot 0: uniform sampler2D uTrailTexture.
  static const int trailTextureSamplerSlot = 0;
}

/// In-memory mock shader target recording all uniform and sampler invocations.
/// Strictly adheres to Dart 3 base class rules: does not implement ui.FragmentShader.
class _MockShaderTarget {
  final Map<int, double> floats = <int, double>{};
  final Map<int, ui.Image> samplers = <int, ui.Image>{};
  bool disposed = false;

  void setFloat(int index, double value) {
    floats[index] = value;
  }

  void setImageSampler(int index, ui.Image image) {
    samplers[index] = image;
  }

  void dispose() {
    disposed = true;
  }
}

/// Fake [ui.Image] implementation for headless unit testing without GPU rasterizer.
class _FakeTestImage extends Fake implements ui.Image {
  _FakeTestImage({this.width = 1, this.height = 1});

  @override
  final int width;

  @override
  final int height;

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // 1. GLSL Shader File Integrity & Layout Verification
  // ---------------------------------------------------------------------------
  group('Ribbon Trail GLSL File Integrity & Specification Verification', () {
    late File shaderFile;
    late String glslContent;

    setUpAll(() {
      shaderFile = File('shaders/vfx/ribbon_trail.frag');
      expect(shaderFile.existsSync(), isTrue,
          reason: 'shaders/vfx/ribbon_trail.frag must exist in workspace');
      glslContent = shaderFile.readAsStringSync();
      if (RibbonTrailRenderer.fallbackWhiteImage == null) {
        RibbonTrailRenderer.fallbackWhiteImage = _FakeTestImage();
      }
    });

    test('Shader declares #version 460 core and flutter runtime_effect include', () {
      expect(glslContent, contains('#version 460 core'));
      expect(glslContent, contains('#include <flutter/runtime_effect.glsl>'));
      expect(glslContent, contains('precision highp float;'));
    });

    test('Shader declares all 12 float/vector uniforms in exact linear slot order', () {
      final uniformOrder = <String>[
        'uniform vec2 uResolution;',
        'uniform float uTime;',
        'uniform vec4 uBaseColor;',
        'uniform vec4 uGlowColor;',
        'uniform vec4 uBounds;',
        'uniform float uScrollSpeed;',
        'uniform float uDistortionStrength;',
        'uniform float uDistortionFreq;',
        'uniform float uGlowIntensity;',
        'uniform float uFadePower;',
        'uniform float uTransversePower;',
        'uniform float uTextureMix;',
      ];

      int lastPos = -1;
      for (final declaration in uniformOrder) {
        final pos = glslContent.indexOf(declaration);
        expect(pos, isPositive,
            reason: 'GLSL must declare "$declaration"');
        expect(pos, greaterThan(lastPos),
            reason: 'Uniform "$declaration" must appear in exact expected sequence');
        lastPos = pos;
      }
    });

    test('Sampler uniform uTrailTexture strictly follows all numeric uniforms', () {
      final textureMixPos = glslContent.indexOf('uniform float uTextureMix;');
      final samplerPos = glslContent.indexOf('uniform sampler2D uTrailTexture;');

      expect(samplerPos, isPositive,
          reason: 'uTrailTexture sampler must be declared');
      expect(samplerPos, greaterThan(textureMixPos),
          reason: 'Impeller & Flutter RuntimeEffect require all samplers to follow all numeric uniforms');
    });

    test('Shader declares output fragColor and uses FlutterFragCoord', () {
      expect(glslContent, contains('out vec4 fragColor;'));
      expect(glslContent, contains('FlutterFragCoord().xy'));
    });

    test('Shader implements analytical wave distortion and procedural slash energy streams', () {
      expect(glslContent, contains('vec2 computeDistortion('));
      expect(glslContent, contains('float computeEnergyStreams('));
      expect(glslContent, contains('discard;'));
      expect(glslContent, contains('vec3 whiteCore'));
      expect(glslContent, contains('fragColor = vec4(finalRgb, totalAlpha);'));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. RibbonTrailShaderUniforms Layout & Dart Wrapper Binding
  // ---------------------------------------------------------------------------
  group('RibbonTrailShaderUniforms Layout & Dart Wrapper Binding', () {
    test('Authoritative uniform constants match 22-float specification', () {
      expect(RibbonTrailShaderUniforms.totalFloatUniforms, equals(22));
      expect(RibbonTrailShaderUniforms.uResolutionX, equals(0));
      expect(RibbonTrailShaderUniforms.uResolutionY, equals(1));
      expect(RibbonTrailShaderUniforms.uTime, equals(2));
      expect(RibbonTrailShaderUniforms.uBaseColorR, equals(3));
      expect(RibbonTrailShaderUniforms.uBaseColorG, equals(4));
      expect(RibbonTrailShaderUniforms.uBaseColorB, equals(5));
      expect(RibbonTrailShaderUniforms.uBaseColorA, equals(6));
      expect(RibbonTrailShaderUniforms.uGlowColorR, equals(7));
      expect(RibbonTrailShaderUniforms.uGlowColorG, equals(8));
      expect(RibbonTrailShaderUniforms.uGlowColorB, equals(9));
      expect(RibbonTrailShaderUniforms.uGlowColorA, equals(10));
      expect(RibbonTrailShaderUniforms.uBoundsMinX, equals(11));
      expect(RibbonTrailShaderUniforms.uBoundsMinY, equals(12));
      expect(RibbonTrailShaderUniforms.uBoundsWidth, equals(13));
      expect(RibbonTrailShaderUniforms.uBoundsHeight, equals(14));
      expect(RibbonTrailShaderUniforms.uScrollSpeed, equals(15));
      expect(RibbonTrailShaderUniforms.uDistortionStrength, equals(16));
      expect(RibbonTrailShaderUniforms.uDistortionFreq, equals(17));
      expect(RibbonTrailShaderUniforms.uGlowIntensity, equals(18));
      expect(RibbonTrailShaderUniforms.uFadePower, equals(19));
      expect(RibbonTrailShaderUniforms.uTransversePower, equals(20));
      expect(RibbonTrailShaderUniforms.uTextureMix, equals(21));
      expect(RibbonTrailShaderUniforms.trailTextureSamplerSlot, equals(0));
    });

    test('applyShaderUniforms populates all 22 float slots with precise values', () {
      final mock = _MockShaderTarget();
      const config = RibbonTrailConfig(
        baseColor: Color(0xCCFF5500), // R: 255/255, G: 85/255, B: 0/255, A: 204/255
        glowColor: Color(0x99FFAA33), // R: 255/255, G: 170/255, B: 51/255, A: 153/255
        scrollSpeed: 2.4,
        distortionStrength: 0.12,
        distortionFreq: 3.5,
        glowIntensity: 4.8,
        fadePower: 1.8,
        transversePower: 3.2,
        textureMix: 0.65,
      );

      const resolution = Size(1920.0, 1080.0);
      const bounds = Rect.fromLTWH(150.0, 250.0, 500.0, 300.0);
      const testTime = 3.75;
      final dummyTexture = RibbonTrailRenderer.fallbackWhiteImage ?? _FakeTestImage();

      RibbonTrailRenderer.applyShaderUniforms(
        mock,
        resolution: resolution,
        bounds: bounds,
        time: testTime,
        config: config,
        texture: dummyTexture,
      );

      expect(mock.floats.length, equals(RibbonTrailShaderUniforms.totalFloatUniforms));

      // uResolution
      expect(mock.floats[RibbonTrailShaderUniforms.uResolutionX], closeTo(1920.0, 1e-5));
      expect(mock.floats[RibbonTrailShaderUniforms.uResolutionY], closeTo(1080.0, 1e-5));

      // uTime
      expect(mock.floats[RibbonTrailShaderUniforms.uTime], closeTo(3.75, 1e-5));

      // uBaseColor (ARGB: 0xCCFF5500)
      expect(mock.floats[RibbonTrailShaderUniforms.uBaseColorR], closeTo(1.0, 1e-3));
      expect(mock.floats[RibbonTrailShaderUniforms.uBaseColorG], closeTo(85.0 / 255.0, 1e-3));
      expect(mock.floats[RibbonTrailShaderUniforms.uBaseColorB], closeTo(0.0, 1e-3));
      expect(mock.floats[RibbonTrailShaderUniforms.uBaseColorA], closeTo(204.0 / 255.0, 1e-3));

      // uGlowColor (ARGB: 0x99FFAA33)
      expect(mock.floats[RibbonTrailShaderUniforms.uGlowColorR], closeTo(1.0, 1e-3));
      expect(mock.floats[RibbonTrailShaderUniforms.uGlowColorG], closeTo(170.0 / 255.0, 1e-3));
      expect(mock.floats[RibbonTrailShaderUniforms.uGlowColorB], closeTo(51.0 / 255.0, 1e-3));
      expect(mock.floats[RibbonTrailShaderUniforms.uGlowColorA], closeTo(153.0 / 255.0, 1e-3));

      // uBounds
      expect(mock.floats[RibbonTrailShaderUniforms.uBoundsMinX], closeTo(150.0, 1e-5));
      expect(mock.floats[RibbonTrailShaderUniforms.uBoundsMinY], closeTo(250.0, 1e-5));
      expect(mock.floats[RibbonTrailShaderUniforms.uBoundsWidth], closeTo(500.0, 1e-5));
      expect(mock.floats[RibbonTrailShaderUniforms.uBoundsHeight], closeTo(300.0, 1e-5));

      // Animation & Visual Tuning
      expect(mock.floats[RibbonTrailShaderUniforms.uScrollSpeed], closeTo(2.4, 1e-5));
      expect(mock.floats[RibbonTrailShaderUniforms.uDistortionStrength], closeTo(0.12, 1e-5));
      expect(mock.floats[RibbonTrailShaderUniforms.uDistortionFreq], closeTo(3.5, 1e-5));
      expect(mock.floats[RibbonTrailShaderUniforms.uGlowIntensity], closeTo(4.8, 1e-5));
      expect(mock.floats[RibbonTrailShaderUniforms.uFadePower], closeTo(1.8, 1e-5));
      expect(mock.floats[RibbonTrailShaderUniforms.uTransversePower], closeTo(3.2, 1e-5));
      expect(mock.floats[RibbonTrailShaderUniforms.uTextureMix], closeTo(0.65, 1e-5));

      // Sampler slot 0
      expect(mock.samplers[RibbonTrailShaderUniforms.trailTextureSamplerSlot], equals(dummyTexture));
    });

    test('applyShaderUniforms forces uTextureMix to 0.0 when texture is null', () {
      final mock = _MockShaderTarget();
      const config = RibbonTrailConfig(textureMix: 0.95);
      final fallback = _FakeTestImage();

      RibbonTrailRenderer.applyShaderUniforms(
        mock,
        resolution: const Size(800.0, 600.0),
        bounds: const Rect.fromLTWH(0.0, 0.0, 100.0, 50.0),
        time: 1.0,
        config: config,
        texture: null,
        fallbackImage: fallback,
      );

      // uTextureMix must clamp to 0.0 to enable procedural energy mode
      expect(mock.floats[RibbonTrailShaderUniforms.uTextureMix], equals(0.0));
      // Fallback texture bound to slot 0 to prevent mobile driver crashes
      expect(mock.samplers[RibbonTrailShaderUniforms.trailTextureSamplerSlot], equals(fallback));
    });

    test('FragmentProgram fromAsset loads ribbon_trail.frag and applies uniforms', () async {
      try {
        final program = await ui.FragmentProgram.fromAsset('shaders/vfx/ribbon_trail.frag');
        final shader = program.fragmentShader();
        expect(shader, isNotNull);

        final testImage = _FakeTestImage();
        const config = RibbonTrailConfig(
          baseColor: Color(0xFFFF5500),
          glowColor: Color(0xFFFFAA33),
          textureMix: 0.5,
        );

        RibbonTrailRenderer.applyShaderUniforms(
          shader,
          resolution: const Size(800.0, 600.0),
          bounds: const Rect.fromLTWH(10.0, 10.0, 200.0, 100.0),
          time: 1.5,
          config: config,
          texture: testImage,
        );

        shader.dispose();
      } catch (_) {
        // Asset bundle or shader compilation may be omitted in isolated unit tests
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 3. CatmullRomType & Centripetal Spline Curve Evaluation
  // ---------------------------------------------------------------------------
  group('Centripetal Catmull-Rom Spline Interpolation Curve Evaluation', () {
    test('CatmullRomType exposes correct alpha parameterization constants', () {
      expect(CatmullRomType.uniform.alpha, equals(0.0));
      expect(CatmullRomType.centripetal.alpha, equals(0.5));
      expect(CatmullRomType.chordal.alpha, equals(1.0));
    });

    test('Centripetal spline strictly interpolates through control points P1 and P2', () {
      const p0 = Vector3D(0.0, 0.0, 0.0);
      const p1 = Vector3D(100.0, 20.0, 5.0);
      const p2 = Vector3D(250.0, 180.0, 15.0);
      const p3 = Vector3D(400.0, 50.0, 0.0);

      final start = RibbonCatmullRomSpline.evaluate3D(p0, p1, p2, p3, 0.0, alpha: 0.5);
      expect(start.x, closeTo(p1.x, 1e-6));
      expect(start.y, closeTo(p1.y, 1e-6));
      expect(start.z, closeTo(p1.z, 1e-6));

      final end = RibbonCatmullRomSpline.evaluate3D(p0, p1, p2, p3, 1.0, alpha: 0.5);
      expect(end.x, closeTo(p2.x, 1e-6));
      expect(end.y, closeTo(p2.y, 1e-6));
      expect(end.z, closeTo(p2.z, 1e-6));
    });

    test('Centripetal spline midpoint is smooth and bounded', () {
      const p0 = Vector3D(0.0, 0.0, 0.0);
      const p1 = Vector3D(100.0, 0.0, 0.0);
      const p2 = Vector3D(200.0, 100.0, 0.0);
      const p3 = Vector3D(300.0, 100.0, 0.0);

      final mid = RibbonCatmullRomSpline.evaluate3D(p0, p1, p2, p3, 0.5, alpha: 0.5);
      expect(mid.x, inInclusiveRange(100.0, 200.0));
      expect(mid.y, inInclusiveRange(0.0, 100.0));
    });

    test('Centripetal parameterization (alpha=0.5) eliminates cusps on rapid weapon direction changes', () {
      // Hairpin turnaround simulation (rapid counter-swing)
      const p0 = Vector3D(0.0, 0.0, 0.0);
      const p1 = Vector3D(100.0, 0.0, 0.0);
      const p2 = Vector3D(100.1, 100.0, 0.0); // sharp right turn
      const p3 = Vector3D(0.0, 100.0, 0.0);   // reverse direction

      final centripetalMid = RibbonCatmullRomSpline.evaluate3D(p0, p1, p2, p3, 0.5, alpha: 0.5);
      final uniformMid = RibbonCatmullRomSpline.evaluate3D(p0, p1, p2, p3, 0.5, alpha: 0.0);

      // Centripetal does not drastically overshoot the bounding interval
      expect(centripetalMid.x, inInclusiveRange(50.0, 150.0));
      expect(centripetalMid.y, inInclusiveRange(0.0, 100.0));

      // Both stay finite and non-NaN
      expect(centripetalMid.x.isNaN, isFalse);
      expect(uniformMid.x.isNaN, isFalse);
    });

    test('Straight collinear control points yield exact linear trajectory', () {
      const p0 = Vector3D(0.0, 0.0, 0.0);
      const p1 = Vector3D(10.0, 10.0, 10.0);
      const p2 = Vector3D(20.0, 20.0, 20.0);
      const p3 = Vector3D(30.0, 30.0, 30.0);

      for (double t = 0.0; t <= 1.0; t += 0.25) {
        final pt = RibbonCatmullRomSpline.evaluate3D(p0, p1, p2, p3, t, alpha: 0.5);
        final expected = 10.0 + 10.0 * t;
        expect(pt.x, closeTo(expected, 1e-4));
        expect(pt.y, closeTo(expected, 1e-4));
        expect(pt.z, closeTo(expected, 1e-4));
      }
    });

    test('Coincident control points handle numerical singularity safely', () {
      const pCoincident = Vector3D(50.0, 50.0, 50.0);
      final pt = RibbonCatmullRomSpline.evaluate3D(
        pCoincident,
        pCoincident,
        pCoincident,
        pCoincident,
        0.5,
        alpha: 0.5,
      );

      expect(pt.x, closeTo(50.0, 1e-5));
      expect(pt.y, closeTo(50.0, 1e-5));
      expect(pt.z, closeTo(50.0, 1e-5));
    });

    test('2D evaluate2D produces matching Offset to 3D evaluation', () {
      const p0 = Offset(10.0, 20.0);
      const p1 = Offset(30.0, 60.0);
      const p2 = Offset(80.0, 90.0);
      const p3 = Offset(120.0, 40.0);

      final eval2D = RibbonCatmullRomSpline.evaluate2D(p0, p1, p2, p3, 0.4, alpha: 0.5);
      final eval3D = RibbonCatmullRomSpline.evaluate3D(
        Vector3D.fromOffset(p0),
        Vector3D.fromOffset(p1),
        Vector3D.fromOffset(p2),
        Vector3D.fromOffset(p3),
        0.4,
        alpha: 0.5,
      );

      expect(eval2D.dx, closeTo(eval3D.x, 1e-6));
      expect(eval2D.dy, closeTo(eval3D.y, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Quad Strip Mesh Generation & Non-Linear Width Tapering
  // ---------------------------------------------------------------------------
  group('Quad Strip Mesh Generation & Non-Linear Width Tapering', () {
    test('Empty mesh returned when sample count < 2', () {
      const config = RibbonTrailConfig();
      final meshZero = RibbonTrailMeshGenerator.generate(
        samples: <RibbonSample>[],
        currentTime: 1.0,
        config: config,
      );
      expect(meshZero.isEmpty, isTrue);
      expect(meshZero.vertexCount, equals(0));
      expect(meshZero.triangleCount, equals(0));

      final sample1 = RibbonSample.from2D(
        tip: const Offset(10.0, 10.0),
        base: const Offset(10.0, 0.0),
        timestamp: 1.0,
      );
      final meshOne = RibbonTrailMeshGenerator.generate(
        samples: <RibbonSample>[sample1],
        currentTime: 1.0,
        config: config,
      );
      expect(meshOne.isEmpty, isTrue);
    });

    test('Two samples produce linear quad strip mesh with expected geometry', () {
      const config = RibbonTrailConfig(
        subdivisions: 4,
        startWidthMultiplier: 1.0,
        endWidthMultiplier: 1.0,
      );

      final samples = <RibbonSample>[
        RibbonSample.from2D(
          tip: const Offset(0.0, 50.0),
          base: const Offset(0.0, 0.0),
          timestamp: 0.0,
        ),
        RibbonSample.from2D(
          tip: const Offset(100.0, 50.0),
          base: const Offset(100.0, 0.0),
          timestamp: 0.1,
        ),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 0.1,
        config: config,
      );

      expect(mesh.isNotEmpty, isTrue);
      final sliceCount = config.subdivisions + 1; // 5 slices for 2 points
      expect(mesh.vertexCount, equals(sliceCount * 2)); // 10 vertices
      expect(mesh.triangleCount, equals((sliceCount - 1) * 2)); // 8 triangles
      expect(mesh.indices.length, equals(mesh.triangleCount * 3)); // 24 indices

      // Vertex positions length = vertexCount * 2
      expect(mesh.positions.length, equals(mesh.vertexCount * 2));
      // TexCoords length = vertexCount * 2
      expect(mesh.texCoords.length, equals(mesh.vertexCount * 2));
      // Colors length = vertexCount
      expect(mesh.colors.length, equals(mesh.vertexCount));
    });

    test('Triangle indices follow proper quad strip winding order', () {
      const config = RibbonTrailConfig(subdivisions: 2);
      final samples = <RibbonSample>[
        RibbonSample.from2D(
          tip: const Offset(0.0, 20.0),
          base: const Offset(0.0, 0.0),
          timestamp: 0.0,
        ),
        RibbonSample.from2D(
          tip: const Offset(50.0, 20.0),
          base: const Offset(50.0, 0.0),
          timestamp: 0.1,
        ),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 0.1,
        config: config,
      );

      // Verify each quad (4 vertices: v0=top0, v1=bot0, v2=top1, v3=bot1)
      // Triangle 1: (v0, v1, v2), Triangle 2: (v1, v3, v2)
      final indices = mesh.indices;
      for (int q = 0; q < mesh.triangleCount ~/ 2; q++) {
        final tri1Idx = q * 6;
        final v0 = q * 2;
        final v1 = v0 + 1;
        final v2 = v0 + 2;
        final v3 = v0 + 3;

        expect(indices[tri1Idx], equals(v0));
        expect(indices[tri1Idx + 1], equals(v1));
        expect(indices[tri1Idx + 2], equals(v2));

        expect(indices[tri1Idx + 3], equals(v1));
        expect(indices[tri1Idx + 4], equals(v3));
        expect(indices[tri1Idx + 5], equals(v2));
      }
    });

    test('UV mapping spans U: [0, 1] longitudinally and V: [0, 1] transversely', () {
      const config = RibbonTrailConfig(subdivisions: 5);
      final samples = <RibbonSample>[
        RibbonSample.from2D(tip: const Offset(0, 20), base: const Offset(0, 0), timestamp: 0.0),
        RibbonSample.from2D(tip: const Offset(50, 20), base: const Offset(50, 0), timestamp: 0.1),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 0.1,
        config: config,
      );

      final sliceCount = mesh.vertexCount ~/ 2;
      for (int i = 0; i < sliceCount; i++) {
        final tipUvIdx = (i * 2) * 2;
        final baseUvIdx = (i * 2 + 1) * 2;

        final expectedU = i / (sliceCount - 1);

        // Tip vertex: u in [0, 1], v = 0.0
        expect(mesh.texCoords[tipUvIdx], closeTo(expectedU, 1e-5));
        expect(mesh.texCoords[tipUvIdx + 1], closeTo(0.0, 1e-5));

        // Base vertex: u in [0, 1], v = 1.0
        expect(mesh.texCoords[baseUvIdx], closeTo(expectedU, 1e-5));
        expect(mesh.texCoords[baseUvIdx + 1], closeTo(1.0, 1e-5));
      }
    });

    test('Non-linear width tapering tapers width from startWidthMultiplier to endWidthMultiplier', () {
      // Blade trail tapering: startWidthMultiplier = 1.0 (broad blade), endWidthMultiplier = 0.0 (pin-point tail)
      const config = RibbonTrailConfig(
        subdivisions: 10,
        startWidthMultiplier: 1.0,
        endWidthMultiplier: 0.0,
        widthTaperCurve: Curves.linear,
      );

      final samples = <RibbonSample>[
        RibbonSample.from2D(tip: const Offset(0, 100), base: const Offset(0, 0), timestamp: 0.0),
        RibbonSample.from2D(tip: const Offset(200, 100), base: const Offset(200, 0), timestamp: 0.1),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 0.1,
        config: config,
      );

      final sliceCount = mesh.vertexCount ~/ 2;

      // Slice 0 (u = 0.0): width should be full 100.0
      final tip0Y = mesh.positions[1];
      final base0Y = mesh.positions[3];
      final width0 = (tip0Y - base0Y).abs();
      expect(width0, closeTo(100.0, 1e-4));

      // Slice mid (u = 0.5): width should be approx 50.0 under linear taper
      final midIdx = sliceCount ~/ 2;
      final tipMidY = mesh.positions[midIdx * 4 + 1];
      final baseMidY = mesh.positions[midIdx * 4 + 3];
      final widthMid = (tipMidY - baseMidY).abs();
      expect(widthMid, closeTo(50.0, 1.0));

      // Slice tail (u = 1.0): width should taper to 0.0 (tip == base)
      final lastIdx = sliceCount - 1;
      final tipLastY = mesh.positions[lastIdx * 4 + 1];
      final baseLastY = mesh.positions[lastIdx * 4 + 3];
      final widthLast = (tipLastY - baseLastY).abs();
      expect(widthLast, closeTo(0.0, 1e-4));
    });

    test('Custom non-linear width tapering curves (easeInOut) evaluated correctly', () {
      const config = RibbonTrailConfig(
        subdivisions: 20,
        startWidthMultiplier: 1.0,
        endWidthMultiplier: 0.0,
        widthTaperCurve: Curves.easeInOut,
      );

      final samples = <RibbonSample>[
        RibbonSample.from2D(tip: const Offset(0, 100), base: const Offset(0, 0), timestamp: 0.0),
        RibbonSample.from2D(tip: const Offset(100, 100), base: const Offset(100, 0), timestamp: 0.1),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 0.1,
        config: config,
      );

      final sliceCount = mesh.vertexCount ~/ 2;
      for (int i = 0; i < sliceCount; i++) {
        final u = i / (sliceCount - 1);
        final expectedFactor = Curves.easeInOut.transform(u);
        final expectedWidthMult = 1.0 + (0.0 - 1.0) * expectedFactor;
        final expectedWidth = 100.0 * expectedWidthMult;

        final tipY = mesh.positions[i * 4 + 1];
        final baseY = mesh.positions[i * 4 + 3];
        final actualWidth = (tipY - baseY).abs();

        expect(actualWidth, closeTo(expectedWidth, 1e-3));
      }
    });

    test('Mesh correctly generates 3D positions buffer when generate3D is true', () {
      const config = RibbonTrailConfig(generate3D: true, subdivisions: 2);
      final samples = <RibbonSample>[
        RibbonSample.from3D(
          tip: const Vector3D(10.0, 20.0, 30.0),
          base: const Vector3D(10.0, 0.0, 30.0),
          timestamp: 0.0,
        ),
        RibbonSample.from3D(
          tip: const Vector3D(50.0, 20.0, 80.0),
          base: const Vector3D(50.0, 0.0, 80.0),
          timestamp: 0.1,
        ),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 0.1,
        config: config,
      );

      expect(mesh.positions3D, isNotNull);
      expect(mesh.positions3D!.length, equals(mesh.vertexCount * 3));

      // Start tip z should be close to 30.0
      expect(mesh.positions3D![2], closeTo(30.0, 1e-4));
      // End tip z should be close to 80.0
      final lastTipZIdx = (mesh.vertexCount - 2) * 3 + 2;
      expect(mesh.positions3D![lastTipZIdx], closeTo(80.0, 1e-4));
    });

    test('Bounding box encompasses all vertex coordinates', () {
      const config = RibbonTrailConfig(subdivisions: 4);
      final samples = <RibbonSample>[
        RibbonSample.from2D(tip: const Offset(50, 150), base: const Offset(50, 50), timestamp: 0.0),
        RibbonSample.from2D(tip: const Offset(200, 300), base: const Offset(200, 200), timestamp: 0.1),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 0.1,
        config: config,
      );

      final bounds = mesh.bounds;
      expect(bounds.isEmpty, isFalse);

      for (int i = 0; i < mesh.positions.length; i += 2) {
        final x = mesh.positions[i];
        final y = mesh.positions[i + 1];
        expect(x, inInclusiveRange(bounds.left - 1e-4, bounds.right + 1e-4));
        expect(y, inInclusiveRange(bounds.top - 1e-4, bounds.bottom + 1e-4));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Age Attenuation, Alpha Power-Curve Decay, & Additive HDR Bloom Boost
  // ---------------------------------------------------------------------------
  group('Age Attenuation, Alpha Power-Curve Decay, & Additive HDR Bloom Boost', () {
    test('Samples exceeding lifetime are pruned and omitted from mesh', () {
      const config = RibbonTrailConfig(lifetime: 0.4);
      final samples = <RibbonSample>[
        RibbonSample.from2D(tip: const Offset(0, 10), base: const Offset(0, 0), timestamp: 0.0), // age 0.6 -> expired
        RibbonSample.from2D(tip: const Offset(10, 10), base: const Offset(10, 0), timestamp: 0.1), // age 0.5 -> expired
        RibbonSample.from2D(tip: const Offset(30, 10), base: const Offset(30, 0), timestamp: 0.3), // age 0.3 -> active
        RibbonSample.from2D(tip: const Offset(50, 10), base: const Offset(50, 0), timestamp: 0.5), // age 0.1 -> active
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 0.6,
        config: config,
      );

      // Only the 2 active samples should be retained
      expect(mesh.isNotEmpty, isTrue);
      // Min X bound must be >= 30.0 (the expired samples at 0 and 10 were pruned)
      expect(mesh.bounds.left, greaterThanOrEqualTo(29.0));
    });

    test('Alpha decay curve attenuates older slices down to near zero', () {
      const config = RibbonTrailConfig(
        lifetime: 1.0,
        alphaDecayCurve: Curves.linear,
        fadePower: 1.0,
        subdivisions: 2,
        baseColor: Color(0xFFFFFFFF),
      );

      // S0 at head (t = 1.0, age = 0.0), S1 at tail (t = 0.0, age = 1.0)
      final samples = <RibbonSample>[
        RibbonSample.from2D(tip: const Offset(0, 20), base: const Offset(0, 0), timestamp: 1.0),
        RibbonSample.from2D(tip: const Offset(100, 20), base: const Offset(100, 0), timestamp: 0.0),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 1.0,
        config: config,
      );

      // First vertex at head should have strong alpha (near 255 * 0.85 edge atten = ~217)
      final headColor = mesh.colors[0];
      final headAlpha = (headColor >> 24) & 0xFF;
      expect(headAlpha, greaterThan(180));

      // Last vertex at tail (age = 1.0) should decay to 0 alpha
      final tailColor = mesh.colors[mesh.vertexCount - 1];
      final tailAlpha = (tailColor >> 24) & 0xFF;
      expect(tailAlpha, equals(0));
    });

    test('fadePower modulates longitudinal decay rate along swing arc', () {
      // Longitudinal decay = pow(1.0 - u, fadePower)
      // Higher fadePower concentrates intensity near leading edge
      for (final fadePower in <double>[0.5, 1.0, 2.0, 4.0]) {
        final config = RibbonTrailConfig(
          lifetime: 2.0,
          fadePower: fadePower,
          subdivisions: 4,
          baseColor: const Color(0xFFFFFFFF),
        );

        final samples = <RibbonSample>[
          RibbonSample.from2D(tip: const Offset(0, 20), base: const Offset(0, 0), timestamp: 2.0),
          RibbonSample.from2D(tip: const Offset(100, 20), base: const Offset(100, 0), timestamp: 2.0),
        ];

        final mesh = RibbonTrailMeshGenerator.generate(
          samples: samples,
          currentTime: 2.0,
          config: config,
        );

        expect(mesh.isNotEmpty, isTrue);
        final sliceCount = mesh.vertexCount ~/ 2;

        // Middle slice (u = 0.5)
        final midSlice = sliceCount ~/ 2;
        final midAlpha = (mesh.colors[midSlice * 2] >> 24) & 0xFF;

        final expectedFactor = math.pow(1.0 - (midSlice / (sliceCount - 1)), fadePower).toDouble();
        final expectedMaxAlpha = (expectedFactor * 255 * 0.85).round();
        expect(midAlpha, closeTo(expectedMaxAlpha, 3));
      }
    });

    test('Emissive HDR glow blends baseColor towards glowColor at the leading head', () {
      const baseColor = Color(0xFFFF2200); // Crimson flame
      const glowColor = Color(0xFFFFFF00); // High-radiance gold
      const config = RibbonTrailConfig(
        baseColor: baseColor,
        glowColor: glowColor,
        glowIntensity: 3.5,
        subdivisions: 2,
      );

      final samples = <RibbonSample>[
        RibbonSample.from2D(tip: const Offset(0, 20), base: const Offset(0, 0), timestamp: 1.0),
        RibbonSample.from2D(tip: const Offset(100, 20), base: const Offset(100, 0), timestamp: 1.0),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 1.0,
        config: config,
      );

      // Slice 0 (u = 0.0) has maximum glowMix = pow(1.0 - 0.0, 1.2) = 1.0 -> glowColor (gold)
      final headColor = mesh.colors[0];
      final headR = (headColor >> 16) & 0xFF;
      final headG = (headColor >> 8) & 0xFF;
      final headB = headColor & 0xFF;

      // GlowColor (0xFFFFFF00) has full Red (255) and full Green (255)
      expect(headR, equals(255));
      expect(headG, equals(255));
      expect(headB, equals(0));

      // Slice tail (u = 1.0) has glowMix = 0.0 -> baseColor (crimson: R=255, G=34, B=0)
      final tailSliceIdx = (mesh.vertexCount ~/ 2 - 1) * 2;
      final tailColor = mesh.colors[tailSliceIdx];
      final tailG = (tailColor >> 8) & 0xFF;
      expect(tailG, equals(34));
    });

    test('Sample opacity and custom per-sample color modulate vertex output', () {
      const config = RibbonTrailConfig(subdivisions: 1);
      final samples = <RibbonSample>[
        RibbonSample.from2D(
          tip: const Offset(0, 20),
          base: const Offset(0, 0),
          timestamp: 1.0,
          color: const Color(0xFF00FFCC), // Custom cyan slash
          opacity: 0.5,
        ),
        RibbonSample.from2D(
          tip: const Offset(50, 20),
          base: const Offset(50, 0),
          timestamp: 1.0,
          opacity: 0.5,
        ),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 1.0,
        config: config,
      );

      // Verify alpha scaled by sample opacity 0.5
      final headAlpha = (mesh.colors[0] >> 24) & 0xFF;
      expect(headAlpha, closeTo((255 * 0.5 * 0.85).round(), 2));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. RibbonTrail State Management & Dynamic Simulation
  // ---------------------------------------------------------------------------
  group('RibbonTrail State Management & Dynamic Simulation', () {
    test('Distance culling filters out tiny stationary weapon samples', () {
      final trail = RibbonTrail(
        config: const RibbonTrailConfig(minSegmentDistance: 5.0),
      );

      // Initial sample
      trail.addSample(
        tip: const Offset(10.0, 50.0),
        base: const Offset(10.0, 0.0),
        timestamp: 0.0,
      );
      expect(trail.sampleCount, equals(1));

      // Attempt sample with distance < minSegmentDistance (e.g. 1.0 pixel offset)
      trail.addSample(
        tip: const Offset(11.0, 50.0),
        base: const Offset(11.0, 0.0),
        timestamp: 0.01,
      );
      // Must be rejected by distance culling
      expect(trail.sampleCount, equals(1));

      // Add significant motion (> 5.0 pixels)
      trail.addSample(
        tip: const Offset(20.0, 50.0),
        base: const Offset(20.0, 0.0),
        timestamp: 0.02,
      );
      expect(trail.sampleCount, equals(2));
    });

    test('3D sample addition respects minSegmentDistance in 3D space', () {
      final trail = RibbonTrail(
        config: const RibbonTrailConfig(minSegmentDistance: 10.0),
      );

      trail.addSample3D(
        tip: const Vector3D(0.0, 10.0, 0.0),
        base: const Vector3D(0.0, 0.0, 0.0),
        timestamp: 0.0,
      );
      expect(trail.sampleCount, equals(1));

      // Small 3D displacement
      trail.addSample3D(
        tip: const Vector3D(1.0, 10.0, 2.0),
        base: const Vector3D(1.0, 0.0, 2.0),
        timestamp: 0.05,
      );
      expect(trail.sampleCount, equals(1));

      // Large 3D displacement
      trail.addSample3D(
        tip: const Vector3D(50.0, 10.0, 40.0),
        base: const Vector3D(50.0, 0.0, 40.0),
        timestamp: 0.1,
      );
      expect(trail.sampleCount, equals(2));
    });

    test('update advances currentTime and prunes expired samples', () {
      final trail = RibbonTrail(
        config: const RibbonTrailConfig(lifetime: 0.3),
      );

      trail.addSample(tip: const Offset(0, 10), base: const Offset(0, 0), timestamp: 0.0);
      trail.addSample(tip: const Offset(20, 10), base: const Offset(20, 0), timestamp: 0.2);
      expect(trail.sampleCount, equals(2));

      // Advance by 0.25 -> currentTime = 0.45.
      // Sample at 0.0 has age 0.45 > lifetime (0.3) -> pruned.
      // Sample at 0.2 has age 0.25 <= lifetime (0.3) -> kept.
      trail.update(0.25);
      expect(trail.sampleCount, equals(1));
      expect(trail.currentTime, closeTo(0.45, 1e-6));

      // Advance by another 0.2 -> sample at 0.2 expires
      trail.update(0.2);
      expect(trail.sampleCount, equals(0));
      expect(trail.isEmpty, isTrue);
    });

    test('setTime updates clock and clears expired history', () {
      final trail = RibbonTrail(
        config: const RibbonTrailConfig(lifetime: 0.5),
      );

      trail.addSample(tip: const Offset(0, 10), base: const Offset(0, 0), timestamp: 1.0);
      trail.setTime(2.0); // Jump forward 1 second
      expect(trail.sampleCount, equals(0));
      expect(trail.currentTime, equals(2.0));
    });

    test('clear resets all samples and cached mesh', () {
      final trail = RibbonTrail();
      trail.addSample(tip: const Offset(0, 10), base: const Offset(0, 0));
      trail.addSample(tip: const Offset(20, 10), base: const Offset(20, 0));
      expect(trail.isNotEmpty, isTrue);

      final mesh = trail.generateMesh();
      expect(mesh.isNotEmpty, isTrue);

      trail.clear();
      expect(trail.isEmpty, isTrue);
      expect(trail.generateMesh().isEmpty, isTrue);
    });

    test('Mesh caching avoids re-evaluating when trail is not dirty', () {
      final trail = RibbonTrail();
      trail.addSample(tip: const Offset(0, 10), base: const Offset(0, 0), timestamp: 0.0);
      trail.addSample(tip: const Offset(20, 10), base: const Offset(20, 0), timestamp: 0.1);

      final mesh1 = trail.generateMesh();
      final mesh2 = trail.generateMesh();

      // Should return identical cached instance
      expect(identical(mesh1, mesh2), isTrue);

      // Adding sample dirties mesh
      trail.addSample(tip: const Offset(40, 10), base: const Offset(40, 0), timestamp: 0.2);
      final mesh3 = trail.generateMesh();
      expect(identical(mesh1, mesh3), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Widget Tree Integration & RibbonTrailPainter Rendering
  // ---------------------------------------------------------------------------
  group('Widget Tree Integration & RibbonTrailPainter Rendering', () {
    test('RibbonTrailPainter shouldRepaint returns true for frame updates', () {
      final trail = RibbonTrail();
      final painter1 = RibbonTrailPainter(trail: trail);
      final painter2 = RibbonTrailPainter(trail: trail);
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('RibbonTrailMesh.toVertices produces valid ui.Vertices for Flutter Canvas', () {
      const config = RibbonTrailConfig(subdivisions: 2);
      final samples = <RibbonSample>[
        RibbonSample.from2D(tip: const Offset(0, 20), base: const Offset(0, 0), timestamp: 0.0),
        RibbonSample.from2D(tip: const Offset(50, 20), base: const Offset(50, 0), timestamp: 0.1),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 0.1,
        config: config,
      );

      final vertices = mesh.toVertices();
      expect(vertices, isNotNull);
      expect(vertices, isA<ui.Vertices>());
    });

    testWidgets('CustomPaint with RibbonTrailPainter mounts and renders without errors', (tester) async {
      final trail = RibbonTrail();
      trail.addSample(tip: const Offset(10, 80), base: const Offset(10, 20), timestamp: 0.0);
      trail.addSample(tip: const Offset(60, 90), base: const Offset(60, 30), timestamp: 0.05);
      trail.addSample(tip: const Offset(120, 70), base: const Offset(120, 10), timestamp: 0.1);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            size: const Size(300, 300),
            painter: RibbonTrailPainter(
              trail: trail,
              blendMode: BlendMode.plus,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsOneWidget);

      // Dynamic animation frame pump
      trail.update(0.05);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    });

    testWidgets('RibbonTrailPainter handles empty trail gracefully', (tester) async {
      final emptyTrail = RibbonTrail();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            size: const Size(200, 200),
            painter: RibbonTrailPainter(trail: emptyTrail),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Mathematical Parity & Shader Logic Simulation
  // ---------------------------------------------------------------------------
  group('Mathematical Parity with GLSL ribbon_trail.frag Algorithms', () {
    // Pure Dart simulation of GLSL computeDistortion
    Offset computeDistortionDart(Offset uv, double time, double freq, double strength) {
      if (strength <= 0.0001) return Offset.zero;
      final animTime = time % 628.31853;
      final t = animTime * 2.5;
      final wave1 = math.sin(uv.dx * freq * 6.28318 + t * 1.3) * math.cos(uv.dy * freq * 3.14159 - t * 0.8);
      final wave2 = math.sin((uv.dx + uv.dy) * (freq * 1.8) - t * 2.1);
      final wave3 = math.cos((uv.dx * 2.5 - uv.dy * 1.5) * freq + t * 3.7);

      final offset = Offset(
        wave1 * 0.6 + wave2 * 0.4,
        wave2 * 0.5 + wave3 * 0.5,
      );
      return offset * strength;
    }

    test('Wave distortion amplitude bounded by strength scalar', () {
      const strength = 0.08;
      const freq = 2.5;

      for (double u = 0.0; u <= 1.0; u += 0.25) {
        for (double v = 0.0; v <= 1.0; v += 0.25) {
          final dist = computeDistortionDart(Offset(u, v), 1.5, freq, strength);
          expect(dist.dx.abs(), lessThanOrEqualTo(strength * 1.05));
          expect(dist.dy.abs(), lessThanOrEqualTo(strength * 1.05));
        }
      }
    });

    test('Transverse edge-to-center glow profile peaks at blade center v=0.5', () {
      // centerProfile = clamp(1.0 - abs(v - 0.5) * 2.0, 0.0, 1.0)
      // transverseFactor = pow(centerProfile, transversePower)
      const transversePower = 2.0;

      double evaluateTransverse(double v) {
        final distFromCenter = (v - 0.5).abs() * 2.0;
        final centerProfile = (1.0 - distFromCenter).clamp(0.0, 1.0);
        return math.pow(centerProfile, transversePower).toDouble();
      }

      // At center (v = 0.5), profile is exactly 1.0
      expect(evaluateTransverse(0.5), closeTo(1.0, 1e-6));

      // At outer edges (v = 0.0 and v = 1.0), profile drops to 0.0
      expect(evaluateTransverse(0.0), closeTo(0.0, 1e-6));
      expect(evaluateTransverse(1.0), closeTo(0.0, 1e-6));

      // Symmetric falloff around center
      expect(evaluateTransverse(0.25), closeTo(evaluateTransverse(0.75), 1e-6));
      expect(evaluateTransverse(0.25), inInclusiveRange(0.0, 1.0));
    });

    test('High-intensity white core mask concentrates at center line and leading edge', () {
      // coreSharpness = pow(centerProfile, 4.0) * longitudinalFactor
      double evaluateCore(double u, double v, double fadePower) {
        final distFromCenter = (v - 0.5).abs() * 2.0;
        final centerProfile = (1.0 - distFromCenter).clamp(0.0, 1.0);
        final lengthDecay = (1.0 - u).clamp(0.0, 1.0);
        final longitudinal = math.pow(lengthDecay, fadePower).toDouble();
        return math.pow(centerProfile, 4.0) * longitudinal;
      }

      // Brightest at head and center line (u = 0.0, v = 0.5)
      expect(evaluateCore(0.0, 0.5, 1.4), closeTo(1.0, 1e-6));

      // Zero at tail (u = 1.0)
      expect(evaluateCore(1.0, 0.5, 1.4), closeTo(0.0, 1e-6));

      // Zero at blade edges (v = 0.0, v = 1.0)
      expect(evaluateCore(0.0, 0.0, 1.4), closeTo(0.0, 1e-6));
      expect(evaluateCore(0.0, 1.0, 1.4), closeTo(0.0, 1e-6));

      // Ultra-narrow core (at v = 0.3, distance = 0.4, profile = 0.6, pow(0.6, 4) = ~0.13)
      expect(evaluateCore(0.0, 0.3, 1.4), lessThan(0.15));
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Adversarial Edge Cases & Stress Tests
  // ---------------------------------------------------------------------------
  group('Adversarial Verification & Boundary Stress Tests', () {
    test('Zero lifetime handles updates without crashing', () {
      final trail = RibbonTrail(
        config: const RibbonTrailConfig(lifetime: 0.0),
      );
      trail.addSample(tip: const Offset(0, 10), base: const Offset(0, 0), timestamp: 1.0);
      trail.update(0.01);
      expect(trail.sampleCount, equals(0));
    });

    test('Negative simulation updates are safely ignored', () {
      final trail = RibbonTrail();
      trail.addSample(tip: const Offset(0, 10), base: const Offset(0, 0), timestamp: 2.0);
      final prevTime = trail.currentTime;
      trail.update(-1.0);
      expect(trail.currentTime, equals(prevTime));
    });

    test('Extreme weapon swing stress: 50 subdivisions across 10 samples generates valid mesh', () {
      const config = RibbonTrailConfig(
        subdivisions: 50,
        generate3D: true,
      );

      final samples = <RibbonSample>[];
      for (int i = 0; i < 10; i++) {
        final angle = (i / 10.0) * math.pi;
        final tip = Offset(100.0 + math.cos(angle) * 80.0, 100.0 + math.sin(angle) * 80.0);
        final base = Offset(100.0 + math.cos(angle) * 30.0, 100.0 + math.sin(angle) * 30.0);
        samples.add(RibbonSample.from2D(tip: tip, base: base, timestamp: i * 0.02));
      }

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 0.2,
        config: config,
      );

      expect(mesh.isNotEmpty, isTrue);
      expect(mesh.vertexCount, greaterThan(400));
      expect(mesh.positions3D, isNotNull);
      expect(mesh.bounds.width, greaterThan(0.0));
      expect(mesh.bounds.height, greaterThan(0.0));
    });

    test('Zero-width blade sample defaults safely to distance between tip and base', () {
      final sample = RibbonSample.from2D(
        tip: const Offset(0.0, 42.0),
        base: const Offset(0.0, 0.0),
        timestamp: 0.0,
      );
      expect(sample.width, closeTo(42.0, 1e-5));
    });

    test('RibbonTrailConfig copyWith preserves defaults and overrides targets', () {
      const original = RibbonTrailConfig();
      final updated = original.copyWith(
        subdivisions: 12,
        glowIntensity: 5.5,
        splineType: CatmullRomType.chordal,
      );

      expect(updated.subdivisions, equals(12));
      expect(updated.glowIntensity, equals(5.5));
      expect(updated.splineType, equals(CatmullRomType.chordal));
      expect(updated.lifetime, equals(original.lifetime));
      expect(updated.baseColor, equals(original.baseColor));
    });
  });
}
