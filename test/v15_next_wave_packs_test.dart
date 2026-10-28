import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gkk_flutter/components/common/reward_magnet_overlay.dart';
import 'package:gkk_flutter/components/crafting/living_foundry_banner.dart';
import 'package:gkk_flutter/components/leaderboard/champions_3d_podium.dart';
import 'package:gkk_flutter/core/services/app_settings_service.dart';
import 'package:gkk_flutter/core/services/game_sfx_service.dart';
import 'package:gkk_flutter/core/services/graphics_quality_service.dart';
import 'package:gkk_flutter/models/guild_war_model.dart';
import 'package:gkk_flutter/models/leaderboard_model.dart';
import 'package:gkk_flutter/models/moradon_models.dart';
import 'package:gkk_flutter/providers/moradon_hub_provider.dart';
import 'package:gkk_flutter/screens/guild_war/widgets/castle_siege_clash_stage.dart';
import 'package:gkk_flutter/screens/guild_war/widgets/territory_map_view.dart';
import 'package:gkk_flutter/screens/mekans/widgets/mekan_pit_arena_stage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppSettingsService.sfxVolumeKey: 0.85,
      AppSettingsService.hapticKey: true,
    });
    await AppSettingsService.instance.load();
    await GraphicsQualityService.instance.setPreference(
      GraphicsPreference.high,
    );
    GameSfxService.instance.resetForTesting();
    RewardMagnetOverlay.resetForTesting();
  });

  group('Pack 6 — Zero-MB Procedural 16-bit PCM WAV SFX Engine', () {
    test('Synthesizes valid RIFF/WAVE PCM buffers for all 9 GameSfx variants',
        () {
      int totalBytes = 0;
      for (final GameSfx sfx in GameSfx.values) {
        final Uint8List wav = GameSfxService.instance.wavBytesFor(sfx);
        expect(wav.length, greaterThan(44), reason: '$sfx WAV header + PCM');
        expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
        expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
        expect(ascii.decode(wav.sublist(12, 16)), 'fmt ');
        expect(ascii.decode(wav.sublist(36, 40)), 'data');

        // Confirm non-silent PCM payload
        bool hasNonZeroSample = false;
        for (int i = 44; i < wav.length; i++) {
          if (wav[i] != 0) {
            hasNonZeroSample = true;
            break;
          }
        }
        expect(hasNonZeroSample, isTrue, reason: '$sfx must not be silent');
        totalBytes += wav.length;
      }
      // Entire 9-SFX procedural soundbank stays well under 300 KB RAM!
      expect(totalBytes, lessThan(300 * 1024));
    });

    test('Honors AppSettingsService.sfxVolume == 0 mute & cooldown throttling',
        () async {
      await GameSfxService.instance.play(GameSfx.anvilStrike);
      expect(GameSfxService.instance.debugPlayCount, 1);
      expect(GameSfxService.instance.debugLastSfx, GameSfx.anvilStrike);

      // Immediate duplicate within 110ms cooldown is throttled
      await GameSfxService.instance.play(GameSfx.anvilStrike);
      expect(GameSfxService.instance.debugPlayCount, 1);

      // Muted sfxVolume skips playback completely
      await AppSettingsService.instance.setSfxVolume(0.0);
      await GameSfxService.instance.play(GameSfx.legendaryDrop);
      expect(GameSfxService.instance.debugPlayCount, 1);
    });
  });

  group('Pack 1 — 2.5D Continent Conquest Map & 3v3 Castle Gate Breach', () {
    testWidgets('TerritoryMapView renders 2.5D citadel pins & fires tap callback',
        (WidgetTester tester) async {
      TerritoryData? tapped;
      final List<TerritoryData> sampleTerritories = <TerritoryData>[
        const TerritoryData(
          id: 'citadel_north',
          name: 'Obsidyen Başkent Kalesi',
          ownerGuildId: 'g1',
          ownerGuildName: 'Gölge Sancak',
          ownerGuildTag: 'GLG',
          defensePower: 4200,
          hasActiveSiegeSession: true,
        ),
        const TerritoryData(
          id: 'valley_west',
          name: 'Altın Hasat Vadisi',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TerritoryMapView(
                territories: sampleTerritories,
                playerGuildId: 'g1',
                onTerritoryTap: (TerritoryData t) => tapped = t,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('continent_siege_map_stage')), findsOneWidget);
      expect(find.textContaining('Obsidyen'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey<String>('citadel_pin_citadel_north')),
      );
      await tester.pump();
      expect(tapped?.id, 'citadel_north');
    });

    testWidgets('CastleSiegeClashStage renders 3v3 breach & preview charge',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CastleSiegeClashStage(
              territoryName: 'Ejderha Zirvesi',
              attackerGuildName: 'GÖLGE SANCAK',
              defenderGuildName: 'DEMİR MUHAFIZLAR',
              winChancePct: 68.5,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('castle_siege_clash_stage')), findsOneWidget);
      expect(find.textContaining('GÖLGE SANCAK'), findsWidgets);

      final Finder ramBtn = find.byKey(
        const Key('siege_ram_preview_btn'),
      );
      expect(ramBtn, findsOneWidget);
      await tester.tap(ramBtn);
      await tester.pump(const Duration(milliseconds: 250));
      expect(GameSfxService.instance.debugLastSfx, GameSfx.siegeHorn);
    });
  });

  group('Pack 2 — Live 3D Champions Hall Podium & Pantheon Sovereign Statue',
      () {
    testWidgets('Champions3dPodium & PantheonSovereignStatue render cleanly',
        (WidgetTester tester) async {
      const List<LeaderboardEntry> top3 = <LeaderboardEntry>[
        LeaderboardEntry(
          rank: 1,
          username: 'HukumdarKael',
          value: 285000,
          level: 80,
          guild: 'GÖLGE',
        ),
        LeaderboardEntry(
          rank: 2,
          username: 'GeceKrali',
          value: 241000,
          level: 77,
        ),
        LeaderboardEntry(
          rank: 3,
          username: 'AetherLordu',
          value: 199500,
          level: 74,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  Champions3dPodium(
                    entries: top3,
                    categoryKey: 'power',
                  ),
                  PantheonSovereignStatue(
                    kingUsername: 'HukumdarKael',
                    kingPowerLabel: '⚔️ 285.0K',
                    atlas: null,
                    phase: 0.25,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('champions_3d_podium')), findsOneWidget);
      expect(find.byKey(const Key('pantheon_sovereign_statue')), findsOneWidget);
      expect(find.textContaining('HukumdarKael'), findsWidgets);
    });
  });

  group('Pack 3 & 5 — Mekan Pit Stage, Living Foundry & Bezier Reward Magnet',
      () {
    testWidgets('MekanPitArenaStage, LivingFoundryBanner & RewardMagnet work',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext ctx) {
                return SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      const MekanPitArenaStage(
                        playerName: 'Selcuk',
                        opponentName: 'KafesKrali',
                        wagerGold: 50000,
                        previewMode: true,
                      ),
                      const LivingFoundryBanner(
                        title: 'Usta Kaelen Dökümhanesi',
                        subtitle: 'Erimiş altın olukları',
                        statusBadge: '⚒️ KRALİYET ZANAAT OCAĞI',
                        isProducing: true,
                      ),
                      ElevatedButton(
                        key: const Key('trigger_magnet_btn'),
                        onPressed: () {
                          RewardMagnetOverlay.burstToTopWallet(
                            ctx,
                            kind: RewardMagnetKind.gold,
                            label: '+50K Altın!',
                          );
                        },
                        child: const Text('Magnet'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('mekan_pit_arena_stage')), findsOneWidget);
      expect(find.byKey(const Key('living_foundry_banner')), findsOneWidget);

      await tester.tap(find.byKey(const Key('living_foundry_bellows_btn')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(GameSfxService.instance.debugLastSfx, GameSfx.anvilStrike);

      await tester.tap(find.byKey(const Key('trigger_magnet_btn')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(RewardMagnetOverlay.debugBurstCount, 1);
      expect(find.text('+50K Altın!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
    });
  });

  group('Pack 4 — Moradon Royal Steed Mount, Quick Emotes & World Boss Raid',
      () {
    test('MoradonHubNotifier cycles mounts, emotes, and defeats World Boss',
        () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MoradonHubNotifier notifier =
          container.read(moradonHubProvider.notifier);

      // 1. Mount cycling & +34% speed multiplier
      expect(container.read(moradonHubProvider).mountedSteed.isMounted, isFalse);
      notifier.toggleMount();
      expect(
        container.read(moradonHubProvider).mountedSteed,
        MoradonMountVisual.crimsonBolt,
      );
      expect(
        container.read(moradonHubProvider).mountedSteed.speedMultiplier,
        closeTo(1.34, 0.001),
      );
      notifier.toggleMount();
      expect(
        container.read(moradonHubProvider).mountedSteed,
        MoradonMountVisual.shadowMane,
      );

      // 2. Quick Emote Crest
      notifier.cycleQuickEmote();
      final MoradonEmoteBubble? emote =
          container.read(moradonHubProvider).activeEmote;
      expect(emote, isNotNull);
      expect(emote!.isExpired, isFalse);

      // 3. World Boss Raid summon, damage & defeat celebration
      notifier.toggleWorldBossRaid(forceActive: true);
      MoradonWorldBossState boss = container.read(moradonHubProvider).worldBoss;
      expect(boss.isActive, isTrue);
      expect(boss.isDefeated, isFalse);
      final int initialHp = boss.currentHp;

      notifier.interactWithWorldBoss();
      boss = container.read(moradonHubProvider).worldBoss;
      expect(boss.currentHp, lessThan(initialHp));
      expect(boss.myContribution, greaterThan(0));

      int safety = 0;
      while (!container.read(moradonHubProvider).worldBoss.isDefeated &&
          safety < 250) {
        notifier.triggerHeroAttack(targetWorldBoss: true);
        safety++;
      }
      boss = container.read(moradonHubProvider).worldBoss;
      expect(boss.isDefeated, isTrue);
      expect(container.read(moradonHubProvider).activeCelebration, isNotNull);
    });
  });
}
