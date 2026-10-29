import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/screens/character/widgets/character_turntable_viewport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CharacterTurntableViewport', () {
    testWidgets('renders character mode with defaults without error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterTurntableViewport(
              characterClass: CharacterClass.warrior,
            ),
          ),
        ),
      );

      // Verify Semantics and root widgets
      expect(find.byType(CharacterTurntableViewport), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('360°'), findsOneWidget);
      expect(find.text('Karakter Vitrini'), findsOneWidget);
      expect(find.text('Rün: Açık'), findsOneWidget);
    });

    testWidgets('toggles between character and weapon inspection modes',
        (WidgetTester tester) async {
      TurntableMode? lastReportedMode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterTurntableViewport(
              characterClass: CharacterClass.warrior,
              onModeChanged: (TurntableMode mode) {
                lastReportedMode = mode;
              },
            ),
          ),
        ),
      );

      expect(find.text('Karakter Vitrini'), findsOneWidget);

      // Tap mode toggle chip
      await tester.tap(find.text('Karakter Vitrini'));
      await tester.pump();

      // Now should switch to weapon inspection mode
      expect(lastReportedMode, TurntableMode.weapon);
      expect(find.text('Silah Teftişi'), findsOneWidget);
      expect(find.text('Efsanevi Altın Kılıç'), findsOneWidget);
      expect(find.text('Rün Yuvası [2/2]'), findsOneWidget);

      // Tap again to switch back to character mode
      await tester.tap(find.text('Silah Teftişi'));
      await tester.pump();

      expect(lastReportedMode, TurntableMode.character);
      expect(find.text('Karakter Vitrini'), findsOneWidget);
    });

    testWidgets('toggles runic emission highlights',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterTurntableViewport(
              characterClass: CharacterClass.alchemist,
            ),
          ),
        ),
      );

      expect(find.text('Rün: Açık'), findsOneWidget);

      // Tap rune glow button
      await tester.tap(find.text('Rün: Açık'));
      await tester.pump();

      expect(find.text('Rün: Kapalı'), findsOneWidget);

      // Tap again
      await tester.tap(find.text('Rün: Kapalı'));
      await tester.pump();

      expect(find.text('Rün: Açık'), findsOneWidget);
    });

    testWidgets('supports touch drag pan and double-tap orientation reset',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterTurntableViewport(
              characterClass: CharacterClass.shadow,
            ),
          ),
        ),
      );

      final Finder viewport = find.byType(GestureDetector).first;

      // Drag horizontally
      await tester.drag(viewport, const Offset(120, 0));
      await tester.pump();

      // Tap reset button
      await tester.tap(find.byTooltip('Açıyı Sıfırla'));
      await tester.pump();

      // Double-tap to reset
      await tester.tap(viewport);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(viewport);
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(CharacterTurntableViewport), findsOneWidget);
    });

    testWidgets('renders all character classes and null without exceptions',
        (WidgetTester tester) async {
      for (final CharacterClass? cClass in <CharacterClass?>[
        CharacterClass.warrior,
        CharacterClass.alchemist,
        CharacterClass.shadow,
        null,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CharacterTurntableViewport(
                characterClass: cClass,
                equippedCount: 5,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CharacterTurntableViewport), findsOneWidget);
      }
    });

    testWidgets('accepts custom GLB model path overrides gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterTurntableViewport(
              characterClass: CharacterClass.warrior,
              customGlbPath: 'assets/models/characters/Knight.glb',
              weaponGlbPath: 'assets/models/weapons/Claymore.glb',
              initialMode: TurntableMode.weapon,
            ),
          ),
        ),
      );

      expect(find.byType(CharacterTurntableViewport), findsOneWidget);
      expect(find.text('Silah Teftişi'), findsOneWidget);
    });

    testWidgets('cycles studio lighting presets with visual feedback',
        (WidgetTester tester) async {
      TurntableLightingPreset? currentPreset;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterTurntableViewport(
              characterClass: CharacterClass.warrior,
              onLightingPresetChanged: (TurntableLightingPreset preset) {
                currentPreset = preset;
              },
            ),
          ),
        ),
      );

      // Default preset is Stüdyo
      expect(find.text('Stüdyo'), findsOneWidget);

      // Cycle to Arkana
      await tester.tap(find.text('Stüdyo'));
      await tester.pump();
      expect(find.text('Arkana'), findsOneWidget);
      expect(currentPreset, TurntableLightingPreset.astralArcane);

      // Cycle to Alev
      await tester.tap(find.text('Arkana'));
      await tester.pump();
      expect(find.text('Alev'), findsOneWidget);
      expect(currentPreset, TurntableLightingPreset.forgeInferno);

      // Cycle to Gölge
      await tester.tap(find.text('Alev'));
      await tester.pump();
      expect(find.text('Gölge'), findsOneWidget);
      expect(currentPreset, TurntableLightingPreset.shadowAbyss);

      // Cycle back to Stüdyo
      await tester.tap(find.text('Gölge'));
      await tester.pump();
      expect(find.text('Stüdyo'), findsOneWidget);
      expect(currentPreset, TurntableLightingPreset.heroStudio);
    });

    testWidgets('toggles auto-rotation via 360 badge and renders fallback badge',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterTurntableViewport(
              characterClass: CharacterClass.alchemist,
            ),
          ),
        ),
      );
      await tester.pump();

      // Check fallback projection badge appears when 3D GLB is not loaded
      expect(find.text('Vektörel Projeksiyon Fallback'), findsOneWidget);

      // Tap 360 badge to toggle continuous auto-rotation
      final Finder badge360 = find.text('360°');
      expect(badge360, findsOneWidget);
      await tester.tap(badge360);
      await tester.pump();

      // Tap again to toggle off
      await tester.tap(badge360);
      await tester.pump();

      expect(find.byType(CharacterTurntableViewport), findsOneWidget);
    });
  });
}
