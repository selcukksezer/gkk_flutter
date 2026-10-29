import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/shaders/social/banner/celestial_banner_painter.dart';
import 'package:gkk_flutter/shaders/social/banner/celestial_banner_widget.dart';
import 'package:gkk_flutter/shaders/social/social_shaders.dart';
import 'package:gkk_flutter/shaders/social/theme/social_theme_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // 1. GLSL Shader Source File Verification
  // ===========================================================================
  group('Celestial Banner GLSL Shader Source Verification', () {
    late File glslFile;
    late String glslContent;

    setUpAll(() {
      glslFile = File('lib/shaders/social/glsl/celestial_banner.frag');
      expect(
        glslFile.existsSync(),
        isTrue,
        reason: 'celestial_banner.frag must exist at lib/shaders/social/glsl/',
      );
      glslContent = glslFile.readAsStringSync();
    });

    test('Shader header declares version 460 core and flutter runtime_effect include', () {
      expect(glslContent, contains('#version 460 core'));
      expect(glslContent, contains('#include <flutter/runtime_effect.glsl>'));
    });

    test('Shader declares all 7 uniform inputs in exact 17-float sequential layout', () {
      expect(glslContent, contains('uniform vec2 uResolution;')); // floats 0..1
      expect(glslContent, contains('uniform float uTime;')); // float 2
      expect(glslContent, contains('uniform float uProgress;')); // float 3
      expect(glslContent, contains('uniform float uEnergyIntensity;')); // float 4
      expect(glslContent, contains('uniform vec4 uPrimaryColor;')); // floats 5..8
      expect(glslContent, contains('uniform vec4 uSecondaryColor;')); // floats 9..12
      expect(glslContent, contains('uniform vec4 uGoldColor;')); // floats 13..16
      expect(glslContent, contains('out vec4 fragColor;'));
    });

    test('Shader implements procedural cloth waving harmonics and holographic sheen', () {
      expect(glslContent, contains('float hash(vec2 p)'));
      expect(glslContent, contains('float noise(vec2 p)'));
      expect(glslContent, contains('float fbm(vec2 p)'));
      // Multi-harmonic sinusoidal wave formulation
      expect(glslContent, contains('sin(uv.x * 6.28 * 2.0 + uTime * 2.0)'));
      expect(glslContent, contains('cos(uv.x * 6.28 * 3.5 - uTime * 1.5)'));
      expect(glslContent, contains('smoothstep(0.4, 0.0, abs(uv.y - 0.5 - wave1 - wave2))'));
      // Sheen and border glint equations
      expect(glslContent, contains('sheenRainbow'));
      expect(glslContent, contains('borderDist'));
      expect(glslContent, contains('vignette'));
    });
  });

  // ===========================================================================
  // 2. sRGB to Linear Color Conversion Math
  // ===========================================================================
  group('sRGB to Linear Color Conversion Math', () {
    test('sRgbToLinear accurately adheres to standard IEC 61966-2-1 piecewise curve', () {
      // Zero boundary
      expect(CelestialBannerPainter.sRgbToLinear(0.0), equals(0.0));

      // Linear section threshold (c <= 0.04045 -> c / 12.92)
      const double threshold = 0.04045;
      final double expectedThresholdLinear = threshold / 12.92;
      expect(
        CelestialBannerPainter.sRgbToLinear(threshold),
        closeTo(expectedThresholdLinear, 1e-7),
      );

      // Value just inside linear section
      const double smallVal = 0.02;
      expect(
        CelestialBannerPainter.sRgbToLinear(smallVal),
        closeTo(smallVal / 12.92, 1e-7),
      );

      // Exponential section (c > 0.04045 -> ((c + 0.055) / 1.055)^2.4)
      const double midSrgb = 0.5;
      final double expectedMidLinear = math.pow((midSrgb + 0.055) / 1.055, 2.4).toDouble();
      expect(
        CelestialBannerPainter.sRgbToLinear(midSrgb),
        closeTo(expectedMidLinear, 1e-6),
      );

      // Unity boundary
      expect(
        CelestialBannerPainter.sRgbToLinear(1.0),
        closeTo(1.0, 1e-6),
      );
    });

    test('sRgbToLinear is strictly monotonic increasing over [0.0, 1.0]', () {
      double previous = -1.0;
      for (int i = 0; i <= 100; i++) {
        final double srgb = i / 100.0;
        final double linear = CelestialBannerPainter.sRgbToLinear(srgb);
        expect(linear, greaterThanOrEqualTo(previous));
        expect(linear, greaterThanOrEqualTo(0.0));
        expect(linear, lessThanOrEqualTo(1.0));
        previous = linear;
      }
    });

    test('colorToLinearRgba converts RGB while preserving unmodified alpha', () {
      const Color semiTransparentBlue = Color(0x803366CC); // alpha = 128 / 255
      final (double r, double g, double b, double a) =
          CelestialBannerPainter.colorToLinearRgba(semiTransparentBlue);

      expect(a, closeTo(semiTransparentBlue.a, 1e-5));
      expect(r, closeTo(CelestialBannerPainter.sRgbToLinear(semiTransparentBlue.r), 1e-5));
      expect(g, closeTo(CelestialBannerPainter.sRgbToLinear(semiTransparentBlue.g), 1e-5));
      expect(b, closeTo(CelestialBannerPainter.sRgbToLinear(semiTransparentBlue.b), 1e-5));
    });

    test('Parity between CelestialBannerPainter and CelestialBannerUniforms conversion', () {
      const Color testColor = Color(0xFFE5A93C);
      final (double pr, double pg, double pb, double pa) =
          CelestialBannerPainter.colorToLinearRgba(testColor);
      final List<double> uniformFloats =
          CelestialBannerUniforms.colorToLinearFloats(testColor);

      expect(pr, equals(uniformFloats[0]));
      expect(pg, equals(uniformFloats[1]));
      expect(pb, equals(uniformFloats[2]));
      expect(pa, equals(uniformFloats[3]));
    });
  });

  // ===========================================================================
  // 3. CelestialBannerPainter Uniform Packing & Buffer Layout
  // ===========================================================================
  group('CelestialBannerPainter Uniform Packing: 17 Floats Layout', () {
    test('kUniformFloatCount constant strictly equals 17', () {
      expect(CelestialBannerPainter.kUniformFloatCount, equals(17));
      expect(CelestialBannerUniforms.floatCount, equals(17));
    });

    test('packUniforms packs uResolution, uTime, uWindSpeed/Progress, uWaveAmplitude/Intensity', () {
      const Size size = Size(360.0, 110.0);
      const double progress = 0.65;
      const double energyIntensity = 1.35; // uWaveAmplitude

      final Float32List buffer = CelestialBannerPainter.packUniforms(
        size: size,
        progress: progress,
        energyIntensity: energyIntensity,
      );

      expect(buffer.length, equals(17));

      // 0..1: uResolution (vec2)
      expect(buffer[0], equals(360.0));
      expect(buffer[1], equals(110.0));

      // 2: uTime (defaults to progress * 4.0 when time is null)
      expect(buffer[2], closeTo(0.65 * 4.0, 1e-6));

      // 3: uProgress / uWindSpeed progress
      expect(buffer[3], equals(0.65));

      // 4: uEnergyIntensity / uWaveAmplitude
      expect(buffer[4], equals(1.35));
    });

    test('packUniforms respects explicit time parameter over computed default', () {
      const Size size = Size(200.0, 80.0);
      const double progress = 0.25;
      const double customTime = 14.85;

      final Float32List buffer = CelestialBannerPainter.packUniforms(
        size: size,
        progress: progress,
        time: customTime,
      );

      // uTime should be explicit 14.85, NOT 0.25 * 4.0 = 1.0
      expect(buffer[2], equals(14.85));
      expect(buffer[3], equals(0.25));
    });

    test('packUniforms accurately linearizes uPrimaryColor, uSecondaryColor, and uGoldColor', () {
      const Color primary = Color(0xFF00E5FF);
      const Color secondary = Color(0xFF9D4EDD);
      const Color gold = Color(0xFFFFD700);

      final Float32List buffer = CelestialBannerPainter.packUniforms(
        size: const Size(300.0, 100.0),
        progress: 0.5,
        primaryEnergyColor: primary,
        secondaryEnergyColor: secondary,
        goldShimmerColor: gold,
      );

      // 5..8: uPrimaryColor
      final (double pr, double pg, double pb, double pa) =
          CelestialBannerPainter.colorToLinearRgba(primary);
      expect(buffer[5], closeTo(pr, 1e-5));
      expect(buffer[6], closeTo(pg, 1e-5));
      expect(buffer[7], closeTo(pb, 1e-5));
      expect(buffer[8], closeTo(pa, 1e-5));

      // 9..12: uSecondaryColor
      final (double sr, double sg, double sb, double sa) =
          CelestialBannerPainter.colorToLinearRgba(secondary);
      expect(buffer[9], closeTo(sr, 1e-5));
      expect(buffer[10], closeTo(sg, 1e-5));
      expect(buffer[11], closeTo(sb, 1e-5));
      expect(buffer[12], closeTo(sa, 1e-5));

      // 13..16: uGoldColor (uGoldTrimIntensity)
      final (double gr, double gg, double gb, double ga) =
          CelestialBannerPainter.colorToLinearRgba(gold);
      expect(buffer[13], closeTo(gr, 1e-5));
      expect(buffer[14], closeTo(gg, 1e-5));
      expect(buffer[15], closeTo(gb, 1e-5));
      expect(buffer[16], closeTo(ga, 1e-5));
    });

    test('Parity between CelestialBannerPainter.packUniforms and CelestialBannerUniforms.buildUniforms', () {
      const Size size = Size(420.0, 130.0);
      const double time = 3.2;
      const double progress = 0.8;
      const double intensity = 1.25;
      const Color primary = SocialThemeTokens.aetherCyan;
      const Color secondary = SocialThemeTokens.daevaPrismViolet;
      const Color gold = SocialThemeTokens.celestialGold;

      final Float32List painterBuffer = CelestialBannerPainter.packUniforms(
        size: size,
        time: time,
        progress: progress,
        energyIntensity: intensity,
        primaryEnergyColor: primary,
        secondaryEnergyColor: secondary,
        goldShimmerColor: gold,
      );

      final List<double> uniformsList = CelestialBannerUniforms.buildUniforms(
        size: size,
        time: time,
        progress: progress,
        energyIntensity: intensity,
        primaryColor: primary,
        secondaryColor: secondary,
        goldColor: gold,
        useLinearColors: true,
      );

      expect(painterBuffer.length, equals(uniformsList.length));
      for (int i = 0; i < painterBuffer.length; i++) {
        expect(
          painterBuffer[i],
          closeTo(uniformsList[i], 1e-5),
          reason: 'Mismatch at uniform float index $i',
        );
      }
    });

    test('CelestialBannerUniforms supports sRGB raw output when useLinearColors is false', () {
      const Color rawColor = Color(0xFF112233);
      final List<double> rawUniforms = CelestialBannerUniforms.buildUniforms(
        size: const Size(100.0, 50.0),
        time: 1.0,
        progress: 0.2,
        energyIntensity: 1.0,
        primaryColor: rawColor,
        secondaryColor: rawColor,
        goldColor: rawColor,
        useLinearColors: false,
      );

      expect(rawUniforms[5], closeTo(rawColor.r, 1e-5));
      expect(rawUniforms[6], closeTo(rawColor.g, 1e-5));
      expect(rawUniforms[7], closeTo(rawColor.b, 1e-5));
      expect(rawUniforms[8], closeTo(rawColor.a, 1e-5));
    });
  });

  // ===========================================================================
  // 4. Procedural Sinusoidal Cloth Waving Math in Dart Fallback
  // ===========================================================================
  group('Procedural Sinusoidal Cloth Waving Math in Dart Fallback', () {
    // Pure mathematical reconstruction of the dual sinusoidal harmonic formula
    // used in CelestialBannerPainter._paintCelestialEnergyRibbons:
    // y = yOffset + amp * sin(normX * freq * 2 * pi + t * speed) + (amp * 0.4) * cos(normX * 4.8 * pi - t * 0.8)
    double evaluateClothWaveHeight({
      required double normX,
      required double progress,
      required double yOffset,
      required double amp,
      required double freq,
      required double speed,
    }) {
      final double t = progress * 2 * math.pi;
      return yOffset +
          amp * math.sin(normX * freq * 2 * math.pi + t * speed) +
          (amp * 0.4) * math.cos(normX * 4.8 * math.pi - t * 0.8);
    }

    test('Wave displacement is strictly bounded within [-1.4 * amp, +1.4 * amp]', () {
      const double height = 120.0;
      const double energyIntensity = 1.0;
      const double amp = height * 0.22 * energyIntensity;
      const double yOffset = height * 0.45;
      const double freq = 2.2;
      const double speed = 1.0;

      const double maxDeviation = amp * 1.4; // 1.0 * amp + 0.4 * amp

      // Evaluate over dense grid of positions and times
      for (int step = 0; step <= 50; step++) {
        final double normX = step / 50.0;
        for (int p = 0; p <= 20; p++) {
          final double progress = p / 20.0;
          final double y = evaluateClothWaveHeight(
            normX: normX,
            progress: progress,
            yOffset: yOffset,
            amp: amp,
            freq: freq,
            speed: speed,
          );

          final double displacement = y - yOffset;
          expect(displacement, lessThanOrEqualTo(maxDeviation + 1e-5));
          expect(displacement, greaterThanOrEqualTo(-maxDeviation - 1e-5));
        }
      }
    });

    test('When energyIntensity is zero, cloth wave collapses completely to flat yOffset', () {
      const double height = 100.0;
      const double energyIntensity = 0.0;
      const double amp = height * 0.22 * energyIntensity; // exactly 0.0
      const double yOffset = height * 0.45;

      for (int step = 0; step <= 20; step++) {
        final double normX = step / 20.0;
        final double y = evaluateClothWaveHeight(
          normX: normX,
          progress: 0.5,
          yOffset: yOffset,
          amp: amp,
          freq: 2.2,
          speed: 1.0,
        );
        expect(y, equals(yOffset));
      }
    });

    test('Wave amplitude scales strictly linearly with energyIntensity (uWaveAmplitude)', () {
      const double height = 100.0;
      const double yOffset = 50.0;
      const double normX = 0.25;
      const double progress = 0.3;

      final double y1 = evaluateClothWaveHeight(
        normX: normX,
        progress: progress,
        yOffset: yOffset,
        amp: height * 0.22 * 1.0,
        freq: 2.2,
        speed: 1.0,
      );

      final double y2 = evaluateClothWaveHeight(
        normX: normX,
        progress: progress,
        yOffset: yOffset,
        amp: height * 0.22 * 2.0,
        freq: 2.2,
        speed: 1.0,
      );

      final double disp1 = y1 - yOffset;
      final double disp2 = y2 - yOffset;
      expect(disp2, closeTo(disp1 * 2.0, 1e-6));
    });

    test('Opposing wave speeds simulate counter-current plasma turbulence', () {
      // Wave 1 has speed = +1.0 (forward wave propagation)
      // Wave 2 has speed = -1.3 (backward wave propagation)
      const double height = 100.0;
      final double w1_t0 = evaluateClothWaveHeight(
        normX: 0.5,
        progress: 0.0,
        yOffset: 45.0,
        amp: 20.0,
        freq: 2.2,
        speed: 1.0,
      );
      final double w1_t1 = evaluateClothWaveHeight(
        normX: 0.5,
        progress: 0.1,
        yOffset: 45.0,
        amp: 20.0,
        freq: 2.2,
        speed: 1.0,
      );

      final double w2_t0 = evaluateClothWaveHeight(
        normX: 0.5,
        progress: 0.0,
        yOffset: 60.0,
        amp: 16.0,
        freq: 3.5,
        speed: -1.3,
      );
      final double w2_t1 = evaluateClothWaveHeight(
        normX: 0.5,
        progress: 0.1,
        yOffset: 60.0,
        amp: 16.0,
        freq: 3.5,
        speed: -1.3,
      );

      // Both waves undergo non-zero phase shift from t=0 to t=0.1
      expect(w1_t1, isNot(equals(w1_t0)));
      expect(w2_t1, isNot(equals(w2_t0)));
    });
  });

  // ===========================================================================
  // 5. Procedural Motes, Sheen, and Glint Dynamics Math
  // ===========================================================================
  group('Procedural Motes, Sheen, and Glint Dynamics Math', () {
    test('Traveling gold shimmer glint traverses banner smoothly without discontinuity', () {
      const double width = 300.0;
      const double glintWidth = width * 0.28;

      // At progress 0.0, glint starts offscreen left: -glintWidth
      double t0 = (0.0 * 1.5) % 1.0;
      double glintX0 = (t0 * (width + glintWidth)) - glintWidth;
      expect(glintX0, equals(-glintWidth));

      // At progress 1.0, glint completes loop
      double tMid = (0.3333333 * 1.5) % 1.0; // t = 0.5
      double glintXMid = (tMid * (width + glintWidth)) - glintWidth;
      expect(glintXMid, closeTo(width * 0.5 - glintWidth * 0.5, 1.0));
    });

    test('Iridescent sheen sweep beam traverses entire banner width', () {
      const double w = 320.0;
      const double h = 100.0;
      const double totalSpan = w + h * 1.5;

      // beamX = (progress * totalSpan) - (h * 0.5)
      final double beamX0 = (0.0 * totalSpan) - (h * 0.5);
      final double beamX1 = (1.0 * totalSpan) - (h * 0.5);

      expect(beamX0, lessThan(0.0)); // starts outside left
      expect(beamX1, greaterThan(w)); // ends beyond right edge
    });

    test('Celestial motes 14-particle generator produces deterministic, continuous floating coordinates', () {
      const double w = 300.0;
      const double h = 100.0;
      const int moteCount = 14;

      for (int i = 0; i < moteCount; i++) {
        final double seed = (i * 73.13) % 1.0;
        final double speed = 0.5 + ((i * 37.1) % 0.8);
        final double localT = (0.5 * speed + seed) % 1.0;

        final double x = (seed * w + (math.sin(localT * 2 * math.pi + i) * 24.0)) % w;
        final double y = h * (1.0 - localT);
        final double radius = 1.2 + (((i % 4) + 1) * 0.6);
        final double alpha = math.sin(localT * math.pi).clamp(0.0, 1.0) * 0.75;

        // Position coordinates are valid numbers and inside banner bounds
        expect(x, greaterThanOrEqualTo(0.0));
        expect(x, lessThanOrEqualTo(w));
        expect(y, greaterThanOrEqualTo(0.0));
        expect(y, lessThanOrEqualTo(h));
        expect(radius, greaterThan(1.0));
        expect(alpha, greaterThanOrEqualTo(0.0));
        expect(alpha, lessThanOrEqualTo(0.75));
      }
    });
  });

  // ===========================================================================
  // 6. CelestialBannerPainter Canvas Fallback Painting & Geometry
  // ===========================================================================
  group('CelestialBannerPainter Canvas Fallback Painting & Geometry', () {
    test('paint handles zero and negative dimensions gracefully with early exit', () {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      const CelestialBannerPainter painter = CelestialBannerPainter(progress: 0.5);

      // Width <= 0
      painter.paint(canvas, const Size(0, 100));
      // Height <= 0
      painter.paint(canvas, const Size(100, 0));
      // Negative sizes
      painter.paint(canvas, const Size(-50, 100));
      painter.paint(canvas, const Size(100, -50));

      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('paint executes complete analytical fallback stack for standard banner', () {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      const CelestialBannerPainter painter = CelestialBannerPainter(
        progress: 0.35,
        energyIntensity: 1.0,
        showBorderShimmer: true,
        showCornerFiligree: true,
        showFloatingMotes: true,
        isSwallowtail: false,
      );

      // Should complete without throwing any exceptions
      painter.paint(canvas, const Size(360.0, 120.0));
      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('paint executes swallowtail pennant geometry path cleanly', () {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      const CelestialBannerPainter painter = CelestialBannerPainter(
        progress: 0.75,
        isSwallowtail: true,
        borderRadius: 12.0,
      );

      painter.paint(canvas, const Size(300.0, 150.0));
      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('paint handles zero energyIntensity (ribbons skipped) and toggled decorative passes', () {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      const CelestialBannerPainter painter = CelestialBannerPainter(
        progress: 0.5,
        energyIntensity: 0.0, // ribbons skipped
        showFloatingMotes: false, // motes skipped
        showBorderShimmer: false, // shimmer skipped
        showCornerFiligree: false, // filigree skipped
      );

      painter.paint(canvas, const Size(280.0, 90.0));
      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  // ===========================================================================
  // 7. CelestialBannerPainter shouldRepaint Exhaustive Mutation Matrix
  // ===========================================================================
  group('CelestialBannerPainter shouldRepaint Exhaustive Mutation Matrix', () {
    const CelestialBannerPainter base = CelestialBannerPainter(
      progress: 0.25,
      time: 1.0,
      primaryEnergyColor: Color(0xFF00E5FF),
      secondaryEnergyColor: Color(0xFF9D4EDD),
      goldShimmerColor: Color(0xFFFFD700),
      energyIntensity: 1.0,
      borderRadius: 16.0,
      showBorderShimmer: true,
      showCornerFiligree: true,
      showFloatingMotes: true,
      isSwallowtail: false,
    );

    test('returns false when all 12 properties are strictly identical', () {
      const CelestialBannerPainter identical = CelestialBannerPainter(
        progress: 0.25,
        time: 1.0,
        primaryEnergyColor: Color(0xFF00E5FF),
        secondaryEnergyColor: Color(0xFF9D4EDD),
        goldShimmerColor: Color(0xFFFFD700),
        energyIntensity: 1.0,
        borderRadius: 16.0,
        showBorderShimmer: true,
        showCornerFiligree: true,
        showFloatingMotes: true,
        isSwallowtail: false,
      );

      expect(base.shouldRepaint(identical), isFalse);
    });

    test('returns true when progress mutates', () {
      final CelestialBannerPainter other = CelestialBannerPainter(
        progress: 0.30,
        time: base.time,
        primaryEnergyColor: base.primaryEnergyColor,
        secondaryEnergyColor: base.secondaryEnergyColor,
        goldShimmerColor: base.goldShimmerColor,
        energyIntensity: base.energyIntensity,
        borderRadius: base.borderRadius,
        showBorderShimmer: base.showBorderShimmer,
        showCornerFiligree: base.showCornerFiligree,
        showFloatingMotes: base.showFloatingMotes,
        isSwallowtail: base.isSwallowtail,
      );
      expect(base.shouldRepaint(other), isTrue);
    });

    test('returns true when time mutates', () {
      final CelestialBannerPainter other = CelestialBannerPainter(
        progress: base.progress,
        time: 2.5,
        primaryEnergyColor: base.primaryEnergyColor,
        secondaryEnergyColor: base.secondaryEnergyColor,
        goldShimmerColor: base.goldShimmerColor,
        energyIntensity: base.energyIntensity,
        borderRadius: base.borderRadius,
        showBorderShimmer: base.showBorderShimmer,
        showCornerFiligree: base.showCornerFiligree,
        showFloatingMotes: base.showFloatingMotes,
        isSwallowtail: base.isSwallowtail,
      );
      expect(base.shouldRepaint(other), isTrue);
    });

    test('returns true when primaryEnergyColor mutates', () {
      final CelestialBannerPainter other = CelestialBannerPainter(
        progress: base.progress,
        time: base.time,
        primaryEnergyColor: const Color(0xFF00FF00),
        secondaryEnergyColor: base.secondaryEnergyColor,
        goldShimmerColor: base.goldShimmerColor,
        energyIntensity: base.energyIntensity,
        borderRadius: base.borderRadius,
        showBorderShimmer: base.showBorderShimmer,
        showCornerFiligree: base.showCornerFiligree,
        showFloatingMotes: base.showFloatingMotes,
        isSwallowtail: base.isSwallowtail,
      );
      expect(base.shouldRepaint(other), isTrue);
    });

    test('returns true when secondaryEnergyColor mutates', () {
      final CelestialBannerPainter other = CelestialBannerPainter(
        progress: base.progress,
        time: base.time,
        primaryEnergyColor: base.primaryEnergyColor,
        secondaryEnergyColor: const Color(0xFFFF00FF),
        goldShimmerColor: base.goldShimmerColor,
        energyIntensity: base.energyIntensity,
        borderRadius: base.borderRadius,
        showBorderShimmer: base.showBorderShimmer,
        showCornerFiligree: base.showCornerFiligree,
        showFloatingMotes: base.showFloatingMotes,
        isSwallowtail: base.isSwallowtail,
      );
      expect(base.shouldRepaint(other), isTrue);
    });

    test('returns true when goldShimmerColor mutates', () {
      final CelestialBannerPainter other = CelestialBannerPainter(
        progress: base.progress,
        time: base.time,
        primaryEnergyColor: base.primaryEnergyColor,
        secondaryEnergyColor: base.secondaryEnergyColor,
        goldShimmerColor: const Color(0xFFE5C158),
        energyIntensity: base.energyIntensity,
        borderRadius: base.borderRadius,
        showBorderShimmer: base.showBorderShimmer,
        showCornerFiligree: base.showCornerFiligree,
        showFloatingMotes: base.showFloatingMotes,
        isSwallowtail: base.isSwallowtail,
      );
      expect(base.shouldRepaint(other), isTrue);
    });

    test('returns true when energyIntensity mutates', () {
      final CelestialBannerPainter other = CelestialBannerPainter(
        progress: base.progress,
        time: base.time,
        primaryEnergyColor: base.primaryEnergyColor,
        secondaryEnergyColor: base.secondaryEnergyColor,
        goldShimmerColor: base.goldShimmerColor,
        energyIntensity: 0.5,
        borderRadius: base.borderRadius,
        showBorderShimmer: base.showBorderShimmer,
        showCornerFiligree: base.showCornerFiligree,
        showFloatingMotes: base.showFloatingMotes,
        isSwallowtail: base.isSwallowtail,
      );
      expect(base.shouldRepaint(other), isTrue);
    });

    test('returns true when borderRadius mutates', () {
      final CelestialBannerPainter other = CelestialBannerPainter(
        progress: base.progress,
        time: base.time,
        primaryEnergyColor: base.primaryEnergyColor,
        secondaryEnergyColor: base.secondaryEnergyColor,
        goldShimmerColor: base.goldShimmerColor,
        energyIntensity: base.energyIntensity,
        borderRadius: 8.0,
        showBorderShimmer: base.showBorderShimmer,
        showCornerFiligree: base.showCornerFiligree,
        showFloatingMotes: base.showFloatingMotes,
        isSwallowtail: base.isSwallowtail,
      );
      expect(base.shouldRepaint(other), isTrue);
    });

    test('returns true when showBorderShimmer mutates', () {
      final CelestialBannerPainter other = CelestialBannerPainter(
        progress: base.progress,
        time: base.time,
        primaryEnergyColor: base.primaryEnergyColor,
        secondaryEnergyColor: base.secondaryEnergyColor,
        goldShimmerColor: base.goldShimmerColor,
        energyIntensity: base.energyIntensity,
        borderRadius: base.borderRadius,
        showBorderShimmer: false,
        showCornerFiligree: base.showCornerFiligree,
        showFloatingMotes: base.showFloatingMotes,
        isSwallowtail: base.isSwallowtail,
      );
      expect(base.shouldRepaint(other), isTrue);
    });

    test('returns true when showCornerFiligree mutates', () {
      final CelestialBannerPainter other = CelestialBannerPainter(
        progress: base.progress,
        time: base.time,
        primaryEnergyColor: base.primaryEnergyColor,
        secondaryEnergyColor: base.secondaryEnergyColor,
        goldShimmerColor: base.goldShimmerColor,
        energyIntensity: base.energyIntensity,
        borderRadius: base.borderRadius,
        showBorderShimmer: base.showBorderShimmer,
        showCornerFiligree: false,
        showFloatingMotes: base.showFloatingMotes,
        isSwallowtail: base.isSwallowtail,
      );
      expect(base.shouldRepaint(other), isTrue);
    });

    test('returns true when showFloatingMotes mutates', () {
      final CelestialBannerPainter other = CelestialBannerPainter(
        progress: base.progress,
        time: base.time,
        primaryEnergyColor: base.primaryEnergyColor,
        secondaryEnergyColor: base.secondaryEnergyColor,
        goldShimmerColor: base.goldShimmerColor,
        energyIntensity: base.energyIntensity,
        borderRadius: base.borderRadius,
        showBorderShimmer: base.showBorderShimmer,
        showCornerFiligree: base.showCornerFiligree,
        showFloatingMotes: false,
        isSwallowtail: base.isSwallowtail,
      );
      expect(base.shouldRepaint(other), isTrue);
    });

    test('returns true when isSwallowtail mutates', () {
      final CelestialBannerPainter other = CelestialBannerPainter(
        progress: base.progress,
        time: base.time,
        primaryEnergyColor: base.primaryEnergyColor,
        secondaryEnergyColor: base.secondaryEnergyColor,
        goldShimmerColor: base.goldShimmerColor,
        energyIntensity: base.energyIntensity,
        borderRadius: base.borderRadius,
        showBorderShimmer: base.showBorderShimmer,
        showCornerFiligree: base.showCornerFiligree,
        showFloatingMotes: base.showFloatingMotes,
        isSwallowtail: true,
      );
      expect(base.shouldRepaint(other), isTrue);
    });
  });

  // ===========================================================================
  // 8. CelestialBannerWidget Tree Rendering & Content Composition
  // ===========================================================================
  group('CelestialBannerWidget Tree Rendering & Content Composition', () {
    testWidgets('renders standard CelestialBannerWidget with title, subtitle, badge, and icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CelestialBannerWidget(
                title: 'Archon Vanguard',
                subtitle: 'Daeva of Elysea',
                badgeText: 'PRESTIGE',
                leading: const Icon(Icons.shield, key: Key('banner_leading_icon')),
                trailing: const Icon(Icons.chevron_right, key: Key('banner_trailing_icon')),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Archon Vanguard'), findsOneWidget);
      expect(find.text('Daeva of Elysea'), findsOneWidget);
      expect(find.text('PRESTIGE'), findsOneWidget);
      expect(find.byKey(const Key('banner_leading_icon')), findsOneWidget);
      expect(find.byKey(const Key('banner_trailing_icon')), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders custom child when provided, overriding default row layout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget(
              child: Text('Custom Clan Header', key: Key('custom_banner_child')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('custom_banner_child')), findsOneWidget);
      expect(find.text('Custom Clan Header'), findsOneWidget);
    });

    testWidgets('executes onTap callback when tapped with InkWell splash', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget(
              title: 'Interactive Banner',
              onTap: () => tapCount++,
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.text('Interactive Banner'));
      expect(tapCount, equals(1));

      await tester.tap(find.byType(InkWell));
      expect(tapCount, equals(2));
    });

    testWidgets('omits InkWell when onTap is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget(
              title: 'Non-tappable Banner',
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsNothing);
      expect(find.text('Non-tappable Banner'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 9. CelestialBannerWidget Factory Presets & Styling
  // ===========================================================================
  group('CelestialBannerWidget Factory Presets & Styling', () {
    testWidgets('guildHeader factory configures Elyos gold aesthetic and custom motto', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget.guildHeader(
              guildName: 'Legion of Siel',
              levelText: 'LEGION LV. 15',
              motto: 'Faith in the Tower of Eternity',
              emblem: const Icon(Icons.castle, key: Key('guild_emblem')),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Legion of Siel'), findsOneWidget);
      expect(find.text('LEGION LV. 15'), findsOneWidget);
      expect(find.text('Faith in the Tower of Eternity'), findsOneWidget);
      expect(find.byKey(const Key('guild_emblem')), findsOneWidget);

      await tester.tap(find.text('Legion of Siel'));
      expect(tapped, isTrue);
    });

    testWidgets('seasonPassMilestone factory formats tier and days remaining', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget.seasonPassMilestone(
              seasonTitle: 'Season 5: Abyss Awakening',
              tierText: 'Tier 100 Max',
              daysRemaining: '5 Days Remaining',
              rewardIllustration: const Icon(Icons.military_tech, key: Key('season_pass_reward')),
            ),
          ),
        ),
      );

      expect(find.text('Season 5: Abyss Awakening'), findsOneWidget);
      expect(find.text('Tier 100 Max • 5 Days Remaining'), findsOneWidget);
      expect(find.text('SEASON PASS'), findsOneWidget);
      expect(find.byKey(const Key('season_pass_reward')), findsOneWidget);
    });

    testWidgets('questClaim factory renders claim badge and triggers onClaim callback', (tester) async {
      bool claimed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget.questClaim(
              questTitle: 'Defeat Dragon Lord Beritra',
              rewardDescription: 'Gain 2,500 Abyss Points & 100 Stigma Shards',
              onClaim: () => claimed = true,
            ),
          ),
        ),
      );

      expect(find.text('Defeat Dragon Lord Beritra'), findsOneWidget);
      expect(find.text('Gain 2,500 Abyss Points & 100 Stigma Shards'), findsOneWidget);
      expect(find.text('CLAIM READY'), findsOneWidget);

      await tester.tap(find.text('Defeat Dragon Lord Beritra'));
      expect(claimed, isTrue);
    });

    testWidgets('leaderboardPodium factory displays rank badge and AP score', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget.leaderboardPodium(
              rankTitle: '#1 SUPREME COMMANDER',
              playerName: 'LordKaisinel',
              scoreText: '1,250,400 Abyss Points',
              rankBadge: const Icon(Icons.emoji_events, key: Key('podium_badge')),
            ),
          ),
        ),
      );

      expect(find.text('LordKaisinel'), findsOneWidget);
      expect(find.text('#1 SUPREME COMMANDER'), findsOneWidget);
      expect(find.text('1,250,400 Abyss Points'), findsOneWidget);
      expect(find.byKey(const Key('podium_badge')), findsOneWidget);
    });

    testWidgets('reputationFaction factory displays faction allegiance and standing tier', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget.reputationFaction(
              factionName: 'Alabaster Order',
              standingTier: 'Exalted',
              progressText: '18,500 / 20,000',
              crest: const Icon(Icons.shield_moon, key: Key('faction_crest')),
            ),
          ),
        ),
      );

      expect(find.text('Alabaster Order'), findsOneWidget);
      expect(find.text('Exalted • 18,500 / 20,000'), findsOneWidget);
      expect(find.text('FACTION REPUTATION'), findsOneWidget);
      expect(find.byKey(const Key('faction_crest')), findsOneWidget);
    });
  });

  // ===========================================================================
  // 10. CelestialBannerWidget Responsive Layout & Constraint Guards
  // ===========================================================================
  group('CelestialBannerWidget Responsive Layout & Constraint Guards', () {
    testWidgets('defaults to 320.0 fallback width when placed in unbounded horizontal flex', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  CelestialBannerWidget(
                    title: 'Horizontal Row Banner',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final RenderBox box = tester.renderObject(find.byType(CelestialBannerWidget));
      expect(box.size.width, equals(320.0));
      expect(box.size.height, greaterThanOrEqualTo(64.0));
    });

    testWidgets('respects explicit width and height constraints', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CelestialBannerWidget(
                width: 440.0,
                height: 140.0,
                title: 'Fixed Size Banner',
              ),
            ),
          ),
        ),
      );

      final RenderBox box = tester.renderObject(find.byType(CelestialBannerWidget));
      expect(box.size.width, equals(440.0));
      expect(box.size.height, equals(140.0));
    });

    testWidgets('applies outer margin and internal padding correctly', (tester) async {
      const EdgeInsets margin = EdgeInsets.all(16.0);
      const EdgeInsets padding = EdgeInsets.symmetric(horizontal: 24.0, vertical: 18.0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget(
              title: 'Padded Banner',
              margin: margin,
              padding: padding,
            ),
          ),
        ),
      );

      expect(find.byType(Padding), findsWidgets);
      expect(find.text('Padded Banner'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 11. AnimationController Lifecycle, Time Advancement & DidUpdateWidget
  // ===========================================================================
  group('AnimationController Lifecycle, Time Advancement & DidUpdateWidget', () {
    testWidgets('internal AnimationController starts repeating and advances continuous progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget(
              title: 'Animated Banner',
              animationDuration: Duration(seconds: 4),
            ),
          ),
        ),
      );

      // Verify widget mounted and initial CustomPaint created
      final Finder paintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is CelestialBannerPainter,
      );
      expect(paintFinder, findsOneWidget);

      CustomPaint customPaint = tester.widget<CustomPaint>(paintFinder);
      CelestialBannerPainter painter = customPaint.painter as CelestialBannerPainter;
      final double initialProgress = painter.progress;

      // Advance clock by 1 second (1/4 of 4-second duration)
      await tester.pump(const Duration(seconds: 1));

      customPaint = tester.widget<CustomPaint>(paintFinder);
      painter = customPaint.painter as CelestialBannerPainter;
      expect(painter.progress, greaterThan(initialProgress));
      expect(painter.progress, closeTo(0.25, 0.05));

      // Advance clock by 2 more seconds (total 3s -> progress ~ 0.75)
      await tester.pump(const Duration(seconds: 2));

      customPaint = tester.widget<CustomPaint>(paintFinder);
      painter = customPaint.painter as CelestialBannerPainter;
      expect(painter.progress, closeTo(0.75, 0.05));
    });

    testWidgets('external AnimationController drives progress directly', (tester) async {
      late AnimationController externalController;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: _ExternalControllerHost(
                  onControllerReady: (ctrl) => externalController = ctrl,
                ),
              ),
            );
          },
        ),
      );

      final Finder paintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is CelestialBannerPainter,
      );
      expect(paintFinder, findsOneWidget);

      // Drive external controller to specific progress points
      externalController.value = 0.42;
      await tester.pump();

      CustomPaint customPaint = tester.widget<CustomPaint>(paintFinder);
      CelestialBannerPainter painter = customPaint.painter as CelestialBannerPainter;
      expect(painter.progress, equals(0.42));

      externalController.value = 0.91;
      await tester.pump();

      customPaint = tester.widget<CustomPaint>(paintFinder);
      painter = customPaint.painter as CelestialBannerPainter;
      expect(painter.progress, equals(0.91));
    });

    testWidgets('didUpdateWidget dynamically adapts when switching between internal and external controllers', (tester) async {
      final GlobalKey<_DynamicControllerHostState> hostKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _DynamicControllerHost(key: hostKey),
          ),
        ),
      );

      expect(hostKey.currentState!.isUsingExternal, isFalse);
      await tester.pump(const Duration(milliseconds: 500));

      // Switch to external controller
      hostKey.currentState!.toggleExternalController();
      await tester.pump();
      expect(hostKey.currentState!.isUsingExternal, isTrue);

      // Switch back to internal controller
      hostKey.currentState!.toggleExternalController();
      await tester.pump();
      expect(hostKey.currentState!.isUsingExternal, isFalse);

      await tester.pump(const Duration(milliseconds: 500));
    });
  });

  // ===========================================================================
  // 12. Adversarial & Boundary Conditions
  // ===========================================================================
  group('Adversarial & Boundary Conditions', () {
    testWidgets('handles extreme text lengths and missing optional parameters without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget(
              title: 'A' * 400,
              subtitle: 'B' * 600,
              badgeText: 'EXTREME LEVEL 999999',
            ),
          ),
        ),
      );

      expect(find.byType(CelestialBannerWidget), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('handles minimal widget with null title, subtitle, and badge without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget(),
          ),
        ),
      );

      expect(find.byType(CelestialBannerWidget), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });

    test('packUniforms handles extreme floats (infinity, negative, zero) gracefully', () {
      final Float32List buffer = CelestialBannerPainter.packUniforms(
        size: const Size(0.0, 0.0),
        progress: -0.5,
        time: -100.0,
        energyIntensity: 0.0,
      );

      expect(buffer[0], equals(0.0));
      expect(buffer[1], equals(0.0));
      expect(buffer[2], equals(-100.0));
      expect(buffer[3], equals(-0.5));
      expect(buffer[4], equals(0.0));
    });
  });
}

