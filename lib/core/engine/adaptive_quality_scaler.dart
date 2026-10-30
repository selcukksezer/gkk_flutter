import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Hardware classification tiers for target device scaling in gkk_flutter.
///
/// Designed to cover the complete spectrum from low-end 2GB RAM budget devices
/// up to 2027 AAA flagship mobile SoCs.
enum HardwareTier {
  /// Eco-tier: Extreme power saving / < 1.8GB RAM ultra-budget devices (Android Go, low-end Mali-400 / Unisoc).
  /// Maximum decimation: 0.5x resolution scale, 0 fog steps, 150 particles, zero shadows, minimum draw calls.
  eco,

  /// Low-tier: 2GB–3GB RAM, Mali-G52 / Snapdragon 4xx / Helio P35 equivalent.
  /// Targets 30 FPS baseline with reduced fill-rate overhead.
  low,

  /// Mid-tier: 4GB–6GB RAM, Mali-G57 / Adreno 618 / Snapdragon 7xx equivalent.
  /// Targets 60 FPS baseline with balanced post-processing.
  mid,

  /// High-tier: 8GB–12GB RAM, Mali-G710 / Adreno 730 / Apple A16 equivalent.
  /// Targets 60 FPS with volumetric fog and full SSAO enabled.
  high,

  /// Ultra-tier: 16GB+ RAM, Immortalis-G925 / Adreno 830 / Apple A18 Pro equivalent.
  /// 2027 AAA flagship standard: raymarched volumetric godrays, 10K particle limits,
  /// 4-cascade shadow maps, and 120Hz display target support.
  ultra,
}

/// Hardware specification profile describing the host device's physical capabilities.
class DeviceHardwareProfile {
  /// Total physical system RAM in Megabytes (e.g. 2048, 4096, 8192, 16384).
  final int totalRamMb;

  /// Logical CPU core count.
  final int cpuCoreCount;

  /// GPU renderer string if queried via OpenGL / Vulkan / Impeller backend.
  /// (e.g. "Mali-G52 MP2", "Adreno (TM) 618", "Apple A18 Pro GPU").
  final String? gpuRenderer;

  /// GPU vendor name (e.g. "ARM", "Qualcomm", "Apple", "Imagination").
  final String? gpuVendor;

  /// Display maximum refresh rate in Hertz (e.g. 60.0, 90.0, 120.0).
  final double maxRefreshRate;

  /// Whether device supports compute shaders for crowd simulation & particle culling.
  final bool supportsComputeShaders;

  /// Whether device hardware decompressor supports Google Draco mesh compression.
  final bool supportsDraco;

  /// Whether device supports KTX2 / Basis Universal GPU texture transcoding.
  final bool supportsKtx2;

  const DeviceHardwareProfile({
    required this.totalRamMb,
    this.cpuCoreCount = 8,
    this.gpuRenderer,
    this.gpuVendor,
    this.maxRefreshRate = 60.0,
    this.supportsComputeShaders = true,
    this.supportsDraco = true,
    this.supportsKtx2 = true,
  });

  /// Factory preset for ultra-budget / Android Go reference device (1.5GB RAM, Mali-400 / Unisoc SC7731E).
  factory DeviceHardwareProfile.ecoUltraLowSpec() {
    return const DeviceHardwareProfile(
      totalRamMb: 1536,
      cpuCoreCount: 4,
      gpuRenderer: 'Mali-400 MP2',
      gpuVendor: 'ARM',
      maxRefreshRate: 60.0,
      supportsComputeShaders: false,
      supportsDraco: true,
      supportsKtx2: true,
    );
  }

  /// Factory preset for low-spec reference device (2GB RAM, Mali-G52 MP2).
  factory DeviceHardwareProfile.lowSpec2GbMaliG52() {
    return const DeviceHardwareProfile(
      totalRamMb: 2048,
      cpuCoreCount: 8,
      gpuRenderer: 'Mali-G52 MP2',
      gpuVendor: 'ARM',
      maxRefreshRate: 60.0,
      supportsComputeShaders: false,
      supportsDraco: true,
      supportsKtx2: true,
    );
  }

  /// Factory preset for mid-tier reference device (4GB-6GB RAM, Snapdragon 720G / Adreno 618).
  factory DeviceHardwareProfile.midSpecSnapdragon720() {
    return const DeviceHardwareProfile(
      totalRamMb: 4096,
      cpuCoreCount: 8,
      gpuRenderer: 'Adreno (TM) 618',
      gpuVendor: 'Qualcomm',
      maxRefreshRate: 60.0,
      supportsComputeShaders: true,
      supportsDraco: true,
      supportsKtx2: true,
    );
  }

  /// Factory preset for high-tier reference device (8GB RAM, Snapdragon 8+ Gen 1 / Adreno 730).
  factory DeviceHardwareProfile.highSpecAdreno730() {
    return const DeviceHardwareProfile(
      totalRamMb: 8192,
      cpuCoreCount: 8,
      gpuRenderer: 'Adreno (TM) 730',
      gpuVendor: 'Qualcomm',
      maxRefreshRate: 120.0,
      supportsComputeShaders: true,
      supportsDraco: true,
      supportsKtx2: true,
    );
  }

  /// Factory preset for 2027 AAA flagship reference device (16GB RAM, Immortalis-G925 / Adreno 830).
  factory DeviceHardwareProfile.ultraFlagship2027() {
    return const DeviceHardwareProfile(
      totalRamMb: 16384,
      cpuCoreCount: 8,
      gpuRenderer: 'Immortalis-G925 MC12',
      gpuVendor: 'ARM',
      maxRefreshRate: 120.0,
      supportsComputeShaders: true,
      supportsDraco: true,
      supportsKtx2: true,
    );
  }

