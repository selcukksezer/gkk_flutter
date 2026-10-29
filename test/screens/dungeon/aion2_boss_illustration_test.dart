import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/dungeon_model.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/aion2_boss_illustration_catalog.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/aion2_presentation_frame.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_card.dart';

void main() {
  group('Aion2BossIllustrationCatalog tests', () {
    test('Resolves distinct boss definitions for each zone 1..7', () {
      final Set<String> bossIds = <String>{};
      for (int zone = 1; zone <= 7; zone++) {
        final Aion2BossArtDefinition boss =
            Aion2BossIllustrationCatalog.resolveForZone(zone);
        expect(boss.zone, equals(zone));
        expect(boss.name, isNotEmpty);
        expect(boss.title, isNotEmpty);
        expect(boss.element, isNotEmpty);
        expect(boss.loreQuote, isNotEmpty);
        expect(boss.fallbackDungeonAsset, isNotEmpty);
        bossIds.add(boss.bossId);
      }
      expect(bossIds.length, equals(7), reason: 'Each zone has a unique boss');
    });

    test('Resolves correctly for dungeon numbers across tier thresholds', () {
      expect(Aion2BossIllustrationCatalog.resolveForDungeonNumber(5).zone, equals(1));
      expect(Aion2BossIllustrationCatalog.resolveForDungeonNumber(15).zone, equals(2));
      expect(Aion2BossIllustrationCatalog.resolveForDungeonNumber(25).zone, equals(3));
      expect(Aion2BossIllustrationCatalog.resolveForDungeonNumber(35).zone, equals(4));
      expect(Aion2BossIllustrationCatalog.resolveForDungeonNumber(45).zone, equals(5));
      expect(Aion2BossIllustrationCatalog.resolveForDungeonNumber(55).zone, equals(6));
      expect(Aion2BossIllustrationCatalog.resolveForDungeonNumber(65).zone, equals(7));
    });

    test('Resolves for DungeonData model with zone override', () {
      const DungeonData dungeon = DungeonData(
        id: '1',
        dungeonId: 'dng_025',
        name: 'Ateş Tapınağı',
        description: 'Akkor alevler',
        difficulty: 'dungeon',
        requiredLevel: 25,
        maxPlayers: 1,
        energyCost: 10,
        minGold: 100,
        maxGold: 500,
        lootTable: <String>[],
        isGroup: false,
        zone: 3,
        isBoss: true,
      );

      final Aion2BossArtDefinition boss =
          Aion2BossIllustrationCatalog.resolveForDungeon(dungeon: dungeon);
      expect(boss.zone, equals(3));
      expect(boss.name, contains('Ignis'));
      expect(boss.tier, equals(Aion2BossTier.abyssalOverlord));
    });
  });

  group('Aion2AbyssalIllustrationPainter tests', () {
    test('Repaint logic responds to progress and intensity changes', () {
      final Aion2BossArtDefinition boss =
          Aion2BossIllustrationCatalog.resolveForZone(1);
      final Aion2AbyssalIllustrationPainter painter1 =
          Aion2AbyssalIllustrationPainter(
        boss: boss,
        animationProgress: 0.2,
        intensity: 1.0,
      );
      final Aion2AbyssalIllustrationPainter painter2 =
          Aion2AbyssalIllustrationPainter(
        boss: boss,
        animationProgress: 0.5,
        intensity: 1.0,
      );
      final Aion2AbyssalIllustrationPainter painter3 =
          Aion2AbyssalIllustrationPainter(
        boss: boss,
        animationProgress: 0.2,
        intensity: 0.8,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
      expect(painter1.shouldRepaint(painter3), isTrue);
      expect(painter1.shouldRepaint(painter1), isFalse);
    });

    testWidgets('CustomPaint with Aion2AbyssalIllustrationPainter renders cleanly',
        (WidgetTester tester) async {
      final Aion2BossArtDefinition boss =
          Aion2BossIllustrationCatalog.resolveForZone(4);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 200,
              child: CustomPaint(
                painter: Aion2AbyssalIllustrationPainter(
                  boss: boss,
                  animationProgress: 0.35,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('Aion2GoldFiligreePainter & Frame tests', () {
    test('Gold filigree painter shouldRepaint respects properties', () {
      const Aion2GoldFiligreePainter p1 = Aion2GoldFiligreePainter(
        primaryGold: Color(0xFFFFD700),
        cornerSize: 20,
      );
      const Aion2GoldFiligreePainter p2 = Aion2GoldFiligreePainter(
        primaryGold: Color(0xFFFFAA00),
        cornerSize: 20,
      );
      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p1), isFalse);
    });

    testWidgets('Aion2GlassmorphicFrame displays child and filigree border',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Aion2GlassmorphicFrame(
              showFiligree: true,
              child: Text('FRAME CONTENT'),
            ),
          ),
        ),
      );

      expect(find.text('FRAME CONTENT'), findsOneWidget);
      expect(find.byType(Aion2GlassmorphicFrame), findsOneWidget);
    });
  });

  group('Aion2BossPortraitCard & Intro Banner tests', () {
    testWidgets('Aion2BossPortraitCard displays boss name and attributes',
        (WidgetTester tester) async {
      final Aion2BossArtDefinition boss =
          Aion2BossIllustrationCatalog.resolveForZone(5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Aion2BossPortraitCard(
              boss: boss,
              height: 140,
              showLore: true,
            ),
          ),
        ),
      );

      expect(find.text(boss.name), findsOneWidget);
      expect(find.text(boss.tier.label), findsOneWidget);
      expect(find.text(boss.element.toUpperCase()), findsOneWidget);
      expect(find.text(boss.loreQuote), findsOneWidget);
    });

    testWidgets('Aion2BossIntroBanner renders VS dual portraits and titles',
        (WidgetTester tester) async {
      final Aion2BossArtDefinition boss =
          Aion2BossIllustrationCatalog.resolveForZone(3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Aion2BossIntroBanner(
                boss: boss,
                playerName: 'ALPHAWOLF',
                playerLevel: 42,
                playerAsset: 'assets/characters/savasci.png',
                playerColor: const Color(0xFF00FF66),
                animationProgress: 0.5,
              ),
            ),
          ),
        ),
      );

      expect(find.text('VS'), findsOneWidget);
      expect(find.text('LV.42 KAHRAMAN'), findsOneWidget);
      expect(find.text(boss.tier.label), findsOneWidget);
      expect(find.textContaining(boss.title.toUpperCase()), findsOneWidget);
    });
  });

  group('DungeonCard boss presentation integration tests', () {
    testWidgets('DungeonCard displays gold filigree and boss title when isBoss is true',
        (WidgetTester tester) async {
      const DungeonData bossDungeon = DungeonData(
        id: 'dng_boss_7',
        dungeonId: 'dng_065',
        name: 'Kadim Ejder Mabedi',
        description: 'Tiamat Uçurum Yuvası',
        difficulty: 'dungeon_boss',
        requiredLevel: 65,
        maxPlayers: 1,
        energyCost: 15,
        minGold: 500,
        maxGold: 2000,
        lootTable: <String>[],
        isGroup: false,
        zone: 7,
        isBoss: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DungeonCard(
                dungeon: bossDungeon,
                zone: null,
                canEnter: true,
                inHospital: false,
                inPrison: false,
                entering: false,
                successPercent: 75,
                playerPower: 120000,
                powerRequirement: 100000,
                onEnter: () {},
                onLoot: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Kadim Ejder Mabedi'), findsOneWidget);
      expect(find.text('BOSS'), findsOneWidget);
      // Gold filigree painter should be present in the tree
      final Iterable<CustomPaint> customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );
      final bool hasFiligree = customPaints.any(
        (CustomPaint cp) => cp.painter is Aion2GoldFiligreePainter,
      );
      expect(hasFiligree, isTrue, reason: 'Boss card must have Aion2GoldFiligreePainter');
    });
  });
}
