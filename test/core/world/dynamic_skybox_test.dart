import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/world/dynamic_skybox.dart';

void main() {
  group('3D Vector & Math Utilities Tests', () {
    test('SkyVector3 arithmetic, dot, cross, and normalization', () {
      const SkyVector3 v1 = SkyVector3(1.0, 2.0, 3.0);
      const SkyVector3 v2 = SkyVector3(4.0, 5.0, 6.0);

      final SkyVector3 add = v1 + v2;
      expect(add.x, closeTo(5.0, 1e-6));
      expect(add.y, closeTo(7.0, 1e-6));
      expect(add.z, closeTo(9.0, 1e-6));

      final SkyVector3 sub = v2 - v1;
      expect(sub.x, closeTo(3.0, 1e-6));
      expect(sub.y, closeTo(3.0, 1e-6));
      expect(sub.z, closeTo(3.0, 1e-6));

      final double dot = v1.dot(v2);
      expect(dot, closeTo(1.0 * 4.0 + 2.0 * 5.0 + 3.0 * 6.0, 1e-6)); // 32.0

      final SkyVector3 cross = v1.cross(v2);
      expect(cross.x, closeTo(2 * 6 - 3 * 5, 1e-6)); // -3
      expect(cross.y, closeTo(3 * 4 - 1 * 6, 1e-6)); // 6
      expect(cross.z, closeTo(1 * 5 - 2 * 4, 1e-6)); // -3

      final SkyVector3 unit = v1.normalized();
      expect(unit.length, closeTo(1.0, 1e-6));

      final SkyVector3 zeroNorm = SkyVector3.zero.normalized();
      expect(zeroNorm, equals(SkyVector3.up));
    });

    test('SkyVector3 spherical coordinate conversion', () {
      // Zenith: elevation = PI/2, azimuth = 0
      final SkyVector3 zenith = SkyVector3.fromSpherical(0.0, math.pi / 2.0);
      expect(zenith.x, closeTo(0.0, 1e-6));
      expect(zenith.y, closeTo(1.0, 1e-6));
      expect(zenith.z, closeTo(0.0, 1e-6));

      // Horizon East: elevation = 0, azimuth = PI/2
      final SkyVector3 east = SkyVector3.fromSpherical(math.pi / 2.0, 0.0);
      expect(east.x, closeTo(1.0, 1e-6));
      expect(east.y, closeTo(0.0, 1e-6));
      expect(east.z, closeTo(0.0, 1e-6));

      // Horizon South: elevation = 0, azimuth = 0
      final SkyVector3 south = SkyVector3.fromSpherical(0.0, 0.0);
      expect(south.x, closeTo(0.0, 1e-6));
      expect(south.y, closeTo(0.0, 1e-6));
      expect(south.z, closeTo(1.0, 1e-6));
    });
  });

  group('LinearColor & Color Temperature Tests', () {
    test('LinearColor Planckian blackbody gradient evaluates accurately', () {
      // 2000K: Fiery golden-red (Dawn / Sunset) -> R is dominant, B is low
      final LinearColor sunsetWarm = LinearColor.fromColorTemperature(2000.0);
      expect(sunsetWarm.r, greaterThan(sunsetWarm.g));
      expect(sunsetWarm.g, greaterThan(sunsetWarm.b));
      expect(sunsetWarm.b, lessThan(0.2));

      // 6500K: Standard D65 Daylight -> R, G, B roughly equal / neutral
      final LinearColor daylight = LinearColor.fromColorTemperature(6500.0);
      expect((daylight.r - daylight.g).abs(), lessThan(0.15));
      expect((daylight.g - daylight.b).abs(), lessThan(0.15));

      // 12000K: Deep Twilight / Astral Blue -> B is dominant
      final LinearColor deepTwilight = LinearColor.fromColorTemperature(12000.0);
      expect(deepTwilight.b, greaterThan(deepTwilight.g));
      expect(deepTwilight.g, greaterThan(deepTwilight.r));
    });

    test('LinearColor luminance and lerp math', () {
      const LinearColor white = LinearColor(1.0, 1.0, 1.0);
      expect(white.luminance, closeTo(1.0, 1e-4));

      const LinearColor black = LinearColor(0.0, 0.0, 0.0);
      expect(black.luminance, closeTo(0.0, 1e-4));

      final LinearColor mid = black.lerp(white, 0.5);
      expect(mid.r, closeTo(0.5, 1e-6));
      expect(mid.g, closeTo(0.5, 1e-6));
      expect(mid.b, closeTo(0.5, 1e-6));

      final ui.Color uiCol = mid.toColor();
      expect(uiCol.a, closeTo(1.0, 1e-4));
    });
  });

  group('Celestial Orbit & Sun/Moon Trajectory Tests', () {
    final CelestialOrbitSystem orbit = CelestialOrbitSystem();

    test('Sun direction vector rotates correctly across 24h cycle', () {
      // 1. Noon (12:00 -> normalized 0.50): Sun near peak zenith (Y > 0)
      final SkyVector3 sunNoon = orbit.computeSunDirection(0.50);
      expect(sunNoon.length, closeTo(1.0, 1e-6));
      expect(sunNoon.y, greaterThan(0.50)); // High in sky

      // 2. Midnight (00:00 -> normalized 0.00): Sun deep below horizon (Y < 0)
      final SkyVector3 sunMidnight = orbit.computeSunDirection(0.00);
      expect(sunMidnight.length, closeTo(1.0, 1e-6));
      expect(sunMidnight.y, lessThan(-0.20)); // Below horizon

      // 3. Dawn (06:00 -> normalized 0.25): Sun rising, azimuth towards East (+X)
      final SkyVector3 sunDawn = orbit.computeSunDirection(0.25);
      expect(sunDawn.length, closeTo(1.0, 1e-6));
      expect(sunDawn.x, greaterThan(0.5)); // Eastward
      expect(sunDawn.y.abs(), lessThan(0.4)); // Near horizon

      // 4. Dusk (18:00 -> normalized 0.75): Sun setting, azimuth towards West (-X)
      final SkyVector3 sunDusk = orbit.computeSunDirection(0.75);
      expect(sunDusk.length, closeTo(1.0, 1e-6));
      expect(sunDusk.x, lessThan(-0.5)); // Westward
      expect(sunDusk.y.abs(), lessThan(0.4)); // Near horizon
    });

    test('Moon opposes Sun with lunar inclination offset', () {
      final SkyVector3 sunMidnight = orbit.computeSunDirection(0.00);
      final SkyVector3 moonMidnight = orbit.computeMoonDirection(0.00);

      expect(moonMidnight.length, closeTo(1.0, 1e-6));
      // At midnight, Sun is down, Moon is up
      expect(sunMidnight.y, lessThan(0.0));
      expect(moonMidnight.y, greaterThan(0.3));

      // Opposition dot product in topocentric coordinates with 45 deg latitude
      final double alignment = sunMidnight.dot(moonMidnight);
      expect(alignment, lessThan(-0.5));
    });

    test('Solar radiance scales with atmospheric extinction', () {
      final SkyVector3 sunNoon = orbit.computeSunDirection(0.50);
      final LinearColor noonRadiance = orbit.computeSunRadiance(sunNoon);
      expect(noonRadiance.luminance, greaterThan(5.0));

      final SkyVector3 sunDusk = orbit.computeSunDirection(0.75);
      final LinearColor duskRadiance = orbit.computeSunRadiance(sunDusk);
      expect(duskRadiance.luminance, lessThan(noonRadiance.luminance));
      expect(duskRadiance.r, greaterThan(duskRadiance.b)); // Warm sunset tint

      final SkyVector3 sunMidnight = orbit.computeSunDirection(0.00);
      final LinearColor midnightRadiance = orbit.computeSunRadiance(sunMidnight);
      expect(midnightRadiance.luminance, equals(0.0)); // Extinguished below horizon
    });

    test('Lunar radiance is active at night and inactive at midday', () {
      final SkyVector3 moonMidnight = orbit.computeMoonDirection(0.00);
      final LinearColor midnightMoon = orbit.computeMoonRadiance(moonMidnight);
      expect(midnightMoon.luminance, greaterThan(0.5));
      expect(midnightMoon.b, greaterThan(midnightMoon.r)); // Silver/cool moonlight

      final SkyVector3 moonNoon = orbit.computeMoonDirection(0.50);
      final LinearColor noonMoon = orbit.computeMoonRadiance(moonNoon);
      expect(noonMoon.luminance, equals(0.0)); // Moon below horizon at noon
    });
  });

  group('TimeOfDayModel & Diurnal Phases Tests', () {
    test('Clock advances and accurately determines celestial phases', () {
      final TimeOfDayModel model = TimeOfDayModel(initialHours: 6.0); // 06:00
      expect(model.currentPhase, equals(CelestialPhase.dawn));

      model.setHours(12.0); // 12:00
      expect(model.currentPhase, equals(CelestialPhase.noon));

      model.setHours(18.0); // 18:00
      expect(model.currentPhase, equals(CelestialPhase.dusk));

      model.setHours(20.0); // 20:00
      expect(model.currentPhase, equals(CelestialPhase.twilight));

      model.setHours(0.0); // Midnight
      expect(model.currentPhase, equals(CelestialPhase.midnight));

      model.setHours(23.5); // Midnight phase
      expect(model.currentPhase, equals(CelestialPhase.midnight));

      // Advance by 1 hour (3600 seconds)
      model.setHours(23.5);
      model.advance(3600.0); // Now 00:30
      expect(model.hours, closeTo(0.5, 1e-4));
      expect(model.currentPhase, equals(CelestialPhase.midnight));

      // Check phase progress is in [0.0, 1.0]
      expect(model.phaseProgress, greaterThanOrEqualTo(0.0));
      expect(model.phaseProgress, lessThanOrEqualTo(1.0));
    });
  });

  group('Global Illumination & Spherical Harmonics Tests', () {
    test('Analytical GI computes daytime Rayleigh blue zenith and night astral indigo', () {
      final CelestialOrbitSystem orbit = CelestialOrbitSystem();

      // Midday GI
      final SkyVector3 sunNoon = orbit.computeSunDirection(0.50);
      final SkyVector3 moonNoon = orbit.computeMoonDirection(0.50);
      final LinearColor sunNoonRad = orbit.computeSunRadiance(sunNoon);
      final LinearColor moonNoonRad = orbit.computeMoonRadiance(moonNoon);

      final WorldGiUniforms dayGi = GlobalIlluminationComputer.computeWorldGi(
        sunDir: sunNoon,
        moonDir: moonNoon,
        sunRadiance: sunNoonRad,
        moonRadiance: moonNoonRad,
        params: SkyPreset.clearDay,
      );

      // Daytime zenith has blue dominance
      expect(dayGi.zenithColor.b, greaterThan(dayGi.zenithColor.r));
      expect(dayGi.mainLightIntensity, greaterThan(0.5));

      // Midnight GI
      final SkyVector3 sunMid = orbit.computeSunDirection(0.00);
      final SkyVector3 moonMid = orbit.computeMoonDirection(0.00);
      final LinearColor sunMidRad = orbit.computeSunRadiance(sunMid);
      final LinearColor moonMidRad = orbit.computeMoonRadiance(moonMid);

      final WorldGiUniforms nightGi = GlobalIlluminationComputer.computeWorldGi(
        sunDir: sunMid,
        moonDir: moonMid,
        sunRadiance: sunMidRad,
        moonRadiance: moonMidRad,
        params: SkyPreset.darkFantasyMidnight,
      );

      expect(nightGi.zenithColor.luminance, lessThan(dayGi.zenithColor.luminance));
      expect(nightGi.mainLightIntensity, lessThan(dayGi.mainLightIntensity));
      expect(nightGi.mainLightDirection, equals(moonMid));
    });

    test('Spherical Harmonics L0+L1 irradiance evaluation preserves directional bias', () {
      const SphericalHarmonicsL1 sh = SphericalHarmonicsL1(
        l00: LinearColor(0.5, 0.5, 0.6),      // Ambient
        l1Minus1: LinearColor(0.3, 0.3, 0.4), // Vertical Zenith bias (+Y)
        l10: LinearColor(0.0, 0.0, 0.0),
        l11: LinearColor(0.1, 0.0, 0.0),      // East bias (+X)
      );

      // Upward surface normal (0, 1, 0): receives full zenith ambient
      final LinearColor upIrr = sh.evaluateIrradiance(SkyVector3.up);

      // Downward surface normal (0, -1, 0): receives nadir ground bounce
      final LinearColor downIrr = sh.evaluateIrradiance(SkyVector3.down);

      expect(upIrr.luminance, greaterThan(downIrr.luminance));
    });

    test('WorldGiUniforms packs contiguous 32-float buffer with zero NaNs', () {
      final DynamicSkyboxController controller = DynamicSkyboxController(initialHours: 12.0);
      final Float32List giBuffer = controller.giUniforms.toFloat32List();

      expect(giBuffer.length, equals(32));
      for (int i = 0; i < giBuffer.length; i++) {
        expect(giBuffer[i].isFinite, isTrue, reason: 'Index $i is not finite: ${giBuffer[i]}');
      }
    });
  });

  group('Shader Uniform Packing & Continuous Cycle Stress Test', () {
    test('buildShaderUniforms produces exact 39-float array matching GLSL layout', () {
      final DynamicSkyboxController controller = DynamicSkyboxController(initialHours: 12.0);
      const ui.Size viewport = ui.Size(1920.0, 1080.0);

      final Float32List uniforms = controller.buildShaderUniforms(viewport, timeSeconds: 42.5);

      expect(uniforms.length, equals(39));

      // 0..1: uResolution
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));
      // 2: uTime
      expect(uniforms[2], equals(42.5));
      // 3: uTimeOfDay (12:00 -> 0.5)
      expect(uniforms[3], closeTo(0.5, 1e-4));
      // 4..6: uSunDirection
      expect(uniforms[4], closeTo(controller.sunDirection.x, 1e-5));
      expect(uniforms[5], closeTo(controller.sunDirection.y, 1e-5));
      expect(uniforms[6], closeTo(controller.sunDirection.z, 1e-5));
      // 7..9: uMoonDirection
      expect(uniforms[7], closeTo(controller.moonDirection.x, 1e-5));
      expect(uniforms[8], closeTo(controller.moonDirection.y, 1e-5));
      expect(uniforms[9], closeTo(controller.moonDirection.z, 1e-5));
      // 10..12: uSunColor
      expect(uniforms[10], closeTo(controller.sunRadiance.r, 1e-5));
      expect(uniforms[11], closeTo(controller.sunRadiance.g, 1e-5));
      expect(uniforms[12], closeTo(controller.sunRadiance.b, 1e-5));
      // 13..15: uMoonColor
      expect(uniforms[13], closeTo(controller.moonRadiance.r, 1e-5));
      expect(uniforms[14], closeTo(controller.moonRadiance.g, 1e-5));
      expect(uniforms[15], closeTo(controller.moonRadiance.b, 1e-5));
      // 16..18: uRayleighCoeff
      expect(uniforms[16], closeTo(5.8e-3, 1e-6));
      expect(uniforms[17], closeTo(13.5e-3, 1e-6));
      expect(uniforms[18], closeTo(33.1e-3, 1e-6));
      // 19: uRayleighScale
      expect(uniforms[19], closeTo(1.0, 1e-5));
      // 20: uMieCoeff
      expect(uniforms[20], closeTo(0.002, 1e-5));
      // 21: uMieG
      expect(uniforms[21], closeTo(0.76, 1e-4));
      // 22: uTurbidity
      expect(uniforms[22], closeTo(1.8, 1e-4));
      // 23..25: uGroundColor
      expect(uniforms[23], closeTo(controller.params.groundColor.r, 1e-5));
      expect(uniforms[24], closeTo(controller.params.groundColor.g, 1e-5));
      expect(uniforms[25], closeTo(controller.params.groundColor.b, 1e-5));
      // 37: uFov
      expect(uniforms[37], closeTo(controller.fov, 1e-4));
      // 38: uExposure
      expect(uniforms[38], equals(controller.params.exposure));
    });

    test('24-Hour Continuous Simulation Stress: 96 steps with zero NaN or infinities', () {
      final DynamicSkyboxController controller = DynamicSkyboxController(initialHours: 0.0);
      const ui.Size size = ui.Size(800.0, 600.0);

      // Step across 24 hours in 15 minute increments (96 iterations)
      for (int step = 0; step < 96; step++) {
        controller.setTime(step * 0.25);
        final Float32List uniforms = controller.buildShaderUniforms(size, timeSeconds: step * 60.0);

        for (int i = 0; i < uniforms.length; i++) {
          expect(uniforms[i].isFinite, isTrue,
              reason: 'Time ${controller.timeModel} generated non-finite uniform at index $i: ${uniforms[i]}');
        }

        expect(controller.sunDirection.length, closeTo(1.0, 1e-5));
        expect(controller.moonDirection.length, closeTo(1.0, 1e-5));

        final Float32List gi = controller.giUniforms.toFloat32List();
        for (int j = 0; j < gi.length; j++) {
          expect(gi[j].isFinite, isTrue,
              reason: 'Time ${controller.timeModel} generated non-finite GI float at index $j: ${gi[j]}');
        }
      }
    });

    test('Presets apply distinct atmospheric parameters', () {
      final DynamicSkyboxController controller = DynamicSkyboxController();

      controller.setParameters(SkyPreset.goldenDusk);
      expect(controller.params.mieG, equals(0.85));
      expect(controller.params.turbidity, equals(4.5));

      controller.setParameters(SkyPreset.darkFantasyMidnight);
      expect(controller.params.nebulaIntensity, equals(4.2));
      expect(controller.params.starIntensity, equals(3.5));

      controller.setParameters(SkyPreset.bloodMoon);
      expect(controller.params.rayleighScale, equals(1.8));
    });

    test('DynamicSkyboxPainter analytical canvas fallback executes without throwing', () {
      final DynamicSkyboxController controller = DynamicSkyboxController();
      final DynamicSkyboxPainter painter = DynamicSkyboxPainter(controller: controller);

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      const ui.Size size = ui.Size(1280.0, 720.0);

      // Noon test
      controller.setTime(12.0);
      expect(() => painter.paint(canvas, size), returnsNormally);

      // Sunset test
      controller.setTime(18.0);
      expect(() => painter.paint(canvas, size), returnsNormally);

      // Midnight test
      controller.setTime(0.0);
      expect(() => painter.paint(canvas, size), returnsNormally);

      final ui.Picture picture = recorder.endRecording();
      picture.dispose();
    });
  });
}
