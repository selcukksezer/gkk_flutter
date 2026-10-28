import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/l10n/app_localizations.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/models/moradon_models.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/moradon_hub_provider.dart';
import 'package:gkk_flutter/providers/restriction_ward_world_provider.dart';
import 'package:gkk_flutter/screens/home/moradon/moradon_hud_overlay.dart';
import 'package:gkk_flutter/screens/home/moradon/moradon_world_view.dart';
import 'package:gkk_flutter/screens/home/widgets/character_inspect_sheet.dart';
import 'package:gkk_flutter/screens/home/widgets/restriction_world_home_view.dart';

PlayerProfile _makeHero({
  String id = 'hero_local_1',
  String username = 'theking',
  int level = 70,
  int power = 173372,
  String? hospitalUntil,
  String? prisonUntil,
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
    level: level,
    xp: 54000,
    gold: 120000,
    gems: 250,
    energy: 80,
    maxEnergy: 100,
    attack: 48018,
    defense: 51184,
    health: 35360,
    maxHealth: 35360,
    power: power,
    isOnline: true,
    isBanned: false,
    tutorialCompleted: true,
    guildId: 'guild_kankaja',
    guildRole: 'leader',
    guildName: 'kankaja',
    referralCode: 'KING1',
    referredBy: null,
    pvpRating: 1420,
    pvpWins: 24,
    pvpLosses: 6,
    addictionLevel: 0,
    tolerance: 0,
    lastPotionUsedAt: null,
    warriorBloodlustUntil: null,
    hospitalUntil: hospitalUntil,
    hospitalReason: hospitalUntil != null ? 'dungeon_defeat' : null,
    hospitalLifetimeCount: 2,
    prisonUntil: prisonUntil,
    prisonReason: prisonUntil != null ? 'bribe_failed' : null,
    globalSuspicionLevel: 0,
    lastBribeAt: null,
    lastLoginAt: nowIso,
    lastLogin: nowIso,
    createdAt: nowIso,
    updatedAt: nowIso,
    reputation: 1250,
    luck: 123,
    equipBonusLuck: 14642,
    characterClass: CharacterClass.warrior,
  );
}

InventoryItem _makeTestWeapon() {
  return const InventoryItem(
    rowId: 'row_wpn_1',
    itemId: 'wpn_sword_mythic',
    quantity: 1,
    slotPosition: 0,
    isEquipped: true,
    equippedSlot: 'weapon',
    enhancementLevel: 8,
    isFavorite: true,
    pendingSync: false,
    name: 'Imperial Halberd',
    description: 'Mitik Savaşçı Silahı',
    icon: 'wpn_sword_mythic',
    itemType: ItemType.weapon,
    rarity: Rarity.mythic,
    basePrice: 50000,
    vendorSellPrice: 12500,
    attack: 14140,
    defense: 175,
    health: 67,
    power: 28149,
    luck: 1342,
    mana: 0,
    equipSlot: EquipSlot.weapon,
    weaponType: WeaponType.sword,
    armorType: ArmorType.none,
    requiredLevel: 55,
    canEnhance: true,
    maxEnhancement: 10,
    isStackable: false,
    maxStack: 1,
    isTradeable: true,
    potionType: PotionType.none,
    energyRestore: 0,
    healthRestore: 0,
    toleranceIncrease: 0,
  );
}

class _StubMoradonHubNotifier extends MoradonHubNotifier {
  final MoradonHubState seeded;
  _StubMoradonHubNotifier(this.seeded);

  @override
  MoradonHubState build() => seeded;

  @override
  void bindLocalProfile(PlayerProfile profile, {required int totalPower}) {}
}

class _StubWardWorldNotifier extends RestrictionWardWorldNotifier {
  final RestrictionWardWorldState seeded;
  _StubWardWorldNotifier(this.seeded);

  @override
  RestrictionWardWorldState build() => seeded;

  @override
  void bindSession({
    required WardWorldMode mode,
    required PlayerProfile profile,
    required int totalPower,
  }) {}

  @override
  Future<void> refreshOnlinePeers({bool silent = false}) async {}

  @override
  Future<void> loadWardChatHistory() async {}
}

