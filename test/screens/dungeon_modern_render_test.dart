import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PictureRecorder, Picture;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gkk_flutter/core/lighting/dungeon_light_system.dart' as dls;
import 'package:gkk_flutter/core/vfx/ground_decal_system.dart' as gds;
import 'package:gkk_flutter/models/auth_model.dart';
import 'package:gkk_flutter/models/dungeon_model.dart';
import 'package:gkk_flutter/models/dungeon_siege_model.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/models/staff_model.dart';
import 'package:gkk_flutter/providers/auth_provider.dart';
import 'package:gkk_flutter/providers/dungeon_provider.dart';
import 'package:gkk_flutter/providers/dungeon_siege_provider.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/providers/staff_provider.dart';
import 'package:gkk_flutter/screens/dungeon/dungeon_battle_screen.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/aion2_boss_illustration_catalog.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_cave_theme.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_cinematic_atmosphere.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_combat_vfx.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_monster_glb_viewport.dart';

// =============================================================================
// Fake Riverpod Providers & Test Fixtures
// =============================================================================

class _FakePlayerNotifier extends PlayerNotifier {
  _FakePlayerNotifier(this._profile);
  final PlayerProfile? _profile;

  @override
  PlayerState build() => PlayerState(
        status: _profile != null ? PlayerStatus.ready : PlayerStatus.initial,
        profile: _profile,
      );

  @override
  void clear() {
    state = const PlayerState(status: PlayerStatus.initial);
  }
}

class _FakeDungeonNotifier extends DungeonNotifier {
  _FakeDungeonNotifier(this._dungeons);
  final List<DungeonData> _dungeons;

  @override
  DungeonState build() => DungeonState(
        status: DungeonStatus.ready,
        dungeons: _dungeons,
      );
}

class _FakeInventoryNotifier extends InventoryNotifier {
  _FakeInventoryNotifier(this._snapshot);
  final InventorySnapshot _snapshot;

  @override
  InventorySnapshot build() => _snapshot;
}

class _FakeDungeonSiegeNotifier extends DungeonSiegeNotifier {
  @override
  DungeonSiegeState build() => DungeonSiegeState.initial();
}

class _FakeStaffNotifier extends StaffNotifier {
  @override
  StaffState build() => const StaffState(profile: StaffProfile.none);
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);

  @override
  Future<void> logout() async {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

PlayerProfile _testProfile({
  int level = 45,
  int energy = 90,
  int maxEnergy = 100,
  int attack = 420,
  int defense = 310,
  int power = 1850,
  String? hospitalUntil,
  String? prisonUntil,
  CharacterClass characterClass = CharacterClass.warrior,
}) {
  return PlayerProfile(
    id: 'player_test_uuid',
    authId: 'auth_test_uuid',
    username: 'AionCommander',
    email: 'commander@aion.test',
    displayName: 'AionCommander',
    avatarUrl: null,
    avatarFrame: 'glow',
    level: level,
    xp: 125000,
    gold: 50000,
    gems: 250,
    energy: energy,
    maxEnergy: maxEnergy,
    attack: attack,
    defense: defense,
    health: 1200,
    maxHealth: 1200,
    power: power,
    isOnline: true,
    isBanned: false,
    tutorialCompleted: true,
    guildId: 'guild_elyos_1',
    guildRole: 'Commander',
    guildName: 'Elyos Order',
    characterClass: characterClass,
    reputation: 1500,
    statPoints: 5,
    pvpWins: 42,
    pvpLosses: 8,
    pvpRating: 1450,
    tolerance: 15,
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

DungeonData _testDungeon({
  String id = 'dungeon_1',
  String name = 'Karanlık Mağara',
  int zone = 1,
  int powerRequirement = 300,
  int energyCost = 10,
}) {
  return DungeonData(
    id: id,
    dungeonId: id,
    name: name,
    description: 'Abis yaratıklarının toplandığı karanlık mağara.',
    difficulty: 'Normal',
    requiredLevel: 1,
    maxPlayers: 1,
    energyCost: energyCost,
    minGold: 100,
    maxGold: 250,
    lootTable: 'standard_cave',
    isGroup: false,
    powerRequirement: powerRequirement,
    zone: zone,
  );
}

Widget buildDungeonScreenHarness({
  required String initialLocation,
  PlayerProfile? profile,
  List<DungeonData>? dungeons,
  InventorySnapshot? inventorySnapshot,
  Size size = const Size(390, 844),
}) {
  final PlayerProfile testProfile = profile ?? _testProfile();
  final List<DungeonData> testDungeons = dungeons ??
      <DungeonData>[
        _testDungeon(id: 'dungeon_1', name: 'Karanlık Mağara', zone: 1, powerRequirement: 300),
        _testDungeon(id: 'dungeon_2', name: 'Kristal Yarık', zone: 2, powerRequirement: 500),
      ];
  final InventorySnapshot testInventory = inventorySnapshot ??
      const InventorySnapshot(
        items: <InventoryItem>[],
        equippedItems: <String, InventoryItem?>{},
      );

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/dungeon/battle',
        builder: (BuildContext context, GoRouterState state) =>
            const DungeonBattleScreen(),
      ),
      GoRoute(
        path: '/dungeon',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('DUNGEON_HUB'))),
      ),
      GoRoute(
        path: '/hospital',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('HOSPITAL_SCREEN'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      playerProvider.overrideWith(() => _FakePlayerNotifier(testProfile)),
      dungeonProvider.overrideWith(() => _FakeDungeonNotifier(testDungeons)),
      inventoryProvider.overrideWith(() => _FakeInventoryNotifier(testInventory)),
      dungeonSiegeProvider.overrideWith(() => _FakeDungeonSiegeNotifier()),
      staffProvider.overrideWith(() => _FakeStaffNotifier()),
      authProvider.overrideWith(() => _FakeAuthNotifier()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030407),
      ),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(top: 47, bottom: 34),
            viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
            devicePixelRatio: 2.0,
          ),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: child,
          ),
        );
      },
    ),
  );
}

