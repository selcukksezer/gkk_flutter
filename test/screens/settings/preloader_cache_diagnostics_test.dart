import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/assets/mesh_asset_registry.dart';
import 'package:gkk_flutter/core/engine/zero_jank_preloader.dart';
import 'package:gkk_flutter/core/shaders/shader_pipeline.dart';
import 'package:gkk_flutter/core/shaders/shader_registry.dart';
import 'package:gkk_flutter/screens/settings/services/preloader_diagnostics_service.dart';
import 'package:gkk_flutter/screens/settings/widgets/preloader_cache_diagnostics_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ZeroJankPreloader preloader;
  late MeshAssetRegistry meshRegistry;
  late ShaderPipeline shaderPipeline;
  late PreloaderDiagnosticsService service;

  setUp(() {
    preloader = ZeroJankPreloader(
      config: ZeroJankConfig.midSpec(),
    );
    meshRegistry = MeshAssetRegistry();
    shaderPipeline = ShaderPipeline(
      registry: ShaderRegistry(loadDefaults: true),
      config: const ShaderPipelineConfig(enableWarmup: true),
    );
    service = PreloaderDiagnosticsService(
      preloader: preloader,
      meshRegistry: meshRegistry,
      shaderPipeline: shaderPipeline,
    );
  });

  tearDown(() {
    service.dispose();
    preloader.dispose();
  });

  group('PreloaderDiagnosticsService Unit Tests', () {
    test('initial snapshot aggregates valid preloader, mesh, and shader metrics', () {
      final CombinedDiagnosticsSnapshot snap = service.latestSnapshot;

      expect(snap.preloaderSnapshot.ramCeilingBytes, equals(100 * 1024 * 1024));
      expect(snap.preloaderSnapshot.vramCeilingBytes, equals(200 * 1024 * 1024));
      expect(snap.frameBudgetMs, equals(1.8));
      expect(snap.isPreloaderPaused, isFalse);
      expect(snap.isTouchYielding, isFalse);

      expect(snap.meshStats.totalModels, greaterThan(0));
      expect(snap.meshStats.totalCc0Models, equals(snap.meshStats.totalModels));
      expect(snap.meshStats.modelsByCategory.isNotEmpty, isTrue);

      expect(snap.shaderStats.totalRegistered, greaterThan(5));
      expect(snap.totalMemoryMb, greaterThanOrEqualTo(0.0));
      expect(snap.totalCeilingMb, greaterThan(0.0));
    });

    test('setHardwarePreset updates ZeroJankConfig ceilings and frame budgets', () {
      service.setHardwarePreset(DiagnosticsHardwarePreset.lowSpec);
      expect(preloader.config.ramCeilingBytes, equals(50 * 1024 * 1024));
      expect(preloader.config.vramCeilingBytes, equals(100 * 1024 * 1024));
      expect(preloader.config.frameBudgetMs, equals(1.5));
      expect(service.currentPreset, equals(DiagnosticsHardwarePreset.lowSpec));

      service.setHardwarePreset(DiagnosticsHardwarePreset.ultraSpec);
      expect(preloader.config.ramCeilingBytes, equals(300 * 1024 * 1024));
      expect(preloader.config.vramCeilingBytes, equals(700 * 1024 * 1024));
      expect(preloader.config.frameBudgetMs, equals(2.2));
      expect(service.currentPreset, equals(DiagnosticsHardwarePreset.ultraSpec));
    });

    test('togglePreloaderPause pauses and resumes preloader execution loop', () {
      expect(preloader.isPaused, isFalse);

      service.togglePreloaderPause();
      expect(preloader.isPaused, isTrue);
      expect(service.latestSnapshot.isPreloaderPaused, isTrue);

      service.togglePreloaderPause();
      expect(preloader.isPaused, isFalse);
      expect(service.latestSnapshot.isPreloaderPaused, isFalse);
    });

    test('verifyAssetIntegrity verifies all registered CC0 models successfully', () async {
      final AssetIntegrityReport report = await service.verifyAssetIntegrity();

      expect(report.totalChecked, greaterThan(5));
      expect(report.validCount, equals(report.totalChecked));
      expect(report.warningCount, equals(0));
      expect(report.isAllValid, isTrue);
      expect(report.verifiedModelIds.length, equals(report.totalChecked));
      expect(report.elapsed.inMicroseconds, greaterThan(0));
      expect(service.lastIntegrityReport, isNotNull);
    });

    test('triggerShaderWarmup binds uniforms and warms up shader descriptors', () async {
      final ShaderWarmupResult result = await service.triggerShaderWarmup();

      expect(result.shadersWarmedUp, greaterThan(5));
      expect(result.totalDurationMs, greaterThanOrEqualTo(0.0));
      expect(result.warmedShaderIds.isNotEmpty, isTrue);
      expect(result.summary, contains('Warm-up completed'));
      expect(service.lastWarmupResult, isNotNull);
    });

    test('clearPreloaderCaches and clearMeshCache reset memory footprints', () {
      preloader.putCache('test_vram_texture', 'dummy_data', sizeBytes: 1024 * 1024);
      expect(preloader.vramCache.currentSizeBytes, equals(1024 * 1024));

      final int purged = service.clearAllCaches(forceAll: true);
      expect(purged, greaterThanOrEqualTo(1));
      expect(preloader.vramCache.currentSizeBytes, equals(0));
      expect(meshRegistry.cache.currentMemoryBytes, equals(0));
    });
  });

  group('PreloaderCacheDiagnosticsCard Widget Tests', () {
    Widget buildTestHarness() {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PreloaderCacheDiagnosticsCard(
              diagnosticsService: service,
              autoStartPolling: false,
            ),
          ),
        ),
      );
    }

    testWidgets('renders all diagnostic cards, metrics, and preset selectors', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestHarness());
      await tester.pump();

      expect(find.text('ÖN YÜKLEYİCİ VE ÖNBELLEK DİYAGNOSTİK'), findsOneWidget);
      expect(find.text('ZERO-JANK BELLEK VE GÖREV DAĞILIMI'), findsOneWidget);
      expect(find.text('DÜŞÜK SİSTEM PROFİL TESTİ (DONANIM TAVANI)'), findsOneWidget);
      expect(find.text('3D VARLIK DEPOSU VE CC0 MODEL ÖNBELLEĞİ'), findsOneWidget);
      expect(find.text('SHADER PİPELİNE VE ISITMA (WARM-UP)'), findsOneWidget);
      expect(find.text('Tüm Önbellekleri Boşalt (RAM, VRAM, Mesh)'), findsOneWidget);

      expect(find.text('Sistem RAM'), findsOneWidget);
      expect(find.text('GPU VRAM'), findsOneWidget);
      expect(find.text('Önbellek İsabeti'), findsOneWidget);
    });

    testWidgets('switching hardware preset updates active card selection', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestHarness());
      await tester.pump();

      final lowSpecFinder = find.text('Low-Spec (150 MB)');
      expect(lowSpecFinder, findsOneWidget);

      await tester.tap(lowSpecFinder);
      await tester.pump();

      expect(service.currentPreset, equals(DiagnosticsHardwarePreset.lowSpec));
      expect(preloader.config.ramCeilingBytes, equals(50 * 1024 * 1024));
    });

    testWidgets('tapping Bütünlüğü Doğrula triggers integrity check and displays report banner', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestHarness());
      await tester.pump();

      final verifyBtn = find.text('Bütünlüğü Doğrula');
      expect(verifyBtn, findsOneWidget);

      await tester.tap(verifyBtn);
      await tester.pump();

      expect(find.textContaining('3D Varlık doğrulandı'), findsOneWidget);
    });

    testWidgets('tapping SHADER WARM-UP ÇALIŞTIR triggers warmup and shows summary banner', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestHarness());
      await tester.pump();

      final warmupBtn = find.text('SHADER WARM-UP ÇALIŞTIR');
      expect(warmupBtn, findsOneWidget);

      await tester.tap(warmupBtn);
      await tester.pump();

      expect(find.textContaining('Warm-up completed'), findsOneWidget);
    });

    testWidgets('tapping play/pause button toggles preloader loop state', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestHarness());
      await tester.pump();

      expect(find.text('ÇALIŞIYOR'), findsOneWidget);

      await tester.tap(find.text('ÇALIŞIYOR'));
      await tester.pump();

      expect(find.text('DURAKLATILDI'), findsOneWidget);
      expect(preloader.isPaused, isTrue);

      await tester.tap(find.text('DURAKLATILDI'));
      await tester.pump();

      expect(find.text('ÇALIŞIYOR'), findsOneWidget);
      expect(preloader.isPaused, isFalse);
    });

    testWidgets('tapping Tüm Önbellekleri Boşalt flushes caches and shows SnackBar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestHarness());
      await tester.pump();

      final flushBtn = find.text('Tüm Önbellekleri Boşalt (RAM, VRAM, Mesh)');
      await tester.tap(flushBtn);
      await tester.pump();

      expect(find.textContaining('Tüm önbellekler başarıyla boşaltıldı'), findsOneWidget);
    });
  });
}
