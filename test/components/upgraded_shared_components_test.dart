import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/character/character_combat_stats_panel.dart';
import 'package:gkk_flutter/components/character/character_health_panel.dart';
import 'package:gkk_flutter/components/character/stat_allocation_panel.dart';
import 'package:gkk_flutter/components/comeback/comeback.dart';
import 'package:gkk_flutter/components/common/cosmetic_title_badge.dart';
import 'package:gkk_flutter/components/common/gkk_badge.dart';
import 'package:gkk_flutter/components/common/gkk_progress_bar.dart';
import 'package:gkk_flutter/components/common/player_health_bar.dart';
import 'package:gkk_flutter/components/pvp/colosseum_arena_lighting.dart';
import 'package:gkk_flutter/models/comeback_summary_model.dart';
import 'package:gkk_flutter/models/player_model.dart';

// ── Test Helpers & Mock Fixtures ─────────────────────────────────────────────

PlayerProfile _buildTestProfile({
  int health = 1000,
  int maxHealth = 1000,
  int energy = 80,
  int maxEnergy = 100,
  int pvpWins = 25,
  int pvpRating = 1200,
  int statPoints = 15,
  int attack = 350,
  int defense = 280,
  int luck = 60,
  int power = 15000,
  int reputation = 2500,
  String? hospitalUntil,
  String? prisonUntil,
}) {
  return PlayerProfile(
    id: 'test_player_id',
    authId: 'test_auth_id',
    username: 'DaevaHero',
    email: 'daeva@aion.test',
    displayName: 'DaevaHero',
    avatarUrl: null,
    avatarFrame: 'glow',
    level: 30,
    xp: 50000,
    gold: 10000,
    gems: 50,
    energy: energy,
    maxEnergy: maxEnergy,
    attack: attack,
    defense: defense,
    health: health,
    maxHealth: maxHealth,
    power: power,
    isOnline: true,
    isBanned: false,
    tutorialCompleted: true,
    guildId: null,
    guildRole: null,
    guildName: null,
    characterClass: CharacterClass.warrior,
    reputation: reputation,
    statPoints: statPoints,
    pvpWins: pvpWins,
    pvpLosses: 5,
    pvpRating: pvpRating,
    tolerance: 0,
    addictionLevel: 0,
    referralCode: null,
    referredBy: null,
    lastPotionUsedAt: null,
    warriorBloodlustUntil: null,
    hospitalUntil: hospitalUntil,
    prisonUntil: prisonUntil,
    prisonReason: null,
    globalSuspicionLevel: 0,
    lastBribeAt: null,
    lastLoginAt: '2026-10-28T00:00:00Z',
    lastLogin: null,
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-10-28T00:00:00Z',
  );
}

ComebackSummary _buildTestComebackSummary({
  double offlineHours = 74.0,
  int pendingCount = 2,
}) {
  return ComebackSummary(
    showSummary: true,
    offlineHours: offlineHours,
    pendingCount: pendingCount,
    items: const <ComebackSummaryItem>[
      ComebackSummaryItem(
        id: 'item_1',
        kind: ComebackItemKind.boxReady,
        title: 'Kutu Açılmaya Hazır',
        subtitle: 'Bronz sandık kilit açma tamamlandı',
        route: '/inventory',
        priority: 1,
        ctaLabel: 'Sandığa Git',
      ),
      ComebackSummaryItem(
        id: 'item_2',
        kind: ComebackItemKind.facilityReady,
        title: 'Tesis Üretimi Tamam',
        subtitle: 'Simya laboratuvarı iksirleri hazır',
        route: '/facility',
        priority: 2,
        ctaLabel: 'Topla',
      ),
    ],
  );
}

