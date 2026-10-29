import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/layout/mobile_ssao_layer.dart';
import 'package:gkk_flutter/components/layout/mobile_ssr_reflection_layer.dart';
import 'package:gkk_flutter/components/layout/viewport_postprocess_layout.dart';

void main() {
  group('MobileSsaoContactMath Tests', () {
    test('generateVogelSpiralTaps generates expected number of unit disk taps', () {
      final List<ui.Offset> taps16 = MobileSsaoContactMath.generateVogelSpiralTaps(16);
      expect(taps16.length, equals(16));

      for (final ui.Offset tap in taps16) {
        final double dist = tap.distance;
        expect(dist, lessThanOrEqualTo(1.0 + 1e-6));
        expect(dist, greaterThanOrEqualTo(0.0));
      }

      // Radius should increase monotonically with tap index
      for (int i = 0; i < taps16.length - 1; i++) {
        expect(taps16[i].distance, lessThan(taps16[i + 1].distance));
      }
    });

    test('calculateGroundContactOcclusion produces smooth contact shadow at ground plane', () {
      const double groundY = 0.65;
      const double spread = 0.30;

      // Far above contact spread -> 0 occlusion
      final double farAbove = MobileSsaoContactMath.calculateGroundContactOcclusion(
        normalizedY: 0.20,
        groundY: groundY,
        contactSpread: spread,
      );
      expect(farAbove, equals(0.0));

      // Approaching ground plane -> monotonically increasing occlusion
      final double midApproach = MobileSsaoContactMath.calculateGroundContactOcclusion(
        normalizedY: 0.50,
        groundY: groundY,
        contactSpread: spread,
      );
      final double closeApproach = MobileSsaoContactMath.calculateGroundContactOcclusion(
        normalizedY: 0.60,
        groundY: groundY,
        contactSpread: spread,
      );
      expect(midApproach, greaterThan(0.0));
      expect(closeApproach, greaterThan(midApproach));

      // At or below ground plane -> full grounding contact occlusion
      final double atGround = MobileSsaoContactMath.calculateGroundContactOcclusion(
        normalizedY: 0.65,
        groundY: groundY,
        contactSpread: spread,
      );
      expect(atGround, greaterThanOrEqualTo(1.0));
    });

    test('calculateCreviceOcclusion respects power curve and crevice darkening multiplier', () {
      final double zeroOcc = MobileSsaoContactMath.calculateCreviceOcclusion(
        cornerFactor: 0.0,
        creviceDarkening: 0.5,
      );
      expect(zeroOcc, equals(0.0));

      final double midOcc = MobileSsaoContactMath.calculateCreviceOcclusion(
        cornerFactor: 0.5,
        creviceDarkening: 0.8,
        power: 2.0,
      );
      expect(midOcc, closeTo(0.25 * 0.8, 1e-4));

      final double maxOcc = MobileSsaoContactMath.calculateCreviceOcclusion(
        cornerFactor: 1.0,
        creviceDarkening: 0.75,
      );
      expect(maxOcc, closeTo(0.75, 1e-4));
    });

    test('linearizeDepth maps depth monotonically between near and far planes', () {
      const double near = 0.1;
      const double far = 100.0;

      expect(MobileSsaoContactMath.linearizeDepth(0.0, near, far), closeTo(near, 1e-3));
      expect(MobileSsaoContactMath.linearizeDepth(1.0, near, far), closeTo(far, 1e-3));

      final double zMid = MobileSsaoContactMath.linearizeDepth(0.5, near, far);
      expect(zMid, greaterThan(near));
      expect(zMid, lessThan(far));
    });

    test('bilateralWeight strongly preserves depth silhouettes while smoothing continuous space', () {
      // Continuous surface (same depth) -> high spatial smoothing weight
      final double continuous = MobileSsaoContactMath.bilateralWeight(
        spatialDistance: 1.0,
        depthDelta: 0.0,
      );
      expect(continuous, greaterThan(0.85));

      // Discontinuous edge / silhouette (large depth delta) -> weight drops to zero
      final double silhouette = MobileSsaoContactMath.bilateralWeight(
        spatialDistance: 1.0,
        depthDelta: 1.5,
      );
      expect(silhouette, lessThan(0.001));
    });
  });

  group('MobileSsaoConfig & Controller Tests', () {
    test('MobileSsaoQuality properties match mobile specification', () {
      expect(MobileSsaoQuality.off.sampleCount, equals(0));
      expect(MobileSsaoQuality.eco.sampleCount, equals(4));
      expect(MobileSsaoQuality.medium.sampleCount, equals(8));
      expect(MobileSsaoQuality.high.sampleCount, equals(16));
      expect(MobileSsaoQuality.ultra.sampleCount, equals(24));

      expect(MobileSsaoQuality.off.frameBudgetMs, equals(0.0));
      expect(MobileSsaoQuality.eco.frameBudgetMs, lessThan(0.5));
      expect(MobileSsaoQuality.ultra.hasBilateralFiltering, isTrue);
      expect(MobileSsaoQuality.off.hasCreviceDarkening, isFalse);
    });

    test('Presets instantiate valid configurations', () {
      final MobileSsaoConfig balanced = MobileSsaoConfig.mobileBalanced();
      expect(balanced.quality, equals(MobileSsaoQuality.medium));

      final MobileSsaoConfig ultra = MobileSsaoConfig.aion2Cinematic();
      expect(ultra.quality, equals(MobileSsaoQuality.ultra));
      expect(ultra.creviceDarkening, greaterThan(0.5));

      final MobileSsaoConfig eco = MobileSsaoConfig.ecoLowSpec();
      expect(eco.quality, equals(MobileSsaoQuality.eco));
      expect(eco.enableBilateralBlur, isFalse);

      final MobileSsaoConfig dungeon = MobileSsaoConfig.dungeonCrevices();
      expect(dungeon.intensity, greaterThan(1.5));

      final MobileSsaoConfig off = MobileSsaoConfig.off();
      expect(off.quality, equals(MobileSsaoQuality.off));
      expect(off.intensity, equals(0.0));
    });

    test('MobileSsaoController state mutations trigger listeners', () {
      final MobileSsaoController controller = MobileSsaoController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setQuality(MobileSsaoQuality.ultra);
      expect(controller.quality, equals(MobileSsaoQuality.ultra));
      expect(notifyCount, equals(1));

      controller.setGroundContactHeight(0.72);
      expect(controller.config.groundContactHeight, closeTo(0.72, 1e-4));
      expect(notifyCount, equals(2));

      controller.setIntensity(1.85);
      expect(controller.config.intensity, closeTo(1.85, 1e-4));
      expect(notifyCount, equals(3));

      controller.dispose();
    });
  });

  group('MobileSsrMath Tests', () {
    test('evaluateSchlickFresnel increases at grazing angles and dampens with roughness', () {
      const double f0 = 0.0204; // water normal reflectance

      // Normal incidence (cosTheta = 1.0) -> f0
      final double normalIncidence = MobileSsrMath.evaluateSchlickFresnel(
        cosTheta: 1.0,
        f0: f0,
        roughness: 0.0,
      );
      expect(normalIncidence, closeTo(f0, 1e-4));

      // Grazing angle (cosTheta -> 0.0) -> 1.0
      final double grazing = MobileSsrMath.evaluateSchlickFresnel(
        cosTheta: 0.0,
        f0: f0,
        roughness: 0.0,
      );
      expect(grazing, closeTo(1.0, 1e-4));

      // High roughness dampens grazing specular intensity
      final double roughGrazing = MobileSsrMath.evaluateSchlickFresnel(
        cosTheta: 0.0,
        f0: f0,
        roughness: 0.8,
      );
      expect(roughGrazing, closeTo(0.2, 1e-4));
    });

    test('evaluateBeerLambertTransmittance follows exponential extinction', () {
      expect(
        MobileSsrMath.evaluateBeerLambertTransmittance(depth: 0.0, extinction: 0.5),
        equals(1.0),
      );

      final double t1 = MobileSsrMath.evaluateBeerLambertTransmittance(
        depth: 1.0,
        extinction: 1.0,
        depthScale: 1.0,
      );
      final double t2 = MobileSsrMath.evaluateBeerLambertTransmittance(
        depth: 2.0,
        extinction: 1.0,
        depthScale: 1.0,
      );
      expect(t1, closeTo(0.3678, 1e-3)); // 1/e
      expect(t2, lessThan(t1));
    });

    test('calculateEdgeFade provides smooth fade at viewport boundaries', () {
      // Center of viewport (0.5, 0.5) -> full reflection weight (1.0)
      expect(
        MobileSsrMath.calculateEdgeFade(uv: const ui.Offset(0.5, 0.5), margin: 0.1),
        closeTo(1.0, 1e-4),
      );

      // Edge of viewport (0.0, 0.5) -> 0.0
      expect(
        MobileSsrMath.calculateEdgeFade(uv: const ui.Offset(0.0, 0.5), margin: 0.1),
        equals(0.0),
      );
    });

    test('marchScreenRay marches within viewport and calculates edge weights', () {
      final (ui.Offset endUv, double edgeWeight) = MobileSsrMath.marchScreenRay(
        startUv: const ui.Offset(0.5, 0.6),
        rayDir: const ui.Offset(0.0, -1.0),
        maxSteps: 8,
        stepSize: 0.04,
        edgeFadeMargin: 0.08,
      );

      expect(endUv.dy, lessThan(0.6));
      expect(endUv.dx, closeTo(0.5, 1e-4));
      expect(edgeWeight, greaterThan(0.0));
      expect(edgeWeight, lessThanOrEqualTo(1.0));
    });

    test('generateOrganicPuddlePath creates valid non-empty closed geometry', () {
      final ui.Path path = MobileSsrMath.generateOrganicPuddlePath(
        const ui.Size(390, 844),
        844 * 0.62,
      );
      final ui.Rect bounds = path.getBounds();
      expect(bounds.width, greaterThan(100.0));
      expect(bounds.height, greaterThan(50.0));
      expect(bounds.top, greaterThanOrEqualTo(844 * 0.55));
    });
  });

  group('MobileSsrConfig & Controller Tests', () {
    test('MobileSsrQuality maxRaySteps matches specification', () {
      expect(MobileSsrQuality.off.maxRaySteps, equals(0));
      expect(MobileSsrQuality.eco.maxRaySteps, equals(4));
      expect(MobileSsrQuality.medium.maxRaySteps, equals(8));
      expect(MobileSsrQuality.high.maxRaySteps, equals(16));
      expect(MobileSsrQuality.ultra.maxRaySteps, equals(24));
    });

    test('Presets instantiate properly', () {
      final MobileSsrConfig calm = MobileSsrConfig.calmWaterPuddles();
      expect(calm.quality, equals(MobileSsrQuality.medium));

      final MobileSsrConfig stormy = MobileSsrConfig.stormyDownpour();
      expect(stormy.rainIntensity, greaterThan(0.8));

      final MobileSsrConfig aion2 = MobileSsrConfig.aion2CinematicNight();
      expect(aion2.quality, equals(MobileSsrQuality.ultra));

      final MobileSsrConfig eco = MobileSsrConfig.ecoLowSpec();
      expect(eco.quality, equals(MobileSsrQuality.eco));
    });

    test('MobileSsrController updates simulation time and configuration', () {
      final MobileSsrController controller = MobileSsrController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.update(0.016);
      expect(controller.time, closeTo(0.016, 1e-4));
      expect(notifyCount, equals(1));

      controller.setWetness(0.92);
      expect(controller.config.wetness, closeTo(0.92, 1e-4));
      expect(notifyCount, equals(2));

      controller.setRainIntensity(0.75);
      expect(controller.config.rainIntensity, closeTo(0.75, 1e-4));
      expect(notifyCount, equals(3));

      controller.reset();
      expect(controller.time, equals(0.0));

      controller.dispose();
    });
  });

  group('ViewportPostProcessLayout Integration Tests', () {
    testWidgets('Renders underlying child with SSAO and SSR viewport overlays', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                height: 844,
                child: ViewportPostProcessLayout(
                  config: ViewportPostProcessConfig.balanced(),
                  autoAnimate: false,
                  child: Container(
                    color: Colors.blueGrey,
                    child: const Center(
                      child: Text('3D Viewport Scene'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('3D Viewport Scene'), findsOneWidget);
      expect(find.byType(MobileSsaoViewport), findsOneWidget);
      expect(find.byType(MobileSsrViewport), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Quality Tier switching updates both SSAO and SSR synchronously', (WidgetTester tester) async {
      final ViewportPostProcessController controller = ViewportPostProcessController(
        config: ViewportPostProcessConfig.balanced(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: ViewportPostProcessLayout(
                controller: controller,
                autoAnimate: false,
                child: const Text('Scene Content'),
              ),
            ),
          ),
        ),
      );

      expect(controller.ssaoController.quality, equals(MobileSsaoQuality.medium));
      expect(controller.ssrController.quality, equals(MobileSsrQuality.medium));

      // Switch to Eco (low-spec mobile)
      controller.setTier(MobilePostProcessTier.eco);
      await tester.pump();
      expect(controller.ssaoController.quality, equals(MobileSsaoQuality.eco));
      expect(controller.ssrController.quality, equals(MobileSsrQuality.eco));

      // Switch to Ultra (Aion 2 Cinematic)
      controller.setTier(MobilePostProcessTier.ultra);
      await tester.pump();
      expect(controller.ssaoController.quality, equals(MobileSsaoQuality.ultra));
      expect(controller.ssrController.quality, equals(MobileSsrQuality.ultra));

      // Switch to Off
      controller.setTier(MobilePostProcessTier.off);
      await tester.pump();
      expect(controller.ssaoController.quality, equals(MobileSsaoQuality.off));
      expect(controller.ssrController.quality, equals(MobileSsrQuality.off));

      // In Off tier, layout passes child directly with zero overlay passes
      expect(find.byType(MobileSsaoViewport), findsNothing);
      expect(find.byType(MobileSsrViewport), findsNothing);
      expect(find.text('Scene Content'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Toggling SSAO and SSR passes independently', (WidgetTester tester) async {
      final ViewportPostProcessController controller = ViewportPostProcessController(
        config: ViewportPostProcessConfig.balanced(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: ViewportPostProcessLayout(
                controller: controller,
                autoAnimate: false,
                child: const Text('Modular Viewport'),
              ),
            ),
          ),
        ),
      );

      // Disable SSAO, keep SSR active
      controller.setEnableSsao(false);
      await tester.pump();
      expect(controller.ssaoController.quality, equals(MobileSsaoQuality.off));
      expect(controller.ssrController.quality, equals(MobileSsrQuality.medium));
      expect(find.byType(MobileSsaoViewport), findsNothing);
      expect(find.byType(MobileSsrViewport), findsOneWidget);

      // Disable SSR, re-enable SSAO
      controller.setEnableSsao(true);
      controller.setEnableSsr(false);
      await tester.pump();
      expect(controller.ssaoController.quality, equals(MobileSsaoQuality.medium));
      expect(controller.ssrController.quality, equals(MobileSsrQuality.off));
      expect(find.byType(MobileSsaoViewport), findsOneWidget);
      expect(find.byType(MobileSsrViewport), findsNothing);

      controller.dispose();
    });
  });
}
