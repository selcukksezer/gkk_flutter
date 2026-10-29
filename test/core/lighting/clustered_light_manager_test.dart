import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/lighting/clustered_light_manager.dart';

void main() {
  group('ClusteredLightManager — Zero Per-Entity Point Lights (R4 Compliance)', () {
    test('Prohibits instantiation of ClusteredLight with attachedEntityId', () {
      expect(
        () => ClusteredLight(
          id: 1,
          x: 0.0,
          y: 2.0,
          z: 0.0,
          radius: 10.0,
          attachedEntityId: 42,
        ),
        throwsA(isA<DynamicPointLightViolationException>()),
      );
    });

    test('prohibitEntityDynamicPointLight throws DynamicPointLightViolationException', () {
      expect(
        () => ClusteredLightManager.prohibitEntityDynamicPointLight(101, 'PlayerKnight'),
        throwsA(
          isA<DynamicPointLightViolationException>().having(
            (e) => e.entityId,
            'entityId',
            equals(101),
          ),
        ),
      );
    });

    test('assertZeroEntityPointLights detects forbidden point light maps', () {
      final validEntities = [
        {'id': 1, 'type': 'Warrior', 'lod': 0},
        {'id': 2, 'type': 'Mage', 'lod': 1},
      ];
      expect(
        () => ClusteredLightManager.assertZeroEntityPointLights(validEntities),
        returnsNormally,
      );

      final invalidEntities = [
        {'id': 1, 'type': 'Warrior', 'lod': 0},
        {'id': 2, 'type': 'Mage', 'pointLight': {'radius': 10.0}},
      ];
      expect(
        () => ClusteredLightManager.assertZeroEntityPointLights(invalidEntities),
        throwsA(isA<DynamicPointLightViolationException>()),
      );
    });

    test('Light radius must be strictly positive', () {
      expect(
        () => ClusteredLight(id: 1, x: 0, y: 0, z: 0, radius: 0.0),
        throwsArgumentError,
      );
      expect(
        () => ClusteredLight(id: 1, x: 0, y: 0, z: 0, radius: -5.0),
        throwsArgumentError,
      );
    });
  });

  group('ClusterGridBounds — 3D Spatial Voxel & Screen-Space Partitioning', () {
    late ClusterGridBounds bounds;

    setUp(() {
      bounds = ClusterGridBounds(
        minX: -100.0,
        minY: -10.0,
        minZ: -100.0,
        maxX: 100.0,
        maxY: 30.0,
        maxZ: 100.0,
        dimX: 16,
        dimY: 8,
        dimZ: 16,
        zNear: 0.5,
        zFar: 200.0,
      );
    });

    test('Total clusters equals product of dimensions', () {
      expect(bounds.totalClusters, equals(16 * 8 * 16)); // 2048
      expect(bounds.cellSizeX, closeTo(12.5, 0.001));
      expect(bounds.cellSizeY, closeTo(5.0, 0.001));
      expect(bounds.cellSizeZ, closeTo(12.5, 0.001));
    });

    test('worldToVoxel clamps out-of-bounds coordinates correctly', () {
      // Point well below min
      final (cMinX, cMinY, cMinZ) = bounds.worldToVoxel(-500.0, -100.0, -500.0);
      expect(cMinX, equals(0));
      expect(cMinY, equals(0));
      expect(cMinZ, equals(0));

      // Point well above max
      final (cMaxX, cMaxY, cMaxZ) = bounds.worldToVoxel(500.0, 100.0, 500.0);
      expect(cMaxX, equals(15));
      expect(cMaxY, equals(7));
      expect(cMaxZ, equals(15));

      // Origin (0, 0, 0)
      final (cx, cy, cz) = bounds.worldToVoxel(0.0, 0.0, 0.0);
      expect(cx, equals(8));
      expect(cy, equals(2));
      expect(cz, equals(8));
    });

    test('voxelToLinearIndex and linearIndexToVoxel roundtrip for all cells', () {
      for (int cz = 0; cz < bounds.dimZ; cz++) {
        for (int cy = 0; cy < bounds.dimY; cy++) {
          for (int cx = 0; cx < bounds.dimX; cx++) {
            final linear = bounds.voxelToLinearIndex(cx, cy, cz);
            final (rx, ry, rz) = bounds.linearIndexToVoxel(linear);
            expect(rx, equals(cx));
            expect(ry, equals(cy));
            expect(rz, equals(cz));
          }
        }
      }
    });

    test('getClusterAABB computes exact non-overlapping cell boundaries', () {
      final (minX, minY, minZ, maxX, maxY, maxZ) = bounds.getClusterAABB(0, 0, 0);
      expect(minX, closeTo(-100.0, 0.001));
      expect(minY, closeTo(-10.0, 0.001));
      expect(minZ, closeTo(-100.0, 0.001));
      expect(maxX, closeTo(-87.5, 0.001));
      expect(maxY, closeTo(-5.0, 0.001));
      expect(maxZ, closeTo(-87.5, 0.001));
    });

    test('depthToSlice performs logarithmic depth distribution', () {
      expect(bounds.depthToSlice(0.1), equals(0)); // <= zNear
      expect(bounds.depthToSlice(0.5), equals(0)); // == zNear
      expect(bounds.depthToSlice(300.0), equals(15)); // >= zFar

      // Mid-depth values scale logarithmically
      final s1 = bounds.depthToSlice(2.0);
      final s2 = bounds.depthToSlice(10.0);
      final s3 = bounds.depthToSlice(50.0);
      expect(s1, lessThan(s2));
      expect(s2, lessThan(s3));
      expect(s3, lessThan(16));
    });

    test('screenSpaceToCluster maps UV and linear depth to cluster index', () {
      final (cx0, cy0, cz0) = bounds.screenSpaceToCluster(0.0, 0.0, 0.5);
      expect(cx0, equals(0));
      expect(cy0, equals(0));
      expect(cz0, equals(0));

      final (cx1, cy1, cz1) = bounds.screenSpaceToCluster(0.999, 0.999, 199.0);
      expect(cx1, equals(15));
      expect(cy1, equals(7));
      expect(cz1, equals(15));
    });
  });

  group('ClusterGridBounds — Sphere-AABB Intersection (Jim Arvo Algorithm)', () {
    test('Sphere centered inside AABB returns true', () {
      final overlap = ClusterGridBounds.testSphereAABBOverlap(
        sphereX: 0.0,
        sphereY: 0.0,
        sphereZ: 0.0,
        radius: 5.0,
        boxMinX: -10.0,
        boxMinY: -10.0,
        boxMinZ: -10.0,
        boxMaxX: 10.0,
        boxMaxY: 10.0,
        boxMaxZ: 10.0,
      );
      expect(overlap, isTrue);
    });

    test('Sphere touching AABB face returns true', () {
      final overlap = ClusterGridBounds.testSphereAABBOverlap(
        sphereX: 15.0,
        sphereY: 0.0,
        sphereZ: 0.0,
        radius: 5.0,
        boxMinX: 0.0,
        boxMinY: -10.0,
        boxMinZ: -10.0,
        boxMaxX: 10.0,
        boxMaxY: 10.0,
        boxMaxZ: 10.0,
      );
      expect(overlap, isTrue);
    });

    test('Sphere beyond radius from AABB returns false', () {
      final overlap = ClusterGridBounds.testSphereAABBOverlap(
        sphereX: 20.0,
        sphereY: 0.0,
        sphereZ: 0.0,
        radius: 5.0,
        boxMinX: 0.0,
        boxMinY: -10.0,
        boxMinZ: -10.0,
        boxMaxX: 10.0,
        boxMaxY: 10.0,
        boxMaxZ: 10.0,
      );
      expect(overlap, isFalse);
    });

    test('Sphere diagonally touching AABB corner returns true', () {
      // Corner at (10, 10, 10), sphere at (12, 12, 12), distSq = 4 + 4 + 4 = 12
      // Radius = sqrt(12) ~ 3.464 -> overlap!
      final overlap = ClusterGridBounds.testSphereAABBOverlap(
        sphereX: 12.0,
        sphereY: 12.0,
        sphereZ: 12.0,
        radius: 3.5,
        boxMinX: 0.0,
        boxMinY: 0.0,
        boxMinZ: 0.0,
        boxMaxX: 10.0,
        boxMaxY: 10.0,
        boxMaxZ: 10.0,
      );
      expect(overlap, isTrue);

      final noOverlap = ClusterGridBounds.testSphereAABBOverlap(
        sphereX: 12.0,
        sphereY: 12.0,
        sphereZ: 12.0,
        radius: 3.0,
        boxMinX: 0.0,
        boxMinY: 0.0,
        boxMinZ: 0.0,
        boxMaxX: 10.0,
        boxMaxY: 10.0,
        boxMaxZ: 10.0,
      );
      expect(noOverlap, isFalse);
    });
  });

  group('ClusteredLight — Attenuation & Radiance Physics', () {
    test('evaluateSmoothAttenuation adheres to windowed inverse square curve', () {
      final light = ClusteredLight(
        id: 1,
        x: 0.0,
        y: 0.0,
        z: 0.0,
        radius: 10.0,
      );

      // Center (d = 0)
      final attCenter = light.evaluateSmoothAttenuation(0.0);
      expect(attCenter, closeTo(1.0, 0.001));

      // Halfway (d = 5)
      final attHalf = light.evaluateSmoothAttenuation(5.0);
      expect(attHalf, greaterThan(0.0));
      expect(attHalf, lessThan(attCenter));

      // Boundary (d = 10)
      final attEdge = light.evaluateSmoothAttenuation(10.0);
      expect(attEdge, equals(0.0));

      // Outside (d = 15)
      final attOutside = light.evaluateSmoothAttenuation(15.0);
      expect(attOutside, equals(0.0));
    });

    test('evaluateRadiance accounts for Lambertian normal orientation', () {
      final light = ClusteredLight(
        id: 1,
        x: 0.0,
        y: 5.0,
        z: 0.0,
        radius: 20.0,
        r: 1.0,
        g: 1.0,
        b: 1.0,
        intensity: 2.0,
      );

      // Surface at origin facing directly up toward light
      final (rFacing, gFacing, bFacing) = light.evaluateRadiance(
        targetX: 0.0,
        targetY: 0.0,
        targetZ: 0.0,
        normalX: 0.0,
        normalY: 1.0,
        normalZ: 0.0,
      );
      expect(rFacing, greaterThan(0.0));
      expect(rFacing, equals(gFacing));
      expect(gFacing, equals(bFacing));

      // Surface at origin facing downward away from light
      final (rBack, gBack, bBack) = light.evaluateRadiance(
        targetX: 0.0,
        targetY: 0.0,
        targetZ: 0.0,
        normalX: 0.0,
        normalY: -1.0,
        normalZ: 0.0,
      );
      expect(rBack, equals(0.0));
      expect(gBack, equals(0.0));
      expect(bBack, equals(0.0));
    });
  });

  group('ClusteredLightManager — Scene Light Binning & Cluster Assignment', () {
    late ClusteredLightManager manager;

    setUp(() {
      manager = ClusteredLightManager(
        bounds: ClusterGridBounds(
          minX: -50.0,
          minY: -10.0,
          minZ: -50.0,
          maxX: 50.0,
          maxY: 30.0,
          maxZ: 50.0,
          dimX: 10,
          dimY: 4,
          dimZ: 10,
        ),
        maxLights: 64,
        maxLightsPerCluster: 16,
      );
    });

    test('Initial grid has 0 lights assigned across all clusters', () {
      expect(manager.lightCount, equals(0));
      expect(manager.activeLightCount, equals(0));
      expect(manager.totalClusterLightAssignments, equals(0));

      for (int i = 0; i < manager.gridBounds.totalClusters; i++) {
        expect(manager.clusterLightCounts[i], equals(0));
      }
    });

    test('Adding a localized scene light assigns it only to intersecting clusters', () {
      final slot = manager.createSceneLight(
        x: 0.0,
        y: 10.0,
        z: 0.0,
        radius: 12.0,
        name: 'TownCenterBrazier',
      );
      expect(slot, equals(0));
      expect(manager.lightCount, equals(1));
      expect(manager.activeLightCount, equals(1));

      // The center cluster should have this light assigned
      final (centerCx, centerCy, centerCz) = manager.gridBounds.worldToVoxel(0.0, 10.0, 0.0);
      final centerClusterIdx = manager.gridBounds.voxelToLinearIndex(centerCx, centerCy, centerCz);

      final centerLights = manager.getLightsForCluster(centerClusterIdx);
      expect(centerLights, contains(slot));

      // A distant corner cluster (-45, -5, -45) must NOT have this light
      final (cornerCx, cornerCy, cornerCz) = manager.gridBounds.worldToVoxel(-45.0, -5.0, -45.0);
      final cornerClusterIdx = manager.gridBounds.voxelToLinearIndex(cornerCx, cornerCy, cornerCz);
      final cornerLights = manager.getLightsForCluster(cornerClusterIdx);
      expect(cornerLights, isEmpty);
    });

    test('Multiple overlapping lights accumulate correctly in shared clusters', () {
      final slot1 = manager.createSceneLight(
        x: 0.0,
        y: 10.0,
        z: 0.0,
        radius: 15.0,
        name: 'Torch_1',
      );
      final slot2 = manager.createSceneLight(
        x: 5.0,
        y: 10.0,
        z: 0.0,
        radius: 15.0,
        name: 'Torch_2',
      );

      final (cx, cy, cz) = manager.gridBounds.worldToVoxel(2.5, 10.0, 0.0);
      final clusterIdx = manager.gridBounds.voxelToLinearIndex(cx, cy, cz);
      final lightsInCluster = manager.getLightsForCluster(clusterIdx);

      expect(lightsInCluster, contains(slot1));
      expect(lightsInCluster, contains(slot2));
      expect(lightsInCluster.length, equals(2));
    });

    test('Removing a light cleans up cluster assignments on rebuild', () {
      final slot = manager.createSceneLight(
        x: 0.0,
        y: 10.0,
        z: 0.0,
        radius: 15.0,
      );
      expect(manager.totalClusterLightAssignments, greaterThan(0));

      final removed = manager.removeLight(slot);
      expect(removed, isTrue);
      expect(manager.lightCount, equals(0));
      expect(manager.totalClusterLightAssignments, equals(0));

      final (cx, cy, cz) = manager.gridBounds.worldToVoxel(0.0, 10.0, 0.0);
      final clusterIdx = manager.gridBounds.voxelToLinearIndex(cx, cy, cz);
      expect(manager.getLightsForCluster(clusterIdx), isEmpty);
    });

    test('Capping at maxLightsPerCluster protects against buffer overflows', () {
      // Create 20 lights all at the exact same location with large radius
      for (int i = 0; i < 20; i++) {
        manager.createSceneLight(
          x: 0.0,
          y: 10.0,
          z: 0.0,
          radius: 20.0,
          name: 'SpamLight_$i',
        );
      }

      final (cx, cy, cz) = manager.gridBounds.worldToVoxel(0.0, 10.0, 0.0);
      final clusterIdx = manager.gridBounds.voxelToLinearIndex(cx, cy, cz);

      // Cluster count must be capped at maxLightsPerCluster (16)
      expect(manager.clusterLightCounts[clusterIdx], equals(16));
      expect(manager.getLightsForCluster(clusterIdx).length, equals(16));
    });
  });

  group('ClusteredLightManager — O(1) Crowd Lighting Evaluation (10,000 Entities)', () {
    late ClusteredLightManager manager;

    setUp(() {
      manager = ClusteredLightManager(
        bounds: ClusterGridBounds(
          minX: -100.0,
          minY: -10.0,
          minZ: -100.0,
          maxX: 100.0,
          maxY: 40.0,
          maxZ: 100.0,
          dimX: 16,
          dimY: 8,
          dimZ: 16,
        ),
        maxLights: 128,
        ambientR: 0.05,
        ambientG: 0.06,
        ambientB: 0.08,
      );

      // Add environmental lanterns and braziers throughout the arena
      manager.createSceneLight(
        x: -40.0,
        y: 8.0,
        z: -40.0,
        radius: 35.0,
        r: 1.0,
        g: 0.6,
        b: 0.2,
        intensity: 2.5,
        name: 'GateTorchNorthWest',
      );
      manager.createSceneLight(
        x: 40.0,
        y: 8.0,
        z: 40.0,
        radius: 35.0,
        r: 0.2,
        g: 0.6,
        b: 1.0,
        intensity: 2.5,
        name: 'GateTorchSouthEast',
      );
      manager.createSceneLight(
        x: 0.0,
        y: 12.0,
        z: 0.0,
        radius: 45.0,
        r: 1.0,
        g: 0.9,
        b: 0.7,
        intensity: 3.0,
        name: 'ArenaGrandChandelier',
      );
    });

    test('sampleLightingAt samples ambient irradiance in dark clusters', () {
      // Very distant point outside any light radius
      final (r, g, b) = manager.sampleLightingAt(
        x: -95.0,
        y: 0.0,
        z: -95.0,
        normalX: 0.0,
        normalY: 1.0,
        normalZ: 0.0,
      );
      expect(r, closeTo(0.05, 0.001));
      expect(g, closeTo(0.06, 0.001));
      expect(b, closeTo(0.08, 0.001));
    });

    test('sampleLightingAt accumulates direct radiance near Grand Chandelier', () {
      final (r, g, b) = manager.sampleLightingAt(
        x: 0.0,
        y: 0.0,
        z: 0.0,
        normalX: 0.0,
        normalY: 1.0,
        normalZ: 0.0,
      );
      expect(r, greaterThan(0.05));
      expect(g, greaterThan(0.06));
      expect(b, greaterThan(0.08));
    });

    test('evaluateCrowdLighting evaluates 10,000 crowd instances in real-time budget', () {
      const int entityCount = 10000;
      final positions = Float32List(entityCount * 3);
      final normals = Float32List(entityCount * 3);
      final outColors = Float32List(entityCount * 3);

      final rng = math.Random(1337);
      for (int i = 0; i < entityCount; i++) {
        final base = i * 3;
        // Distribute within arena [-80 .. 80]
        positions[base + 0] = (rng.nextDouble() * 160.0) - 80.0;
        positions[base + 1] = rng.nextDouble() * 4.0;
        positions[base + 2] = (rng.nextDouble() * 160.0) - 80.0;

        normals[base + 0] = 0.0;
        normals[base + 1] = 1.0;
        normals[base + 2] = 0.0;
      }

      final durationMs = manager.evaluateCrowdLighting(
        crowdPositions: positions,
        crowdNormals: normals,
        outColors: outColors,
        entityCount: entityCount,
      );

      // Verify that all 10,000 entities received valid lighting
      for (int i = 0; i < entityCount; i++) {
        final base = i * 3;
        expect(outColors[base + 0], greaterThanOrEqualTo(0.049));
        expect(outColors[base + 1], greaterThanOrEqualTo(0.059));
        expect(outColors[base + 2], greaterThanOrEqualTo(0.079));
      }

      // Performance check: 10,000 crowd instances evaluated in sub-millisecond or fast budget
      expect(durationMs, lessThan(35.0)); // < 35ms on debug CPU, << 1ms in release/GPU
    });
  });

  group('ClusteredLightManager — GPU Texture & Uniform Buffer Packing', () {
    late ClusteredLightManager manager;

    setUp(() {
      manager = ClusteredLightManager(
        bounds: ClusterGridBounds(
          dimX: 8,
          dimY: 4,
          dimZ: 8,
        ),
        maxLights: 32,
        maxLightsPerCluster: 16,
      );
      manager.createSceneLight(
        x: 0.0,
        y: 5.0,
        z: 0.0,
        radius: 20.0,
        r: 1.0,
        g: 0.5,
        b: 0.25,
      );
    });

    test('packClusterGridTexture builds valid RGBA8888 buffer matching cluster data', () {
      final textureBytes = manager.packClusterGridTexture(textureWidth: 64);
      expect(textureBytes, isNotEmpty);
      expect(textureBytes.length % 4, equals(0));

      // Center cluster has count > 0
      final (cx, cy, cz) = manager.gridBounds.worldToVoxel(0.0, 5.0, 0.0);
      final centerClusterIdx = manager.gridBounds.voxelToLinearIndex(cx, cy, cz);
      final byteOffset = centerClusterIdx * 4;

      final countByte = textureBytes[byteOffset + 2];
      expect(countByte, greaterThan(0));
    });

    test('packLightIndexTexture outputs non-empty byte buffer', () {
      final indexBytes = manager.packLightIndexTexture(textureWidth: 64);
      expect(indexBytes, isNotEmpty);
      expect(indexBytes.length % 4, equals(0));
    });

    test('buildShaderUniforms generates 27 floats matching clustered_crowd_lighting.frag', () {
      final uniforms = manager.buildShaderUniforms(
        viewportWidth: 1920.0,
        viewportHeight: 1080.0,
        clusterMode: 1.0,
        cameraX: 0.0,
        cameraY: 15.0,
        cameraZ: -30.0,
        roughness: 0.4,
      );

      expect(uniforms.length, equals(27));
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));
      expect(uniforms[2], equals(8.0)); // dimX
      expect(uniforms[3], equals(4.0)); // dimY
      expect(uniforms[4], equals(8.0)); // dimZ
      expect(uniforms[14], equals(manager.gridBounds.maxZ)); // uVoxelMax.z
      expect(uniforms[15], equals(1.0)); // clusterMode
      expect(uniforms[16], equals(16.0)); // maxLightsPerCluster
      expect(uniforms[21], equals(0.0)); // cameraX
      expect(uniforms[22], equals(15.0)); // cameraY
      expect(uniforms[23], equals(-30.0)); // cameraZ
      expect(uniforms[24], closeTo(0.4, 0.0001)); // roughness
    });
  });
}
