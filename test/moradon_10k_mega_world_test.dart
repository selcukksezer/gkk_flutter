import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/l10n/app_localizations.dart';
import 'package:gkk_flutter/models/moradon_models.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/moradon_hub_provider.dart';
import 'package:gkk_flutter/screens/home/moradon/moradon_hud_overlay.dart';
import 'package:gkk_flutter/screens/home/moradon/moradon_world_view.dart';

PlayerProfile _makeHero({
  String id = 'hero_10k_1',
  String username = 'theking',
}) {
  final String nowIso = DateTime.now().toUtc().toIso8601String();
  return PlayerProfile(
    id: id,
    authId: 'auth_$id',
    username: username,
    email: '$id@gkk.test',
    displayName: username,
    avatarUrl: null,
    avatarFrame: null,
    level: 70,
    xp: 54000,
    gold: 250000,
    gems: 500,
    energy: 90,
    maxEnergy: 100,
    attack: 48018,
    defense: 51184,
    health: 35360,
    maxHealth: 35360,
    power: 173372,
    isOnline: true,
    isBanned: false,
    tutorialCompleted: true,
    guildId: 'guild_kankaja',
    guildRole: 'leader',
    guildName: 'kankaja',
    referralCode: 'KING10K',
    referredBy: null,
    pvpRating: 1520,
    pvpWins: 32,
    pvpLosses: 7,
    addictionLevel: 0,
    tolerance: 0,
    lastPotionUsedAt: null,
    warriorBloodlustUntil: null,
    hospitalUntil: null,
    hospitalReason: null,
    hospitalLifetimeCount: 0,
    prisonUntil: null,
    prisonReason: null,
    globalSuspicionLevel: 0,
    lastBribeAt: null,
    lastLoginAt: nowIso,
    lastLogin: nowIso,
    createdAt: nowIso,
    updatedAt: nowIso,
    reputation: 1500,
    luck: 140,
    equipBonusLuck: 14642,
    characterClass: CharacterClass.warrior,
  );
}

class _TestMegaMoradonNotifier extends MoradonHubNotifier {
  final MoradonHubState seeded;
  _TestMegaMoradonNotifier(this.seeded);

  @override
  MoradonHubState build() => seeded;

  @override
  void bindLocalProfile(PlayerProfile profile, {required int totalPower}) {}

  @override
  Future<void> switchChannel(int channelId) async {
    final MoradonChannelInfo? target = state.channels
        .where((MoradonChannelInfo c) => c.channelId == channelId)
        .firstOrNull;
    state = state.copyWith(
      currentChannel: channelId,
      channelOnlineCount: target?.onlineCount ?? state.channelOnlineCount,
      clearSelectedRemoteUser: true,
    );
  }
}

