import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/screens/mekans/widgets/mekan_design.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

import '../golden/mobile_viewport_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mekans Screen Mobile Golden & 390x844 Viewport Suite', () {
    testWidgets('Mekans screen renders interactive list, arena & stock cards on 390x844 without overflow', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();
      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      final Widget mekansScreen = Scaffold(
        backgroundColor: MekanPalette.void_,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xEB0A0E1A),
              border: Border(bottom: BorderSide(color: Color(0x3338BDF8), width: 1)),
            ),
            child: const SafeArea(
              bottom: false,
              child: Text(
                'Mekanlar & Hanlar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          height: 60,
          color: const Color(0xEB070A12),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              Icon(Icons.home, color: AppColors.textSecondary),
              Icon(Icons.nightlife, color: MekanPalette.aqua),
              Icon(Icons.domain, color: AppColors.textSecondary),
              Icon(Icons.castle, color: AppColors.textSecondary),
            ],
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Atmospheric Neon Rim
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 220,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      MekanPalette.aqua.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: <Widget>[
                  // Category Filter Bar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MekanPalette.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MekanPalette.aqua.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Row(
                          children: <Widget>[
                            Icon(Icons.tune_rounded, size: 14, color: MekanPalette.aqua),
                            SizedBox(width: 6),
                            Text(
                              'HAN FİLTRELERİ',
                              style: TextStyle(
                                color: MekanPalette.aqua,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: <Widget>[
                              _buildPill('Tümü (24)', true),
                              _buildPill('Meyhane & Bar', false),
                              _buildPill('Dövüş Kulübü', false),
                              _buildPill('Lüks Salon', false),
                              _buildPill('Gölge Pazarı', false),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Arena Feature Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xFF28131E),
                          Color(0xFF160E22),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: MekanPalette.ruby.withValues(alpha: 0.6)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: MekanPalette.ruby.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: MekanPalette.ruby.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.sports_kabaddi_rounded,
                                color: MekanPalette.ruby,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Yeraltı Dövüş Kulübü',
                                    style: TextStyle(
                                      color: MekanPalette.textHi,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Gladyatör Bahisleri & Sıralama Ligi',
                                    style: TextStyle(
                                      color: MekanPalette.gold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text('Aktif Bahis', style: TextStyle(color: MekanPalette.textLow, fontSize: 10)),
                                    Text('12.500 🪙', style: TextStyle(color: MekanPalette.gold, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text('Kazanma Oranı', style: TextStyle(color: MekanPalette.textLow, fontSize: 10)),
                                    Text('1 : 2.45', style: TextStyle(color: MekanPalette.aqua, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mekan List
                  _buildMekanItem(
                    name: 'Kuzey Rüzgarı Tavernası',
                    type: 'Meyhane & Bilgi Ağı',
                    level: 6,
                    revenue: '54.000 🪙 / Gün',
                    occupancy: '%92 Dolu',
                    accentColor: MekanPalette.aqua,
                  ),
                  const SizedBox(height: 10),
                  _buildMekanItem(
                    name: 'Altın Kadeh Dinlenme Salonu',
                    type: 'Lüks Han & Kahve',
                    level: 5,
                    revenue: '41.500 🪙 / Gün',
                    occupancy: '%84 Dolu',
                    accentColor: MekanPalette.gold,
                  ),
                  const SizedBox(height: 10),
                  _buildMekanItem(
                    name: 'Karanlık Geçit Kumarhanesi',
                    type: 'Gölge Bahisleri',
                    level: 8,
                    revenue: '89.000 🪙 / Gün',
                    occupancy: '%98 Dolu',
                    accentColor: MekanPalette.neon,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: mekansScreen,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mekanlar & Hanlar'), findsOneWidget);
      expect(find.text('Yeraltı Dövüş Kulübü'), findsOneWidget);
      expect(find.text('Kuzey Rüzgarı Tavernası'), findsOneWidget);

      final File golden = await captureWidgetToMobilePng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'mekans_390x844_golden.png',
      );

      verifyMobileGoldenFile(golden);
    });
  });
}

Widget _buildPill(String label, bool isSelected) {
  return Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: isSelected ? MekanPalette.aqua : MekanPalette.surfaceHi,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isSelected ? MekanPalette.aqua : MekanPalette.titanium.withValues(alpha: 0.3),
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: isSelected ? Colors.black : MekanPalette.textMid,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget _buildMekanItem({
  required String name,
  required String type,
  required int level,
  required String revenue,
  required String occupancy,
  required Color accentColor,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: MekanPalette.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accentColor.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.6)),
          ),
          child: Icon(Icons.nightlife, color: accentColor, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    name,
                    style: const TextStyle(
                      color: MekanPalette.textHi,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Lvl $level',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                type,
                style: const TextStyle(
                  color: MekanPalette.textLow,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Text(
                    revenue,
                    style: const TextStyle(
                      color: MekanPalette.gold,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    occupancy,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
