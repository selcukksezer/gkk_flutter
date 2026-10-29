import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/components/pvp/colosseum_arena_lighting.dart';
import 'package:gkk_flutter/screens/pvp/widgets/arena_map_viewport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArenaLightingTheme Architectural Tests', () {
    test('Sanctum Celestial preset initializes authentic celestial lighting', () {
      final ArenaLightingTheme theme = ArenaLightingTheme.sanctumCelestial();
      expect(theme.name, 'Sanctum Göksel Meydanı');
      expect(theme.sunElevation, greaterThan(1.0)); // High sun angle
      expect(theme.sunIntensity, greaterThanOrEqualTo(0.9));
      expect(theme.sunColor, const Color(0xFFFFE082));
      expect(theme.crystalColor, const Color(0xFF00E5FF));
      expect(theme.beamCount, 6);
      expect(theme.dustMoteCount, 30);
    });

    test('Abyssal Eclipse preset initializes low dramatic crimson lighting', () {
      final ArenaLightingTheme theme = ArenaLightingTheme.abyssalEclipse();
      expect(theme.name, 'Uçurum Gladyatör Arenası');
      expect(theme.sunElevation, lessThan(0.7)); // Low sun angle for long shadows
      expect(theme.sunIntensity, greaterThanOrEqualTo(0.85));
      expect(theme.sunColor, const Color(0xFFFF3D00));
      expect(theme.crystalColor, const Color(0xFFFF1744));
      expect(theme.beamCount, 7);
      expect(theme.dustMoteCount, 35);
    });

    test('Obsidian Chasm preset initializes subterranean cyan crystal illumination', () {
      final ArenaLightingTheme theme = ArenaLightingTheme.obsidianChasm();
      expect(theme.name, 'Obsidiyen Çukur Koloseumu');
      expect(theme.sunColor, const Color(0xFF64FFDA));
      expect(theme.crystalColor, const Color(0xFF00B0FF));
      expect(theme.beamCount, 5);
      expect(theme.dustMoteCount, 26);
    });

    test('Dawn Gladiator preset initializes morning amber sunbeam illumination', () {
      final ArenaLightingTheme theme = ArenaLightingTheme.dawnGladiator();
      expect(theme.name, 'Şafak Gladyatör Koloseumu');
      expect(theme.sunElevation, closeTo(0.45, 0.05));
      expect(theme.sunColor, const Color(0xFFFFB300));
    });

    test('fromAtmosphere correctly maps all 4 colosseum atmospheres', () {
      for (final ColosseumAtmosphere atmosphere in ColosseumAtmosphere.values) {
        final ArenaLightingTheme theme = ArenaLightingTheme.fromAtmosphere(atmosphere);
        expect(theme.name, isNotEmpty);
        expect(theme.sunIntensity, inInclusiveRange(0.0, 1.0));
        expect(theme.beamCount, greaterThan(0));
        expect(theme.dustMoteCount, greaterThan(0));
      }
    });
  });

  group('ColosseumArenaPainter & Shadow Caster Rendering Tests', () {
    testWidgets('ColosseumArenaLighting renders custom painter with all layers enabled', (
      WidgetTester tester,
    ) async {
      final ArenaLightingTheme theme = ArenaLightingTheme.sanctumCelestial();
      final List<GladiatorShadowSlot> slots = <GladiatorShadowSlot>[
        const GladiatorShadowSlot(
          position: Offset(0.3, 0.6),
          height: 70.0,
          width: 30.0,
        ),
        const GladiatorShadowSlot(
          position: Offset(0.7, 0.6),
          height: 70.0,
          width: 30.0,
          lungeOffset: Offset(5, -2),
          hitShake: 0.5,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColosseumArenaLighting(
              theme: theme,
              height: 250.0,
              gladiatorSlots: slots,
              combatFlash: 0.8,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(ColosseumArenaLighting), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    test('ColosseumArenaPainter shouldRepaint triggers on animation or theme change', () {
      final ArenaLightingTheme themeA = ArenaLightingTheme.sanctumCelestial();
      final ArenaLightingTheme themeB = ArenaLightingTheme.abyssalEclipse();

      final ColosseumArenaPainter painter1 = ColosseumArenaPainter(
        animationProgress: 0.0,
        theme: themeA,
      );
      final ColosseumArenaPainter painter2 = ColosseumArenaPainter(
        animationProgress: 0.5,
        theme: themeA,
      );
      final ColosseumArenaPainter painter3 = ColosseumArenaPainter(
        animationProgress: 0.0,
        theme: themeB,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
      expect(painter1.shouldRepaint(painter3), isTrue);
    });

    test('Directional shadow projection reacts mathematically to sun elevation', () {
      // Lower sun elevation produces longer cotangent shadow
      final ArenaLightingTheme lowSun = ArenaLightingTheme.abyssalEclipse();
      final ArenaLightingTheme highSun = ArenaLightingTheme.sanctumCelestial();

      final double cotLow = 1.0 / math.tan(lowSun.sunElevation);
      final double cotHigh = 1.0 / math.tan(highSun.sunElevation);

      expect(cotLow, greaterThan(cotHigh));
    });
  });

  group('ArenaMapViewport Integration & Mobile Responsiveness Tests', () {
    testWidgets('ArenaMapViewport renders in mobile portrait mode (390x844)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool entered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArenaMapViewport(
              currentRating: 1450,
              onEnterArena: () => entered = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ArenaMapViewport), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('Rating: 1450'), findsOneWidget);
      expect(find.text('Arenaya Gir'), findsOneWidget);

      await tester.tap(find.text('Arenaya Gir'));
      await tester.pump();
      expect(entered, isTrue);
    });

    testWidgets('ArenaMapViewport renders in landscape mode (844x390)', (
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
            body: ArenaMapViewport(currentRating: 1800),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ArenaMapViewport), findsOneWidget);
      expect(find.text('ARENA MODU'), findsOneWidget);
    });

    test('ArenaThemeInfo effectiveLightingTheme resolves appropriate presets', () {
      final ArenaThemeInfo abyssal = defaultArenaThemes[0];
      final ArenaThemeInfo sanctum = defaultArenaThemes[1];
      final ArenaThemeInfo obsidian = defaultArenaThemes[2];

      expect(abyssal.effectiveLightingTheme.name, 'Uçurum Gladyatör Arenası');
      expect(sanctum.effectiveLightingTheme.name, 'Sanctum Göksel Meydanı');
      expect(obsidian.effectiveLightingTheme.name, 'Obsidiyen Çukur Koloseumu');
    });
  });
}