  /// Automatically derives the appropriate [HardwareTier] by analyzing hardware
  /// memory ceilings, GPU vendor/renderer signatures, and compute capabilities.
  HardwareTier autoDetectTier() {
    // 1. Strict memory constraint: devices with <= 2560 MB RAM must run on Low tier
    // to strictly prevent Out-Of-Memory (OOM) background kills by the OS.
    if (totalRamMb < 1800) {
      return HardwareTier.eco;
    }
    if (totalRamMb <= 2560) {
      return HardwareTier.low;
    }

    final renderer = (gpuRenderer ?? '').toLowerCase();

    // 2. Ultra 2027 AAA flagship GPU signatures
    if (_matchesAny(renderer, const [
      'immortalis-g925',
      'immortalis-g720',
      'adreno 830',
      'adreno 750',
      'apple a18',
      'apple m3',
      'apple m4',
      'rtx 40',
      'rtx 30',
      'geforce',
      'radeon rx',
      'snapdragon 8 elite',
      'dimensity 9400',
    ])) {
      return HardwareTier.ultra;
    }

    // 3. High-tier GPU signatures
    if (_matchesAny(renderer, const [
      'mali-g710',
      'mali-g715',
      'mali-g78',
      'mali-g77',
      'adreno 730',
      'adreno 740',
      'adreno 660',
      'adreno 650',
      'apple a15',
      'apple a16',
      'apple a17',
      'apple m1',
      'apple m2',
      'tensor g2',
      'tensor g3',
      'tensor g4',
      'dimensity 9000',
      'dimensity 9200',
    ])) {
      return HardwareTier.high;
    }

    // 4. Mid-tier GPU signatures
    if (_matchesAny(renderer, const [
      'mali-g57',
      'mali-g68',
      'mali-g72',
      'mali-g76',
      'adreno 618',
      'adreno 619',
      'adreno 620',
      'adreno 640',
      'adreno 642',
      'apple a11',
      'apple a12',
      'apple a13',
      'apple a14',
      'dimensity 700',
      'dimensity 800',
      'dimensity 810',
      'dimensity 1080',
      'helio g90',
      'helio g95',
      'helio g99',
      'snapdragon 7',
    ])) {
      return HardwareTier.mid;
    }

    // 5. Low-tier GPU signatures
    if (_matchesAny(renderer, const [
      'mali-g52',
      'mali-g51',
      'mali-g31',
      'mali-t',
      'mali-400',
      'adreno 505',
      'adreno 506',
      'adreno 508',
      'adreno 512',
      'adreno 610',
      'adreno 612',
      'powervr',
      'helio p',
      'helio a',
      'unisoc',
      'spreadtrum',
      'snapdragon 4',
    ])) {
      return HardwareTier.low;
    }

    // 6. Fallback based strictly on RAM capacity when GPU string is unrecognised
    if (totalRamMb < 3500) {
      return HardwareTier.low;
    } else if (totalRamMb < 7000) {
      return HardwareTier.mid;
    } else if (totalRamMb < 14000) {
      return HardwareTier.high;
    } else {
      return HardwareTier.ultra;
    }
  }

  static bool _matchesAny(String text, List<String> patterns) {
    for (final pattern in patterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }
}

/// Comprehensive, immutable snapshot of graphics rendering settings
/// controlled dynamically by the [AdaptiveQualityScaler].
@immutable
class QualitySettings {
  /// The parent hardware tier establishing base capability presets.
  final HardwareTier tier;

  /// Dynamic runtime throttle level:
  /// - 0: Full baseline quality.
  /// - 1: Light downscale (0.75x resolution, reduced fog, SSAO blur off, capped particles).
  /// - 2: Medium downscale (0.5x resolution, minimal fog, SSAO disabled, tightly capped particles).
  /// - 3: Severe downscale (0.5x resolution, 0 fog, minimal particles, shadows disabled).
  final int throttleLevel;

  /// Internal render resolution scale multiplier.
  /// Strictly bounded within `[0.5, 1.0]` (or up to 1.25 for Ultra supersampling).
  final double renderResolutionScale;

  /// Number of march steps used in volumetric fog & god-ray integration.
  /// Ultra: 64, High: 32, Mid: 16, Low: 4, Throttled: 0–4.
  final int volumetricFogStepCount;

  /// Screen Space Ambient Occlusion (SSAO) activation status.
  final bool ssaoEnabled;

  /// SSAO bilateral blur filter pass.
  /// Disabled during dynamic downscaling to reduce GPU fill-rate bandwidth.
  final bool ssaoBlurEnabled;

  /// Maximum simultaneous GPU particles rendered in active combat/VFX.
  /// Ultra: 10,000, High: 5,000, Mid: 2,000, Low: 500, Throttled: 100–250.
  final int maxActiveParticles;

  /// Resolution of cascaded shadow maps (e.g. 2048, 1024, 512, 256, 0 for off).
  final int shadowResolution;

  /// Number of directional shadow cascades (0 to 4).
  final int shadowCascadeCount;

  /// Distance multiplier for Level of Detail (LOD) mesh switches.
  /// Higher values push LOD0 further away; lower values trigger LOD1/LOD2/VAT sooner.
  final double lodDistanceMultiplier;

  /// Post-processing bloom pass status.
  final bool bloomEnabled;

  /// Maximum entities allowed simultaneously in the crowd rendering pool.
  final int crowdDensityCap;

