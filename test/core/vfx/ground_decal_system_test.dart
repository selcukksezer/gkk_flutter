import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/vfx/ground_decal_system.dart';

void main() {
  group('3D Math & OBB Transforms', () {
    test('Vector3D operations', () {
      const a = Vector3D(1.0, 2.0, 3.0);
      const b = Vector3D(4.0, 5.0, 6.0);

      final sum = a + b;
      expect(sum.x, closeTo(5.0, 1e-6));
      expect(sum.y, closeTo(7.0, 1e-6));
      expect(sum.z, closeTo(9.0, 1e-6));

      final diff = b - a;
      expect(diff.x, closeTo(3.0, 1e-6));
      expect(diff.y, closeTo(3.0, 1e-6));
      expect(diff.z, closeTo(3.0, 1e-6));

      expect(a.dot(b), closeTo(1 * 4 + 2 * 5 + 3 * 6, 1e-6));

      final cross = Vector3D.unitX.cross(Vector3D.unitY);
      expect(cross.x, closeTo(0.0, 1e-6));
      expect(cross.y, closeTo(0.0, 1e-6));
      expect(cross.z, closeTo(1.0, 1e-6));

      expect(a.normalized.length, closeTo(1.0, 1e-6));
      expect(a.distanceTo(b), closeTo(math.sqrt(27.0), 1e-6));
    });

    test('QuaternionD rotation and Euler creation', () {
      final qYaw = QuaternionD.fromAxisAngle(Vector3D.unitY, math.pi * 0.5); // 90 deg around Y
      final rotatedX = qYaw.rotate(Vector3D.unitX);

      // (1, 0, 0) rotated 90 deg around Y should point towards (0, 0, -1) in standard right-handed coordinates
      expect(rotatedX.x, closeTo(0.0, 1e-5));
      expect(rotatedX.y, closeTo(0.0, 1e-5));
      expect(rotatedX.z, closeTo(-1.0, 1e-5));

      final unrotated = qYaw.unrotate(rotatedX);
      expect(unrotated.x, closeTo(1.0, 1e-5));
      expect(unrotated.y, closeTo(0.0, 1e-5));
      expect(unrotated.z, closeTo(0.0, 1e-5));

      final qEuler = QuaternionD.fromEuler(math.pi * 0.5, 0.0, 0.0);
      final rotatedEuler = qEuler.rotate(Vector3D.unitX);
      expect(rotatedEuler.distanceTo(rotatedX), closeTo(0.0, 1e-5));
    });

    test('Matrix4D composition and inversion', () {
      final pos = const Vector3D(10.0, -5.0, 20.0);
      final rot = QuaternionD.fromAxisAngle(Vector3D.unitY, math.pi * 0.25);
      final scale = const Vector3D(2.0, 3.0, 4.0);

      final mat = Matrix4D.compose(pos, rot, scale);
      final inv = mat.inverse();
      expect(inv, isNotNull);

      final identityProduct = mat * inv!;
      for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
          final expected = (i == j) ? 1.0 : 0.0;
          expect(identityProduct.m[i * 4 + j], closeTo(expected, 1e-5));
        }
      }

      final testPoint = const Vector3D(1.0, 2.0, 3.0);
      final transformed = mat.transformPoint(testPoint);
      final restored = inv.transformPoint(transformed);
      expect(restored.distanceTo(testPoint), closeTo(0.0, 1e-5));
    });

    test('OrientedBoundingBox point containment', () {
      final obb = OrientedBoundingBox(
        center: const Vector3D(0.0, 0.0, 0.0),
        halfExtents: const Vector3D(2.0, 1.0, 3.0),
        orientation: QuaternionD.identity,
      );

      expect(obb.containsPoint(const Vector3D(0.0, 0.0, 0.0)), isTrue);
      expect(obb.containsPoint(const Vector3D(1.9, 0.9, 2.9)), isTrue);
      expect(obb.containsPoint(const Vector3D(-2.0, -1.0, -3.0)), isTrue);

      expect(obb.containsPoint(const Vector3D(2.1, 0.0, 0.0)), isFalse);
      expect(obb.containsPoint(const Vector3D(0.0, 1.1, 0.0)), isFalse);
      expect(obb.containsPoint(const Vector3D(0.0, 0.0, 3.1)), isFalse);
    });

    test('OrientedBoundingBox rotated containment and projection', () {
      // Rotate OBB 90 degrees around Y axis
      final rotY90 = QuaternionD.fromAxisAngle(Vector3D.unitY, math.pi * 0.5);
      final obb = OrientedBoundingBox(
        center: const Vector3D(5.0, 0.0, 5.0),
        halfExtents: const Vector3D(2.0, 1.0, 4.0), // X=2, Z=4 in local space
        orientation: rotY90,
      );

      // Local (0,0,0) is world (5, 0, 5)
      expect(obb.containsPoint(const Vector3D(5.0, 0.0, 5.0)), isTrue);

      // In rotated space, local X (halfExt=2) maps to world -Z
      // Local Z (halfExt=4) maps to world +X
      // Point at world (5 + 3.5, 0, 5) is local Z = 3.5 <= 4.0 -> inside!
      expect(obb.containsPoint(const Vector3D(8.5, 0.0, 5.0)), isTrue);

      // Point at world (5 + 4.5, 0, 5) is local Z = 4.5 > 4.0 -> outside!
      expect(obb.containsPoint(const Vector3D(9.5, 0.0, 5.0)), isFalse);

      // Center point projection has UV (0.5, 0.5)
      final centerProj = obb.projectPoint(
        worldPoint: const Vector3D(5.0, 0.0, 5.0),
        surfaceNormal: Vector3D.groundUp,
      );
      expect(centerProj.uv.dx, closeTo(0.5, 1e-5));
      expect(centerProj.uv.dy, closeTo(0.5, 1e-5));
      expect(centerProj.depth, closeTo(0.0, 1e-5));
      expect(centerProj.isInside, isTrue);
    });

    test('OrientedBoundingBox ground plane intersection polygon', () {
      final obb = OrientedBoundingBox(
        center: const Vector3D(0.0, 0.0, 0.0),
        halfExtents: const Vector3D(1.0, 1.0, 1.0),
        orientation: QuaternionD.identity,
      );

      // Plane at Y = 0 with normal = (0, 1, 0)
      final intersections = obb.intersectGroundPlane(
        planePoint: Vector3D.zero,
        planeNormal: Vector3D.groundUp,
      );

      expect(intersections.isNotEmpty, isTrue);
      // All intersection points must lie on Y = 0
      for (final pt in intersections) {
        expect(pt.y, closeTo(0.0, 1e-5));
      }
    });
  });

  group('Surface Normal Alignment & Angle Attenuation', () {
    test('Perpendicular surface normal yields full alignment', () {
      final obb = OrientedBoundingBox(
        center: const Vector3D(0.0, 2.0, 0.0),
        halfExtents: const Vector3D(2.0, 2.0, 3.0),
        // Projector pointing straight down along -Y
        orientation: QuaternionD.fromAxisAngle(Vector3D.unitX, math.pi * 0.5),
      );

      final groundPoint = const Vector3D(0.0, 0.0, 0.0);
      final result = obb.projectPoint(
        worldPoint: groundPoint,
        surfaceNormal: Vector3D.groundUp,
        angleCutoff: 0.35,
      );

      expect(result.angleAttenuation, closeTo(1.0, 1e-2));
      expect(result.hasContribution, isTrue);
    });

    test('Steep cliff / vertical wall falls below angle cutoff', () {
      final obb = OrientedBoundingBox(
        center: const Vector3D(0.0, 1.0, 0.0),
        halfExtents: const Vector3D(2.0, 2.0, 3.0),
        // Projector pointing along Z
        orientation: QuaternionD.identity,
      );

      // Surface normal perpendicular to projector (e.g. wall normal)
      final wallNormal = const Vector3D(1.0, 0.0, 0.0);
      final result = obb.projectPoint(
        worldPoint: const Vector3D(0.0, 0.0, 0.0),
        surfaceNormal: wallNormal,
        angleCutoff: 0.5,
      );

      expect(result.angleAttenuation, closeTo(0.0, 1e-2));
      expect(result.hasContribution, isFalse);
    });
  });

  group('Decal Pool & Ring Buffer Replacement', () {
    test('Pool enforces max capacity and circular FIFO eviction', () {
      const maxDecals = 4;
      final pool = DecalRingBuffer(capacity: maxDecals);

      expect(pool.capacity, equals(4));
      expect(pool.activeCount, equals(0));
      expect(pool.totalEvictions, equals(0));

      // Spawn 4 decals
      final d0 = pool.allocateNext()..initialize(
        id: 0,
        type: DecalType.scorchMark,
        position: const Vector3D(0, 0, 0),
        orientation: QuaternionD.identity,
        size: Vector3D.one,
        color: const ui.Color(0xFF000000),
      );

      final d1 = pool.allocateNext()..initialize(
        id: 1,
        type: DecalType.bloodSplatter,
        position: const Vector3D(1, 0, 0),
        orientation: QuaternionD.identity,
        size: Vector3D.one,
        color: const ui.Color(0xFF000000),
      );

      pool.allocateNext().initialize(
        id: 2,
        type: DecalType.crackedEarth,
        position: const Vector3D(2, 0, 0),
        orientation: QuaternionD.identity,
        size: Vector3D.one,
        color: const ui.Color(0xFF000000),
      );

      pool.allocateNext().initialize(
        id: 3,
        type: DecalType.slashGouge,
        position: const Vector3D(3, 0, 0),
        orientation: QuaternionD.identity,
        size: Vector3D.one,
        color: const ui.Color(0xFF000000),
      );

      expect(pool.activeCount, equals(4));
      expect(pool.totalSpawned, equals(4));
      expect(pool.totalEvictions, equals(0));

      // 5th decal should evict slot 0 (d0)
      final d4 = pool.allocateNext();
      expect(pool.totalEvictions, equals(1));
      expect(identical(d4, d0), isTrue); // Reused slot in place!

      d4.initialize(
        id: 4,
        type: DecalType.scorchMark,
        position: const Vector3D(4, 0, 0),
        orientation: QuaternionD.identity,
        size: Vector3D.one,
        color: const ui.Color(0xFF000000),
      );

      // 6th decal should evict slot 1 (d1)
      final d5 = pool.allocateNext();
      expect(pool.totalEvictions, equals(2));
      expect(identical(d5, d1), isTrue);

      // Active count remains at capacity cap
      expect(pool.activeCount, equals(4));
    });

    test('Clearing pool deactivates all decals and resets active count', () {
      final pool = DecalRingBuffer(capacity: 8);
      for (int i = 0; i < 5; i++) {
        pool.allocateNext().initialize(
          id: i,
          type: DecalType.scorchMark,
          position: Vector3D(i.toDouble(), 0, 0),
          orientation: QuaternionD.identity,
          size: Vector3D.one,
          color: const ui.Color(0xFF000000),
        );
      }
      expect(pool.activeCount, equals(5));

      pool.clear();
      expect(pool.activeCount, equals(0));
      expect(pool.activeDecals.isEmpty, isTrue);
    });
  });

  group('Opacity Fade Timelines & Expiration', () {
    test('Decal maintains full opacity before fade duration and fades out linearly', () {
      final decal = DecalInstance(
        totalLifetime: 10.0,
        fadeDuration: 4.0, // fades from t=6.0 to t=10.0
        fadeCurve: DecalFadeCurve.linear,
        baseOpacity: 1.0,
      );

      // At t = 0
      expect(decal.currentOpacity, closeTo(1.0, 1e-6));
      expect(decal.isExpired, isFalse);

      // Advance to t = 5.0 (before fade start)
      decal.update(5.0);
      expect(decal.elapsedTime, closeTo(5.0, 1e-6));
      expect(decal.currentOpacity, closeTo(1.0, 1e-6));
      expect(decal.isExpired, isFalse);

      // Advance to t = 8.0 (halfway through fade window [6..10])
      decal.update(3.0);
      expect(decal.elapsedTime, closeTo(8.0, 1e-6));
      expect(decal.currentOpacity, closeTo(0.5, 1e-6));
      expect(decal.isExpired, isFalse);

      // Advance to t = 10.0 (exact lifetime end)
      decal.update(2.0);
      expect(decal.elapsedTime, closeTo(10.0, 1e-6));
      expect(decal.currentOpacity, closeTo(0.0, 1e-6));
      expect(decal.isExpired, isTrue);
      expect(decal.isActive, isFalse);
    });

    test('Decal SmoothStep fade curve', () {
      final decal = DecalInstance(
        totalLifetime: 2.0,
        fadeDuration: 2.0,
        fadeCurve: DecalFadeCurve.smoothStep,
        baseOpacity: 1.0,
      );

      // At t = 1.0 (50% progress), smoothstep(0.5) = 3*(0.5)^2 - 2*(0.5)^3 = 0.5
      decal.update(1.0);
      expect(decal.currentOpacity, closeTo(0.5, 1e-6));

      // At t = 0.5 (25% elapsed, 75% remaining):
      final decal2 = DecalInstance(
        totalLifetime: 2.0,
        fadeDuration: 2.0,
        fadeCurve: DecalFadeCurve.smoothStep,
        baseOpacity: 1.0,
      );
      decal2.update(0.5); // remaining = 0.75
      final expectedSmooth = 0.75 * 0.75 * (3.0 - 2.0 * 0.75);
      expect(decal2.currentOpacity, closeTo(expectedSmooth, 1e-6));
    });

    test('Infinite lifetime decal never expires', () {
      final decal = DecalInstance(
        totalLifetime: 0.0, // infinite
        baseOpacity: 0.8,
      );

      decal.update(1000.0);
      expect(decal.currentOpacity, closeTo(0.8, 1e-6));
      expect(decal.isExpired, isFalse);
      expect(decal.isActive, isTrue);
    });
  });

  group('Decal Spawning Convenience Methods (R3 Presets)', () {
    late GroundDecalSystem system;

    setUp(() {
      system = GroundDecalSystem(maxDecals: 16);
    });

    test('spawnScorchMark sets scorch defaults', () {
      final decal = system.spawnScorchMark(
        position: const Vector3D(10, 0, 5),
        radius: 2.5,
        depth: 1.5,
        lifetime: 14.0,
        fadeDuration: 4.0,
      );

      expect(decal.type, equals(DecalType.scorchMark));
      expect(decal.size.x, closeTo(5.0, 1e-6)); // 2.5 * 2
      expect(decal.size.y, closeTo(5.0, 1e-6));
      expect(decal.size.z, closeTo(1.5, 1e-6));
      expect(decal.roughness, closeTo(0.94, 1e-2)); // Charred soot roughness
      expect(decal.totalLifetime, closeTo(14.0, 1e-6));
      expect(system.activeDecalCount, equals(1));
    });

    test('spawnBloodSplatter sets blood defaults and directional orientation', () {
      final decal = system.spawnBloodSplatter(
        position: const Vector3D(0, 0, 0),
        impactVelocity: const Vector3D(5.0, 0.0, 0.0), // Directional spray along X
        radius: 1.5,
      );

      expect(decal.type, equals(DecalType.bloodSplatter));
      expect(decal.roughness, closeTo(0.08, 1e-2)); // Wet glossy
      expect(decal.color.toARGB32(), equals(0xFF6B0B14)); // Deep crimson
      expect(decal.orientation, isNot(equals(QuaternionD.identity)));
    });

    test('spawnCrackedEarth sets fissure properties', () {
      final decal = system.spawnCrackedEarth(
        position: const Vector3D(-2, 0, 3),
        radius: 4.0,
        lifetime: 30.0,
      );

      expect(decal.type, equals(DecalType.crackedEarth));
      expect(decal.roughness, closeTo(0.88, 1e-2)); // Dusty matte rock
      expect(decal.size.x, closeTo(8.0, 1e-6));
      expect(decal.normalStrength, closeTo(1.2, 1e-2)); // Deep crevice normals
    });

    test('spawnSlashGouge aligns with strike direction vector', () {
      final strikeDir = const Vector3D(0.0, 0.0, 1.0); // Strike along Z
      final decal = system.spawnSlashGouge(
        position: const Vector3D(1, 0, 1),
        strikeDirection: strikeDir,
        length: 3.5,
        width: 0.8,
      );

      expect(decal.type, equals(DecalType.slashGouge));
      expect(decal.size.x, closeTo(0.8, 1e-6)); // width
      expect(decal.size.y, closeTo(3.5, 1e-6)); // length
      expect(decal.roughness, closeTo(0.76, 1e-2));
    });
  });

  group('System Queries, Batching, and Rendering', () {
    late GroundDecalSystem system;

    setUp(() {
      system = GroundDecalSystem(maxDecals: 16);
    });

    test('queryPoint returns contributing decals at world ground point', () {
      system.spawnScorchMark(
        position: const Vector3D(0.0, 0.0, 0.0),
        radius: 2.0,
      );

      // Point within radius
      final resultsInside = system.queryPoint(const Vector3D(0.5, 0.0, 0.5));
      expect(resultsInside.isNotEmpty, isTrue);
      expect(resultsInside.first.isInside, isTrue);

      // Point far away
      final resultsOutside = system.queryPoint(const Vector3D(100.0, 0.0, 100.0));
      expect(resultsOutside.isEmpty, isTrue);
    });

    test('queryBounds2D filters decals in spatial region', () {
      system.spawnScorchMark(position: const Vector3D(0, 0, 0), radius: 2.0);
      system.spawnBloodSplatter(position: const Vector3D(50, 0, 50), radius: 2.0);

      final boundsNearOrigin = Rect.fromCenter(center: Offset.zero, width: 10, height: 10);
      final overlapping = system.queryBounds2D(boundsNearOrigin);

      expect(overlapping.length, equals(1));
      expect(overlapping.first.type, equals(DecalType.scorchMark));
    });

    test('generateRenderBatch sorts items by distance to camera', () {
      system.spawnScorchMark(position: const Vector3D(5, 0, 0));
      system.spawnBloodSplatter(position: const Vector3D(15, 0, 0));
      system.spawnCrackedEarth(position: const Vector3D(2, 0, 0));

      final batch = system.generateRenderBatch(
        cameraPosition: const Vector3D(0, 0, 0),
        maxDistance: 30.0,
      );

      expect(batch.count, equals(3));
      // Verify descending order (back-to-front rendering)
      expect(batch.items[0].distanceToCamera, greaterThanOrEqualTo(batch.items[1].distanceToCamera));
      expect(batch.items[1].distanceToCamera, greaterThanOrEqualTo(batch.items[2].distanceToCamera));
    });

    testWidgets('GroundDecalPainter paints decals on canvas without errors', (tester) async {
      system.spawnScorchMark(position: const Vector3D(0, 0, 0), radius: 2.0);
      system.spawnBloodSplatter(position: const Vector3D(2, 0, 1), radius: 1.5);
      system.spawnCrackedEarth(position: const Vector3D(-1, 0, 2), radius: 2.0);
      system.spawnSlashGouge(
        position: const Vector3D(1, 0, -1),
        strikeDirection: const Vector3D(1, 0, 0),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            size: const Size(400, 400),
            painter: GroundDecalPainter(system: system),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });
  });
}
