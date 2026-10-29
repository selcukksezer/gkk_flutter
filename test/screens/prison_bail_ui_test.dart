import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/prison/widgets/prison_bail_panel.dart';

void main() {
  group('PrisonSentenceDurationCard Tests', () {
    testWidgets('renders sentence countdown, release label and reason correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrisonSentenceDurationCard(
              countdown: '00:45:12',
              releaseLabel: '22:45',
              progress: 0.65,
              reasonLabel: 'Gerekçe:',
              reasonValue: 'Krallık Kanun İhlali',
              remainingDuration: Duration(minutes: 45, seconds: 12),
              statusChip: 'Elmas Yetersiz',
            ),
          ),
        ),
      );

      expect(find.text('ZİNDAN CEZASI'), findsOneWidget);
      expect(find.text('00:45:12'), findsOneWidget);
      expect(find.text('Gerekçe: Krallık Kanun İhlali'), findsOneWidget);
      expect(find.text('Tahmini Tahliye: 22:45'), findsOneWidget);
      expect(find.text('%65 Tamamlandı'), findsOneWidget);
      expect(find.text('Elmas Yetersiz'), findsOneWidget);
    });

    testWidgets('clamps progress properly at extremes', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrisonSentenceDurationCard(
              countdown: '00:00:00',
              releaseLabel: '00:00',
              progress: 1.5,
              reasonLabel: 'Gerekçe:',
              reasonValue: 'Kafes',
              remainingDuration: Duration.zero,
            ),
          ),
        ),
      );

      expect(find.text('%100 Tamamlandı'), findsOneWidget);
    });
  });

  group('PrisonBailActionCard Tests', () {
    testWidgets('displays affordable state when player has sufficient gems', (WidgetTester tester) async {
      bool bailPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrisonBailActionCard(
              bailCost: 50,
              playerGems: 120,
              loading: false,
              onPayBail: () => bailPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Kefalet ile Erken Tahliye'), findsOneWidget);
      expect(find.text('Mevcut Kasa: 120 Elmas'), findsOneWidget);
      expect(find.text('Ödenebilir'), findsOneWidget);
      expect(find.text('Kefalet Öde (50 Elmas)'), findsOneWidget);

      await tester.tap(find.text('Kefalet Öde (50 Elmas)'));
      await tester.pump();

      expect(bailPressed, isTrue);
    });

    testWidgets('displays insufficient state and disables button when player lacks gems', (WidgetTester tester) async {
      bool bailPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrisonBailActionCard(
              bailCost: 100,
              playerGems: 15.5,
              loading: false,
              onPayBail: () => bailPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Mevcut Kasa: 15 Elmas'), findsOneWidget);
      expect(find.text('Yetersiz'), findsOneWidget);
      expect(find.text('Elmas Satın Al → Dükkana Git'), findsOneWidget);

      final ElevatedButton button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('displays progress indicator when loading', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrisonBailActionCard(
              bailCost: 50,
              playerGems: 120,
              loading: true,
              onPayBail: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final ElevatedButton button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });
  });

  group('PrisonLaborActionTile Tests', () {
    testWidgets('renders title, subtitle, badge and triggers tap callback', (WidgetTester tester) async {
      bool tileTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrisonLaborActionTile(
              title: 'Gardiyan İkna',
              subtitle: '25000 Altın',
              icon: Icons.handshake_outlined,
              accent: Colors.amber,
              badge: 'Altın',
              onTap: () => tileTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Gardiyan İkna'), findsOneWidget);
      expect(find.text('25000 Altın'), findsOneWidget);
      expect(find.text('Altın'), findsOneWidget);
      expect(find.byIcon(Icons.handshake_outlined), findsOneWidget);

      await tester.tap(find.text('Gardiyan İkna'));
      await tester.pump();

      expect(tileTapped, isTrue);
    });

    testWidgets('shows linear progress bar when loading', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrisonLaborActionTile(
              title: 'Zindan Firarı',
              subtitle: 'Risk (+15dk)',
              icon: Icons.directions_run_rounded,
              accent: Colors.red,
              loading: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('PrisonFreeStatusCard Tests', () {
    testWidgets('renders free amnesty status accurately', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrisonFreeStatusCard(),
          ),
        ),
      );

      expect(find.text('ZİNDAN KAPILARI AÇIK'), findsOneWidget);
      expect(find.text('Özgürsün'), findsOneWidget);
      expect(find.text('🕊️'), findsOneWidget);
    });
  });

  group('PrisonGothicDialog Tests', () {
    testWidgets('showBailConfirm returns true when confirmed', (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await PrisonGothicDialog.showBailConfirm(
                    context,
                    bailCost: 40,
                    playerGems: 100,
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Kefalet İle Tahliye'), findsOneWidget);
      expect(find.text('Kalan Kasa:'), findsOneWidget);
      expect(find.text('60 💎'), findsOneWidget);

      await tester.tap(find.text('Kefaleti Öde'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('showBailConfirm returns false when cancelled', (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await PrisonGothicDialog.showBailConfirm(
                    context,
                    bailCost: 40,
                    playerGems: 100,
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hücrede Kal'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('showInsufficientGems renders warning and dismisses on Kapat', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () async {
                  await PrisonGothicDialog.showInsufficientGems(
                    context,
                    bailCost: 80,
                    playerGems: 25.0,
                  );
                },
                child: const Text('Open Insufficient'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Insufficient'));
      await tester.pumpAndSettle();

      expect(find.text('Yetersiz Elmas'), findsOneWidget);
      expect(find.text('Kefalet bedeli 80 💎 gerektiriyor.\nMevcut kasanızda yalnızca 25 💎 var.'), findsOneWidget);

      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();

      expect(find.text('Yetersiz Elmas'), findsNothing);
    });
  });
}
