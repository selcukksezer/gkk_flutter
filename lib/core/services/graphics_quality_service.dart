import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_perf_probe.dart';

/// User-selected graphics mode persisted in SharedPreferences.
enum GraphicsPreference {
  auto,
  low,
  medium,
  high,
  ultra;

  String get storageKey => name;

  static GraphicsPreference fromStorage(String? raw) {
    if (raw == null || raw.isEmpty) return GraphicsPreference.auto;
    for (final GraphicsPreference p in GraphicsPreference.values) {
      if (p.name == raw) return p;
    }
    return GraphicsPreference.auto;
  }

  String labelTr({GraphicsQualityTier? resolvedAutoTier}) {
    return switch (this) {
      GraphicsPreference.auto => resolvedAutoTier != null
          ? 'Otomatik (${resolvedAutoTier.shortLabelTr})'
          : 'Otomatik',
      GraphicsPreference.low => 'Düşük',
      GraphicsPreference.medium => 'Orta',
      GraphicsPreference.high => 'Yüksek',
      GraphicsPreference.ultra => 'Ultra',
    };
  }

  String get shortChipTr => switch (this) {
        GraphicsPreference.auto => 'Oto',
        GraphicsPreference.low => 'Düşük',
        GraphicsPreference.medium => 'Orta',
        GraphicsPreference.high => 'Yüksek',
        GraphicsPreference.ultra => 'Ultra',
      };
}

/// Concrete resolved hardware/runtime rendering tier.
enum GraphicsQualityTier {
  low,
  medium,
  high,
  ultra;

  String get shortLabelTr => switch (this) {
        GraphicsQualityTier.low => 'Düşük',
        GraphicsQualityTier.medium => 'Orta',
        GraphicsQualityTier.high => 'Yüksek',
        GraphicsQualityTier.ultra => 'Ultra',
      };

  String get subtitleTr => switch (this) {
        GraphicsQualityTier.low =>
          'En düşük RAM ve GPU kullanımı • Eski / zayıf telefonlar için maksimum akıcılık',
        GraphicsQualityTier.medium =>
          'Dengeli görsel kalite ve pil tasarrufu • Orta segment telefonlar',
        GraphicsQualityTier.high =>
          'Zengin ışıklandırma, 3D sahne ve tam sürü animasyonları',
        GraphicsQualityTier.ultra =>
          'Tam 4K doku, cam bulanıklığı, 3D perspektif ve tüm atmosfer parçacıkları',
      };

  GraphicsQualityTier stepDown() => switch (this) {
        GraphicsQualityTier.ultra => GraphicsQualityTier.high,
        GraphicsQualityTier.high => GraphicsQualityTier.medium,
        GraphicsQualityTier.medium => GraphicsQualityTier.low,
        GraphicsQualityTier.low => GraphicsQualityTier.low,
      };
}

/// Hardware inspection snapshot used for automatic device classification.
class DeviceHardwareReport {
  const DeviceHardwareReport({
    required this.totalRamMb,
    required this.cpuCores,
    required this.isLowRamDevice,
    required this.deviceModel,
    required this.devicePixelRatio,
    required this.shortestLogicalSide,
    required this.isMobilePlatform,
    required this.isWebPlatform,
    required this.recommendedTier,
  });

  final int totalRamMb;
  final int cpuCores;
  final bool isLowRamDevice;
  final String deviceModel;
  final double devicePixelRatio;
  final double shortestLogicalSide;
  final bool isMobilePlatform;
  final bool isWebPlatform;
  final GraphicsQualityTier recommendedTier;

  static const DeviceHardwareReport fallback = DeviceHardwareReport(
    totalRamMb: 0,
    cpuCores: 4,
    isLowRamDevice: false,
    deviceModel: '',
    devicePixelRatio: 2.0,
    shortestLogicalSide: 390.0,
    isMobilePlatform: true,
    isWebPlatform: false,
    recommendedTier: GraphicsQualityTier.medium,
  );

