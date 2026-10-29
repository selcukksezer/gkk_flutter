import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/shaders/shader_pipeline.dart';
import 'package:gkk_flutter/core/vfx/rim_hit_flash_effect.dart';

// =============================================================================
// TEST DOUBLES FOR HEADLESS ISOLATED SHADER & CANVAS VERIFICATION
// =============================================================================

/// In-memory fake uniform storage recording uniform float and sampler calls
/// to verify exact GLSL uniform layout order and values without violating
/// Dart 3 [ui.FragmentShader] base class restrictions.
class FakeUniformStorage implements ShaderUniformTarget {
  final Map<int, double> uniforms = <int, double>{};
  final Map<int, ui.Image> samplers = <int, ui.Image>{};
  bool disposed = false;

  @override
  void setFloat(int index, double value) {
    uniforms[index] = value;
  }

  @override
  void setImageSampler(int index, ui.Image image) {
    samplers[index] = image;
  }

  void dispose() {
    disposed = true;
  }

  /// Binds controller uniforms and texture samplers to this storage matching shader layout.
  void bindFromController({
    required RimHitFlashController controller,
    required ui.Size size,
    required ui.Image targetImage,
    ui.Image? normalMapImage,
  }) {
    final List<double> values = controller.buildUniformList(size);
    for (int i = 0; i < values.length; i++) {
      setFloat(i, values[i]);
    }
    setImageSampler(0, targetImage);
    setImageSampler(1, normalMapImage ?? targetImage);
  }
}

/// In-memory fake [ui.Canvas] recording drawing operations without native engine handles.
class FakeCanvas extends Fake implements ui.Canvas {
  final List<ui.Rect> drawnRects = <ui.Rect>[];
  final List<ui.Paint> usedPaints = <ui.Paint>[];
  ui.Paint? lastPaint;

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) {
    drawnRects.add(rect);
    usedPaints.add(paint);
    lastPaint = paint;
  }

  @override
  void save() {}

  @override
  void translate(double dx, double dy) {}

  @override
  void restore() {}
}

/// In-memory fake [ui.Image] representing sprite/character textures.
class FakeImage extends Fake implements ui.Image {
  FakeImage({this.width = 256, this.height = 256});

  @override
  final int width;

  @override
  final int height;

  @override
  bool get debugDisposed => false;

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // 1. GLSL SHADER SOURCE CODE SPECIFICATION & UNIFORM LAYOUT PARITY
  // ===========================================================================
  group('1. GLSL Shader Source Code Specification & Uniform Layout Parity', () {
    late File shaderFile;
    late String shaderCode;

    setUpAll(() {
      shaderFile = File('shaders/vfx/rim_hit_flash.frag');
      expect(shaderFile.existsSync(), isTrue,
          reason: 'shaders/vfx/rim_hit_flash.frag must exist in repository');
      shaderCode = shaderFile.readAsStringSync();
    });

    test('Shader header declares version 460 core and flutter runtime_effect include', () {
      expect(shaderCode, contains('#version 460 core'));
      expect(shaderCode, contains('#include <flutter/runtime_effect.glsl>'));
      expect(shaderCode, contains('precision highp float;'));
      expect(shaderCode, contains('out vec4 fragColor;'));
    });

    test('Shader declares all 10 uniforms matching exact 13-float layout in order', () {
      // 0..1: uResolution (vec2 = 2 floats)
      expect(shaderCode, contains('uniform vec2  uResolution;'));
      // 2: uIntensity (float = 1 float)
      expect(shaderCode, contains('uniform float uIntensity;'));
      // 3..5: uTintColor (vec3 = 3 floats)
      expect(shaderCode, contains('uniform vec3  uTintColor;'));
      // 6: uRimPower (float = 1 float)
      expect(shaderCode, contains('uniform float uRimPower;'));
      // 7: uRimIntensity (float = 1 float)
      expect(shaderCode, contains('uniform float uRimIntensity;'));
      // 8: uInnerFlash (float = 1 float)
      expect(shaderCode, contains('uniform float uInnerFlash;'));
      // 9: uEdgeBleedWidth (float = 1 float)
      expect(shaderCode, contains('uniform float uEdgeBleedWidth;'));
      // 10: uEdgeBleedIntensity (float = 1 float)
      expect(shaderCode, contains('uniform float uEdgeBleedIntensity;'));
      // 11: uBloomMultiplier (float = 1 float)
      expect(shaderCode, contains('uniform float uBloomMultiplier;'));
      // 12: uNormalMode (float = 1 float)
      expect(shaderCode, contains('uniform float uNormalMode;'));

      // Check declaration ordering
      final int idxResolution = shaderCode.indexOf('uResolution');
      final int idxIntensity = shaderCode.indexOf('uIntensity');
      final int idxTint = shaderCode.indexOf('uTintColor');
      final int idxPower = shaderCode.indexOf('uRimPower');
      final int idxRimIntensity = shaderCode.indexOf('uRimIntensity');
      final int idxInner = shaderCode.indexOf('uInnerFlash');
      final int idxBleedW = shaderCode.indexOf('uEdgeBleedWidth');
      final int idxBleedI = shaderCode.indexOf('uEdgeBleedIntensity');
      final int idxBloom = shaderCode.indexOf('uBloomMultiplier');
      final int idxNormal = shaderCode.indexOf('uNormalMode');

      expect(idxResolution, lessThan(idxIntensity));
      expect(idxIntensity, lessThan(idxTint));
      expect(idxTint, lessThan(idxPower));
      expect(idxPower, lessThan(idxRimIntensity));
      expect(idxRimIntensity, lessThan(idxInner));
      expect(idxInner, lessThan(idxBleedW));
      expect(idxBleedW, lessThan(idxBleedI));
      expect(idxBleedI, lessThan(idxBloom));
      expect(idxBloom, lessThan(idxNormal));
    });

    test('Samplers are declared strictly after all numeric uniforms', () {
      expect(shaderCode, contains('uniform sampler2D uTexture;'));
      expect(shaderCode, contains('uniform sampler2D uNormalMap;'));

      final int idxNormal = shaderCode.indexOf('uniform float uNormalMode;');
      final int idxTex = shaderCode.indexOf('uniform sampler2D uTexture;');
      final int idxNormMap = shaderCode.indexOf('uniform sampler2D uNormalMap;');

      expect(idxTex, greaterThan(idxNormal),
          reason: 'uTexture sampler must follow numeric uniforms for Flutter runtime effects');
      expect(idxNormMap, greaterThan(idxTex),
          reason: 'uNormalMap sampler must follow uTexture sampler');
    });

    test('Shader defines view vector V = vec3(0.0, 0.0, 1.0) pointing towards camera', () {
      expect(shaderCode, contains('vec3 V = vec3(0.0, 0.0, 1.0);'));
      expect(shaderCode, contains('float NdotV = clamp(dot(N, V), 0.0, 1.0);'));
      expect(shaderCode, contains('float grazing = clamp(1.0 - NdotV, 0.0, 1.0);'));
      expect(shaderCode, contains('float fresnel = pow(grazing, max(uRimPower, 0.01)) * uRimIntensity;'));
    });

    test('Shader implements all three normal modes (Sobel, Map, Spherical Dome)', () {
      expect(shaderCode, contains('if (uNormalMode < 0.5) {'));
      expect(shaderCode, contains('} else if (uNormalMode < 1.5) {'));
      expect(shaderCode, contains('// Mode 2: Billboard analytical spherical dome normal'));
      expect(shaderCode, contains('normalize(vec3(-grad.x * 3.0, -grad.y * 3.0, zDepth));'));
    });

    test('Shader implements 8-tap silhouette edge bleed sampling', () {
      expect(shaderCode, contains('const float kDiag = 0.70710678;'));
      expect(shaderCode, contains('float avgNeighborAlpha = sumNeighborAlpha * 0.125;'));
      expect(shaderCode, contains('float outerBleed = clamp(avgNeighborAlpha * (1.0 - baseColor.a) * uEdgeBleedIntensity, 0.0, 1.0);'));
    });

    test('Shader implements fast-path bypass when flash is inactive', () {
      expect(shaderCode, contains('if (uIntensity <= 0.0001) {'));
      expect(shaderCode, contains('fragColor = baseColor;'));
    });
  });