  /// Display target frames per second (e.g. 30.0, 60.0, 120.0).
  final double targetFps;

  const QualitySettings({
    required this.tier,
    required this.throttleLevel,
    required this.renderResolutionScale,
    required this.volumetricFogStepCount,
    required this.ssaoEnabled,
    required this.ssaoBlurEnabled,
    required this.maxActiveParticles,
    required this.shadowResolution,
    required this.shadowCascadeCount,
    required this.lodDistanceMultiplier,
    required this.bloomEnabled,
    required this.crowdDensityCap,
    required this.targetFps,
  });

  /// Factory constructor producing baseline unthrottled presets for a given [HardwareTier].
  factory QualitySettings.forTier(HardwareTier tier) {
    switch (tier) {
      case HardwareTier.eco:
        return const QualitySettings(
          tier: HardwareTier.eco,
          throttleLevel: 0,
          renderResolutionScale: 0.5,
          volumetricFogStepCount: 0,
          ssaoEnabled: false,
          ssaoBlurEnabled: false,
          maxActiveParticles: 150,
          shadowResolution: 0,
          shadowCascadeCount: 0,
          lodDistanceMultiplier: 0.35,
          bloomEnabled: false,
          crowdDensityCap: 250,
          targetFps: 30.0,
        );

      case HardwareTier.low:
        return const QualitySettings(
          tier: HardwareTier.low,
          throttleLevel: 0,
          renderResolutionScale: 0.75,
          volumetricFogStepCount: 4,
          ssaoEnabled: false,
          ssaoBlurEnabled: false,
          maxActiveParticles: 500,
          shadowResolution: 0, // Disabled or simple blob shadow
          shadowCascadeCount: 0,
          lodDistanceMultiplier: 0.5,
          bloomEnabled: false,
          crowdDensityCap: 500,
          targetFps: 30.0,
        );

      case HardwareTier.mid:
        return const QualitySettings(
          tier: HardwareTier.mid,
          throttleLevel: 0,
          renderResolutionScale: 1.0,
          volumetricFogStepCount: 16,
          ssaoEnabled: true,
          ssaoBlurEnabled: true,
          maxActiveParticles: 2000,
          shadowResolution: 512,
          shadowCascadeCount: 2,
          lodDistanceMultiplier: 0.75,
          bloomEnabled: true,
          crowdDensityCap: 2000,
          targetFps: 60.0,
        );

      case HardwareTier.high:
        return const QualitySettings(
          tier: HardwareTier.high,
          throttleLevel: 0,
          renderResolutionScale: 1.0,
          volumetricFogStepCount: 32,
          ssaoEnabled: true,
          ssaoBlurEnabled: true,
          maxActiveParticles: 5000,
          shadowResolution: 1024,
          shadowCascadeCount: 3,
          lodDistanceMultiplier: 1.0,
          bloomEnabled: true,
          crowdDensityCap: 5000,
          targetFps: 60.0,
        );

      case HardwareTier.ultra:
        return const QualitySettings(
          tier: HardwareTier.ultra,
          throttleLevel: 0,
          renderResolutionScale: 1.0,
          volumetricFogStepCount: 64,
          ssaoEnabled: true,
          ssaoBlurEnabled: true,
          maxActiveParticles: 10000,
          shadowResolution: 2048,
          shadowCascadeCount: 4,
          lodDistanceMultiplier: 1.5,
          bloomEnabled: true,
          crowdDensityCap: 10000,
          targetFps: 60.0,
        );
    }
  }

  /// Produces a copy with adjusted settings corresponding to a specific throttle level.
  QualitySettings withThrottleLevel(int newThrottleLevel) {
    if (newThrottleLevel <= 0) {
      return QualitySettings.forTier(tier).copyWith(targetFps: targetFps);
    }

    final base = QualitySettings.forTier(tier).copyWith(targetFps: targetFps);

    switch (newThrottleLevel) {
      case 1:
        // Level 1: Light downscale
        // 1.0x -> 0.75x; 0.75x -> 0.5x
        final double scale = (tier == HardwareTier.low || tier == HardwareTier.eco) ? 0.5 : 0.75;
        return base.copyWith(
          throttleLevel: 1,
          renderResolutionScale: scale.clamp(0.5, 1.0),
          volumetricFogStepCount: math.max(0, (base.volumetricFogStepCount / 2).round()),
          ssaoBlurEnabled: false, // Disables SSAO blur per dispatch requirement
          maxActiveParticles: (base.maxActiveParticles * 0.5).round(),
          lodDistanceMultiplier: base.lodDistanceMultiplier * 0.8,
        );

      case 2:
        // Level 2: Medium downscale
        // Render resolution down to 0.5x (minimum bound)
        return base.copyWith(
          throttleLevel: 2,
          renderResolutionScale: 0.5,
          volumetricFogStepCount: math.max(0, (base.volumetricFogStepCount / 4).round()),
          ssaoEnabled: false, // Disables SSAO completely
          ssaoBlurEnabled: false,
          maxActiveParticles: math.min(500, (base.maxActiveParticles * 0.25).round()),
          shadowResolution: math.min(512, base.shadowResolution ~/ 2),
          shadowCascadeCount: math.max(0, base.shadowCascadeCount - 1),
          lodDistanceMultiplier: base.lodDistanceMultiplier * 0.6,
        );

      default:
        // Level 3+: Severe downscale
        return base.copyWith(
          throttleLevel: newThrottleLevel,
          renderResolutionScale: 0.5, // Strict lower bound
          volumetricFogStepCount: 0, // Fog disabled completely
          ssaoEnabled: false,
          ssaoBlurEnabled: false,
          maxActiveParticles: math.min(100, math.max(25, (base.maxActiveParticles * 0.15).round())), // Capped to emergency limit
          shadowResolution: 0,
          shadowCascadeCount: 0,
          bloomEnabled: false,
          lodDistanceMultiplier: base.lodDistanceMultiplier * 0.4,
          crowdDensityCap: math.min(300, base.crowdDensityCap),
        );
    }
  }

