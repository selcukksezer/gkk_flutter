import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/l10n/app_localizations.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/providers/restriction_ward_world_provider.dart';
import 'package:gkk_flutter/screens/home/home_screen.dart';
import 'package:gkk_flutter/screens/home/moradon/moradon_world_view.dart';
import 'package:gkk_flutter/screens/home/widgets/restriction_world_home_view.dart';

PlayerProfile _makeProfile({
  String id = 'me_1',
  String username = 'KaraSovalye',
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
    level: 42,
    xp: 1200,
    gold: 25000,
    gems: 80,
    energy: 65,
    maxEnergy: 100,
    attack: 220,
    defense: 180,
    health: 400,
    maxHealth: 1000,
    power: 4500,
    isOnline: true,
    isBanned: false,
    tutorialCompleted: true,
    guildId: 'guild_1',
    guildRole: 'member',
    guildName: 'Kızıl Sancak',
    referralCode: 'REF1',
    referredBy: null,
    pvpRating: 1200,
    pvpWins: 12,
    pvpLosses: 4,
    addictionLevel: 0,
    tolerance: 0,
    lastPotionUsedAt: null,
    warriorBloodlustUntil: null,
    hospitalUntil: hospitalUntil,
    hospitalReason: hospitalUntil != null ? 'dungeon_defeat' : null,
    hospitalLifetimeCount: 5,
    prisonUntil: prisonUntil,
    prisonReason: prisonUntil != null ? 'bribe_failed' : null,
    globalSuspicionLevel: 0,
    lastBribeAt: null,
    lastLoginAt: nowIso,
    lastLogin: nowIso,
    createdAt: nowIso,
    updatedAt: nowIso,
    characterClass: CharacterClass.warrior,
  );
}

class _StubPlayerNotifier extends PlayerNotifier {
  final PlayerProfile seeded;
  _StubPlayerNotifier(this.seeded);

  @override
  PlayerState build() =>
      PlayerState(status: PlayerStatus.ready, profile: seeded);

  @override
  Future<void> loadProfile() async {}
}

class _StubWardWorldNotifier extends RestrictionWardWorldNotifier {
  final WardWorldMode seededMode;
  final Map<String, OnlineWardPeer> seededPeers;

  _StubWardWorldNotifier({
    required this.seededMode,
    this.seededPeers = const <String, OnlineWardPeer>{},
  });

  @override
  RestrictionWardWorldState build() {
    return RestrictionWardWorldState(
      mode: seededMode,
      onlinePeers: seededPeers,
    );
  }

  @override
  void bindSession({
    required WardWorldMode mode,
    required PlayerProfile profile,
    required int totalPower,
  }) {
    state = state.copyWith(mode: mode);
  }

  @override
  Future<void> refreshOnlinePeers({bool silent = false}) async {}

  @override
  Future<void> loadWardChatHistory() async {}
}

Widget _wrapTestApp({
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
      home: child,
    ),
  );
}

