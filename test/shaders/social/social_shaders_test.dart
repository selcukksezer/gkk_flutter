import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/shaders/social/social_shaders.dart';

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
}
