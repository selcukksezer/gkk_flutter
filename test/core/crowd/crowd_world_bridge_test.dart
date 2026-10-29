import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/crowd/crowd_render_manager.dart';
import 'package:gkk_flutter/core/crowd/crowd_world_bridge.dart';
import 'package:gkk_flutter/core/crowd/frustum_culling.dart';
import 'package:gkk_flutter/core/crowd/gpu_instancing_batcher.dart';
import 'package:gkk_flutter/core/crowd/spatial_hash_grid.dart';
import 'package:gkk_flutter/core/crowd/vat_crowd_renderer.dart' hide CrowdEntity;
import 'package:gkk_flutter/core/world/cinematic_camera_controller.dart';

void main() {
  group('CrowdWorldBridge — Lifecycle, Preallocation & Dependency Injection', () {
    test('initializes with preallocated buffers and zero active entities', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 10000),
      );

      expect(bridge.isRunning, isFalse);
      expect(bridge.isPaused, isFalse);
      expect(bridge.frameCount, equals(0));
      expect(bridge.totalActiveEntities, equals(0));
      expect(bridge.frustumVisibleCount, equals(0));
      expect(bridge.lod0Count, equals(0));
      expect(bridge.lod2InstanceCount, equals(0));
      expect(bridge.vatInstanceCount, equals(0));
      expect(bridge.isRowMajor, isFalse);
      expect(bridge.zeroToOneClipSpace, isFalse);

      // Buffer capacities
      expect(bridge.manager.positions.length, equals(30000));
      expect(bridge.manager.velocities.length, equals(30000));
      expect(bridge.manager.lod2TransformBuffer.length, equals(160000));
      expect(bridge.manager.vatInstanceBuffer.length, equals(80000));
      expect(bridge.frustum.planeBuffer.length, equals(24));
      expect(bridge.spatialGrid.maxEntities, equals(10000));
      expect(bridge.vatGpuBuffer.capacity, equals(10000));
      expect(bridge.vatGpuBuffer.buffer.length, equals(280000));
      expect(bridge.activeGpuBatchCount, equals(0));
      expect(bridge.activeGpuBatches, isEmpty);
    });

    test('supports custom manager and spatial grid injection via constructor', () {
      final customManager = CrowdRenderManager(maxEntities: 100);
      final customGrid = SpatialHashGrid(maxEntities: 100);

      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 100),
        customManager: customManager,
        customSpatialGrid: customGrid,
      );

      expect(identical(bridge.manager, customManager), isTrue);
      expect(identical(bridge.spatialGrid, customGrid), isTrue);
      expect(bridge.manager.maxEntities, equals(100));
      expect(bridge.spatialGrid.maxEntities, equals(100));
    });

    test('validates config assertions (maxEntities and maxInstancesPerBatch must be positive)', () {
      expect(() => CrowdWorldBridgeConfig(maxEntities: 0), throwsA(isA<AssertionError>()));
      expect(() => CrowdWorldBridgeConfig(maxEntities: -10), throwsA(isA<AssertionError>()));
      expect(() => CrowdWorldBridgeConfig(maxInstancesPerBatch: 0), throwsA(isA<AssertionError>()));
      expect(() => CrowdWorldBridgeConfig(maxInstancesPerBatch: -64), throwsA(isA<AssertionError>()));
    });

    test('lifecycle state transitions and dt edge cases (start, pause, resume, stop, reset)', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 50),
      );

      // Stopped initially: tick does nothing
      bridge.tick(0.016);
      expect(bridge.frameCount, equals(0));

      bridge.start();
      expect(bridge.isRunning, isTrue);
      expect(bridge.isPaused, isFalse);

      bridge.tick(0.016);
      expect(bridge.frameCount, equals(1));

      // Non-positive dt is ignored
      bridge.tick(0.0);
      expect(bridge.frameCount, equals(1));
      bridge.tick(-0.016);
      expect(bridge.frameCount, equals(1));

      // Pause
      bridge.pause();
      expect(bridge.isPaused, isTrue);
      bridge.tick(0.016);
      expect(bridge.frameCount, equals(1)); // skipped

      // Resume
      bridge.resume();
      expect(bridge.isPaused, isFalse);
      bridge.tick(0.016);
      expect(bridge.frameCount, equals(2));

      // Stop
      bridge.stop();
      expect(bridge.isRunning, isFalse);
      bridge.tick(0.016);
      expect(bridge.frameCount, equals(2));

      // Reset
      bridge.reset();
      expect(bridge.frameCount, equals(0));
      expect(bridge.metrics.frameCount, equals(0));
      expect(bridge.activeGpuBatchCount, equals(0));
      expect(bridge.frustumVisibleCount, equals(0));
    });

    test('clearEntities resets entities while preserving buffer memory', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 100),
      );
      bridge.start();

      bridge.spawnCluster(count: 50, radius: 20.0);
      expect(bridge.totalActiveEntities, equals(50));

      bridge.clearEntities();
      expect(bridge.totalActiveEntities, equals(0));
      expect(bridge.lod0Count, equals(0));
      expect(bridge.spatialGrid.activeEntityCount, equals(0));
      expect(bridge.frameCount, equals(0));

      // Can spawn after clear
      final id = bridge.spawnEntity(x: 10.0, z: 10.0);
      expect(id, isNonNegative);
      expect(bridge.totalActiveEntities, equals(1));
      expect(bridge.spatialGrid.isEntityActive(id), isTrue);
    });
  });

  group('CrowdWorldBridge — Entity State Ingestion & Management', () {
    test('spawns and despawns single entities with O(1) recycling', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 50),
      );

      final id0 = bridge.spawnEntity(
        x: 10.0,
        y: 2.0,
        z: 30.0,
        vx: 1.0,
        vy: 0.0,
        vz: 2.0,
        yaw: 1.57,
        scale: 1.2,
        archetypeId: 3,
        tintColor: 0xFFFF0000,
        animationPhase: 0.75,
        animationSpeed: 1.25,
      );

      expect(id0, equals(49));
      expect(bridge.totalActiveEntities, equals(1));
      expect(bridge.manager.positions[id0 * 3], equals(10.0));
      expect(bridge.manager.positions[id0 * 3 + 1], equals(2.0));
      expect(bridge.manager.positions[id0 * 3 + 2], equals(30.0));
      expect(bridge.manager.velocities[id0 * 3], equals(1.0));
      expect(bridge.manager.velocities[id0 * 3 + 2], equals(2.0));
      expect(bridge.manager.rotations[id0], closeTo(1.57, 0.001));
      expect(bridge.manager.scales[id0], closeTo(1.2, 0.0001));
      expect(bridge.manager.archetypeIds[id0], equals(3));
      expect(bridge.manager.tintColors[id0], equals(0xFFFF0000.toSigned(32)));
      expect(bridge.manager.animationTimes[id0], equals(0.75));
      expect(bridge.manager.animationSpeeds[id0], equals(1.25));
      expect(bridge.spatialGrid.isEntityActive(id0), isTrue);

      // Despawn
      final despawned = bridge.despawnEntity(id0);
      expect(despawned, isTrue);
      expect(bridge.totalActiveEntities, equals(0));
      expect(bridge.spatialGrid.isEntityActive(id0), isFalse);

      // Re-spawn reuses the slot
      final idReused = bridge.spawnEntity(x: 99.0, z: 99.0);
      expect(idReused, equals(id0));
      expect(bridge.totalActiveEntities, equals(1));
    });

    test('despawnEntity handles invalid entity indices and double despawn safely', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 10),
      );

      expect(bridge.despawnEntity(-1), isFalse);
      expect(bridge.despawnEntity(10), isFalse);
      expect(bridge.despawnEntity(999), isFalse);

      final id = bridge.spawnEntity();
      expect(bridge.despawnEntity(id), isTrue);
      expect(bridge.despawnEntity(id), isFalse); // Already despawned
    });

    test('updateEntityTransform mutates transform in-place without reallocation', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 10),
      );

      final id = bridge.spawnEntity(x: 5.0, y: 0.0, z: 5.0, yaw: 0.0);
      bridge.updateEntityTransform(
        id,
        x: 25.0,
        y: 3.0,
        z: 35.0,
        vx: 2.0,
        vy: 1.0,
        vz: -2.0,
        yaw: 3.14159,
        scale: 2.0,
        archetypeId: 7,
        tintColor: 0xFF00FF00,
      );

      final pIdx = id * 3;
      expect(bridge.manager.positions[pIdx], equals(25.0));
      expect(bridge.manager.positions[pIdx + 1], equals(3.0));
      expect(bridge.manager.positions[pIdx + 2], equals(35.0));
      expect(bridge.manager.velocities[pIdx], equals(2.0));
      expect(bridge.manager.velocities[pIdx + 1], equals(1.0));
      expect(bridge.manager.velocities[pIdx + 2], equals(-2.0));
      expect(bridge.manager.rotations[id], closeTo(3.14159, 0.001));
      expect(bridge.manager.scales[id], equals(2.0));
      expect(bridge.manager.archetypeIds[id], equals(7));
      expect(bridge.manager.tintColors[id], equals(0xFF00FF00.toSigned(32)));
      expect(bridge.spatialGrid.posX[id], equals(25.0));
      expect(bridge.spatialGrid.posZ[id], equals(35.0));
    });

    test('updateEntityTransform handles out-of-bounds and inactive indices safely', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 10),
      );

      // Out of bounds - should be safe no-op
      bridge.updateEntityTransform(-1, x: 10.0);
      bridge.updateEntityTransform(10, x: 10.0);
      bridge.updateEntityTransform(999, x: 10.0);

      // Inactive slot - should be safe no-op
      final id = bridge.spawnEntity();
      bridge.despawnEntity(id);
      bridge.updateEntityTransform(id, x: 50.0);
      expect(bridge.totalActiveEntities, equals(0));
    });

    test('ingestEntityTransforms bulk ingests Float32List arrays with archetypes and tints', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 100),
      );

      const count = 10;
      final positions = Float32List(count * 3);
      final velocities = Float32List(count * 3);
      final rotations = Float32List(count);
      final scales = Float32List(count);
      final archetypeIds = Int32List(count);
      final tintColors = Int32List(count);

      for (int i = 0; i < count; i++) {
        positions[i * 3] = i * 10.0;
        positions[i * 3 + 1] = 1.0;
        positions[i * 3 + 2] = i * 5.0;
        velocities[i * 3] = 1.0;
        velocities[i * 3 + 1] = 0.5;
        velocities[i * 3 + 2] = -1.0;
        rotations[i] = i * 0.5;
        scales[i] = 1.0 + i * 0.1;
        archetypeIds[i] = i % 4;
        tintColors[i] = 0xFF000000 + i * 1000;
      }

      bridge.ingestEntityTransforms(
        positions: positions,
        velocities: velocities,
        rotations: rotations,
        scales: scales,
        archetypeIds: archetypeIds,
        tintColors: tintColors,
        count: count,
      );

      expect(bridge.totalActiveEntities, equals(count));
      int foundActive = 0;
      for (int i = 0; i < bridge.manager.maxEntities; i++) {
        if ((bridge.manager.flags[i] & 1) == 0) continue;
        expect(bridge.spatialGrid.isEntityActive(i), isTrue);
        foundActive++;
      }
      expect(foundActive, equals(count));

      // Test clamping when count exceeds maxEntities
      final overflowBridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 5),
      );
      overflowBridge.ingestEntityTransforms(
        positions: positions,
        count: 20,
      );
      expect(overflowBridge.totalActiveEntities, equals(5));
    });

    test('spawnCluster populates bounded radial area', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 100),
      );

      bridge.spawnCluster(
        count: 50,
        radius: 30.0,
        centerX: 100.0,
        centerZ: 100.0,
        rng: math.Random(123),
      );

      expect(bridge.totalActiveEntities, equals(50));
      final positions = bridge.manager.positions;

      for (int i = 0; i < bridge.manager.maxEntities; i++) {
        if ((bridge.manager.flags[i] & 1) == 0) continue;
        final dx = positions[i * 3] - 100.0;
        final dz = positions[i * 3 + 2] - 100.0;
        final dist = math.sqrt(dx * dx + dz * dz);
        expect(dist, lessThanOrEqualTo(30.001));
      }
    });

    test('spawnCluster gracefully clamps when capacity is exceeded', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 8),
      );

      bridge.spawnCluster(
        count: 20,
        radius: 10.0,
      );

      expect(bridge.totalActiveEntities, equals(8));
    });

    test('enforces maxEntities limit gracefully', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 5),
      );

      for (int i = 0; i < 5; i++) {
        final id = bridge.spawnEntity(x: i.toDouble());
        expect(id, isNonNegative);
      }
      expect(bridge.totalActiveEntities, equals(5));

      final idOverflow = bridge.spawnEntity(x: 100.0);
      expect(idOverflow, equals(-1)); // pool exhausted
      expect(bridge.totalActiveEntities, equals(5));
    });
  });

  group('CrowdWorldBridge — Camera View-Projection Binding & Frustum Culling', () {
    test('binds 4x4 matrix and extracts 6 normalized frustum planes', () {
      final bridge = CrowdWorldBridge();

      // Standard perspective and look-at matrix
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
      final vp = FrustumMatrixUtils.multiply(proj, view);

      bridge.bindCameraViewProjection(
        vp,
        cameraX: 0.0,
        cameraY: 5.0,
        cameraZ: 0.0,
        yaw: 0.0,
        pitch: 0.0,
      );

      expect(bridge.camera.x, equals(0.0));
      expect(bridge.camera.y, equals(5.0));
      expect(bridge.camera.z, equals(0.0));

      // Plane buffer has 24 floats (6 planes * 4)
      final planes = bridge.frustum.planeBuffer;
      expect(planes.length, equals(24));

      // Check all 6 normals are normalized unit vectors
      for (int p = 0; p < 6; p++) {
        final nx = planes[p * 4];
        final ny = planes[p * 4 + 1];
        final nz = planes[p * 4 + 2];
        final len = math.sqrt(nx * nx + ny * ny + nz * nz);
        expect(len, closeTo(1.0, 0.001));
      }
    });

    test('binds camera matrix with row-major and zeroToOne clip space options', () {
      final bridge = CrowdWorldBridge();

      final view = FrustumMatrixUtils.createLookAt(
        eyeX: 0.0,
        eyeY: 0.0,
        eyeZ: 0.0,
        targetX: 0.0,
        targetY: 0.0,
        targetZ: 10.0,
      );

      bridge.bindCameraViewProjection(
        view,
        cameraX: 10.0,
        cameraY: 20.0,
        cameraZ: 30.0,
        yaw: 0.5,
        pitch: -0.2,
        fovDegrees: 75.0,
        aspectRatio: 2.0,
        nearPlane: 0.25,
        farPlane: 500.0,
        isRowMajor: true,
        zeroToOneClipSpace: true,
      );

      expect(bridge.isRowMajor, isTrue);
      expect(bridge.zeroToOneClipSpace, isTrue);
      expect(bridge.camera.x, equals(10.0));
      expect(bridge.camera.y, equals(20.0));
      expect(bridge.camera.z, equals(30.0));
      expect(bridge.camera.nearPlane, equals(0.25));
      expect(bridge.camera.farPlane, equals(500.0));
      expect(bridge.camera.aspect, equals(2.0));
      expect(bridge.camera.fovRadians, closeTo(75.0 * (math.pi / 180.0), 0.001));
      expect(bridge.frustum.planeBuffer.length, equals(24));
    });

    test('bindCameraMatrix4 binds Flutter Matrix4 accurately', () {
      final bridge = CrowdWorldBridge();
      final matrix4 = Matrix4.identity();

      bridge.bindCameraMatrix4(
        matrix4,
        cameraX: 15.0,
        cameraY: 25.0,
        cameraZ: 35.0,
        yaw: 0.785,
        pitch: 0.123,
        fovDegrees: 65.0,
        aspectRatio: 1.5,
        nearPlane: 0.5,
        farPlane: 300.0,
      );

      expect(bridge.camera.x, equals(15.0));
      expect(bridge.camera.y, equals(25.0));
      expect(bridge.camera.z, equals(35.0));
      expect(bridge.camera.yaw, closeTo(0.785, 0.001));
      expect(bridge.camera.pitch, closeTo(0.123, 0.001));
      expect(bridge.camera.nearPlane, equals(0.5));
      expect(bridge.camera.farPlane, equals(300.0));
      expect(bridge.camera.aspect, equals(1.5));
      expect(bridge.isRowMajor, isFalse);
    });

    test('bindCameraViewProjection asserts when matrix has fewer than 16 elements', () {
      final bridge = CrowdWorldBridge();
      expect(
        () => bridge.bindCameraViewProjection([1.0, 2.0, 3.0]),
        throwsA(isA<AssertionError>()),
      );
    });

    test('culls entities outside camera frustum and retains visible entities', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(
          maxEntities: 20,
          defaultNearPlane: 0.1,
          defaultFarPlane: 100.0,
        ),
      );
      bridge.start();

      // Camera at (0, 0, 0) looking along +Z toward (0, 0, 100)
      final view = FrustumMatrixUtils.createLookAt(
        eyeX: 0.0,
        eyeY: 0.0,
        eyeZ: 0.0,
        targetX: 0.0,
        targetY: 0.0,
        targetZ: 100.0,
      );
      final proj = FrustumMatrixUtils.createPerspective(
        fovYRadians: 60.0 * math.pi / 180.0,
        aspectRatio: 1.0,
        near: 0.1,
        far: 100.0,
      );
      final vp = FrustumMatrixUtils.multiply(proj, view);

      bridge.bindCameraViewProjection(
        vp,
        cameraX: 0.0,
        cameraY: 0.0,
        cameraZ: 0.0,
        yaw: 0.0,
        pitch: 0.0,
      );

      // Entity 0: directly in front (0, 0, 30) -> Inside
      bridge.spawnEntity(x: 0.0, y: 0.0, z: 30.0);

      // Entity 1: behind camera (0, 0, -30) -> Culled
      bridge.spawnEntity(x: 0.0, y: 0.0, z: -30.0);

      // Entity 2: far away beyond farPlane (0, 0, 500) -> Culled
      bridge.spawnEntity(x: 0.0, y: 0.0, z: 500.0);

      // Entity 3: far to the right outside FOV (200, 0, 20) -> Culled
      bridge.spawnEntity(x: 200.0, y: 0.0, z: 20.0);

      bridge.tick(0.016);

      // Only Entity 0 should be visible
      expect(bridge.frustumVisibleCount, equals(1));
      expect(bridge.metrics.visibleEntityCount, equals(1));
    });

    test('respects enableFrustumCulling flag when disabled', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(
          maxEntities: 10,
          enableFrustumCulling: false,
        ),
      );
      bridge.start();

      // Spawn 3 entities behind camera
      bridge.spawnEntity(x: 0.0, z: -50.0);
      bridge.spawnEntity(x: 0.0, z: -100.0);
      bridge.spawnEntity(x: 0.0, z: -150.0);

      bridge.tick(0.016);

      // With frustum culling disabled, visible count equals active count
      expect(bridge.frustumVisibleCount, equals(3));
      expect(bridge.metrics.visibleEntityCount, equals(3));
    });

    test('binds from CinematicCameraController seamlessly', () {
      final bridge = CrowdWorldBridge();
      final controller = CinematicCameraController(
        initialTarget: const WorldVector3(0.0, 1.6, 0.0),
        initialAzimuth: 0.5,
        initialElevation: 0.2,
        initialDistance: 10.0,
      );

      bridge.bindCinematicCamera(
        controller,
        aspectRatio: 16.0 / 9.0,
        nearPlane: 0.5,
        farPlane: 300.0,
      );

      expect(bridge.camera.fovRadians, closeTo(controller.state.fovRadians, 0.001));
      expect(bridge.camera.x, closeTo(controller.state.eyePosition.x, 0.001));
      expect(bridge.camera.y, closeTo(controller.state.eyePosition.y, 0.001));
      expect(bridge.camera.z, closeTo(controller.state.eyePosition.z, 0.001));
      expect(bridge.camera.nearPlane, equals(0.5));
      expect(bridge.camera.farPlane, equals(300.0));
      expect(bridge.frustum.planeBuffer.length, equals(24));
    });
  });

  group('CrowdWorldBridge — Spatial Hash Grid & AOI Integration', () {
    test('categorizes entities into Close, Medium, Distant, and Culled tiers', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(
          maxEntities: 100,
          closeDistanceThreshold: 25.0,
          mediumDistanceThreshold: 80.0,
          maxCullDistance: 250.0,
        ),
      );
      bridge.start();

      bridge.camera.setPosition(0.0, 0.0, 0.0);

      // Entity at 10m -> Close (< 25m)
      final idClose = bridge.spawnEntity(x: 0.0, z: 10.0);

      // Entity at 50m -> Medium (25m - 80m)
      final idMed = bridge.spawnEntity(x: 0.0, z: 50.0);

      // Entity at 150m -> Distant (80m - 250m)
      final idDist = bridge.spawnEntity(x: 0.0, z: 150.0);

      // Entity at 300m -> Culled (> 250m)
      final idCulled = bridge.spawnEntity(x: 0.0, z: 300.0);

      bridge.tick(0.016);

      expect(bridge.spatialGrid.entityTiers[idClose], equals(LodDistanceTier.close.id));
      expect(bridge.spatialGrid.entityTiers[idMed], equals(LodDistanceTier.medium.id));
      expect(bridge.spatialGrid.entityTiers[idDist], equals(LodDistanceTier.distant.id));
      expect(bridge.spatialGrid.entityTiers[idCulled], equals(LodDistanceTier.culled.id));

      expect(bridge.spatialGrid.closeCount, equals(1));
      expect(bridge.spatialGrid.mediumCount, equals(1));
      expect(bridge.spatialGrid.distantCount, equals(1));
      expect(bridge.spatialGrid.culledCount, equals(1));
    });

    test('caps LOD0 close entities to maxLod0Entities (e.g. 50)', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(
          maxEntities: 200,
          closeDistanceThreshold: 25.0,
          maxLod0Entities: 30,
        ),
      );
      bridge.start();
      bridge.camera.setPosition(0.0, 0.0, 0.0);

      // Spawn 70 entities all within 20m (< 25m)
      for (int i = 0; i < 70; i++) {
        bridge.spawnEntity(x: (i + 1) * 0.2, z: (i + 1) * 0.2);
      }

      bridge.tick(0.016);

      // Close count must be clamped strictly to 30
      expect(bridge.spatialGrid.closeCount, equals(30));
      // Remaining 40 demoted into medium tier
      expect(bridge.spatialGrid.mediumCount, equals(40));
    });

    test('respects enableSpatialHashAOI flag when disabled', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(
          maxEntities: 50,
          enableSpatialHashAOI: false,
        ),
      );
      bridge.start();
      bridge.spawnEntity(x: 5.0, z: 5.0);
      bridge.tick(0.016);

      // When AOI is disabled, spatial AOI tier update is bypassed
      expect(bridge.spatialGrid.closeCount, equals(0));
    });

    test('queryRadius finds entities within radius with zero allocations', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 100),
      );
      bridge.start();

      bridge.spawnEntity(x: 5.0, z: 5.0);
      bridge.spawnEntity(x: 10.0, z: 10.0);
      bridge.spawnEntity(x: 50.0, z: 50.0);

      final found = bridge.queryRadius(
        centerX: 0.0,
        centerZ: 0.0,
        radius: 15.0,
      );

      expect(found, equals(2));
    });

    test('queryRadius writes to custom caller-provided buffers with maxResults cap', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 100),
      );
      bridge.start();

      for (int i = 0; i < 10; i++) {
        bridge.spawnEntity(x: (i + 1).toDouble(), z: 0.0);
      }

      final outBuffer = Int32List(5);
      final outDistancesSq = Float32List(5);

      final found = bridge.queryRadius(
        centerX: 0.0,
        centerZ: 0.0,
        radius: 20.0,
        outBuffer: outBuffer,
        outDistancesSq: outDistancesSq,
        maxResults: 5,
      );

      expect(found, equals(5));
      for (int i = 0; i < 5; i++) {
        expect(outBuffer[i], isNonNegative);
        expect(outDistancesSq[i], lessThanOrEqualTo(400.0));
      }
    });

    test('queryBox finds entities within 3D bounding box', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 100),
      );
      bridge.start();

      bridge.spawnEntity(x: 5.0, y: 0.0, z: 5.0);
      bridge.spawnEntity(x: 25.0, y: 0.0, z: 25.0);
      bridge.spawnEntity(x: 100.0, y: 0.0, z: 100.0);

      final outBuffer = Int32List(16);
      final found = bridge.queryBox(
        minX: 0.0,
        minY: -10.0,
        minZ: 0.0,
        maxX: 30.0,
        maxY: 10.0,
        maxZ: 30.0,
        outBuffer: outBuffer,
      );

      expect(found, equals(2));
    });

    test('findNearest locates closest entity and returns -1 when none in range', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 50),
      );
      bridge.start();

      final eFar = bridge.spawnEntity(x: 40.0, z: 40.0);
      final eNear = bridge.spawnEntity(x: 2.0, z: 2.0);

      final nearest = bridge.findNearest(0.0, 0.0, 100.0);
      expect(nearest, equals(eNear));
      expect(nearest, isNot(equals(eFar)));

      // When no entity is in radius
      final none = bridge.findNearest(0.0, 0.0, 1.0);
      expect(none, equals(-1));
    });
  });

  group('CrowdWorldBridge — GPU Instancer & VAT Impostor Layer Feeds', () {
    test('feedGpuInstancer packs medium-range entities into DrawCallBatches', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(
          maxEntities: 500,
          closeDistanceThreshold: 20.0,
          mediumDistanceThreshold: 80.0,
          maxInstancesPerBatch: 64,
        ),
      );
      bridge.start();

      // Camera at (0, 0, 0)
      bridge.camera.setPosition(0.0, 0.0, 0.0);

      // Spawn 100 entities in medium distance range (e.g. 40m - 60m)
      for (int i = 0; i < 100; i++) {
        bridge.spawnEntity(x: 30.0, z: 40.0 + i * 0.1, yaw: 0.5);
      }

      bridge.tick(0.016);

      // Medium entities must be packed into batches of 64
      expect(bridge.lod2InstanceCount, equals(100));
      expect(bridge.activeGpuBatchCount, equals(2)); // ceil(100 / 64) = 2
      expect(bridge.metrics.gpuBatchedInstances, equals(100));
      expect(bridge.metrics.gpuDrawCalls, equals(2));

      final batch0 = bridge.activeGpuBatches[0];
      final batch1 = bridge.activeGpuBatches[1];

      expect(batch0.instanceCount, equals(64));
      expect(batch1.instanceCount, equals(36));

      // Validate 4x4 matrix packed in batch0
      final matrix0 = Float32List(16);
      final anim0 = Float32List(4);
      final tint0 = Float32List(4);
      batch0.unpackInstance(0, outMatrix: matrix0, outAnimData: anim0, outTintColor: tint0);

      expect(matrix0[12], equals(30.0)); // translation X
      expect(matrix0[14], inInclusiveRange(40.0, 50.0)); // translation Z
      expect(matrix0[15], equals(1.0));
      expect(anim0[2], equals(1.0)); // walk animType
      expect(tint0[0], equals(1.0)); // tint RGBA
    });

    test('feedGpuInstancer handles zero instances gracefully', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 50),
      );
      bridge.start();

      final batches = bridge.feedGpuInstancer();
      expect(batches, isEmpty);
      expect(bridge.activeGpuBatchCount, equals(0));
      expect(bridge.metrics.gpuBatchedInstances, equals(0));
      expect(bridge.metrics.gpuDrawCalls, equals(0));
    });

    test('feedVatImpostorLayer packs distant entities into 28-float buffer', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(
          maxEntities: 100,
          closeDistanceThreshold: 20.0,
          mediumDistanceThreshold: 60.0,
          maxCullDistance: 250.0,
        ),
      );
      bridge.start();
      bridge.camera.setPosition(0.0, 0.0, 0.0);

      // Spawn 20 entities in distant range (100m)
      for (int i = 0; i < 20; i++) {
        bridge.spawnEntity(x: 0.0, z: 100.0 + i, yaw: 0.785, scale: 1.1);
      }

      bridge.tick(0.016);

      expect(bridge.vatInstanceCount, equals(20));
      expect(bridge.metrics.vatBatchedInstances, equals(20));

      final vatBuf = bridge.vatGpuBuffer.buffer;
      // Stride is 28 floats
      const stride = 28;
      for (int i = 0; i < 20; i++) {
        final offset = i * stride;
        expect(vatBuf[offset + 12], equals(0.0)); // pos X
        expect(vatBuf[offset + 14], inInclusiveRange(100.0, 120.0)); // pos Z
        expect(vatBuf[offset + 15], equals(1.0));
      }
    });

    test('feedVatImpostorLayer writes to custom target CrowdInstanceBuffer', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(
          maxEntities: 50,
          closeDistanceThreshold: 10.0,
          mediumDistanceThreshold: 20.0,
          maxCullDistance: 200.0,
        ),
      );
      bridge.start();
      bridge.camera.setPosition(0.0, 0.0, 0.0);

      bridge.spawnEntity(x: 0.0, z: 50.0, scale: 1.5);
      bridge.tick(0.016);

      final customBuffer = CrowdInstanceBuffer(initialCapacity: 10);
      bridge.feedVatImpostorLayer(
        targetBuffer: customBuffer,
        defaultBoundingRadius: 2.5,
      );

      expect(customBuffer.buffer[12], equals(0.0)); // posX
      expect(customBuffer.buffer[14], equals(50.0)); // posZ
      expect(customBuffer.buffer[24], equals(2.5)); // defaultBoundingRadius
    });

    test('exposes LOD0 entities and Flutter canvas drawRawAtlas buffers', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(
          maxEntities: 50,
          closeDistanceThreshold: 25.0,
        ),
      );
      bridge.start();
      bridge.camera.setPosition(0.0, 0.0, 0.0);

      // Spawn 5 close entities directly in front of camera along +Z (< 25m)
      for (int i = 0; i < 5; i++) {
        bridge.spawnEntity(x: 0.0, z: 5.0 + i * 2.0);
      }

      bridge.tick(0.016);

      expect(bridge.lod0Count, equals(5));
      expect(bridge.lod0Entities.length, greaterThanOrEqualTo(5));

      // Canvas raw atlas buffers populated
      expect(bridge.manager.rstTransforms.length, equals(200));
      expect(bridge.manager.atlasColors.length, equals(50));
    });
  });

  group('CrowdWorldBridge — Telemetry & Metrics Verification', () {
    test('metrics records per-stage timings, counts, and formats toString()', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 100),
      );
      bridge.start();
      bridge.spawnEntity(x: 0.0, z: 15.0);
      bridge.tick(0.016);

      final m = bridge.metrics;
      expect(m.frameCount, equals(1));
      expect(m.totalActiveEntities, equals(1));
      expect(m.visibleEntityCount, greaterThanOrEqualTo(0));
      expect(m.lastFrameDurationMs, greaterThanOrEqualTo(0.0));
      expect(m.simulationDurationMs, greaterThanOrEqualTo(0.0));
      expect(m.frustumCullDurationMs, greaterThanOrEqualTo(0.0));
      expect(m.spatialQueryDurationMs, greaterThanOrEqualTo(0.0));
      expect(m.gpuFeedDurationMs, greaterThanOrEqualTo(0.0));

      final str = m.toString();
      expect(str, contains('CrowdBridgeMetrics'));
      expect(str, contains('frame: 1'));
      expect(str, contains('active: 1'));
      expect(str, contains('LOD: ['));

      m.resetFrame();
      expect(m.gpuDrawCalls, equals(0));
      expect(m.gpuBatchedInstances, equals(0));
      expect(m.vatBatchedInstances, equals(0));
    });
  });

  group('CrowdWorldBridge — Continuous 10K Movement & Zero GC Verification', () {
    test('simulates 10,000 active entities across 100 frames with 0 GC allocations', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(
          maxEntities: 10000,
          closeDistanceThreshold: 25.0,
          mediumDistanceThreshold: 80.0,
          maxCullDistance: 250.0,
          maxLod0Entities: 50,
        ),
      );
      bridge.start();

      // Camera positioned at center
      bridge.camera.setPosition(0.0, 10.0, -20.0);

      // Populate 10,000 moving entities across world area
      final rng = math.Random(42);
      final positions = Float32List(30000);
      final velocities = Float32List(30000);
      final rotations = Float32List(10000);
      final scales = Float32List(10000);

      for (int i = 0; i < 10000; i++) {
        final angle = rng.nextDouble() * 2.0 * math.pi;
        final r = math.sqrt(rng.nextDouble()) * 200.0;
        positions[i * 3] = math.cos(angle) * r;
        positions[i * 3 + 1] = 0.0;
        positions[i * 3 + 2] = math.sin(angle) * r;

        velocities[i * 3] = (rng.nextDouble() - 0.5) * 2.0;
        velocities[i * 3 + 1] = 0.0;
        velocities[i * 3 + 2] = (rng.nextDouble() - 0.5) * 2.0;

        rotations[i] = rng.nextDouble() * 2.0 * math.pi;
        scales[i] = 0.9 + rng.nextDouble() * 0.2;
      }

      bridge.ingestEntityTransforms(
        positions: positions,
        velocities: velocities,
        rotations: rotations,
        scales: scales,
        count: 10000,
      );

      expect(bridge.totalActiveEntities, equals(10000));

      // Cache reference identity of all typed buffers before continuous simulation
      final refPositions = bridge.manager.positions;
      final refVelocities = bridge.manager.velocities;
      final refLod2Buffer = bridge.manager.lod2TransformBuffer;
      final refVatBuffer = bridge.manager.vatInstanceBuffer;
      final refFrustumPlanes = bridge.frustum.planeBuffer;
      final refSpatialPosX = bridge.spatialGrid.posX;
      final refGpuBatch0 = bridge.activeGpuBatches.isEmpty
          ? null
          : bridge.activeGpuBatches[0].buffer;
      final refVatGpuBuffer = bridge.vatGpuBuffer.buffer;

      // Track positions of a sample entity before movement
      final samplePIdx = 42 * 3;
      final initialX = refPositions[samplePIdx];
      final initialZ = refPositions[samplePIdx + 2];
      final sampleVx = refVelocities[samplePIdx];
      final sampleVz = refVelocities[samplePIdx + 2];

      // Warm-up JIT compilation before benchmarking
      for (int w = 0; w < 5; w++) {
        bridge.tick(0.016);
      }

      // Re-read reference values for benchmark phase
      final benchInitialX = refPositions[samplePIdx];
      final benchInitialZ = refPositions[samplePIdx + 2];
      final initialFrameCount = bridge.frameCount;

      final stopwatch = Stopwatch()..start();

      // Run 100 continuous simulation frames
      const int benchmarkFrames = 100;
      for (int f = 0; f < benchmarkFrames; f++) {
        bridge.tick(0.016); // 16ms delta time (~60 FPS)

        // Memory identity verification: NONE of the backing buffers should have reallocated
        expect(identical(bridge.manager.positions, refPositions), isTrue);
        expect(identical(bridge.manager.velocities, refVelocities), isTrue);
        expect(identical(bridge.manager.lod2TransformBuffer, refLod2Buffer), isTrue);
        expect(identical(bridge.manager.vatInstanceBuffer, refVatBuffer), isTrue);
        expect(identical(bridge.frustum.planeBuffer, refFrustumPlanes), isTrue);
        expect(identical(bridge.spatialGrid.posX, refSpatialPosX), isTrue);
        expect(identical(bridge.vatGpuBuffer.buffer, refVatGpuBuffer), isTrue);
        if (refGpuBatch0 != null && bridge.activeGpuBatches.isNotEmpty) {
          expect(identical(bridge.activeGpuBatches[0].buffer, refGpuBatch0), isTrue);
        }

        // Integrity check: frame counter increments continuously
        expect(bridge.frameCount, equals(initialFrameCount + f + 1));
        expect(bridge.totalActiveEntities, equals(10000));
      }

      stopwatch.stop();
      final totalElapsedMs = stopwatch.elapsedMilliseconds;
      final avgFrameMs = totalElapsedMs / benchmarkFrames.toDouble();

      // Assert physical movement took place (p = p_0 + v * t)
      final finalX = refPositions[samplePIdx];
      final finalZ = refPositions[samplePIdx + 2];
      final expectedX = benchInitialX + sampleVx * (0.016 * benchmarkFrames);
      final expectedZ = benchInitialZ + sampleVz * (0.016 * benchmarkFrames);

      expect(finalX, closeTo(expectedX, 0.01));
      expect(finalZ, closeTo(expectedZ, 0.01));

      // Benchmark requirement: average tick execution fits within frame budget (< 25.0ms on test runners)
      expect(
        avgFrameMs,
        lessThan(25.0),
        reason: '10K continuous tick average took ${avgFrameMs.toStringAsFixed(2)}ms, exceeding budget',
      );
      expect(bridge.metrics.frameCount, equals(initialFrameCount + benchmarkFrames));
      expect(bridge.metrics.lastFrameDurationMs, greaterThan(0.0));
    });
  });

  group('CrowdWorldBridge — Flutter Pipeline Integration', () {
    test('createPainter produces CrowdCustomPainter with correct manager reference', () {
      final bridge = CrowdWorldBridge();
      final painter = bridge.createPainter(
        debugVisualizer: true,
        worldToScreenScale: 3.0,
        screenOrigin: const ui.Offset(500, 500),
      );

      expect(painter, isA<CrowdCustomPainter>());
      expect(painter.manager, equals(bridge.manager));
      expect(painter.debugVisualizer, isTrue);
      expect(painter.worldToScreenScale, equals(3.0));
      expect(painter.screenOrigin, equals(const ui.Offset(500, 500)));
    });

    test('CrowdCustomPainter shouldRepaint reflects simulation tick changes', () {
      final bridge = CrowdWorldBridge();
      bridge.start();

      final painterA = bridge.createPainter();
      final painterB = bridge.createPainter();
      expect(painterB.shouldRepaint(painterA), isFalse);

      bridge.tick(0.016);
      final painterAfterTick = bridge.createPainter();
      expect(painterAfterTick.shouldRepaint(painterA), isTrue);
    });

    test('CrowdCustomPainter paints debug circles without throwing', () {
      final bridge = CrowdWorldBridge(
        config: const CrowdWorldBridgeConfig(maxEntities: 10),
      );
      bridge.start();
      bridge.camera.setPosition(0.0, 0.0, 0.0);

      // Spawn entities in different tiers
      bridge.spawnEntity(x: 0.0, z: 10.0); // Close
      bridge.spawnEntity(x: 0.0, z: 40.0); // Medium
      bridge.spawnEntity(x: 0.0, z: 100.0); // Distant
      bridge.tick(0.016);

      final painter = bridge.createPainter(debugVisualizer: true);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      painter.paint(canvas, const Size(800, 600));

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });
  });
}