// ── Main Test Suite ──────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 1: ComebackRewardsPortal & Returning Warrior Shared Components
  // ═══════════════════════════════════════════════════════════════════════════
  group('ComebackRewardsPortal & Returning Warrior Shared Components', () {
    testWidgets('ComebackRewardsPortal renders responsive mobile layout with bounds constraints (390x844)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ComebackSummary summary = _buildTestComebackSummary();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComebackRewardsPortal(summary: summary),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Header and design tokens
      expect(find.text('Geri Dönen Savaşçı'), findsOneWidget);
      expect(find.text('2027 AION 2'), findsOneWidget);
      expect(find.text('Aion 2 Özel Karşılama Portalı'), findsOneWidget);

      // Offline greeting message for 74 hours (3 days)
      expect(find.textContaining('3 gündür Atreia\'dan uzaktaydın'), findsOneWidget);

      // Subcomponents rendered inside portal
      expect(find.byType(ComebackBuffBadge), findsOneWidget);
      expect(find.byType(ComebackGiftCard), findsOneWidget);
      expect(find.byType(ComebackMilestoneTrack), findsOneWidget);
      expect(find.text('YOKLUĞUNDA GERÇEKLEŞENLER'), findsOneWidget);
      expect(find.text('Kutu Açılmaya Hazır'), findsOneWidget);
      expect(find.text('Tesis Üretimi Tamam'), findsOneWidget);
      expect(find.text('Atreia\'ya Dönüş Yap'), findsOneWidget);

      // Verify ConstrainedBox constraints (maxWidth: 440, maxHeight: 90% viewport)
      final Finder boxFinder = find.byWidgetPredicate(
        (Widget widget) => widget is ConstrainedBox && widget.constraints.maxWidth == 440.0,
      );
      expect(boxFinder, findsOneWidget);
      final ConstrainedBox constrainedBox = tester.widget<ConstrainedBox>(boxFinder);
      expect(constrainedBox.constraints.maxWidth, equals(440.0));
      expect(constrainedBox.constraints.maxHeight, closeTo(844.0 * 0.90, 0.01));

      expect(tester.takeException(), isNull);
    });

    testWidgets('ComebackRewardsPortal triggers onClose via top-bar close icon button', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool closed = false;
      final ComebackSummary summary = _buildTestComebackSummary();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComebackRewardsPortal(
              summary: summary,
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final Finder closeButton = find.byIcon(Icons.close_rounded);
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('ComebackRewardsPortal triggers onClose via footer CTA button', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool closed = false;
      final ComebackSummary summary = _buildTestComebackSummary();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComebackRewardsPortal(
              summary: summary,
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Atreia\'ya Dönüş Yap'));
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('ComebackRewardsPortal pending actions dispatches onActionItemTap callback', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      ComebackSummaryItem? tappedItem;
      final ComebackSummary summary = _buildTestComebackSummary();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComebackRewardsPortal(
              summary: summary,
              onActionItemTap: (ComebackSummaryItem item) => tappedItem = item,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Kutu Açılmaya Hazır'), findsOneWidget);
      await tester.tap(find.text('Kutu Açılmaya Hazır'));
      await tester.pump();

      expect(tappedItem, isNotNull);
      expect(tappedItem!.id, equals('item_1'));
      expect(tappedItem!.kind, equals(ComebackItemKind.boxReady));
    });

    testWidgets('ComebackRewardsPortal gift card claim updates internal state & triggers onClaimGift', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool giftClaimed = false;
      final ComebackSummary summary = _buildTestComebackSummary();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComebackRewardsPortal(
              summary: summary,
              onClaimGift: () => giftClaimed = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final Finder claimGiftFinder = find.text('Paketi Al');
      expect(claimGiftFinder, findsOneWidget);

      await tester.tap(claimGiftFinder);
      await tester.pump(const Duration(milliseconds: 150));

      expect(giftClaimed, isTrue);
      expect(find.text('Alındı ✓'), findsOneWidget);
    });

    testWidgets('ComebackRewardsPortal milestone claim updates internal state & triggers onClaimMilestone', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      ComebackMilestoneTier? claimedTier;
      final ComebackSummary summary = _buildTestComebackSummary();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComebackRewardsPortal(
              summary: summary,
              currentDay: 1,
              onClaimMilestone: (ComebackMilestoneTier tier) => claimedTier = tier,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final Finder claimMilestoneButton = find.text('Al');
      expect(claimMilestoneButton, findsOneWidget);

      await tester.tap(claimMilestoneButton);
      await tester.pump(const Duration(milliseconds: 150));

      expect(claimedTier, isNotNull);
      expect(claimedTier!.day, equals(1));
    });

    testWidgets('ComebackRewardsPortal adapts greeting message across offline duration tiers', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Tier 1: >= 24 hours (e.g. 48h -> 2 days)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComebackRewardsPortal(
              summary: _buildTestComebackSummary(offlineHours: 48.0),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('2 gündür Atreia\'dan uzaktaydın'), findsOneWidget);

      // Tier 2: 1 to 23 hours (e.g. 5.5h -> 5 hours)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComebackRewardsPortal(
              summary: _buildTestComebackSummary(offlineHours: 5.5),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('5 saattir uzaktaydın'), findsOneWidget);

      // Tier 3: < 1 hour (e.g. 0.4h -> short break)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComebackRewardsPortal(
              summary: _buildTestComebackSummary(offlineHours: 0.4),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.textContaining('Kısa bir aradan sonra tekrar hoş geldin'),
        findsOneWidget,
      );
    });

    testWidgets('ComebackBuffBadge renders in expanded and compact modes with boost telemetry', (
      WidgetTester tester,
    ) async {
      final ComebackBuffInfo buff = ComebackBuffInfo.defaultBuff();

      // Expanded mode
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: ComebackBuffBadge(buffInfo: buff, compact: false),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Geri Dönen Savaşçı Kutsaması'), findsOneWidget);
      expect(find.text('AKTİF BUFF'), findsOneWidget);
      expect(find.text('+20% EXP'), findsOneWidget);
      expect(find.text('+15% Altın'), findsOneWidget);
      expect(find.text('+10% Drop'), findsOneWidget);

      // Compact mode
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                child: ComebackBuffBadge(buffInfo: buff, compact: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('+20% EXP'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    });

    testWidgets('ComebackGiftCard displays reward items and handles standalone claim interaction', (
      WidgetTester tester,
    ) async {
      bool claimed = false;
      final ComebackGiftCardData cardData =
          ComebackGiftCardData.defaultForOffline(offlineHours: 48);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: ComebackGiftCard(
                  data: cardData,
                  onClaim: () => claimed = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Efsanevi Geri Dönüş Paketi'), findsOneWidget);
      expect(find.text('Elmas Kesesi'), findsOneWidget);
      expect(find.text('Paketi Al'), findsOneWidget);

      await tester.tap(find.text('Paketi Al'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(claimed, isTrue);
      expect(find.text('Alındı ✓'), findsOneWidget);
    });

    testWidgets('ComebackMilestoneTrack displays 7 tiers and invokes onClaimTier callback', (
      WidgetTester tester,
    ) async {
      ComebackMilestoneTier? claimedTier;
      final List<ComebackMilestoneTier> track =
          ComebackMilestoneTier.generateDefaultTrack(currentProgressDay: 2);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: ComebackMilestoneTrack(
                  tiers: track,
                  currentDay: 2,
                  onClaimTier: (ComebackMilestoneTier tier) => claimedTier = tier,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('7 Günlük Geri Dönüş Yolu'), findsOneWidget);
      expect(find.text('1. Gün'), findsOneWidget);
      expect(find.text('2. Gün'), findsOneWidget);
      expect(find.text('7. Gün'), findsOneWidget);

      // Day 2 is ready to claim
      final Finder claimBtn = find.text('Al');
      expect(claimBtn, findsOneWidget);

      await tester.tap(claimBtn);
      await tester.pump(const Duration(milliseconds: 150));

      expect(claimedTier, isNotNull);
      expect(claimedTier!.day, equals(2));
    });

    testWidgets('ComebackParticleBurst controller triggers particle burst without error', (
      WidgetTester tester,
    ) async {
      final ComebackParticleBurstController burstCtrl =
          ComebackParticleBurstController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: ComebackParticleBurst(
                controller: burstCtrl,
                particleCount: 25,
                child: const Text('Child Center'),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Child Center'), findsOneWidget);

      burstCtrl.burst(count: 20);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 2: Character Combat Stats & Health Panels (Aion 2 Obsidian-Glass)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Character Combat Stats & Health Panels (Aion 2 Obsidian-Glass)', () {
    testWidgets('CharacterCombatStatsPanel renders CP aura badge, tier calculations, and telemetry stats', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CharacterCombatStatsPanel(
                power: '15.000',
                health: 950,
                maxHealth: 1000,
                attack: '450',
                defense: '320',
                luck: '75',
                luckSubtitle: 'baz 60',
                pvpWinRate: '%83',
                pvpRating: '1450',
                reputation: 2500,
                initiallyExpanded: true,
                highlightPowerAnchor: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // CP Aura Insignia Badge
      expect(find.text('SAVAŞ GÜCÜ (CP)'), findsOneWidget);
      expect(find.text('15.000'), findsOneWidget);
      expect(find.text('TIER S · ŞAMPİYON'), findsOneWidget);

      // Section titles
      expect(find.text('TAARRUZ & BÜYÜ (OFFENSE)'), findsOneWidget);
      expect(find.text('SAVUNMA & DİRENÇ (DEFENSE)'), findsOneWidget);
      expect(find.text('PVP VE DAEVA İTİBARI'), findsOneWidget);

      // Core attributes
      expect(find.text('Fiziksel Saldırı'), findsOneWidget);
      expect(find.text('Büyü Saldırısı'), findsOneWidget);
      expect(find.text('Savunma Gücü'), findsOneWidget);
      expect(find.text('Kaçınma / Çeviklik'), findsOneWidget);
      expect(find.text('Şans (Kader)'), findsOneWidget);
      expect(find.text('PvP Kazanma'), findsOneWidget);
      expect(find.text('PvP Rating'), findsOneWidget);
      expect(find.textContaining('İtibar:'), findsOneWidget);
    });

    testWidgets('CharacterCombatStatsPanel filters attributes via tactical category switcher', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CharacterCombatStatsPanel(
                power: '12.000',
                health: 800,
                maxHealth: 1000,
                attack: '400',
                defense: '300',
                luck: '50',
                pvpWinRate: '%70',
                pvpRating: '1300',
                initiallyExpanded: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to TAARRUZ (Offense)
      await tester.tap(find.text('TAARRUZ'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('TAARRUZ & BÜYÜ (OFFENSE)'), findsOneWidget);
      expect(find.text('SAVUNMA & DİRENÇ (DEFENSE)'), findsNothing);
      expect(find.text('PVP VE DAEVA İTİBARI'), findsNothing);

      // Switch to SAVUNMA (Defense)
      await tester.tap(find.text('SAVUNMA'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SAVUNMA & DİRENÇ (DEFENSE)'), findsOneWidget);
      expect(find.text('TAARRUZ & BÜYÜ (OFFENSE)'), findsNothing);
      expect(find.text('PVP VE DAEVA İTİBARI'), findsNothing);

      // Switch to DAEVA & PVP (Prestige)
      await tester.tap(find.text('DAEVA & PVP'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('PVP VE DAEVA İTİBARI'), findsOneWidget);
      expect(find.text('TAARRUZ & BÜYÜ (OFFENSE)'), findsNothing);
      expect(find.text('SAVUNMA & DİRENÇ (DEFENSE)'), findsNothing);

      // Switch back to TÜMÜ (All)
      await tester.tap(find.text('TÜMÜ'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('TAARRUZ & BÜYÜ (OFFENSE)'), findsOneWidget);
      expect(find.text('SAVUNMA & DİRENÇ (DEFENSE)'), findsOneWidget);
      expect(find.text('PVP VE DAEVA İTİBARI'), findsOneWidget);
    });

    testWidgets('CharacterCombatStatsPanel collapsible header toggles body visibility', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CharacterCombatStatsPanel(
                power: '5.200',
                health: 500,
                maxHealth: 500,
                attack: '200',
                defense: '150',
                luck: '30',
                pvpWinRate: '%60',
                pvpRating: '1100',
                initiallyExpanded: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Fiziksel Saldırı'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('Gelişim & Savaş İstatistikleri'));
      await tester.pump(const Duration(milliseconds: 350));

      // CP badge remains visible, detailed stats are collapsed
      expect(find.text('SAVAŞ GÜCÜ (CP)'), findsOneWidget);
      expect(find.text('Fiziksel Saldırı'), findsNothing);

      // Tap header to re-expand
      await tester.tap(find.text('Gelişim & Savaş İstatistikleri'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Fiziksel Saldırı'), findsOneWidget);
    });

    testWidgets('CharacterHealthPanel displays segmented HP/MP/DP vitals and handles low-health critical warning', (
      WidgetTester tester,
    ) async {
      // Normal healthy profile
      final PlayerProfile healthyProfile = _buildTestProfile(
        health: 800,
        maxHealth: 1000,
        energy: 60,
        maxEnergy: 100,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CharacterHealthPanel(profile: healthyProfile),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('YAŞAMSAL GÖSTERGELER'), findsOneWidget);
      expect(find.text('AİON 2 SAVAŞ & BİYOMETRİK VERİLERİ'), findsOneWidget);
      expect(find.text('HP (Sağlık)'), findsOneWidget);
      expect(find.text('MP (Mana / Enerji)'), findsOneWidget);
      expect(find.text('DP (Divine Power · İlahi Güç)'), findsOneWidget);
      expect(find.textContaining('800 / 1000'), findsOneWidget);
      expect(find.textContaining('60 / 100'), findsOneWidget);
      expect(find.text('İksirler'), findsOneWidget);

      // Critical low-health profile (< 25% health, e.g. 200/1000)
      final PlayerProfile criticalProfile = _buildTestProfile(
        health: 200,
        maxHealth: 1000,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CharacterHealthPanel(profile: criticalProfile),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('KRİTİK CAN · ACİL MÜDAHALE GEREKİYOR'),
        findsOneWidget,
      );
    });

    testWidgets('CharacterHealthPanel displays restriction buttons for hospital and prison', (
      WidgetTester tester,
    ) async {
      final PlayerProfile hospitalProfile = _buildTestProfile(
        health: 300,
        maxHealth: 1000,
        hospitalUntil: DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CharacterHealthPanel(
                profile: hospitalProfile,
                inHospital: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Hastane'), findsOneWidget);

      final PlayerProfile prisonProfile = _buildTestProfile(
        health: 500,
        maxHealth: 1000,
        prisonUntil: DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CharacterHealthPanel(
                profile: prisonProfile,
                inPrison: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Hapishane'), findsOneWidget);
    });

    testWidgets('StatAllocationPanel allows +/-1 and +/-10 adjustments with real-time CP preview and reset', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatAllocationPanel(availablePoints: 20),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Available points badge
      expect(find.text('20 puan'), findsOneWidget);
      expect(find.text('Stat Puanı Dağıt'), findsOneWidget);

      // Four stat rows
      expect(find.text('Saldırı'), findsOneWidget);
      expect(find.text('Savunma'), findsOneWidget);
      expect(find.text('Şans'), findsOneWidget);
      expect(find.text('Can'), findsOneWidget);
      expect(find.text('Puan Seçimi Yapın'), findsOneWidget);

      // Tap +10 on Attack (first +10 button)
      final Finder plus10Buttons = find.text('+10');
      expect(plus10Buttons, findsNWidgets(4));

      await tester.tap(plus10Buttons.at(0));
      await tester.pump(const Duration(milliseconds: 100));

      // 10 allocated to attack, 10 remaining
      expect(find.text('10 puan'), findsOneWidget);
      expect(find.textContaining('Tahmini Güç Artışı:'), findsOneWidget);
      expect(find.text('Sıfırla'), findsOneWidget);
      expect(find.textContaining('Değişiklikleri Onayla (+10 Puan)'), findsOneWidget);

      // Tap +1 on Can (4th +1 icon button)
      final Finder addButtons = find.byIcon(Icons.add_rounded);
      expect(addButtons, findsNWidgets(4));

      await tester.tap(addButtons.at(3));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('9 puan'), findsOneWidget);
      expect(find.textContaining('Değişiklikleri Onayla (+11 Puan)'), findsOneWidget);

      // Tap Sıfırla (Reset)
      await tester.tap(find.text('Sıfırla'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('20 puan'), findsOneWidget);
      expect(find.text('Puan Seçimi Yapın'), findsOneWidget);
      expect(find.text('Sıfırla'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 3: Colosseum Arena Lighting & Shadow Physics (PVP Atmospheric Systems)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Colosseum Arena Lighting & Shadow Physics (PVP Atmospheric Systems)', () {
    test('ArenaLightingTheme presets initialize with correct atmospheric properties', () {
      final ArenaLightingTheme sanctum = ArenaLightingTheme.sanctumCelestial();
      expect(sanctum.name, 'Sanctum Göksel Meydanı');
      expect(sanctum.sunElevation, greaterThan(1.0));
      expect(sanctum.sunIntensity, inInclusiveRange(0.0, 1.0));
      expect(sanctum.beamCount, equals(6));
      expect(sanctum.dustMoteCount, equals(30));

      final ArenaLightingTheme abyss = ArenaLightingTheme.abyssalEclipse();
      expect(abyss.name, 'Uçurum Gladyatör Arenası');
      expect(abyss.sunElevation, lessThan(0.7)); // Low sun angle for dramatic shadows
      expect(abyss.beamCount, equals(7));

      final ArenaLightingTheme obsidian = ArenaLightingTheme.obsidianChasm();
      expect(obsidian.name, 'Obsidiyen Çukur Koloseumu');
      expect(obsidian.beamCount, equals(5));

      final ArenaLightingTheme dawn = ArenaLightingTheme.dawnGladiator();
      expect(dawn.name, 'Şafak Gladyatör Koloseumu');
      expect(dawn.sunElevation, closeTo(0.45, 0.05));

      final ArenaLightingTheme crimson = ArenaLightingTheme.crimsonBattle();
      expect(crimson.name, 'Aion Obsidiyen Kan Arenası');
      expect(crimson.sunIntensity, greaterThanOrEqualTo(0.95));
      expect(crimson.beamCount, equals(8));
    });

    test('ArenaLightingTheme.fromAtmosphere covers all ColosseumAtmosphere values', () {
      for (final ColosseumAtmosphere atmosphere in ColosseumAtmosphere.values) {
        final ArenaLightingTheme theme = ArenaLightingTheme.fromAtmosphere(atmosphere);
        expect(theme.name, isNotEmpty);
        expect(theme.sunIntensity, inInclusiveRange(0.0, 1.0));
        expect(theme.beamCount, greaterThan(0));
        expect(theme.dustMoteCount, greaterThan(0));
        expect(theme.spotlightFalloff, greaterThan(0.0));
      }
    });

    test('Directional shadow projection cotangent math responds to sun elevation', () {
      final ArenaLightingTheme lowSun = ArenaLightingTheme.abyssalEclipse(); // 0.55 rad
      final ArenaLightingTheme highSun = ArenaLightingTheme.sanctumCelestial(); // 1.15 rad

      final double cotLow = 1.0 / math.tan(lowSun.sunElevation);
      final double cotHigh = 1.0 / math.tan(highSun.sunElevation);

      // Low sun creates significantly longer cast shadows on floor
      expect(cotLow, greaterThan(cotHigh));
      expect(cotLow / cotHigh, greaterThan(2.0));
    });

    test('ArenaLightingTheme.lerp smoothly blends lighting parameters', () {
      final ArenaLightingTheme themeA = ArenaLightingTheme.sanctumCelestial();
      final ArenaLightingTheme themeB = ArenaLightingTheme.abyssalEclipse();

      final ArenaLightingTheme lerp0 = ArenaLightingTheme.lerp(themeA, themeB, 0.0);
      expect(lerp0.name, equals(themeA.name));
      expect(lerp0.sunElevation, equals(themeA.sunElevation));

      final ArenaLightingTheme lerp1 = ArenaLightingTheme.lerp(themeA, themeB, 1.0);
      expect(lerp1.name, equals(themeB.name));
      expect(lerp1.sunElevation, equals(themeB.sunElevation));

      final ArenaLightingTheme lerpHalf = ArenaLightingTheme.lerp(themeA, themeB, 0.5);
      expect(
        lerpHalf.sunElevation,
        closeTo((themeA.sunElevation + themeB.sunElevation) / 2.0, 0.001),
      );
    });

    testWidgets('ColosseumArenaLighting renders custom painter with gladiator shadow slots', (
      WidgetTester tester,
    ) async {
      final ArenaLightingTheme theme = ArenaLightingTheme.crimsonBattle();
      const List<GladiatorShadowSlot> slots = <GladiatorShadowSlot>[
        GladiatorShadowSlot(
          position: Offset(0.3, 0.6),
          height: 70.0,
          width: 32.0,
        ),
        GladiatorShadowSlot(
          position: Offset(0.7, 0.6),
          height: 70.0,
          width: 32.0,
          lungeOffset: Offset(6, -3),
          hitShake: 0.4,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColosseumArenaLighting(
              theme: theme,
              height: 280.0,
              gladiatorSlots: slots,
              combatFlash: 0.5,
              enablePreload: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ColosseumArenaLighting), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('ColosseumArenaLighting atmosphere HUD buttons switch theme & fire callback', (
      WidgetTester tester,
    ) async {
      ColosseumAtmosphere? selectedAtmosphere;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColosseumArenaLighting(
              theme: ArenaLightingTheme.sanctumCelestial(),
              height: 320.0,
              showAtmosphereHud: true,
              enablePreload: false,
              onAtmosphereChanged: (ColosseumAtmosphere a) => selectedAtmosphere = a,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sanctum'), findsOneWidget);
      expect(find.text('Abyss'), findsOneWidget);
      expect(find.text('Obsidian'), findsOneWidget);
      expect(find.text('Dawn'), findsOneWidget);
      expect(find.text('Crimson'), findsOneWidget);

      await tester.tap(find.text('Abyss'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(selectedAtmosphere, equals(ColosseumAtmosphere.abyssalEclipse));

      await tester.tap(find.text('Obsidian'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(selectedAtmosphere, equals(ColosseumAtmosphere.obsidianChasm));
    });

    test('ColosseumArenaPainter.shouldRepaint detects animation and theme updates', () {
      final ArenaLightingTheme themeA = ArenaLightingTheme.sanctumCelestial();
      final ArenaLightingTheme themeB = ArenaLightingTheme.abyssalEclipse();

      final ColosseumArenaPainter painterA = ColosseumArenaPainter(
        animationProgress: 0.1,
        theme: themeA,
      );
      final ColosseumArenaPainter painterSame = ColosseumArenaPainter(
        animationProgress: 0.1,
        theme: themeA,
      );
      final ColosseumArenaPainter painterProgress = ColosseumArenaPainter(
        animationProgress: 0.6,
        theme: themeA,
      );
      final ColosseumArenaPainter painterTheme = ColosseumArenaPainter(
        animationProgress: 0.1,
        theme: themeB,
      );

      expect(painterA.shouldRepaint(painterSame), isFalse);
      expect(painterA.shouldRepaint(painterProgress), isTrue);
      expect(painterA.shouldRepaint(painterTheme), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 4: Shared Common UI Design System Components
  // ═══════════════════════════════════════════════════════════════════════════
  group('Shared Common UI Design System Components', () {
    testWidgets('PlayerHealthBar renders health ratio, clamps values, and displays critical alert', (
      WidgetTester tester,
    ) async {
      // 1. Healthy state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerHealthBar(
              health: 800,
              maxHealth: 1000,
              showLabel: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Can 800/1000'), findsOneWidget);
      expect(find.text('PvP için yetersiz'), findsNothing);

      // Verify LinearProgressIndicator fraction
      final Finder healthyIndicator = find.byType(LinearProgressIndicator);
      expect(healthyIndicator, findsOneWidget);
      final LinearProgressIndicator healthyWidget =
          tester.widget<LinearProgressIndicator>(healthyIndicator);
      expect(healthyWidget.value, closeTo(0.8, 0.001));

      // 2. Critical state (< 20% health floor)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerHealthBar(
              health: 150,
              maxHealth: 1000,
              showLabel: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Can 150/1000'), findsOneWidget);
      expect(find.text('PvP için yetersiz'), findsOneWidget);

      // 3. Clamping boundary checks: negative or 0 health
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerHealthBar(
              health: -50,
              maxHealth: 1000,
            ),
          ),
        ),
      );
      await tester.pump();

      final LinearProgressIndicator zeroWidget =
          tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(zeroWidget.value, equals(0.0));

      // Over-maximum clamping check
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerHealthBar(
              health: 1500,
              maxHealth: 1000,
            ),
          ),
        ),
      );
      await tester.pump();

      final LinearProgressIndicator overflowWidget =
          tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(overflowWidget.value, equals(1.0));
    });

    testWidgets('PlayerHealthBar compact mode formats text without "Can " prefix', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerHealthBar(
              health: 500,
              maxHealth: 1000,
              compactLabel: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('500/1000'), findsOneWidget);
      expect(find.text('Can 500/1000'), findsNothing);
    });

    testWidgets('GkkProgressBar clamps progress value and renders label/sublabel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GkkProgressBar(
              value: 0.65,
              label: 'Deneyim (XP)',
              sublabel: '650 / 1000',
              color: Color(0xFF00E5FF),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Deneyim (XP)'), findsOneWidget);
      expect(find.text('650 / 1000'), findsOneWidget);
      expect(find.byType(GkkProgressBar), findsOneWidget);

      // Clamping test with over 1.0 and under 0.0 values
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GkkProgressBar(value: 1.5),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('GkkBadge renders small and standard variants with custom colors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                GkkBadge(text: '⚔️ Gladyatör', color: Color(0xFFE5C158), small: false),
                GkkBadge(text: '🛡️ Muhafız', color: Color(0xFF00E5FF), small: true),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('⚔️ Gladyatör'), findsOneWidget);
      expect(find.text('🛡️ Muhafız'), findsOneWidget);
    });

    testWidgets('CosmeticTitleBadge renders liquid-gold chip for known titles and shrinks for empty/null', (
      WidgetTester tester,
    ) async {
      // 1. Valid cosmetic title: 'onur_nisani'
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CosmeticTitleBadge(titleKey: 'onur_nisani'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Onur Nişanı'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);

      // 2. Valid cosmetic title: 'kodex_ustasi'
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CosmeticTitleBadge(titleKey: 'kodex_ustasi', compact: true),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Kodex Ustası'), findsOneWidget);

      // 3. Null or empty cosmetic title key -> renders SizedBox.shrink()
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CosmeticTitleBadge(titleKey: null),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CosmeticTitleBadge(titleKey: '   '),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);
    });
  });
}
