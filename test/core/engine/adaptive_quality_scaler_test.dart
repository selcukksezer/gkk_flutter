import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/engine/adaptive_quality_scaler.dart';

void main() {
  group('Hardware Tier Detection & Presets', () {
    test('autoDetectTier classifies <1800MB RAM as Eco tier', () {
      final profile = DeviceHardwareProfile.ecoUltraLowSpec();
      expect(profile.totalRamMb, equals(1536));
      expect(profile.gpuRenderer, contains('Mali-400'));
      expect(profile.autoDetectTier(), equals(HardwareTier.eco));

      final ecoSettings = QualitySettings.forTier(HardwareTier.eco);
      expect(ecoSettings.renderResolutionScale, equals(0.5));
      expect(ecoSettings.volumetricFogStepCount, equals(0));
      expect(ecoSettings.maxActiveParticles, equals(150));
      expect(ecoSettings.shadowResolution, equals(0));
    });

    test('autoDetectTier classifies 2GB RAM Mali-G52 as Low tier', () {
      final profile = DeviceHardwareProfile.lowSpec2GbMaliG52();
      expect(profile.totalRamMb, equals(2048));
      expect(profile.gpuRenderer, contains('Mali-G52'));
      expect(profile.autoDetectTier(), equals(HardwareTier.low));
    });

    test('autoDetectTier strictly classifies any device with <= 2560MB RAM as Low tier', () {
      const lowRamUnknownGpu = DeviceHardwareProfile(
        totalRamMb: 2048,
        gpuRenderer: 'Unknown Flagship Chipset',
      );
      expect(lowRamUnknownGpu.autoDetectTier(), equals(HardwareTier.low));
    });

    test('autoDetectTier classifies budget GPU strings as Low tier', () {
      final budgetGpus = [
        'Mali-G31',
        'Mali-G51 MP4',
        'Mali-G52 2EEMC2',
        'Adreno (TM) 505',
        'Adreno (TM) 506',
        'Adreno (TM) 610',
        'PowerVR GE8320',
        'Helio P35',
        'Unisoc T606',
        'Spreadtrum SC9863A',
      ];

      for (final gpu in budgetGpus) {
        final profile = DeviceHardwareProfile(totalRamMb: 3072, gpuRenderer: gpu);
        expect(profile.autoDetectTier(), equals(HardwareTier.low),
            reason: 'Expected $gpu to detect as Low tier');
      }
    });

    test('autoDetectTier classifies Snapdragon 720G / Adreno 618 as Mid tier', () {
      final profile = DeviceHardwareProfile.midSpecSnapdragon720();
      expect(profile.totalRamMb, equals(4096));
      expect(profile.gpuRenderer, contains('Adreno (TM) 618'));
      expect(profile.autoDetectTier(), equals(HardwareTier.mid));
    });

    test('autoDetectTier classifies mid-range GPUs as Mid tier', () {
      final midGpus = [
        'Mali-G57 MC2',
        'Mali-G68 MC4',
        'Mali-G76 MP12',
        'Adreno (TM) 619',
        'Adreno (TM) 620',
        'Adreno (TM) 642L',
        'Dimensity 700',
        'Dimensity 1080',
        'Apple A12 GPU',
      ];

      for (final gpu in midGpus) {
        final profile = DeviceHardwareProfile(totalRamMb: 6144, gpuRenderer: gpu);
        expect(profile.autoDetectTier(), equals(HardwareTier.mid),
            reason: 'Expected $gpu to detect as Mid tier');
      }
    });

    test('autoDetectTier classifies Snapdragon 8+ Gen 1 / Adreno 730 as High tier', () {
      final profile = DeviceHardwareProfile.highSpecAdreno730();
      expect(profile.totalRamMb, equals(8192));
      expect(profile.gpuRenderer, contains('Adreno (TM) 730'));
      expect(profile.autoDetectTier(), equals(HardwareTier.high));
    });

    test('autoDetectTier classifies high-end GPUs as High tier', () {
      final highGpus = [
        'Mali-G710 MC10',
        'Mali-G715 Immortalis',
        'Adreno (TM) 740',
        'Apple A16 GPU',
        'Google Tensor G3',
      ];

      for (final gpu in highGpus) {
        final profile = DeviceHardwareProfile(totalRamMb: 8192, gpuRenderer: gpu);
        expect(profile.autoDetectTier(), equals(HardwareTier.high),
            reason: 'Expected $gpu to detect as High tier');
      }
    });

    test('autoDetectTier classifies 2027 AAA flagship as Ultra tier', () {
      final profile = DeviceHardwareProfile.ultraFlagship2027();
      expect(profile.totalRamMb, equals(16384));
      expect(profile.gpuRenderer, contains('Immortalis-G925'));
      expect(profile.autoDetectTier(), equals(HardwareTier.ultra));
    });

    test('autoDetectTier classifies next-gen GPUs as Ultra tier', () {
      final ultraGpus = [
        'Immortalis-G925 MC12',
        'Adreno (TM) 830',
        'Snapdragon 8 Elite',
        'Apple A18 Pro GPU',
        'NVIDIA GeForce RTX 4080',
      ];

      for (final gpu in ultraGpus) {
        final profile = DeviceHardwareProfile(totalRamMb: 16384, gpuRenderer: gpu);
        expect(profile.autoDetectTier(), equals(HardwareTier.ultra),
            reason: 'Expected $gpu to detect as Ultra tier');
      }
    });

    test('autoDetectTier falls back sensibly based on RAM capacity when GPU string is null', () {
      expect(
        const DeviceHardwareProfile(totalRamMb: 3000).autoDetectTier(),
        equals(HardwareTier.low),
      );
      expect(
        const DeviceHardwareProfile(totalRamMb: 4096).autoDetectTier(),
        equals(HardwareTier.mid),
      );
      expect(
        const DeviceHardwareProfile(totalRamMb: 8192).autoDetectTier(),
        equals(HardwareTier.high),
      );
      expect(
        const DeviceHardwareProfile(totalRamMb: 16384).autoDetectTier(),
        equals(HardwareTier.ultra),
      );
    });

    test('DeviceHardwareProfile default constructor and named factory presets verification', () {
      const defaultProfile = DeviceHardwareProfile(totalRamMb: 4096);
      expect(defaultProfile.totalRamMb, equals(4096));
      expect(defaultProfile.cpuCoreCount, equals(8));
      expect(defaultProfile.maxRefreshRate, equals(60.0));
      expect(defaultProfile.supportsComputeShaders, isTrue);
      expect(defaultProfile.supportsDraco, isTrue);
      expect(defaultProfile.supportsKtx2, isTrue);
      expect(defaultProfile.gpuRenderer, isNull);
      expect(defaultProfile.gpuVendor, isNull);

      final eco = DeviceHardwareProfile.ecoUltraLowSpec();
      expect(eco.totalRamMb, equals(1536));
      expect(eco.cpuCoreCount, equals(4));
      expect(eco.gpuRenderer, equals('Mali-400 MP2'));
      expect(eco.gpuVendor, equals('ARM'));
      expect(eco.supportsComputeShaders, isFalse);

      final low = DeviceHardwareProfile.lowSpec2GbMaliG52();
      expect(low.totalRamMb, equals(2048));
      expect(low.gpuRenderer, equals('Mali-G52 MP2'));
      expect(low.supportsComputeShaders, isFalse);

      final mid = DeviceHardwareProfile.midSpecSnapdragon720();
      expect(mid.totalRamMb, equals(4096));
      expect(mid.gpuRenderer, equals('Adreno (TM) 618'));
      expect(mid.gpuVendor, equals('Qualcomm'));
      expect(mid.supportsComputeShaders, isTrue);

      final high = DeviceHardwareProfile.highSpecAdreno730();
      expect(high.totalRamMb, equals(8192));
      expect(high.gpuRenderer, equals('Adreno (TM) 730'));
      expect(high.maxRefreshRate, equals(120.0));

      final ultra = DeviceHardwareProfile.ultraFlagship2027();
      expect(ultra.totalRamMb, equals(16384));
      expect(ultra.gpuRenderer, equals('Immortalis-G925 MC12'));
      expect(ultra.maxRefreshRate, equals(120.0));
    });

    test('autoDetectTier handles case variations, empty string, and unusual GPU names', () {
      expect(
        const DeviceHardwareProfile(totalRamMb: 4096, gpuRenderer: 'adreno (tm) 618').autoDetectTier(),
        equals(HardwareTier.mid),
      );
      expect(
        const DeviceHardwareProfile(totalRamMb: 4096, gpuRenderer: 'ADRENO (TM) 618').autoDetectTier(),
        equals(HardwareTier.mid),
      );
      expect(
        const DeviceHardwareProfile(totalRamMb: 8192, gpuRenderer: 'MALI-G710 MC10').autoDetectTier(),
        equals(HardwareTier.high),
      );
      expect(
        const DeviceHardwareProfile(totalRamMb: 16384, gpuRenderer: 'IMMORTALIS-G925').autoDetectTier(),
        equals(HardwareTier.ultra),
      );
      expect(
        const DeviceHardwareProfile(totalRamMb: 4096, gpuRenderer: '').autoDetectTier(),
        equals(HardwareTier.mid),
      );
      expect(
        const DeviceHardwareProfile(totalRamMb: 16384, gpuRenderer: 'Custom Quantum Accelerator').autoDetectTier(),
        equals(HardwareTier.ultra),
      );
    });

    test('QualitySettings baseline matches specifications for all 5 tiers', () {
      final eco = QualitySettings.forTier(HardwareTier.eco);
      expect(eco.tier, equals(HardwareTier.eco));
      expect(eco.throttleLevel, equals(0));
      expect(eco.renderResolutionScale, equals(0.5));
      expect(eco.volumetricFogStepCount, equals(0));
      expect(eco.ssaoEnabled, isFalse);
      expect(eco.ssaoBlurEnabled, isFalse);
      expect(eco.maxActiveParticles, equals(150));
      expect(eco.shadowResolution, equals(0));
      expect(eco.shadowCascadeCount, equals(0));
      expect(eco.lodDistanceMultiplier, equals(0.35));
      expect(eco.bloomEnabled, isFalse);
      expect(eco.crowdDensityCap, equals(250));
      expect(eco.targetFps, equals(30.0));

      final low = QualitySettings.forTier(HardwareTier.low);
      expect(low.tier, equals(HardwareTier.low));
      expect(low.throttleLevel, equals(0));
      expect(low.renderResolutionScale, equals(0.75));
      expect(low.volumetricFogStepCount, equals(4));
      expect(low.ssaoEnabled, isFalse);
      expect(low.ssaoBlurEnabled, isFalse);
      expect(low.maxActiveParticles, equals(500));
      expect(low.shadowResolution, equals(0));
      expect(low.shadowCascadeCount, equals(0));
      expect(low.lodDistanceMultiplier, equals(0.5));
      expect(low.bloomEnabled, isFalse);
      expect(low.crowdDensityCap, equals(500));
      expect(low.targetFps, equals(30.0));

      final mid = QualitySettings.forTier(HardwareTier.mid);
      expect(mid.tier, equals(HardwareTier.mid));
      expect(mid.throttleLevel, equals(0));
      expect(mid.renderResolutionScale, equals(1.0));
      expect(mid.volumetricFogStepCount, equals(16));
      expect(mid.ssaoEnabled, isTrue);
      expect(mid.ssaoBlurEnabled, isTrue);
      expect(mid.maxActiveParticles, equals(2000));
      expect(mid.shadowResolution, equals(512));
      expect(mid.shadowCascadeCount, equals(2));
      expect(mid.lodDistanceMultiplier, equals(0.75));
      expect(mid.bloomEnabled, isTrue);
      expect(mid.crowdDensityCap, equals(2000));
      expect(mid.targetFps, equals(60.0));

      final high = QualitySettings.forTier(HardwareTier.high);
      expect(high.tier, equals(HardwareTier.high));
      expect(high.throttleLevel, equals(0));
      expect(high.renderResolutionScale, equals(1.0));
      expect(high.volumetricFogStepCount, equals(32));
      expect(high.ssaoEnabled, isTrue);
      expect(high.ssaoBlurEnabled, isTrue);
      expect(high.maxActiveParticles, equals(5000));
      expect(high.shadowResolution, equals(1024));
      expect(high.shadowCascadeCount, equals(3));
      expect(high.lodDistanceMultiplier, equals(1.0));
      expect(high.bloomEnabled, isTrue);
      expect(high.crowdDensityCap, equals(5000));
      expect(high.targetFps, equals(60.0));

      final ultra = QualitySettings.forTier(HardwareTier.ultra);
      expect(ultra.tier, equals(HardwareTier.ultra));
      expect(ultra.throttleLevel, equals(0));
      expect(ultra.renderResolutionScale, equals(1.0));
      expect(ultra.volumetricFogStepCount, equals(64));
      expect(ultra.ssaoEnabled, isTrue);
      expect(ultra.ssaoBlurEnabled, isTrue);
      expect(ultra.maxActiveParticles, equals(10000));
      expect(ultra.shadowResolution, equals(2048));
      expect(ultra.shadowCascadeCount, equals(4));
      expect(ultra.lodDistanceMultiplier, equals(1.5));
      expect(ultra.bloomEnabled, isTrue);
      expect(ultra.crowdDensityCap, equals(10000));
      expect(ultra.targetFps, equals(60.0));
    });
  });

  group('QualitySettings Serialization, Immutability & Throttle Progression', () {
    test('QualitySettings.toJson produces comprehensive schema with all required fields', () {
      final settings = QualitySettings.forTier(HardwareTier.high);
      final json = settings.toJson();

      expect(json['tier'], equals('high'));
      expect(json['throttleLevel'], equals(0));
      expect(json['renderResolutionScale'], equals(1.0));
      expect(json['volumetricFogStepCount'], equals(32));
      expect(json['ssaoEnabled'], isTrue);
      expect(json['ssaoBlurEnabled'], isTrue);
      expect(json['maxActiveParticles'], equals(5000));
      expect(json['shadowResolution'], equals(1024));
      expect(json['shadowCascadeCount'], equals(3));
      expect(json['lodDistanceMultiplier'], equals(1.0));
      expect(json['bloomEnabled'], isTrue);
      expect(json['crowdDensityCap'], equals(5000));
      expect(json['targetFps'], equals(60.0));
    });

    test('QualitySettings equality (==) and hashCode contracts are reflexive, symmetric, and field-sensitive', () {
      final a = QualitySettings.forTier(HardwareTier.mid);
      final b = QualitySettings.forTier(HardwareTier.mid);
      final c = a.copyWith(maxActiveParticles: 9999);
      final d = a.copyWith(renderResolutionScale: 0.85);

      expect(a, equals(b));
      expect(b, equals(a));
      expect(a.hashCode, equals(b.hashCode));

      expect(a == c, isFalse);
      expect(a == d, isFalse);
      expect(a == Object(), isFalse);
    });

    test('QualitySettings copyWith preserves untouched properties while modifying targeted fields', () {
      final base = QualitySettings.forTier(HardwareTier.high);
      final modified = base.copyWith(
        renderResolutionScale: 0.82,
        bloomEnabled: false,
        maxActiveParticles: 3500,
      );

      expect(modified.renderResolutionScale, equals(0.82));
      expect(modified.bloomEnabled, isFalse);
      expect(modified.maxActiveParticles, equals(3500));
      expect(modified.tier, equals(base.tier));
      expect(modified.volumetricFogStepCount, equals(base.volumetricFogStepCount));
      expect(modified.ssaoEnabled, equals(base.ssaoEnabled));
      expect(modified.shadowResolution, equals(base.shadowResolution));
    });

    test('QualitySettings toString formats human-readable diagnostic summary', () {
      final settings = QualitySettings.forTier(HardwareTier.high);
      final str = settings.toString();
      expect(str, contains('QualitySettings(tier: high'));
      expect(str, contains('throttle: 0'));
      expect(str, contains('scale: 1.00x'));
      expect(str, contains('fogSteps: 32'));
      expect(str, contains('particles: 5000'));
    });

    test('QualitySettings withThrottleLevel produces strictly monotonic degradation down to Level 3 across all tiers', () {
      for (final tier in HardwareTier.values) {
        final l0 = QualitySettings.forTier(tier).withThrottleLevel(0);
        final l1 = QualitySettings.forTier(tier).withThrottleLevel(1);
        final l2 = QualitySettings.forTier(tier).withThrottleLevel(2);
        final l3 = QualitySettings.forTier(tier).withThrottleLevel(3);

        expect(l0.throttleLevel, equals(0));
        expect(l1.throttleLevel, equals(1));
        expect(l2.throttleLevel, equals(2));
        expect(l3.throttleLevel, equals(3));

        expect(l1.renderResolutionScale, lessThanOrEqualTo(l0.renderResolutionScale));
        expect(l2.renderResolutionScale, lessThanOrEqualTo(l1.renderResolutionScale));
        expect(l3.renderResolutionScale, equals(0.5));

        expect(l1.volumetricFogStepCount, lessThanOrEqualTo(l0.volumetricFogStepCount));
        expect(l2.volumetricFogStepCount, lessThanOrEqualTo(l1.volumetricFogStepCount));
        expect(l3.volumetricFogStepCount, equals(0));

        expect(l1.ssaoBlurEnabled, isFalse);
        expect(l2.ssaoEnabled, isFalse);
        expect(l3.ssaoEnabled, isFalse);
        expect(l3.bloomEnabled, isFalse);
        expect(l3.shadowResolution, equals(0));
        expect(l3.shadowCascadeCount, equals(0));

        expect(l1.maxActiveParticles, lessThanOrEqualTo(l0.maxActiveParticles));
        expect(l2.maxActiveParticles, lessThanOrEqualTo(l1.maxActiveParticles));
        expect(l3.maxActiveParticles, lessThanOrEqualTo(l2.maxActiveParticles));
        expect(l3.maxActiveParticles, greaterThanOrEqualTo(25));

        expect(l1.lodDistanceMultiplier, lessThanOrEqualTo(l0.lodDistanceMultiplier));
        expect(l2.lodDistanceMultiplier, lessThanOrEqualTo(l1.lodDistanceMultiplier));
        expect(l3.lodDistanceMultiplier, lessThanOrEqualTo(l2.lodDistanceMultiplier));
      }
    });

    test('QualitySettings withThrottleLevel preserves custom targetFps across all throttle levels', () {
      final custom = QualitySettings.forTier(HardwareTier.high).copyWith(targetFps: 120.0);
      expect(custom.withThrottleLevel(0).targetFps, equals(120.0));
      expect(custom.withThrottleLevel(1).targetFps, equals(120.0));
      expect(custom.withThrottleLevel(2).targetFps, equals(120.0));
      expect(custom.withThrottleLevel(3).targetFps, equals(120.0));
    });
  });

  group('FrameTimeTracker & Rolling 60-Frame Moving Window', () {
    test('initializes with zero frames and graceful defaults', () {
      final tracker = FrameTimeTracker();
      expect(tracker.count, equals(0));
      expect(tracker.totalRecorded, equals(0));
      expect(tracker.droppedFrames, equals(0));
      expect(tracker.averageFrameTimeMs, equals(0.0));
      expect(tracker.currentFps, equals(0.0));
      expect(tracker.minFrameTimeMs, equals(0.0));
      expect(tracker.maxFrameTimeMs, equals(0.0));
      expect(tracker.p95FrameTimeMs, equals(0.0));
      expect(tracker.p99FrameTimeMs, equals(0.0));
      expect(tracker.standardDeviationMs, equals(0.0));
    });

    test('accurately calculates rolling moving average for 60fps', () {
      final tracker = FrameTimeTracker();
      for (int i = 0; i < 30; i++) {
        tracker.record(16.6667, 16.6667);
      }
      expect(tracker.count, equals(30));
      expect(tracker.totalRecorded, equals(30));
      expect(tracker.averageFrameTimeMs, closeTo(16.6667, 0.01));
      expect(tracker.currentFps, closeTo(60.0, 0.1));
    });

    test('caps buffer size at strictly 60 frames and evicts oldest values', () {
      final tracker = FrameTimeTracker();

      // Fill with 60 frames of 10.0 ms
      for (int i = 0; i < 60; i++) {
        tracker.record(10.0, 16.66);
      }
      expect(tracker.count, equals(60));
      expect(tracker.totalRecorded, equals(60));
      expect(tracker.averageFrameTimeMs, closeTo(10.0, 0.001));

      // Add 60 frames of 20.0 ms, pushing all original 10.0ms frames out
      for (int i = 0; i < 60; i++) {
        tracker.record(20.0, 16.66);
      }
      expect(tracker.count, equals(60));
      expect(tracker.totalRecorded, equals(120));
      expect(tracker.averageFrameTimeMs, closeTo(20.0, 0.001));
      expect(tracker.currentFps, closeTo(50.0, 0.1));
    });

    test('accurately tracks dropped frames exceeding target by > 20%', () {
      final tracker = FrameTimeTracker();
      // Target is 16.66ms; > 20% is > 20.0ms
      tracker.record(16.6, 16.66); // normal
      tracker.record(18.0, 16.66); // under 20%
      tracker.record(25.0, 16.66); // dropped frame
      tracker.record(33.3, 16.66); // dropped frame

      expect(tracker.totalRecorded, equals(4));
      expect(tracker.droppedFrames, equals(2));
    });

    test('computes P95 latency and standard deviation jitter correctly', () {
      final tracker = FrameTimeTracker();
      // Record 50 frames of 16.0ms and 10 frames of 30.0ms
      for (int i = 0; i < 50; i++) {
        tracker.record(16.0, 16.66);
      }
      for (int i = 0; i < 10; i++) {
        tracker.record(30.0, 16.66);
      }

      expect(tracker.count, equals(60));
      expect(tracker.p95FrameTimeMs, equals(30.0));
      expect(tracker.standardDeviationMs, greaterThan(4.0));
    });

    test('computes minFrameTimeMs, maxFrameTimeMs, and P99 latency accurately', () {
      final tracker = FrameTimeTracker();
      tracker.record(10.0, 16.66);
      tracker.record(15.0, 16.66);
      tracker.record(22.0, 16.66);
      tracker.record(35.0, 16.66);

      expect(tracker.minFrameTimeMs, equals(10.0));
      expect(tracker.maxFrameTimeMs, equals(35.0));

      // Fill up to 60 frames: 58 frames of 16.0ms, 2 frames of 50.0ms
      final trackerP99 = FrameTimeTracker();
      for (int i = 0; i < 58; i++) {
        trackerP99.record(16.0, 16.66);
      }
      trackerP99.record(50.0, 16.66);
      trackerP99.record(50.0, 16.66);

      expect(trackerP99.count, equals(60));
      expect(trackerP99.p99FrameTimeMs, equals(50.0));
    });

    test('handles negative frame times and zero target frame times gracefully without crashes', () {
      final tracker = FrameTimeTracker();
      tracker.record(-12.5, 0.0);
      expect(tracker.minFrameTimeMs, equals(0.0));
      expect(tracker.maxFrameTimeMs, equals(0.0));
      expect(tracker.averageFrameTimeMs, equals(0.0));
      expect(tracker.droppedFrames, equals(0));
    });

    test('handles standard deviation with 0, 1, and many identical frame samples', () {
      final tracker = FrameTimeTracker();
      expect(tracker.standardDeviationMs, equals(0.0));

      tracker.record(16.0, 16.66);
      expect(tracker.standardDeviationMs, equals(0.0));

      for (int i = 0; i < 20; i++) {
        tracker.record(16.0, 16.66);
      }
      expect(tracker.standardDeviationMs, closeTo(0.0, 0.0001));
    });

    test('reset clears all history and counters', () {
      final tracker = FrameTimeTracker();
      tracker.record(25.0, 16.66);
      tracker.record(30.0, 16.66);
      tracker.reset();

      expect(tracker.count, equals(0));
      expect(tracker.totalRecorded, equals(0));
      expect(tracker.droppedFrames, equals(0));
      expect(tracker.averageFrameTimeMs, equals(0.0));
    });
  });

  group('Dynamic Runtime Scaling — Downscaling on FPS Drop', () {
    test('downscales on 60Hz target when rolling FPS drops below 54 FPS', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
      );

      expect(scaler.currentTier, equals(HardwareTier.high));
      expect(scaler.currentThrottleLevel, equals(0));
      expect(scaler.currentSettings.renderResolutionScale, equals(1.0));
      expect(scaler.currentSettings.volumetricFogStepCount, equals(32));
      expect(scaler.currentSettings.ssaoBlurEnabled, isTrue);
      expect(scaler.currentSettings.maxActiveParticles, equals(5000));

      // Feed frames running at 50 FPS (~20.0 ms frame time, which is below 54 FPS threshold)
      for (int i = 0; i < 15; i++) {
        scaler.recordFrameTime(20.0);
      }

      // Throttle Level 1: downscales render resolution to 0.75x, halves fog, disables SSAO blur, caps particles
      expect(scaler.currentThrottleLevel, equals(1));
      expect(scaler.currentSettings.renderResolutionScale, equals(0.75));
      expect(scaler.currentSettings.volumetricFogStepCount, equals(16));
      expect(scaler.currentSettings.ssaoBlurEnabled, isFalse);
      expect(scaler.currentSettings.maxActiveParticles, equals(2500));
      expect(scaler.totalDownscaleEvents, equals(1));
    });

    test('progressively drops to throttle level 2 (0.5x resolution) under continued pressure', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
      );

      // Trigger first downscale (Level 1)
      for (int i = 0; i < 12; i++) {
        scaler.recordFrameTime(22.0);
      }
      expect(scaler.currentThrottleLevel, equals(1));
      expect(scaler.currentSettings.renderResolutionScale, equals(0.75));

      // Trigger second downscale under heavy load (Level 2) after 30-frame cooldown
      for (int i = 0; i < 30; i++) {
        scaler.recordFrameTime(25.0);
      }
      expect(scaler.currentThrottleLevel, equals(2));
      expect(scaler.currentSettings.renderResolutionScale, equals(0.5));
      expect(scaler.currentSettings.volumetricFogStepCount, equals(8));
      expect(scaler.currentSettings.ssaoEnabled, isFalse);
      expect(scaler.currentSettings.ssaoBlurEnabled, isFalse);
      expect(scaler.currentSettings.maxActiveParticles, equals(500));
      expect(scaler.totalDownscaleEvents, equals(2));
    });

    test('downscales on 30Hz target when rolling FPS drops below 28 FPS', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.low,
        customTargetFps: 30.0,
        customDownscaleFpsThreshold: 28.0,
      );

      expect(scaler.targetFps, equals(30.0));
      expect(scaler.downscaleFpsThreshold, equals(28.0));
      expect(scaler.currentSettings.renderResolutionScale, equals(0.75));

      // Feed frames at 25 FPS (40.0 ms frame time, below 28 FPS threshold)
      for (int i = 0; i < 15; i++) {
        scaler.recordFrameTime(40.0);
      }

      expect(scaler.currentThrottleLevel, equals(1));
      // For low tier, Level 1 downscales from 0.75x to 0.5x
      expect(scaler.currentSettings.renderResolutionScale, equals(0.5));
      expect(scaler.currentSettings.maxActiveParticles, equals(250));
      expect(scaler.currentSettings.volumetricFogStepCount, equals(2));
    });

    test('does not trigger downscale during warmup period (< 10 frames)', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.mid,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
      );

      // Feed 5 very slow frames (50ms)
      for (int i = 0; i < 5; i++) {
        scaler.recordFrameTime(50.0);
      }

      // Should still be at 0 throttle during warmup to prevent false trips
      expect(scaler.currentThrottleLevel, equals(0));
      expect(scaler.frameTracker.count, equals(5));
    });

    test('does NOT trigger downscale if frame time is under target even if rolling FPS is low', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
      );

      // Feed 9 slow frames (50ms) during warmup
      for (int i = 0; i < 9; i++) {
        scaler.recordFrameTime(50.0);
      }
      expect(scaler.currentThrottleLevel, equals(0));

      // 10th frame arrives, which completes warmup. Rolling FPS is very low (~20 FPS).
      // BUT this 10th frame is smooth: 15.0ms (<= 16.66ms targetFrameTimeMs).
      // Because isCurrentlyStruggling is false, downscale must NOT trigger!
      scaler.recordFrameTime(15.0);
      expect(scaler.currentThrottleLevel, equals(0));
      expect(scaler.totalDownscaleEvents, equals(0));
    });

    test('does NOT trigger downscale on single frame lag spike if rolling FPS remains healthy', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
      );

      // Feed 40 smooth frames (16.66ms -> rolling FPS is 60)
      for (int i = 0; i < 40; i++) {
        scaler.recordFrameTime(16.66);
      }
      expect(scaler.currentThrottleLevel, equals(0));

      // Single frame stutter of 35.0ms:
      scaler.recordFrameTime(35.0);

      // Rolling FPS is still ~58.5 FPS (> 54 FPS threshold), so no downscale!
      expect(scaler.currentThrottleLevel, equals(0));
      expect(scaler.totalDownscaleEvents, equals(0));
    });

    test('recordFrameDuration accepts Dart Duration and triggers downscaling identically to recordFrameTime', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
      );

      for (int i = 0; i < 15; i++) {
        scaler.recordFrameDuration(const Duration(milliseconds: 25));
      }

      expect(scaler.currentThrottleLevel, equals(1));
      expect(scaler.totalDownscaleEvents, equals(1));
    });

    test('downscales all the way to maximum throttle level 3 and clamps strictly', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
      );

      // Level 1: 10 frames
      for (int i = 0; i < 10; i++) {
        scaler.recordFrameTime(50.0);
      }
      expect(scaler.currentThrottleLevel, equals(1));

      // Level 2: 30 frames
      for (int i = 0; i < 30; i++) {
        scaler.recordFrameTime(50.0);
      }
      expect(scaler.currentThrottleLevel, equals(2));

      // Level 3: 30 frames
      for (int i = 0; i < 30; i++) {
        scaler.recordFrameTime(50.0);
      }
      expect(scaler.currentThrottleLevel, equals(3));
      expect(scaler.totalDownscaleEvents, equals(3));

      // Further slow frames remain clamped at Level 3
      for (int i = 0; i < 60; i++) {
        scaler.recordFrameTime(50.0);
      }
      expect(scaler.currentThrottleLevel, equals(3));
      expect(scaler.totalDownscaleEvents, equals(3));
    });
  });

  group('Strict Resolution Scaling Bounds', () {
    test('render resolution scale never drops below 0.5x minimum bound', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
      );

      // Feed 200 severe stutter frames (100ms each)
      for (int i = 0; i < 200; i++) {
        scaler.recordFrameTime(100.0);
      }

      expect(scaler.currentThrottleLevel, equals(AdaptiveQualityScaler.maxThrottleLevel));
      expect(scaler.currentResolutionScale, greaterThanOrEqualTo(0.5));
      expect(scaler.currentResolutionScale, equals(0.5));
      expect(scaler.currentSettings.renderResolutionScale, equals(0.5));
    });

    test('setRenderResolutionScale strictly clamps input between 0.5 and 1.0', () {
      final scaler = AdaptiveQualityScaler(initialTier: HardwareTier.high);

      scaler.setRenderResolutionScale(0.1);
      expect(scaler.currentResolutionScale, equals(0.5));

      scaler.setRenderResolutionScale(0.49);
      expect(scaler.currentResolutionScale, equals(0.5));

      scaler.setRenderResolutionScale(0.85);
      expect(scaler.currentResolutionScale, equals(0.85));

      scaler.setRenderResolutionScale(1.5);
      expect(scaler.currentResolutionScale, equals(1.0));
    });
  });

  group('Hysteresis Prevention & Smooth Upscaling', () {
    test('scales quality back up smoothly only after > 5 continuous seconds under 14ms', () {
      DateTime simulatedTime = DateTime(2027, 1, 1, 12, 0, 0);
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
        recoveryThresholdMs: 14.0,
        requiredStabilityDuration: const Duration(seconds: 5),
        clock: () => simulatedTime,
      );

      // Step 1: Force downscale to Level 2
      for (int i = 0; i < 15; i++) {
        scaler.recordFrameTime(25.0);
      }
      expect(scaler.currentThrottleLevel, equals(1));
      for (int i = 0; i < 30; i++) {
        scaler.recordFrameTime(25.0);
      }
      expect(scaler.currentThrottleLevel, equals(2));
      expect(scaler.currentResolutionScale, equals(0.5));

      // Step 2: Feed fast frames (12ms <= 14ms) for 4.0 seconds
      final startRecovery = simulatedTime;
      for (int i = 0; i < 240; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 16));
        scaler.recordFrameTime(12.0);
      }

      // Elapsed is ~3.84s (< 5 seconds) -> MUST NOT UPSCALE YET
      expect(scaler.currentThrottleLevel, equals(2),
          reason: 'Must not upscale before 5 seconds of sustained stability');
      expect(scaler.currentResolutionScale, equals(0.5));

      // Step 3: Advance past 5.0 seconds under 14ms
      simulatedTime = startRecovery.add(const Duration(milliseconds: 5100));
      scaler.recordFrameTime(12.0);

      // Now hysteresis condition is satisfied! Scales up by exactly 1 step (Level 2 -> Level 1)
      expect(scaler.currentThrottleLevel, equals(1),
          reason: 'Should smoothly upscale by 1 level after 5s under 14ms');
      expect(scaler.currentResolutionScale, equals(0.75));
      expect(scaler.totalUpscaleEvents, equals(1));

      // Step 4: Advance another 5.1 seconds under 14ms -> scales back to baseline Level 0
      final secondUpscaleStart = simulatedTime;
      for (int i = 0; i < 300; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 16));
        scaler.recordFrameTime(11.5);
      }
      simulatedTime = secondUpscaleStart.add(const Duration(milliseconds: 5100));
      scaler.recordFrameTime(11.5);

      expect(scaler.currentThrottleLevel, equals(0));
      expect(scaler.currentResolutionScale, equals(1.0));
      expect(scaler.currentSettings.volumetricFogStepCount, equals(32));
      expect(scaler.currentSettings.ssaoBlurEnabled, isTrue);
      expect(scaler.totalUpscaleEvents, equals(2));
    });

    test('single frame exceeding 14ms resets stability timer and prevents oscillation', () {
      DateTime simulatedTime = DateTime(2027, 1, 1, 12, 0, 0);
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
        recoveryThresholdMs: 14.0,
        requiredStabilityDuration: const Duration(seconds: 5),
        clock: () => simulatedTime,
      );

      // Downscale to Level 1
      for (int i = 0; i < 15; i++) {
        scaler.recordFrameTime(25.0);
      }
      expect(scaler.currentThrottleLevel, equals(1));

      // Perform 4 seconds of stable 10ms frames (< 14ms)
      for (int i = 0; i < 200; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 20));
        scaler.recordFrameTime(10.0);
      }
      expect(scaler.currentThrottleLevel, equals(1));
      expect(scaler.currentStableDuration.inMilliseconds, greaterThan(3500));

      // STUTTER SPIKE: Single 15.0ms frame (> 14ms threshold)
      simulatedTime = simulatedTime.add(const Duration(milliseconds: 20));
      scaler.recordFrameTime(15.0);

      // Stability timer MUST be immediately reset to zero
      expect(scaler.currentStableDuration, equals(Duration.zero));
      expect(scaler.currentThrottleLevel, equals(1));

      // Another 2 seconds of 10ms frames (total 6s from start, but only 2s from spike)
      for (int i = 0; i < 100; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 20));
        scaler.recordFrameTime(10.0);
      }

      // MUST NOT upscale because continuous stability was broken by the spike
      expect(scaler.currentThrottleLevel, equals(1));
      expect(scaler.currentStableDuration.inMilliseconds, closeTo(2000, 100));

      // After a full continuous 5.0 seconds from the spike:
      simulatedTime = simulatedTime.add(const Duration(milliseconds: 3100));
      scaler.recordFrameTime(10.0);

      // Now it upscales cleanly
      expect(scaler.currentThrottleLevel, equals(0));
      expect(scaler.totalUpscaleEvents, equals(1));
    });

    test('full roundtrip: downscales to Level 3 then upscales step-by-step back to baseline Level 0', () {
      DateTime simulatedTime = DateTime(2027, 1, 1, 12, 0, 0);
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
        recoveryThresholdMs: 14.0,
        requiredStabilityDuration: const Duration(seconds: 5),
        clock: () => simulatedTime,
      );

      // Downscale: 0 -> 1 -> 2 -> 3
      for (int i = 0; i < 10; i++) {
        scaler.recordFrameTime(50.0);
      }
      expect(scaler.currentThrottleLevel, equals(1));

      for (int i = 0; i < 30; i++) {
        scaler.recordFrameTime(50.0);
      }
      expect(scaler.currentThrottleLevel, equals(2));

      for (int i = 0; i < 30; i++) {
        scaler.recordFrameTime(50.0);
      }
      expect(scaler.currentThrottleLevel, equals(3));
      expect(scaler.totalDownscaleEvents, equals(3));

      // Recovery: Level 3 -> Level 2
      DateTime recoveryStart = simulatedTime;
      for (int i = 0; i < 300; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 16));
        scaler.recordFrameTime(10.0);
      }
      simulatedTime = recoveryStart.add(const Duration(milliseconds: 5100));
      scaler.recordFrameTime(10.0);
      expect(scaler.currentThrottleLevel, equals(2));

      // Recovery: Level 2 -> Level 1
      recoveryStart = simulatedTime;
      for (int i = 0; i < 300; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 16));
        scaler.recordFrameTime(10.0);
      }
      simulatedTime = recoveryStart.add(const Duration(milliseconds: 5100));
      scaler.recordFrameTime(10.0);
      expect(scaler.currentThrottleLevel, equals(1));

      // Recovery: Level 1 -> Level 0
      recoveryStart = simulatedTime;
      for (int i = 0; i < 300; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 16));
        scaler.recordFrameTime(10.0);
      }
      simulatedTime = recoveryStart.add(const Duration(milliseconds: 5100));
      scaler.recordFrameTime(10.0);
      expect(scaler.currentThrottleLevel, equals(0));
      expect(scaler.totalUpscaleEvents, equals(3));
      expect(scaler.currentStableDuration, equals(Duration.zero));
    });

    test('negative time delta in currentStableDuration returns Duration.zero safely', () {
      DateTime simulatedTime = DateTime(2027, 1, 1, 12, 0, 0);
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
        recoveryThresholdMs: 14.0,
        clock: () => simulatedTime,
      );

      // Force Level 1
      for (int i = 0; i < 15; i++) {
        scaler.recordFrameTime(25.0);
      }
      expect(scaler.currentThrottleLevel, equals(1));

      // Record a stable frame at 12:00:00
      scaler.recordFrameTime(10.0);

      // Jump clock backwards into the past (e.g. system clock NTP adjustment)
      simulatedTime = DateTime(2027, 1, 1, 11, 59, 50);
      expect(scaler.currentStableDuration, equals(Duration.zero));
    });
  });

  group('Reactive Notifications & Telemetry Feed', () {
    test('notifies listeners on downscale, upscale, and manual tier changes', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
      );

      int notifyCount = 0;
      scaler.addListener(() {
        notifyCount++;
      });

      // Downscale
      for (int i = 0; i < 15; i++) {
        scaler.recordFrameTime(25.0);
      }
      expect(notifyCount, greaterThan(0));

      final countAfterDownscale = notifyCount;
      // Manual tier switch
      scaler.setHardwareTier(HardwareTier.low);
      expect(notifyCount, greaterThan(countAfterDownscale));
      expect(scaler.currentTier, equals(HardwareTier.low));

      // Manual resolution override
      final countAfterTier = notifyCount;
      scaler.setRenderResolutionScale(0.65);
      expect(notifyCount, greaterThan(countAfterTier));
      expect(scaler.currentResolutionScale, equals(0.65));
    });

    test('emits QualitySettings updates to onSettingsChanged stream', () async {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.mid,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
      );

      final List<QualitySettings> emitted = [];
      final sub = scaler.onSettingsChanged.listen((settings) {
        emitted.add(settings);
      });

      for (int i = 0; i < 15; i++) {
        scaler.recordFrameTime(25.0);
      }

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emitted, isNotEmpty);
      expect(emitted.first.throttleLevel, equals(1));
      expect(emitted.first.renderResolutionScale, equals(0.75));

      await sub.cancel();
      scaler.dispose();
    });

    test('getTelemetry outputs structured performance metrics and formats report', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
      );

      for (int i = 0; i < 20; i++) {
        scaler.recordFrameTime(16.0);
      }

      final telemetry = scaler.getTelemetry();
      expect(telemetry.tier, equals(HardwareTier.high));
      expect(telemetry.totalFramesRecorded, equals(20));
      expect(telemetry.rollingAvgFrameTimeMs, closeTo(16.0, 0.1));
      expect(telemetry.rollingFps, closeTo(62.5, 1.0));
      expect(telemetry.resolutionScale, equals(1.0));

      final json = telemetry.toJson();
      expect(json['tier'], equals('high'));
      expect(json['totalFramesRecorded'], equals(20));
      expect(json['rollingFps'], isNotNull);
      expect(telemetry.toString(), contains('ScalerTelemetry'));
    });

    test('setAutoScaling(false) freezes dynamic scaling and true re-enables it', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
      );

      scaler.setAutoScaling(false);
      expect(scaler.isAutoScalingEnabled, isFalse);

      for (int i = 0; i < 30; i++) {
        scaler.recordFrameTime(50.0); // Severe stutter
      }

      // Scaling must remain frozen at level 0
      expect(scaler.currentThrottleLevel, equals(0));
      expect(scaler.totalDownscaleEvents, equals(0));

      // Re-enable auto-scaling
      scaler.setAutoScaling(true);
      expect(scaler.isAutoScalingEnabled, isTrue);

      // Now subsequent slow frames trigger downscale
      for (int i = 0; i < 15; i++) {
        scaler.recordFrameTime(50.0);
      }
      expect(scaler.currentThrottleLevel, equals(1));
      expect(scaler.totalDownscaleEvents, equals(1));
    });

    test('resetMetrics clears rolling tracker and frames-since-throttle counter', () {
      final scaler = AdaptiveQualityScaler(initialTier: HardwareTier.high);
      for (int i = 0; i < 25; i++) {
        scaler.recordFrameTime(16.66);
      }
      expect(scaler.frameTracker.count, equals(25));
      expect(scaler.frameTracker.totalRecorded, equals(25));

      scaler.resetMetrics();
      expect(scaler.frameTracker.count, equals(0));
      expect(scaler.frameTracker.totalRecorded, equals(0));
      expect(scaler.currentStableDuration, equals(Duration.zero));
    });

    test('scaler preserves custom targetFps on manual setHardwareTier and throttle transitions', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 120.0,
      );

      expect(scaler.targetFps, equals(120.0));
      expect(scaler.currentSettings.targetFps, equals(120.0));

      // Downscale
      for (int i = 0; i < 15; i++) {
        scaler.recordFrameTime(25.0);
      }
      expect(scaler.currentThrottleLevel, equals(1));
      expect(scaler.currentSettings.targetFps, equals(120.0));

      // Manual tier change
      scaler.setHardwareTier(HardwareTier.mid);
      expect(scaler.currentTier, equals(HardwareTier.mid));
      expect(scaler.currentSettings.targetFps, equals(120.0));
    });

    test('dispose closes settings stream controller cleanly', () async {
      final scaler = AdaptiveQualityScaler(initialTier: HardwareTier.mid);
      bool streamDone = false;
      scaler.onSettingsChanged.listen((_) {}, onDone: () {
        streamDone = true;
      });

      scaler.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(streamDone, isTrue);
    });
  });

  group('Downscale Cooldown Hysteresis (Cascade Prevention)', () {
    test('30-frame cooldown prevents runaway cascade from dropping multiple levels in consecutive frames', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
      );

      // Warmup phase: 10 frames of 50ms stutter
      for (int i = 0; i < 10; i++) {
        scaler.recordFrameTime(50.0);
      }
      expect(scaler.currentThrottleLevel, equals(1),
          reason: 'Level 1 downscale triggers on warmup completion');
      expect(scaler.totalDownscaleEvents, equals(1));

      // Runaway cascade attack: 29 consecutive slow frames (100ms) within the 30-frame cooldown window
      for (int i = 0; i < 29; i++) {
        scaler.recordFrameTime(100.0);
        expect(scaler.currentThrottleLevel, equals(1),
            reason: 'Must remain at Level 1 during cooldown (frame ${i + 1}/29)');
        expect(scaler.totalDownscaleEvents, equals(1));
      }

      // Exactly on the 30th frame after downscale, the cooldown expires and continued load triggers Level 2
      scaler.recordFrameTime(100.0);
      expect(scaler.currentThrottleLevel, equals(2),
          reason: 'Downscales to Level 2 only after 30-frame cooldown elapses');
      expect(scaler.totalDownscaleEvents, equals(2));

      // Another 29 frames of severe stutter: must remain at Level 2
      for (int i = 0; i < 29; i++) {
        scaler.recordFrameTime(100.0);
        expect(scaler.currentThrottleLevel, equals(2));
      }

      // 30th frame: triggers Level 3 (max throttle)
      scaler.recordFrameTime(100.0);
      expect(scaler.currentThrottleLevel, equals(3));
      expect(scaler.totalDownscaleEvents, equals(3));

      // Further slow frames cannot exceed maxThrottleLevel
      for (int i = 0; i < 60; i++) {
        scaler.recordFrameTime(100.0);
      }
      expect(scaler.currentThrottleLevel, equals(3));
      expect(scaler.totalDownscaleEvents, equals(3));
    });

    test('custom downscaleCooldownFrames is strictly respected', () {
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.high,
        customTargetFps: 60.0,
        customDownscaleFpsThreshold: 54.0,
        downscaleCooldownFrames: 15,
      );

      for (int i = 0; i < 10; i++) {
        scaler.recordFrameTime(50.0);
      }
      expect(scaler.currentThrottleLevel, equals(1));

      // 14 frames: still within 15-frame cooldown
      for (int i = 0; i < 14; i++) {
        scaler.recordFrameTime(50.0);
        expect(scaler.currentThrottleLevel, equals(1));
      }

      // 15th frame: downscales to Level 2
      scaler.recordFrameTime(50.0);
      expect(scaler.currentThrottleLevel, equals(2));
    });
  });

  group('Dynamic Recovery Threshold & High Refresh Targets (90Hz / 120Hz)', () {
    test('calculates recovery threshold dynamically as 0.85 * targetFrameTime for 60Hz and 30Hz', () {
      // 60 FPS: 1000 / 60 * 0.85 = ~14.167ms
      final scaler60 = AdaptiveQualityScaler(customTargetFps: 60.0);
      expect(scaler60.recoveryThresholdMs, closeTo(14.1667, 0.01));

      // 30 FPS via Low Tier: 1000 / 30 * 0.85 = ~28.333ms
      final scalerLow = AdaptiveQualityScaler(initialTier: HardwareTier.low);
      expect(scalerLow.targetFps, equals(30.0));
      expect(scalerLow.recoveryThresholdMs, closeTo(28.3333, 0.01));

      // 30 FPS via customTargetFps: ~28.333ms
      final scaler30 = AdaptiveQualityScaler(customTargetFps: 30.0);
      expect(scaler30.recoveryThresholdMs, closeTo(28.3333, 0.01));

      // 120 FPS: 1000 / 120 * 0.85 = ~7.083ms
      final scaler120 = AdaptiveQualityScaler(customTargetFps: 120.0);
      expect(scaler120.recoveryThresholdMs, closeTo(7.0833, 0.01));

      // Explicit recoveryThresholdMs override
      final scalerExplicit = AdaptiveQualityScaler(
        customTargetFps: 60.0,
        recoveryThresholdMs: 12.0,
      );
      expect(scalerExplicit.recoveryThresholdMs, equals(12.0));

      // Explicit customRecoveryThresholdMs override
      final scalerCustom = AdaptiveQualityScaler(
        customTargetFps: 30.0,
        customRecoveryThresholdMs: 22.0,
      );
      expect(scalerCustom.recoveryThresholdMs, equals(22.0));
    });

    test('30 FPS target device cleanly recovers and upscales under 25ms frames without deadlock', () {
      DateTime simulatedTime = DateTime(2027, 1, 1, 12, 0, 0);
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.low,
        customTargetFps: 30.0,
        customDownscaleFpsThreshold: 28.0,
        requiredStabilityDuration: const Duration(seconds: 5),
        clock: () => simulatedTime,
      );

      // Verify dynamic threshold is ~28.33ms (NOT hardcoded 14.0ms)
      expect(scaler.recoveryThresholdMs, closeTo(28.3333, 0.01));

      // Downscale to Level 1 with 15 frames at 40ms (< 28 FPS threshold)
      for (int i = 0; i < 15; i++) {
        scaler.recordFrameTime(40.0);
      }
      expect(scaler.currentThrottleLevel, equals(1));
      expect(scaler.currentSettings.renderResolutionScale, equals(0.5));

      // Performance recovers to smooth 25.0ms frames (40 FPS, well above 30 FPS target).
      final startRecovery = simulatedTime;
      for (int i = 0; i < 120; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 33));
        scaler.recordFrameTime(25.0);
      }

      // Elapsed is ~3.96s (< 5.0 seconds) -> must not upscale yet
      expect(scaler.currentThrottleLevel, equals(1),
          reason: 'Must not upscale before 5 seconds of sustained stability');

      // Advance past 5.0 seconds under 25ms frames
      simulatedTime = startRecovery.add(const Duration(milliseconds: 5100));
      scaler.recordFrameTime(25.0);

      // Successfully upscales back to baseline Level 0 (deadlock broken!)
      expect(scaler.currentThrottleLevel, equals(0),
          reason: '30 FPS device must upscale smoothly after 5s under 28.33ms');
      expect(scaler.currentSettings.renderResolutionScale, equals(0.75)); // Baseline for low tier
      expect(scaler.totalUpscaleEvents, equals(1));
    });

    test('30 FPS target resets stability timer when frame exceeds dynamic threshold (> 28.33ms)', () {
      DateTime simulatedTime = DateTime(2027, 1, 1, 12, 0, 0);
      final scaler = AdaptiveQualityScaler(
        initialTier: HardwareTier.low,
        customTargetFps: 30.0,
        customDownscaleFpsThreshold: 28.0,
        requiredStabilityDuration: const Duration(seconds: 5),
        clock: () => simulatedTime,
      );

      // Downscale to Level 1
      for (int i = 0; i < 15; i++) {
        scaler.recordFrameTime(40.0);
      }
      expect(scaler.currentThrottleLevel, equals(1));

      // Stable 25ms frames for 4 seconds
      for (int i = 0; i < 120; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 33));
        scaler.recordFrameTime(25.0);
      }
      expect(scaler.currentThrottleLevel, equals(1));
      expect(scaler.currentStableDuration.inMilliseconds, greaterThan(3500));

      // STUTTER SPIKE: Single 30.0ms frame (exceeds 28.33ms dynamic recovery threshold)
      simulatedTime = simulatedTime.add(const Duration(milliseconds: 33));
      scaler.recordFrameTime(30.0);

      // Stability timer must immediately reset
      expect(scaler.currentStableDuration, equals(Duration.zero));
      expect(scaler.currentThrottleLevel, equals(1));

      // Another 2 seconds of 25ms frames (total 6s from start, but only 2s from spike)
      for (int i = 0; i < 60; i++) {
        simulatedTime = simulatedTime.add(const Duration(milliseconds: 33));
        scaler.recordFrameTime(25.0);
      }

      // MUST NOT upscale because stability was interrupted
      expect(scaler.currentThrottleLevel, equals(1));
      expect(scaler.currentStableDuration.inMilliseconds, closeTo(1980, 100));

      // Finish remaining 3.1 seconds after spike
      simulatedTime = simulatedTime.add(const Duration(milliseconds: 3100));
      scaler.recordFrameTime(25.0);

      expect(scaler.currentThrottleLevel, equals(0));
      expect(scaler.totalUpscaleEvents, equals(1));
    });

    test('120Hz display target resolves 108 FPS downscale threshold and ~7.08ms recovery threshold', () {
      final scaler120 = AdaptiveQualityScaler(customTargetFps: 120.0);
      expect(scaler120.targetFps, equals(120.0));
      expect(scaler120.downscaleFpsThreshold, equals(108.0));
      expect(scaler120.recoveryThresholdMs, closeTo(7.0833, 0.01));
    });

    test('AdaptiveQualityScaler default constructor uses mid-tier Snapdragon 720 defaults when no parameters given', () {
      final scaler = AdaptiveQualityScaler();
      expect(scaler.currentTier, equals(HardwareTier.mid));
      expect(scaler.targetFps, equals(60.0));
      expect(scaler.downscaleFpsThreshold, equals(54.0));
      expect(scaler.recoveryThresholdMs, closeTo(14.1667, 0.01));
      expect(scaler.currentSettings.renderResolutionScale, equals(1.0));
    });

    test('AdaptiveQualityScaler initializes eco tier properly with 30 FPS target from ecoUltraLowSpec profile', () {
      final scaler = AdaptiveQualityScaler(profile: DeviceHardwareProfile.ecoUltraLowSpec());
      expect(scaler.currentTier, equals(HardwareTier.eco));
      expect(scaler.targetFps, equals(30.0));
      expect(scaler.downscaleFpsThreshold, equals(28.0));
      expect(scaler.recoveryThresholdMs, closeTo(28.3333, 0.01));
      expect(scaler.currentSettings.renderResolutionScale, equals(0.5));
    });
  });
}
