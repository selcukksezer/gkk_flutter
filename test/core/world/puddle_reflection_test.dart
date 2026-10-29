import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/engine/adaptive_quality_scaler.dart';
import 'package:gkk_flutter/core/world/puddle_reflection_layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // 1. WorldVector3 Math & Reflection Tests
  // ---------------------------------------------------------------------------
  group('WorldVector3 Math & Reflection Tests', () {
    test('Vector basic arithmetic, dot, cross, and length', () {
      const WorldVector3 v1 = WorldVector3(1.0, 2.0, 3.0);
      const WorldVector3 v2 = WorldVector3(4.0, 5.0, 6.0);

      final WorldVector3 sum = v1 + v2;
      expect(sum.x, closeTo(5.0, 1e-6));
      expect(sum.y, closeTo(7.0, 1e-6));
      expect(sum.z, closeTo(9.0, 1e-6));

      final WorldVector3 diff = v2 - v1;
      expect(diff.x, closeTo(3.0, 1e-6));
      expect(diff.y, closeTo(3.0, 1e-6));
      expect(diff.z, closeTo(3.0, 1e-6));

      final WorldVector3 scaled = v1 * 2.0;
      expect(scaled.x, closeTo(2.0, 1e-6));
      expect(scaled.y, closeTo(4.0, 1e-6));
      expect(scaled.z, closeTo(6.0, 1e-6));

      final WorldVector3 divided = scaled / 2.0;
      expect(divided, equals(v1));

      expect(v1.dot(v2), closeTo(1 * 4 + 2 * 5 + 3 * 6, 1e-6));

      // Cross product of unitX and unitY is unitZ
      final WorldVector3 crossProd = WorldVector3.unitX.cross(WorldVector3.unitY);
      expect(crossProd.x, closeTo(0.0, 1e-6));
      expect(crossProd.y, closeTo(0.0, 1e-6));
      expect(crossProd.z, closeTo(1.0, 1e-6));

      const WorldVector3 v = WorldVector3(0.0, 3.0, 4.0);
      expect(v.lengthSquared, closeTo(25.0, 1e-6));
      expect(v.length, closeTo(5.0, 1e-6));

      final WorldVector3 norm = v.normalized;
      expect(norm.length, closeTo(1.0, 1e-6));
      expect(norm.y, closeTo(0.6, 1e-6));
      expect(norm.z, closeTo(0.8, 1e-6));
    });

    test('Reflecting incident ray perpendicular to plane reverses direction', () {
      const WorldVector3 incident = WorldVector3(0.0, 0.0, -1.0);
      const WorldVector3 normal = WorldVector3(0.0, 0.0, 1.0);

      final WorldVector3 reflected = incident.reflect(normal);
      expect(reflected.x, closeTo(0.0, 1e-6));
      expect(reflected.y, closeTo(0.0, 1e-6));
      expect(reflected.z, closeTo(1.0, 1e-6));
      expect(reflected.length, closeTo(incident.length, 1e-6));
    });

    test('Reflecting 45-degree incident ray obeys specular law of reflection', () {
      final WorldVector3 incident = const WorldVector3(1.0, 0.0, -1.0).normalized;
      const WorldVector3 normal = WorldVector3(0.0, 0.0, 1.0);

      final WorldVector3 reflected = incident.reflect(normal);
      expect(reflected.x, closeTo(incident.x, 1e-6));
      expect(reflected.y, closeTo(0.0, 1e-6));
      expect(reflected.z, closeTo(-incident.z, 1e-6));
      expect(reflected.length, closeTo(1.0, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Schlick's Fresnel Approximation Tests
  // ---------------------------------------------------------------------------
  group("Schlick's Fresnel Approximation Tests", () {
    test('Direct normal view (cosTheta = 1.0) evaluates strictly to F0', () {
      final double fNormal = SchlickFresnel.evaluate(
        cosTheta: 1.0,
        f0: SchlickFresnel.waterF0,
        roughness: 0.0,
      );
      expect(fNormal, closeTo(SchlickFresnel.waterF0, 1e-6));
    });

    test('Grazing angle view (cosTheta = 0.0) evaluates to 1.0 for smooth surface', () {
      final double fGrazing = SchlickFresnel.evaluate(
        cosTheta: 0.0,
        f0: SchlickFresnel.waterF0,
        roughness: 0.0,
      );
      expect(fGrazing, closeTo(1.0, 1e-6));
    });

    test('Fresnel reflection increases monotonically from normal incidence to grazing', () {
      double previousReflectance = -1.0;

      // As angle theta increases from 0 (normal) to 90 degrees (grazing),
      // cosTheta decreases from 1.0 down to 0.0, and reflectance must strictly increase.
      for (double cosTheta = 1.0; cosTheta >= 0.0; cosTheta -= 0.1) {
        final double reflectance = SchlickFresnel.evaluate(
          cosTheta: cosTheta,
          f0: SchlickFresnel.waterF0,
          roughness: 0.0,
        );

        expect(reflectance, greaterThanOrEqualTo(previousReflectance - 1e-9));
        previousReflectance = reflectance;
      }
    });

    test('Mid-angle incidence matches analytical Schlick equation', () {
      const double cosTheta = 0.5; // 60 degrees incidence
      const double f0 = 0.0204;
      const double roughness = 0.0;

      // F = 0.0204 + (1.0 - 0.0204) * (1.0 - 0.5)^5
      // (0.5)^5 = 0.03125
      // 0.0204 + 0.9796 * 0.03125 = 0.0204 + 0.0306125 = 0.0510125
      final double expected = f0 + (1.0 - f0) * math.pow(1.0 - cosTheta, 5.0);
      final double actual = SchlickFresnel.evaluate(
        cosTheta: cosTheta,
        f0: f0,
        roughness: roughness,
      );

      expect(actual, closeTo(expected, 1e-5));
    });

    test('Roughness modulates maximum grazing specular reflectance', () {
      const double roughness = 0.4;
      final double fGrazingRough = SchlickFresnel.evaluate(
        cosTheta: 0.0,
        f0: SchlickFresnel.waterF0,
        roughness: roughness,
      );

      // max(1.0 - roughness, F0) = 0.6
      expect(fGrazingRough, closeTo(0.6, 1e-5));
    });

    test('Out-of-bound cosTheta values are safely clamped to [0.0, 1.0]', () {
      final double fNegative = SchlickFresnel.evaluate(cosTheta: -0.5);
      expect(fNegative, closeTo(1.0, 1e-6));

      final double fOver = SchlickFresnel.evaluate(cosTheta: 1.5);
      expect(fOver, closeTo(SchlickFresnel.waterF0, 1e-6));
    });

    test('calculateF0 computes correct normal reflectance from refractive indices', () {
      // Air (1.0) to Water (1.333) -> ((1.0 - 1.333) / (1.0 + 1.333))^2 ~= 0.02037
      final double f0Water = SchlickFresnel.calculateF0(n1: 1.0, n2: 1.333);
      expect(f0Water, closeTo(0.02037, 0.001));

      // Air (1.0) to Glass (1.5) -> ((1.0 - 1.5) / (1.0 + 1.5))^2 = (-0.5 / 2.5)^2 = 0.04
      final double f0Glass = SchlickFresnel.calculateF0(n1: 1.0, n2: 1.5);
      expect(f0Glass, closeTo(0.04, 1e-5));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Dual-Octave Gerstner Wave Math Tests
  // ---------------------------------------------------------------------------
  group('Dual-Octave Gerstner Wave Math Tests', () {
    test('Zero intensity produces upright unit normal (0, 0, 1)', () {
      final WorldVector3 normal = GerstnerWaveMath.evaluateNormal(
        uv: const ui.Offset(0.5, 0.5),
        time: 1.0,
        intensity: 0.0,
      );
      expect(normal, equals(WorldVector3.up));

      final double height = GerstnerWaveMath.evaluateHeight(
        uv: const ui.Offset(0.5, 0.5),
        time: 1.0,
        intensity: 0.0,
      );
      expect(height, closeTo(0.0, 1e-6));
    });

    test('Non-zero intensity produces normalized perturbed surface normal', () {
      final WorldVector3 normal = GerstnerWaveMath.evaluateNormal(
        uv: const ui.Offset(0.3, 0.7),
        time: 2.5,
        intensity: 0.8,
      );

      expect(normal.length, closeTo(1.0, 1e-5));
      expect(normal.z, greaterThan(0.0)); // normal points upwards towards sky
    });

    test('Surface height displacement oscillates over time and space', () {
      const ui.Offset uv = ui.Offset(0.25, 0.45);
      final double h0 = GerstnerWaveMath.evaluateHeight(uv: uv, time: 0.0, intensity: 1.0);
      final double h1 = GerstnerWaveMath.evaluateHeight(uv: uv, time: 0.5, intensity: 1.0);
      final double h2 = GerstnerWaveMath.evaluateHeight(uv: uv, time: 1.0, intensity: 1.0);

      // Height displacement should not be constant across time
      expect((h0 - h1).abs() + (h1 - h2).abs(), greaterThan(1e-4));
      // Max displacement bounded by amplitudes (0.015 + 0.008 = 0.023)
      expect(h0.abs(), lessThanOrEqualTo(0.03));
      expect(h1.abs(), lessThanOrEqualTo(0.03));
    });

    test('Wavelength and wave number relationships adhere to dispersion relation', () {
      const GerstnerWaveOctave octave = GerstnerWaveMath.defaultOctave1;
      expect(octave.waveNumber, closeTo((2.0 * math.pi) / octave.waveLength, 1e-4));
      expect(octave.angularFrequency, greaterThan(0.0));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Dual-Octave Voronoi Rain Ripple Math Tests
  // ---------------------------------------------------------------------------
  group('Dual-Octave Voronoi Rain Ripple Math Tests', () {
    test('Hash functions hash12 and hash22 are deterministic and bounded in [0.0, 1.0]', () {
      for (double x = 0.0; x <= 5.0; x += 1.0) {
        for (double y = 0.0; y <= 5.0; y += 1.0) {
          final ui.Offset p = ui.Offset(x, y);
          final double h1 = VoronoiRippleMath.hash12(p);
          final ui.Offset h2 = VoronoiRippleMath.hash22(p);

          expect(h1, greaterThanOrEqualTo(0.0));
          expect(h1, lessThan(1.0));

          expect(h2.dx, greaterThanOrEqualTo(0.0));
          expect(h2.dx, lessThan(1.0));
          expect(h2.dy, greaterThanOrEqualTo(0.0));
          expect(h2.dy, lessThan(1.0));

          // Deterministic
          expect(VoronoiRippleMath.hash12(p), equals(h1));
          expect(VoronoiRippleMath.hash22(p), equals(h2));
        }
      }
    });

    test('Zero rain intensity returns zero ripple perturbation', () {
      final WorldVector3 ripple = VoronoiRippleMath.evaluateDualOctave(
        uv: const ui.Offset(0.5, 0.5),
        time: 2.0,
        speed: 1.0,
        intensity: 0.0,
      );

      expect(ripple.x, closeTo(0.0, 1e-6));
      expect(ripple.y, closeTo(0.0, 1e-6));
      expect(ripple.z, closeTo(0.0, 1e-6));
    });

    test('Rain impact generates dynamic normal offsets across surface', () {
      final WorldVector3 r1 = VoronoiRippleMath.evaluateDualOctave(
        uv: const ui.Offset(0.2, 0.3),
        time: 1.2,
        speed: 1.0,
        intensity: 0.8,
      );

      final WorldVector3 r2 = VoronoiRippleMath.evaluateDualOctave(
        uv: const ui.Offset(0.7, 0.8),
        time: 1.2,
        speed: 1.0,
        intensity: 0.8,
      );

      // Ripples generate spatial variations across different puddle locations
      expect(r1.lengthSquared + r2.lengthSquared, greaterThan(0.0));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. SSR Raymarching & Screen Mapping Tests
  // ---------------------------------------------------------------------------
  group('SSR Raymarching & Screen Mapping Tests', () {
    test('calculatePlanarUV mirrors vertically across plane Y', () {
      const double planeY = 0.6;
      const ui.Offset uv = ui.Offset(0.4, 0.7); // 0.1 below plane

      final ui.Offset planarUV = SSRRaymarchMath.calculatePlanarUV(
        uv: uv,
        planeY: planeY,
      );

      // Mirrored Y = 2 * 0.6 - 0.7 = 0.5 (0.1 above plane)
      expect(planarUV.dx, closeTo(0.4, 1e-4));
      expect(planarUV.dy, closeTo(0.5, 1e-4));
    });

    test('calculateEdgeFade attenuates near screen edges and stays 1.0 in interior', () {
      const double margin = 0.08;

      // Exact border has zero fade factor
      final double atLeft = SSRRaymarchMath.calculateEdgeFade(
        uv: const ui.Offset(0.0, 0.5),
        margin: margin,
      );
      expect(atLeft, closeTo(0.0, 1e-5));

      final double atTop = SSRRaymarchMath.calculateEdgeFade(
        uv: const ui.Offset(0.5, 0.0),
        margin: margin,
      );
      expect(atTop, closeTo(0.0, 1e-5));

      // Interior point far from margins has 1.0
      final double center = SSRRaymarchMath.calculateEdgeFade(
        uv: const ui.Offset(0.5, 0.5),
        margin: margin,
      );
      expect(center, closeTo(1.0, 1e-5));

      // Point at exactly half-margin has smoothstep(0.5) = 0.5
      final double halfMargin = SSRRaymarchMath.calculateEdgeFade(
        uv: const ui.Offset(0.04, 0.5),
        margin: margin,
      );
      // smoothstep(0.5) = 0.5^2 * (3 - 2*0.5) = 0.25 * 2 = 0.5
      expect(halfMargin, closeTo(0.5, 1e-4));
    });

    test('marchRayPath steps incrementally along reflection direction and terminates at screen boundary', () {
      final List<ui.Offset> path = SSRRaymarchMath.marchRayPath(
        startUV: const ui.Offset(0.5, 0.5),
        screenReflectDir: const ui.Offset(0.0, -1.0), // upward
        stepSize: 0.1,
        maxSteps: 10,
      );

      // Starting at y=0.5, stepping up by 0.1:
      // Step 1: y = 0.4
      // Step 2: y = 0.3
      // Step 3: y = 0.2
      // Step 4: y = 0.1
      // Step 5: y = 0.0
      // Step 6: y = -0.1 (exits boundary, terminates)
      expect(path.length, equals(5));
      expect(path.first.dy, closeTo(0.4, 1e-4));
      expect(path.last.dy, closeTo(0.0, 1e-4));
    });

    test('Beer-Lambert transmittance decays exponentially with water depth', () {
      const double extinction = 0.5;

      final double tShallow = SSRRaymarchMath.calculateBeerLambertTransmittance(
        waterDepth: 0.1,
        extinctionCoeff: extinction,
      );

      final double tMedium = SSRRaymarchMath.calculateBeerLambertTransmittance(
        waterDepth: 0.5,
        extinctionCoeff: extinction,
      );

      final double tDeep = SSRRaymarchMath.calculateBeerLambertTransmittance(
        waterDepth: 1.0,
        extinctionCoeff: extinction,
      );

      // Strict exponential decay
      expect(tShallow, greaterThan(tMedium));
      expect(tMedium, greaterThan(tDeep));
      expect(tDeep, greaterThan(0.0));
      expect(tShallow, lessThanOrEqualTo(1.0));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Shader Uniform Transmission & Layout Tests
  // ---------------------------------------------------------------------------
  group('Shader Uniform Transmission & Layout Tests', () {
    test('buildUniformList exports exactly 27 floats in GLSL declaration order', () {
      final PuddleReflectionConfig config = PuddleReflectionConfig.calmAfterRain();
      const ui.Size size = ui.Size(1920.0, 1080.0);
      const double time = 4.2;

      final List<double> uniforms = config.buildUniformList(
        viewportSize: size,
        time: time,
      );

      expect(uniforms.length, equals(27));

      // 0, 1: uResolution
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));

      // 2: uTime
      expect(uniforms[2], equals(4.2));

      // 3, 4, 5: uCameraPos
      expect(uniforms[3], equals(config.cameraPosition.x));
      expect(uniforms[4], equals(config.cameraPosition.y));
      expect(uniforms[5], equals(config.cameraPosition.z));

      // 6, 7, 8: uCameraDir
      final WorldVector3 normDir = config.cameraDirection.normalized;
      expect(uniforms[6], closeTo(normDir.x, 1e-5));
      expect(uniforms[7], closeTo(normDir.y, 1e-5));
      expect(uniforms[8], closeTo(normDir.z, 1e-5));

      // 9: uRainIntensity
      expect(uniforms[9], equals(config.rainIntensity));

      // 10: uRippleSpeed
      expect(uniforms[10], equals(config.rippleSpeed));

      // 11: uPuddleRoughness
      expect(uniforms[11], equals(config.puddleRoughness));

      // 12: uReflectivity
      expect(uniforms[12], equals(config.reflectivity));

      // 13: uFresnelR0
      expect(uniforms[13], equals(config.fresnelR0));

      // 14: uWaterDepthScale
      expect(uniforms[14], equals(config.waterDepthScale));

      // 15..18: uWaterColor
      expect(uniforms[15], closeTo(config.waterColor.r, 1e-4));
      expect(uniforms[16], closeTo(config.waterColor.g, 1e-4));
      expect(uniforms[17], closeTo(config.waterColor.b, 1e-4));
      expect(uniforms[18], closeTo(config.waterColor.a, 1e-4));

      // 19..22: uMudColor
      expect(uniforms[19], closeTo(config.mudColor.r, 1e-4));
      expect(uniforms[20], closeTo(config.mudColor.g, 1e-4));
      expect(uniforms[21], closeTo(config.mudColor.b, 1e-4));
      expect(uniforms[22], closeTo(config.mudColor.a, 1e-4));

      // 23: uMaxRaySteps
      expect(uniforms[23], equals(config.maxRaySteps));

      // 24: uRayStepSize
      expect(uniforms[24], equals(config.rayStepSize));

      // 25: uPlanarReflectionHeight
      expect(uniforms[25], equals(config.planarReflectionHeight));

      // 26: uEdgeFadeMargin
      expect(uniforms[26], equals(config.edgeFadeMargin));
    });

    test('toUniformFloat32List packs valid Float32List matching buildUniformList', () {
      final PuddleReflectionConfig config = PuddleReflectionConfig.heavyDownpour();
      const ui.Size size = ui.Size(800.0, 600.0);
      const double time = 10.0;

      final Float32List float32List = config.toUniformFloat32List(
        viewportSize: size,
        time: time,
      );

      final List<double> uniformList = config.buildUniformList(
        viewportSize: size,
        time: time,
      );

      expect(float32List.length, equals(27));
      for (int i = 0; i < 27; i++) {
        expect(float32List[i], closeTo(uniformList[i], 1e-4));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Preset Configurations & Controller Lifecycle Tests
  // ---------------------------------------------------------------------------
  group('Preset Configurations & Controller Lifecycle Tests', () {
    test('Presets instantiate distinct realistic parameters', () {
      final PuddleReflectionConfig calm = PuddleReflectionConfig.calmAfterRain();
      final PuddleReflectionConfig heavy = PuddleReflectionConfig.heavyDownpour();
      final PuddleReflectionConfig night = PuddleReflectionConfig.nightHubReflections();

      expect(heavy.rainIntensity, greaterThan(calm.rainIntensity));
      expect(heavy.rippleSpeed, greaterThan(calm.rippleSpeed));
      expect(night.reflectivity, greaterThan(calm.reflectivity));
      expect(calm.puddleRoughness, lessThan(heavy.puddleRoughness));
    });

    test('PuddleReflectionController tracks time and notifies listeners', () {
      final scaler = AdaptiveQualityScaler(initialTier: HardwareTier.high);
      final PuddleReflectionController controller = PuddleReflectionController(scaler: scaler);
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      expect(controller.time, equals(0.0));
      controller.update(0.016);
      expect(controller.time, closeTo(0.016, 1e-4));
      expect(notifyCount, equals(1));

      controller.update(0.034);
      expect(controller.time, closeTo(0.050, 1e-4));
      expect(notifyCount, equals(2));

      controller.setRainIntensity(0.75);
      expect(controller.rainIntensity, closeTo(0.75, 1e-4));
      expect(notifyCount, equals(3));

      controller.setRoughness(0.2);
      expect(controller.config.puddleRoughness, closeTo(0.2, 1e-4));
      expect(notifyCount, equals(4));

      controller.setCamera(
        position: const WorldVector3(1.0, 2.0, 3.0),
        direction: const WorldVector3(0.0, 0.0, -1.0),
      );
      expect(controller.config.cameraPosition, equals(const WorldVector3(1.0, 2.0, 3.0)));
      expect(notifyCount, equals(5));

      controller.reset();
      expect(controller.time, equals(0.0));
      expect(notifyCount, equals(6));

      controller.dispose();
      // Should not notify after disposal
      controller.update(0.1);
      expect(notifyCount, equals(6));
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Widget & CustomPainter Integration Tests
  // ---------------------------------------------------------------------------
  group('Widget & CustomPainter Integration Tests', () {
    testWidgets('PuddleReflectionLayer renders child widget and executes fallback painter without errors', (
      WidgetTester tester,
    ) async {
      final PuddleReflectionController controller = PuddleReflectionController(
        config: PuddleReflectionConfig.calmAfterRain(),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: PuddleReflectionLayer(
            controller: controller,
            child: const Text('Open World Scene Ground'),
          ),
        ),
      );

      expect(find.text('Open World Scene Ground'), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget);

      // Advance time and pump frame
      controller.update(0.033);
      await tester.pump();

      expect(tester.takeException(), isNull);
      controller.dispose();
    });

    testWidgets('PuddleReflectionPainter paints custom puddle path with fallback shader without throwing', (
      WidgetTester tester,
    ) async {
      final PuddleReflectionController controller = PuddleReflectionController(
        config: PuddleReflectionConfig.heavyDownpour(),
      );

      final Path customPath = Path()
        ..addOval(const Rect.fromLTWH(50, 100, 300, 150));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: PuddleReflectionLayer(
            controller: controller,
            customPuddlePath: customPath,
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);

      controller.update(0.1);
      await tester.pump();

      expect(tester.takeException(), isNull);
      controller.dispose();
    });
  });
}