  String get summaryTr {
    final List<String> parts = <String>[];
    if (deviceModel.trim().isNotEmpty) {
      parts.add(deviceModel.trim());
    }
    if (totalRamMb > 0) {
      final double gb = totalRamMb / 1024.0;
      parts.add('${gb.toStringAsFixed(gb < 3.0 ? 1 : 0)} GB RAM');
    }
    if (cpuCores > 0) {
      parts.add('$cpuCores Çekirdek');
    }
    if (isLowRamDevice) {
      parts.add('Düşük Bellek Modu');
    }
    if (parts.isEmpty) {
      return 'Otomatik Profil: ${recommendedTier.shortLabelTr}';
    }
    return '${parts.join(' • ')} → Önerilen: ${recommendedTier.shortLabelTr}';
  }
}

/// Complete rendering budget consumed by Moradon, Dungeon Hub, Combat Stage & Chrome.
class GraphicsProfile {
  const GraphicsProfile({
    required this.preference,
    required this.tier,
    required this.hardwareTier,
    required this.autoDowngraded,
    required this.estimatedFps,
    required this.showFpsOverlay,
    required this.enableBackdropBlur,
    required this.blurSigma,
    required this.enable3dPerspective,
    required this.enableDotGridOverlay,
    required this.enableHeavyShadows,
    required this.enableWeatherAndAtmosphere,
    required this.enableArchitecturalVfx,
    required this.enableForegroundOcclusion,
    required this.enableCompanionPets,
    required this.enableRemoteCompanionPets,
    required this.enablePaintedBattleVfxBitmaps,
    required this.useFastSpriteQuad,
    required this.enableSpriteCrossDissolveAndGhost,
    required this.moradonTickIntervalMs,
    required this.moradonMaxAvatarRigs,
    required this.moradonAmbientBotCount,
    required this.moradonEnablePatrolGuards,
    required this.moradonEnableBraziers,
    required this.moradonMapCacheWidth,
    required this.charAtlasTargetWidth,
    required this.dungeonArenaCacheWidth,
    required this.dungeonSpriteCacheWidth,
    required this.dungeonMaxPackMobs,
    required this.enableLive3dHubDiorama,
    required this.enableGpuShaders,
    required this.enableHoloFoilSweep,
    required this.filterQuality,
    required this.imageCacheMaxBytes,
    required this.imageCacheMaxCount,
  });

  final GraphicsPreference preference;
  final GraphicsQualityTier tier;
  final GraphicsQualityTier hardwareTier;
  final bool autoDowngraded;
  final int estimatedFps;
  final bool showFpsOverlay;

  final bool enableBackdropBlur;
  final double blurSigma;
  final bool enable3dPerspective;
  final bool enableDotGridOverlay;
  final bool enableHeavyShadows;
  final bool enableWeatherAndAtmosphere;
  final bool enableArchitecturalVfx;
  final bool enableForegroundOcclusion;
  final bool enableCompanionPets;
  final bool enableRemoteCompanionPets;
  final bool enablePaintedBattleVfxBitmaps;
  final bool useFastSpriteQuad;
  final bool enableSpriteCrossDissolveAndGhost;

  final int moradonTickIntervalMs;
  final int moradonMaxAvatarRigs;
  final int moradonAmbientBotCount;
  final bool moradonEnablePatrolGuards;
  final bool moradonEnableBraziers;
  final int? moradonMapCacheWidth;
  final int? charAtlasTargetWidth;

  final int? dungeonArenaCacheWidth;
  final int? dungeonSpriteCacheWidth;
  final int dungeonMaxPackMobs;
  final bool enableLive3dHubDiorama;
  final bool enableGpuShaders;
  final bool enableHoloFoilSweep;

  final FilterQuality filterQuality;
  final int imageCacheMaxBytes;
  final int imageCacheMaxCount;

  bool get isLow => tier == GraphicsQualityTier.low;
  bool get isLowOrMedium =>
      tier == GraphicsQualityTier.low || tier == GraphicsQualityTier.medium;