  QualitySettings copyWith({
    HardwareTier? tier,
    int? throttleLevel,
    double? renderResolutionScale,
    int? volumetricFogStepCount,
    bool? ssaoEnabled,
    bool? ssaoBlurEnabled,
    int? maxActiveParticles,
    int? shadowResolution,
    int? shadowCascadeCount,
    double? lodDistanceMultiplier,
    bool? bloomEnabled,
    int? crowdDensityCap,
    double? targetFps,
  }) {
    return QualitySettings(
      tier: tier ?? this.tier,
      throttleLevel: throttleLevel ?? this.throttleLevel,
      renderResolutionScale: renderResolutionScale ?? this.renderResolutionScale,
      volumetricFogStepCount: volumetricFogStepCount ?? this.volumetricFogStepCount,
      ssaoEnabled: ssaoEnabled ?? this.ssaoEnabled,
      ssaoBlurEnabled: ssaoBlurEnabled ?? this.ssaoBlurEnabled,
      maxActiveParticles: maxActiveParticles ?? this.maxActiveParticles,
      shadowResolution: shadowResolution ?? this.shadowResolution,
      shadowCascadeCount: shadowCascadeCount ?? this.shadowCascadeCount,
      lodDistanceMultiplier: lodDistanceMultiplier ?? this.lodDistanceMultiplier,
      bloomEnabled: bloomEnabled ?? this.bloomEnabled,
      crowdDensityCap: crowdDensityCap ?? this.crowdDensityCap,
      targetFps: targetFps ?? this.targetFps,
    );
  }

  Map<String, dynamic> toJson() => {
        'tier': tier.name,
        'throttleLevel': throttleLevel,
        'renderResolutionScale': renderResolutionScale,
        'volumetricFogStepCount': volumetricFogStepCount,
        'ssaoEnabled': ssaoEnabled,
        'ssaoBlurEnabled': ssaoBlurEnabled,
        'maxActiveParticles': maxActiveParticles,
        'shadowResolution': shadowResolution,
        'shadowCascadeCount': shadowCascadeCount,
        'lodDistanceMultiplier': lodDistanceMultiplier,
        'bloomEnabled': bloomEnabled,
        'crowdDensityCap': crowdDensityCap,
        'targetFps': targetFps,
      };

  @override
  String toString() =>
      'QualitySettings(tier: ${tier.name}, throttle: $throttleLevel, scale: ${renderResolutionScale.toStringAsFixed(2)}x, fogSteps: $volumetricFogStepCount, ssaoBlur: $ssaoBlurEnabled, particles: $maxActiveParticles, shadows: ${shadowResolution}px)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QualitySettings &&
          runtimeType == other.runtimeType &&
          tier == other.tier &&
          throttleLevel == other.throttleLevel &&
          (renderResolutionScale - other.renderResolutionScale).abs() < 0.001 &&
          volumetricFogStepCount == other.volumetricFogStepCount &&
          ssaoEnabled == other.ssaoEnabled &&
          ssaoBlurEnabled == other.ssaoBlurEnabled &&
          maxActiveParticles == other.maxActiveParticles &&
          shadowResolution == other.shadowResolution &&
          shadowCascadeCount == other.shadowCascadeCount &&
          (lodDistanceMultiplier - other.lodDistanceMultiplier).abs() < 0.001 &&
          bloomEnabled == other.bloomEnabled &&
          crowdDensityCap == other.crowdDensityCap &&
          (targetFps - other.targetFps).abs() < 0.01;

  @override
  int get hashCode => Object.hash(
        tier,
        throttleLevel,
        renderResolutionScale,
        volumetricFogStepCount,
        ssaoEnabled,
        ssaoBlurEnabled,
        maxActiveParticles,
        shadowResolution,
        shadowCascadeCount,
        lodDistanceMultiplier,
        bloomEnabled,
        crowdDensityCap,
        targetFps,
      );
}

/// Rolling 60-frame moving average calculator and frame-pacing telemetry tracker.
///
/// Implements a fixed-size ring buffer for exact O(1) insertion and stable numerical
/// computation of rolling average, 95th percentile, standard deviation, and dropped frames.
class FrameTimeTracker {
  /// Ring buffer capacity strictly adhering to the 60-frame moving window requirement.
  static const int capacity = 60;

  final List<double> _buffer = List<double>.filled(capacity, 0.0);
  int _head = 0;
  int _count = 0;
  int _totalRecorded = 0;
  int _droppedFrames = 0;

  /// Returns the number of frame samples currently held in the rolling window (0 to 60).
  int get count => _count;

  /// Lifetime count of all frames recorded since instantiation or last reset.
  int get totalRecorded => _totalRecorded;

  /// Lifetime count of dropped frames exceeding target frame time by > 20%.
  int get droppedFrames => _droppedFrames;

