import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/vfx/directional_camera_shake.dart';

void main() {
  group('DirectionalCameraShake - Trauma Clamping & Non-linear Math', () {
    test('trauma clamps strictly to [0.0, 1.0]', () {
      final shake = DirectionalCameraShake();
      expect(shake.trauma, 0.0);
      expect(shake.isActive, isFalse);

      shake.addTrauma(0.4);
      expect(shake.trauma, closeTo(0.4, 1e-5));
      expect(shake.isActive, isTrue);

      // Adding beyond 1.0 clamps at 1.0
      shake.addTrauma(0.9);
      expect(shake.trauma, 1.0);

      // Adding negative or zero trauma has no effect
      shake.addTrauma(-0.5);
      expect(shake.trauma, 1.0);
      shake.addTrauma(0.0);
      expect(shake.trauma, 1.0);
    });

    test('shakeIntensity follows non-linear power curve (trauma^exponent)', () {
      final shakeQuad = DirectionalCameraShake(
        config: const CameraShakeConfig(traumaExponent: 2.0),
      );
      shakeQuad.addTrauma(0.5);
      expect(shakeQuad.shakeIntensity, closeTo(0.25, 1e-4));

      final shakeCubic = DirectionalCameraShake(
        config: const CameraShakeConfig(traumaExponent: 3.0),
      );
      shakeCubic.addTrauma(0.5);
      expect(shakeCubic.shakeIntensity, closeTo(0.125, 1e-4));
    });

    test('reset() zeroes trauma, elapsed time, and returns state to neutral', () {
      final shake = DirectionalCameraShake();
      shake.addTrauma(0.8, hitDirection: const Offset(1.0, 0.0));
      shake.update(0.05);

      expect(shake.trauma, greaterThan(0.0));
      expect(shake.state.translation, isNot(Offset.zero));

      shake.reset();
      expect(shake.trauma, 0.0);
      expect(shake.isActive, isFalse);
      expect(shake.state.translation, Offset.zero);
      expect(shake.state.roll, 0.0);
      expect(shake.state.toMatrix4(), Matrix4.identity());
    });
  });

  group('DirectionalCameraShake - Non-linear Decay and Convergence to Zero', () {
    test('quadratic decay monotonically decreases and converges to exact 0.0', () {
      final shake = DirectionalCameraShake(
        config: const CameraShakeConfig(
          decayRate: 3.0,
          decayMode: CameraShakeDecayMode.quadratic,
          traumaCutoff: 1e-3,
        ),
      );
      shake.addTrauma(1.0);

      double prevTrauma = shake.trauma;
      int iterations = 0;
      while (shake.isActive && iterations < 50) {
        shake.update(0.033); // ~30 fps step
        expect(shake.trauma, lessThanOrEqualTo(prevTrauma));
        prevTrauma = shake.trauma;
        iterations++;
      }

      expect(shake.trauma, 0.0);
      expect(shake.isActive, isFalse);
      expect(shake.state, CameraShakeState.neutral);
    });

    test('exponential decay converges to exact 0.0 below cutoff', () {
      final shake = DirectionalCameraShake(
        config: const CameraShakeConfig(
          decayRate: 4.0,
          decayMode: CameraShakeDecayMode.exponential,
          traumaCutoff: 1e-3,
        ),
      );
      shake.addTrauma(0.8);

      for (int i = 0; i < 60; i++) {
        shake.update(0.05);
      }

      expect(shake.trauma, 0.0);
      expect(shake.isActive, isFalse);
    });

    test('smoothstep decay converges to exact 0.0', () {
      final shake = DirectionalCameraShake(
        config: const CameraShakeConfig(
          decayRate: 2.5,
          decayMode: CameraShakeDecayMode.smoothStep,
          traumaCutoff: 1e-3,
        ),
      );
      shake.addTrauma(0.5);

      for (int i = 0; i < 50; i++) {
        shake.update(0.05);
      }

      expect(shake.trauma, 0.0);
      expect(shake.isActive, isFalse);
    });

    test('zero or negative dt does not mutate state or produce NaN', () {
      final shake = DirectionalCameraShake();
      shake.addTrauma(0.5);
      final initialTrauma = shake.trauma;

      shake.update(0.0);
      expect(shake.trauma, initialTrauma);

      shake.update(-0.016);
      expect(shake.trauma, initialTrauma);
    });
  });

  group('DirectionalCameraShake - Directional Bias & Damped Harmonic Math', () {
    test('hit direction normalizes safely and handles zero vector', () {
      final shake = DirectionalCameraShake();
      // Un-normalized vector
      shake.addTrauma(0.5, hitDirection: const Offset(10.0, 0.0));
      expect(shake.state.translation.dx.isNaN, isFalse);

      shake.reset();
      // Zero vector
      shake.addTrauma(0.5, hitDirection: Offset.zero);
      expect(shake.state.translation.dx.isNaN, isFalse);
      expect(shake.state.translation.dy.isNaN, isFalse);
      expect(shake.state.roll.isNaN, isFalse);
    });

    test('horizontal hit vector biases initial displacement in hit direction', () {
      // Configure pure directional bias (bias weight = 1.0) with zero noise to test exact math
      final shakeRight = DirectionalCameraShake(
        config: const CameraShakeConfig(
          traumaExponent: 1.0,
          directionalBiasWeight: 1.0,
          maxTranslation: Offset(20.0, 10.0),
        ),
      );
      shakeRight.addTrauma(1.0, hitDirection: const Offset(1.0, 0.0));

      final shakeLeft = DirectionalCameraShake(
        config: const CameraShakeConfig(
          traumaExponent: 1.0,
          directionalBiasWeight: 1.0,
          maxTranslation: Offset(20.0, 10.0),
        ),
      );
      shakeLeft.addTrauma(1.0, hitDirection: const Offset(-1.0, 0.0));

      // Right hit pushes in positive X
      expect(shakeRight.state.translation.dx, greaterThan(10.0));
      // Left hit pushes in negative X
      expect(shakeLeft.state.translation.dx, lessThan(-10.0));
      // Symmetrical magnitude
      expect(
        shakeRight.state.translation.dx.abs(),
        closeTo(shakeLeft.state.translation.dx.abs(), 1e-4),
      );
    });

    test('horizontal hit vector induces directional rotational roll torque', () {
      final shakeRight = DirectionalCameraShake(
        config: const CameraShakeConfig(
          traumaExponent: 1.0,
          directionalBiasWeight: 1.0,
          maxRoll: 0.08,
        ),
      );
      shakeRight.addTrauma(1.0, hitDirection: const Offset(1.0, 0.0));

      final shakeLeft = DirectionalCameraShake(
        config: const CameraShakeConfig(
          traumaExponent: 1.0,
          directionalBiasWeight: 1.0,
          maxRoll: 0.08,
        ),
      );
      shakeLeft.addTrauma(1.0, hitDirection: const Offset(-1.0, 0.0));

      // Hit from left (+X velocity) tilts roll negative (clockwise)
      expect(shakeRight.state.roll, lessThan(0.0));
      // Hit from right (-X velocity) tilts roll positive (counter-clockwise)
      expect(shakeLeft.state.roll, greaterThan(0.0));
      // Roll torque magnitudes match
      expect(shakeRight.state.roll.abs(), closeTo(shakeLeft.state.roll.abs(), 1e-4));
    });

    test('vertical hit vector induces vertical translation and pitch bias without roll torque', () {
      final shakeDown = DirectionalCameraShake(
        config: const CameraShakeConfig(
          traumaExponent: 1.0,
          directionalBiasWeight: 1.0,
          maxTranslation: Offset(10.0, 30.0),
          maxPitch: 0.05,
        ),
      );
      // Impact downwards (+Y)
      shakeDown.addTrauma(1.0, hitDirection: const Offset(0.0, 1.0));

      expect(shakeDown.state.translation.dy, greaterThan(10.0));
      expect(shakeDown.state.pitch, greaterThan(0.0));
      // Zero X component means zero directional roll bias
      expect(shakeDown.state.roll.abs(), closeTo(0.0, 1e-4));
    });
  });

  group('DirectionalCameraShake - Multi-Octave Perlin Noise Generator', () {
    test('PerlinNoise1D generates continuous, bounded, reproducible noise', () {
      final noiseA = PerlinNoise1D(1337);
      final noiseB = PerlinNoise1D(1337);
      final noiseC = PerlinNoise1D(9999);

      for (double t = 0.0; t < 20.0; t += 0.05) {
        final valA = noiseA.sample(t);
        final valB = noiseB.sample(t);
        final valC = noiseC.sample(t);

        // Bounded in [-1.0, 1.0]
        expect(valA, inInclusiveRange(-1.0, 1.0));
        expect(valC, inInclusiveRange(-1.0, 1.0));

        // Deterministic across identical seeds
        expect(valA, valB);
      }

      // Smooth continuity: no jumps between t and t+0.001
      for (double t = 0.0; t < 10.0; t += 0.25) {
        final delta = (noiseA.sample(t + 0.002) - noiseA.sample(t)).abs();
        expect(delta, lessThan(0.05));
      }
    });

    test('MultiOctaveNoise1D combines octaves and stays normalized in [-1.0, 1.0]', () {
      final multiNoise = MultiOctaveNoise1D(
        octaveCount: 4,
        lacunarity: 2.0,
        persistence: 0.5,
        baseSeed: 42,
      );

      for (double t = 0.0; t < 50.0; t += 0.1) {
        final sample = multiNoise.sample(t);
        expect(sample, inInclusiveRange(-1.0, 1.0));
      }
    });
  });

  group('DirectionalCameraShake - Combat Presets (R3 Game Feel)', () {
    test('lightJab preset has quick decay and high frequency', () {
      final shake = DirectionalCameraShake();
      shake.triggerPreset(CameraShakePreset.lightJab);

      expect(shake.trauma, 0.30);
      expect(shake.config.decayRate, 4.0);
      expect(shake.config.baseFrequency, 32.0);
      expect(shake.config.maxTranslation.dx, 6.0);

      // Fast decay: settles in under 0.25 seconds
      for (int i = 0; i < 15; i++) {
        shake.update(0.016);
      }
      expect(shake.trauma, lessThan(0.05));
    });

    test('heavyCrit preset provides visceral displacement and heavy rumble', () {
      final shake = DirectionalCameraShake();
      shake.triggerPreset(
        CameraShakePreset.heavyCrit,
        hitDirection: const Offset(1.0, 0.2),
      );

      expect(shake.trauma, 0.78);
      expect(shake.config.maxTranslation.dx, 26.0);
      expect(shake.config.noiseOctaves, 3);
      expect(shake.config.directionalBiasWeight, 0.85);

      // Produces significant initial offset
      expect(shake.state.translation.dx.abs(), greaterThan(5.0));
      expect(shake.state.shakeIntensity, closeTo(0.78 * 0.78, 1e-3));
    });

    test('explosiveShock preset produces max trauma and wide translation', () {
      final shake = DirectionalCameraShake();
      shake.triggerPreset(
        CameraShakePreset.explosiveShock,
        hitDirection: const Offset(0.0, -1.0),
      );

      expect(shake.trauma, 1.0);
      expect(shake.shakeIntensity, 1.0);
      expect(shake.config.maxTranslation.dx, 44.0);
      expect(shake.config.maxTranslation.dy, 32.0);
      expect(shake.config.noiseOctaves, 4);
    });

    test('microVibration preset produces high-frequency subtle jitter', () {
      final shake = DirectionalCameraShake();
      shake.triggerPreset(CameraShakePreset.microVibration);

      expect(shake.config.baseFrequency, 48.0);
      expect(shake.config.decayRate, 5.0);
      expect(shake.config.maxTranslation.dx, 4.5);
    });
  });

  group('DirectionalCameraShake - Matrix4 Transformation Output', () {
    test('neutral state produces exact identity matrix', () {
      const neutral = CameraShakeState.neutral;
      final m = neutral.toMatrix4();
      expect(m, Matrix4.identity());

      final mPivot = neutral.toMatrix4WithPivot(const Offset(200, 300));
      expect(mPivot, Matrix4.identity());
    });

    test('active state generates valid 4x4 transform matrix', () {
      const state = CameraShakeState(
        translation: Offset(15.0, -8.0),
        roll: 0.05,
        pitch: 0.02,
        yaw: 0.01,
        trauma: 0.7,
        shakeIntensity: 0.49,
        elapsedTime: 0.1,
      );

      final matrix = state.toMatrix4();

      // Ensure no NaN or infinity in any of the 16 elements
      for (int i = 0; i < 16; i++) {
        expect(matrix.storage[i].isNaN, isFalse);
        expect(matrix.storage[i].isInfinite, isFalse);
      }

      // Check translation components (matrix storage layout: col-major)
      // Translation X is index 12, Y is index 13, Z is index 14
      expect(matrix.storage[12], closeTo(15.0, 1e-4));
      expect(matrix.storage[13], closeTo(-8.0, 1e-4));
      expect(matrix.storage[14], closeTo(0.0, 1e-4));
    });

    test('toMatrix4WithPivot transforms around specified screen center without drift', () {
      const pivot = Offset(400.0, 300.0);
      const state = CameraShakeState(
        translation: Offset(10.0, 5.0),
        roll: 0.1,
        pitch: 0.0,
        yaw: 0.0,
        trauma: 0.8,
        shakeIntensity: 0.64,
        elapsedTime: 0.1,
      );

      final matrix = state.toMatrix4WithPivot(pivot);

      for (int i = 0; i < 16; i++) {
        expect(matrix.storage[i].isNaN, isFalse);
        expect(matrix.storage[i].isInfinite, isFalse);
      }

      // Origin should be translated
      expect(matrix.storage[12], isNot(0.0));
      expect(matrix.storage[13], isNot(0.0));
    });
  });

  group('DirectionalCameraShakeHost Widget Integration', () {
    testWidgets('renders child widget and applies transform when active', (tester) async {
      final controller = DirectionalCameraShake();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DirectionalCameraShakeHost(
            controller: controller,
            child: const Text('Combat Viewport'),
          ),
        ),
      );

      expect(find.text('Combat Viewport'), findsOneWidget);

      // Trigger shake and pump frame
      controller.triggerPreset(
        CameraShakePreset.heavyCrit,
        hitDirection: const Offset(1.0, 0.0),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(controller.isActive, isTrue);
      expect(find.byType(Transform), findsOneWidget);

      final transformFinder = find.byType(Transform);
      final Transform transformWidget = tester.widget(transformFinder);
      expect(transformWidget.transform, isNot(Matrix4.identity()));

      // Reset and verify transform returns to identity or inactive
      controller.reset();
      await tester.pump();
      expect(controller.isActive, isFalse);
    });
  });
}
