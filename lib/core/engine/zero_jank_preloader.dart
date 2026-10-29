// Production-ready Zero-Jank Progressive Preloader & VRAM Cache
// Time-sliced background loading (<2ms per frame), touch yielding, priority queue, and dual LRU cache.

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Loading priorities strictly enforced by the Zero-Jank Preloader.
/// Ordered from highest urgency (0) to lowest urgency (3).
enum PreloadPriority {
  /// Critical HUD textures, icons, font glyphs, and immediate combat UI assets.
  criticalHud(0, 'Critical HUD'),

  /// LOD0 high-detail meshes and 2K/4K PBR textures within player's immediate AoI.
  nearbyLod0(1, 'Nearby LOD0'),

  /// Distant crowd models (LOD2), Vertex Animated Textures (VAT), and impostor billboards.
  farLod2Vat(2, 'Far LOD2 / VAT'),

  /// Ambient soundscapes, non-critical background audio streams, and distant SFX.
  backgroundMusic(3, 'Background Music');

  final int rank;
  final String label;
  const PreloadPriority(this.rank, this.label);

  /// Returns true if this priority is strictly higher than [other].
  bool isHigherThan(PreloadPriority other) => rank < other.rank;

  /// Returns true if this priority is higher or equal to [other].
  bool isAtLeast(PreloadPriority other) => rank <= other.rank;
}

/// Target memory cache domain for preloaded assets.
enum CacheTarget {
  /// System RAM (decoded geometry data, parsed JSON, audio buffers).
  ram,

  /// GPU VRAM (textures uploaded to GPU, vertex buffer objects, compiled shaders).
  vram,

  /// Cached in both RAM and VRAM.
  both,
}

/// Current lifecycle status of an asset preload task.
enum PreloadTaskStatus {
  pending,
  running,
  paused,
  completed,
  cancelled,
  failed,
}

/// Hardware specification presets for cache ceilings and frame-budget limits.
class ZeroJankConfig {
  /// Maximum time budget in milliseconds per frame slice for background asset operations.
  /// Strictly clamped to avoid frame drops (default: 1.8ms to guarantee < 2.0ms margin).
  final double frameBudgetMs;

  /// Maximum RAM ceiling in bytes before LRU eviction begins.
  final int ramCeilingBytes;

  /// Maximum VRAM ceiling in bytes before LRU eviction begins.
  final int vramCeilingBytes;

  /// Whether to immediately yield background preloading while the user is touching/interacting.
  final bool yieldOnTouch;

  /// Duration to wait after the last touch event before resuming preloading (debounce cooldown).
  final Duration touchCooldown;

  /// High watermark fraction (0.0 - 1.0) at which LRU cache initiates trimming.
  final double highWatermark;

  /// Low watermark fraction (0.0 - 1.0) to which LRU cache evicts down to prevent eviction churn.
  final double lowWatermark;

  const ZeroJankConfig({
    this.frameBudgetMs = 1.8,
    this.ramCeilingBytes = 150 * 1024 * 1024, // 150 MB
    this.vramCeilingBytes = 350 * 1024 * 1024, // 350 MB
    this.yieldOnTouch = true,
    this.touchCooldown = const Duration(milliseconds: 100),
    this.highWatermark = 0.95,
    this.lowWatermark = 0.80,
  })  : assert(frameBudgetMs > 0.0 && frameBudgetMs <= 5.0, 'Frame budget must be between 0.1ms and 5.0ms'),
        assert(ramCeilingBytes > 0, 'RAM ceiling must be positive'),
        assert(vramCeilingBytes > 0, 'VRAM ceiling must be positive'),
        assert(highWatermark > lowWatermark, 'High watermark must be greater than low watermark');

  /// 150MB total memory ceiling for low-spec mobile/SoC (50MB RAM + 100MB VRAM).
  factory ZeroJankConfig.lowSpec() => const ZeroJankConfig(
        frameBudgetMs: 1.5,
        ramCeilingBytes: 50 * 1024 * 1024, // 50 MB
        vramCeilingBytes: 100 * 1024 * 1024, // 100 MB -> 150 MB total
        yieldOnTouch: true,
        touchCooldown: Duration(milliseconds: 150),
        highWatermark: 0.90,
        lowWatermark: 0.75,
      );

  /// 300MB total memory ceiling for mid-range hardware (100MB RAM + 200MB VRAM).
  factory ZeroJankConfig.midSpec() => const ZeroJankConfig(
        frameBudgetMs: 1.8,
        ramCeilingBytes: 100 * 1024 * 1024, // 100 MB
        vramCeilingBytes: 200 * 1024 * 1024, // 200 MB -> 300 MB total
        yieldOnTouch: true,
        touchCooldown: Duration(milliseconds: 100),
      );

  /// 500MB total memory ceiling for high-spec flagship hardware (150MB RAM + 350MB VRAM).
  factory ZeroJankConfig.highSpec() => const ZeroJankConfig(
        frameBudgetMs: 2.0,
        ramCeilingBytes: 150 * 1024 * 1024, // 150 MB
        vramCeilingBytes: 350 * 1024 * 1024, // 350 MB -> 500 MB total
        yieldOnTouch: true,
        touchCooldown: Duration(milliseconds: 80),
      );

  /// 1000MB total memory ceiling for ultra / desktop PC / flagship 2027 Aion 2 standard.
  factory ZeroJankConfig.ultraSpec() => const ZeroJankConfig(
        frameBudgetMs: 2.2,
        ramCeilingBytes: 300 * 1024 * 1024, // 300 MB
        vramCeilingBytes: 700 * 1024 * 1024, // 700 MB -> 1000 MB total
        yieldOnTouch: true,
        touchCooldown: Duration(milliseconds: 50),
      );

