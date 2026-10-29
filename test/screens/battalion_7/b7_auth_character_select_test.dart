import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/auth/character_select_screen.dart';
import 'package:gkk_flutter/screens/auth/widgets/aion_luxury_button.dart';
import 'package:gkk_flutter/screens/auth/widgets/character_elemental_aura.dart';
import 'package:gkk_flutter/screens/auth/widgets/character_slot_selector.dart';
import 'package:gkk_flutter/screens/auth/widgets/character_stats_badge.dart';

Widget _buildTestApp({
  required Widget child,
  Size size = const Size(390, 844),
  EdgeInsets padding = const EdgeInsets.only(top: 47, bottom: 34),
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07080B),
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: padding,
          viewPadding: padding,
          devicePixelRatio: 3.0,
        ),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CharacterSelectScreen Aion-2 Modernization', () {
    testWidgets('renders realm header, slot selector, default warrior, and luxury CTA on 390x844', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const CharacterSelectScreen(),
          size: const Size(390, 844),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Realm and status
      expect(find.text('REALM: ELYSEA-01 // ONLINE'), findsOneWidget);
      expect(find.text('İGNİS'), findsWidgets);

      // Character Slot Selector
      expect(find.byType(CharacterSlotSelector), findsOneWidget);
      expect(find.text('Yuva I'), findsOneWidget);
      expect(find.text('Yuva II'), findsOneWidget);
      expect(find.text('Yuva III'), findsOneWidget);

      // Default active class: Savaşçı
      expect(find.text('SAVAŞÇI'), findsWidgets);
      expect(find.text('Frontline Dominator'), findsOneWidget);

      // Character Stats Badge with animated attributes
      expect(find.byType(CharacterStatsBadge), findsOneWidget);
      expect(find.text('GÜÇ'), findsOneWidget);
      expect(find.text('SAVUNMA'), findsOneWidget);
      expect(find.text('ÇEVİKLİK'), findsOneWidget);
      expect(find.text('ETER'), findsOneWidget);
      expect(find.text('1480 CP'), findsOneWidget);

      // Aion Luxury CTA Button
      expect(find.byType(AionLuxuryButton), findsOneWidget);
      expect(find.text('DÜNYAYA ADIM AT'), findsOneWidget);

      // Elemental aura painter should be active in preview stage
      expect(find.byType(CharacterElementalAura), findsOneWidget);
    });

    testWidgets('switching class updates elemental aura, insignia and stats', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const CharacterSelectScreen(),
          size: const Size(390, 844),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Simyacı in the carousel
      final Finder alchemistCard = find.text('Simyacı');
      expect(alchemistCard, findsOneWidget);
      await tester.tap(alchemistCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Now Simyacı should be active
      expect(find.text('SİMYACI'), findsWidgets);
      expect(find.text('Arcane Field Engineer'), findsOneWidget);
      expect(find.text('1420 CP'), findsOneWidget);
      expect(find.text('ETER'), findsWidgets);

      // Tap Gölge in the carousel
      final Finder shadowCard = find.text('Gölge');
      expect(shadowCard, findsOneWidget);
      await tester.tap(shadowCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Now Gölge should be active
      expect(find.text('GÖLGE'), findsWidgets);
      expect(find.text('Precision Elimination'), findsOneWidget);
      expect(find.text('1530 CP'), findsOneWidget);
      expect(find.text('Hiçlik'), findsWidgets);
    });

    testWidgets('slot selector switches slot and notifies on locked slot', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const CharacterSelectScreen(),
          size: const Size(390, 844),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Slot II
      await tester.tap(find.text('Yuva II'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Tap Slot III (Locked)
      await tester.tap(find.text('Yuva III'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // SnackBar with requirement appears
      expect(find.text('Yuva III Seviye 50 veya VIP üyelik gerektirir.'), findsOneWidget);
    });

    testWidgets('renders cleanly without overflow on compact mobile (360x640)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const CharacterSelectScreen(),
          size: const Size(360, 640),
          padding: const EdgeInsets.only(top: 24, bottom: 12),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(CharacterSelectScreen), findsOneWidget);
      expect(find.byType(AionLuxuryButton), findsOneWidget);
    });

    testWidgets('renders cleanly without overflow on large mobile (412x915)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const CharacterSelectScreen(),
          size: const Size(412, 915),
          padding: const EdgeInsets.only(top: 36, bottom: 20),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(CharacterSelectScreen), findsOneWidget);
      expect(find.byType(AionLuxuryButton), findsOneWidget);
    });
  });

  group('AionLuxuryButton Interactive Widget Test', () {
    testWidgets('triggers tap and reflects enabled state', (
      WidgetTester tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AionLuxuryButton(
                label: 'Dünyaya Adım At',
                subtitle: 'Aion-2 Realm',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('DÜNYAYA ADIM AT'), findsOneWidget);
      expect(find.text('Aion-2 Realm'), findsOneWidget);

      await tester.tap(find.byType(AionLuxuryButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('shows loading state when isLoading is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AionLuxuryButton(
                label: 'Dünyaya Adım At',
                subtitle: 'Aion-2 Realm',
                isLoading: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Aion Realm Bağlanıyor...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
