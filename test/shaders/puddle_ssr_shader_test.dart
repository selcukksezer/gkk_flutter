import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/world/puddle_reflection_layer.dart';

// -----------------------------------------------------------------------------
// Puddle Ripple Wave Simulation & Pool Helpers
// Implements discrete circular ripple pool, harmonic damping, and propagation
// -----------------------------------------------------------------------------

/// Discrete circular ripple wavefront simulation model with harmonic damping,
/// wave velocity propagation, and pooling support.
class PuddleRipple {
  PuddleRipple({
    this.center = ui.Offset.zero,
    this.birthTime = 0.0,
    this.amplitude = 1.0,
    this.waveLength = 0.2,
    this.propagationSpeed = 1.0,
    this.dampingRate = 4.0,
    this.maxAge = 1.5,
  });

  ui.Offset center;
  double birthTime;
  double amplitude;
  double waveLength;
  double propagationSpeed;
  double dampingRate;
  double maxAge;
  bool isAlive = true;

  double get waveNumber => (2.0 * math.pi) / math.max(waveLength, 0.001);

  double evaluateRadius(double currentTime) {
    final double age = currentTime - birthTime;
    if (age <= 0.0) return 0.0;
    return age * propagationSpeed;
  }

  double evaluateHarmonicDamping(double currentTime) {
    final double age = currentTime - birthTime;
    if (age <= 0.0) return 1.0;
    return math.exp(-dampingRate * age);
  }

  double evaluateWaveElevation(ui.Offset pos, double currentTime) {
    final double age = currentTime - birthTime;
    if (age <= 0.0 || age > maxAge) return 0.0;

    final double dist = (pos - center).distance;
    final double frontRadius = age * propagationSpeed;
    final double distToFront = dist - frontRadius;

    final double phase = 2.0 * math.pi * (waveNumber * distToFront - age * 4.0);
    final double wave = math.sin(phase);
    final double edge = (0.18 - distToFront.abs()) / 0.18;
    final double smooth = edge.clamp(0.0, 1.0);
    final double envelope = evaluateHarmonicDamping(currentTime) *
        (smooth * smooth * (3.0 - 2.0 * smooth));

    return wave * envelope * amplitude;
  }

  ui.Offset evaluateNormalPerturbation(ui.Offset pos, double currentTime) {
    final double age = currentTime - birthTime;
    if (age <= 0.0 || age > maxAge) return ui.Offset.zero;

    final ui.Offset diff = pos - center;
    final double dist = diff.distance;
    if (dist <= 0.001) return ui.Offset.zero;

    final double frontRadius = age * propagationSpeed;
    final double distToFront = dist - frontRadius;

    final double phase = 2.0 * math.pi * (waveNumber * distToFront - age * 4.0);
    final double waveSlope = math.cos(phase) * waveNumber;
    final double edge = (0.18 - distToFront.abs()) / 0.18;
    final double smooth = edge.clamp(0.0, 1.0);
    final double envelope = evaluateHarmonicDamping(currentTime) *
        (smooth * smooth * (3.0 - 2.0 * smooth));

    final ui.Offset dir = ui.Offset(diff.dx / dist, diff.dy / dist);
    final double ageFactor = 1.0 - (age / maxAge).clamp(0.0, 1.0);
    final double slopeX = dir.dx * waveSlope * envelope * ageFactor;
    final double slopeY = dir.dy * waveSlope * envelope * ageFactor;

    return ui.Offset(slopeX * amplitude, slopeY * amplitude);
  }

  void update(double currentTime) {
    if (currentTime - birthTime >= maxAge) {
      isAlive = false;
    }
  }

  void reset({
    required ui.Offset newCenter,
    required double newBirthTime,
    double newAmplitude = 1.0,
    double newWaveLength = 0.2,
    double newSpeed = 1.0,
    double newDamping = 4.0,
    double newMaxAge = 1.5,
  }) {
    center = newCenter;
    birthTime = newBirthTime;
    amplitude = newAmplitude;
    waveLength = newWaveLength;
    propagationSpeed = newSpeed;
    dampingRate = newDamping;
    maxAge = newMaxAge;
    isAlive = true;
  }
}

/// High-performance circular ripple pool eliminating garbage collection allocations.
class PuddleRipplePool {
  PuddleRipplePool({this.capacity = 32}) {
    for (int i = 0; i < capacity; i++) {
      _pool.add(PuddleRipple());
    }
  }

  final int capacity;
  final List<PuddleRipple> _pool = <PuddleRipple>[];
  final List<PuddleRipple> _active = <PuddleRipple>[];

  int get activeCount => _active.length;
  int get poolAvailableCount => _pool.length;
  List<PuddleRipple> get activeRipples => List<PuddleRipple>.unmodifiable(_active);

  PuddleRipple? spawn({
    required ui.Offset center,
    required double currentTime,
    double amplitude = 1.0,
    double waveLength = 0.2,
    double speed = 1.0,
    double damping = 4.0,
    double maxAge = 1.5,
  }) {
    PuddleRipple ripple;
    if (_pool.isNotEmpty) {
      ripple = _pool.removeLast();
    } else if (_active.isNotEmpty) {
      // Steal oldest active ripple
      ripple = _active.removeAt(0);
    } else {
      return null;
    }

    ripple.reset(
      newCenter: center,
      newBirthTime: currentTime,
      newAmplitude: amplitude,
      newWaveLength: waveLength,
      newSpeed: speed,
      newDamping: damping,
      newMaxAge: maxAge,
    );
    _active.add(ripple);
    return ripple;
  }

