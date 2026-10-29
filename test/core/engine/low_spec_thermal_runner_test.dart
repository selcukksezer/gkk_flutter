import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/engine/adaptive_quality_scaler.dart';
import 'package:gkk_flutter/core/engine/low_spec_thermal_runner.dart';

void main() {
  group('Low-End Android 2GB RAM / 60 FPS Thermal Simulation Runner', () {
    test('instantiates with 2GB RAM Mali-G52 budget Android device profile', () {
      final runner = LowSpecThermalRunner();
      expect(runner.hardwareProfile.totalRamMb, equals(2048));
      expect(runner.hardwareProfile.gpuRenderer, contains('Mali-G52'));
      expect(runner.scaler.targetFps, equals(60.0));
      expect(runner.currentThermalState, equals(ThermalState.normal));
      expect(runner.gpuClockMultiplier, equals(1.0));
    });

    test('TBDR VRAM accounting remains strictly below 350MB budget ceiling across all settings', () {
      final runner = LowSpecThermalRunner();

      for (final tier in [HardwareTier.low, HardwareTier.mid, HardwareTier.high, HardwareTier.ultra]) {
        for (int throttle = 0; throttle <= 3; throttle++) {
          final settings = QualitySettings.forTier(tier).withThrottleLevel(throttle);
          final vramMb = runner.computeVramUsageMb(settings);

          expect(
            vramMb,
            lessThan(LowSpecThermalRunner.vramBudgetCeilingMb),
            reason: 'VRAM for ${tier.name} at throttle $throttle ($vramMb MB) must not exceed 350MB',
          );
          expect(vramMb, greaterThan(20.0), reason: 'VRAM must be a realistic non-zero value');
        }
      }
    });

    test('calculates accurate VRAM delta when dynamic resolution scaling reduces framebuffers', () {
      final runner = LowSpecThermalRunner(viewportWidth: 720, viewportHeight: 1600);

      final unthrottled = QualitySettings.forTier(HardwareTier.low);
      final throttledL1 = unthrottled.withThrottleLevel(1);

      final vramUnthrottled = runner.computeVramUsageMb(unthrottled);
      final vramThrottled = runner.computeVramUsageMb(throttledL1);

      expect(vramThrottled, lessThan(vramUnthrottled));
      expect(vramUnthrottled - vramThrottled, greaterThan(2.0));
      expect(vramThrottled, lessThan(120.0));
    });

    test('thermal governor triggers throttling when SoC temperature exceeds 45.0 C', () {
      final runner = LowSpecThermalRunner(ambientTemperatureCelsius: 32.0);

      expect(runner.currentTemperatureCelsius, equals(32.0));
      expect(runner.currentThermalState, equals(ThermalState.normal));
      expect(runner.gpuClockMultiplier, equals(1.0));

      for (int i = 0; i < 120; i++) {
        runner.stepFrame(frameIndex: i, simulatedWorkloadFactor: 3.0);
        if (runner.currentThermalState == ThermalState.throttled) break;
      }

      expect(runner.currentThermalState, equals(ThermalState.throttled));
      expect(runner.currentTemperatureCelsius, greaterThanOrEqualTo(45.0));
      expect(runner.gpuClockMultiplier, lessThan(1.0));
      expect(runner.gpuClockMultiplier, greaterThanOrEqualTo(0.50));
    });

    test('adaptive quality scaler dynamically downscales resolution and decimates particles under thermal stress', () {
      final runner = LowSpecThermalRunner(ambientTemperatureCelsius: 30.0);

      expect(runner.scaler.currentThrottleLevel, equals(0));
      expect(runner.scaler.currentResolutionScale, equals(0.75));
      expect(runner.scaler.currentSettings.maxActiveParticles, equals(500));

      for (int i = 0; i < 50; i++) {
        runner.stepFrame(frameIndex: i, simulatedWorkloadFactor: 2.8);
      }

      expect(runner.scaler.currentThrottleLevel, greaterThanOrEqualTo(1));
      expect(runner.scaler.currentResolutionScale, equals(0.5));
      expect(runner.scaler.currentSettings.maxActiveParticles, lessThanOrEqualTo(250));
      expect(runner.scaler.totalDownscaleEvents, greaterThanOrEqualTo(1));
    });

    test('sustains stable 60 FPS without memory leaks or OOM crashes under 2GB memory pressure', () {
      final runner = LowSpecThermalRunner(
        ambientTemperatureCelsius: 30.0,
        targetFps: 60.0,
      );

      final result = runner.runThermalSimulation(totalFrames: 600, memoryPressureMb: 350);

      expect(result.totalFramesSimulated, equals(600));
      expect(result.slaVramUnderBudget, isTrue);
      expect(result.peakVramMb, lessThan(LowSpecThermalRunner.vramBudgetCeilingMb));
      expect(result.vramBudgetMarginMb, greaterThan(150.0));

      expect(result.slaTargetFpsSustained, isTrue);
      expect(result.effectiveFps, greaterThanOrEqualTo(56.5));
      expect(result.p95FrameTimeMs, lessThan(24.0));

      expect(result.slaDynamicResolutionActivated, isTrue);
      expect(result.minimumResolutionScale, equals(0.5));

      expect(result.slaParticleDecimationActivated, isTrue);
      expect(result.minimumParticles, lessThanOrEqualTo(250));

      expect(result.slaZeroMemoryLeaks, isTrue);
      expect(result.leakedBytes, equals(0));

      expect(result.slaZeroOomCrashes, isTrue);
      expect(result.oomCrashCount, equals(0));

      expect(result.allSlasPassed, isTrue);

      final json = result.toJson();
      expect(json['tier'], equals('low'));

      expect(json['targetFps'], equals(60.0));
      expect(json['slaVerification']['allSlasPassed'], isTrue);
    });

    test('benchmark output outputs parseable tag payload', () {
      final runner = LowSpecThermalRunner();
      final result = runner.runThermalSimulation(totalFrames: 300);

      final jsonStartTag = '<<<BENCHMARK_LOW_SPEC_JSON_START>>>';
      final jsonEndTag = '<<<BENCHMARK_LOW_SPEC_JSON_END>>>';
      final payload = '$jsonStartTag\n${jsonEncode(result.toJson())}\n$jsonEndTag';

      expect(payload, contains(jsonStartTag));
      expect(payload, contains(jsonEndTag));
      expect(payload, contains('"allSlasPassed":true'));
    });
  });
}