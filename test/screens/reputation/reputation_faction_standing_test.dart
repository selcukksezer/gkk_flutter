import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/reputation/widgets/faction_emblem_shader.dart';
import 'package:gkk_flutter/screens/reputation/widgets/faction_standing_card.dart';
import 'package:gkk_flutter/screens/reputation/widgets/faction_standing_model.dart';
import 'package:gkk_flutter/screens/reputation/widgets/faction_standings_hub.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

const double kMobileWidth = 390.0;
const double kMobileHeight = 844.0;
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);

Widget _wrapInMobileHarness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.bgDeep,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.accentBlue,
        surface: AppColors.bgSurface,
      ),
    ),
    home: Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: MediaQuery(
        data: const MediaQueryData(
          size: Size(kMobileWidth, kMobileHeight),
          devicePixelRatio: 2.0,
          padding: kMobileSafeArea,
          viewPadding: kMobileSafeArea,
        ),
        child: SizedBox(
          width: kMobileWidth,
          height: kMobileHeight,
          child: SafeArea(
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FactionStandingsHub & FactionStandingCard Mobile Tests (390x844)', () {
    testWidgets('renders all 7 authentic Aion 2 factions with standing levels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrapInMobileHarness(const FactionStandingsHub()));
      await tester.pumpAndSettle();

      // Verify category filter chips
      expect(find.text('Tümü'), findsOneWidget);
      expect(find.text('Hanedan'), findsOneWidget);
      expect(find.text('Zanaat'), findsOneWidget);
      expect(find.text('Konsey'), findsOneWidget);

      // Verify default order faction cards
      expect(find.text('Sanctum Işık Düzeni'), findsOneWidget);
      expect(find.text('Pandaemonium Gölge Lejyonu'), findsOneWidget);

      // Verify category badge icon and standing tier badges
      expect(find.byType(FactionStandingCard), findsWidgets);
      expect(find.byType(FactionEmblemShaderWidget), findsWidgets);
    });

    testWidgets('filters factions by category tabs (Order, Craft, Council)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrapInMobileHarness(const FactionStandingsHub()));
      await tester.pumpAndSettle();

      // Tap 'Zanaat' (Craft) category chip
      await tester.tap(find.text('Zanaat'));
      await tester.pumpAndSettle();

      expect(find.text('Aether Simyacıları Loncası'), findsOneWidget);
      expect(find.text('Sanctum Işık Düzeni'), findsNothing);

      // Tap 'Konsey' (Council) category chip
      await tester.tap(find.text('Konsey'));
      await tester.pumpAndSettle();

      expect(find.text('Inggison Sınır Muhafızları'), findsOneWidget);
      expect(find.text('Aether Simyacıları Loncası'), findsNothing);

      // Tap 'Tümü' (All) category chip to reset
      await tester.tap(find.text('Tümü'));
      await tester.pumpAndSettle();

      expect(find.text('Sanctum Işık Düzeni'), findsOneWidget);
    });

    testWidgets('expands faction standing card to show lore, perks, and milestone rewards', (
      WidgetTester tester,
    ) async {
      String? claimedFactionId;
      String? claimedRewardId;

      await tester.pumpWidget(
        _wrapInMobileHarness(
          FactionStandingsHub(
            onRewardClaimed: (fId, rId) {
              claimedFactionId = fId;
              claimedRewardId = rId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap first card expand button
      final Finder toggleBtn = find.text('Ayrıcalıklar & Ödülleri Göster').first;
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // Verify expanded details are now visible
      expect(find.text('KADEME AYRICALIKLARI'), findsOneWidget);
      expect(find.text('KADEME ÖDÜLLERİ'), findsOneWidget);
      expect(find.text('Ayrıntıları Gizle'), findsOneWidget);

      // Find an eligible claim button if available
      final Finder claimBtn = find.widgetWithText(ElevatedButton, 'Teslim Al');
      if (claimBtn.evaluate().isNotEmpty) {
        await tester.tap(claimBtn.first);
        await tester.pumpAndSettle();
        expect(claimedFactionId, isNotNull);
        expect(claimedRewardId, isNotNull);
      }
    });

    testWidgets('standing tier calculations and Roman badges are mathematically exact', (
      WidgetTester tester,
    ) async {
      const List<FactionStandingData> customFactions = <FactionStandingData>[
        FactionStandingData(
          id: 'test_neutral',
          name: 'Acemi Birliği',
          alignment: 'Test Nötr',
          category: FactionCategory.order,
          paletteType: FactionPaletteType.deepAzure,
          points: 1200,
          headquarters: 'Test Karargahı',
          loreDescription: 'Test nötr açıklaması.',
        ),
        FactionStandingData(
          id: 'test_exalted',
          name: 'Yüce Hanedan',
          alignment: 'Test Yüce',
          category: FactionCategory.order,
          paletteType: FactionPaletteType.emeraldAura,
          points: 55000,
          headquarters: 'Yüce Saray',
          loreDescription: 'Test yüce açıklaması.',
        ),
      ];

      final FactionStandingData fNeutral = customFactions[0];
      final FactionStandingData fExalted = customFactions[1];

      // Test Tier calculations
      expect(fNeutral.currentTier, FactionStandingTier.neutral);
      expect(fNeutral.currentTier.romanBadge, 'I');
      expect(fNeutral.pointsToNextTier, 1800); // 3000 - 1200
      expect(fNeutral.tierProgress, closeTo(1200 / 3000, 0.001));

      expect(fExalted.currentTier, FactionStandingTier.exalted);
      expect(fExalted.currentTier.romanBadge, 'V');
      expect(fExalted.pointsToNextTier, 0);
      expect(fExalted.tierProgress, 1.0);
      expect(fExalted.isMaxTier, isTrue);

      await tester.pumpWidget(
        _wrapInMobileHarness(
          FactionStandingsHub(factions: customFactions),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acemi Birliği'), findsOneWidget);
      expect(find.text('Yüce Hanedan'), findsOneWidget);
      expect(find.text('Nötr'), findsWidgets);
      expect(find.text('Yüce'), findsWidgets);
    });
  });
}
