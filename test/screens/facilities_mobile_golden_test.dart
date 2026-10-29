import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/screens/facilities/widgets/facilities_hub_design.dart';
import 'package:gkk_flutter/screens/facilities/widgets/facilities_ui.dart';
import 'package:gkk_flutter/screens/facilities/widgets/facility_3d_viewport.dart';
import 'package:gkk_flutter/screens/facilities/widgets/facility_hub_cards.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

import '../golden/mobile_viewport_harness.dart';

// =============================================================================
// RESILIENT ASSET CHANNELS & MOCK HARNESS (ZERO TEST FLAKINESS)
// =============================================================================

/// Canonical 1x1 transparent PNG bytes conforming to RFC 2083 PNG specifications.
final Uint8List kTransparent1x1PngBytes = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG magic header
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR header
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 dimensions
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, // 8-bit RGBA
  0x89, 0x00, 0x00, 0x00, 0x0B, 0x49, 0x44, 0x41, // IDAT chunk
  0x54, 0x78, 0x01, 0x63, 0x60, 0x00, 0x00, 0x00,
  0x02, 0x00, 0x01, 0xF4, 0x71, 0x64, 0xA6, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND footer
  0x42, 0x60, 0x82,
]);

/// A resilient [CachingAssetBundle] that resolves any image, font, or JSON asset
/// gracefully without throwing [FlutterError] or hanging on unbundled assets.
class ResilientTestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('.png') || key.endsWith('.jpg') || key.endsWith('.webp')) {
      return ByteData.view(kTransparent1x1PngBytes.buffer);
    }
    if (key.endsWith('.json') || key.contains('Manifest')) {
      final Uint8List jsonBytes = Uint8List.fromList(utf8.encode('{}'));
      return ByteData.view(jsonBytes.buffer);
    }
    return ByteData(0);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key.endsWith('.json') || key.contains('Manifest')) {
      return '{}';
    }
    return '';
  }
}

/// Registers mock binary messenger handlers for asset channels to prevent test failures.
void setupMockAssetChannels(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      if (message == null) return null;
      final String key = utf8.decode(
        message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes),
      );
      if (key.endsWith('.png') || key.endsWith('.jpg') || key.endsWith('.webp')) {
        return ByteData.view(kTransparent1x1PngBytes.buffer);
      }
      if (key.endsWith('.json') || key.contains('Manifest')) {
        final Uint8List jsonBytes = Uint8List.fromList(utf8.encode('{}'));
        return ByteData.view(jsonBytes.buffer);
      }
      return ByteData(0);
    },
  );
}

/// Cleans up mock message handlers.
void tearDownMockAssetChannels(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    null,
  );
}

/// Builds a mobile test harness wrapping [child] with authentic 390x844 SafeArea
/// and resilient asset bundles on both internal and external levels.
Widget buildRobustMobileTestHarness({
  required GlobalKey repaintKey,
  required Widget child,
}) {
  final ResilientTestAssetBundle testBundle = ResilientTestAssetBundle();
  return DefaultAssetBundle(
    bundle: testBundle,
    child: buildMobileTestHarness(
      repaintKey: repaintKey,
      child: DefaultAssetBundle(
        bundle: testBundle,
        child: child,
      ),
    ),
  );
}

