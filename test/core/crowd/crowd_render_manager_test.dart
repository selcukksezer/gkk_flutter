import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/crowd/crowd_render_manager.dart';

void main() {
  group('CrowdLodTier & Enums', () {
    test('defines correct enum integer IDs and fromId mapping', () {
      expect(CrowdLodTier.lod0Close.id, equals(0));
      expect(CrowdLodTier.lod2Instanced.id, equals(1));
      expect(CrowdLodTier.vatDistant.id, equals(2));
      expect(CrowdLodTier.culled.id, equals(3));

      expect(CrowdLodTier.fromId(0), equals(CrowdLodTier.lod0Close));
      expect(CrowdLodTier.fromId(1), equals(CrowdLodTier.lod2Instanced));
      expect(CrowdLodTier.fromId(2), equals(CrowdLodTier.vatDistant));
      expect(CrowdLodTier.fromId(3), equals(CrowdLodTier.culled));
      expect(CrowdLodTier.fromId(-1), equals(CrowdLodTier.culled));
      expect(CrowdLodTier.fromId(999), equals(CrowdLodTier.culled));
    });
  });

  group('CrowdCamera — Frustum & Orientation', () {
    test('initializes with default orientation and calculates forward vectors', () {
      final camera = CrowdCamera();

      expect(camera.x, equals(0.0));
      expect(camera.y, equals(10.0));
      expect(camera.z, equals(-20.0));
      expect(camera.yaw, equals(0.0));
      expect(camera.pitch, equals(0.0));
      expect(camera.fovRadians, closeTo(60.0 * (math.pi / 180.0), 0.001));
      expect(camera.aspect, closeTo(16.0 / 9.0, 0.001));
      expect(camera.nearPlane, equals(0.1));
      expect(camera.farPlane, equals(250.0));
    });

    test('setPosition and setRotation update coordinates and unit vectors', () {
      final camera = CrowdCamera();
      camera.setPosition(15.0, 25.0, -35.0);
      expect(camera.x, equals(15.0));
      expect(camera.y, equals(25.0));
      expect(camera.z, equals(-35.0));

      // Rotate camera 90 degrees yaw (facing +X)
      camera.setRotation(math.pi * 0.5, 0.0);
      expect(camera.yaw, closeTo(math.pi * 0.5, 0.001));
      expect(camera.pitch, equals(0.0));

      // Point along +X should now be in view
      expect(camera.isInView(65.0, 25.0, -35.0, 5.0), isTrue);
      // Point along original +Z should now be outside 60 deg cone
      expect(camera.isInView(15.0, 25.0, 15.0, 5.0), isFalse);
    });

    test('isInView correctly performs distance and frustum cone checks', () {
      final camera = CrowdCamera(
        x: 0.0,
        y: 0.0,
        z: 0.0,
        yaw: 0.0,
        pitch: 0.0,
        fovDegrees: 60.0,
        farPlane: 200.0,
      );

      // Directly ahead on +Z axis within range
      expect(camera.isInView(0.0, 0.0, 50.0, 5.0), isTrue);

      // Directly behind on -Z axis -> outside FOV
      expect(camera.isInView(0.0, 0.0, -50.0, 5.0), isFalse);

      // Beyond far plane (200m + 5m margin = 205m)
      expect(camera.isInView(0.0, 0.0, 250.0, 5.0), isFalse);

      // Very close to camera within near plane + margin
      expect(camera.isInView(0.0, 0.0, 1.0, 5.0), isTrue);

      // Entity at exact camera position (distSq = 0)
      expect(camera.isInView(0.0, 0.0, 0.0, 5.0), isTrue);
    });
  });

  group('FastSpatialHashGrid — Linked-List Spatial Partitioning', () {
    test('initializes empty and clear resets all cell heads and links', () {
      final grid = FastSpatialHashGrid(
        cellSize: 10.0,
        gridResolution: 64,
        maxEntities: 100,
      );

      expect(grid.cellSize, equals(10.0));
      expect(grid.cellCount, equals(4096));
      expect(grid.maxEntities, equals(100));

      for (int i = 0; i < grid.cellCount; i++) {
        expect(grid.cellHeads[i], equals(-1));
      }
      for (int i = 0; i < grid.maxEntities; i++) {
        expect(grid.entityNext[i], equals(-1));
        expect(grid.entityCell[i], equals(-1));
      }
    });

    test('inserts entities and queries by radius with zero allocations', () {
      final grid = FastSpatialHashGrid(
        cellSize: 10.0,
        gridResolution: 64,
        maxEntities: 10,
      );

      final positions = Float32List(30);
      // Entity 0 at (10, 0, 10)
      positions[0] = 10.0;
      positions[1] = 0.0;
      positions[2] = 10.0;
      grid.insert(0, 10.0, 10.0);

      // Entity 1 at (12, 0, 11)
      positions[3] = 12.0;
      positions[4] = 0.0;
      positions[5] = 11.0;
      grid.insert(1, 12.0, 11.0);

      // Entity 2 at (80, 0, 80)
      positions[6] = 80.0;
      positions[7] = 0.0;
      positions[8] = 80.0;
      grid.insert(2, 80.0, 80.0);

      final outBuf = Int32List(16);
      final count = grid.queryRadius(
        centerX: 10.0,
        centerZ: 10.0,
        radius: 5.0,
        positions: positions,
        outBuffer: outBuf,
      );

      expect(count, equals(2));
      final found = [outBuf[0], outBuf[1]];
      expect(found, containsAll([0, 1]));
      expect(found, isNot(contains(2)));
    });

    test('beginFrame resets cell heads in O(N_cells) without array re-allocations', () {
      final grid = FastSpatialHashGrid(
        cellSize: 10.0,
        gridResolution: 16,
        maxEntities: 10,
      );

      grid.insert(0, 5.0, 5.0);
      grid.insert(1, 15.0, 15.0);

      // Heads must have changed from -1
      bool hasActiveHead = grid.cellHeads.any((h) => h != -1);
      expect(hasActiveHead, isTrue);

      grid.beginFrame();

      // All heads reset to -1
      for (int i = 0; i < grid.cellCount; i++) {
        expect(grid.cellHeads[i], equals(-1));
      }
    });

    test('handles negative world coordinates and boundary wrapping seamlessly', () {
      final grid = FastSpatialHashGrid(
        cellSize: 10.0,
        gridResolution: 32,
        maxEntities: 10,
      );

      final positions = Float32List(30);
      // Negative coordinates
      positions[0] = -25.0;
      positions[1] = 0.0;
      positions[2] = -35.0;
      grid.insert(0, -25.0, -35.0);

      positions[3] = -23.0;
      positions[4] = 0.0;
      positions[5] = -33.0;
      grid.insert(1, -23.0, -33.0);

      final outBuf = Int32List(8);
      final count = grid.queryRadius(
        centerX: -25.0,
        centerZ: -35.0,
        radius: 5.0,
        positions: positions,
        outBuffer: outBuf,
      );

      expect(count, equals(2));
      final found = [outBuf[0], outBuf[1]];
      expect(found, containsAll([0, 1]));
    });

    test('queryRadius clamps to maxResults and outBuffer capacity', () {
      final grid = FastSpatialHashGrid(
        cellSize: 10.0,
        gridResolution: 32,
        maxEntities: 20,
      );

      final positions = Float32List(60);
      for (int i = 0; i < 15; i++) {
        positions[i * 3] = 5.0;
        positions[i * 3 + 2] = 5.0;
        grid.insert(i, 5.0, 5.0);
      }

      final smallBuf = Int32List(4);
      final count = grid.queryRadius(
        centerX: 5.0,
        centerZ: 5.0,
        radius: 10.0,
        positions: positions,
        outBuffer: smallBuf,
        maxResults: 4,
      );

      expect(count, equals(4));
    });
  });

  group('CrowdRenderManager — Lifecycle, Preallocation & Memory Pools', () {
    test('preallocates buffers and initializes with zero active entities', () {
      final manager = CrowdRenderManager(
        maxEntities: 10000,
        closeDistanceThreshold: 25.0,
        mediumDistanceThreshold: 80.0,
        maxCullDistance: 250.0,
        maxLod0Entities: 50,
      );

      expect(manager.maxEntities, equals(10000));
      expect(manager.activeCount, equals(0));
      expect(manager.lod0Count, equals(0));
      expect(manager.lod2InstanceCount, equals(0));
      expect(manager.vatInstanceCount, equals(0));
      expect(manager.culledCount, equals(0));
      expect(manager.tickCounter, equals(0));
      expect(manager.lastTickDurationMs, equals(0.0));

      // Verify contiguous typed buffer dimensions
      expect(manager.positions.length, equals(30000));
      expect(manager.velocities.length, equals(30000));
      expect(manager.rotations.length, equals(10000));
      expect(manager.scales.length, equals(10000));
      expect(manager.animationIds.length, equals(10000));
      expect(manager.animationTimes.length, equals(10000));
      expect(manager.animationSpeeds.length, equals(10000));
      expect(manager.archetypeIds.length, equals(10000));
      expect(manager.tintColors.length, equals(10000));
      expect(manager.flags.length, equals(10000));
      expect(manager.distancesToCamera.length, equals(10000));
      expect(manager.lodTiers.length, equals(10000));

      expect(manager.lod0Indices.length, equals(50));
      expect(manager.lod2TransformBuffer.length, equals(160000));
      expect(manager.vatInstanceBuffer.length, equals(80000));
      expect(manager.rstTransforms.length, equals(40000));
      expect(manager.atlasRects.length, equals(40000));
      expect(manager.atlasColors.length, equals(10000));

      // Buffer defaults
      expect(manager.scales[0], equals(1.0));
      expect(manager.animationSpeeds[0], equals(1.0));
      expect(manager.tintColors[0].toUnsigned(32), equals(0xFFFFFFFF));
      expect(manager.lodTiers[0], equals(CrowdLodTier.culled.id));
    });

    test('exposes gpuBuffers snapshot with accurate metadata', () {
      final manager = CrowdRenderManager(maxEntities: 100);
      final gpuBuf = manager.gpuBuffers;

      expect(gpuBuf.lod2TransformBuffer, equals(manager.lod2TransformBuffer));
      expect(gpuBuf.vatInstanceBuffer, equals(manager.vatInstanceBuffer));
      expect(gpuBuf.lod0Indices, equals(manager.lod0Indices));
      expect(gpuBuf.lod2InstanceCount, equals(0));
      expect(gpuBuf.vatInstanceCount, equals(0));
      expect(gpuBuf.lod0Count, equals(0));
      expect(gpuBuf.totalActive, equals(0));
      expect(gpuBuf.culledCount, equals(0));
    });
  });

  group('CrowdRenderManager — Agent Registration & Recycling (Pooling)', () {
    test('spawns agent with full custom attributes and sets active flag', () {
      final manager = CrowdRenderManager(maxEntities: 50);

      final id = manager.spawnEntity(
        x: 12.5,
        y: 1.0,
        z: 22.5,
        vx: 1.5,
        vy: 0.0,
        vz: -2.0,
        yaw: 0.75,
        scale: 1.3,
        archetypeId: 2,
        tintColor: 0xFF112233,
        animationPhase: 1.25,
        animationSpeed: 1.1,
      );

      expect(id, equals(49)); // Free-list top pop
      expect(manager.activeCount, equals(1));
      expect(manager.flags[id], equals(1));

      final pIdx = id * 3;
      expect(manager.positions[pIdx], equals(12.5));
      expect(manager.positions[pIdx + 1], equals(1.0));
      expect(manager.positions[pIdx + 2], equals(22.5));

      expect(manager.velocities[pIdx], equals(1.5));
      expect(manager.velocities[pIdx + 1], equals(0.0));
      expect(manager.velocities[pIdx + 2], equals(-2.0));

      expect(manager.rotations[id], closeTo(0.75, 0.001));
      expect(manager.scales[id], closeTo(1.3, 0.001));
      expect(manager.archetypeIds[id], equals(2));
      expect(manager.tintColors[id].toUnsigned(32), equals(0xFF112233));
      expect(manager.animationTimes[id], closeTo(1.25, 0.001));
      expect(manager.animationSpeeds[id], closeTo(1.1, 0.001));
    });

    test('spawns agent with default attributes', () {
      final manager = CrowdRenderManager(maxEntities: 10);
      final id = manager.spawnEntity();

      expect(id, isNonNegative);
      expect(manager.activeCount, equals(1));
      expect(manager.flags[id], equals(1));

      final pIdx = id * 3;
      expect(manager.positions[pIdx], equals(0.0));
      expect(manager.positions[pIdx + 1], equals(0.0));
      expect(manager.positions[pIdx + 2], equals(0.0));
      expect(manager.scales[id], equals(1.0));
      expect(manager.archetypeIds[id], equals(0));
      expect(manager.tintColors[id].toUnsigned(32), equals(0xFFFFFFFF));
      expect(manager.animationSpeeds[id], equals(1.0));
    });

    test('recycles slot in O(1) LIFO order upon despawn', () {
      final manager = CrowdRenderManager(maxEntities: 10);

      final id0 = manager.spawnEntity(x: 1.0, z: 1.0);
      final id1 = manager.spawnEntity(x: 2.0, z: 2.0);
      expect(id0, equals(9));
      expect(id1, equals(8));
      expect(manager.activeCount, equals(2));

      // Despawn id0
      final ok = manager.despawnEntity(id0);
      expect(ok, isTrue);
      expect(manager.activeCount, equals(1));
      expect(manager.flags[id0], equals(0));
      expect(manager.lodTiers[id0], equals(CrowdLodTier.culled.id));

      // Next spawn must immediately reuse id0
      final idReused = manager.spawnEntity(x: 100.0, z: 100.0);
      expect(idReused, equals(id0));
      expect(manager.activeCount, equals(2));
      expect(manager.positions[idReused * 3], equals(100.0));
    });

    test('despawnEntity gracefully rejects invalid indices and inactive slots', () {
      final manager = CrowdRenderManager(maxEntities: 20);

      expect(manager.despawnEntity(-1), isFalse);
      expect(manager.despawnEntity(20), isFalse);
      expect(manager.despawnEntity(100), isFalse);

      // Inactive slot (not yet spawned)
      expect(manager.despawnEntity(5), isFalse);

      // Spawn and despawn
      final id = manager.spawnEntity();
      expect(manager.despawnEntity(id), isTrue);
      // Double despawn must return false
      expect(manager.despawnEntity(id), isFalse);
    });

    test('returns -1 when entity pool is exhausted', () {
      final manager = CrowdRenderManager(maxEntities: 3);

      final e0 = manager.spawnEntity();
      final e1 = manager.spawnEntity();
      final e2 = manager.spawnEntity();

      expect(e0, isNonNegative);
      expect(e1, isNonNegative);
      expect(e2, isNonNegative);
      expect(manager.activeCount, equals(3));

      // 4th spawn fails
      final eOverflow = manager.spawnEntity();
      expect(eOverflow, equals(-1));
      expect(manager.activeCount, equals(3));

      // Free one and spawn again
      manager.despawnEntity(e1);
      expect(manager.activeCount, equals(2));
      final eNew = manager.spawnEntity();
      expect(eNew, equals(e1));
      expect(manager.activeCount, equals(3));
    });

    test('spawnBatch spawns cluster of entities and respects pool limit', () {
      final manager = CrowdRenderManager(maxEntities: 100);

      manager.spawnBatch(
        count: 40,
        areaRadius: 30.0,
        originX: 10.0,
        originZ: 20.0,
        defaultArchetype: 1,
        rng: math.Random(1234),
      );

      expect(manager.activeCount, equals(40));

      // Spawn beyond remaining 60 capacity
      manager.spawnBatch(
        count: 100, // Only 60 can fit
        areaRadius: 50.0,
        rng: math.Random(5678),
      );

      expect(manager.activeCount, equals(100));
      expect(manager.spawnEntity(), equals(-1));
    });

    test('clear() resets active count, flags, LOD tiers, and frees all slots', () {
      final manager = CrowdRenderManager(maxEntities: 50);
      manager.spawnBatch(count: 30, areaRadius: 50.0);
      expect(manager.activeCount, equals(30));

      manager.clear();
      expect(manager.activeCount, equals(0));
      expect(manager.lod0Count, equals(0));
      expect(manager.lod2InstanceCount, equals(0));
      expect(manager.vatInstanceCount, equals(0));
      expect(manager.culledCount, equals(0));

      for (int i = 0; i < 50; i++) {
        expect(manager.flags[i], equals(0));
        expect(manager.lodTiers[i], equals(CrowdLodTier.culled.id));
      }

      // Can spawn full 50 after clear
      for (int i = 0; i < 50; i++) {
        final id = manager.spawnEntity(x: i.toDouble(), z: 0.0);
        expect(id, isNonNegative);
      }
      expect(manager.activeCount, equals(50));
      expect(manager.spawnEntity(), equals(-1)); // pool exhausted
    });
  });

  group('CrowdRenderManager — Single-Pass Simulation & Kinematics', () {
    test('updates positions and animation times across multiple frames without separate loops', () {
      final manager = CrowdRenderManager(maxEntities: 10);
      final camera = CrowdCamera(x: 0, y: 0, z: 0, yaw: 0, fovDegrees: 120, farPlane: 500);

      final id = manager.spawnEntity(
        x: 0.0,
        y: 0.0,
        z: 30.0,
        vx: 2.0,
        vy: 1.0,
        vz: 3.0,
        animationPhase: 0.5,
        animationSpeed: 2.0,
      );

      // Frame 1: 0.5s step
      manager.update(0.5, camera);
      expect(manager.tickCounter, equals(1));
      expect(manager.lastTickDurationMs, greaterThanOrEqualTo(0.0));

      final pIdx = id * 3;
      expect(manager.positions[pIdx], closeTo(1.0, 0.001)); // 0 + 2 * 0.5
      expect(manager.positions[pIdx + 1], closeTo(0.5, 0.001)); // 0 + 1 * 0.5
      expect(manager.positions[pIdx + 2], closeTo(31.5, 0.001)); // 30 + 3 * 0.5
      expect(manager.animationTimes[id], closeTo(1.5, 0.001)); // 0.5 + 2 * 0.5

      // Frame 2: 0.25s step
      manager.update(0.25, camera);
      expect(manager.tickCounter, equals(2));
      expect(manager.positions[pIdx], closeTo(1.5, 0.001)); // 1.0 + 2 * 0.25
      expect(manager.positions[pIdx + 1], closeTo(0.75, 0.001)); // 0.5 + 1 * 0.25
      expect(manager.positions[pIdx + 2], closeTo(32.25, 0.001)); // 31.5 + 3 * 0.25
      expect(manager.animationTimes[id], closeTo(2.0, 0.001)); // 1.5 + 2 * 0.25
    });

    test('skips inactive slots during kinematics and tier categorization', () {
      final manager = CrowdRenderManager(maxEntities: 10);
      final camera = CrowdCamera(x: 0, y: 0, z: 0, fovDegrees: 90);

      final id0 = manager.spawnEntity(x: 0, z: 10, vx: 5.0);
      final id1 = manager.spawnEntity(x: 0, z: 10, vx: 10.0);

      // Despawn id0
      manager.despawnEntity(id0);

      manager.update(1.0, camera);

      // id0 position should not have integrated
      expect(manager.positions[id0 * 3], equals(0.0));
      // id1 position should have moved
      expect(manager.positions[id1 * 3], equals(10.0));
      expect(manager.activeCount, equals(1));
    });
  });

  group('CrowdRenderManager — LOD Tier Categorization & Dynamic Transitions', () {
    test('correctly categorizes entities into LOD0 (<25m), LOD2 (25-80m), VAT (80-250m), Culled (>250m)', () {
      final manager = CrowdRenderManager(
        maxEntities: 100,
        closeDistanceThreshold: 25.0,
        mediumDistanceThreshold: 80.0,
        maxCullDistance: 250.0,
        maxLod0Entities: 50,
      );

      // Camera facing down +Z axis
      final camera = CrowdCamera(x: 0, y: 0, z: 0, yaw: 0, pitch: 0, fovDegrees: 120, farPlane: 250);

      // Entity 1: Distance = 15m -> LOD0
      final e1 = manager.spawnEntity(x: 0, y: 0, z: 15);
      // Entity 2: Distance = 50m -> LOD2
      final e2 = manager.spawnEntity(x: 0, y: 0, z: 50);
      // Entity 3: Distance = 120m -> VAT
      final e3 = manager.spawnEntity(x: 0, y: 0, z: 120);
      // Entity 4: Distance = 300m -> Culled (> 250m)
      final e4 = manager.spawnEntity(x: 0, y: 0, z: 300);
      // Entity 5: Behind camera (-50m Z) -> Culled by frustum
      final e5 = manager.spawnEntity(x: 0, y: 0, z: -50);

      manager.update(0.016, camera);

      expect(manager.lodTiers[e1], equals(CrowdLodTier.lod0Close.id));
      expect(manager.lodTiers[e2], equals(CrowdLodTier.lod2Instanced.id));
      expect(manager.lodTiers[e3], equals(CrowdLodTier.vatDistant.id));
      expect(manager.lodTiers[e4], equals(CrowdLodTier.culled.id));
      expect(manager.lodTiers[e5], equals(CrowdLodTier.culled.id));

      expect(manager.lod0Count, equals(1));
      expect(manager.lod2InstanceCount, equals(1));
      expect(manager.vatInstanceCount, equals(1));
      expect(manager.culledCount, equals(2));
      expect(manager.lod0Indices[0], equals(e1));
    });

    test('caps LOD0 to maxLod0Entities (e.g. 50) and spills remaining close entities into LOD2', () {
      final manager = CrowdRenderManager(
        maxEntities: 200,
        closeDistanceThreshold: 25.0,
        mediumDistanceThreshold: 80.0,
        maxLod0Entities: 50,
      );

      final camera = CrowdCamera(x: 0, y: 0, z: 0, yaw: 0, fovDegrees: 120);

      // Spawn 70 entities all at distance 10m (< 25m)
      for (int i = 0; i < 70; i++) {
        manager.spawnEntity(x: 0, y: 0, z: 10.0);
      }

      manager.update(0.016, camera);

      // Exactly 50 must be assigned to LOD0 full-fidelity
      expect(manager.lod0Count, equals(50));
      // Remaining 20 must spill to LOD2 instanced mesh
      expect(manager.lod2InstanceCount, equals(20));
      expect(manager.vatInstanceCount, equals(0));
    });

    test('dynamically transitions entity across LOD tiers as it moves towards and past camera', () {
      final manager = CrowdRenderManager(
        maxEntities: 10,
        closeDistanceThreshold: 25.0,
        mediumDistanceThreshold: 80.0,
        maxCullDistance: 250.0,
      );

      final camera = CrowdCamera(x: 0, y: 0, z: 0, yaw: 0, fovDegrees: 120, farPlane: 250.0);

      // Spawn at 150m (VAT distance), moving towards camera along -Z at 50 m/s
      final id = manager.spawnEntity(x: 0, y: 0, z: 150.0, vz: -50.0);

      // Frame 1: z = 150 - 50 * 0.5 = 125m -> VAT
      manager.update(0.5, camera);
      expect(manager.lodTiers[id], equals(CrowdLodTier.vatDistant.id));

      // Frame 2: z = 125 - 50 * 1.5 = 50m -> LOD2 (25m - 80m)
      manager.update(1.5, camera);
      expect(manager.lodTiers[id], equals(CrowdLodTier.lod2Instanced.id));

      // Frame 3: z = 50 - 50 * 0.7 = 15m -> LOD0 (< 25m)
      manager.update(0.7, camera);
      expect(manager.lodTiers[id], equals(CrowdLodTier.lod0Close.id));

      // Frame 4: z = 15 - 50 * 0.6 = -15m -> Behind camera -> Culled
      manager.update(0.6, camera);
      expect(manager.lodTiers[id], equals(CrowdLodTier.culled.id));
    });
  });

  group('CrowdRenderManager — GPU Transform Buffers & 2D Atlas Packing', () {
    test('packs valid 4x4 column-major matrix into lod2TransformBuffer', () {
      final manager = CrowdRenderManager(maxEntities: 10);
      final camera = CrowdCamera(x: 0, y: 0, z: 0, yaw: 0, fovDegrees: 120);

      // Spawn at distance 50m (LOD2 tier), yaw = 0, scale = 2.0
      manager.spawnEntity(
        x: 10.0,
        y: 2.0,
        z: 50.0,
        yaw: 0.0,
        scale: 2.0,
      );

      manager.update(0.016, camera);

      expect(manager.lod2InstanceCount, equals(1));
      final buf = manager.lod2TransformBuffer;

      // Column 0: [cos(0)*2, 0, sin(0)*2, 0] = [2, 0, 0, 0]
      expect(buf[0], closeTo(2.0, 0.001));
      expect(buf[1], closeTo(0.0, 0.001));
      expect(buf[2], closeTo(0.0, 0.001));
      expect(buf[3], closeTo(0.0, 0.001));

      // Column 1: [0, 2, 0, 0]
      expect(buf[4], closeTo(0.0, 0.001));
      expect(buf[5], closeTo(2.0, 0.001));
      expect(buf[6], closeTo(0.0, 0.001));
      expect(buf[7], closeTo(0.0, 0.001));

      // Column 2: [-sin(0)*2, 0, cos(0)*2, 0] = [0, 0, 2, 0]
      expect(buf[8], closeTo(0.0, 0.001));
      expect(buf[9], closeTo(0.0, 0.001));
      expect(buf[10], closeTo(2.0, 0.001));
      expect(buf[11], closeTo(0.0, 0.001));

      // Column 3: Translation [10, 2, 50, 1]
      expect(buf[12], closeTo(10.0, 0.001));
      expect(buf[13], closeTo(2.0, 0.001));
      expect(buf[14], closeTo(50.0, 0.001));
      expect(buf[15], closeTo(1.0, 0.001));
    });

    test('packs 4x4 matrix with non-zero rotation angle', () {
      final manager = CrowdRenderManager(maxEntities: 10);
      final camera = CrowdCamera(x: 0, y: 0, z: 0, yaw: 0, fovDegrees: 120);

      // Yaw = pi / 2 (90 deg), scale = 1.0, distance = 40m
      const yaw = math.pi * 0.5;
      manager.spawnEntity(
        x: 5.0,
        y: 0.0,
        z: 40.0,
        yaw: yaw,
        scale: 1.0,
      );

      manager.update(0.016, camera);

      final buf = manager.lod2TransformBuffer;
      // cos(pi/2) ~ 0, sin(pi/2) ~ 1
      expect(buf[0], closeTo(0.0, 0.001)); // cos(yaw)
      expect(buf[2], closeTo(1.0, 0.001)); // sin(yaw)
      expect(buf[8], closeTo(-1.0, 0.001)); // -sin(yaw)
      expect(buf[10], closeTo(0.0, 0.001)); // cos(yaw)
      expect(buf[12], closeTo(5.0, 0.001)); // posX
      expect(buf[14], closeTo(40.0, 0.001)); // posZ
    });

    test('packs 8-float VAT/Impostor instance packet into vatInstanceBuffer', () {
      final manager = CrowdRenderManager(maxEntities: 10);
      final camera = CrowdCamera(x: 0, y: 0, z: 0, yaw: 0, fovDegrees: 120);

      // Distance 100m -> VAT tier
      manager.spawnEntity(
        x: 15.0,
        y: 0.0,
        z: 100.0,
        yaw: 1.25,
        scale: 1.5,
        archetypeId: 3,
        animationPhase: 0.75,
        animationSpeed: 1.0,
        tintColor: 0xFF55AAEE,
      );

      manager.update(0.016, camera);

      expect(manager.vatInstanceCount, equals(1));
      final vatBuf = manager.vatInstanceBuffer;

      expect(vatBuf[0], closeTo(15.0, 0.001)); // x
      expect(vatBuf[1], closeTo(0.0, 0.001));  // y
      expect(vatBuf[2], closeTo(100.0, 0.001)); // z
      expect(vatBuf[3], closeTo(1.25, 0.001)); // yaw
      expect(vatBuf[4], closeTo(1.5, 0.001));  // scale
      expect(vatBuf[5], closeTo(0.75 + 0.016, 0.005)); // animTime
      expect(vatBuf[6], closeTo(3.0, 0.001));  // archetype
      expect(vatBuf[7].toInt().toUnsigned(32), equals(0xFF55AAEE)); // tintColor
    });

    test('packs 2D Canvas RSTransforms and atlasColors for Flutter / Impeller', () {
      final manager = CrowdRenderManager(maxEntities: 10);
      final camera = CrowdCamera(x: 0, y: 0, z: 0, fovDegrees: 120);

      final id = manager.spawnEntity(
        x: 12.0,
        y: 0.0,
        z: 20.0,
        yaw: 0.0,
        scale: 2.0,
        tintColor: 0xFFAABBCC,
      );

      manager.update(0.016, camera);

      expect(manager.rstTransforms[0], closeTo(2.0, 0.001)); // scos
      expect(manager.rstTransforms[1], closeTo(0.0, 0.001)); // ssin
      expect(manager.rstTransforms[2], closeTo(12.0, 0.001)); // tx
      expect(manager.rstTransforms[3], closeTo(20.0, 0.001)); // ty (posZ)
      expect(manager.atlasColors[id].toUnsigned(32), equals(0xFFAABBCC));
    });
  });

  group('CrowdRenderManager — Spatial Proximity Queries & Nearest Neighbor', () {
    test('registers entities and executes zero-allocation radial queries', () {
      final manager = CrowdRenderManager(maxEntities: 50, spatialCellSize: 10.0);
      final camera = CrowdCamera(x: 0, y: 0, z: 0, fovDegrees: 120);

      final e1 = manager.spawnEntity(x: 10, z: 10);
      final e2 = manager.spawnEntity(x: 12, z: 11);
      final e3 = manager.spawnEntity(x: 15, z: 15);
      final e4 = manager.spawnEntity(x: 100, z: 100); // Far away

      manager.update(0.016, camera);

      final outBuf = Int32List(16);
      final count = manager.queryRadius(
        cx: 10.0,
        cz: 10.0,
        radius: 4.0, // captures e1 (dist=0) and e2 (dist=2.23), not e3 (dist=7.07) or e4
        outBuffer: outBuf,
      );

      expect(count, equals(2));
      final found = [outBuf[0], outBuf[1]];
      expect(found, contains(e1));
      expect(found, contains(e2));
      expect(found, isNot(contains(e3)));
      expect(found, isNot(contains(e4)));
    });

    test('findNearest locates the closest entity correctly', () {
      final manager = CrowdRenderManager(maxEntities: 20);
      final camera = CrowdCamera(x: 0, y: 0, z: 0, fovDegrees: 120);

      manager.spawnEntity(x: 20, z: 20);
      final closest = manager.spawnEntity(x: 5, z: 5);
      manager.spawnEntity(x: 30, z: 30);

      manager.update(0.016, camera);

      final found = manager.findNearest(0, 0, 50.0);
      expect(found, equals(closest));
    });

    test('findNearest returns -1 when no entities are within search radius', () {
      final manager = CrowdRenderManager(maxEntities: 20);
      final camera = CrowdCamera(x: 0, y: 0, z: 0, fovDegrees: 120);

      manager.spawnEntity(x: 100, z: 100);
      manager.update(0.016, camera);

      final found = manager.findNearest(0, 0, 10.0); // radius too small
      expect(found, equals(-1));
    });

    test('findNearest returns correct entity when queried at exact coordinates (dist = 0)', () {
      final manager = CrowdRenderManager(maxEntities: 20);
      final camera = CrowdCamera(x: 0, y: 0, z: 0, fovDegrees: 120);

      final target = manager.spawnEntity(x: 25.0, z: 25.0);
      manager.spawnEntity(x: 26.0, z: 26.0);
      manager.update(0.016, camera);

      final found = manager.findNearest(25.0, 25.0, 10.0);
      expect(found, equals(target));
    });
  });

  group('CrowdRenderManager — Performance & Zero-Allocation Invariants', () {
    test('simulates 10,000 entities in single tick within performance budget', () {
      final manager = CrowdRenderManager(
        maxEntities: 10000,
        closeDistanceThreshold: 25.0,
        mediumDistanceThreshold: 80.0,
        maxCullDistance: 250.0,
        maxLod0Entities: 50,
      );

      // Spawn exactly 10,000 entities in a 180m radius
      manager.spawnBatch(
        count: 10000,
        areaRadius: 180.0,
        originX: 0.0,
        originZ: 50.0,
        rng: math.Random(1337),
      );

      expect(manager.activeCount, equals(10000));

      final camera = CrowdCamera(
        x: 0,
        y: 10,
        z: -10,
        yaw: 0,
        pitch: -0.1,
        fovDegrees: 75.0,
        farPlane: 250.0,
      );

      // Warm up JIT / cache
      for (int i = 0; i < 5; i++) {
        manager.update(0.016, camera);
      }

      // Measure 10 ticks
      final sw = Stopwatch()..start();
      const numFrames = 10;
      for (int i = 0; i < numFrames; i++) {
        manager.update(0.016, camera);
      }
      sw.stop();

      final avgMs = (sw.elapsedMicroseconds / numFrames) / 1000.0;
      // Requirement: execution step in < 5.0ms (SLA target from R4 specification)
      expect(avgMs, lessThan(5.0), reason: 'Average 10K tick time $avgMs ms exceeds 5.0ms budget!');

      // Check tier distribution
      expect(manager.lod0Count, inInclusiveRange(1, 50));
      expect(manager.lod2InstanceCount, greaterThan(100));
      expect(manager.vatInstanceCount, greaterThan(500));
      expect(manager.culledCount, greaterThan(0));
      expect(
        manager.lod0Count + manager.lod2InstanceCount + manager.vatInstanceCount + manager.culledCount,
        equals(10000),
      );
    });

    test('executes 100 consecutive ticks with ZERO heap re-allocations on typed buffers', () {
      final manager = CrowdRenderManager(maxEntities: 10000);
      manager.spawnBatch(count: 10000, areaRadius: 150.0, rng: math.Random(42));
      final camera = CrowdCamera(x: 0, y: 15, z: -20, fovDegrees: 80.0);

      // Capture buffer identity references
      final posRef = manager.positions;
      final velRef = manager.velocities;
      final rotRef = manager.rotations;
      final scaleRef = manager.scales;
      final lod2BufRef = manager.lod2TransformBuffer;
      final vatBufRef = manager.vatInstanceBuffer;
      final lod0IndicesRef = manager.lod0Indices;
      final rstRef = manager.rstTransforms;
      final atlasRectsRef = manager.atlasRects;
      final atlasColorsRef = manager.atlasColors;

      for (int tick = 0; tick < 100; tick++) {
        manager.update(0.016, camera);

        // Verify identical buffer references (strictly zero re-allocations)
        expect(identical(manager.positions, posRef), isTrue);
        expect(identical(manager.velocities, velRef), isTrue);
        expect(identical(manager.rotations, rotRef), isTrue);
        expect(identical(manager.scales, scaleRef), isTrue);
        expect(identical(manager.lod2TransformBuffer, lod2BufRef), isTrue);
        expect(identical(manager.vatInstanceBuffer, vatBufRef), isTrue);
        expect(identical(manager.lod0Indices, lod0IndicesRef), isTrue);
        expect(identical(manager.rstTransforms, rstRef), isTrue);
        expect(identical(manager.atlasRects, atlasRectsRef), isTrue);
        expect(identical(manager.atlasColors, atlasColorsRef), isTrue);
      }
    });
  });

  group('Flutter Pipeline Integration — CrowdCustomPainter & CrowdRenderBridge', () {
    test('CrowdCustomPainter paints debug circles without exceptions across all LOD tiers', () {
      final manager = CrowdRenderManager(
        maxEntities: 100,
        closeDistanceThreshold: 25.0,
        mediumDistanceThreshold: 80.0,
        maxCullDistance: 250.0,
      );
      final camera = CrowdCamera(x: 0, y: 0, z: 0, fovDegrees: 120);

      // Spawn entities in each tier
      manager.spawnEntity(x: 0, z: 10); // LOD0
      manager.spawnEntity(x: 0, z: 50); // LOD2
      manager.spawnEntity(x: 0, z: 120); // VAT
      manager.spawnEntity(x: 0, z: -50); // Culled
      // Off-screen entity (sx > size.width)
      manager.spawnEntity(x: 1000, z: 1000);

      manager.update(0.016, camera);

      final painter = CrowdCustomPainter(
        manager: manager,
        debugVisualizer: true,
        worldToScreenScale: 1.0,
        screenOrigin: const ui.Offset(400, 400),
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = const Size(800, 800);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('CrowdCustomPainter handles empty crowd safely', () {
      final manager = CrowdRenderManager(maxEntities: 10);
      final painter = CrowdCustomPainter(manager: manager, debugVisualizer: true);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => painter.paint(canvas, const Size(400, 400)), returnsNormally);
      recorder.endRecording();
    });

    test('CrowdCustomPainter shouldRepaint responds to tickCounter changes', () {
      final manager = CrowdRenderManager(maxEntities: 10);
      final camera = CrowdCamera();

      final painter1 = CrowdCustomPainter(manager: manager);
      final painter2 = CrowdCustomPainter(manager: manager);

      // Same tickCounter (0) -> should not repaint
      expect(painter2.shouldRepaint(painter1), isFalse);

      // Manager ticks -> tickCounter becomes 1
      manager.update(0.016, camera);
      final painter3 = CrowdCustomPainter(manager: manager);
      expect(painter3.shouldRepaint(painter1), isTrue);
    });

    test('CrowdRenderBridge starts, stops and coordinates ticks', () {
      final manager = CrowdRenderManager(maxEntities: 10);
      final camera = CrowdCamera();
      final bridge = CrowdRenderBridge(manager: manager, camera: camera);

      expect(bridge.isRunning, isFalse);
      bridge.onTick(0.016);
      expect(manager.tickCounter, equals(0)); // Should not tick while stopped

      bridge.start();
      expect(bridge.isRunning, isTrue);
      bridge.onTick(0.016);
      expect(manager.tickCounter, equals(1)); // Tick processed

      bridge.stop();
      expect(bridge.isRunning, isFalse);
      bridge.onTick(0.016);
      expect(manager.tickCounter, equals(1)); // No further ticks

      // Restart
      bridge.start();
      bridge.onTick(0.032);
      expect(manager.tickCounter, equals(2));
    });
  });
}