  /// Records a frame duration in milliseconds.
  void record(double frameTimeMs, double targetFrameTimeMs) {
    if (frameTimeMs < 0.0) frameTimeMs = 0.0;
    _totalRecorded++;

    // Track frame drop if frame time exceeds target by > 20%
    if (targetFrameTimeMs > 0 && frameTimeMs > targetFrameTimeMs * 1.20) {
      _droppedFrames++;
    }

    _buffer[_head] = frameTimeMs;
    _head = (_head + 1) % capacity;
    if (_count < capacity) {
      _count++;
    }
  }

  /// Rolling moving average frame time in milliseconds over the last <= 60 frames.
  double get averageFrameTimeMs {
    if (_count == 0) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < _count; i++) {
      sum += _buffer[i];
    }
    return sum / _count;
  }

  /// Current smoothed frames per second derived from the rolling 60-frame average.
  double get currentFps {
    final avg = averageFrameTimeMs;
    if (avg <= 0.0001) return 0.0;
    return 1000.0 / avg;
  }

  /// Minimum frame time within current rolling window.
  double get minFrameTimeMs {
    if (_count == 0) return 0.0;
    double minVal = _buffer[0];
    for (int i = 1; i < _count; i++) {
      if (_buffer[i] < minVal) minVal = _buffer[i];
    }
    return minVal;
  }

  /// Maximum frame time within current rolling window.
  double get maxFrameTimeMs {
    if (_count == 0) return 0.0;
    double maxVal = _buffer[0];
    for (int i = 1; i < _count; i++) {
      if (_buffer[i] > maxVal) maxVal = _buffer[i];
    }
    return maxVal;
  }

  /// 95th-percentile frame time in milliseconds (P95 latency).
  double get p95FrameTimeMs => _percentile(0.95);

  /// 99th-percentile frame time in milliseconds (P99 latency).
  double get p99FrameTimeMs => _percentile(0.99);

  /// Standard deviation of frame times in the rolling window (jitter metric).
  double get standardDeviationMs {
    if (_count < 2) return 0.0;
    final mean = averageFrameTimeMs;
    double sumSquaredDiff = 0.0;
    for (int i = 0; i < _count; i++) {
      final diff = _buffer[i] - mean;
      sumSquaredDiff += diff * diff;
    }
    return math.sqrt(sumSquaredDiff / _count);
  }

  double _percentile(double fraction) {
    if (_count == 0) return 0.0;
    final sorted = List<double>.generate(_count, (i) => _buffer[i])..sort();
    final index = (sorted.length * fraction).clamp(0, sorted.length - 1).toInt();
    return sorted[index];
  }

  /// Resets rolling sample history and dropped frame counters.
  void reset() {
    _head = 0;
    _count = 0;
    _totalRecorded = 0;
    _droppedFrames = 0;
    _buffer.fillRange(0, capacity, 0.0);
  }
}

/// Telemetry metrics snapshot emitted by [AdaptiveQualityScaler].
class ScalerTelemetry {
  final HardwareTier tier;
  final int throttleLevel;
  final double resolutionScale;
  final int fogStepCount;
  final bool ssaoBlurEnabled;
  final int particleLimit;
  final double rollingAvgFrameTimeMs;
  final double rollingFps;
  final double p95FrameTimeMs;
  final double jitterStandardDeviationMs;
  final int totalFramesRecorded;
  final int droppedFramesCount;
  final Duration stableUnderThresholdDuration;
  final int totalDownscaleEvents;
  final int totalUpscaleEvents;
  final double p95FrameBudgetMs;
  final bool isMemoryConstrained;
  final int? availableRamMb;

  const ScalerTelemetry({
    required this.tier,
    required this.throttleLevel,
    required this.resolutionScale,
    required this.fogStepCount,
    required this.ssaoBlurEnabled,
    required this.particleLimit,
    required this.rollingAvgFrameTimeMs,
    required this.rollingFps,
    required this.p95FrameTimeMs,
    required this.jitterStandardDeviationMs,
    required this.totalFramesRecorded,
    required this.droppedFramesCount,
    required this.stableUnderThresholdDuration,
    required this.totalDownscaleEvents,
    required this.totalUpscaleEvents,
    this.p95FrameBudgetMs = 0.0,
    this.isMemoryConstrained = false,
    this.availableRamMb,
  });

  Map<String, dynamic> toJson() => {
        'tier': tier.name,
        'throttleLevel': throttleLevel,
        'resolutionScale': resolutionScale,
        'fogStepCount': fogStepCount,
        'ssaoBlurEnabled': ssaoBlurEnabled,
        'particleLimit': particleLimit,
        'rollingAvgFrameTimeMs': rollingAvgFrameTimeMs,
        'rollingFps': rollingFps,
        'p95FrameTimeMs': p95FrameTimeMs,
        'jitterStandardDeviationMs': jitterStandardDeviationMs,
        'totalFramesRecorded': totalFramesRecorded,
        'droppedFramesCount': droppedFramesCount,
        'stableUnderThresholdMs': stableUnderThresholdDuration.inMilliseconds,
        'totalDownscaleEvents': totalDownscaleEvents,
        'totalUpscaleEvents': totalUpscaleEvents,
        'p95FrameBudgetMs': p95FrameBudgetMs,
        'isMemoryConstrained': isMemoryConstrained,
        'availableRamMb': availableRamMb,
      };

  @override
  String toString() =>
      'ScalerTelemetry(tier: ${tier.name}, throttle: $throttleLevel, scale: ${resolutionScale.toStringAsFixed(2)}x, '
      'FPS: ${rollingFps.toStringAsFixed(1)}, AvgTime: ${rollingAvgFrameTimeMs.toStringAsFixed(2)}ms, '
      'P95: ${p95FrameTimeMs.toStringAsFixed(2)}ms, Budget: ${p95FrameBudgetMs.toStringAsFixed(2)}ms, '
      'Jitter: ${jitterStandardDeviationMs.toStringAsFixed(2)}ms, '
      'Frames: $totalFramesRecorded, Dropped: $droppedFramesCount, LowMem: $isMemoryConstrained)';
}

