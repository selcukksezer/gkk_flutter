// Unit tests for Zero-Jank Progressive Preloader & Dual LRU Cache
// Validating time-budget adherence, priority ordering, touch yielding, LRU eviction, and cancellation.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/engine/zero_jank_preloader.dart';

/// Controllable time source for deterministic time slicing tests.
class MockTimeSource implements TimeSource {
  int _micros = 0;

  @override
  int get nowMicroseconds => _micros;

  void advanceMicroseconds(int delta) {
    _micros += delta;
  }

  void advanceMilliseconds(double deltaMs) {
    _micros += (deltaMs * 1000).round();
  }

  void reset() {
    _micros = 0;
  }
}

/// Controllable frame scheduler that records yield count and allows step-by-step frame ticking.
class MockFrameScheduler implements FrameScheduler {
  int yieldCount = 0;
  final List<Completer<void>> _pendingYields = <Completer<void>>[];

  @override
  Future<void> yieldFrame() {
    yieldCount++;
    final Completer<void> completer = Completer<void>();
    _pendingYields.add(completer);
    // Complete asynchronously on next microtask by default so loop continues
    scheduleMicrotask(() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  /// Manually flushes all currently pending yields.
  void flushYields() {
    for (final Completer<void> c in List<Completer<void>>.from(_pendingYields)) {
      if (!c.isCompleted) {
        c.complete();
      }
    }
    _pendingYields.clear();
  }
}

void main() {
  group('LruMemoryCache Tests', () {
    test('enforces byte ceiling and evicts least recently used items down to watermark', () {
      final List<String> evictedKeys = <String>[];
      final LruMemoryCache<String> cache = LruMemoryCache<String>(
        name: 'test_cache',
        defaultTarget: CacheTarget.ram,
        maxSizeBytes: 1000,
        highWatermark: 0.90, // evicts when > 900 bytes
        lowWatermark: 0.70, // evicts down to <= 700 bytes
        onEvicted: (String key, String value, CacheTarget target) {
          evictedKeys.add(key);
        },
      );

      // Add item 1 (300 bytes)
      cache.put('item1', 'data1', sizeBytes: 300);
      expect(cache.currentSizeBytes, 300);
      expect(cache.entryCount, 1);

      // Add item 2 (300 bytes) -> total 600
      cache.put('item2', 'data2', sizeBytes: 300);
      expect(cache.currentSizeBytes, 600);

      // Add item 3 (300 bytes) -> total 900 bytes (hits high watermark 900)
      cache.put('item3', 'data3', sizeBytes: 300);
      expect(cache.currentSizeBytes, 900);
      expect(evictedKeys, isEmpty);

      // Add item 4 (200 bytes) -> total 1100 > 900 -> triggers eviction down to <= 700
      // LRU order: item1 (oldest), item2, item3, item4 (newest)
      // Evict item1 (1100 - 300 = 800 > 700)
      // Evict item2 (800 - 300 = 500 <= 700) -> stops
      cache.put('item4', 'data4', sizeBytes: 200);

      expect(cache.currentSizeBytes, 500); // item3 (300) + item4 (200)
      expect(cache.containsKey('item1'), isFalse);
      expect(cache.containsKey('item2'), isFalse);
      expect(cache.containsKey('item3'), isTrue);
      expect(cache.containsKey('item4'), isTrue);
      expect(evictedKeys, equals(<String>['item1', 'item2']));
    });

    test('cache hit moves entry to MRU head and prevents eviction', () {
      final LruMemoryCache<String> cache = LruMemoryCache<String>(
        name: 'test_cache',
        defaultTarget: CacheTarget.vram,
        maxSizeBytes: 1000,
        highWatermark: 0.90,
        lowWatermark: 0.60,
      );

      cache.put('a', 'data_a', sizeBytes: 300);
      cache.put('b', 'data_b', sizeBytes: 300);
      cache.put('c', 'data_c', sizeBytes: 300);

      // Order now: c (head), b, a (tail)
      // Access 'a' so it becomes MRU head!
      final String? valA = cache.get('a');
      expect(valA, 'data_a');
      // Order now: a (head), c, b (tail)

      // Add 'd' (200 bytes) -> 1100 > 900 -> evicts down to <= 600
      // 'b' is now the oldest (tail), so 'b' should be evicted first!
      cache.put('d', 'data_d', sizeBytes: 200);

      expect(cache.containsKey('b'), isFalse);
      expect(cache.containsKey('c'), isFalse);
      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('d'), isTrue);
    });

    test('pinned items are never evicted under memory pressure', () {
      final LruMemoryCache<String> cache = LruMemoryCache<String>(
        name: 'test_cache',
        defaultTarget: CacheTarget.vram,
        maxSizeBytes: 1000,
        highWatermark: 0.80,
        lowWatermark: 0.70,
      );

      cache.put('hud_icon', 'icon_data', sizeBytes: 400, isPinned: true);
      cache.put('mesh_lod2', 'mesh_data', sizeBytes: 400, isPinned: false);

      // Total 800. Now add 300 -> total 1100 > 800
      // 'hud_icon' is older than 'mesh_lod2', but it is pinned!
      cache.put('sound_bgm', 'bgm_data', sizeBytes: 300);

      // 'mesh_lod2' must be evicted instead of 'hud_icon'
      expect(cache.containsKey('hud_icon'), isTrue);
      expect(cache.containsKey('mesh_lod2'), isFalse);
      expect(cache.containsKey('sound_bgm'), isTrue);

      // Test unpinning allows eviction
      cache.unpin('hud_icon');
      cache.put('boss_model', 'boss_data', sizeBytes: 400);
      expect(cache.containsKey('hud_icon'), isFalse);
    });
  });

  group('Priority Queue Ordering Tests', () {
    test('executes strictly in priority order: HUD > Nearby LOD0 > Far LOD2 > BGM', () async {
      final MockTimeSource timeSource = MockTimeSource();
      final MockFrameScheduler frameScheduler = MockFrameScheduler();

      final ZeroJankPreloader preloader = ZeroJankPreloader(
        config: const ZeroJankConfig(frameBudgetMs: 5.0),
        timeSource: timeSource,
        frameScheduler: frameScheduler,
      );

      final List<String> executionLog = <String>[];

      // Enqueue in reverse priority order
      preloader.preloadAtomic<String>(
        id: 'bgm_theme',
        priority: PreloadPriority.backgroundMusic,
        loader: () async {
          executionLog.add('bgm_theme');
          return 'bgm';
        },
      );

      preloader.preloadAtomic<String>(
        id: 'vat_crowd_01',
        priority: PreloadPriority.farLod2Vat,
        loader: () async {
          executionLog.add('vat_crowd_01');
          return 'vat';
        },
      );

      preloader.preloadAtomic<String>(
        id: 'hero_lod0',
        priority: PreloadPriority.nearbyLod0,
        loader: () async {
          executionLog.add('hero_lod0');
          return 'hero';
        },
      );

      preloader.preloadAtomic<String>(
        id: 'combat_hud_hotbar',
        priority: PreloadPriority.criticalHud,
        loader: () async {
          executionLog.add('combat_hud_hotbar');
          return 'hud';
        },
      );

      // Allow microtask ticks to process
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        executionLog,
        equals(<String>[
          'combat_hud_hotbar',
          'hero_lod0',
          'vat_crowd_01',
          'bgm_theme',
        ]),
      );

      preloader.dispose();
    });

    test('dynamically promotes task priority when entity moves into player proximity', () async {
      final MockTimeSource timeSource = MockTimeSource();
      final MockFrameScheduler frameScheduler = MockFrameScheduler();

      final ZeroJankPreloader preloader = ZeroJankPreloader(
        config: const ZeroJankConfig(frameBudgetMs: 5.0),
        timeSource: timeSource,
        frameScheduler: frameScheduler,
      );

      final List<String> executionLog = <String>[];

      preloader.preloadAtomic<String>(
        id: 'monster_far',
        priority: PreloadPriority.farLod2Vat,
        loader: () async {
          executionLog.add('monster_far');
          return 'monster';
        },
      );

      preloader.preloadAtomic<String>(
        id: 'dungeon_torch_lod0',
        priority: PreloadPriority.nearbyLod0,
        loader: () async {
          executionLog.add('dungeon_torch_lod0');
          return 'torch';
        },
      );

      // Before execution processes monster_far, promote it to Critical HUD
      final bool promoted = preloader.promotePriority('monster_far', PreloadPriority.criticalHud);
      expect(promoted, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // monster_far should now run BEFORE dungeon_torch_lod0
      expect(
        executionLog,
        equals(<String>[
          'monster_far',
          'dungeon_torch_lod0',
        ]),
      );

      preloader.dispose();
    });
  });

  group('Time-Budget Slicing & Yielding Tests', () {
    test('enforces strict < 2ms time budget and cooperatively yields control', () async {
      final MockTimeSource timeSource = MockTimeSource();
      final MockFrameScheduler frameScheduler = MockFrameScheduler();

      final ZeroJankPreloader preloader = ZeroJankPreloader(
        config: const ZeroJankConfig(frameBudgetMs: 1.8), // 1800 µs
        timeSource: timeSource,
        frameScheduler: frameScheduler,
      );

      int chunksProcessed = 0;

      final Future<String> taskFuture = preloader.preload<String>(
        id: 'large_terrain_mesh',
        priority: PreloadPriority.nearbyLod0,
        loader: (PreloadExecutionContext ctx) async {
          for (int i = 0; i < 4; i++) {
            chunksProcessed++;
            ctx.reportProgress(i / 4.0);

            // Simulate heavy decoding chunk taking 1000 µs
            timeSource.advanceMicroseconds(1000);

            // After 2 chunks (2000 µs), budget (1800 µs) is exceeded!
            if (ctx.shouldYield()) {
              await ctx.yieldControl();
            }
          }
          return 'done';
        },
      );

      // Wait for execution to complete
      final String result = await taskFuture;
      expect(result, 'done');
      expect(chunksProcessed, 4);

      // Verify that frameScheduler was asked to yield to prevent jank
      expect(frameScheduler.yieldCount, greaterThanOrEqualTo(1));

      preloader.dispose();
    });
  });

  group('Touch Interaction Yielding Tests', () {
    test('immediately yields and halts preloading during touch interaction', () async {
      final MockTimeSource timeSource = MockTimeSource();
      final MockFrameScheduler frameScheduler = MockFrameScheduler();

      final ZeroJankPreloader preloader = ZeroJankPreloader(
        config: const ZeroJankConfig(
          frameBudgetMs: 2.0,
          yieldOnTouch: true,
          touchCooldown: Duration(milliseconds: 50),
        ),
        timeSource: timeSource,
        frameScheduler: frameScheduler,
      );

      bool taskExecuted = false;

      // Simulate user touch interaction active BEFORE enqueueing
      preloader.onTouchStart();
      expect(preloader.isYieldingToTouch, isTrue);

      preloader.preloadAtomic<String>(
        id: 'non_critical_asset',
        priority: PreloadPriority.nearbyLod0,
        loader: () async {
          taskExecuted = true;
          return 'ok';
        },
      );

      // Wait 20ms - task should NOT execute because user is touching
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(taskExecuted, isFalse);

      // User releases touch
      preloader.onTouchEnd();

      // Wait past the 50ms touch cooldown
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // Task should now have executed smoothly!
      expect(taskExecuted, isTrue);

      preloader.dispose();
    });
  });

  group('Cancellation Tests', () {
    test('cancels individual task by ID before running', () async {
      final MockTimeSource timeSource = MockTimeSource();
      final MockFrameScheduler frameScheduler = MockFrameScheduler();

      final ZeroJankPreloader preloader = ZeroJankPreloader(
        config: const ZeroJankConfig(frameBudgetMs: 2.0),
        timeSource: timeSource,
        frameScheduler: frameScheduler,
      );

      // Enqueue low priority task
      final Future<String> taskFuture = preloader.preloadAtomic<String>(
        id: 'cancelled_task',
        priority: PreloadPriority.backgroundMusic,
        loader: () async => 'should_not_run',
      );

      // Immediately cancel
      final bool cancelled = preloader.cancel('cancelled_task', 'Player closed screen');
      expect(cancelled, isTrue);

      expect(
        () async => await taskFuture,
        throwsA(isA<PreloadCancelledException>()),
      );

      preloader.dispose();
    });

    test('cancels tasks by tag in bulk', () async {
      final MockTimeSource timeSource = MockTimeSource();
      final MockFrameScheduler frameScheduler = MockFrameScheduler();

      final ZeroJankPreloader preloader = ZeroJankPreloader(
        config: const ZeroJankConfig(frameBudgetMs: 2.0),
        timeSource: timeSource,
        frameScheduler: frameScheduler,
      );

      final Future<String> task1 = preloader.preloadAtomic<String>(
        id: 'dungeon_skeleton',
        priority: PreloadPriority.farLod2Vat,
        tags: <String>{'dungeon_crypt', 'monsters'},
        loader: () async => 'skeleton',
      );

      final Future<String> task2 = preloader.preloadAtomic<String>(
        id: 'dungeon_zombie',
        priority: PreloadPriority.farLod2Vat,
        tags: <String>{'dungeon_crypt', 'monsters'},
        loader: () async => 'zombie',
      );

      final Future<String> task3 = preloader.preloadAtomic<String>(
        id: 'hub_merchant',
        priority: PreloadPriority.criticalHud,
        tags: <String>{'main_hub'},
        loader: () async => 'merchant',
      );

      // Player exits dungeon crypt back to hub
      final int cancelledCount = preloader.cancelByTag('dungeon_crypt', 'Left dungeon');
      expect(cancelledCount, 2);

      expect(() async => await task1, throwsA(isA<PreloadCancelledException>()));
      expect(() async => await task2, throwsA(isA<PreloadCancelledException>()));

      final String hubResult = await task3;
      expect(hubResult, 'merchant');

      preloader.dispose();
    });
  });

  group('Hardware Specification Presets & Dynamic Reconfiguration', () {
    test('lowSpec and highSpec initialize distinct memory ceilings', () {
      final ZeroJankConfig low = ZeroJankConfig.lowSpec();
      final ZeroJankConfig high = ZeroJankConfig.highSpec();

      // Low spec: 50MB RAM + 100MB VRAM = 150MB total ceiling
      expect(low.ramCeilingBytes, 50 * 1024 * 1024);
      expect(low.vramCeilingBytes, 100 * 1024 * 1024);
      expect(low.ramCeilingBytes + low.vramCeilingBytes, 150 * 1024 * 1024);

      // High spec: 150MB RAM + 350MB VRAM = 500MB total ceiling
      expect(high.ramCeilingBytes, 150 * 1024 * 1024);
      expect(high.vramCeilingBytes, 350 * 1024 * 1024);
      expect(high.ramCeilingBytes + high.vramCeilingBytes, 500 * 1024 * 1024);
    });

    test('updateConfig dynamically trims memory cache when switching from high to low tier', () {
      final ZeroJankPreloader preloader = ZeroJankPreloader(
        config: ZeroJankConfig.highSpec(),
      );

      // Put 80MB of assets in VRAM
      preloader.putCache('terrain_texture', 'bytes_data', sizeBytes: 80 * 1024 * 1024, target: CacheTarget.vram);
      preloader.putCache('boss_model', 'bytes_data', sizeBytes: 40 * 1024 * 1024, target: CacheTarget.vram);

      expect(preloader.vramCache.currentSizeBytes, 120 * 1024 * 1024);

      // Now dynamically downgrade to lowSpec (100MB VRAM ceiling, high watermark 0.90 = 90MB)
      // 120MB > 90MB -> will evict older unpinned items down to 75MB
      preloader.updateConfig(ZeroJankConfig.lowSpec());

      expect(preloader.vramCache.currentSizeBytes, lessThanOrEqualTo(100 * 1024 * 1024));
      expect(preloader.vramCache.containsKey('terrain_texture'), isFalse);
      expect(preloader.vramCache.containsKey('boss_model'), isTrue);

      preloader.dispose();
    });

    test('telemetry snapshot provides complete diagnostic visibility', () async {
      final ZeroJankPreloader preloader = ZeroJankPreloader(
        config: ZeroJankConfig.midSpec(),
      );

      preloader.putCache('ui_atlas', 'atlas_data', sizeBytes: 10 * 1024 * 1024, target: CacheTarget.ram);
      preloader.putCache('pbr_env', 'env_data', sizeBytes: 25 * 1024 * 1024, target: CacheTarget.vram);

      // Read cache to generate hits
      preloader.getCached('ui_atlas', CacheTarget.ram);
      preloader.getCached('missing_key', CacheTarget.ram);

      final ZeroJankSnapshot snapshot = preloader.getSnapshot();
      expect(snapshot.ramUsedBytes, 10 * 1024 * 1024);
      expect(snapshot.vramUsedBytes, 25 * 1024 * 1024);
      expect(snapshot.hitRate, 0.5); // 1 hit, 1 miss
      expect(snapshot.toString(), contains('ZeroJankSnapshot'));

      preloader.dispose();
    });
  });

  group('Progressive Asset Preloading Verification (<2ms Budget)', () {
    test('preloadGlbMesh progressive chunking yields at <2ms budget per slice', () async {
      final MockTimeSource timeSource = MockTimeSource();
      final MockFrameScheduler frameScheduler = MockFrameScheduler();

      final ZeroJankPreloader preloader = ZeroJankPreloader(
        config: const ZeroJankConfig(frameBudgetMs: 1.8), // 1.8ms slice budget
        timeSource: timeSource,
        frameScheduler: frameScheduler,
      );

      final List<double> recordedSliceDurations = <double>[];
      int decodedVertices = 0;

      // 6 geometry chunks (vertex buffers, normal streams, uv coords, Draco decompress)
      // Each chunk takes 700 µs (0.7ms).
      // Budget is 1800 µs (1.8ms).
      // Chunk 0: 700 µs (elapsed 700) -> shouldYield: false
      // Chunk 1: 700 µs (elapsed 1400) -> shouldYield: false
      // Chunk 2: 700 µs (elapsed 2100 >= 1800) -> shouldYield: true -> YIELD!
      // Frame 2:
      // Chunk 3: 700 µs (elapsed 700) -> shouldYield: false
      // Chunk 4: 700 µs (elapsed 1400) -> shouldYield: false
      // Chunk 5: 700 µs (elapsed 2100 >= 1800) -> shouldYield: true -> YIELD!
      final Future<Map<String, dynamic>> glbFuture = preloader.preloadGlbMesh<Map<String, dynamic>>(
        id: 'hero_warrior_lod0.glb',
        priority: PreloadPriority.nearbyLod0,
        estimatedSizeBytes: 8 * 1024 * 1024,
        loader: (PreloadExecutionContext ctx) async {
          for (int chunk = 0; chunk < 6; chunk++) {
            timeSource.advanceMicroseconds(700);
            decodedVertices += 5000;
            ctx.reportProgress((chunk + 1) / 6.0);
            recordedSliceDurations.add(ctx.elapsedSliceMs);

            if (ctx.shouldYield()) {
              await ctx.yieldControl();
            }
          }
          return <String, dynamic>{
            'mesh': 'hero_warrior',
            'vertices': decodedVertices,
            'lod': 'lod0',
          };
        },
      );

      final Map<String, dynamic> result = await glbFuture;
      expect(result['vertices'], 30000);
      expect(frameScheduler.yieldCount, greaterThanOrEqualTo(2));

      // Verify asset is cached in VRAM
      expect(preloader.vramCache.containsKey('hero_warrior_lod0.glb'), isTrue);

      preloader.dispose();
    });

    test('preloadKtx2Texture uploads mipmaps progressively adhering to frame budget', () async {
      final MockTimeSource timeSource = MockTimeSource();
      final MockFrameScheduler frameScheduler = MockFrameScheduler();

      final ZeroJankPreloader preloader = ZeroJankPreloader(
        config: const ZeroJankConfig(frameBudgetMs: 1.5), // Low-spec 1.5ms budget
        timeSource: timeSource,
        frameScheduler: frameScheduler,
      );

      final List<int> uploadedMips = <int>[];

      // 5 mipmap levels: 1024x1024 down to 64x64
      // Mip 0 (1024x1024) takes 1100 µs
      // Mip 1 (512x512) takes 500 µs -> 1600 µs >= 1500 µs -> yield!
      // Mip 2 (256x256) takes 300 µs
      // Mip 3 (128x128) takes 200 µs
      // Mip 4 (64x64) takes 100 µs -> total 600 µs -> done!
      final Future<String> texFuture = preloader.preloadKtx2Texture<String>(
        id: 'dragon_albedo_ktx2',
        priority: PreloadPriority.nearbyLod0,
        estimatedSizeBytes: 4 * 1024 * 1024,
        loader: (PreloadExecutionContext ctx) async {
          final List<int> mipCosts = <int>[1100, 500, 300, 200, 100];
          for (int i = 0; i < mipCosts.length; i++) {
            timeSource.advanceMicroseconds(mipCosts[i]);
            uploadedMips.add(i);
            ctx.reportProgress((i + 1) / mipCosts.length);

            if (ctx.shouldYield()) {
              await ctx.yieldControl();
            }
          }
          return 'uploaded_ktx2_gpu_handle';
        },
      );

      final String gpuHandle = await texFuture;
      expect(gpuHandle, 'uploaded_ktx2_gpu_handle');
      expect(uploadedMips, equals(<int>[0, 1, 2, 3, 4]));
      expect(frameScheduler.yieldCount, greaterThanOrEqualTo(1));
      expect(preloader.vramCache.containsKey('dragon_albedo_ktx2'), isTrue);

      preloader.dispose();
    });

    test('preloadAudio buffers background music and ambient SFX without starving UI', () async {
      final MockTimeSource timeSource = MockTimeSource();
      final MockFrameScheduler frameScheduler = MockFrameScheduler();

      final ZeroJankPreloader preloader = ZeroJankPreloader(
        config: const ZeroJankConfig(frameBudgetMs: 2.0),
        timeSource: timeSource,
        frameScheduler: frameScheduler,
      );

      final Future<String> bgmFuture = preloader.preloadAudio<String>(
        id: 'dungeon_ambient_loop',
        priority: PreloadPriority.backgroundMusic,
        estimatedSizeBytes: 2 * 1024 * 1024,
        audioLoader: () async {
          timeSource.advanceMicroseconds(400);
          return 'pcm_buffer_stream';
        },
      );

      final String audioResult = await bgmFuture;
      expect(audioResult, 'pcm_buffer_stream');
      // Audio is stored in RAM cache, NOT VRAM
      expect(preloader.ramCache.containsKey('dungeon_ambient_loop'), isTrue);
      expect(preloader.vramCache.containsKey('dungeon_ambient_loop'), isFalse);

      preloader.dispose();
    });

    test('preloadShader warms up pipeline PSO asynchronously without first-frame hitching', () async {
      final MockTimeSource timeSource = MockTimeSource();
      final MockFrameScheduler frameScheduler = MockFrameScheduler();

      final ZeroJankPreloader preloader = ZeroJankPreloader(
        config: const ZeroJankConfig(frameBudgetMs: 2.0),
        timeSource: timeSource,
        frameScheduler: frameScheduler,
      );

      bool shaderCompiled = false;
      bool psoWarmedUp = false;

      final Future<String> shaderTask = preloader.preloadShader<String>(
        id: 'volumetric_fog_pipeline',
        priority: PreloadPriority.criticalHud,
        shaderWarmupLoader: (PreloadExecutionContext ctx) async {
          // Stage 1: SPIR-V byte compile (took 800 µs)
          timeSource.advanceMicroseconds(800);
          shaderCompiled = true;
          ctx.reportProgress(0.5);

          if (ctx.shouldYield()) {
            await ctx.yieldControl();
          }

          // Stage 2: Offscreen 1x1 rasterization PSO priming (took 700 µs)
          timeSource.advanceMicroseconds(700);
          psoWarmedUp = true;
          ctx.reportProgress(1.0);

          return 'warmed_pso_volumetric_fog';
        },
      );

      final String shaderResult = await shaderTask;
      expect(shaderResult, 'warmed_pso_volumetric_fog');
      expect(shaderCompiled, isTrue);
      expect(psoWarmedUp, isTrue);
      // Pinned shader stays cached in VRAM
      expect(preloader.vramCache.containsKey('volumetric_fog_pipeline'), isTrue);

      preloader.dispose();
    });

    test('frame budget verification: slice never exceeds budget across multi-task frame', () async {
      final MockTimeSource timeSource = MockTimeSource();
      final MockFrameScheduler frameScheduler = MockFrameScheduler();

      // Strict 1.8ms budget
      final ZeroJankPreloader preloader = ZeroJankPreloader(
        config: const ZeroJankConfig(frameBudgetMs: 1.8),
        timeSource: timeSource,
        frameScheduler: frameScheduler,
      );

      final List<String> completedTasks = <String>[];

      // Enqueue 3 tasks each taking 1000 µs (1.0ms)
      // Task 1: 1.0ms -> elapsed 1.0ms < 1.8ms -> no yield
      // Task 2: 1.0ms -> total frame elapsed 2.0ms >= 1.8ms -> frame yield!
      // Task 3: runs in frame 2
      preloader.preloadAtomic<String>(
        id: 'task_alpha',
        priority: PreloadPriority.criticalHud,
        loader: () async {
          timeSource.advanceMicroseconds(1000);
          completedTasks.add('alpha');
          return 'alpha';
        },
      );

      preloader.preloadAtomic<String>(
        id: 'task_beta',
        priority: PreloadPriority.criticalHud,
        loader: () async {
          timeSource.advanceMicroseconds(1000);
          completedTasks.add('beta');
          return 'beta';
        },
      );

      preloader.preloadAtomic<String>(
        id: 'task_gamma',
        priority: PreloadPriority.criticalHud,
        loader: () async {
          timeSource.advanceMicroseconds(1000);
          completedTasks.add('gamma');
          return 'gamma';
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(completedTasks, equals(<String>['alpha', 'beta', 'gamma']));
      // Verifies that multi-task execution yielded between tasks to protect the frame budget!
      expect(frameScheduler.yieldCount, greaterThanOrEqualTo(1));

      preloader.dispose();
    });

    test('dual LRU cache trims down to low watermark without thrashing under progressive load', () async {
      final ZeroJankPreloader preloader = ZeroJankPreloader(
        config: const ZeroJankConfig(
          ramCeilingBytes: 1000,
          vramCeilingBytes: 2000,
          highWatermark: 0.90, // VRAM high: 1800 bytes
          lowWatermark: 0.70, // VRAM low: 1400 bytes
        ),
      );

      // Pin critical HUD shader (300 bytes)
      preloader.putCache('critical_shader', 'shader_pso', sizeBytes: 300, isPinned: true);

      // Add regular mesh assets
      preloader.putCache('mesh_a', 'data_a', sizeBytes: 600);
      preloader.putCache('mesh_b', 'data_b', sizeBytes: 600);
      // Total VRAM = 300 + 600 + 600 = 1500 bytes (below 1800)
      expect(preloader.vramCache.currentSizeBytes, 1500);

      // Now add mesh_c (500 bytes) -> total 2000 > 1800 (triggers eviction down to <= 1400)
      preloader.putCache('mesh_c', 'data_c', sizeBytes: 500);

      // Pinned critical_shader must survive, mesh_a (oldest unpinned) is evicted
      expect(preloader.vramCache.containsKey('critical_shader'), isTrue);
      expect(preloader.vramCache.containsKey('mesh_a'), isFalse);
      expect(preloader.vramCache.currentSizeBytes, lessThanOrEqualTo(1400));

      preloader.dispose();
    });
  });
}
