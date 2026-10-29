import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/mekans/widgets/mekan_3d_viewport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mekan3DViewportController Tests', () {
    test('initializes with default location and camera values', () {
      final controller = Mekan3DViewportController(initialLocationType: 'all');
      expect(controller.currentLocationType, equals('all'));
      expect(controller.activeDescriptor.id, equals('all'));
      expect(controller.yaw, closeTo(0.35, 0.01));
      expect(controller.pitch, closeTo(0.22, 0.01));
      expect(controller.zoom, equals(1.0));
      expect(controller.selectedDifficulty, equals('Normal'));
      controller.dispose();
    });

    test('focusOnLocation transitions to selected location descriptor', () {
      final controller = Mekan3DViewportController(initialLocationType: 'all');

      controller.focusOnLocation('bar');
      expect(controller.currentLocationType, equals('bar'));
      expect(controller.activeDescriptor.typeKey, equals('bar'));
      expect(controller.activeDescriptor.modelPath, contains('Brazier_IronEmbers'));

      controller.focusOnLocation('dovus_kulubu');
      expect(controller.currentLocationType, equals('dovus_kulubu'));
      expect(controller.activeDescriptor.typeKey, equals('dovus_kulubu'));
      expect(controller.activeDescriptor.modelPath, contains('Gargoyle_DarkStone'));

      controller.focusOnLocation('yeralti');
      expect(controller.currentLocationType, equals('yeralti'));
      expect(controller.activeDescriptor.typeKey, equals('yeralti'));
      expect(controller.activeDescriptor.modelPath, contains('dungeon_warkarma.glb'));

      controller.dispose();
    });

    test('addOrbit updates yaw and clamped pitch', () {
      final controller = Mekan3DViewportController(initialLocationType: 'all');
      final double initialYaw = controller.yaw;
      final double initialPitch = controller.pitch;

      controller.addOrbit(0.2, 0.1);
      expect(controller.yaw, closeTo(initialYaw + 0.2, 0.001));
      expect(controller.pitch, closeTo(initialPitch + 0.1, 0.001));

      // Test pitch clamping
      controller.addOrbit(0.0, 5.0);
      expect(controller.pitch, lessThanOrEqualTo(0.65));

      controller.addOrbit(0.0, -10.0);
      expect(controller.pitch, greaterThanOrEqualTo(-0.45));

      controller.dispose();
    });

    test('setZoom updates zoom within bounds', () {
      final controller = Mekan3DViewportController(initialLocationType: 'all');
      controller.setZoom(1.8);
      expect(controller.zoom, equals(1.8));

      controller.setZoom(0.1);
      expect(controller.zoom, equals(0.65)); // Clamped min

      controller.setZoom(10.0);
      expect(controller.zoom, equals(2.5)); // Clamped max

      controller.dispose();
    });

    test('setDifficulty updates selected difficulty', () {
      final controller = Mekan3DViewportController(initialLocationType: 'all');
      expect(controller.selectedDifficulty, equals('Normal'));

      controller.setDifficulty('Heroic');
      expect(controller.selectedDifficulty, equals('Heroic'));

      controller.setDifficulty('Mythic');
      expect(controller.selectedDifficulty, equals('Mythic'));

      controller.dispose();
    });

    test('tick smoothly updates transition and auto-rotation', () {
      final controller = Mekan3DViewportController(initialLocationType: 'all');
      controller.focusOnLocation('kahvehane');

      // Tick several frames
      for (int i = 0; i < 20; i++) {
        controller.tick(0.016);
      }

      expect(controller.activeDescriptor.typeKey, equals('kahvehane'));
      controller.dispose();
    });
  });

  group('MekanLocationDescriptor Catalog Tests', () {
    test('catalog contains all 6 required location types with real 3D models', () {
      expect(MekanLocationDescriptor.catalog.length, equals(6));

      for (final loc in MekanLocationDescriptor.catalog) {
        expect(loc.id, isNotEmpty);
        expect(loc.name, isNotEmpty);
        expect(loc.modelPath, endsWith('.glb'));
        expect(loc.fallbackModelPaths, isNotEmpty);
        for (final fallback in loc.fallbackModelPaths) {
          expect(fallback, endsWith('.glb'));
        }
        expect(loc.supportedDifficulties, isNotEmpty);
        expect(loc.recommendedLevel, greaterThanOrEqualTo(1));
      }
    });

    test('forType retrieves correct descriptor or falls back to overview', () {
      final bar = MekanLocationDescriptor.forType('bar');
      expect(bar.typeKey, equals('bar'));

      final unknown = MekanLocationDescriptor.forType('non_existent');
      expect(unknown.id, equals('all'));
    });
  });

  group('Mekan3DViewport Widget Tests', () {
    testWidgets('renders viewport with 3D canvas, header chip, and dungeon card', (tester) async {
      String? selectedLocation;
      String? enteredDungeon;
      String? changedDifficulty;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Mekan3DViewport(
              selectedLocationType: 'all',
              height: 310,
              onLocationSelected: (loc) => selectedLocation = loc,
              onEnterDungeon: (id, diff) => enteredDungeon = '$id:$diff',
              onDifficultyChanged: (diff) => changedDifficulty = diff,
            ),
          ),
        ),
      );

      // Verify custom painter is present
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify location title
      expect(find.textContaining('Sanctum'), findsWidgets);

      // Verify 360 toggle
      expect(find.text('360° Açık'), findsOneWidget);

      // Verify dungeon title and level
      expect(find.textContaining('Önerilen Seviye'), findsOneWidget);

      // Verify difficulty pills
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Heroic'), findsOneWidget);
      expect(find.text('Mythic'), findsOneWidget);

      // Tap difficulty pill
      await tester.tap(find.text('Heroic'));
      await tester.pump();
      expect(changedDifficulty, equals('Heroic'));

      // Tap Dungeon entry button
      await tester.tap(find.text('ZİNDAN'));
      await tester.pump();
      expect(enteredDungeon, equals('all:Heroic'));
    });

    testWidgets('switching location type updates descriptor and triggers callbacks', (tester) async {
      final controller = Mekan3DViewportController(initialLocationType: 'bar');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Mekan3DViewport(
              controller: controller,
              selectedLocationType: 'bar',
              height: 310,
            ),
          ),
        ),
      );

      expect(find.textContaining('Taverna'), findsWidgets);

      // Update widget to dovus_kulubu
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Mekan3DViewport(
              controller: controller,
              selectedLocationType: 'dovus_kulubu',
              height: 310,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(controller.currentLocationType, equals('dovus_kulubu'));
      expect(find.textContaining('Dövüş'), findsWidgets);
    });
  });
}
