import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/guild_war_model.dart';
import 'package:gkk_flutter/screens/guild_war/widgets/fortress_siege_illustration.dart';
import 'package:gkk_flutter/screens/guild_war/widgets/territory_map_view.dart';

void main() {
  final testTerritories = <TerritoryData>[
    const TerritoryData(
      id: 't-1',
      name: 'Uçurum Bastionu',
      ownerGuildId: 'guild-player',
      ownerGuildName: 'Ejder Sancak',
      defensePower: 7500,
      baseDefensePower: 10000,
      minDefenseGems: 10,
      tradeIncome: 2400,
      reward: '500 elmas',
    ),
    const TerritoryData(
      id: 't-2',
      name: 'Merkez Mabedi',
      ownerGuildId: 'guild-enemy',
      ownerGuildName: 'Gölge Tarikatı',
      defensePower: 10000,
      baseDefensePower: 10000,
      minDefenseGems: 15,
      tradeIncome: 4800,
      reward: '1000 elmas',
    ),
    const TerritoryData(
      id: 't-3',
      name: 'Batık Geçit',
      ownerGuildId: null,
      ownerGuildName: null,
      defensePower: 5000,
      baseDefensePower: 5000,
      minDefenseGems: 5,
      tradeIncome: 1200,
      reward: '250 elmas',
    ),
  ];

  group('Guild War Tactical Map & Territory View Tests', () {
    testWidgets('Renders Continent Tactical Map, nodes, and FortressSiegeIllustration drawer',
        (WidgetTester tester) async {
      TerritoryData? tappedTerritory;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TerritoryMapView(
                territories: testTerritories,
                playerGuildId: 'guild-player',
                onTerritoryTap: (t) => tappedTerritory = t,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Header and Clash Banner
      expect(find.text('Kuşatma Haritası'), findsOneWidget);
      expect(find.text('ELYOS'), findsOneWidget);
      expect(find.text('ASMODIAN'), findsOneWidget);

      // 2. Verify Tactical Map Canvas is present
      expect(find.byType(CustomPaint), findsWidgets);

      // 3. Verify Detail Drawer shows selected territory with FortressSiegeIllustration
      expect(find.byType(FortressSiegeIllustration), findsWidgets);
      expect(find.text('Uçurum Bastionu'), findsWidgets);
      expect(find.text('Loncan'), findsWidgets);

      // 4. Tap the Action Button in the drawer ('Yönet')
      await tester.tap(find.text('Yönet'));
      expect(tappedTerritory?.id, equals('t-1'));
    });

    testWidgets('Switches to Card Grid mode and renders mini illustrations',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TerritoryMapView(
                territories: testTerritories,
                playerGuildId: 'guild-player',
                onTerritoryTap: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Tap 'Kartlar' tab
      await tester.tap(find.text('Kartlar'));
      await tester.pumpAndSettle();

      // In card mode, each card has its fortress illustration thumbnail
      expect(find.byType(FortressSiegeIllustration), findsNWidgets(3));
      expect(find.text('Merkez Mabedi'), findsOneWidget);
      expect(find.text('Batık Geçit'), findsOneWidget);
    });
  });
}