Widget _wrapMegaWorldApp({
  required Widget child,
  List<Override> overrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Blender 6400x3600 Mega-Capital & Spatial AOI Architecture', () {
    test('Dark-Gothic 4K citadel courtyard, seamless flagstone tile & 2.5D occlusion PNGs exist on disk', () {
      expect(
        File('assets/moradon/citadel_dungeon_v9.jpg').existsSync(),
        isTrue,
      );
      expect(
        File('assets/moradon/tile_dungeon_flagstone.png').existsSync(),
        isTrue,
      );
      for (final MoradonOcclusionProp prop in kCitadelOcclusionProps) {
        expect(
          File(prop.assetPath).existsSync(),
          isTrue,
          reason: 'Missing Dark-Gothic 2.5D occlusion asset: ${prop.assetPath}',
        );
      }
    });

    test('Mega-Capital spans 6400x3600 (4x surface) with 8 distinct districts', () {
      expect(MoradonHubState.worldWidth, 6400.0);
      expect(MoradonHubState.worldHeight, 3600.0);
      expect(kMoradonDistricts.length, 8);

      expect(resolveMoradonDistrict(3200, 2090).id, 'pantheon_plaza');
      expect(resolveMoradonDistrict(3200, 880).id, 'northern_bastion');
      expect(resolveMoradonDistrict(5060, 1960).id, 'grand_bazaar_district');
      expect(resolveMoradonDistrict(1340, 1960).id, 'western_forge');
      expect(resolveMoradonDistrict(4760, 1120).id, 'war_colosseum');
      expect(resolveMoradonDistrict(1680, 1290).id, 'royal_treasury');
      expect(resolveMoradonDistrict(1960, 2780).id, 'guard_barracks');
      expect(resolveMoradonDistrict(4880, 2860).id, 'southern_tavern');
    });

    test('MoradonSpatialGrid queries arbitrary AOI rects in O(1) cell buckets', () {
      final MoradonSpatialGrid<String> grid = MoradonSpatialGrid<String>(
        worldWidth: MoradonHubState.worldWidth,
        worldHeight: MoradonHubState.worldHeight,
        cellSize: 400.0,
      );

      grid.insert(3200, 2240, 'hero_plaza');
      grid.insert(4860, 2020, 'merchant_bazaar');
      grid.insert(1620, 1960, 'smith_forge');
      grid.insert(3200, 880, 'raider_north');

      final List<String> bazaarHits = grid.queryRect(
        const Rect.fromLTWH(4500, 1750, 700, 500),
      );
      expect(bazaarHits, <String>['merchant_bazaar']);

      final List<String> plazaHits = grid.queryRect(
        const Rect.fromLTWH(2900, 1950, 600, 500),
      );
      expect(plazaHits, <String>['hero_plaza']);
    });
  });

  group('10,000 Concurrent Online Crowd LOD, Culling & Sharding UI', () {
    testWidgets(
      'Frustum Culling + Mobile 48-Avatar LOD Cap handles 220+ dense players at 0 overflow while prioritizing selected & guildmates (390x844)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final PlayerProfile me = _makeHero();
        final InventoryState inv = InventoryState.initial();
        final Map<String, MoradonPlayerPresence> crowd =
            <String, MoradonPlayerPresence>{};

        // 120 dense players around hero in Grand Bazaar (4860, 2020)
        for (int i = 0; i < 120; i++) {
          final double dx = ((i % 12) - 6) * 22.0;
          final double dy = ((i ~/ 12) - 5) * 18.0;
          final double px = 4860.0 + dx;
          final double py = 2020.0 + dy;
          final String uid = 'bazaar_$i';
          crowd[uid] = MoradonPlayerPresence(
            userId: uid,
            username: 'Pazarci$i',
            characterClass: i.isEven ? 'savasci' : 'golge',
            guildName: i == 95 ? 'kankaja' : 'DIGER',
            level: 60 + (i % 15),
            totalPower: 85000 + i * 350,
            x: px,
            y: py,
            targetX: px,
            targetY: py,
            isMerchant: i % 3 == 0,
            merchantTitle: i % 3 == 0 ? 'Tezgah #$i' : null,
          );
        }

        // 100 off-screen players far away in West Magma Forge (1450, 1930)
        for (int i = 0; i < 100; i++) {
          final double px = 1450.0 + (i % 10) * 18.0;
          final double py = 1920.0 + (i ~/ 10) * 16.0;
          final String uid = 'forge_$i';
          crowd[uid] = MoradonPlayerPresence(
            userId: uid,
            username: 'Demirci$i',
            characterClass: 'simyaci',
            level: 55,
            totalPower: 64000,
            x: px,
            y: py,
            targetX: px,
            targetY: py,
          );
        }

        final MoradonHubState seeded = MoradonHubState(
          playerX: 4860.0,
          playerY: 2020.0,
          targetX: 4860.0,
          targetY: 2020.0,
          zoom: 0.92,
          responsiveZoomApplied: true,
          currentChannel: 1,
          channelOnlineCount: 158,
          totalRealmOnline: 10240,
          selectedRemoteUserId: 'bazaar_110',
          remotePlayers: crowd,
        );

        await tester.pumpWidget(
          _wrapMegaWorldApp(
            overrides: <Override>[
              moradonHubProvider
                  .overrideWith(() => _TestMegaMoradonNotifier(seeded)),
            ],
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                MoradonWorldView(
                  profile: me,
                  inventoryState: inv,
                  totalPower: me.power,
                ),
                MoradonHudOverlay(
                  profile: me,
                  inventoryState: inv,
                  totalPower: me.power,
                  reputation: me.reputation ?? 0,
                  onSlotTap: (_, _) {},
                ),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 120));

        expect(tester.takeException(), isNull);

        // 1. Off-screen West Forge players are 100% frustum-culled (0 widgets)
        expect(
          find.byKey(const ValueKey<String>('moradon_remote_avatar_forge_0')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('moradon_remote_avatar_forge_50')),
          findsNothing,
        );

        // 2. Count rendered remote avatar widgets -> strictly capped <= 48 on mobile
        int renderedBazaarAvatars = 0;
        for (int i = 0; i < 120; i++) {
          if (find
              .byKey(ValueKey<String>('moradon_remote_avatar_bazaar_$i'))
              .evaluate()
              .isNotEmpty) {
            renderedBazaarAvatars++;
          }
        }
        expect(
          renderedBazaarAvatars,
          lessThanOrEqualTo(MoradonHubState.mobileAvatarRenderCap),
        );
        expect(renderedBazaarAvatars, greaterThanOrEqualTo(36));

        // 3. Priority preservation: Selected target (bazaar_110) & Guildmate (bazaar_95)
        // MUST be promoted into the full-avatar render budget despite high index/distance!
        expect(
          find.byKey(const ValueKey<String>('moradon_remote_avatar_bazaar_110')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('moradon_remote_avatar_bazaar_95')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Channel Switcher & 8-District Fast-Travel Sheet switches shards and teleports across 6400x3600 capital',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final PlayerProfile me = _makeHero();
        final InventoryState inv = InventoryState.initial();
        final MoradonHubState seeded = MoradonHubState(
          playerX: 3200.0,
          playerY: 2360.0,
          targetX: 3200.0,
          targetY: 2360.0,
          zoom: 0.88,
          responsiveZoomApplied: true,
          currentChannel: 1,
          channelOnlineCount: 162,
          totalRealmOnline: 10240,
          channels: const <MoradonChannelInfo>[
            MoradonChannelInfo(
              channelId: 1,
              onlineCount: 162,
              capacity: 200,
              status: 'crowded',
            ),
            MoradonChannelInfo(
              channelId: 2,
              onlineCount: 148,
              capacity: 200,
              status: 'crowded',
            ),
            MoradonChannelInfo(
              channelId: 3,
              onlineCount: 74,
              capacity: 200,
              status: 'normal',
            ),
          ],
        );

        await tester.pumpWidget(
          _wrapMegaWorldApp(
            overrides: <Override>[
              moradonHubProvider
                  .overrideWith(() => _TestMegaMoradonNotifier(seeded)),
            ],
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                MoradonWorldView(
                  profile: me,
                  inventoryState: inv,
                  totalPower: me.power,
                ),
                MoradonHudOverlay(
                  profile: me,
                  inventoryState: inv,
                  totalPower: me.power,
                  reputation: me.reputation ?? 0,
                  onSlotTap: (_, _) {},
                ),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Open Channel & District Sheet via Mobile HUD chip
        final Finder chipFinder =
            find.byKey(const Key('moradon_channel_switcher_chip'));
        expect(chipFinder, findsOneWidget);
        await tester.tap(chipFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        expect(find.byKey(const Key('moradon_channel_sheet')), findsOneWidget);
        expect(find.textContaining('10240'), findsOneWidget);
        expect(find.text('Moradon-1'), findsOneWidget);
        expect(find.text('Moradon-3'), findsOneWidget);

        // Switch to Channel 3 ("Akıcı")
        final Finder ch3Finder = find.byKey(const Key('moradon_channel_tile_3'));
        await tester.ensureVisible(ch3Finder);
        await tester.pump();
        await tester.tap(ch3Finder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        final ProviderContainer container = ProviderScope.containerOf(
          tester.element(find.byType(MoradonHudOverlay)),
        );
        expect(container.read(moradonHubProvider).currentChannel, 3);

        // Re-open sheet and fast-travel to Grand Bazaar (Doğu Büyük Pazar)
        await tester.tap(chipFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        final Finder bazaarFinder = find.byKey(
          const Key('moradon_district_chip_grand_bazaar_district'),
        );
        await tester.ensureVisible(bazaarFinder);
        await tester.pump();
        await tester.tap(bazaarFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        final MoradonHubState afterTeleport = container.read(moradonHubProvider);
        expect(afterTeleport.currentDistrict.id, 'grand_bazaar_district');
        expect(afterTeleport.playerX, closeTo(4800.0, 1.0));
        expect(afterTeleport.playerY, closeTo(1980.0, 1.0));
      },
    );

    testWidgets(
      '350 dense plaza players batch-render smoothly and tapping an overflow crowd player promotes them to selected target',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final PlayerProfile me = _makeHero();
        final InventoryState inv = InventoryState.initial();
        final Map<String, MoradonPlayerPresence> crowd =
            <String, MoradonPlayerPresence>{};

        // 350 concurrent players in Pantheon Plaza around (3200, 2580)
        for (int i = 0; i < 350; i++) {
          final double ring = 35.0 + (i ~/ 20) * 18.0;
          final double px = 3200.0 + ((i % 20) - 10) * 16.0;
          final double py = 2580.0 + (i.isEven ? ring * 0.45 : -ring * 0.35);
          final String uid = 'plaza_crowd_$i';
          crowd[uid] = MoradonPlayerPresence(
            userId: uid,
            username: 'Oyuncu$i',
            characterClass: switch (i % 3) {
              0 => 'savasci',
              1 => 'golge',
              _ => 'simyaci',
            },
            level: 50 + (i % 25),
            totalPower: 42000 + i * 250,
            x: px,
            y: py,
            targetX: px + (i.isEven ? 12.0 : 0.0),
            targetY: py,
            isMerchant: i % 5 == 0,
          );
        }

        // Place a distinct distant visible crowd player inside viewport but beyond top-48 nearest
        const String overflowUid = 'plaza_overflow_target';
        crowd[overflowUid] = const MoradonPlayerPresence(
          userId: overflowUid,
          username: 'UzakSovalye',
          characterClass: 'savasci',
          level: 72,
          totalPower: 188000,
          x: 3340.0,
          y: 2740.0,
          targetX: 3340.0,
          targetY: 2740.0,
        );

        final MoradonHubState seeded = MoradonHubState(
          playerX: 3200.0,
          playerY: 2580.0,
          targetX: 3200.0,
          targetY: 2580.0,
          zoom: 1.0,
          responsiveZoomApplied: true,
          currentChannel: 1,
          channelOnlineCount: 352,
          totalRealmOnline: 10240,
          remotePlayers: crowd,
        );

        await tester.pumpWidget(
          _wrapMegaWorldApp(
            overrides: <Override>[
              moradonHubProvider
                  .overrideWith(() => _TestMegaMoradonNotifier(seeded)),
            ],
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                MoradonWorldView(
                  profile: me,
                  inventoryState: inv,
                  totalPower: me.power,
                ),
                MoradonHudOverlay(
                  profile: me,
                  inventoryState: inv,
                  totalPower: me.power,
                  reputation: me.reputation ?? 0,
                  onSlotTap: (_, _) {},
                ),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);

        // Before tap: overflow player has 0 dedicated widgets (rendered in GPU Crowd Batch!)
        expect(
          find.byKey(
            const ValueKey<String>('moradon_remote_avatar_$overflowUid'),
          ),
          findsNothing,
        );

        // Compute screen tap position for (3340, 2740) at zoom=1.0 on 390x844 (vFocus=0.61)
        // camX = 3200 - 195 = 3005 -> screenX = 3340 - 3005 = 335
        // camY = 2580 - 844*0.61 = 2065.16 -> body center ~ y=2690 -> screenY = 2690 - 2065.16 = 624.8
        await tester.tapAt(const Offset(335.0, 625.0));
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull);

        final ProviderContainer container = ProviderScope.containerOf(
          tester.element(find.byType(MoradonWorldView)),
        );
        expect(
          container.read(moradonHubProvider).selectedRemoteUserId,
          overflowUid,
        );
        // After tap: promoted immediately into full interactive avatar budget!
        expect(
          find.byKey(
            const ValueKey<String>('moradon_remote_avatar_$overflowUid'),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
