import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/assets/mesh_asset_registry.dart';
import '../../../core/engine/zero_jank_preloader.dart';
import '../../../core/shaders/shader_pipeline.dart';
import '../../../core/shaders/shader_registry.dart';

/// Hardware tier profile preset for low-spec vs flagship testing.
enum DiagnosticsHardwarePreset {
  lowSpec('Low-Spec (150 MB)', 'Low RAM & VRAM, 1.5ms budget'),
  midSpec('Mid-Spec (300 MB)', 'Standard mobile, 1.8ms budget'),
  highSpec('High-Spec (500 MB)', 'Flagship SoC, 2.0ms budget'),
  ultraSpec('Ultra 2027 (1000 MB)', 'AAA Desktop/Tablet, 2.2ms budget');

  final String label;
  final String description;
  const DiagnosticsHardwarePreset(this.label, this.description);
}

/// Comprehensive report produced by verifying CC0 3D mesh asset integrity.
class AssetIntegrityReport {
  final int totalChecked;
  final int validCount;
  final int warningCount;
  final List<String> verifiedModelIds;
  final List<String> details;
  final int totalVerticesVerified;
  final int totalTrianglesVerified;
  final Duration elapsed;

  const AssetIntegrityReport({
    required this.totalChecked,
    required this.validCount,
    required this.warningCount,
    required this.verifiedModelIds,
    required this.details,
    required this.totalVerticesVerified,
    required this.totalTrianglesVerified,
    required this.elapsed,
  });

  bool get isAllValid => validCount == totalChecked && warningCount == 0;
}

/// Result of executing a manual shader warm-up batch.
class ShaderWarmupResult {
  final int shadersWarmedUp;
  final int shadersFailed;
  final double totalDurationMs;
  final List<String> warmedShaderIds;
  final String summary;

  const ShaderWarmupResult({
    required this.shadersWarmedUp,
    required this.shadersFailed,
    required this.totalDurationMs,
    required this.warmedShaderIds,
    required this.summary,
  });
}

/// Unified real-time telemetry snapshot aggregating preloader, mesh, and shader data.
class CombinedDiagnosticsSnapshot {
  final ZeroJankSnapshot preloaderSnapshot;
  final RegistryStatistics meshStats;
  final ShaderPipelineStats shaderStats;
  final DiagnosticsHardwarePreset activePreset;
  final bool isTouchYielding;
  final bool isPreloaderPaused;
  final double frameBudgetMs;
  final DateTime timestamp;

  const CombinedDiagnosticsSnapshot({
    required this.preloaderSnapshot,
    required this.meshStats,
    required this.shaderStats,
    required this.activePreset,
    required this.isTouchYielding,
    required this.isPreloaderPaused,
    required this.frameBudgetMs,
    required this.timestamp,
  });

  /// Combined memory footprint in Megabytes across RAM and VRAM.
  double get totalMemoryMb =>
      (preloaderSnapshot.ramUsedBytes +
          preloaderSnapshot.vramUsedBytes +
          meshStats.cachedMemoryBytes) /
      (1024 * 1024);

  /// Combined memory ceiling in Megabytes.
  double get totalCeilingMb =>
      (preloaderSnapshot.ramCeilingBytes +
          preloaderSnapshot.vramCeilingBytes +
          meshStats.maxCacheMemoryBytes) /
      (1024 * 1024);

  /// Combined utilization fraction (0.0 to 1.0).
  double get totalUtilizationFraction =>
      totalCeilingMb > 0 ? (totalMemoryMb / totalCeilingMb).clamp(0.0, 1.0) : 0.0;
}

/// Service coordinator managing Zero-Jank preloader telemetry, 3D asset cache
/// diagnostics, shader warm-up triggering, and hardware preset adjustments.
class PreloaderDiagnosticsService extends ChangeNotifier {
  static PreloaderDiagnosticsService? _instance;
  static PreloaderDiagnosticsService get instance =>
      _instance ??= PreloaderDiagnosticsService();

  final ZeroJankPreloader preloader;
  final MeshAssetRegistry meshRegistry;
  final ShaderPipeline shaderPipeline;

  Timer? _telemetryTimer;
  DiagnosticsHardwarePreset _currentPreset = DiagnosticsHardwarePreset.midSpec;
  AssetIntegrityReport? _lastIntegrityReport;
  ShaderWarmupResult? _lastWarmupResult;
  bool _isWarmingUp = false;
  bool _isVerifyingIntegrity = false;

  CombinedDiagnosticsSnapshot? _latestSnapshot;

