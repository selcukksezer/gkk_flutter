import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/components/character/character_combat_stats_panel.dart';
import 'package:gkk_flutter/components/character/character_health_panel.dart';
import 'package:gkk_flutter/components/character/stat_allocation_panel.dart';
import 'package:gkk_flutter/models/player_model.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CharacterCombatStatsPanel Aion 2 Tests', () {
    testWidgets('renders CP aura badge and core Aion 2 combat stats', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CharacterCombatStatsPanel(
                power: '15.000',
                health: 900,
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
      await tester.pumpAndSettle();

      // Check Combat Power (CP) Aura Badge
      expect(find.text('SAVAŞ GÜCÜ (CP)'), findsOneWidget);
      expect(find.text('15.000'), findsOneWidget);
      expect(find.text('TIER S · ŞAMPİYON'), findsOneWidget);

      // Check section titles
      expect(find.text('TAARRUZ & BÜYÜ (OFFENSE)'), findsOneWidget);
      expect(find.text('SAVUNMA & DİRENÇ (DEFENSE)'), findsOneWidget);
      expect(find.text('PVP VE DAEVA İTİBARI'), findsOneWidget);

      // Check Aion 2 combat stats
      expect(find.text('Fiziksel Saldırı'), findsOneWidget);
      expect(find.text('Büyü Saldırısı'), findsOneWidget);
      expect(find.text('Kritik Vuruş'), findsOneWidget);
      expect(find.text('Büyü Güçlendirmesi'), findsOneWidget);
      expect(find.text('Savunma Gücü'), findsOneWidget);
      expect(find.text('Bloklama Oranı'), findsOneWidget);
      expect(find.text('Kaçınma / Çeviklik'), findsOneWidget);
      expect(find.text('Şans (Kader)'), findsOneWidget);
      expect(find.text('PvP Kazanma'), findsOneWidget);
      expect(find.text('PvP Rating'), findsOneWidget);

      // Reputation tile
      expect(find.textContaining('İtibar:'), findsOneWidget);
    });

    testWidgets('can collapse and re-expand stats panel', (
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
      await tester.pumpAndSettle();

      expect(find.text('Fiziksel Saldırı'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('Gelişim & Savaş İstatistikleri'));
      await tester.pumpAndSettle();

      // CP badge remains visible
      expect(find.text('SAVAŞ GÜCÜ (CP)'), findsOneWidget);

      // Tap header to expand again
      await tester.tap(find.text('Gelişim & Savaş İstatistikleri'));
      await tester.pumpAndSettle();

      expect(find.text('Fiziksel Saldırı'), findsOneWidget);
    });
  });

  group('CharacterHealthPanel Segmented HP/MP/DP Tests', () {
    testWidgets('renders segmented HP, MP, and DP vitals with percentage', (
      WidgetTester tester,
    ) async {
      final PlayerProfile profile = _buildTestProfile(
        health: 800,
        maxHealth: 1000,
        energy: 60,
        maxEnergy: 100,
        pvpWins: 30,
        pvpRating: 1500,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CharacterHealthPanel(profile: profile),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Vitals header
      expect(find.text('Savaş Yaşamsal Göstergeleri (Vitals)'), findsOneWidget);

      // HP, MP, DP rows
      expect(find.text('HP (Sağlık)'), findsOneWidget);
      expect(find.text('MP (Mana / Enerji)'), findsOneWidget);
      expect(find.text('DP (Divine Power · İlahi Güç)'), findsOneWidget);

      // Health ratio text
      expect(find.textContaining('800 / 1000'), findsOneWidget);
      expect(find.textContaining('60 / 100'), findsOneWidget);

      // Action buttons
      expect(find.text('İksirler'), findsOneWidget);
      expect(find.textContaining('Elmas'), findsOneWidget);
    });

    testWidgets('displays hospital / prison button when restricted', (
      WidgetTester tester,
    ) async {
      final PlayerProfile profile = _buildTestProfile(
        health: 300,
        maxHealth: 1000,
        hospitalUntil: DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CharacterHealthPanel(
                profile: profile,
                inHospital: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hastane'), findsOneWidget);
    });
  });

  group('StatAllocationPanel Tactile & Preview Tests', () {
    testWidgets('allows +/-1 and +/-10 allocation, previewing delta and resetting', (
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
      await tester.pumpAndSettle();

      // Available points badge
      expect(find.text('20 puan'), findsOneWidget);
      expect(find.text('Stat Puanı Dağıt'), findsOneWidget);

      // Four stat rows
      expect(find.text('Saldırı'), findsOneWidget);
      expect(find.text('Savunma'), findsOneWidget);
      expect(find.text('Şans'), findsOneWidget);
      expect(find.text('Can'), findsOneWidget);

      // Initially no pending points
      expect(find.text('Puan Seçimi Yapın'), findsOneWidget);

      // Tap +10 on Saldırı (first +10 button)
      final Finder plus10Buttons = find.text('+10');
      expect(plus10Buttons, findsNWidgets(4));

      await tester.tap(plus10Buttons.at(0));
      await tester.pumpAndSettle();

      // 10 points allocated to attack, 10 remaining
      expect(find.text('10 puan'), findsOneWidget);
      expect(find.text('+10'), findsWidgets);
      expect(find.textContaining('Tahmini Güç Artışı:'), findsOneWidget);
      expect(find.text('Sıfırla'), findsOneWidget);
      expect(find.textContaining('Değişiklikleri Onayla (+10 Puan)'), findsOneWidget);

      // Tap +1 on Can (4th +1 icon button)
      final Finder addButtons = find.byIcon(Icons.add_rounded);
      expect(addButtons, findsNWidgets(4));

      await tester.tap(addButtons.at(3));
      await tester.pumpAndSettle();

      // 9 remaining, 11 pending
      expect(find.text('9 puan'), findsOneWidget);
      expect(find.text('+1'), findsWidgets);
      expect(find.textContaining('Değişiklikleri Onayla (+11 Puan)'), findsOneWidget);

      // Tap Sıfırla (Reset)
      await tester.tap(find.text('Sıfırla'));
      await tester.pumpAndSettle();

      // Reset back to 20 available points
      expect(find.text('20 puan'), findsOneWidget);
      expect(find.text('Puan Seçimi Yapın'), findsOneWidget);
      expect(find.text('Sıfırla'), findsNothing);
    });
  });
}
