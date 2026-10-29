import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/world/cinematic_camera_controller.dart';
import 'package:gkk_flutter/core/world/dynamic_skybox.dart';
import 'package:gkk_flutter/core/world/puddle_reflection_layer.dart' hide WorldVector3;
import 'package:gkk_flutter/screens/home/widgets/hub_crowd_layer.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_environment_layer.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_postprocess_stack.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_scene_viewport.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_volumetric_fog.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_wind_vegetation.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

import '../golden/mobile_viewport_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Main Hub Mobile Golden & 390x844 Viewport Suite', () {
    testWidgets('HubSceneViewport with embedded 10K crowd renders properly on 390x844 without overflow', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();
      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      final HubSceneViewportController viewportController =
          HubSceneViewportController(initialHours: 18.2);

      final Widget mainHub = Scaffold(
        extendBody: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xEB0A0E1A),
              border: Border(bottom: BorderSide(color: Color(0x3338BDF8), width: 1)),
            ),
            child: const SafeArea(
              bottom: false,
              child: Row(
                children: <Widget>[
                  Icon(Icons.shield, color: AppColors.liquidGold, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aion 2 Başkent Meydanı',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          height: 60,
          color: const Color(0xEB070A12),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              Icon(Icons.home, color: AppColors.liquidGold),
              Icon(Icons.sports_kabaddi, color: AppColors.textSecondary),
              Icon(Icons.domain, color: AppColors.textSecondary),
              Icon(Icons.castle, color: AppColors.textSecondary),
            ],
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 3D Viewport Stack (includes DynamicSkybox, HubEnvironment, HubCrowdBackgroundLayer, Wind, SSR, Fog, PostProcess)
            Positioned.fill(
              child: HubSceneViewport(
                controller: viewportController,
                enablePostProcess: true,
              ),
            ),

            // Mobile HUD Safe Foreground
            SafeArea(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Flexible(
                          child: HubCrowdDensitySelector(
                            controller: viewportController.crowdController,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x990A0E1A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.6)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.bolt, size: 12, color: AppColors.liquidGold),
                              SizedBox(width: 4),
                              Text(
                                '10K MMO',
                                style: TextStyle(
                                  color: AppColors.liquidGold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xCC0E1524),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x4038BDF8)),
                          ),
                          child: const Text(
                            'Lord Kaelen · Seviye 85 · Kudret: 1.84M',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xCC0E1524),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x40F5C842)),
                          ),
                          child: const Text(
                            'Canlı Dünya Etkinliği: Ejder Kuşatması Başladı!',
                            style: TextStyle(color: AppColors.liquidGold, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 90), // Bottom navigation clearance
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: mainHub,
        ),
      );

      // Verify rendering of all visual layers
      await tester.pump(const Duration(milliseconds: 32));
      expect(find.byType(HubSceneViewport), findsOneWidget);
      expect(find.byType(DynamicSkyboxView), findsOneWidget);
      expect(find.byType(HubEnvironmentLayer), findsOneWidget);
      expect(find.byType(HubWindVegetationLayer), findsOneWidget);
      expect(find.byType(PuddleReflectionLayer), findsOneWidget);
      expect(find.byType(VolumetricFogLayer), findsOneWidget);
      expect(find.byType(HubPostProcessStack), findsOneWidget);
      expect(find.byType(HubCrowdBackgroundLayer), findsOneWidget);

      // Capture golden PNG
      final File golden = await captureWidgetToMobilePng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'hub_main_390x844_golden.png',
      );

      verifyMobileGoldenFile(golden);

      await tester.pumpWidget(const SizedBox());
      viewportController.dispose();
    });

    testWidgets('Crowd density switching updates viewport without memory leaks or layout break', (
      WidgetTester tester,
    ) async {
      final HubCrowdController crowdController = HubCrowdController();

      await tester.pumpWidget(
        buildMobileTestHarness(
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  HubCrowdDensitySelector(controller: crowdController),
                  Expanded(
                    child: HubCrowdBackgroundLayer(controller: crowdController),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(crowdController.config.density, equals(HubCrowdDensity.ultra10k));

      // Switch to Eco (1K)
      crowdController.setDensity(HubCrowdDensity.low1k);
      await tester.pump(const Duration(milliseconds: 16));
      expect(crowdController.config.density, equals(HubCrowdDensity.low1k));

      // Switch to Balanced (5K)
      crowdController.setDensity(HubCrowdDensity.medium5k);
      await tester.pump(const Duration(milliseconds: 16));
      expect(crowdController.config.density, equals(HubCrowdDensity.medium5k));

      // Switch back to Ultra (10K)
      crowdController.setDensity(HubCrowdDensity.ultra10k);
      await tester.pump(const Duration(milliseconds: 16));
      expect(crowdController.config.density, equals(HubCrowdDensity.ultra10k));

      await tester.pumpWidget(const SizedBox());
      crowdController.dispose();
    });
  });
}
