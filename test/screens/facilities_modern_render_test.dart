import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_controller.dart';
import 'package:gkk_flutter/l10n/l10n.dart';
import 'package:gkk_flutter/models/facility_model.dart';
import 'package:gkk_flutter/models/facility_production_preview_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/models/staff_model.dart';
import 'package:gkk_flutter/providers/facilities_provider.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/providers/staff_provider.dart';
import 'package:gkk_flutter/screens/facilities/facilities_screen.dart';
import 'package:gkk_flutter/screens/facilities/facility_detail_data.dart';
import 'package:gkk_flutter/screens/facilities/widgets/facilities_dialogs.dart';
import 'package:gkk_flutter/screens/facilities/widgets/facilities_hub_design.dart';
import 'package:gkk_flutter/screens/facilities/widgets/facilities_ui.dart';
import 'package:gkk_flutter/screens/facilities/widgets/facility_detail_design.dart';
import 'package:gkk_flutter/screens/facilities/widgets/facility_hub_cards.dart';
import 'package:gkk_flutter/screens/facilities/widgets/facility_rarity_simulator.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MOCK DATA & HARNESS HELPERS
// ─────────────────────────────────────────────────────────────────────────────

PlayerProfile createTestPlayerProfile({
  int level = 15,
  int gold = 600000,
  double gems = 50.0,
  int energy = 100,
  int globalSuspicion = 35,
  String? prisonUntil,
  String? prisonReason,
}) {
  return PlayerProfile.fromJson(<String, dynamic>{
    'id': 'test-player-001',
    'auth_id': 'auth-test-001',
    'username': 'AionChampion',
    'email': 'champion@aion2.com',
    'display_name': 'Aion Şampiyonu',
    'avatar_url': '',
    'avatar_frame': 'gold_celestial',
    'level': level,
    'xp': 15000,
    'gold': gold,
    'gems': gems,
    'energy': energy,
    'max_energy': 100,
    'attack': 850,
    'defense': 720,
    'health': 3400,
    'max_health': 3400,
    'power': 2100,
    'is_online': true,
    'is_banned': false,
    'tutorial_completed': true,
    'guild_id': 'guild-01',
    'guild_role': 'member',
    'referral_code': 'AION2026',
    'referred_by': null,
    'pvp_rating': 1400,
    'pvp_wins': 20,
    'pvp_losses': 5,
    'addiction_level': 0,
    'tolerance': 0,
    'global_suspicion_level': globalSuspicion,
    'prison_until': prisonUntil,
    'prison_reason': prisonReason,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-10-29T00:00:00Z',
  });
}

class FakePlayerNotifier extends PlayerNotifier {
  FakePlayerNotifier({this.mockProfile});
  final PlayerProfile? mockProfile;

  @override
  PlayerState build() => PlayerState(
        status: PlayerStatus.ready,
        profile: mockProfile ?? createTestPlayerProfile(),
      );

  @override
  Future<void> loadProfile({bool silent = false}) async {}
}

class FakeFacilitiesNotifier extends FacilitiesNotifier {
  FakeFacilitiesNotifier({required this.initialState});
  final FacilitiesState initialState;

  @override
  FacilitiesState build() => initialState;

  @override
  Future<void> loadFacilities() async {}

  @override
  Future<bool> unlockFacility({required String facilityType}) async => true;

  @override
  Future<bool> bribeOfficials({required String facilityType, required int gemAmount}) async => true;
}

class FakeStaffNotifier extends StaffNotifier {
  @override
  StaffState build() => const StaffState(isLoading: false, profile: StaffProfile.none);
}

class FakeTutorialController extends TutorialController {
  @override
  TutorialState build() => TutorialState.initial().copyWith(loaded: true);

  @override
  Future<void> onRouteEnter(String route) async {}
}

Widget testHarness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('tr'),
    theme: ThemeData.dark(),
    home: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: child,
        ),
      ),
    ),
  );
}

