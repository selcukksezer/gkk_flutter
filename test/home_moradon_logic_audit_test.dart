import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gkk_flutter/core/services/app_settings_service.dart';
import 'package:gkk_flutter/core/services/game_sfx_service.dart';
import 'package:gkk_flutter/core/services/graphics_quality_service.dart';
import 'package:gkk_flutter/l10n/app_localizations.dart';
import 'package:gkk_flutter/models/moradon_models.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/moradon_hub_provider.dart';
import 'package:gkk_flutter/screens/home/moradon/moradon_hud_overlay.dart';
import 'package:gkk_flutter/screens/home/moradon/moradon_world_view.dart';

PlayerProfile _makeHero({
  String id = 'hero_audit_1',
  String username = 'theking',
  int health = 35360,
  int maxHealth = 35360,
  int power = 173372,
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
    health: health,
    maxHealth: maxHealth,
    power: power,
    isOnline: true,
    isBanned: false,
    tutorialCompleted: true,
    guildId: 'guild_kankaja',
    guildRole: 'leader',
    guildName: 'kankaja',
    referralCode: 'AUDIT1',
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

class _SeededAuditMoradonNotifier extends MoradonHubNotifier {
  final MoradonHubState seeded;
  _SeededAuditMoradonNotifier(this.seeded);

  @override
  MoradonHubState build() => seeded;
}

Widget _buildHomeMoradonHarness({
  required PlayerProfile hero,
  required MoradonHubState seeded,
}) {
  final InventoryState inv = InventoryState.initial();
  return ProviderScope(
    overrides: <Override>[
      moradonHubProvider
          .overrideWith(() => _SeededAuditMoradonNotifier(seeded)),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            MoradonWorldView(
              profile: hero,
              inventoryState: inv,
              totalPower: hero.power,
            ),
            MoradonHudOverlay(
              profile: hero,
              inventoryState: inv,
              totalPower: hero.power,
              reputation: hero.reputation ?? 0,
              onSlotTap: (_, _) {},
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppSettingsService.sfxVolumeKey: 0.0,
      AppSettingsService.hapticKey: false,
    });
    await AppSettingsService.instance.load();
    await GraphicsQualityService.instance.setPreference(
      GraphicsPreference.high,
    );
    GameSfxService.instance.resetForTesting();
  });

  group('Home Screen & Moradon Comprehensive Logic Audit', () {
    test(
      'Open-air attack in Safe Zone plays slash flourish WITHOUT fake damage or hitting peaceful players',
      () {
        final PlayerProfile hero = _makeHero();
        const MoradonPlayerPresence peacefulPeer = MoradonPlayerPresence(
          userId: 'peer_1',
          username: 'BarisciPazarci',
          characterClass: 'simyaci',
          level: 50,
          totalPower: 42000,
          x: 1835,
          y: 1810,
          targetX: 1835,
          targetY: 1810,
          isMerchant: true,
          merchantTitle: 'İksir Tezgahı',
        );

        // Place hero in open avenue (>620px from all training dummies, no active boss)
        const MoradonHubState openStreetState = MoradonHubState(
          playerX: 1800,
          playerY: 1800,
          targetX: 1800,
          targetY: 1800,
          selectedRemoteUserId: 'peer_1',
          remotePlayers: <String, MoradonPlayerPresence>{
            'peer_1': peacefulPeer,
          },
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            moradonHubProvider.overrideWith(
              () => _SeededAuditMoradonNotifier(openStreetState),
            ),
          ],
        );
        addTearDown(container.dispose);

        final MoradonHubNotifier notifier =
            container.read(moradonHubProvider.notifier);
        notifier.bindLocalProfile(hero, totalPower: hero.power);

        notifier.triggerHeroAttack();
        final MoradonHubState after = container.read(moradonHubProvider);

        expect(after.attackProgress, greaterThan(0.0));
        expect(after.activeStrike, isNull);
        expect(after.comboStreak, 0);
      },
    );

    testWidgets(
      'Attacking from spawn auto-approaches nearest dummy and automatically lands melee strike upon arrival',
      (WidgetTester tester) async {
        final PlayerProfile hero = _makeHero();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: const Locale('tr'),
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MoradonWorldView(
                  profile: hero,
                  inventoryState: InventoryState.initial(),
                  totalPower: hero.power,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        final ProviderContainer container = ProviderScope.containerOf(
          tester.element(find.byType(MoradonWorldView)),
        );
        final MoradonHubNotifier notifier =
            container.read(moradonHubProvider.notifier);
        notifier.bindLocalProfile(hero, totalPower: hero.power);
        await tester.pump(const Duration(milliseconds: 50));

        // At spawn (3200, 2625), west/east plaza dummies are ~462px away (> 175px melee reach)
        notifier.triggerHeroAttack();
        final MoradonHubState approaching = container.read(moradonHubProvider);

        expect(approaching.activeStrike, isNull);
        expect(approaching.comboStreak, 0);
        expect(approaching.isMoving, isTrue);
        expect(approaching.pendingDummyId, isNotNull);

        // Advance simulation ~1.5s in 50ms steps -> hero sprints up to dummy & strikes face-to-face!
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (container.read(moradonHubProvider).activeStrike != null) {
            break;
          }
        }

        final MoradonHubState arrived = container.read(moradonHubProvider);
        expect(arrived.activeStrike, isNotNull);
        expect(arrived.comboStreak, 1);
        expect(arrived.pendingDummyId, isNull);
        expect(arrived.isMoving, isFalse);

        // Also pump 6 seconds to confirm ZERO fake auto-celebrations fire!
        await tester.pump(const Duration(seconds: 6));
        expect(container.read(moradonHubProvider).activeCelebration, isNull);
      },
    );

    testWidgets(
      'Overhead HP bar renders full non-zero height, damage callout has no minus sign, and no contradictory KOMBO x2 HUD label',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(640, 480);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final PlayerProfile hero = _makeHero(health: 35360, maxHealth: 35360);
        final MoradonTrainingDummy eastDummy = kMoradonTrainingDummies[1];

        // Place hero in true melee reach (90px left of East Plaza Dummy)
        final MoradonHubState seeded = MoradonHubState(
          playerX: eastDummy.x - 90.0,
          playerY: eastDummy.y + 8.0,
          targetX: eastDummy.x - 90.0,
          targetY: eastDummy.y + 8.0,
          zoom: 0.48,
          responsiveZoomApplied: true,
        );

        await tester.pumpWidget(
          _buildHomeMoradonHarness(hero: hero, seeded: seeded),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);

        // 1. Verify overhead local HP fill has non-zero height & width (not 0px black strip!)
        final Finder hpFill = find.byKey(const Key('moradon_local_hp_fill'));
        expect(hpFill, findsOneWidget);
        final Size hpSize = tester.getSize(hpFill);
        expect(hpSize.height, greaterThan(2.5));
        expect(hpSize.width, greaterThan(35.0));

        // 2. Strike dummy twice via HUD Attack button -> verify formatted damage & unified combo label
        await tester.tap(find.byKey(const Key('moradon_attack_btn')));
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tap(find.byKey(const Key('moradon_attack_btn')));
        await tester.pump(const Duration(milliseconds: 80));

        final ProviderContainer container = ProviderScope.containerOf(
          tester.element(find.byType(MoradonWorldView)),
        );
        final MoradonHubState stateAfter = container.read(moradonHubProvider);
        expect(stateAfter.comboStreak, 2);
        expect(stateAfter.activeStrike, isNotNull);

        // Never shows contradictory 'KOMBO x2' or negative '-121158' text!
        expect(find.text('KOMBO x2'), findsNothing);
        expect(find.text('KOMBO x1'), findsNothing);
        expect(
          find.text('-${stateAfter.activeStrike!.damage}'),
          findsNothing,
        );
        expect(find.text('Merkez'), findsOneWidget);
      },
    );

    testWidgets(
      'Pantheon Sovereign Statue never crowns ambient bots, and Desktop HUD exposes Mount/Emote/Boss + clean Teleport Gate emblem',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final PlayerProfile hero = _makeHero(
          username: 'GercekOyuncu',
          power: 12000,
        );
        final MoradonNpcDefinition teleportGate = kMoradonNpcs.firstWhere(
          (MoradonNpcDefinition n) => n.id == 'teleport_gate',
        );

        final MoradonHubState seeded = MoradonHubState(
          playerX: 3200,
          playerY: 2420,
          targetX: 3200,
          targetY: 2420,
          zoom: 0.68,
          responsiveZoomApplied: true,
          activeNpcDialog: teleportGate,
          remotePlayers: const <String, MoradonPlayerPresence>{
            'ambient_roamer_1': MoradonPlayerPresence(
              userId: 'ambient_roamer_1',
              username: 'GeceAvcisiBot',
              characterClass: 'golge',
              level: 99,
              totalPower: 999999,
              x: 3100,
              y: 2450,
              targetX: 3100,
              targetY: 2450,
              isAmbientBot: true,
            ),
          },
        );

        await tester.pumpWidget(
          _buildHomeMoradonHarness(hero: hero, seeded: seeded),
        );
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.takeException(), isNull);

        // 1. Sovereign statue crowns GercekOyuncu, NOT the 999,999-power ambient bot!
        expect(find.textContaining('GercekOyuncu'), findsWidgets);
        expect(
          find.descendant(
            of: find.byKey(const Key('pantheon_sovereign_statue')),
            matching: find.textContaining('GeceAvcisiBot'),
          ),
          findsNothing,
        );

        // 2. Desktop HUD has Mount, Emote, and World Boss controls, and NO '+10 Kutla' debug pill!
        expect(find.byKey(const Key('moradon_mount_chip')), findsOneWidget);
        expect(find.byKey(const Key('moradon_emote_chip')), findsOneWidget);
        expect(
          find.byKey(const Key('moradon_world_boss_chip')),
          findsOneWidget,
        );
        expect(find.text('+10 Kutla'), findsNothing);

        // 3. Teleport Gate NPC dialog renders sculpted Heraldic Medallion instead of broken empty image!
        final Finder emblem = find.byKey(
          const Key('moradon_npc_emblem_teleport_gate'),
        );
        expect(emblem, findsOneWidget);
        expect(tester.getSize(emblem), const Size(58, 58));

        // 4. Hardware keyboard WASD moves hero when chat input is unfocused
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
        await tester.pump(const Duration(milliseconds: 40));
        final ProviderContainer container = ProviderScope.containerOf(
          tester.element(find.byType(MoradonWorldView)),
        );
        expect(container.read(moradonHubProvider).isMoving, isTrue);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
        await tester.pump(const Duration(milliseconds: 40));
        expect(container.read(moradonHubProvider).isMoving, isFalse);
      },
    );

    test(
      'Spatial layout audit: every NPC, training dummy, and town spawn maintains safe non-overlapping clearance',
      () {
        final MoradonDistrictZone plaza = kMoradonDistricts.firstWhere(
          (MoradonDistrictZone z) => z.id == 'pantheon_plaza',
        );
        expect(plaza.fastTravelX, MoradonHubState.spawnX);
        expect(plaza.fastTravelY, MoradonHubState.spawnY);

        for (final MoradonTrainingDummy dummy in kMoradonTrainingDummies) {
          for (final MoradonNpcDefinition npc in kMoradonNpcs) {
            final double dist = math.sqrt(
              math.pow(dummy.x - npc.x, 2) + math.pow(dummy.y - npc.y, 2),
            );
            expect(
              dist,
              greaterThanOrEqualTo(280.0),
              reason:
                  'Dummy ${dummy.id} is too close (${dist.toStringAsFixed(1)}px) to NPC ${npc.id}',
            );
          }
        }

        for (int i = 0; i < kMoradonTrainingDummies.length; i++) {
          for (int j = i + 1; j < kMoradonTrainingDummies.length; j++) {
            final MoradonTrainingDummy a = kMoradonTrainingDummies[i];
            final MoradonTrainingDummy b = kMoradonTrainingDummies[j];
            final double dist = math.sqrt(
              math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2),
            );
            expect(
              dist,
              greaterThanOrEqualTo(400.0),
              reason: 'Dummies ${a.id} and ${b.id} overlap (${dist}px)',
            );
          }
        }
      },
    );

    testWidgets(
      'Short landscape 640x480 and narrow desktop 768x600 open NPC Directory, 4-action NPC Dialog, Mount & Boss with zero overflow',
      (WidgetTester tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1.0;

        final PlayerProfile hero = _makeHero();
        final MoradonNpcDefinition monument = kMoradonNpcs.firstWhere(
          (MoradonNpcDefinition n) => n.id == 'monument_center',
        );

        // 1. Short landscape viewport (640x480 — exact aspect of user screenshot)
        tester.view.physicalSize = const Size(640, 480);
        await tester.pumpWidget(
          _buildHomeMoradonHarness(
            hero: hero,
            seeded: MoradonHubState(
              zoom: 0.48,
              responsiveZoomApplied: true,
              activeNpcDialog: monument,
              mountedSteed: MoradonMountVisual.crimsonBolt,
              worldBoss: const MoradonWorldBossState(isActive: true),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text('NPC Rehber'));
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(find.text('NPC Rehber'));
        await tester.pump(const Duration(milliseconds: 80));
        expect(find.text('BAŞKENT HIZLI ULAŞIM'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 2. Narrow desktop / tablet breakpoint (768x600) with all pills + directory active
        tester.view.physicalSize = const Size(768, 600);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('BAŞKENT HIZLI ULAŞIM'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
