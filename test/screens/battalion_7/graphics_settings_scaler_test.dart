import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gkk_flutter/core/engine/adaptive_quality_scaler.dart';
import 'package:gkk_flutter/screens/settings/graphics_quality_section.dart';
import 'package:gkk_flutter/screens/settings/graphics_settings_provider.dart';
import 'package:gkk_flutter/screens/settings/graphics_settings_screen.dart';
import 'package:gkk_flutter/screens/settings/graphics_settings_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('GraphicsQualityTier Presets & Footprint Calculations', () {
    test('Eco preset targets battery saver 30 FPS with 50% scale', () {
      final preset = GraphicsConfigData.presetForTier(GraphicsQualityTier.eco);
      expect(preset.tier, equals(GraphicsQualityTier.eco));
      expect(preset.targetFps, equals(30.0));
      expect(preset.resolutionScale, equals(0.50));
      expect(preset.shadowsEnabled, isFalse);
      expect(preset.volumetricFogEnabled, isFalse);
      expect(preset.volumetricFogSteps, equals(0));
      expect(preset.postProcessingEnabled, isFalse);
      expect(preset.ssaoEnabled, isFalse);
      expect(preset.bloomEnabled, isFalse);
      expect(preset.autoScalerEnabled, isTrue);
      expect(preset.estimatedRamMb, lessThan(500));
      expect(preset.estimatedVramMb, lessThan(200));
    });

    test('Low preset targets budget 30 FPS with 75% scale', () {
      final preset = GraphicsConfigData.presetForTier(GraphicsQualityTier.low);
      expect(preset.tier, equals(GraphicsQualityTier.low));
      expect(preset.targetFps, equals(30.0));
      expect(preset.resolutionScale, equals(0.75));
      expect(preset.volumetricFogEnabled, isTrue);
      expect(preset.volumetricFogSteps, equals(4));
      expect(preset.shadowsEnabled, isFalse);
    });

    test('Med preset targets balanced 60 FPS with 100% scale', () {
      final preset = GraphicsConfigData.presetForTier(GraphicsQualityTier.med);
      expect(preset.tier, equals(GraphicsQualityTier.med));
      expect(preset.targetFps, equals(60.0));
      expect(preset.resolutionScale, equals(1.0));
      expect(preset.shadowsEnabled, isTrue);
      expect(preset.shadowResolution, equals(512));
      expect(preset.volumetricFogEnabled, isTrue);
      expect(preset.volumetricFogSteps, equals(16));
      expect(preset.ssaoEnabled, isTrue);
      expect(preset.bloomEnabled, isTrue);
    });

    test('High preset targets 60 FPS with full SSAO & 1024px shadows', () {
      final preset = GraphicsConfigData.presetForTier(GraphicsQualityTier.high);
      expect(preset.tier, equals(GraphicsQualityTier.high));
      expect(preset.targetFps, equals(60.0));
      expect(preset.shadowResolution, equals(1024));
      expect(preset.volumetricFogSteps, equals(32));
      expect(preset.qualitySettings.maxActiveParticles, equals(5000));
    });

    test('Ultra preset targets 2027 AAA flagship 120 FPS with 2048px shadows & god-rays', () {
      final preset = GraphicsConfigData.presetForTier(GraphicsQualityTier.ultra);
      expect(preset.tier, equals(GraphicsQualityTier.ultra));
      expect(preset.targetFps, equals(120.0));
      expect(preset.shadowResolution, equals(2048));
      expect(preset.volumetricFogSteps, equals(64));
      expect(preset.qualitySettings.maxActiveParticles, equals(10000));
      expect(preset.qualitySettings.crowdDensityCap, equals(10000));
      expect(preset.estimatedRamMb, greaterThan(2000));
      expect(preset.estimatedVramMb, greaterThan(1200));
    });

    test('HardwareTier bidirectional mapping works correctly', () {
      expect(GraphicsQualityTier.eco.toHardwareTier(), equals(HardwareTier.eco));
      expect(GraphicsQualityTier.low.toHardwareTier(), equals(HardwareTier.low));
      expect(GraphicsQualityTier.med.toHardwareTier(), equals(HardwareTier.mid));
      expect(GraphicsQualityTier.high.toHardwareTier(), equals(HardwareTier.high));
      expect(GraphicsQualityTier.ultra.toHardwareTier(), equals(HardwareTier.ultra));

      expect(GraphicsQualityTier.fromHardwareTier(HardwareTier.eco), equals(GraphicsQualityTier.eco));
      expect(GraphicsQualityTier.fromHardwareTier(HardwareTier.mid), equals(GraphicsQualityTier.med));
      expect(GraphicsQualityTier.fromHardwareTier(HardwareTier.high), equals(GraphicsQualityTier.high));
      expect(GraphicsQualityTier.fromHardwareTier(HardwareTier.ultra), equals(GraphicsQualityTier.ultra));
    });
  });

  group('GraphicsSettingsService & Scaler Synchronization', () {
    test('setTier updates config and syncs hardware tier to AdaptiveQualityScaler', () async {
      final scaler = AdaptiveQualityScaler();
      final service = GraphicsSettingsService.createForTesting(scaler: scaler);

      await service.setTier(GraphicsQualityTier.eco);
      expect(service.config.tier, equals(GraphicsQualityTier.eco));
      expect(service.config.targetFps, equals(30.0));
      expect(scaler.currentTier, equals(HardwareTier.eco));
      expect(scaler.currentResolutionScale, equals(0.50));

      await service.setTier(GraphicsQualityTier.ultra);
      expect(service.config.tier, equals(GraphicsQualityTier.ultra));
      expect(service.config.targetFps, equals(120.0));
      expect(scaler.currentTier, equals(HardwareTier.ultra));
    });

    test('setResolutionScale updates internal render resolution within [0.5, 1.0]', () async {
      final scaler = AdaptiveQualityScaler();
      final service = GraphicsSettingsService.createForTesting(scaler: scaler);

      await service.setResolutionScale(0.65);
      expect(service.config.resolutionScale, closeTo(0.65, 0.01));
      expect(scaler.currentResolutionScale, closeTo(0.65, 0.01));

      // Test clamp lower bound
      await service.setResolutionScale(0.20);
      expect(scaler.currentResolutionScale, equals(0.50));

      // Test clamp upper bound
      await service.setResolutionScale(1.50);
      expect(scaler.currentResolutionScale, equals(1.00));
    });

    test('Feature toggles update config and recalculate estimated footprint', () async {
      final scaler = AdaptiveQualityScaler();
      final service = GraphicsSettingsService.createForTesting(scaler: scaler);

      final initialVram = service.config.estimatedVramMb;

      await service.setShadowsEnabled(false);
      expect(service.config.shadowsEnabled, isFalse);
      expect(service.config.estimatedVramMb, lessThanOrEqualTo(initialVram));

      await service.setVolumetricFogEnabled(false);
      expect(service.config.volumetricFogEnabled, isFalse);

      await service.setPostProcessingEnabled(false);
      expect(service.config.postProcessingEnabled, isFalse);
    });

    test('Persistence loads preferences correctly', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        GraphicsSettingsService.keyTier: 'high',
        GraphicsSettingsService.keyFps: 60.0,
        GraphicsSettingsService.keyResolutionScale: 0.85,
        GraphicsSettingsService.keyShadows: true,
        GraphicsSettingsService.keyShadowRes: 1024,
        GraphicsSettingsService.keyFog: true,
        GraphicsSettingsService.keyFogSteps: 32,
        GraphicsSettingsService.keyPostProcessing: true,
        GraphicsSettingsService.keyAutoScaler: true,
      });

      final service = GraphicsSettingsService.createForTesting();
      await service.load();

      expect(service.isLoaded, isTrue);
      expect(service.config.tier, equals(GraphicsQualityTier.high));
      expect(service.config.resolutionScale, closeTo(0.85, 0.01));
      expect(service.config.shadowResolution, equals(1024));
    });
  });

  group('2027 Aion-2 Graphics UI Widget Tests (390x844 Mobile Viewport)', () {
    testWidgets('GraphicsQualitySection renders on 390x844 mobile viewport', (tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GraphicsQualitySection(showAdvancedLink: true),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('GÖRSEL & KALİTE MOTORU'), findsOneWidget);

      // Verify 5 Tiers
      expect(find.text('Eco'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Med'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Ultra'), findsOneWidget);

      // Verify FPS selector options
      expect(find.text('30 FPS'), findsOneWidget);
      expect(find.text('60 FPS'), findsOneWidget);
      expect(find.text('120 FPS'), findsOneWidget);

      // Verify Memory & Load HUD
      expect(find.text('TAHMİNİ BELLEK VE MOTOR YÜKÜ'), findsOneWidget);
      expect(find.text('RAM Bütçesi'), findsOneWidget);
      expect(find.text('GPU VRAM'), findsOneWidget);

      // Verify Feature toggles
      expect(find.text('Dinamik Uyarlamalı Ölçekleyici'), findsOneWidget);
      expect(find.text('Dinamik Gölgeler'), findsOneWidget);
      expect(find.text('Volümetrik Sis & Işık Hüzmeleri'), findsOneWidget);
      expect(find.text('Post-Processing (SSAO & Bloom)'), findsOneWidget);

      // Verify Advanced Button
      expect(find.text('Detaylı Ayar'), findsOneWidget);
      expect(find.text('Önerilene Dön'), findsOneWidget);
    });

    testWidgets('Tapping Ultra tier chip updates config', (tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GraphicsQualitySection(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Ultra chip
      await tester.tap(find.text('Ultra'));
      await tester.pumpAndSettle();

      expect(find.text('ULTRA'), findsWidgets);
    });

    testWidgets('GraphicsSettingsScreen renders fine tuning & live scaler test bench', (tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: GraphicsSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Screen Header
      expect(find.text('GRAFİK VE MOTOR AYARLARI'), findsOneWidget);
      expect(find.text('DONANIM VE CİHAZ PROFİLİ'), findsOneWidget);

      // Verify Fine Tuning
      await tester.scrollUntilVisible(find.text('İNCE MOTOR AYARLARI'), 200);
      expect(find.text('İNCE MOTOR AYARLARI'), findsOneWidget);
      expect(find.text('KADEMELİ GÖLGE ÇÖZÜNÜRLÜĞÜ'), findsOneWidget);
      expect(find.text('VOLÜMETRİK SİS IŞIN ADIMLARI'), findsOneWidget);

      // Verify Live Test Bench & Telemetry
      await tester.scrollUntilVisible(find.text('CANLI ÖLÇEKLEYİCİ TELEMETRİSİ'), 200);
      expect(find.text('CANLI ÖLÇEKLEYİCİ TELEMETRİSİ'), findsOneWidget);
      expect(find.text('Kare Düşüşü Simüle Et'), findsOneWidget);
      expect(find.text('Toparlanma Simüle Et'), findsOneWidget);

      // Tap drop simulation button
      await tester.tap(find.text('Kare Düşüşü Simüle Et'));
      await tester.pumpAndSettle();
    });
  });
}
