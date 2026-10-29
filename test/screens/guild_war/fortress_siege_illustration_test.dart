import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/guild_war/widgets/faction_crest_painter.dart';
import 'package:gkk_flutter/screens/guild_war/widgets/fortress_siege_illustration.dart';

void main() {
  group('FortressTheme Archetype Tests', () {
    test('Correctly maps Turkish and dark fantasy names to themes', () {
      expect(
        FortressTheme.fromName('Uçurum Kalesi'),
        equals(FortressTheme.abyssalCitadel),
      );
      expect(
        FortressTheme.fromName('Merkez Bastion'),
        equals(FortressTheme.celestialSanctuary),
      );
      expect(
        FortressTheme.fromName('Ejderha Mabedi'),
        equals(FortressTheme.dragonShrine),
      );
      expect(
        FortressTheme.fromName('Batık Geçit'),
        equals(FortressTheme.sunkenGate),
      );
      expect(
        FortressTheme.fromName('Obsidiyen Kule'),
        equals(FortressTheme.obsidianBastion),
      );
    });

    test('Each theme defines distinctive sky and energy colors', () {
      for (final theme in FortressTheme.values) {
        expect(theme.skyTop, isNotNull);
        expect(theme.skyBottom, isNotNull);
        expect(theme.stoneColorPrimary, isNotNull);
        expect(theme.stoneColorHighlight, isNotNull);
        expect(theme.energyGlow, isNotNull);
      }
    });
  });

  group('FortressSiegeIllustration Widget Tests', () {
    testWidgets('Renders fortress title, faction crest, and shield integrity', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FortressSiegeIllustration(
              fortressName: 'Merkez Bastion',
              faction: FactionType.elyos,
              shieldIntegrity: 0.85,
              isUnderSiege: false,
              garrisonCount: 24,
              defensePower: 8500,
              maxDefensePower: 10000,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Merkez Bastion'), findsOneWidget);
      expect(find.text('Elyos (Işık Hanedanı)'), findsOneWidget);
      expect(find.text('Kalkan: %85'), findsOneWidget);
      expect(find.text('24 Savaşçı'), findsOneWidget);
      expect(find.text('8500'), findsOneWidget);
    });

    testWidgets('Renders under siege warning pill when isUnderSiege is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FortressSiegeIllustration(
              fortressName: 'Uçurum Kalesi',
              faction: FactionType.asmodian,
              shieldIntegrity: 0.35,
              isUnderSiege: true,
              defensePower: 3500,
              maxDefensePower: 10000,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Uçurum Kalesi'), findsOneWidget);
      expect(find.text('KUŞATMA ALTINDA'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    });

    testWidgets('Triggers onTap callback when tapped', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FortressSiegeIllustration(
              fortressName: 'Ejderha Mabedi',
              faction: FactionType.neutral,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FortressSiegeIllustration));
      expect(tapped, isTrue);
    });

    testWidgets('CustomPainter repaints cleanly over time', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FortressSiegeIllustration(
              fortressName: 'Batık Geçit',
              faction: FactionType.neutral,
              shieldIntegrity: 0.5,
              isUnderSiege: true,
            ),
          ),
        ),
      );

      // Advance animation frames
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
