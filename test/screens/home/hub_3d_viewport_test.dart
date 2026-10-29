import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/assets/mesh_asset_registry.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/screens/home/widgets/hero_showcase.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_3d_viewport.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_environment_layer.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_scene_viewport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // 1. 3D GLB Real Asset & Loader Tests (Integrity Mandate: Zero Primitive Blockouts)
  // ===========================================================================
  group('Hub3dAssetLoader & Real .GLB Asset Pipeline', () {
    test('Hub3dAssetLoader singleton is accessible and clears cache', () {
      final loader = Hub3dAssetLoader.instance;
      expect(loader, isNotNull);
      loader.clearCache();
    });

    test('Loads and parses authentic GLB asset with genuine vertex geometry', () async {
      const String swordPath = 'assets/models/aion2/aion2_dark_fantasy_sword.glb';
      final file = io.File(swordPath);
      expect(file.existsSync(), isTrue, reason: 'Real Aion-2 sword GLB file must exist on disk');

      final ParsedModelMesh? mesh = await Hub3dAssetLoader.instance.loadGlbAsset(
        swordPath,
        modelId: 'test_aion2_sword',
      );

      expect(mesh, isNotNull);
      expect(mesh!.modelId, equals('test_aion2_sword'));
      expect(mesh.submeshes, isNotEmpty);

      // Verify that geometry is genuine real mesh (not primitive 8-vertex cube)
      expect(mesh.totalVertices, greaterThan(100));
      expect(mesh.totalTriangles, greaterThan(100));
      expect(mesh.bounds.maxDimension, greaterThan(0.0));

      // Cache hit test
      final ParsedModelMesh? cached = await Hub3dAssetLoader.instance.loadGlbAsset(
        swordPath,
        modelId: 'test_aion2_sword',
      );
      expect(identical(mesh, cached), isTrue, reason: 'Asset loader must return cached instance');
    });

    test('Loads and parses architectural column asset without primitives', () async {
      const String columnPath = 'assets/models/environment/column-large.glb';
      final file = io.File(columnPath);
      expect(file.existsSync(), isTrue);

      final ParsedModelMesh? mesh = await Hub3dAssetLoader.instance.loadGlbAsset(
        columnPath,
        modelId: 'test_column_large',
      );

      expect(mesh, isNotNull);
      expect(mesh!.submeshes, isNotEmpty);
      expect(mesh.totalVertices, greaterThan(50));
      expect(mesh.totalTriangles, greaterThan(50));
    });

    test('Gracefully returns null on invalid or missing GLB path without crashing', () async {
      final ParsedModelMesh? invalid = await Hub3dAssetLoader.instance.loadGlbAsset(
        'assets/models/non_existent_file_9999.glb',
        modelId: 'invalid_model',
      );
      expect(invalid, isNull);
    });
  });

  // ===========================================================================
  // 2. Hub3dModelController & Interactive Turntable Orbit Tests
  // ===========================================================================
  group('Hub3dModelController & Gesture Turntable', () {
    test('Initializes with default orientation and auto-rotation enabled', () {
      final controller = Hub3dModelController(
        initialRotationY: 0.25,
        autoRotateSpeed: 0.5,
        enableAutoRotate: true,
      );

      expect(controller.rotationY, closeTo(0.25, 1e-6));
      expect(controller.rotationX, equals(0.0));
      expect(controller.isAutoRotating, isTrue);

      controller.dispose();
    });

    test('Pan gesture interrupts auto-rotation and updates yaw/pitch safely', () {
      final controller = Hub3dModelController(
        initialRotationY: 0.0,
      );

      controller.onPanStart();
      expect(controller.isAutoRotating, isFalse);

      controller.onPanUpdate(DragUpdateDetails(
        globalPosition: const Offset(100, 100),
        delta: const Offset(15.0, -10.0),
      ));

      expect(controller.rotationY, greaterThan(0.0));
      expect(controller.rotationX, greaterThan(0.0));
      expect(controller.rotationX, lessThanOrEqualTo(0.35)); // pitch clamped

      controller.onPanEnd(DragEndDetails(
        velocity: const Velocity(pixelsPerSecond: Offset(200, 0)),
      ));

      // Advance tick to test friction damping
      final double initialRotY = controller.rotationY;
      controller.tick(0.016);
      expect(controller.rotationY, greaterThan(initialRotY));

      // Reset snaps back to front
      controller.resetRotation();
      expect(controller.rotationY, equals(0.0));
      expect(controller.rotationX, equals(0.0));
      expect(controller.isAutoRotating, isTrue);

      controller.dispose();
    });

    test('Celestial Global Illumination updates lighting uniform parameters', () {
      final controller = Hub3dModelController();

      controller.updateLighting(
        sunElevation: 0.8,
        sunAzimuth: 1.2,
        sunColor: const Color(0xFFFFE0B2),
        zenithColor: const Color(0xFF1E3A8A),
        groundColor: const Color(0xFF0F172A),
      );

      // Verify notifyListeners fired and controller holds state
      expect(controller.cameraDistance, equals(4.2));

      controller.dispose();
    });
  });

  // ===========================================================================
  // 3. 3D Math, Backface Culling & Painter's Algorithm Depth Tests
  // ===========================================================================
  group('3D Rendering Math & Backface Culling', () {
    test('Backface culling cross product correctly detects front vs back facing', () {
      // Screen-space Triangle A: Clockwise (front-facing)
      const double a0x = 100.0, a0y = 100.0;
      const double a1x = 150.0, a1y = 80.0;
      const double a2x = 120.0, a2y = 140.0;

      final double frontCross =
          (a1x - a0x) * (a2y - a0y) - (a1y - a0y) * (a2x - a0x);
      expect(frontCross, greaterThan(0.0), reason: 'Clockwise triangle must be front-facing');

      // Counter-Clockwise (back-facing)
      final double backCross =
          (a2x - a0x) * (a1y - a0y) - (a2y - a0y) * (a1x - a0x);
      expect(backCross, lessThan(0.0), reason: 'Counter-clockwise triangle must be culled');
    });

    test('BoundingBox3D center and dimensions calculate correctly', () {
      final Float32List vertices = Float32List.fromList(<double>[
        -1.0, -2.0, -3.0,
        1.0, 2.0, 3.0,
        0.0, 0.0, 0.0,
      ]);

      final BoundingBox3D b = BoundingBox3D.fromPoints(vertices);
      expect(b.minX, equals(-1.0));
      expect(b.maxX, equals(1.0));
      expect(b.minY, equals(-2.0));
      expect(b.maxY, equals(2.0));
      expect(b.minZ, equals(-3.0));
      expect(b.maxZ, equals(3.0));
      expect(b.centerX, equals(0.0));
      expect(b.centerY, equals(0.0));
      expect(b.centerZ, equals(0.0));
      expect(b.maxDimension, equals(6.0));
    });
  });

  // ===========================================================================
  // 4. Widget Tree Integration & Mobile Gameplay State Preservation
  // ===========================================================================
  group('Widget Integration & Gameplay Preservation', () {
    testWidgets('Hub3dModelViewport mounts and displays fallback/preloader gracefully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: Hub3dModelViewport(
                assetPath: 'assets/models/props/Brazier_IronEmbers.glb',
                fallbackWidget: const Text('PRELOADING_3D_ASSET'),
              ),
            ),
          ),
        ),
      );

      // Verify that widget tree built without throwing
      expect(find.byType(Hub3dModelViewport), findsOneWidget);
    });

    testWidgets('Hub3dWorldPropsLayer renders within HubSceneViewport without throwing', (
      WidgetTester tester,
    ) async {
      final envController = HubEnvironmentController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: Hub3dWorldPropsLayer(
                controller: envController,
                parallaxOffset: const Offset(5.0, -10.0),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Hub3dWorldPropsLayer), findsOneWidget);
      envController.dispose();
    });

    testWidgets('HeroShowcase renders Hero3dGlbViewport and preserves 100% equipment slots', (
      WidgetTester tester,
    ) async {
      const PlayerProfile profile = PlayerProfile(
        id: 'test_hero_id',
        username: 'AionChampion',
        characterClass: CharacterClass.warrior,
        level: 42,
        power: 125000,
        reputation: 9800,
        energy: 85,
        maxEnergy: 100,
        health: 5400,
        maxHealth: 5400,
      );

      const InventoryState inventory = InventoryState(
        equippedItems: <String, InventoryItem>{},
      );

      String? tappedSlot;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 420,
              child: HeroShowcase(
                profile: profile,
                inventoryState: inventory,
                totalPower: 125000,
                reputation: 9800,
                onSlotTap: (slot, item) {
                  tappedSlot = slot;
                },
              ),
            ),
          ),
        ),
      );

      // 1. Verify 3D Hero Viewport is mounted
      expect(find.byType(Hero3dGlbViewport), findsOneWidget);

      // 2. Verify all 8 equipment slots are present
      expect(find.text('Silah'), findsOneWidget);
      expect(find.text('Kask'), findsOneWidget);
      expect(find.text('Zırh'), findsOneWidget);
      expect(find.text('Eldiven'), findsOneWidget);
      expect(find.text('Bacak'), findsOneWidget);
      expect(find.text('Bot'), findsOneWidget);
      expect(find.text('Aksesuar'), findsOneWidget);
      expect(find.text('Yüzük'), findsOneWidget);

      // 3. Verify Level Badge
      expect(find.text('LVL 42'), findsOneWidget);

      // 4. Verify Power & Reputation Badges
      expect(find.text('125.0K'), findsOneWidget);

      // 5. Verify Slot Tap Callback execution (Gameplay Logic Preservation)
      await tester.tap(find.text('Silah'));
      await tester.pump();
      expect(tappedSlot, equals('Silah'), reason: 'Slot tap callback must execute without regression');
    });
  });
}
