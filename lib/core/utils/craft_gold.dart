import '../../models/crafting_model.dart';

/// Total gold charged by `start_crafting` (per-unit cost × batch).
int totalCraftGoldCost(CraftRecipe recipe, int batchCount) {
  final int batch = batchCount.clamp(1, 999);
  return recipe.goldCost * batch;
}

bool canAffordCraftGold({required int playerGold, required CraftRecipe recipe, required int batchCount}) {
  if (recipe.goldCost <= 0) return true;
  return playerGold >= totalCraftGoldCost(recipe, batchCount);
}
