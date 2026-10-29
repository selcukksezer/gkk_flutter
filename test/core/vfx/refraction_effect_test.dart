import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/vfx/refraction_effect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RefractionParams — Configuration & Presets', () {
    test('Default constructor sets expected baseline values', () {
      const RefractionParams params = RefractionParams();

      expect(params.center, equals(const ui.Offset(0.5, 0.5)));
      expect(params.progress, equals(0.0));
      expect(params.time, equals(0.0));
      expect(params.maxRadius, equals(0.75));
      expect(params.thickness, equals(0.08));
      expect(params.refractionStrength, equals(0.05));
      expect(params.chromaticAberration, equals(0.02));
      expect(params.dampening, equals(2.5));
      expect(params.frequency, equals(3.0));
      expect(params.mode, equals(RefractionEffectMode.shockwave));
      expect(params.useNormalMap, isFalse);
      expect(params.tint, equals(const ui.Color(0x00000000)));
    });

    test('Shockwave preset configures physical explosive parameters', () {
      final RefractionParams params = RefractionParams.shockwave(
        center: const ui.Offset(0.2, 0.8),
        maxRadius: 0.9,
      );

      expect(params.mode, equals(RefractionEffectMode.shockwave));
      expect(params.center, equals(const ui.Offset(0.2, 0.8)));
      expect(params.maxRadius, equals(0.9));
      expect(params.refractionStrength, closeTo(0.055, 0.001));
      expect(params.dampening, closeTo(2.2, 0.001));
    });

    test('Critical hit preset sets violent high-frequency parameters and crimson tint', () {
      final RefractionParams params = RefractionParams.criticalHit();

      expect(params.mode, equals(RefractionEffectMode.criticalHit));
      expect(params.maxRadius, equals(0.95));
      expect(params.thickness, equals(0.12));
      expect(params.refractionStrength, equals(0.085));
      expect(params.chromaticAberration, equals(0.045));
      expect(params.frequency, equals(4.5));
      expect(params.tint, equals(const ui.Color(0x66FF3333)));
    });

    test('Heat haze preset configures continuous convection parameters', () {
      final RefractionParams params = RefractionParams.heatHaze(time: 2.5);

      expect(params.mode, equals(RefractionEffectMode.heatHaze));
      expect(params.time, equals(2.5));
      expect(params.dampening, equals(0.0));
      expect(params.frequency, equals(3.5));
    });

    test('Magical shield preset sets cyan tint and runic interference frequency', () {
      final RefractionParams params = RefractionParams.magicalShield();

      expect(params.mode, equals(RefractionEffectMode.magicalShield));
      expect(params.tint, equals(const ui.Color(0x5522E5FF)));
      expect(params.frequency, equals(5.0));
    });

    test('copyWith updates specified fields while retaining others', () {
      const RefractionParams original = RefractionParams();
      final RefractionParams copy = original.copyWith(
        progress: 0.75,
        refractionStrength: 0.12,
        mode: RefractionEffectMode.criticalHit,
      );

      expect(copy.progress, equals(0.75));
      expect(copy.refractionStrength, equals(0.12));
      expect(copy.mode, equals(RefractionEffectMode.criticalHit));
      expect(copy.center, equals(original.center));
      expect(copy.maxRadius, equals(original.maxRadius));
      expect(copy.dampening, equals(original.dampening));
    });

    test('Value equality and hashCode handle identical and differing instances', () {
      const RefractionParams a = RefractionParams(progress: 0.5);
      const RefractionParams b = RefractionParams(progress: 0.5);
      const RefractionParams c = RefractionParams(progress: 0.6);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('Shockwave'));
    });
  });

  group('RefractionParams — Uniform Serialization', () {
    test('toUniformList serializes exactly 18 floats in GLSL layout order', () {
      const ui.Size size = ui.Size(1920.0, 1080.0);
      final RefractionParams params = RefractionParams(
        center: const ui.Offset(0.4, 0.6),
        progress: 0.35,
        time: 1.25,
        maxRadius: 0.8,
        thickness: 0.09,
        refractionStrength: 0.06,
        chromaticAberration: 0.025,
        dampening: 2.4,
        frequency: 4.0,
        mode: RefractionEffectMode.criticalHit,
        useNormalMap: true,
        tint: const ui.Color.fromRGBO(255, 128, 64, 0.75),
      );

      final List<double> uniforms = params.toUniformList(size: size);
      expect(uniforms.length, equals(18));

      // 0..1: uResolution
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));

      // 2..3: uCenter
      expect(uniforms[2], equals(0.4));
      expect(uniforms[3], equals(0.6));

      // 4: uProgress
      expect(uniforms[4], equals(0.35));

      // 5: uTime
      expect(uniforms[5], equals(1.25));

      // 6: uMaxRadius
      expect(uniforms[6], equals(0.8));

      // 7: uThickness
      expect(uniforms[7], equals(0.09));

      // 8: uRefractionStrength
      expect(uniforms[8], equals(0.06));

      // 9: uChromaticAberration
      expect(uniforms[9], equals(0.025));

      // 10: uDampening
      expect(uniforms[10], equals(2.4));

      // 11: uFrequency
      expect(uniforms[11], equals(4.0));

      // 12: uMode
      expect(uniforms[12], equals(1.0)); // criticalHit

      // 13: uUseNormalMap
      expect(uniforms[13], equals(1.0));

      // 14..17: uTint (RGBA)
      expect(uniforms[14], closeTo(1.0, 0.01));
      expect(uniforms[15], closeTo(0.5, 0.01));
      expect(uniforms[16], closeTo(0.25, 0.01));
      expect(uniforms[17], closeTo(0.75, 0.01));
    });

    test('Mode shaderValues match exact numeric identifiers', () {
      expect(RefractionEffectMode.shockwave.shaderValue, equals(0.0));
      expect(RefractionEffectMode.criticalHit.shaderValue, equals(1.0));
      expect(RefractionEffectMode.heatHaze.shaderValue, equals(2.0));
      expect(RefractionEffectMode.magicalShield.shaderValue, equals(3.0));
    });
  });

  group('RefractionMath — Analytical Wave Physics & Optics', () {
    test('calculateCurrentRadius expands linearly for shockwave', () {
      const RefractionParams params = RefractionParams(
        mode: RefractionEffectMode.shockwave,
        maxRadius: 0.8,
      );

      expect(RefractionMath.calculateCurrentRadius(params.copyWith(progress: 0.0)), equals(0.0));
      expect(RefractionMath.calculateCurrentRadius(params.copyWith(progress: 0.5)), closeTo(0.4, 0.0001));
      expect(RefractionMath.calculateCurrentRadius(params.copyWith(progress: 1.0)), closeTo(0.8, 0.0001));
    });

    test('calculateCurrentRadius expands with square-root curve for critical hit', () {
      const RefractionParams params = RefractionParams(
        mode: RefractionEffectMode.criticalHit,
        maxRadius: 0.8,
      );

      // At progress 0.25, sqrt(0.25) = 0.5, so radius is 0.8 * 0.5 = 0.4 (faster than linear 0.2)
      final double radiusAtQuarter = RefractionMath.calculateCurrentRadius(params.copyWith(progress: 0.25));
      expect(radiusAtQuarter, closeTo(0.4, 0.0001));

      // Critical hit expansion must exceed linear shockwave expansion at t=0.25
      const RefractionParams shockwave = RefractionParams(
        mode: RefractionEffectMode.shockwave,
        maxRadius: 0.8,
      );
      final double shockwaveRadius = RefractionMath.calculateCurrentRadius(shockwave.copyWith(progress: 0.25));
      expect(radiusAtQuarter, greaterThan(shockwaveRadius));
    });

    test('calculateDecay strictly decays monotonically to 0.0 at progress=1.0', () {
      const RefractionParams params = RefractionParams(
        mode: RefractionEffectMode.shockwave,
        dampening: 2.5,
      );

      double previousDecay = 1.0;
      for (double p = 0.1; p <= 1.0; p += 0.1) {
        final double decay = RefractionMath.calculateDecay(params.copyWith(progress: p));
        expect(decay, lessThanOrEqualTo(previousDecay));
        previousDecay = decay;
      }

      // At progress 1.0, decay must hit 0.0 exactly due to boundary clamp
      expect(RefractionMath.calculateDecay(params.copyWith(progress: 1.0)), equals(0.0));
    });

    test('calculateHannEnvelope forms symmetric bell window with 0 at edges', () {
      const double thickness = 0.1;

      // Center of wavefront (distToFront = 0.0)
      final double centerEnvelope = RefractionMath.calculateHannEnvelope(
        distToFront: 0.0,
        thickness: thickness,
      );
      expect(centerEnvelope, closeTo(1.0, 0.0001));

      // Halfway between center and boundary (distToFront = 0.025)
      final double halfEnvelope = RefractionMath.calculateHannEnvelope(
        distToFront: 0.025,
        thickness: thickness,
      );
      expect(halfEnvelope, closeTo(0.5, 0.001));

      // Exactly at or beyond boundary (distToFront >= 0.05)
      final double edgeEnvelope = RefractionMath.calculateHannEnvelope(
        distToFront: 0.05,
        thickness: thickness,
      );
      expect(edgeEnvelope, equals(0.0));

      final double outsideEnvelope = RefractionMath.calculateHannEnvelope(
        distToFront: 0.08,
        thickness: thickness,
      );
      expect(outsideEnvelope, equals(0.0));
    });

    test('isWithinWavefront identifies fragments inside active ring', () {
      const ui.Size size = ui.Size(800.0, 800.0);
      const RefractionParams params = RefractionParams(
        center: ui.Offset(0.5, 0.5),
        progress: 0.5,
        maxRadius: 0.8, // current radius = 0.4
        thickness: 0.1,  // half thickness = 0.05 (ring extends from 0.35 to 0.45)
      );

      // Point at radius 0.40 (exact wavefront center)
      final ui.Offset insidePoint = ui.Offset(0.5 + 0.40, 0.5);
      expect(
        RefractionMath.isWithinWavefront(uv: insidePoint, size: size, params: params),
        isTrue,
      );

      // Point at radius 0.20 (behind wavefront)
      final ui.Offset innerPoint = ui.Offset(0.5 + 0.20, 0.5);
      expect(
        RefractionMath.isWithinWavefront(uv: innerPoint, size: size, params: params),
        isFalse,
      );

      // Point at radius 0.60 (ahead of wavefront)
      final ui.Offset outerPoint = ui.Offset(0.5 + 0.60, 0.5);
      expect(
        RefractionMath.isWithinWavefront(uv: outerPoint, size: size, params: params),
        isFalse,
      );
    });

    test('calculateDisplacement produces radial vector directed outward/inward across ring', () {
      const ui.Size size = ui.Size(500.0, 500.0);
      const RefractionParams params = RefractionParams(
        center: ui.Offset(0.5, 0.5),
        progress: 0.5,
        maxRadius: 0.8, // radius = 0.4
        thickness: 0.1,
        refractionStrength: 0.05,
        frequency: 2.0,
      );

      // Point slightly ahead of wave center (outer crest)
      final ui.Offset outerSample = ui.Offset(0.5 + 0.425, 0.5);
      final ui.Offset dispOuter = RefractionMath.calculateDisplacement(
        uv: outerSample,
        size: size,
        params: params,
      );

      // Displacement along X axis must be non-zero while Y remains 0
      expect(dispOuter.dx.abs(), greaterThan(0.0));
      expect(dispOuter.dy, closeTo(0.0, 0.0001));

      // Point outside ring produces exactly zero displacement
      final ui.Offset outsideSample = ui.Offset(0.5 + 0.10, 0.5);
      final ui.Offset dispOutside = RefractionMath.calculateDisplacement(
        uv: outsideSample,
        size: size,
        params: params,
      );
      expect(dispOutside, equals(ui.Offset.zero));
    });

    test('calculateChromaticUvs splits red and blue channels radially', () {
      const ui.Size size = ui.Size(600.0, 600.0);
      const RefractionParams params = RefractionParams(
        center: ui.Offset(0.5, 0.5),
        progress: 0.5,
        maxRadius: 0.8,
        thickness: 0.1,
        refractionStrength: 0.05,
        chromaticAberration: 0.03,
      );

      final ui.Offset sampleUv = ui.Offset(0.5 + 0.42, 0.5);
      final chromatic = RefractionMath.calculateChromaticUvs(
        uv: sampleUv,
        size: size,
        params: params,
      );

      // Red channel must be pushed further along the radial vector than green
      expect(chromatic.red.dx, greaterThan(chromatic.green.dx));

      // Blue channel must be pulled backward along the radial vector relative to green
      expect(chromatic.blue.dx, lessThan(chromatic.green.dx));

      // Green UV is the base displaced coordinate
      expect(chromatic.green.dy, closeTo(0.5, 0.01));
    });
  });

  group('RefractionShaderController — Lifecycle & State Management', () {
    test('Initial controller starts in idle non-animating state', () {
      final RefractionShaderController controller = RefractionShaderController();

      expect(controller.isActive, isFalse);
      expect(controller.isContinuous, isFalse);
      expect(controller.elapsedTimeSeconds, equals(0.0));
      expect(controller.isShaderLoaded, isFalse);
    });

    test('triggerShockwave activates controller with shockwave params', () {
      final RefractionShaderController controller = RefractionShaderController();

      controller.triggerShockwave(
        center: const ui.Offset(0.3, 0.7),
        maxRadius: 0.85,
        duration: const Duration(milliseconds: 500),
      );

      expect(controller.isActive, isTrue);
      expect(controller.isContinuous, isFalse);
      expect(controller.params.mode, equals(RefractionEffectMode.shockwave));
      expect(controller.params.center, equals(const ui.Offset(0.3, 0.7)));
      expect(controller.params.maxRadius, equals(0.85));
      expect(controller.params.progress, equals(0.0));
    });

    test('triggerCriticalHit sets high strength and crimson flash', () {
      final RefractionShaderController controller = RefractionShaderController();

      controller.triggerCriticalHit(
        center: const ui.Offset(0.5, 0.5),
        strength: 0.09,
      );

      expect(controller.isActive, isTrue);
      expect(controller.params.mode, equals(RefractionEffectMode.criticalHit));
      expect(controller.params.refractionStrength, equals(0.09));
    });

    test('triggerMagicalShield sets magical shield mode and cyan tint', () {
      final RefractionShaderController controller = RefractionShaderController();

      controller.triggerMagicalShield(
        center: const ui.Offset(0.4, 0.4),
      );

      expect(controller.isActive, isTrue);
      expect(controller.params.mode, equals(RefractionEffectMode.magicalShield));
      expect(controller.params.tint, equals(const ui.Color(0x5522E5FF)));
    });

    test('update advances progress and completes animation at 100%', () {
      final RefractionShaderController controller = RefractionShaderController();
      controller.triggerShockwave(duration: const Duration(milliseconds: 500));

      // Advance by 250ms (50%)
      controller.update(0.25);
      expect(controller.params.progress, closeTo(0.5, 0.01));
      expect(controller.isActive, isTrue);

      // Advance by another 250ms (total 500ms = 100%)
      controller.update(0.25);
      expect(controller.params.progress, equals(1.0));
      expect(controller.isActive, isFalse);
    });

    test('Continuous heat haze mode advances continuous time without terminating', () {
      final RefractionShaderController controller = RefractionShaderController();
      controller.startContinuousHeatHaze(strength: 0.03);

      expect(controller.isActive, isTrue);
      expect(controller.isContinuous, isTrue);
      expect(controller.params.mode, equals(RefractionEffectMode.heatHaze));

      controller.update(1.0);
      expect(controller.params.time, closeTo(1.0, 0.001));
      expect(controller.isActive, isTrue);

      controller.update(2.5);
      expect(controller.params.time, closeTo(3.5, 0.001));
      expect(controller.isActive, isTrue);

      controller.stop();
      expect(controller.isActive, isFalse);
      expect(controller.isContinuous, isFalse);
    });

    test('buildUniformList and toUniformFloat32List generate valid buffers', () {
      final RefractionShaderController controller = RefractionShaderController();
      controller.triggerShockwave();

      final Float32List buffer = controller.toUniformFloat32List(const ui.Size(800.0, 600.0));
      expect(buffer.length, equals(18));
      expect(buffer[0], equals(800.0));
      expect(buffer[1], equals(600.0));
    });

    test('initShader handles missing asset in test environment gracefully', () async {
      final RefractionShaderController controller = RefractionShaderController();
      final bool loaded = await controller.initShader('non_existent.frag');

      expect(loaded, isFalse);
      expect(controller.isShaderLoaded, isFalse);
    });
  });

  group('RefractionShaderWarmUp — Impeller & Skia Pre-Warming', () {
    test('RefractionShaderWarmUp constructs and executes warmUpOnCanvas', () async {
      final RefractionShaderController controller = RefractionShaderController();
      final RefractionShaderWarmUp warmUp = RefractionShaderWarmUp(
        controller: controller,
        warmUpSize: const ui.Size(64.0, 64.0),
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      await warmUp.warmUpOnCanvas(canvas);

      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('Standalone controller warmUp executes without throwing', () {
      final RefractionShaderController controller = RefractionShaderController();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      controller.warmUp(canvas, const ui.Size(128.0, 128.0));

      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });
  });

  group('RefractionEffectPainter — Rendering & Fallback Pipeline', () {
    test('CustomPainter paints fallback shockwave without crashing', () {
      final RefractionShaderController controller = RefractionShaderController();
      controller.triggerShockwave();
      controller.update(0.3);

      final RefractionEffectPainter painter = RefractionEffectPainter(
        controller: controller,
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      painter.paint(canvas, const ui.Size(300.0, 300.0));

      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('shouldRepaint returns true when controller state changes', () {
      final RefractionShaderController controller1 = RefractionShaderController();
      final RefractionShaderController controller2 = RefractionShaderController();

      final RefractionEffectPainter painter1 = RefractionEffectPainter(controller: controller1);
      final RefractionEffectPainter painter2 = RefractionEffectPainter(controller: controller2);

      expect(painter1.shouldRepaint(painter2), isTrue);
      expect(painter1.shouldRepaint(painter1), isFalse);
    });
  });

  group('RefractionTextureHelper — Neutral Normal Synthesis', () {
    test('getNeutralNormalTexture synthesizes a 2x2 normal map texture', () async {
      final ui.Image normalMap = await RefractionTextureHelper.getNeutralNormalTexture();

      expect(normalMap, isNotNull);
      expect(normalMap.width, equals(2));
      expect(normalMap.height, equals(2));

      // Subsequent call returns cached instance
      final ui.Image cached = await RefractionTextureHelper.getNeutralNormalTexture();
      expect(identical(normalMap, cached), isTrue);
    });
  });

  group('RefractionEffectWidget — Widget Lifecycle Test', () {
    testWidgets('RefractionEffectWidget renders child cleanly', (WidgetTester tester) async {
      final RefractionShaderController controller = RefractionShaderController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RefractionEffectWidget(
            controller: controller,
            child: const SizedBox(
              width: 200,
              height: 200,
              child: Text('Dungeon Hero'),
            ),
          ),
        ),
      );

      expect(find.text('Dungeon Hero'), findsOneWidget);

      // Trigger shockwave and pump frames
      controller.triggerShockwave();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.isActive, isTrue);

      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.isActive, isFalse);
    });
  });
}