  String get activeBadgeTr {
    if (preference == GraphicsPreference.auto) {
      return 'Oto: ${tier.shortLabelTr}';
    }
    return tier.shortLabelTr;
  }

  factory GraphicsProfile.forTier({
    required GraphicsQualityTier tier,
    required GraphicsPreference preference,
    required GraphicsQualityTier hardwareTier,
    bool autoDowngraded = false,
    int estimatedFps = 60,
    bool showFpsOverlay = false,
  }) {
    switch (tier) {
      case GraphicsQualityTier.low:
        return GraphicsProfile(
          preference: preference,
          tier: tier,
          hardwareTier: hardwareTier,
          autoDowngraded: autoDowngraded,
          estimatedFps: estimatedFps,
          showFpsOverlay: showFpsOverlay,
          enableBackdropBlur: false,
          blurSigma: 0.0,
          enable3dPerspective: false,
          enableDotGridOverlay: false,
          enableHeavyShadows: false,
          enableWeatherAndAtmosphere: false,
          enableArchitecturalVfx: false,
          enableForegroundOcclusion: false,
          enableCompanionPets: false,
          enableRemoteCompanionPets: false,
          enablePaintedBattleVfxBitmaps: false,
          useFastSpriteQuad: true,
          enableSpriteCrossDissolveAndGhost: false,
          moradonTickIntervalMs: 40, // 25 Hz sim tick + 0 Hz idle sleep!
          moradonMaxAvatarRigs: 10,
          moradonAmbientBotCount: 3, // Stationary merchants only -> 0 CPU roam!
          moradonEnablePatrolGuards: false,
          moradonEnableBraziers: false,
          moradonMapCacheWidth: 1440, // ~4.6 MB RGBA vs 33.2 MB!
          charAtlasTargetWidth: 1530, // 170px/cell -> ~1.3 MB per class!
          dungeonArenaCacheWidth: 960,
          dungeonSpriteCacheWidth: 260,
          dungeonMaxPackMobs: 3,
          enableLive3dHubDiorama: false,
          enableGpuShaders: false,
          enableHoloFoilSweep: false,
          filterQuality: FilterQuality.none,
          imageCacheMaxBytes: 28 * 1024 * 1024,
          imageCacheMaxCount: 45,
        );
      case GraphicsQualityTier.medium:
        return GraphicsProfile(
          preference: preference,
          tier: tier,
          hardwareTier: hardwareTier,
          autoDowngraded: autoDowngraded,
          estimatedFps: estimatedFps,
          showFpsOverlay: showFpsOverlay,
          enableBackdropBlur: false,
          blurSigma: 0.0,
          enable3dPerspective: true,
          enableDotGridOverlay: true,
          enableHeavyShadows: false,
          enableWeatherAndAtmosphere: false,
          enableArchitecturalVfx: true,
          enableForegroundOcclusion: false,
          enableCompanionPets: true,
          enableRemoteCompanionPets: false,
          enablePaintedBattleVfxBitmaps: true,
          useFastSpriteQuad: false,
          enableSpriteCrossDissolveAndGhost: false,
          moradonTickIntervalMs: 28, // ~35 Hz smooth mid-range tick
          moradonMaxAvatarRigs: 22,
          moradonAmbientBotCount: 5,
          moradonEnablePatrolGuards: true,
          moradonEnableBraziers: true,
          moradonMapCacheWidth: 2240,
          charAtlasTargetWidth: 2430,
          dungeonArenaCacheWidth: 1280,
          dungeonSpriteCacheWidth: 380,
          dungeonMaxPackMobs: 4,
          enableLive3dHubDiorama: true,
          enableGpuShaders: false,
          enableHoloFoilSweep: true,
          filterQuality: FilterQuality.low,
          imageCacheMaxBytes: 52 * 1024 * 1024,
          imageCacheMaxCount: 75,
        );
      case GraphicsQualityTier.high:
        return GraphicsProfile(
          preference: preference,
          tier: tier,
          hardwareTier: hardwareTier,
          autoDowngraded: autoDowngraded,
          estimatedFps: estimatedFps,
          showFpsOverlay: showFpsOverlay,
          enableBackdropBlur: true,
          blurSigma: 7.0,
          enable3dPerspective: true,
          enableDotGridOverlay: true,
          enableHeavyShadows: true,
          enableWeatherAndAtmosphere: true,
          enableArchitecturalVfx: true,
          enableForegroundOcclusion: true,
          enableCompanionPets: true,
          enableRemoteCompanionPets: true,
          enablePaintedBattleVfxBitmaps: true,
          useFastSpriteQuad: false,
          enableSpriteCrossDissolveAndGhost: true,
          moradonTickIntervalMs: 16,
          moradonMaxAvatarRigs: 38,
          moradonAmbientBotCount: 8,
          moradonEnablePatrolGuards: true,
          moradonEnableBraziers: true,
          moradonMapCacheWidth: 3200,
          charAtlasTargetWidth: 3240,
          dungeonArenaCacheWidth: 1600,
          dungeonSpriteCacheWidth: 520,
          dungeonMaxPackMobs: 5,
          enableLive3dHubDiorama: true,
          enableGpuShaders: true,
          enableHoloFoilSweep: true,
          filterQuality: FilterQuality.medium,
          imageCacheMaxBytes: 85 * 1024 * 1024,
          imageCacheMaxCount: 110,
        );
      case GraphicsQualityTier.ultra:
        return GraphicsProfile(
          preference: preference,
          tier: tier,
          hardwareTier: hardwareTier,
          autoDowngraded: autoDowngraded,
          estimatedFps: estimatedFps,
          showFpsOverlay: showFpsOverlay,
          enableBackdropBlur: true,
          blurSigma: 10.0,
          enable3dPerspective: true,
          enableDotGridOverlay: true,
          enableHeavyShadows: true,
          enableWeatherAndAtmosphere: true,
          enableArchitecturalVfx: true,
          enableForegroundOcclusion: true,
          enableCompanionPets: true,
          enableRemoteCompanionPets: true,
          enablePaintedBattleVfxBitmaps: true,
          useFastSpriteQuad: false,
          enableSpriteCrossDissolveAndGhost: true,
          moradonTickIntervalMs: 16,
          moradonMaxAvatarRigs: 48,
          moradonAmbientBotCount: 8,
          moradonEnablePatrolGuards: true,
          moradonEnableBraziers: true,
          moradonMapCacheWidth: null,
          charAtlasTargetWidth: null,
          dungeonArenaCacheWidth: null,
          dungeonSpriteCacheWidth: null,
          dungeonMaxPackMobs: 5,
          enableLive3dHubDiorama: true,
          enableGpuShaders: true,
          enableHoloFoilSweep: true,
          filterQuality: FilterQuality.medium,
          imageCacheMaxBytes: 120 * 1024 * 1024,
          imageCacheMaxCount: 150,
        );
    }
  }
}