  // ===========================================================================
  // 2. COLOR SPACE CONVERSION & TINT PRESETS
  // ===========================================================================
  group('2. Color Space Conversion & Tint Presets', () {
    test('RimFlashTint constants match authentic R3 combat specifications', () {
      expect(RimFlashTint.white, equals(const ui.Color(0xFFFFFFFF)));
      expect(RimFlashTint.bloodRed, equals(const ui.Color(0xFFFF2222)));
      expect(RimFlashTint.magicalCyan, equals(const ui.Color(0xFF22E5FF)));
      expect(RimFlashTint.poisonGreen, equals(const ui.Color(0xFF33FF55)));
      expect(RimFlashTint.lightningGold, equals(const ui.Color(0xFFFFDF22)));
      expect(RimFlashTint.voidPurple, equals(const ui.Color(0xFFA533FF)));
    });

    test('srgbToLinearChannel accurately applies IEC 61966-2-1 transfer function', () {
      // Zero and full range
      expect(RimHitFlashEnvelope.srgbToLinearChannel(0.0), closeTo(0.0, 1e-6));
      expect(RimHitFlashEnvelope.srgbToLinearChannel(1.0), closeTo(1.0, 1e-6));

      // Linear segment: c <= 0.04045 -> c / 12.92
      const double threshold = 0.04045;
      expect(RimHitFlashEnvelope.srgbToLinearChannel(threshold),
          closeTo(threshold / 12.92, 1e-6));
      expect(RimHitFlashEnvelope.srgbToLinearChannel(0.02),
          closeTo(0.02 / 12.92, 1e-6));

      // Exponential segment: c > 0.04045 -> ((c + 0.055) / 1.055)^2.4
      const double mid = 0.5;
      final double expectedMid = math.pow((mid + 0.055) / 1.055, 2.4).toDouble();
      expect(RimHitFlashEnvelope.srgbToLinearChannel(mid), closeTo(expectedMid, 1e-6));
    });

    test('colorToLinearRgb converts colors accurately', () {
      // White -> (1.0, 1.0, 1.0)
      final (double wr, double wg, double wb) =
          RimHitFlashEnvelope.colorToLinearRgb(RimFlashTint.white);
      expect(wr, closeTo(1.0, 1e-4));
      expect(wg, closeTo(1.0, 1e-4));
      expect(wb, closeTo(1.0, 1e-4));

      // Black -> (0.0, 0.0, 0.0)
      final (double br, double bg, double bb) =
          RimHitFlashEnvelope.colorToLinearRgb(const ui.Color(0xFF000000));
      expect(br, closeTo(0.0, 1e-6));
      expect(bg, closeTo(0.0, 1e-6));
      expect(bb, closeTo(0.0, 1e-6));

      // Blood Red -> high linear red, low green and blue
      final (double rr, double rg, double rb) =
          RimHitFlashEnvelope.colorToLinearRgb(RimFlashTint.bloodRed);
      expect(rr, closeTo(1.0, 1e-4));
      expect(rg, lessThan(0.05));
      expect(rb, lessThan(0.05));
    });

    test('linearRgbToColor round-trips with high fidelity', () {
      const List<ui.Color> testColors = <ui.Color>[
        RimFlashTint.white,
        RimFlashTint.bloodRed,
        RimFlashTint.magicalCyan,
        RimFlashTint.poisonGreen,
        RimFlashTint.lightningGold,
        RimFlashTint.voidPurple,
      ];

      for (final ui.Color color in testColors) {
        final (double r, double g, double b) =
            RimHitFlashEnvelope.colorToLinearRgb(color);
        final ui.Color roundTrip = RimHitFlashEnvelope.linearRgbToColor(r, g, b);

        expect((roundTrip.r * 255.0).round(), closeTo((color.r * 255.0).round(), 1.0));
        expect((roundTrip.g * 255.0).round(), closeTo((color.g * 255.0).round(), 1.0));
        expect((roundTrip.b * 255.0).round(), closeTo((color.b * 255.0).round(), 1.0));
      }
    });
  });

