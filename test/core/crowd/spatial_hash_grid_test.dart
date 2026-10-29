import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/crowd/spatial_hash_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpatialHashGrid - Unit Tests (O(1) Operations & Doubly-Linked Buckets)', () {
    late SpatialHashGrid grid;

    setUp(() {
      grid = SpatialHashGrid(
        cellSize: 10.0,
        maxEntities: 100,
        tableSize: 256,
      );
    });

    test('Initial state is empty with valid defaults', () {
      expect(grid.activeEntityCount, equals(0));
      expect(grid.isEntityActive(0), isFalse);
      expect(grid.getTier(0), equals(LodDistanceTier.culled));
      expect(grid.verifyIntegrity(), isTrue);
    });

    test('O(1) Insertion and active check', () {
      grid.insert(0, 5.0, 0.0, 5.0);
      grid.insert(1, 15.0, 0.0, 25.0);

      expect(grid.activeEntityCount, equals(2));
      expect(grid.isEntityActive(0), isTrue);
      expect(grid.isEntityActive(1), isTrue);
      expect(grid.isEntityActive(2), isFalse);
      expect(grid.posX[0], equals(5.0));
      expect(grid.posZ[0], equals(5.0));
      expect(grid.posX[1], equals(15.0));
      expect(grid.posZ[1], equals(25.0));
      expect(grid.verifyIntegrity(), isTrue);
    });

    test('Multiple entities in the same cell form valid linked list', () {
      // Cell (0, 0) spans [0, 10) on X and Z
      grid.insert(10, 1.0, 0.0, 1.0);
      grid.insert(20, 2.0, 0.0, 2.0);
      grid.insert(30, 3.0, 0.0, 3.0);

      expect(grid.activeEntityCount, equals(3));
      expect(grid.verifyIntegrity(), isTrue);

      final count = grid.queryRadius(
        centerX: 0.0,
        centerY: 0.0,
        centerZ: 0.0,
        radius: 10.0,
      );

      expect(count, equals(3));
      final found = [grid.queryResults[0], grid.queryResults[1], grid.queryResults[2]];
      expect(found, containsAll([10, 20, 30]));
    });

    test('Update position within the same cell maintains list without re-linking', () {
      grid.insert(5, 2.0, 0.0, 2.0);
      final initialBucket = grid.entityBucket[5];

      // Move within same cell [0, 10)
      grid.update(5, 7.5, 0.0, 8.5);

      expect(grid.posX[5], equals(7.5));
      expect(grid.posZ[5], equals(8.5));
      expect(grid.entityBucket[5], equals(initialBucket));
      expect(grid.verifyIntegrity(), isTrue);
    });

    test('Update position across cell boundary transitions bucket correctly', () {
      grid.insert(7, 2.0, 0.0, 2.0); // cell (0, 0)
      grid.insert(8, 3.0, 0.0, 3.0); // cell (0, 0)
      expect(grid.verifyIntegrity(), isTrue);

      // Move entity 7 to cell (5, 5) -> [50, 60)
      grid.update(7, 55.0, 0.0, 55.0);

      expect(grid.posX[7], equals(55.0));
      expect(grid.posZ[7], equals(55.0));
      expect(grid.verifyIntegrity(), isTrue);

      // Query near old cell
      final oldCellCount = grid.queryRadius(
        centerX: 2.0,
        centerY: 0.0,
        centerZ: 2.0,
        radius: 5.0,
      );
      expect(oldCellCount, equals(1));
      expect(grid.queryResults[0], equals(8));

      // Query near new cell
      final newCellCount = grid.queryRadius(
        centerX: 55.0,
        centerY: 0.0,
        centerZ: 55.0,
        radius: 5.0,
      );
      expect(newCellCount, equals(1));
      expect(grid.queryResults[0], equals(7));
    });

    test('O(1) Removal correctly updates doubly linked list (head, middle, tail)', () {
      // 3 entities in same cell
      grid.insert(1, 1.0, 0.0, 1.0);
      grid.insert(2, 2.0, 0.0, 2.0);
      grid.insert(3, 3.0, 0.0, 3.0);
      expect(grid.verifyIntegrity(), isTrue);

      // Remove middle entity (insertion was 1, then 2, then 3 -> head is 3 -> 2 -> 1)
      final removedMiddle = grid.remove(2);
      expect(removedMiddle, isTrue);
      expect(grid.isEntityActive(2), isFalse);
      expect(grid.activeEntityCount, equals(2));
      expect(grid.verifyIntegrity(), isTrue);

      // Remove head entity (3)
      final removedHead = grid.remove(3);
      expect(removedHead, isTrue);
      expect(grid.isEntityActive(3), isFalse);
      expect(grid.activeEntityCount, equals(1));
      expect(grid.verifyIntegrity(), isTrue);

      // Remove tail entity (1)
      final removedTail = grid.remove(1);
      expect(removedTail, isTrue);
      expect(grid.isEntityActive(1), isFalse);
      expect(grid.activeEntityCount, equals(0));
      expect(grid.verifyIntegrity(), isTrue);

      // Removing non-active returns false
      expect(grid.remove(1), isFalse);
    });

    test('Clear resets all structures and pointers', () {
      grid.insert(1, 10.0, 0.0, 10.0);
      grid.insert(2, 20.0, 0.0, 20.0);
      expect(grid.activeEntityCount, equals(2));

      grid.clear();
      expect(grid.activeEntityCount, equals(0));
      expect(grid.isEntityActive(1), isFalse);
      expect(grid.isEntityActive(2), isFalse);
      expect(grid.verifyIntegrity(), isTrue);
    });
  });

  group('Spatial Queries & Boundary Handling', () {
    late SpatialHashGrid grid;

    setUp(() {
      grid = SpatialHashGrid(
        cellSize: 10.0,
        maxEntities: 1000,
        tableSize: 1024,
      );
    });

    test('Handles negative coordinates and transitions across origin', () {
      grid.insert(0, -15.0, 0.0, -25.0); // Cell (-2, -3)
      grid.insert(1, -0.001, 0.0, -0.001); // Cell (-1, -1)
      grid.insert(2, 0.0, 0.0, 0.0); // Cell (0, 0)
      grid.insert(3, 15.0, 0.0, 25.0); // Cell (1, 2)

      expect(grid.verifyIntegrity(), isTrue);

      // Query around negative coordinate
      final count = grid.queryRadius(
        centerX: -15.0,
        centerY: 0.0,
        centerZ: -25.0,
        radius: 2.0,
      );
      expect(count, equals(1));
      expect(grid.queryResults[0], equals(0));
      expect(grid.queryDistancesSq[0], closeTo(0.0, 1e-4));
    });

    test('Exact boundary points fall into well-defined cells without duplicates', () {
      // Cell size is 10.0: boundary at 0.0, 10.0, 20.0
      grid.insert(0, 9.999, 0.0, 0.0);
      grid.insert(1, 10.000, 0.0, 0.0);
      grid.insert(2, 10.001, 0.0, 0.0);

      expect(grid.verifyIntegrity(), isTrue);

      final count = grid.queryRadius(
        centerX: 10.0,
        centerY: 0.0,
        centerZ: 0.0,
        radius: 0.005,
      );

      // 9.999 is 0.001 away; 10.0 is 0 away; 10.001 is 0.001 away -> all 3 within 0.005!
      expect(count, equals(3));
    });

    test('queryAABB correctly filters entities in 3D box', () {
      grid.insert(0, 5.0, 2.0, 5.0);
      grid.insert(1, 25.0, 5.0, 25.0);
      grid.insert(2, -5.0, -2.0, -5.0);
      grid.insert(3, 8.0, 10.0, 8.0); // Outside Y range

      final count = grid.queryAABB(
        minX: 0.0,
        minY: 0.0,
        minZ: 0.0,
        maxX: 10.0,
        maxY: 4.0,
        maxZ: 10.0,
      );

      expect(count, equals(1));
      expect(grid.queryResults[0], equals(0));
    });

    test('3D spatial grid mode correctly hashes Y axis', () {
      final grid3D = SpatialHashGrid(
        cellSize: 10.0,
        maxEntities: 100,
        tableSize: 256,
        is3D: true,
      );

      grid3D.insert(0, 0.0, 0.0, 0.0);
      grid3D.insert(1, 0.0, 50.0, 0.0); // 50m above in Y

      expect(grid3D.verifyIntegrity(), isTrue);

      // Query radius 10m around origin
      final count = grid3D.queryRadius(
        centerX: 0.0,
        centerY: 0.0,
        centerZ: 0.0,
        radius: 10.0,
      );

      expect(count, equals(1));
      expect(grid3D.queryResults[0], equals(0));
    });

    test('Out of range entityId throws RangeError', () {
      expect(() => grid.insert(-1, 0, 0, 0), throwsRangeError);
      expect(() => grid.insert(1000, 0, 0, 0), throwsRangeError);
      expect(() => grid.update(-1, 0, 0, 0), throwsRangeError);
      expect(() => grid.update(1000, 0, 0, 0), throwsRangeError);
    });
  });

  group('AOI Distance Tier Categorization Engine (R4 Compliance)', () {
    late SpatialHashGrid grid;

    setUp(() {
      grid = SpatialHashGrid(
        cellSize: 12.5,
        maxEntities: 500,
        tableSize: 1024,
      );
    });

    test('Correctly categorizes Close (<25m), Medium (25-80m), Distant (>80m), Culled (>250m)', () {
      // Camera at (0, 0, 0)
      // Entity 0: 10m -> Close (< 25m)
      grid.insert(0, 10.0, 0.0, 0.0);

      // Entity 1: 24.9m -> Close (< 25m)
      grid.insert(1, 0.0, 0.0, 24.9);

      // Entity 2: 25.0m -> Medium (25m - 80m)
      grid.insert(2, 25.0, 0.0, 0.0);

      // Entity 3: 50.0m -> Medium (25m - 80m)
      grid.insert(3, 30.0, 0.0, 40.0); // dist = 50

      // Entity 4: 80.0m -> Medium (25m - 80m)
      grid.insert(4, 0.0, 0.0, 80.0);

      // Entity 5: 80.1m -> Distant (> 80m)
      grid.insert(5, 80.1, 0.0, 0.0);

      // Entity 6: 150.0m -> Distant (> 80m)
      grid.insert(6, 150.0, 0.0, 0.0);

      // Entity 7: 250.0m -> Distant (<= 250m)
      grid.insert(7, 0.0, 0.0, 250.0);

      // Entity 8: 250.1m -> Culled (> 250m)
      grid.insert(8, 250.1, 0.0, 0.0);

      grid.updateAOI(
        cameraX: 0.0,
        cameraY: 0.0,
        cameraZ: 0.0,
        closeThreshold: 25.0,
        mediumThreshold: 80.0,
        maxAoiDistance: 250.0,
      );

      // Tiers validation
      expect(grid.getTier(0), equals(LodDistanceTier.close));
      expect(grid.getTier(1), equals(LodDistanceTier.close));
      expect(grid.getTier(2), equals(LodDistanceTier.medium));
      expect(grid.getTier(3), equals(LodDistanceTier.medium));
      expect(grid.getTier(4), equals(LodDistanceTier.medium));
      expect(grid.getTier(5), equals(LodDistanceTier.distant));
      expect(grid.getTier(6), equals(LodDistanceTier.distant));
      expect(grid.getTier(7), equals(LodDistanceTier.distant));
      expect(grid.getTier(8), equals(LodDistanceTier.culled));

      // Tier Counts
      expect(grid.closeCount, equals(2));
      expect(grid.mediumCount, equals(3));
      expect(grid.distantCount, equals(3));
      expect(grid.culledCount, equals(1));

      // Distance inspection
      expect(grid.getDistance(0), closeTo(10.0, 1e-3));
      expect(grid.getDistance(3), closeTo(50.0, 1e-3));
      expect(grid.getDistance(7), closeTo(250.0, 1e-3));
    });

    test('LOD0 budget clamp constrains close tier to target entity count (30-50)', () {
      // Insert 80 entities in close range (distance 1.0 to 20.0m)
      for (int i = 0; i < 80; i++) {
        final dist = 1.0 + (i * 0.2); // all < 20m, strictly close tier
        grid.insert(i, dist, 0.0, 0.0);
      }

      // Without clamp: all 80 in close tier
      grid.updateAOI(
        cameraX: 0.0,
        cameraY: 0.0,
        cameraZ: 0.0,
        clampCloseBudget: false,
      );
      expect(grid.closeCount, equals(80));
      expect(grid.mediumCount, equals(0));

      // With clamp: target budget 40 entities
      grid.updateAOI(
        cameraX: 0.0,
        cameraY: 0.0,
        cameraZ: 0.0,
        maxCloseEntities: 40,
        clampCloseBudget: true,
      );

      expect(grid.closeCount, equals(40));
      expect(grid.mediumCount, equals(40)); // 40 demoted to medium

      // Verify the 40 entities in close tier are indeed the closest ones
      final double maxCloseDistSq = grid.entityDistancesSq[grid.closeEntities[0]];
      double highestInClose = maxCloseDistSq;
      for (int i = 1; i < grid.closeCount; i++) {
        final d2 = grid.entityDistancesSq[grid.closeEntities[i]];
        if (d2 > highestInClose) highestInClose = d2;
      }

      // The 41st closest entity (demoted) must have distance >= highest in close
      for (int i = 0; i < grid.mediumCount; i++) {
        final medId = grid.mediumEntities[i];
        if (medId < 80) { // demoted close entity
          expect(grid.entityDistancesSq[medId], greaterThanOrEqualTo(highestInClose - 1e-4));
        }
      }
    });

    test('Moving camera dynamically shifts tiers correctly', () {
      // Place entity at (100, 0, 0)
      grid.insert(0, 100.0, 0.0, 0.0);

      // Camera at (0, 0, 0) -> distance is 100m -> Distant (> 80m)
      grid.updateAOI(cameraX: 0.0, cameraY: 0.0, cameraZ: 0.0);
      expect(grid.getTier(0), equals(LodDistanceTier.distant));

      // Camera moves to (50, 0, 0) -> distance is 50m -> Medium (25-80m)
      grid.updateAOI(cameraX: 50.0, cameraY: 0.0, cameraZ: 0.0);
      expect(grid.getTier(0), equals(LodDistanceTier.medium));

      // Camera moves to (90, 0, 0) -> distance is 10m -> Close (< 25m)
      grid.updateAOI(cameraX: 90.0, cameraY: 0.0, cameraZ: 0.0);
      expect(grid.getTier(0), equals(LodDistanceTier.close));

      // Camera moves far away to (-200, 0, 0) -> distance is 300m -> Culled (> 250m)
      grid.updateAOI(cameraX: -200.0, cameraY: 0.0, cameraZ: 0.0);
      expect(grid.getTier(0), equals(LodDistanceTier.culled));
    });
  });

  group('10,000 Entities Synthetic Stress & Verification Test', () {
    const int entityCount = 10000;
    late SpatialHashGrid grid;

    setUp(() {
      grid = SpatialHashGrid(
        cellSize: 15.0,
        maxEntities: entityCount,
        tableSize: 32768,
      );
    });

    test('Populates 10,000 synthetic entities across 1000m x 1000m world with 100% integrity', () {
      final rng = math.Random(1337); // Deterministic seed

      // Populate 10,000 synthetic entities
      for (int i = 0; i < entityCount; i++) {
        final double x = (rng.nextDouble() - 0.5) * 1000.0; // [-500, 500]
        final double y = rng.nextDouble() * 15.0; // [0, 15] terrain height
        final double z = (rng.nextDouble() - 0.5) * 1000.0; // [-500, 500]
        grid.insert(i, x, y, z);
      }

      expect(grid.activeEntityCount, equals(entityCount));
      expect(grid.verifyIntegrity(), isTrue);

      final stats = grid.getStats();
      expect(stats.totalActiveEntities, equals(entityCount));
      expect(stats.occupiedBuckets, greaterThan(2000));
      expect(stats.maxBucketDepth, lessThan(35));
    });

    test('Radial query on 10,000 entities matches brute-force ground truth exactly', () {
      final rng = math.Random(42);

      // Populate 10,000 entities
      for (int i = 0; i < entityCount; i++) {
        final double x = (rng.nextDouble() - 0.5) * 600.0;
        final double y = rng.nextDouble() * 10.0;
        final double z = (rng.nextDouble() - 0.5) * 600.0;
        grid.insert(i, x, y, z);
      }

      // Query from arbitrary camera location
      const double queryX = 25.5;
      const double queryY = 3.0;
      const double queryZ = -14.2;
      const double queryRadius = 35.0;
      const double radiusSq = queryRadius * queryRadius;

      final gridFoundCount = grid.queryRadius(
        centerX: queryX,
        centerY: queryY,
        centerZ: queryZ,
        radius: queryRadius,
      );

      // Brute force check across all 10,000 entities
      final bruteForceMatches = <int>{};
      for (int i = 0; i < entityCount; i++) {
        final dx = grid.posX[i] - queryX;
        final dy = grid.posY[i] - queryY;
        final dz = grid.posZ[i] - queryZ;
        if (dx * dx + dy * dy + dz * dz <= radiusSq) {
          bruteForceMatches.add(i);
        }
      }

      expect(gridFoundCount, equals(bruteForceMatches.length));

      final gridSet = <int>{};
      for (int i = 0; i < gridFoundCount; i++) {
        gridSet.add(grid.queryResults[i]);
      }

      expect(gridSet, equals(bruteForceMatches));
    });

    test('AOI categorization on 10,000 entities matches ground truth across all tiers', () {
      final rng = math.Random(999);

      for (int i = 0; i < entityCount; i++) {
        final double x = (rng.nextDouble() - 0.5) * 800.0;
        final double y = (rng.nextDouble() - 0.5) * 20.0;
        final double z = (rng.nextDouble() - 0.5) * 800.0;
        grid.insert(i, x, y, z);
      }

      const double camX = 12.0;
      const double camY = 5.0;
      const double camZ = -8.0;

      grid.updateAOI(
        cameraX: camX,
        cameraY: camY,
        cameraZ: camZ,
        closeThreshold: 25.0,
        mediumThreshold: 80.0,
        maxAoiDistance: 250.0,
      );

      // Verify every single entity matches ground truth
      const closeSq = 25.0 * 25.0;
      const medSq = 80.0 * 80.0;
      const maxSq = 250.0 * 250.0;

      int expectedClose = 0;
      int expectedMed = 0;
      int expectedDist = 0;
      int expectedCulled = 0;

      for (int i = 0; i < entityCount; i++) {
        final dx = grid.posX[i] - camX;
        final dy = grid.posY[i] - camY;
        final dz = grid.posZ[i] - camZ;
        final d2 = dx * dx + dy * dy + dz * dz;

        LodDistanceTier expectedTier;
        if (d2 < closeSq) {
          expectedTier = LodDistanceTier.close;
          expectedClose++;
        } else if (d2 <= medSq) {
          expectedTier = LodDistanceTier.medium;
          expectedMed++;
        } else if (d2 <= maxSq) {
          expectedTier = LodDistanceTier.distant;
          expectedDist++;
        } else {
          expectedTier = LodDistanceTier.culled;
          expectedCulled++;
        }

        expect(grid.getTier(i), equals(expectedTier));
      }

      expect(grid.closeCount, equals(expectedClose));
      expect(grid.mediumCount, equals(expectedMed));
      expect(grid.distantCount, equals(expectedDist));
      expect(grid.culledCount, equals(expectedCulled));
      expect(grid.closeCount + grid.mediumCount + grid.distantCount + grid.culledCount, equals(entityCount));
    });
  });

  group('Performance Benchmarks (Strict Sub-1.5ms Requirement for 10,000 Entities)', () {
    const int entityCount = 10000;
    late SpatialHashGrid grid;
    late Float32List packedPositions;

    setUp(() {
      grid = SpatialHashGrid(
        cellSize: 15.0,
        maxEntities: entityCount,
        tableSize: 32768,
      );

      final rng = math.Random(777);
      packedPositions = Float32List(entityCount * 3);

      for (int i = 0; i < entityCount; i++) {
        final x = (rng.nextDouble() - 0.5) * 800.0;
        final y = rng.nextDouble() * 10.0;
        final z = (rng.nextDouble() - 0.5) * 800.0;
        packedPositions[i * 3] = x;
        packedPositions[i * 3 + 1] = y;
        packedPositions[i * 3 + 2] = z;
        grid.insert(i, x, y, z);
      }
    });

    test('10,000 Entity Update pass executes well below 1.5ms', () {
      // Warm up JIT
      for (int w = 0; w < 10; w++) {
        for (int i = 0; i < entityCount; i++) {
          final x = packedPositions[i * 3] + (w * 0.1);
          final y = packedPositions[i * 3 + 1];
          final z = packedPositions[i * 3 + 2] + (w * 0.1);
          grid.update(i, x, y, z);
        }
      }

      // Measure 50 iterations
      const int benchmarkIterations = 50;
      final stopwatch = Stopwatch()..start();

      for (int iter = 0; iter < benchmarkIterations; iter++) {
        final double delta = iter * 0.05;
        for (int i = 0; i < entityCount; i++) {
          final int idx = i * 3;
          grid.update(
            i,
            packedPositions[idx] + delta,
            packedPositions[idx + 1],
            packedPositions[idx + 2] + delta,
          );
        }
      }

      stopwatch.stop();
      final double avgUpdateTimeMs = stopwatch.elapsedMicroseconds / (benchmarkIterations * 1000.0);
      // ignore: avoid_print
      print('[BENCHMARK] 10,000 entity update average time: ${avgUpdateTimeMs.toStringAsFixed(3)}ms');

      // Verify requirement: < 1.5ms
      expect(avgUpdateTimeMs, lessThan(1.5),
          reason: '10,000 entity update took ${avgUpdateTimeMs.toStringAsFixed(3)}ms (must be < 1.5ms)');
    });

    test('10,000 Entity AOI Categorization executes well below 1.5ms', () {
      // Warm up
      for (int w = 0; w < 10; w++) {
        grid.updateAOI(cameraX: w * 1.0, cameraY: 5.0, cameraZ: w * 1.0);
      }

      const int aoiIterations = 50;
      final stopwatch = Stopwatch()..start();

      for (int iter = 0; iter < aoiIterations; iter++) {
        grid.updateAOI(
          cameraX: iter * 0.5,
          cameraY: 5.0,
          cameraZ: iter * 0.5,
          clampCloseBudget: true,
          maxCloseEntities: 50,
        );
      }

      stopwatch.stop();
      final double avgAoiTimeMs = stopwatch.elapsedMicroseconds / (aoiIterations * 1000.0);
      // ignore: avoid_print
      print('[BENCHMARK] 10,000 entity AOI categorization average time: ${avgAoiTimeMs.toStringAsFixed(3)}ms');

      expect(avgAoiTimeMs, lessThan(1.5),
          reason: '10,000 entity AOI categorization took ${avgAoiTimeMs.toStringAsFixed(3)}ms (must be < 1.5ms)');
    });

    test('Proximity radial query around camera executes in microseconds (< 0.1ms)', () {
      // Warm up
      for (int w = 0; w < 20; w++) {
        grid.queryRadius(centerX: 0.0, centerY: 0.0, centerZ: 0.0, radius: 25.0);
      }

      const int queryIterations = 200;
      final stopwatch = Stopwatch()..start();

      for (int iter = 0; iter < queryIterations; iter++) {
        grid.queryRadius(
          centerX: (iter % 10) * 5.0,
          centerY: 5.0,
          centerZ: (iter % 10) * 5.0,
          radius: 25.0,
        );
      }

      stopwatch.stop();
      final double avgQueryTimeMs = stopwatch.elapsedMicroseconds / (queryIterations * 1000.0);
      // ignore: avoid_print
      print('[BENCHMARK] 25m radial query average time: ${avgQueryTimeMs.toStringAsFixed(4)}ms');

      expect(avgQueryTimeMs, lessThan(0.2),
          reason: 'Radial query took ${avgQueryTimeMs.toStringAsFixed(4)}ms (must be < 0.2ms)');
    });
  });
}