Widget _wrapApp({
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
  group('Character power formatting & inspect models', () {
    test('formatCharacterPower formats Turkish thousands cleanly', () {
      expect(formatCharacterPower(0), '0');
      expect(formatCharacterPower(950), '950');
      expect(formatCharacterPower(14850), '14.850');
      expect(formatCharacterPower(173372), '173.372');
      expect(formatCharacterPower(1250000), '1.250.000');
    });

    test('InspectedEquippedItem.fromRpcJson computes enhanced stats accurately', () {
      final InspectedEquippedItem item = InspectedEquippedItem.fromRpcJson(
        <String, dynamic>{
          'equip_slot': 'weapon',
          'item_id': 'wpn_sword_mythic',
          'name': 'Imperial Halberd',
          'icon': 'wpn_sword_mythic',
          'item_type': 'weapon',
          'rarity': 'mythic',
          'enhancement_level': 4,
          'attack': 14140,
          'defense': 175,
          'health': 67,
          'luck': 1342,
          'required_level': 55,
        },
      );

      expect(item.equipSlot, 'weapon');
      expect(item.rarity, Rarity.mythic);
      expect(item.displayNameWithEnhancement, '+4 Imperial Halberd');
      // +4 multiplier = 1 + 4*0.12 = 1.48 -> floor(14140 * 1.48) = 20927
      expect(item.effectiveAttack, 20927);
      expect(item.effectiveGearPower, greaterThan(24000));
    });
  });

  group('Moradon & Ward Nameplate Power + Tap-to-Inspect UI', () {
    testWidgets(
      'MoradonWorldView + MoradonHudOverlay show power on ALL character nameplates and inspect gear on tap (390x844 mobile)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final PlayerProfile me = _makeHero();
        final InventoryState inv = InventoryState.initial().copyWith(
          equippedItems: <String, InventoryItem?>{
            ...InventoryState.initial().equippedItems,
            'weapon': _makeTestWeapon(),
          },
        );

        const MoradonPlayerPresence remoteCitizen = MoradonPlayerPresence(
          userId: 'ambient_roamer_1',
          username: 'GeceAvcisi',
          characterClass: 'golge',
          guildName: 'NEMESIS',
          cosmeticTitle: 'Gece Avcısı',
          level: 68,
          totalPower: 89420,
          x: 1690,
          y: 1255,
          targetX: 1690,
          targetY: 1255,
          weaponGlowLevel: 10,
          weaponVisual: MoradonWeaponVisual.twilightFang,
          weaponLabel: '+10 Twilight Fang',
          isAmbientBot: true,
        );

        const MoradonPatrolGuard guard = MoradonPatrolGuard(
          id: 'guard_west_patrol',
          name: 'Kraliyet Muhafızı',
          title: 'Batı Avlu Devriyesi',
          totalPower: 45800,
          waypoints: <Offset>[Offset(1610, 1250), Offset(1640, 1250)],
          targetWaypointIndex: 1,
          x: 1610,
          y: 1250,
        );

        final MoradonHubState hubSeed = MoradonHubState(
          playerX: 1652,
          playerY: 1265,
          targetX: 1652,
          targetY: 1265,
          zoom: 1.0,
          responsiveZoomApplied: true,
          remotePlayers: <String, MoradonPlayerPresence>{
            remoteCitizen.userId: remoteCitizen,
          },
          patrolGuards: const <MoradonPatrolGuard>[guard],
        );

        await tester.pumpWidget(
          _wrapApp(
            overrides: <Override>[
              moradonHubProvider.overrideWith(
                () => _StubMoradonHubNotifier(hubSeed),
              ),
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

        // 1. Overhead nameplate power badges exist on local player, remote player, AND patrol guard!
        expect(find.byType(CharacterNameplatePowerBadge), findsNWidgets(3));
        expect(find.text('173.372 Güç'), findsOneWidget);
        expect(find.text('89.420 Güç'), findsOneWidget);
        expect(find.text('45.800 Güç'), findsOneWidget);

        // 2. Tap remote character -> CharacterInspectPanel opens with Total Power, Stats & Equipped Items!
        await tester.tap(find.text('Lv.68 GeceAvcisi'));
        await tester.pump(const Duration(milliseconds: 150));

        expect(
          find.byKey(
            const ValueKey<String>('character_inspect_panel_ambient_roamer_1'),
          ),
          findsOneWidget,
        );
        expect(find.text('TOPLAM GÜÇ'), findsOneWidget);
        expect(find.text('89.420'), findsOneWidget);
        expect(find.textContaining('KUŞANILAN EKİPMANLAR (8/8)'), findsOneWidget);
        expect(find.text('+10 Twilight Fang'), findsOneWidget);
        expect(find.text('Düello (PvP)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'RestrictionWorldHomeView shows overhead power on local hero & online peers and opens CharacterInspectPanel on tap',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final DateTime now = DateTime.now();
        final PlayerProfile me = _makeHero(
          power: 42500,
          hospitalUntil: now.add(const Duration(minutes: 15)).toUtc().toIso8601String(),
        );
        final OnlineWardPeer peer = OnlineWardPeer(
          userId: 'peer_ward_1',
          username: 'KizilSimyaci',
          displayName: 'KizilSimyaci',
          characterClass: 'simyaci',
          level: 52,
          power: 64300,
          guildName: 'ARKANA',
          untilTs: now.add(const Duration(minutes: 12)),
          x: 920,
          y: 740,
          targetX: 920,
          targetY: 740,
          lastDbOnlineSeen: now,
        );

        await tester.pumpWidget(
          _wrapApp(
            overrides: <Override>[
              restrictionWardWorldProvider.overrideWith(
                () => _StubWardWorldNotifier(
                  RestrictionWardWorldState(
                    mode: WardWorldMode.hospital,
                    playerX: 860,
                    playerY: 750,
                    targetX: 860,
                    targetY: 750,
                    onlinePeers: <String, OnlineWardPeer>{peer.userId: peer},
                  ),
                ),
              ),
            ],
            child: RestrictionWorldHomeView(
              mode: WardWorldMode.hospital,
              profile: me,
              inventoryState: InventoryState.initial(),
              totalPower: 42500,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 120));

        // Both local hero & online fellow patient show overhead power badges!
        expect(find.byType(CharacterNameplatePowerBadge), findsNWidgets(2));
        expect(find.text('42.500 Güç'), findsOneWidget);
        expect(find.text('64.300 Güç'), findsOneWidget);

        // Tap the online fellow patient -> CharacterInspectPanel opens with power & equipment slots!
        await tester.tap(
          find.byKey(const ValueKey<String>('online_ward_peer_peer_ward_1')),
        );
        await tester.pump(const Duration(milliseconds: 150));

        expect(
          find.byKey(
            const ValueKey<String>('character_inspect_panel_peer_ward_1'),
          ),
          findsOneWidget,
        );
        expect(find.text('TOPLAM GÜÇ'), findsOneWidget);
        expect(find.text('64.300'), findsOneWidget);
        expect(find.textContaining('KUŞANILAN EKİPMANLAR'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