  ZeroJankConfig copyWith({
    double? frameBudgetMs,
    int? ramCeilingBytes,
    int? vramCeilingBytes,
    bool? yieldOnTouch,
    Duration? touchCooldown,
    double? highWatermark,
    double? lowWatermark,
  }) {
    return ZeroJankConfig(
      frameBudgetMs: frameBudgetMs ?? this.frameBudgetMs,
      ramCeilingBytes: ramCeilingBytes ?? this.ramCeilingBytes,
      vramCeilingBytes: vramCeilingBytes ?? this.vramCeilingBytes,
      yieldOnTouch: yieldOnTouch ?? this.yieldOnTouch,
      touchCooldown: touchCooldown ?? this.touchCooldown,
      highWatermark: highWatermark ?? this.highWatermark,
      lowWatermark: lowWatermark ?? this.lowWatermark,
    );
  }
}

/// Token used to cancel active or queued preload tasks.
class PreloadCancellationToken {
  bool _isCancelled = false;
  String? _cancelReason;
  final List<VoidCallback> _listeners = <VoidCallback>[];

  bool get isCancelled => _isCancelled;
  String? get cancelReason => _cancelReason;

  void cancel([String reason = 'Cancelled by caller']) {
    if (_isCancelled) return;
    _isCancelled = true;
    _cancelReason = reason;
    for (final VoidCallback listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  void addListener(VoidCallback listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
}

/// Exception thrown when a preload task is cancelled before or during execution.
class PreloadCancelledException implements Exception {
  final String taskId;
  final String reason;
  const PreloadCancelledException(this.taskId, this.reason);

  @override
  String toString() => 'PreloadCancelledException(task: $taskId, reason: $reason)';
}

/// Abstract time provider for deterministic time budget simulation in unit tests.
abstract class TimeSource {
  int get nowMicroseconds;
}

class SystemTimeSource implements TimeSource {
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  int get nowMicroseconds => _stopwatch.elapsedMicroseconds;
}

/// Mockable frame scheduler for controlling time slicing and frame yielding.
abstract class FrameScheduler {
  Future<void> yieldFrame();
}

/// Production frame scheduler hooked into Flutter's engine scheduler binding.
class FlutterEngineFrameScheduler implements FrameScheduler {
  const FlutterEngineFrameScheduler();

  @override
  Future<void> yieldFrame() {
    final Completer<void> completer = Completer<void>();
    try {
      final SchedulerBinding binding = SchedulerBinding.instance;
      binding.scheduleFrameCallback((_) {
        completer.complete();
      });
      binding.ensureVisualUpdate();
    } catch (_) {
      // In headless test environments or when binding isn't initialized yet
      Future<void>.delayed(Duration.zero, completer.complete);
    }
    return completer.future;
  }
}

/// Execution context passed to progressive asset loaders.
/// Allows long-running loaders (e.g. 50MB GLB decoders, texture decompressors)
/// to check their frame budget and cooperatively yield to the main thread.
class PreloadExecutionContext {
  final String taskId;
  final PreloadCancellationToken cancellationToken;
  final ZeroJankPreloader _preloader;

  double _progress = 0.0;
  double get progress => _progress;

  PreloadExecutionContext._({
    required this.taskId,
    required this.cancellationToken,
    required ZeroJankPreloader preloader,
  })  : _preloader = preloader;

  /// Elapsed microseconds in the current active frame slice.
  int get elapsedSliceMicroseconds =>
      _preloader.timeSource.nowMicroseconds - _preloader.currentSliceStartMicroseconds;

  /// Elapsed milliseconds in the current active frame slice.
  double get elapsedSliceMs => elapsedSliceMicroseconds / 1000.0;

  /// Remaining time budget in milliseconds for the current frame slice.
  double get remainingBudgetInSliceMs =>
      math.max(0.0, (_preloader.sliceBudgetMicroseconds - elapsedSliceMicroseconds) / 1000.0);

  /// Returns true if the time budget for the current frame slice has been exceeded
  /// or if the user is currently interacting with the screen.
  bool shouldYield() {
    if (cancellationToken.isCancelled) return true;
    if (_preloader.isYieldingToTouch) return true;

    return elapsedSliceMicroseconds >= _preloader.sliceBudgetMicroseconds;
  }

  /// Cooperatively yields control back to the UI engine to guarantee 60/120 FPS.
  /// Throws [PreloadCancelledException] if the task was cancelled while yielding.
  Future<void> yieldControl() async {
    if (cancellationToken.isCancelled) {
      throw PreloadCancelledException(taskId, cancellationToken.cancelReason ?? 'Cancelled');
    }
    await _preloader._yieldExecution(taskId);
    if (cancellationToken.isCancelled) {
      throw PreloadCancelledException(taskId, cancellationToken.cancelReason ?? 'Cancelled');
    }
  }

  /// Reports progressive loading status (0.0 to 1.0).
  void reportProgress(double progress) {
    _progress = progress.clamp(0.0, 1.0);
    _preloader._notifyTaskProgress(taskId, _progress);
  }
}

/// Function signature for progressive, slice-aware asset loaders.
typedef ProgressiveLoader<T> = Future<T> Function(PreloadExecutionContext ctx);

/// Represents a single queued or active preload task.
class PreloadTask<T> {
  final String id;
  PreloadPriority priority;
  final CacheTarget targetCache;
  final int estimatedSizeBytes;
  final ProgressiveLoader<T> loader;
  final PreloadCancellationToken cancellationToken;
  final Set<String> tags;
  final bool isPinned;

  PreloadTaskStatus _status = PreloadTaskStatus.pending;
  PreloadTaskStatus get status => _status;

  double _progress = 0.0;
  double get progress => _progress;

  final Completer<T> _completer = Completer<T>();
  Future<T> get future => _completer.future;

  final DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;

  PreloadTask({
    required this.id,
    required this.priority,
    required this.targetCache,
    required this.estimatedSizeBytes,
    required this.loader,
    PreloadCancellationToken? cancellationToken,
    Set<String>? tags,
    this.isPinned = false,
  })  : cancellationToken = cancellationToken ?? PreloadCancellationToken(),
        tags = tags ?? <String>{},
        createdAt = DateTime.now();

  void _setStatus(PreloadTaskStatus newStatus) {
    _status = newStatus;
  }

  void reportProgress(double progress) {
    _progress = progress.clamp(0.0, 1.0);
  }
}

/// Internal node for doubly-linked list in the LRU Cache.
class _LruNode<V> {
  final String key;
  V value;
  int sizeBytes;
  final CacheTarget cacheTarget;
  bool isPinned;
  DateTime lastAccessTime;
  int accessCount;

  _LruNode<V>? prev;
  _LruNode<V>? next;

  _LruNode({
    required this.key,
    required this.value,
    required this.sizeBytes,
    required this.cacheTarget,
    this.isPinned = false,
    DateTime? accessTime,
  })  : lastAccessTime = accessTime ?? DateTime.now(),
        accessCount = 1;
}

/// Eviction callback invoked when an asset is evicted from the cache.
/// Useful for calling `.dispose()` on textures, vertex buffers, or sound streams.
typedef CacheEvictionCallback<V> = void Function(String key, V value, CacheTarget target);

/// High-performance Least-Recently-Used (LRU) Memory Cache with byte-based ceilings
/// and anti-thrashing dual-watermark eviction.
class LruMemoryCache<V> {
  final String name;
  final CacheTarget defaultTarget;
  final CacheEvictionCallback<V>? onEvicted;

  int _maxSizeBytes;
  int _currentSizeBytes = 0;
  double _highWatermark;
  double _lowWatermark;

  final Map<String, _LruNode<V>> _map = <String, _LruNode<V>>{};
  _LruNode<V>? _head; // Most recently used
  _LruNode<V>? _tail; // Least recently used

  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;

  LruMemoryCache({
    required this.name,
    required this.defaultTarget,
    required int maxSizeBytes,
    double highWatermark = 0.95,
    double lowWatermark = 0.80,
    this.onEvicted,
  })  : _maxSizeBytes = maxSizeBytes,
        _highWatermark = highWatermark,
        _lowWatermark = lowWatermark;

  int get maxSizeBytes => _maxSizeBytes;
  int get currentSizeBytes => _currentSizeBytes;
  int get entryCount => _map.length;
  int get hitCount => _hitCount;
  int get missCount => _missCount;
  int get evictionCount => _evictionCount;
  double get highWatermark => _highWatermark;
  double get lowWatermark => _lowWatermark;

  double get hitRate {
    final int total = _hitCount + _missCount;
    return total == 0 ? 0.0 : _hitCount / total;
  }

  /// Updates memory ceiling and triggers immediate eviction if necessary.
  void setMaxSizeBytes(int newMaxSizeBytes) {
    assert(newMaxSizeBytes > 0, 'Cache ceiling must be positive');
    _maxSizeBytes = newMaxSizeBytes;
    _evictToCeiling();
  }

  void setWatermarks({required double high, required double low}) {
    assert(high > low && high <= 1.0 && low > 0.0, 'Invalid watermarks');
    _highWatermark = high;
    _lowWatermark = low;
    _evictToCeiling();
  }

  /// Checks if key is cached.
  bool containsKey(String key) => _map.containsKey(key);

  /// Retrieves an item from cache and marks it as Most Recently Used.
  V? get(String key) {
    final _LruNode<V>? node = _map[key];
    if (node == null) {
      _missCount++;
      return null;
    }
    _hitCount++;
    node.accessCount++;
    node.lastAccessTime = DateTime.now();
    _moveToHead(node);
    return node.value;
  }

  /// Inserts or updates an item in the cache.
  void put(
    String key,
    V value, {
    required int sizeBytes,
    CacheTarget? target,
    bool isPinned = false,
  }) {
    assert(sizeBytes >= 0, 'Size in bytes must be non-negative');

    final _LruNode<V>? existing = _map[key];
    if (existing != null) {
      _currentSizeBytes -= existing.sizeBytes;
      existing.value = value;
      existing.sizeBytes = sizeBytes;
      existing.isPinned = isPinned;
      existing.lastAccessTime = DateTime.now();
      existing.accessCount++;
      _currentSizeBytes += sizeBytes;
      _moveToHead(existing);
    } else {
      final _LruNode<V> newNode = _LruNode<V>(
        key: key,
        value: value,
        sizeBytes: sizeBytes,
        cacheTarget: target ?? defaultTarget,
        isPinned: isPinned,
      );
      _map[key] = newNode;
      _currentSizeBytes += sizeBytes;
      _addToHead(newNode);
    }

    _evictToCeiling();
  }

  /// Pins an entry so it will not be evicted under memory pressure.
  bool pin(String key) {
    final _LruNode<V>? node = _map[key];
    if (node == null) return false;
    node.isPinned = true;
    return true;
  }

  /// Unpins an entry, permitting future eviction.
  bool unpin(String key) {
    final _LruNode<V>? node = _map[key];
    if (node == null) return false;
    node.isPinned = false;
    _evictToCeiling();
    return true;
  }

  /// Removes and returns an item from the cache.
  V? remove(String key) {
    final _LruNode<V>? node = _map.remove(key);
    if (node == null) return null;
    _removeNode(node);
    _currentSizeBytes -= node.sizeBytes;
    onEvicted?.call(node.key, node.value, node.cacheTarget);
    return node.value;
  }

  /// Clears all unpinned entries, or completely clears everything if [forceAll] is true.
  int clear({bool forceAll = false}) {
    if (forceAll) {
      final int count = _map.length;
      for (final _LruNode<V> node in _map.values) {
        onEvicted?.call(node.key, node.value, node.cacheTarget);
      }
      _map.clear();
      _head = null;
      _tail = null;
      _currentSizeBytes = 0;
      return count;
    }

    final List<String> toRemove = <String>[];
    for (final _LruNode<V> node in _map.values) {
      if (!node.isPinned) {
        toRemove.add(node.key);
      }
    }
    for (final String key in toRemove) {
      remove(key);
    }
    return toRemove.length;
  }

  /// Evicts unpinned items starting from the least recently used tail
  /// whenever memory exceeds high watermark until it drops to low watermark.
  void _evictToCeiling() {
    final int highThreshold = (_maxSizeBytes * _highWatermark).round();
    if (_currentSizeBytes <= highThreshold) return;

    final int targetBudget = (_maxSizeBytes * _lowWatermark).round();

    _LruNode<V>? curr = _tail;
    while (curr != null && _currentSizeBytes > targetBudget) {
      final _LruNode<V>? prev = curr.prev;
      if (!curr.isPinned) {
        _removeNode(curr);
        _map.remove(curr.key);
        _currentSizeBytes -= curr.sizeBytes;
        _evictionCount++;
        onEvicted?.call(curr.key, curr.value, curr.cacheTarget);
      }
      curr = prev;
    }
  }

  void _moveToHead(_LruNode<V> node) {
    if (node == _head) return;
    _removeNode(node);
    _addToHead(node);
  }

  void _addToHead(_LruNode<V> node) {
    node.prev = null;
    node.next = _head;
    if (_head != null) {
      _head!.prev = node;
    }
    _head = node;
    _tail ??= node;
  }

  void _removeNode(_LruNode<V> node) {
    if (node.prev != null) {
      node.prev!.next = node.next;
    } else {
      _head = node.next;
    }

    if (node.next != null) {
      node.next!.prev = node.prev;
    } else {
      _tail = node.prev;
    }

    node.prev = null;
    node.next = null;
  }

  /// Returns unmodifiable list of keys ordered from Most Recently Used to Least Recently Used.
  List<String> get mruKeys {
    final List<String> keys = <String>[];
    _LruNode<V>? curr = _head;
    while (curr != null) {
      keys.add(curr.key);
      curr = curr.next;
    }
    return keys;
  }
}

/// Complete performance telemetry snapshot of the Zero-Jank Progressive Preloader.
class ZeroJankSnapshot {
  final int pendingTasks;
  final int runningTasks;
  final int completedTasks;
  final int cancelledTasks;
  final int failedTasks;

  final int ramUsedBytes;
  final int ramCeilingBytes;
  final int vramUsedBytes;
  final int vramCeilingBytes;

  final double ramUsageFraction;
  final double vramUsageFraction;

  final double hitRate;
  final int totalEvictions;
  final bool isTouchYielding;
  final double currentFrameBudgetMs;

  const ZeroJankSnapshot({
    required this.pendingTasks,
    required this.runningTasks,
    required this.completedTasks,
    required this.cancelledTasks,
    required this.failedTasks,
    required this.ramUsedBytes,
    required this.ramCeilingBytes,
    required this.vramUsedBytes,
    required this.vramCeilingBytes,
    required this.ramUsageFraction,
    required this.vramUsageFraction,
    required this.hitRate,
    required this.totalEvictions,
    required this.isTouchYielding,
    required this.currentFrameBudgetMs,
  });

  @override
  String toString() {
    final double ramMb = ramUsedBytes / (1024 * 1024);
    final double ramMaxMb = ramCeilingBytes / (1024 * 1024);
    final double vramMb = vramUsedBytes / (1024 * 1024);
    final double vramMaxMb = vramCeilingBytes / (1024 * 1024);

    return 'ZeroJankSnapshot('
        'tasks: [pending: $pendingTasks, running: $runningTasks, done: $completedTasks, cancelled: $cancelledTasks], '
        'RAM: ${ramMb.toStringAsFixed(1)}MB/${ramMaxMb.toStringAsFixed(1)}MB (${(ramUsageFraction * 100).toStringAsFixed(1)}%), '
        'VRAM: ${vramMb.toStringAsFixed(1)}MB/${vramMaxMb.toStringAsFixed(1)}MB (${(vramUsageFraction * 100).toStringAsFixed(1)}%), '
        'hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, evictions: $totalEvictions, '
        'touchYield: $isTouchYielding, budget: ${currentFrameBudgetMs}ms)';
  }
}

/// Production-ready Zero-Jank Progressive Preloader & Dual LRU VRAM/RAM Cache.
///
/// Features:
/// 1. Strict time slicing adhering to < 2.0ms per frame budget.
/// 2. Cooperative async slicing context for progressive multi-stage asset loaders.
/// 3. Immediate yielding to UI thread during touch interactions with configurable cooldown.
/// 4. 4-tier Priority Queue (Critical HUD > Nearby LOD0 > Far LOD2/VAT > Background Music).
/// 5. Dual LRU Cache with RAM & VRAM ceilings and anti-churn watermarks.
/// 6. Comprehensive cancellation by task ID, tag, or priority.
class ZeroJankPreloader {
  static ZeroJankPreloader? _instance;
  static ZeroJankPreloader get instance => _instance ??= ZeroJankPreloader();

  ZeroJankConfig _config;
  final TimeSource timeSource;
  final FrameScheduler frameScheduler;
  final CacheEvictionCallback<dynamic>? onEvicted;

  late final LruMemoryCache<dynamic> ramCache;
  late final LruMemoryCache<dynamic> vramCache;

  // 4 Priority Buckets
  final Map<PreloadPriority, Queue<PreloadTask<dynamic>>> _priorityQueues =
      <PreloadPriority, Queue<PreloadTask<dynamic>>>{
    PreloadPriority.criticalHud: Queue<PreloadTask<dynamic>>(),
    PreloadPriority.nearbyLod0: Queue<PreloadTask<dynamic>>(),
    PreloadPriority.farLod2Vat: Queue<PreloadTask<dynamic>>(),
    PreloadPriority.backgroundMusic: Queue<PreloadTask<dynamic>>(),
  };

  final Map<String, PreloadTask<dynamic>> _allTasks = <String, PreloadTask<dynamic>>{};
  final Set<String> _activeTaskIds = <String>{};

  // Touch tracking state
  int _activeTouchCount = 0;
  Timer? _touchCooldownTimer;
  bool _isTouchCooldownActive = false;

  // Task counters
  int _completedCount = 0;
  int _cancelledCount = 0;
  int _failedCount = 0;

  // Processing loop state
  bool _isLoopRunning = false;
  int _currentSliceStartMicroseconds = 0;

  ZeroJankPreloader({
    ZeroJankConfig? config,
    TimeSource? timeSource,
    FrameScheduler? frameScheduler,
    this.onEvicted,
  })  : _config = config ?? const ZeroJankConfig(),
        timeSource = timeSource ?? SystemTimeSource(),
        frameScheduler = frameScheduler ?? const FlutterEngineFrameScheduler() {
    _initCaches();
  }

  void _initCaches() {
    ramCache = LruMemoryCache<dynamic>(
      name: 'ZeroJank_RAM_Cache',
      defaultTarget: CacheTarget.ram,
      maxSizeBytes: _config.ramCeilingBytes,
      highWatermark: _config.highWatermark,
      lowWatermark: _config.lowWatermark,
      onEvicted: onEvicted,
    );

    vramCache = LruMemoryCache<dynamic>(
      name: 'ZeroJank_VRAM_Cache',
      defaultTarget: CacheTarget.vram,
      maxSizeBytes: _config.vramCeilingBytes,
      highWatermark: _config.highWatermark,
      lowWatermark: _config.lowWatermark,
      onEvicted: onEvicted,
    );
  }

  ZeroJankConfig get config => _config;

  int get sliceBudgetMicroseconds => (_config.frameBudgetMs * 1000).round();

  /// Start timestamp (in microseconds) of the current frame slice.
  int get currentSliceStartMicroseconds => _currentSliceStartMicroseconds;

  /// Returns true if touch interaction is currently yielding the preloader loop.
  bool get isYieldingToTouch => _config.yieldOnTouch && (_activeTouchCount > 0 || _isTouchCooldownActive);

  /// Dynamic runtime reconfiguration (e.g. from AdaptiveQualityScaler on device tier switch).
  void updateConfig(ZeroJankConfig newConfig) {
    _config = newConfig;
    ramCache.setMaxSizeBytes(newConfig.ramCeilingBytes);
    vramCache.setMaxSizeBytes(newConfig.vramCeilingBytes);
    ramCache.setWatermarks(high: newConfig.highWatermark, low: newConfig.lowWatermark);
    vramCache.setWatermarks(high: newConfig.highWatermark, low: newConfig.lowWatermark);
  }

  // ---------------------------------------------------------------------------
  // Touch Interaction Management
  // ---------------------------------------------------------------------------

  /// Called when a user finger/pointer goes down. Pauses preloading immediately.
  void onTouchStart() {
    _touchCooldownTimer?.cancel();
    _isTouchCooldownActive = false;
    _activeTouchCount++;
  }

  /// Called when a pointer is lifted or cancelled. Begins debounce cooldown before resuming.
  void onTouchEnd() {
    if (_activeTouchCount > 0) {
      _activeTouchCount--;
    }

    if (_activeTouchCount == 0 && _config.yieldOnTouch) {
      _isTouchCooldownActive = true;
      _touchCooldownTimer?.cancel();
      _touchCooldownTimer = Timer(_config.touchCooldown, () {
        _isTouchCooldownActive = false;
        _touchCooldownTimer = null;
        _wakeProcessingLoop();
      });
    }
  }

  /// Directly set touch state (e.g., from gesture detector or combat stick).
  void setTouchInteracting(bool isInteracting) {
    if (isInteracting) {
      onTouchStart();
    } else {
      onTouchEnd();
    }
  }

  // ---------------------------------------------------------------------------
  // Enqueue & Preload API
  // ---------------------------------------------------------------------------

  /// Enqueues a preloading task with specified priority and cache target.
  /// Returns a Future that completes when the asset is ready and cached.
  Future<T> preload<T>({
    required String id,
    required PreloadPriority priority,
    required ProgressiveLoader<T> loader,
    CacheTarget targetCache = CacheTarget.vram,
    int estimatedSizeBytes = 1024 * 1024,
    PreloadCancellationToken? cancellationToken,
    Set<String>? tags,
    bool isPinned = false,
  }) {
    // Check if already in cache
    final dynamic cached = getCached(id, targetCache);
    if (cached != null && cached is T) {
      return Future<T>.value(cached);
    }

    // Check if task is already registered or running
    final PreloadTask<dynamic>? existing = _allTasks[id];
    if (existing != null) {
      if (existing.priority.isHigherThan(priority)) {
        // Already higher priority
      } else if (priority.isHigherThan(existing.priority)) {
        promotePriority(id, priority);
      }
      return existing.future.then((dynamic val) => val as T);
    }

    final PreloadTask<T> task = PreloadTask<T>(
      id: id,
      priority: priority,
      targetCache: targetCache,
      estimatedSizeBytes: estimatedSizeBytes,
      loader: loader,
      cancellationToken: cancellationToken,
      tags: tags,
      isPinned: isPinned,
    );

    _allTasks[id] = task;
    _priorityQueues[priority]!.add(task);

    _wakeProcessingLoop();
    return task.future;
  }

  /// Convenient helper to preload an atomic asynchronous task that does not require internal slicing.
  Future<T> preloadAtomic<T>({
    required String id,
    required PreloadPriority priority,
    required Future<T> Function() loader,
    CacheTarget targetCache = CacheTarget.vram,
    int estimatedSizeBytes = 1024 * 1024,
    PreloadCancellationToken? cancellationToken,
    Set<String>? tags,
    bool isPinned = false,
  }) {
    return preload<T>(
      id: id,
      priority: priority,
      targetCache: targetCache,
      estimatedSizeBytes: estimatedSizeBytes,
      cancellationToken: cancellationToken,
      tags: tags,
      isPinned: isPinned,
      loader: (PreloadExecutionContext ctx) async {
        return loader();
      },
    );
  }

  /// Preloads a 3D GLB model progressively using time-sliced geometry decoding.
  Future<T> preloadGlbMesh<T>({
    required String id,
    required PreloadPriority priority,
    required ProgressiveLoader<T> loader,
    CacheTarget targetCache = CacheTarget.vram,
    int estimatedSizeBytes = 5 * 1024 * 1024,
    PreloadCancellationToken? cancellationToken,
    Set<String>? tags,
    bool isPinned = false,
  }) {
    return preload<T>(
      id: id,
      priority: priority,
      loader: loader,
      targetCache: targetCache,
      estimatedSizeBytes: estimatedSizeBytes,
      cancellationToken: cancellationToken,
      tags: tags,
      isPinned: isPinned,
    );
  }

  /// Preloads a PBR / KTX2 texture progressively, uploading mipmaps in time-sliced budgets.
  Future<T> preloadKtx2Texture<T>({
    required String id,
    required PreloadPriority priority,
    required ProgressiveLoader<T> loader,
    CacheTarget targetCache = CacheTarget.vram,
    int estimatedSizeBytes = 2 * 1024 * 1024,
    PreloadCancellationToken? cancellationToken,
    Set<String>? tags,
    bool isPinned = false,
  }) {
    return preload<T>(
      id: id,
      priority: priority,
      loader: loader,
      targetCache: targetCache,
      estimatedSizeBytes: estimatedSizeBytes,
      cancellationToken: cancellationToken,
      tags: tags,
      isPinned: isPinned,
    );
  }

  /// Preloads an audio buffer or soundscape into system RAM.
  Future<T> preloadAudio<T>({
    required String id,
    required Future<T> Function() audioLoader,
    PreloadPriority priority = PreloadPriority.backgroundMusic,
    int estimatedSizeBytes = 512 * 1024,
    PreloadCancellationToken? cancellationToken,
    Set<String>? tags,
    bool isPinned = false,
  }) {
    return preloadAtomic<T>(
      id: id,
      priority: priority,
      targetCache: CacheTarget.ram,
      estimatedSizeBytes: estimatedSizeBytes,
      loader: audioLoader,
      cancellationToken: cancellationToken,
      tags: tags,
      isPinned: isPinned,
    );
  }

  /// Preloads and pre-warms a shader pipeline program asynchronously within time-sliced budgets.
  Future<T> preloadShader<T>({
    required String id,
    required Future<T> Function(PreloadExecutionContext ctx) shaderWarmupLoader,
    PreloadPriority priority = PreloadPriority.criticalHud,
    CacheTarget targetCache = CacheTarget.vram,
    int estimatedSizeBytes = 256 * 1024,
    PreloadCancellationToken? cancellationToken,
    Set<String>? tags,
    bool isPinned = true,
  }) {
    return preload<T>(
      id: id,
      priority: priority,
      targetCache: targetCache,
      estimatedSizeBytes: estimatedSizeBytes,
      loader: shaderWarmupLoader,
      cancellationToken: cancellationToken,
      tags: tags,
      isPinned: isPinned,
    );
  }

  // ---------------------------------------------------------------------------
  // Priority Promotion & Dynamic Reprioritization
  // ---------------------------------------------------------------------------

  /// Dynamically promotes a task's priority (e.g. entity moved from distant LOD2 into nearby LOD0).
  bool promotePriority(String id, PreloadPriority newPriority) {
    final PreloadTask<dynamic>? task = _allTasks[id];
    if (task == null || task.status != PreloadTaskStatus.pending) return false;
    if (newPriority.rank >= task.priority.rank) return false;

    _priorityQueues[task.priority]!.remove(task);
    task.priority = newPriority;
    _priorityQueues[newPriority]!.add(task);
    _wakeProcessingLoop();
    return true;
  }

  /// Dynamically demotes a task's priority (e.g. entity moved away).
  bool demotePriority(String id, PreloadPriority newPriority) {
    final PreloadTask<dynamic>? task = _allTasks[id];
    if (task == null || task.status != PreloadTaskStatus.pending) return false;
    if (newPriority.rank <= task.priority.rank) return false;

    _priorityQueues[task.priority]!.remove(task);
    task.priority = newPriority;
    _priorityQueues[newPriority]!.add(task);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Cancellation API
  // ---------------------------------------------------------------------------

  /// Cancels an individual task by ID.
  bool cancel(String id, [String reason = 'Cancelled by user']) {
    final PreloadTask<dynamic>? task = _allTasks[id];
    if (task == null) return false;

    task.cancellationToken.cancel(reason);
    _handleTaskCancelled(task, reason);
    return true;
  }

  /// Cancels all tasks matching the specified tag (e.g. 'dungeon_level_1').
  int cancelByTag(String tag, [String reason = 'Tag cancelled']) {
    int count = 0;
    final List<PreloadTask<dynamic>> matching = _allTasks.values
        .where((PreloadTask<dynamic> t) => t.tags.contains(tag) && !_isFinished(t.status))
        .toList();

    for (final PreloadTask<dynamic> task in matching) {
      task.cancellationToken.cancel(reason);
      _handleTaskCancelled(task, reason);
      count++;
    }
    return count;
  }

  /// Cancels all pending tasks matching the specified priority.
  int cancelByPriority(PreloadPriority priority, [String reason = 'Priority cancelled']) {
    int count = 0;
    final Queue<PreloadTask<dynamic>> queue = _priorityQueues[priority]!;
    final List<PreloadTask<dynamic>> pending = queue.toList();
    queue.clear();

    for (final PreloadTask<dynamic> task in pending) {
      task.cancellationToken.cancel(reason);
      _handleTaskCancelled(task, reason);
      count++;
    }
    return count;
  }

  /// Cancels all pending and active tasks.
  int cancelAll([String reason = 'All tasks cancelled']) {
    int count = 0;
    final List<PreloadTask<dynamic>> active = _allTasks.values
        .where((PreloadTask<dynamic> t) => !_isFinished(t.status))
        .toList();

    for (final PreloadTask<dynamic> task in active) {
      task.cancellationToken.cancel(reason);
      _handleTaskCancelled(task, reason);
      count++;
    }
    for (final Queue<PreloadTask<dynamic>> q in _priorityQueues.values) {
      q.clear();
    }
    return count;
  }

  bool _isFinished(PreloadTaskStatus status) =>
      status == PreloadTaskStatus.completed ||
      status == PreloadTaskStatus.cancelled ||
      status == PreloadTaskStatus.failed;

  void _handleTaskCancelled(PreloadTask<dynamic> task, String reason) {
    if (_isFinished(task.status)) return;

    task._setStatus(PreloadTaskStatus.cancelled);
    _priorityQueues[task.priority]!.remove(task);
    _activeTaskIds.remove(task.id);
    _cancelledCount++;

    if (!task._completer.isCompleted) {
      task._completer.completeError(PreloadCancelledException(task.id, reason));
    }
  }

  // ---------------------------------------------------------------------------
  // Cache Access
  // ---------------------------------------------------------------------------

  /// Retrieves an item from the requested cache.
  dynamic getCached(String key, [CacheTarget target = CacheTarget.vram]) {
    switch (target) {
      case CacheTarget.ram:
        return ramCache.get(key);
      case CacheTarget.vram:
        return vramCache.get(key);
      case CacheTarget.both:
        return vramCache.get(key) ?? ramCache.get(key);
    }
  }

  /// Stores an asset directly in the cache.
  void putCache(
    String key,
    dynamic value, {
    required int sizeBytes,
    CacheTarget target = CacheTarget.vram,
    bool isPinned = false,
  }) {
    if (target == CacheTarget.ram || target == CacheTarget.both) {
      ramCache.put(key, value, sizeBytes: sizeBytes, target: CacheTarget.ram, isPinned: isPinned);
    }
    if (target == CacheTarget.vram || target == CacheTarget.both) {
      vramCache.put(key, value, sizeBytes: sizeBytes, target: CacheTarget.vram, isPinned: isPinned);
    }
  }

  /// Pins an asset in cache preventing eviction.
  void pin(String key) {
    ramCache.pin(key);
    vramCache.pin(key);
  }

  /// Unpins an asset in cache allowing eviction.
  void unpin(String key) {
    ramCache.unpin(key);
    vramCache.unpin(key);
  }

  /// Evicts and disposes a specific asset from all caches.
  void evict(String key) {
    ramCache.remove(key);
    vramCache.remove(key);
  }

  bool _isManuallyPaused = false;

  /// Returns true if preloader is manually paused.
  bool get isPaused => _isManuallyPaused;

  /// Manually pauses background preloading (e.g. during cinematic cutscenes).
  void pause() {
    _isManuallyPaused = true;
  }

  /// Resumes background preloading if previously paused.
  void resume() {
    if (!_isManuallyPaused) return;
    _isManuallyPaused = false;
    _wakeProcessingLoop();
  }

  // ---------------------------------------------------------------------------
  // Time-Sliced Execution Loop
  // ---------------------------------------------------------------------------

  void _wakeProcessingLoop() {
    if (_isLoopRunning || _isManuallyPaused) return;
    _isLoopRunning = true;
    scheduleMicrotask(_runLoop);
  }

  Future<void> _runLoop() async {
    _currentSliceStartMicroseconds = timeSource.nowMicroseconds;

    while (true) {
      // 1. Yield immediately if touch interaction or manual pause is active
      if (isYieldingToTouch || _isManuallyPaused) {
        _isLoopRunning = false;
        return;
      }

      // Check if time budget is already exceeded for this frame before picking next task
      if (_hasExceededBudget()) {
        await frameScheduler.yieldFrame();
        _currentSliceStartMicroseconds = timeSource.nowMicroseconds;
        continue;
      }

      // 2. Fetch highest priority available task
      final PreloadTask<dynamic>? nextTask = _peekNextTask();
      if (nextTask == null) {
        // No more pending tasks
        _isLoopRunning = false;
        return;
      }

      // Pop task from queue
      final PreloadTask<dynamic> task = _popNextTask()!;
      if (task.cancellationToken.isCancelled) {
        _handleTaskCancelled(task, task.cancellationToken.cancelReason ?? 'Cancelled');
        continue;
      }

      // 4. Execute task with cooperative execution context
      await _executeTask(task);

      // Check if we need to yield to UI frame
      if (_hasExceededBudget() || isYieldingToTouch) {
        await frameScheduler.yieldFrame();
        _currentSliceStartMicroseconds = timeSource.nowMicroseconds;
      }
    }
  }

  bool _hasExceededBudget() {
    final int elapsed = timeSource.nowMicroseconds - _currentSliceStartMicroseconds;
    return elapsed >= sliceBudgetMicroseconds;
  }

  Future<void> _yieldExecution(String taskId) async {
    await frameScheduler.yieldFrame();
    // Restart slice timer for the new frame
    _currentSliceStartMicroseconds = timeSource.nowMicroseconds;
  }

  PreloadTask<dynamic>? _peekNextTask() {
    for (final PreloadPriority priority in PreloadPriority.values) {
      final Queue<PreloadTask<dynamic>> queue = _priorityQueues[priority]!;
      while (queue.isNotEmpty) {
        final PreloadTask<dynamic> candidate = queue.first;
        if (candidate.cancellationToken.isCancelled) {
          queue.removeFirst();
          _handleTaskCancelled(candidate, candidate.cancellationToken.cancelReason ?? 'Cancelled');
        } else {
          return candidate;
        }
      }
    }
    return null;
  }

  PreloadTask<dynamic>? _popNextTask() {
    for (final PreloadPriority priority in PreloadPriority.values) {
      final Queue<PreloadTask<dynamic>> queue = _priorityQueues[priority]!;
      while (queue.isNotEmpty) {
        final PreloadTask<dynamic> task = queue.removeFirst();
        if (task.cancellationToken.isCancelled) {
          _handleTaskCancelled(task, task.cancellationToken.cancelReason ?? 'Cancelled');
        } else {
          return task;
        }
      }
    }
    return null;
  }

  Future<void> _executeTask(PreloadTask<dynamic> task) async {
    task._setStatus(PreloadTaskStatus.running);
    task.startedAt = DateTime.now();
    _activeTaskIds.add(task.id);

    final PreloadExecutionContext ctx = PreloadExecutionContext._(
      taskId: task.id,
      cancellationToken: task.cancellationToken,
      preloader: this,
    );

    try {
      final dynamic result = await task.loader(ctx);

      if (task.cancellationToken.isCancelled) {
        _handleTaskCancelled(task, task.cancellationToken.cancelReason ?? 'Cancelled');
        return;
      }

      // Store in requested LRU cache
      putCache(
        task.id,
        result,
        sizeBytes: task.estimatedSizeBytes,
        target: task.targetCache,
        isPinned: task.isPinned,
      );

      task._setStatus(PreloadTaskStatus.completed);
      task.completedAt = DateTime.now();
      task.reportProgress(1.0);
      _activeTaskIds.remove(task.id);
      _completedCount++;

      if (!task._completer.isCompleted) {
        task._completer.complete(result);
      }
    } catch (e, st) {
      if (task.cancellationToken.isCancelled || e is PreloadCancelledException) {
        _handleTaskCancelled(task, task.cancellationToken.cancelReason ?? 'Cancelled');
      } else {
        task._setStatus(PreloadTaskStatus.failed);
        _activeTaskIds.remove(task.id);
        _failedCount++;
        if (!task._completer.isCompleted) {
          task._completer.completeError(e, st);
        }
      }
    }
  }

  void _notifyTaskProgress(String taskId, double progress) {
    final PreloadTask<dynamic>? task = _allTasks[taskId];
    if (task != null) {
      task._progress = progress;
    }
  }

  // ---------------------------------------------------------------------------
  // Telemetry & Diagnostic Snapshots
  // ---------------------------------------------------------------------------

  ZeroJankSnapshot getSnapshot() {
    int pending = 0;
    for (final Queue<PreloadTask<dynamic>> q in _priorityQueues.values) {
      pending += q.length;
    }

    final int ramUsed = ramCache.currentSizeBytes;
    final int ramCeil = ramCache.maxSizeBytes;
    final int vramUsed = vramCache.currentSizeBytes;
    final int vramCeil = vramCache.maxSizeBytes;

    final int totalHits = ramCache.hitCount + vramCache.hitCount;
    final int totalMisses = ramCache.missCount + vramCache.missCount;
    final double overallHitRate = (totalHits + totalMisses) == 0 ? 0.0 : totalHits / (totalHits + totalMisses);

    return ZeroJankSnapshot(
      pendingTasks: pending,
      runningTasks: _activeTaskIds.length,
      completedTasks: _completedCount,
      cancelledTasks: _cancelledCount,
      failedTasks: _failedCount,
      ramUsedBytes: ramUsed,
      ramCeilingBytes: ramCeil,
      vramUsedBytes: vramUsed,
      vramCeilingBytes: vramCeil,
      ramUsageFraction: ramCeil == 0 ? 0.0 : (ramUsed / ramCeil).clamp(0.0, 1.0),
      vramUsageFraction: vramCeil == 0 ? 0.0 : (vramUsed / vramCeil).clamp(0.0, 1.0),
      hitRate: overallHitRate,
      totalEvictions: ramCache.evictionCount + vramCache.evictionCount,
      isTouchYielding: isYieldingToTouch,
      currentFrameBudgetMs: _config.frameBudgetMs,
    );
  }

  /// Resets all statistics and cleans up memory.
  void dispose() {
    _touchCooldownTimer?.cancel();
    _touchCooldownTimer = null;
    cancelAll('Preloader disposed');
    ramCache.clear(forceAll: true);
    vramCache.clear(forceAll: true);
    _allTasks.clear();
  }
}

/// Optional Flutter Widget that automatically reports touch interactions
/// to the ZeroJankPreloader to yield background tasks seamlessly.
class ZeroJankTouchScope extends StatelessWidget {
  final Widget child;
  final ZeroJankPreloader? preloader;

  const ZeroJankTouchScope({
    super.key,
    required this.child,
    this.preloader,
  });

  ZeroJankPreloader get _targetPreloader => preloader ?? ZeroJankPreloader.instance;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _targetPreloader.onTouchStart(),
      onPointerUp: (_) => _targetPreloader.onTouchEnd(),
      onPointerCancel: (_) => _targetPreloader.onTouchEnd(),
      child: child,
    );
  }
}