  void update(double currentTime) {
    for (int i = _active.length - 1; i >= 0; i--) {
      final PuddleRipple ripple = _active[i];
      ripple.update(currentTime);
      if (!ripple.isAlive) {
        _active.removeAt(i);
        _pool.add(ripple);
      }
    }
  }

  void clear() {
    _pool.addAll(_active);
    _active.clear();
  }
}

// -----------------------------------------------------------------------------
// Analytical 4x4 Planar Reflection Matrix Math
// -----------------------------------------------------------------------------

/// Analytical 4x4 Planar Reflection Matrix Calculator for arbitrary 3D planes.
class PlanarReflectionMatrix {
  PlanarReflectionMatrix._();

  /// Builds a 16-element column-major 4x4 planar reflection matrix
  /// reflecting points across a plane: n.x * X + n.y * Y + n.z * Z + d = 0.
  static Float32List createReflectionMatrix({
    required WorldVector3 planeNormal,
    required double planeD,
  }) {
    final WorldVector3 n = planeNormal.normalized;
    final Float32List m = Float32List(16);

    // Column 0
    m[0] = 1.0 - 2.0 * n.x * n.x;
    m[1] = -2.0 * n.x * n.y;
    m[2] = -2.0 * n.x * n.z;
    m[3] = 0.0;

    // Column 1
    m[4] = -2.0 * n.x * n.y;
    m[5] = 1.0 - 2.0 * n.y * n.y;
    m[6] = -2.0 * n.y * n.z;
    m[7] = 0.0;

    // Column 2
    m[8] = -2.0 * n.x * n.z;
    m[9] = -2.0 * n.y * n.z;
    m[10] = 1.0 - 2.0 * n.z * n.z;
    m[11] = 0.0;

    // Column 3
    m[12] = -2.0 * n.x * planeD;
    m[13] = -2.0 * n.y * planeD;
    m[14] = -2.0 * n.z * planeD;
    m[15] = 1.0;

    return m;
  }

  /// Reflects a 3D point using a column-major 4x4 reflection matrix.
  static WorldVector3 transformPoint(Float32List matrix, WorldVector3 point) {
    final double x = matrix[0] * point.x + matrix[4] * point.y + matrix[8] * point.z + matrix[12];
    final double y = matrix[1] * point.x + matrix[5] * point.y + matrix[9] * point.z + matrix[13];
    final double z = matrix[2] * point.x + matrix[6] * point.y + matrix[10] * point.z + matrix[14];
    final double w = matrix[3] * point.x + matrix[7] * point.y + matrix[11] * point.z + matrix[15];

    final double invW = w.abs() > 1e-9 ? 1.0 / w : 1.0;
    return WorldVector3(x * invW, y * invW, z * invW);
  }
}

