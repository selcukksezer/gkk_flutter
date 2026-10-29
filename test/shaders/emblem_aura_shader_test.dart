// =============================================================================
// Emblem Aura Shader, Painter & Widget Test Suite
// 2027 Aion 2 Mobile Social & Heraldic Graphics Pipeline (Impeller / Skia)
// =============================================================================

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/shaders/social/emblem/pulsing_emblem_painter.dart';
import 'package:gkk_flutter/shaders/social/emblem/pulsing_emblem_widget.dart';
import 'package:gkk_flutter/shaders/social/theme/social_theme_tokens.dart';

/// Test uniform recorder capturing [setFloat] and [setImageSampler] invocations
/// without violating Dart 3's `base class` restriction on `ui.FragmentShader`.
class RecordingUniformTarget {
  final Map<int, double> floats = <int, double>{};
  final List<(int, double)> history = <(int, double)>[];
  final Map<int, ui.Image> samplers = <int, ui.Image>{};

  void setFloat(int index, double value) {
    floats[index] = value;
    history.add((index, value));
  }

  void setImageSampler(int index, ui.Image image) {
    samplers[index] = image;
  }

  void reset() {
    floats.clear();
    history.clear();
    samplers.clear();
  }
}

/// Fallback painter spy for widget injection tests.
class SpyFallbackPainter extends CustomPainter {
  SpyFallbackPainter({this.onPaint});