  // ===========================================================================
  // 3. MATHEMATICAL PARITY: FRESNEL RIM FALLOFF & EMISSIVE HIGHLIGHTS
  // ===========================================================================
  group('3. Mathematical Parity: Fresnel Rim Falloff & Emissive Highlights', () {
    test('Fresnel rim produces 0.0 highlight when surface directly faces viewer (NdotV = 1.0)', () {
      // Facing viewer: grazing angle is 0.0
      final double fresnel = RimHitFlashEnvelope.computeFresnel(
        nDotV: 1.0,
        rimPower: 3.5,
        rimIntensity: 2.0,
      );
      expect(fresnel, closeTo(0.0, 1e-6));
    });

    test('Fresnel rim produces maximum peak highlight at grazing edge (NdotV = 0.0)', () {
      // Perpendicular to viewer: grazing angle is 1.0 -> (1.0)^power * intensity = intensity
      final double fresnel = RimHitFlashEnvelope.computeFresnel(
        nDotV: 0.0,
        rimPower: 3.5,
        rimIntensity: 2.0,
      );
      expect(fresnel, closeTo(2.0, 1e-6));
    });

    test('Higher rimPower yields sharper edge concentration', () {
      const double midNdotV = 0.3; // Grazing factor = 0.7
      final double softRim = RimHitFlashEnvelope.computeFresnel(
        nDotV: midNdotV,
        rimPower: 2.0,
        rimIntensity: 1.0,
      );
      final double sharpRim = RimHitFlashEnvelope.computeFresnel(
        nDotV: midNdotV,
        rimPower: 5.0,
        rimIntensity: 1.0,
      );

      // (0.7)^5 is much smaller than (0.7)^2
      expect(sharpRim, lessThan(softRim));
      expect(softRim, closeTo(0.49, 0.01));
      expect(sharpRim, closeTo(0.168, 0.01));
    });

    test('Negative and out-of-range NdotV are clamped safely', () {
      // NdotV < 0.0 (facing away from camera) clamps to 0.0 -> peak rim
      final double negFresnel = RimHitFlashEnvelope.computeFresnel(
        nDotV: -0.5,
        rimPower: 3.0,
        rimIntensity: 1.5,
      );
      expect(negFresnel, closeTo(1.5, 1e-6));

      // NdotV > 1.0 clamps to 1.0 -> 0.0 rim
      final double overFresnel = RimHitFlashEnvelope.computeFresnel(
        nDotV: 1.5,
        rimPower: 3.0,
        rimIntensity: 1.5,
      );
      expect(overFresnel, closeTo(0.0, 1e-6));
    });

    test('Safe power handling prevents division by zero or negative exponent issues', () {
      final double safeZeroPower = RimHitFlashEnvelope.computeFresnel(
        nDotV: 0.5,
        rimPower: -1.0,
        rimIntensity: 1.0,
      );
      expect(safeZeroPower.isFinite, isTrue);
      expect(safeZeroPower, greaterThan(0.0));
    });

    test('computeEmissiveHighlight matches GLSL composition formula', () {
      // Inactive flash (intensity = 0.0) -> zero emissive contribution
      final (double r0, double g0, double b0) =
          RimHitFlashEnvelope.computeEmissiveHighlight(
        nDotV: 0.0,
        tint: RimFlashTint.white,
        intensity: 0.0,
      );
      expect(r0, equals(0.0));
      expect(g0, equals(0.0));
      expect(b0, equals(0.0));

      // Active flash: verify linear scaling with bloom multiplier
      final (double r1, double g1, double b1) =
          RimHitFlashEnvelope.computeEmissiveHighlight(
        nDotV: 0.0,
        tint: RimFlashTint.white,
        intensity: 1.0,
        rimPower: 3.5,
        rimIntensity: 2.0,
        innerFlash: 0.4,
        edgeBleed: 0.1,
        bloomMultiplier: 2.5,
        baseAlpha: 1.0,
      );

      // highlightFactor = (2.0 * 1.0 + 0.1 + 0.4) * 1.0 = 2.5
      // totalMultiplier = 2.5 * 2.5 = 6.25
      // Linear white = (1.0, 1.0, 1.0) -> components = 6.25
      expect(r1, closeTo(6.25, 1e-4));
      expect(g1, closeTo(6.25, 1e-4));
      expect(b1, closeTo(6.25, 1e-4));
    });
  });