/// Singleton adaptive performance controller & shared downsampled sprite atlas cache.
class GraphicsQualityService extends ChangeNotifier {
  GraphicsQualityService._();

  static final GraphicsQualityService instance = GraphicsQualityService._();

  static const String prefGraphicsModeKey = 'graphics_quality_preference';
  static const String prefShowFpsKey = 'graphics_show_fps_overlay';

  bool _initialized = false;
  bool _timingsAttached = false;
  GraphicsPreference _preference = GraphicsPreference.auto;
  GraphicsQualityTier _hardwareTier = GraphicsQualityTier.high;
  GraphicsQualityTier? _runtimeAutoOverrideTier;
  bool _reduceMotionOverride = false;
  bool _showFpsOverlay = false;
  int _estimatedFps = 60;
  DeviceHardwareReport _hardwareReport = DeviceHardwareReport.fallback;

  // FrameTiming rolling telemetry
  final DateTime _bootedAt = DateTime.now();
  DateTime _lastAutoStepDownAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFpsPublishAt = DateTime.fromMillisecondsSinceEpoch(0);
  final List<double> _frameSpansMs = <double>[];
  int _consecutiveSlowWindows = 0;

  // Shared decoded character & pet atlases keyed by targetWidth so Moradon & Ward share VRAM!
  int? _cachedAtlasTargetWidth = -1;
  final Map<String, ui.Image> _sharedCharAtlases = <String, ui.Image>{};
  final Map<String, ui.Image> _sharedPetSprites = <String, ui.Image>{};
  Future<Map<String, ui.Image>>? _inFlightCharLoad;