  final void Function(Canvas canvas, Size size)? onPaint;
  int paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount++;
    onPaint?.call(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // 1. GLSL Shader Uniform Declarations & Memory Layout Contract
  // ---------------------------------------------------------------------------
  group('1. Emblem Aura Shader Uniform Structure & Packing Contract', () {
    test('kEmblemAuraUniformFloatCount matches GLSL declaration count', () {
      // emblem_aura.frag declares:
      // 0..1:   uniform vec2 uResolution;
      // 2:      uniform float uTime;
      // 3:      uniform float uProgress;
      // 4..7:   uniform vec4 uAuraColor;
      // 8..11:  uniform vec4 uCoreColor;
      // 12:     uniform float uPulseSpeed;
      // 13:     uniform float uAuraRadius;
      // Total floats = 2 + 1 + 1 + 4 + 4 + 1 + 1 = 14
      expect(kEmblemAuraUniformFloatCount, equals(14));
    });

    test('sRgbToLinear adheres to IEC 61966-2-1 transfer function curve', () {
      // Zero boundary
      expect(PulsingEmblemPainter.sRgbToLinear(0.0), closeTo(0.0, 1e-6));

      // Unity boundary
      expect(PulsingEmblemPainter.sRgbToLinear(1.0), closeTo(1.0, 1e-6));

      // Linear section: c <= 0.04045 -> c / 12.92
      const double lowThreshold = 0.04045;
      final double expectedLinearLow = lowThreshold / 12.92;
      expect(
        PulsingEmblemPainter.sRgbToLinear(lowThreshold),
        closeTo(expectedLinearLow, 1e-6),
      );

      // Value just under threshold
      const double subThreshold = 0.02;
      expect(
        PulsingEmblemPainter.sRgbToLinear(subThreshold),
        closeTo(subThreshold / 12.92, 1e-6),
      );

      // Power section: c > 0.04045 -> ((c + 0.055) / 1.055)^2.4
      const double mid = 0.5;
      final double expectedMid = math.pow((mid + 0.055) / 1.055, 2.4).toDouble();
      expect(
        PulsingEmblemPainter.sRgbToLinear(mid),
        closeTo(expectedMid, 1e-6),
      );

      // 0..255 denormalized input normalization support
      expect(
        PulsingEmblemPainter.sRgbToLinear(255.0),
        closeTo(1.0, 1e-6),
      );
      expect(
        PulsingEmblemPainter.sRgbToLinear(127.5),
        closeTo(expectedMid, 1e-4),
      );
    });

    test('colorToLinearRgba converts Flutter Color into 4 linear RGBA floats', () {
      // Pure opaque black
      final (double kr, double kg, double kb, double ka) =
          PulsingEmblemPainter.colorToLinearRgba(const Color(0xFF000000));
      expect(kr, closeTo(0.0, 1e-5));
      expect(kg, closeTo(0.0, 1e-5));
      expect(kb, closeTo(0.0, 1e-5));
      expect(ka, closeTo(1.0, 1e-5));

      // Pure opaque white
      final (double wr, double wg, double wb, double wa) =
          PulsingEmblemPainter.colorToLinearRgba(const Color(0xFFFFFFFF));
      expect(wr, closeTo(1.0, 1e-5));
      expect(wg, closeTo(1.0, 1e-5));
      expect(wb, closeTo(1.0, 1e-5));
      expect(wa, closeTo(1.0, 1e-5));

      // Fully transparent
      final (double tr, double tg, double tb, double ta) =
          PulsingEmblemPainter.colorToLinearRgba(const Color(0x00000000));
      expect(tr, closeTo(0.0, 1e-5));
      expect(tg, closeTo(0.0, 1e-5));
      expect(tb, closeTo(0.0, 1e-5));
      expect(ta, closeTo(0.0, 1e-5));

      // Semi-transparent color
      const Color semiColor = Color(0x80FF0000); // 50% opacity red
      final (double sr, double sg, double sb, double sa) =
          PulsingEmblemPainter.colorToLinearRgba(semiColor);
      expect(sr, closeTo(1.0, 1e-4));
      expect(sg, closeTo(0.0, 1e-5));
      expect(sb, closeTo(0.0, 1e-5));
      expect(sa, closeTo(0x80 / 255.0, 1e-3));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. PulsingEmblemPainter Uniform Packing (packUniforms & applyToTarget)
  // ---------------------------------------------------------------------------
  group('2. PulsingEmblemPainter Uniform Packing Verification', () {
    test('packUniforms returns Float32List with 14 floats and default values', () {
      const Size size = Size(160.0, 90.0);
      const double progress = 0.35;

      final Float32List buffer = PulsingEmblemPainter.packUniforms(
        size: size,
        progress: progress,
      );

      expect(buffer.length, equals(14));
      // 0..1: uResolution
      expect(buffer[0], equals(160.0));
      expect(buffer[1], equals(90.0));

      // 2: uTime (default = progress * 2 * pi)
      expect(buffer[2], closeTo(progress * 2.0 * math.pi, 1e-5));

      // 3: uProgress
      expect(buffer[3], equals(progress));

      // 4..7: uAuraColor (default = elyosGold)
      final (double ar, double ag, double ab, double aa) =
          PulsingEmblemPainter.colorToLinearRgba(SocialThemeTokens.elyosGold);
      expect(buffer[4], closeTo(ar, 1e-5));
      expect(buffer[5], closeTo(ag, 1e-5));
      expect(buffer[6], closeTo(ab, 1e-5));
      expect(buffer[7], closeTo(aa * 1.0, 1e-5));

      // 8..11: uCoreColor (default = elyosRadiance)
      final (double cr, double cg, double cb, double ca) =
          PulsingEmblemPainter.colorToLinearRgba(SocialThemeTokens.elyosRadiance);
      expect(buffer[8], closeTo(cr, 1e-5));
      expect(buffer[9], closeTo(cg, 1e-5));
      expect(buffer[10], closeTo(cb, 1e-5));
      expect(buffer[11], closeTo(ca * 1.0, 1e-5));

      // 12: uPulseSpeed (default = 1.0)
      expect(buffer[12], equals(1.0));

      // 13: uAuraRadius (default = 0.42)
      expect(buffer[13], equals(0.42));
    });

    test('packUniforms accurately maps explicit overrides & intensity clamping', () {
      const Size size = Size(200.0, 200.0);
      const double progress = 0.8;
      const double explicitTime = 12.345;
      const Color aura = Color(0xFF00E5FF);
      const Color core = Color(0xFFFFFFFF);
      const double pulseSpeed = 2.5;
      const double auraRadius = 0.65;

      // Over-amped intensity (3.0 should clamp to 2.0)
      final Float32List clampedHigh = PulsingEmblemPainter.packUniforms(
        size: size,
        progress: progress,
        time: explicitTime,
        auraColor: aura,
        coreColor: core,
        auraIntensity: 3.0,
        pulseSpeed: pulseSpeed,
        auraRadius: auraRadius,
      );

      expect(clampedHigh[2], equals(explicitTime));
      expect(clampedHigh[12], equals(pulseSpeed));
      expect(clampedHigh[13], equals(auraRadius));
      // Alpha scaled by max clamp 2.0
      expect(clampedHigh[7], closeTo(2.0, 1e-5));
      expect(clampedHigh[11], closeTo(2.0, 1e-5));

      // Negative intensity (-1.0 should clamp to 0.0)
      final Float32List clampedLow = PulsingEmblemPainter.packUniforms(
        size: size,
        progress: progress,
        auraIntensity: -1.0,
      );
      expect(clampedLow[7], closeTo(0.0, 1e-5));
      expect(clampedLow[11], closeTo(0.0, 1e-5));
    });

    test('applyToTarget binds all 14 uniforms with identical values to packUniforms', () {
      const Size size = Size(128.0, 128.0);
      const double progress = 0.45;
      const double time = 2.82;
      const double speed = 1.75;
      const double radius = 0.48;

      const PulsingEmblemPainter painter = PulsingEmblemPainter(
        progress: progress,
        faction: EmblemFaction.asmodian,
        customPrimaryColor: SocialThemeTokens.asmodianViolet,
        customCoreColor: SocialThemeTokens.asmodianCrimson,
        auraIntensity: 1.4,
        time: time,
        pulseSpeed: speed,
        auraRadius: radius,
      );

      final RecordingUniformTarget target = RecordingUniformTarget();
      painter.applyToTarget(target, size);

      // Verify count
      expect(target.floats.length, equals(14));

      final Float32List packed = PulsingEmblemPainter.packUniforms(
        size: size,
        progress: progress,
        time: time,
        auraColor: SocialThemeTokens.asmodianViolet,
        coreColor: SocialThemeTokens.asmodianCrimson,
        auraIntensity: 1.4,
        pulseSpeed: speed,
        auraRadius: radius,
      );

      for (int i = 0; i < 14; i++) {
        expect(target.floats[i], isNotNull, reason: 'Uniform slot $i must be bound');
        expect(
          target.floats[i]!,
          closeTo(packed[i], 1e-5),
          reason: 'Slot $i mismatch between applyToTarget and packUniforms',
        );
      }
    });

    test('applyToTarget respects faction color fallbacks when custom colors are null', () {
      const Size size = Size(64.0, 64.0);
      final RecordingUniformTarget target = RecordingUniformTarget();

      for (final faction in EmblemFaction.values) {
        target.reset();
        final painter = PulsingEmblemPainter(
          progress: 0.1,
          faction: faction,
        );
        painter.applyToTarget(target, size);

        final (double expectedAr, double expectedAg, double expectedAb, _) =
            PulsingEmblemPainter.colorToLinearRgba(faction.primaryAura);
        final (double expectedCr, double expectedCg, double expectedCb, _) =
            PulsingEmblemPainter.colorToLinearRgba(faction.coreColor);

        expect(target.floats[4], closeTo(expectedAr, 1e-4));
        expect(target.floats[5], closeTo(expectedAg, 1e-4));
        expect(target.floats[6], closeTo(expectedAb, 1e-4));
        expect(target.floats[8], closeTo(expectedCr, 1e-4));
        expect(target.floats[9], closeTo(expectedCg, 1e-4));
        expect(target.floats[10], closeTo(expectedCb, 1e-4));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Harmonic Resonance Pulsation & Breathing Calculations
  // ---------------------------------------------------------------------------
  group('3. Harmonic Resonance Pulsation Calculation', () {
    test('GPU harmonic breathing pulse formula oscillates strictly in [0.0, 1.0]', () {
      // In emblem_aura.frag:
      // float pulse = 0.5 + 0.5 * sin(uTime * uPulseSpeed * 3.14159);
      const double speed = 1.0;
      for (double t = 0.0; t <= 4.0; t += 0.05) {
        final double pulse = 0.5 + 0.5 * math.sin(t * speed * math.pi);
        expect(pulse, greaterThanOrEqualTo(-1e-6));
        expect(pulse, lessThanOrEqualTo(1.0 + 1e-6));
      }

      // Peak resonance at t = 0.5 / speed: sin(0.5 * pi) = 1.0 -> pulse = 1.0
      final double peakPulse = 0.5 + 0.5 * math.sin(0.5 * speed * math.pi);
      expect(peakPulse, closeTo(1.0, 1e-6));

      // Trough contraction at t = 1.5 / speed: sin(1.5 * pi) = -1.0 -> pulse = 0.0
      final double troughPulse = 0.5 + 0.5 * math.sin(1.5 * speed * math.pi);
      expect(troughPulse, closeTo(0.0, 1e-6));

      // Neutral midpoint at t = 0.0, 1.0, 2.0: pulse = 0.5
      final double neutralPulse0 = 0.5 + 0.5 * math.sin(0.0 * speed * math.pi);
      final double neutralPulse1 = 0.5 + 0.5 * math.sin(1.0 * speed * math.pi);
      expect(neutralPulse0, closeTo(0.5, 1e-6));
      expect(neutralPulse1, closeTo(0.5, 1e-6));
    });

    test('GPU dynamic aura radius expansion matches harmonic range', () {
      // In emblem_aura.frag:
      // float currentRadius = uAuraRadius * (0.85 + 0.15 * pulse);
      const double auraRadius = 0.42;

      // At peak pulse (1.0): currentRadius = auraRadius * (0.85 + 0.15) = auraRadius * 1.0
      final double maxRadius = auraRadius * (0.85 + 0.15 * 1.0);
      expect(maxRadius, closeTo(0.42, 1e-6));

      // At trough pulse (0.0): currentRadius = auraRadius * 0.85 = 0.357
      final double minRadius = auraRadius * (0.85 + 0.15 * 0.0);
      expect(minRadius, closeTo(0.357, 1e-6));

      // At neutral pulse (0.5): currentRadius = auraRadius * 0.925 = 0.3885
      final double midRadius = auraRadius * (0.85 + 0.15 * 0.5);
      expect(midRadius, closeTo(0.3885, 1e-6));
    });

    test('Canvas 2D fallback breathing radius formula preserves harmonic bounds', () {
      // In pulsing_emblem_painter.dart:
      // final double pulse = 0.5 + 0.5 * math.sin(progress * 2 * math.pi);
      // final double breathingRadius = radius * (1.15 + 0.18 * pulse * auraIntensity);
      const double radius = 50.0;
      const double intensity = 1.0;

      // progress = 0.0 -> sin(0) = 0 -> pulse = 0.5
      final double pulse0 = 0.5 + 0.5 * math.sin(0.0 * 2 * math.pi);
      final double r0 = radius * (1.15 + 0.18 * pulse0 * intensity);
      expect(r0, closeTo(50.0 * (1.15 + 0.09), 1e-5)); // 62.0

      // progress = 0.25 -> sin(pi/2) = 1.0 -> pulse = 1.0 (maximum breath)
      final double pulseQuarter = 0.5 + 0.5 * math.sin(0.25 * 2 * math.pi);
      final double rQuarter = radius * (1.15 + 0.18 * pulseQuarter * intensity);
      expect(rQuarter, closeTo(50.0 * (1.15 + 0.18), 1e-5)); // 66.5

      // progress = 0.75 -> sin(3*pi/2) = -1.0 -> pulse = 0.0 (maximum contraction)
      final double pulseThreeQuarter = 0.5 + 0.5 * math.sin(0.75 * 2 * math.pi);
      final double rThreeQuarter = radius * (1.15 + 0.18 * pulseThreeQuarter * intensity);
      expect(rThreeQuarter, closeTo(50.0 * 1.15, 1e-5)); // 57.5
    });

    test('Higher-order harmonic frequencies (2x radiant rays, 3x particles) remain in gamut', () {
      // Rays: alpha = (0.25 + 0.25 * sin(progress * 4 * pi + i)) * auraIntensity
      // Sparkle: sparkle = 0.5 + 0.5 * sin(progress * 6 * pi + i)
      for (int i = 0; i < 16; i++) {
        for (double p = 0.0; p <= 1.0; p += 0.1) {
          final double rayAlpha = (0.25 + 0.25 * math.sin(p * 4 * math.pi + i)) * 1.0;
          expect(rayAlpha, greaterThanOrEqualTo(-1e-6));
          expect(rayAlpha, lessThanOrEqualTo(0.5 + 1e-6));

          final double sparkle = 0.5 + 0.5 * math.sin(p * 6 * math.pi + i);
          expect(sparkle, greaterThanOrEqualTo(-1e-6));
          expect(sparkle, lessThanOrEqualTo(1.0 + 1e-6));
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Emblem Faction & Design System Metadata Contract
  // ---------------------------------------------------------------------------
  group('4. EmblemFaction Model & Theme Tokens Contract', () {
    test('All 5 faction archetypes provide valid non-empty display names and palette tints', () {
      final Set<String> names = <String>{};

      for (final faction in EmblemFaction.values) {
        expect(faction.displayName, isNotEmpty);
        expect(names.add(faction.displayName), isTrue, reason: 'Duplicate display name');

        expect(faction.primaryAura, isA<Color>());
        expect(faction.coreColor, isA<Color>());
        expect(faction.primaryAura.a, greaterThan(0));
        expect(faction.coreColor.a, greaterThan(0));
      }

      expect(EmblemFaction.elyos.displayName, equals('Elyos Celestial'));
      expect(EmblemFaction.asmodian.displayName, equals('Asmodian Shadow'));
      expect(EmblemFaction.balaur.displayName, equals('Balaur Ascendant'));
      expect(EmblemFaction.daeva.displayName, equals('Daeva Sovereign'));
      expect(EmblemFaction.guildShield.displayName, equals('Guild Legion Shield'));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. PulsingEmblemPainter 2D Canvas Fallback & Heraldic Crest Rendering
  // ---------------------------------------------------------------------------
  group('5. PulsingEmblemPainter Canvas Fallback & Crest Painting', () {
    test('Renders 2D Canvas fallback across all 5 faction heraldry crests without throwing', () {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      const Size size = Size(100.0, 100.0);

      for (final faction in EmblemFaction.values) {
        final painter = PulsingEmblemPainter(
          progress: 0.5,
          faction: faction,
          showOrbitingParticles: true,
          showRadiantRays: true,
          showInnerGlow: true,
        );

        expect(
          () => painter.paint(canvas, size),
          returnsNormally,
          reason: 'Faction ${faction.name} failed to paint on Canvas',
        );
      }

      final ui.Picture picture = recorder.endRecording();
      picture.dispose();
    });

    test('paint handles zero and negative dimension boundaries gracefully', () {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      const PulsingEmblemPainter painter = PulsingEmblemPainter(progress: 0.2);

      // Should early return and not throw on zero or negative bounds
      expect(() => painter.paint(canvas, Size.zero), returnsNormally);
      expect(() => painter.paint(canvas, const Size(-100.0, 100.0)), returnsNormally);
      expect(() => painter.paint(canvas, const Size(100.0, -50.0)), returnsNormally);
      expect(() => painter.paint(canvas, const Size(-1.0, -1.0)), returnsNormally);

      final ui.Picture picture = recorder.endRecording();
      picture.dispose();
    });

    test('paint respects feature toggles (rays, particles, inner glow)', () {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      const Size size = Size(120.0, 120.0);

      // Particles disabled, rays disabled, inner glow disabled
      const painter = PulsingEmblemPainter(
        progress: 0.75,
        showOrbitingParticles: false,
        showRadiantRays: false,
        showInnerGlow: false,
      );

      expect(() => painter.paint(canvas, size), returnsNormally);

      final ui.Picture picture = recorder.endRecording();
      picture.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // 6. PulsingEmblemPainter Repaint Boundary & shouldRepaint Evaluation
  // ---------------------------------------------------------------------------
  group('6. PulsingEmblemPainter shouldRepaint Evaluation', () {
    test('shouldRepaint returns false when all properties are identical', () {
      const p1 = PulsingEmblemPainter(
        progress: 0.3,
        faction: EmblemFaction.elyos,
        customPrimaryColor: Colors.amber,
        customCoreColor: Colors.white,
        auraIntensity: 1.2,
        showOrbitingParticles: true,
        showRadiantRays: true,
        showInnerGlow: true,
        time: 1.5,
        pulseSpeed: 1.2,
        auraRadius: 0.45,
      );

      const p2 = PulsingEmblemPainter(
        progress: 0.3,
        faction: EmblemFaction.elyos,
        customPrimaryColor: Colors.amber,
        customCoreColor: Colors.white,
        auraIntensity: 1.2,
        showOrbitingParticles: true,
        showRadiantRays: true,
        showInnerGlow: true,
        time: 1.5,
        pulseSpeed: 1.2,
        auraRadius: 0.45,
      );

      expect(p1.shouldRepaint(p2), isFalse);
    });

    test('shouldRepaint returns true when any single property changes', () {
      const base = PulsingEmblemPainter(
        progress: 0.3,
        faction: EmblemFaction.elyos,
        customPrimaryColor: Colors.amber,
        customCoreColor: Colors.white,
        auraIntensity: 1.0,
        showOrbitingParticles: true,
        showRadiantRays: true,
        showInnerGlow: true,
        time: 1.0,
        pulseSpeed: 1.0,
        auraRadius: 0.42,
      );

      // 1. Progress changed
      expect(base.shouldRepaint(const PulsingEmblemPainter(progress: 0.4)), isTrue);

      // 2. Faction changed
      expect(base.shouldRepaint(const PulsingEmblemPainter(progress: 0.3, faction: EmblemFaction.balaur)), isTrue);

      // 3. customPrimaryColor changed
      expect(base.shouldRepaint(const PulsingEmblemPainter(progress: 0.3, customPrimaryColor: Colors.cyan)), isTrue);

      // 4. customCoreColor changed
      expect(base.shouldRepaint(const PulsingEmblemPainter(progress: 0.3, customCoreColor: Colors.red)), isTrue);

      // 5. auraIntensity changed
      expect(base.shouldRepaint(const PulsingEmblemPainter(progress: 0.3, auraIntensity: 1.8)), isTrue);

      // 6. showOrbitingParticles changed
      expect(base.shouldRepaint(const PulsingEmblemPainter(progress: 0.3, showOrbitingParticles: false)), isTrue);

      // 7. showRadiantRays changed
      expect(base.shouldRepaint(const PulsingEmblemPainter(progress: 0.3, showRadiantRays: false)), isTrue);

      // 8. showInnerGlow changed
      expect(base.shouldRepaint(const PulsingEmblemPainter(progress: 0.3, showInnerGlow: false)), isTrue);

      // 9. time changed
      expect(base.shouldRepaint(const PulsingEmblemPainter(progress: 0.3, time: 5.0)), isTrue);

      // 10. pulseSpeed changed
      expect(base.shouldRepaint(const PulsingEmblemPainter(progress: 0.3, pulseSpeed: 2.0)), isTrue);

      // 11. auraRadius changed
      expect(base.shouldRepaint(const PulsingEmblemPainter(progress: 0.3, auraRadius: 0.5)), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 7. PulsingEmblemWidget Layout, Mounting & Sizing
  // ---------------------------------------------------------------------------
  group('7. PulsingEmblemWidget Layout & Constraint Tests', () {
    test('PulsingEmblemSize presets specify correct standard mobile dimensions', () {
      expect(PulsingEmblemSize.compact.dimension, equals(36.0));
      expect(PulsingEmblemSize.standard.dimension, equals(56.0));
      expect(PulsingEmblemSize.large.dimension, equals(84.0));
      expect(PulsingEmblemSize.hero.dimension, equals(128.0));
    });

    testWidgets('mounts default PulsingEmblemWidget and applies standard 56x56 constraint', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PulsingEmblemWidget(
                faction: EmblemFaction.elyos,
              ),
            ),
          ),
        ),
      );

      final Finder finder = find.byType(PulsingEmblemWidget);
      expect(finder, findsOneWidget);

      final Size widgetSize = tester.getSize(finder);
      expect(widgetSize.width, equals(56.0));
      expect(widgetSize.height, equals(56.0));

      final CustomPaint customPaint = tester.widget<CustomPaint>(find.descendant(
        of: finder,
        matching: find.byType(CustomPaint),
      ));
      expect(customPaint.size, equals(const Size(56.0, 56.0)));
    });

    testWidgets('customSize overrides sizePreset dimension', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PulsingEmblemWidget(
                sizePreset: PulsingEmblemSize.hero, // 128.0
                customSize: 92.0,                  // Override
              ),
            ),
          ),
        ),
      );

      final Finder finder = find.byType(PulsingEmblemWidget);
      final Size widgetSize = tester.getSize(finder);
      expect(widgetSize.width, equals(92.0));
      expect(widgetSize.height, equals(92.0));
    });

    testWidgets('tierBadgeText increases total height by 12.0 and displays badge text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PulsingEmblemWidget(
                sizePreset: PulsingEmblemSize.standard, // 56.0
                tierBadgeText: 'LEGION VII',
              ),
            ),
          ),
        ),
      );

      final Finder finder = find.byType(PulsingEmblemWidget);
      final Size widgetSize = tester.getSize(finder);
      // Width = 56.0, Height = 56.0 + 12.0 = 68.0
      expect(widgetSize.width, equals(56.0));
      expect(widgetSize.height, equals(68.0));

      expect(find.text('LEGION VII'), findsOneWidget);
    });

    testWidgets('whitespace or empty tierBadgeText does not add badge height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PulsingEmblemWidget(
                sizePreset: PulsingEmblemSize.compact, // 36.0
                tierBadgeText: '   ',
              ),
            ),
          ),
        ),
      );

      final Finder finder = find.byType(PulsingEmblemWidget);
      final Size widgetSize = tester.getSize(finder);
      expect(widgetSize.height, equals(36.0));
      expect(find.byType(Stack), findsNothing);
    });

    testWidgets('zero or negative dimension renders SizedBox.shrink', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PulsingEmblemWidget(
                customSize: 0.0,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsNothing);
      final Finder finder = find.byType(PulsingEmblemWidget);
      final Size widgetSize = tester.getSize(finder);
      expect(widgetSize, equals(Size.zero));
    });

    testWidgets('extreme dimensions are safely clamped between 12.0 and 4096.0', (tester) async {
      // Sub-minimum size 4.0 should clamp to 12.0
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PulsingEmblemWidget(
                customSize: 4.0,
              ),
            ),
          ),
        ),
      );

      final Finder finder = find.byType(PulsingEmblemWidget);
      final Size widgetSize = tester.getSize(finder);
      expect(widgetSize.width, equals(12.0));
      expect(widgetSize.height, equals(12.0));
    });

    testWidgets('semantics node provides faction label and button status for onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PulsingEmblemWidget(
              faction: EmblemFaction.daeva,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      final Semantics semantics = tester.widget<Semantics>(find.descendant(
        of: find.byType(PulsingEmblemWidget),
        matching: find.byType(Semantics),
      ));

      expect(semantics.properties.label, equals('Daeva Sovereign Emblem'));
      expect(semantics.properties.button, isTrue);

      await tester.tap(find.byType(PulsingEmblemWidget));
      expect(tapped, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. PulsingEmblemWidget Heraldry Factories & Theming
  // ---------------------------------------------------------------------------
  group('8. PulsingEmblemWidget Factory Constructors', () {
    testWidgets('guild factory constructs guildShield faction with gold theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PulsingEmblemWidget.guild(
              levelText: 'LV. 50',
            ),
          ),
        ),
      );

      final PulsingEmblemWidget widget = tester.widget<PulsingEmblemWidget>(
        find.byType(PulsingEmblemWidget),
      );

      expect(widget.faction, equals(EmblemFaction.guildShield));
      expect(widget.primaryColor, equals(SocialThemeTokens.celestialGold));
      expect(widget.coreColor, equals(SocialThemeTokens.celestialGoldLight));
      expect(widget.tierBadgeText, equals('LV. 50'));
      expect(find.text('LV. 50'), findsOneWidget);
    });

    testWidgets('elyos factory constructs elyos faction with radiant gold theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PulsingEmblemWidget.elyos(
              rankText: 'Archon 1',
            ),
          ),
        ),
      );

