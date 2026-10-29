import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/hospital/widgets/hospital_aura_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hospital Divine Sanctuary Healing Aura Tests', () {
    test('SanctuaryAuraConfig copyWith preserves and overrides values', () {
      const SanctuaryAuraConfig config = SanctuaryAuraConfig(
        coreRadius: 30.0,
        outerRadius: 150.0,
        rayCount: 16,
        bloomIntensity: 1.0,
      );

      final SanctuaryAuraConfig updated = config.copyWith(
        bloomIntensity: 1.5,
        isHealingSurge: true,
        rayRotation: 1.25,
      );

      expect(updated.coreRadius, 30.0);
      expect(updated.outerRadius, 150.0);
      expect(updated.bloomIntensity, 1.5);
      expect(updated.isHealingSurge, isTrue);
      expect(updated.rayRotation, 1.25);
      expect(updated.showAltarCross, isTrue);
    });

    test('HospitalAuraPainter shouldRepaint triggers correctly on changes', () {
      const SanctuaryAuraConfig c1 = SanctuaryAuraConfig(rayRotation: 0.0);
      const SanctuaryAuraConfig c2 = SanctuaryAuraConfig(rayRotation: 0.1);
      const SanctuaryAuraConfig c3 = SanctuaryAuraConfig(rayRotation: 0.0);

      const HospitalAuraPainter p1 = HospitalAuraPainter(config: c1);
      const HospitalAuraPainter p2 = HospitalAuraPainter(config: c2);
      const HospitalAuraPainter p3 = HospitalAuraPainter(config: c3);

      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p3), isFalse);
    });

    testWidgets('HospitalAuraWidget renders without errors and animates', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HospitalAuraWidget(
                size: 200,
                isHealing: false,
                showAltarCross: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(HospitalAuraWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(tester.takeException(), isNull);
    });

    testWidgets('HospitalAuraWidget dynamically handles isHealing toggle', (
      WidgetTester tester,
    ) async {
      bool isHealing = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: <Widget>[
                    HospitalAuraWidget(
                      size: 150,
                      isHealing: isHealing,
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => isHealing = true),
                      child: const Text('Heal'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Heal'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Heal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('HospitalAltarHeader displays sanctuary state in hospital mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HospitalAltarHeader(
              inHospital: true,
              isHealing: false,
              remainingCountdown: '04:12',
              energyRatio: '⚡ 85/100',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('SANCTUARY'), findsOneWidget);
      expect(find.text('Kutsal Şifa Mabedi'), findsOneWidget);
      expect(find.text('Kalan İyileşme: 04:12'), findsOneWidget);
      expect(find.text('⚡ 85/100'), findsOneWidget);
      expect(find.byType(HospitalAuraWidget), findsWidgets);
    });

    testWidgets('HospitalAltarHeader displays blessed state when healthy', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HospitalAltarHeader(
              inHospital: false,
              isHealing: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('BLESSED'), findsOneWidget);
      expect(find.text('İlahi Koruma Altındasın'), findsOneWidget);
      expect(find.text('Tüm yaraların sarıldı, hayat gücün dorukta.'), findsOneWidget);
      expect(find.byType(HospitalAuraWidget), findsWidgets);
    });

    testWidgets('HospitalSanctuaryBackdrop renders as background layer without blocking touches', (
      WidgetTester tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                const HospitalSanctuaryBackdrop(isHealing: false),
                Center(
                  child: ElevatedButton(
                    onPressed: () => tapped = true,
                    child: const Text('Touch Me'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(HospitalSanctuaryBackdrop), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HospitalSanctuaryBackdrop),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Touch Me'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
