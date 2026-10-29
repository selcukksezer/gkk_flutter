import 'dart:typed_data';
import 'dart:ui' show Color, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/lighting/dungeon_light_system.dart';

void main() {
  group('Vector3D Math Operations', () {
    test('Basic vector arithmetic, length, and normalization', () {
      const Vector3D a = Vector3D(1.0, 2.0, 3.0);
      const Vector3D b = Vector3D(4.0, 5.0, 6.0);

      final Vector3D sum = a + b;
      expect(sum.x, closeTo(5.0, 1e-6));
      expect(sum.y, closeTo(7.0, 1e-6));
      expect(sum.z, closeTo(9.0, 1e-6));

      final Vector3D diff = b - a;
      expect(diff.x, closeTo(3.0, 1e-6));
      expect(diff.y, closeTo(3.0, 1e-6));
      expect(diff.z, closeTo(3.0, 1e-6));

      const Vector3D v = Vector3D(3.0, 4.0, 0.0);
      expect(v.length, closeTo(5.0, 1e-6));
      final Vector3D norm = v.normalized();
      expect(norm.length, closeTo(1.0, 1e-6));
      expect(norm.x, closeTo(0.6, 1e-6));
      expect(norm.y, closeTo(0.8, 1e-6));

      expect(a.dot(b), closeTo(1.0 * 4.0 + 2.0 * 5.0 + 3.0 * 6.0, 1e-6));
    });

    test('Distance calculations', () {
      const Vector3D p1 = Vector3D(10.0, 20.0, 0.0);
      const Vector3D p2 = Vector3D(10.0, 20.0, 50.0);
      expect(p1.distanceTo(p2), closeTo(50.0, 1e-6));
      expect(p1.distanceSquaredTo(p2), closeTo(2500.0, 1e-6));
    });
  });

  group('Perlin Noise Generator', () {
    test('Noise values are strictly bounded within [-1.0, 1.0]', () {
      final PerlinNoiseGenerator noise = PerlinNoiseGenerator(seed: 42);

      for (double x = -10.0; x <= 10.0; x += 0.25) {
        final double n1 = noise.noise1D(x);
        expect(n1, greaterThanOrEqualTo(-1.0));
        expect(n1, lessThanOrEqualTo(1.0));

        for (double y = -5.0; y <= 5.0; y += 1.0) {
          final double n2 = noise.noise2D(x, y);
          expect(n2, greaterThanOrEqualTo(-1.0));
          expect(n2, lessThanOrEqualTo(1.0));
        }
      }
    });

    test('Noise generator is deterministic with identical seed', () {
      final PerlinNoiseGenerator nA = PerlinNoiseGenerator(seed: 9999);
      final PerlinNoiseGenerator nB = PerlinNoiseGenerator(seed: 9999);

      for (double x = 0.0; x < 5.0; x += 0.5) {
        expect(nA.noise1D(x), equals(nB.noise1D(x)));
        expect(nA.noise2D(x, x * 2.0), equals(nB.noise2D(x, x * 2.0)));
      }
    });

    test('fBm noise produces smooth multi-octave output', () {
      final PerlinNoiseGenerator noise = PerlinNoiseGenerator(seed: 777);
      for (double x = 0.0; x <= 10.0; x += 0.5) {
        final double f = noise.fbm1D(x, octaves: 3);
        expect(f.abs(), lessThanOrEqualTo(1.0));
      }
    });
  });

  group('Procedural Torch Flicker Algorithm', () {
    test('Torch intensity strictly obeys min and max bounds across time', () {
      final TorchFlickerEngine engine = TorchFlickerEngine();
      const double baseInt = 2.0;
      const double minInt = 1.2;
      const double maxInt = 2.8;

      for (double t = 0.0; t <= 10.0; t += 0.05) {
        final TorchFlickerSample sample = engine.evaluate(
          t: t,
          baseIntensity: baseInt,
          minIntensity: minInt,
          maxIntensity: maxInt,
          maxWobbleRadius: 5.0,
          baseColor: const Color(0xFFFF9800),
        );

        expect(sample.intensity, greaterThanOrEqualTo(minInt));
        expect(sample.intensity, lessThanOrEqualTo(maxInt));
      }
    });

    test('Torch position wobble strictly stays within maximum wobble radius', () {
      final TorchFlickerEngine engine = TorchFlickerEngine();
      const double maxWobbleRadius = 7.5;

      for (double t = 0.0; t <= 10.0; t += 0.05) {
        final TorchFlickerSample sample = engine.evaluate(
          t: t,
          baseIntensity: 2.0,
          minIntensity: 1.0,
          maxIntensity: 3.0,
          maxWobbleRadius: maxWobbleRadius,
          baseColor: const Color(0xFFFF9800),
          phase: 12.34,
        );

        final double wobbleDistance = sample.positionOffset.length;
        expect(wobbleDistance, lessThanOrEqualTo(maxWobbleRadius + 1e-6));
      }
    });

    test('Torch flicker produces dynamic variation and phase de-synchronization', () {
      final TorchFlickerEngine engine = TorchFlickerEngine();
      final List<double> samplesT1 = <double>[];
      final List<double> samplesT2 = <double>[];

      for (double t = 0.0; t < 2.0; t += 0.1) {
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
          phase: 45.67,
        );

        samplesT1.add(s1.intensity);
        samplesT2.add(s2.intensity);
      }

      // Assert values are not all constant
      final double firstVal = samplesT1.first;
      final bool hasVariation = samplesT1.any((double v) => (v - firstVal).abs() > 0.01);
      expect(hasVariation, isTrue);

      // Assert phase offset produces distinct values between the two torches
      bool hasDifference = false;
      for (int i = 0; i < samplesT1.length; ++i) {
        if ((samplesT1[i] - samplesT2[i]).abs() > 0.05) {
          hasDifference = true;
          break;
        }
      }
      expect(hasDifference, isTrue);
    });
  });

  group('Light Attenuation Equations', () {
    test('All falloff models reach exact 0.0 at dist >= radius', () {
      const double radius = 100.0;

      for (final FalloffType type in FalloffType.values) {
        expect(LightingAttenuationEngine.evaluateFalloff(radius, radius, type), equals(0.0));
        expect(LightingAttenuationEngine.evaluateFalloff(radius + 10.0, radius, type), equals(0.0));
        expect(LightingAttenuationEngine.evaluateFalloff(radius * 2.0, radius, type), equals(0.0));
      }
    });

    test('Falloff strictly decreases monotonically with distance', () {
      const double radius = 200.0;

      for (final FalloffType type in FalloffType.values) {
        double prevAtten = LightingAttenuationEngine.evaluateFalloff(0.0, radius, type);
        expect(prevAtten, greaterThan(0.0));

        for (double d = 10.0; d < radius; d += 20.0) {
          final double atten = LightingAttenuationEngine.evaluateFalloff(d, radius, type);
          expect(atten, lessThan(prevAtten), reason: 'Failed monotonic decay for $type at dist $d');
          prevAtten = atten;
        }
      }
    });

    test('Windowed inverse square decays faster than linear in mid-field', () {
      const double radius = 100.0;
      final double midDist = radius * 0.5;

      final double invSq = LightingAttenuationEngine.evaluateWindowedInverseSquare(midDist, radius);
      final double lin = LightingAttenuationEngine.evaluateLinearFalloff(midDist, radius);

      // Linear at midDist = 0.5 is exactly 0.5. Windowed inverse square is heavily attenuated (1/(d^2+1)).
      expect(invSq, lessThan(lin));
    });
  });

  group('Dynamic Shadow Penumbra & AO Modulation', () {
    test('Shadow attenuation drops to 0 outside light radius', () {
      const Vector3D lightPos = Vector3D(0.0, 0.0, 0.0);
      const Vector3D fragPos = Vector3D(150.0, 0.0, 0.0);
      const double lightRadius = 100.0;

      final double shadow = LightingAttenuationEngine.evaluateShadowAttenuation(
        fragPos: fragPos,
        lightPos: lightPos,
        lightRadius: lightRadius,
        shadowHardness: 0.8,
      );

      expect(shadow, equals(0.0));
    });

    test('Harder shadows produce lower transmission for occluded pixels', () {
      const Vector3D lightPos = Vector3D(0.0, 0.0, 0.0);
      const Vector3D fragPos = Vector3D(20.0, 0.0, 0.0);
      const double lightRadius = 100.0;

      final double softShadow = LightingAttenuationEngine.evaluateShadowAttenuation(
        fragPos: fragPos,
        lightPos: lightPos,
        lightRadius: lightRadius,
        shadowHardness: 0.3,
        shadowMask: 0.0, // Fully occluded
      );

      final double hardShadow = LightingAttenuationEngine.evaluateShadowAttenuation(
        fragPos: fragPos,
        lightPos: lightPos,
        lightRadius: lightRadius,
        shadowHardness: 0.9,
        shadowMask: 0.0, // Fully occluded
      );

      expect(hardShadow, lessThan(softShadow));
    });

    test('AO modulation strongly dampens ambient light in deep crevices', () {
      // Surface with zero AO (deep crevice)
      final double creviceAo = LightingAttenuationEngine.evaluateAoModulation(
        aoRaw: 0.0,
        aoModulation: 1.0,
      );
      expect(creviceAo, equals(0.0));

      // Surface with full visibility (AO = 1.0)
      final double openAo = LightingAttenuationEngine.evaluateAoModulation(
        aoRaw: 1.0,
        aoModulation: 1.0,
      );
      expect(openAo, equals(1.0));

      // Partial AO (e.g. 0.5) is non-linearly darkened by modulation power > 1
      final double midAo = LightingAttenuationEngine.evaluateAoModulation(
        aoRaw: 0.5,
        aoModulation: 1.0,
      );
      expect(midAo, lessThan(0.5));
    });

    test('Analytical illumination accumulates ambient, diffuse, and specular components', () {
      final DungeonLight torch = DungeonLight(
        id: 'test_torch',
        type: LightType.torch,
        position: const Vector3D(0.0, 0.0, 50.0),
        color: const Color(0xFFFFFFFF),
        intensity: 2.0,
        radius: 100.0,
        shadowHardness: 0.0,
      );

      // Surface directly below torch with normal facing up
      final Vector3D illum = LightingAttenuationEngine.computeAnalyticalIllumination(
        surfacePos: const Vector3D(0.0, 0.0, 0.0),
        surfaceNormal: const Vector3D(0.0, 0.0, 1.0),
        surfaceAo: 1.0,
        ambientColor: const Vector3D(0.1, 0.1, 0.1),
        ambientIntensity: 1.0,
        lights: <DungeonLight>[torch],
        cameraPos: const Vector3D(0.0, 0.0, 100.0),
      );

      // Must exceed ambient level alone
      expect(illum.x, greaterThan(0.1));
      expect(illum.y, greaterThan(0.1));
      expect(illum.z, greaterThan(0.1));
    });
  });

  group('Magical Spell Light Casting', () {
    test('Pulsing Rune breathes rhythmically in intensity and radius', () {
      final DungeonLightSystem system = DungeonLightSystem();
      final DungeonLight rune = system.castPulsingRune(
        id: 'rune_1',
        position: const Vector3D(50.0, 50.0, 0.0),
        baseIntensity: 2.0,
        radius: 100.0,
        pulseFreq: 1.0, // 1 Hz
      );

      // Sample at t = 0.0, 0.25s, 0.5s
      system.update(0.0, currentTime: 0.0);
      final double int0 = rune.currentIntensity;
      final double rad0 = rune.currentRadius;

      system.update(0.25, currentTime: 0.25);
      final double int1 = rune.currentIntensity;
      final double rad1 = rune.currentRadius;

      system.update(0.25, currentTime: 0.5);
      final double int2 = rune.currentIntensity;

      // Values should oscillate dynamically
      expect(int0, isNot(equals(int1)));
      expect(rad0, isNot(equals(rad1)));
      expect(int1, isNot(equals(int2)));
    });

    test('Fiery Explosion expands, flares, decays, and auto-expires', () {
      final DungeonLightSystem system = DungeonLightSystem();
      final DungeonLight explosion = system.castFieryExplosion(
        id: 'fireball_1',
        position: const Vector3D(100.0, 100.0, 0.0),
        peakIntensity: 5.0,
        maxRadius: 200.0,
        duration: 1.0,
      );

      expect(explosion.isExpired, isFalse);
      expect(system.lightCount, equals(1));

      // Progress through attack phase (0.15s)
      system.update(0.15, currentTime: 0.15);
      final double peakIntensity = explosion.currentIntensity;
      expect(peakIntensity, greaterThan(2.0));

      // Progress through decay phase (0.8s)
      system.update(0.65, currentTime: 0.8);
      final double decayedIntensity = explosion.currentIntensity;
      expect(decayedIntensity, lessThan(peakIntensity));
      expect(explosion.currentRadius, greaterThan(explosion.initialExplosionRadius));

      // Progress past duration -> expired and pruned
      system.update(0.3, currentTime: 1.1);
      expect(system.getLight('fireball_1'), isNull);
      expect(system.lightCount, equals(0));
    });

    test('Ethereal Soul wanders in 3D orbit trajectory', () {
      final DungeonLightSystem system = DungeonLightSystem();
      const Vector3D origin = Vector3D(200.0, 300.0, 50.0);
      final DungeonLight soul = system.castEtherealSoul(
        id: 'soul_1',
        origin: origin,
        orbitRadius: 30.0,
      );

      system.update(0.0, currentTime: 0.0);
      final Vector3D pos0 = soul.currentPosition;

      system.update(1.0, currentTime: 1.0);
      final Vector3D pos1 = soul.currentPosition;

      // Wandering trajectory should move position away from initial sample
      expect(pos0.distanceTo(pos1), greaterThan(5.0));

      // Drift should stay bounded within orbit radius
      expect(pos1.distanceTo(origin), lessThanOrEqualTo(30.0 + 1e-4));
    });
  });

  group('Multi-Light Buffer Packing & Priority Culling', () {
    test('buildUniformBuffer constructs exact 109-float layout matching shader', () {
      final DungeonLightSystem system = DungeonLightSystem(
        ambientColor: const Color(0xFF1A237E),
        ambientIntensity: 0.35,
        aoModulation: 0.9,
        shadowSoftness: 1.2,
      );

      system.addTorch(
        id: 'torch_1',
        position: const Vector3D(100.0, 200.0, 30.0),
        baseIntensity: 2.5,
        radius: 160.0,
      );

      final Float32List buffer = system.buildUniformBuffer(
        resolution: const Size(1920.0, 1080.0),
        cameraPos: const Vector3D(0.0, 0.0, 500.0),
        time: 5.5,
      );

      // Exact uniform array size: 13 global floats + 8 * 12 per-light floats = 109
      expect(buffer.length, equals(109));

      // Global Header
      expect(buffer[0], equals(1920.0));
      expect(buffer[1], equals(1080.0));
      expect(buffer[2], equals(5.5)); // time
      expect(buffer[6], closeTo(0.35, 1e-5)); // ambientIntensity
      expect(buffer[7], equals(1.0)); // active light count = 1
      expect(buffer[8], closeTo(0.9, 1e-5)); // aoModulation
      expect(buffer[9], closeTo(1.2, 1e-5)); // shadowSoftness
      expect(buffer[10], equals(0.0)); // cameraPos.x
      expect(buffer[11], equals(0.0)); // cameraPos.y
      expect(buffer[12], equals(500.0)); // cameraPos.z

      // First light: uLightPosRadius[0] at offset 13
      expect(buffer[13], equals(100.0)); // pos.x
      expect(buffer[14], equals(200.0)); // pos.y
      expect(buffer[15], equals(30.0)); // pos.z
      expect(buffer[16], equals(160.0)); // radius

      // First light: uLightColorIntensity[0] at offset 45
      expect(buffer[48], equals(2.5)); // intensity

      // First light: uLightParams[0] at offset 77
      expect(buffer[77], equals(LightType.torch.shaderValue)); // lightType = 0.0
      expect(buffer[78], equals(FalloffType.windowedInverseSquare.shaderValue)); // falloff = 0.0

      // Unused light slots 1..7 are zero-filled
      for (int i = 1; i < 8; ++i) {
        expect(buffer[13 + i * 4 + 3], equals(0.0)); // radius = 0
        expect(buffer[45 + i * 4 + 3], equals(0.0)); // intensity = 0
      }
    });

    test('Priority culling dynamically limits uniform packing to top maxLights', () {
      final DungeonLightSystem system = DungeonLightSystem(maxLights: 8);

      // Add 15 lights in a line
      for (int i = 0; i < 15; ++i) {
        system.addLight(DungeonLight(
          id: 'light_$i',
          type: LightType.point,
          position: Vector3D(i * 100.0, 0.0, 0.0),
          color: const Color(0xFFFFFFFF),
          intensity: 1.0,
          radius: 100.0,
        ));
      }

      expect(system.lightCount, equals(15));

      // Camera is positioned at (0, 0, 0)
      final List<DungeonLight> topLights = system.selectTopActiveLights(const Vector3D(0.0, 0.0, 0.0));

      // Must be capped at maxLights = 8
      expect(topLights.length, equals(8));

      // Lights closest to (0,0,0) have highest perceptual impact
      expect(topLights.first.id, equals('light_0'));
      expect(topLights[1].id, equals('light_1'));

      // Uniform buffer must reflect lightCount = 8
      final Float32List buffer = system.buildUniformBuffer(
        resolution: const Size(800.0, 600.0),
        cameraPos: const Vector3D(0.0, 0.0, 0.0),
      );
      expect(buffer[7], equals(8.0));
    });
  });
}