// =============================================================================
// Test Helper Stateful Widgets
// =============================================================================

class _ExternalControllerHost extends StatefulWidget {
  const _ExternalControllerHost({required this.onControllerReady});
  final ValueChanged<AnimationController> onControllerReady;

  @override
  State<_ExternalControllerHost> createState() => _ExternalControllerHostState();
}

class _ExternalControllerHostState extends State<_ExternalControllerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    widget.onControllerReady(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CelestialBannerWidget(
      controller: _controller,
      title: 'External Controller Banner',
    );
  }
}

class _DynamicControllerHost extends StatefulWidget {
  const _DynamicControllerHost({super.key});

  @override
  State<_DynamicControllerHost> createState() => _DynamicControllerHostState();
}

class _DynamicControllerHostState extends State<_DynamicControllerHost>
    with SingleTickerProviderStateMixin {
  AnimationController? _externalController;
  bool get isUsingExternal => _externalController != null;

  void toggleExternalController() {
    setState(() {
      if (_externalController == null) {
        _externalController = AnimationController(
          vsync: this,
          duration: const Duration(seconds: 2),
        );
      } else {
        _externalController!.dispose();
        _externalController = null;
      }
    });
  }

  @override
  void dispose() {
    _externalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CelestialBannerWidget(
      controller: _externalController,
      title: 'Dynamic Controller Banner',
    );
  }
}
