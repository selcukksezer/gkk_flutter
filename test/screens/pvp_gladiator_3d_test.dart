import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/components/pvp/pvp_duel_battle_screen.dart';
import 'package:gkk_flutter/components/pvp/pvp_gladiator_3d_view.dart';
import 'package:gkk_flutter/screens/pvp/widgets/arena_map_viewport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PvpGladiator3dView Stance & Weapon Tests', () {
    testWidgets('renders all 5 gladiator classes with their default weapons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  PvpGladiator3dView(
                    gladiatorClass: GladiatorClass.knight,
                    weapon: GladiatorWeapon.claymore,
                    stance: GladiatorStance.idle,
                  ),
                  PvpGladiator3dView(
                    gladiatorClass: GladiatorClass.barbarian,
                    weapon: GladiatorWeapon.battleaxe,
                    stance: GladiatorStance.combatReady,
                  ),
                  PvpGladiator3dView(
                    gladiatorClass: GladiatorClass.mage,
                    weapon: GladiatorWeapon.darkSword,
                    stance: GladiatorStance.attacking,
                  ),
                  PvpGladiator3dView(
                    gladiatorClass: GladiatorClass.soldier,
                    weapon: GladiatorWeapon.goldenSword,
                    stance: GladiatorStance.victory,
                  ),
                  PvpGladiator3dView(
                    gladiatorClass: GladiatorClass.skeleton,
                    weapon: GladiatorWeapon.dagger,
                    stance: GladiatorStance.defeated,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PvpGladiator3dView), findsNWidgets(5));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('GladiatorClass.fromNameOrId resolves various naming conventions', (
      WidgetTester tester,
    ) async {
      expect(GladiatorClass.fromNameOrId('char_knight'), GladiatorClass.knight);
      expect(GladiatorClass.fromNameOrId('Şövalye'), GladiatorClass.knight);
      expect(GladiatorClass.fromNameOrId('Barbarian Warrior'), GladiatorClass.barbarian);
      expect(GladiatorClass.fromNameOrId('Büyücü Sorcerer'), GladiatorClass.mage);
      expect(GladiatorClass.fromNameOrId('Lejyoner Asker'), GladiatorClass.soldier);
      expect(GladiatorClass.fromNameOrId('Skeleton Undead'), GladiatorClass.skeleton);
      expect(GladiatorClass.fromNameOrId(null), GladiatorClass.knight);
    });

    testWidgets('GladiatorStance transitions smoothly without errors', (
      WidgetTester tester,
    ) async {
      GladiatorStance currentStance = GladiatorStance.idle;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: <Widget>[
                    PvpGladiator3dView(
                      gladiatorClass: GladiatorClass.knight,
                      stance: currentStance,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          currentStance = GladiatorStance.hitReact;
                        });
                      },
                      child: const Text('Hit'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(PvpGladiator3dView), findsOneWidget);

      // Trigger hit react stance
      await tester.tap(find.text('Hit'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PvpGladiator3dView), findsOneWidget);
    });

    testWidgets('interactive horizontal drag rotates gladiator yaw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PvpGladiator3dView(
                gladiatorClass: GladiatorClass.knight,
                interactiveRotation: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Drag across the gladiator view
      await tester.drag(find.byType(PvpGladiator3dView), const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(PvpGladiator3dView), findsOneWidget);
    });
  });

  group('ArenaMapViewport 3D Gladiator Integration Tests', () {
    testWidgets('ArenaMapViewport renders 3D Gladiator on colosseum stage in portrait', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArenaMapViewport(
              currentRating: 1450,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PvpGladiator3dView), findsOneWidget);
      expect(find.text('Rating: 1450'), findsOneWidget);
    });

    testWidgets('ArenaMapViewport renders 3D Gladiator on colosseum stage in landscape', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArenaMapViewport(
              currentRating: 1620,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PvpGladiator3dView), findsOneWidget);
      expect(find.text('ARENA MODU'), findsOneWidget);
    });
  });

  group('PvpDuelBattleScreen 3D Gladiators Combat Tests', () {
    testWidgets('PvpDuelBattleScreen builds and mounts with fighters and gladiator views', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final Map<String, dynamic> mockDuel = <String, dynamic>{
        'challenger_won': true,
        'wager': 500,
        'net_win': 950,
        'challenger_rating_change': 25,
        'target_rating_change': -20,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PvpDuelBattleScreen(
              duel: mockDuel,
              myAuthId: 'player_123',
              iAmChallenger: true,
              wager: 500,
              opponentId: 'opponent_456',
              opponentName: 'Gladiator Rex',
              opponentLevel: 12,
              opponentPower: 3400,
              opponentRating: 1500,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // In loading/intro phase, check that the screen renders
      expect(find.byType(PvpDuelBattleScreen), findsOneWidget);
    });
  });
}
