import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/vfx/dungeon_shadows.dart';
import 'package:gkk_flutter/core/vfx/ground_decal_system.dart' as gds;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DungeonShadows — Dynamic Soft Shadows (Module 9)', () {
    late DungeonShadowsController controller;

    setUp(() {
      controller = DungeonShadowsController.abyssalDungeon();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initializes with default lights and occluders in abyssal preset', () {
      expect(controller.lights.length, greaterThanOrEqualTo(2));
      expect(controller.occluders.length, greaterThanOrEqualTo(2));
      expect(controller.enabled, isTrue);

      final leftTorch = controller.getLight('torch_left');
      expect(leftTorch, isNotNull);
      expect(leftTorch!.color, equals(const Color(0xFFFF851B)));

      final playerOcc = controller.getOccluder('player_fighter');
      expect(playerOcc, isNotNull);
      expect(playerOcc!.radius, greaterThan(0.0));
      expect(playerOcc.height, greaterThan(0.0));
    });

    test('Torch flicker updates intensity and subtle wobble over time', () {
      final torch = controller.getLight('torch_left')!;
      final initialIntensity = torch.currentIntensity;
      final initialPos = torch.currentPosition;

      controller.update(0.15);

      expect(torch.currentIntensity, isNot(equals(initialIntensity)));
      expect(torch.currentIntensity, greaterThanOrEqualTo(torch.minIntensity));
      expect(torch.currentIntensity, lessThanOrEqualTo(torch.maxIntensity));
      expect(controller.timeSeconds, closeTo(0.15, 0.001));
    });

    test('Moving occluder updates position smoothly', () {
      const newPos = gds.Vector3D(0.5, 1.0, 1.2);
      controller.updateOccluderPosition('player_fighter', newPos);

      final playerOcc = controller.getOccluder('player_fighter')!;
      expect(playerOcc.center.x, equals(0.5));
      expect(playerOcc.center.y, equals(1.0));
      expect(playerOcc.center.z, equals(1.2));
    });

    test('Light removal and addition modifies active list', () {
      final initialCount = controller.lights.length;
      final newLight = DungeonShadowLight(
        id: 'test_flare',
        worldPosition: const gds.Vector3D(1.0, 2.0, 3.0),
        color: Colors.purple,
        type: ShadowLightType.magicalFlare,
      );

      controller.addLight(newLight);
      expect(controller.lights.length, equals(initialCount + 1));
      expect(controller.getLight('test_flare'), isNotNull);

      controller.removeLight('test_flare');
      expect(controller.lights.length, equals(initialCount));
      expect(controller.getLight('test_flare'), isNull);
    });

    test('Preset switches create distinct thematic lighting configurations', () {
      final colosseum = DungeonShadowsController.colosseumSunlight();
      expect(colosseum.lights.any((l) => l.type == ShadowLightType.directionalSun), isTrue);

      final siege = DungeonShadowsController.guildFortressSiege();
      expect(siege.lights.any((l) => l.id == 'siege_fire_left'), isTrue);
      expect(siege.occluders.any((o) => o.id == 'fortress_gate'), isTrue);

      colosseum.dispose();
      siege.dispose();
    });

    testWidgets('DungeonShadowsWidget renders in widget tree without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 200,
                child: DungeonShadowsWidget(
                  controller: controller,
                  child: Container(
                    key: const ValueKey('shadow_child'),
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('shadow_child')), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      controller.update(0.016);
      await tester.pump();
    });
  });
}