  PreloaderDiagnosticsService({
    ZeroJankPreloader? preloader,
    MeshAssetRegistry? meshRegistry,
    ShaderPipeline? shaderPipeline,
  })  : preloader = preloader ?? ZeroJankPreloader.instance,
        meshRegistry = meshRegistry ?? MeshAssetRegistry.instance,
        shaderPipeline = shaderPipeline ??
            ShaderPipeline(
              registry: ShaderRegistry(loadDefaults: true),
              config: const ShaderPipelineConfig(
                enableWarmup: true,
                enableFallbacks: true,
              ),
            ) {
    _refreshSnapshot();
  }

  DiagnosticsHardwarePreset get currentPreset => _currentPreset;
  AssetIntegrityReport? get lastIntegrityReport => _lastIntegrityReport;
  ShaderWarmupResult? get lastWarmupResult => _lastWarmupResult;
  bool get isWarmingUp => _isWarmingUp;
  bool get isVerifyingIntegrity => _isVerifyingIntegrity;
  CombinedDiagnosticsSnapshot get latestSnapshot =>
      _latestSnapshot ?? _refreshSnapshot();

  // ---------------------------------------------------------------------------
  // Telemetry Polling Loop
  // ---------------------------------------------------------------------------

  /// Starts low-latency real-time telemetry polling.
  void startTelemetryPolling({Duration interval = const Duration(milliseconds: 700)}) {
    _telemetryTimer?.cancel();
    _refreshSnapshot();
    _telemetryTimer = Timer.periodic(interval, (_) {
      _refreshSnapshot();
      notifyListeners();
    });
  }

  /// Pauses telemetry polling to save battery / CPU when UI is invisible.
  void stopTelemetryPolling() {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
  }

  CombinedDiagnosticsSnapshot _refreshSnapshot() {
    final ZeroJankSnapshot pSnap = preloader.getSnapshot();
    final RegistryStatistics mStats = meshRegistry.getStats();
    final ShaderPipelineStats sStats = shaderPipeline.getPipelineStats();

    final CombinedDiagnosticsSnapshot snap = CombinedDiagnosticsSnapshot(
      preloaderSnapshot: pSnap,
      meshStats: mStats,
      shaderStats: sStats,
      activePreset: _currentPreset,
      isTouchYielding: preloader.isYieldingToTouch,
      isPreloaderPaused: preloader.isPaused,
      frameBudgetMs: preloader.config.frameBudgetMs,
      timestamp: DateTime.now(),
    );
    _latestSnapshot = snap;
    return snap;
  }

  // ---------------------------------------------------------------------------
  // Hardware Spec Tier Configuration
  // ---------------------------------------------------------------------------

