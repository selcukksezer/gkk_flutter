import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gkk_flutter/components/layout/game_chrome.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_controller.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_step.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track.dart';
import 'package:gkk_flutter/core/world/dynamic_skybox.dart';
import 'package:gkk_flutter/core/world/puddle_reflection_layer.dart' hide WorldVector3;
import 'package:gkk_flutter/l10n/app_localizations.dart';
import 'package:gkk_flutter/models/comeback_summary_model.dart';
import 'package:gkk_flutter/models/daily_reward_model.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/models/retention_promos_model.dart';
import 'package:gkk_flutter/models/staff_model.dart';
import 'package:gkk_flutter/providers/comeback_summary_provider.dart';
import 'package:gkk_flutter/providers/daily_reward_provider.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/player_inbox_provider.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/providers/retention_promos_provider.dart';
import 'package:gkk_flutter/providers/staff_provider.dart';
import 'package:gkk_flutter/rendering/postprocess/aces_tonemap_curve.dart';
import 'package:gkk_flutter/repositories/inventory_repository.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:gkk_flutter/screens/home/home_screen.dart';
import 'package:gkk_flutter/screens/home/widgets/hero_showcase.dart';
import 'package:gkk_flutter/screens/home/widgets/home_promo_carousel.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_3d_viewport.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_crowd_layer.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_environment_layer.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_postprocess_stack.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_scene_viewport.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_volumetric_fog.dart';
import 'package:gkk_flutter/screens/home/widgets/hub_wind_vegetation.dart';
import 'package:gkk_flutter/screens/home/widgets/pantheon_board.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

// =============================================================================
// Fake Riverpod Notifiers & Test Fixtures for Home Modern Rendering
// =============================================================================

class FakePlayerNotifier extends PlayerNotifier {
  FakePlayerNotifier({
    this.mockProfile,
    this.mockStatus = PlayerStatus.ready,
    this.errorMessage,
  });

  final PlayerProfile? mockProfile;
  final PlayerStatus mockStatus;
  final String? errorMessage;
  int loadProfileCalls = 0;

  @override
  PlayerState build() => PlayerState(
        status: mockStatus,
        profile: mockProfile,
        errorMessage: errorMessage,
      );

  @override
  Future<void> loadProfile({bool silent = false}) async {
    loadProfileCalls++;
  }
}

class FakeInventoryNotifier extends InventoryNotifier {
  FakeInventoryNotifier({this.snapshot});

  final InventorySnapshot? snapshot;
  int loadInventoryCalls = 0;

  @override
  InventoryState build() => InventoryState(
        status: InventoryStatus.ready,
        items: snapshot?.items ?? const <InventoryItem>[],
        equippedItems: snapshot?.equippedItems ?? const <String, InventoryItem?>{},
      );

  @override
  Future<void> loadInventory({bool silent = false}) async {
    loadInventoryCalls++;
  }
}

class FakeStaffNotifier extends StaffNotifier {
  int loadCalls = 0;

  @override
  StaffState build() => const StaffState(isLoading: false, profile: StaffProfile.none);

  @override
  Future<void> load({bool silent = false}) async {
    loadCalls++;
  }
}

class FakePlayerInboxNotifier extends PlayerInboxNotifier {
  int refreshCalls = 0;

  @override
  List<PlayerInboxItem> build() => const <PlayerInboxItem>[];

  @override
  Future<void> refresh() async {
    refreshCalls++;
  }
}

class FakeTutorialController extends TutorialController {
  FakeTutorialController({this.activeStep});

  final TutorialStepV2? activeStep;

  @override
  TutorialState build() => TutorialState.initial().copyWith(
        loaded: true,
        activeStep: activeStep,
      );

  @override
  Future<void> onRouteEnter(String route) async {}

  @override
  bool isTrackComplete(String trackId) => true;

  @override
  bool get hasActiveTrack => false;

  @override
  Future<void> startTrack(String trackId) async {}
}

class FakeDailyRewardNotifier extends DailyRewardNotifier {
  @override
  DailyRewardState build() => const DailyRewardState(
        autoPromptedThisSession: true,
      );

