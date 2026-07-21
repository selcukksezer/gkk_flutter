import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/crafting_model.dart';
import '../../../providers/crafting_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/player_provider.dart';
import 'crafting_preview_panel.dart';

Future<void> showCraftingRecipePreviewDialog({
  required BuildContext context,
  required WidgetRef ref,
  required CraftRecipe recipe,
  required Future<bool> Function() onCraft,
}) async {
  ref.read(craftingProvider.notifier).selectRecipe(recipe.id);

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Üretim önizleme',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (BuildContext dialogContext, Animation<double> animation, Animation<double> secondaryAnimation) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                behavior: HitTestBehavior.opaque,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.black.withValues(alpha: 0.68)),
                ),
              ),
            ),
            Center(
              child: Consumer(
                builder: (BuildContext context, WidgetRef ref, Widget? child) {
                  final craftState = ref.watch(craftingProvider);
                  final playerState = ref.watch(playerProvider);
                  final hasMaterials = ref.watch(hasMaterialsProvider);

                  final CraftRecipe? selectedRecipe = craftState.selectedRecipeId == null
                      ? null
                      : craftState.recipes.cast<CraftRecipe?>().firstWhere(
                            (r) => r?.id == craftState.selectedRecipeId,
                            orElse: () => null,
                          );

                  if (selectedRecipe == null) {
                    return const SizedBox.shrink();
                  }

                  final double playerGems = playerState.profile?.gems ?? 0;
                  final int gemCost = (craftState.selectedBatchCount - 1).clamp(0, craftingBatchLimit);
                  final bool canAffordGems = playerGems >= gemCost;
                  final bool hasEnoughMaterials = hasMaterials(
                    selectedRecipe,
                    batchCount: craftState.selectedBatchCount,
                  );
                  final bool canCraft = hasEnoughMaterials &&
                      canAffordGems &&
                      !craftState.isCrafting &&
                      craftState.queue.length < craftingQueueLimit;

                  final Map<String, int> ownedQuantities = <String, int>{};
                  for (final item in ref.read(inventoryProvider).items) {
                    ownedQuantities[item.itemId] = (ownedQuantities[item.itemId] ?? 0) + item.quantity;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
                    child: CraftingPreviewPanel(
                      recipe: selectedRecipe,
                      batchCount: craftState.selectedBatchCount,
                      gemCost: gemCost,
                      canCraft: canCraft,
                      isCrafting: craftState.isCrafting,
                      hasEnoughMaterials: hasEnoughMaterials,
                      canAffordGems: canAffordGems,
                      ownedQuantities: ownedQuantities,
                      onCraft: () async {
                        final bool ok = await onCraft();
                        if (ok && dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                      onClose: () => Navigator.of(dialogContext).pop(),
                      onBatchDecrement: () =>
                          ref.read(craftingProvider.notifier).setBatchCount(craftState.selectedBatchCount - 1),
                      onBatchIncrement: () =>
                          ref.read(craftingProvider.notifier).setBatchCount(craftState.selectedBatchCount + 1),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
    transitionBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      );
    },
  );

  ref.read(craftingProvider.notifier).selectRecipe(null);
  ref.read(craftingProvider.notifier).setBatchCount(1);
}
