import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/vfx/rim_hit_flash_effect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Rim Hit Flash — Exponential Decay Envelope Tests', () {
    test('Instantaneous onset at t = 0ms evaluates to full peak intensity 1.0', () {
      final double peak = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 0.0,
        totalDurationMs: 100.0,
      );
      expect(peak, equals(1.0));

      final double negativeElapsed = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: -5.0,
        totalDurationMs: 100.0,
      );
      expect(negativeElapsed, equals(1.0));
    });

    test('Exponential decay strictly decreases monotonically over time', () {
      const double duration = 100.0;
      double previousIntensity = 1.0;

      for (double t = 10.0; t <= duration; t += 10.0) {
        final double intensity = RimHitFlashEnvelope.evaluateDecay(
          elapsedMs: t,
          totalDurationMs: duration,
        );
        expect(intensity, lessThan(previousIntensity));
        previousIntensity = intensity;
      }
    });

    test('Mid-duration (50%) intensity matches analytical e^(-lambda/2)', () {
      const double duration = 100.0;
      const double lambda = 4.60517; // e^(-4.60517) ~= 0.01

      final double midIntensity = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 50.0,
        totalDurationMs: duration,
        lambda: lambda,
      );

      // e^(-2.302585) = 0.1000
      expect(midIntensity, closeTo(0.100, 0.005));
    });

    test('End-of-duration decay reaches <= 1% and snaps to 0.0 at/after duration', () {
      const double duration = 100.0;

      final double nearEnd = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 99.0,
        totalDurationMs: duration,
      );
      expect(nearEnd, lessThanOrEqualTo(0.015));

      final double atEnd = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 100.0,
        totalDurationMs: duration,
      );
      expect(atEnd, equals(0.0));

      final double pastEnd = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 120.0,
        totalDurationMs: duration,
      );
      expect(pastEnd, equals(0.0));
    });

    test('Hit-stop freeze window holds maximum peak before initiating decay', () {
      const double totalDuration = 100.0;
      const double hitStop = 40.0; // 40ms hit-stop freeze

      // During hit-stop, intensity must remain at 1.0
      expect(
        RimHitFlashEnvelope.evaluateDecay(
          elapsedMs: 0.0,
          totalDurationMs: totalDuration,
          hitStopMs: hitStop,
        ),
        equals(1.0),
      );
      expect(
        RimHitFlashEnvelope.evaluateDecay(
          elapsedMs: 20.0,
          totalDurationMs: totalDuration,
          hitStopMs: hitStop,
        ),
        equals(1.0),
      );
      expect(
        RimHitFlashEnvelope.evaluateDecay(
          elapsedMs: 40.0,
          totalDurationMs: totalDuration,
          hitStopMs: hitStop,
        ),
        equals(1.0),
      );

      // After hit-stop, decay initiates on remaining 60ms window
      final double afterHitStop = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 70.0, // halfway through remaining (70 - 40 = 30ms of 60ms)
        totalDurationMs: totalDuration,
        hitStopMs: hitStop,
      );
      expect(afterHitStop, closeTo(0.100, 0.01));
    });

    test('Custom duration boundaries (80ms to 120ms total duration)', () {
      // 80ms fast strike
      expect(
        RimHitFlashEnvelope.evaluateDecay(elapsedMs: 40.0, totalDurationMs: 80.0),
        closeTo(0.100, 0.01),
      );
      expect(
        RimHitFlashEnvelope.evaluateDecay(elapsedMs: 80.0, totalDurationMs: 80.0),
        equals(0.0),
      );

      // 120ms heavy blow
      expect(
        RimHitFlashEnvelope.evaluateDecay(elapsedMs: 60.0, totalDurationMs: 120.0),
        closeTo(0.100, 0.01),
      );
      expect(
        RimHitFlashEnvelope.evaluateDecay(elapsedMs: 120.0, totalDurationMs: 120.0),
        equals(0.0),
      );
    });
  });

  group('Rim Hit Flash — View-Angle Fresnel Dot Normal Tests', () {
    test('Direct surface view (N dot V = 1.0) produces 0.0 Fresnel rim', () {
      final double rim = RimHitFlashEnvelope.computeFresnel(
        nDotV: 1.0,
        rimPower: 3.5,
        rimIntensity: 2.0,
      );
      expect(rim, closeTo(0.0, 0.0001));
    });

    test('Grazing edge view (N dot V = 0.0) produces maximum rim highlight', () {
      const double rimIntensity = 2.5;
      final double rim = RimHitFlashEnvelope.computeFresnel(
        nDotV: 0.0,
        rimPower: 3.5,
        rimIntensity: rimIntensity,
      );
      // (1.0 - 0.0)^3.5 * 2.5 = 2.5
      expect(rim, closeTo(rimIntensity, 0.0001));
    });

    test('Fresnel rim increases monotonically as view angle approaches grazing silhouette', () {
      double previousRim = -1.0;
      // Step from direct normal (1.0) to silhouette edge (0.0)
      for (double dot = 1.0; dot >= 0.0; dot -= 0.1) {
        final double rim = RimHitFlashEnvelope.computeFresnel(
          nDotV: dot,
          rimPower: 3.0,
          rimIntensity: 1.0,
        );
        expect(rim, greaterThanOrEqualTo(previousRim));
        previousRim = rim;
      }
    });

    test('Sharp exponential falloff: higher rimPower concentrates glow closer to edge', () {
      const double midDot = 0.6; // (1.0 - 0.6 = 0.4)

      final double softRim = RimHitFlashEnvelope.computeFresnel(
        nDotV: midDot,
        rimPower: 1.5,
      );
      final double sharpRim = RimHitFlashEnvelope.computeFresnel(
        nDotV: midDot,
        rimPower: 4.5,
      );

      // 0.4^1.5 ~= 0.25298, 0.4^4.5 ~= 0.01619
      expect(softRim, closeTo(0.253, 0.01));
      expect(sharpRim, closeTo(0.016, 0.005));
      expect(sharpRim, lessThan(softRim * 0.1));
    });

    test('Out-of-range dot products clamp properly to [0.0, 1.0]', () {
      final double clampedNeg = RimHitFlashEnvelope.computeFresnel(
        nDotV: -0.5,
        rimPower: 2.0,
      );
      expect(clampedNeg, closeTo(1.0, 0.0001));

      final double clampedAbove = RimHitFlashEnvelope.computeFresnel(
        nDotV: 1.5,
        rimPower: 2.0,
      );
      expect(clampedAbove, closeTo(0.0, 0.0001));
    });
  });

  group('Rim Hit Flash — Color Presets & Emissive Silhouette Highlight Tests', () {
    test('Preset tint colors map correctly to linear space', () {
      final (double wr, double wg, double wb) =
          RimHitFlashEnvelope.colorToLinearRgb(RimFlashTint.white);
      expect(wr, closeTo(1.0, 0.001));
      expect(wg, closeTo(1.0, 0.001));
      expect(wb, closeTo(1.0, 0.001));

      final (double rr, double rg, double rb) =
          RimHitFlashEnvelope.colorToLinearRgb(RimFlashTint.bloodRed);
      expect(rr, greaterThan(0.9));
      expect(rg, lessThan(0.05));
      expect(rb, lessThan(0.05));

      final (double cr, double cg, double cb) =
          RimHitFlashEnvelope.colorToLinearRgb(RimFlashTint.magicalCyan);
      expect(cr, lessThan(0.05));
      expect(cg, greaterThan(0.7));
      expect(cb, greaterThan(0.9));
    });

    test('Roundtrip color conversion preserves chromaticity', () {
      const List<ui.Color> tints = <ui.Color>[
        RimFlashTint.white,
        RimFlashTint.bloodRed,
        RimFlashTint.magicalCyan,
        RimFlashTint.poisonGreen,
        RimFlashTint.lightningGold,
        RimFlashTint.voidPurple,
      ];

      for (final ui.Color tint in tints) {
        final (double r, double g, double b) =
            RimHitFlashEnvelope.colorToLinearRgb(tint);
        final ui.Color roundtrip =
            RimHitFlashEnvelope.linearRgbToColor(r, g, b);
        expect((roundtrip.r * 255).round(), closeTo((tint.r * 255).round(), 2));
        expect((roundtrip.g * 255).round(), closeTo((tint.g * 255).round(), 2));
        expect((roundtrip.b * 255).round(), closeTo((tint.b * 255).round(), 2));
      }
    });

    test('Emissive silhouette calculation incorporates bloom overdrive multiplier', () {
      const double bloomMultiplier = 3.0;

      // Silhouette edge: NdotV = 0.0, fresnel = 2.0, innerFlash = 0.4, intensity = 1.0
      final (double r, double g, double b) =
          RimHitFlashEnvelope.computeEmissiveHighlight(
        nDotV: 0.0,
        tint: RimFlashTint.white,
        intensity: 1.0,
        rimPower: 3.5,
        rimIntensity: 2.0,
        innerFlash: 0.4,
        bloomMultiplier: bloomMultiplier,
      );

      // Total multiplier = (2.0 + 0.4) * 1.0 * 3.0 = 7.2
      expect(r, closeTo(7.2, 0.05));
      expect(g, closeTo(7.2, 0.05));
      expect(b, closeTo(7.2, 0.05));

      // Overdrive luminance > 1.0 confirms HDR bloom capability
      expect(r, greaterThan(1.0));
    });

    test('Zero intensity produces zero emissive highlight', () {
      final (double r, double g, double b) =
          RimHitFlashEnvelope.computeEmissiveHighlight(
        nDotV: 0.0,
        tint: RimFlashTint.bloodRed,
        intensity: 0.0,
      );
      expect(r, closeTo(0.0, 0.0001));
      expect(g, closeTo(0.0, 0.0001));
      expect(b, closeTo(0.0, 0.0001));
    });
  });

  group('Rim Hit Flash — Shader Uniform Transmission & Layout Tests', () {
    test('buildUniformList exports 13 floats in exact GLSL declaration order', () {
      final RimHitFlashController controller = RimHitFlashController(
        defaultConfig: const RimHitFlashConfig(
          tint: RimFlashTint.magicalCyan,
          rimPower: 4.0,
          rimIntensity: 2.2,
          innerFlash: 0.5,
          edgeBleedWidth: 3.0,
          edgeBleedIntensity: 1.4,
          bloomMultiplier: 2.8,
          normalMode: RimFlashNormalMode.silhouetteGradient,
        ),
      );

      controller.triggerHit();

      const ui.Size testSize = ui.Size(1920.0, 1080.0);
      final List<double> uniforms = controller.buildUniformList(testSize);

      expect(uniforms.length, equals(13));

      // 0..1: uResolution
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));

      // 2: uIntensity
      expect(uniforms[2], equals(1.0));

      // 3..5: uTintColor (linear RGB)
      final (double cr, double cg, double cb) =
          RimHitFlashEnvelope.colorToLinearRgb(RimFlashTint.magicalCyan);
      expect(uniforms[3], closeTo(cr, 0.001));
      expect(uniforms[4], closeTo(cg, 0.001));
      expect(uniforms[5], closeTo(cb, 0.001));

      // 6..12: VFX tuning parameters
      expect(uniforms[6], equals(4.0)); // uRimPower
      expect(uniforms[7], equals(2.2)); // uRimIntensity
      expect(uniforms[8], equals(0.5)); // uInnerFlash
      expect(uniforms[9], equals(3.0)); // uEdgeBleedWidth
      expect(uniforms[10], equals(1.4)); // uEdgeBleedIntensity
      expect(uniforms[11], equals(2.8)); // uBloomMultiplier
      expect(uniforms[12], equals(0.0)); // uNormalMode (silhouetteGradient = 0.0)
    });

    test('toUniformFloat32List packs valid Float32List matching buildUniformList', () {
      final RimHitFlashController controller = RimHitFlashController();
      controller.triggerHit();

      final Float32List buffer = controller.toUniformFloat32List(const ui.Size(640, 480));
      expect(buffer.length, equals(13));
      expect(buffer[0], equals(640.0));
      expect(buffer[1], equals(480.0));
      expect(buffer[2], equals(1.0));
    });

    test('Normal mode enum values map correctly to shader floats', () {
      expect(RimFlashNormalMode.silhouetteGradient.shaderValue, equals(0.0));
      expect(RimFlashNormalMode.normalMap.shaderValue, equals(1.0));
      expect(RimFlashNormalMode.sphericalDome.shaderValue, equals(2.0));
    });
  });

  group('Rim Hit Flash — Controller State Transitions & Lifecycle Tests', () {
    test('Initial state is idle without active flash', () {
      final RimHitFlashController controller = RimHitFlashController();
      expect(controller.isFlashing, isFalse);
      expect(controller.currentIntensity, equals(0.0));
      expect(controller.elapsedTimeMs, equals(0.0));
    });

    test('triggerHit initiates instantaneous flash onset and notifies listeners', () {
      final RimHitFlashController controller = RimHitFlashController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.triggerHit(tint: RimFlashTint.bloodRed);

      expect(controller.isFlashing, isTrue);
      expect(controller.currentIntensity, equals(1.0));
      expect(controller.config.tint, equals(RimFlashTint.bloodRed));
      expect(notifyCount, equals(1));
    });

    test('update steps through time along exponential curve and completes at duration', () {
      final RimHitFlashController controller = RimHitFlashController(
        defaultConfig: const RimHitFlashConfig(
          duration: Duration(milliseconds: 100),
        ),
      );

      controller.triggerHit();

      // Step forward 50ms (0.05 seconds)
      controller.update(0.05);
      expect(controller.isFlashing, isTrue);
      expect(controller.elapsedTimeMs, closeTo(50.0, 0.01));
      expect(controller.currentIntensity, closeTo(0.100, 0.01));

      // Step forward another 50ms (reaching 100ms total)
      controller.update(0.05);
      expect(controller.isFlashing, isFalse);
      expect(controller.currentIntensity, equals(0.0));
      expect(controller.elapsedTimeMs, equals(100.0));

      // Subsequent updates while idle do not advance
      controller.update(0.02);
      expect(controller.isFlashing, isFalse);
      expect(controller.currentIntensity, equals(0.0));
    });

    test('Consecutive multi-hit combo re-triggers reset envelope immediately', () {
      final RimHitFlashController controller = RimHitFlashController(
        defaultConfig: const RimHitFlashConfig(
          duration: Duration(milliseconds: 100),
        ),
      );

      // Hit 1: White flash
      controller.triggerHit(tint: RimFlashTint.white);
      controller.update(0.04); // 40ms passed, intensity down to ~0.16

      expect(controller.currentIntensity, lessThan(0.3));
      expect(controller.elapsedTimeMs, closeTo(40.0, 0.01));

      // Hit 2 in quick combo: Blood red critical strike
      controller.triggerHit(tint: RimFlashTint.bloodRed);

      // Elapsed time must reset immediately to 0 and intensity snap back to 1.0
      expect(controller.isFlashing, isTrue);
      expect(controller.elapsedTimeMs, equals(0.0));
      expect(controller.currentIntensity, equals(1.0));
      expect(controller.config.tint, equals(RimFlashTint.bloodRed));
    });

    test('reset immediately terminates any active flash', () {
      final RimHitFlashController controller = RimHitFlashController();
      controller.triggerHit();
      expect(controller.isFlashing, isTrue);

      controller.reset();
      expect(controller.isFlashing, isFalse);
      expect(controller.currentIntensity, equals(0.0));
      expect(controller.elapsedTimeMs, equals(0.0));
    });

    test('intensityMultiplier scales peak onset accordingly', () {
      final RimHitFlashController controller = RimHitFlashController();
      controller.triggerHit(intensityMultiplier: 1.5);
      expect(controller.currentIntensity, equals(1.5));

      controller.update(0.05); // half duration
      expect(controller.currentIntensity, closeTo(0.150, 0.015));
    });
  });

  group('Rim Hit Flash — Widget & Painter Integration Tests', () {
    testWidgets('RimHitFlashWidget renders child and repaints on hit trigger',
        (WidgetTester tester) async {
      final RimHitFlashController controller = RimHitFlashController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RimHitFlashWidget(
            controller: controller,
            child: const SizedBox(
              width: 100,
              height: 100,
              key: Key('combat_target'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('combat_target')), findsOneWidget);

      // Trigger hit and pump frame
      controller.triggerHit(tint: RimFlashTint.magicalCyan);
      await tester.pump();

      expect(controller.isFlashing, isTrue);

      // Step time and pump frame
      controller.update(0.05);
      await tester.pump();
      expect(controller.isFlashing, isTrue);

      // Step past duration
      controller.update(0.06);
      await tester.pump();
      expect(controller.isFlashing, isFalse);
    });

    test('RimHitFlashPainter does not paint when intensity is zero', () {
      final RimHitFlashController controller = RimHitFlashController();
      final RimHitFlashPainter painter = RimHitFlashPainter(controller: controller);

      // Verify shouldRepaint logic
      final RimHitFlashPainter newPainter = RimHitFlashPainter(controller: controller);
      expect(painter.shouldRepaint(newPainter), isFalse);
    });

    testWidgets('RimHitFlashPainter paints with targetImage without throwing',
        (WidgetTester tester) async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      final ui.Paint paint = ui.Paint()..color = const ui.Color(0xFF00FF00);
      canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 32, 32), paint);
      final ui.Image testImage = await recorder.endRecording().toImage(32, 32);

      final RimHitFlashController controller = RimHitFlashController();
      controller.triggerHit(tint: RimFlashTint.white);

      final RimHitFlashPainter painter = RimHitFlashPainter(
        controller: controller,
        targetImage: testImage,
      );

      final ui.PictureRecorder testRecorder = ui.PictureRecorder();
      final ui.Canvas testCanvas = ui.Canvas(testRecorder);
      expect(() => painter.paint(testCanvas, const ui.Size(32, 32)), returnsNormally);

      testImage.dispose();
    });
  });
}
