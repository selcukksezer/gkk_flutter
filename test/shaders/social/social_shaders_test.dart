import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/shaders/social/social_shaders.dart';

/// Fake uniform storage that mirrors FragmentShader uniform slot mapping
/// without violating Dart 3's `base class FragmentShader` constraint.
///
/// In Dart 3, `ui.FragmentShader` is a base class and cannot be implemented
/// (`implements ui.FragmentShader` causes compile error outside `dart:ui`).
/// Testing uniform buffers directly via wrapper arrays and fake uniform
/// recorders achieves 100% verification without illegal mock implementations.
class FakeUniformBuffer {
  final Map<int, double> floats = <int, double>{};
  final Map<int, ui.Image> samplers = <int, ui.Image>{};

  void setFloat(int index, double value) {
    floats[index] = value;
  }

  void setImageSampler(int index, ui.Image image) {
    samplers[index] = image;
  }

  void loadFromList(List<double> values) {
    for (int i = 0; i < values.length; i++) {
      floats[i] = values[i];
    }
  }

  void loadFromFloat32List(Float32List values) {
    for (int i = 0; i < values.length; i++) {
      floats[i] = values[i];
    }
  }

  int get floatCount => floats.length;
  double? operator [](int index) => floats[index];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SocialThemeTokens & Models', () {
    test('SocialThemeTokens defines valid colors and gradients', () {
      expect(SocialThemeTokens.celestialGold, isA<Color>());
      expect(SocialThemeTokens.aetherCyan, isA<Color>());
      expect(SocialThemeTokens.abyssVoid, isA<Color>());
      expect(SocialThemeTokens.elyosGold, isA<Color>());
      expect(SocialThemeTokens.asmodianViolet, isA<Color>());
      expect(SocialThemeTokens.balaurFlame, isA<Color>());
      expect(SocialThemeTokens.daevaPrismViolet, isA<Color>());

      final shadows = SocialThemeTokens.celestialGlow();
      expect(shadows, isNotEmpty);
      final goldShadows = SocialThemeTokens.goldGlow();
      expect(goldShadows, isNotEmpty);
    });

    test('SocialRewardType metadata properties are valid', () {
      for (final type in SocialRewardType.values) {
        expect(type.displayName, isNotEmpty);
        expect(type.subtitle, isNotEmpty);
        expect(type.primaryColor, isA<Color>());
        expect(type.accentGlow, isA<Color>());
      }
    });

    test('SocialRewardRarity properties are valid', () {
      for (final rarity in SocialRewardRarity.values) {
        expect(rarity.label, isNotEmpty);
        expect(rarity.color, isA<Color>());
        expect(rarity.auraColors, isNotEmpty);
      }
    });

    test('EmblemFaction properties are valid', () {
      for (final faction in EmblemFaction.values) {
        expect(faction.displayName, isNotEmpty);
        expect(faction.primaryAura, isA<Color>());
        expect(faction.coreColor, isA<Color>());
      }
    });

