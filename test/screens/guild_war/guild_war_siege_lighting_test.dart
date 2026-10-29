import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/guild_war/guild_war_siege_lighting.dart';

void main() {
  group('SiegeVector2 Math Operations', () {
    test('Vector arithmetic, length, and normalization', () {
      const SiegeVector2 v1 = SiegeVector2(3.0, 4.0);
      expect(v1.length, closeTo(5.0, 1e-6));
      expect(v1.lengthSquared, closeTo(25.0, 1e-6));

      final SiegeVector2 norm = v1.normalized();
      expect(norm.length, closeTo(1.0, 1e-6));
      expect(norm.x, closeTo(0.6, 1e-6));
      expect(norm.y, closeTo(0.8, 1e-6));

      const SiegeVector2 v2 = SiegeVector2(1.0, 2.0);
      final SiegeVector2 sum = v1 + v2;
      expect(sum.x, closeTo(4.0, 1e-6));
      expect(sum.y, closeTo(6.0, 1e-6));

      final SiegeVector2 diff = v1 - v2;
      expect(diff.x, closeTo(2.0, 1e-6));
      expect(diff.y, closeTo(2.0, 1e-6));

      final SiegeVector2 scaled = v1 * 2.0;
      expect(scaled.x, closeTo(6.0, 1e-6));
      expect(scaled.y, closeTo(8.0, 1e-6));

      final SiegeVector2 divided = v1 / 2.0;
      expect(divided.x, closeTo(1.5, 1e-6));
      expect(divided.y, closeTo(2.0, 1e-6));

      final SiegeVector2 neg = -v1;
      expect(neg.x, closeTo(-3.0, 1e-6));
      expect(neg.y, closeTo(-4.0, 1e-6));
    });

    test('Distance, dot product, and lerp calculations', () {
      const SiegeVector2 a = SiegeVector2(10.0, 20.0);
      const SiegeVector2 b = SiegeVector2(10.0, 50.0);

      expect(a.distanceTo(b), closeTo(30.0, 1e-6));
      expect(a.distanceSquaredTo(b), closeTo(900.0, 1e-6));

      const SiegeVector2 u = SiegeVector2(1.0, 0.0);
      const SiegeVector2 v = SiegeVector2(0.0, 1.0);
      expect(u.dot(v), closeTo(0.0, 1e-6)); // Perpendicular vectors dot is zero

      final SiegeVector2 mid = a.lerp(b, 0.5);
      expect(mid.x, closeTo(10.0, 1e-6));
      expect(mid.y, closeTo(35.0, 1e-6));

      final Offset off = a.toOffset();
      expect(off.dx, closeTo(10.0, 1e-6));
      expect(off.dy, closeTo(20.0, 1e-6));
    });

    test('Equality and hash code parity', () {
      const SiegeVector2 v1 = SiegeVector2(12.34, 56.78);
      const SiegeVector2 v2 = SiegeVector2(12.34, 56.78);
      const SiegeVector2 v3 = SiegeVector2(99.0, 1.0);

      expect(v1, equals(v2));
      expect(v1.hashCode, equals(v2.hashCode));
      expect(v1 == v3, isFalse);
    });
  });

  group('SiegeLightSource & Windowed Inverse-Square Attenuation', () {
    test('Throws assertion error if radius is non-positive', () {
      expect(
        () => SiegeLightSource(
          id: 'invalid_radius',
          position: const SiegeVector2(0, 0),
          radius: 0.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Multi-harmonic flicker stays clamped within physical range', () {
      final SiegeLightSource light = SiegeLightSource(
        id: 'torch_1',
        position: const SiegeVector2(50, 50),
        radius: 100.0,
        intensity: 1.5,
        flickerAmount: 0.3,
        flickerRate: 5.0,
      );

      for (double t = 0.0; t <= 10.0; t += 0.1) {
        final double flickered = light.evaluateFlicker(t);
        expect(flickered, greaterThanOrEqualTo(0.0));
        expect(flickered, lessThanOrEqualTo(1.5 * 2.5));
      }
    });

    test('Zero flickerAmount returns exact base intensity', () {
      final SiegeLightSource light = SiegeLightSource(
        id: 'steady_light',
        position: const SiegeVector2(0, 0),
        radius: 50.0,
        intensity: 2.0,
        flickerAmount: 0.0,
      );

      expect(light.evaluateFlicker(1.234), equals(2.0));
    });

    test('Attenuation strictly drops to 0.0 at dist >= radius', () {
      final SiegeLightSource light = SiegeLightSource(
        id: 'test_light',
        position: const SiegeVector2(100, 100),
        radius: 80.0,
      );

      // Within radius
      final double attNear = light.evaluateAttenuation(const SiegeVector2(100, 110));
      expect(attNear, greaterThan(0.0));

      // At boundary
      final double attBound = light.evaluateAttenuation(const SiegeVector2(100, 180));
      expect(attBound, closeTo(0.0, 1e-6));

      // Outside radius
      final double attFar = light.evaluateAttenuation(const SiegeVector2(100, 220));
      expect(attFar, equals(0.0));
    });

    test('Attenuation decreases monotonically with distance', () {
      final SiegeLightSource light = SiegeLightSource(
        id: 'decay_light',
        position: const SiegeVector2(0, 0),
        radius: 100.0,
      );

      double prevAtt = light.evaluateAttenuation(const SiegeVector2(0, 0));
      for (double d = 10.0; d < 100.0; d += 10.0) {
        final double att = light.evaluateAttenuation(SiegeVector2(d, 0));
        expect(att, lessThan(prevAtt));
        prevAtt = att;
      }
    });
  });

  group('FortressShadowCaster & Dynamic Perimeter Projection', () {
    test('Calculates perpendicular wall normal', () {
      final FortressShadowCaster wall = FortressShadowCaster(
        id: 'horizontal_wall',
        start: const SiegeVector2(0.0, 100.0),
        end: const SiegeVector2(50.0, 100.0),
      );

      final SiegeVector2 norm = wall.normal;
      expect(norm.length, closeTo(1.0, 1e-6));
      expect(norm.x, closeTo(0.0, 1e-6));
      expect(norm.y, closeTo(1.0, 1e-6));
    });

    test('Projects 4-point shadow polygon directed away from light source', () {
      final FortressShadowCaster wall = FortressShadowCaster(
        id: 'curtain_wall',
        start: const SiegeVector2(100.0, 100.0),
        end: const SiegeVector2(150.0, 100.0),
        height: 40.0,
      );

      // Light positioned at (125, 50) directly above the wall
      final SiegeLightSource light = SiegeLightSource(
        id: 'light_above',
        position: const SiegeVector2(125.0, 50.0),
        radius: 120.0,
      );

      final List<SiegeVector2> poly = wall.projectShadowPolygon(light);
      expect(poly.length, equals(4));
      expect(poly[0], equals(wall.start));
      expect(poly[3], equals(wall.end));

      // The projected points pStart and pEnd should extend downwards (y > 100)
      expect(poly[1].y, greaterThan(100.0));
      expect(poly[2].y, greaterThan(100.0));
    });
  });

  group('BurningCatapultTrail Ballistics & Detonation Shockwave', () {
    test('Parabolic arc elevation peaks at midpoint progress', () {
      final BurningCatapultTrail cat = BurningCatapultTrail(
        id: 'cat_test',
        origin: const SiegeVector2(0.0, 100.0),
        target: const SiegeVector2(200.0, 100.0),
        arcHeight: 120.0,
        totalDuration: 2.0,
      );

      expect(cat.progress, equals(0.0));
      expect(cat.isDetonated, isFalse);

      // Step to halfway (1.0 sec)
      cat.update(1.0);
      expect(cat.progress, closeTo(0.5, 1e-3));
      // At t=0.5, 4 * h * t * (1-t) = 4 * 120 * 0.25 = 120.0
      // y = 100.0 - 120.0 * 0.45 = 46.0
      expect(cat.currentPos.x, closeTo(100.0, 1e-3));
      expect(cat.currentPos.y, closeTo(46.0, 1e-3));
    });

    test('Detonates upon reaching duration and transitions to shockwave flash', () {
      final BurningCatapultTrail cat = BurningCatapultTrail(
        id: 'cat_detonate',
        origin: const SiegeVector2(0.0, 0.0),
        target: const SiegeVector2(100.0, 100.0),
        totalDuration: 1.0,
      );

      cat.update(1.05);
      expect(cat.isDetonated, isTrue);
      expect(cat.isFinished, isFalse);
      expect(cat.lightSource.position, equals(const SiegeVector2(100.0, 100.0)));

      // Step past detonation timer (0.6s)
      cat.update(0.65);
      expect(cat.isFinished, isTrue);
    });

    test('Trajectory ribbon captures and prunes historical positions', () {
      final BurningCatapultTrail cat = BurningCatapultTrail(
        id: 'cat_ribbon',
        origin: const SiegeVector2(0, 0),
        target: const SiegeVector2(300, 300),
        totalDuration: 3.0,
      );

      for (int i = 0; i < 10; i++) {
        cat.update(0.1);
      }
      expect(cat.trajectoryRibbon.isNotEmpty, isTrue);
      expect(cat.ribbonTimestamps.isNotEmpty, isTrue);
      // Older timestamps should be strictly pruned
      expect(cat.ribbonTimestamps.last - cat.ribbonTimestamps.first, lessThanOrEqualTo(0.5));
    });
  });

  group('SiegeWarFireParticle Aerodynamics', () {
    test('Particle updates position, decays age, and applies drag', () {
      final SiegeWarFireParticle p = SiegeWarFireParticle(
        position: const SiegeVector2(50.0, 100.0),
        velocity: const SiegeVector2(10.0, -20.0),
        size: 3.0,
        maxAge: 1.0,
        color: const Color(0xFFFF5722),
      );

      expect(p.lifeRemaining, equals(1.0));
      expect(p.isDead, isFalse);

      p.update(0.5);
      expect(p.lifeRemaining, closeTo(0.5, 1e-3));
      expect(p.position.y, lessThan(100.0)); // Rose upwards due to negative y velocity
      expect(p.isDead, isFalse);

      p.update(0.6);
      expect(p.isDead, isTrue);
      expect(p.lifeRemaining, equals(0.0));
    });

    test('Smoke particle expands in size as it ascends', () {
      final SiegeWarFireParticle smoke = SiegeWarFireParticle(
        position: const SiegeVector2(50.0, 100.0),
        velocity: const SiegeVector2(0.0, -10.0),
        size: 4.0,
        maxAge: 2.0,
        color: const Color(0x66444444),
        isSmoke: true,
      );

      smoke.update(1.0);
      expect(smoke.size, greaterThan(4.0));
    });
  });

  group('TwilightSkyGISystem & Global Illumination Model', () {
    test('Creates 4-stop sky gradient matching Aion 2 twilight palette', () {
      final TwilightSkyGISystem gi = TwilightSkyGISystem();
      final LinearGradient grad = gi.createSkyGradient();

      expect(grad.colors.length, equals(4));
      expect(grad.stops?.length, equals(4));
      expect(grad.colors[0], equals(gi.zenithColor));
      expect(grad.colors[2], equals(gi.horizonColor));
    });

    test('Hemispherical ambient tone transitions smoothly across elevation', () {
      final TwilightSkyGISystem gi = TwilightSkyGISystem();

      final Color topAmbient = gi.evaluateAmbientTone(0.0);
      expect(topAmbient, equals(gi.zenithColor));

      final Color midAmbient = gi.evaluateAmbientTone(0.5);
      expect(midAmbient, equals(gi.midAtmosphereColor));

      final Color lowAmbient = gi.evaluateAmbientTone(1.0);
      expect(lowAmbient, equals(gi.horizonColor));
    });
  });

  group('GuildWarSiegeLightingSystem Simulation Loop', () {
    test('Initializes with default fortress shadow casters and braziers', () {
      final GuildWarSiegeLightingSystem system = GuildWarSiegeLightingSystem();

      expect(system.casters.length, greaterThanOrEqualTo(3));
      expect(system.lights.length, greaterThanOrEqualTo(4));
      expect(system.simulationTime, equals(0.0));
    });

    test('Simulation step advances time, spawns particles, and drives physics', () {
      final GuildWarSiegeLightingSystem system = GuildWarSiegeLightingSystem();

      system.step(0.1);
      expect(system.simulationTime, closeTo(0.1, 1e-6));

      // Emits war fire particles
      system.emitWarFireBurst(const SiegeVector2(100, 100), count: 5);
      expect(system.particles.length, greaterThanOrEqualTo(5));

      // Launches catapult
      final BurningCatapultTrail cat = system.launchCatapult(
        origin: const SiegeVector2(10, 100),
        target: const SiegeVector2(200, 100),
      );
      expect(system.catapults.contains(cat), isTrue);
      expect(system.lights.contains(cat.lightSource), isTrue);

      // Advances past catapult flight
      for (int i = 0; i < 35; i++) {
        system.step(0.1);
      }
      expect(system.simulationTime, greaterThan(3.0));
    });
  });

  group('Widget Tests — GuildWarSiegeBattlefieldViewport & GuildWarSiegeBackdrop', () {
    testWidgets('GuildWarSiegeBattlefieldViewport mounts and paints without exceptions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GuildWarSiegeBattlefieldViewport(
              height: 220.0,
              title: '⚔ TEST SIEGE',
              subtitle: 'Dynamic testing viewport',
            ),
          ),
        ),
      );

      expect(find.text('⚔ TEST SIEGE'), findsOneWidget);
      expect(find.text('KUŞATMA AKTİF'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Advance clock to trigger animation frames
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      // Tap on viewport to test interactive catapult launching
      await tester.tap(find.byType(GuildWarSiegeBattlefieldViewport));
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('GuildWarSiegeBackdrop wraps child content seamlessly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GuildWarSiegeBackdrop(
              child: Center(
                child: Text('WAR_CONTENT_RENDERED'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('WAR_CONTENT_RENDERED'), findsOneWidget);
      expect(find.byType(GuildWarSiegeBackdrop), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
    });

    testWidgets('ContinentTacticalMapPainter renders upgraded siege lighting and dynamic shadows',
        (WidgetTester tester) async {
      const List<Offset> nodes = <Offset>[
        Offset(80, 60),
        Offset(280, 60),
        Offset(180, 140),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 240,
              child: CustomPaint(
                painter: ContinentTacticalMapPainter(
                  nodePositions: nodes,
                  selectedNodeIndex: 0,
                  pulseValue: 0.5,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