void main() {
  group('Online-only Hospital & Prison filter', () {
    test('accepts ONLY online peers in matching active restriction', () {
      final DateTime now = DateTime.utc(2026, 10, 25, 12, 0, 0);
      final String futureIso =
          now.add(const Duration(minutes: 25)).toIso8601String();
      final String expiredIso =
          now.subtract(const Duration(minutes: 1)).toIso8601String();
      final String freshActiveIso =
          now.subtract(const Duration(minutes: 2)).toIso8601String();
      final String staleActiveIso =
          now.subtract(const Duration(minutes: 9)).toIso8601String();

      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
        // 1. Valid online hospital peer -> ACCEPTED
        <String, dynamic>{
          'id': 'u_online_1',
          'username': 'OnlineHasta1',
          'character_class': 'golge',
          'level': 35,
          'is_online': true,
          'last_active_at': freshActiveIso,
          'hospital_until': futureIso,
        },
        // 2. Offline hospital peer -> REJECTED
        <String, dynamic>{
          'id': 'u_offline_1',
          'username': 'OfflineHasta',
          'character_class': 'savasci',
          'level': 50,
          'is_online': false,
          'last_active_at': freshActiveIso,
          'hospital_until': futureIso,
        },
        // 3. Stale heartbeat (>5m) hospital peer -> REJECTED
        <String, dynamic>{
          'id': 'u_stale_1',
          'username': 'StaleHasta',
          'character_class': 'simyaci',
          'level': 28,
          'is_online': true,
          'last_active_at': staleActiveIso,
          'hospital_until': futureIso,
        },
        // 4. Expired hospital timer -> REJECTED
        <String, dynamic>{
          'id': 'u_expired_1',
          'username': 'TaburcuOlmus',
          'character_class': 'savasci',
          'level': 40,
          'is_online': true,
          'last_active_at': freshActiveIso,
          'hospital_until': expiredIso,
        },
        // 5. Online PRISON inmate (wrong ward) -> REJECTED in hospital mode
        <String, dynamic>{
          'id': 'u_prison_only',
          'username': 'OnlineMahkum',
          'character_class': 'savasci',
          'level': 44,
          'is_online': true,
          'last_active_at': freshActiveIso,
          'hospital_until': null,
          'prison_until': futureIso,
        },
        // 6. Self -> REJECTED from remote peer map
        <String, dynamic>{
          'id': 'me_1',
          'username': 'KaraSovalye',
          'character_class': 'savasci',
          'level': 42,
          'is_online': true,
          'last_active_at': freshActiveIso,
          'hospital_until': futureIso,
        },
      ];

      final List<OnlineWardPeer> hospitalAccepted =
          filterOnlineWardPeersFromRows(
            mode: WardWorldMode.hospital,
            rows: rows,
            myUserId: 'me_1',
            now: now,
          );

      expect(hospitalAccepted.length, 1);
      expect(hospitalAccepted.single.userId, 'u_online_1');
      expect(hospitalAccepted.single.displayName, 'OnlineHasta1');

      final List<OnlineWardPeer> prisonAccepted =
          filterOnlineWardPeersFromRows(
            mode: WardWorldMode.prison,
            rows: rows,
            myUserId: 'me_1',
            now: now,
          );

      expect(prisonAccepted.length, 1);
      expect(prisonAccepted.single.userId, 'u_prison_only');
      expect(prisonAccepted.single.displayName, 'OnlineMahkum');
    });
  });

  group('HomeScreen auto-switch & online-only peers', () {
    testWidgets(
      'HomeScreen shows Hospital 2.5D world + NPC healers + ONLY online fellow patients',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final DateTime now = DateTime.now();
        final PlayerProfile hospitalizedProfile = _makeProfile(
          hospitalUntil: now
              .add(const Duration(minutes: 18))
              .toUtc()
              .toIso8601String(),
        );

        final OnlineWardPeer validOnlinePeer = OnlineWardPeer(
          userId: 'peer_online_hosp',
          username: 'SifaBekleyen',
          displayName: 'SifaBekleyen',
          characterClass: 'simyaci',
          level: 31,
          guildName: 'Gümüş Ay',
          untilTs: now.add(const Duration(minutes: 14)),
          x: 980,
          y: 660,
          targetX: 980,
          targetY: 660,
          lastDbOnlineSeen: now,
        );

        // Stale/offline peer injected into state map must STILL be hidden at render time
        final OnlineWardPeer staleOfflinePeer = OnlineWardPeer(
          userId: 'peer_stale_offline',
          username: 'CevrimdisiOyuncu',
          displayName: 'CevrimdisiOyuncu',
          characterClass: 'savasci',
          level: 20,
          untilTs: now.add(const Duration(minutes: 14)),
          x: 1120,
          y: 700,
          targetX: 1120,
          targetY: 700,
          lastDbOnlineSeen: now.subtract(const Duration(minutes: 15)),
        );

        await tester.pumpWidget(
          _wrapTestApp(
            overrides: <Override>[
              playerProvider.overrideWith(
                () => _StubPlayerNotifier(hospitalizedProfile),
              ),
              restrictionWardWorldProvider.overrideWith(
                () => _StubWardWorldNotifier(
                  seededMode: WardWorldMode.hospital,
                  seededPeers: <String, OnlineWardPeer>{
                    validOnlinePeer.userId: validOnlinePeer,
                    staleOfflinePeer.userId: staleOfflinePeer,
                  },
                ),
              ),
            ],
            child: const HomeScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.byType(RestrictionWorldHomeView), findsOneWidget);
        expect(find.byType(MoradonWorldView), findsNothing);
        expect(find.text('KRALİYET ŞİFAHANESİ'), findsOneWidget);
        expect(find.text('[Baş Şifacı Lyra]'), findsOneWidget);
        expect(find.text('[Klinik Hekimi Veyron]'), findsOneWidget);

        // Online peer is visible; offline/stale peer is strictly excluded!
        expect(find.text('1 Çevrimiçi Hasta'), findsOneWidget);
        expect(find.textContaining('SifaBekleyen'), findsOneWidget);
        expect(find.textContaining('CevrimdisiOyuncu'), findsNothing);

        // Open online ward roster drawer and verify roster lists only online peer
        await tester.tap(
          find.byKey(const ValueKey<String>('toggle_online_ward_roster_btn')),
        );
        await tester.pump(const Duration(milliseconds: 120));
        expect(find.textContaining('🟢 Çevrimiçi Hastalar (1)'), findsOneWidget);
        expect(find.textContaining('CevrimdisiOyuncu'), findsNothing);
      },
    );

    testWidgets(
      'HomeScreen shows Prison 2.5D world + Warden/Guard NPCs + ONLY online fellow inmates',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final DateTime now = DateTime.now();
        final PlayerProfile imprisonedProfile = _makeProfile(
          prisonUntil: now
              .add(const Duration(minutes: 32))
              .toUtc()
              .toIso8601String(),
        );

        final OnlineWardPeer onlineInmate = OnlineWardPeer(
          userId: 'inmate_online_1',
          username: 'DemirMahkum',
          displayName: 'DemirMahkum',
          characterClass: 'golge',
          level: 48,
          untilTs: now.add(const Duration(minutes: 20)),
          x: 960,
          y: 675,
          targetX: 960,
          targetY: 675,
          lastRealtimeSeen: now,
        );

        await tester.pumpWidget(
          _wrapTestApp(
            overrides: <Override>[
              playerProvider.overrideWith(
                () => _StubPlayerNotifier(imprisonedProfile),
              ),
              restrictionWardWorldProvider.overrideWith(
                () => _StubWardWorldNotifier(
                  seededMode: WardWorldMode.prison,
                  seededPeers: <String, OnlineWardPeer>{
                    onlineInmate.userId: onlineInmate,
                  },
                ),
              ),
            ],
            child: const HomeScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.byType(RestrictionWorldHomeView), findsOneWidget);
        expect(find.byType(MoradonWorldView), findsNothing);
        expect(find.text('KRALİYET ZİNDANI'), findsOneWidget);
        expect(find.text('[Baş Gardiyan Alaric]'), findsOneWidget);
        expect(find.text('[Demir Kapı Nöbetçisi]'), findsOneWidget);
        expect(find.text('1 Çevrimiçi Mahkum'), findsOneWidget);
        expect(find.textContaining('DemirMahkum'), findsOneWidget);
        expect(find.textContaining('Kefalet ('), findsOneWidget);
      },
    );

    testWidgets(
      'RestrictionWorldHomeView works cleanly on narrow mobile portrait without overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final DateTime now = DateTime.now();
        final PlayerProfile hospitalizedProfile = _makeProfile(
          hospitalUntil: now
              .add(const Duration(minutes: 10))
              .toUtc()
              .toIso8601String(),
        );

        await tester.pumpWidget(
          _wrapTestApp(
            overrides: <Override>[
              restrictionWardWorldProvider.overrideWith(
                () => _StubWardWorldNotifier(seededMode: WardWorldMode.hospital),
              ),
            ],
            child: Scaffold(
              body: RestrictionWorldHomeView(
                mode: WardWorldMode.hospital,
                profile: hospitalizedProfile,
                inventoryState: InventoryState.initial(),
                totalPower: 4500,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 120));

        expect(tester.takeException(), isNull);
        expect(find.text('KRALİYET ŞİFAHANESİ'), findsOneWidget);
        expect(find.text('0 Çevrimiçi Hasta'), findsOneWidget);
      },
    );
  });
}