    test('CrystalColorVariant properties are valid', () {
      for (final variant in CrystalColorVariant.values) {
        expect(variant.primary, isA<Color>());
        expect(variant.deep, isA<Color>());
        expect(variant.highlight, isA<Color>());
      }
    });
  });

  group('CelestialBannerWidget Tests', () {
    testWidgets('renders default CelestialBannerWidget without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget(
              title: 'Test Banner',
              subtitle: 'Aion 2 Celestial Shader',
              badgeText: 'HONOR',
            ),
          ),
        ),
      );

      expect(find.text('Test Banner'), findsOneWidget);
      expect(find.text('Aion 2 Celestial Shader'), findsOneWidget);
      expect(find.text('HONOR'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('renders CelestialBannerWidget.guildHeader factory', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget.guildHeader(
              guildName: 'Legion of Elysea',
              levelText: 'LV. 25',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Legion of Elysea'), findsOneWidget);
      expect(find.text('LV. 25'), findsOneWidget);

      await tester.tap(find.text('Legion of Elysea'));
      expect(tapped, isTrue);
    });

    testWidgets('renders CelestialBannerWidget.seasonPassMilestone factory', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget.seasonPassMilestone(
              seasonTitle: 'Season IV: Abyss Awakening',
              tierText: 'Tier 50',
              daysRemaining: '14 Days Left',
            ),
          ),
        ),
      );

      expect(find.text('Season IV: Abyss Awakening'), findsOneWidget);
      expect(find.text('SEASON PASS'), findsOneWidget);
    });

    testWidgets('renders CelestialBannerWidget.questClaim factory', (tester) async {
      bool claimed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget.questClaim(
              questTitle: 'Slay the Balaur Overlord',
              rewardDescription: 'Earn 500 Honor Points',
              onClaim: () => claimed = true,
            ),
          ),
        ),
      );

      expect(find.text('Slay the Balaur Overlord'), findsOneWidget);
      expect(find.text('CLAIM READY'), findsOneWidget);

      await tester.tap(find.text('Slay the Balaur Overlord'));
      expect(claimed, isTrue);
    });

    testWidgets('renders CelestialBannerWidget.leaderboardPodium factory', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget.leaderboardPodium(
              rankTitle: 'RANK 1 CHAMPION',
              playerName: 'ArchonKaiser',
              scoreText: '99,450 AP',
            ),
          ),
        ),
      );

      expect(find.text('ArchonKaiser'), findsOneWidget);
      expect(find.text('RANK 1 CHAMPION'), findsOneWidget);
    });

    testWidgets('renders CelestialBannerWidget.reputationFaction factory', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelestialBannerWidget.reputationFaction(
              factionName: 'Silver Mane Tribe',
              standingTier: 'Revered',
              progressText: '24,000 / 30,000',
            ),
          ),
        ),
      );

      expect(find.text('Silver Mane Tribe'), findsOneWidget);
      expect(find.text('FACTION REPUTATION'), findsOneWidget);
    });
  });

  group('PulsingEmblemWidget Tests', () {
    testWidgets('renders PulsingEmblemWidget across all factions', (tester) async {
      for (final faction in EmblemFaction.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: PulsingEmblemWidget(
                  faction: faction,
                  sizePreset: PulsingEmblemSize.standard,
                  tierBadgeText: 'I',
                ),
              ),
            ),
          ),
        );

        expect(find.text('I'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 200));
      }
    });

    testWidgets('renders PulsingEmblemWidget factories', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PulsingEmblemWidget.guild(levelText: 'LV. 10'),
                PulsingEmblemWidget.elyos(rankText: 'Archon'),
                PulsingEmblemWidget.asmodian(rankText: 'General'),
                PulsingEmblemWidget.balaur(rankText: 'Dragon'),
                PulsingEmblemWidget.daeva(tierText: 'High Daeva'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('LV. 10'), findsOneWidget);
      expect(find.text('Archon'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Dragon'), findsOneWidget);
      expect(find.text('High Daeva'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('Authentic Reward Illustrations Tests', () {
    testWidgets('renders CelestialArchonWingsWidget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CelestialArchonWingsWidget(size: 100.0),
            ),
          ),
        ),
      );

      expect(find.byType(CelestialArchonWingsWidget), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('renders MythicDaevaChestWidget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MythicDaevaChestWidget(size: 90.0, isOpen: false),
            ),
          ),
        ),
      );

      expect(find.byType(MythicDaevaChestWidget), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('renders AbyssCrystalWidget with various variants', (tester) async {
      for (final variant in CrystalColorVariant.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AbyssCrystalWidget(size: 80.0, variant: variant),
              ),
            ),
          ),
        );

        expect(find.byType(AbyssCrystalWidget), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 200));
      }
    });

    testWidgets('renders AncientEnchantmentStoneWidget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AncientEnchantmentStoneWidget(size: 90.0),
            ),
          ),
        ),
      );

      expect(find.byType(AncientEnchantmentStoneWidget), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('renders FactionHonorInsigniaWidget across star tiers', (tester) async {
      for (int stars = 1; stars <= 5; stars++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: FactionHonorInsigniaWidget(size: 88.0, starCount: stars),
              ),
            ),
          ),
        );

        expect(find.byType(FactionHonorInsigniaWidget), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 200));
      }
    });
  });

  group('SocialRewardIcon Adapter Tests', () {
    testWidgets('renders SocialRewardIcon across all 5 types', (tester) async {
      for (final type in SocialRewardType.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SocialRewardIcon(
                  type: type,
                  rarity: SocialRewardRarity.mythic,
                  countText: 'x10',
                ),
              ),
            ),
          ),
        );

        expect(find.text('x10'), findsOneWidget);
        expect(find.byType(SocialRewardIcon), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 200));
      }
    });

    testWidgets('renders SocialRewardIcon factory constructors and handles tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                SocialRewardIcon.wings(countText: 'x1', onTap: () => tapped = true),
                SocialRewardIcon.chest(countText: 'x3'),
                SocialRewardIcon.crystal(countText: 'x50'),
                SocialRewardIcon.stone(countText: 'x12'),
                SocialRewardIcon.insignia(countText: 'x5'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('x1'), findsOneWidget);
      expect(find.text('x3'), findsOneWidget);
      expect(find.text('x50'), findsOneWidget);
      expect(find.text('x12'), findsOneWidget);
      expect(find.text('x5'), findsOneWidget);

      await tester.tap(find.text('x1'));
      expect(tapped, isTrue);
    });
  });

  group('CustomPainter shouldRepaint verification', () {
    test('CelestialBannerPainter shouldRepaint returns correct values', () {
      const p1 = CelestialBannerPainter(progress: 0.1);
      const p2 = CelestialBannerPainter(progress: 0.2);
      const p3 = CelestialBannerPainter(progress: 0.1);

      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p3), isFalse);
    });

    test('PulsingEmblemPainter shouldRepaint returns correct values', () {
      const p1 = PulsingEmblemPainter(progress: 0.1, faction: EmblemFaction.elyos);
      const p2 = PulsingEmblemPainter(progress: 0.1, faction: EmblemFaction.asmodian);
      const p3 = PulsingEmblemPainter(progress: 0.1, faction: EmblemFaction.elyos);

      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p3), isFalse);
    });

    test('CelestialWingsPainter shouldRepaint returns correct values', () {
      const p1 = CelestialWingsPainter(progress: 0.1);
      const p2 = CelestialWingsPainter(progress: 0.3);
      const p3 = CelestialWingsPainter(progress: 0.1);

      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p3), isFalse);
    });

    test('DaevaChestPainter shouldRepaint returns correct values', () {
      const p1 = DaevaChestPainter(progress: 0.1, isOpen: false);
      const p2 = DaevaChestPainter(progress: 0.1, isOpen: true);
      const p3 = DaevaChestPainter(progress: 0.1, isOpen: false);

      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p3), isFalse);
    });

    test('AbyssCrystalPainter shouldRepaint returns correct values', () {
      const p1 = AbyssCrystalPainter(progress: 0.1, variant: CrystalColorVariant.abyssCyan);
      const p2 = AbyssCrystalPainter(progress: 0.1, variant: CrystalColorVariant.dragonRuby);
      const p3 = AbyssCrystalPainter(progress: 0.1, variant: CrystalColorVariant.abyssCyan);

      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p3), isFalse);
    });

    test('EnchantmentStonePainter shouldRepaint returns correct values', () {
      const p1 = EnchantmentStonePainter(progress: 0.1);
      const p2 = EnchantmentStonePainter(progress: 0.5);
      const p3 = EnchantmentStonePainter(progress: 0.1);

      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p3), isFalse);
    });

    test('HonorInsigniaPainter shouldRepaint returns correct values', () {
      const p1 = HonorInsigniaPainter(progress: 0.1, starCount: 3);
      const p2 = HonorInsigniaPainter(progress: 0.1, starCount: 5);
      const p3 = HonorInsigniaPainter(progress: 0.1, starCount: 3);

      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p3), isFalse);
    });
  });

  group('CelestialBannerUniforms & GLSL Layout Parity', () {
    test('CelestialBannerUniforms defines correct index layout and float count', () {
      expect(CelestialBannerUniforms.indexResolution, 0);
      expect(CelestialBannerUniforms.indexTime, 2);
      expect(CelestialBannerUniforms.indexProgress, 3);
      expect(CelestialBannerUniforms.indexEnergyIntensity, 4);
      expect(CelestialBannerUniforms.indexPrimaryColor, 5);
      expect(CelestialBannerUniforms.indexSecondaryColor, 9);
      expect(CelestialBannerUniforms.indexGoldColor, 13);
      expect(CelestialBannerUniforms.floatCount, 17);
    });

    test('CelestialBannerUniforms.buildUniforms packs 17 floats with linear color conversion', () {
      final uniforms = CelestialBannerUniforms.buildUniforms(
        size: const Size(400, 200),
        time: 2.5,
        progress: 0.65,
        energyIntensity: 1.2,
        primaryColor: const Color(0xFF00E5FF),
        secondaryColor: const Color(0xFF7C4DFF),
        goldColor: const Color(0xFFFFD700),
        useLinearColors: true,
      );

      expect(uniforms.length, CelestialBannerUniforms.floatCount);
      expect(uniforms[0], 400.0);
      expect(uniforms[1], 200.0);
      expect(uniforms[2], 2.5);
      expect(uniforms[3], 0.65);
      expect(uniforms[4], 1.2);

      // Verify colors are in [0..1] range
      for (int i = 5; i < 17; i++) {
        expect(uniforms[i], inInclusiveRange(0.0, 1.0));
      }
    });

    test('CelestialBannerUniforms supports raw sRGB colors when useLinearColors is false', () {
      const color = Color(0x80FF0000);
      final uniforms = CelestialBannerUniforms.buildUniforms(
        size: const Size(100, 100),
        time: 1.0,
        progress: 0.5,
        energyIntensity: 1.0,
        primaryColor: color,
        secondaryColor: color,
        goldColor: color,
        useLinearColors: false,
      );

      expect(uniforms[5], closeTo(color.r, 0.001));
      expect(uniforms[6], closeTo(color.g, 0.001));
      expect(uniforms[7], closeTo(color.b, 0.001));
      expect(uniforms[8], closeTo(color.a, 0.001));
    });

    test('CelestialBannerPainter.packUniforms matches CelestialBannerUniforms layout exactly', () {
      const size = Size(360, 180);
      const progress = 0.4;
      const time = 1.6;
      const intensity = 0.9;
      const primary = SocialThemeTokens.aetherCyan;
      const secondary = SocialThemeTokens.daevaPrismViolet;
      const gold = SocialThemeTokens.celestialGold;

      final listUniforms = CelestialBannerUniforms.buildUniforms(
        size: size,
        time: time,
        progress: progress,
        energyIntensity: intensity,
        primaryColor: primary,
        secondaryColor: secondary,
        goldColor: gold,
        useLinearColors: true,
      );

      final buffer = CelestialBannerPainter.packUniforms(
        size: size,
        progress: progress,
        time: time,
        energyIntensity: intensity,
        primaryEnergyColor: primary,
        secondaryEnergyColor: secondary,
        goldShimmerColor: gold,
      );

      expect(buffer.length, CelestialBannerPainter.kUniformFloatCount);
      expect(buffer.length, listUniforms.length);

      for (int i = 0; i < buffer.length; i++) {
        expect(buffer[i], closeTo(listUniforms[i], 1e-4),
            reason: 'Mismatch at uniform index $i');
      }
    });
  });

  group('EmblemAuraUniforms & GLSL Layout Parity', () {
    test('EmblemAuraUniforms defines correct index layout and float count', () {
      expect(EmblemAuraUniforms.indexResolution, 0);
      expect(EmblemAuraUniforms.indexTime, 2);
      expect(EmblemAuraUniforms.indexProgress, 3);
      expect(EmblemAuraUniforms.indexAuraColor, 4);
      expect(EmblemAuraUniforms.indexCoreColor, 8);
      expect(EmblemAuraUniforms.indexPulseSpeed, 12);
      expect(EmblemAuraUniforms.indexAuraRadius, 13);
      expect(EmblemAuraUniforms.floatCount, 14);
    });

    test('EmblemAuraUniforms.buildUniforms packs 14 floats with linear color conversion', () {
      final uniforms = EmblemAuraUniforms.buildUniforms(
        size: const Size(128, 128),
        time: 3.14,
        progress: 0.5,
        auraColor: const Color(0xFFFFD54F),
        coreColor: const Color(0xFFFFF9C4),
        pulseSpeed: 1.5,
        auraRadius: 0.45,
        useLinearColors: true,
      );

      expect(uniforms.length, EmblemAuraUniforms.floatCount);
      expect(uniforms[0], 128.0);
      expect(uniforms[1], 128.0);
      expect(uniforms[2], 3.14);
      expect(uniforms[3], 0.5);
      expect(uniforms[12], 1.5);
      expect(uniforms[13], 0.45);

      // Verify colors in [0..1] range
      for (int i = 4; i < 12; i++) {
        expect(uniforms[i], inInclusiveRange(0.0, 1.0));
      }
    });

    test('PulsingEmblemPainter.packUniforms matches EmblemAuraUniforms layout exactly', () {
      const size = Size(96, 96);
      const progress = 0.75;
      const time = 4.71;
      const speed = 1.25;
      const radius = 0.5;
      const aura = SocialThemeTokens.elyosGold;
      const core = SocialThemeTokens.elyosRadiance;

      final listUniforms = EmblemAuraUniforms.buildUniforms(
        size: size,
        time: time,
        progress: progress,
        auraColor: aura,
        coreColor: core,
        pulseSpeed: speed,
        auraRadius: radius,
        useLinearColors: true,
      );

      final buffer = PulsingEmblemPainter.packUniforms(
        size: size,
        progress: progress,
        time: time,
        pulseSpeed: speed,
        auraRadius: radius,
        auraColor: aura,
        coreColor: core,
      );

      expect(buffer.length, PulsingEmblemPainter.kEmblemAuraUniformFloatCount);
      expect(buffer.length, listUniforms.length);

      for (int i = 0; i < buffer.length; i++) {
        expect(buffer[i], closeTo(listUniforms[i], 1e-4),
            reason: 'Mismatch at uniform index $i');
      }
    });
  });

  group('RewardShaderConfig & Uniform Buffer Packaging', () {
    test('RewardShaderConfig packs all 24 uniform floats accurately', () {
      const config = RewardShaderConfig(
        size: Size(120, 120),
        progress: 0.35,
        time: 1.4,
        type: SocialRewardType.celestialArchonWings,
        rarity: SocialRewardRarity.ancient,
        glowIntensity: 1.5,
        speedMultiplier: 1.2,
      );

      expect(RewardShaderConfig.kUniformFloatCount, 24);
      final buffer = config.packUniforms();
      expect(buffer.length, 24);

      expect(buffer[0], 120.0);
      expect(buffer[1], 120.0);
      expect(buffer[2], 1.4);
      expect(buffer[3], 0.35);
      expect(buffer[4], SocialRewardType.celestialArchonWings.index.toDouble());
      expect(buffer[5], SocialRewardRarity.ancient.tierProgress);
      expect(buffer[6], 1.5 * SocialRewardRarity.ancient.glowMultiplier);
      expect(buffer[7], 1.2 * SocialRewardRarity.ancient.pulseSpeed);

      // Verify colors 8..23 are within [0..1]
      for (int i = 8; i < 24; i++) {
        expect(buffer[i], inInclusiveRange(0.0, 1.0));
      }
    });

    test('RewardShaderConfig copyWith works correctly', () {
      const original = RewardShaderConfig(
        size: Size(50, 50),
        progress: 0.1,
      );
      final modified = original.copyWith(
        size: const Size(100, 100),
        progress: 0.8,
        type: SocialRewardType.mythicDaevaChest,
      );

      expect(modified.size.width, 100.0);
      expect(modified.progress, 0.8);
      expect(modified.type, SocialRewardType.mythicDaevaChest);
    });
  });

  group('SocialShaderPaths & GLSL 460 Asset Parity', () {
    test('SocialShaderPaths exposes non-empty canonical and alt asset paths', () {
      expect(SocialShaderPaths.celestialBanner, isNotEmpty);
      expect(SocialShaderPaths.celestialBannerAlt, isNotEmpty);
      expect(SocialShaderPaths.emblemAura, isNotEmpty);
      expect(SocialShaderPaths.emblemAuraAlt, isNotEmpty);
    });

    test('GLSL source files exist on disk and declare valid GLSL 460 shaders', () {
      final bannerFile = File(SocialShaderPaths.celestialBannerAlt);
      expect(bannerFile.existsSync(), isTrue,
          reason: 'celestial_banner.frag must physically exist');
      final bannerSource = bannerFile.readAsStringSync();
      expect(bannerSource, contains('#version 460 core'));
      expect(bannerSource, contains('#include <flutter/runtime_effect.glsl>'));
      expect(bannerSource, contains('uniform vec2 uResolution;'));
      expect(bannerSource, contains('uniform float uTime;'));
      expect(bannerSource, contains('uniform float uProgress;'));
      expect(bannerSource, contains('uniform float uEnergyIntensity;'));
      expect(bannerSource, contains('uniform vec4 uPrimaryColor;'));
      expect(bannerSource, contains('uniform vec4 uSecondaryColor;'));
      expect(bannerSource, contains('uniform vec4 uGoldColor;'));
      expect(bannerSource, contains('out vec4 fragColor;'));

      final emblemFile = File(SocialShaderPaths.emblemAuraAlt);
      expect(emblemFile.existsSync(), isTrue,
          reason: 'emblem_aura.frag must physically exist');
      final emblemSource = emblemFile.readAsStringSync();
      expect(emblemSource, contains('#version 460 core'));
      expect(emblemSource, contains('#include <flutter/runtime_effect.glsl>'));
      expect(emblemSource, contains('uniform vec2 uResolution;'));
      expect(emblemSource, contains('uniform float uTime;'));
      expect(emblemSource, contains('uniform float uProgress;'));
      expect(emblemSource, contains('uniform vec4 uAuraColor;'));
      expect(emblemSource, contains('uniform vec4 uCoreColor;'));
      expect(emblemSource, contains('uniform float uPulseSpeed;'));
      expect(emblemSource, contains('uniform float uAuraRadius;'));
      expect(emblemSource, contains('out vec4 fragColor;'));
    });
  });

  group('SocialShaderCache Lifecycle & Fallback Verification', () {
    test('SocialShaderCache maintains singleton identity', () {
      final c1 = SocialShaderCache();
      final c2 = SocialShaderCache.instance;
      expect(identical(c1, c2), isTrue);
    });

    test('SocialShaderCache handles uninitialized state and safe shader queries', () {
      final cache = SocialShaderCache.instance;
      cache.clear();

      expect(cache.isInitialized, isFalse);
      expect(cache.celestialBannerProgram, isNull);
      expect(cache.emblemAuraProgram, isNull);
      expect(cache.lastError, isNull);

      // Instantiating before init returns null without throwing
      expect(cache.createCelestialBannerShader(), isNull);
      expect(cache.createEmblemAuraShader(), isNull);
    });

    test('SocialShaderCache.init executes safely in headless environment', () async {
      final cache = SocialShaderCache.instance;
      cache.clear();

      // In a headless test runner without Impeller GPU, init handles errors gracefully
      final hasSupport = await cache.init();
      expect(cache.isInitialized, isTrue);
      // If no GPU assets found, hasHardwareShaderSupport is false and fallback painter runs
      expect(hasSupport, equals(cache.hasHardwareShaderSupport));

      cache.clear();
      expect(cache.isInitialized, isFalse);
    });
  });

  group('Fake Uniform Buffer Storage (Dart 3 Base Class Compliant)', () {
    test('FakeUniformBuffer records and validates uniform packing without illegal mock', () {
      final fakeBuffer = FakeUniformBuffer();
      final bannerUniforms = CelestialBannerUniforms.buildUniforms(
        size: const Size(200, 100),
        time: 1.0,
        progress: 0.2,
        energyIntensity: 0.8,
        primaryColor: Colors.blue,
        secondaryColor: Colors.purple,
        goldColor: Colors.amber,
      );

      fakeBuffer.loadFromList(bannerUniforms);

      expect(fakeBuffer.floatCount, CelestialBannerUniforms.floatCount);
      expect(fakeBuffer[0], 200.0);
      expect(fakeBuffer[1], 100.0);
      expect(fakeBuffer[2], 1.0);
      expect(fakeBuffer[3], 0.2);
      expect(fakeBuffer[4], 0.8);
    });

    test('FakeUniformBuffer loads Float32List from painter accurately', () {
      final fakeBuffer = FakeUniformBuffer();
      final packed = PulsingEmblemPainter.packUniforms(
        size: const Size(64, 64),
        progress: 0.5,
        time: 2.0,
        pulseSpeed: 1.0,
        auraRadius: 0.42,
      );

      fakeBuffer.loadFromFloat32List(packed);

      expect(fakeBuffer.floatCount, PulsingEmblemPainter.kEmblemAuraUniformFloatCount);
      expect(fakeBuffer[0], 64.0);
      expect(fakeBuffer[1], 64.0);
      expect(fakeBuffer[2], 2.0);
      expect(fakeBuffer[3], 0.5);
      expect(fakeBuffer[12], 1.0);
      expect(fakeBuffer[13], 0.42);
    });
  });

  group('Photometrically Accurate Color Math in SocialThemeTokens', () {
    test('IEC 61966-2-1 sRGB to linear conversion boundaries and roundtrip', () {
      expect(SocialThemeTokens.sRgbToLinear(0.0), 0.0);
      expect(SocialThemeTokens.sRgbToLinear(1.0), 1.0);
      expect(SocialThemeTokens.sRgbToLinear(0.04), closeTo(0.04 / 12.92, 1e-6));

      // Test roundtrip
      for (double c = 0.0; c <= 1.0; c += 0.1) {
        final linear = SocialThemeTokens.sRgbToLinear(c);
        final backToSRgb = SocialThemeTokens.linearToSRgb(linear);
        expect(backToSRgb, closeTo(c, 0.005));
      }
    });

    test('relativeLuminance computes accurate photometric values', () {
      expect(SocialThemeTokens.relativeLuminance(Colors.black), closeTo(0.0, 1e-5));
      expect(SocialThemeTokens.relativeLuminance(Colors.white), closeTo(1.0, 1e-5));
      expect(SocialThemeTokens.isLight(Colors.white), isTrue);
      expect(SocialThemeTokens.isLight(Colors.black), isFalse);
    });

    test('contrastRatio computes standard WCAG 2.1 ratios', () {
      final ratio = SocialThemeTokens.contrastRatio(Colors.black, Colors.white);
      expect(ratio, closeTo(21.0, 0.5));

      final sameRatio = SocialThemeTokens.contrastRatio(Colors.white, Colors.white);
      expect(sameRatio, closeTo(1.0, 1e-5));
    });
  });
}
