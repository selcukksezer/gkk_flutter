import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/pvp/widgets/gladiator_tier_emblem.dart';
import 'package:gkk_flutter/screens/pvp/widgets/pvp_versus_splash_banner.dart';
import 'package:gkk_flutter/screens/pvp/widgets/pvp_colosseum_backdrop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gladiator Tier Model & Rating Bracket Tests', () {
    test('GladiatorTier.fromRating correctly resolves all 7 MMR brackets', () {
      expect(GladiatorTier.fromRating(850), GladiatorTier.bronze);
      expect(GladiatorTier.fromRating(1099), GladiatorTier.bronze);
      expect(GladiatorTier.fromRating(1100), GladiatorTier.silver);
      expect(GladiatorTier.fromRating(1299), GladiatorTier.silver);
      expect(GladiatorTier.fromRating(1300), GladiatorTier.gold);
      expect(GladiatorTier.fromRating(1499), GladiatorTier.gold);
      expect(GladiatorTier.fromRating(1500), GladiatorTier.platinum);
      expect(GladiatorTier.fromRating(1699), GladiatorTier.platinum);
      expect(GladiatorTier.fromRating(1700), GladiatorTier.diamond);
      expect(GladiatorTier.fromRating(1899), GladiatorTier.diamond);
      expect(GladiatorTier.fromRating(1900), GladiatorTier.master);
      expect(GladiatorTier.fromRating(2099), GladiatorTier.master);
      expect(GladiatorTier.fromRating(2100), GladiatorTier.grandmaster);
      expect(GladiatorTier.fromRating(2850), GladiatorTier.grandmaster);
    });

    test('GladiatorTier metadata has consistent codes and titles', () {
      for (final GladiatorTier tier in GladiatorTier.values) {
        expect(tier.title, isNotEmpty);
        expect(tier.shortCode, isNotEmpty);
        expect(tier.minRating, greaterThanOrEqualTo(0));
        expect(tier.maxRating, greaterThan(tier.minRating));
        expect(tier.primaryColor, isNotNull);
        expect(tier.secondaryColor, isNotNull);
        expect(tier.glowColor, isNotNull);
      }
    });
  });

  group('GladiatorTierEmblem UI Tests', () {
    testWidgets('Renders emblem across all tiers with CustomPaint', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: GladiatorTier.values
                    .map((GladiatorTier t) => GladiatorTierEmblem(
                          tier: t,
                          size: 40,
                          showLabel: true,
                          animated: false,
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(GladiatorTierEmblem), findsNWidgets(7));
      expect(find.text('Bronz Gladyatör'), findsOneWidget);
      expect(find.text('Altın Gladyatör'), findsOneWidget);
      expect(find.text('Abyssal Grandmaster'), findsOneWidget);
    });

    testWidgets('GladiatorTierProgressCard calculates progress and triggers callback', (
      WidgetTester tester,
    ) async {
      bool leaderboardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GladiatorTierProgressCard(
              rating: 1350,
              pvpWins: 24,
              pvpLosses: 8,
              onViewLeaderboard: () => leaderboardTapped = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Altın Gladyatör'), findsOneWidget);
      expect(find.text('1350 MMR'), findsOneWidget);
      expect(find.text('GOLD'), findsOneWidget);
      expect(find.text('Sonraki Aşama: +150 MMR'), findsOneWidget);
      expect(find.textContaining('Kazanma: %75.0 (24 G / 8 M)'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.leaderboard_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      expect(leaderboardTapped, isTrue);
    });
  });

  group('PvpVersusSplashBanner Mobile Viewport Tests', () {
    testWidgets('Renders full versus match intro banner on 390x844 mobile screen', (
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
            body: PvpVersusSplashBanner(
              challengerName: 'KaranlıkGladyatör',
              challengerRating: 1650,
              challengerPower: 3200,
              challengerLevel: 42,
              defenderName: 'IşıkŞövalyesi',
              defenderRating: 1580,
              defenderPower: 3100,
              defenderLevel: 40,
              arenaTitle: 'Uçurum Gladyatör Koloseumu',
              wager: 1000,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('KaranlıkGladyatör'), findsOneWidget);
      expect(find.text('IşıkŞövalyesi'), findsOneWidget);
      expect(find.text('1650 MMR'), findsOneWidget);
      expect(find.text('1580 MMR'), findsOneWidget);
      expect(find.text('1000 Altın Bahis'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
      expect(find.text('Uçurum Gladyatör Koloseumu'), findsOneWidget);
    });

    testWidgets('Renders compact versus splash banner on small screen (360x640)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PvpVersusSplashBanner(
              challengerName: 'Ben',
              challengerRating: 1200,
              defenderName: 'Rakip',
              defenderRating: 1180,
              compact: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('VS'), findsOneWidget);
      expect(find.text('Dostluk Maçı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PvpColosseumBackdrop & Card Illustration Tests', () {
    testWidgets('PvpColosseumBackdrop renders all theme moods without error', (
      WidgetTester tester,
    ) async {
      for (final ColosseumThemeMood mood in ColosseumThemeMood.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PvpColosseumBackdrop(
                mood: mood,
                child: const Text('Arena Content'),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('Arena Content'), findsOneWidget);
      }
    });

    testWidgets('ColosseumCardIllustration renders with tap action', (
      WidgetTester tester,
    ) async {
      bool cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColosseumCardIllustration(
              title: 'Uçurum Gladyatör Koloseumu',
              subtitle: 'Ölüm maçı · Çift rep çarpanı',
              mood: ColosseumThemeMood.abyssCrimson,
              onTap: () => cardTapped = true,
              trailing: const Text('GİR'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Uçurum Gladyatör Koloseumu'), findsOneWidget);
      expect(find.text('Ölüm maçı · Çift rep çarpanı'), findsOneWidget);
      expect(find.text('GİR'), findsOneWidget);

      await tester.tap(find.text('GİR'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(cardTapped, isTrue);
    });
  });
}
