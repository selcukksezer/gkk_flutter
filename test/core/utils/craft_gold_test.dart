import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/utils/craft_gold.dart';
import 'package:gkk_flutter/models/crafting_model.dart';

CraftRecipe _recipe({int goldCost = 500}) => CraftRecipe(
      id: 'r1',
      recipeId: 'r1',
      name: 'Test',
      description: 'Test recipe',
      recipeType: 'weapon',
      itemType: 'weapon',
      outputItemId: 'item1',
      outputQuantity: 1,
      outputRarity: 'common',
      requiredLevel: 1,
      requiredFacility: 'none',
      requiredFacilityLevel: 0,
      productionTimeSeconds: 60,
      successRate: 1,
      ingredients: const <CraftIngredient>[],
      gemCost: 0,
      goldCost: goldCost,
    );

void main() {
  group('craft gold helpers', () {
    test('totalCraftGoldCost multiplies batch count', () {
      expect(totalCraftGoldCost(_recipe(goldCost: 200), 3), 600);
      expect(totalCraftGoldCost(_recipe(goldCost: 0), 5), 0);
    });

    test('canAffordCraftGold respects player balance', () {
      final CraftRecipe recipe = _recipe(goldCost: 100);
      expect(
        canAffordCraftGold(playerGold: 300, recipe: recipe, batchCount: 2),
        isTrue,
      );
      expect(
        canAffordCraftGold(playerGold: 150, recipe: recipe, batchCount: 2),
        isFalse,
      );
    });
  });
}
