import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gkk_flutter/core/engine/adaptive_quality_scaler.dart';
import 'package:gkk_flutter/screens/settings/graphics_quality_section.dart';
import 'package:gkk_flutter/screens/settings/graphics_settings_provider.dart';
import 'package:gkk_flutter/screens/settings/graphics_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('AdaptiveQualityScaler Unit Tests', () {
    test('Default initialization derives correct hardware tier and quality settings', () {
      final scaler = AdaptiveQualityScaler(
        profile: DeviceHardwareProfile.midSpecSnapdragon720(),
      );

      expect(scaler.currentTier, HardwareTier.mid);
      expect(scaler.currentSettings.tier, HardwareTier.mid);
      expect(scaler.currentSettings.targetFps, 60.0);
      expect(scaler.currentSettings.renderResolutionScale, 1.0);
      expect(scaler.currentSettings.volumetricFogStepCount, 16);
      expect(scaler.currentSettings.ssaoEnabled, isTrue);
      expect(scaler.currentSettings.maxActiveParticles, 2000);
      expect(scaler.currentThrottleLevel, 0);
      expect(scaler.isAutoScalingEnabled, isTrue);
    });

    test('Low-spec profile auto-detects Low tier with 30 FPS ceiling and 0.75x resolution', () {
      final scaler = AdaptiveQualityScaler(
        profile: DeviceHardwareProfile.lowSpec2GbMaliG52(),
      );

      expect(scaler.currentTier, HardwareTier.low);
      expect(scaler.targetFps, 30.0);
      expect(scaler.currentSettings.volumetricFogStepCount, 4);
      expect(scaler.currentSettings.ssaoBlurEnabled, isFalse);
      expect(scaler.currentSettings.maxActiveParticles, 500);
    });

    test('Ultra-spec profile auto-detects Ultra tier with 120 FPS and 10000 particles', () {
      final scaler = AdaptiveQualityScaler(
        profile: DeviceHardwareProfile.ultraFlagship2027(),
      );

      expect(scaler.currentTier, HardwareTier.ultra);
      expect(scaler.targetFps, 60.0); // Baseline default target
      expect(scaler.currentSettings.volumetricFogStepCount, 64);
      expect(scaler.currentSettings.maxActiveParticles, 10000);
      expect(scaler.currentSettings.shadowResolution, 2048);
      expect(scaler.currentSettings.shadowCascadeCount, 4);
    });

    test('Manual setHardwareTier updates configuration and notifies stream listeners', () async {
      final scaler = AdaptiveQualityScaler(
        profile: DeviceHardwareProfile.midSpecSnapdragon720(),
      );

      final List<QualitySettings> emittedSettings = <QualitySettings>[];
      final subscription = scaler.onSettingsChanged.listen(emittedSettings.add);

      scaler.setHardwareTier(HardwareTier.ultra);
      expect(scaler.currentTier, HardwareTier.ultra);
      expect(scaler.currentSettings.tier, HardwareTier.ultra);
      expect(scaler.currentSettings.volumetricFogStepCount, 64);
      expect(scaler.currentSettings.maxActiveParticles, 10000);

      scaler.setHardwareTier(HardwareTier.low);
      expect(scaler.currentTier, HardwareTier.low);
      expect(scaler.currentSettings.tier, HardwareTier.low);
      expect(scaler.currentSettings.maxActiveParticles, 500);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emittedSettings.length, 2);
      expect(emittedSettings[0].tier, HardwareTier.ultra);
      expect(emittedSettings[1].tier, HardwareTier.low);

      await subscription.cancel();
    });

    test('Render resolution scale is strictly clamped between 0.5x and 1.0x', () {
      final scaler = AdaptiveQualityScaler();

      scaler.setRenderResolutionScale(0.2); // Below 0.5 floor
      expect(scaler.currentResolutionScale, 0.5);

      scaler.setRenderResolutionScale(1.8); // Above 1.0 ceiling
      expect(scaler.currentResolutionScale, 1.0);

      scaler.setRenderResolutionScale(0.75);
      expect(scaler.currentResolutionScale, 0.75);
    });

    test('Dynamic downscaling triggers when frame times consistently breach budget', () {
      DateTime simulatedTime = DateTime(2026, 10, 28, 12, 0, 0);
      final scaler = AdaptiveQualityScaler(
        profile: DeviceHardwareProfile.midSpecSnapdragon720(),
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
        minimumWarmupFrames: 10,
        downscaleCooldownFrames: 5,
        clock: () => simulatedTime,
      );

      // Warmup with smooth 16ms frames
      for (int i = 0; i < 10; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 16));
        scaler.recordFrameTime(16.0, timestamp: simulatedTime);
      }
      expect(scaler.currentThrottleLevel, 0);

      // Heavy stuttering: consecutive 40ms frames (25 FPS)
      for (int i = 0; i < 20; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 40));
        scaler.recordFrameTime(40.0, timestamp: simulatedTime);
      }

      // Should have throttled to reduce GPU stress
      expect(scaler.currentThrottleLevel, greaterThanOrEqualTo(1));
      expect(scaler.totalDownscaleEvents, greaterThanOrEqualTo(1));
      expect(scaler.currentSettings.renderResolutionScale, lessThanOrEqualTo(0.75));
    });

    test('Hysteresis recovery requires 5 continuous seconds under recovery threshold', () {
      DateTime simulatedTime = DateTime(2026, 10, 28, 12, 0, 0);
      final scaler = AdaptiveQualityScaler(
        profile: DeviceHardwareProfile.midSpecSnapdragon720(),
        customTargetFps: 60.0,
        customRecoveryThresholdMs: 14.0,
        requiredStabilityDuration: const Duration(seconds: 5),
        minimumWarmupFrames: 5,
        downscaleCooldownFrames: 5,
        clock: () => simulatedTime,
      );

      // Push into throttle level 2
      for (int i = 0; i < 15; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 40));
        scaler.recordFrameTime(40.0, timestamp: simulatedTime);
      }
      expect(scaler.currentThrottleLevel, greaterThan(0));
      final int throttledLevel = scaler.currentThrottleLevel;

      // Provide 3 seconds of stable frames (not enough for 5s requirement)
      for (int i = 0; i < 30; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 100));
        scaler.recordFrameTime(10.0, timestamp: simulatedTime);
      }
      expect(scaler.currentThrottleLevel, throttledLevel); // Still throttled

      // Single spike disrupts stability
      simulatedTime = simulatedTime.add(const Duration(milliseconds: 100));
      scaler.recordFrameTime(25.0, timestamp: simulatedTime);

      // 5 full continuous seconds of stable 10ms frames
      for (int i = 0; i < 55; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 100));
        scaler.recordFrameTime(10.0, timestamp: simulatedTime);
      }

      // Upscale recovery should have fired
      expect(scaler.totalUpscaleEvents, greaterThanOrEqualTo(1));
      expect(scaler.currentThrottleLevel, lessThan(throttledLevel));
    });
  });

  group('GraphicsSettingsService & Scaler Wiring Integration Tests', () {
    test('Switching tier on GraphicsSettingsService updates AdaptiveQualityScaler', () async {
      final service = GraphicsSettingsService.instance;
      await service.resetToRecommended();

      // Eco tier test
      await service.setTier(GraphicsQualityTier.eco);
      expect(service.config.tier, GraphicsQualityTier.eco);
      expect(service.config.targetFps, 30.0);
      expect(service.config.resolutionScale, 0.50);
      expect(service.config.shadowsEnabled, isFalse);
      expect(service.config.volumetricFogEnabled, isFalse);
      expect(service.scaler.currentTier, HardwareTier.low);

      // Low tier test
      await service.setTier(GraphicsQualityTier.low);
      expect(service.config.tier, GraphicsQualityTier.low);
      expect(service.config.targetFps, 30.0);
      expect(service.config.resolutionScale, 0.75);
      expect(service.config.volumetricFogEnabled, isTrue);
      expect(service.config.volumetricFogSteps, 4);

      // Med tier test
      await service.setTier(GraphicsQualityTier.med);
      expect(service.config.tier, GraphicsQualityTier.med);
      expect(service.config.targetFps, 60.0);
      expect(service.config.resolutionScale, 1.0);
      expect(service.scaler.currentTier, HardwareTier.mid);
      expect(service.config.ssaoEnabled, isTrue);

      // High tier test
      await service.setTier(GraphicsQualityTier.high);
      expect(service.config.tier, GraphicsQualityTier.high);
      expect(service.config.targetFps, 60.0);
      expect(service.config.volumetricFogSteps, 32);
      expect(service.config.shadowResolution, 1024);
      expect(service.scaler.currentTier, HardwareTier.high);

      // Ultra tier test
      await service.setTier(GraphicsQualityTier.ultra);
      expect(service.config.tier, GraphicsQualityTier.ultra);
      expect(service.config.targetFps, 120.0);
      expect(service.config.volumetricFogSteps, 64);
      expect(service.config.shadowResolution, 2048);
      expect(service.scaler.currentTier, HardwareTier.ultra);
    });

    test('Telemetry snapshot correctly captures scaler live state', () async {
      final service = GraphicsSettingsService.instance;
      await service.setTier(GraphicsQualityTier.med);

      // Feed frame telemetry
      service.scaler.recordFrameTime(16.6);
      service.scaler.recordFrameTime(16.6);

      final telemetry = service.scaler.getTelemetry();
      expect(telemetry.tier, HardwareTier.mid);
      expect(telemetry.resolutionScale, 1.0);
      expect(telemetry.particleLimit, 2000);
      expect(telemetry.totalFramesRecorded, greaterThanOrEqualTo(2));
      expect(telemetry.rollingFps, greaterThan(0.0));
    });
  });

  group('GraphicsQualitySection Widget Tests', () {
    testWidgets('Renders all quality tier buttons and updates on user tap', (WidgetTester tester) async {
      final service = GraphicsSettingsService.instance;
      await service.resetToRecommended();

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GraphicsQualitySection(showAdvancedLink: false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and section titles are present
      expect(find.text('GÖRSEL & KALİTE MOTORU'), findsOneWidget);
      expect(find.text('KALİTE ÖN AYARI'), findsOneWidget);
      expect(find.text('HEDEF KARE HIZI (FPS)'), findsOneWidget);

      // Verify all 5 preset tier buttons are rendered
      expect(find.text('Eco'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Med'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Ultra'), findsOneWidget);

      // Verify FPS buttons are rendered
      expect(find.text('30'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);

      // Tap 'Ultra' tier button
      await tester.tap(find.text('Ultra'));
      await tester.pumpAndSettle();

      expect(service.config.tier, GraphicsQualityTier.ultra);
      expect(service.scaler.currentTier, HardwareTier.ultra);

      // Tap 'Eco' tier button
      await tester.tap(find.text('Eco'));
      await tester.pumpAndSettle();

      expect(service.config.tier, GraphicsQualityTier.eco);
      expect(service.scaler.currentTier, HardwareTier.low);
    });
  });
}