  /// Dynamically updates preloader hardware preset for low-spec testing.
  void setHardwarePreset(DiagnosticsHardwarePreset preset) {
    _currentPreset = preset;
    ZeroJankConfig config;

    switch (preset) {
      case DiagnosticsHardwarePreset.lowSpec:
        config = ZeroJankConfig.lowSpec();
        break;
      case DiagnosticsHardwarePreset.midSpec:
        config = ZeroJankConfig.midSpec();
        break;
      case DiagnosticsHardwarePreset.highSpec:
        config = ZeroJankConfig.highSpec();
        break;
      case DiagnosticsHardwarePreset.ultraSpec:
        config = ZeroJankConfig.ultraSpec();
        break;
    }

    preloader.updateConfig(config);
    _refreshSnapshot();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Preloader Control
  // ---------------------------------------------------------------------------

  /// Toggles pause state of background preloading loop.
  void togglePreloaderPause() {
    if (preloader.isPaused) {
      preloader.resume();
    } else {
      preloader.pause();
    }
    _refreshSnapshot();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Cache Management
  // ---------------------------------------------------------------------------

  /// Clears Zero-Jank preloader RAM and VRAM caches.
  int clearPreloaderCaches({bool forceAll = false}) {
    final int ramCount = preloader.ramCache.clear(forceAll: forceAll);
    final int vramCount = preloader.vramCache.clear(forceAll: forceAll);
    _refreshSnapshot();
    notifyListeners();
    return ramCount + vramCount;
  }

  /// Clears 3D model mesh cache.
  void clearMeshCache() {
    meshRegistry.clearCache();
    _refreshSnapshot();
    notifyListeners();
  }

  /// Clears all caches (preloader RAM/VRAM + 3D mesh cache).
  int clearAllCaches({bool forceAll = false}) {
    final int pCount = clearPreloaderCaches(forceAll: forceAll);
    clearMeshCache();
    return pCount;
  }

  // ---------------------------------------------------------------------------
  // 3D Asset Integrity Verification
  // ---------------------------------------------------------------------------

  /// Genuinely verifies registered 3D models and cached meshes:
  /// - Inspects bounding boxes, vertex counts, LOD configurations, and license metadata.
  Future<AssetIntegrityReport> verifyAssetIntegrity() async {
    _isVerifyingIntegrity = true;
    notifyListeners();

    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> verified = <String>[];
    final List<String> details = <String>[];
    int valid = 0;
    int warnings = 0;
    int totalVerts = 0;
    int totalTris = 0;

    final List<MeshAssetMetadata> registryEntries = meshRegistry.getAll();

    for (final MeshAssetMetadata meta in registryEntries) {
      final String id = meta.id;

      bool itemValid = true;

      // 1. Verify LOD completeness
      if (meta.lods.isEmpty) {
        details.add('WARNING: Model "$id" has no registered LOD variants.');
        warnings++;
        itemValid = false;
      }

      // 2. Verify bounding box integrity
      final BoundingBox3D b = meta.bounds;
      if (b.minX > b.maxX || b.minY > b.maxY || b.minZ > b.maxZ) {
        details.add('ERROR: Model "$id" has inverted bounding box coordinates.');
        warnings++;
        itemValid = false;
      }

      // 3. Verify CC0 license tag
      if (!meta.isCc0) {
        details.add('INFO: Model "$id" uses custom license (${meta.license}).');
      }

      // 4. Verify cached mesh geometry if present in memory
      final String cacheKey = '${id}_${meta.defaultLod.name}';
      final ParsedModelMesh? cached = meshRegistry.cache.get(cacheKey);
      if (cached != null) {
        totalVerts += cached.totalVertices;
        totalTris += cached.submeshes.fold<int>(
          0,
          (int sum, ParsedSubmesh sub) => sum + sub.triangleCount,
        );

        for (final ParsedSubmesh sub in cached.submeshes) {
          if (sub.positions != null && sub.positions!.length % 3 != 0) {
            details.add('ERROR: Submesh "${sub.name}" has invalid vertex coordinates.');
            warnings++;
            itemValid = false;
          }
        }
      }

      if (itemValid) {
        valid++;
        verified.add(id);
      }
    }

    stopwatch.stop();
    _isVerifyingIntegrity = false;

    final AssetIntegrityReport report = AssetIntegrityReport(
      totalChecked: registryEntries.length,
      validCount: valid,
      warningCount: warnings,
      verifiedModelIds: verified,
      details: details,
      totalVerticesVerified: totalVerts,
      totalTrianglesVerified: totalTris,
      elapsed: stopwatch.elapsed,
    );

    _lastIntegrityReport = report;
    _refreshSnapshot();
    notifyListeners();
    return report;
  }

  // ---------------------------------------------------------------------------
  // Shader Warm-Up
  // ---------------------------------------------------------------------------

  /// Asynchronously warms up all registered shaders:
  /// compiles pipelines, binds uniform buffers, and primes offscreen targets.
  Future<ShaderWarmupResult> triggerShaderWarmup() async {
    _isWarmingUp = true;
    notifyListeners();

    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> warmed = <String>[];
    int failed = 0;

    final List<ShaderDescriptor> descriptors = shaderPipeline.registry.descriptors;

    for (final ShaderDescriptor desc in descriptors) {
      try {
        final BufferUniformTarget target = BufferUniformTarget();
        shaderPipeline.warmUpTarget(target, desc);

        // Check if uniform definitions successfully bound
        if (target.floatCount > 0 || desc.uniforms.isEmpty) {
          warmed.add(desc.id);
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
    }

    stopwatch.stop();
    _isWarmingUp = false;

    final double durationMs = stopwatch.elapsedMicroseconds / 1000.0;
    final ShaderWarmupResult result = ShaderWarmupResult(
      shadersWarmedUp: warmed.length,
      shadersFailed: failed,
      totalDurationMs: durationMs,
      warmedShaderIds: warmed,
      summary:
          'Warm-up completed: ${warmed.length} shaders primed in ${durationMs.toStringAsFixed(1)} ms ($failed failures).',
    );

    _lastWarmupResult = result;
    _refreshSnapshot();
    notifyListeners();
    return result;
  }

  @override
  void dispose() {
    stopTelemetryPolling();
    super.dispose();
  }
}