// =============================================================================
// Test Suite
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dungeon 3D Perspective Arena & Camera Math', () {
    const Size viewport = Size(400.0, 800.0);
    const Arena3DCamera camera = Arena3DCamera(
      pitch: 0.52,
      height: 4.2,
      distance: 7.0,
      fov: 1.15,
      horizonYRatio: 0.42,
    );

    test('Center alignment: world X=0 projects to exact screen center width', () {
      final Offset nearCenter =
          camera.project(const dls.Vector3D(0.0, 0.0, 1.0), viewport);
      final Offset farCenter =
          camera.project(const dls.Vector3D(0.0, 0.0, 8.0), viewport);

      expect(nearCenter.dx, closeTo(200.0, 1e-4));
      expect(farCenter.dx, closeTo(200.0, 1e-4));
    });

    test('Perspective foreshortening: deeper objects project closer to horizon', () {
      final Offset nearP =
          camera.project(const dls.Vector3D(0.0, 0.0, 1.0), viewport);
      final Offset midP =
          camera.project(const dls.Vector3D(0.0, 0.0, 4.0), viewport);
      final Offset farP =
          camera.project(const dls.Vector3D(0.0, 0.0, 8.0), viewport);

      final double horizonY = viewport.height * camera.horizonYRatio; // 336.0

      // Near ground is lower on screen (larger Y), far ground is closer to horizon
      expect(nearP.dy, greaterThan(midP.dy));
      expect(midP.dy, greaterThan(farP.dy));
      expect(farP.dy, greaterThanOrEqualTo(horizonY));
    });

    test('Depth scale decreases strictly monotonically with increasing world Z', () {
      final double scaleNear = camera.depthScale(1.0, viewport);
      final double scaleMid = camera.depthScale(4.0, viewport);
      final double scaleFar = camera.depthScale(8.0, viewport);

      expect(scaleNear, greaterThan(scaleMid));
      expect(scaleMid, greaterThan(scaleFar));
      expect(scaleFar, greaterThan(0.0));
    });

    test('Symmetric left-right projection around center', () {
      final Offset left =
          camera.project(const dls.Vector3D(-2.5, 0.0, 3.0), viewport);
      final Offset right =
          camera.project(const dls.Vector3D(2.5, 0.0, 3.0), viewport);

      expect(left.dy, closeTo(right.dy, 1e-4));
      final double distLeft = 200.0 - left.dx;
      final double distRight = right.dx - 200.0;
      expect(distLeft, closeTo(distRight, 1e-4));
      expect(distLeft, greaterThan(20.0));
    });

    test('Extreme camera projection values handle gracefully without NaN or infinity', () {
      final Offset farBound =
          camera.project(const dls.Vector3D(100.0, 0.0, 500.0), viewport);
      expect(farBound.dx.isFinite, isTrue);
      expect(farBound.dy.isFinite, isTrue);

      final double farScale = camera.depthScale(500.0, viewport);
      expect(farScale.isFinite, isTrue);
      expect(farScale, greaterThan(0.0));
    });
  });

  group('Dynamic Torch Flickers & Lighting State', () {
    test('Atmosphere controller initializes default torches with authentic positions', () {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());

      expect(controller.torches.length, greaterThanOrEqualTo(3));
      final ArenaTorchConfig left =
          controller.torches.firstWhere((ArenaTorchConfig t) => t.id == 'torch_left');
      final ArenaTorchConfig right =
          controller.torches.firstWhere((ArenaTorchConfig t) => t.id == 'torch_right');

      expect(left.worldPosition.x, lessThan(0.0));
      expect(right.worldPosition.x, greaterThan(0.0));
      expect(left.color, isNotNull);
      expect(right.color, isNotNull);
      expect(controller.lightSystem.getLight('torch_left'), isNotNull);
      expect(controller.lightSystem.getLight('torch_right'), isNotNull);
    });

    test('Controller update advances time and causes torch flicker variation', () {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());

      final dls.DungeonLight torch = controller.lightSystem.getLight('torch_left')!;
      final double initialIntensity = torch.currentIntensity;
      expect(initialIntensity, greaterThan(0.0));

      // Advance by 0.5 seconds
      controller.update(0.5);
      expect(controller.timeSeconds, closeTo(0.5, 1e-6));

      // After ticking time, current intensity and positions are modulated
      expect(torch.currentIntensity, greaterThanOrEqualTo(torch.effectiveMinIntensity));
      expect(torch.currentIntensity, lessThanOrEqualTo(torch.effectiveMaxIntensity));

      // Continuous ticking
      double prevIntensity = torch.currentIntensity;
      bool varied = false;
      for (int i = 0; i < 10; ++i) {
        controller.update(0.05);
        if ((torch.currentIntensity - prevIntensity).abs() > 0.001) {
          varied = true;
          break;
        }
        prevIntensity = torch.currentIntensity;
      }
      expect(varied, isTrue);
    });

    test('Torch position wobble strictly stays within wobble radius', () {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());
      final dls.DungeonLight torch = controller.lightSystem.getLight('torch_left')!;

      for (int i = 0; i < 30; ++i) {
        controller.update(0.05);
        final double distFromAnchor =
            torch.currentPosition.distanceTo(torch.position);
        expect(
          distFromAnchor,
          lessThanOrEqualTo(torch.maxWobbleRadius + 1e-4),
        );
      }
    });
  });

  group('Soft Shadow Projection Optical Mathematics', () {
    test('Optical ray projection from light through occluder to ground plane', () {
      // Light at (0, 4.0, 0), occluder at (0, 2.0, 2.0)
      // Ray through occluder hits ground Y=0 at Z = 0 + (2.0 - 0) * (4.0 / (4.0 - 2.0)) = 4.0
      const dls.Vector3D lightPos = dls.Vector3D(0.0, 4.0, 0.0);
      const dls.Vector3D occPos = dls.Vector3D(0.0, 2.0, 2.0);

      final double dy = lightPos.y - occPos.y;
      final double t = lightPos.y / dy; // 4.0 / 2.0 = 2.0

      final double shadowX = lightPos.x + (occPos.x - lightPos.x) * t;
      final double shadowZ = lightPos.z + (occPos.z - lightPos.z) * t;

      expect(shadowX, closeTo(0.0, 1e-6));
      expect(shadowZ, closeTo(4.0, 1e-6));
    });

    test('Penumbra blur width increases with occluder-to-ground distance', () {
      const double occRadius = 0.5;
      const double distNear = 1.0;
      const double distFar = 5.0;

      final double penumbraNear = (occRadius * 24.0) * (1.0 + distNear * 0.35);
      final double penumbraFar = (occRadius * 24.0) * (1.0 + distFar * 0.35);

      expect(penumbraFar, greaterThan(penumbraNear));
      expect(penumbraNear, greaterThan(0.0));
    });

    test('Shadow occluders list contains arena arch pillars and battle monoliths', () {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());

      expect(controller.occluders.length, greaterThanOrEqualTo(4));
      for (final ArenaShadowOccluder occ in controller.occluders) {
        expect(occ.height, greaterThan(0.0));
        expect(occ.radius, greaterThan(0.0));
        expect(occ.center.y, greaterThan(0.0));
      }
    });
  });

  group('Ground Decal System Integration (Blood, Scorch, Cracked Flagstones, Slash)', () {
    test('Initial atmospheric decals are seeded on creation', () {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());

      expect(controller.decalSystem.activeDecalCount, greaterThanOrEqualTo(4));
      final List<gds.DecalType> types = controller.decalSystem.activeDecals
          .map((gds.DecalInstance d) => d.type)
          .toList();

      expect(types, contains(gds.DecalType.crackedEarth));
      expect(types, contains(gds.DecalType.scorchMark));
      expect(types, contains(gds.DecalType.bloodSplatter));
    });

    test('triggerBloodSplatter creates blood decal with crimson color and droplets', () {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());
      final int initialCount = controller.decalSystem.activeDecalCount;

      controller.triggerBloodSplatter(
        position: const gds.Vector3D(1.0, 0.0, 2.0),
        radius: 1.5,
      );

      expect(controller.decalSystem.activeDecalCount, equals(initialCount + 1));
      final gds.DecalInstance spawned = controller.decalSystem.activeDecals.last;
      expect(spawned.type, equals(gds.DecalType.bloodSplatter));
      expect(spawned.color.r, greaterThan(spawned.color.g)); // Predominantly red
      expect(spawned.currentOpacity, closeTo(1.0, 1e-4));
    });

    test('triggerScorchMark creates scorch decal and spell light flare', () {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());
      final int initialDecals = controller.decalSystem.activeDecalCount;
      final int initialLights = controller.lightSystem.lightCount;

      controller.triggerScorchMark(
        position: const gds.Vector3D(-0.5, 0.0, 2.5),
        radius: 2.0,
      );

      expect(controller.decalSystem.activeDecalCount, equals(initialDecals + 1));
      final gds.DecalInstance spawned = controller.decalSystem.activeDecals.last;
      expect(spawned.type, equals(gds.DecalType.scorchMark));

      // Also casts dynamic spell light in light system
      expect(controller.lightSystem.lightCount, equals(initialLights + 1));
    });

    test('triggerCrackedFlagstones creates cracked stone fissure network', () {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());
      final int initialCount = controller.decalSystem.activeDecalCount;

      controller.triggerCrackedFlagstones(
        position: const gds.Vector3D(0.2, 0.0, 1.8),
        radius: 1.8,
      );

      expect(controller.decalSystem.activeDecalCount, equals(initialCount + 1));
      final gds.DecalInstance spawned = controller.decalSystem.activeDecals.last;
      expect(spawned.type, equals(gds.DecalType.crackedEarth));
    });

    test('triggerSlashGouge creates directional strike furrow', () {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());
      final int initialCount = controller.decalSystem.activeDecalCount;

      controller.triggerSlashGouge(
        position: const gds.Vector3D(-1.0, 0.0, 2.2),
        strikeDir: const gds.Vector3D(0.707, 0.0, 0.707),
        length: 2.5,
      );

      expect(controller.decalSystem.activeDecalCount, equals(initialCount + 1));
      final gds.DecalInstance spawned = controller.decalSystem.activeDecals.last;
      expect(spawned.type, equals(gds.DecalType.slashGouge));
    });

    test('Decal fading and lifecycle update over time', () {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());

      controller.triggerBloodSplatter(
        position: const gds.Vector3D(0.0, 0.0, 2.0),
        lifetime: 12.0,
      );
      final gds.DecalInstance decal = controller.decalSystem.activeDecals.last;

      expect(decal.currentOpacity, closeTo(1.0, 1e-3));

      // Advance by 2.0 seconds (within full opacity before fade starts)
      controller.update(2.0);
      expect(decal.currentOpacity, closeTo(1.0, 1e-3));

      // Advance past lifetime
      controller.update(8.5);
      expect(decal.currentOpacity, lessThan(1.0));
    });
  });

  group('Multi-Tier Atmospheric Mist Simulation', () {
    test('Mist wisps list is populated across tiers 0, 1, and 2', () {
      final List<MistWisp> wisps = DungeonArena3DPainter.wisps;
      expect(wisps.length, greaterThanOrEqualTo(20));

      final Set<int> tiers = wisps.map((MistWisp w) => w.tier).toSet();
      expect(tiers, containsAll(<int>[0, 1, 2]));
    });

    test('Mist wisps drift with time and stay within bounded region', () {
      for (final MistWisp wisp in DungeonArena3DPainter.wisps) {
        for (double t = 0.0; t < 20.0; t += 4.5) {
          final double driftX =
              ((wisp.baseX + t * wisp.speed * 0.4) % 18.0) - 9.0;
          expect(driftX, greaterThanOrEqualTo(-9.0));
          expect(driftX, lessThanOrEqualTo(9.0));
        }
      }
    });
  });

  group('Dynamic Stone Wall Shadows & Magic Point Lights Pipeline', () {
    test('Optical ray projection from light through occluder to vertical stone wall', () {
      // Light at (0, 2.0, 2.0), occluder at (0, 1.5, 4.0), wall at Z = 6.8
      // dZ = 4.0 - 2.0 = 2.0
      // tz = (6.8 - 2.0) / 2.0 = 2.4
      // wallShadowX = 0 + (0 - 0) * 2.4 = 0.0
      // wallShadowY = 2.0 + (1.5 - 2.0) * 2.4 = 0.8
      const dls.Vector3D lightPos = dls.Vector3D(0.0, 2.0, 2.0);
      const dls.Vector3D occPos = dls.Vector3D(0.0, 1.5, 4.0);
      const double wallZ = 6.8;

      final double dZ = occPos.z - lightPos.z;
      final double tz = (wallZ - lightPos.z) / dZ;
      final double wallShadowX = lightPos.x + (occPos.x - lightPos.x) * tz;
      final double wallShadowY = lightPos.y + (occPos.y - lightPos.y) * tz;

      expect(tz, closeTo(2.4, 1e-4));
      expect(wallShadowX, closeTo(0.0, 1e-6));
      expect(wallShadowY, closeTo(0.8, 1e-4));
    });

    test('Wall shadow penumbra scales with distance from occluder to wall', () {
      const double occRadius = 0.4;
      const double tz = 2.0;
      const double distNear = 1.0;
      const double distFar = 4.0;

      final double penumbraNear = (occRadius * 26.0 * tz) * (1.0 + distNear * 0.28);
      final double penumbraFar = (occRadius * 26.0 * tz) * (1.0 + distFar * 0.28);

      expect(penumbraFar, greaterThan(penumbraNear));
      expect(penumbraNear, greaterThan(15.0));
    });

    test('triggerMagicSpellFlare casts dynamic expanding light in light system', () {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());
      final int initialLightCount = controller.lightSystem.lightCount;

      controller.triggerMagicSpellFlare(
        position: const dls.Vector3D(0.0, 1.5, 3.0),
        color: const Color(0xFFE040FB),
        peakIntensity: 4.8,
        duration: 1.5,
      );

      expect(controller.lightSystem.lightCount, equals(initialLightCount + 1));
      final dls.DungeonLight spawned = controller.lightSystem.lights.last;
      expect(spawned.type, equals(dls.LightType.fieryExplosion));
      expect(spawned.currentIntensity, greaterThan(0.0));
    });

    test('triggerArcaneRunePulse casts pulsing rune with breathing intensity', () {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());
      final int initialLightCount = controller.lightSystem.lightCount;

      final dls.DungeonLight rune = controller.triggerArcaneRunePulse(
        id: 'test_rune_pulse',
        position: const dls.Vector3D(1.2, 1.0, 3.5),
        color: const Color(0xFF00E5FF),
        intensity: 2.5,
      );

      expect(controller.lightSystem.lightCount, equals(initialLightCount + 1));
      expect(rune.type, equals(dls.LightType.pulsingRune));
      expect(rune.id, equals('test_rune_pulse'));

      final double initialIntensity = rune.currentIntensity;
      controller.update(0.3);
      expect(rune.currentIntensity, isNot(equals(initialIntensity)));
    });

    test('triggerEtherealSoulOrb spawns floating spectral orb with 3D orbit trajectory', () {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());
      final int initialCount = controller.lightSystem.lightCount;

      final dls.DungeonLight soul = controller.triggerEtherealSoulOrb(
        id: 'test_soul_orb',
        orbitCenter: const dls.Vector3D(0.0, 2.0, 3.0),
        intensity: 2.2,
      );

      expect(controller.lightSystem.lightCount, equals(initialCount + 1));
      expect(soul.type, equals(dls.LightType.etherealSoul));

      final dls.Vector3D pos0 = soul.currentPosition;
      controller.update(0.5);
      final dls.Vector3D pos1 = soul.currentPosition;

      expect(pos0.distanceTo(pos1), greaterThan(0.0));
    });

    test('triggerCelestialFlash creates high-intensity radial flash', () {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());
      final int initialCount = controller.lightSystem.lightCount;

      controller.triggerCelestialFlash(
        position: const dls.Vector3D(0.0, 3.0, 2.5),
        peakIntensity: 6.0,
      );

      expect(controller.lightSystem.lightCount, equals(initialCount + 1));
      final dls.DungeonLight flash = controller.lightSystem.lights.last;
      expect(flash.currentIntensity, greaterThan(3.0));
    });
  });

  group('Dungeon Cinematic Atmosphere Widget & Custom Painter Tests', () {
    testWidgets('DungeonCinematicAtmosphere mounts and renders cleanly without errors', (
      WidgetTester tester,
    ) async {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: DungeonCinematicAtmosphere(
                controller: controller,
                theme: CaveCardTheme.cyberCave,
                showTorches: true,
                showArena3D: true,
                showMist: true,
                showDecals: true,
                showDynamicShadows: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DungeonCinematicAtmosphere), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      controller.update(0.1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.timeSeconds, greaterThanOrEqualTo(0.1));

      // Clean unmount to cancel repeating ticker
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('DungeonCinematicAtmosphere renders across different aspect ratios', (
      WidgetTester tester,
    ) async {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());

      // Tablet landscape view
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1024,
              height: 768,
              child: DungeonCinematicAtmosphere(
                controller: controller,
                theme: CaveCardTheme.cyberCave,
                showTorches: true,
                showArena3D: true,
                showMist: true,
                showDecals: true,
                showDynamicShadows: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(DungeonCinematicAtmosphere), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Triggering combat decals during widget rendering updates painter cleanly', (
      WidgetTester tester,
    ) async {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: DungeonCinematicAtmosphere(
                controller: controller,
                theme: CaveCardTheme.cyberCave,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      // Trigger all combat decals
      controller.triggerBloodSplatter();
      controller.triggerScorchMark();
      controller.triggerCrackedFlagstones();
      controller.triggerSlashGouge();

      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(controller.decalSystem.activeDecalCount, greaterThanOrEqualTo(8));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('DungeonArena3DPainter paints on a standard Canvas without exceptions', (
      WidgetTester tester,
    ) async {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());

      final DungeonArena3DPainter painter = DungeonArena3DPainter(
        controller: controller,
        camera: const Arena3DCamera(),
        theme: CaveCardTheme.cyberCave,
        showTorches: true,
        showArena3D: true,
        showMist: true,
        showDecals: true,
        showDynamicShadows: true,
        showWallShadows: true,
      );

      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      const Size size = Size(400.0, 800.0);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    testWidgets('DungeonArena3DPainter renders with all magic light types without throwing', (
      WidgetTester tester,
    ) async {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());

      // Trigger all specialized light sources
      controller.triggerMagicSpellFlare();
      controller.triggerArcaneRunePulse();
      controller.triggerEtherealSoulOrb();
      controller.triggerCelestialFlash();

      final DungeonArena3DPainter painter = DungeonArena3DPainter(
        controller: controller,
        camera: const Arena3DCamera(),
        theme: CaveCardTheme.cyberCave,
        showTorches: true,
        showArena3D: true,
        showMist: true,
        showDecals: true,
        showDynamicShadows: true,
        showWallShadows: true,
      );

      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      const Size size = Size(390.0, 844.0);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    testWidgets('DungeonCinematicAtmosphere renders with wall shadows enabled and disabled', (
      WidgetTester tester,
    ) async {
      final DungeonAtmosphereController controller =
          DungeonAtmosphereController();
      addTearDown(() => controller.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: DungeonCinematicAtmosphere(
                controller: controller,
                theme: CaveCardTheme.cyberCave,
                showDynamicShadows: true,
                showWallShadows: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      // Disable wall shadows
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: DungeonCinematicAtmosphere(
                controller: controller,
                theme: CaveCardTheme.cyberCave,
                showDynamicShadows: true,
                showWallShadows: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('DungeonBattleScreen Modern Mobile Render & Controller Bindings', () {
    testWidgets('DungeonBattleScreen renders Idle phase with authentic header, energy chip, 3D atmosphere, and challenge card', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildDungeonScreenHarness(
          initialLocation:
              '/dungeon/battle?dungeon_id=dungeon_1&dungeon_name=Karanl%C4%B1k%20Ma%C4%9Fara&zone=1&energy_cost=10',
        ),
      );

      await tester.pump(const Duration(milliseconds: 80));

      expect(find.byType(DungeonBattleScreen), findsOneWidget);
      expect(find.text('Karanlık Mağara'), findsWidgets);
      expect(find.text('BÖLGE 1 • ZİNDAN SAVAŞI'), findsOneWidget);
      expect(find.text('90/100'), findsOneWidget); // Energy chip from mock player profile

      // Verify atmospheric 3D render system is mounted in backdrop
      expect(find.byType(DungeonCinematicAtmosphere), findsOneWidget);

      // Verify 3D monster toggle & preview panel
      expect(find.text('3D Canavar'), findsOneWidget);
      expect(find.text('Kahraman'), findsOneWidget);
      expect(find.byType(DungeonMonsterGlbViewport), findsOneWidget);

      // Verify Challenge card & CTAs
      expect(find.text('MEYDAN OKUMA'), findsOneWidget);
      expect(find.text('SALDIR'), findsOneWidget);
      expect(find.text('Geri Dön'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Toggling between 3D Canavar and Kahraman switches preview smoothly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildDungeonScreenHarness(
          initialLocation:
              '/dungeon/battle?dungeon_id=dungeon_1&dungeon_name=Karanl%C4%B1k%20Ma%C4%9Fara&zone=1&energy_cost=10',
        ),
      );

      await tester.pump(const Duration(milliseconds: 80));

      // Initial state is 3D monster
      expect(find.byType(DungeonMonsterGlbViewport), findsOneWidget);

      // Tap Kahraman toggle pill
      await tester.tap(find.text('Kahraman'));
      await tester.pump(const Duration(milliseconds: 100));

      // 3D Monster is switched to hero image / icon
      expect(find.byType(DungeonMonsterGlbViewport), findsNothing);

      // Tap back to 3D Canavar
      await tester.tap(find.text('3D Canavar'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DungeonMonsterGlbViewport), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Tapping SALDIR CTA transitions DungeonBattleScreen from Idle into Counting (VS Duel Intro) phase', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildDungeonScreenHarness(
          initialLocation:
              '/dungeon/battle?dungeon_id=dungeon_1&dungeon_name=Karanl%C4%B1k%20Ma%C4%9Fara&zone=1&energy_cost=10',
        ),
      );

      await tester.pump(const Duration(milliseconds: 80));

      // Tap the SALDIR CTA button
      await tester.tap(find.text('SALDIR'));
      await tester.pump(const Duration(milliseconds: 100));

      // The screen transitions to counting phase (_VsIntroView)
      expect(find.text('SEN'), findsWidgets);
      expect(find.text('VS'), findsOneWidget);
      expect(find.text('GÜÇ'), findsWidgets);
      expect(find.text('GEREKEN GÜÇ'), findsOneWidget);
      expect(find.text('300'), findsOneWidget); // Dungeon power requirement
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('DungeonBattleScreen auto-start parameter triggers countdown automatically on mount', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildDungeonScreenHarness(
          initialLocation:
              '/dungeon/battle?dungeon_id=dungeon_1&dungeon_name=Karanl%C4%B1k%20Ma%C4%9Fara&zone=1&energy_cost=10&auto=1',
        ),
      );

      // Let post-frame callbacks execute
      await tester.pump(const Duration(milliseconds: 80));

      // Auto-start initiates the VS duel sequence automatically
      expect(find.text('VS'), findsOneWidget);
      expect(find.text('SEN'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('DungeonBattleScreen preflight blocks entry when energy is insufficient', (
      WidgetTester tester,
    ) async {
      // Player with only 4 energy, dungeon requires 10
      final PlayerProfile lowEnergyPlayer = _testProfile(energy: 4);

      await tester.pumpWidget(
        buildDungeonScreenHarness(
          initialLocation:
              '/dungeon/battle?dungeon_id=dungeon_1&dungeon_name=Karanl%C4%B1k%20Ma%C4%9Fara&zone=1&energy_cost=10',
          profile: lowEnergyPlayer,
        ),
      );

      await tester.pump(const Duration(milliseconds: 80));

      // Tapping attack button should block transition
      await tester.tap(find.text('SALDIR'));
      await tester.pump(const Duration(milliseconds: 50));

      // Did not transition to VS intro because of energy preflight block
      expect(find.text('VS'), findsNothing);
      expect(find.text('MEYDAN OKUMA'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('DungeonBattleScreen preflight blocks entry when player is in hospital', (
      WidgetTester tester,
    ) async {
      final PlayerProfile hospitalizedPlayer = _testProfile(
        hospitalUntil: '2099-01-01T00:00:00Z',
      );

      await tester.pumpWidget(
        buildDungeonScreenHarness(
          initialLocation:
              '/dungeon/battle?dungeon_id=dungeon_1&dungeon_name=Karanl%C4%B1k%20Ma%C4%9Fara&zone=1&energy_cost=10',
          profile: hospitalizedPlayer,
        ),
      );

      await tester.pump(const Duration(milliseconds: 80));

      await tester.tap(find.text('SALDIR'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('VS'), findsNothing);
      expect(find.text('MEYDAN OKUMA'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('DungeonBattleScreen preflight blocks entry when player is in prison', (
      WidgetTester tester,
    ) async {
      final PlayerProfile imprisonedPlayer = _testProfile(
        prisonUntil: '2099-01-01T00:00:00Z',
      );

      await tester.pumpWidget(
        buildDungeonScreenHarness(
          initialLocation:
              '/dungeon/battle?dungeon_id=dungeon_1&dungeon_name=Karanl%C4%B1k%20Ma%C4%9Fara&zone=1&energy_cost=10',
          profile: imprisonedPlayer,
        ),
      );

      await tester.pump(const Duration(milliseconds: 80));

      await tester.tap(find.text('SALDIR'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('VS'), findsNothing);
      expect(find.text('MEYDAN OKUMA'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Empty dungeon_id triggers post-frame pop navigation cleanly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildDungeonScreenHarness(
          initialLocation: '/dungeon/battle?dungeon_id=&dungeon_name=Zindan',
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('DungeonBattleScreen renders tablet landscape (1024x768) without render overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildDungeonScreenHarness(
          initialLocation:
              '/dungeon/battle?dungeon_id=dungeon_1&dungeon_name=Karanl%C4%B1k%20Ma%C4%9Fara&zone=1&energy_cost=10',
          size: const Size(1024, 768),
        ),
      );

      await tester.pump(const Duration(milliseconds: 80));

      expect(find.byType(DungeonBattleScreen), findsOneWidget);
      expect(find.text('Karanlık Mağara'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Dungeon Battle Combat VFX, 3D Monster & Zone Palettes Suite', () {
    test('CaveCardTheme resolves authentic theme palettes for all 7 dungeon zones', () {
      for (int zone = 1; zone <= 7; zone++) {
        final CaveCardTheme? theme = CaveCardTheme.forDungeonNumber(zone);
        expect(theme, isNotNull);
        expect(theme!.assetPath, isNotEmpty);
        expect(theme.surface, isNotNull);
        expect(theme.accent, isNotNull);
        expect(theme.accentGlow, isNotNull);
        expect(theme.gradientColors, isNotEmpty);
        expect(theme.featherColors, isNotEmpty);
      }

      // Verify threat level color mappings based on success percentage
      final CaveCardTheme theme1 = CaveCardTheme.cyberCave;
      expect(theme1.threatForSuccess(95), equals(theme1.threatEasy));
      expect(theme1.threatForSuccess(65), equals(theme1.threatMedium));
      expect(theme1.threatForSuccess(40), equals(theme1.threatHard));
      expect(theme1.threatForSuccess(15), equals(theme1.threatDeadly));
    });

    test('DungeonCombatVfxController updates all 9 juice modules smoothly without error', () {
      final DungeonAtmosphereController atmosphereController =
          DungeonAtmosphereController();
      final DungeonCombatVfxController vfxController =
          DungeonCombatVfxController(atmosphereController: atmosphereController);

      addTearDown(() {
        vfxController.dispose();
        atmosphereController.dispose();
      });

      // 1. Process simulated combat lines
      vfxController.processCombatLine(
        'Kritik darbe! Alev dalgaları mağarayı sardı!',
        playerAttack: 150,
        playerDefense: 100,
      );

      vfxController.processCombatLine(
        'Düşmanın buz mızrağı zırhını sıyırdı...',
        playerAttack: 150,
        playerDefense: 100,
      );

      // 2. Advance time through frame delta
      vfxController.update(0.016);
      vfxController.update(0.016);

      // 3. Trigger manual combat feel actions
      vfxController.triggerClash(centerPoint: const Offset(195.0, 110.0));
      vfxController.triggerPlayerStrike(
        damage: 450,
        isCritical: true,
        damageType: HitDamageType.fire,
      );
      vfxController.triggerEnemyStrike(
        damage: 220,
        isCritical: false,
        damageType: HitDamageType.frost,
      );

      expect(vfxController.cameraShake.trauma, greaterThan(0.0));
      expect(vfxController.activeDamageNumbersCount, greaterThan(0));

      vfxController.update(0.05);
      expect(vfxController.cameraShake.trauma, greaterThan(0.0));
    });

    test('DungeonMonsterGlbController manages hit reaction, flinch, and recovery physics', () {
      final DungeonMonsterGlbController monsterController =
          DungeonMonsterGlbController();
      addTearDown(() => monsterController.dispose());

      expect(monsterController.hitCounter, equals(0));
      expect(monsterController.hitFlashIntensity, equals(0.0));
      expect(monsterController.flinchPitch, equals(0.0));

      // Trigger standard hit
      monsterController.triggerHitReaction(isCritical: false);
      expect(monsterController.hitCounter, equals(1));
      expect(monsterController.hitFlashIntensity, greaterThan(0.0));
      expect(monsterController.flinchPitch, greaterThan(0.0));

      // Advance frames to test decay physics
      final double flashBefore = monsterController.hitFlashIntensity;
      monsterController.update(0.05);
      expect(monsterController.hitFlashIntensity, lessThanOrEqualTo(flashBefore));

      // Trigger heavy critical hit reaction
      monsterController.triggerHitReaction(isCritical: true);
      expect(monsterController.hitCounter, equals(2));
      expect(monsterController.hitFlashIntensity, equals(1.0));
      expect(monsterController.flinchPitch, closeTo(0.28, 1e-4));
    });

    testWidgets('DungeonCombatVfxArenaHost mounts with player and enemy portraits without exceptions', (
      WidgetTester tester,
    ) async {
      final DungeonAtmosphereController atmosphereController =
          DungeonAtmosphereController();
      final DungeonCombatVfxController vfxController =
          DungeonCombatVfxController(atmosphereController: atmosphereController);

      addTearDown(() {
        vfxController.dispose();
        atmosphereController.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DungeonCombatVfxArenaHost(
                controller: vfxController,
                arenaWidth: 360,
                arenaHeight: 140,
                playerPortrait: const CircleAvatar(
                  radius: 30,
                  child: Text('P'),
                ),
                enemyPortrait: const CircleAvatar(
                  radius: 30,
                  child: Text('E'),
                ),
                clashIcon: const Icon(Icons.flash_on, color: Colors.amber),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(DungeonCombatVfxArenaHost), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
      expect(find.text('E'), findsOneWidget);
      expect(find.byIcon(Icons.flash_on), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });

    test('Aion2BossIllustrationCatalog resolves valid boss art definition for all 7 zones', () {
      for (int zone = 1; zone <= 7; zone++) {
        final Aion2BossArtDefinition boss =
            Aion2BossIllustrationCatalog.resolveForZone(zone);
        expect(boss.name, isNotEmpty);
        expect(boss.title, isNotEmpty);
        expect(boss.element, isNotEmpty);
        expect(boss.goldFiligreeColor, isNotNull);
        expect(boss.glowColor, isNotNull);
        expect(boss.tier, isNotNull);
      }
    });
  });
}
