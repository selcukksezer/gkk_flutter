import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/prison/widgets/prison_cell_painter.dart';

void main() {
  group('PrisonDustMote Simulation & Math Tests', () {
    test('Dust mote initializes with authentic depth tiers and values', () {
      const PrisonDustMote moteFg = PrisonDustMote(
        baseX: 0.5,
        baseY: 0.5,
        radius: 4.5,
        speedY: 0.04,
        amplitudeX: 0.05,
        frequencyX: 1.0,
        phaseX: 0.0,
        baseAlpha: 0.6,
        tier: DustMoteTier.foreground,
      );

      expect(moteFg.tier, equals(DustMoteTier.foreground));
      expect(moteFg.radius, equals(4.5));
      expect(moteFg.baseAlpha, equals(0.6));
    });

    test('Vertical upward drift wraps cleanly across screen boundaries (0..1)', () {
      const PrisonDustMote mote = PrisonDustMote(
        baseX: 0.5,
        baseY: 0.1,
        radius: 2.0,
        speedY: 0.2, // 0.2 units/sec
        amplitudeX: 0.0,
        frequencyX: 0.0,
        phaseX: 0.0,
        baseAlpha: 0.5,
        tier: DustMoteTier.midground,
      );

      const Size size = Size(400.0, 800.0);

      // At t=0, y should be 0.1 * 800 = 80.0
      final Offset pos0 = mote.computePosition(0.0, size);
      expect(pos0.dy, closeTo(80.0, 1e-4));

      // At t=1, y = (0.1 - 0.2) = -0.1 -> wrapped to 0.9 * 800 = 720.0
      final Offset pos1 = mote.computePosition(1.0, size);
      expect(pos1.dy, closeTo(720.0, 1e-4));
      expect(pos1.dy, greaterThanOrEqualTo(0.0));
      expect(pos1.dy, lessThanOrEqualTo(size.height));
    });

    test('Horizontal sway follows organic sinusoidal Brownian drift within amplitude bounds', () {
      const PrisonDustMote mote = PrisonDustMote(
        baseX: 0.5,
        baseY: 0.5,
        radius: 3.0,
        speedY: 0.0,
        amplitudeX: 0.08,
        frequencyX: 2.0,
        phaseX: 0.0,
        baseAlpha: 0.5,
        tier: DustMoteTier.foreground,
      );

      const Size size = Size(500.0, 1000.0);

      for (double t = 0.0; t < 10.0; t += 0.5) {
        final Offset pos = mote.computePosition(t, size);
        final double minX = (0.5 - 0.08) * size.width;
        final double maxX = (0.5 + 0.08) * size.width;

        expect(pos.dx, greaterThanOrEqualTo(minX - 1e-4));
        expect(pos.dx, lessThanOrEqualTo(maxX + 1e-4));
      }
    });

    test('Luminous alpha computation fluctuates gently between valid opacity bounds', () {
      const PrisonDustMote mote = PrisonDustMote(
        baseX: 0.5,
        baseY: 0.5,
        radius: 2.5,
        speedY: 0.03,
        amplitudeX: 0.04,
        frequencyX: 1.0,
        phaseX: 0.0,
        baseAlpha: 0.5,
        tier: DustMoteTier.midground,
        flickerSpeed: 2.5,
        flickerPhase: 0.5,
      );

      for (double t = 0.0; t < 5.0; t += 0.25) {
        final double alpha = mote.computeAlpha(t);
        expect(alpha, greaterThanOrEqualTo(0.0));
        expect(alpha, lessThanOrEqualTo(1.0));
      }
    });

    test('Default motes list contains all three depth tiers with at least 20 motes', () {
      final List<PrisonDustMote> motes = PrisonCellPainter.defaultDustMotes;
      expect(motes.length, greaterThanOrEqualTo(20));

      final Set<DustMoteTier> tiers = motes.map((PrisonDustMote m) => m.tier).toSet();
      expect(tiers, containsAll(<DustMoteTier>[
        DustMoteTier.background,
        DustMoteTier.midground,
        DustMoteTier.foreground,
      ]));
    });
  });

  group('PrisonIronBarConfig & Theme Tests', () {
    test('Default iron bars are symmetrically distributed with valid dimensions', () {
      final List<PrisonIronBarConfig> bars = PrisonCellPainter.defaultIronBars;
      expect(bars.length, greaterThanOrEqualTo(4));

      for (final PrisonIronBarConfig bar in bars) {
        expect(bar.xRatio, greaterThanOrEqualTo(0.0));
        expect(bar.xRatio, lessThanOrEqualTo(1.0));
        expect(bar.barWidth, greaterThan(10.0));
        expect(bar.rivetYFractions, isNotEmpty);
      }

      // Check symmetry of outermost bars
      final double leftMargin = bars.first.xRatio;
      final double rightMargin = 1.0 - bars.last.xRatio;
      expect(leftMargin, closeTo(rightMargin, 0.02));
    });

    test('PrisonCellTheme exposes gothic cold stone and wrought iron palettes', () {
      const PrisonCellTheme theme = PrisonCellTheme.gothicCold;
      expect(theme.wallBaseDark, isNotNull);
      expect(theme.wallBaseMid, isNotNull);
      expect(theme.stoneHighlight, isNotNull);
      expect(theme.mortarGroove, isNotNull);
      expect(theme.ironSpecularBand, isNotNull);
      expect(theme.torchRimWarm, isNotNull);
      expect(theme.dungeonRimCold, isNotNull);
      expect(theme.stoneRimWet, isNotNull);
      expect(theme.brickRowHeight, greaterThan(20.0));
      expect(theme.brickWidth, greaterThan(40.0));
    });
  });

  group('PrisonCellPainter Canvas Rendering Tests', () {
    test('Painter executes paint on standard mobile Canvas without throwing', () {
      final PrisonCellPainter painter = PrisonCellPainter(
        timeSeconds: 2.5,
        isInPrison: true,
        showBars: true,
        showDust: true,
        showBricks: true,
        barsOpacity: 0.85,
      );

      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      const Size size = Size(390.0, 844.0);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('Painter renders cleanly in freedom mode without throwing', () {
      final PrisonCellPainter painter = PrisonCellPainter(
        timeSeconds: 5.0,
        isInPrison: false,
        showBars: false,
        showDust: true,
        showBricks: false,
      );

      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      const Size size = Size(390.0, 844.0);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('shouldRepaint correctly detects property changes', () {
      final PrisonCellPainter painter1 = PrisonCellPainter(timeSeconds: 1.0);
      final PrisonCellPainter painter2 = PrisonCellPainter(timeSeconds: 1.0);
      final PrisonCellPainter painterDifferentTime = PrisonCellPainter(timeSeconds: 1.5);
      final PrisonCellPainter painterDifferentState = PrisonCellPainter(timeSeconds: 1.0, isInPrison: false);

      expect(painter1.shouldRepaint(painter2), isFalse);
      expect(painter1.shouldRepaint(painterDifferentTime), isTrue);
      expect(painter1.shouldRepaint(painterDifferentState), isTrue);
    });

    test('Painter handles zero or negative size gracefully without exceptions', () {
      final PrisonCellPainter painter = PrisonCellPainter(timeSeconds: 1.0);
      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      expect(() => painter.paint(canvas, Size.zero), returnsNormally);
      expect(() => painter.paint(canvas, const Size(-10.0, -10.0)), returnsNormally);
    });
  });

  group('PrisonCellAtmosphere & Foreground Bars Overlay Widget Tests', () {
    testWidgets('PrisonCellAtmosphere mounts and runs 60fps ticker cleanly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390.0,
              height: 844.0,
              child: PrisonCellAtmosphere(
                isInPrison: true,
                showBars: true,
                showDust: true,
                showBricks: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PrisonCellAtmosphere), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Advance frames to confirm animation controller ticks smoothly
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });

    testWidgets('PrisonForegroundBarsOverlay renders with IgnorePointer and correct visibility', (
      WidgetTester tester,
    ) async {
      bool buttonTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390.0,
              height: 844.0,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Center(
                    child: ElevatedButton(
                      onPressed: () => buttonTapped = true,
                      child: const Text('Interactable Button'),
                    ),
                  ),
                  const Positioned.fill(
                    child: PrisonForegroundBarsOverlay(
                      isInPrison: true,
                      barsOpacity: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PrisonForegroundBarsOverlay), findsOneWidget);
      expect(find.byType(IgnorePointer), findsWidgets);

      // Tap through the bars overlay onto the button
      await tester.tap(find.text('Interactable Button'));
      await tester.pump();

      expect(buttonTapped, isTrue);
    });

    testWidgets('PrisonForegroundBarsOverlay renders SizedBox.shrink when not in prison', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390.0,
              height: 844.0,
              child: PrisonForegroundBarsOverlay(
                isInPrison: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsNothing);
    });

    testWidgets('PrisonCellAtmosphere adapts gracefully to tablet landscape dimensions (1024x768)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1024.0,
              height: 768.0,
              child: PrisonCellAtmosphere(
                isInPrison: true,
                showBars: true,
                showDust: true,
                showBricks: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.byType(PrisonCellAtmosphere), findsOneWidget);
    });
  });
}
