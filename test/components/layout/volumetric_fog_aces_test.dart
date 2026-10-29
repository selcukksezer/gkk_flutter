import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/components/layout/layout_shaders.dart';

void main() {
  group('VolumetricFogMath Analytical Tests', () {
    test('calculateExponentialHeightDensity computes exponential depth falloff', () {
      final double groundDensity = VolumetricFogMath.calculateExponentialHeightDensity(
        y: 0.8,
        groundLevel: 0.8,
        baseDensity: 0.5,
        heightFalloff: 0.003,
      );
      expect(groundDensity, closeTo(0.5, 0.001));

      // Higher altitude (smaller y, e.g. 0.2) should produce near zero density due to exp(-beta * height)
      final double highAltitudeDensity = VolumetricFogMath.calculateExponentialHeightDensity(
        y: 0.2,
        groundLevel: 0.8,
        baseDensity: 0.5,
        heightFalloff: 0.003,
      );
      expect(highAltitudeDensity, lessThan(groundDensity));
      expect(highAltitudeDensity, greaterThanOrEqualTo(0.0));
    });

    test('evaluateHenyeyGreensteinPhase models forward Mie scattering', () {
      // Forward scattering: cosTheta = 1.0 (looking directly at light source)
      final double forward = VolumetricFogMath.evaluateHenyeyGreensteinPhase(
        cosTheta: 1.0,
        g: 0.75,
      );
      // Backward scattering: cosTheta = -1.0 (looking away from light source)
      final double backward = VolumetricFogMath.evaluateHenyeyGreensteinPhase(
        cosTheta: -1.0,
        g: 0.75,
      );
      // Side scattering: cosTheta = 0.0
      final double side = VolumetricFogMath.evaluateHenyeyGreensteinPhase(
        cosTheta: 0.0,
        g: 0.75,
      );

      expect(forward, greaterThan(side));
      expect(side, greaterThan(backward));
      expect(forward, greaterThan(0.0));
      expect(backward, greaterThan(0.0));
    });

    test('evaluateBeerLambertTransmittance respects exponential optical depth', () {
      final double t0 = VolumetricFogMath.evaluateBeerLambertTransmittance(0.0);
      final double t1 = VolumetricFogMath.evaluateBeerLambertTransmittance(1.0);
      final double t5 = VolumetricFogMath.evaluateBeerLambertTransmittance(5.0);

      expect(t0, equals(1.0));
      expect(t1, closeTo(math.exp(-1.0), 0.0001));
      expect(t5, closeTo(math.exp(-5.0), 0.0001));
      expect(t5, lessThan(t1));
    });

    test('evaluateMistTurbulence generates bounded sinusoidal wave field', () {
      final double mist = VolumetricFogMath.evaluateMistTurbulence(
        u: 0.5,
        v: 0.5,
        time: 1.25,
        wind: const Offset(0.02, 0.01),
        octaves: 2,
      );

      expect(mist, greaterThanOrEqualTo(0.0));
      expect(mist, lessThanOrEqualTo(1.0));
    });
  });

  group('AcesMath Filmic Curve & Color Grading Tests', () {
    test('narkowiczCurve maps linear radiance into filmic [0, 1]', () {
      expect(AcesMath.narkowiczCurve(0.0), equals(0.0));
      expect(AcesMath.narkowiczCurve(0.18), greaterThan(0.0));
      expect(AcesMath.narkowiczCurve(1.0), closeTo(0.81, 0.05));
      expect(AcesMath.narkowiczCurve(10.0), closeTo(0.99, 0.02));
      expect(AcesMath.narkowiczCurve(100.0), lessThanOrEqualTo(1.0));
    });

    test('linearToSrgb applies IEC 61966-2-1 piecewise transfer function', () {
      expect(AcesMath.linearToSrgb(0.0), equals(0.0));
      // Linear segment for small values: c * 12.92
      expect(AcesMath.linearToSrgb(0.001), closeTo(0.001 * 12.92, 0.0001));
      // Power segment for higher values
      expect(AcesMath.linearToSrgb(1.0), closeTo(1.0, 0.0001));
    });

    test('linearToGamma22 applies standard 2.2 exponent', () {
      expect(AcesMath.linearToGamma22(0.0), equals(0.0));
      expect(AcesMath.linearToGamma22(1.0), equals(1.0));
      expect(AcesMath.linearToGamma22(0.5), closeTo(math.pow(0.5, 1.0 / 2.2), 0.001));
    });

    test('calculateExposureMultiplier computes EV stops and linear factors', () {
      const AcesTonemappingConfig evConfig = AcesTonemappingConfig(
        exposure: 1.0, // +1 EV = 2^1 = 2.0x multiplier
        exposureMode: ExposureMode.evStops,
        preGain: 1.0,
      );
      expect(AcesMath.calculateExposureMultiplier(evConfig), closeTo(2.0, 0.001));

      const AcesTonemappingConfig linearConfig = AcesTonemappingConfig(
        exposure: 1.5,
        exposureMode: ExposureMode.linear,
        preGain: 2.0,
      );
      expect(AcesMath.calculateExposureMultiplier(linearConfig), closeTo(3.0, 0.001));
    });

    test('generateColorGradingMatrix generates 20-element valid color transform matrix', () {
      const AcesTonemappingConfig config = AcesTonemappingConfig(
        exposure: 0.0,
        contrast: 1.1,
        saturation: 1.2,
        colorTemperature: -0.1,
        tint: 0.05,
      );

      final List<double> matrix = AcesMath.generateColorGradingMatrix(config);
      expect(matrix.length, equals(20));

      // Check alpha row [0, 0, 0, 1, 0]
      expect(matrix[15], equals(0.0));
      expect(matrix[16], equals(0.0));
      expect(matrix[17], equals(0.0));
      expect(matrix[18], equals(1.0));
      expect(matrix[19], equals(0.0));
    });
  });

  group('VolumetricFogLayer Widget & Painter Tests', () {
    testWidgets('VolumetricFogLayer renders overlay and child', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: VolumetricFogLayer(
                isAnimated: false,
                parameters: VolumetricFogParameters(
                  density: 0.45,
                  qualityTier: FogQualityTier.medium,
                ),
                child: Text('3D Viewport Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('3D Viewport Content'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('VolumetricFogPainter shouldRepaint triggers on parameter change', (WidgetTester tester) async {
      final VolumetricFogPainter painter1 = VolumetricFogPainter(
        parameters: const VolumetricFogParameters(density: 0.4),
        animationTime: 1.0,
      );
      final VolumetricFogPainter painter2 = VolumetricFogPainter(
        parameters: const VolumetricFogParameters(density: 0.6),
        animationTime: 1.0,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });
  });

  group('AcesTonemappingLayer Widget & Vignette Tests', () {
    testWidgets('AcesTonemappingLayer renders child with ColorFilter and Vignette', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: AcesTonemappingLayer(
                config: AcesTonemappingConfig(
                  vignetteIntensity: 0.4,
                ),
                child: Center(child: Text('Cinematic Content')),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Cinematic Content'), findsOneWidget);
      expect(find.byType(ColorFiltered), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('AcesTonemappingLayer disables grading and vignette when flags are false', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: AcesTonemappingLayer(
                enableGrading: false,
                enableVignette: false,
                child: Text('Raw Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Raw Content'), findsOneWidget);
      expect(find.byType(ColorFiltered), findsNothing);
    });
  });

  group('CinematicViewportPostProcess Composable Integration Tests', () {
    testWidgets('CinematicViewportPostProcess integrates fog, ACES, and vignette on mobile viewport', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: CinematicViewportPostProcess(
                qualityPreset: ViewportQualityPreset.high,
                isAnimated: false,
                fogParameters: const VolumetricFogParameters(
                  density: 0.5,
                  lightShaftIntensity: 0.8,
                ),
                tonemapConfig: const AcesTonemappingConfig(
                  exposure: 0.2,
                  contrast: 1.15,
                  saturation: 1.1,
                  vignetteIntensity: 0.35,
                ),
                child: Container(
                  color: const Color(0xFF1E293B),
                  child: const Center(
                    child: Text('3D Hub Realm Viewport'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('3D Hub Realm Viewport'), findsOneWidget);
      expect(find.byType(VolumetricFogLayer), findsOneWidget);
      expect(find.byType(AcesTonemappingLayer), findsOneWidget);
    });

    testWidgets('CinematicViewportPostProcess respects low-end device preset', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: CinematicViewportPostProcess(
                qualityPreset: ViewportQualityPreset.low,
                isAnimated: false,
                child: const Text('Low End Scene'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Low End Scene'), findsOneWidget);
    });
  });
}
