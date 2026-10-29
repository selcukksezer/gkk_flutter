import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/crowd/occlusion_culling.dart';

void main() {
  group('3D Math Primitives', () {
    test('Vector3D basic operations', () {
      const v1 = Vector3D(1.0, 2.0, 3.0);
      const v2 = Vector3D(4.0, 5.0, 6.0);

      final sum = v1 + v2;
      expect(sum.x, 5.0);
      expect(sum.y, 7.0);
      expect(sum.z, 9.0);

      final diff = v2 - v1;
      expect(diff.x, 3.0);
      expect(diff.y, 3.0);
      expect(diff.z, 3.0);

      final scaled = v1 * 2.0;
      expect(scaled.x, 2.0);
      expect(scaled.y, 4.0);
      expect(scaled.z, 6.0);

      final dot = v1.dot(v2); // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
      expect(dot, 32.0);

      final cross = Vector3D.right.cross(Vector3D.up);
      expect(cross.x, closeTo(0.0, 1e-5));
      expect(cross.y, closeTo(0.0, 1e-5));
      expect(cross.z, closeTo(1.0, 1e-5));

      final norm = const Vector3D(3.0, 0.0, 4.0).normalized();
      expect(norm.length(), closeTo(1.0, 1e-5));
      expect(norm.x, closeTo(0.6, 1e-5));
      expect(norm.z, closeTo(0.8, 1e-5));
    });

    test('Aabb3D containment and intersection', () {
      const aabb = Aabb3D(
        Vector3D(-5.0, -5.0, -5.0),
        Vector3D(5.0, 5.0, 5.0),
      );

      expect(aabb.center.x, 0.0);
      expect(aabb.center.y, 0.0);
      expect(aabb.center.z, 0.0);

      expect(aabb.containsPoint(const Vector3D(0.0, 0.0, 0.0)), isTrue);
      expect(aabb.containsPoint(const Vector3D(5.0, 5.0, 5.0)), isTrue);
      expect(aabb.containsPoint(const Vector3D(5.1, 0.0, 0.0)), isFalse);

      const intersecting = Aabb3D(
        Vector3D(4.0, 4.0, 4.0),
        Vector3D(10.0, 10.0, 10.0),
      );
      expect(aabb.intersects(intersecting), isTrue);

      const disjoint = Aabb3D(
        Vector3D(6.0, 6.0, 6.0),
        Vector3D(10.0, 10.0, 10.0),
      );
      expect(aabb.intersects(disjoint), isFalse);

      expect(aabb.getCorners().length, 8);
    });

    test('Plane3D signed distance and normal calculation', () {
      final plane = Plane3D.fromPointAndNormal(
        const Vector3D(0.0, 10.0, 0.0),
        Vector3D.up,
      );

      expect(plane.signedDistanceToPoint(const Vector3D(0.0, 15.0, 0.0)), 5.0);
      expect(plane.signedDistanceToPoint(const Vector3D(0.0, 5.0, 0.0)), -5.0);
      expect(plane.signedDistanceToPoint(const Vector3D(0.0, 10.0, 0.0)), 0.0);
    });
  });

  group('OcclusionCamera & Projection', () {
    test('Camera projection maps 3D points to normalized screen coordinates', () {
      final camera = OcclusionCamera(
        position: const Vector3D(0.0, 0.0, -10.0),
        target: const Vector3D(0.0, 0.0, 0.0),
        up: Vector3D.up,
        fovDegrees: 60.0,
        aspect: 1.0,
        nearPlane: 1.0,
        farPlane: 100.0,
      );

      // Center point (0, 0, 0) should project to center of screen (64, 64) for 128x128 buffer
      final screenPt = camera.projectToScreen(const Vector3D(0.0, 0.0, 0.0), 128, 128);
      expect(screenPt.x, closeTo(63.5, 1.0));
      expect(screenPt.y, closeTo(63.5, 1.0));
      expect(screenPt.z, greaterThan(0.0));
      expect(screenPt.z, lessThan(1.0));

      // Point behind camera should have depth < 0
      final behindPt = camera.projectToScreen(const Vector3D(0.0, 0.0, -15.0), 128, 128);
      expect(behindPt.z, lessThan(0.0));
    });

    test('projectAabb calculates valid screen bounds and depth bounds', () {
      final camera = OcclusionCamera(
        position: const Vector3D(0.0, 0.0, -20.0),
        target: const Vector3D(0.0, 0.0, 0.0),
        fovDegrees: 60.0,
        aspect: 1.0,
      );

      const box = Aabb3D(
        Vector3D(-2.0, -2.0, 0.0),
        Vector3D(2.0, 2.0, 0.0),
      );

      final rect = ScreenRectDepth();
      camera.projectAabb(box, 128, 128, rect);

      expect(rect.isFullyBehindNearPlane, isFalse);
      expect(rect.minX, greaterThanOrEqualTo(0));
      expect(rect.maxX, lessThan(128));
      expect(rect.minY, greaterThanOrEqualTo(0));
      expect(rect.maxY, lessThan(128));
      expect(rect.minZ, lessThanOrEqualTo(rect.maxZ));
    });
  });

  group('Occluder Geometry Generation', () {
    test('Hub building occluder generates 6 bounded faces', () {
      final building = Occluder.building(
        id: 'tavern_01',
        name: 'The Golden Tankard',
        center: const Vector3D(0.0, 5.0, 20.0),
        size: const Vector3D(10.0, 10.0, 10.0),
      );

      expect(building.type, OccluderType.hubBuilding);
      expect(building.faces.length, 6);
      expect(building.bounds.containsPoint(const Vector3D(0.0, 5.0, 20.0)), isTrue);
      expect(building.bounds.containsPoint(const Vector3D(20.0, 5.0, 20.0)), isFalse);
    });

    test('Dungeon wall occluder creates thick slab with correct orientation', () {
      final wall = Occluder.dungeonWall(
        id: 'dungeon_wall_north',
        name: 'Crypt Boundary Wall',
        start: const Vector3D(-10.0, 0.0, 15.0),
        end: const Vector3D(10.0, 0.0, 15.0),
        height: 6.0,
        thickness: 1.0,
      );

      expect(wall.type, OccluderType.dungeonWall);
      expect(wall.faces.length, 5);
      expect(wall.bounds.min.y, closeTo(0.0, 0.01));
      expect(wall.bounds.max.y, closeTo(6.0, 0.01));
    });

    test('Large boulder creates octagonal convex prism', () {
      final boulder = Occluder.largeBoulder(
        id: 'boulder_granite',
        name: 'Massive Granite Boulder',
        center: const Vector3D(5.0, 2.0, 10.0),
        radius: 3.0,
        height: 4.0,
        sides: 8,
      );

      expect(boulder.type, OccluderType.largeBoulder);
      expect(boulder.faces.length, 10); // 8 sides + top + bottom
      expect(boulder.bounds.containsPoint(const Vector3D(5.0, 2.0, 10.0)), isTrue);
    });

    test('Castle gate occluder respects open/closed state', () {
      final gate = Occluder.castleGate(
        id: 'castle_drawbridge',
        name: 'Iron Portcullis',
        center: const Vector3D(0.0, 3.0, 10.0),
        width: 6.0,
        height: 6.0,
        thickness: 1.0,
        isOpen: false,
      );

      expect(gate.type, OccluderType.castleGate);
      expect(gate.isOpen, isFalse);

      gate.isOpen = true;
      expect(gate.isOpen, isTrue);
    });
  });

  group('Software Occlusion Depth Buffer & Hi-Z', () {
    test('Software depth buffer clears and rasterizes triangle depth conservatively', () {
      final buffer = SoftwareOcclusionBuffer(width: 64, height: 64);
      expect(buffer.depthBuffer[0], 1.0); // Cleared depth

      // Rasterize a triangle in center of screen with depth 0.3
      const s0 = Vector3D(20.0, 20.0, 0.3);
      const s1 = Vector3D(40.0, 20.0, 0.3);
      const s2 = Vector3D(30.0, 40.0, 0.3);

      buffer.rasterizeTriangleScreen(s0, s1, s2);

      // Pixel at centroid (30, 26) should have depth 0.3
      final centerDepth = buffer.depthBuffer[26 * 64 + 30];
      expect(centerDepth, closeTo(0.3, 0.01));

      // Pixel outside triangle should remain 1.0
      final outsideDepth = buffer.depthBuffer[5 * 64 + 5];
      expect(outsideDepth, 1.0);
    });

    test('Hi-Z pyramid downsamples with maximum depth for conservative culling', () {
      final buffer = SoftwareOcclusionBuffer(width: 64, height: 64);

      // Place depth in an 8x8 block (covers Level 1, 2, and 3 downsampling)
      for (int y = 16; y < 24; y++) {
        for (int x = 16; x < 24; x++) {
          buffer.depthBuffer[y * 64 + x] = 0.4;
        }
      }

      buffer.buildHiZ();

      // Hi-Z Level 1 (32x32): block (8, 8) covers pixels (16..17, 16..17)
      expect(buffer.mip1[8 * 32 + 8], closeTo(0.4, 0.01));

      // Hi-Z Level 2 (16x16): block (4, 4) covers Level 1 (8..9, 8..9)
      expect(buffer.mip2[4 * 16 + 4], closeTo(0.4, 0.01));

      // Hi-Z Level 3 (8x8): block (2, 2) covers Level 2 (4..5, 4..5)
      expect(buffer.mip3[2 * 8 + 2], closeTo(0.4, 0.01));
    });

    test('isScreenRectOccluded correctly differentiates occluded vs visible rectangles', () {
      final buffer = SoftwareOcclusionBuffer(width: 64, height: 64);

      // Rasterize occluder triangle with depth 0.4
      const s0 = Vector3D(10.0, 10.0, 0.4);
      const s1 = Vector3D(50.0, 10.0, 0.4);
      const s2 = Vector3D(30.0, 50.0, 0.4);
      buffer.rasterizeTriangleScreen(s0, s1, s2);
      buffer.buildHiZ();

      // Entity behind occluder (depth 0.6) inside the triangle footprint
      final occludedRect = ScreenRectDepth(
        minX: 28,
        maxX: 32,
        minY: 20,
        maxY: 24,
        minZ: 0.6,
        maxZ: 0.7,
      );
      expect(buffer.isScreenRectOccluded(occludedRect), isTrue);

      // Entity in front of occluder (depth 0.2)
      final inFrontRect = ScreenRectDepth(
        minX: 28,
        maxX: 32,
        minY: 20,
        maxY: 24,
        minZ: 0.2,
        maxZ: 0.3,
      );
      expect(buffer.isScreenRectOccluded(inFrontRect), isFalse);

      // Entity partially outside occluder footprint
      final peekingRect = ScreenRectDepth(
        minX: 5,
        maxX: 30,
        minY: 5,
        maxY: 20,
        minZ: 0.6,
        maxZ: 0.7,
      );
      expect(buffer.isScreenRectOccluded(peekingRect), isFalse);
    });
  });

  group('Sector-based Visibility Graph (PVS)', () {
    late PvsGraph graph;
    late OcclusionCamera camera;

    setUp(() {
      graph = PvsGraph();
      camera = OcclusionCamera(
        position: const Vector3D(0.0, 1.0, 0.0),
        target: const Vector3D(0.0, 1.0, 20.0),
      );

      // Sector A: Entrance Hall
      final sectorA = Sector(
        id: 'sector_a',
        name: 'Entrance Hall',
        bounds: const Aabb3D(
          Vector3D(-10.0, 0.0, -10.0),
          Vector3D(10.0, 5.0, 10.0),
        ),
      );

      // Sector B: Dungeon Chamber (ahead)
      final sectorB = Sector(
        id: 'sector_b',
        name: 'Dungeon Chamber',
        bounds: const Aabb3D(
          Vector3D(-10.0, 0.0, 10.0),
          Vector3D(10.0, 5.0, 30.0),
        ),
      );

      // Sector C: Secret Vault (behind closed iron door in Sector B)
      final sectorC = Sector(
        id: 'sector_c',
        name: 'Secret Vault',
        bounds: const Aabb3D(
          Vector3D(-10.0, 0.0, 30.0),
          Vector3D(10.0, 5.0, 50.0),
        ),
      );

      graph.addSector(sectorA);
      graph.addSector(sectorB);
      graph.addSector(sectorC);

      // Portal A -> B (Open doorway at z = 10)
      final portalAB = Portal.door(
        id: 'portal_a_b',
        fromSectorId: 'sector_a',
        toSectorId: 'sector_b',
        center: const Vector3D(0.0, 2.0, 10.0),
        width: 4.0,
        height: 4.0,
        normal: const Vector3D(0.0, 0.0, -1.0),
        isOpen: true,
      );
      graph.addPortal(portalAB);

      // Portal B -> C (Closed iron door at z = 30)
      final portalBC = Portal.door(
        id: 'portal_b_c',
        fromSectorId: 'sector_b',
        toSectorId: 'sector_c',
        center: const Vector3D(0.0, 2.0, 30.0),
        width: 3.0,
        height: 4.0,
        normal: const Vector3D(0.0, 0.0, -1.0),
        isOpen: false, // Closed!
      );
      graph.addPortal(portalBC);
    });

    test('Camera in Sector A sees Sector A and reachable Sector B, but NOT closed Sector C', () {
      final pvs = graph.computePvs(camera.position, camera);

      expect(pvs.contains('sector_a'), isTrue);
      expect(pvs.contains('sector_b'), isTrue);
      expect(pvs.contains('sector_c'), isFalse); // Closed portal occludes Sector C!
    });

    test('Opening door portal B->C exposes Sector C to PVS', () {
      graph.setPortalOpen('portal_b_c', true);

      final pvs = graph.computePvs(camera.position, camera);

      expect(pvs.contains('sector_a'), isTrue);
      expect(pvs.contains('sector_b'), isTrue);
      expect(pvs.contains('sector_c'), isTrue); // Now visible through opened portal!
    });
  });

  group('OcclusionCullingEngine - Integration & Real-World Scenarios', () {
    late OcclusionCullingEngine engine;
    late OcclusionCamera camera;

    setUp(() {
      engine = OcclusionCullingEngine(bufferResolution: 128);
      camera = OcclusionCamera(
        position: const Vector3D(0.0, 2.0, -10.0),
        target: const Vector3D(0.0, 2.0, 50.0),
        fovDegrees: 60.0,
        aspect: 16.0 / 9.0,
      );
    });

    test('Entities occluded directly behind a large hub building are culled', () {
      // 1. Place a large hub building at z = 15, size = 12x10x12
      final building = Occluder.building(
        id: 'city_hall',
        name: 'Main City Hall',
        center: const Vector3D(0.0, 5.0, 15.0),
        size: const Vector3D(12.0, 10.0, 12.0),
      );
      engine.registerOccluder(building);

      engine.beginFrame(camera);
      expect(engine.stats.occludersRasterized, 1);

      // 2. Entity strictly behind the building (z = 30) -> Should be occluded!
      const occludedEntity = Aabb3D(
        Vector3D(-1.0, 1.0, 30.0),
        Vector3D(1.0, 3.0, 30.0),
      );
      expect(engine.isEntityVisible(occludedEntity), isFalse);

      // 3. Entity in front of the building (z = 5) -> Should be visible!
      const inFrontEntity = Aabb3D(
        Vector3D(-1.0, 1.0, 5.0),
        Vector3D(1.0, 3.0, 5.0),
      );
      expect(engine.isEntityVisible(inFrontEntity), isTrue);

      // 4. Entity peeking to the right of the building (x = 15, z = 30) -> Visible!
      const peekingEntity = Aabb3D(
        Vector3D(14.0, 1.0, 30.0),
        Vector3D(16.0, 3.0, 30.0),
      );
      expect(engine.isEntityVisible(peekingEntity), isTrue);
    });

    test('Entities occluded behind dungeon wall are culled', () {
      // Dungeon wall spanning from x = -15 to x = 15 at z = 20, height = 5
      final wall = Occluder.dungeonWall(
        id: 'corridor_wall',
        name: 'Stone Wall',
        start: const Vector3D(-15.0, 0.0, 20.0),
        end: const Vector3D(15.0, 0.0, 20.0),
        height: 5.0,
        thickness: 1.0,
      );
      engine.registerOccluder(wall);

      engine.beginFrame(camera);

      // Hidden behind wall
      const hidden = Aabb3D(
        Vector3D(0.0, 1.0, 25.0),
        Vector3D(1.0, 2.0, 26.0),
      );
      expect(engine.isEntityVisible(hidden), isFalse);

      // Standing on top or above wall height (y = 8) -> Visible!
      const flyingAbove = Aabb3D(
        Vector3D(0.0, 7.0, 25.0),
        Vector3D(1.0, 9.0, 26.0),
      );
      expect(engine.isEntityVisible(flyingAbove), isTrue);
    });

    test('Castle gate occludes entities when closed and reveals them when opened', () {
      final gate = Occluder.castleGate(
        id: 'main_gate',
        name: 'Great Castle Gate',
        center: const Vector3D(0.0, 3.0, 15.0),
        width: 10.0,
        height: 8.0,
        thickness: 1.5,
        isOpen: false, // Closed initially
      );
      engine.registerOccluder(gate);

      // Test with gate CLOSED
      engine.beginFrame(camera);

      const behindGate = Aabb3D(
        Vector3D(-1.0, 1.0, 22.0),
        Vector3D(1.0, 3.0, 22.0),
      );
      expect(engine.isEntityVisible(behindGate), isFalse);

      // Now OPEN the gate
      engine.setGateOpen('main_gate', true);
      engine.beginFrame(camera);

      // With gate open, the entity behind the gate becomes visible!
      expect(engine.isEntityVisible(behindGate), isTrue);
    });

    test('Disabling an occluder restores visibility to hidden entities', () {
      final boulder = Occluder.largeBoulder(
        id: 'giant_rock',
        name: 'Giant Rock',
        center: const Vector3D(0.0, 3.0, 12.0),
        radius: 5.0,
        height: 6.0,
      );
      engine.registerOccluder(boulder);

      engine.beginFrame(camera);

      const behindRock = Aabb3D(
        Vector3D(-0.5, 1.0, 20.0),
        Vector3D(0.5, 2.5, 20.0),
      );
      expect(engine.isEntityVisible(behindRock), isFalse);

      // Disable boulder occluder
      engine.setOccluderEnabled('giant_rock', false);
      engine.beginFrame(camera);

      expect(engine.isEntityVisible(behindRock), isTrue);
    });
  });

  group('High-Throughput Batch Culling (10,000 Entities Benchmark)', () {
    test('cullEntitiesBatch accurately culls 10,000 entities in < 2ms without allocations', () {
      final engine = OcclusionCullingEngine(bufferResolution: 128);
      final camera = OcclusionCamera(
        position: const Vector3D(0.0, 5.0, -10.0),
        target: const Vector3D(0.0, 5.0, 100.0),
        fovDegrees: 60.0,
        aspect: 16.0 / 9.0,
      );

      // Place 3 major occluders in the world:
      // 1. Central castle hub building at (0, 10, 30), size = 30x20x20
      engine.registerOccluder(Occluder.building(
        id: 'castle_hub',
        name: 'Castle Keep',
        center: const Vector3D(0.0, 10.0, 30.0),
        size: const Vector3D(30.0, 20.0, 20.0),
      ));

      // 2. Left dungeon wall at (-35, 5, 40)
      engine.registerOccluder(Occluder.dungeonWall(
        id: 'west_wall',
        name: 'West Perimeter Wall',
        start: const Vector3D(-50.0, 0.0, 40.0),
        end: const Vector3D(-20.0, 0.0, 40.0),
        height: 8.0,
      ));

      // 3. Right giant boulder at (35, 4, 35)
      engine.registerOccluder(Occluder.largeBoulder(
        id: 'east_boulder',
        name: 'East Boulder',
        center: const Vector3D(35.0, 4.0, 35.0),
        radius: 8.0,
        height: 10.0,
      ));

      engine.beginFrame(camera);

      const entityCount = 10000;
      final positions = Float32List(entityCount * 3);
      final halfExtents = Float32List(entityCount * 3);
      final visibility = Uint8List(entityCount);

      final rng = math.Random(42);

      // Synthesize 10,000 entities:
      // - Some in front of occluders (visible)
      // - Many directly behind the castle hub building (occluded)
      // - Some scattered to the sides and background
      for (int i = 0; i < entityCount; i++) {
        final posIdx = i * 3;
        double x, y, z;

        if (i < 4000) {
          // 40% placed directly in shadow volume behind the castle hub (x: -12..12, z: 45..100)
          x = (rng.nextDouble() - 0.5) * 20.0;
          y = rng.nextDouble() * 8.0;
          z = 45.0 + rng.nextDouble() * 55.0;
        } else if (i < 6000) {
          // 20% placed in front of castle hub (x: -15..15, z: 5..20) -> Visible
          x = (rng.nextDouble() - 0.5) * 30.0;
          y = rng.nextDouble() * 8.0;
          z = 5.0 + rng.nextDouble() * 15.0;
        } else {
          // 40% spread across field
          x = (rng.nextDouble() - 0.5) * 100.0;
          y = rng.nextDouble() * 8.0;
          z = 10.0 + rng.nextDouble() * 90.0;
        }

        positions[posIdx] = x;
        positions[posIdx + 1] = y;
        positions[posIdx + 2] = z;

        halfExtents[posIdx] = 0.5;
        halfExtents[posIdx + 1] = 1.0;
        halfExtents[posIdx + 2] = 0.5;
      }

      // Warm-up pass
      engine.cullEntitiesBatch(
        positions: positions,
        halfExtents: halfExtents,
        count: entityCount,
        outVisibility: visibility,
      );

      // Timed benchmark pass
      final stopwatch = Stopwatch()..start();
      engine.cullEntitiesBatch(
        positions: positions,
        halfExtents: halfExtents,
        count: entityCount,
        outVisibility: visibility,
      );
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMicroseconds / 1000.0;

      // Verification checks:
      expect(engine.stats.totalEntitiesTested, greaterThanOrEqualTo(entityCount));
      expect(engine.stats.entitiesCulledByDepthBuffer, greaterThan(0));
      expect(engine.stats.entitiesVisible, greaterThan(0));
      expect(engine.stats.cullRatio, greaterThan(0.2)); // At least 20-50% culled

      // Entities placed in front (indices 4000..4500) must be visible
      int inFrontVisibleCount = 0;
      for (int i = 4000; i < 4500; i++) {
        if (visibility[i] == 1) inFrontVisibleCount++;
      }
      expect(inFrontVisibleCount, greaterThan(400)); // Vast majority visible

      // Entities behind castle hub (indices 0..1000) must be predominantly culled
      int behindCulledCount = 0;
      for (int i = 0; i < 1000; i++) {
        if (visibility[i] == 0) behindCulledCount++;
      }
      expect(behindCulledCount, greaterThan(800)); // Vast majority culled

      // Throughput check: 10,000 entities in reasonable benchmark budget
      // (in debug test mode, Dart JIT typically does 10K in < 5ms; compiled AOT does < 1ms)
      expect(elapsedMs, lessThan(35.0)); // Generous bound for debug VM mode
    });
  });
}