  bool get isInitialized => _initialized;
  GraphicsPreference get preference => _preference;
  DeviceHardwareReport get hardwareReport => _hardwareReport;
  bool get showFpsOverlay => _showFpsOverlay;
  int get estimatedFps => _estimatedFps;

  GraphicsQualityTier get effectiveTier {
    if (_preference != GraphicsPreference.auto) {
      return switch (_preference) {
        GraphicsPreference.low => GraphicsQualityTier.low,
        GraphicsPreference.medium => GraphicsQualityTier.medium,
        GraphicsPreference.high => GraphicsQualityTier.high,
        GraphicsPreference.ultra => GraphicsQualityTier.ultra,
        GraphicsPreference.auto => _hardwareTier,
      };
    }
    if (_reduceMotionOverride) {
      return GraphicsQualityTier.low;
    }
    return _runtimeAutoOverrideTier ?? _hardwareTier;
  }

  GraphicsProfile get profile => GraphicsProfile.forTier(
        tier: effectiveTier,
        preference: _preference,
        hardwareTier: _hardwareTier,
        autoDowngraded: _preference == GraphicsPreference.auto &&
            _runtimeAutoOverrideTier != null &&
            _runtimeAutoOverrideTier != _hardwareTier,
        estimatedFps: _estimatedFps,
        showFpsOverlay: _showFpsOverlay,
      );

  /// Pure deterministic hardware classifier (unit-testable across all phone specs).
  static GraphicsQualityTier classifyHardwareTier({
    required int totalRamMb,
    required int cpuCores,
    required bool isLowRamDevice,
    required double devicePixelRatio,
    required double shortestLogicalSide,
    required bool isMobilePlatform,
    required bool isWebPlatform,
    bool systemReduceMotion = false,
  }) {
    if (systemReduceMotion || isLowRamDevice) {
      return GraphicsQualityTier.low;
    }

    // Known RAM classification (Android MethodChannel or Web navigator.deviceMemory)
    if (totalRamMb > 0) {
      if (totalRamMb <= 2650) {
        return GraphicsQualityTier.low;
      }
      if (totalRamMb <= 4300) {
        return cpuCores <= 4
            ? GraphicsQualityTier.low
            : GraphicsQualityTier.medium;
      }
      if (totalRamMb <= 6500) {
        return cpuCores <= 4
            ? GraphicsQualityTier.medium
            : GraphicsQualityTier.high;
      }
      return cpuCores >= 8 && !isWebPlatform
          ? GraphicsQualityTier.ultra
          : GraphicsQualityTier.high;
    }

    // Fallback when OS hides exact RAM (iOS / restricted WebViews / Desktop)
    if (cpuCores <= 2) {
      return GraphicsQualityTier.low;
    }
    if (cpuCores <= 4) {
      if (isMobilePlatform || isWebPlatform || devicePixelRatio < 2.0) {
        return shortestLogicalSide < 365 || devicePixelRatio <= 1.75
            ? GraphicsQualityTier.low
            : GraphicsQualityTier.medium;
      }
      return GraphicsQualityTier.medium;
    }
    if (isWebPlatform && isMobilePlatform) {
      return GraphicsQualityTier.medium;
    }
    if (cpuCores >= 8 && !isMobilePlatform && !isWebPlatform) {
      return GraphicsQualityTier.ultra;
    }
    return GraphicsQualityTier.high;
  }

