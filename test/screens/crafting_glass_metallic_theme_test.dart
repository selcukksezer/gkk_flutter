import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/crafting/widgets/aion_glass_metallic.dart';
import 'package:gkk_flutter/screens/inventory/widgets/aion_rarity_glow.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

void main() {
  Widget buildTestScaffold({
    required Widget child,
    Size surfaceSize = const Size(390, 844),
  }) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: SafeArea(
          child: SizedBox(
            width: surfaceSize.width,
            height: surfaceSize.height,
            child: child,
          ),
        ),
      ),
    );
  }

  group('AionGlassPanel Widget Tests', () {
    testWidgets('renders child content inside frosted glass container', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(
          child: const AionGlassPanel(
            child: Text('Glass Panel Content', style: TextStyle(color: Colors.white)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Glass Panel Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('respects custom blur, padding, margin, and glow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(
          child: AionGlassPanel(
            blur: 16.0,
            opacity: 0.85,
            glowColor: AppColors.liquidGold,
            glowBlurRadius: 12.0,
            glowSpreadRadius: 1.0,
            padding: const EdgeInsets.all(20.0),
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              height: 100,
              color: Colors.blue.withValues(alpha: 0.2),
              child: const Text('Customized Glass'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Customized Glass'), findsOneWidget);
      final BackdropFilter backdrop = tester.widget(find.byType(BackdropFilter));
      expect(backdrop.filter != null, isTrue);
    });

    testWidgets('renders cleanly on 390x844 responsive mobile viewport with zero overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestScaffold(
          surfaceSize: const Size(390, 844),
          child: AionGlassPanel(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Header Text', style: TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Container(height: 120, color: Colors.white10),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Header Text'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('OrnateMetallicBorder Widget Tests', () {
    testWidgets('renders child enclosed in metallic border with filigree and corner runes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(
          child: const OrnateMetallicBorder(
            theme: MetallicTheme.agedGold,
            showCornerRunes: true,
            showFiligreeCrests: true,
            child: SizedBox(
              width: 140,
              height: 140,
              child: Center(
                child: Text('Metallic Frame', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Metallic Frame'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders various metallic themes and glow aura without error', (
      WidgetTester tester,
    ) async {
      for (final MetallicTheme theme in MetallicTheme.values) {
        await tester.pumpWidget(
          buildTestScaffold(
            child: OrnateMetallicBorder(
              theme: theme,
              glowAura: true,
              borderWidth: 2.0,
              child: SizedBox(
                width: 100,
                height: 100,
                child: Text(theme.name, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text(theme.name), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('RunicHeader Widget Tests', () {
    testWidgets('renders title, subtitle, glowing rune, and wing flourishes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(
          child: const RunicHeader(
            title: 'Kutsal Şifa İksiri',
            subtitle: 'ARKON · Kadim Tarif',
            rune: 'ᛟ',
            wingsStyle: RunicWingsStyle.metallic,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Kutsal Şifa İksiri'), findsOneWidget);
      expect(find.text('ARKON · Kadim Tarif'), findsOneWidget);
      expect(find.text('ᛟ'), findsOneWidget);
    });

    testWidgets('renders leading and trailing action slots', (
      WidgetTester tester,
    ) async {
      bool closePressed = false;

      await tester.pumpWidget(
        buildTestScaffold(
          child: RunicHeader(
            title: 'Tarif Detayı',
            leading: const Icon(Icons.arrow_back, color: Colors.white),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                closePressed = true;
              },
            ),
            wingsStyle: RunicWingsStyle.gem,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(closePressed, isTrue);
    });

    testWidgets('handles long text on 390px width without layout overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(
          surfaceSize: const Size(390, 844),
          child: const RunicHeader(
            title: 'Çok Uzun Efsanevi Ejderha Katili Kutsal Daevanion Silahı Ön İzleme Paneli',
            subtitle: 'Bu tarif inanılmaz derecede nadir ve kadim güçlerle donatılmış bir üretimdir',
            rune: '✦',
            wingsStyle: RunicWingsStyle.metallic,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('✦'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('GlowingStatBadge Widget Tests', () {
    testWidgets('renders badge with label, value, and icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(
          child: const GlowingStatBadge(
            label: 'BAŞARI',
            value: '85%',
            icon: Icons.percent_rounded,
            variant: GlowingStatBadgeVariant.pill,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('BAŞARI'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
      expect(find.byIcon(Icons.percent_rounded), findsOneWidget);
    });

    testWidgets('renders with AionRarityTier binding', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(
          child: const GlowingStatBadge(
            label: 'MİTİK',
            tier: AionRarityTier.mythic,
            variant: GlowingStatBadgeVariant.card,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('MİTİK'), findsOneWidget);
    });

    testWidgets('renders mini circular progress gauge when progress is set', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(
          child: const GlowingStatBadge(
            label: '90% Şans',
            progress: 0.90,
            variant: GlowingStatBadgeVariant.compact,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('90% Şans'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('triggers onTap callback when pressed', (
      WidgetTester tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestScaffold(
          child: GlowingStatBadge(
            label: 'Dokunmatik Rozet',
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Dokunmatik Rozet'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('all variants (pill, card, compact, metallic) render without error', (
      WidgetTester tester,
    ) async {
      for (final GlowingStatBadgeVariant variant in GlowingStatBadgeVariant.values) {
        await tester.pumpWidget(
          buildTestScaffold(
            child: GlowingStatBadge(
              label: variant.name,
              value: '100',
              variant: variant,
              isPulsing: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text(variant.name), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Full Composite Aion 2 Glass & Metallic Layout Test', () {
    testWidgets('renders complete crafting panel composition within 390x844 bounds', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(
          surfaceSize: const Size(390, 844),
          child: AionGlassPanel(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const RunicHeader(
                  title: 'Kadim Ejderha Zırhı',
                  subtitle: 'ARKON · Seviye 50 Daevanion',
                  rune: 'ᛟ',
                  wingsStyle: RunicWingsStyle.metallic,
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 12),
                const OrnateMetallicBorder(
                  theme: MetallicTheme.obsidianGold,
                  showCornerRunes: true,
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: Text('Kadim Çelik Zırh Resmi', style: TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(height: 14),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    GlowingStatBadge(
                      label: 'Başarı',
                      value: '95%',
                      progress: 0.95,
                      variant: GlowingStatBadgeVariant.compact,
                    ),
                    GlowingStatBadge(
                      label: 'ARKON',
                      tier: AionRarityTier.archon,
                      variant: GlowingStatBadgeVariant.compact,
                    ),
                    GlowingStatBadge(
                      label: '+15 Geliştirme',
                      icon: Icons.shield_rounded,
                      variant: GlowingStatBadgeVariant.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Kadim Ejderha Zırhı'), findsOneWidget);
      expect(find.text('Kadim Çelik Zırh Resmi'), findsOneWidget);
      expect(find.text('ARKON'), findsOneWidget);
      expect(find.text('95%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
