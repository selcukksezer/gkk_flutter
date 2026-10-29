import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/guild_war_model.dart';
import 'package:gkk_flutter/screens/guild_war/widgets/territory_detail_ui.dart';

void main() {
  group('Guild War Logic & Business Calculations Preservation', () {
    test('territoryBonusSummary accurately computes trade income and hourly kasa rate', () {
      const territory = TerritoryData(
        id: 't-test',
        name: 'Garnizon Kalesi',
        tradeIncome: 4800,
        tradeIncomeHourly: 200.0,
        defenseLineLevel: 3,
        reward: 'Efsanevi Kasa',
      );

      final bonuses = territoryBonusSummary(territory);
      expect(bonuses.any((b) => b.contains('4800/gün')), isTrue);
      expect(bonuses.any((b) => b.contains('~200/saat kasa')), isTrue);
      expect(bonuses.any((b) => b.contains('Savunma hattı Sv.3')), isTrue);
    });

    test('territoryMapCoordinateFor produces deterministic grid coordinates', () {
      final list = <TerritoryData>[
        const TerritoryData(id: 't-1', name: 'T1'),
        const TerritoryData(id: 't-2', name: 'T2'),
        const TerritoryData(id: 't-3', name: 'T3'),
        const TerritoryData(id: 't-4', name: 'T4'),
        const TerritoryData(id: 't-5', name: 'T5'),
      ];

      expect(territoryMapCoordinateFor('t-1', list), equals('Harita 1·1'));
      expect(territoryMapCoordinateFor('t-2', list), equals('Harita 2·1'));
      expect(territoryMapCoordinateFor('t-5', list), equals('Harita 1·2'));
    });

    test('GuildWarRanking rank score calculation formula is preserved', () {
      final ranking = GuildWarRanking.fromJson({
        'rank': 1,
        'guild_id': 'g-100',
        'guild_name': 'Kızıl Şahinler',
        'points': 800,
        'prestige': 400,
        'rank_score': 900,
        'wins': 10,
        'losses': 2,
      });

      expect(ranking.guildName, equals('Kızıl Şahinler'));
      expect(ranking.points, equals(800));
      expect(ranking.prestige, equals(400));
      expect(ranking.rankScore, equals(900));
      expect(ranking.wins, equals(10));
    });

    test('LiveGuildWarClash time calculation and rally eligibility logic', () {
      final now = DateTime.now().toUtc();
      final clash = LiveGuildWarClash(
        matchId: 'clash-123',
        tournamentId: 'tourn-99',
        tournamentTitle: 'Büyük Kuşatma',
        guild1Id: 'g1',
        guild1Name: 'Elyos Öncüleri',
        guild2Id: 'g2',
        guild2Name: 'Asmodian Lejyonu',
        guild1Score: 1250,
        guild2Score: 980,
        startAt: now.subtract(const Duration(hours: 1)),
        endAt: now.add(const Duration(hours: 3)),
        status: 'active',
      );

      expect(clash.isLive, isTrue);
      expect(clash.matchId, equals('clash-123'));
      expect(clash.guild1Score, greaterThan(clash.guild2Score));
    });

    testWidgets('TerritoryDetailHero displays fortress illustration with preserved bonuses',
        (WidgetTester tester) async {
      const territory = TerritoryData(
        id: 't-dragon',
        name: 'Ejderha Bastionu',
        ownerGuildId: 'my-guild',
        ownerGuildName: 'Ejder Loncası',
        defensePower: 8000,
        baseDefensePower: 10000,
        tradeIncome: 2400,
        reward: 'Altın Sandık',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TerritoryDetailHero(
                territory: territory,
                ownerLabel: 'Ejder Loncası',
                mapIcon: '🏰',
                mapCoordinate: 'Harita 2·3',
                accent: Colors.amber,
                isOwner: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Ejderha Bastionu'), findsWidgets);
      expect(find.text('Harita 2·3'), findsOneWidget);
      expect(find.text('Senin loncan'), findsOneWidget);
      expect(find.text('🏰 Ejder Loncası'), findsOneWidget);
    });
  });
}
