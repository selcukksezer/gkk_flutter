import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/enhancement/enhancement_design.dart';

void main() {
  group('Aion 2 Divine Forge - RiskMeterGauge Tests', () {
    testWidgets('displays Safe Zone (+0..+3) with 100% success and zero risk', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RiskMeterGauge(
                successChance: 100,
                currentLevel: 2,
              ),
            ),
          ),
        ),
      );

      expect(find.text('%100'), findsOneWidget);
      expect(find.text('GÜVENLİ BÖLGE'), findsOneWidget);
      expect(find.text('BAŞARI'), findsOneWidget);
      expect(find.text('DÜŞME'), findsOneWidget);
      expect(find.text('%0'), findsNWidgets(2)); // Düşme %0, Kırılma %0
      expect(find.text('KIRILMA'), findsOneWidget);
    });

    testWidgets('displays Downgrade Risk Zone (+4..+5) with 70% success and 30% drop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RiskMeterGauge(
                successChance: 70,
                currentLevel: 4,
              ),
            ),
          ),
        ),
      );

      expect(find.text('%70'), findsNWidgets(2)); // Big central %70 + small pill %70
      expect(find.text('SEVİYE DÜŞME RİSKİ'), findsOneWidget);
      expect(find.text('%30'), findsOneWidget); // Düşme %30
      expect(find.text('%0'), findsOneWidget); // Kırılma %0
    });

    testWidgets('displays Catastrophic Break Zone (+6..+10) with item destruction risk', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RiskMeterGauge(
                successChance: 35,
                currentLevel: 7,
              ),
            ),
          ),
        ),
      );

      expect(find.text('%35'), findsNWidgets(2)); // Central %35 + breakdown pill %35
      expect(find.text('YOK OLMA TEHLİKESİ'), findsOneWidget);
      expect(find.text('%65'), findsOneWidget); // Kırılma %65
      expect(find.text('%0'), findsOneWidget); // Düşme %0 (tamamen kırılır)
    });
  });

  group('Aion 2 Divine Forge - AionForgePedestal Tests', () {
    testWidgets('renders empty pedestal state with selection prompt', (
      WidgetTester tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AionForgePedestal(
                rotation: 0.25,
                pulse: 0.5,
                onTap: () => tapped = true,
                child: null,
              ),
            ),
          ),
        ),
      );

      expect(find.text('EŞYA SEÇ'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);

      await tester.tap(find.text('EŞYA SEÇ'));
      expect(tapped, isTrue);
    });

    testWidgets('renders equipped artifact with level badge and clear action', (
      WidgetTester tester,
    ) async {
      bool cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AionForgePedestal(
                rotation: 0.5,
                pulse: 0.8,
                badgeText: '+8',
                badgeColor: AionForgeTokens.celestialGold,
                onClear: () => cleared = true,
                child: const Text('Kılıç İlahı'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Kılıç İlahı'), findsOneWidget);
      expect(find.text('+8'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      expect(cleared, isTrue);
    });
  });

  group('Aion 2 Divine Forge - ForgeSlotContainer Tests', () {
    testWidgets('renders slot container with custom key, badge, and interaction', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      bool cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ForgeSlotContainer(
                slotKey: const Key('enhancement_scroll_slot'),
                label: 'Geliştirme Taşı',
                icon: Icons.auto_awesome,
                badgeText: 'x5',
                onTap: () => tapped = true,
                onClear: () => cleared = true,
                child: const Text('Parşömen'),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('enhancement_scroll_slot')), findsOneWidget);
      expect(find.text('Geliştirme Taşı'), findsOneWidget);
      expect(find.text('Parşömen'), findsOneWidget);
      expect(find.text('x5'), findsOneWidget);

      await tester.tap(find.byKey(const Key('enhancement_scroll_slot')));
      expect(tapped, isTrue);

      await tester.tap(find.byIcon(Icons.close));
      expect(cleared, isTrue);
    });
  });

  group('Aion 2 Divine Forge - DivineForgeStrikeButton Tests', () {
    testWidgets('triggers strike action on tap and displays cost', (
      WidgetTester tester,
    ) async {
      bool triggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DivineForgeStrikeButton(
                label: 'İLAHÎ ÇEKİÇ VUR',
                costText: 'Maliyet: 7.5M Altın',
                enabled: true,
                onTrigger: () => triggered = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('İLAHÎ ÇEKİÇ VUR'), findsOneWidget);
      expect(find.text('Maliyet: 7.5M Altın'), findsOneWidget);
      expect(find.byIcon(Icons.auto_fix_high_rounded), findsOneWidget);

      await tester.tap(find.byType(DivineForgeStrikeButton));
      expect(triggered, isTrue);
    });

    testWidgets('shows loading state when forging is in progress', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: DivineForgeStrikeButton(
                label: 'İLAHÎ ÇEKİÇ VUR',
                loading: true,
                onTrigger: null,
              ),
            ),
          ),
        ),
      );

      expect(find.text('GÜÇLENDİRİLİYOR...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
