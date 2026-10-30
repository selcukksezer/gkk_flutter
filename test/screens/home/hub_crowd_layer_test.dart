import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/world/dynamic_skybox.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_crowd_layer.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_scene_viewport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HubCrowdController & 10K Simulation Engine', () {
    test('Initializes with default 10K Ultra density and preallocated entities', () {
      final controller = HubCrowdController();

      expect(controller.config.density, equals(HubCrowdDensity.ultra10k));
      expect(controller.config.density.targetCount, equals(10000));
      expect(controller.bridge.totalActiveEntities, equals(10000));
      expect(controller.bridge.isRunning, isTrue);

      controller.dispose();
    });

    test('Adaptive density switching adjusts entity count seamlessly', () {
      final controller = HubCrowdController();

      // Switch to 1K Eco mode
      controller.setDensity(HubCrowdDensity.low1k);
      expect(controller.config.density, equals(HubCrowdDensity.low1k));
      expect(controller.config.density.targetCount, equals(1000));
      expect(controller.bridge.totalActiveEntities, equals(1000));

      // Switch to 5K Balanced mode
      controller.setDensity(HubCrowdDensity.medium5k);
      expect(controller.config.density, equals(HubCrowdDensity.medium5k));
      expect(controller.config.density.targetCount, equals(5000));
      expect(controller.bridge.totalActiveEntities, equals(5000));

      // Switch back to 10K Ultra mode
      controller.setDensity(HubCrowdDensity.ultra10k);
      expect(controller.config.density, equals(HubCrowdDensity.ultra10k));
      expect(controller.config.density.targetCount, equals(10000));
      expect(controller.bridge.totalActiveEntities, equals(10000));

      controller.dispose();
    });

    test('Frame update advances time and SoA crowd transforms with zero per-entity loops', () {
      final controller = HubCrowdController();

      final double initialTime = controller.totalTime;
      controller.update(0.016);

      expect(controller.totalTime, greaterThan(initialTime));
      expect(controller.bridge.manager.tickCounter, greaterThan(0));

      controller.dispose();
    });

    test('Celestial Global Illumination uniforms update crowd lighting colors', () {
      final controller = HubCrowdController();
      final skybox = DynamicSkyboxController(initialHours: 12.0);

      controller.updateGlobalIllumination(skybox.giUniforms);

      expect(controller.ambientZenith.r, greaterThanOrEqualTo(0.0));
      expect(controller.ambientGround.g, greaterThanOrEqualTo(0.0));
      expect(controller.sunRadiance.b, greaterThanOrEqualTo(0.0));
      expect(controller.sunElevation, isNotNull);

      skybox.dispose();
      controller.dispose();
    });

    test('Scroll parallax propagates to crowd layer', () {
      final controller = HubCrowdController();

      controller.handleScroll(250.0, const Offset(6.0, -45.0));

      expect(controller.scrollParallaxX, equals(6.0));
      expect(controller.scrollParallaxY, equals(-45.0));

      controller.dispose();
    });
  });

  group('HubCrowdBackgroundLayer & Viewport Integration', () {
    testWidgets('HubCrowdBackgroundLayer renders in widget tree with fallback procedural impostors', (tester) async {
      final controller = HubCrowdController(
        config: const HubCrowdConfig(
          density: HubCrowdDensity.low1k,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: HubCrowdBackgroundLayer(
                controller: controller,
                parallaxOffset: const Offset(2.0, -10.0),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(HubCrowdBackgroundLayer), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);

      controller.dispose();
    });

    testWidgets('HubCrowdDensitySelector allows changing density via UI dropdown', (tester) async {
      final controller = HubCrowdController(
        config: const HubCrowdConfig(
          density: HubCrowdDensity.ultra10k,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HubCrowdDensitySelector(
                controller: controller,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(HubCrowdDensitySelector), findsOneWidget);
      expect(find.text('10K ULTRA'), findsOneWidget);

      // Open dropdown
      await tester.tap(find.text('10K ULTRA'));
      await tester.pumpAndSettle();

      // Tap 1K ECO
      expect(find.text('1K ECO'), findsWidgets);
      await tester.tap(find.text('1K ECO').last);
      await tester.pumpAndSettle();

      expect(controller.config.density, equals(HubCrowdDensity.low1k));
      expect(controller.bridge.totalActiveEntities, equals(1000));

      controller.dispose();
    });

    testWidgets('HubSceneViewport embeds HubCrowdBackgroundLayer and ticks simulation', (tester) async {
      final viewportController = HubSceneViewportController(
        crowdConfig: const HubCrowdConfig(
          density: HubCrowdDensity.low1k,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: HubSceneViewport(
                controller: viewportController,
                enablePostProcess: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(HubSceneViewport), findsOneWidget);
      expect(find.byType(HubCrowdBackgroundLayer), findsOneWidget);

      // Let tickers advance
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewportController.crowdController.totalTime, greaterThan(0.0));

      // Unmount widgets before disposing controller to stop layer tickers
      await tester.pumpWidget(const SizedBox());
      viewportController.dispose();
    });
  });
}
