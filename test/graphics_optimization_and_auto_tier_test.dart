import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gkk_flutter/components/common/adaptive_glass_blur.dart';
import 'package:gkk_flutter/core/services/graphics_quality_service.dart';
import 'package:gkk_flutter/screens/dungeon/dungeon_battle_profiles.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_mob_pack_rig.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GraphicsQualityService.instance.configureForTest(
      hardwareTier: GraphicsQualityTier.high,
      preference: GraphicsPreference.auto,
    );
    await GraphicsQualityService.instance.setShowFpsOverlay(false);
  });

  group('Automatic Hardware Tier Classification', () {
    test('classifies Android Go & 1-2 GB RAM potato phones as Low', () {
      expect(
        GraphicsQualityService.classifyHardwareTier(
          totalRamMb: 1024,
          cpuCores: 4,
          isLowRamDevice: true,
          devicePixelRatio: 1.5,
          shortestLogicalSide: 320,
          isMobilePlatform: true,
          isWebPlatform: false,
        ),
        GraphicsQualityTier.low,
      );

      expect(
        GraphicsQualityService.classifyHardwareTier(
          totalRamMb: 2048,
          cpuCores: 4,
          isLowRamDevice: false,
          devicePixelRatio: 2.0,
          shortestLogicalSide: 360,
          isMobilePlatform: true,
          isWebPlatform: false,
        ),
        GraphicsQualityTier.low,
      );

      expect(
        GraphicsQualityService.classifyHardwareTier(
          totalRamMb: 3072,
          cpuCores: 4,
          isLowRamDevice: false,
          devicePixelRatio: 2.0,
          shortestLogicalSide: 360,
          isMobilePlatform: true,
          isWebPlatform: false,
        ),
        GraphicsQualityTier.low,
      );
    });

    test('classifies 4 GB octa-core as Medium, 6 GB as High, 8+ GB native as Ultra', () {
      expect(
        GraphicsQualityService.classifyHardwareTier(
          totalRamMb: 4096,
          cpuCores: 8,
          isLowRamDevice: false,
          devicePixelRatio: 2.5,
          shortestLogicalSide: 390,
          isMobilePlatform: true,
          isWebPlatform: false,
        ),
        GraphicsQualityTier.medium,
      );

      expect(
        GraphicsQualityService.classifyHardwareTier(
          totalRamMb: 6144,
          cpuCores: 8,
          isLowRamDevice: false,
          devicePixelRatio: 2.75,
          shortestLogicalSide: 393,
          isMobilePlatform: true,
          isWebPlatform: false,
        ),
        GraphicsQualityTier.high,
      );

      expect(
        GraphicsQualityService.classifyHardwareTier(
          totalRamMb: 8192,
          cpuCores: 8,
          isLowRamDevice: false,
          devicePixelRatio: 3.0,
          shortestLogicalSide: 412,
          isMobilePlatform: true,
          isWebPlatform: false,
        ),
        GraphicsQualityTier.ultra,
      );
    });

    test('caps Web browser tabs at High and honors systemReduceMotion -> Low', () {
      expect(
        GraphicsQualityService.classifyHardwareTier(
          totalRamMb: 8192,
          cpuCores: 8,
          isLowRamDevice: false,
          devicePixelRatio: 2.0,
          shortestLogicalSide: 900,
          isMobilePlatform: false,
          isWebPlatform: true,
        ),
        GraphicsQualityTier.high,
      );

      expect(
        GraphicsQualityService.classifyHardwareTier(
          totalRamMb: 12288,
          cpuCores: 8,
          isLowRamDevice: false,
          devicePixelRatio: 3.0,
          shortestLogicalSide: 412,
          isMobilePlatform: true,
          isWebPlatform: false,
          systemReduceMotion: true,
        ),
        GraphicsQualityTier.low,
      );
    });
  });

  group('GraphicsProfile Budgets & Runtime FPS Auto-Downgrade', () {
    test('Low profile disables expensive GPU/CPU passes and shrinks VRAM caps', () {
      final GraphicsProfile low = GraphicsProfile.forTier(
        tier: GraphicsQualityTier.low,
        preference: GraphicsPreference.low,
        hardwareTier: GraphicsQualityTier.low,
      );

      expect(low.enableBackdropBlur, isFalse);
      expect(low.enable3dPerspective, isFalse);
      expect(low.enableDotGridOverlay, isFalse);
      expect(low.enableHeavyShadows, isFalse);
      expect(low.enableWeatherAndAtmosphere, isFalse);
      expect(low.enableForegroundOcclusion, isFalse);
      expect(low.enableCompanionPets, isFalse);
      expect(low.enablePaintedBattleVfxBitmaps, isFalse);
      expect(low.useFastSpriteQuad, isTrue);
      expect(low.moradonEnablePatrolGuards, isFalse);
      expect(low.moradonAmbientBotCount, 3);
      expect(low.moradonTickIntervalMs, 40);
      expect(low.dungeonMaxPackMobs, 3);
      expect(low.enableLive3dHubDiorama, isFalse);
      expect(low.imageCacheMaxBytes, 28 * 1024 * 1024);
    });

    test('steps down automatically in Otomatik mode on sustained frame lag', () async {
      final GraphicsQualityService svc = GraphicsQualityService.instance;
      svc.configureForTest(
        hardwareTier: GraphicsQualityTier.high,
        preference: GraphicsPreference.auto,
      );
      expect(svc.effectiveTier, GraphicsQualityTier.high);
      expect(svc.profile.autoDowngraded, isFalse);

      // 2 consecutive slow ~23 FPS windows trigger High -> Medium step-down
      final List<double> jankyWindow = List<double>.filled(44, 43.0);
      svc.ingestFrameSpanSamplesMsForTest(jankyWindow);
      expect(svc.effectiveTier, GraphicsQualityTier.high);
      svc.ingestFrameSpanSamplesMsForTest(jankyWindow);
      expect(svc.effectiveTier, GraphicsQualityTier.medium);
      expect(svc.profile.autoDowngraded, isTrue);

      // 2 more sustained janky windows step down Medium -> Low
      svc.ingestFrameSpanSamplesMsForTest(jankyWindow);
      svc.ingestFrameSpanSamplesMsForTest(jankyWindow);
      expect(svc.effectiveTier, GraphicsQualityTier.low);
      expect(svc.profile.isLow, isTrue);
    });

    test('manual preset locks tier and never auto-downgrades on slow frames', () async {
      final GraphicsQualityService svc = GraphicsQualityService.instance;
      await svc.setPreference(GraphicsPreference.ultra);
      expect(svc.effectiveTier, GraphicsQualityTier.ultra);

      final List<double> jankyWindow = List<double>.filled(44, 48.0);
      for (int i = 0; i < 5; i++) {
        svc.ingestFrameSpanSamplesMsForTest(jankyWindow);
      }
      expect(svc.effectiveTier, GraphicsQualityTier.ultra);
      expect(svc.profile.autoDowngraded, isFalse);
    });
  });

  group('Multi-Mob Pack Tier Capping', () {
    test('resolveDungeonMobPack preserves Boss/Leader slot and normalizes HP weights when capped', () {
      final DungeonBattleProfile bossProfile =
          DungeonBattleProfile.forDungeonId('dungeon_65', fallbackZone: 7);
      final List<DungeonMobPackMember> fullPack =
          resolveDungeonMobPack(bossProfile);
      expect(fullPack.length, 5);
      expect(fullPack.last.isLeader, isTrue);
      expect(fullPack.last.isBoss, isTrue);

      final List<DungeonMobPackMember> lowPack =
          resolveDungeonMobPack(bossProfile, maxMembers: 3);
      expect(lowPack.length, 3);
      expect(lowPack[0].slotIndex, 0);
      expect(lowPack[1].slotIndex, 1);
      expect(lowPack[2].slotIndex, 2);
      expect(lowPack.last.isLeader, isTrue);
      expect(lowPack.last.isBoss, isTrue);
      expect(lowPack.last.name, bossProfile.enemyName);

      final double weightSum =
          lowPack.fold<double>(0.0, (double s, DungeonMobPackMember m) => s + m.hpWeight);
      expect(weightSum, closeTo(1.0, 0.0001));
    });
  });

  group('AdaptiveGlassBlur & Quick Graphics Sheet Widgets', () {
    testWidgets('AdaptiveGlassBlur skips BackdropFilter on Low/Medium and enables on High', (WidgetTester tester) async {
      await GraphicsQualityService.instance.setPreference(GraphicsPreference.low);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AdaptiveGlassBlur(
                sigma: 10,
                child: Text('GKK Glass Child'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('GKK Glass Child'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);

      await GraphicsQualityService.instance.setPreference(GraphicsPreference.medium);
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);

      await GraphicsQualityService.instance.setPreference(GraphicsPreference.high);
      await tester.pump();
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('GraphicsQuickPill opens modal sheet and switches to Düşük + FPS overlay', (WidgetTester tester) async {
      GraphicsQualityService.instance.configureForTest(
        hardwareTier: GraphicsQualityTier.high,
        preference: GraphicsPreference.auto,
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: <Widget>[
                  Center(child: GraphicsQuickPill()),
                  LiveFpsOverlayBanner(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Oto: Yüksek'), findsOneWidget);

      await tester.tap(find.byKey(const Key('graphics_quick_pill')));
      await tester.pumpAndSettle();

      expect(find.text('GRAFİK VE PERFORMANS MODU'), findsOneWidget);
      await tester.tap(find.byKey(const Key('graphics_mode_option_low')));
      await tester.pumpAndSettle();

      expect(GraphicsQualityService.instance.effectiveTier, GraphicsQualityTier.low);

      await tester.tap(find.text('Canlı FPS Sayacını Göster'));
      await tester.pumpAndSettle();
      expect(GraphicsQualityService.instance.showFpsOverlay, isTrue);
    });
  });
}
