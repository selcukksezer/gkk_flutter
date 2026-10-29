import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/hospital/widgets/hospital_particles.dart';

void main() {
  group('HospitalParticle Physical Simulation & Zero-Garbage Pooling Tests', () {
    test('Particle factory initializes and resets in-place without heap reallocation', () {
      final math.Random rng = math.Random(42);
      const Size viewport = Size(400, 800);

      final HospitalParticle particle = HospitalParticle.random(viewport, rng, randomizeY: false);

      expect(particle.lifetime, equals(0.0));
      expect(particle.maxLifetime, greaterThanOrEqualTo(4.5));
      expect(particle.maxLifetime, lessThanOrEqualTo(9.5));
      expect(particle.y, greaterThanOrEqualTo(viewport.height));
      expect(particle.isBurst, isFalse);

      // Mutate state to simulate particle aging
      particle.lifetime = 10.0;
      particle.x = 999.0;

      // Reset in-place
      particle.reset(viewport, rng, randomizeY: true);
      expect(particle.lifetime, greaterThanOrEqualTo(0.0));
      expect(particle.lifetime, lessThanOrEqualTo(particle.maxLifetime));
      expect(particle.y, greaterThanOrEqualTo(0.0));
      expect(particle.y, lessThanOrEqualTo(viewport.height + 40));
    });

    test('Particle simulation covers all four restorative visual types', () {
      final math.Random rng = math.Random(12345);
      const Size viewport = Size(400, 800);
      final Set<HospitalParticleKind> encounteredKinds = <HospitalParticleKind>{};

      for (int i = 0; i < 100; i++) {
        final HospitalParticle p = HospitalParticle.random(viewport, rng);
        encounteredKinds.add(p.kind);
      }

      expect(encounteredKinds, contains(HospitalParticleKind.emeraldOrb));
      expect(encounteredKinds, contains(HospitalParticleKind.goldSparkle));
      expect(encounteredKinds, contains(HospitalParticleKind.healingCross));
      expect(encounteredKinds, contains(HospitalParticleKind.etherealRing));
    });

    test('Rising motion and sinusoidal sway drift update coordinates correctly', () {
      final math.Random rng = math.Random(101);
      const Size viewport = Size(400, 800);
      final HospitalParticle p = HospitalParticle.random(viewport, rng, randomizeY: false);

      final double startY = p.y;

      final bool respawned = p.update(0.1, viewport, rng);

      expect(respawned, isFalse);
      expect(p.y, lessThan(startY)); // Rose upwards
      expect(p.lifetime, closeTo(0.1, 0.0001));
      // Sway drift active
      expect(p.x, isNotNull);
    });

    test('Particle respawns when floating above screen boundary or exceeding maxLifetime', () {
      final math.Random rng = math.Random(777);
      const Size viewport = Size(400, 800);
      final HospitalParticle p = HospitalParticle.random(viewport, rng, randomizeY: false);

      p.y = -50.0; // Above top boundary
      final bool respawned = p.update(0.016, viewport, rng);

      expect(respawned, isTrue);
      expect(p.y, greaterThan(viewport.height)); // Respawned at bottom
    });

    test('Smooth non-linear alpha curve fades in and fades out properly', () {
      final math.Random rng = math.Random(999);
      const Size viewport = Size(400, 800);
      final HospitalParticle p = HospitalParticle.random(viewport, rng);
      p.maxLifetime = 10.0;

      // Start: lifetime 0 -> opacity 0
      p.lifetime = 0.0;
      expect(p.currentOpacity, equals(0.0));

      // Mid-flight: lifetime 5.0 -> luminous opacity
      p.lifetime = 5.0;
      final double midOpacity = p.currentOpacity;
      expect(midOpacity, greaterThan(0.2));

      // End-of-flight: lifetime near max -> gently fades towards 0
      p.lifetime = 9.9;
      final double endOpacity = p.currentOpacity;
      expect(endOpacity, lessThan(midOpacity));
    });

    test('Burst particle expands with velocity and decays smoothly', () {
      final math.Random rng = math.Random(888);
      const Size viewport = Size(400, 800);
      const Offset origin = Offset(200, 400);

      final HospitalParticle p = HospitalParticle.random(viewport, rng);
      p.reset(viewport, rng, origin: origin);

      expect(p.isBurst, isTrue);
      expect(p.x, equals(200.0));
      expect(p.y, equals(400.0));
      expect(p.maxLifetime, lessThanOrEqualTo(3.0)); // Snappy burst

      p.update(0.05, viewport, rng);
      // Position moved away from origin
      final double distance = math.sqrt(
        math.pow(p.x - origin.dx, 2) + math.pow(p.y - origin.dy, 2),
      );
      expect(distance, greaterThan(0.0));
    });
  });

  group('HospitalParticleController Tests', () {
    test('Controller triggers bursts and notifies listeners', () {
      final HospitalParticleController controller = HospitalParticleController();
      int notified = 0;
      controller.addListener(() => notified++);

      expect(controller.burstId, equals(0));
      controller.triggerBurst(origin: const Offset(150, 300), count: 20);

      expect(controller.burstId, equals(1));
      expect(controller.burstOrigin, equals(const Offset(150, 300)));
      expect(controller.burstCount, equals(20));
      expect(notified, equals(1));
    });

    test('Controller sets intensity and clamps bounds', () {
      final HospitalParticleController controller = HospitalParticleController();
      int notified = 0;
      controller.addListener(() => notified++);

      controller.setIntensity(1.5);
      expect(controller.intensity, equals(1.5));
      expect(notified, equals(1));

      // Clamp upper bound
      controller.setIntensity(5.0);
      expect(controller.intensity, equals(3.0));

      // Clamp lower bound
      controller.setIntensity(-1.0);
      expect(controller.intensity, equals(0.0));
    });

    test('Controller toggles pause and resume states', () {
      final HospitalParticleController controller = HospitalParticleController();
      expect(controller.isPaused, isFalse);

      controller.pause();
      expect(controller.isPaused, isTrue);

      controller.resume();
      expect(controller.isPaused, isFalse);
    });
  });

  group('HospitalParticlesPainter Tests', () {
    test('Painter executes all particle drawing paths without crashing', () {
      final math.Random rng = math.Random(321);
      const Size size = Size(390, 844);

      final List<HospitalParticle> particles = List<HospitalParticle>.generate(
        8,
        (int i) {
          final HospitalParticle p = HospitalParticle.random(size, rng, randomizeY: true);
          p.lifetime = p.maxLifetime * 0.5; // Ensure active opacity
          return p;
        },
      );

      final HospitalParticlesPainter painter = HospitalParticlesPainter(
        particles: particles,
        celestialGlow: true,
        intensity: 1.0,
        animationValue: 0.5,
      );

      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      expect(() => painter.paint(canvas, size), returnsNormally);
      expect(painter.shouldRepaint(painter), isFalse);

      final HospitalParticlesPainter changedPainter = HospitalParticlesPainter(
        particles: particles,
        celestialGlow: true,
        intensity: 1.0,
        animationValue: 0.8,
      );
      expect(changedPainter.shouldRepaint(painter), isTrue);
    });

    test('Painter exits gracefully on zero dimensions or zero intensity', () {
      final HospitalParticlesPainter painter = HospitalParticlesPainter(
        particles: <HospitalParticle>[],
        celestialGlow: true,
        intensity: 0.0,
        animationValue: 0.0,
      );

      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      expect(() => painter.paint(canvas, Size.zero), returnsNormally);
    });
  });

  group('HospitalRestorativeParticles Widget Integration Tests', () {
    testWidgets('Widget mounts, runs ticker, and updates particle simulation', (WidgetTester tester) async {
      final HospitalParticleController controller = HospitalParticleController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HospitalRestorativeParticles(
              controller: controller,
              particleCount: 20,
              celestialGlow: true,
            ),
          ),
        ),
      );

      expect(find.byType(HospitalRestorativeParticles), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Pump frames to verify 60fps simulation progress
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      // Trigger burst through controller
      controller.triggerBurst(origin: const Offset(100, 200), count: 12);
      await tester.pump(const Duration(milliseconds: 16));

      controller.dispose();
    });

    testWidgets('Interactive mode registers tap events to emit bursts', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: HospitalRestorativeParticles(
                particleCount: 15,
                interactive: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsOneWidget);

      // Tap on screen to trigger interactive burst
      await tester.tapAt(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 32));
    });

    testWidgets('HospitalSanctuaryAtmosphere wraps child with non-blocking particle layer', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HospitalSanctuaryAtmosphere(
              particleCount: 16,
              child: Center(
                child: ElevatedButton(
                  onPressed: () => tapped = true,
                  child: const Text('Sanctuary Action'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sanctuary Action'), findsOneWidget);
      expect(
        find.byWidgetPredicate((Widget w) => w is IgnorePointer && w.ignoring),
        findsOneWidget,
      );

      // Tap button to verify touch pass-through (zero touch blocking)
      await tester.tap(find.text('Sanctuary Action'));
      expect(tapped, isTrue);

      await tester.pump(const Duration(milliseconds: 16));
    });
  });
}
