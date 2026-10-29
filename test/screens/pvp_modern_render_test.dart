import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/matchmaking/matchmaking_offer.dart';
import 'package:gkk_flutter/models/guild_war_model.dart';
import 'package:gkk_flutter/models/nemesis_model.dart';
import 'package:gkk_flutter/screens/guild_war/battle_result_screen.dart';
import 'package:gkk_flutter/screens/guild_war/widgets/faction_crest_painter.dart';
import 'package:gkk_flutter/screens/guild_war/widgets/faction_war_banner.dart';
import 'package:gkk_flutter/screens/guild_war/widgets/territory_map_view.dart';
import 'package:gkk_flutter/screens/pvp/pvp_screen.dart';
import 'package:gkk_flutter/screens/pvp/widgets/arena_map_viewport.dart';
import 'package:gkk_flutter/screens/pvp/widgets/gladiator_tier_emblem.dart';
import 'package:gkk_flutter/screens/pvp/widgets/nemesis_rival_panel.dart';
import 'package:gkk_flutter/screens/pvp/widgets/pvp_colosseum_backdrop.dart';
import 'package:gkk_flutter/screens/pvp/widgets/pvp_thumb_action_deck.dart';
import 'package:gkk_flutter/screens/pvp/widgets/pvp_versus_splash_banner.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Faction Crest & Banner Modern Rendering Tests', () {
    testWidgets('FactionCrestWidget renders Elyos and Asmodian crests cleanly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                FactionCrestWidget(faction: FactionType.elyos, size: 60),
                FactionCrestWidget(faction: FactionType.asmodian, size: 60),
                FactionCrestWidget(faction: FactionType.neutral, size: 60),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FactionCrestWidget), findsNWidgets(3));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('FactionWarBanner renders single faction banner with title and subtitle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FactionWarBanner(
              faction: FactionType.elyos,
              title: 'ELYOS HANEDANI',
              subtitle: 'Işığın Egemenliği',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ELYOS HANEDANI'), findsOneWidget);
      expect(find.text('Işığın Egemenliği'), findsOneWidget);
      expect(find.byType(FactionCrestWidget), findsOneWidget);
    });

    testWidgets('FactionClashBanner renders confrontation with scores and ratio bar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FactionClashBanner(
              elyosScore: 2450,
              asmodianScore: 2100,
              elyosTerritoryCount: 5,
              asmodianTerritoryCount: 2,
              battleTimerText: '08:42',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ELYOS'), findsOneWidget);
      expect(find.text('ASMODIAN'), findsOneWidget);
      expect(find.text('2450 Puan · 5 Bölge'), findsOneWidget);
      expect(find.text('2100 Puan · 2 Bölge'), findsOneWidget);
      expect(find.text('08:42'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
    });
  });

  group('ArenaMapViewport Mobile Responsiveness Tests', () {
    testWidgets('ArenaMapViewport renders portrait mobile view without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool entered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArenaMapViewport(
              currentRating: 1420,
              onEnterArena: () => entered = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('1420'), findsOneWidget);
      expect(find.text('Uçurum Gladyatör Arenası'), findsOneWidget);
      expect(find.text('Arenaya Gir'), findsOneWidget);
      expect(find.byIcon(Icons.military_tech_rounded), findsOneWidget);

      await tester.tap(find.text('Arenaya Gir'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(entered, isTrue);
    });

    testWidgets('ArenaMapViewport renders landscape mobile view without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool entered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArenaMapViewport(
              currentRating: 1580,
              onEnterArena: () => entered = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ARENA MODU'), findsOneWidget);
      expect(find.text('1580'), findsOneWidget);
      expect(find.text('Arenaya Gir'), findsOneWidget);

      await tester.tap(find.text('Arenaya Gir'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(entered, isTrue);
    });
  });

  group('PvpThumbActionDeck Mobile Combat Trigger Tests', () {
    testWidgets('PvpThumbActionDeck allows wager selection, triggers onWagerSelected, and fires quick duel callback', (
      WidgetTester tester,
    ) async {
      int? duelWager;
      int? reportedWager;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PvpThumbActionDeck(
              initialWager: 0,
              maxGold: 5000,
              onWagerSelected: (int w) => reportedWager = w,
              onQuickDuel: (int wager) async {
                duelWager = wager;
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('BAHİS MİKTARI'), findsOneWidget);
      expect(find.text('Bahissiz (Dostluk)'), findsOneWidget);
      expect(find.text('⚡ HIZLI DÜELLO ARA'), findsOneWidget);

      // Tap +500 wager preset
      await tester.tap(find.text('+500'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('500 🪙 Altın'), findsOneWidget);
      expect(reportedWager, 500);

      // Trigger duel
      final Finder triggerBtn = find.text('⚡ BAHİSLİ DÜELLO BAŞLAT');
      expect(triggerBtn, findsOneWidget);
      await tester.tap(triggerBtn);
      await tester.pump(const Duration(milliseconds: 50));

      expect(duelWager, 500);

      // Tap Max wager preset
      await tester.tap(find.text('Max'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('5000 🪙 Altın'), findsOneWidget);
      expect(reportedWager, 5000);
    });

    testWidgets('PvpThumbActionDeck handles disabled state when hospitalized or imprisoned', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PvpThumbActionDeck(
              disabled: true,
              onQuickDuel: (int wager) async {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final ElevatedButton button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });
  });

  group('PvP Matchmaking UI & Opponent Discovery Tests', () {
    test('OnlinePlayer model parses from JSON and MatchmakingOffer cleanly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'offer_id': 'offer-123',
        'auth_id': 'auth-456',
        'username': 'ShadowBlade',
        'display_name': 'Gölge Avcısı',
        'avatar_url': 'https://example.com/avatar.png',
        'level': 35,
        'power': 2400,
        'pvp_rating': 1450,
      };
      final OnlinePlayer fromJson = OnlinePlayer.fromJson(json);
      expect(fromJson.offerId, 'offer-123');
      expect(fromJson.authId, 'auth-456');
      expect(fromJson.username, 'ShadowBlade');
      expect(fromJson.displayName, 'Gölge Avcısı');
      expect(fromJson.level, 35);
      expect(fromJson.power, 2400);
      expect(fromJson.pvpRating, 1450);

      const MatchmakingOffer offer = MatchmakingOffer(
        offerId: 'offer-999',
        authId: 'auth-888',
        username: 'AionKnight',
        displayName: 'Aion Şövalyesi',
        avatarUrl: '',
        level: 40,
        power: 3100,
        pvpRating: 1600,
      );
      final OnlinePlayer fromOffer = OnlinePlayer.fromOffer(offer);
      expect(fromOffer.offerId, 'offer-999');
      expect(fromOffer.authId, 'auth-888');
      expect(fromOffer.displayName, 'Aion Şövalyesi');
      expect(fromOffer.pvpRating, 1600);
    });

    testWidgets('Matchmaking Info dialog renders rules and explanations smoothly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestMatchmakingInfoDialog(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Eşleşme Nasıl Çalışır?'), findsOneWidget);
      expect(find.text('🎯'), findsOneWidget);
      expect(find.text('📈'), findsOneWidget);
      expect(find.text('🌍'), findsOneWidget);
      expect(find.text('🛡️'), findsOneWidget);
      expect(
        find.text('Önce sana yakın rakipler aranır: ±5 seviye veya ±250 rating.'),
        findsOneWidget,
      );
      expect(find.text('Anladım'), findsOneWidget);
    });

    testWidgets('NemesisRivalPanel renders rival info, nemesis banner, stats, and handles actions', (
      WidgetTester tester,
    ) async {
      String? revengeTarget;
      bool dismissed = false;

      const NemesisRival rival = NemesisRival(
        hasRival: true,
        rivalId: 'rival-777',
        rivalUsername: 'Vulkan_Kral',
        losses: 4,
        wins: 2,
        online: true,
        level: 32,
        power: 2800,
        pvpRating: 1520,
        leaderboardGap: 140,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NemesisRivalPanel(
              rival: rival,
              onRevenge: (String id) => revengeTarget = id,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('NEMESIS'), findsOneWidget);
      expect(find.text('Çevrimiçi'), findsOneWidget);
      expect(find.text('Vulkan_Kral'), findsOneWidget);
      expect(find.text('4 yenilgi · 2 galibiyet · Lv 32'), findsOneWidget);
      expect(find.text('Sıralama farkı: 140 güç'), findsOneWidget);
      expect(find.text('Düello Gönder'), findsOneWidget);

      await tester.tap(find.text('Düello Gönder'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(revengeTarget, 'rival-777');

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      expect(dismissed, isTrue);
    });

    testWidgets('NemesisRivalPanel disables revenge button when rival is below level 5', (
      WidgetTester tester,
    ) async {
      const NemesisRival lowLevelRival = NemesisRival(
        hasRival: true,
        rivalId: 'newbie-1',
        rivalUsername: 'AcemiGladyatör',
        level: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NemesisRivalPanel(
              rival: lowLevelRival,
              onRevenge: (String id) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hedef 5. seviyenin altında — düello kapalı.'), findsOneWidget);
      final ElevatedButton button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Matchmaking empty state and refresh countdown cards render smoothly', (
      WidgetTester tester,
    ) async {
      bool arenaTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestMatchmakingEmptyStateCard(
              message: 'Şu anda uygun rakip teklifi yok.',
              ctaLabel: 'Arenaya git',
              onPressed: () => arenaTapped = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Şu anda uygun rakip teklifi yok.'), findsOneWidget);
      expect(find.text('Arenaya git'), findsOneWidget);
      expect(find.byIcon(Icons.sports_mma_rounded), findsOneWidget);

      await tester.tap(find.text('Arenaya git'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(arenaTapped, isTrue);
    });
  });

  group('PvP Arena Headers & Colosseum Visuals Tests', () {
    testWidgets('ColosseumCardIllustration renders across all 4 theme moods cleanly', (
      WidgetTester tester,
    ) async {
      for (final ColosseumThemeMood mood in ColosseumThemeMood.values) {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ColosseumCardIllustration(
                title: 'Mekan Arenası',
                subtitle: 'Özel Dövüş Alanı',
                mood: mood,
                onTap: () => tapped = true,
                trailing: const Text('GİR'),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Mekan Arenası'), findsOneWidget);
        expect(find.text('Özel Dövüş Alanı'), findsOneWidget);
        expect(find.text('GİR'), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);

        await tester.tap(find.text('GİR'));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tapped, isTrue);
      }
    });

    testWidgets('PvpVersusSplashBanner renders duel matchup header with full combat stats and wager', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PvpVersusSplashBanner(
              challengerName: 'EjderhaAvcısı',
              challengerRating: 1720,
              challengerPower: 3400,
              challengerLevel: 45,
              defenderName: 'GölgeKatili',
              defenderRating: 1680,
              defenderPower: 3350,
              defenderLevel: 44,
              arenaTitle: 'Uçurum Gladyatör Koloseumu',
              wager: 750,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('EjderhaAvcısı'), findsOneWidget);
      expect(find.text('GölgeKatili'), findsOneWidget);
      expect(find.text('1720 MMR'), findsOneWidget);
      expect(find.text('1680 MMR'), findsOneWidget);
      expect(find.text('750 Altın Bahis'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
      expect(find.text('Uçurum Gladyatör Koloseumu'), findsOneWidget);
    });

    testWidgets('PvpVersusSplashBanner renders compact mode for small screens', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PvpVersusSplashBanner(
              challengerName: 'Ben',
              challengerRating: 1200,
              defenderName: 'Rakip',
              defenderRating: 1180,
              compact: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('VS'), findsOneWidget);
      expect(find.text('Dostluk Maçı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PvP Mock Stats & Gladiator Rank Progression Tests', () {
    testWidgets('GladiatorTierProgressCard calculates progress and win rate stats accurately', (
      WidgetTester tester,
    ) async {
      bool leaderboardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GladiatorTierProgressCard(
              rating: 1350,
              pvpWins: 30,
              pvpLosses: 10,
              onViewLeaderboard: () => leaderboardTapped = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Altın Gladyatör'), findsOneWidget);
      expect(find.text('1350 MMR'), findsOneWidget);
      expect(find.text('GOLD'), findsOneWidget);
      expect(find.text('Sonraki Aşama: +150 MMR'), findsOneWidget);
      expect(find.textContaining('Kazanma: %75.0 (30 G / 10 M)'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.leaderboard_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      expect(leaderboardTapped, isTrue);
    });

    testWidgets('GladiatorTierEmblem renders all 7 tier classifications', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: GladiatorTier.values
                    .map((GladiatorTier t) => GladiatorTierEmblem(
                          tier: t,
                          size: 40,
                          showLabel: true,
                          animated: false,
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(GladiatorTierEmblem), findsNWidgets(7));
      expect(find.text('Bronz Gladyatör'), findsOneWidget);
      expect(find.text('Gümüş Gladyatör'), findsOneWidget);
      expect(find.text('Altın Gladyatör'), findsOneWidget);
      expect(find.text('Platin Gladyatör'), findsOneWidget);
      expect(find.text('Elmas Gladyatör'), findsOneWidget);
      expect(find.text('Abyssal Efendisi'), findsOneWidget);
      expect(find.text('Abyssal Grandmaster'), findsOneWidget);
    });

    testWidgets('PvP mock stats section layout renders chips, win rate, energy, and wounded penalties', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestPvPStatsSection(
              rating: 1420,
              winRate: 64.5,
              energy: 48,
              wins: 78,
              losses: 43,
              isWounded: true,
              woundPenaltyPercent: 20,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('PvP İstatistikleri'), findsOneWidget);
      expect(find.text('1420'), findsOneWidget);
      expect(find.text('Rating'), findsOneWidget);
      expect(find.text('64.5%'), findsOneWidget);
      expect(find.text('Kazanma Oranı'), findsOneWidget);
      expect(find.text('48'), findsOneWidget);
      expect(find.text('Enerji'), findsOneWidget);
      expect(find.text('78'), findsOneWidget);
      expect(find.text('Galibiyet'), findsOneWidget);
      expect(find.text('43'), findsOneWidget);
      expect(find.text('Mağlubiyet'), findsOneWidget);
      expect(find.text('Yaralı: PvP gücü -20%'), findsOneWidget);
    });

    testWidgets('PvP match history card renders duel outcome, role, arena badge and rewards', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                _TestMatchCard(
                  opponentName: 'GölgeSuikastçi',
                  isAttacker: true,
                  won: true,
                  isArena: true,
                  timeAgo: '5 dk önce',
                  hpRemaining: 840,
                  goldStolen: 350,
                  repChange: 25,
                  isCritical: true,
                ),
                SizedBox(height: 10),
                _TestMatchCard(
                  opponentName: 'DemirMuhafız',
                  isAttacker: false,
                  won: false,
                  isArena: false,
                  timeAgo: '2 saat önce',
                  hpRemaining: 0,
                  goldStolen: -150,
                  repChange: -12,
                  isCritical: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Saldırı'), findsOneWidget);
      expect(find.text('Savunma'), findsOneWidget);
      expect(find.text('Arena'), findsOneWidget);
      expect(find.text('GölgeSuikastçi'), findsOneWidget);
      expect(find.text('DemirMuhafız'), findsOneWidget);
      expect(find.text('Kazandın'), findsOneWidget);
      expect(find.text('Kaybettin'), findsOneWidget);
      expect(find.text('+350'), findsOneWidget);
      expect(find.text('-150'), findsOneWidget);
      expect(find.text('+25'), findsOneWidget);
      expect(find.text('-12'), findsOneWidget);
      expect(find.text('⚡ Kritik zafer kaydı'), findsOneWidget);
    });
  });

  group('TerritoryMapView Dark Fantasy Fortress Siege Tests', () {
    final List<TerritoryData> mockTerritories = <TerritoryData>[
      const TerritoryData(
        id: 't-1',
        name: 'Şafak Hisarı',
        zoneNumber: 1,
        defensePower: 2500,
        baseDefensePower: 3000,
        ownerGuildId: 'my-guild-id',
        ownerGuildName: 'Ejderha Lejyonu',
        tradeIncome: 500,
      ),
      const TerritoryData(
        id: 't-2',
        name: 'Uçurum Kalesi',
        zoneNumber: 2,
        defensePower: 1800,
        baseDefensePower: 2500,
        ownerGuildId: 'enemy-guild-id',
        ownerGuildName: 'Gölge Klanı',
        tradeIncome: 350,
      ),
    ];

    testWidgets('TerritoryMapView renders interactive tactical map with nodes', (
      WidgetTester tester,
    ) async {
      TerritoryData? tappedTerritory;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TerritoryMapView(
                territories: mockTerritories,
                playerGuildId: 'my-guild-id',
                onTerritoryTap: (TerritoryData t) => tappedTerritory = t,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Kuşatma Haritası'), findsOneWidget);
      expect(find.text('Harita'), findsOneWidget);
      expect(find.text('Kartlar'), findsOneWidget);
      expect(find.text('Şafak Hisarı'), findsWidgets);
      expect(find.text('Uçurum Kalesi'), findsWidgets);

      // Switch to Card Grid view
      await tester.tap(find.text('Kartlar'));
      await tester.pumpAndSettle();

      expect(find.text('Senin Loncan'), findsOneWidget);
      expect(find.text('Düşman Kalesi'), findsOneWidget);

      // Tap on territory
      await tester.tap(find.text('Şafak Hisarı').first);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tappedTerritory?.id, 't-1');
    });
  });

  group('BattleResultScreen Victory Celebration VFX Tests', () {
    testWidgets('BattleResultScreen renders victory screen with celebration VFX and haptic', (
      WidgetTester tester,
    ) async {
      const GuildWarAttackResult victoryResult = GuildWarAttackResult(
        success: true,
        message: 'Bölge ele geçirildi!',
        territoryName: 'Obsidiyen Kalesi',
        attackPower: 3400,
        defensePower: 2800,
        pointsGained: 150,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: BattleResultScreen(result: victoryResult),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('BÖLGE ELE GEÇİRİLDİ!'), findsOneWidget);
      expect(find.text('Obsidiyen Kalesi'), findsOneWidget);
      expect(find.text('+150'), findsOneWidget);
      expect(find.byType(FactionCrestWidget), findsOneWidget);
    });

    testWidgets('BattleResultScreen renders defeat screen with proper styling', (
      WidgetTester tester,
    ) async {
      const GuildWarAttackResult defeatResult = GuildWarAttackResult(
        success: false,
        message: 'Saldırı püskürtüldü!',
        territoryName: 'Gölge Geçidi',
        attackPower: 1200,
        defensePower: 2600,
        pointsGained: 25,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: BattleResultScreen(result: defeatResult),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('SALDIRI PÜSKÜRTÜLDÜ!'), findsOneWidget);
      expect(find.text('Gölge Geçidi'), findsOneWidget);
      expect(find.text('+25'), findsOneWidget);
    });
  });

  group('Mobile Screen Constraints & Zero Overflow Tests', () {
    testWidgets('ArenaMapViewport and PvpThumbActionDeck render on small mobile screen (360x640)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  const ArenaMapViewport(currentRating: 1100),
                  const SizedBox(height: 10),
                  PvpThumbActionDeck(onQuickDuel: (int wager) async {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });

    testWidgets('Full PvP dashboard components render on ultra-compact mobile screen (320x568)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  const ArenaMapViewport(currentRating: 1300),
                  const SizedBox(height: 8),
                  const NemesisRivalPanel(
                    rival: NemesisRival(
                      hasRival: true,
                      rivalUsername: 'KaranlıkKral',
                      level: 25,
                      losses: 3,
                      wins: 1,
                    ),
                    onDismiss: _dummyVoid,
                  ),
                  const SizedBox(height: 8),
                  const GladiatorTierProgressCard(rating: 1300, pvpWins: 12, pvpLosses: 4),
                  const SizedBox(height: 8),
                  PvpThumbActionDeck(onQuickDuel: (int w) async {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });
  });
}

void _dummyVoid() {}

// ── TEST HELPER WIDGETS ────────────────────────────────────────────────────────

class _TestMatchmakingInfoDialog extends StatelessWidget {
  const _TestMatchmakingInfoDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1025),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      title: const Row(
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: AppColors.toxicNeon, size: 20),
          SizedBox(width: 8),
          Text('Eşleşme Nasıl Çalışır?', style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('🎯', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Önce sana yakın rakipler aranır: ±5 seviye veya ±250 rating.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('📈', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Uygun rakip yoksa band genişler: ±10 seviye veya ±500 rating.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('🌍', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hâlâ bulunamazsa tüm oyunculardan rastgele seçilir.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('🛡️', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Yeni oyuncular korunur: düşük seviyeler yüksek seviyelerle eşleşmez.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {},
          child: const Text('Anladım', style: TextStyle(color: AppColors.toxicNeon)),
        ),
      ],
    );
  }
}

class _TestMatchmakingEmptyStateCard extends StatelessWidget {
  const _TestMatchmakingEmptyStateCard({
    required this.message,
    required this.ctaLabel,
    required this.onPressed,
  });

  final String message;
  final String ctaLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: <Widget>[
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.sports_mma_rounded, size: 18),
            label: Text(ctaLabel),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TestPvPStatsSection extends StatelessWidget {
  const _TestPvPStatsSection({
    required this.rating,
    required this.winRate,
    required this.energy,
    required this.wins,
    required this.losses,
    this.isWounded = false,
    this.woundPenaltyPercent = 20,
  });

  final int rating;
  final double winRate;
  final int energy;
  final int wins;
  final int losses;
  final bool isWounded;
  final int woundPenaltyPercent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF141B2A),
        border: Border.all(color: const Color(0xFF253154)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'PvP İstatistikleri',
            style: TextStyle(
              color: AppColors.liquidGold,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _TestStatChip(label: 'Rating', value: '$rating', color: Colors.amber),
              const SizedBox(width: 10),
              _TestStatChip(label: 'Kazanma Oranı', value: '$winRate%', color: Colors.greenAccent),
              const SizedBox(width: 10),
              _TestStatChip(label: 'Enerji', value: '$energy', color: const Color(0xFF00D7D7)),
            ],
          ),
          if (isWounded) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Yaralı: PvP gücü -$woundPenaltyPercent%',
              style: const TextStyle(
                color: AppColors.warningSolar,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _TestStatChip(label: 'Galibiyet', value: '$wins', color: Colors.greenAccent),
              const SizedBox(width: 10),
              _TestStatChip(label: 'Mağlubiyet', value: '$losses', color: Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }
}

class _TestStatChip extends StatelessWidget {
  const _TestStatChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: <Widget>[
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _TestMatchCard extends StatelessWidget {
  const _TestMatchCard({
    required this.opponentName,
    required this.isAttacker,
    required this.won,
    required this.isArena,
    required this.timeAgo,
    required this.hpRemaining,
    required this.goldStolen,
    required this.repChange,
    required this.isCritical,
  });

  final String opponentName;
  final bool isAttacker;
  final bool won;
  final bool isArena;
  final String timeAgo;
  final int hpRemaining;
  final int goldStolen;
  final int repChange;
  final bool isCritical;

  @override
  Widget build(BuildContext context) {
    final Color resultColor = won ? Colors.greenAccent : Colors.redAccent;
    final String resultText = won ? 'Kazandın' : 'Kaybettin';
    final String roleText = isAttacker ? 'Saldırı' : 'Savunma';
    final String goldSign = goldStolen >= 0 ? '+' : '';
    final String repSign = repChange >= 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isAttacker
                      ? Colors.redAccent.withValues(alpha: 0.2)
                      : Colors.blueAccent.withValues(alpha: 0.2),
                ),
                child: Text(
                  roleText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isAttacker ? Colors.redAccent : Colors.blueAccent,
                  ),
                ),
              ),
              if (isArena) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.amber.withValues(alpha: 0.15),
                  ),
                  child: const Text('Arena', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.amber)),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  opponentName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              Text(timeAgo, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 8),
              Text(resultText, style: TextStyle(fontWeight: FontWeight.w700, color: resultColor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.favorite_rounded, size: 13, color: Colors.redAccent),
                  const SizedBox(width: 3),
                  Text('$hpRemaining', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                  const SizedBox(width: 3),
                  const Text('HP', style: TextStyle(fontSize: 10, color: Colors.white38)),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.paid_rounded, size: 13, color: Colors.amber),
                  const SizedBox(width: 3),
                  Text('$goldSign$goldStolen', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber)),
                  const SizedBox(width: 3),
                  const Text('Altın', style: TextStyle(fontSize: 10, color: Colors.white38)),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.star_rounded, size: 13, color: Colors.greenAccent),
                  const SizedBox(width: 3),
                  Text('$repSign$repChange', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.greenAccent)),
                  const SizedBox(width: 3),
                  const Text('İtibar', style: TextStyle(fontSize: 10, color: Colors.white38)),
                ],
              ),
            ],
          ),
          if (isCritical) ...<Widget>[
            const SizedBox(height: 8),
            const Text('⚡ Kritik zafer kaydı', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