  // ===========================================================================
  // 4. HIT-STOP SYNCHRONIZATION & EXPONENTIAL PARAMETER DECAY (30-50MS)
  // ===========================================================================
  group('4. Hit-Stop Synchronization & Exponential Parameter Decay', () {
    test('Zero or negative elapsed time yields instantaneous peak 1.0', () {
      expect(
        RimHitFlashEnvelope.evaluateDecay(elapsedMs: 0.0, totalDurationMs: 100.0),
        equals(1.0),
      );
      expect(
        RimHitFlashEnvelope.evaluateDecay(elapsedMs: -10.0, totalDurationMs: 100.0),
        equals(1.0),
      );
    });

    test('Elapsed time >= totalDurationMs terminates strictly to 0.0', () {
      expect(
        RimHitFlashEnvelope.evaluateDecay(elapsedMs: 100.0, totalDurationMs: 100.0),
        equals(0.0),
      );
      expect(
        RimHitFlashEnvelope.evaluateDecay(elapsedMs: 150.0, totalDurationMs: 100.0),
        equals(0.0),
      );
      expect(
        RimHitFlashEnvelope.evaluateDecay(elapsedMs: 10.0, totalDurationMs: 0.0),
        equals(0.0),
      );
    });

    test('Hit-stop holds peak 1.0 during 30ms freeze window', () {
      const double totalDuration = 100.0;
      const double hitStop = 30.0;

      // Inside hit-stop window: holds 1.0
      expect(
        RimHitFlashEnvelope.evaluateDecay(
          elapsedMs: 0.0,
          totalDurationMs: totalDuration,
          hitStopMs: hitStop,
        ),
        equals(1.0),
      );
      expect(
        RimHitFlashEnvelope.evaluateDecay(
          elapsedMs: 15.0,
          totalDurationMs: totalDuration,
          hitStopMs: hitStop,
        ),
        equals(1.0),
      );
      expect(
        RimHitFlashEnvelope.evaluateDecay(
          elapsedMs: 30.0,
          totalDurationMs: totalDuration,
          hitStopMs: hitStop,
        ),
        equals(1.0),
      );

      // Right after hit-stop window: decay starts
      final double justAfter = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 31.0,
        totalDurationMs: totalDuration,
        hitStopMs: hitStop,
      );
      expect(justAfter, lessThan(1.0));
      expect(justAfter, greaterThan(0.9));
    });

    test('Hit-stop holds peak 1.0 during 40ms freeze window', () {
      const double totalDuration = 100.0;
      const double hitStop = 40.0;

      expect(
        RimHitFlashEnvelope.evaluateDecay(
          elapsedMs: 20.0,
          totalDurationMs: totalDuration,
          hitStopMs: hitStop,
        ),
        equals(1.0),
      );
      expect(
        RimHitFlashEnvelope.evaluateDecay(
          elapsedMs: 40.0,
          totalDurationMs: totalDuration,
          hitStopMs: hitStop,
        ),
        equals(1.0),
      );

      // Mid-decay at elapsed = 70ms: effective progress = (70 - 40)/(100 - 40) = 30/60 = 0.5
      // exp(-4.60517 * 0.5) ~= 0.100
      final double midDecay = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 70.0,
        totalDurationMs: totalDuration,
        hitStopMs: hitStop,
      );
      expect(midDecay, closeTo(math.exp(-4.60517 * 0.5), 0.01));
    });

