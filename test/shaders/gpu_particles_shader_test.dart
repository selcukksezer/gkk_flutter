import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/vfx/gpu_particle_system.dart';

/// Test recording canvas capturing invocations for headless verification.
class DrawCircleRecord {
  const DrawCircleRecord({
    required this.center,
    required this.radius,
    required this.paint,
  });

  final Offset center;
  final double radius;
  final Paint paint;
}

class DrawLineRecord {
  const DrawLineRecord({
    required this.p1,
    required this.p2,
    required this.paint,
  });

  final Offset p1;
  final Offset p2;
  final Paint paint;
}

class RecordingCanvas implements Canvas {
  final List<String> callLog = <String>[];
  final List<DrawCircleRecord> circles = <DrawCircleRecord>[];
  final List<DrawLineRecord> lines = <DrawLineRecord>[];
  final List<Rect> rects = <Rect>[];
  final List<Offset> translations = <Offset>[];
  final List<double> rotations = <double>[];
  int saveCount = 0;
  int restoreCount = 0;

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    callLog.add('drawCircle');
    circles.add(DrawCircleRecord(
      center: c,
      radius: radius,
      paint: Paint()
        ..color = paint.color
        ..blendMode = paint.blendMode
        ..style = paint.style
        ..strokeWidth = paint.strokeWidth,
    ));
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    callLog.add('drawLine');
    lines.add(DrawLineRecord(
      p1: p1,
      p2: p2,
      paint: Paint()
        ..color = paint.color
        ..blendMode = paint.blendMode
        ..style = paint.style
        ..strokeWidth = paint.strokeWidth
        ..strokeCap = paint.strokeCap,
    ));
  }

  @override
  void drawRect(Rect rect, Paint paint) {
    callLog.add('drawRect');
    rects.add(rect);
  }

  @override
  void save() {
    callLog.add('save');
    saveCount++;
  }

  @override
  void restore() {
    callLog.add('restore');
    restoreCount++;
  }

  @override
  void translate(double dx, double dy) {
    callLog.add('translate');
    translations.add(Offset(dx, dy));
  }

  @override
  void rotate(double radians) {
    callLog.add('rotate');
    rotations.add(radians);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Mock FragmentShader to verify GpuParticleShaderUniforms.apply.
class MockFragmentShader implements ui.FragmentShader {
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

  @override
  void dispose() {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group 1: GPU Particle Shader (GLSL 460) Specification & Layout Parity', () {
    late File shaderFile;
    late String shaderSource;

    setUpAll(() {
      shaderFile = File('shaders/vfx/gpu_particles.frag');
      expect(shaderFile.existsSync(), isTrue, reason: 'gpu_particles.frag must exist in shaders/vfx/');
      shaderSource = shaderFile.readAsStringSync();
    });

    test('Shader header declares version 460 core and flutter runtime_effect include', () {
      expect(shaderSource, contains('#version 460 core'));
      expect(shaderSource, contains('#include <flutter/runtime_effect.glsl>'));
      expect(shaderSource, contains('precision highp float;'));
    });

    test('Shader declares all 24 uniform floats in contiguous specification order', () {
      expect(shaderSource, contains('uniform vec2 uResolution;')); // 0..1
      expect(shaderSource, contains('uniform float uTime;')); // 2
      expect(shaderSource, contains('uniform vec4 uBounds;')); // 3..6
      expect(shaderSource, contains('uniform float uParticleType;')); // 7
      expect(shaderSource, contains('uniform float uLifetimeProgress;')); // 8
      expect(shaderSource, contains('uniform vec4 uColorStart;')); // 9..12
      expect(shaderSource, contains('uniform vec4 uColorEnd;')); // 13..16
      expect(shaderSource, contains('uniform vec2 uVelocity;')); // 17..18
      expect(shaderSource, contains('uniform float uTurbulence;')); // 19
      expect(shaderSource, contains('uniform float uEmissiveIntensity;')); // 20
      expect(shaderSource, contains('uniform float uSize;')); // 21
      expect(shaderSource, contains('uniform float uRotation;')); // 22
      expect(shaderSource, contains('uniform float uLayerParam;')); // 23
    });

    test('Shader defines fragment output and procedural synthesizers for all 5 particle types', () {
      expect(shaderSource, contains('out vec4 fragColor;'));
      expect(shaderSource, contains('vec4 renderSpellOrb(vec2 p, float dist, float age)'));
      expect(shaderSource, contains('vec4 renderSpark(vec2 p, float age)'));
      expect(shaderSource, contains('vec4 renderBloodDroplet(vec2 p, float age)'));
      expect(shaderSource, contains('vec4 renderMagicRune(vec2 p, float age)'));
      expect(shaderSource, contains('vec4 renderShockwave(vec2 p, float age)'));
    });

    test('Shader outputs premultiplied alpha and discards near-zero alpha fragments', () {
      expect(shaderSource, contains('if (result.a <= 0.001)'));
      expect(shaderSource, contains('discard;'));
      expect(shaderSource, contains('fragColor = vec4(result.rgb * result.a, result.a);'));
    });
  });

  group('Group 2: GpuParticleShaderUniforms Packing & Memory Layout', () {
    test('uniformFloatCount equals exactly 24 floats matching GLSL declaration', () {
      expect(GpuParticleShaderUniforms.uniformFloatCount, equals(24));
    });

    test('pack() maps all parameters to correct float indices', () {
      const Size resolution = Size(1920.0, 1080.0);
      const double time = 12.345;
      const Rect bounds = Rect.fromLTWH(100.0, 200.0, 64.0, 64.0);
      const GpuParticleType type = GpuParticleType.bloodDroplet;
      const double lifetimeProgress = 0.65;
      const Color startColor = Color.fromARGB(255, 200, 150, 100);
      const Color endColor = Color.fromARGB(0, 50, 40, 30);
      const Offset velocity = Offset(120.0, -80.0);
      const double turbulence = 3.5;
      const double emissive = 2.8;
      const double size = 32.0;
      const double rotation = 1.57;
      const double layerParam = 0.42;

      final Float32List uniforms = GpuParticleShaderUniforms.pack(
        resolution: resolution,
        time: time,
        bounds: bounds,
        type: type,
        lifetimeProgress: lifetimeProgress,
        startColor: startColor,
        endColor: endColor,
        velocity: velocity,
        turbulence: turbulence,
        emissiveIntensity: emissive,
        size: size,
        rotation: rotation,
        layerParam: layerParam,
      );

      expect(uniforms.length, equals(24));

      // 0..1: uResolution
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));

      // 2: uTime
      expect(uniforms[2], closeTo(12.345, 1e-4));

      // 3..6: uBounds (minX, minY, width, height)
      expect(uniforms[3], equals(100.0));
      expect(uniforms[4], equals(200.0));
      expect(uniforms[5], equals(64.0));
      expect(uniforms[6], equals(64.0));

      // 7: uParticleType (bloodDroplet index == 2)
      expect(uniforms[7], equals(2.0));

      // 8: uLifetimeProgress
      expect(uniforms[8], closeTo(0.65, 1e-4));

      // 9..12: uColorStart (RGBA in [0, 1])
      expect(uniforms[9], closeTo(startColor.r, 1e-4));
      expect(uniforms[10], closeTo(startColor.g, 1e-4));
      expect(uniforms[11], closeTo(startColor.b, 1e-4));
      expect(uniforms[12], closeTo(startColor.a, 1e-4));

      // 13..16: uColorEnd (RGBA in [0, 1])
      expect(uniforms[13], closeTo(endColor.r, 1e-4));
      expect(uniforms[14], closeTo(endColor.g, 1e-4));
      expect(uniforms[15], closeTo(endColor.b, 1e-4));
      expect(uniforms[16], closeTo(endColor.a, 1e-4));

      // 17..18: uVelocity
      expect(uniforms[17], equals(120.0));
      expect(uniforms[18], equals(-80.0));

      // 19: uTurbulence
      expect(uniforms[19], equals(3.5));

      // 20: uEmissiveIntensity
      expect(uniforms[20], equals(2.8));

      // 21: uSize
      expect(uniforms[21], equals(32.0));

      // 22: uRotation
      expect(uniforms[22], equals(1.57));

      // 23: uLayerParam
      expect(uniforms[23], equals(0.42));
    });

    test('pack() clamps lifetimeProgress strictly to [0.0, 1.0]', () {
      final Float32List low = GpuParticleShaderUniforms.pack(
        resolution: const Size(100, 100),
        time: 0.0,
        bounds: Rect.zero,
        type: GpuParticleType.spellOrb,
        lifetimeProgress: -0.85,
        startColor: const Color(0xFFFFFFFF),
        endColor: const Color(0x00000000),
        velocity: Offset.zero,
        turbulence: 0.0,
        emissiveIntensity: 1.0,
        size: 10.0,
        rotation: 0.0,
        layerParam: 0.0,
      );
      expect(low[8], equals(0.0));

      final Float32List high = GpuParticleShaderUniforms.pack(
        resolution: const Size(100, 100),
        time: 0.0,
        bounds: Rect.zero,
        type: GpuParticleType.spellOrb,
        lifetimeProgress: 1.75,
        startColor: const Color(0xFFFFFFFF),
        endColor: const Color(0x00000000),
        velocity: Offset.zero,
        turbulence: 0.0,
        emissiveIntensity: 1.0,
        size: 10.0,
        rotation: 0.0,
        layerParam: 0.0,
      );
      expect(high[8], equals(1.0));
    });

    test('pack() maps all GpuParticleType enum variants correctly', () {
      final List<GpuParticleType> types = <GpuParticleType>[
        GpuParticleType.spellOrb,
        GpuParticleType.sparkStreak,
        GpuParticleType.bloodDroplet,
        GpuParticleType.magicRune,
        GpuParticleType.shockwave,
      ];

      for (int i = 0; i < types.length; ++i) {
        final Float32List uniforms = GpuParticleShaderUniforms.pack(
          resolution: const Size(100, 100),
          time: 0.0,
          bounds: Rect.zero,
          type: types[i],
          lifetimeProgress: 0.0,
          startColor: const Color(0xFFFFFFFF),
          endColor: const Color(0x00000000),
          velocity: Offset.zero,
          turbulence: 0.0,
          emissiveIntensity: 1.0,
          size: 10.0,
          rotation: 0.0,
          layerParam: 0.0,
        );
        expect(uniforms[7], equals(i.toDouble()));
      }
    });

    test('apply() sets all 24 uniform floats sequentially into FragmentShader', () {
      final MockFragmentShader mockShader = MockFragmentShader();
      final Float32List sampleUniforms = Float32List(24);
      for (int i = 0; i < 24; ++i) {
        sampleUniforms[i] = (i + 1) * 1.5;
      }

      GpuParticleShaderUniforms.apply(mockShader, sampleUniforms);

      expect(mockShader.floats.length, equals(24));
      for (int i = 0; i < 24; ++i) {
        expect(mockShader.floats[i], equals(sampleUniforms[i]));
      }
    });
  });

  group('Group 3: GpuParticleBuffer Zero-GC Memory Management & Ring Recycling', () {
    test('Constructor initializes capacity, zero active count, and full free-list', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(100);

      expect(buffer.capacity, equals(100));
      expect(buffer.activeCount, equals(0));
      expect(buffer.freeCount, equals(100));
      expect(buffer.data.length, equals(100 * GpuParticleBuffer.stride));
      expect(buffer.activeIndices.length, equals(100));
    });

    test('allocate() consumes from free-list in O(1) and updates active tracking', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(10);

      final int? p0 = buffer.allocate();
      expect(p0, isNotNull);
      expect(buffer.activeCount, equals(1));
      expect(buffer.freeCount, equals(9));
      expect(buffer.activeIndices[0], equals(p0));

      final int? p1 = buffer.allocate();
      expect(p1, isNotNull);
      expect(p1, isNot(equals(p0)));
      expect(buffer.activeCount, equals(2));
      expect(buffer.freeCount, equals(8));
      expect(buffer.activeIndices[1], equals(p1));
    });

    test('allocate() returns null when buffer reaches full capacity', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(3);
      expect(buffer.allocate(), isNotNull);
      expect(buffer.allocate(), isNotNull);
      expect(buffer.allocate(), isNotNull);
      expect(buffer.activeCount, equals(3));
      expect(buffer.freeCount, equals(0));

      // Over-allocation attempt
      final int? overflow = buffer.allocate();
      expect(overflow, isNull);
      expect(buffer.activeCount, equals(3));
      expect(buffer.freeCount, equals(0));
    });

    test('free() performs O(1) swap-and-pop maintaining dense contiguous activeIndices', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(5);

      final int p0 = buffer.allocate()!;
      final int p1 = buffer.allocate()!;
      final int p2 = buffer.allocate()!;

      expect(buffer.activeCount, equals(3));
      expect(buffer.activeIndices[0], equals(p0));
      expect(buffer.activeIndices[1], equals(p1));
      expect(buffer.activeIndices[2], equals(p2));

      // Free middle particle p1 -> p2 swaps into index 1
      buffer.free(p1);
      expect(buffer.activeCount, equals(2));
      expect(buffer.freeCount, equals(3));
      expect(buffer.activeIndices[0], equals(p0));
      expect(buffer.activeIndices[1], equals(p2));

      // Free head particle p0 -> p2 swaps into index 0
      buffer.free(p0);
      expect(buffer.activeCount, equals(1));
      expect(buffer.freeCount, equals(4));
      expect(buffer.activeIndices[0], equals(p2));

      // Free remaining particle
      buffer.free(p2);
      expect(buffer.activeCount, equals(0));
      expect(buffer.freeCount, equals(5));
    });

    test('free() handles invalid or duplicate recycling gracefully as a safe no-op', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(5);
      final int p = buffer.allocate()!;

      buffer.free(p);
      expect(buffer.activeCount, equals(0));

      // Duplicate free on already freed particle
      buffer.free(p);
      expect(buffer.activeCount, equals(0));
      expect(buffer.freeCount, equals(5));

      // Freeing an out-of-bounds or non-allocated index
      buffer.free(999);
      expect(buffer.activeCount, equals(0));
      expect(buffer.freeCount, equals(5));
    });

    test('Direct attribute accessors (position, velocity, life, size, rotation, seed)', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(10);
      final int p = buffer.allocate()!;

      buffer.setPosition(p, 123.5, 456.75);
      expect(buffer.getX(p), equals(123.5));
      expect(buffer.getY(p), equals(456.75));

      buffer.setVelocity(p, -50.0, 75.25);
      expect(buffer.getVx(p), equals(-50.0));
      expect(buffer.getVy(p), equals(75.25));

      buffer.setLife(p, 0.75, 1.5);
      expect(buffer.getLife(p), equals(0.75));
      expect(buffer.getMaxLife(p), equals(1.5));
      expect(buffer.getNormalizedAge(p), closeTo(0.5, 1e-5));

      // Set start and end sizes
      final int base = p * GpuParticleBuffer.stride;
      buffer.data[base + GpuParticleBuffer.kOffsetStartSize] = 10.0;
      buffer.data[base + GpuParticleBuffer.kOffsetEndSize] = 20.0;
      expect(buffer.getCurrentSize(p), closeTo(15.0, 1e-5));

      buffer.setRotation(p, 3.14, 0.5);
      expect(buffer.getRotation(p), equals(3.14));
      expect(buffer.getRotSpeed(p), equals(0.5));

      buffer.data[base + GpuParticleBuffer.kOffsetLayerId] = 2.0;
      buffer.data[base + GpuParticleBuffer.kOffsetSeed] = 0.88;
      expect(buffer.getLayerId(p), equals(2));
      expect(buffer.getSeed(p), equals(0.88));
    });

    test('getCurrentColor() interpolates RGBA across lifetime accurately', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(5);
      final int p = buffer.allocate()!;
      final int base = p * GpuParticleBuffer.stride;

      buffer.data[base + GpuParticleBuffer.kOffsetColorR0] = 1.0;
      buffer.data[base + GpuParticleBuffer.kOffsetColorG0] = 0.0;
      buffer.data[base + GpuParticleBuffer.kOffsetColorB0] = 0.0;
      buffer.data[base + GpuParticleBuffer.kOffsetColorA0] = 1.0;

      buffer.data[base + GpuParticleBuffer.kOffsetColorR1] = 0.0;
      buffer.data[base + GpuParticleBuffer.kOffsetColorG1] = 0.0;
      buffer.data[base + GpuParticleBuffer.kOffsetColorB1] = 1.0;
      buffer.data[base + GpuParticleBuffer.kOffsetColorA1] = 0.0;

      // Age = 0.0 -> Red fully opaque
      buffer.setLife(p, 0.0, 1.0);
      Color c = buffer.getCurrentColor(p);
      expect(c.r, closeTo(1.0, 0.01));
      expect(c.b, closeTo(0.0, 0.01));
      expect(c.a, closeTo(1.0, 0.01));

      // Age = 0.5 -> Midpoint (r=0.5, b=0.5, a=0.5)
      buffer.setLife(p, 0.5, 1.0);
      c = buffer.getCurrentColor(p);
      expect(c.r, closeTo(0.5, 0.02));
      expect(c.b, closeTo(0.5, 0.02));
      expect(c.a, closeTo(0.5, 0.02));

      // Age = 1.0 -> Blue fully transparent
      buffer.setLife(p, 1.0, 1.0);
      c = buffer.getCurrentColor(p);
      expect(c.r, closeTo(0.0, 0.01));
      expect(c.b, closeTo(1.0, 0.01));
      expect(c.a, closeTo(0.0, 0.01));
    });

    test('clear() resets active count and restores entire capacity to free-list', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(10);
      for (int i = 0; i < 7; ++i) {
        buffer.allocate();
      }
      expect(buffer.activeCount, equals(7));

      buffer.clear();
      expect(buffer.activeCount, equals(0));
      expect(buffer.freeCount, equals(10));

      // Can allocate all 10 slots again
      for (int i = 0; i < 10; ++i) {
        expect(buffer.allocate(), isNotNull);
      }
      expect(buffer.activeCount, equals(10));
      expect(buffer.freeCount, equals(0));
    });
  });

  group('Group 4: GpuNoise & Divergence-Free Curl Field Mathematical Parity', () {
    test('simplex2D generates bounded deterministic procedural values in [-1.0, 1.0]', () {
      for (double x = -10.0; x <= 10.0; x += 1.5) {
        for (double y = -10.0; y <= 10.0; y += 1.5) {
          final double val = GpuNoise.simplex2D(x, y);
          expect(val, greaterThanOrEqualTo(-1.0));
          expect(val, lessThanOrEqualTo(1.0));
        }
      }
      // Determinism
      expect(GpuNoise.simplex2D(1.23, 4.56), equals(GpuNoise.simplex2D(1.23, 4.56)));
    });

    test('simplex2D exhibits spatial continuity for nearby sample coordinates', () {
      const double x = 2.5;
      const double y = 3.5;
      final double base = GpuNoise.simplex2D(x, y);
      final double nearby = GpuNoise.simplex2D(x + 0.001, y + 0.001);
      expect((base - nearby).abs(), lessThan(0.01));
    });

    test('curlNoise2D is divergence-free: div(V) = dVx/dx + dVy/dy ~ 0', () {
      // Numerical divergence test: div(V) = (V_x(x+h, y) - V_x(x-h, y))/(2h) + (V_y(x, y+h) - V_y(x, y-h))/(2h)
      const double h = 0.005;
      const List<Offset> testPoints = <Offset>[
        Offset(0.5, 0.5),
        Offset(2.0, -1.5),
        Offset(-3.2, 4.1),
        Offset(10.0, 10.0),
      ];

      for (final Offset pt in testPoints) {
        final (double vxRight, _) = GpuNoise.curlNoise2D(pt.dx + h, pt.dy);
        final (double vxLeft, _) = GpuNoise.curlNoise2D(pt.dx - h, pt.dy);
        final double dVxDx = (vxRight - vxLeft) / (2.0 * h);

        final (_, double vyUp) = GpuNoise.curlNoise2D(pt.dx, pt.dy + h);
        final (_, double vyDown) = GpuNoise.curlNoise2D(pt.dx, pt.dy - h);
        final double dVyDy = (vyUp - vyDown) / (2.0 * h);

        final double divergence = dVxDx + dVyDy;
        expect(divergence.abs(), lessThan(0.06),
            reason: 'Curl noise vector field must have zero divergence at $pt');
      }
    });
  });

  group('Group 5: Particle Physics Integration Engine', () {
    test('Gravity acceleration integrates correctly into velocity and position', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'GravityLayer',
            type: GpuParticleType.sparkStreak,
            maxParticles: 10,
            gravity: Offset(0, 500),
          ),
        ],
      );

      final int? p = system.buffer.allocate();
      expect(p, isNotNull);
      system.buffer.setPosition(p!, 0.0, 0.0);
      system.buffer.setVelocity(p, 0.0, 0.0);
      system.buffer.setLife(p, 0.0, 10.0);
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetLayerId] = 0.0;

      // Update 0.1s: vy += 500 * 0.1 = 50; y += 50 * 0.1 = 5.0
      system.update(0.1);
      expect(system.buffer.getVy(p), closeTo(50.0, 1e-4));
      expect(system.buffer.getY(p), closeTo(5.0, 1e-4));

      // Update another 0.1s: vy += 50; y += 100 * 0.1 = 15.0
      system.update(0.1);
      expect(system.buffer.getVy(p), closeTo(100.0, 1e-4));
      expect(system.buffer.getY(p), closeTo(15.0, 1e-4));
    });

    test('Drag damping attenuates velocity exponentially', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'DragLayer',
            type: GpuParticleType.bloodDroplet,
            maxParticles: 10,
            drag: 2.0, // factor = 1 - 2.0 * 0.1 = 0.8
          ),
        ],
      );

      final int p = system.buffer.allocate()!;
      system.buffer.setPosition(p, 0.0, 0.0);
      system.buffer.setVelocity(p, 100.0, 100.0);
      system.buffer.setLife(p, 0.0, 10.0);
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetLayerId] = 0.0;

      system.update(0.1);
      expect(system.buffer.getVx(p), closeTo(80.0, 1e-4));
      expect(system.buffer.getVy(p), closeTo(80.0, 1e-4));

      system.update(0.1);
      expect(system.buffer.getVx(p), closeTo(64.0, 1e-4));
      expect(system.buffer.getVy(p), closeTo(64.0, 1e-4));
    });

    test('Floor collision plane reflects velocity with bounce and applies ground friction', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'FloorBounceLayer',
            type: GpuParticleType.sparkStreak,
            maxParticles: 10,
            floorY: 200.0,
            bounce: 0.6,
          ),
        ],
      );

      final int p = system.buffer.allocate()!;
      system.buffer.setPosition(p, 10.0, 190.0);
      system.buffer.setVelocity(p, 50.0, 200.0); // downward
      system.buffer.setLife(p, 0.0, 10.0);
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetLayerId] = 0.0;

      // dt = 0.1s -> y reaches 190 + 20 = 210 >= 200.0
      system.update(0.1);

      // Floor clamped to 200.0
      expect(system.buffer.getY(p), equals(200.0));
      // vy negated and scaled by bounce: -200 * 0.6 = -120.0
      expect(system.buffer.getVy(p), closeTo(-120.0, 1e-4));
      // vx dampened by ground friction (0.8): 50 * 0.8 = 40.0
      expect(system.buffer.getVx(p), closeTo(40.0, 1e-4));
    });

    test('Micro-bounce velocities below threshold clamp to zero', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'SettlingLayer',
            type: GpuParticleType.sparkStreak,
            maxParticles: 10,
            floorY: 100.0,
            bounce: 0.5,
          ),
        ],
      );

      final int p = system.buffer.allocate()!;
      system.buffer.setPosition(p, 0.0, 99.0);
      system.buffer.setVelocity(p, 0.0, 15.0); // -15 * 0.5 = -7.5 < 10.0 abs
      system.buffer.setLife(p, 0.0, 10.0);
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetLayerId] = 0.0;

      system.update(0.1);
      expect(system.buffer.getY(p), equals(100.0));
      expect(system.buffer.getVy(p), equals(0.0));
    });

    test('Angular rotation integrates rotSpeed * dt', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'RuneLayer',
            type: GpuParticleType.magicRune,
            maxParticles: 10,
          ),
        ],
      );

      final int p = system.buffer.allocate()!;
      system.buffer.setRotation(p, 0.0, 2.5); // rotSpeed = 2.5 rad/s
      system.buffer.setLife(p, 0.0, 10.0);
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetLayerId] = 0.0;

      system.update(0.2);
      expect(system.buffer.getRotation(p), closeTo(0.5, 1e-4));
    });

    test('Particle lifecycle automatically recycles expired particles', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'ShortLived',
            type: GpuParticleType.spellOrb,
            maxParticles: 10,
          ),
        ],
      );

      final int p = system.buffer.allocate()!;
      system.buffer.setLife(p, 0.0, 0.5); // maxLife = 0.5s
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetLayerId] = 0.0;
      expect(system.activeParticleCount, equals(1));

      system.update(0.3); // life = 0.3 < 0.5
      expect(system.activeParticleCount, equals(1));

      system.update(0.25); // life = 0.55 >= 0.5 -> recycled
      expect(system.activeParticleCount, equals(0));
      expect(system.buffer.freeCount, equals(10));
    });

    test('emitBurst() respects origin, directionAngle, speed, and count', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'BurstLayer',
            type: GpuParticleType.sparkStreak,
            maxParticles: 50,
            minSpeed: 100.0,
            maxSpeed: 100.0,
            spreadAngle: 0.0, // strictly forward
            emissionAngle: 0.0, // along +X
            minLifetime: 1.0,
            maxLifetime: 1.0,
          ),
        ],
        randomSeed: 42,
      );

      final int spawned = system.emitBurst(
        layerIndex: 0,
        count: 5,
        origin: const Offset(50.0, 100.0),
        directionAngle: 0.0,
      );

      expect(spawned, equals(5));
      expect(system.activeParticleCount, equals(5));

      for (int i = 0; i < 5; ++i) {
        final int p = system.buffer.activeIndices[i];
        expect(system.buffer.getX(p), equals(50.0));
        expect(system.buffer.getY(p), equals(100.0));
        expect(system.buffer.getVx(p), closeTo(100.0, 1e-3));
        expect(system.buffer.getVy(p), closeTo(0.0, 1e-3));
      }
    });

    test('emitAllLayersBurst() emits bursts concurrently across all system layers', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'Layer0',
            type: GpuParticleType.spellOrb,
            maxParticles: 20,
          ),
          const GpuParticleLayerConfig(
            name: 'Layer1',
            type: GpuParticleType.magicRune,
            maxParticles: 20,
          ),
        ],
      );

      final int total = system.emitAllLayersBurst(
        countPerLayer: 8,
        origin: const Offset(20, 20),
      );

      expect(total, equals(16));
      expect(system.activeParticleCount, equals(16));
    });

    test('Continuous emission rate accumulates and spawns particles over time', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'EmitterLayer',
            type: GpuParticleType.sparkStreak,
            maxParticles: 100,
            emissionRate: 50.0, // 50 particles/sec -> 5 particles per 0.1s
          ),
        ],
      );

      expect(system.activeParticleCount, equals(0));
      system.update(0.1);
      expect(system.activeParticleCount, equals(5));

      system.update(0.1);
      expect(system.activeParticleCount, equals(10));
    });

    test('reset() cleans all active particles, resets counters, and resets globalTime', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'ResetLayer',
            type: GpuParticleType.spellOrb,
            maxParticles: 50,
            emissionRate: 20.0,
          ),
        ],
      );

      system.update(0.5);
      expect(system.globalTime, closeTo(0.5, 1e-5));
      expect(system.activeParticleCount, greaterThan(0));

      system.reset();
      expect(system.globalTime, equals(0.0));
      expect(system.activeParticleCount, equals(0));
      expect(system.buffer.freeCount, equals(50));
    });

    test('update() with dt <= 0 is a safe no-op', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'NoOpLayer',
            type: GpuParticleType.spellOrb,
            maxParticles: 10,
          ),
        ],
      );

      system.update(0.0);
      system.update(-0.1);
      expect(system.globalTime, equals(0.0));
    });
  });

  group('Group 6: Preset Systems (Arcane Blast, Weapon Sparks, Blood Splatter, Shockwave)', () {
    test('spellArcaneBlast preset declares shockwave, arcane shards, and mystic runes', () {
      final GpuParticleSystem system = GpuParticlePresets.spellArcaneBlast();

      expect(system.layers.length, equals(3));

      // Layer 0: Shockwave Ring
      final GpuParticleLayerConfig shockwave = system.layers[0];
      expect(shockwave.name, equals('ArcaneShockwave'));
      expect(shockwave.type, equals(GpuParticleType.shockwave));
      expect(shockwave.blendMode, equals(GpuBlendMode.additive));
      expect(shockwave.startSize, equals(10.0));
      expect(shockwave.endSize, equals(180.0));
      expect(shockwave.emissiveIntensity, equals(4.0));

      // Layer 1: Arcane Shards
      final GpuParticleLayerConfig shards = system.layers[1];
      expect(shards.name, equals('ArcaneShards'));
      expect(shards.type, equals(GpuParticleType.sparkStreak));
      expect(shards.blendMode, equals(GpuBlendMode.additive));
      expect(shards.drag, equals(1.5));
      expect(shards.maxParticles, equals(400));

      // Layer 2: Mystic Runes
      final GpuParticleLayerConfig runes = system.layers[2];
      expect(runes.name, equals('MysticRunes'));
      expect(runes.type, equals(GpuParticleType.magicRune));
      expect(runes.blendMode, equals(GpuBlendMode.additive));
      expect(runes.minRotationSpeed, equals(-1.5));
      expect(runes.maxRotationSpeed, equals(1.5));

      // Emit and simulate explosion
      final int count = system.emitAllLayersBurst(
        countPerLayer: 5,
        origin: const Offset(100, 100),
      );
      expect(count, equals(15));
      system.update(0.1);
      expect(system.activeParticleCount, equals(15));
    });

    test('weaponImpact preset features ricochet sparks with floor bounce and impact flash', () {
      final GpuParticleSystem system = GpuParticlePresets.weaponImpact(
        normal: const Offset(0, -1), // floor bounce upward
        floorY: 300.0,
      );

      expect(system.layers.length, equals(2));

      final GpuParticleLayerConfig sparks = system.layers[0];
      expect(sparks.name, equals('RicochetSparks'));
      expect(sparks.type, equals(GpuParticleType.sparkStreak));
      expect(sparks.blendMode, equals(GpuBlendMode.additive));
      expect(sparks.gravity.dy, equals(850.0));
      expect(sparks.bounce, equals(0.65));
      expect(sparks.floorY, equals(300.0));

      final GpuParticleLayerConfig flash = system.layers[1];
      expect(flash.name, equals('ImpactFlash'));
      expect(flash.type, equals(GpuParticleType.spellOrb));
      expect(flash.emissiveIntensity, equals(5.0));

      // Emit burst and simulate
      system.emitBurst(layerIndex: 0, count: 20, origin: const Offset(50, 250));
      system.update(0.05);
      expect(system.activeParticleCount, equals(20));
    });

    test('bloodSplatter preset features directional viscous droplets and aerosol mist', () {
      final GpuParticleSystem system = GpuParticlePresets.bloodSplatter(
        direction: const Offset(1, 0),
        floorY: 400.0,
      );

      expect(system.layers.length, equals(2));

      final GpuParticleLayerConfig droplets = system.layers[0];
      expect(droplets.name, equals('BloodDroplets'));
      expect(droplets.type, equals(GpuParticleType.bloodDroplet));
      expect(droplets.blendMode, equals(GpuBlendMode.normal)); // alpha compositing for blood
      expect(droplets.gravity.dy, equals(900.0));
      expect(droplets.floorY, equals(400.0));

      final GpuParticleLayerConfig mist = system.layers[1];
      expect(mist.name, equals('BloodMist'));
      expect(mist.type, equals(GpuParticleType.bloodDroplet));
      expect(mist.blendMode, equals(GpuBlendMode.normal));
      expect(mist.drag, equals(0.8));

      system.emitAllLayersBurst(countPerLayer: 10, origin: const Offset(10, 10));
      system.update(0.1);
      expect(system.activeParticleCount, equals(20));
    });

    test('spellFireball preset defines core blaze and trailing swirling embers', () {
      final GpuParticleSystem system = GpuParticlePresets.spellFireball();

      expect(system.layers.length, equals(2));
      expect(system.layers[0].name, equals('CoreBlaze'));
      expect(system.layers[0].type, equals(GpuParticleType.spellOrb));
      expect(system.layers[0].emissionRate, equals(60.0));

      expect(system.layers[1].name, equals('SwirlingEmbers'));
      expect(system.layers[1].type, equals(GpuParticleType.sparkStreak));
      expect(system.layers[1].emissionRate, equals(120.0));
      expect(system.layers[1].turbulenceStrength, equals(120.0));

      system.update(0.1);
      expect(system.activeParticleCount, greaterThan(0));
    });

    test('magicRunes preset defines orbiting runic sigils and buoyant starlight sparkles', () {
      final GpuParticleSystem system = GpuParticlePresets.magicRunes();

      expect(system.layers.length, equals(2));
      expect(system.layers[0].type, equals(GpuParticleType.magicRune));
      expect(system.layers[1].type, equals(GpuParticleType.sparkStreak));
      expect(system.layers[1].gravity.dy, lessThan(0.0)); // buoyant upwards
    });

    test('emberFlames preset defines rising embers with curl turbulence and negative gravity', () {
      final GpuParticleSystem system = GpuParticlePresets.emberFlames();

      expect(system.layers.length, equals(1));
      expect(system.layers[0].type, equals(GpuParticleType.sparkStreak));
      expect(system.layers[0].gravity.dy, equals(-90.0));
      expect(system.layers[0].turbulenceStrength, equals(60.0));
    });
  });

  group('Group 7: GpuParticlePainter Headless Canvas Fallback Routines', () {
    test('Painter early-exits when particle system has zero active particles', () {
      final GpuParticleSystem system = GpuParticlePresets.spellArcaneBlast();
      final GpuParticlePainter painter = GpuParticlePainter(system: system);
      final RecordingCanvas canvas = RecordingCanvas();

      painter.paint(canvas, const Size(800, 600));
      expect(canvas.callLog, isEmpty);
    });

    test('Painter renders spellOrb with circle and emissive core highlight', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'SpellOrbLayer',
            type: GpuParticleType.spellOrb,
            maxParticles: 5,
            emissiveIntensity: 3.0, // > 1.5 triggers core highlight
            startSize: 20.0,
            endSize: 20.0,
          ),
        ],
      );

      final int p = system.buffer.allocate()!;
      system.buffer.setPosition(p, 100.0, 150.0);
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetStartSize] = 20.0;
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetEndSize] = 20.0;
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetLayerId] = 0.0;

      final GpuParticlePainter painter = GpuParticlePainter(system: system);
      final RecordingCanvas canvas = RecordingCanvas();

      painter.paint(canvas, const Size(800, 600));

      expect(canvas.circles.length, equals(2));
      // Main circle: radius = halfSize = 10.0
      expect(canvas.circles[0].center, equals(const Offset(100.0, 150.0)));
      expect(canvas.circles[0].radius, equals(10.0));
      // Emissive core circle: radius = halfSize * 0.35 = 3.5
      expect(canvas.circles[1].center, equals(const Offset(100.0, 150.0)));
      expect(canvas.circles[1].radius, closeTo(3.5, 1e-4));
      expect(canvas.circles[1].paint.blendMode, equals(BlendMode.plus));
    });

    test('Painter renders sparkStreak as velocity-aligned capsule or fallback circle', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'SparkLayer',
            type: GpuParticleType.sparkStreak,
            maxParticles: 5,
            startSize: 10.0,
            endSize: 10.0,
          ),
        ],
      );

      // Fast spark (speed > 10.0) -> drawLine
      final int pFast = system.buffer.allocate()!;
      system.buffer.setPosition(pFast, 200.0, 200.0);
      system.buffer.setVelocity(pFast, 100.0, 0.0);
      system.buffer.data[pFast * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetStartSize] = 10.0;
      system.buffer.data[pFast * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetEndSize] = 10.0;
      system.buffer.data[pFast * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetLayerId] = 0.0;

      // Slow spark (speed <= 10.0) -> drawCircle
      final int pSlow = system.buffer.allocate()!;
      system.buffer.setPosition(pSlow, 300.0, 300.0);
      system.buffer.setVelocity(pSlow, 0.0, 0.0);
      system.buffer.data[pSlow * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetStartSize] = 10.0;
      system.buffer.data[pSlow * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetEndSize] = 10.0;
      system.buffer.data[pSlow * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetLayerId] = 0.0;

      final GpuParticlePainter painter = GpuParticlePainter(system: system);
      final RecordingCanvas canvas = RecordingCanvas();

      painter.paint(canvas, const Size(800, 600));

      expect(canvas.lines.length, equals(1));
      expect(canvas.lines[0].p2, equals(const Offset(200.0, 200.0)));

      expect(canvas.circles.length, equals(1));
      expect(canvas.circles[0].center, equals(const Offset(300.0, 300.0)));
    });

    test('Painter renders bloodDroplet with teardrop streak or circle fallback', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'BloodLayer',
            type: GpuParticleType.bloodDroplet,
            maxParticles: 5,
            startSize: 16.0,
            endSize: 16.0,
            blendMode: GpuBlendMode.normal,
          ),
        ],
      );

      // Fast droplet (speed > 30.0) -> drawLine
      final int pFast = system.buffer.allocate()!;
      system.buffer.setPosition(pFast, 50.0, 50.0);
      system.buffer.setVelocity(pFast, 0.0, 80.0);
      system.buffer.data[pFast * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetStartSize] = 16.0;
      system.buffer.data[pFast * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetEndSize] = 16.0;
      system.buffer.data[pFast * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetLayerId] = 0.0;

      // Slow droplet (speed <= 30.0) -> drawCircle
      final int pSlow = system.buffer.allocate()!;
      system.buffer.setPosition(pSlow, 150.0, 150.0);
      system.buffer.setVelocity(pSlow, 10.0, 10.0);
      system.buffer.data[pSlow * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetStartSize] = 16.0;
      system.buffer.data[pSlow * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetEndSize] = 16.0;
      system.buffer.data[pSlow * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetLayerId] = 0.0;

      final GpuParticlePainter painter = GpuParticlePainter(system: system);
      final RecordingCanvas canvas = RecordingCanvas();

      painter.paint(canvas, const Size(800, 600));

      expect(canvas.lines.length, equals(1));
      expect(canvas.lines[0].paint.blendMode, equals(BlendMode.srcOver));

      expect(canvas.circles.length, equals(1));
      expect(canvas.circles[0].center, equals(const Offset(150.0, 150.0)));
    });

    test('Painter renders magicRune with geometric matrix transform, rings and cross', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'RuneLayer',
            type: GpuParticleType.magicRune,
            maxParticles: 5,
            startSize: 30.0,
            endSize: 30.0,
          ),
        ],
      );

      final int p = system.buffer.allocate()!;
      system.buffer.setPosition(p, 400.0, 300.0);
      system.buffer.setRotation(p, 0.785, 0.0);
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetStartSize] = 30.0;
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetEndSize] = 30.0;
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetLayerId] = 0.0;

      final GpuParticlePainter painter = GpuParticlePainter(system: system);
      final RecordingCanvas canvas = RecordingCanvas();

      painter.paint(canvas, const Size(800, 600));

      expect(canvas.saveCount, equals(1));
      expect(canvas.restoreCount, equals(1));
      expect(canvas.translations.single, equals(const Offset(400.0, 300.0)));
      expect(canvas.rotations.single, equals(0.785));
      // Concentric rings (2 circles)
      expect(canvas.circles.length, equals(2));
      // Cross lines (2 lines)
      expect(canvas.lines.length, equals(2));
    });

    test('Painter renders shockwave with expanding stroked ring', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'WaveLayer',
            type: GpuParticleType.shockwave,
            maxParticles: 5,
            startSize: 50.0,
            endSize: 50.0,
          ),
        ],
      );

      final int p = system.buffer.allocate()!;
      system.buffer.setPosition(p, 250.0, 250.0);
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetStartSize] = 50.0;
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetEndSize] = 50.0;
      system.buffer.data[p * GpuParticleBuffer.stride + GpuParticleBuffer.kOffsetLayerId] = 0.0;

      final GpuParticlePainter painter = GpuParticlePainter(system: system);
      final RecordingCanvas canvas = RecordingCanvas();

      painter.paint(canvas, const Size(800, 600));

      expect(canvas.circles.length, equals(1));
      expect(canvas.circles[0].center, equals(const Offset(250.0, 250.0)));
      expect(canvas.circles[0].radius, equals(25.0)); // halfSize
      expect(canvas.circles[0].paint.style, equals(PaintingStyle.stroke));
    });

    test('Painter executes safely via native ui.PictureRecorder and Canvas', () {
      final GpuParticleSystem system = GpuParticlePresets.spellArcaneBlast();
      system.emitAllLayersBurst(countPerLayer: 3, origin: const Offset(100, 100));

      final GpuParticlePainter painter = GpuParticlePainter(system: system);
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      painter.paint(canvas, const Size(800, 600));
      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('shouldRepaint always returns true for continuous particle animation', () {
      final GpuParticleSystem system = GpuParticlePresets.weaponImpact();
      final GpuParticlePainter p1 = GpuParticlePainter(system: system);
      final GpuParticlePainter p2 = GpuParticlePainter(system: system);
      expect(p1.shouldRepaint(p2), isTrue);
    });
  });

  group('Group 8: GpuParticleWidget Lifecycle & Continuous Ticker', () {
    testWidgets('GpuParticleWidget mounts and builds RepaintBoundary & CustomPaint', (WidgetTester tester) async {
      final GpuParticleSystem system = GpuParticlePresets.spellArcaneBlast();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GpuParticleWidget(
              system: system,
              autoTick: false,
            ),
          ),
        ),
      );

      expect(find.byType(GpuParticleWidget), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('GpuParticleWidget with autoTick: true advances simulation on frames', (WidgetTester tester) async {
      final GpuParticleSystem system = GpuParticlePresets.emberFlames();
      final double initialTime = system.globalTime;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GpuParticleWidget(
              system: system,
              autoTick: true,
            ),
          ),
        ),
      );

      // Advance clock by 100ms
      await tester.pump(const Duration(milliseconds: 100));
      expect(system.globalTime, greaterThan(initialTime));

      await tester.pump(const Duration(milliseconds: 100));
      expect(system.activeParticleCount, greaterThan(0));
    });

    testWidgets('GpuParticleWidget sub-steps long elapsed suspension frames gracefully', (WidgetTester tester) async {
      final GpuParticleSystem system = GpuParticlePresets.weaponImpact();
      system.emitBurst(layerIndex: 0, count: 10, origin: const Offset(50, 50));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GpuParticleWidget(
              system: system,
              autoTick: true,
            ),
          ),
        ),
      );

      // Simulate a long 3-second application suspension jump (capped at 2.0s internally)
      await tester.pump(const Duration(seconds: 3));
      expect(system.globalTime, closeTo(2.0, 0.1));
    });

    testWidgets('GpuParticleWidget unmount cleans and disposes ticker without throwing', (WidgetTester tester) async {
      final GpuParticleSystem system = GpuParticlePresets.spellFireball();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GpuParticleWidget(
              system: system,
              autoTick: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      // Replace with empty container to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(GpuParticleWidget), findsNothing);
    });
  });

  group('Group 9: Adversarial Boundary & Resource Stress Verification', () {
    test('Zero capacity GpuParticleBuffer operations behave safely', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(0);
      expect(buffer.capacity, equals(0));
      expect(buffer.activeCount, equals(0));
      expect(buffer.freeCount, equals(0));
      expect(buffer.allocate(), isNull);
      buffer.free(0);
      buffer.clear();
      expect(buffer.activeCount, equals(0));
    });

    test('Single-slot GpuParticleBuffer cycling stability', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(1);
      final int p0 = buffer.allocate()!;
      expect(p0, equals(0));
      expect(buffer.allocate(), isNull);

      buffer.free(p0);
      expect(buffer.activeCount, equals(0));
      expect(buffer.freeCount, equals(1));

      final int p1 = buffer.allocate()!;
      expect(p1, equals(0));
    });

    test('getNormalizedAge returns 1.0 when maxLife is zero or negative', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(2);
      final int p = buffer.allocate()!;
      buffer.setLife(p, 0.5, 0.0);
      expect(buffer.getNormalizedAge(p), equals(1.0));

      buffer.setLife(p, 0.5, -2.0);
      expect(buffer.getNormalizedAge(p), equals(1.0));
    });

    test('GpuParticleLayerConfig copyWith preserves defaults and overrides targets', () {
      const GpuParticleLayerConfig base = GpuParticleLayerConfig(
        name: 'Original',
        type: GpuParticleType.spellOrb,
        minSpeed: 40.0,
      );

      final GpuParticleLayerConfig modified = base.copyWith(
        name: 'Updated',
        minSpeed: 120.0,
        blendMode: GpuBlendMode.normal,
      );

      expect(modified.name, equals('Updated'));
      expect(modified.minSpeed, equals(120.0));
      expect(modified.blendMode, equals(GpuBlendMode.normal));
      expect(modified.type, equals(GpuParticleType.spellOrb)); // preserved
      expect(modified.spreadAngle, equals(math.pi * 2.0)); // preserved
    });

    test('High particle throughput stress recycling preserves index integrity', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(500);

      // Allocate all 500
      final List<int> allocated = <int>[];
      for (int i = 0; i < 500; ++i) {
        allocated.add(buffer.allocate()!);
      }
      expect(buffer.activeCount, equals(500));
      expect(buffer.freeCount, equals(0));

      // Free even indices (250 particles)
      for (int i = 0; i < 500; i += 2) {
        buffer.free(allocated[i]);
      }
      expect(buffer.activeCount, equals(250));
      expect(buffer.freeCount, equals(250));

      // Reallocate 250
      for (int i = 0; i < 250; ++i) {
        expect(buffer.allocate(), isNotNull);
      }
      expect(buffer.activeCount, equals(500));
      expect(buffer.freeCount, equals(0));

      // Free all
      buffer.clear();
      expect(buffer.activeCount, equals(0));
      expect(buffer.freeCount, equals(500));
    });

    test('Sub-millisecond dt simulation stability', () {
      final GpuParticleSystem system = GpuParticlePresets.spellArcaneBlast();
      system.emitBurst(layerIndex: 1, count: 10, origin: Offset.zero);

      // Advance in tiny 100-microsecond increments
      for (int i = 0; i < 50; ++i) {
        system.update(0.0001);
      }
      expect(system.globalTime, closeTo(0.005, 1e-5));
      expect(system.activeParticleCount, equals(10));
    });
  });
}
