import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gkk_flutter/models/crafting_model.dart';
import 'package:gkk_flutter/screens/crafting/widgets/crafting_forge_effects.dart';
import 'package:gkk_flutter/screens/crafting/widgets/crafting_material_slot.dart';
import 'package:gkk_flutter/screens/crafting/widgets/crafting_recipe_carousel.dart';
import 'package:gkk_flutter/screens/crafting/widgets/crafting_result_modal.dart';
import 'package:gkk_flutter/screens/crafting/widgets/crafting_main_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aion 2 Dark Fantasy Forge Effects', () {
    testWidgets('ForgeEmbersOverlay renders without throwing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForgeEmbersOverlay(
              particleCount: 15,
              child: Text('Forge Content'),
            ),
          ),
        ),
      );

      expect(find.text('Forge Content'), findsOneWidget);
      expect(find.byType(ForgeEmbersOverlay), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('MoltenProgressBar renders cleanly across progress fractions', (WidgetTester tester) async {
      for (final double p in <double>[0.0, 0.2, 0.5, 0.85, 1.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MoltenProgressBar(progress: p),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('ForgeAnvilHeader displays status and reacts to toggle button', (WidgetTester tester) async {
      bool toggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeAnvilHeader(
              recipeCount: 12,
              queueCount: 2,
              queueMax: 4,
              isCarouselMode: false,
              onToggleViewMode: () => toggled = true,
            ),
          ),
        ),
      );

      expect(find.text('KADİM DEMİR OCAĞI'), findsOneWidget);
      expect(find.text('AION II'), findsOneWidget);
      expect(find.text('2/4'), findsOneWidget);

      // Tap view mode toggle button
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pump();
      expect(toggled, isTrue);
    });
  });

  group('OrnateForgeMaterialSlot', () {
    const CraftIngredient testIng = CraftIngredient(
      itemId: 'iron_ore',
      itemName: 'Demir Cevheri',
      quantity: 5,
    );

    testWidgets('shows satisfied state when owned >= required', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrnateForgeMaterialSlot(
              ingredient: testIng,
              owned: 10,
              requiredCount: 5,
            ),
          ),
        ),
      );

      expect(find.text('Demir Cevheri'), findsOneWidget);
      expect(find.text('10 / 5'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows shortage and bank surplus chip when available in bank', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrnateForgeMaterialSlot(
              ingredient: testIng,
              owned: 2,
              requiredCount: 5,
              inBank: 8,
            ),
          ),
        ),
      );

      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.text('Banka: 8'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('tapping opens material inspection bottom sheet', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrnateForgeMaterialSlot(
              ingredient: testIng,
              owned: 2,
              requiredCount: 5,
              inBank: 8,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(OrnateForgeMaterialSlot));
      await tester.pumpAndSettle();

      expect(find.text('Gerekli Miktar:'), findsOneWidget);
      expect(find.text('Çantadakiler:'), findsOneWidget);
      expect(find.text('Bankadaki Stok:'), findsOneWidget);
    });
  });

  group('CraftingRecipeCarousel', () {
    final CraftRecipe recipe1 = CraftRecipe(
      id: 'rec_sword',
      name: 'Ejder Katili Kılıç',
      description: 'Efsanevi ejderha ateşiyle dövülmüş silah',
      recipeType: 'weapon',
      itemType: 'weapon',
      outputItemId: 'wpn_sword_01',
      outputQuantity: 1,
      outputRarity: 'mythic',
      requiredLevel: 25,
      requiredFacilityLevel: 1,
      productionTimeSeconds: 60,
      successRate: 0.9,
      ingredients: const <CraftIngredient>[
        CraftIngredient(itemId: 'dragon_scale', itemName: 'Ejder Pulu', quantity: 3),
      ],
      gemCost: 0,
      goldCost: 500,
      xpReward: 150,
    );

    final CraftRecipe recipe2 = CraftRecipe(
      id: 'rec_shield',
      name: 'Arkon Koruma Kalkanı',
      description: 'Kadim kalkan',
      recipeType: 'armor',
      itemType: 'armor',
      outputItemId: 'arm_shield_01',
      outputQuantity: 1,
      outputRarity: 'archon',
      requiredLevel: 30,
      requiredFacilityLevel: 1,
      productionTimeSeconds: 120,
      successRate: 0.85,
      ingredients: const <CraftIngredient>[
        CraftIngredient(itemId: 'archon_metal', itemName: 'Arkon Madeni', quantity: 2),
      ],
      gemCost: 10,
      goldCost: 1000,
      xpReward: 300,
    );

    testWidgets('renders recipe carousel and pages smoothly', (WidgetTester tester) async {
      CraftRecipe? previewed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CraftingRecipeCarousel(
              recipes: <CraftRecipe>[recipe1, recipe2],
              selectedRecipeId: recipe1.id,
              hasMaterials: (r) => true,
              onSelectRecipe: (_) {},
              onOpenPreview: (r) => previewed = r,
            ),
          ),
        ),
      );

      expect(find.text('Ejder Katili Kılıç'), findsOneWidget);
      expect(find.text('MİTİK'), findsOneWidget);

      // Tap action button to open preview
      await tester.tap(find.text('Döv ve Üret').first);
      await tester.pump();
      expect(previewed?.id, equals('rec_sword'));
    });
  });

  group('CraftingResultModal', () {
    testWidgets('renders triumphant forged reveal modal', (WidgetTester tester) async {
      bool closed = false;
      bool craftAgain = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CraftingResultModal(
              itemName: 'Aion Yüce Kılıcı',
              itemId: 'wpn_aion_01',
              rarity: 'archon',
              quantity: 2,
              xpReward: 250,
              isFailed: false,
              onClose: () => closed = true,
              onCraftAgain: () => craftAgain = true,
            ),
          ),
        ),
      );

      expect(find.text('DÖVME TAMAMLANDI'), findsOneWidget);
      expect(find.text('Aion Yüce Kılıcı'), findsOneWidget);
      expect(find.text('x2'), findsOneWidget);
      expect(find.text('+250 Demircilik XP'), findsOneWidget);
      expect(find.text('Yeniden Üret'), findsOneWidget);
      expect(find.text('Harika! Envantere Al'), findsOneWidget);

      await tester.tap(find.text('Yeniden Üret'));
      await tester.pump();
      expect(craftAgain, isTrue);

      await tester.tap(find.text('Harika! Envantere Al'));
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('renders failure modal when craft fails', (WidgetTester tester) async {
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CraftingResultModal(
              itemName: 'Bozuk Alaşım',
              itemId: 'scrap_metal',
              rarity: 'common',
              quantity: 1,
              isFailed: true,
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      expect(find.text('DÖVME BAŞARISIZ'), findsOneWidget);
      expect(find.text('Ocağın ateşi malzemeleri yuttu'), findsOneWidget);
      expect(find.text('Kapat'), findsOneWidget);

      await tester.tap(find.text('Kapat'));
      await tester.pump();
      expect(closed, isTrue);
    });
  });
}
