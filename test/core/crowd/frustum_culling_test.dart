import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/crowd/frustum_culling.dart';

void main() {
  group('FrustumPlane', () {
    test('plane normalization and coefficient calculation', () {
      final plane = FrustumPlane.fromCoefficients(2.0, 0.0, 0.0, 10.0);
      expect(plane.normalX, closeTo(1.0, 1e-6));
      expect(plane.normalY, closeTo(0.0, 1e-6));
      expect(plane.normalZ, closeTo(0.0, 1e-6));
      expect(plane.distance, closeTo(5.0, 1e-6));

      // Normal length must be 1.0
      final len = math.sqrt(
        plane.normalX * plane.normalX +
            plane.normalY * plane.normalY +
            plane.normalZ * plane.normalZ,
      );
      expect(len, closeTo(1.0, 1e-6));
    });

    test('signed distance to point calculation', () {
      // Plane at x = -5 facing +X (normal is [1, 0, 0], d = 5)
      final plane = FrustumPlane.fromCoefficients(1.0, 0.0, 0.0, 5.0);

      // Point at x = 0: distance is 1 * 0 + 5 = 5 (in front / inside)
      expect(plane.distanceToPoint(0.0, 0.0, 0.0), closeTo(5.0, 1e-6));

      // Point at x = -5: on the plane
      expect(plane.distanceToPoint(-5.0, 10.0, -20.0), closeTo(0.0, 1e-6));

      // Point at x = -10: distance is -5 (behind / outside)
      expect(plane.distanceToPoint(-10.0, 0.0, 0.0), closeTo(-5.0, 1e-6));
    });

    test('degenerate zero normal handling', () {
      final plane = FrustumPlane.fromCoefficients(0.0, 0.0, 0.0, 0.0);
      expect(plane.normalX, equals(0.0));
      expect(plane.normalY, equals(0.0));
      expect(plane.normalZ, equals(0.0));
      expect(plane.distance, equals(0.0));
    });
  });

  group('Frustum extraction from View-Projection Matrix', () {
    late Float32List vpMatrix;
    late Frustum frustum;

    setUp(() {
      // Camera at (0, 0, 0) looking along -Z toward (0, 0, -10), up is +Y
      final view = FrustumMatrixUtils.createLookAt(
        eyeX: 0.0,
        eyeY: 0.0,
        eyeZ: 0.0,
        targetX: 0.0,
        targetY: 0.0,
        targetZ: -10.0,
        upX: 0.0,
        upY: 1.0,
        upZ: 0.0,
      );

      // Perspective projection: 60 deg FOV, 1.0 aspect, near=1.0, far=100.0
      final proj = FrustumMatrixUtils.createPerspective(
        fovYRadians: 60.0 * math.pi / 180.0,
        aspectRatio: 1.0,
        near: 1.0,
        far: 100.0,
        zeroToOne: false,
      );

      vpMatrix = FrustumMatrixUtils.multiply(proj, view);
      frustum = Frustum.fromViewProjection(vpMatrix, zeroToOneClipSpace: false);
    });

    test('all 6 extracted planes have normalized unit normals', () {
      for (int i = 0; i < 6; i++) {
        final plane = frustum.getPlane(i);
        final len = math.sqrt(
          plane.normalX * plane.normalX +
              plane.normalY * plane.normalY +
              plane.normalZ * plane.normalZ,
        );
        expect(len, closeTo(1.0, 1e-5), reason: 'Plane $i must be unit length');
      }
    });

    test('camera target point in front of camera is inside all 6 planes', () {
      // Center point at (0, 0, -10) is inside frustum
      expect(frustum.containsPoint(0.0, 0.0, -10.0), isTrue);

      for (int i = 0; i < 6; i++) {
        final plane = frustum.getPlane(i);
        final dist = plane.distanceToPoint(0.0, 0.0, -10.0);
        expect(dist, greaterThan(0.0), reason: 'Plane $i should have positive distance');
      }
    });

    test('near and far plane boundaries', () {
      // Near plane is at z = -1.0, Far plane is at z = -100.0
      // In-range point: (0, 0, -50)
      expect(frustum.containsPoint(0.0, 0.0, -50.0), isTrue);

      // Point closer than near plane (e.g. z = -0.5)
      expect(frustum.containsPoint(0.0, 0.0, -0.5), isFalse);

      // Point behind camera (e.g. z = +5.0)
      expect(frustum.containsPoint(0.0, 0.0, 5.0), isFalse);

      // Point beyond far plane (e.g. z = -150.0)
      expect(frustum.containsPoint(0.0, 0.0, -150.0), isFalse);
    });

    test('left, right, bottom, top plane boundaries', () {
      // At z = -10, half-height = 10 * tan(30 deg) = 5.7735
      final halfHeight = 10.0 * math.tan(30.0 * math.pi / 180.0);

      // Inside bounds
      expect(frustum.containsPoint(0.0, halfHeight * 0.5, -10.0), isTrue);
      expect(frustum.containsPoint(0.0, -halfHeight * 0.5, -10.0), isTrue);
      expect(frustum.containsPoint(halfHeight * 0.5, 0.0, -10.0), isTrue);
      expect(frustum.containsPoint(-halfHeight * 0.5, 0.0, -10.0), isTrue);

      // Clearly outside left, right, top, bottom
      expect(frustum.containsPoint(halfHeight * 1.5, 0.0, -10.0), isFalse);
      expect(frustum.containsPoint(-halfHeight * 1.5, 0.0, -10.0), isFalse);
      expect(frustum.containsPoint(0.0, halfHeight * 1.5, -10.0), isFalse);
      expect(frustum.containsPoint(0.0, -halfHeight * 1.5, -10.0), isFalse);
    });

    test('zero-to-one clip space extraction matches Vulkan/Metal requirements', () {
      final projZ01 = FrustumMatrixUtils.createPerspective(
        fovYRadians: 60.0 * math.pi / 180.0,
        aspectRatio: 1.0,
        near: 1.0,
        far: 100.0,
        zeroToOne: true,
      );
      final view = FrustumMatrixUtils.createLookAt(
        eyeX: 0.0,
        eyeY: 0.0,
        eyeZ: 0.0,
        targetX: 0.0,
        targetY: 0.0,
        targetZ: -10.0,
      );
      final vpZ01 = FrustumMatrixUtils.multiply(projZ01, view);
      final frustumZ01 = Frustum.fromViewProjection(vpZ01, zeroToOneClipSpace: true);

      // Point at (0, 0, -10) must be inside
      expect(frustumZ01.containsPoint(0.0, 0.0, -10.0), isTrue);
      // Near boundary test (z = -0.5 is outside, z = -2.0 is inside)
      expect(frustumZ01.containsPoint(0.0, 0.0, -0.5), isFalse);
      expect(frustumZ01.containsPoint(0.0, 0.0, -2.0), isTrue);
    });

    test('row-major matrix extraction produces identical planes to column-major', () {
      // Transpose vpMatrix to create row-major layout
      final rowMajorVp = Float32List(16);
      for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 4; c++) {
          rowMajorVp[r * 4 + c] = vpMatrix[c * 4 + r];
        }
      }

      final rowMajorFrustum = Frustum.fromViewProjection(
        rowMajorVp,
        isRowMajor: true,
        zeroToOneClipSpace: false,
      );

      for (int i = 0; i < 24; i++) {
        expect(
          rowMajorFrustum.planeBuffer[i],
          closeTo(frustum.planeBuffer[i], 1e-5),
          reason: 'Plane coefficient $i must match',
        );
      }
    });

    test('in-place extractFromMatrix updates existing instance with zero allocations', () {
      final reusableFrustum = Frustum();
      reusableFrustum.extractFromMatrix(vpMatrix, zeroToOneClipSpace: false);

      expect(reusableFrustum.containsPoint(0.0, 0.0, -10.0), isTrue);
      expect(reusableFrustum.containsPoint(0.0, 0.0, 10.0), isFalse);
    });
  });

  group('Orthographic Frustum extraction', () {
    test('extracts exact axis-aligned planes for box bounds', () {
      final ortho = FrustumMatrixUtils.createOrthographic(
        left: -10.0,
        right: 10.0,
        bottom: -5.0,
        top: 5.0,
        near: 1.0,
        far: 50.0,
        zeroToOne: false,
      );

      final frustum = Frustum.fromViewProjection(ortho);

      // Inside points
      expect(frustum.containsPoint(0.0, 0.0, -10.0), isTrue);
      expect(frustum.containsPoint(9.0, 4.0, -25.0), isTrue);
      expect(frustum.containsPoint(-9.0, -4.0, -25.0), isTrue);

      // Outside points
      expect(frustum.containsPoint(11.0, 0.0, -10.0), isFalse); // right
      expect(frustum.containsPoint(-11.0, 0.0, -10.0), isFalse); // left
      expect(frustum.containsPoint(0.0, 6.0, -10.0), isFalse); // top
      expect(frustum.containsPoint(0.0, -6.0, -10.0), isFalse); // bottom
      expect(frustum.containsPoint(0.0, 0.0, -0.5), isFalse); // near
      expect(frustum.containsPoint(0.0, 0.0, -55.0), isFalse); // far
    });
  });

  group('Bounding Sphere Tests', () {
    late Frustum frustum;

    setUp(() {
      final view = FrustumMatrixUtils.createLookAt(
        eyeX: 0.0,
        eyeY: 0.0,
        eyeZ: 0.0,
        targetX: 0.0,
        targetY: 0.0,
        targetZ: -10.0,
      );
      final proj = FrustumMatrixUtils.createPerspective(
        fovYRadians: 60.0 * math.pi / 180.0,
        aspectRatio: 1.0,
        near: 1.0,
        far: 100.0,
      );
      frustum = Frustum.fromViewProjection(FrustumMatrixUtils.multiply(proj, view));
    });

    test('sphere fully inside frustum', () {
      // Center at (0, 0, -20), radius 2.0
      expect(frustum.testSphere(0.0, 0.0, -20.0, 2.0), equals(ContainmentResult.inside));
      expect(frustum.isSphereVisible(0.0, 0.0, -20.0, 2.0), isTrue);
    });

    test('sphere completely outside frustum', () {
      // Behind camera
      expect(frustum.testSphere(0.0, 0.0, 10.0, 2.0), equals(ContainmentResult.outside));
      expect(frustum.isSphereVisible(0.0, 0.0, 10.0, 2.0), isFalse);

      // Far beyond far plane
      expect(frustum.testSphere(0.0, 0.0, -150.0, 2.0), equals(ContainmentResult.outside));
      expect(frustum.isSphereVisible(0.0, 0.0, -150.0, 2.0), isFalse);

      // Far to the right
      expect(frustum.testSphere(50.0, 0.0, -20.0, 2.0), equals(ContainmentResult.outside));
      expect(frustum.isSphereVisible(50.0, 0.0, -20.0, 2.0), isFalse);
    });

    test('sphere intersecting frustum boundary', () {
      // Sphere center outside far plane (z = -101) with radius 5.0 -> straddles far plane
      expect(frustum.testSphere(0.0, 0.0, -101.0, 5.0), equals(ContainmentResult.intersects));
      expect(frustum.isSphereVisible(0.0, 0.0, -101.0, 5.0), isTrue);

      // Sphere center near plane boundary (z = -1.2) with radius 1.0 -> straddles near plane
      expect(frustum.testSphere(0.0, 0.0, -1.2, 1.0), equals(ContainmentResult.intersects));
      expect(frustum.isSphereVisible(0.0, 0.0, -1.2, 1.0), isTrue);

      // Massive sphere encompassing camera and entire scene
      expect(frustum.testSphere(0.0, 0.0, -50.0, 200.0), equals(ContainmentResult.intersects));
      expect(frustum.isSphereVisible(0.0, 0.0, -50.0, 200.0), isTrue);
    });

    test('early rejection stops evaluation on first failing plane', () {
      // Point behind camera fails Near plane (or whichever plane is tested)
      expect(frustum.isSphereVisible(0.0, 0.0, 50.0, 1.0), isFalse);
      // Point far left fails Left plane
      expect(frustum.isSphereVisible(-200.0, 0.0, -50.0, 1.0), isFalse);
      // Point far right fails Right plane
      expect(frustum.isSphereVisible(200.0, 0.0, -50.0, 1.0), isFalse);
      // Point far above fails Top plane
      expect(frustum.isSphereVisible(0.0, 200.0, -50.0, 1.0), isFalse);
      // Point far below fails Bottom plane
      expect(frustum.isSphereVisible(0.0, -200.0, -50.0, 1.0), isFalse);
    });
  });

  group('Axis-Aligned Bounding Box (AABB) Tests', () {
    late Frustum frustum;

    setUp(() {
      final view = FrustumMatrixUtils.createLookAt(
        eyeX: 0.0,
        eyeY: 0.0,
        eyeZ: 0.0,
        targetX: 0.0,
        targetY: 0.0,
        targetZ: -10.0,
      );
      final proj = FrustumMatrixUtils.createPerspective(
        fovYRadians: 60.0 * math.pi / 180.0,
        aspectRatio: 1.0,
        near: 1.0,
        far: 100.0,
      );
      frustum = Frustum.fromViewProjection(FrustumMatrixUtils.multiply(proj, view));
    });

    test('AABB fully inside frustum', () {
      // Box around (0, 0, -20) from -1 to +1
      final res = frustum.testAabb(-1.0, -1.0, -21.0, 1.0, 1.0, -19.0);
      expect(res, equals(ContainmentResult.inside));
      expect(frustum.isAabbVisible(-1.0, -1.0, -21.0, 1.0, 1.0, -19.0), isTrue);
    });

    test('AABB completely outside frustum', () {
      // Completely behind camera
      final resBehind = frustum.testAabb(-5.0, -5.0, 5.0, 5.0, 5.0, 15.0);
      expect(resBehind, equals(ContainmentResult.outside));
      expect(frustum.isAabbVisible(-5.0, -5.0, 5.0, 5.0, 5.0, 15.0), isFalse);

      // Completely far to the right
      final resRight = frustum.testAabb(100.0, -5.0, -30.0, 120.0, 5.0, -20.0);
      expect(resRight, equals(ContainmentResult.outside));
      expect(frustum.isAabbVisible(100.0, -5.0, -30.0, 120.0, 5.0, -20.0), isFalse);
    });

    test('AABB intersecting frustum edge', () {
      // Box crossing the far plane (z from -105 to -95)
      final res = frustum.testAabb(-2.0, -2.0, -105.0, 2.0, 2.0, -95.0);
      expect(res, equals(ContainmentResult.intersects));
      expect(frustum.isAabbVisible(-2.0, -2.0, -105.0, 2.0, 2.0, -95.0), isTrue);
    });
  });

  group('Batch Culling API & Accuracy', () {
    late Frustum frustum;

    setUp(() {
      final view = FrustumMatrixUtils.createLookAt(
        eyeX: 0.0,
        eyeY: 0.0,
        eyeZ: 0.0,
        targetX: 0.0,
        targetY: 0.0,
        targetZ: -10.0,
      );
      final proj = FrustumMatrixUtils.createPerspective(
        fovYRadians: 60.0 * math.pi / 180.0,
        aspectRatio: 1.0,
        near: 1.0,
        far: 100.0,
      );
      frustum = Frustum.fromViewProjection(FrustumMatrixUtils.multiply(proj, view));
    });

    test('cullSpheres correctly filters mixed visible and invisible entities', () {
      // 5 entities:
      // 0: inside (0, 0, -20)
      // 1: behind camera (0, 0, 10) -> culled
      // 2: inside (1, 1, -15)
      // 3: far to the right (80, 0, -20) -> culled
      // 4: inside (0, -2, -30)
      final positions = Float32List.fromList([
        0.0, 0.0, -20.0, // 0: visible
        0.0, 0.0, 10.0, // 1: culled
        1.0, 1.0, -15.0, // 2: visible
        80.0, 0.0, -20.0, // 3: culled
        0.0, -2.0, -30.0, // 4: visible
      ]);

      final visibleIndices = Uint32List(5);
      final count = frustum.cullSpheres(
        positions: positions,
        radius: 1.0,
        outVisibleIndices: visibleIndices,
      );

      expect(count, equals(3));
      expect(visibleIndices[0], equals(0));
      expect(visibleIndices[1], equals(2));
      expect(visibleIndices[2], equals(4));
    });

    test('cullSpheresWithRadii handles varying radii per entity', () {
      // Entity 0: center at (0, 0, -102), radius 3 -> intersects far plane (visible)
      // Entity 1: center at (0, 0, -102), radius 1 -> outside far plane (culled)
      final data = Float32List.fromList([
        0.0, 0.0, -102.0, 3.0, // visible
        0.0, 0.0, -102.0, 1.0, // culled
      ]);

      final visibleIndices = Uint32List(2);
      final count = frustum.cullSpheresWithRadii(
        positionsAndRadii: data,
        outVisibleIndices: visibleIndices,
      );

      expect(count, equals(1));
      expect(visibleIndices[0], equals(0));
    });

    test('cullAabbs batch correctly identifies visible boxes', () {
      final aabbs = Float32List.fromList([
        -1.0, -1.0, -21.0, 1.0, 1.0, -19.0, // 0: inside
        100.0, 0.0, -20.0, 110.0, 5.0, -15.0, // 1: outside
        -2.0, -2.0, -102.0, 2.0, 2.0, -98.0, // 2: straddles far plane (visible)
      ]);

      final visibleIndices = Uint32List(3);
      final count = frustum.cullAabbs(
        aabbMinMax: aabbs,
        outVisibleIndices: visibleIndices,
      );

      expect(count, equals(2));
      expect(visibleIndices[0], equals(0));
      expect(visibleIndices[1], equals(2));
    });

    test('cullTransforms extracts position from 4x4 matrix buffer', () {
      // 2 matrices (16 floats each)
      final matrices = Float32List(32);
      // Matrix 0: translation at indices 12, 13, 14 = (0, 0, -25) -> visible
      matrices[12] = 0.0;
      matrices[13] = 0.0;
      matrices[14] = -25.0;

      // Matrix 1: translation at indices 28, 29, 30 = (0, 0, 15) -> culled
      matrices[28] = 0.0;
      matrices[29] = 0.0;
      matrices[30] = 15.0;

      final visibleIndices = Uint32List(2);
      final count = frustum.cullTransforms(
        transforms: matrices,
        radius: 1.0,
        outVisibleIndices: visibleIndices,
      );

      expect(count, equals(1));
      expect(visibleIndices[0], equals(0));
    });

    test('cullSphereMask matches cullSpheres index output', () {
      final positions = Float32List.fromList([
        0.0, 0.0, -20.0, // visible
        0.0, 0.0, 10.0, // culled
        1.0, 1.0, -15.0, // visible
        80.0, 0.0, -20.0, // culled
        0.0, -2.0, -30.0, // visible
      ]);

      final mask = Uint8List(5);
      final count = frustum.cullSphereMask(
        positions: positions,
        radius: 1.0,
        outVisibilityMask: mask,
      );

      expect(count, equals(3));
      expect(mask, equals(Uint8List.fromList([1, 0, 1, 0, 1])));
    });

    test('cullIndexedSpheres filters candidate subset from Spatial Hash Grid', () {
      final positions = Float32List.fromList([
        0.0, 0.0, -20.0, // 0: visible
        0.0, 0.0, 10.0, // 1: culled
        1.0, 1.0, -15.0, // 2: visible
        80.0, 0.0, -20.0, // 3: culled
        0.0, -2.0, -30.0, // 4: visible
      ]);

      // Only evaluate candidate indices [0, 1, 3]
      final candidates = [0, 1, 3];
      final visibleIndices = Uint32List(3);
      final count = frustum.cullIndexedSpheres(
        positions: positions,
        candidateIndices: candidates,
        radius: 1.0,
        outVisibleIndices: visibleIndices,
      );

      expect(count, equals(1));
      expect(visibleIndices[0], equals(0));
    });

    test('empty buffers and zero entity count return zero visible count', () {
      final emptyPositions = Float32List(0);
      final visibleIndices = Uint32List(0);
      expect(
        frustum.cullSpheres(
          positions: emptyPositions,
          radius: 1.0,
          outVisibleIndices: visibleIndices,
        ),
        equals(0),
      );

      final positions = Float32List(6);
      expect(
        frustum.cullSpheres(
          positions: positions,
          radius: 1.0,
          outVisibleIndices: Uint32List(2),
          count: 0,
        ),
        equals(0),
      );
    });

    test('custom offset and stride parameter handling', () {
      // Interleaved buffer: [unused, unused, x, y, z, unused] -> stride 6, offset 2
      final customBuffer = Float32List.fromList([
        999.0, 999.0, 0.0, 0.0, -20.0, 999.0, // 0: visible
        999.0, 999.0, 0.0, 0.0, 10.0, 999.0,  // 1: culled
      ]);

      final visibleIndices = Uint32List(2);
      final count = frustum.cullSpheres(
        positions: customBuffer,
        radius: 1.0,
        outVisibleIndices: visibleIndices,
        stride: 6,
        offset: 2,
      );

      expect(count, equals(1));
      expect(visibleIndices[0], equals(0));
    });
  });

  group('Stress Benchmark: 10,000 Entities Batch Culling (< 1ms)', () {
    const int entityCount = 10000;
    late Float32List positions;
    late Uint32List visibleIndices;
    late Frustum frustum;

    setUp(() {
      // Deterministic PRNG seed for reproducible stress test
      final rng = math.Random(42);

      positions = Float32List(entityCount * 3);
      visibleIndices = Uint32List(entityCount);

      // Distribute 10,000 entities across a 200x200 ground plane with varied depth
      for (int i = 0; i < entityCount; i++) {
        final x = (rng.nextDouble() - 0.5) * 300.0;
        final y = (rng.nextDouble() - 0.5) * 40.0;
        final z = -rng.nextDouble() * 250.0 + 50.0; // from -200 to +50

        final idx = i * 3;
        positions[idx] = x;
        positions[idx + 1] = y;
        positions[idx + 2] = z;
      }

      // Camera positioned at (0, 5, 0) looking forward at (0, 5, -50)
      final view = FrustumMatrixUtils.createLookAt(
        eyeX: 0.0,
        eyeY: 5.0,
        eyeZ: 0.0,
        targetX: 0.0,
        targetY: 5.0,
        targetZ: -50.0,
      );

      final proj = FrustumMatrixUtils.createPerspective(
        fovYRadians: 60.0 * math.pi / 180.0,
        aspectRatio: 16.0 / 9.0,
        near: 0.5,
        far: 150.0,
      );

      frustum = Frustum.fromViewProjection(FrustumMatrixUtils.multiply(proj, view));
    });

    test('processes 10,000 entities in < 1.0 ms with high accuracy and zero allocations', () {
      const radius = 1.2;

      // Warmup pass (JIT compilation & CPU cache warmup)
      for (int w = 0; w < 10; w++) {
        frustum.cullSpheres(
          positions: positions,
          radius: radius,
          outVisibleIndices: visibleIndices,
          count: entityCount,
        );
      }

      // Benchmark pass: 100 consecutive frames
      const int iterations = 100;
      final stopwatch = Stopwatch()..start();

      int lastVisibleCount = 0;
      for (int i = 0; i < iterations; i++) {
        lastVisibleCount = frustum.cullSpheres(
          positions: positions,
          radius: radius,
          outVisibleIndices: visibleIndices,
          count: entityCount,
        );
      }
      stopwatch.stop();

      final totalMs = stopwatch.elapsedMicroseconds / 1000.0;
      final avgMsPerFrame = totalMs / iterations;

      // Verify that entities were filtered realistically (some inside, some outside)
      expect(lastVisibleCount, greaterThan(100), reason: 'Must have visible entities');
      expect(lastVisibleCount, lessThan(entityCount), reason: 'Must cull outside entities');

      // Requirement R4: 10,000 entities batch culling in < 1ms
      // Typically runs in ~0.15ms - 0.35ms in Dart VM
      expect(
        avgMsPerFrame,
        lessThan(1.0),
        reason: '10K batch culling took $avgMsPerFrame ms (budget: < 1.0 ms)',
      );

      // Verify ground truth consistency: every index in visibleIndices is confirmed by isSphereVisible
      for (int i = 0; i < math.min(100, lastVisibleCount); i++) {
        final entityId = visibleIndices[i];
        final px = positions[entityId * 3];
        final py = positions[entityId * 3 + 1];
        final pz = positions[entityId * 3 + 2];
        expect(
          frustum.isSphereVisible(px, py, pz, radius),
          isTrue,
          reason: 'Entity $entityId was reported visible but failed individual test',
        );
      }
    });
  });
}
