import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/vfx/gpu_particle_system.dart';

void main() {
  group('GpuParticleBuffer Contiguous Memory & Allocation Tests', () {
    test('Buffer initializes with exact stride and zero active particles', () {
      const int capacity = 100;
      final GpuParticleBuffer buffer = GpuParticleBuffer(capacity);

      expect(GpuParticleBuffer.stride, equals(20));
      expect(buffer.capacity, equals(capacity));
      expect(buffer.data.length, equals(capacity * 20));
      expect(buffer.activeCount, equals(0));
      expect(buffer.freeCount, equals(capacity));
      expect(buffer.activeIndices.length, equals(capacity));
    });

    test('O(1) allocate and free cycles properly update active and free pools', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(5);

      final int? p0 = buffer.allocate();
      final int? p1 = buffer.allocate();
      final int? p2 = buffer.allocate();

      expect(p0, isNotNull);
      expect(p1, isNotNull);
      expect(p2, isNotNull);
      expect(buffer.activeCount, equals(3));
      expect(buffer.freeCount, equals(2));

      // Free middle particle p1
      buffer.free(p1!);
      expect(buffer.activeCount, equals(2));
      expect(buffer.freeCount, equals(3));

      // Allocate again should reuse recycled slot
      final int? pNew = buffer.allocate();
      expect(pNew, isNotNull);
      expect(pNew, equals(p1));
      expect(buffer.activeCount, equals(3));
    });

    test('Buffer rejects allocations when full capacity is reached', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(3);
      expect(buffer.allocate(), isNotNull);
      expect(buffer.allocate(), isNotNull);
      expect(buffer.allocate(), isNotNull);

      // 4th allocation must fail gracefully
      expect(buffer.allocate(), isNull);
      expect(buffer.activeCount, equals(3));
      expect(buffer.freeCount, equals(0));
    });

    test('Direct attribute accessors write and read contiguous memory correctly', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(10);
      final int p = buffer.allocate()!;

      buffer.setPosition(p, 123.5, 456.75);
      expect(buffer.getX(p), closeTo(123.5, 0.001));
      expect(buffer.getY(p), closeTo(456.75, 0.001));

      buffer.setVelocity(p, -50.0, 75.25);
      expect(buffer.getVx(p), closeTo(-50.0, 0.001));
      expect(buffer.getVy(p), closeTo(75.25, 0.001));

      buffer.setLife(p, 0.5, 2.0);
      expect(buffer.getLife(p), closeTo(0.5, 0.001));
      expect(buffer.getMaxLife(p), closeTo(2.0, 0.001));
      expect(buffer.getNormalizedAge(p), closeTo(0.25, 0.001));

      buffer.setRotation(p, 1.57, 3.14);
      expect(buffer.getRotation(p), closeTo(1.57, 0.001));
      expect(buffer.getRotSpeed(p), closeTo(3.14, 0.001));
    });

    test('Clear resets all indices and restores entire free-list capacity', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(50);
      for (int i = 0; i < 30; ++i) {
        buffer.allocate();
      }
      expect(buffer.activeCount, equals(30));

      buffer.clear();
      expect(buffer.activeCount, equals(0));
      expect(buffer.freeCount, equals(50));
    });
  });

  group('Particle Life Cycle & Interpolation Math Tests', () {
    test('Normalized age clamps strictly between 0.0 and 1.0', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(5);
      final int p = buffer.allocate()!;

      buffer.setLife(p, 0.0, 1.0);
      expect(buffer.getNormalizedAge(p), equals(0.0));

      buffer.setLife(p, 0.75, 1.5);
      expect(buffer.getNormalizedAge(p), equals(0.5));

      buffer.setLife(p, 3.0, 2.0);
      expect(buffer.getNormalizedAge(p), equals(1.0)); // clamped
    });

    test('Size interpolates linearly from startSize to endSize over lifetime', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(5);
      final int p = buffer.allocate()!;
      final int base = p * GpuParticleBuffer.stride;

      buffer.data[base + GpuParticleBuffer.kOffsetStartSize] = 20.0;
      buffer.data[base + GpuParticleBuffer.kOffsetEndSize] = 4.0;

      buffer.setLife(p, 0.0, 2.0);
      expect(buffer.getCurrentSize(p), closeTo(20.0, 0.001));

      buffer.setLife(p, 1.0, 2.0); // 50%
      expect(buffer.getCurrentSize(p), closeTo(12.0, 0.001));

      buffer.setLife(p, 2.0, 2.0); // 100%
      expect(buffer.getCurrentSize(p), closeTo(4.0, 0.001));
    });

    test('Color and alpha gradient interpolates accurately over lifetime', () {
      final GpuParticleBuffer buffer = GpuParticleBuffer(5);
      final int p = buffer.allocate()!;
      final int base = p * GpuParticleBuffer.stride;

      // Start: Opaque Red (1.0, 0.0, 0.0, 1.0)
      buffer.data[base + GpuParticleBuffer.kOffsetColorR0] = 1.0;
      buffer.data[base + GpuParticleBuffer.kOffsetColorG0] = 0.0;
      buffer.data[base + GpuParticleBuffer.kOffsetColorB0] = 0.0;
      buffer.data[base + GpuParticleBuffer.kOffsetColorA0] = 1.0;

      // End: Transparent Blue (0.0, 0.0, 1.0, 0.0)
      buffer.data[base + GpuParticleBuffer.kOffsetColorR1] = 0.0;
      buffer.data[base + GpuParticleBuffer.kOffsetColorG1] = 0.0;
      buffer.data[base + GpuParticleBuffer.kOffsetColorB1] = 1.0;
      buffer.data[base + GpuParticleBuffer.kOffsetColorA1] = 0.0;

      buffer.setLife(p, 0.0, 1.0);
      Color c = buffer.getCurrentColor(p);
      expect(c.r, closeTo(1.0, 0.02));
      expect(c.b, closeTo(0.0, 0.02));
      expect(c.a, closeTo(1.0, 0.02));

      // At 50%
      buffer.setLife(p, 0.5, 1.0);
      c = buffer.getCurrentColor(p);
      expect(c.r, closeTo(0.5, 0.02));
      expect(c.b, closeTo(0.5, 0.02));
      expect(c.a, closeTo(0.5, 0.02));

      // At 100%
      buffer.setLife(p, 1.0, 1.0);
      c = buffer.getCurrentColor(p);
      expect(c.r, closeTo(0.0, 0.02));
      expect(c.b, closeTo(1.0, 0.02));
      expect(c.a, closeTo(0.0, 0.02));
    });
  });

  group('Procedural Simplex Noise & Divergence-Free Curl Field Tests', () {
    test('Simplex2D produces bounded deterministic values in range [-1.0, 1.0]', () {
      for (double x = -10.0; x <= 10.0; x += 1.5) {
        for (double y = -10.0; y <= 10.0; y += 1.5) {
          final double val = GpuNoise.simplex2D(x, y);
          expect(val, greaterThanOrEqualTo(-1.05));
          expect(val, lessThanOrEqualTo(1.05));
          expect(val.isNaN, isFalse);
          expect(val.isInfinite, isFalse);
        }
      }
    });

    test('CurlNoise2D computes valid 2D turbulence vector without NaN or infinity', () {
      for (double x = 0.0; x < 5.0; x += 0.8) {
        for (double y = 0.0; y < 5.0; y += 0.8) {
          final (double cx, double cy) = GpuNoise.curlNoise2D(x, y);
          expect(cx.isNaN, isFalse);
          expect(cy.isNaN, isFalse);
          expect(cx.isInfinite, isFalse);
          expect(cy.isInfinite, isFalse);
        }
      }
    });
  });

  group('GpuParticleSystem Simulation & Physics Tests', () {
    test('Particles expire and are automatically recycled when lifetime completes', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'TestExpire',
            type: GpuParticleType.sparkStreak,
            minLifetime: 0.5,
            maxLifetime: 0.5,
            minSpeed: 10.0,
            maxSpeed: 10.0,
          ),
        ],
        randomSeed: 42,
      );

      system.emitBurst(layerIndex: 0, count: 10, origin: Offset.zero);
      expect(system.activeParticleCount, equals(10));

      // Advance by 0.25s: all particles still alive
      system.update(0.25);
      expect(system.activeParticleCount, equals(10));

      // Advance past 0.5s: all particles must expire
      system.update(0.30);
      expect(system.activeParticleCount, equals(0));
    });

    test('Gravity accelerates particles along specified vector', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'TestGravity',
            type: GpuParticleType.bloodDroplet,
            minLifetime: 2.0,
            maxLifetime: 2.0,
            minSpeed: 0.0,
            maxSpeed: 0.0,
            gravity: Offset(0, 1000.0), // 1000 px/s^2 downward
          ),
        ],
        randomSeed: 123,
      );

      system.emitBurst(layerIndex: 0, count: 1, origin: Offset.zero);
      final int p = system.buffer.activeIndices[0];

      // After 0.1s, vy should be ~100 px/s and y should be ~5 px (0.5 * 1000 * 0.01)
      system.update(0.1);
      expect(system.buffer.getVy(p), closeTo(100.0, 1.0));
      expect(system.buffer.getY(p), closeTo(10.0, 1.5));
    });

    test('Drag dampens particle velocity monotonically over time', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'TestDrag',
            type: GpuParticleType.sparkStreak,
            minLifetime: 2.0,
            maxLifetime: 2.0,
            minSpeed: 200.0,
            maxSpeed: 200.0,
            emissionAngle: 0.0, // horizontal right
            spreadAngle: 0.0,
            drag: 2.0, // heavy drag
          ),
        ],
        randomSeed: 777,
      );

      system.emitBurst(layerIndex: 0, count: 1, origin: Offset.zero);
      final int p = system.buffer.activeIndices[0];
      final double initialVx = system.buffer.getVx(p);
      expect(initialVx, closeTo(200.0, 0.1));

      system.update(0.1);
      final double vx1 = system.buffer.getVx(p);
      expect(vx1, lessThan(initialVx));

      system.update(0.1);
      final double vx2 = system.buffer.getVx(p);
      expect(vx2, lessThan(vx1));
    });

    test('Floor collision reflects velocity with bounce restitution and ground friction', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'TestBounce',
            type: GpuParticleType.sparkStreak,
            minLifetime: 3.0,
            maxLifetime: 3.0,
            minSpeed: 100.0,
            maxSpeed: 100.0,
            emissionAngle: math.pi * 0.5, // straight down
            spreadAngle: 0.0,
            gravity: Offset(0, 500.0),
            bounce: 0.6,
            floorY: 100.0,
          ),
        ],
        randomSeed: 999,
      );

      system.emitBurst(layerIndex: 0, count: 1, origin: const Offset(50, 90));
      final int p = system.buffer.activeIndices[0];

      // Step towards floor: y starts at 90, hits 100
      system.update(0.15);
      expect(system.buffer.getY(p), lessThanOrEqualTo(100.0));
      // vy must have bounced and become negative (moving upward)
      expect(system.buffer.getVy(p), lessThan(0.0));
    });

    test('Continuous emission spawns particles proportional to emissionRate', () {
      final GpuParticleSystem system = GpuParticleSystem(
        layers: <GpuParticleLayerConfig>[
          const GpuParticleLayerConfig(
            name: 'TestContinuous',
            type: GpuParticleType.spellOrb,
            emissionRate: 50.0, // 50 particles/sec
            minLifetime: 1.0,
            maxLifetime: 1.0,
            minSpeed: 20.0,
            maxSpeed: 40.0,
          ),
        ],
        randomSeed: 101,
      );

      expect(system.activeParticleCount, equals(0));

      // After 0.1s at 50/sec, should emit ~5 particles
      system.update(0.1);
      expect(system.activeParticleCount, inInclusiveRange(4, 6));

      // After another 0.2s (total 0.3s), should have ~15 particles
      system.update(0.2);
      expect(system.activeParticleCount, inInclusiveRange(13, 17));
    });
  });

  group('Production AAA VFX Presets Verification', () {
    test('spellFireball preset configures blazing core and trailing embers', () {
      final GpuParticleSystem fireball = GpuParticlePresets.spellFireball();
      expect(fireball.layers.length, equals(2));
      expect(fireball.layers[0].type, equals(GpuParticleType.spellOrb));
      expect(fireball.layers[0].blendMode, equals(GpuBlendMode.additive));
      expect(fireball.layers[0].emissiveIntensity, greaterThanOrEqualTo(3.0));
      expect(fireball.layers[1].type, equals(GpuParticleType.sparkStreak));
      expect(fireball.layers[1].turbulenceStrength, greaterThan(0.0));
    });

    test('spellArcaneBlast preset configures shockwave, shards, and runes', () {
      final GpuParticleSystem blast = GpuParticlePresets.spellArcaneBlast();
      expect(blast.layers.length, equals(3));
      expect(blast.layers[0].type, equals(GpuParticleType.shockwave));
      expect(blast.layers[1].type, equals(GpuParticleType.sparkStreak));
      expect(blast.layers[2].type, equals(GpuParticleType.magicRune));
    });

    test('weaponImpact preset configures bouncing sparks with gravity and impact flash', () {
      final GpuParticleSystem impact = GpuParticlePresets.weaponImpact(floorY: 200.0);
      expect(impact.layers.length, equals(2));
      final GpuParticleLayerConfig sparks = impact.layers[0];
      expect(sparks.type, equals(GpuParticleType.sparkStreak));
      expect(sparks.gravity.dy, greaterThan(0.0));
      expect(sparks.bounce, greaterThan(0.5));
      expect(sparks.floorY, equals(200.0));
      expect(impact.layers[1].type, equals(GpuParticleType.spellOrb));
    });

    test('bloodSplatter preset configures viscous droplets and aerosol mist', () {
      final GpuParticleSystem blood = GpuParticlePresets.bloodSplatter();
      expect(blood.layers.length, equals(2));
      expect(blood.layers[0].type, equals(GpuParticleType.bloodDroplet));
      expect(blood.layers[0].blendMode, equals(GpuBlendMode.normal));
      expect(blood.layers[0].gravity.dy, greaterThan(0.0));
      expect(blood.layers[1].type, equals(GpuParticleType.bloodDroplet));
    });

    test('magicRunes preset configures orbiting rune sigils and starlight sparkles', () {
      final GpuParticleSystem runes = GpuParticlePresets.magicRunes();
      expect(runes.layers.length, equals(2));
      expect(runes.layers[0].type, equals(GpuParticleType.magicRune));
      expect(runes.layers[0].minRotationSpeed, greaterThan(0.0));
      expect(runes.layers[1].gravity.dy, lessThan(0.0)); // buoyant upwards
    });

    test('emberFlames preset configures buoyant rising embers with turbulence', () {
      final GpuParticleSystem embers = GpuParticlePresets.emberFlames();
      expect(embers.layers.length, equals(1));
      expect(embers.layers[0].gravity.dy, lessThan(0.0));
      expect(embers.layers[0].turbulenceStrength, greaterThan(0.0));
    });
  });

  group('Shader Uniform Packing & GLSL Layout Tests', () {
    test('GpuParticleShaderUniforms packs exact 24 floats in strict GLSL declaration order', () {
      const Size res = Size(1920, 1080);
      const Rect bounds = Rect.fromLTWH(100, 200, 64, 64);
      const Color c0 = Color(0xFFFF8800);
      const Color c1 = Color(0x00FF0044);
      const Offset vel = Offset(150, -80);

      final Float32List uniforms = GpuParticleShaderUniforms.pack(
        resolution: res,
        time: 2.5,
        bounds: bounds,
        type: GpuParticleType.magicRune,
        lifetimeProgress: 0.45,
        startColor: c0,
        endColor: c1,
        velocity: vel,
        turbulence: 25.0,
        emissiveIntensity: 3.5,
        size: 48.0,
        rotation: 1.57,
        layerParam: 2.0,
      );

      expect(uniforms.length, equals(24));

      // 0..1: uResolution
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));

      // 2: uTime
      expect(uniforms[2], equals(2.5));

      // 3..6: uBounds
      expect(uniforms[3], equals(100.0));
      expect(uniforms[4], equals(200.0));
      expect(uniforms[5], equals(64.0));
      expect(uniforms[6], equals(64.0));

      // 7: uParticleType (magicRune = 3)
      expect(uniforms[7], equals(3.0));

      // 8: uLifetimeProgress
      expect(uniforms[8], closeTo(0.45, 0.001));

      // 9..12: uColorStart
      expect(uniforms[9], closeTo(c0.r, 0.001));
      expect(uniforms[10], closeTo(c0.g, 0.001));
      expect(uniforms[11], closeTo(c0.b, 0.001));
      expect(uniforms[12], closeTo(c0.a, 0.001));

      // 13..16: uColorEnd
      expect(uniforms[13], closeTo(c1.r, 0.001));
      expect(uniforms[14], closeTo(c1.g, 0.001));
      expect(uniforms[15], closeTo(c1.b, 0.001));
      expect(uniforms[16], closeTo(c1.a, 0.001));

      // 17..18: uVelocity
      expect(uniforms[17], equals(150.0));
      expect(uniforms[18], equals(-80.0));

      // 19: uTurbulence
      expect(uniforms[19], equals(25.0));

      // 20: uEmissiveIntensity
      expect(uniforms[20], equals(3.5));

      // 21: uSize
      expect(uniforms[21], equals(48.0));

      // 22: uRotation
      expect(uniforms[22], closeTo(1.57, 0.001));

      // 23: uLayerParam
      expect(uniforms[23], equals(2.0));
    });
  });

  group('Painter & Widget Zero-Allocation Integration Tests', () {
    testWidgets('GpuParticlePainter draws all particle types without exception', (WidgetTester tester) async {
      final GpuParticleSystem system = GpuParticlePresets.spellArcaneBlast();
      system.emitAllLayersBurst(countPerLayer: 5, origin: const Offset(100, 100));

      final GpuParticlePainter painter = GpuParticlePainter(system: system);
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      expect(() => painter.paint(canvas, const Size(800, 600)), returnsNormally);
      recorder.endRecording().dispose();
    });

    testWidgets('GpuParticleWidget mounts, renders, and ticks with zero per-particle widgets', (WidgetTester tester) async {
      final GpuParticleSystem system = GpuParticlePresets.weaponImpact();
      system.emitBurst(layerIndex: 0, count: 20, origin: const Offset(200, 200));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: GpuParticleWidget(
            system: system,
            autoTick: true,
          ),
        ),
      );

      // Verify the widget tree contains ONLY a single CustomPaint and NO per-particle widgets!
      expect(find.byType(CustomPaint), findsOneWidget);
      expect(system.activeParticleCount, equals(20));

      // Pump frames
      await tester.pump(const Duration(milliseconds: 50));
      expect(system.activeParticleCount, equals(20));

      // Fast forward past lifetime
      await tester.pump(const Duration(seconds: 2));
      expect(system.activeParticleCount, equals(0));
    });
  });
}