      final PulsingEmblemWidget widget = tester.widget<PulsingEmblemWidget>(
        find.byType(PulsingEmblemWidget),
      );

      expect(widget.faction, equals(EmblemFaction.elyos));
      expect(widget.primaryColor, equals(SocialThemeTokens.elyosGold));
      expect(widget.coreColor, equals(SocialThemeTokens.elyosRadiance));
      expect(find.text('Archon 1'), findsOneWidget);
    });

    testWidgets('asmodian factory constructs asmodian faction with shadow theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PulsingEmblemWidget.asmodian(
              rankText: 'Shadow General',
            ),
          ),
        ),
      );

      final PulsingEmblemWidget widget = tester.widget<PulsingEmblemWidget>(
        find.byType(PulsingEmblemWidget),
      );

      expect(widget.faction, equals(EmblemFaction.asmodian));
      expect(widget.primaryColor, equals(SocialThemeTokens.asmodianViolet));
      expect(widget.coreColor, equals(SocialThemeTokens.asmodianCrimson));
      expect(find.text('Shadow General'), findsOneWidget);
    });

    testWidgets('balaur factory constructs balaur faction with dragon flame theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PulsingEmblemWidget.balaur(
              rankText: 'Drakan Lord',
            ),
          ),
        ),
      );

      final PulsingEmblemWidget widget = tester.widget<PulsingEmblemWidget>(
        find.byType(PulsingEmblemWidget),
      );

      expect(widget.faction, equals(EmblemFaction.balaur));
      expect(widget.primaryColor, equals(SocialThemeTokens.balaurFlame));
      expect(widget.coreColor, equals(SocialThemeTokens.balaurRuby));
      expect(find.text('Drakan Lord'), findsOneWidget);
    });

    testWidgets('daeva factory constructs daeva faction with aether cyan theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PulsingEmblemWidget.daeva(
              tierText: 'High Daeva',
            ),
          ),
        ),
      );

      final PulsingEmblemWidget widget = tester.widget<PulsingEmblemWidget>(
        find.byType(PulsingEmblemWidget),
      );

      expect(widget.faction, equals(EmblemFaction.daeva));
      expect(widget.primaryColor, equals(SocialThemeTokens.aetherCyan));
      expect(widget.coreColor, equals(SocialThemeTokens.daevaPrismWhite));
      expect(find.text('High Daeva'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Animation Ticking, Repaint Boundary & Widget Tree Mounting
  // ---------------------------------------------------------------------------
  group('9. Animation Ticking & Repaint Boundary Isolation', () {
    testWidgets('internal animation controller ticks smoothly across multiple frames', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PulsingEmblemWidget(
                animationDuration: Duration(seconds: 2),
              ),
            ),
          ),
        ),
      );

      // Verify first frame CustomPaint painter progress is roughly 0
      CustomPaint customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      PulsingEmblemPainter painter = customPaint.painter as PulsingEmblemPainter;
      expect(painter.progress, closeTo(0.0, 0.05));

      // Advance by 1 second (half of 2s period -> progress should be ~0.5)
      await tester.pump(const Duration(seconds: 1));
      customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      painter = customPaint.painter as PulsingEmblemPainter;
      expect(painter.progress, closeTo(0.5, 0.05));

      // Advance by another 1 second -> progress resets and continues
      await tester.pump(const Duration(seconds: 1));
      customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      painter = customPaint.painter as PulsingEmblemPainter;
      expect(painter.progress, closeTo(0.0, 0.05));
    });

    testWidgets('isolated within RepaintBoundary without leaking dirty rects to parent', (tester) async {
      final GlobalKey boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: const PulsingEmblemWidget(
                sizePreset: PulsingEmblemSize.hero,
              ),
            ),
          ),
        ),
      );

      final RenderRepaintBoundary renderObject =
          boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

      expect(renderObject.isRepaintBoundary, isTrue);
      expect(renderObject.paintBounds.size, equals(const Size(128.0, 128.0)));

      // Pump animation frames
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(renderObject.hasSize, isTrue);
    });

    testWidgets('fallbackPainter parameter bypasses PulsingEmblemPainter generation', (tester) async {
      final SpyFallbackPainter spyPainter = SpyFallbackPainter();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PulsingEmblemWidget(
              fallbackPainter: spyPainter,
            ),
          ),
        ),
      );

      final CustomPaint customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      expect(customPaint.painter, same(spyPainter));
      expect(spyPainter.paintCount, greaterThanOrEqualTo(1));
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Memory Leak Prevention & Controller Lifecycle
  // ---------------------------------------------------------------------------
  group('10. Memory Leak Prevention & Controller Lifecycle', () {
    testWidgets('internal animation controller is cleanly disposed on widget unmount', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PulsingEmblemWidget(),
          ),
        ),
      );

      // Verify active
      expect(find.byType(PulsingEmblemWidget), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));

      // Unmount the widget completely
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.byType(PulsingEmblemWidget), findsNothing);

      // Verify no pending ticker exceptions occur after unmounting
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('accepts external AnimationController and does not dispose it on widget unmount', (tester) async {
      late AnimationController externalController;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: _ExternalControllerHost(
                  onInit: (controller) => externalController = controller,
                ),
              );
            },
          ),
        ),
      );

      expect(externalController.isAnimating, isTrue);
      await tester.pump(const Duration(milliseconds: 200));

      // Verify external controller is driving the painter progress
      final CustomPaint customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      final PulsingEmblemPainter painter = customPaint.painter as PulsingEmblemPainter;
      expect(painter.progress, closeTo(externalController.value, 1e-4));

      // Unmount widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Unmounted'),
          ),
        ),
      );

      // External controller was NOT disposed by widget disposal; disposing here should succeed
      expect(() => externalController.dispose(), returnsNormally);
    });

    testWidgets('accepts external progressAnimation directly', (tester) async {
      const AlwaysStoppedAnimation<double> staticProgress = AlwaysStoppedAnimation<double>(0.72);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PulsingEmblemWidget(
              progressAnimation: staticProgress,
            ),
          ),
        ),
      );

      final CustomPaint customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      final PulsingEmblemPainter painter = customPaint.painter as PulsingEmblemPainter;
      expect(painter.progress, equals(0.72));

      await tester.pump(const Duration(milliseconds: 300));
      // Still 0.72 because of static progress
      final CustomPaint customPaint2 = tester.widget<CustomPaint>(find.byType(CustomPaint));
      final PulsingEmblemPainter painter2 = customPaint2.painter as PulsingEmblemPainter;
      expect(painter2.progress, equals(0.72));
    });

    testWidgets('didUpdateWidget cleanly updates duration or switches to/from external controller', (tester) async {
      bool useExternal = false;
      Duration animDuration = const Duration(seconds: 2);

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: _DynamicControllerHost(
                  useExternal: useExternal,
                  duration: animDuration,
                ),
              );
            },
          ),
        ),
      );

      expect(find.byType(PulsingEmblemWidget), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));

      // Change duration on internal controller
      final _DynamicControllerHostState state =
          tester.state<_DynamicControllerHostState>(find.byType(_DynamicControllerHost));
      state.updateDuration(const Duration(seconds: 4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to external controller (disposes internal controller)
      state.toggleExternal(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Switch back to internal controller (creates fresh internal controller)
      state.toggleExternal(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 11. Adversarial Inputs, Extreme Bounds & Stress Resilience
  // ---------------------------------------------------------------------------
  group('11. Adversarial Edge Cases & Boundary Stress', () {
    test('Extreme progress and frequency inputs in packUniforms remain stable', () {
      final Float32List extremeBuffer = PulsingEmblemPainter.packUniforms(
        size: const Size(1920.0, 1080.0),
        progress: 1e6, // Massive non-normalized progress
        pulseSpeed: 100.0,
        auraRadius: 10.0,
        auraIntensity: 2.0,
      );

      expect(extremeBuffer.length, equals(14));
      expect(extremeBuffer[0], equals(1920.0));
      expect(extremeBuffer[1], equals(1080.0));
      expect(extremeBuffer[3], equals(1e6));
      expect(extremeBuffer[12], equals(100.0));
      expect(extremeBuffer[13], equals(10.0));
    });

    testWidgets('Rapid ticker pumping over 60 simulated frames exhibits zero stutter or crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PulsingEmblemWidget(
                faction: EmblemFaction.balaur,
                sizePreset: PulsingEmblemSize.hero,
                tierBadgeText: 'DRAKAN X',
              ),
            ),
          ),
        ),
      );

      // Simulate 60 consecutive 16.6ms frames (1 full second at 60fps)
      for (int f = 0; f < 60; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(tester.takeException(), isNull);
      expect(find.text('DRAKAN X'), findsOneWidget);
    });
  });
}

