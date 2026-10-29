import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/kingdom/kingdom_components.dart';
import 'package:gkk_flutter/models/kingdom_market_blessing_model.dart';
import 'package:gkk_flutter/providers/kingdom_market_blessing_provider.dart';

void main() {
  group('KingdomGlassCard Widget Tests', () {
    testWidgets('renders child content with glass styling and handles tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KingdomGlassCard(
              onTap: () => tapped = true,
              child: const Text('Glass Content'),
            ),
          ),
        ),
      );

      expect(find.text('Glass Content'), findsOneWidget);
      await tester.tap(find.text('Glass Content'));
      expect(tapped, isTrue);
    });
  });

  group('KingdomCrestIcon Widget Tests', () {
    testWidgets('renders all crest types without errors', (tester) async {
      for (final type in KingdomCrestType.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KingdomCrestIcon(
                type: type,
                size: 64,
                showGlow: true,
                badgeText: 'LV.5',
              ),
            ),
          ),
        );

        expect(find.byType(KingdomCrestIcon), findsOneWidget);
        expect(find.text('LV.5'), findsOneWidget);
      }
    });

    testWidgets('animates pulsing when animatedPulse is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KingdomCrestIcon(
              type: KingdomCrestType.blessing,
              animatedPulse: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(KingdomCrestIcon), findsOneWidget);
    });
  });

  group('KingdomMarketBlessingBanner Widget Tests', () {
    testWidgets('renders SizedBox.shrink when blessing is inactive', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            kingdomMarketBlessingProvider.overrideWith(
              () => _FakeBlessingNotifier(
                KingdomMarketBlessingStatus.inactive(),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: KingdomMarketBlessingBanner(),
            ),
          ),
        ),
      );

      expect(find.text('KRAL İNDİRİMİ'), findsNothing);
    });

    testWidgets('renders active banner with discounts and timer', (tester) async {
      final activeStatus = KingdomMarketBlessingStatus(
        active: true,
        goldDiscountPct: 20,
        gemDiscountPct: 10,
        startedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 25)),
        activatedByUsername: 'KralArthur',
        activatedByGuildName: 'Camelot',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            kingdomMarketBlessingProvider.overrideWith(
              () => _FakeBlessingNotifier(activeStatus),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: KingdomMarketBlessingBanner(
                locationLabel: 'Pazar Alanı',
              ),
            ),
          ),
        ),
      );

      expect(find.text('KRAL İNDİRİMİ'), findsOneWidget);
      expect(find.text('Altın -%20'), findsOneWidget);
      expect(find.text('Elmas -%10'), findsOneWidget);
      expect(find.text('Camelot · KralArthur'), findsOneWidget);
      expect(find.byType(KingdomCrestIcon), findsOneWidget);
    });
  });

  group('Kingdom Bento Overview Cards Tests', () {
    testWidgets('KingdomTerritoryCard displays info and callbacks', (tester) async {
      bool manageClicked = false;
      bool mapClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KingdomTerritoryCard(
              realmName: 'Solaria Realm',
              controlledProvinces: 8,
              totalProvinces: 10,
              defenseLevel: 5,
              taxYieldMultiplier: 1.5,
              onManage: () => manageClicked = true,
              onViewMap: () => mapClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Solaria Realm'), findsOneWidget);
      expect(find.text('Bölge Kontrolü: 8 / 10 Eyalet'), findsOneWidget);
      expect(find.text('Kademe 5'), findsOneWidget);
      expect(find.text('x1.50'), findsOneWidget);

      await tester.tap(find.text('Haritayı Aç'));
      expect(mapClicked, isTrue);

      await tester.tap(find.text('Eyaleti Yönet'));
      expect(manageClicked, isTrue);
    });

    testWidgets('KingdomTreasuryCard displays formatted balances and gift action', (tester) async {
      bool giftClicked = false;
      bool ledgerClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KingdomTreasuryCard(
              goldBalance: 2500000,
              gemBalance: 12500,
              dailyTaxRevenue: 150000,
              isKing: true,
              canGift: true,
              onGiftSend: () => giftClicked = true,
              onViewLedger: () => ledgerClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('KRALİYET HAZİNESİ'), findsOneWidget);
      expect(find.text('2.500.000 🪙'), findsOneWidget);
      expect(find.text('12.500 💎'), findsOneWidget);
      expect(find.text('KASA YETKİLİSİ'), findsOneWidget);

      await tester.tap(find.text('Kasa Defteri'));
      expect(ledgerClicked, isTrue);

      await tester.tap(find.text('Hediye Gönder'));
      expect(giftClicked, isTrue);
    });

    testWidgets('KingdomArmyCard displays legion stats and inspect callback', (tester) async {
      bool inspectClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KingdomArmyCard(
              legionName: 'Astra Muhafızları',
              activeSoldiers: 15000,
              readinessRating: 98,
              warDefenseBonusPct: 20,
              onInspect: () => inspectClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Astra Muhafızları'), findsOneWidget);
      expect(find.text('Aktif Lejyon: 15.000 Savaşçı'), findsOneWidget);
      expect(find.text('%98'), findsOneWidget);
      expect(find.text('+20%'), findsOneWidget);

      await tester.tap(find.text('Garnizonu Teftiş Et'));
      expect(inspectClicked, isTrue);
    });

    testWidgets('KingdomDiplomacyCard displays monarch and voting', (tester) async {
      bool voteClicked = false;
      bool councilClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KingdomDiplomacyCard(
              kingName: 'Lord Valerius',
              guildName: 'Güneş Şövalyeleri',
              month: 'Aralık 2026',
              isElectionActive: true,
              countdownLabel: '3g 12sa kaldı',
              canVote: true,
              alreadyVoted: false,
              onVote: () => voteClicked = true,
              onViewCouncil: () => councilClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('KRALLIK SEÇİMİ'), findsOneWidget);
      expect(find.text('Lord Valerius'), findsOneWidget);
      expect(find.text('Hükümran Lonca: Güneş Şövalyeleri'), findsOneWidget);
      expect(find.text('3g 12sa kaldı'), findsOneWidget);

      await tester.tap(find.text('Meclis Kaydı'));
      expect(councilClicked, isTrue);

      await tester.tap(find.text('Oy Kullan'));
      expect(voteClicked, isTrue);
    });
  });

  group('KingdomRealmHeader Mobile Responsive Tests', () {
    testWidgets('renders header with custom artwork on 390x844 mobile viewport', (tester) async {
      tester.view.physicalSize = const Size(390 * 3.0, 844 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool headerClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: KingdomRealmHeader(
                realmTitle: 'Aethelgard Hükümranlığı',
                reigningKing: 'Kral Aethel',
                reigningGuild: 'Ejderha Süvarileri',
                dominionLevel: 15,
                activeBlessingSummary: 'Kral İndirimi %20',
                onTapHeader: () => headerClicked = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Aethelgard Hükümranlığı'), findsOneWidget);
      expect(find.text('HÂKİMİYET LV.15'), findsOneWidget);
      expect(find.text('Kral İndirimi %20'), findsOneWidget);
      expect(find.text('Kral Aethel'), findsOneWidget);

      await tester.tap(find.text('Aethelgard Hükümranlığı'));
      expect(headerClicked, isTrue);
    });
  });
}

class _FakeBlessingNotifier extends KingdomMarketBlessingNotifier {
  _FakeBlessingNotifier(this._initialState);

  final KingdomMarketBlessingStatus _initialState;

  @override
  KingdomMarketBlessingStatus build() => _initialState;

  @override
  Future<void> load() async {}
}
