import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/horse_race/horse_race_live_view.dart';
import 'package:gkk_flutter/screens/horse_race/horse_race_provider.dart';
import 'package:gkk_flutter/screens/horse_race/horse_race_track_painter.dart';

void main() {
  group('HorseRaceTrackLayout Tests', () {
    test('computes track rect with correct rail margins', () {
      const Size size = Size(400, 800);
      final Rect track = HorseRaceTrackLayout.trackRect(size);

      expect(track.left, 400 * HorseRaceTrackLayout.leftRailFraction);
      expect(track.width, 400 * (1.0 - HorseRaceTrackLayout.leftRailFraction - HorseRaceTrackLayout.rightRailFraction));
      expect(track.top, 0);
      expect(track.height, 800);
    });

    test('computes lane width and center correctly for various lane counts', () {
      const Size size = Size(400, 800);
      final Rect track = HorseRaceTrackLayout.trackRect(size);

      for (final int laneCount in <int>[4, 6, 8]) {
        final double width = HorseRaceTrackLayout.laneWidth(size, laneCount);
        expect(width, closeTo(track.width / laneCount, 0.001));

        for (int i = 0; i < laneCount; i++) {
          final double center = HorseRaceTrackLayout.laneCenterX(size, i, laneCount);
          expect(center, closeTo(track.left + width * (i + 0.5), 0.001));
        }
      }
    });

    test('computes horseY for start (0.0) and finish (1.0)', () {
      const Size size = Size(400, 800);
      final double startY = HorseRaceTrackLayout.horseY(size, 0.0);
      final double finishY = HorseRaceTrackLayout.horseY(size, 1.0);
      final double midY = HorseRaceTrackLayout.horseY(size, 0.5);

      expect(startY, 800 * HorseRaceTrackLayout.trackStartY);
      expect(finishY, 800 * HorseRaceTrackLayout.trackEndY);
      expect(midY, (startY + finishY) * 0.5);
      expect(finishY, lessThan(startY)); // Progress moves bottom -> top
    });

    test('computes horseSize based on lane count tiers', () {
      expect(HorseRaceTrackLayout.horseSize(3), 52);
      expect(HorseRaceTrackLayout.horseSize(5), 44);
      expect(HorseRaceTrackLayout.horseSize(8), 38);
    });
  });

  group('HorseRaceTrackPainter Rendering Tests', () {
    test('paints all layers without exceptions at various race phases', () {
      final List<Color> colors = <Color>[
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.yellow,
        Colors.purple,
        Colors.orange,
      ];

      // Phase 1: Start gate closed
      final HorseRaceTrackPainter painterStart = HorseRaceTrackPainter(
        laneCount: 6,
        laneColors: colors,
        scrollOffset: 0,
        raceProgress: 0,
        gateOpen: false,
        finalStretch: false,
        showSpeedLines: false,
        horsePositions: const <double>[0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      );

      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      const Size size = Size(390, 700);

      expect(() => painterStart.paint(canvas, size), returnsNormally);

      // Phase 2: Mid race with speed lines
      final HorseRaceTrackPainter painterMid = HorseRaceTrackPainter(
        laneCount: 6,
        laneColors: colors,
        scrollOffset: 120,
        raceProgress: 0.5,
        gateOpen: true,
        finalStretch: false,
        showSpeedLines: true,
        horsePositions: const <double>[0.52, 0.48, 0.55, 0.46, 0.50, 0.49],
      );
      expect(() => painterMid.paint(canvas, size), returnsNormally);

      // Phase 3: Final stretch and finish line bloom
      final HorseRaceTrackPainter painterFinish = HorseRaceTrackPainter(
        laneCount: 6,
        laneColors: colors,
        scrollOffset: 380,
        raceProgress: 0.95,
        gateOpen: true,
        finalStretch: true,
        showSpeedLines: true,
        horsePositions: const <double>[0.96, 0.92, 0.94, 0.88, 0.90, 0.89],
      );
      expect(() => painterFinish.paint(canvas, size), returnsNormally);
    });

    test('shouldRepaint returns true on any visual property change', () {
      final List<Color> colors = <Color>[Colors.red, Colors.blue];
      final HorseRaceTrackPainter base = HorseRaceTrackPainter(
        laneCount: 2,
        laneColors: colors,
        scrollOffset: 0,
        raceProgress: 0,
        gateOpen: false,
        finalStretch: false,
        showSpeedLines: false,
      );

      expect(base.shouldRepaint(base), isFalse);

      expect(
        base.shouldRepaint(
          HorseRaceTrackPainter(
            laneCount: 2,
            laneColors: colors,
            scrollOffset: 10,
            raceProgress: 0,
            gateOpen: false,
            finalStretch: false,
            showSpeedLines: false,
          ),
        ),
        isTrue,
      );

      expect(
        base.shouldRepaint(
          HorseRaceTrackPainter(
            laneCount: 2,
            laneColors: colors,
            scrollOffset: 0,
            raceProgress: 0.1,
            gateOpen: false,
            finalStretch: false,
            showSpeedLines: false,
          ),
        ),
        isTrue,
      );

      expect(
        base.shouldRepaint(
          HorseRaceTrackPainter(
            laneCount: 2,
            laneColors: colors,
            scrollOffset: 0,
            raceProgress: 0,
            gateOpen: true,
            finalStretch: false,
            showSpeedLines: false,
          ),
        ),
        isTrue,
      );

      expect(
        base.shouldRepaint(
          HorseRaceTrackPainter(
            laneCount: 2,
            laneColors: colors,
            scrollOffset: 0,
            raceProgress: 0,
            gateOpen: false,
            finalStretch: true,
            showSpeedLines: false,
          ),
        ),
        isTrue,
      );

      expect(
        base.shouldRepaint(
          HorseRaceTrackPainter(
            laneCount: 2,
            laneColors: colors,
            scrollOffset: 0,
            raceProgress: 0,
            gateOpen: false,
            finalStretch: false,
            showSpeedLines: true,
          ),
        ),
        isTrue,
      );

      expect(
        base.shouldRepaint(
          HorseRaceTrackPainter(
            laneCount: 2,
            laneColors: colors,
            scrollOffset: 0,
            raceProgress: 0,
            gateOpen: false,
            finalStretch: false,
            showSpeedLines: false,
            horsePositions: const <double>[0.1, 0.2],
          ),
        ),
        isTrue,
      );
    });
  });

  group('HorseRaceLiveView Widget Tests', () {
    testWidgets('renders track painter, starting countdown, and horse cards', (WidgetTester tester) async {
      final List<HorseRaceEntry> horses = <HorseRaceEntry>[
        const HorseRaceEntry(
          horseId: 'h1',
          name: 'Fırtına',
          emoji: '⚡',
          laneColor: '#FFD700',
          goldMultiplier: 2.5,
          gemMultiplier: 2.5,
          winChancePct: 35.0,
          sortOrder: 1,
        ),
        const HorseRaceEntry(
          horseId: 'h2',
          name: 'Poyraz',
          emoji: '🌪️',
          laneColor: '#00FFFF',
          goldMultiplier: 3.2,
          gemMultiplier: 3.2,
          winChancePct: 28.0,
          sortOrder: 2,
        ),
        const HorseRaceEntry(
          horseId: 'h3',
          name: 'Gölge',
          emoji: '🌑',
          laneColor: '#FF0055',
          goldMultiplier: 4.0,
          gemMultiplier: 4.0,
          winChancePct: 20.0,
          sortOrder: 3,
        ),
      ];

      final HorseRaceScript script = const HorseRaceScript(
        durationMs: 4000,
        finishOrder: <String>['h1', 'h2', 'h3'],
        winnerId: 'h1',
        keyframes: <HorseRaceKeyframe>[
          HorseRaceKeyframe(t: 0.0, positions: <String, double>{'h1': 0.0, 'h2': 0.0, 'h3': 0.0}),
          HorseRaceKeyframe(t: 0.5, positions: <String, double>{'h1': 0.55, 'h2': 0.50, 'h3': 0.45}),
          HorseRaceKeyframe(t: 1.0, positions: <String, double>{'h1': 1.0, 'h2': 0.95, 'h3': 0.90}),
        ],
      );

      bool finished = false;

      await tester.pumpWidget(
        MaterialApp(
          home: HorseRaceLiveView(
            horses: horses,
            raceScript: script,
            winnerHorseId: 'h1',
            onFinished: () => finished = true,
          ),
        ),
      );

      expect(find.text('START KAPISI'), findsOneWidget);
      expect(find.text('Fırtına'), findsWidgets);
      expect(find.text('Poyraz'), findsWidgets);
      expect(find.text('Gölge'), findsWidgets);
      expect(find.byType(CustomPaint), findsWidgets);

      // Countdown advances
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      // Race is now started
      await tester.pump(const Duration(milliseconds: 1000));
      expect(finished, isFalse);
    });
  });
}
