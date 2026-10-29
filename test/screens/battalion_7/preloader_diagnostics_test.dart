import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/assets/mesh_asset_registry.dart';
import 'package:gkk_flutter/core/engine/zero_jank_preloader.dart';
import 'package:gkk_flutter/screens/settings/services/preloader_diagnostics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZeroJankPreloader Architecture & Budget Tests', () {
    test('ZeroJankConfig default and low-spec presets strictly enforce <2ms budget', () {
      const defaultConfig = ZeroJankConfig();
      expect(defaultConfig.frameBudgetMs, lessThanOrEqualTo(2.0));
      expect(defaultConfig.frameBudgetMs, 1.8);
      expect(defaultConfig.yieldOnTouch, isTrue);

      final lowSpecConfig = ZeroJankConfig.lowSpec();
      expect(lowSpecConfig.frameBudgetMs, lessThanOrEqualTo(1.5));
      // Combined ceiling: 50MB RAM + 100MB VRAM = 150MB total ceiling
      expect(lowSpecConfig.ramCeilingBytes, 50 * 1024 * 1024);
      expect(lowSpecConfig.vramCeilingBytes, 100 * 1024 * 1024);

      final ultraConfig = ZeroJankConfig.ultraSpec();
      expect(ultraConfig.frameBudgetMs, lessThanOrEqualTo(2.5));
      expect(ultraConfig.ramCeilingBytes, 300 * 1024 * 1024);
      expect(ultraConfig.vramCeilingBytes, 700 * 1024 * 1024);
    });

    test('PreloadPriority correctly enforces strict priority ranks', () {
      expect(PreloadPriority.criticalHud.isHigherThan(PreloadPriority.nearbyLod0), isTrue);
      expect(PreloadPriority.nearbyLod0.isHigherThan(PreloadPriority.farLod2Vat), isTrue);
      expect(PreloadPriority.farLod2Vat.isHigherThan(PreloadPriority.backgroundMusic), isTrue);
      expect(PreloadPriority.backgroundMusic.isHigherThan(PreloadPriority.criticalHud), isFalse);
    });

    test('LruMemoryCache enforces high watermark eviction and honors item pinning', () {
      final cache = LruMemoryCache<String>(
        name: 'Test_VRAM_Cache',
        defaultTarget: CacheTarget.vram,
        maxSizeBytes: 1000,
        highWatermark: 0.90, // Evicts at 900 bytes
        lowWatermark: 0.70,  // Evicts down to 700 bytes
      );

      // Insert 3 items of 300 bytes each = 900 bytes
      cache.put('asset_1', 'mesh_data_1', sizeBytes: 300);
      cache.put('asset_2', 'mesh_data_2', sizeBytes: 300);
      cache.put('asset_3', 'mesh_data_3', sizeBytes: 300);

      expect(cache.currentSizeBytes, 900);
      expect(cache.containsKey('asset_1'), isTrue);

      // Pin asset_1 so it cannot be evicted
      final bool pinned = cache.pin('asset_1');
      expect(pinned, isTrue);

      // Insert asset_4 (200 bytes) -> total would be 1100 > 900 -> triggers eviction down to <= 700
      cache.put('asset_4', 'mesh_data_4', sizeBytes: 200);

      // asset_1 must remain because it is pinned
      expect(cache.containsKey('asset_1'), isTrue);
      // asset_4 is MRU so it remains
      expect(cache.containsKey('asset_4'), isTrue);
      // asset_2 (oldest unpinned) was evicted
      expect(cache.containsKey('asset_2'), isFalse);
      expect(cache.currentSizeBytes, lessThanOrEqualTo(700));
      expect(cache.evictionCount, greaterThanOrEqualTo(1));
    });

    test('Touch yielding pauses preloader immediately on pointer down', () {
      final preloader = ZeroJankPreloader(
        config: const ZeroJankConfig(
          yieldOnTouch: true,
          touchCooldown: Duration(milliseconds: 50),
        ),
      );

      expect(preloader.isYieldingToTouch, isFalse);

      // User finger touches screen
      preloader.onTouchStart();
      expect(preloader.isYieldingToTouch, isTrue);

      // Multiple fingers (multitouch)
      preloader.onTouchStart();
      expect(preloader.isYieldingToTouch, isTrue);

      // Lift first finger
      preloader.onTouchEnd();
      expect(preloader.isYieldingToTouch, isTrue);

      // Lift second finger -> cooldown active
      preloader.onTouchEnd();
      expect(preloader.isYieldingToTouch, isTrue);
    });

    test('ZeroJankSnapshot reflects accurate memory metrics and task counts', () {
      final preloader = ZeroJankPreloader(
        config: const ZeroJankConfig(
          ramCeilingBytes: 50 * 1024 * 1024,
          vramCeilingBytes: 100 * 1024 * 1024,
        ),
      );

      preloader.ramCache.put('ui_icon_1', 'raw_bytes', sizeBytes: 1024 * 1024);
      preloader.vramCache.put('tex_albedo', 'gpu_texture', sizeBytes: 5 * 1024 * 1024);

      final snapshot = preloader.getSnapshot();
      expect(snapshot.ramUsedBytes, 1024 * 1024);
      expect(snapshot.vramUsedBytes, 5 * 1024 * 1024);
      expect(snapshot.ramCeilingBytes, 50 * 1024 * 1024);
      expect(snapshot.vramCeilingBytes, 100 * 1024 * 1024);
      expect(snapshot.ramUsageFraction, closeTo(0.02, 0.005));
      expect(snapshot.vramUsageFraction, closeTo(0.05, 0.005));
      expect(snapshot.currentFrameBudgetMs, 1.8);
    });
  });

  group('PreloaderDiagnosticsService Integration Tests', () {
    test('Service provides consolidated diagnostics across preloader and mesh registry', () {
      final service = PreloaderDiagnosticsService.instance;
      final snapshot = service.latestSnapshot;

      expect(snapshot.preloaderSnapshot, isNotNull);
      expect(snapshot.meshStats, isNotNull);
      expect(snapshot.shaderStats, isNotNull);
      expect(snapshot.activePreset, DiagnosticsHardwarePreset.midSpec);
      expect(snapshot.totalCeilingMb, greaterThan(0.0));
      expect(snapshot.totalUtilizationFraction, greaterThanOrEqualTo(0.0));
      expect(snapshot.totalUtilizationFraction, lessThanOrEqualTo(1.0));
    });

    test('Setting hardware preset updates ZeroJankPreloader memory ceilings and budgets', () {
      final service = PreloaderDiagnosticsService.instance;

      // Switch to Low-Spec (150 MB ceiling, 1.5ms budget)
      service.setHardwarePreset(DiagnosticsHardwarePreset.lowSpec);
      expect(service.currentPreset, DiagnosticsHardwarePreset.lowSpec);
      expect(service.preloader.config.frameBudgetMs, 1.5);
      expect(service.preloader.config.ramCeilingBytes, 50 * 1024 * 1024);
      expect(service.preloader.config.vramCeilingBytes, 100 * 1024 * 1024);

      // Switch to Ultra (1000 MB ceiling, 2.2ms budget)
      service.setHardwarePreset(DiagnosticsHardwarePreset.ultraSpec);
      expect(service.currentPreset, DiagnosticsHardwarePreset.ultraSpec);
      expect(service.preloader.config.frameBudgetMs, 2.2);
      expect(service.preloader.config.ramCeilingBytes, 300 * 1024 * 1024);
      expect(service.preloader.config.vramCeilingBytes, 700 * 1024 * 1024);

      // Revert to Mid-Spec
      service.setHardwarePreset(DiagnosticsHardwarePreset.midSpec);
      expect(service.currentPreset, DiagnosticsHardwarePreset.midSpec);
    });

    test('Cache clearing genuinely flushes RAM, VRAM, and mesh cache entries', () {
      final service = PreloaderDiagnosticsService.instance;

      service.preloader.ramCache.put('temp_1', 'data', sizeBytes: 2000);
      service.preloader.vramCache.put('temp_2', 'data', sizeBytes: 4000);
      expect(service.preloader.ramCache.currentSizeBytes, greaterThan(0));
      expect(service.preloader.vramCache.currentSizeBytes, greaterThan(0));

      final int evicted = service.clearPreloaderCaches(forceAll: true);
      expect(evicted, greaterThanOrEqualTo(2));
      expect(service.preloader.ramCache.currentSizeBytes, 0);
      expect(service.preloader.vramCache.currentSizeBytes, 0);

      service.clearAllCaches(forceAll: true);
      expect(service.latestSnapshot.preloaderSnapshot.ramUsedBytes, 0);
      expect(service.latestSnapshot.preloaderSnapshot.vramUsedBytes, 0);
    });

    test('Asset integrity verification inspects registered 3D models genuinely', () async {
      final service = PreloaderDiagnosticsService.instance;
      final report = await service.verifyAssetIntegrity();

      expect(report.totalChecked, greaterThan(0));
      expect(report.validCount, greaterThan(0));
      expect(report.verifiedModelIds, isNotEmpty);
      expect(report.elapsed.inMilliseconds, greaterThanOrEqualTo(0));
      expect(service.lastIntegrityReport, isNotNull);
      expect(service.isVerifyingIntegrity, isFalse);
    });

    test('Preloader pause and resume toggles processing state correctly', () {
      final service = PreloaderDiagnosticsService.instance;
      final bool wasPaused = service.preloader.isPaused;

      service.togglePreloaderPause();
      expect(service.preloader.isPaused, !wasPaused);

      service.togglePreloaderPause();
      expect(service.preloader.isPaused, wasPaused);
    });
  });
}
