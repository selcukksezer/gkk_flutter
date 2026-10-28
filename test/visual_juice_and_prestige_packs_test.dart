import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gkk_flutter/components/character/character_3d_paperdoll_showcase.dart';
import 'package:gkk_flutter/components/common/holo_foil_sheen.dart';
import 'package:gkk_flutter/components/common/rarity_loot_beam.dart';
import 'package:gkk_flutter/components/pvp/pvp_colosseum_stage.dart';
import 'package:gkk_flutter/core/services/gpu_shader_service.dart';
import 'package:gkk_flutter/core/services/graphics_quality_service.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/models/moradon_models.dart';
import 'package:gkk_flutter/screens/enhancement/widgets/enhancement_forge_effects.dart';
import 'package:gkk_flutter/screens/home/moradon/moradon_v5_layers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GpuShaderService.instance.resetForTesting();
    GraphicsQualityService.instance.configureForTest(
      hardwareTier: GraphicsQualityTier.high,
      preference: GraphicsPreference.high,
    );
    await GraphicsQualityService.instance.setShowFpsOverlay(false);
  });

  group('Packs 5 & 6 — GraphicsProfile Tier Budgets & Blood Moon World Sky', () {
    test('gates GLSL shaders to High/Ultra and Holo Foil Sweep to Medium+', () {
      GraphicsQualityService.instance.configureForTest(
        hardwareTier: GraphicsQualityTier.low,
        preference: GraphicsPreference.low,
      );
      final GraphicsProfile low = GraphicsQualityService.instance.profile;
      expect(low.enableGpuShaders, isFalse);
      expect(low.enableHoloFoilSweep, isFalse);

      GraphicsQualityService.instance.configureForTest(
        hardwareTier: GraphicsQualityTier.medium,
        preference: GraphicsPreference.medium,
      );
      final GraphicsProfile med = GraphicsQualityService.instance.profile;
      expect(med.enableGpuShaders, isFalse);
      expect(med.enableHoloFoilSweep, isTrue);

      GraphicsQualityService.instance.configureForTest(
        hardwareTier: GraphicsQualityTier.high,
        preference: GraphicsPreference.high,
      );
      final GraphicsProfile high = GraphicsQualityService.instance.profile;
      expect(high.enableGpuShaders, isTrue);
      expect(high.enableHoloFoilSweep, isTrue);
    });

    test('resolves Moradon Kanlı Ay (bloodMoon) atmosphere phase & badge', () {
      final MoradonAtmospherePhase phase = resolveLiveAtmospherePhase(
        choice: MoradonAtmosphereChoice.bloodMoon,
        nightMarketActive: false,
        siegeLive: false,
      );
      expect(phase, MoradonAtmospherePhase.bloodMoon);
      expect(
        atmosphereChoiceBadgeLabel(MoradonAtmosphereChoice.bloodMoon, phase),
        'Kanlı Ay',
      );
    });

    test('compiles GLSL water caustics & heat distortion shaders on High and skips on Low', () async {
      GraphicsQualityService.instance.configureForTest(
        hardwareTier: GraphicsQualityTier.low,
        preference: GraphicsPreference.low,
      );
      await GpuShaderService.instance.warmUpIfEnabled();
      expect(GpuShaderService.instance.isWaterShaderReady, isFalse);
      expect(
        GpuShaderService.instance.createWaterCausticsShader(
          size: const ui.Size(440, 270),
          timeSec: 1.5,
        ),
        isNull,
      );

      GraphicsQualityService.instance.configureForTest(
        hardwareTier: GraphicsQualityTier.high,
        preference: GraphicsPreference.high,
      );
      await GpuShaderService.instance.warmUpIfEnabled();
      expect(GpuShaderService.instance.isWaterShaderReady, isTrue);
      expect(GpuShaderService.instance.isHeatShaderReady, isTrue);
      expect(
        GpuShaderService.instance.createWaterCausticsShader(
          size: const ui.Size(440, 270),
          timeSec: 2.0,
        ),
        isNotNull,
      );
      expect(
        GpuShaderService.instance.createHeatDistortionShader(
          size: const ui.Size(800, 600),
          timeSec: 2.0,
        ),
        isNotNull,
      );
    });
  });

  group('Packs 4 & 6 — HoloFoilRarityBox, RarityLootBeam & MagicAnvil', () {
    testWidgets('HoloFoilRarityBox skips common items and switches static vs sweep by tier', (WidgetTester tester) async {
      GraphicsQualityService.instance.configureForTest(
        hardwareTier: GraphicsQualityTier.low,
        preference: GraphicsPreference.low,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                HoloFoilRarityBox(
                  rarity: Rarity.common,
                  enhancementLevel: 3,
                  child: SizedBox(width: 56, height: 56),
                ),
                HoloFoilRarityBox(
                  rarity: Rarity.legendary,
                  enhancementLevel: 9,
                  child: SizedBox(width: 56, height: 56),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Common +3 has zero foil paint; Legendary +9 on Low renders static foil glint
      expect(
        find.byKey(const ValueKey<String>('holo_foil_static_paint')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('holo_foil_sweep_paint')),
        findsNothing,
      );

      // Switch live to High tier -> upgrades immediately to prismatic sweep
      await GraphicsQualityService.instance.setPreference(
        GraphicsPreference.high,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('holo_foil_sweep_paint')),
        findsOneWidget,
      );
    });

    testWidgets('RarityLootBeamOverlay & MagicAnvilCinematicOverlay render cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                RarityLootBeamOverlay(
                  rarity: Rarity.mythic,
                  height: 160,
                  width: 180,
                  child: SizedBox(width: 64, height: 64),
                ),
                SizedBox(
                  width: 280,
                  height: 150,
                  child: MagicAnvilCinematicOverlay(
                    progress: 0.42,
                    mode: 'enhancing',
                    child: ColoredBox(color: Color(0xFF0E1422)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('rarity_loot_beam_paint')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('magic_anvil_paint_enhancing')),
        findsOneWidget,
      );
    });
  });

  group('Packs 2 & 3 — 3D Character Paperdoll Showcase & 1v1 PvP Colosseum', () {
    testWidgets('Character3dPaperdollShowcase previews +10 Sovereign Aura & 3-hit combo', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Character3dPaperdollShowcase(profile: null),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('character_3d_paperdoll_showcase')),
        findsOneWidget,
      );

      // Tap +10 Hükümdar aura chip
      final Finder chip10 = find.byKey(
        const ValueKey<String>('paperdoll_aura_chip_10'),
      );
      await tester.ensureVisible(chip10);
      await tester.tap(chip10);
      await tester.pump();
      expect(find.textContaining('+10 PRESTİJ AURA'), findsOneWidget);

      // Trigger 3-hit combo preview
      await tester.tap(find.byKey(const Key('character_combo_preview_btn')));
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump(const Duration(milliseconds: 450));
    });

    testWidgets('PvpColosseumHeroBanner renders 1v1 stage & runs exhibition duel', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PvpColosseumHeroBanner(
                  profile: null,
                  rivalName: 'Gölge Şampiyon',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('pvp_colosseum_hero_banner')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pvp_colosseum_stage')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pvp_colosseum_spar_btn')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 2600));
    });
  });
}