/// Production-ready Adaptive Quality Scaler for low-spec and high-spec devices.
///
/// Continuously monitors frame pacing via a rolling 60-frame moving window.
/// Dynamically scales rendering resolution (0.75x or 0.5x), reduces volumetric
/// fog steps, disables SSAO blur, and caps particle limits when FPS drops below target.
///
/// Incorporates strict hysteresis prevention: when frame times remain uninterruptedly
/// stable under recovery threshold (0.85 * targetFrameTime, e.g. ~14.1ms at 60Hz, ~28.3ms at 30Hz)
/// for > 5 seconds, it scales quality back up smoothly step by step.
class AdaptiveQualityScaler extends ChangeNotifier {
  /// Minimum allowed internal render resolution scale.
  static const double minResolutionScale = 0.5;

  /// Default maximum internal render resolution scale.
  static const double maxResolutionScale = 1.0;

  /// Maximum runtime throttle level before hitting hard floor.
  static const int maxThrottleLevel = 3;

  /// Physical hardware profile.
  final DeviceHardwareProfile hardwareProfile;

  /// Target frame time in milliseconds (1000.0 / targetFps).
  double get targetFrameTimeMs => 1000.0 / targetFps;

  /// Display target FPS.
  final double targetFps;

  /// Threshold FPS below which dynamic downscaling is triggered.
  /// (e.g. 54 FPS on 60Hz target; 28 FPS on 30Hz target).
  final double downscaleFpsThreshold;

  /// Frame time threshold under which performance is considered stable for recovery.
  /// Calculated dynamically as 0.85 * targetFrameTimeMs (e.g. ~28.3ms on 30Hz target, ~14.1ms on 60Hz target)
  /// unless explicitly overridden by [customRecoveryThresholdMs] or [recoveryThresholdMs].
  final double recoveryThresholdMs;

  /// Frame budget for 95th-percentile (P95) latency in milliseconds.
  /// Violations of this budget indicate micro-stutters and prompt dynamic downscaling.
  final double p95FrameBudgetMs;

  /// Factor multiplying target frame time to determine [p95FrameBudgetMs] (default: 1.25).
  final double p95BudgetFactor;

  /// Critical available memory threshold in MB below which downscaling is triggered (default: 250 MB).
  final int criticalMemoryThresholdMb;

  /// Duration for which frame time must remain uninterruptedly <= [recoveryThresholdMs]
  /// before upscaling by one step (5 seconds).
  final Duration requiredStabilityDuration;

  /// Minimum warm-up samples required before triggering automatic downscaling.
  final int minimumWarmupFrames;

  /// Minimum frame count required between consecutive dynamic downscale adjustments.
  /// Defaults to 30 frames (hysteresis cooldown to prevent runaway downscale cascade).
  final int downscaleCooldownFrames;

  /// Optional clock provider for deterministic unit testing.
  final DateTime Function()? _clock;

  final FrameTimeTracker _frameTracker = FrameTimeTracker();
  final StreamController<QualitySettings> _settingsStreamController =
      StreamController<QualitySettings>.broadcast();

  HardwareTier _currentTier;
  QualitySettings _currentSettings;
  int _currentThrottleLevel = 0;
  bool _isAutoScalingEnabled = true;

  DateTime? _stableSince;
  int _framesSinceLastThrottleChange = 999;
  int _totalDownscaleEvents = 0;
  int _totalUpscaleEvents = 0;
  int? _currentAvailableRamMb;
  bool _isMemoryConstrained = false;

  AdaptiveQualityScaler({
    DeviceHardwareProfile? profile,
    HardwareTier? initialTier,
    double? customTargetFps,
    double? customDownscaleFpsThreshold,
    double? recoveryThresholdMs,
    double? customRecoveryThresholdMs,
    this.requiredStabilityDuration = const Duration(seconds: 5),
    this.minimumWarmupFrames = 10,
    this.downscaleCooldownFrames = 30,
    this.p95BudgetFactor = 1.25,
    double? customP95FrameBudgetMs,
    this.criticalMemoryThresholdMb = 250,
    DateTime Function()? clock,
  })  : hardwareProfile = profile ?? DeviceHardwareProfile.midSpecSnapdragon720(),
        targetFps = _resolveTargetFps(profile, initialTier, customTargetFps),
        downscaleFpsThreshold = _resolveDownscaleFpsThreshold(
          _resolveTargetFps(profile, initialTier, customTargetFps),
          customDownscaleFpsThreshold,
        ),
        recoveryThresholdMs = customRecoveryThresholdMs ??
            recoveryThresholdMs ??
            (_resolveTargetFrameTimeMs(
                  _resolveTargetFps(profile, initialTier, customTargetFps),
                ) *
                0.85),
        p95FrameBudgetMs = customP95FrameBudgetMs ??
            (_resolveTargetFrameTimeMs(
                  _resolveTargetFps(profile, initialTier, customTargetFps),
                ) *
                p95BudgetFactor),
        _clock = clock,
        _currentTier = initialTier ?? (profile?.autoDetectTier() ?? HardwareTier.mid),
        _currentSettings = QualitySettings.forTier(
            initialTier ?? (profile?.autoDetectTier() ?? HardwareTier.mid)) {
    // If targetFps was customized, update settings
    if ((_currentSettings.targetFps - targetFps).abs() > 0.01) {
      _currentSettings = _currentSettings.copyWith(targetFps: targetFps);
    }
  }

