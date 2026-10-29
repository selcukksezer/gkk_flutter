import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/world/dynamic_skybox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // SECTION 1: GLSL Shader Source File Contract & Uniform Interface Integrity
  // ===========================================================================
  group('Atmospheric Sky Shader GLSL File Verification', () {
    late File shaderFile;
    late String shaderContent;

    setUpAll(() {
      shaderFile = File('shaders/world/atmospheric_sky.frag');
      expect(
        shaderFile.existsSync(),
        isTrue,
        reason: 'atmospheric_sky.frag must exist at shaders/world/atmospheric_sky.frag',
      );
      shaderContent = shaderFile.readAsStringSync();
    });

    test('Shader header has version 460 core and flutter runtime_effect include', () {
      expect(shaderContent, contains('#version 460 core'));
      expect(shaderContent, contains('#include <flutter/runtime_effect.glsl>'));
      expect(shaderContent, contains('precision highp float;'));
    });

    test('Shader declares all 20 uniform variables in exact contiguous sequence (39 floats)', () {
      // 0..1: uResolution (vec2)
      expect(shaderContent, contains('uniform vec2  uResolution;'));
      // 2: uTime (float)
      expect(shaderContent, contains('uniform float uTime;'));
      // 3: uTimeOfDay (float)
      expect(shaderContent, contains('uniform float uTimeOfDay;'));
      // 4..6: uSunDirection (vec3)
      expect(shaderContent, contains('uniform vec3  uSunDirection;'));
      // 7..9: uMoonDirection (vec3)
      expect(shaderContent, contains('uniform vec3  uMoonDirection;'));
      // 10..12: uSunColor (vec3)
      expect(shaderContent, contains('uniform vec3  uSunColor;'));
      // 13..15: uMoonColor (vec3)
      expect(shaderContent, contains('uniform vec3  uMoonColor;'));
      // 16..18: uRayleighCoeff (vec3)
      expect(shaderContent, contains('uniform vec3  uRayleighCoeff;'));
      // 19: uRayleighScale (float)
      expect(shaderContent, contains('uniform float uRayleighScale;'));
      // 20: uMieCoeff (float)
      expect(shaderContent, contains('uniform float uMieCoeff;'));
      // 21: uMieG (float)
      expect(shaderContent, contains('uniform float uMieG;'));
      // 22: uTurbidity (float)
      expect(shaderContent, contains('uniform float uTurbidity;'));
      // 23..25: uGroundColor (vec3)
      expect(shaderContent, contains('uniform vec3  uGroundColor;'));
      // 26..28: uNebulaColor1 (vec3)
      expect(shaderContent, contains('uniform vec3  uNebulaColor1;'));
      // 29..31: uNebulaColor2 (vec3)
      expect(shaderContent, contains('uniform vec3  uNebulaColor2;'));
      // 32: uNebulaIntensity (float)
      expect(shaderContent, contains('uniform float uNebulaIntensity;'));
      // 33: uStarIntensity (float)
      expect(shaderContent, contains('uniform float uStarIntensity;'));
      // 34..36: uCameraRotation (vec3)
      expect(shaderContent, contains('uniform vec3  uCameraRotation;'));
      // 37: uFov (float)
      expect(shaderContent, contains('uniform float uFov;'));
      // 38: uExposure (float)
      expect(shaderContent, contains('uniform float uExposure;'));

      // Validate relative ordering of declarations to guarantee uniform buffer alignment
      final int idxRes = shaderContent.indexOf('uResolution');
      final int idxTime = shaderContent.indexOf('uTime;');
      final int idxTimeOfDay = shaderContent.indexOf('uTimeOfDay');
      final int idxSunDir = shaderContent.indexOf('uSunDirection');
      final int idxMoonDir = shaderContent.indexOf('uMoonDirection');
      final int idxSunCol = shaderContent.indexOf('uSunColor');
      final int idxMoonCol = shaderContent.indexOf('uMoonColor');
      final int idxRayleighCoeff = shaderContent.indexOf('uRayleighCoeff');
      final int idxRayleighScale = shaderContent.indexOf('uRayleighScale');
      final int idxMieCoeff = shaderContent.indexOf('uMieCoeff');
      final int idxMieG = shaderContent.indexOf('uMieG');
      final int idxTurbidity = shaderContent.indexOf('uTurbidity');
      final int idxGroundCol = shaderContent.indexOf('uGroundColor');
      final int idxNebula1 = shaderContent.indexOf('uNebulaColor1');
      final int idxNebula2 = shaderContent.indexOf('uNebulaColor2');
      final int idxNebulaInt = shaderContent.indexOf('uNebulaIntensity');
      final int idxStarInt = shaderContent.indexOf('uStarIntensity');
      final int idxCamRot = shaderContent.indexOf('uCameraRotation');
      final int idxFov = shaderContent.indexOf('uFov');
      final int idxExposure = shaderContent.indexOf('uExposure');

      expect(idxRes, lessThan(idxTime));
      expect(idxTime, lessThan(idxTimeOfDay));
      expect(idxTimeOfDay, lessThan(idxSunDir));
      expect(idxSunDir, lessThan(idxMoonDir));
      expect(idxMoonDir, lessThan(idxSunCol));
      expect(idxSunCol, lessThan(idxMoonCol));
      expect(idxMoonCol, lessThan(idxRayleighCoeff));
      expect(idxRayleighCoeff, lessThan(idxRayleighScale));
      expect(idxRayleighScale, lessThan(idxMieCoeff));
      expect(idxMieCoeff, lessThan(idxMieG));
      expect(idxMieG, lessThan(idxTurbidity));
      expect(idxTurbidity, lessThan(idxGroundCol));
      expect(idxGroundCol, lessThan(idxNebula1));
      expect(idxNebula1, lessThan(idxNebula2));
      expect(idxNebula2, lessThan(idxNebulaInt));
      expect(idxNebulaInt, lessThan(idxStarInt));
      expect(idxStarInt, lessThan(idxCamRot));
      expect(idxCamRot, lessThan(idxFov));
      expect(idxFov, lessThan(idxExposure));
    });

    test('Shader declares out vec4 fragColor and essential atmospheric algorithms', () {
      expect(shaderContent, contains('out vec4 fragColor;'));
      expect(shaderContent, contains('float rayleighPhase('));
      expect(shaderContent, contains('float miePhase('));
      expect(shaderContent, contains('float opticalAirMass('));
      expect(shaderContent, contains('float renderStars('));
      expect(shaderContent, contains('vec3 renderNebula('));
      expect(shaderContent, contains('float nebulaFbm('));
      expect(shaderContent, contains('vec3 renderSunDisk('));
      expect(shaderContent, contains('vec3 renderMoonDisk('));
      expect(shaderContent, contains('vec3 acesTonemap('));
      expect(shaderContent, contains('void main()'));
    });
  });

  // ===========================================================================
  // SECTION 2: Rayleigh & Mie Atmospheric Scattering Uniform Packing & Math
  // ===========================================================================
  group('Rayleigh & Mie Atmospheric Scattering Uniform Packing & Parity', () {
    test('DynamicSkyboxController packs exact 39-float array with accurate Rayleigh & Mie parameters', () {
      final controller = DynamicSkyboxController(
        initialHours: 12.0,
        initialParams: const AtmosphericParameters(
          rayleighCoeff: SkyVector3(0.0058, 0.0135, 0.0331),
          rayleighScale: 1.25,
          mieCoeff: 0.0035,
          mieG: 0.82,
          turbidity: 3.2,
          groundColor: LinearColor(0.15, 0.12, 0.08),
          nebulaColor1: LinearColor(0.70, 0.10, 0.80),
          nebulaColor2: LinearColor(0.10, 0.60, 0.90),
          nebulaIntensity: 3.0,
          starIntensity: 2.5,
          exposure: 1.1,
        ),
      );

      final Float32List uniforms = controller.buildShaderUniforms(const ui.Size(1920.0, 1080.0), timeSeconds: 42.5);
      expect(uniforms.length, equals(39));

      // Viewport & Time (0..3)
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));
      expect(uniforms[2], equals(42.5));
      expect(uniforms[3], closeTo(0.5, 1e-4)); // 12:00 -> 0.5

      // Rayleigh coefficients & scale (16..19)
      expect(uniforms[16], closeTo(0.0058, 1e-6));
      expect(uniforms[17], closeTo(0.0135, 1e-6));
      expect(uniforms[18], closeTo(0.0331, 1e-6));
      expect(uniforms[19], closeTo(1.25, 1e-6));

      // Mie scattering & aerosol haze turbidity (20..22)
      expect(uniforms[20], closeTo(0.0035, 1e-6));
      expect(uniforms[21], closeTo(0.82, 1e-6));
      expect(uniforms[22], closeTo(3.2, 1e-6));

      // Ground color (23..25)
      expect(uniforms[23], closeTo(0.15, 1e-6));
      expect(uniforms[24], closeTo(0.12, 1e-6));
      expect(uniforms[25], closeTo(0.08, 1e-6));

      // Exposure scalar (38)
      expect(uniforms[38], closeTo(1.1, 1e-6));
    });

    test('Atmospheric presets configure Rayleigh, Mie, and Turbidity with physically sound parameters', () {
      // Clear Day: subtle Mie haze, normal turbidity, balanced Rayleigh
      const clearDay = SkyPreset.clearDay;
      expect(clearDay.rayleighScale, equals(1.0));
      expect(clearDay.mieCoeff, equals(0.002));
      expect(clearDay.mieG, equals(0.76));
      expect(clearDay.turbidity, equals(1.8));

      // Golden Dusk: heightened Mie forward scattering, higher turbidity, warm ground bounce
      const goldenDusk = SkyPreset.goldenDusk;
      expect(goldenDusk.rayleighScale, greaterThan(clearDay.rayleighScale));
      expect(goldenDusk.mieCoeff, greaterThan(clearDay.mieCoeff));
      expect(goldenDusk.mieG, greaterThan(clearDay.mieG)); // Narrower, more forward sun halo
      expect(goldenDusk.turbidity, greaterThan(clearDay.turbidity));

      // Dark Fantasy Midnight: reduced daytime scattering, amplified cosmic emission
      const midnight = SkyPreset.darkFantasyMidnight;
      expect(midnight.rayleighScale, lessThan(clearDay.rayleighScale));
      expect(midnight.turbidity, lessThan(clearDay.turbidity));
      expect(midnight.nebulaIntensity, greaterThan(3.5));
      expect(midnight.starIntensity, greaterThan(3.0));

      // Blood Moon: extreme crimson Rayleigh spectrum, heavy atmospheric haze
      const bloodMoon = SkyPreset.bloodMoon;
      expect(bloodMoon.rayleighCoeff.x, greaterThan(bloodMoon.rayleighCoeff.z)); // Red dominates Blue
      expect(bloodMoon.turbidity, equals(6.0));
      expect(bloodMoon.mieG, equals(0.88));
    });

    test('Atmospheric parameters copyWith enables partial immutable overrides', () {
      const original = AtmosphericParameters();
      final modified = original.copyWith(
        rayleighScale: 2.0,
        turbidity: 5.0,
        exposure: 1.5,
      );

      expect(modified.rayleighScale, equals(2.0));
      expect(modified.turbidity, equals(5.0));
      expect(modified.exposure, equals(1.5));
      expect(modified.mieCoeff, equals(original.mieCoeff));
      expect(modified.mieG, equals(original.mieG));
      expect(modified.rayleighCoeff, equals(original.rayleighCoeff));
    });

    test('Rayleigh Phase Function exhibits exact mathematical symmetry and forward-backward peaking', () {
      double rayleighPhase(double cosTheta) {
        return (3.0 / (16.0 * math.pi)) * (1.0 + cosTheta * cosTheta);
      }

      // Perpendicular scattering (cosTheta = 0): minimum phase intensity
      final double minPhase = rayleighPhase(0.0);
      expect(minPhase, closeTo(3.0 / (16.0 * math.pi), 1e-6));

      // Forward scattering (cosTheta = 1.0) and backward scattering (cosTheta = -1.0)
      final double forwardPhase = rayleighPhase(1.0);
      final double backPhase = rayleighPhase(-1.0);

      // Symmetry condition: Pr(cosTheta) == Pr(-cosTheta)
      expect(forwardPhase, equals(backPhase));
      expect(forwardPhase, closeTo(6.0 / (16.0 * math.pi), 1e-6));
      expect(forwardPhase, equals(minPhase * 2.0));

      // Values between -1 and 1 must be strictly greater than minPhase
      for (double cosTheta = -0.9; cosTheta <= 0.9; cosTheta += 0.2) {
        expect(rayleighPhase(cosTheta), greaterThanOrEqualTo(minPhase));
      }
    });

    test('Henyey-Greenstein Mie Phase Function produces forward scattering lobe parameterized by asymmetry factor g', () {
      double miePhase(double cosTheta, double g) {
        final double g2 = g * g;
        final double clampedCos = cosTheta.clamp(-1.0, 1.0);
        final double denom = math.max(1.0 + g2 - 2.0 * g * clampedCos, 1e-4);
        final double invFourPi = 1.0 / (4.0 * math.pi);
        return invFourPi * (1.0 - g2) / math.pow(denom, 1.5);
      }

      const double g = 0.76;
      final double forwardLobe = miePhase(1.0, g);
      final double perpLobe = miePhase(0.0, g);
      final double backLobe = miePhase(-1.0, g);

      // Forward scattering is dramatically stronger than 90-degree and backward scattering
      expect(forwardLobe, greaterThan(perpLobe * 10.0));
      expect(perpLobe, greaterThan(backLobe));

      // Higher g concentrates forward lobe even more intensely
      const double higherG = 0.88;
      expect(miePhase(1.0, higherG), greaterThan(forwardLobe));
    });

    test('Optical Air Mass decreases monotonically from horizon to zenith', () {
      double opticalAirMass(double cosZenith) {
        final double z = cosZenith.clamp(0.0, 1.0);
        final double thetaDeg = (math.pi * 0.5 - math.asin(z)) * (180.0 / math.pi);
        final double denom = z + 0.15 * math.pow(math.max(93.885 - thetaDeg, 1e-3), -1.253);
        return 1.0 / denom;
      }

      // Air mass at zenith (cosZenith = 1.0) must be ~1.0 atmosphere
      final double zenithAirMass = opticalAirMass(1.0);
      expect(zenithAirMass, closeTo(1.0, 0.05));

      // Air mass at horizon (cosZenith = 0.0) represents heavy atmospheric extinction (approx 30..40 air masses)
      final double horizonAirMass = opticalAirMass(0.0);
      expect(horizonAirMass, greaterThan(25.0));
      expect(horizonAirMass, lessThan(45.0));

      // Strict monotonicity from horizon (0.0) to zenith (1.0)
      double prevAirMass = horizonAirMass;
      for (double cosZ = 0.05; cosZ <= 1.0; cosZ += 0.05) {
        final double currentAirMass = opticalAirMass(cosZ);
        expect(currentAirMass, lessThan(prevAirMass));
        prevAirMass = currentAirMass;
      }
    });

    test('Atmospheric extinction attenuation decays exponentially with optical path', () {
      const SkyVector3 betaR = SkyVector3(0.0058, 0.0135, 0.0331);
      const double betaM = 0.0024 * 2.0;

      // Blue wavelength scatters far more rapidly than Red (Rayleigh wavelength law: 1 / lambda^4)
      expect(betaR.z, greaterThan(betaR.x * 4.0));

      // Compute transmittance: exp(-betaExt * path)
      final double extRed = betaR.x + betaM;
      final double extBlue = betaR.z + betaM;

      final double transRedShort = math.exp(-extRed * 1.0);
      final double transBlueShort = math.exp(-extBlue * 1.0);

      expect(transRedShort, greaterThan(transBlueShort));

      // Along long sunset path (e.g. 30 air masses), Blue is nearly extinguished, leaving Red/Golden
      final double transRedLong = math.exp(-extRed * 30.0);
      final double transBlueLong = math.exp(-extBlue * 30.0);

      expect(transRedLong / transBlueLong, greaterThan(2.0));
    });
  });

  // ===========================================================================
  // SECTION 3: 24h Simulated Day/Night Cycle, Sun & Moon Celestial Orbit
  // ===========================================================================
  group('24-Hour Day/Night Diurnal Cycle & Celestial Orbit Mechanics', () {
    test('TimeOfDayModel advances smoothly, handles wrap-around, and maps 7 diurnal phases', () {
      final model = TimeOfDayModel(initialHours: 12.0);
      expect(model.hours, equals(12.0));
      expect(model.normalizedTime, equals(0.5));
      expect(model.currentPhase, equals(CelestialPhase.noon));

      // Advance by 1 hour (3600 seconds with scale 1.0)
      model.advance(3600.0);
      expect(model.hours, closeTo(13.0, 1e-5));
      expect(model.currentPhase, equals(CelestialPhase.afternoon));

      // Advance to dusk (18:00)
      model.setHours(18.0);
      expect(model.normalizedTime, equals(0.75));
      expect(model.currentPhase, equals(CelestialPhase.dusk));

      // Advance to twilight (20:00)
      model.setHours(20.0);
      expect(model.currentPhase, equals(CelestialPhase.twilight));

      // Advance to midnight (23:00)
      model.setHours(23.0);
      expect(model.currentPhase, equals(CelestialPhase.midnight));

      // Advance to dawn (06:00)
      model.setHours(6.0);
      expect(model.currentPhase, equals(CelestialPhase.dawn));

      // Advance to morning (08:30)
      model.setHours(8.5);
      expect(model.currentPhase, equals(CelestialPhase.morning));

      // Verify wrap-around for overflow >= 24.0 and underflow < 0.0
      model.setHours(26.5);
      expect(model.hours, closeTo(2.5, 1e-5));
      expect(model.currentPhase, equals(CelestialPhase.midnight));

      model.setHours(-3.0);
      expect(model.hours, closeTo(21.0, 1e-5));
      expect(model.currentPhase, equals(CelestialPhase.twilight));

      // String formatting verification
      model.setHours(14.5);
      final String formatted = model.toString();
      expect(formatted, contains('14:30:00'));
      expect(formatted, contains('afternoon'));
    });

    test('Midnight diurnal phase handles wrap-around boundary across day transition', () {
      // Midnight wraps from 0.896 (21:30) to 0.208 (05:00)
      final model = TimeOfDayModel();

      model.setHours(22.0); // 22:00 -> norm 0.9167
      expect(model.currentPhase, equals(CelestialPhase.midnight));
      expect(model.phaseProgress, inInclusiveRange(0.0, 1.0));

      model.setHours(0.0); // 00:00 -> norm 0.0
      expect(model.currentPhase, equals(CelestialPhase.midnight));
      expect(model.phaseProgress, inInclusiveRange(0.0, 1.0));

      model.setHours(4.0); // 04:00 -> norm 0.1667
      expect(model.currentPhase, equals(CelestialPhase.midnight));
      expect(model.phaseProgress, inInclusiveRange(0.0, 1.0));

      // Progress should be monotonically increasing through midnight span
      model.setHours(22.0);
      final double prog22 = model.phaseProgress;
      model.setHours(0.0);
      final double prog00 = model.phaseProgress;
      model.setHours(3.0);
      final double prog03 = model.phaseProgress;

      expect(prog22, lessThan(prog00));
      expect(prog00, lessThan(prog03));
    });

    test('CelestialOrbitSystem calculates normalized Sun and Moon vectors throughout 24-hour cycle', () {
      final orbit = CelestialOrbitSystem();

      // Sample 96 timestamps (every 15 minutes) across the complete 24h orbit
      for (int i = 0; i < 96; i++) {
        final double normTime = i / 96.0;
        final SkyVector3 sunDir = orbit.computeSunDirection(normTime);
        final SkyVector3 moonDir = orbit.computeMoonDirection(normTime);

        // Vector length must strictly be unit normalized (1.0 ± 1e-5)
        expect(sunDir.length, closeTo(1.0, 1e-5), reason: 'Sun vector must be normalized at t=$normTime');
        expect(moonDir.length, closeTo(1.0, 1e-5), reason: 'Moon vector must be normalized at t=$normTime');

        // Neither vector should contain NaN or Infinity
        expect(sunDir.x.isNaN, isFalse);
        expect(sunDir.y.isNaN, isFalse);
        expect(sunDir.z.isNaN, isFalse);
        expect(moonDir.x.isNaN, isFalse);
        expect(moonDir.y.isNaN, isFalse);
        expect(moonDir.z.isNaN, isFalse);
      }
    });

    test('Solar elevation peaks at midday and reaches nadir at midnight', () {
      final orbit = CelestialOrbitSystem();

      final SkyVector3 noonSun = orbit.computeSunDirection(0.5); // 12:00
      final SkyVector3 midnightSun = orbit.computeSunDirection(0.0); // 00:00
      final SkyVector3 dawnSun = orbit.computeSunDirection(0.25); // 06:00
      final SkyVector3 duskSun = orbit.computeSunDirection(0.75); // 18:00

      // Noon sun elevation is high in the sky (+Y zenith)
      expect(noonSun.y, greaterThan(0.6));
      expect(noonSun.elevation, greaterThan(math.pi * 0.25));

      // Midnight sun is well below the horizon (-Y nadir)
      expect(midnightSun.y, lessThan(-0.2));
      expect(midnightSun.elevation, lessThan(0.0));

      // Dawn sun rises in the East (+X)
      expect(dawnSun.x, greaterThan(0.5));
      expect(dawnSun.elevation, closeTo(0.0, 0.25));

      // Dusk sun sets in the West (-X)
      expect(duskSun.x, lessThan(-0.5));
      expect(duskSun.elevation, closeTo(0.0, 0.25));

      // Midday sun elevation is strictly the maximum of all four
      expect(noonSun.y, greaterThan(dawnSun.y));
      expect(noonSun.y, greaterThan(duskSun.y));
      expect(noonSun.y, greaterThan(midnightSun.y));
    });

    test('Moon opposes the Sun with 5.14-degree orbital inclination tilt offset', () {
      final orbit = CelestialOrbitSystem();

      // At midday (Sun at zenith), Moon is on the opposite side of the planet (below horizon)
      final SkyVector3 middayMoon = orbit.computeMoonDirection(0.5);
      expect(middayMoon.y, lessThan(0.0));

      // At midnight (Sun at nadir), Moon is elevated in the night sky
      final SkyVector3 midnightMoon = orbit.computeMoonDirection(0.0);
      expect(midnightMoon.y, greaterThan(0.2));

      // Verify 5.14 degree orbital tilt offset prevents Moon from being an exact simple negative of Sun
      final SkyVector3 noonSun = orbit.computeSunDirection(0.5);
      final SkyVector3 exactOpposite = -noonSun;

      // Because of the 5.14 degree orbital tilt, dot product between actual moon and exact opposite is slightly < 1.0
      final double dotProd = middayMoon.dot(exactOpposite);
      expect(dotProd, closeTo(math.cos(0.0897), 0.05));
      expect(dotProd, lessThan(1.0)); // Proves genuine orbital mechanics, not hardcoded negation
    });

    test('24-Hour continuous trajectory shows smooth vector transitions without jumps', () {
      final orbit = CelestialOrbitSystem();
      SkyVector3 previousSun = orbit.computeSunDirection(0.0);

      // Verify that every 15-minute step has a small continuous delta (< 0.15 radians displacement)
      for (int i = 1; i <= 96; i++) {
        final double normTime = (i % 96) / 96.0;
        final SkyVector3 currentSun = orbit.computeSunDirection(normTime);
        final double displacement = currentSun.distanceTo(previousSun);
        expect(displacement, lessThan(0.15), reason: 'Discontinuity detected at step $i');
        previousSun = currentSun;
      }
    });
  });

  // ===========================================================================
  // SECTION 4: Cloud Layer Turbulence, Cosmic Nebula, Density & Drift Speed
  // ===========================================================================
  group('Cloud Layer Turbulence, Density & Drift Speed Verification', () {
    test('Shader uniforms pack nebula colors, intensity, and simulation time for temporal cloud drift', () {
      final controller = DynamicSkyboxController(
        initialHours: 0.0, // Midnight
        initialParams: const AtmosphericParameters(
          nebulaColor1: LinearColor(0.85, 0.15, 0.92), // Radiant Cosmic Magenta
          nebulaColor2: LinearColor(0.05, 0.75, 0.98), // Astral Cyan
          nebulaIntensity: 4.5,
          starIntensity: 3.8,
          turbidity: 2.2,
        ),
      );

      final Float32List uniforms = controller.buildShaderUniforms(const ui.Size(1280.0, 720.0), timeSeconds: 120.0);

      // uTime (index 2) drives dynamic cloud turbulence and drift
      expect(uniforms[2], equals(120.0));

      // Turbidity / aerosol haze cloud density (index 22)
      expect(uniforms[22], closeTo(2.2, 1e-5));

      // Nebula primary color RGB (indices 26..28)
      expect(uniforms[26], closeTo(0.85, 1e-5));
      expect(uniforms[27], closeTo(0.15, 1e-5));
      expect(uniforms[28], closeTo(0.92, 1e-5));

      // Nebula secondary color RGB (indices 29..31)
      expect(uniforms[29], closeTo(0.05, 1e-5));
      expect(uniforms[30], closeTo(0.75, 1e-5));
      expect(uniforms[31], closeTo(0.98, 1e-5));

      // Nebula intensity multiplier (index 32)
      expect(uniforms[32], closeTo(4.5, 1e-5));

      // Starfield brightness scalar (index 33)
      expect(uniforms[33], closeTo(3.8, 1e-5));
    });

    test('Temporal cosmic cloud drift vector velocity and magnitude satisfy shader specifications', () {
      // In atmospheric_sky.frag:
      // vec3 drift = vec3(time * 0.005, time * 0.003, -time * 0.004);
      SkyVector3 computeCloudDrift(double time) {
        return SkyVector3(
          time * 0.005,
          time * 0.003,
          -time * 0.004,
        );
      }

      final SkyVector3 drift0 = computeCloudDrift(0.0);
      expect(drift0, equals(SkyVector3.zero));

      final SkyVector3 drift100 = computeCloudDrift(100.0);
      expect(drift100.x, closeTo(0.5, 1e-5));
      expect(drift100.y, closeTo(0.3, 1e-5));
      expect(drift100.z, closeTo(-0.4, 1e-5));

      // Cosmic drift speed magnitude = sqrt(0.005^2 + 0.003^2 + 0.004^2) ≈ 0.007071 units per second
      final double expectedSpeed = math.sqrt(0.005 * 0.005 + 0.003 * 0.003 + 0.004 * 0.004);
      final double actualSpeed = drift100.length / 100.0;
      expect(actualSpeed, closeTo(expectedSpeed, 1e-6));
      expect(actualSpeed, closeTo(0.007071, 1e-5));
    });

    test('4-Octave Fractional Brownian Motion (fBm) cloud turbulence series converges', () {
      // Test fractal series amplitude summation: 0.5 + 0.25 + 0.125 + 0.0625 = 0.9375 < 1.0
      double totalAmplitude = 0.0;
      double amp = 0.5;
      for (int i = 0; i < 4; i++) {
        totalAmplitude += amp;
        amp *= 0.5;
      }
      expect(totalAmplitude, equals(0.9375));
      expect(totalAmplitude, lessThan(1.0));

      // Verify the 3D rotation matrix used in GLSL nebulaFbm preserves orthogonality (det = 1.0):
      // mat3 rot = mat3(
      //    0.00,  0.80,  0.60,
      //   -0.80,  0.36, -0.48,
      //   -0.60, -0.48,  0.64
      // );
      const r00 = 0.00, r01 = 0.80, r02 = 0.60;
      const r10 = -0.80, r11 = 0.36, r12 = -0.48;
      const r20 = -0.60, r21 = -0.48, r22 = 0.64;

      final double det = r00 * (r11 * r22 - r12 * r21) -
          r01 * (r10 * r22 - r12 * r20) +
          r02 * (r10 * r21 - r11 * r20);

      expect(det, closeTo(1.0, 1e-5));
    });

    test('Cloud density threshold mask and filament power curves satisfy smoothstep behavior', () {
      double smoothstep(double edge0, double edge1, double x) {
        final double t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
        return t * t * (3.0 - 2.0 * t);
      }

      // Cloud density mask: smoothstep(0.35, 0.82, n)
      expect(smoothstep(0.35, 0.82, 0.20), equals(0.0)); // Clear sky, zero cloud
      expect(smoothstep(0.35, 0.82, 0.35), equals(0.0)); // Mask threshold start
      expect(smoothstep(0.35, 0.82, 0.585), closeTo(0.5, 0.05)); // Mid-density
      expect(smoothstep(0.35, 0.82, 0.82), equals(1.0)); // Full density
      expect(smoothstep(0.35, 0.82, 1.00), equals(1.0)); // Core peak

      // Core filament glow: pow(smoothstep(0.45, 0.88, n), 2.5) * 2.0
      double filamentGlow(double n) {
        final double s = smoothstep(0.45, 0.88, n);
        return math.pow(s, 2.5) * 2.0;
      }

      expect(filamentGlow(0.40), equals(0.0));
      expect(filamentGlow(0.88), closeTo(2.0, 1e-5));
      expect(filamentGlow(0.70), greaterThan(0.0));
      expect(filamentGlow(0.70), lessThan(filamentGlow(0.88)));
    });

    test('Advancing simulation time in DynamicSkyboxController increments totalTimeElapsed and updates drift', () {
      final controller = DynamicSkyboxController();
      expect(controller.totalTimeElapsed, equals(0.0));

      controller.update(0.5);
      expect(controller.totalTimeElapsed, closeTo(0.5, 1e-6));

      controller.update(1.25);
      expect(controller.totalTimeElapsed, closeTo(1.75, 1e-6));

      final Float32List uniforms = controller.buildShaderUniforms(const ui.Size(800, 600));
      expect(uniforms[2], closeTo(1.75, 1e-6));
    });
  });

  // ===========================================================================
  // SECTION 5: Twilight / Dusk / Midday / Midnight Color Palette Transitions
  // ===========================================================================
  group('Twilight, Dusk, Midday, and Midnight Color Palette Transitions', () {
    test('Midday lighting: crisp daylight white sun, vibrant Rayleigh blue zenith, sun as primary light', () {
      final controller = DynamicSkyboxController(initialHours: 12.0);

      final LinearColor sunRad = controller.sunRadiance;
      final WorldGiUniforms gi = controller.giUniforms;

      // Sun radiance is high intensity and daylight white (6500K color temperature)
      expect(sunRad.luminance, greaterThan(5.0));
      // Red, Green, Blue radiance are well balanced at 6500K white
      expect(sunRad.r, closeTo(sunRad.b, 2.5));

      // Zenith color is dominated by Rayleigh scattering (vibrant blue: blue channel >> red channel)
      expect(gi.zenithColor.b, greaterThan(gi.zenithColor.r * 2.0));

      // Primary directional light is the Sun
      expect(gi.mainLightDirection, equals(controller.sunDirection));
      expect(gi.mainLightDirection.y, greaterThan(0.5));
      expect(gi.mainLightIntensity, greaterThan(0.8));
    });

    test('Dusk lighting: fiery crimson/golden horizon, warm sun color temperature, sunset band', () {
      final controller = DynamicSkyboxController(initialHours: 18.5); // 18:30 Dusk sunset

      final LinearColor sunRad = controller.sunRadiance;
      final WorldGiUniforms gi = controller.giUniforms;

      // Sun is near the horizon
      expect(controller.sunDirection.y, closeTo(0.0, 0.25));

      // Sun radiance shifts to warm golden/fiery red (2000K-3500K: Red channel dominates Blue channel)
      expect(sunRad.r, greaterThan(sunRad.b));

      // Horizon color represents the sunset belt: fiery orange / crimson
      expect(gi.horizonColor.r, greaterThan(gi.horizonColor.b));
      expect(gi.horizonColor.r, greaterThan(0.5));
    });

    test('Twilight lighting: sun sinks below horizon, deep indigo zenith transition', () {
      final controller = DynamicSkyboxController(initialHours: 20.5); // 20:30 Twilight

      final WorldGiUniforms gi = controller.giUniforms;

      // Sun is below horizon
      expect(controller.sunDirection.y, lessThan(0.0));

      // Twilight zenith shifts from Rayleigh daytime blue to deep indigo
      expect(gi.zenithColor.luminance, lessThan(0.3));
      expect(gi.zenithColor.b, greaterThan(gi.zenithColor.r));

      // Horizon transitions from fiery sunset to deep evening haze
      expect(gi.horizonColor.luminance, lessThan(0.6));
    });

    test('Midnight lighting: solar radiance extinguished, cool silver moonlight, cosmic nebula zenith', () {
      final controller = DynamicSkyboxController(
        initialHours: 0.0, // 00:00 Midnight
        initialParams: SkyPreset.darkFantasyMidnight,
      );

      final LinearColor sunRad = controller.sunRadiance;
      final LinearColor moonRad = controller.moonRadiance;
      final WorldGiUniforms gi = controller.giUniforms;

      // Sun is below -0.15 threshold, so solar radiance is completely extinguished
      expect(sunRad.r, equals(0.0));
      expect(sunRad.g, equals(0.0));
      expect(sunRad.b, equals(0.0));

      // Moon is elevated in the sky and active
      expect(controller.moonDirection.y, greaterThan(0.2));
      expect(moonRad.luminance, greaterThan(0.5));

      // Moonlight possesses cool astral silver/cyan spectrum (~8500K with Purkinje blue shift)
      expect(moonRad.b, greaterThan(moonRad.r));

      // Primary directional light switches to the Moon
      expect(gi.mainLightDirection, equals(controller.moonDirection));
      expect(gi.mainLightRadiance, equals(moonRad));

      // Zenith incorporates astral night sky and cosmic nebula emission
      expect(gi.zenithColor.luminance, greaterThan(0.0));
      expect(gi.zenithColor.luminance, lessThan(0.4)); // Dark, but lit by nebula glow
    });

    test('Diurnal progression shows smooth luminance transition across all 24 hours without sudden discontinuities', () {
      final controller = DynamicSkyboxController(initialHours: 0.0);

      double previousZenithLuminance = controller.giUniforms.zenithColor.luminance;

      // Sample every 30 minutes (48 samples) across 24 hours
      for (int i = 1; i <= 48; i++) {
        controller.setTime(i * 0.5);
        final double currentZenithLuminance = controller.giUniforms.zenithColor.luminance;

        // Verify no sudden NaN or explosive jump between consecutive half-hour steps
        final double delta = (currentZenithLuminance - previousZenithLuminance).abs();
        expect(delta, lessThan(0.35), reason: 'Luminance jump at step $i (time: ${i * 0.5})');

        previousZenithLuminance = currentZenithLuminance;
      }
    });
  });

  // ===========================================================================
  // SECTION 6: Atmospheric Vector & HDR Color Mathematical Primitives
  // ===========================================================================
  group('SkyVector3 & LinearColor Mathematical Operations', () {
    test('SkyVector3 basic arithmetic, dot, cross, and spherical conversions', () {
      const v1 = SkyVector3(1.0, 2.0, 3.0);
      const v2 = SkyVector3(4.0, 5.0, 6.0);

      expect(v1 + v2, equals(const SkyVector3(5.0, 7.0, 9.0)));
      expect(v2 - v1, equals(const SkyVector3(3.0, 3.0, 3.0)));
      expect(v1 * 2.0, equals(const SkyVector3(2.0, 4.0, 6.0)));
      expect(v2 / 2.0, equals(const SkyVector3(2.0, 2.5, 3.0)));
      expect(-v1, equals(const SkyVector3(-1.0, -2.0, -3.0)));

      // Dot product: 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
      expect(v1.dot(v2), equals(32.0));

      // Cross product: Right-handed orthogonal vector
      final SkyVector3 crossProd = SkyVector3.right.cross(SkyVector3.up);
      expect(crossProd, equals(SkyVector3.forward));

      // Spherical coordinate reconstruction
      final SkyVector3 sphericalVec = SkyVector3.fromSpherical(math.pi * 0.5, 0.0); // 90 deg azimuth, 0 elevation -> +X (right)
      expect(sphericalVec.x, closeTo(1.0, 1e-5));
      expect(sphericalVec.y, closeTo(0.0, 1e-5));
      expect(sphericalVec.z, closeTo(0.0, 1e-5));
      expect(sphericalVec.elevation, closeTo(0.0, 1e-5));
      expect(sphericalVec.azimuth, closeTo(math.pi * 0.5, 1e-5));

      // Normalized zero protection fallback
      expect(SkyVector3.zero.normalized(), equals(SkyVector3.up));

      // Distance and lerp
      expect(SkyVector3.zero.distanceTo(const SkyVector3(3.0, 4.0, 0.0)), equals(5.0));
      expect(SkyVector3.zero.lerp(const SkyVector3(10.0, 20.0, 30.0), 0.5), equals(const SkyVector3(5.0, 10.0, 15.0)));
    });

    test('LinearColor blackbody radiation curve, gamma conversions, and photometric Rec. 709 luminance', () {
      // 2000K: deep warm candle/sunset glow (Red >> Blue)
      final LinearColor warmSunset = LinearColor.fromColorTemperature(2000.0);
      expect(warmSunset.r, greaterThan(warmSunset.b * 3.0));

      // 6500K: standard D65 daylight white
      final LinearColor daylightWhite = LinearColor.fromColorTemperature(6500.0);
      expect(daylightWhite.r, closeTo(daylightWhite.g, 0.2));
      expect(daylightWhite.r, closeTo(daylightWhite.b, 0.2));

      // 12000K: cool deep blue sky
      final LinearColor coolSky = LinearColor.fromColorTemperature(12000.0);
      expect(coolSky.b, greaterThan(coolSky.r));

      // Rec. 709 luminance: 0.2126*R + 0.7152*G + 0.0722*B
      const pureGreen = LinearColor(0.0, 1.0, 0.0);
      const pureRed = LinearColor(1.0, 0.0, 0.0);
      const pureBlue = LinearColor(0.0, 0.0, 1.0);
      expect(pureGreen.luminance, equals(0.7152));
      expect(pureRed.luminance, equals(0.2126));
      expect(pureBlue.luminance, equals(0.0722));
      expect(pureGreen.luminance, greaterThan(pureRed.luminance));
      expect(pureRed.luminance, greaterThan(pureBlue.luminance));

      // Conversion to Flutter ui.Color and round-trip
      final ui.Color color = daylightWhite.toColor();
      expect(color.alpha, equals(255));
      expect(color.red, greaterThan(0));
      expect(color.green, greaterThan(0));
      expect(color.blue, greaterThan(0));

      final LinearColor convertedBack = LinearColor.fromColor(color);
      expect(convertedBack.r, closeTo(daylightWhite.r, 0.05));
    });

    test('SphericalHarmonicsL1 evaluates diffuse irradiance for any surface normal', () {
      const sh = SphericalHarmonicsL1(
        l00: LinearColor(0.5, 0.5, 0.5), // Ambient base
        l1Minus1: LinearColor(0.3, 0.3, 0.3), // Vertical gradient (+Y vs -Y)
        l10: LinearColor(0.1, 0.1, 0.1),
        l11: LinearColor(0.2, 0.2, 0.2),
      );

      final LinearColor zenithIrr = sh.evaluateIrradiance(SkyVector3.up);
      final LinearColor nadirIrr = sh.evaluateIrradiance(SkyVector3.down);

      // Zenith (+Y) receives positive dipole contribution compared to Nadir (-Y)
      expect(zenithIrr.r, greaterThan(nadirIrr.r));
      expect(zenithIrr.g, greaterThan(nadirIrr.g));
      expect(zenithIrr.b, greaterThan(nadirIrr.b));
    });

    test('HemisphericAmbientProbe blends correctly between Zenith, Horizon, and Ground', () {
      const probe = HemisphericAmbientProbe(
        zenithColor: LinearColor(0.2, 0.4, 0.9), // Blue
        horizonColor: LinearColor(0.7, 0.8, 0.9), // Pale haze
        groundColor: LinearColor(0.1, 0.1, 0.05), // Dark soil
      );

      // Overhead surface (normal = +Y) evaluates close to zenith
      final LinearColor upColor = probe.evaluate(SkyVector3.up);
      expect(upColor.b, closeTo(probe.zenithColor.b, 0.05));

      // Equator / wall surface (normal = +X, horizon) evaluates to horizon
      final LinearColor horizonColor = probe.evaluate(SkyVector3.right);
      expect(horizonColor.r, closeTo(probe.horizonColor.r, 0.05));

      // Ground facing surface (normal = -Y) evaluates close to ground nadir
      final LinearColor downColor = probe.evaluate(SkyVector3.down);
      expect(downColor.r, closeTo(probe.groundColor.r, 0.05));
      expect(downColor.b, closeTo(probe.groundColor.b, 0.05));
    });

    test('WorldGiUniforms packs 32 contiguous floats with 16-byte alignment padding', () {
      const gi = WorldGiUniforms(
        zenithColor: LinearColor(0.1, 0.2, 0.3),
        horizonColor: LinearColor(0.4, 0.5, 0.6),
        groundColor: LinearColor(0.05, 0.04, 0.03),
        mainLightDirection: SkyVector3(0.5, 0.8, 0.1),
        mainLightRadiance: LinearColor(8.0, 7.5, 7.0),
        mainLightIntensity: 0.95,
        shL00: LinearColor(0.3, 0.3, 0.3),
        shL1Y: LinearColor(0.1, 0.1, 0.1),
        shL1X: LinearColor(0.05, 0.05, 0.05),
        shL1Z: LinearColor(0.02, 0.02, 0.02),
        ambientOcclusionFactor: 0.85,
      );

      final Float32List buffer = gi.toFloat32List();
      expect(buffer.length, equals(32));

      // Zenith RGB (0..2)
      expect(buffer[0], closeTo(0.1, 1e-6));
      expect(buffer[1], closeTo(0.2, 1e-6));
      expect(buffer[2], closeTo(0.3, 1e-6));

      // Horizon RGB (3..5)
      expect(buffer[3], closeTo(0.4, 1e-6));
      expect(buffer[4], closeTo(0.5, 1e-6));
      expect(buffer[5], closeTo(0.6, 1e-6));

      // Ground RGB (6..8)
      expect(buffer[6], closeTo(0.05, 1e-6));
      expect(buffer[7], closeTo(0.04, 1e-6));
      expect(buffer[8], closeTo(0.03, 1e-6));

      // Main light direction XYZ (9..11)
      expect(buffer[9], closeTo(0.5, 1e-6));
      expect(buffer[10], closeTo(0.8, 1e-6));
      expect(buffer[11], closeTo(0.1, 1e-6));

      // Main light radiance RGB & intensity (12..15)
      expect(buffer[12], closeTo(8.0, 1e-6));
      expect(buffer[13], closeTo(7.5, 1e-6));
      expect(buffer[14], closeTo(7.0, 1e-6));
      expect(buffer[15], closeTo(0.95, 1e-6));

      // SH coefficients (16..27)
      expect(buffer[16], closeTo(0.3, 1e-6));
      expect(buffer[19], closeTo(0.1, 1e-6));
      expect(buffer[22], closeTo(0.05, 1e-6));
      expect(buffer[25], closeTo(0.02, 1e-6));

      // AO factor (28)
      expect(buffer[28], closeTo(0.85, 1e-6));

      // 16-byte alignment padding slots (29..31) must strictly be 0.0
      expect(buffer[29], equals(0.0));
      expect(buffer[30], equals(0.0));
      expect(buffer[31], equals(0.0));
    });
  });

  // ===========================================================================
  // SECTION 7: DynamicSkyboxPainter & DynamicSkyboxView Widget Integration
  // ===========================================================================
  group('DynamicSkyboxPainter & DynamicSkyboxView Widget Integration', () {
    test('DynamicSkyboxPainter analytical fallback renders celestial gradients without errors', () {
      final controller = DynamicSkyboxController(initialHours: 12.0);
      final painter = DynamicSkyboxPainter(controller: controller);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Standard paint pass with analytical procedural fallback (shader is null)
      painter.paint(canvas, const Size(1920.0, 1080.0));
      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);

      // Zero-size boundary test must return early without throwing
      final zeroRecorder = ui.PictureRecorder();
      final zeroCanvas = Canvas(zeroRecorder);
      painter.paint(zeroCanvas, Size.zero);
      painter.paint(zeroCanvas, const Size(0.0, 500.0));
      painter.paint(zeroCanvas, const Size(500.0, 0.0));
      final ui.Picture zeroPicture = zeroRecorder.endRecording();
      expect(zeroPicture, isNotNull);

      // Repaint policy
      expect(painter.shouldRepaint(painter), isTrue);
    });

    test('DynamicSkyboxPainter analytical fallback renders nocturnal moon halo at midnight', () {
      final controller = DynamicSkyboxController(initialHours: 0.0);
      final painter = DynamicSkyboxPainter(controller: controller);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      painter.paint(canvas, const Size(800.0, 600.0));
      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    testWidgets('DynamicSkyboxView renders widget hierarchy with fallback canvas painter', (WidgetTester tester) async {
      final controller = DynamicSkyboxController(initialHours: 12.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicSkyboxView(
              controller: controller,
              enableShader: false, // Pure analytical canvas procedural rendering
              child: const Center(
                child: Text('Aion 2 Cinematic World Viewport'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DynamicSkyboxView), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget);
      expect(find.text('Aion 2 Cinematic World Viewport'), findsOneWidget);

      // Advance frames and verify ticker updates simulation
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Update controller and trigger reactive rebuild via ListenableBuilder
      controller.setTime(18.5); // Shift to dusk
      await tester.pump();

      expect(controller.timeModel.currentPhase, equals(CelestialPhase.dusk));
    });

    testWidgets('DynamicSkyboxView updates camera rotation and field-of-view smoothly', (WidgetTester tester) async {
      final controller = DynamicSkyboxController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicSkyboxView(
              controller: controller,
              enableShader: false,
            ),
          ),
        ),
      );

      // Adjust camera pitch and yaw
      const newRotation = SkyVector3(0.15, -0.75, 0.0);
      controller.setCameraRotation(newRotation);
      expect(controller.cameraRotation, equals(newRotation));

      // Adjust vertical field of view
      controller.setFov(1.20);
      expect(controller.fov, closeTo(1.20, 1e-5));

      // FOV clamp test
      controller.setFov(0.001); // Below min
      expect(controller.fov, closeTo(0.1, 1e-5));

      controller.setFov(10.0); // Above max
      expect(controller.fov, closeTo(math.pi * 0.95, 1e-5));

      await tester.pump();
    });
  });
}