Widget screenTestHarness({
  required Widget child,
  PlayerProfile? profile,
  FacilitiesState? facilitiesState,
}) {
  return ProviderScope(
    overrides: [
      playerProvider.overrideWith(() => FakePlayerNotifier(mockProfile: profile)),
      facilitiesProvider.overrideWith(() => FakeFacilitiesNotifier(
            initialState: facilitiesState ?? FacilitiesState.initial(),
          )),
      staffProvider.overrideWith(() => FakeStaffNotifier()),
      tutorialProvider.overrideWith(() => FakeTutorialController()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.liquidGold,
          secondary: AppColors.accentCyan,
          surface: AppColors.bgSurface,
        ),
      ),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(412, 915),
          padding: EdgeInsets.only(top: 44, bottom: 34),
        ),
        child: SizedBox(
          width: 412,
          height: 915,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aion-2 Facilities Glassmorphism UI Primitives', () {
    testWidgets('FacGlassPanel renders with frosted blur and borders', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          const FacGlassPanel(
            borderColor: AppColors.liquidGold,
            child: Text('Frosted Content'),
          ),
        ),
      );

      expect(find.text('Frosted Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('facilitiesStatChip displays label and value', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          facilitiesStatChip('Üretim', '150/saat', valueColor: AppColors.toxicNeon),
        ),
      );

      expect(find.text('ÜRETİM'), findsOneWidget);
      expect(find.text('150/saat'), findsOneWidget);
    });

    testWidgets('facilitiesSectionTitle renders with golden accent bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          facilitiesSectionTitle('Kaynak Havuzu', trailing: 'Lv.5'),
        ),
      );

      expect(find.text('Kaynak Havuzu'), findsOneWidget);
      expect(find.text('Lv.5'), findsOneWidget);
    });

    testWidgets('FacBadge variants render with proper themed styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          const Row(
            children: <Widget>[
              FacBadge.gold('EFSANEVİ'),
              FacBadge.cyan('MİSTİK'),
              FacBadge.ruby('TEHLİKELİ'),
              FacBadge.emerald('AKTİF'),
              FacBadge.neutral('SIRADAN'),
            ],
          ),
        ),
      );

      expect(find.text('EFSANEVİ'), findsOneWidget);
      expect(find.text('MİSTİK'), findsOneWidget);
      expect(find.text('TEHLİKELİ'), findsOneWidget);
      expect(find.text('AKTİF'), findsOneWidget);
      expect(find.text('SIRADAN'), findsOneWidget);
    });

    testWidgets('FacBadge.level and FacBadge.tier format level and tier labels accurately', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          Row(
            children: <Widget>[
              FacBadge.level(5),
              FacBadge.level(1, compact: true),
              FacBadge.tier(2),
            ],
          ),
        ),
      );

      expect(find.text('LV. 5'), findsOneWidget);
      expect(find.text('LV. 1'), findsOneWidget);
      expect(find.text('TIER 2'), findsOneWidget);
    });
  });

  group('Facilities Hub UI & Cards', () {
    testWidgets('FacSuspicionPanel renders gauge and triggers bribe callback', (WidgetTester tester) async {
      bool bribeTriggered = false;

      await tester.pumpWidget(
        testHarness(
          FacSuspicionPanel(
            activeCount: 8,
            globalSuspicion: 45,
            suspicionCap: 100,
            bribeGemCost: 5,
            bribeDisabled: false,
            onBribe: () => bribeTriggered = true,
          ),
        ),
      );

      expect(find.text('GENEL ŞÜPHE'), findsOneWidget);
      expect(find.text('%45'), findsOneWidget);
      expect(find.text('8/15 Tesis Aktif Çalışıyor'), findsOneWidget);
      expect(find.text('Maks Sınır: %100'), findsOneWidget);

      final bribeBtnFinder = find.text('Rüşvet (5 Gem)');
      expect(bribeBtnFinder, findsOneWidget);

      await tester.tap(bribeBtnFinder);
      await tester.pumpAndSettle();

      expect(bribeTriggered, isTrue);
    });

    testWidgets('FacSuspicionPanel renders safe zone when suspicion is 0', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          FacSuspicionPanel(
            activeCount: 3,
            globalSuspicion: 0,
            suspicionCap: 100,
            bribeGemCost: 5,
            bribeDisabled: true,
            onBribe: () {},
          ),
        ),
      );

      expect(find.text('%0'), findsOneWidget);
      expect(find.text('Güvenli Bölge • Baskın Riski Yok'), findsOneWidget);
      expect(find.text('3/15 Tesis Aktif Çalışıyor'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('FacPrisonBanner displays detention warning', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          const FacPrisonBanner(reason: 'Yüksek şüphe baskını'),
        ),
      );

      expect(find.text('CEZAEVİ — OPERASYONLAR KİLİTLİ'), findsOneWidget);
      expect(find.text('Yüksek şüphe baskını'), findsOneWidget);
    });

    testWidgets('FacHubFacilityCard renders active status and handles taps', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        testHarness(
          FacHubFacilityCard(
            animationIndex: 0,
            icon: '⛏️',
            name: 'Maden Ocağı',
            isUnlocked: true,
            canUnlock: false,
            footer: 'Lv.3 • Kuyruk: 2',
            accentColor: AppColors.liquidGold,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Maden Ocağı'), findsOneWidget);
      expect(find.text('⛏️'), findsOneWidget);
      expect(find.text('● Aktif'), findsOneWidget);
      expect(find.text('3D'), findsOneWidget);
      expect(find.text('Lv.3 • Kuyruk: 2'), findsOneWidget);

      await tester.tap(find.text('Maden Ocağı'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('FacHubFacilityCard renders unlockable state', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          FacHubFacilityCard(
            animationIndex: 0,
            icon: '🌾',
            name: 'Çiftlik',
            isUnlocked: false,
            canUnlock: true,
            footer: 'Dokun ve Aç • 200.000 Altın',
            accentColor: AppColors.toxicNeon,
            onTap: () {},
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Çiftlik'), findsOneWidget);
      expect(find.text('⚡ Açılabilir'), findsOneWidget);
      expect(find.text('Dokun ve Aç • 200.000 Altın'), findsOneWidget);
    });

    testWidgets('FacHubFacilityCard renders locked state with level requirement', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          FacHubFacilityCard(
            animationIndex: 0,
            icon: '🔥',
            name: 'Elementel Ocak',
            isUnlocked: false,
            canUnlock: false,
            footer: 'Seviye 30 gerekli (Mevcut: Lv. 15)',
            accentColor: AppColors.coralFlare,
            onTap: () {},
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Elementel Ocak'), findsOneWidget);
      expect(find.text('🔒 Kilitli'), findsOneWidget);
      expect(find.text('Seviye 30 gerekli (Mevcut: Lv. 15)'), findsOneWidget);
    });

    testWidgets('FacTierSection renders title, tier number, trailing count, and divider', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          const FacTierSection(
            tier: 2,
            title: 'Kademe 2 — Gelişmiş Tesisler',
            trailing: '3/5 Açık',
            accentColor: AppColors.accentCyan,
            children: <Widget>[
              Text('Tesis İçeriği Test'),
            ],
          ),
        ),
      );

      expect(find.text('KADEME 2 — GELİŞMİŞ TESİSLER'), findsOneWidget);
      expect(find.text('3/5 Açık'), findsOneWidget);
      expect(find.text('Tesis İçeriği Test'), findsOneWidget);
    });
  });

  group('Facility Detail Design Components', () {
    testWidgets('FacDetailHero renders medallion, name, level and status', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          const FacDetailHero(
            icon: '🔥',
            name: 'Elementel Ocak',
            description: 'Ateş elementleri döver ve mistik kaynaklar üretir.',
            level: 4,
            isProducing: true,
          ),
        ),
      );

      expect(find.text('Elementel Ocak'), findsOneWidget);
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('Lv.4'), findsOneWidget);
      expect(find.text('● Üretim Aktif'), findsOneWidget);
      expect(find.text('Ateş elementleri döver ve mistik kaynaklar üretir.'), findsOneWidget);
    });

    testWidgets('FacProductionBanner displays active countdown and items', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          const FacProductionBanner(
            isRunning: true,
            remainingLabel: '04:25',
            onStart: null,
            startEnabled: false,
            startLabel: '',
            previewItems: <String>['Demir Cevheri ×5', 'Kuvars ×2'],
          ),
        ),
      );

      expect(find.text('ÜRETİM DEVAM EDİYOR'), findsOneWidget);
      expect(find.text('04:25'), findsOneWidget);
      expect(find.text('Demir Cevheri ×5'), findsOneWidget);
      expect(find.text('Kuvars ×2'), findsOneWidget);
    });

    testWidgets('FacProductionBanner displays idle start button and triggers start', (WidgetTester tester) async {
      bool started = false;

      await tester.pumpWidget(
        testHarness(
          FacProductionBanner(
            isRunning: false,
            remainingLabel: '00:00',
            onStart: () => started = true,
            startEnabled: true,
            startLabel: '⚡ Üretimi Başlat',
          ),
        ),
      );

      expect(find.text('ÜRETİM HATTI HAZIR'), findsOneWidget);
      expect(find.text('Maliyet: 50⚡ Enerji'), findsOneWidget);

      final startBtnFinder = find.text('⚡ Üretimi Başlat');
      expect(startBtnFinder, findsOneWidget);

      await tester.tap(startBtnFinder);
      await tester.pumpAndSettle();

      expect(started, isTrue);
    });

    testWidgets('FacResourceCell renders unlocked percentage and locked requirement', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          const Row(
            children: <Widget>[
              Expanded(
                child: FacResourceCell(
                  emoji: '💎',
                  name: 'Mavi Kristal',
                  percentLabel: '%35',
                  accentColor: AppColors.accentCyan,
                  locked: false,
                ),
              ),
              Expanded(
                child: FacResourceCell(
                  emoji: '🔮',
                  name: 'Karanlık Cevher',
                  percentLabel: '🔒 Lv.5',
                  accentColor: AppColors.cyberFuchsia,
                  locked: true,
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Mavi Kristal'), findsOneWidget);
      expect(find.text('%35'), findsOneWidget);
      expect(find.text('Karanlık Cevher'), findsOneWidget);
      expect(find.text('🔒 Lv.5'), findsOneWidget);
    });

    testWidgets('FacUpgradeStrip triggers upgrade callback', (WidgetTester tester) async {
      bool upgraded = false;

      await tester.pumpWidget(
        testHarness(
          FacUpgradeStrip(
            summary: 'Gelecek Seviye: Lv.4 • 120.000 Altın',
            buttonLabel: 'Yükselt',
            enabled: true,
            onUpgrade: () => upgraded = true,
          ),
        ),
      );

      expect(find.text('Gelecek Seviye: Lv.4 • 120.000 Altın'), findsOneWidget);
      await tester.tap(find.text('Yükselt'));
      await tester.pumpAndSettle();

      expect(upgraded, isTrue);
    });

    testWidgets('FacUpgradeStrip renders max level achieved state and disables button', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          FacUpgradeStrip(
            summary: 'Maksimum Seviyeye Ulaşıldı (Lv.10)',
            buttonLabel: 'Yükselt',
            enabled: false,
            onUpgrade: () {},
          ),
        ),
      );

      expect(find.text('Maksimum Seviyeye Ulaşıldı (Lv.10)'), findsOneWidget);
      expect(find.text('Yükselt'), findsOneWidget);
    });

    testWidgets('FacRaritySimulatorAccordion toggles level simulation', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          const FacRaritySimulatorAccordion(currentLevel: 1),
        ),
      );

      expect(find.text('Nadir Seviye İhtimal Simülasyonu'), findsOneWidget);
      expect(find.text('Mevcut Seviye'), findsOneWidget);

      // Tap Lv.3 to expand
      final lv3Finder = find.text('Lv.3');
      expect(lv3Finder, findsOneWidget);
      await tester.tap(lv3Finder);
      await tester.pumpAndSettle();

      expect(find.text('Lv.3'), findsOneWidget);
    });

    testWidgets('FacDepotRow renders resource item, rarity bar, and quantity pill', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          const FacDepotRow(
            label: 'Ham Demir • ⚪ Yaygın',
            quantity: 24,
            accentColor: AppColors.mutedTitanium,
          ),
        ),
      );

      expect(find.text('Ham Demir • ⚪ Yaygın'), findsOneWidget);
      expect(find.text('×24'), findsOneWidget);
    });

    testWidgets('FacEmptyState renders hero icon, title, subtitle, and return hint', (WidgetTester tester) async {
      await tester.pumpWidget(
        testHarness(
          const FacEmptyState(
            icon: '🔒',
            title: 'Tesis Kilitli',
            subtitle: 'Bu tesise erişmek için seviye gereksinimini tamamlayın.',
          ),
        ),
      );

      expect(find.text('🔒'), findsOneWidget);
      expect(find.text('Tesis Kilitli'), findsOneWidget);
      expect(find.text('Bu tesise erişmek için seviye gereksinimini tamamlayın.'), findsOneWidget);
      expect(find.text('← Geri tuşuyla tesis listesine dönebilirsiniz'), findsOneWidget);
    });
  });

  group('Facilities Dialogs', () {
    testWidgets('showFacConfirmDialog renders and responds to confirm/cancel', (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        testHarness(
          Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showFacConfirmDialog(
                    context,
                    title: 'YÜKSELTME ONAYI',
                    message: 'Seviye yükseltmek için 50.000 Altın harcanacak.',
                    icon: '⬆️',
                    highlight: '50.000 Altın',
                    confirmLabel: 'Yükselt',
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

      expect(find.text('YÜKSELTME ONAYI'), findsOneWidget);
      expect(find.text('50.000 Altın'), findsOneWidget);
      expect(find.text('Vazgeç'), findsOneWidget);
      expect(find.text('Yükselt'), findsOneWidget);

      await tester.tap(find.text('Yükselt'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('showFacUnlockDialog renders facility icon, name, formatted cost highlight, and returns true on Aç', (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        testHarness(
          Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showFacUnlockDialog(
                    context,
                    facilityName: 'Çiftlik',
                    facilityIcon: '🌾',
                    formattedCost: '200.000',
                  );
                },
                child: const Text('Open Unlock Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Unlock Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('🌾'), findsOneWidget);
      expect(find.text('Tesis Aç'), findsOneWidget);
      expect(find.text('200.000'), findsOneWidget);
      expect(find.text('Aç'), findsOneWidget);
      expect(find.text('Vazgeç'), findsOneWidget);

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('showFacBribeDialog renders gem highlight, target facility info, and returns true on Ver', (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        testHarness(
          Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showFacBribeDialog(
                    context,
                    facilityType: 'mining',
                    gemAmount: 15,
                  );
                },
                child: const Text('Open Bribe Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Bribe Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('💎'), findsOneWidget);
      expect(find.text('Rüşvet'), findsOneWidget);
      expect(find.text('15 Gem'), findsOneWidget);
      expect(find.text('Ver'), findsOneWidget);
      expect(find.text('Vazgeç'), findsOneWidget);

      await tester.tap(find.text('Ver'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('showFacUpgradeDialog renders facility name, target level, formatted cost, and returns true on Yükselt', (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        testHarness(
          Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showFacUpgradeDialog(
                    context,
                    facilityName: 'Maden Ocağı',
                    targetLevel: 4,
                    formattedCost: '150.000',
                  );
                },
                child: const Text('Open Upgrade Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Upgrade Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('⬆️'), findsOneWidget);
      expect(find.text('Yükselt'), findsWidgets);
      expect(find.text('150.000'), findsOneWidget);
      expect(find.text('Vazgeç'), findsOneWidget);

      // Find the confirm button in dialog (the second 'Yükselt')
      final upgradeConfirmBtn = find.widgetWithText(ElevatedButton, 'Open Upgrade Dialog');
      expect(upgradeConfirmBtn, findsOneWidget);

      final confirmFinder = find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Yükselt'),
      );
      expect(confirmFinder, findsOneWidget);

      await tester.tap(confirmFinder);
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });

  group('FacilitiesScreen Full AAA Mobile Render & States', () {
    testWidgets('FacilitiesScreen renders loading indicator when status is loading', (WidgetTester tester) async {
      await tester.pumpWidget(
        screenTestHarness(
          facilitiesState: const FacilitiesState(
            status: FacilitiesStatus.loading,
            facilities: <PlayerFacility>[],
            productionPreviews: <String, FacilityProductionPreview>{},
            isMutating: false,
          ),
          child: const FacilitiesScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('FacilitiesScreen renders error panel with retry when status is error', (WidgetTester tester) async {
      await tester.pumpWidget(
        screenTestHarness(
          facilitiesState: const FacilitiesState(
            status: FacilitiesStatus.error,
            facilities: <PlayerFacility>[],
            productionPreviews: <String, FacilityProductionPreview>{},
            isMutating: false,
            errorMessage: 'Veritabanı bağlantı hatası',
          ),
          child: const FacilitiesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tesisler Yüklenemedi'), findsOneWidget);
      expect(find.text('Veritabanı bağlantı hatası'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);
    });

    testWidgets('FacilitiesScreen renders prison banner when player is detained in prison', (WidgetTester tester) async {
      await tester.pumpWidget(
        screenTestHarness(
          profile: createTestPlayerProfile(
            prisonUntil: '2099-01-01T00:00:00Z',
            prisonReason: 'Kaçak üretim baskını',
          ),
          facilitiesState: const FacilitiesState(
            status: FacilitiesStatus.ready,
            facilities: <PlayerFacility>[],
            productionPreviews: <String, FacilityProductionPreview>{},
            isMutating: false,
          ),
          child: const FacilitiesScreen(),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('CEZAEVİ — OPERASYONLAR KİLİTLİ'), findsOneWidget);
      expect(find.text('Kaçak üretim baskını'), findsOneWidget);
    });

    testWidgets('FacilitiesScreen renders full hub in ready state: GameTopBar, revenue hero card, filter bar, and tier sections with facility upgrade tiles', (WidgetTester tester) async {
      final facilitiesState = FacilitiesState(
        status: FacilitiesStatus.ready,
        facilities: <PlayerFacility>[
          const PlayerFacility(
            id: 'fac-mining-1',
            facilityType: 'mining',
            level: 3,
            suspicion: 20,
            isActive: true,
            productionStartedAt: '2026-10-29T00:00:00Z',
            facilityQueue: <FacilityQueueItem>[],
          ),
          const PlayerFacility(
            id: 'fac-quarry-1',
            facilityType: 'quarry',
            level: 2,
            suspicion: 10,
            isActive: true,
            productionStartedAt: null,
            facilityQueue: <FacilityQueueItem>[
              FacilityQueueItem(
                id: 'q-1',
                quantity: 4,
                rarity: 'common',
                startedAt: '2026-10-29T00:00:00Z',
                completesAt: '2026-10-29T00:01:00Z',
                isCompleted: true,
              ),
            ],
          ),
        ],
        productionPreviews: const <String, FacilityProductionPreview>{},
        isMutating: false,
      );

      await tester.pumpWidget(
        screenTestHarness(
          profile: createTestPlayerProfile(
            level: 20,
            gold: 800000,
            gems: 100,
            globalSuspicion: 45,
          ),
          facilitiesState: facilitiesState,
          child: const FacilitiesScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Tesisler'), findsWidgets);
      expect(find.text('GENEL ŞÜPHE'), findsOneWidget);
      expect(find.text('%45'), findsOneWidget);
      expect(find.text('TESİS GELİR & YÖNETİM MERKEZİ'), findsOneWidget);
      expect(find.text('TAHMİNİ GELİR'), findsOneWidget);
      expect(find.text('AKTİF ÜRETİM'), findsOneWidget);
      expect(find.text('HAZIR TESLİMAT'), findsOneWidget);
      expect(find.text('Maden Ocağı'), findsOneWidget);
      expect(find.text('Taş Ocağı'), findsOneWidget);
    });

    testWidgets('FacilitiesScreen filter tabs filter facilities by category (Kademe 1, 2, 3)', (WidgetTester tester) async {
      final facilitiesState = FacilitiesState(
        status: FacilitiesStatus.ready,
        facilities: <PlayerFacility>[
          const PlayerFacility(
            id: 'fac-mining-1',
            facilityType: 'mining',
            level: 1,
            suspicion: 0,
            isActive: true,
            productionStartedAt: null,
            facilityQueue: <FacilityQueueItem>[],
          ),
        ],
        productionPreviews: const <String, FacilityProductionPreview>{},
        isMutating: false,
      );

      await tester.pumpWidget(
        screenTestHarness(
          profile: createTestPlayerProfile(level: 25, gold: 500000),
          facilitiesState: facilitiesState,
          child: const FacilitiesScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Tap Kademe 2 tab
      final kademe2Tab = find.text('Kademe 2');
      expect(kademe2Tab, findsOneWidget);
      await tester.tap(kademe2Tab);
      await tester.pumpAndSettle();

      // In Kademe 2, Çiftlik (farming) is present
      expect(find.text('Çiftlik'), findsOneWidget);
      // Maden Ocağı (tier 1) should no longer be present
      expect(find.text('Maden Ocağı'), findsNothing);

      // Tap Kademe 3 tab
      final kademe3Tab = find.text('Kademe 3');
      expect(kademe3Tab, findsOneWidget);
      await tester.tap(kademe3Tab);
      await tester.pumpAndSettle();

      // In Kademe 3, Rune Madeni is present
      expect(find.text('Rune Madeni'), findsOneWidget);
      expect(find.text('Çiftlik'), findsNothing);
    });

    testWidgets('FacilitiesScreen status filters filter facilities by unlocked/canUnlock/locked states', (WidgetTester tester) async {
      final facilitiesState = FacilitiesState(
        status: FacilitiesStatus.ready,
        facilities: <PlayerFacility>[
          const PlayerFacility(
            id: 'fac-mining-1',
            facilityType: 'mining',
            level: 3,
            suspicion: 10,
            isActive: true,
            productionStartedAt: null,
            facilityQueue: <FacilityQueueItem>[],
          ),
        ],
        productionPreviews: const <String, FacilityProductionPreview>{},
        isMutating: false,
      );

      await tester.pumpWidget(
        screenTestHarness(
          profile: createTestPlayerProfile(level: 2, gold: 100000),
          facilitiesState: facilitiesState,
          child: const FacilitiesScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Tap 'Açık' filter chip
      final openFilter = find.text('Açık');
      expect(openFilter, findsOneWidget);
      await tester.tap(openFilter);
      await tester.pumpAndSettle();

      // Maden Ocağı is unlocked
      expect(find.text('Maden Ocağı'), findsOneWidget);

      // Tap 'Kilitli' filter chip
      final lockedFilter = find.text('Kilitli');
      expect(lockedFilter, findsOneWidget);
      await tester.tap(lockedFilter);
      await tester.pumpAndSettle();

      // Maden Ocağı is unlocked, so should not show up under locked
      expect(find.text('Maden Ocağı'), findsNothing);
    });
  });
}