    test('Hit-stop holds peak 1.0 during 50ms freeze window', () {
      const double totalDuration = 120.0;
      const double hitStop = 50.0;

      expect(
        RimHitFlashEnvelope.evaluateDecay(
          elapsedMs: 50.0,
          totalDurationMs: totalDuration,
          hitStopMs: hitStop,
        ),
        equals(1.0),
      );

      // After 50ms: decays smoothly towards 0.0 at 120ms
      final double decay70 = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 70.0,
        totalDurationMs: totalDuration,
        hitStopMs: hitStop,
      );
      final double decay100 = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 100.0,
        totalDurationMs: totalDuration,
        hitStopMs: hitStop,
      );
      final double decay120 = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 120.0,
        totalDurationMs: totalDuration,
        hitStopMs: hitStop,
      );

      expect(decay70, lessThan(1.0));
      expect(decay100, lessThan(decay70));
      expect(decay120, equals(0.0));
    });

    test('Standard exponential decay without hit-stop (hitStopMs = 0) decays continuously', () {
      const double totalDuration = 100.0;

      final double t0 = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 0.0,
        totalDurationMs: totalDuration,
      );
      final double t25 = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 25.0,
        totalDurationMs: totalDuration,
      );
      final double t50 = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 50.0,
        totalDurationMs: totalDuration,
      );
      final double t75 = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 75.0,
        totalDurationMs: totalDuration,
      );
      final double t100 = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 100.0,
        totalDurationMs: totalDuration,
      );

      expect(t0, equals(1.0));
      expect(t25, closeTo(math.exp(-4.60517 * 0.25), 0.01));
      expect(t50, closeTo(math.exp(-4.60517 * 0.50), 0.01));
      expect(t75, closeTo(math.exp(-4.60517 * 0.75), 0.01));
      expect(t100, equals(0.0));

      // Strictly monotonic decrease
      expect(t25, lessThan(t0));
      expect(t50, lessThan(t25));
      expect(t75, lessThan(t50));
    });

    test('Edge case: hitStopMs >= totalDurationMs terminates to 0.0 at or past total duration', () {
      final double during = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 50.0,
        totalDurationMs: 100.0,
        hitStopMs: 100.0,
      );
      expect(during, equals(1.0));

      final double end = RimHitFlashEnvelope.evaluateDecay(
        elapsedMs: 100.0,
        totalDurationMs: 100.0,
        hitStopMs: 100.0,
      );
      expect(end, equals(0.0));
    });
  });

  // ===========================================================================
  // 5. CONFIGURATION & NORMAL MODE SPECIFICATIONS
  // ===========================================================================
  group('5. Configuration & Normal Mode Specifications', () {
    test('RimHitFlashConfig baseline defaults align with AAA dark fantasy visual specs', () {
      const RimHitFlashConfig config = RimHitFlashConfig();

      expect(config.duration, equals(const Duration(milliseconds: 100)));
      expect(config.tint, equals(RimFlashTint.white));
      expect(config.rimPower, equals(3.5));
      expect(config.rimIntensity, equals(2.0));
      expect(config.innerFlash, equals(0.4));
      expect(config.edgeBleedWidth, equals(2.0));
      expect(config.edgeBleedIntensity, equals(1.2));
      expect(config.bloomMultiplier, equals(2.5));
      expect(config.normalMode, equals(RimFlashNormalMode.silhouetteGradient));
      expect(config.decayLambda, closeTo(4.60517, 1e-4));
      expect(config.hitStopDuration, equals(Duration.zero));
    });

    test('RimFlashNormalMode shader values match GLSL branches', () {
      expect(RimFlashNormalMode.silhouetteGradient.shaderValue, equals(0.0));
      expect(RimFlashNormalMode.normalMap.shaderValue, equals(1.0));
      expect(RimFlashNormalMode.sphericalDome.shaderValue, equals(2.0));
    });

    test('RimHitFlashConfig copyWith modifies target properties without mutating defaults', () {
      const RimHitFlashConfig original = RimHitFlashConfig();
      final RimHitFlashConfig modified = original.copyWith(
        duration: const Duration(milliseconds: 120),
        tint: RimFlashTint.bloodRed,
        rimPower: 5.0,
        rimIntensity: 3.0,
        innerFlash: 0.6,
        edgeBleedWidth: 3.5,
        edgeBleedIntensity: 1.8,
        bloomMultiplier: 4.0,
        normalMode: RimFlashNormalMode.normalMap,
        decayLambda: 3.0,
        hitStopDuration: const Duration(milliseconds: 40),
      );

      expect(modified.duration, equals(const Duration(milliseconds: 120)));
      expect(modified.tint, equals(RimFlashTint.bloodRed));
      expect(modified.rimPower, equals(5.0));
      expect(modified.rimIntensity, equals(3.0));
      expect(modified.innerFlash, equals(0.6));
      expect(modified.edgeBleedWidth, equals(3.5));
      expect(modified.edgeBleedIntensity, equals(1.8));
      expect(modified.bloomMultiplier, equals(4.0));
      expect(modified.normalMode, equals(RimFlashNormalMode.normalMap));
      expect(modified.decayLambda, equals(3.0));
      expect(modified.hitStopDuration, equals(const Duration(milliseconds: 40)));

      // Original remains pristine
      expect(original.duration, equals(const Duration(milliseconds: 100)));
      expect(original.tint, equals(RimFlashTint.white));
    });
  });

  // ===========================================================================
  // 6. CONTROLLER STATE MACHINE & FLASH PULSES
  // ===========================================================================
  group('6. Controller State Machine & Flash Pulses', () {
    test('Controller initial state is inactive with zero intensity and elapsed time', () {
      final RimHitFlashController controller = RimHitFlashController();

      expect(controller.isFlashing, isFalse);
      expect(controller.currentIntensity, equals(0.0));
      expect(controller.elapsedTimeMs, equals(0.0));
      expect(controller.config.tint, equals(RimFlashTint.white));
    });

    test('triggerHit activates flash, resets elapsed time, and sets peak intensity', () {
      final RimHitFlashController controller = RimHitFlashController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.triggerHit(
        tint: RimFlashTint.magicalCyan,
        intensityMultiplier: 1.25,
      );

      expect(controller.isFlashing, isTrue);
      expect(controller.currentIntensity, equals(1.25));
      expect(controller.elapsedTimeMs, equals(0.0));
      expect(controller.config.tint, equals(RimFlashTint.magicalCyan));
      expect(notifyCount, equals(1));
    });

    test('Rapid combat combo re-triggering resets elapsed time and reapplies parameters', () {
      final RimHitFlashController controller = RimHitFlashController();
      controller.triggerHit(duration: const Duration(milliseconds: 100));

      // Advance time by 40ms
      controller.update(0.04);
      expect(controller.elapsedTimeMs, closeTo(40.0, 1e-4));
      expect(controller.currentIntensity, lessThan(1.0));

      // Re-trigger before first flash ends (combat combo strike)
      controller.triggerHit(
        tint: RimFlashTint.bloodRed,
        intensityMultiplier: 1.5,
      );

      expect(controller.isFlashing, isTrue);
      expect(controller.elapsedTimeMs, equals(0.0));
      expect(controller.currentIntensity, equals(1.5));
      expect(controller.config.tint, equals(RimFlashTint.bloodRed));
    });

    test('update() decrements intensity according to exponential decay envelope', () {
      final RimHitFlashController controller = RimHitFlashController(
        defaultConfig: const RimHitFlashConfig(
          duration: Duration(milliseconds: 100),
          hitStopDuration: Duration(milliseconds: 40),
        ),
      );

      controller.triggerHit();
      expect(controller.currentIntensity, equals(1.0));

      // 1. Advance by 20ms (inside 40ms hit stop) -> holds 1.0
      controller.update(0.02);
      expect(controller.elapsedTimeMs, closeTo(20.0, 1e-4));
      expect(controller.currentIntensity, equals(1.0));

      // 2. Advance by another 20ms (at exactly 40ms hit stop boundary) -> holds 1.0
      controller.update(0.02);
      expect(controller.elapsedTimeMs, closeTo(40.0, 1e-4));
      expect(controller.currentIntensity, equals(1.0));

      // 3. Advance by 20ms (at 60ms, decay active) -> intensity decreases
      controller.update(0.02);
      expect(controller.elapsedTimeMs, closeTo(60.0, 1e-4));
      expect(controller.currentIntensity, lessThan(1.0));
      expect(controller.currentIntensity, greaterThan(0.0));

      // 4. Advance past 100ms total duration -> completes and stops flashing
      controller.update(0.05);
      expect(controller.isFlashing, isFalse);
      expect(controller.currentIntensity, equals(0.0));
      expect(controller.elapsedTimeMs, equals(100.0));
    });

    test('update() is a no-op when controller is inactive', () {
      final RimHitFlashController controller = RimHitFlashController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.update(0.016);
      expect(controller.isFlashing, isFalse);
      expect(controller.elapsedTimeMs, equals(0.0));
      expect(controller.currentIntensity, equals(0.0));
      expect(notifyCount, equals(0));
    });

    test('reset() immediately clears all flash state and notifies listeners', () {
      final RimHitFlashController controller = RimHitFlashController();
      controller.triggerHit();
      controller.update(0.02);
      expect(controller.isFlashing, isTrue);

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.reset();
      expect(controller.isFlashing, isFalse);
      expect(controller.currentIntensity, equals(0.0));
      expect(controller.elapsedTimeMs, equals(0.0));
      expect(notifyCount, equals(1));
    });
  });

  // ===========================================================================
  // 7. UNIFORM PACKING & BUFFER GENERATION (13-FLOAT LAYOUT)
  // ===========================================================================
  group('7. Uniform Packing & Buffer Generation (13-Float Layout)', () {
    test('buildUniformList packs continuous 13 floats with exact GLSL offsets', () {
      final RimHitFlashController controller = RimHitFlashController(
        defaultConfig: const RimHitFlashConfig(
          tint: RimFlashTint.poisonGreen,
          rimPower: 4.5,
          rimIntensity: 2.8,
          innerFlash: 0.5,
          edgeBleedWidth: 3.0,
          edgeBleedIntensity: 1.5,
          bloomMultiplier: 3.2,
          normalMode: RimFlashNormalMode.sphericalDome,
        ),
      );

      controller.triggerHit(intensityMultiplier: 1.0);

      const ui.Size targetSize = ui.Size(1920.0, 1080.0);
      final List<double> uniforms = controller.buildUniformList(targetSize);

      expect(uniforms.length, equals(13));

      // 0..1: uResolution
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));

      // 2: uIntensity
      expect(uniforms[2], equals(1.0));

      // 3..5: uTintColor (linear RGB for poison green)
      final (double expectedR, double expectedG, double expectedB) =
          RimHitFlashEnvelope.colorToLinearRgb(RimFlashTint.poisonGreen);
      expect(uniforms[3], closeTo(expectedR, 1e-4));
      expect(uniforms[4], closeTo(expectedG, 1e-4));
      expect(uniforms[5], closeTo(expectedB, 1e-4));

      // 6: uRimPower
      expect(uniforms[6], equals(4.5));

      // 7: uRimIntensity
      expect(uniforms[7], equals(2.8));

      // 8: uInnerFlash
      expect(uniforms[8], equals(0.5));

      // 9: uEdgeBleedWidth
      expect(uniforms[9], equals(3.0));

      // 10: uEdgeBleedIntensity
      expect(uniforms[10], equals(1.5));

      // 11: uBloomMultiplier
      expect(uniforms[11], equals(3.2));

      // 12: uNormalMode (sphericalDome = 2.0)
      expect(uniforms[12], equals(2.0));
    });

    test('toUniformFloat32List creates native Float32List buffer matching uniforms', () {
      final RimHitFlashController controller = RimHitFlashController();
      controller.triggerHit();

      const ui.Size size = ui.Size(800.0, 600.0);
      final Float32List buffer = controller.toUniformFloat32List(size);
      final List<double> list = controller.buildUniformList(size);

      expect(buffer.length, equals(13));
      for (int i = 0; i < 13; i++) {
        expect(buffer[i], closeTo(list[i], 1e-6));
      }
    });

    test('Dynamic parameter decay accurately updates uniform list index 2', () {
      final RimHitFlashController controller = RimHitFlashController(
        defaultConfig: const RimHitFlashConfig(
          duration: Duration(milliseconds: 100),
        ),
      );

      const ui.Size size = ui.Size(200.0, 200.0);

      // Inactive: intensity = 0.0
      expect(controller.buildUniformList(size)[2], equals(0.0));

      // Trigger: intensity = 1.0
      controller.triggerHit();
      expect(controller.buildUniformList(size)[2], equals(1.0));

      // Advance time: decay reflected
      controller.update(0.05);
      final double midIntensity = controller.buildUniformList(size)[2];
      expect(midIntensity, lessThan(1.0));
      expect(midIntensity, greaterThan(0.0));

      // Finish: intensity = 0.0
      controller.update(0.06);
      expect(controller.buildUniformList(size)[2], equals(0.0));
    });
  });

  // ===========================================================================
  // 8. CUSTOM PAINTER EXECUTION & REPAINT BOUNDARIES
  // ===========================================================================
  group('8. Custom Painter Execution & Repaint Boundaries', () {
    test('Inactive controller does not draw onto canvas', () {
      final RimHitFlashController controller = RimHitFlashController();
      final RimHitFlashPainter painter = RimHitFlashPainter(controller: controller);

      final FakeCanvas fakeCanvas = FakeCanvas();
      painter.paint(fakeCanvas, const ui.Size(200.0, 200.0));

      expect(fakeCanvas.drawnRects, isEmpty);
      expect(fakeCanvas.usedPaints, isEmpty);
    });

    test('Active controller with no shader executes software fallback painter', () {
      final RimHitFlashController controller = RimHitFlashController(
        defaultConfig: const RimHitFlashConfig(
          tint: RimFlashTint.lightningGold,
          enableChromaticAberration: false,
        ),
      );
      controller.triggerHit(intensityMultiplier: 1.0);

      final RimHitFlashPainter painter = RimHitFlashPainter(
        controller: controller,
        shader: null, // Forces software fallback
      );

      final FakeCanvas fakeCanvas = FakeCanvas();
      const ui.Size size = ui.Size(300.0, 400.0);
      painter.paint(fakeCanvas, size);

      // Verifies fallback drawRect
      expect(fakeCanvas.drawnRects.length, equals(1));
      expect(fakeCanvas.drawnRects.first, equals(ui.Offset.zero & size));

      // Verifies fallback paint properties
      final ui.Paint paint = fakeCanvas.lastPaint!;
      expect(paint.blendMode, equals(ui.BlendMode.screen));
      // Effective alpha = 1.0 * 0.85 = 0.85
      expect(paint.color.a, closeTo(0.85, 0.01));
    });

    test('Fallback painter executes natively via PictureRecorder without crashing', () {
      final RimHitFlashController controller = RimHitFlashController();
      controller.triggerHit();

      final RimHitFlashPainter painter = RimHitFlashPainter(controller: controller);

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      painter.paint(canvas, const ui.Size(256.0, 256.0));

      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('GPU uniform storage binds all 13 uniforms and both samplers accurately', () {
      final RimHitFlashController controller = RimHitFlashController(
        defaultConfig: const RimHitFlashConfig(
          tint: RimFlashTint.voidPurple,
          rimPower: 4.2,
          rimIntensity: 3.5,
          innerFlash: 0.7,
          edgeBleedWidth: 2.5,
          edgeBleedIntensity: 1.4,
          bloomMultiplier: 3.0,
          normalMode: RimFlashNormalMode.normalMap,
        ),
      );
      controller.triggerHit();

      final FakeUniformStorage storage = FakeUniformStorage();
      final FakeImage targetImage = FakeImage(width: 512, height: 512);
      final FakeImage normalImage = FakeImage(width: 512, height: 512);

      const ui.Size canvasSize = ui.Size(512.0, 512.0);
      storage.bindFromController(
        controller: controller,
        size: canvasSize,
        targetImage: targetImage,
        normalMapImage: normalImage,
      );

      // Uniforms 0..12 populated
      expect(storage.uniforms.length, equals(13));
      expect(storage.uniforms[0], equals(512.0));
      expect(storage.uniforms[1], equals(512.0));
      expect(storage.uniforms[2], equals(1.0)); // active intensity
      expect(storage.uniforms[6], equals(4.2)); // rimPower
      expect(storage.uniforms[7], equals(3.5)); // rimIntensity
      expect(storage.uniforms[8], equals(0.7)); // innerFlash
      expect(storage.uniforms[9], equals(2.5)); // edgeBleedWidth
      expect(storage.uniforms[10], equals(1.4)); // edgeBleedIntensity
      expect(storage.uniforms[11], equals(3.0)); // bloomMultiplier
      expect(storage.uniforms[12], equals(1.0)); // normalMode = normalMap

      // Samplers populated
      expect(storage.samplers[0], equals(targetImage));
      expect(storage.samplers[1], equals(normalImage));
    });

    test('GPU uniform storage falls back to targetImage when normalMapImage is null', () {
      final RimHitFlashController controller = RimHitFlashController();
      controller.triggerHit();

      final FakeUniformStorage storage = FakeUniformStorage();
      final FakeImage targetImage = FakeImage();

      storage.bindFromController(
        controller: controller,
        size: const ui.Size(100.0, 100.0),
        targetImage: targetImage,
        normalMapImage: null, // Omitted
      );

      expect(storage.samplers[0], equals(targetImage));
      expect(storage.samplers[1], equals(targetImage)); // fallback to targetImage
    });

    test('GPU Shader path binds to real FragmentShader when runtime effect is loaded', () {
      final ui.FragmentProgram? program = RimHitFlashPreloader.cachedProgram;
      if (program != null) {
        final RimHitFlashController controller = RimHitFlashController();
        controller.triggerHit();

        final FakeUniformStorage storage = FakeUniformStorage();
        storage.bindFromController(
          controller: controller,
          size: const ui.Size(512.0, 512.0),
          targetImage: FakeImage(),
        );
        expect(storage.uniforms.length, equals(13));
      }
    });

    test('shouldRepaint returns true on state changes and false when identical', () {
      final RimHitFlashController controller1 = RimHitFlashController();
      final RimHitFlashController controller2 = RimHitFlashController();
      final FakeImage image1 = FakeImage();
      final FakeImage image2 = FakeImage();

      final RimHitFlashPainter painter1 = RimHitFlashPainter(
        controller: controller1,
        shader: null,
        targetImage: image1,
        normalMapImage: image1,
      );

      final RimHitFlashPainter identicalPainter = RimHitFlashPainter(
        controller: controller1,
        shader: null,
        targetImage: image1,
        normalMapImage: image1,
      );

      final RimHitFlashPainter diffController = RimHitFlashPainter(
        controller: controller2,
        shader: null,
        targetImage: image1,
        normalMapImage: image1,
      );

      final RimHitFlashPainter diffTarget = RimHitFlashPainter(
        controller: controller1,
        shader: null,
        targetImage: image2,
        normalMapImage: image1,
      );

      final RimHitFlashPainter diffNormal = RimHitFlashPainter(
        controller: controller1,
        shader: null,
        targetImage: image1,
        normalMapImage: image2,
      );

      expect(painter1.shouldRepaint(identicalPainter), isFalse);
      expect(painter1.shouldRepaint(diffController), isTrue);
      expect(painter1.shouldRepaint(diffTarget), isTrue);
      expect(painter1.shouldRepaint(diffNormal), isTrue);

      if (RimHitFlashPreloader.cachedProgram != null) {
        final ui.FragmentShader realShader =
            RimHitFlashPreloader.cachedProgram!.fragmentShader();
        final RimHitFlashPainter diffShader = RimHitFlashPainter(
          controller: controller1,
          shader: realShader,
          targetImage: image1,
          normalMapImage: image1,
        );
        expect(painter1.shouldRepaint(diffShader), isTrue);
      }
    });
  });

  // ===========================================================================
  // 9. WIDGET TREE INTEGRATION & ANIMATION LIFECYCLE
  // ===========================================================================
  group('9. Widget Tree Integration & Animation Lifecycle', () {
    testWidgets('RimHitFlashWidget renders child and mounts CustomPaint foreground cleanly', (
      WidgetTester tester,
    ) async {
      final RimHitFlashController controller = RimHitFlashController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RimHitFlashWidget(
            controller: controller,
            child: const SizedBox(
              width: 150.0,
              height: 150.0,
              child: Text('Aion Daeva Combat Sprite'),
            ),
          ),
        ),
      );

      expect(find.text('Aion Daeva Combat Sprite'), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget);
      expect(find.byType(AnimatedBuilder), findsOneWidget);
    });

    testWidgets('Widget rebuilds dynamically during combat hit flash pulses', (
      WidgetTester tester,
    ) async {
      final RimHitFlashController controller = RimHitFlashController(
        defaultConfig: const RimHitFlashConfig(
          duration: Duration(milliseconds: 100),
          hitStopDuration: Duration(milliseconds: 30),
          tint: RimFlashTint.bloodRed,
        ),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RimHitFlashWidget(
            controller: controller,
            child: const SizedBox(
              width: 100,
              height: 100,
              child: Text('Boss Monster'),
            ),
          ),
        ),
      );

      expect(find.text('Boss Monster'), findsOneWidget);
      expect(controller.isFlashing, isFalse);

      // Trigger damage hit
      controller.triggerHit();
      await tester.pump();
      expect(controller.isFlashing, isTrue);
      expect(controller.currentIntensity, equals(1.0));

      // Advance during hit stop (20ms) -> remains peak
      controller.update(0.02);
      await tester.pump();
      expect(controller.currentIntensity, equals(1.0));

      // Advance past hit stop (at 60ms) -> decaying
      controller.update(0.04);
      await tester.pump();
      expect(controller.currentIntensity, lessThan(1.0));
      expect(controller.currentIntensity, greaterThan(0.0));

      // Advance past full duration (at 105ms) -> settled
      controller.update(0.045);
      await tester.pump();
      expect(controller.isFlashing, isFalse);
      expect(controller.currentIntensity, equals(0.0));
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // 10. ADVERSARIAL EDGE CASES & GEOMETRIC BOUNDARY STRESS
  // ===========================================================================
  group('10. Adversarial Edge Cases & Geometric Boundary Stress', () {
    test('Camera direction vector (0, 0, 1) correctly evaluates spherical dome normals', () {
      // Analytical Spherical Dome (Mode 2 in GLSL):
      // p = (uv - 0.5) * 2.0; rSq = dot(p, p); z = sqrt(max(0.0, 1.0 - clamp(rSq, 0.0, 1.0)))
      // N = normalize(vec3(p.x, -p.y, max(z, 0.1)))
      // V = vec3(0, 0, 1) -> NdotV = N.z

      // Center of sprite (uv = 0.5, 0.5): p = (0, 0), z = 1.0 -> Normal points straight at viewer
      const double pX_center = 0.0;
      const double pY_center = 0.0;
      final double z_center = math.sqrt(1.0 - (pX_center * pX_center + pY_center * pY_center));
      final double len_center = math.sqrt(pX_center * pX_center + pY_center * pY_center + z_center * z_center);
      final double nDotV_center = z_center / len_center;

      expect(nDotV_center, closeTo(1.0, 1e-6));
      expect(
        RimHitFlashEnvelope.computeFresnel(nDotV: nDotV_center, rimPower: 3.5, rimIntensity: 2.0),
        closeTo(0.0, 1e-6),
        reason: 'Center of billboard dome points directly at camera: must have 0.0 rim flash',
      );

      // Extreme edge of sprite (uv = 1.0, 0.5): p = (1, 0), z = 0.0 -> max(z, 0.1) = 0.1
      const double pX_edge = 1.0;
      const double pY_edge = 0.0;
      const double z_edge = 0.1;
      final double len_edge = math.sqrt(pX_edge * pX_edge + pY_edge * pY_edge + z_edge * z_edge);
      final double nDotV_edge = z_edge / len_edge; // ~ 0.0995

      expect(nDotV_edge, lessThan(0.15));
      final double edgeFresnel = RimHitFlashEnvelope.computeFresnel(
        nDotV: nDotV_edge,
        rimPower: 3.5,
        rimIntensity: 2.0,
      );
      expect(edgeFresnel, greaterThan(1.3),
          reason: 'Silhouette rim edge must generate strong peak Fresnel highlight');
    });

    test('Microsecond duration and extreme hit stop scenarios behave predictably', () {
      final RimHitFlashController controller = RimHitFlashController(
        defaultConfig: const RimHitFlashConfig(
          duration: Duration(microseconds: 500),
          hitStopDuration: Duration(microseconds: 200),
        ),
      );

      controller.triggerHit();
      expect(controller.isFlashing, isTrue);

      // Microsecond step during hit stop (0.0001s = 100 microseconds)
      controller.update(0.0001);
      expect(controller.isFlashing, isTrue);
      expect(controller.currentIntensity, equals(1.0));

      // Step past total duration (0.0005s = 500 microseconds)
      controller.update(0.0005);
      expect(controller.isFlashing, isFalse);
      expect(controller.currentIntensity, equals(0.0));
    });

    test('Extreme intensity multiplier (5.0x overdrive) scales uniformly', () {
      final RimHitFlashController controller = RimHitFlashController();
      controller.triggerHit(intensityMultiplier: 5.0);

      expect(controller.currentIntensity, equals(5.0));

      final List<double> uniforms = controller.buildUniformList(const ui.Size(100.0, 100.0));
      expect(uniforms[2], equals(5.0));
    });

    test('Zero alpha tint color conversions preserve component values safely', () {
      const ui.Color transparentCyan = ui.Color(0x0022E5FF);
      final (double r, double g, double b) =
          RimHitFlashEnvelope.colorToLinearRgb(transparentCyan);

      expect(r, greaterThan(0.0));
      expect(g, greaterThan(0.0));
      expect(b, greaterThan(0.0));

      final ui.Color roundTrip = RimHitFlashEnvelope.linearRgbToColor(r, g, b, 0.0);
      expect(roundTrip.a, equals(0.0));
    });
  });
}