  @override
  Future<void> loadStatus() async {}
}

class FakeComebackSummaryNotifier extends ComebackSummaryNotifier {
  @override
  ComebackSummaryState build() => const ComebackSummaryState(
        shownThisSession: true,
      );

  @override
  Future<void> load() async {}
}

class FakeRetentionPromosNotifier extends RetentionPromosNotifier {
  @override
  RetentionPromosState build() => const RetentionPromosState(
        promos: RetentionPromos.empty,
      );

  @override
  Future<void> load({bool silent = false}) async {}
}

PlayerProfile _testProfile({
  CharacterClass cClass = CharacterClass.warrior,
  int energy = 90,
  int maxEnergy = 100,
  int health = 1200,
  int maxHealth = 1200,
  int tolerance = 15,
  int addictionLevel = 0,
  String? hospitalUntil,
  String? prisonUntil,
}) {
  return PlayerProfile(
    id: 'char_test_1',
    authId: 'auth_1',
    username: 'AionCommander',
    email: 'commander@aion.test',
    displayName: 'AionCommander',
    avatarUrl: null,
    avatarFrame: 'glow',
    level: 45,
    xp: 125000,
    gold: 50000,
    gems: 250.0,
    energy: energy,
    maxEnergy: maxEnergy,
    attack: 420,
    defense: 310,
    health: health,
    maxHealth: maxHealth,
    power: 1850,
    isOnline: true,
    isBanned: false,
    tutorialCompleted: true,
    guildId: 'guild_1',
    guildRole: 'Commander',
    guildName: 'Elyos Order',
    characterClass: cClass,
    reputation: 1500,
    statPoints: 5,
    pvpWins: 42,
    pvpLosses: 8,
    pvpRating: 1450,
    tolerance: tolerance,
    addictionLevel: addictionLevel,
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

InventorySnapshot _testInventorySnapshot() {
  return const InventorySnapshot(
    items: <InventoryItem>[],
    equippedItems: <String, InventoryItem?>{},
  );
}

Widget _wrapHomeScreen({
  Widget? child,
  PlayerProfile? profile,
  PlayerStatus status = PlayerStatus.ready,
  String? errorMessage,
  InventorySnapshot? snapshot,
  Size size = const Size(393, 852), // iPhone 14 Pro reference
  EdgeInsets padding = const EdgeInsets.only(top: 59, bottom: 34),
  List<Override> additionalOverrides = const <Override>[],
}) {
  final GoRouter testRouter = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) =>
            child ?? const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.characterSelect,
        builder: (BuildContext context, GoRouterState state) => const SizedBox(),
      ),
      GoRoute(
        path: AppRoutes.quests,
        builder: (BuildContext context, GoRouterState state) => const SizedBox(),
      ),
      GoRoute(
        path: AppRoutes.trade,
        builder: (BuildContext context, GoRouterState state) => const SizedBox(),
      ),
      GoRoute(
        path: AppRoutes.guildWar,
        builder: (BuildContext context, GoRouterState state) => const SizedBox(),
      ),
      GoRoute(
        path: AppRoutes.dungeon,
        builder: (BuildContext context, GoRouterState state) => const SizedBox(),
      ),
      GoRoute(
        path: AppRoutes.inventory,
        builder: (BuildContext context, GoRouterState state) => const SizedBox(),
      ),
      GoRoute(
        path: AppRoutes.character,
        builder: (BuildContext context, GoRouterState state) => const SizedBox(),
      ),
      GoRoute(
        path: AppRoutes.shop,
        builder: (BuildContext context, GoRouterState state) => const SizedBox(),
      ),
      GoRoute(
        path: AppRoutes.hospital,
        builder: (BuildContext context, GoRouterState state) => const SizedBox(),
      ),
      GoRoute(
        path: AppRoutes.prison,
        builder: (BuildContext context, GoRouterState state) => const SizedBox(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      playerProvider.overrideWith(
        () => FakePlayerNotifier(
          mockProfile: status == PlayerStatus.ready ? (profile ?? _testProfile()) : null,
          mockStatus: status,
          errorMessage: errorMessage,
        ),
      ),
      inventoryProvider.overrideWith(
        () => FakeInventoryNotifier(
          snapshot: snapshot ?? _testInventorySnapshot(),
        ),
      ),
      staffProvider.overrideWith(() => FakeStaffNotifier()),
      playerInboxProvider.overrideWith(() => FakePlayerInboxNotifier()),
      tutorialProvider.overrideWith(() => FakeTutorialController()),
      dailyRewardProvider.overrideWith(() => FakeDailyRewardNotifier()),
      comebackSummaryProvider.overrideWith(() => FakeComebackSummaryNotifier()),
      retentionPromosProvider.overrideWith(() => FakeRetentionPromosNotifier()),
      ...additionalOverrides,
    ],
    child: MaterialApp.router(
      routerConfig: testRouter,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.liquidGold,
          secondary: AppColors.accentBlue,
          surface: AppColors.bgSurface,
        ),
      ),
      builder: (BuildContext context, Widget? routerChild) {
        return MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: padding,
            viewPadding: padding,
            devicePixelRatio: 3.0,
          ),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: routerChild,
          ),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // 1. Volumetric Fog & Atmospheric Mie Scattering Math Tests
  // ===========================================================================
  group('Volumetric Fog & Mie Scattering Math Tests', () {
    test('Exponential height density evaluates base density at ground level', () {
      final double groundDensity = VolumetricFogMath.evaluateExponentialDensity(
        y: 0.65,
        groundLevel: 0.65,
        baseDensity: 0.5,
        heightFalloff: 0.0035,
      );
      expect(groundDensity, closeTo(0.5, 1e-6));
    });

    test('Exponential height density decays monotonically above ground level', () {
      const double groundLevel = 0.65;
      const double baseDensity = 0.5;
      const double heightFalloff = 0.0035;

      final double lowAltitude = VolumetricFogMath.evaluateExponentialDensity(
        y: 0.60, // 0.05 units above ground
        groundLevel: groundLevel,
        baseDensity: baseDensity,
        heightFalloff: heightFalloff,
      );

      final double highAltitude = VolumetricFogMath.evaluateExponentialDensity(
        y: 0.20, // 0.45 units above ground
        groundLevel: groundLevel,
        baseDensity: baseDensity,
        heightFalloff: heightFalloff,
      );

      expect(lowAltitude, lessThan(baseDensity));
      expect(highAltitude, lessThan(lowAltitude));
      expect(highAltitude, greaterThan(0.0));
    });

    test('Henyey-Greenstein Mie phase exhibits strong forward peak at cosTheta = 1.0', () {
      const double g = 0.75;
      final double forwardPhase = VolumetricFogMath.evaluateHenyeyGreensteinPhase(
        cosTheta: 1.0,
        g: g,
      );

      final double sidePhase = VolumetricFogMath.evaluateHenyeyGreensteinPhase(
        cosTheta: 0.0,
        g: g,
      );

      final double backPhase = VolumetricFogMath.evaluateHenyeyGreensteinPhase(
        cosTheta: -1.0,
        g: g,
      );

      expect(forwardPhase, greaterThan(sidePhase));
      expect(sidePhase, greaterThan(backPhase));
      expect(forwardPhase, greaterThan(1.5));
      expect(backPhase, greaterThan(0.0));
    });

    test('Henyey-Greenstein clamps out-of-range cosTheta safely', () {
      const double g = 0.7;
      final double clampedHigh = VolumetricFogMath.evaluateHenyeyGreensteinPhase(
        cosTheta: 2.5,
        g: g,
      );
      final double normalHigh = VolumetricFogMath.evaluateHenyeyGreensteinPhase(
        cosTheta: 1.0,
        g: g,
      );
      expect(clampedHigh, equals(normalHigh));
    });

    test('Beer-Lambert transmittance decreases exponentially with optical depth', () {
      expect(VolumetricFogMath.evaluateTransmittance(0.0), closeTo(1.0, 1e-6));
      expect(VolumetricFogMath.evaluateTransmittance(1.0), closeTo(math.exp(-1.0), 1e-6));

      final double t2 = VolumetricFogMath.evaluateTransmittance(2.0);
      final double t5 = VolumetricFogMath.evaluateTransmittance(5.0);
      expect(t2, lessThan(math.exp(-1.0)));
      expect(t5, lessThan(t2));
      expect(t5, greaterThan(0.0));
    });

    test('Procedural mist density stays normalized in [0.0, 1.0]', () {
      for (double x = 0.0; x <= 2.0; x += 0.25) {
        for (double t = 0.0; t <= 5.0; t += 1.0) {
          final double d = VolumetricFogMath.evaluateMistDensity(
            x: x,
            y: 0.5,
            time: t,
            speed: 0.05,
          );
          expect(d, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('VolumetricFogController updates palette according to time of day', () {
      final VolumetricFogController controller = VolumetricFogController();

      // Day (12:00)
      controller.updateCelestialOrientation(
        sunElevation: 0.8,
        sunAzimuth: 0.0,
        timeOfDayHours: 12.0,
      );
      expect(controller.currentFogColor, equals(controller.config.fogColorDay));
      expect(controller.currentShaftColor, equals(controller.config.lightShaftColorDay));

      // Dusk (19:00)
      controller.updateCelestialOrientation(
        sunElevation: 0.1,
        sunAzimuth: 1.2,
        timeOfDayHours: 19.0,
      );
      expect(controller.currentFogColor, isNot(equals(controller.config.fogColorDay)));

      // Night (23:00)
      controller.updateCelestialOrientation(
        sunElevation: -0.6,
        sunAzimuth: 3.1,
        timeOfDayHours: 23.0,
      );
      expect(controller.currentFogColor, equals(controller.config.fogColorNight));
      expect(controller.currentShaftColor, equals(controller.config.lightShaftColorNight));

      // Tick advances time
      final double initialTime = controller.elapsedTime;
      controller.tick(0.05);
      expect(controller.elapsedTime, closeTo(initialTime + 0.05, 1e-6));
    });
  });

  // ===========================================================================
  // 2. Wind & Vegetation Vertex Displacement Tests
  // ===========================================================================
  group('Wind & Vegetation Vertex Displacement Tests', () {
    test('evaluateWindStrength maintains positive speed with gust harmonics', () {
      const WindSimulationConfig cfg = WindSimulationConfig(
        baseSpeed: 3.0,
        gustStrength: 0.5,
        gustFrequency: 0.4,
      );

      for (double t = 0.0; t < 10.0; t += 0.5) {
        final double speed = WindDisplacementMath.evaluateWindStrength(
          time: t,
          baseSpeed: cfg.baseSpeed,
          gustStrength: cfg.gustStrength,
          gustFrequency: cfg.gustFrequency,
        );
        expect(speed, greaterThan(0.0));
        expect(speed, lessThanOrEqualTo(cfg.baseSpeed * (1.0 + cfg.gustStrength * 1.5)));
      }
    });

    test('Foliage displacement enforces fixed boundary condition at root (y = rootY)', () {
      const WindSimulationConfig cfg = WindSimulationConfig();
      const double rootY = 400.0;
      const double totalHeight = 150.0;

      final Offset rootDisp = WindDisplacementMath.evaluateFoliageDisplacement(
        vertexPos: const Offset(100.0, rootY), // Exactly at root
        rootY: rootY,
        totalHeight: totalHeight,
        time: 1.5,
        config: cfg,
        vertexWeightTip: 1.0,
        vertexWeightFlutter: 0.0,
      );

      expect(rootDisp.dx, closeTo(0.0, 1e-6));
      expect(rootDisp.dy, closeTo(0.0, 1e-6));
    });

    test('Foliage displacement scales quadratically with height', () {
      const WindSimulationConfig cfg = WindSimulationConfig();
      const double rootY = 400.0;
      const double totalHeight = 200.0;
      const double time = 0.5;

      final Offset midDisp = WindDisplacementMath.evaluateFoliageDisplacement(
        vertexPos: const Offset(100.0, 300.0), // Half height (h/H = 0.5 -> factor = 0.25)
        rootY: rootY,
        totalHeight: totalHeight,
        time: time,
        config: cfg,
        vertexWeightTip: 1.0,
        vertexWeightFlutter: 0.0,
      );

      final Offset tipDisp = WindDisplacementMath.evaluateFoliageDisplacement(
        vertexPos: const Offset(100.0, 200.0), // Full height (h/H = 1.0 -> factor = 1.0)
        rootY: rootY,
        totalHeight: totalHeight,
        time: time,
        config: cfg,
        vertexWeightTip: 1.0,
        vertexWeightFlutter: 0.0,
      );

      expect(tipDisp.distance, greaterThan(midDisp.distance));
    });

    test('Banner wave evaluates zero displacement at pin origin (x = 0)', () {
      final double waveAtPin = WindDisplacementMath.evaluateBannerWave(
        distanceAlongCloth: 0.0,
        totalLength: 100.0,
        time: 2.0,
        windSpeed: 3.0,
        waveFrequency: 0.8,
      );
      expect(waveAtPin, closeTo(0.0, 1e-6));
    });

    test('computeAdjustedNormal returns normalized unit vector', () {
      final Offset adjusted = WindDisplacementMath.computeAdjustedNormal(
        originalNormal: const Offset(0.0, -1.0),
        displacementDeltaY: 5.0,
        deltaY: 20.0,
      );

      final double len = math.sqrt(adjusted.dx * adjusted.dx + adjusted.dy * adjusted.dy);
      expect(len, closeTo(1.0, 1e-5));
      expect(adjusted.dx, isNot(0.0));
    });

    test('HubWindVegetationController updates global illumination', () {
      final HubWindVegetationController controller = HubWindVegetationController();
      const WorldGiUniforms testGi = WorldGiUniforms(
        zenithColor: LinearColor(0.2, 0.4, 0.8),
        horizonColor: LinearColor(0.5, 0.4, 0.3),
        groundColor: LinearColor(0.1, 0.1, 0.1),
        mainLightDirection: SkyVector3(0.5, 0.7, 0.2),
        mainLightRadiance: LinearColor(1.5, 1.2, 0.9),
        mainLightIntensity: 1.2,
        shL00: LinearColor.black,
        shL1Y: LinearColor.black,
        shL1X: LinearColor.black,
        shL1Z: LinearColor.black,
        ambientOcclusionFactor: 0.1,
      );

      controller.updateGlobalIllumination(testGi);
      expect(controller.directionalRadiance.r, closeTo(1.5, 1e-6));
      expect(controller.ambientSkylight.b, closeTo(0.8, 1e-6));
    });
  });

  // ===========================================================================
  // 3. PBR Cobblestone & Environment Architecture Tests
  // ===========================================================================
  group('PBR Cobblestone & Environment Architecture Tests', () {
    test('HubTorchLight attenuates with distance-squared and produces organic flicker', () {
      const HubTorchLight torch = HubTorchLight(
        position: Offset(100.0, 100.0),
        radius: 200.0,
        baseColor: Color(0xFFFF9933),
        intensity: 1.5,
        flickerSpeed: 8.0,
        flickerPhase: 0.0,
      );

      final double closeIntensity = torch.evaluateIntensity(0.0, 0.0);
      final double midIntensity = torch.evaluateIntensity(100.0, 0.0);
      final double farIntensity = torch.evaluateIntensity(300.0, 0.0);

      expect(closeIntensity, greaterThan(midIntensity));
      expect(midIntensity, greaterThan(farIntensity));
      expect(closeIntensity, greaterThan(1.0));
      expect(farIntensity, lessThan(0.5));
    });

    test('HubEnvironmentController updates GI parameters', () {
      final HubEnvironmentController controller = HubEnvironmentController();
      const WorldGiUniforms testGi = WorldGiUniforms(
        zenithColor: LinearColor(0.15, 0.25, 0.45),
        horizonColor: LinearColor(0.4, 0.3, 0.2),
        groundColor: LinearColor(0.05, 0.08, 0.1),
        mainLightDirection: SkyVector3(0.0, 0.6, 0.8),
        mainLightRadiance: LinearColor(2.0, 1.8, 1.4),
        mainLightIntensity: 1.5,
        shL00: LinearColor.black,
        shL1Y: LinearColor.black,
        shL1X: LinearColor.black,
        shL1Z: LinearColor.black,
        ambientOcclusionFactor: 0.1,
      );

      controller.updateGlobalIllumination(testGi);
      expect(controller.ambientZenith.b, closeTo(0.45, 1e-6));
      expect(controller.ambientGround.r, closeTo(0.05, 1e-6));
      expect(controller.sunRadiance.r, closeTo(2.0, 1e-6));
      expect(controller.sunElevation, closeTo(0.6, 0.1));
    });
  });

  // ===========================================================================
  // 4. Post-Processing Stack & ACES Tonemapping Tests
  // ===========================================================================
  group('Post-Processing Stack & ACES Tonemapping Tests', () {
    test('HubPostProcessConfig initializes with valid ACES and SSAO defaults', () {
      const HubPostProcessConfig config = HubPostProcessConfig();

      expect(config.enableSsao, isTrue);
      expect(config.enableBloom, isTrue);
      expect(config.enableAcesTonemap, isTrue);
      expect(config.acesParams.fitType, equals(AcesFitType.stephenHill));
      expect(config.acesParams.gammaMode, equals(GammaMode.accurateSrgb));
      expect(config.ssaoParams.radius, greaterThan(0.0));
      expect(config.bloomThreshold, closeTo(0.72, 1e-4));
    });

    test('HubPostProcessConfig copyWith modifies parameters accurately', () {
      const HubPostProcessConfig original = HubPostProcessConfig();
      final HubPostProcessConfig modified = original.copyWith(
        enableBloom: false,
        exposure: 1.5,
        vignetteStrength: 0.6,
      );

      expect(modified.enableBloom, isFalse);
      expect(modified.enableSsao, isTrue);
      expect(modified.exposure, closeTo(1.5, 1e-6));
      expect(modified.vignetteStrength, closeTo(0.6, 1e-6));
    });

    test('HubPostProcessController updates config and pipeline parameters', () {
      final HubPostProcessController controller = HubPostProcessController();
      final HubPostProcessConfig newCfg = controller.config.copyWith(
        exposure: 1.3,
      );

      controller.updateConfig(newCfg);
      expect(controller.config.exposure, closeTo(1.3, 1e-6));
    });
  });

  // ===========================================================================
  // 5. Hub Scene Viewport Orchestrator & Camera Parallax Tests
  // ===========================================================================
  group('Hub Scene Viewport Orchestrator & Camera Parallax Tests', () {
    test('HubSceneViewportController initializes all visual subsystems', () {
      final HubSceneViewportController controller = HubSceneViewportController(
        initialHours: 17.5,
      );

      expect(controller.skyboxController, isNotNull);
      expect(controller.environmentController, isNotNull);
      expect(controller.windController, isNotNull);
      expect(controller.puddleController, isNotNull);
      expect(controller.fogController, isNotNull);
      expect(controller.postProcessController, isNotNull);
      expect(controller.cameraController, isNotNull);
      expect(controller.scrollOffset, equals(0.0));

      controller.dispose();
    });

    test('handleScroll updates vertical and lateral camera parallax smoothly', () {
      final HubSceneViewportController controller = HubSceneViewportController();

      controller.handleScroll(250.0);
      expect(controller.scrollOffset, closeTo(250.0, 1e-6));
      expect(controller.cameraParallax.dy, lessThan(0.0)); // moves upward as user scrolls down
      expect(controller.cameraParallax.dx.abs(), greaterThan(0.0));

      controller.dispose();
    });

    test('Controller update advances simulations cleanly', () {
      final HubSceneViewportController controller = HubSceneViewportController();
      final double initialTime = controller.puddleController.time;

      controller.update(0.05);
      expect(controller.puddleController.time, greaterThan(initialTime));

      controller.dispose();
    });
  });

  // ===========================================================================
  // 6. Widget Hierarchy & Rendering Integration Tests
  // ===========================================================================
  group('Widget Hierarchy & Rendering Integration Tests', () {
    testWidgets('HubSceneViewport mounts and renders all AAA layers without error', (
      WidgetTester tester,
    ) async {
      final HubSceneViewportController controller = HubSceneViewportController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 800,
            child: HubSceneViewport(
              controller: controller,
              enablePostProcess: true,
              child: const Center(
                child: Text('Test Foreground Content'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(HubSceneViewport), findsOneWidget);
      expect(find.byType(DynamicSkyboxView), findsOneWidget);
      expect(find.byType(HubEnvironmentLayer), findsOneWidget);
      expect(find.byType(HubCrowdBackgroundLayer), findsOneWidget);
      expect(find.byType(HubWindVegetationLayer), findsOneWidget);
      expect(find.byType(Hub3dWorldPropsLayer), findsOneWidget);
      expect(find.byType(PuddleReflectionLayer), findsOneWidget);
      expect(find.byType(VolumetricFogLayer), findsOneWidget);
      expect(find.byType(HubPostProcessStack), findsOneWidget);
      expect(find.text('Test Foreground Content'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      controller.dispose();
    });

    testWidgets('HubSceneViewport bypasses HubPostProcessStack when enablePostProcess is false', (
      WidgetTester tester,
    ) async {
      final HubSceneViewportController controller = HubSceneViewportController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 800,
            child: HubSceneViewport(
              controller: controller,
              enablePostProcess: false,
              child: const Center(
                child: Text('Raw Viewport Content'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(HubSceneViewport), findsOneWidget);
      expect(find.byType(HubPostProcessStack), findsNothing);
      expect(find.text('Raw Viewport Content'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      controller.dispose();
    });

    testWidgets('HubSceneViewport handles tap, focal touch pulse, double-tap and long press', (
      WidgetTester tester,
    ) async {
      final HubSceneViewportController controller = HubSceneViewportController();
      bool tapped = false;
      Offset? focalTapOffset;
      bool doubleTapped = false;
      bool longPressed = false;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 800,
            child: HubSceneViewport(
              controller: controller,
              onTap: () => tapped = true,
              onFocalPointTap: (Offset pos) => focalTapOffset = pos,
              onDoubleTap: () => doubleTapped = true,
              onLongPress: () => longPressed = true,
              child: const SizedBox(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      // 1. Single tap triggers focal point tap
      await tester.tapAt(const Offset(250.0, 400.0));
      await tester.pump();
      expect(tapped, isTrue);
      expect(focalTapOffset, isNotNull);
      expect(controller.cameraParallax, isNot(equals(Offset.zero)));

      // 2. Double tap resets focal camera impulse
      await tester.tapAt(const Offset(250.0, 400.0));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(250.0, 400.0));
      await tester.pump();
      expect(doubleTapped, isTrue);

      // 3. Long press
      await tester.longPressAt(const Offset(200.0, 400.0));
      await tester.pump();
      expect(longPressed, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      controller.dispose();
    });

    testWidgets('VolumetricFogLayer custom painter executes without throwing', (
      WidgetTester tester,
    ) async {
      final VolumetricFogController controller = VolumetricFogController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 400,
            child: VolumetricFogLayer(
              controller: controller,
              parallaxOffset: const Offset(10.0, -15.0),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(VolumetricFogLayer), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      controller.dispose();
    });

    testWidgets('HubWindVegetationLayer custom painter executes without throwing', (
      WidgetTester tester,
    ) async {
      final HubWindVegetationController controller = HubWindVegetationController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 400,
            child: HubWindVegetationLayer(
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(HubWindVegetationLayer), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      controller.dispose();
    });

    testWidgets('HubEnvironmentLayer custom painter executes without throwing', (
      WidgetTester tester,
    ) async {
      final HubEnvironmentController controller = HubEnvironmentController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 400,
            child: HubEnvironmentLayer(
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(HubEnvironmentLayer), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      controller.dispose();
    });
  });

  // ===========================================================================
  // 7. HomeScreen State Lifecycle & Riverpod Integration Tests
  // ===========================================================================
  group('HomeScreen State Lifecycle & Riverpod Integration Tests', () {
    testWidgets('HomeScreen renders progressive _HomeSkeleton when playerProvider is loading or initial', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapHomeScreen(
          status: PlayerStatus.loading,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(GameTopBar), findsOneWidget);
      expect(find.byType(GameBottomBar), findsOneWidget);
      expect(find.byType(HubSceneViewport), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('HomeScreen renders _HomeErrorView with retry button when playerProvider status is error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapHomeScreen(
          status: PlayerStatus.error,
          errorMessage: 'Profil verisi sunucudan alınamadı.',
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Profil verisi sunucudan alınamadı.'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // Tap retry button
      await tester.tap(find.text('Tekrar Dene'));
      await tester.pump();

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('HomeScreen renders full _HomeDashboard, GameTopBar, GameBottomBar, and HubSceneViewport when ready', (
      WidgetTester tester,
    ) async {
      final PlayerProfile profile = _testProfile();

      await tester.pumpWidget(
        _wrapHomeScreen(
          profile: profile,
          status: PlayerStatus.ready,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(GameTopBar), findsOneWidget);
      expect(find.byType(GameBottomBar), findsOneWidget);
      expect(find.byType(HubSceneViewport), findsOneWidget);
      expect(find.byType(HeroShowcase), findsOneWidget);
      expect(find.byType(HomePromoCarousel), findsOneWidget);
      expect(find.byType(PantheonBoard), findsOneWidget);

      // Verify character name and quick access shortcuts
      expect(find.text('AionCommander'), findsWidgets);
      expect(find.text('Görevler'), findsOneWidget);
      expect(find.text('Ticaret'), findsOneWidget);
      expect(find.text('Lonca Savaşı'), findsOneWidget);
      expect(find.text('Zindan'), findsOneWidget);

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('HomeScreen shows top-right warning stack when player has low energy or health alerts', (
      WidgetTester tester,
    ) async {
      final PlayerProfile lowEnergyProfile = _testProfile(
        energy: 10,
        health: 200,
        maxHealth: 1200,
      );

      await tester.pumpWidget(
        _wrapHomeScreen(
          profile: lowEnergyProfile,
          status: PlayerStatus.ready,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // In low energy state (< 20), WarningStack displays 'Kritik Enerji' badge
      expect(find.text('Kritik Enerji'), findsOneWidget);

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('HomeScreen pull-to-refresh executes cleanly without throwing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapHomeScreen(
          profile: _testProfile(),
          status: PlayerStatus.ready,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(RefreshIndicator), findsOneWidget);

      // Perform fling downward to trigger refresh
      await tester.fling(find.byType(ListView).first, const Offset(0.0, 300.0), 1000.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  // ===========================================================================
  // 8. Mobile Viewport Responsiveness & Aion 2 Mobile Fidelity Tests
  // ===========================================================================
  group('Mobile Viewport Responsiveness & Aion 2 Mobile Fidelity Tests', () {
    testWidgets('HomeScreen renders cleanly on iPhone 14 Pro (393x852) without overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapHomeScreen(
          profile: _testProfile(),
          status: PlayerStatus.ready,
          size: const Size(393, 852),
          padding: const EdgeInsets.only(top: 59, bottom: 34),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(HubSceneViewport), findsOneWidget);
      expect(find.byType(HeroShowcase), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('HomeScreen renders cleanly on Pixel 7 (412x915) without overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapHomeScreen(
          profile: _testProfile(cClass: CharacterClass.shadow),
          status: PlayerStatus.ready,
          size: const Size(412, 915),
          padding: const EdgeInsets.only(top: 24, bottom: 16),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(HubSceneViewport), findsOneWidget);
      expect(find.byType(HeroShowcase), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('HomeScreen renders cleanly on Compact Mobile (360x640) without overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapHomeScreen(
          profile: _testProfile(cClass: CharacterClass.alchemist),
          status: PlayerStatus.ready,
          size: const Size(360, 640),
          padding: const EdgeInsets.only(top: 20, bottom: 10),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(HubSceneViewport), findsOneWidget);
      expect(find.byType(HeroShowcase), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
