import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/codex_model.dart';
import 'package:gkk_flutter/screens/character/widgets/codex_design.dart';

void main() {
  group('CodexPalette & Dark Fantasy Themes', () {
    test('Palettes and high fantasy gradients are properly defined', () {
      expect(CodexPalette.void_, equals(const Color(0xFF080B12)));
      expect(CodexPalette.aetherCyan, equals(const Color(0xFF00E5FF)));
      expect(CodexPalette.daevaGold, equals(const Color(0xFFFFD700)));
      expect(CodexPalette.tahabataFlame, equals(const Color(0xFFFF3D00)));
      expect(CodexPalette.stormwingCyan, equals(const Color(0xFF00F0FF)));
      expect(CodexPalette.miragentBlue, equals(const Color(0xFF2563EB)));

      expect(CodexPalette.daevanionGrad.colors.length, greaterThanOrEqualTo(2));
      expect(CodexPalette.miragentGrad.colors.length, greaterThanOrEqualTo(2));
      expect(CodexPalette.stormwingGrad.colors.length, greaterThanOrEqualTo(2));
      expect(CodexPalette.tahabataGrad.colors.length, greaterThanOrEqualTo(2));
    });
  });

  group('CodexGearSet Model & Progression Logic', () {
    test('allSets contains Daevanion, Miragent, Stormwing, and Tahabata', () {
      final List<CodexGearSet> sets = CodexGearSet.allSets;
      expect(sets.length, equals(4));

      final List<String> ids = sets.map((CodexGearSet s) => s.id).toList();
      expect(ids, containsAll(<String>['daevanion', 'miragent', 'stormwing', 'tahabata']));

      for (final CodexGearSet s in sets) {
        expect(s.pieces.length, equals(4), reason: '${s.name} must have 4 pieces');
        expect(s.bonus2Piece.isNotEmpty, isTrue);
        expect(s.bonus4Piece.isNotEmpty, isTrue);
        expect(s.lore.isNotEmpty, isTrue);
      }
    });

    test('Piece discovery and 2-piece / 4-piece milestone unlocking logic', () {
      final CodexGearSet daevanion = CodexGearSet.daevanion;

      // 0 pieces discovered
      expect(daevanion.discoveredPiecesCount(const <CodexEntry>[]), equals(0));
      expect(daevanion.is2PieceUnlocked(const <CodexEntry>[]), isFalse);
      expect(daevanion.is4PieceUnlocked(const <CodexEntry>[]), isFalse);

      // 1 piece discovered
      final List<CodexEntry> onePiece = <CodexEntry>[
        const CodexEntry(
          entryType: 'item',
          entryKey: 'daevanion_sword',
          displayName: 'Daevanion Kutsal Uzunkılıç',
          isDiscovered: true,
        ),
      ];
      expect(daevanion.discoveredPiecesCount(onePiece), equals(1));
      expect(daevanion.is2PieceUnlocked(onePiece), isFalse);

      // 2 pieces discovered
      final List<CodexEntry> twoPieces = <CodexEntry>[
        ...onePiece,
        const CodexEntry(
          entryType: 'item',
          entryKey: 'daevanion_cuirass',
          displayName: 'Daevanion Işık Göğüslüğü',
          isDiscovered: true,
        ),
      ];
      expect(daevanion.discoveredPiecesCount(twoPieces), equals(2));
      expect(daevanion.is2PieceUnlocked(twoPieces), isTrue);
      expect(daevanion.is4PieceUnlocked(twoPieces), isFalse);

      // 4 pieces discovered
      final List<CodexEntry> fourPieces = <CodexEntry>[
        ...twoPieces,
        const CodexEntry(
          entryType: 'item',
          entryKey: 'daevanion_greaves',
          displayName: 'Daevanion Şövalye Dizlikleri',
          isDiscovered: true,
        ),
        const CodexEntry(
          entryType: 'item',
          entryKey: 'daevanion_wings',
          displayName: 'Daevanion Kanat Yadigarı',
          isDiscovered: true,
        ),
      ];
      expect(daevanion.discoveredPiecesCount(fourPieces), equals(4));
      expect(daevanion.is2PieceUnlocked(fourPieces), isTrue);
      expect(daevanion.is4PieceUnlocked(fourPieces), isTrue);
    });

    test('Stormwing & Tahabata piece slots and stats are configured', () {
      final CodexGearSet stormwing = CodexGearSet.stormwing;
      expect(stormwing.pieces.any((CodexGearSetPiece p) => p.slot == 'Silah'), isTrue);
      expect(stormwing.pieces.any((CodexGearSetPiece p) => p.slot == 'Zırh'), isTrue);

      final CodexGearSet tahabata = CodexGearSet.tahabata;
      expect(tahabata.pieces.any((CodexGearSetPiece p) => p.name.contains('Tahabata')), isTrue);
      for (final CodexGearSetPiece piece in tahabata.pieces) {
        expect(piece.stats.isNotEmpty, isTrue);
      }
    });
  });

  group('Codex Visual Components Widget Tests', () {
    testWidgets('CodexCompletionRing displays percentage and radial arc', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CodexCompletionRing(
                progress: 0.65,
                discovered: 65,
                total: 100,
              ),
            ),
          ),
        ),
      );

      expect(find.text('%65'), findsOneWidget);
      expect(find.text('ARŞİV'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('CodexTurntable3DView renders rotating 3D pedestal with touch drag', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CodexTurntable3DView(
                accentColor: CodexPalette.daevaGold,
                iconData: Icons.shield_rounded,
                size: 150,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CodexTurntable3DView), findsOneWidget);
      expect(find.text('3D ÇEVİR · KAYDIR'), findsOneWidget);

      // Perform horizontal drag to simulate turntable rotation
      await tester.drag(find.byType(CodexTurntable3DView), const Offset(40, 0));
      await tester.pump();
    });

    testWidgets('CodexGearSetCard renders piece slots and set bonuses', (WidgetTester tester) async {
      CodexGearSetPiece? inspectedPiece;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CodexGearSetCard(
                gearSet: CodexGearSet.daevanion,
                discoveredEntries: const <CodexEntry>[
                  CodexEntry(
                    entryType: 'item',
                    entryKey: 'daevanion_sword',
                    displayName: 'Daevanion Kutsal Uzunkılıç',
                    isDiscovered: true,
                  ),
                ],
                onInspectPiece: (CodexGearSetPiece piece) {
                  inspectedPiece = piece;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Daevanion Seti'), findsOneWidget);
      expect(find.text('1/4 Parça'), findsOneWidget);
      expect(find.text('2P'), findsOneWidget);
      expect(find.text('4P'), findsOneWidget);

      // Tap first piece
      await tester.tap(find.text('Silah').first);
      await tester.pump();

      expect(inspectedPiece, isNotNull);
      expect(inspectedPiece!.id, equals('daevanion_sword'));
    });

    testWidgets('CodexEntryDetailSheet shows 3D turntable, full lore, and dismisses on close', (WidgetTester tester) async {
      const CodexEntry sample = CodexEntry(
        entryType: 'item',
        entryKey: 'stormwing_bow',
        displayName: 'Stormwing Caelum Yayı',
        rarity: 'mythic',
        zone: 'Bölge 4',
        isDiscovered: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    CodexEntryDetailSheet.show(
                      context,
                      entry: sample,
                      rarityColor: CodexPalette.abyssViolet,
                      customLore: 'Beshmundir kadim ejderha yayı lore metni.',
                      setAffiliation: 'Stormwing Abyss Seti [Silah]',
                      statAttributes: const <String, String>{
                        'Menzilli Saldırı': '+445',
                        'Kritik Oranı': '+15%',
                      },
                    );
                  },
                  child: const Text('İncele'),
                );
              },
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('İncele'));
      await tester.pumpAndSettle();

      expect(find.text('Stormwing Caelum Yayı'), findsOneWidget);
      expect(find.text('Stormwing Abyss Seti [Silah]'), findsOneWidget);
      expect(find.text('Beshmundir kadim ejderha yayı lore metni.'), findsOneWidget);
      expect(find.text('Menzilli Saldırı'), findsOneWidget);
      expect(find.text('+445'), findsOneWidget);
      expect(find.byType(CodexTurntable3DView), findsOneWidget);

      // Close sheet
      await tester.tap(find.text('KAPAT'));
      await tester.pumpAndSettle();

      expect(find.text('Beshmundir kadim ejderha yayı lore metni.'), findsNothing);
    });

    testWidgets('CodexCategoryBar renders 6 tabs with counts', (WidgetTester tester) async {
      int selected = 0;
      final List<(String, String, IconData)> tabs = <(String, String, IconData)>[
        ('sets', 'Setler', Icons.shield_moon_rounded),
        ('weapons', 'Silah', Icons.colorize_rounded),
        ('armor', 'Zırh', Icons.shield_rounded),
        ('accessories', 'Aksesuar', Icons.diamond_rounded),
        ('monster_lore', 'Canavar', Icons.whatshot_rounded),
        ('all', 'Tümü', Icons.auto_stories_rounded),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodexCategoryBar(
              tabs: tabs,
              selectedIndex: selected,
              counts: const <String, (int, int)>{
                'sets': (4, 16),
                'weapons': (12, 40),
                'armor': (8, 30),
                'accessories': (5, 15),
                'monster_lore': (10, 20),
                'all': (39, 121),
              },
              onChanged: (int idx) => selected = idx,
            ),
          ),
        ),
      );

      expect(find.text('Setler'), findsOneWidget);
      expect(find.text('4/16'), findsOneWidget);
      expect(find.text('Silah'), findsOneWidget);
      expect(find.text('12/40'), findsOneWidget);
    });
  });
}
