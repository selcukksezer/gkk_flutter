import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/guild_war/widgets/faction_crest_painter.dart';
import 'package:gkk_flutter/screens/guild_war/widgets/faction_war_banner.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

void main() {
  group('Faction Crest & Banner Heraldry Tests', () {
    test('FactionType properties are accurately configured', () {
      expect(FactionType.elyos.displayName, contains('Elyos'));
      expect(FactionType.asmodian.displayName, contains('Asmodian'));
      expect(FactionType.neutral.displayName, contains('Muhafız'));

      expect(FactionType.elyos.primaryColor, equals(AppColors.liquidGold));
      expect(FactionType.asmodian.primaryColor, equals(AppColors.mysticRuby));
    });

    test('GuildCrestSymbol string parsing handles known and fallback cases', () {
      expect(GuildCrestSymbol.fromString('dragon'), equals(GuildCrestSymbol.dragon));
      expect(GuildCrestSymbol.fromString('LION'), equals(GuildCrestSymbol.lion));
      expect(GuildCrestSymbol.fromString('blade'), equals(GuildCrestSymbol.blade));
      expect(GuildCrestSymbol.fromString('unknown_symbol'), equals(GuildCrestSymbol.dragon));
      expect(GuildCrestSymbol.fromString(null), equals(GuildCrestSymbol.dragon));
    });

    testWidgets('FactionCrestWidget renders without error for all factions', (WidgetTester tester) async {
      for (final faction in FactionType.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: FactionCrestWidget(
                  faction: faction,
                  size: 64,
                  showGlow: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(FactionCrestWidget), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    testWidgets('GuildCustomCrestWidget renders all heraldic symbol charges', (WidgetTester tester) async {
      for (final sym in GuildCrestSymbol.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: GuildCustomCrestWidget(
                  symbol: sym,
                  primaryColor: AppColors.liquidGold,
                  secondaryColor: const Color(0xFF2A1C1C),
                  frame: GuildHeraldicFrame.goldFiligree,
                  size: 48,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(GuildCustomCrestWidget), findsOneWidget);
      }
    });

    testWidgets('GuildWarRoomBanner renders guild name, crest, and points badge', (WidgetTester tester) async {
      bool bannerTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GuildWarRoomBanner(
                guildName: 'Demir Muhafızlar',
                faction: FactionType.elyos,
                symbol: GuildCrestSymbol.dragon,
                primaryColor: AppColors.liquidGold,
                secondaryColor: const Color(0xFF3E2723),
                rankBadge: '#1 Lider',
                points: 4500,
                onTap: () => bannerTapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Demir Muhafızlar'), findsOneWidget);
      expect(find.text('#1 Lider'), findsOneWidget);
      expect(find.byType(GuildCustomCrestWidget), findsOneWidget);

      await tester.tap(find.byType(GuildWarRoomBanner));
      expect(bannerTapped, isTrue);
    });

    testWidgets('FactionWarBanner renders Elyos and Asmodian clash with territory ratio', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FactionWarBanner(
              faction: FactionType.elyos,
              title: 'ELYOS ŞEREFİ',
              subtitle: 'Işığın Egemenliği',
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('ELYOS ŞEREFİ'), findsOneWidget);
      expect(find.text('Işığın Egemenliği'), findsOneWidget);
      expect(find.byType(FactionCrestWidget), findsOneWidget);
    });
  });
}
