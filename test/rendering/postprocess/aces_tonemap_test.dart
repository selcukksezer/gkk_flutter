import 'dart:ui' show Color, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/rendering/postprocess/aces_tonemap_curve.dart';
import 'package:gkk_flutter/rendering/postprocess/postprocess_pipeline.dart';

void main() {
  group('ACES Tonemapping & Gamma Correction Tests', () {
    test('Stephen Hill ACES curve handles black, midtones, and HDR highlights', () {
      // 1. Black stays at black
      final (double blackR, double blackG, double blackB) =
          AcesTonemapCurve.acesStephenHill(0.0, 0.0, 0.0);
      expect(blackR, closeTo(0.0, 0.001));
      expect(blackG, closeTo(0.0, 0.001));
      expect(blackB, closeTo(0.0, 0.001));

      // 2. 18% middle gray in linear space (~0.18) maps to a filmic midtone
      final (double midR, double midG, double midB) =
          AcesTonemapCurve.acesStephenHill(0.18, 0.18, 0.18);
      expect(midR, greaterThan(0.1));
      expect(midR, lessThan(0.4));
      expect(midR, closeTo(midG, 0.01));
      expect(midG, closeTo(midB, 0.01));

      // 3. 1.0 linear input maps to filmic shoulder (~0.619 linear, before gamma correction)
      final (double wR, double wG, double wB) =
          AcesTonemapCurve.acesStephenHill(1.0, 1.0, 1.0);
      expect(wR, greaterThan(0.55));
      expect(wR, lessThan(0.70));
      // Post gamma-correction, 0.619 maps to ~0.80 sRGB
      final double srgbW = AcesTonemapCurve.linearToSrgbChannel(wR);
      expect(srgbW, greaterThan(0.75));
      expect(srgbW, lessThan(0.90));

      // 4. Extreme HDR highlights (10.0, 100.0, 1000.0) roll off smoothly without exceeding 1.0
      final (double hdr10R, _, _) =
          AcesTonemapCurve.acesStephenHill(10.0, 10.0, 10.0);
      final (double hdr100R, _, _) =
          AcesTonemapCurve.acesStephenHill(100.0, 100.0, 100.0);
      final (double hdr1000R, _, _) =
          AcesTonemapCurve.acesStephenHill(1000.0, 1000.0, 1000.0);

      expect(hdr10R, greaterThan(wR));
      expect(hdr10R, lessThanOrEqualTo(1.0));
      expect(hdr100R, greaterThanOrEqualTo(hdr10R));
      expect(hdr100R, lessThanOrEqualTo(1.0));
      expect(hdr1000R, closeTo(1.0, 0.01));
    });

    test('Krzysztof Narkowicz ACES fit evaluates monotonic S-curve', () {
      final double black = AcesTonemapCurve.narkowiczChannel(0.0);
      expect(black, closeTo(0.0, 0.01));

      final double mid = AcesTonemapCurve.narkowiczChannel(0.18);
      expect(mid, greaterThan(0.1));
      expect(mid, lessThan(0.35));

      final double white = AcesTonemapCurve.narkowiczChannel(1.0);
      expect(white, greaterThan(0.75));
      expect(white, lessThan(0.90));

      final double hdr10 = AcesTonemapCurve.narkowiczChannel(10.0);
      final double hdr100 = AcesTonemapCurve.narkowiczChannel(100.0);
      expect(hdr10, greaterThan(white));
      expect(hdr100, closeTo(1.0, 0.005));

      // RGB triplet evaluation
      final (double r, double g, double b) =
          AcesTonemapCurve.acesNarkowicz(0.5, 0.2, 0.8);
      expect(r, closeTo(AcesTonemapCurve.narkowiczChannel(0.5), 0.0001));
      expect(g, closeTo(AcesTonemapCurve.narkowiczChannel(0.2), 0.0001));
      expect(b, closeTo(AcesTonemapCurve.narkowiczChannel(0.8), 0.0001));
    });

    test('IEC 61966-2-1 Linear-to-sRGB transfer function satisfies standard specs', () {
      // 1. Linear branch (c <= 0.0031308 -> 12.92 * c)
      const double darkVal = 0.002;
      expect(
        AcesTonemapCurve.linearToSrgbChannel(darkVal),
        closeTo(darkVal * 12.92, 0.00001),
      );

      // 2. Power branch (c > 0.0031308 -> 1.055 * c^(1/2.4) - 0.055)
      const double brightVal = 0.5;
      final double expectedBright = 1.055 * 0.74915353843 - 0.055;
      expect(
        AcesTonemapCurve.linearToSrgbChannel(brightVal),
        closeTo(expectedBright, 0.001),
      );

      // 3. Boundaries
      expect(AcesTonemapCurve.linearToSrgbChannel(0.0), closeTo(0.0, 0.00001));
      expect(AcesTonemapCurve.linearToSrgbChannel(1.0), closeTo(1.0, 0.00001));

      // 4. Roundtrip invertibility: srgbToLinear(linearToSrgb(x)) == x
      for (final double x in <double>[0.001, 0.01, 0.05, 0.18, 0.5, 0.8, 1.0]) {
        final double srgb = AcesTonemapCurve.linearToSrgbChannel(x);
        final double roundtrip = AcesTonemapCurve.srgbToLinearChannel(srgb);
        expect(roundtrip, closeTo(x, 0.0005));
      }
    });

    test('Exposure adjustments scale scene luminance accurately', () {
      const AcesTonemapParams baseParams = AcesTonemapParams(
        exposure: 0.0,
        exposureMode: ExposureMode.evStops,
      );
      expect(baseParams.effectiveExposureMultiplier, equals(1.0));

      // +1 EV doubles luminance
      final AcesTonemapParams plusOneEv = baseParams.copyWith(exposure: 1.0);
      expect(plusOneEv.effectiveExposureMultiplier, closeTo(2.0, 0.0001));

      // +2 EV quadruples luminance
      final AcesTonemapParams plusTwoEv = baseParams.copyWith(exposure: 2.0);
      expect(plusTwoEv.effectiveExposureMultiplier, closeTo(4.0, 0.0001));

      // -1 EV halves luminance
      final AcesTonemapParams minusOneEv = baseParams.copyWith(exposure: -1.0);
      expect(minusOneEv.effectiveExposureMultiplier, closeTo(0.5, 0.0001));

      // Linear multiplier mode
      const AcesTonemapParams linearParams = AcesTonemapParams(
        exposure: 3.5,
        exposureMode: ExposureMode.linearFactor,
      );
      expect(linearParams.effectiveExposureMultiplier, closeTo(3.5, 0.0001));
    });

    test('Complete processLinearRgb and processColor pipelines produce valid outputs', () {
      const AcesTonemapParams params = AcesTonemapParams(
        exposure: 0.5,
        exposureMode: ExposureMode.evStops,
        fitType: AcesFitType.stephenHill,
        gammaMode: GammaMode.accurateSrgb,
      );

      final (double outR, double outG, double outB) =
          AcesTonemapCurve.processLinearRgb(0.2, 0.4, 0.1, params: params);

      expect(outR, inInclusiveRange(0.0, 1.0));
      expect(outG, inInclusiveRange(0.0, 1.0));
      expect(outB, inInclusiveRange(0.0, 1.0));

      const Color testColor = Color.from(alpha: 0.9, red: 0.2, green: 0.4, blue: 0.1);
      final Color result = AcesTonemapCurve.processColor(testColor, params: params);

      expect(result.a, closeTo(0.9, 0.001));
      expect(result.r, closeTo(outR, 0.001));
      expect(result.g, closeTo(outG, 0.001));
      expect(result.b, closeTo(outB, 0.001));
    });

    test('PostProcessPipelineController builds uniform lists matching GLSL layout', () {
      const Size viewport = Size(1920.0, 1080.0);
      const AcesTonemapParams params = AcesTonemapParams(
        exposure: 1.5,
        exposureMode: ExposureMode.evStops,
        fitType: AcesFitType.narkowicz,
        gammaMode: GammaMode.gamma22,
        preGain: 1.2,
        whitePoint: 12.0,
      );

      final List<double> uniforms = PostProcessPipelineController.buildAcesUniforms(
        size: viewport,
        params: params,
      );

      expect(uniforms.length, equals(8));
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));
      expect(uniforms[2], equals(1.5));
      expect(uniforms[3], equals(1.0)); // evStops -> 1.0
      expect(uniforms[4], equals(1.0)); // narkowicz -> 1.0
      expect(uniforms[5], equals(1.0)); // gamma22 -> 1.0
      expect(uniforms[6], equals(1.2)); // preGain
      expect(uniforms[7], equals(12.0)); // whitePoint
    });
  });
}