  static double _resolveTargetFps(
    DeviceHardwareProfile? profile,
    HardwareTier? initialTier,
    double? customTargetFps,
  ) {
    if (customTargetFps != null) return customTargetFps;
    if (initialTier == HardwareTier.eco) return 30.0;
    if (initialTier == HardwareTier.low) return 30.0;
    if (profile?.autoDetectTier() == HardwareTier.eco) return 30.0;
    if (profile?.autoDetectTier() == HardwareTier.low) return 30.0;
    return 60.0;
  }

  static double _resolveDownscaleFpsThreshold(
    double targetFps,
    double? customDownscaleFpsThreshold,
  ) {
    if (customDownscaleFpsThreshold != null) return customDownscaleFpsThreshold;
    if (targetFps <= 35.0) return 28.0;
    if (targetFps >= 90.0) return targetFps * 0.9;
    return 54.0;
  }

  static double _resolveTargetFrameTimeMs(double targetFps) => 1000.0 / targetFps;

  /// Active hardware tier.
  HardwareTier get currentTier => _currentTier;

  /// Active runtime quality settings.
  QualitySettings get currentSettings => _currentSettings;

  /// Rolling 60-frame moving tracker.
  FrameTimeTracker get frameTracker => _frameTracker;

  /// Current throttle level (0 = baseline, 1 = light, 2 = medium, 3 = severe).
  int get currentThrottleLevel => _currentThrottleLevel;

  /// Current internal render resolution scale.
  double get currentResolutionScale => _currentSettings.renderResolutionScale;

  /// Whether dynamic auto-scaling is enabled.
  bool get isAutoScalingEnabled => _isAutoScalingEnabled;

  /// Total count of dynamic downscale adjustments performed.
  int get totalDownscaleEvents => _totalDownscaleEvents;

  /// Total count of dynamic upscale recovery adjustments performed.
  int get totalUpscaleEvents => _totalUpscaleEvents;