  Future<void> initialize({bool appReduceMotion = false}) async {
    _reduceMotionOverride = appReduceMotion;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _preference =
          GraphicsPreference.fromStorage(prefs.getString(prefGraphicsModeKey));
      _showFpsOverlay = prefs.getBool(prefShowFpsKey) ?? false;
    } catch (_) {}

    double dpr = 2.5;
    double shortestSide = 390.0;
    bool sysReduceMotion = false;
    try {
      final ui.PlatformDispatcher pd = ui.PlatformDispatcher.instance;
      sysReduceMotion = pd.accessibilityFeatures.reduceMotion;
      if (pd.views.isNotEmpty) {
        final ui.FlutterView view = pd.views.first;
        dpr = view.devicePixelRatio > 0 ? view.devicePixelRatio : 2.5;
        final Size logical = view.physicalSize / dpr;
        if (logical.shortestSide > 0) {
          shortestSide = logical.shortestSide;
        }
      }
    } catch (_) {}

    RawDeviceSpecs raw = const RawDeviceSpecs();
    try {
      raw = await probePlatformDeviceSpecs();
    } catch (_) {}

    final GraphicsQualityTier detected = classifyHardwareTier(
      totalRamMb: raw.totalRamMb,
      cpuCores: raw.cpuCores,
      isLowRamDevice: raw.isLowRamDevice,
      devicePixelRatio: dpr,
      shortestLogicalSide: shortestSide,
      isMobilePlatform: raw.isMobilePlatform || shortestSide < 600,
      isWebPlatform: raw.isWebPlatform || kIsWeb,
      systemReduceMotion: sysReduceMotion,
    );

    _hardwareTier = detected;
    _hardwareReport = DeviceHardwareReport(
      totalRamMb: raw.totalRamMb,
      cpuCores: raw.cpuCores,
      isLowRamDevice: raw.isLowRamDevice,
      deviceModel: raw.deviceModel,
      devicePixelRatio: dpr,
      shortestLogicalSide: shortestSide,
      isMobilePlatform: raw.isMobilePlatform || shortestSide < 600,
      isWebPlatform: raw.isWebPlatform || kIsWeb,
      recommendedTier: detected,
    );

