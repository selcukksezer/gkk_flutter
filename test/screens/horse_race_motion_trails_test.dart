import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/screens/horse_race/horse_race_provider.dart';
import 'package:gkk_flutter/screens/horse_race/horse_race_utils.dart';
import 'package:gkk_flutter/screens/horse_race/widgets/horse_race_design.dart';

void main() {
  group('Horse Race Motion & Sprint Utilities', () {
    final HorseRaceScript testScript = HorseRaceScript(
      durationMs: 8000,
      finishOrder: const <String>['horse_1', 'horse_2'],
      winnerId: 'horse_1',
      keyframes: const <HorseRaceKeyframe>[
        HorseRaceKeyframe(
          t: 0.0,
          positions: <String, double>{'horse_1': 0.0, 'horse_2': 0.0},
        ),
        HorseRaceKeyframe(
          t: 0.5,
          positions: <String, double>{'horse_1': 0.45, 'horse_2': 0.48},
        ),
        HorseRaceKeyframe(
          t: 0.8,
          positions: <String, double>{'horse_1': 0.78, 'horse_2': 0.72},
        ),
        HorseRaceKeyframe(
          t: 1.0,
          positions: <String, double>{'horse_1': 1.0, 'horse_2': 0.92},
        ),
      ],
    );

    test('HorseSprintTrailPoint stores trajectory metadata correctly', () {
      const HorseSprintTrailPoint point = HorseSprintTrailPoint(
        position: Offset(120, 340),
        progress: 0.65,
        color: Colors.amber,
        speed: 1.25,
        opacity: 0.85,
        width: 8.0,
      );

      expect(point.position.dx, 120);
      expect(point.position.dy, 340);
      expect(point.progress, 0.65);
      expect(point.speed, 1.25);
      expect(point.opacity, 0.85);
      expect(point.width, 8.0);
    });

    test('HorseMotionTrailUtils.createRibbonPath constructs closed ribbon', () {
      final List<Offset> points = <Offset>[
        const Offset(100, 100),
        const Offset(100, 150),
        const Offset(105, 200),
        const Offset(102, 250),
      ];

      final Path ribbon = HorseMotionTrailUtils.createRibbonPath(
        points: points,
        startWidth: 16.0,
        endWidth: 2.0,
      );

      expect(ribbon.getBounds().isEmpty, isFalse);
      expect(ribbon.getBounds().height, greaterThanOrEqualTo(140));
    });

    test('HorseRaceScript velocity and acceleration calculations', () {
      final double vStart = testScript.velocityAt('horse_1', 0.25);
      expect(vStart, greaterThan(0.0));

      final double vClimax = testScript.velocityAt('horse_1', 0.90);
      expect(vClimax, greaterThan(0.0));

      final double accel = testScript.accelerationAt('horse_1', 0.65);
      expect(accel.isFinite, isTrue);

      final bool sprinting = testScript.isSprinting(
        'horse_1',
        0.90,
        speedThreshold: 0.5,
      );
      expect(sprinting, isTrue);
    });

    test('Climax surge factor ramps smoothly on final stretch', () {
      expect(computeClimaxSurgeFactor(0.20), 0.0);
      expect(computeClimaxSurgeFactor(0.70), 0.0);
      expect(computeClimaxSurgeFactor(0.85), greaterThan(0.0));
      expect(computeClimaxSurgeFactor(1.0), closeTo(1.0, 0.01));
    });

    test('Camera shake offset produces directional perturbations during climax', () {
      final Offset noShake = computeCameraShakeOffset(
        progress: 0.40,
        timeSeconds: 1.2,
      );
      expect(noShake, Offset.zero);

      final Offset climaxShake = computeCameraShakeOffset(
        progress: 0.92,
        timeSeconds: 2.4,
        maxIntensity: 6.0,
      );
      expect(climaxShake.dx.abs() + climaxShake.dy.abs(), greaterThan(0.0));
    });

    test('Climax camera surge scale increases during final stretch', () {
      final double normalScale = computeClimaxCameraSurgeScale(progress: 0.5);
      expect(normalScale, 1.0);

      final double surgeScale = computeClimaxCameraSurgeScale(
        progress: 0.95,
        peakSurge: 1.04,
      );
      expect(surgeScale, greaterThan(1.0));
      expect(surgeScale, lessThanOrEqualTo(1.04));
    });

    test('HorseSprintAccelerationTier classifies speed tiers accurately', () {
      expect(
        HorseSprintAccelerationTier.fromSpeedAndProgress(
          speed: 0.95,
          progress: 0.4,
        ),
        HorseSprintAccelerationTier.cruising,
      );

      expect(
        HorseSprintAccelerationTier.fromSpeedAndProgress(
          speed: 1.10,
          progress: 0.5,
        ),
        HorseSprintAccelerationTier.accelerating,
      );

      expect(
        HorseSprintAccelerationTier.fromSpeedAndProgress(
          speed: 1.28,
          progress: 0.7,
        ),
        HorseSprintAccelerationTier.sprinting,
      );

      expect(
        HorseSprintAccelerationTier.fromSpeedAndProgress(
          speed: 1.25,
          progress: 0.88,
          isLeader: true,
        ),
        HorseSprintAccelerationTier.climaxSurge,
      );
    });
  });

  group('Horse Race Motion Visual Widgets', () {
    testWidgets('SpeedLineAccent renders with gradient without errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpeedLineAccent(
              color: HorseRaceDesign.gold,
              width: 80,
              height: 4,
            ),
          ),
        ),
      );

      expect(find.byType(SpeedLineAccent), findsOneWidget);
    });

    testWidgets('HorseSprintAccelerationBadge displays tier label and chevrons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HorseSprintAccelerationBadge(
              tier: HorseSprintAccelerationTier.sprinting,
              speedMultiplier: 1.24,
            ),
          ),
        ),
      );

      expect(find.textContaining('SPRİNT'), findsOneWidget);
      expect(find.textContaining('>>>'), findsOneWidget);
      expect(find.textContaining('1.2x'), findsOneWidget);
    });

    testWidgets('HorseSpeedGaugeBar renders speed level', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HorseSpeedGaugeBar(
              speed: 1.35,
              accent: HorseRaceDesign.gold,
            ),
          ),
        ),
      );

      expect(find.byType(HorseSpeedGaugeBar), findsOneWidget);
    });

    testWidgets('HorseRaceCameraShake transforms child during active climax', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HorseRaceCameraShake(
              progress: 0.95,
              active: true,
              child: Text('Racing Track'),
            ),
          ),
        ),
      );

      expect(find.text('Racing Track'), findsOneWidget);
      expect(find.byType(HorseRaceCameraShake), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Racing Track'), findsOneWidget);
    });

    testWidgets('HorseRaceClimaxSurgeOverlay mounts cleanly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HorseRaceClimaxSurgeOverlay(
              progress: 0.92,
              active: true,
              isFinalStretch: true,
            ),
          ),
        ),
      );

      expect(find.byType(HorseRaceClimaxSurgeOverlay), findsOneWidget);
    });
  });
}