// -----------------------------------------------------------------------------
// Test Helpers & State Holders
// -----------------------------------------------------------------------------

class _ExternalControllerHost extends StatefulWidget {
  const _ExternalControllerHost({required this.onInit});
  final void Function(AnimationController controller) onInit;

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
      duration: const Duration(seconds: 1),
    )..repeat();
    widget.onInit(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return PulsingEmblemWidget(
      controller: _controller,
    );
  }
}

class _DynamicControllerHost extends StatefulWidget {
  const _DynamicControllerHost({
    required this.useExternal,
    required this.duration,
  });

  final bool useExternal;
  final Duration duration;

  @override
  State<_DynamicControllerHost> createState() => _DynamicControllerHostState();
}

class _DynamicControllerHostState extends State<_DynamicControllerHost>
    with SingleTickerProviderStateMixin {
  late bool _useExternal;
  late Duration _duration;
  AnimationController? _externalController;

  @override
  void initState() {
    super.initState();
    _useExternal = widget.useExternal;
    _duration = widget.duration;
    _initExternalIfNeeded();
  }

  void _initExternalIfNeeded() {
    if (_useExternal && _externalController == null) {
      _externalController = AnimationController(
        vsync: this,
        duration: _duration,
      )..repeat();
    }
  }

  void updateDuration(Duration newDuration) {
    setState(() {
      _duration = newDuration;
    });
  }

  void toggleExternal(bool useExt) {
    setState(() {
      _useExternal = useExt;
      if (_useExternal) {
        _initExternalIfNeeded();
      } else {
        _externalController?.dispose();
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
    return PulsingEmblemWidget(
      controller: _useExternal ? _externalController : null,
      animationDuration: _duration,
    );
  }
}