    _initialized = true;
    _applyImageCacheBudget(evictIfShrunk: false);
    _attachFrameTimingsMonitorIfRealApp();
    notifyListeners();
  }

  void syncAppReduceMotion(bool reduceMotion) {
    if (_reduceMotionOverride == reduceMotion) return;
    final GraphicsQualityTier prev = effectiveTier;
    _reduceMotionOverride = reduceMotion;
    if (effectiveTier != prev) {
      _applyImageCacheBudget(evictIfShrunk: effectiveTier.index < prev.index);
    }
    notifyListeners();
  }

  Future<void> setPreference(GraphicsPreference next) async {
    final GraphicsQualityTier prevTier = effectiveTier;
    _preference = next;
    if (next == GraphicsPreference.auto) {
      _runtimeAutoOverrideTier = null;
      _consecutiveSlowWindows = 0;
    }
    final GraphicsQualityTier newTier = effectiveTier;
    _applyImageCacheBudget(evictIfShrunk: newTier.index < prevTier.index);
    if (_cachedAtlasTargetWidth != profile.charAtlasTargetWidth) {
      _invalidateSharedAtlases();
    }
    notifyListeners();

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefGraphicsModeKey, next.storageKey);
    } catch (_) {}
  }

  Future<void> setShowFpsOverlay(bool enabled) async {
    if (_showFpsOverlay == enabled) return;
    _showFpsOverlay = enabled;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefShowFpsKey, enabled);
    } catch (_) {}
  }

  /// Test/debug helper to simulate frame-timing telemetry deterministically.
  @visibleForTesting
  void ingestFrameSpanSamplesMsForTest(
    List<double> spansMs, {
    bool bypassWarmup = true,
  }) {
    _processFrameSpanWindow(spansMs, bypassWarmup: bypassWarmup);
  }

  /// Test helper to configure hardware baseline directly in unit tests.
  @visibleForTesting
  void configureForTest({
    required GraphicsQualityTier hardwareTier,
    GraphicsPreference preference = GraphicsPreference.auto,
    DeviceHardwareReport? report,
  }) {
    _hardwareTier = hardwareTier;
    _preference = preference;
    _runtimeAutoOverrideTier = null;
    _consecutiveSlowWindows = 0;
    if (report != null) {
      _hardwareReport = report;
    }
    _initialized = true;
    notifyListeners();
  }

  void _applyImageCacheBudget({required bool evictIfShrunk}) {
    try {
      final ImageCache cache = PaintingBinding.instance.imageCache;
      final GraphicsProfile p = profile;
      cache.maximumSizeBytes = p.imageCacheMaxBytes;
      cache.maximumSize = p.imageCacheMaxCount;
      if (evictIfShrunk) {
        cache.clear();
      }
    } catch (_) {}
  }

  void _attachFrameTimingsMonitorIfRealApp() {
    if (_timingsAttached) return;
    try {
      final String bindingName =
          WidgetsBinding.instance.runtimeType.toString();
      if (bindingName.contains('Test')) {
        return; // Keep widget tests completely free of background callbacks
      }
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
      _timingsAttached = true;
    } catch (_) {}
  }

  void _onFrameTimings(List<ui.FrameTiming> timings) {
    if (timings.isEmpty) return;
    for (final ui.FrameTiming ft in timings) {
      final double buildMs = ft.buildDuration.inMicroseconds / 1000.0;
      final double rasterMs = ft.rasterDuration.inMicroseconds / 1000.0;
      // UI & Raster threads run in parallel on mobile/desktop; Web shares main thread.
      final double frameWorkMs =
          kIsWeb ? (buildMs + rasterMs) : math.max(buildMs, rasterMs);
      if (frameWorkMs > 0.2 && frameWorkMs < 350.0) {
        _frameSpansMs.add(frameWorkMs);
      }
    }
    if (_frameSpansMs.length >= 42) {
      final List<double> window = List<double>.from(_frameSpansMs);
      _frameSpansMs.clear();
      _processFrameSpanWindow(window, bypassWarmup: false);
    }
  }

  void _processFrameSpanWindow(
    List<double> spansMs, {
    required bool bypassWarmup,
  }) {
    if (spansMs.isEmpty) return;
    double sum = 0.0;
    int jankCount = 0;
    for (final double ms in spansMs) {
      sum += ms;
      if (ms > 33.5) jankCount++;
    }
    final double avgMs = sum / spansMs.length;
    final int nextFps = (1000.0 / avgMs.clamp(16.6, 200.0)).round().clamp(5, 60);
    final DateTime now = DateTime.now();

    bool shouldNotify = false;
    if ((_estimatedFps - nextFps).abs() >= 3 &&
        (_showFpsOverlay ||
            now.difference(_lastFpsPublishAt).inMilliseconds >= 2500)) {
      _estimatedFps = nextFps;
      _lastFpsPublishAt = now;
      if (_showFpsOverlay) {
        shouldNotify = true;
      }
    } else {
      _estimatedFps = nextFps;
    }

    // Automatic runtime downgrade protection when `Otomatik` is active!
    if (_preference == GraphicsPreference.auto &&
        effectiveTier != GraphicsQualityTier.low) {
      final bool warmedUp = bypassWarmup ||
          now.difference(_bootedAt).inMilliseconds >= 4500;
      final bool cooldownDone = bypassWarmup ||
          now.difference(_lastAutoStepDownAt).inMilliseconds >= 18000;

      if (warmedUp && cooldownDone) {
        final double jankRatio = jankCount / spansMs.length;
        final bool severelyLagging = avgMs > 30.0 || jankRatio > 0.42;
        if (severelyLagging) {
          _consecutiveSlowWindows++;
          if (_consecutiveSlowWindows >= 2) {
            _consecutiveSlowWindows = 0;
            _lastAutoStepDownAt = now;
            final GraphicsQualityTier stepped = effectiveTier.stepDown();
            if (stepped != effectiveTier) {
              _runtimeAutoOverrideTier = stepped;
              _applyImageCacheBudget(evictIfShrunk: true);
              if (_cachedAtlasTargetWidth != profile.charAtlasTargetWidth) {
                _invalidateSharedAtlases();
              }
              shouldNotify = true;
            }
          }
        } else {
          _consecutiveSlowWindows = math.max(0, _consecutiveSlowWindows - 1);
        }
      }
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  void _invalidateSharedAtlases() {
    _cachedAtlasTargetWidth = -1;
    _sharedCharAtlases.clear();
    _sharedPetSprites.clear();
    _inFlightCharLoad = null;
  }

  /// Shared downsampled character atlas loader so Moradon & Restriction Ward
  /// reuse a single tier-sized RGBA texture set (3.8 MB on Low vs 28 MB!).
  Future<Map<String, ui.Image>> loadSharedCharacterAtlases() {
    final int? targetW = profile.charAtlasTargetWidth;
    if (_sharedCharAtlases.length == 3 && _cachedAtlasTargetWidth == targetW) {
      return Future<Map<String, ui.Image>>.value(
        Map<String, ui.Image>.unmodifiable(_sharedCharAtlases),
      );
    }
    if (_inFlightCharLoad != null && _cachedAtlasTargetWidth == targetW) {
      return _inFlightCharLoad!;
    }
    _cachedAtlasTargetWidth = targetW;
    final Future<Map<String, ui.Image>> future =
        _decodeCharAtlases(targetWidth: targetW);
    _inFlightCharLoad = future;
    return future;
  }

  Future<Map<String, ui.Image>> _decodeCharAtlases({int? targetWidth}) async {
    const Map<String, String> paths = <String, String>{
      'savasci': 'assets/moradon/char_savasci_atlas.png',
      'golge': 'assets/moradon/char_golge_atlas.png',
      'simyaci': 'assets/moradon/char_simyaci_atlas.png',
    };
    final Map<String, ui.Image> decoded = <String, ui.Image>{};
    for (final MapEntry<String, String> entry in paths.entries) {
      try {
        final ByteData bytes = await rootBundle.load(entry.value);
        final ui.Codec codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
          targetWidth: targetWidth,
        );
        final ui.FrameInfo frame = await codec.getNextFrame();
        decoded[entry.key] = frame.image;
      } catch (_) {}
    }
    if (_cachedAtlasTargetWidth == targetWidth && decoded.isNotEmpty) {
      _sharedCharAtlases
        ..clear()
        ..addAll(decoded);
    }
    return Map<String, ui.Image>.unmodifiable(decoded);
  }

  /// Shared downsampled companion pet loader (skipped completely on Low tier!).
  Future<Map<String, ui.Image>> loadSharedPetSprites() async {
    if (!profile.enableCompanionPets) {
      return const <String, ui.Image>{};
    }
    if (_sharedPetSprites.isNotEmpty) {
      return Map<String, ui.Image>.unmodifiable(_sharedPetSprites);
    }
    final int targetW = profile.isLowOrMedium ? 160 : 320;
    const Map<String, String> paths = <String, String>{
      'solarPhoenix': 'assets/moradon/pet_solar_phoenix.png',
      'shadowRaven': 'assets/moradon/pet_shadow_raven.png',
      'arcaneWisp': 'assets/moradon/pet_arcane_wisp.png',
      'royalGriffin': 'assets/moradon/pet_royal_griffin.png',
    };
    for (final MapEntry<String, String> entry in paths.entries) {
      try {
        final ByteData bytes = await rootBundle.load(entry.value);
        final ui.Codec codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
          targetWidth: targetW,
        );
        final ui.FrameInfo frame = await codec.getNextFrame();
        _sharedPetSprites[entry.key] = frame.image;
      } catch (_) {}
    }
    return Map<String, ui.Image>.unmodifiable(_sharedPetSprites);
  }
}