// =============================================================================
// FACILITIES MOBILE GOLDEN TEST SUITE
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Facilities Screen Mobile Golden & 390x844 Viewport Suite', () {
    testWidgets('Facilities screen renders suspicion panel & tier sections on 390x844 without overflow', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();
      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      setupMockAssetChannels(tester);
      addTearDown(() => tearDownMockAssetChannels(tester));

      final Widget facilitiesScreen = Scaffold(
        backgroundColor: const Color(0xFF080B12),
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
                'Tesisler & Üretim Üssü',
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
              Icon(Icons.nightlife, color: AppColors.textSecondary),
              Icon(Icons.domain, color: AppColors.liquidGold),
              Icon(Icons.castle, color: AppColors.textSecondary),
            ],
          ),
        ),
        body: SafeArea(
          child: facilitiesScreenShell(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: <Widget>[
                // Şüphe + Rüşvet Paneli
                FacSuspicionPanel(
                  activeCount: 5,
                  globalSuspicion: 42,
                  suspicionCap: 100,
                  bribeGemCost: 75,
                  bribeDisabled: false,
                  onBribe: () {},
                ),
                const SizedBox(height: 12),

                // Tier 1 Bölümü
                FacTierSection(
                  tier: 1,
                  title: 'TEMEL ALTYAPI VE LOJİSTİK',
                  trailing: '3 / 3 Tesis Kurulu',
                  accentColor: AppColors.liquidGold,
                  children: <Widget>[
                    _buildFacilityCard(
                      name: 'Ana Depolama Deposu',
                      level: 8,
                      stat: 'Depo Kapasitesi: 12.000 / 12.000 Birim',
                      accent: AppColors.liquidGold,
                      icon: Icons.inventory_2_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildFacilityCard(
                      name: 'Demirci ve Silah Ocağı',
                      level: 6,
                      stat: 'Üretim Oranı: 18 Mithril Kılıç / Gün',
                      accent: AppColors.accentCyan,
                      icon: Icons.hardware_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildFacilityCard(
                      name: 'Askeri Talimgah & Kışla',
                      level: 5,
                      stat: 'Eğitim Oranı: 24 Acemi Muhafız / Gün',
                      accent: const Color(0xFF10B981),
                      icon: Icons.shield_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Tier 2 Bölümü
                FacTierSection(
                  tier: 2,
                  title: 'GÖLGE VE YERALTI ŞEBEKESİ',
                  trailing: '2 / 2 Tesis Kurulu',
                  accentColor: AppColors.mysticRuby,
                  children: <Widget>[
                    _buildFacilityCard(
                      name: 'Gizli Kaçakçı Rıhtımı',
                      level: 4,
                      stat: 'Kaçakçılık Geliri: 95.000 🪙 / Gün',
                      accent: AppColors.mysticRuby,
                      icon: Icons.sailing_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildFacilityCard(
                      name: 'Simyacı ve Zehir Mahzeni',
                      level: 3,
                      stat: 'Saf Zehir Üretimi: 8 Şişe / Gün',
                      accent: const Color(0xFFA855F7),
                      icon: Icons.science_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        buildRobustMobileTestHarness(
          repaintKey: repaintKey,
          child: facilitiesScreen,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull, reason: 'Zero overflow on facilities screen 390x844');
      expect(find.text('Tesisler & Üretim Üssü'), findsOneWidget);
      expect(find.byType(FacSuspicionPanel), findsOneWidget);
      expect(find.text('TEMEL ALTYAPI VE LOJİSTİK'), findsOneWidget);
      expect(find.text('GÖLGE VE YERALTI ŞEBEKESİ'), findsOneWidget);
      expect(find.text('Ana Depolama Deposu'), findsOneWidget);

      final File golden = await captureWidgetToMobilePng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'facilities_390x844_golden.png',
      );

      verifyMobileGoldenFile(golden, minBytes: 2048);
    });

    testWidgets('Facilities screen renders prison lockdown state & critical suspicion on 390x844', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();
      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      setupMockAssetChannels(tester);
      addTearDown(() => tearDownMockAssetChannels(tester));

      final Widget prisonFacilitiesScreen = Scaffold(
        backgroundColor: const Color(0xFF080B12),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xEB0A0E1A),
              border: Border(bottom: BorderSide(color: AppColors.mysticRuby, width: 1)),
            ),
            child: const SafeArea(
              bottom: false,
              child: Text(
                'Tesisler (Cezaevi Kısıtlaması)',
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
              Icon(Icons.nightlife, color: AppColors.textSecondary),
              Icon(Icons.domain, color: AppColors.mysticRuby),
              Icon(Icons.castle, color: AppColors.textSecondary),
            ],
          ),
        ),
        body: SafeArea(
          child: facilitiesScreenShell(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: <Widget>[
                // Authentic Cezaevi Banner
                const FacPrisonBanner(
                  reason: 'Yüksek şüphe ve kaçakçılık baskını sonucu 4 saat tecrit altındasınız.',
                ),
                const SizedBox(height: 12),

                // Critical Suspicion Panel (bribe disabled in prison)
                FacSuspicionPanel(
                  activeCount: 0,
                  globalSuspicion: 92,
                  suspicionCap: 100,
                  bribeGemCost: 150,
                  bribeDisabled: true,
                  onBribe: () {},
                ),
                const SizedBox(height: 12),

                // Locked Tier Section
                FacTierSection(
                  tier: 1,
                  title: 'KİLİTLİ TESİS ÜNİTELERİ',
                  trailing: 'Operasyon Askıda',
                  accentColor: AppColors.mutedTitanium,
                  children: <Widget>[
                    _buildFacilityCard(
                      name: 'Ana Depolama Deposu',
                      level: 8,
                      stat: 'Karantina Altında • Erişim Engellendi',
                      accent: AppColors.mutedTitanium,
                      icon: Icons.lock_outline,
                    ),
                    const SizedBox(height: 8),
                    _buildFacilityCard(
                      name: 'Demirci ve Silah Ocağı',
                      level: 6,
                      stat: 'Mühürlendi • Yargıç Kararı Bekleniyor',
                      accent: AppColors.mutedTitanium,
                      icon: Icons.lock_clock,
                    ),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        buildRobustMobileTestHarness(
          repaintKey: repaintKey,
          child: prisonFacilitiesScreen,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull, reason: 'Zero overflow on prison screen');
      expect(find.text('Tesisler (Cezaevi Kısıtlaması)'), findsOneWidget);
      expect(find.byType(FacPrisonBanner), findsOneWidget);
      expect(find.text('CEZAEVİ — OPERASYONLAR KİLİTLİ'), findsOneWidget);
      expect(find.byType(FacSuspicionPanel), findsOneWidget);
      expect(find.text('KİLİTLİ TESİS ÜNİTELERİ'), findsOneWidget);

      final File golden = await captureWidgetToMobilePng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'facilities_prison_lockdown_390x844_golden.png',
      );

      verifyMobileGoldenFile(golden, minBytes: 2048);
    });

    testWidgets('Authentic FacHubFacilityCard 2-column grid renders tactile states on 390x844', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();
      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      setupMockAssetChannels(tester);
      addTearDown(() => tearDownMockAssetChannels(tester));

      final Widget cardsGridScreen = Scaffold(
        backgroundColor: const Color(0xFF080B12),
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
                'Tesis Kartları & Grid Görünümü',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: facilitiesScreenShell(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: <Widget>[
                FacTierSection(
                  tier: 1,
                  title: 'AKTİF & AÇILABİLİR TESİSLER',
                  trailing: '4 Kart Modeli',
                  accentColor: AppColors.liquidGold,
                  children: facBuildFacilityCardRows(
                    cardBuilder: <Widget Function(int index)>[
                      (int _) => FacHubFacilityCard(
                            animationIndex: 0,
                            icon: '⛏️',
                            name: 'Demir Madeni Ocağı',
                            isUnlocked: true,
                            canUnlock: false,
                            footer: 'Lv.8 • Kuyruk: 3',
                            accentColor: AppColors.liquidGold,
                            onTap: () {},
                          ),
                      (int _) => FacHubFacilityCard(
                            animationIndex: 1,
                            icon: '🧪',
                            name: 'Simyacı Mahzeni',
                            isUnlocked: false,
                            canUnlock: true,
                            footer: '50.000 🪙 Hazır',
                            accentColor: AppColors.toxicNeon,
                            onTap: () {},
                          ),
                      (int _) => FacHubFacilityCard(
                            animationIndex: 2,
                            icon: '⚔️',
                            name: 'Mithril Silah Atölyesi',
                            isUnlocked: true,
                            canUnlock: false,
                            footer: 'Lv.5 • Üretimde',
                            accentColor: AppColors.accentCyan,
                            onTap: () {},
                          ),
                      (int _) => FacHubFacilityCard(
                            animationIndex: 3,
                            icon: '⏳',
                            name: 'Kronos Zaman Monoliti',
                            isUnlocked: false,
                            canUnlock: false,
                            footer: 'Seviye 25 Gerekli',
                            accentColor: AppColors.cyberFuchsia,
                            onTap: () {},
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        buildRobustMobileTestHarness(
          repaintKey: repaintKey,
          child: cardsGridScreen,
        ),
      );

      // Advance clock past the staggered animation delay (35ms * index) and smooth spring motion (450ms)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull, reason: 'Zero overflow on cards grid screen');
      expect(find.byType(FacHubFacilityCard), findsNWidgets(4));
      expect(find.text('Demir Madeni Ocağı'), findsOneWidget);
      expect(find.text('Simyacı Mahzeni'), findsOneWidget);
      expect(find.text('Mithril Silah Atölyesi'), findsOneWidget);
      expect(find.text('Kronos Zaman Monoliti'), findsOneWidget);
      expect(find.text('● Aktif'), findsWidgets);
      expect(find.text('⚡ Açılabilir'), findsOneWidget);
      expect(find.text('🔒 Kilitli'), findsOneWidget);

      final File golden = await captureWidgetToMobilePng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'facilities_cards_grid_390x844_golden.png',
      );

      verifyMobileGoldenFile(golden, minBytes: 2048);
    });

    testWidgets('Facility 3D turntable viewport widget renders on 390x844 mobile viewport', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();
      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      setupMockAssetChannels(tester);
      addTearDown(() => tearDownMockAssetChannels(tester));

      final Widget viewportScreen = Scaffold(
        backgroundColor: const Color(0xFF080B12),
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
                '3D Tesis Modeli İnceleme',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: facilitiesScreenShell(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FacGlassPanel(
                  borderColor: AppColors.liquidGold.withValues(alpha: 0.4),
                  padding: const EdgeInsets.all(8),
                  child: const Facility3dViewport(
                    facilityType: 'mining',
                    level: 5,
                    isProducing: true,
                    height: 320,
                    interactive: false,
                    autoRotate: false,
                    showControls: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        buildRobustMobileTestHarness(
          repaintKey: repaintKey,
          child: viewportScreen,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull, reason: 'Facility 3D viewport renders without overflow');
      expect(find.byType(Facility3dViewport), findsOneWidget);
      expect(find.text('3D Tesis Modeli İnceleme'), findsOneWidget);

      final File golden = await captureWidgetToMobilePng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'facilities_3d_viewport_390x844_golden.png',
      );

      verifyMobileGoldenFile(golden, minBytes: 2048);
    });
  });
}

Widget _buildFacilityCard({
  required String name,
  required int level,
  required String stat,
  required Color accent,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF121A28),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, color: accent, size: 22),
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
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Kademe $level',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                stat,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