  /// Current uninterrupted duration during which frame times have stayed <= recoveryThresholdMs.
  Duration get currentStableDuration {
    final stable = _stableSince;
    if (stable == null) return Duration.zero;
    final now = _now();
    final diff = now.difference(stable);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Broadcast stream emitting whenever quality settings are modified.
  Stream<QualitySettings> get onSettingsChanged => _settingsStreamController.stream;

  /// Whether device system memory is currently under critical pressure.
  bool get isMemoryConstrained => _isMemoryConstrained;

  /// Currently recorded available system RAM in Megabytes.
  int? get currentAvailableRamMb => _currentAvailableRamMb;

  /// Ingests system memory diagnostics and dynamically throttles quality settings
  /// when available RAM falls below [criticalMemoryThresholdMb] or under 12% total capacity.
  void recordMemoryPressure({
    required int availableRamMb,
    int? totalRamMb,
  }) {
    _currentAvailableRamMb = availableRamMb;
    final total = totalRamMb ?? hardwareProfile.totalRamMb;
    final marginPercent = (availableRamMb / math.max(1, total)) * 100.0;

    final bool underPressure = availableRamMb < criticalMemoryThresholdMb || marginPercent < 12.0;

    if (underPressure != _isMemoryConstrained) {
      _isMemoryConstrained = underPressure;
      if (_isMemoryConstrained && _isAutoScalingEnabled) {
        if (_currentThrottleLevel < maxThrottleLevel) {
          _applyThrottleLevel(_currentThrottleLevel + 1);
          _totalDownscaleEvents++;
          _stableSince = null;
          _framesSinceLastThrottleChange = 0;
        }
      }
      notifyListeners();
    }
  }

  DateTime _now() => _clock != null ? _clock() : DateTime.now();

  /// Feed a newly completed frame's duration in milliseconds.
  ///
  /// Updates the rolling 60-frame moving average and evaluates dynamic downscale
  /// or hysteresis-protected upscale recovery conditions.
  void recordFrameTime(double frameTimeMs, {DateTime? timestamp}) {
    final now = timestamp ?? _now();
    _frameTracker.record(frameTimeMs, targetFrameTimeMs);
    _framesSinceLastThrottleChange++;

    if (!_isAutoScalingEnabled) return;

    // Minimum samples required to avoid false triggers on cold startup
    if (_frameTracker.count < minimumWarmupFrames) {
      _evaluateStability(frameTimeMs, now);
      return;
    }

    final rollingFps = _frameTracker.currentFps;
    final p95 = _frameTracker.p95FrameTimeMs;

    // 1. DOWNSCALE CONDITION:
    // Triggers when rolling 60-frame average drops below downscale threshold (e.g. < 54 FPS on 60Hz, or < 28 FPS on 30Hz),
    // OR P95 frame latency violates frame budget (p95 > p95FrameBudgetMs),
    // OR device is under critical memory pressure (isMemoryConstrained),
    // AND the current frame is actively struggling (frameTimeMs > targetFrameTimeMs || isMemoryConstrained),
    // AND the downscale cooldown period has elapsed.
    final bool fpsUnderThreshold = rollingFps < downscaleFpsThreshold;
    final bool p95BudgetViolated = p95 > p95FrameBudgetMs;
    final bool isCurrentlyStruggling = frameTimeMs > targetFrameTimeMs || _isMemoryConstrained;

    if ((fpsUnderThreshold || p95BudgetViolated || _isMemoryConstrained) &&
        isCurrentlyStruggling &&
        _currentThrottleLevel < maxThrottleLevel &&
        _framesSinceLastThrottleChange >= downscaleCooldownFrames) {
      _applyThrottleLevel(_currentThrottleLevel + 1);
      _totalDownscaleEvents++;
      // Reset stability counter immediately on downscale
      _stableSince = null;
      _framesSinceLastThrottleChange = 0;
      return;
    }

    // 2. UPSCALE RECOVERY CONDITION WITH HYSTERESIS PREVENTION:
    // Frame times must remain continuously <= recoveryThresholdMs and P95 latency within budget for > 5 seconds
    _evaluateStability(frameTimeMs, now);
  }

  /// Feeds a frame using a Dart [Duration].
  void recordFrameDuration(Duration duration, {DateTime? timestamp}) {
    recordFrameTime(duration.inMicroseconds / 1000.0, timestamp: timestamp);
  }

  void _evaluateStability(double frameTimeMs, DateTime now) {
    if (_currentThrottleLevel <= 0) {
      // Already at full baseline quality, no upscale needed
      _stableSince = null;
      return;
    }

    // If memory is critically constrained, upscale recovery is prohibited
    if (_isMemoryConstrained) {
      _stableSince = null;
      return;
    }

    final bool isFrameSmooth = frameTimeMs <= recoveryThresholdMs;
    final bool isP95Smooth = _frameTracker.p95FrameTimeMs <= (targetFrameTimeMs * 1.05);

    if (isFrameSmooth && isP95Smooth) {
      // Frame and P95 are well within smooth performance ceiling
      final stable = _stableSince;
      if (stable == null) {
        _stableSince = now;
      } else {
        final elapsed = now.difference(stable);
        if (elapsed >= requiredStabilityDuration) {
          // Hysteresis condition satisfied: 5+ continuous seconds under recoveryThresholdMs & P95 budget
          _applyThrottleLevel(_currentThrottleLevel - 1);
          _totalUpscaleEvents++;
          // Reset stability start time to now so the next upscale step requires
          // another full 5 seconds of stability, preventing rapid oscillation!
          // If already at baseline (Level 0), no further upscale is needed, so clear timer.
          _stableSince = _currentThrottleLevel <= 0 ? null : now;
          _framesSinceLastThrottleChange = 0;
        }
      }
    } else {
      // Any single frame or P95 exceeding recovery budget breaks continuous stability and resets counter!
      _stableSince = null;
    }
  }

  void _applyThrottleLevel(int newLevel) {
    _currentThrottleLevel = newLevel.clamp(0, maxThrottleLevel);
    _currentSettings = QualitySettings.forTier(_currentTier)
        .copyWith(targetFps: targetFps)
        .withThrottleLevel(_currentThrottleLevel);

    notifyListeners();
    _settingsStreamController.add(_currentSettings);
  }

  /// Manually switches the active hardware tier.
  void setHardwareTier(HardwareTier tier) {
    _currentTier = tier;
    _currentThrottleLevel = 0;
    _stableSince = null;
    _framesSinceLastThrottleChange = 999;
    _currentSettings = QualitySettings.forTier(tier).copyWith(targetFps: targetFps);

    notifyListeners();
    _settingsStreamController.add(_currentSettings);
  }

  /// Manually overrides the internal render resolution scale.
  /// The value is strictly clamped between [minResolutionScale] (0.5) and [maxResolutionScale] (1.0).
  void setRenderResolutionScale(double scale) {
    final clamped = scale.clamp(minResolutionScale, maxResolutionScale);
    _currentSettings = _currentSettings.copyWith(renderResolutionScale: clamped);

    notifyListeners();
    _settingsStreamController.add(_currentSettings);
  }

  /// Enables or disables dynamic automatic runtime quality scaling.
  void setAutoScaling(bool enabled) {
    if (_isAutoScalingEnabled == enabled) return;
    _isAutoScalingEnabled = enabled;
    _stableSince = null;
    notifyListeners();
  }

  /// Resets rolling performance metrics and stability tracking.
  void resetMetrics() {
    _frameTracker.reset();
    _stableSince = null;
    _framesSinceLastThrottleChange = 999;
    _isMemoryConstrained = false;
  }

  /// Returns a snapshot of performance telemetry and scaling state.
  ScalerTelemetry getTelemetry() {
    return ScalerTelemetry(
      tier: _currentTier,
      throttleLevel: _currentThrottleLevel,
      resolutionScale: _currentSettings.renderResolutionScale,
      fogStepCount: _currentSettings.volumetricFogStepCount,
      ssaoBlurEnabled: _currentSettings.ssaoBlurEnabled,
      particleLimit: _currentSettings.maxActiveParticles,
      rollingAvgFrameTimeMs: _frameTracker.averageFrameTimeMs,
      rollingFps: _frameTracker.currentFps,
      p95FrameTimeMs: _frameTracker.p95FrameTimeMs,
      jitterStandardDeviationMs: _frameTracker.standardDeviationMs,
      totalFramesRecorded: _frameTracker.totalRecorded,
      droppedFramesCount: _frameTracker.droppedFrames,
      stableUnderThresholdDuration: currentStableDuration,
      totalDownscaleEvents: _totalDownscaleEvents,
      totalUpscaleEvents: _totalUpscaleEvents,
      p95FrameBudgetMs: p95FrameBudgetMs,
      isMemoryConstrained: _isMemoryConstrained,
      availableRamMb: _currentAvailableRamMb,
    );
  }

  @override
  void dispose() {
    _settingsStreamController.close();
    super.dispose();
  }
}
