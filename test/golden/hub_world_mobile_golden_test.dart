import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/kingdom/kingdom_crest_icons.dart';
import 'package:gkk_flutter/components/kingdom/kingdom_glass_card.dart';
import 'package:gkk_flutter/components/kingdom/kingdom_overview_card.dart';
import 'package:gkk_flutter/components/kingdom/kingdom_realm_header.dart';
import 'package:gkk_flutter/core/world/cinematic_camera_controller.dart';
import 'package:gkk_flutter/screens/facilities/widgets/facilities_hub_design.dart';
import 'package:gkk_flutter/screens/facilities/widgets/facilities_ui.dart';
import 'package:gkk_flutter/screens/facilities/widgets/facility_hub_cards.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_crowd_layer.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_scene_viewport.dart';
import 'package:gkk_flutter/screens/mekans/widgets/mekan_design.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

import 'mobile_viewport_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Battalion 1 Hub World: 390x844 Mobile Golden Screenshot Suite', () {
    // ═════════════════════════════════════════════════════════════════════════
    // TEST 1: MAIN HUB SCREEN (3D VIEWPORT + 10K CROWD + AAA HUD)
    // ═════════════════════════════════════════════════════════════════════════
    testWidgets(
      '01: Main Hub renders 3D viewport, 10K crowd layer & HUD on 390x844 mobile without overflow',
      (WidgetTester tester) async {
        final GlobalKey repaintKey = GlobalKey();
        setMobileViewDimensions(tester);
        addTearDown(() => resetMobileViewDimensions(tester));

        final HubSceneViewportController viewportController =
            HubSceneViewportController(initialHours: 17.5);
        final HubCrowdController crowdController = HubCrowdController(
          config: const HubCrowdConfig(
            density: HubCrowdDensity.ultra10k,
            simulationSpeed: 1.0,
          ),
          cameraController: viewportController.cameraController,
        );

        final Widget hubWidget = Scaffold(
          extendBody: true,
          appBar: _buildMobileTopBar('Başkent Meydanı'),
          bottomNavigationBar: _buildMobileBottomBar(0),
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // 1. 3D Architecture Viewport (Skybox, PBR plaza, SSR puddles, Fog, Tonemapping)
              Positioned.fill(
                child: HubSceneViewport(
                  controller: viewportController,
                  enablePostProcess: true,
                ),
              ),

              // 2. 10,000 Crowd Layer (GPU instanced SoA crowd background)
              Positioned.fill(
                child: HubCrowdBackgroundLayer(
                  controller: crowdController,
                ),
              ),

              // 3. Foreground Safe HUD & Content
              SafeArea(
                child: Column(
                  children: <Widget>[
                    // Density Switcher Badge
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          HubCrowdDensitySelector(controller: crowdController),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0x80080B12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.liquidGold.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Row(
                              children: <Widget>[
                                Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                                SizedBox(width: 6),
                                Text(
                                  'AION 2 ULTRA 60 FPS',
                                  style: TextStyle(
                                    color: AppColors.liquidGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Hub Content
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: <Widget>[
                          _buildHubHeroCard(),
                          const SizedBox(height: 12),
                          _buildHubQuickActions(),
                          const SizedBox(height: 12),
                          _buildHubPantheonCard(),
                          const SizedBox(height: 80), // spacing for sticky action bar
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Sticky Quick Action Bar
              Positioned(
                left: 16,
                right: 16,
                bottom: 60,
                child: _buildStickyQuickActionBar(),
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          buildMobileTestHarness(
            repaintKey: repaintKey,
            child: hubWidget,
          ),
        );

        // Advance simulation ticks for atmosphere & crowd
        await tester.pump(const Duration(milliseconds: 32));
        await tester.pump(const Duration(milliseconds: 32));

        // Verify key widgets mounted properly
        expect(find.byType(HubSceneViewport), findsOneWidget);
        expect(find.byType(HubCrowdBackgroundLayer), findsOneWidget);
        expect(find.text('Başkent Meydanı'), findsOneWidget);
        expect(find.text('AION 2 ULTRA 60 FPS'), findsOneWidget);

        // Capture mobile golden screenshot
        final File goldenFile = await captureWidgetToMobilePng(
          tester: tester,
          repaintKey: repaintKey,
          filename: '01_main_hub_mobile_golden.png',
        );

        verifyMobileGoldenFile(goldenFile);

        // Cleanup
        await tester.pumpWidget(const SizedBox());
        viewportController.dispose();
        crowdController.dispose();
      },
    );

    // ═════════════════════════════════════════════════════════════════════════
    // TEST 2: MEKANS SCREEN (HAN & ARENA MOBILE VIEWPORT)
    // ═════════════════════════════════════════════════════════════════════════
    testWidgets(
      '02: Mekans screen renders interactive han list, arena & filter tabs on 390x844 without overflow',
      (WidgetTester tester) async {
        final GlobalKey repaintKey = GlobalKey();
        setMobileViewDimensions(tester);
        addTearDown(() => resetMobileViewDimensions(tester));

        final Widget mekansWidget = Scaffold(
          backgroundColor: MekanPalette.void_,
          appBar: _buildMobileTopBar('Mekanlar (Hanlar)'),
          bottomNavigationBar: _buildMobileBottomBar(1),
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Cyber-Aion Backdrop Glow
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        MekanPalette.aqua.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  children: <Widget>[
                    // Search & Filter Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MekanPalette.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: MekanPalette.aqua.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'MEKAN KATEGORİLERİ',
                            style: TextStyle(
                              color: MekanPalette.aqua,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: <Widget>[
                                _buildMekanFilterPill('Tümü', true),
                                _buildMekanFilterPill('Bar', false),
                                _buildMekanFilterPill('Dövüş Kulübü', false),
                                _buildMekanFilterPill('Kahvehane', false),
                                _buildMekanFilterPill('Lüks Lounge', false),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Arena Spotlight Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[
                            Color(0xFF261219),
                            Color(0xFF140D1B),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: MekanPalette.ruby.withValues(alpha: 0.6),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: MekanPalette.ruby.withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: MekanPalette.ruby.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.sports_martial_arts,
                                  color: MekanPalette.ruby,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Yeraltı Gladyatör Arenası',
                                      style: TextStyle(
                                        color: MekanPalette.textHi,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'Haftalık Bahis & Düello Havuzu: 2.500.000 🪙',
                                      style: TextStyle(
                                        color: MekanPalette.gold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {},
                            style: FilledButton.styleFrom(
                              backgroundColor: MekanPalette.ruby,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.flash_on, size: 16),
                            label: const Text('Arenaya Gir & Bahis Yap'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mekan Cards
                    _buildMekanCard(
                      name: 'Ejder Hanı & Meyhanesi',
                      type: 'Bar & Dinlenme',
                      level: 5,
                      dailyRevenue: 42000,
                      occupancy: '94%',
                      accentColor: MekanPalette.aqua,
                    ),
                    const SizedBox(height: 10),
                    _buildMekanCard(
                      name: 'Gölge Çarşı Kahvesi',
                      type: 'Kahvehane & Ticaret',
                      level: 4,
                      dailyRevenue: 31000,
                      occupancy: '78%',
                      accentColor: MekanPalette.gold,
                    ),
                    const SizedBox(height: 10),
                    _buildMekanCard(
                      name: 'Akrep Yeraltı Kulübü',
                      type: 'Yeraltı Kumarhane',
                      level: 6,
                      dailyRevenue: 68000,
                      occupancy: '98%',
                      accentColor: MekanPalette.neon,
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          buildMobileTestHarness(
            repaintKey: repaintKey,
            child: mekansWidget,
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Mekanlar (Hanlar)'), findsOneWidget);
        expect(find.text('Yeraltı Gladyatör Arenası'), findsOneWidget);
        expect(find.text('Ejder Hanı & Meyhanesi'), findsOneWidget);

        final File goldenFile = await captureWidgetToMobilePng(
          tester: tester,
          repaintKey: repaintKey,
          filename: '02_mekans_mobile_golden.png',
        );

        verifyMobileGoldenFile(goldenFile);
      },
    );

    // ═════════════════════════════════════════════════════════════════════════
    // TEST 3: FACILITIES SCREEN (TESİSLER & ŞÜPHE PANOLARI)
    // ═════════════════════════════════════════════════════════════════════════
    testWidgets(
      '03: Facilities screen renders suspicion panel & facility cards on 390x844 without overflow',
      (WidgetTester tester) async {
        final GlobalKey repaintKey = GlobalKey();
        setMobileViewDimensions(tester);
        addTearDown(() => resetMobileViewDimensions(tester));

        final Widget facilitiesWidget = Scaffold(
          backgroundColor: const Color(0xFF080B12),
          appBar: _buildMobileTopBar('Tesisler & Üretim'),
          bottomNavigationBar: _buildMobileBottomBar(2),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: <Widget>[
                // Suspicion Panel
                FacSuspicionPanel(
                  activeCount: 6,
                  globalSuspicion: 35,
                  suspicionCap: 100,
                  bribeGemCost: 50,
                  bribeDisabled: false,
                  onBribe: () {},
                ),
                const SizedBox(height: 12),

                // Facilities Tier 1 Section
                FacTierSection(
                  tier: 1,
                  title: 'TEMEL ÜRETİM VE DEPO',
                  trailing: '3 / 3 Aktif',
                  accentColor: AppColors.liquidGold,
                  children: <Widget>[
                    _buildFacilityCard(
                      title: 'Merkez Malzeme Deposu',
                      level: 7,
                      output: 'Kapasite: 5.000 / 5.000 birim',
                      isOperating: true,
                      accentColor: AppColors.liquidGold,
                      icon: Icons.inventory_2_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildFacilityCard(
                      title: 'Demirci & Silah Atölyesi',
                      level: 5,
                      output: 'Üretim: 12 Çelik Kılıç / Gün',
                      isOperating: true,
                      accentColor: AppColors.accentCyan,
                      icon: Icons.build_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Facilities Tier 2 Section
                FacTierSection(
                  tier: 2,
                  title: 'GÖLGE OPERASYONLARI',
                  trailing: '2 / 2 Aktif',
                  accentColor: AppColors.mysticRuby,
                  children: <Widget>[
                    _buildFacilityCard(
                      title: 'Kaçakçı Limanı',
                      level: 4,
                      output: 'Gelir: 85.000 🪙 / Gün',
                      isOperating: true,
                      accentColor: AppColors.mysticRuby,
                      icon: Icons.directions_boat_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildFacilityCard(
                      title: 'Simya & Zehir Laboratuvarı',
                      level: 3,
                      output: 'Üretim: 6 Saf Elixir / Gün',
                      isOperating: true,
                      accentColor: const Color(0xFFA855F7),
                      icon: Icons.science_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        );

        await tester.pumpWidget(
          buildMobileTestHarness(
            repaintKey: repaintKey,
            child: facilitiesWidget,
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Tesisler & Üretim'), findsOneWidget);
        expect(find.byType(FacSuspicionPanel), findsOneWidget);
        expect(find.text('Merkez Malzeme Deposu'), findsOneWidget);

        final File goldenFile = await captureWidgetToMobilePng(
          tester: tester,
          repaintKey: repaintKey,
          filename: '03_facilities_mobile_golden.png',
        );

        verifyMobileGoldenFile(goldenFile);
      },
    );

    // ═════════════════════════════════════════════════════════════════════════
    // TEST 4: KINGDOM SCREEN (AION-2 CITADEL, REALM CARDS & CROWN BLESSING)
    // ═════════════════════════════════════════════════════════════════════════
    testWidgets(
      '04: Kingdom screen renders celestial header & realm cards on 390x844 without overflow',
      (WidgetTester tester) async {
        final GlobalKey repaintKey = GlobalKey();
        setMobileViewDimensions(tester);
        addTearDown(() => resetMobileViewDimensions(tester));

        final Widget kingdomWidget = Scaffold(
          backgroundColor: const Color(0xFF070B14),
          appBar: _buildMobileTopBar('Krallık & Hükümranlık'),
          bottomNavigationBar: _buildMobileBottomBar(3),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: <Widget>[
                // Celestial Realm Header Artwork
                const KingdomRealmHeader(
                  realmTitle: 'Aethelgard Hükümranlığı',
                  reigningKing: 'Lord Kaelen',
                  reigningGuild: 'Gök Muhafızları',
                  dominionLevel: 14,
                  activeBlessingSummary: 'Ticaret Lütfu (%15 İndirim)',
                  height: 180,
                ),
                const SizedBox(height: 10),

                // Territory Management Card
                KingdomTerritoryCard(
                  realmName: 'Aethelgard Krallığı',
                  controlledProvinces: 8,
                  totalProvinces: 9,
                  defenseLevel: 5,
                  taxYieldMultiplier: 1.35,
                  isUnderSiege: false,
                  onManage: () {},
                  onViewMap: () {},
                ),
                const SizedBox(height: 12),

                // Treasury Card
                KingdomTreasuryCard(
                  goldBalance: 12450000,
                  gemBalance: 4800,
                  dailyTaxRevenue: 650000,
                  isKing: true,
                  canGift: true,
                  onViewLedger: () {},
                  onGiftSend: () {},
                ),
                const SizedBox(height: 12),

                // Army Card
                KingdomArmyCard(
                  legionName: 'İmparatorluk Muhafız Alayı',
                  activeSoldiers: 18500,
                  readinessRating: 98,
                  warDefenseBonusPct: 20,
                  onInspect: () {},
                ),
                const SizedBox(height: 12),

                // Diplomacy Card
                KingdomDiplomacyCard(
                  month: 'Haziran 2027 Dönemi',
                  kingName: 'Lord Kaelen',
                  guildName: 'Gök Muhafızları',
                  isElectionActive: true,
                  countdownLabel: '2 Gün Kaldı',
                  canVote: true,
                  alreadyVoted: false,
                  onVote: () {},
                  onViewCouncil: () {},
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        );

        await tester.pumpWidget(
          buildMobileTestHarness(
            repaintKey: repaintKey,
            child: kingdomWidget,
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Krallık & Hükümranlık'), findsOneWidget);
        expect(find.byType(KingdomRealmHeader), findsOneWidget);
        expect(find.byType(KingdomTerritoryCard), findsOneWidget);
        expect(find.byType(KingdomTreasuryCard), findsOneWidget);
        expect(find.byType(KingdomArmyCard), findsOneWidget);
        expect(find.byType(KingdomDiplomacyCard), findsOneWidget);

        final File goldenFile = await captureWidgetToMobilePng(
          tester: tester,
          repaintKey: repaintKey,
          filename: '04_kingdom_mobile_golden.png',
        );

        verifyMobileGoldenFile(goldenFile);
      },
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// UI Component Builders
// ─────────────────────────────────────────────────────────────────────────────

PreferredSizeWidget _buildMobileTopBar(String title) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(56),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xEB0A0E1A),
        border: Border(bottom: BorderSide(color: Color(0x3338BDF8), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: <Color>[AppColors.liquidGold, AppColors.coralFlare],
                ),
                border: Border.all(color: AppColors.liquidGold, width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.shield, color: Colors.black, size: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x33F5C842),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x66F5C842), width: 0.8),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.monetization_on, color: AppColors.liquidGold, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '1.4M',
                    style: TextStyle(
                      color: AppColors.liquidGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildMobileBottomBar(int selectedIndex) {
  return Container(
    height: 60,
    decoration: const BoxDecoration(
      color: Color(0xEB070A12),
      border: Border(top: BorderSide(color: Color(0x33253154), width: 1)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        _buildNavItem(Icons.home_filled, 'Meydan', selectedIndex == 0),
        _buildNavItem(Icons.nightlife_rounded, 'Mekanlar', selectedIndex == 1),
        _buildNavItem(Icons.domain_rounded, 'Tesisler', selectedIndex == 2),
        _buildNavItem(Icons.castle_rounded, 'Krallık', selectedIndex == 3),
      ],
    ),
  );
}

Widget _buildNavItem(IconData icon, String label, bool active) {
  final color = active ? AppColors.liquidGold : AppColors.textSecondary;
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 2),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    ],
  );
}

Widget _buildStickyQuickActionBar() {
  return Container(
    height: 48,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: <Color>[Color(0xFF7C2D12), Color(0xFF991B1B)],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFEF4444), width: 1),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: Color(0x40EF4444), blurRadius: 10),
      ],
    ),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
        SizedBox(width: 8),
        Text(
          'HIZLI SEFER & ZİNDAN AKINI',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ],
    ),
  );
}

Widget _buildHubHeroCard() {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xCC0E1524),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x4038BDF8)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF1E3A8A), Color(0xFF0F172A)],
            ),
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
          ),
          child: const Center(
            child: Icon(Icons.person, color: Color(0xFF38BDF8), size: 28),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Lord Kaelen · Seviye 85',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Gök Savaşçısı · Kudret: 1.840.000',
                style: TextStyle(
                  color: AppColors.liquidGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildHubQuickActions() {
  return Row(
    children: <Widget>[
      Expanded(
        child: _buildActionTile(Icons.sports_kabaddi, 'PvP Arena', const Color(0xFFEF4444)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _buildActionTile(Icons.storefront, 'Pazar', AppColors.liquidGold),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _buildActionTile(Icons.shield, 'Lonca', const Color(0xFF38BDF8)),
      ),
    ],
  );
}

Widget _buildActionTile(IconData icon, String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xCC111827),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

Widget _buildHubPantheonCard() {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xCC0E1524),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x40F5C842)),
    ),
    child: const Row(
      children: <Widget>[
        Icon(Icons.emoji_events, color: AppColors.liquidGold, size: 28),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Panteon Lider Tablosu',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                '1. Sıra: [GÖK] Archon (Skor: 94.200)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildMekanFilterPill(String label, bool isSelected) {
  return Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: isSelected ? MekanPalette.aqua : MekanPalette.surfaceHi,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isSelected
            ? MekanPalette.aqua
            : MekanPalette.titanium.withValues(alpha: 0.3),
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

Widget _buildMekanCard({
  required String name,
  required String type,
  required int level,
  required int dailyRevenue,
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
          child: Center(
            child: Icon(Icons.nightlife, color: accentColor, size: 24),
          ),
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
                    'Gelir: $dailyRevenue 🪙 / gün',
                    style: const TextStyle(
                      color: MekanPalette.gold,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Doluluk: $occupancy',
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

Widget _buildFacilityCard({
  required String title,
  required int level,
  required String output,
  required bool isOperating,
  required Color accentColor,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF131B2A),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accentColor.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColor, size: 20),
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
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Kademe $level',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                output,
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