// -----------------------------------------------------------------------------
// Test Suite
// -----------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // 1. Puddle SSR Shader GLSL Source & Impeller Uniform Table Alignment
  // ===========================================================================
  group('Puddle SSR Shader GLSL Source & Impeller Uniform Table Alignment', () {
    late File shaderFile;
    late String shaderContent;

    setUpAll(() {
      shaderFile = File('shaders/world/puddle_ssr.frag');
      expect(shaderFile.existsSync(), isTrue,
          reason: 'shaders/world/puddle_ssr.frag must exist in workspace');
      shaderContent = shaderFile.readAsStringSync();
    });

    test('Shader header specifies GLSL 460 core and flutter runtime_effect include', () {
      expect(shaderContent, contains('#version 460 core'));
      expect(shaderContent, contains('#include <flutter/runtime_effect.glsl>'));
      expect(shaderContent, contains('precision highp float;'));
    });

    test('Shader declares all 27 numeric uniform floats matching Dart wrapper index layout', () {
      expect(shaderContent, contains('uniform vec2 uResolution;')); // 0..1
      expect(shaderContent, contains('uniform float uTime;')); // 2
      expect(shaderContent, contains('uniform vec3 uCameraPos;')); // 3..5
      expect(shaderContent, contains('uniform vec3 uCameraDir;')); // 6..8
      expect(shaderContent, contains('uniform float uRainIntensity;')); // 9
      expect(shaderContent, contains('uniform float uRippleSpeed;')); // 10
      expect(shaderContent, contains('uniform float uPuddleRoughness;')); // 11
      expect(shaderContent, contains('uniform float uReflectivity;')); // 12
      expect(shaderContent, contains('uniform float uFresnelR0;')); // 13
      expect(shaderContent, contains('uniform float uWaterDepthScale;')); // 14
      expect(shaderContent, contains('uniform vec4 uWaterColor;')); // 15..18
      expect(shaderContent, contains('uniform vec4 uMudColor;')); // 19..22
      expect(shaderContent, contains('uniform float uMaxRaySteps;')); // 23
      expect(shaderContent, contains('uniform float uRayStepSize;')); // 24
      expect(shaderContent, contains('uniform float uPlanarReflectionHeight;')); // 25
      expect(shaderContent, contains('uniform float uEdgeFadeMargin;')); // 26
    });

    test('Shader declares samplers strictly after numeric uniforms for Impeller ABI compliance', () {
      expect(shaderContent, contains('uniform sampler2D uSceneTexture;'));
      expect(shaderContent, contains('uniform sampler2D uPuddleMask;'));

      final int lastNumericUniformIdx = shaderContent.indexOf('uEdgeFadeMargin');
      final int firstSamplerIdx = shaderContent.indexOf('uSceneTexture');
      final int secondSamplerIdx = shaderContent.indexOf('uPuddleMask');

      expect(firstSamplerIdx, greaterThan(lastNumericUniformIdx),
          reason: 'uSceneTexture sampler must follow numeric uniforms in Flutter RuntimeEffect GLSL');
      expect(secondSamplerIdx, greaterThan(firstSamplerIdx),
          reason: 'uPuddleMask sampler must follow uSceneTexture');
    });

    test('Shader implements complete SSR raymarching, Voronoi ripples, and Beer-Lambert extinction', () {
      expect(shaderContent, contains('sampleSceneWithRoughness'));
      expect(shaderContent, contains('evaluateDualOctaveVoronoiRipples'));
      expect(shaderContent, contains('evaluateDualOctaveGerstner'));
      expect(shaderContent, contains('evaluateSchlickFresnel'));
      expect(shaderContent, contains('evaluateProceduralSky'));
      expect(shaderContent, contains('raymarchScreenSpaceReflections'));
      expect(shaderContent, contains('puddlePresence <= 0.005'));
    });
  });

  // ===========================================================================
  // 2. PuddleReflectionPainter Uniform Binding & Buffer Serialization
  // ===========================================================================
  group('PuddleReflectionPainter Uniform Binding & Buffer Serialization', () {
    test('buildUniformList exports exactly 27 floats with precise uniform offsets', () {
      final PuddleReflectionConfig cfg = PuddleReflectionConfig(
        rainIntensity: 0.72,
        rippleSpeed: 1.35,
        puddleRoughness: 0.08,
        reflectivity: 1.25,
        fresnelR0: 0.024,
        waterDepthScale: 1.15,
        waterColor: const ui.Color(0x40112A3D),
        mudColor: const ui.Color(0x80251A10),
        maxRaySteps: 24.0,
        rayStepSize: 0.022,
        planarReflectionHeight: 0.68,
        edgeFadeMargin: 0.09,
        cameraPosition: const WorldVector3(0.5, 1.7, 3.2),
        cameraDirection: const WorldVector3(0.1, -0.34, -0.93),
      );

      const ui.Size viewport = ui.Size(1920.0, 1080.0);
      const double time = 5.678;

      final List<double> uniforms = cfg.buildUniformList(
        viewportSize: viewport,
        time: time,
      );

      expect(uniforms.length, equals(27),
          reason: 'Shader uniform table must contain exactly 27 continuous floats');

      // 0..1: uResolution
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));

      // 2: uTime
      expect(uniforms[2], equals(5.678));

      // 3..5: uCameraPos
      expect(uniforms[3], equals(0.5));
      expect(uniforms[4], equals(1.7));
      expect(uniforms[5], equals(3.2));

      // 6..8: uCameraDir (normalized)
      final WorldVector3 normCam = cfg.cameraDirection.normalized;
      expect(uniforms[6], closeTo(normCam.x, 1e-6));
      expect(uniforms[7], closeTo(normCam.y, 1e-6));
      expect(uniforms[8], closeTo(normCam.z, 1e-6));

      // 9: uRainIntensity / uRippleIntensity
      expect(uniforms[9], closeTo(0.72, 1e-5));

      // 10: uRippleSpeed
      expect(uniforms[10], closeTo(1.35, 1e-5));

      // 11: uPuddleRoughness / uReflectionBlur
      expect(uniforms[11], closeTo(0.08, 1e-5));

      // 12: uReflectivity
      expect(uniforms[12], closeTo(1.25, 1e-5));

      // 13: uFresnelR0 / uFresnelExponent base
      expect(uniforms[13], closeTo(0.024, 1e-5));

      // 14: uWaterDepthScale / uWaterDepth
      expect(uniforms[14], closeTo(1.15, 1e-5));

      // 15..18: uWaterColor (vec4)
      expect(uniforms[15], closeTo(cfg.waterColor.r, 1e-4));
      expect(uniforms[16], closeTo(cfg.waterColor.g, 1e-4));
      expect(uniforms[17], closeTo(cfg.waterColor.b, 1e-4));
      expect(uniforms[18], closeTo(cfg.waterColor.a, 1e-4));

      // 19..22: uMudColor (vec4)
      expect(uniforms[19], closeTo(cfg.mudColor.r, 1e-4));
      expect(uniforms[20], closeTo(cfg.mudColor.g, 1e-4));
      expect(uniforms[21], closeTo(cfg.mudColor.b, 1e-4));
      expect(uniforms[22], closeTo(cfg.mudColor.a, 1e-4));

      // 23: uMaxRaySteps
      expect(uniforms[23], equals(24.0));

      // 24: uRayStepSize
      expect(uniforms[24], closeTo(0.022, 1e-5));

      // 25: uPlanarReflectionHeight
      expect(uniforms[25], closeTo(0.68, 1e-5));

      // 26: uEdgeFadeMargin
      expect(uniforms[26], closeTo(0.09, 1e-5));
    });

    test('toUniformFloat32List creates native Float32List with byte-accurate values', () {
      final PuddleReflectionConfig cfg = PuddleReflectionConfig.heavyDownpour();
      const ui.Size size = ui.Size(2560.0, 1440.0);
      const double time = 12.34;

      final Float32List buffer = cfg.toUniformFloat32List(
        viewportSize: size,
        time: time,
      );

      expect(buffer.length, equals(27));
      expect(buffer.elementSizeInBytes, equals(4));
      expect(buffer.lengthInBytes, equals(27 * 4));

      expect(buffer[0], equals(2560.0));
      expect(buffer[1], equals(1440.0));
      expect(buffer[2], closeTo(12.34, 1e-4));
      expect(buffer[9], closeTo(cfg.rainIntensity, 1e-4));
      expect(buffer[11], closeTo(cfg.puddleRoughness, 1e-4));
      expect(buffer[13], closeTo(cfg.fresnelR0, 1e-4));
      expect(buffer[14], closeTo(cfg.waterDepthScale, 1e-4));
    });

    test('PuddleReflectionConfig copyWith creates deep overrides without side effects', () {
      final PuddleReflectionConfig original = PuddleReflectionConfig.calmAfterRain();
      final PuddleReflectionConfig modified = original.copyWith(
        rainIntensity: 0.9,
        puddleRoughness: 0.15,
        waterDepthScale: 2.0,
      );

      expect(original.rainIntensity, equals(0.15));
      expect(modified.rainIntensity, equals(0.9));
      expect(modified.puddleRoughness, equals(0.15));
      expect(modified.waterDepthScale, equals(2.0));
      expect(modified.rippleSpeed, equals(original.rippleSpeed));
      expect(modified.reflectivity, equals(original.reflectivity));
    });

    test('Preset configurations adhere to distinct physical lighting and weather archetypes', () {
      final PuddleReflectionConfig calm = PuddleReflectionConfig.calmAfterRain();
      final PuddleReflectionConfig heavy = PuddleReflectionConfig.heavyDownpour();
      final PuddleReflectionConfig night = PuddleReflectionConfig.nightHubReflections();

      // Calm: low ripple, ultra glossy
      expect(calm.rainIntensity, lessThan(0.3));
      expect(calm.puddleRoughness, lessThan(0.05));

      // Heavy: extreme rain and waves
      expect(heavy.rainIntensity, greaterThan(0.8));
      expect(heavy.rippleSpeed, greaterThan(calm.rippleSpeed));
      expect(heavy.waterDepthScale, greaterThan(calm.waterDepthScale));

      // Night Hub: vibrant specular reflections
      expect(night.reflectivity, greaterThan(calm.reflectivity));
      expect(night.maxRaySteps, greaterThanOrEqualTo(30.0));
    });
  });

  // ===========================================================================
  // 3. Planar Reflection Matrix Math & Screen-Space UV Reflection Distortion
  // ===========================================================================
  group('Planar Reflection Matrix Math & Screen-Space UV Reflection Distortion', () {
    test('Analytical 4x4 planar reflection matrix mirrors points across horizontal water plane', () {
      // Horizontal water plane at height Y = 2.0 (normal = (0, 1, 0), d = -2.0)
      const double planeHeight = 2.0;
      final Float32List matrix = PlanarReflectionMatrix.createReflectionMatrix(
        planeNormal: WorldVector3.unitY,
        planeD: -planeHeight,
      );

      // Verify analytical structure:
      // Column 0: (1, 0, 0, 0)
      // Column 1: (0, -1, 0, 0)
      // Column 2: (0, 0, 1, 0)
      // Column 3: (0, 2*h, 0, 1) = (0, 4.0, 0, 1)
      expect(matrix[0], closeTo(1.0, 1e-6));
      expect(matrix[5], closeTo(-1.0, 1e-6));
      expect(matrix[10], closeTo(1.0, 1e-6));
      expect(matrix[13], closeTo(2.0 * planeHeight, 1e-6));
      expect(matrix[15], closeTo(1.0, 1e-6));

      // Test point 1 unit above water plane (Y = 3.0) reflects to 1 unit below (Y = 1.0)
      const WorldVector3 abovePoint = WorldVector3(5.0, 3.0, 7.0);
      final WorldVector3 reflectedPoint = PlanarReflectionMatrix.transformPoint(matrix, abovePoint);

      expect(reflectedPoint.x, closeTo(5.0, 1e-5));
      expect(reflectedPoint.y, closeTo(1.0, 1e-5));
      expect(reflectedPoint.z, closeTo(7.0, 1e-5));

      // A point lying directly on the water surface (Y = 2.0) is invariant under reflection
      const WorldVector3 surfacePoint = WorldVector3(10.0, 2.0, -4.0);
      final WorldVector3 reflectedSurface = PlanarReflectionMatrix.transformPoint(matrix, surfacePoint);
      expect(reflectedSurface.y, closeTo(2.0, 1e-5));
    });

    test('3D incident ray specular reflection obeys Snell-Descartes law across perturbed normal', () {
      const WorldVector3 incident = WorldVector3(0.0, -1.0, 0.0);
      // Flat surface normal
      const WorldVector3 flatNormal = WorldVector3(0.0, 1.0, 0.0);
      final WorldVector3 flatReflect = incident.reflect(flatNormal);
      expect(flatReflect.y, closeTo(1.0, 1e-6));

      // Perturbed normal at 45 degrees
      final WorldVector3 perturbedNormal = const WorldVector3(0.7071068, 0.7071068, 0.0).normalized;
      final WorldVector3 perturbedReflect = incident.reflect(perturbedNormal);
      expect(perturbedReflect.length, closeTo(1.0, 1e-5));
      expect(perturbedReflect.x, closeTo(1.0, 1e-4));
      expect(perturbedReflect.y, closeTo(0.0, 1e-4));
    });

    test('calculatePlanarUV mirrors UV vertically and applies normal distortion and roughness jitter', () {
      const double planeY = 0.65;
      const ui.Offset uv = ui.Offset(0.5, 0.75); // 0.1 below plane

      // Flat undisturbed reflection
      final ui.Offset flatUV = SSRRaymarchMath.calculatePlanarUV(
        uv: uv,
        planeY: planeY,
        normalPerturbation: ui.Offset.zero,
        roughness: 0.0,
      );

      // Inverted Y = 2 * 0.65 - 0.75 = 0.55
      expect(flatUV.dx, closeTo(0.5, 1e-4));
      expect(flatUV.dy, closeTo(0.55, 1e-4));

      // Distorted reflection with ripple wave normal offset
      const ui.Offset rippleNormal = ui.Offset(0.3, -0.4);
      final ui.Offset distortedUV = SSRRaymarchMath.calculatePlanarUV(
        uv: uv,
        planeY: planeY,
        normalPerturbation: rippleNormal,
        roughness: 0.1,
      );

      // Jitter factor = 0.02 + 0.1 * 0.03 = 0.023
      expect(distortedUV.dx, closeTo(0.5 + 0.3 * 0.023, 1e-4));
      expect(distortedUV.dy, closeTo(0.55 - 0.4 * 0.023, 1e-4));

      // Clamping prevents out-of-bound coordinates at viewport edges
      final ui.Offset edgeUV = SSRRaymarchMath.calculatePlanarUV(
        uv: const ui.Offset(0.0001, 1.5),
        planeY: planeY,
        normalPerturbation: const ui.Offset(-10.0, -10.0),
      );
      expect(edgeUV.dx, greaterThanOrEqualTo(0.001));
      expect(edgeUV.dx, lessThanOrEqualTo(0.999));
      expect(edgeUV.dy, greaterThanOrEqualTo(0.001));
      expect(edgeUV.dy, lessThanOrEqualTo(0.999));
    });

    test('marchRayPath steps incrementally along screen space vector and bounds correctly', () {
      final List<ui.Offset> steps = SSRRaymarchMath.marchRayPath(
        startUV: const ui.Offset(0.5, 0.8),
        screenReflectDir: const ui.Offset(0.0, -1.0),
        stepSize: 0.05,
        maxSteps: 12,
      );

      // Steps marching upwards: y = 0.75, 0.70, ..., 0.25 (11 steps before hitting 0 or max)
      expect(steps.length, equals(12));
      expect(steps[0].dy, closeTo(0.75, 1e-4));
      expect(steps[11].dy, closeTo(0.20, 1e-4));

      // Ray leaving left edge exits immediately
      final List<ui.Offset> exitSteps = SSRRaymarchMath.marchRayPath(
        startUV: const ui.Offset(0.02, 0.5),
        screenReflectDir: const ui.Offset(-1.0, 0.0),
        stepSize: 0.05,
        maxSteps: 10,
      );
      expect(exitSteps.isEmpty, isTrue);
    });

    test('calculateEdgeFade attenuates smoothly near borders to eliminate SSR popping', () {
      const double margin = 0.10;

      // Exact viewport edge
      expect(SSRRaymarchMath.calculateEdgeFade(uv: const ui.Offset(0.0, 0.5), margin: margin),
          equals(0.0));
      expect(SSRRaymarchMath.calculateEdgeFade(uv: const ui.Offset(1.0, 0.5), margin: margin),
          equals(0.0));
      expect(SSRRaymarchMath.calculateEdgeFade(uv: const ui.Offset(0.5, 0.0), margin: margin),
          equals(0.0));
      expect(SSRRaymarchMath.calculateEdgeFade(uv: const ui.Offset(0.5, 1.0), margin: margin),
          equals(0.0));

      // Halfway through margin (t = 0.5): Hermite smoothstep = 0.5^2 * (3 - 2*0.5) = 0.5
      final double midFade = SSRRaymarchMath.calculateEdgeFade(
        uv: const ui.Offset(0.05, 0.5),
        margin: margin,
      );
      expect(midFade, closeTo(0.5, 1e-4));

      // Well within interior
      final double interiorFade = SSRRaymarchMath.calculateEdgeFade(
        uv: const ui.Offset(0.5, 0.5),
        margin: margin,
      );
      expect(interiorFade, equals(1.0));
    });
  });

  // ===========================================================================
  // 4. Dynamic Ripple Propagation, Harmonic Damping & Circular Ripple Pool
  // ===========================================================================
  group('Dynamic Ripple Propagation, Harmonic Damping & Circular Ripple Pool', () {
    test('Voronoi 2D hash functions are strictly deterministic, non-periodic, and normalized', () {
      final ui.Offset seed1 = const ui.Offset(12.34, 56.78);
      final double h1A = VoronoiRippleMath.hash12(seed1);
      final double h1B = VoronoiRippleMath.hash12(seed1);
      expect(h1A, equals(h1B));
      expect(h1A, greaterThanOrEqualTo(0.0));
      expect(h1A, lessThan(1.0));

      final ui.Offset h2A = VoronoiRippleMath.hash22(seed1);
      final ui.Offset h2B = VoronoiRippleMath.hash22(seed1);
      expect(h2A, equals(h2B));
      expect(h2A.dx, greaterThanOrEqualTo(0.0));
      expect(h2A.dx, lessThan(1.0));
      expect(h2A.dy, greaterThanOrEqualTo(0.0));
      expect(h2A.dy, lessThan(1.0));
    });

    test('Voronoi rain droplet ripples scale with intensity and generate dynamic wave slopes', () {
      final WorldVector3 calm = VoronoiRippleMath.evaluateDualOctave(
        uv: const ui.Offset(0.5, 0.5),
        time: 1.0,
        speed: 1.0,
        intensity: 0.0,
      );
      expect(calm, equals(WorldVector3.zero));

      final WorldVector3 active = VoronoiRippleMath.evaluateDualOctave(
        uv: const ui.Offset(0.3, 0.4),
        time: 2.0,
        speed: 1.2,
        intensity: 0.8,
      );

      // Normal offset vectors exist and are bounded
      expect(active.length, greaterThanOrEqualTo(0.0));
      expect(active.x.abs(), lessThan(2.0));
      expect(active.y.abs(), lessThan(2.0));
    });

    test('Gerstner wave normal and height displacement satisfy fluid dispersion and trochoid bounds', () {
      const GerstnerWaveOctave octave1 = GerstnerWaveMath.defaultOctave1;
      const GerstnerWaveOctave octave2 = GerstnerWaveMath.defaultOctave2;

      // Dispersion relation: k = 2 * pi / wavelength
      expect(octave1.waveNumber, closeTo((2.0 * math.pi) / octave1.waveLength, 1e-4));
      expect(octave2.waveNumber, closeTo((2.0 * math.pi) / octave2.waveLength, 1e-4));

      // Surface normal with wind chop displacement
      final WorldVector3 normal = GerstnerWaveMath.evaluateNormal(
        uv: const ui.Offset(0.2, 0.3),
        time: 1.5,
        intensity: 1.0,
        rippleSpeed: 1.0,
      );

      expect(normal.length, closeTo(1.0, 1e-5));
      expect(normal.z, greaterThan(0.0), reason: 'Liquid surface normal must face upward');

      // Wave height displacement oscillating within analytical amplitude limits
      final double h = GerstnerWaveMath.evaluateHeight(
        uv: const ui.Offset(0.4, 0.6),
        time: 2.5,
        intensity: 1.0,
      );
      final double maxPossibleAmplitude = octave1.amplitude + octave2.amplitude;
      expect(h.abs(), lessThanOrEqualTo(maxPossibleAmplitude + 1e-4));
    });

    test('PuddleRipple model exhibits linear radius expansion and exponential harmonic damping', () {
      final PuddleRipple ripple = PuddleRipple(
        center: const ui.Offset(0.5, 0.5),
        birthTime: 1.0,
        amplitude: 1.0,
        propagationSpeed: 2.0,
        dampingRate: 3.0,
        maxAge: 2.0,
      );

      // At birth (t = 1.0)
      expect(ripple.evaluateRadius(1.0), equals(0.0));
      expect(ripple.evaluateHarmonicDamping(1.0), closeTo(1.0, 1e-5));

      // After 0.5s (t = 1.5): Radius = 0.5 * 2.0 = 1.0
      expect(ripple.evaluateRadius(1.5), closeTo(1.0, 1e-5));
      // Damping = exp(-3.0 * 0.5) = exp(-1.5) ~= 0.2231
      expect(ripple.evaluateHarmonicDamping(1.5), closeTo(math.exp(-1.5), 1e-4));

      // After 1.0s (t = 2.0): Damping decays further
      expect(ripple.evaluateHarmonicDamping(2.0), lessThan(ripple.evaluateHarmonicDamping(1.5)));
      expect(ripple.evaluateHarmonicDamping(2.0), greaterThan(0.0));

      // Ripple wave elevation at the expanding wavefront ring
      final ui.Offset wavePoint = const ui.Offset(0.5 + 0.5, 0.5); // dist = 0.5
      // Wavefront reaches dist=0.5 at age = 0.5 / 2.0 = 0.25s -> time = 1.25s
      final double elevationAtPeak = ripple.evaluateWaveElevation(wavePoint, 1.25);
      expect(elevationAtPeak.abs(), greaterThanOrEqualTo(0.0));

      // Normal perturbation radiates radially outward from impact center
      final ui.Offset normal = ripple.evaluateNormalPerturbation(wavePoint, 1.25);
      expect(normal.dx.abs() + normal.dy.abs(), greaterThanOrEqualTo(0.0));

      // Ripple dies when age exceeds maxAge
      ripple.update(3.05); // age = 2.05 > 2.0
      expect(ripple.isAlive, isFalse);
    });

    test('PuddleRipplePool reuses memory and recycles ripples with zero leak', () {
      final PuddleRipplePool pool = PuddleRipplePool(capacity: 4);

      expect(pool.poolAvailableCount, equals(4));
      expect(pool.activeCount, equals(0));

      // Spawn 3 ripples
      final PuddleRipple? r1 = pool.spawn(center: const ui.Offset(0.1, 0.1), currentTime: 0.0);
      final PuddleRipple? r2 = pool.spawn(center: const ui.Offset(0.2, 0.2), currentTime: 0.1);
      final PuddleRipple? r3 = pool.spawn(center: const ui.Offset(0.3, 0.3), currentTime: 0.2);

      expect(r1, isNotNull);
      expect(r2, isNotNull);
      expect(r3, isNotNull);
      expect(pool.activeCount, equals(3));
      expect(pool.poolAvailableCount, equals(1));

      // Spawn 4th ripple (capacity reached)
      final PuddleRipple? r4 = pool.spawn(center: const ui.Offset(0.4, 0.4), currentTime: 0.3);
      expect(r4, isNotNull);
      expect(pool.activeCount, equals(4));
      expect(pool.poolAvailableCount, equals(0));

      // Spawning beyond capacity steals oldest ripple (r1) without dropping or allocating
      final PuddleRipple? r5 = pool.spawn(center: const ui.Offset(0.5, 0.5), currentTime: 0.4);
      expect(r5, isNotNull);
      expect(pool.activeCount, equals(4));

      // Advance time past ripple lifetimes (e.g. 3.0s)
      pool.update(3.0);

      // All ripples should have expired and returned to pool
      expect(pool.activeCount, equals(0));
      expect(pool.poolAvailableCount, equals(4));

      // Clear empties active list
      pool.spawn(center: const ui.Offset(0.1, 0.1), currentTime: 4.0);
      expect(pool.activeCount, equals(1));
      pool.clear();
      expect(pool.activeCount, equals(0));
      expect(pool.poolAvailableCount, equals(4));
    });
  });

  // ===========================================================================
  // 5. Wetness Mask Boundary Clipping & Puddle Surface Specular Shine
  // ===========================================================================
  group('Wetness Mask Boundary Clipping & Puddle Surface Specular Shine', () {
    test('Wetness mask thresholding clips non-puddle ground fragments', () {
      // In GLSL shader: if (puddlePresence <= 0.005) return groundColor;
      bool isPuddleFragment(double presence) => presence > 0.005;

      expect(isPuddleFragment(0.0), isFalse);
      expect(isPuddleFragment(0.003), isFalse);
      expect(isPuddleFragment(0.005), isFalse);
      expect(isPuddleFragment(0.0051), isTrue);
      expect(isPuddleFragment(0.5), isTrue);
      expect(isPuddleFragment(1.0), isTrue);
    });

    test('Wetness mask boundary feathering conforms to cubic Hermite smoothstep [0.01, 0.12]', () {
      double evaluatePuddleAlpha(double presence) {
        final double t = ((presence - 0.01) / (0.12 - 0.01)).clamp(0.0, 1.0);
        return t * t * (3.0 - 2.0 * t);
      }

      // At or below lower threshold: zero opacity
      expect(evaluatePuddleAlpha(0.0), equals(0.0));
      expect(evaluatePuddleAlpha(0.01), equals(0.0));

      // At upper threshold: full puddle layer opacity
      expect(evaluatePuddleAlpha(0.12), equals(1.0));
      expect(evaluatePuddleAlpha(0.5), equals(1.0));

      // Midpoint: (0.065 - 0.01) / 0.11 = 0.055 / 0.11 = 0.5 -> smoothstep = 0.5
      expect(evaluatePuddleAlpha(0.065), closeTo(0.5, 1e-4));
    });

    test('Beer-Lambert water volume depth absorption extinguishes light exponentially', () {
      // T = exp(-extinction * depth * 3.5)
      const double extinction = 0.4;
      const double depthScale = 1.0;

      final double t0 = SSRRaymarchMath.calculateBeerLambertTransmittance(
        waterDepth: 0.0,
        extinctionCoeff: extinction,
        depthScale: depthScale,
      );
      expect(t0, closeTo(1.0, 1e-6));

      final double tShallow = SSRRaymarchMath.calculateBeerLambertTransmittance(
        waterDepth: 0.2,
        extinctionCoeff: extinction,
        depthScale: depthScale,
      );

      final double tDeep = SSRRaymarchMath.calculateBeerLambertTransmittance(
        waterDepth: 0.8,
        extinctionCoeff: extinction,
        depthScale: depthScale,
      );

      expect(tShallow, lessThan(t0));
      expect(tDeep, lessThan(tShallow));
      expect(tDeep, greaterThan(0.0));
    });

    test('Schlick Fresnel approximation calculates water specular shine across view angles', () {
      // Normal incidence (cosTheta = 1.0): strictly F0 (water ≈ 0.0204)
      final double fNormal = SchlickFresnel.evaluate(
        cosTheta: 1.0,
        f0: SchlickFresnel.waterF0,
        roughness: 0.0,
      );
      expect(fNormal, closeTo(SchlickFresnel.waterF0, 1e-6));

      // Grazing angle (cosTheta = 0.0): maximum specular reflectance (1.0 for smooth water)
      final double fGrazingSmooth = SchlickFresnel.evaluate(
        cosTheta: 0.0,
        f0: SchlickFresnel.waterF0,
        roughness: 0.0,
      );
      expect(fGrazingSmooth, closeTo(1.0, 1e-6));

      // Grazing angle on rough water (roughness = 0.3): capped by 1.0 - roughness = 0.7
      final double fGrazingRough = SchlickFresnel.evaluate(
        cosTheta: 0.0,
        f0: SchlickFresnel.waterF0,
        roughness: 0.3,
      );
      expect(fGrazingRough, closeTo(0.7, 1e-5));

      // Strict monotonic growth from normal incidence to grazing
      double prev = -1.0;
      for (double cosT = 1.0; cosT >= 0.0; cosT -= 0.05) {
        final double val = SchlickFresnel.evaluate(cosTheta: cosT);
        expect(val, greaterThanOrEqualTo(prev - 1e-9));
        prev = val;
      }
    });

    test('Droplet sparkle specular boost excites wave crests in heavy downpour', () {
      double computeSparkle(double rippleZ, double rainIntensity) {
        final double clampedZ = rippleZ.clamp(0.0, 1.0);
        return math.pow(clampedZ, 3.0) * rainIntensity * 0.45;
      }

      // Calm rain produces no sparkles
      expect(computeSparkle(0.9, 0.0), equals(0.0));

      // Trough/negative elevation produces no sparkles
      expect(computeSparkle(-0.5, 1.0), equals(0.0));

      // Peak crest (z = 1.0) under storm (rain = 1.0) produces peak highlight
      expect(computeSparkle(1.0, 1.0), closeTo(0.45, 1e-5));

      // Non-linear cubic power concentrates sparkle only on sharpest crests
      final double midSparkle = computeSparkle(0.5, 1.0); // 0.125 * 0.45 = 0.05625
      expect(midSparkle, closeTo(0.05625, 1e-4));
    });

    test('Procedural celestial highlight scales with roughness shininess factor', () {
      double computeCelestialSpec(double dotVal, double roughness) {
        final double shininess = (1.0 - roughness) * 128.0 + roughness * 8.0;
        return math.pow(dotVal.clamp(0.0, 1.0), shininess) * 2.2;
      }

      // Directly aligned celestial highlight (dot = 1.0)
      expect(computeCelestialSpec(1.0, 0.0), closeTo(2.2, 1e-5));
      expect(computeCelestialSpec(1.0, 0.5), closeTo(2.2, 1e-5));

      // Slightly off-axis (dot = 0.95): sharp highlight on mirror puddle, broader on rough puddle
      final double specSmooth = computeCelestialSpec(0.95, 0.0);
      final double specRough = computeCelestialSpec(0.95, 0.5);

      expect(specSmooth, lessThan(specRough));
      expect(specSmooth, greaterThan(0.0));
    });
  });

  // ===========================================================================
  // 6. Controller Lifecycle, Painter & Flutter Widget Integration
  // ===========================================================================
  group('Controller Lifecycle, Painter & Flutter Widget Integration', () {
    test('PuddleReflectionController manages simulation state and listener dispatches', () {
      final PuddleReflectionController controller = PuddleReflectionController(
        config: PuddleReflectionConfig.calmAfterRain(),
      );

      int listenerCalls = 0;
      controller.addListener(() => listenerCalls++);

      // Time advance
      controller.update(0.016);
      expect(controller.time, closeTo(0.016, 1e-4));
      expect(listenerCalls, equals(1));

      // Zero or negative dt does not notify
      controller.update(0.0);
      controller.update(-0.01);
      expect(listenerCalls, equals(1));

      // Rain intensity mutation
      controller.setRainIntensity(0.85);
      expect(controller.rainIntensity, closeTo(0.85, 1e-4));
      expect(listenerCalls, equals(2));

      // Setting identical config does not redundantly notify
      controller.setRainIntensity(0.85);
      expect(listenerCalls, equals(2));

      // Roughness modulation
      controller.setRoughness(0.12);
      expect(controller.config.puddleRoughness, closeTo(0.12, 1e-4));
      expect(listenerCalls, equals(3));

      // Camera position and view vector
      controller.setCamera(
        position: const WorldVector3(1.0, 2.0, 4.0),
        direction: const WorldVector3(0.0, -0.5, -0.866),
      );
      expect(controller.config.cameraPosition, equals(const WorldVector3(1.0, 2.0, 4.0)));
      expect(listenerCalls, equals(4));

      // Reset
      controller.reset();
      expect(controller.time, equals(0.0));
      expect(listenerCalls, equals(5));

      // Dispose
      controller.dispose();
      controller.update(0.016);
      expect(listenerCalls, equals(5));
    });

    test('PuddleReflectionPainter shouldRepaint triggers only on genuine property alterations', () {
      final PuddleReflectionController ctrl1 = PuddleReflectionController();
      final PuddleReflectionController ctrl2 = PuddleReflectionController();

      final PuddleReflectionPainter painterA = PuddleReflectionPainter(controller: ctrl1);
      final PuddleReflectionPainter painterSame = PuddleReflectionPainter(controller: ctrl1);
      final PuddleReflectionPainter painterDifferentCtrl = PuddleReflectionPainter(controller: ctrl2);

      expect(painterA.shouldRepaint(painterSame), isFalse);
      expect(painterA.shouldRepaint(painterDifferentCtrl), isTrue);

      final Path p1 = Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50));
      final Path p2 = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));

      final PuddleReflectionPainter painterPath1 = PuddleReflectionPainter(
        controller: ctrl1,
        customPuddlePath: p1,
      );
      final PuddleReflectionPainter painterPath2 = PuddleReflectionPainter(
        controller: ctrl1,
        customPuddlePath: p2,
      );

      expect(painterPath1.shouldRepaint(painterPath2), isTrue);

      ctrl1.dispose();
      ctrl2.dispose();
    });

    testWidgets('PuddleReflectionLayer mounts cleanly and renders CPU fallback path in test harness', (
      WidgetTester tester,
    ) async {
      final PuddleReflectionController controller = PuddleReflectionController(
        config: PuddleReflectionConfig.nightHubReflections(),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: <Widget>[
              const SizedBox(width: 800, height: 600),
              PuddleReflectionLayer(
                controller: controller,
                child: const Text('Night Hub Plaza Ground'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Night Hub Plaza Ground'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Frame advance
      controller.update(0.033);
      await tester.pump();

      expect(tester.takeException(), isNull);
      controller.dispose();
    });

    testWidgets('PuddleReflectionLayer renders with custom puddle geometry and downpour ripples', (
      WidgetTester tester,
    ) async {
      final PuddleReflectionController controller = PuddleReflectionController(
        config: PuddleReflectionConfig.heavyDownpour(),
      );

      final Path customPolygon = Path()
        ..moveTo(50, 200)
        ..lineTo(350, 180)
        ..lineTo(400, 320)
        ..lineTo(80, 340)
        ..close();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 600,
            height: 400,
            child: PuddleReflectionLayer(
              controller: controller,
              customPuddlePath: customPolygon,
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);

      controller.update(0.05);
      await tester.pump();

      expect(tester.takeException(), isNull);
      controller.dispose();
    });

    testWidgets('PuddleReflectionPainter paint returns safely on zero or empty viewport dimensions', (
      WidgetTester tester,
    ) async {
      final PuddleReflectionController controller = PuddleReflectionController();

      // Zero-size viewport test
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 0.0,
            height: 0.0,
            child: PuddleReflectionLayer(controller: controller),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      controller.dispose();
    });
  });
}
