import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../models/crafting_model.dart';
import '../../../providers/crafting_provider.dart';
import '../crafting_utils.dart';

class CraftingPreviewPanel extends StatelessWidget {
  const CraftingPreviewPanel({
    super.key,
    required this.recipe,
    required this.batchCount,
    required this.gemCost,
    required this.canCraft,
    required this.isCrafting,
    required this.hasEnoughMaterials,
    required this.canAffordGems,
    required this.ownedQuantities,
    required this.onCraft,
    required this.onClose,
    required this.onBatchDecrement,
    required this.onBatchIncrement,
  });

  final CraftRecipe? recipe;
  final int batchCount;
  final int gemCost;
  final bool canCraft;
  final bool isCrafting;
  final bool hasEnoughMaterials;
  final bool canAffordGems;
  final Map<String, int> ownedQuantities;
  final VoidCallback onCraft;
  final VoidCallback onClose;
  final VoidCallback onBatchDecrement;
  final VoidCallback onBatchIncrement;

  @override
  Widget build(BuildContext context) {
    if (recipe == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.info_outline, color: Colors.white38, size: 18),
            SizedBox(width: 10),
            Text('Bir tarif seçin', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    final Color rarityColor = craftingRarityColor(recipe!.outputRarity);
    final int? timeSec = recipe!.productionTimeSeconds;
    final String timeLabel = timeSec == null ? '—' : formatCraftingDuration(timeSec * batchCount);
    final int totalOutput = recipe!.outputQuantity * batchCount;
    final int totalXp = (recipe!.xpReward ?? 0) * batchCount;
    final double successRate = recipe!.normalizedSuccessRate;

    final bool showGemError = !canAffordGems && gemCost > 0;
    final bool showMatError = !hasEnoughMaterials;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0x33202A44), Color(0x140E1426)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      recipe!.outputName?.isNotEmpty == true ? recipe!.outputName! : recipe!.name,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: rarityColor),
                    ),
                    const SizedBox(height: 2),
                    const Text('Üretim Ön İzlemesi', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                tooltip: 'Kapat',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Üretilecek Malzeme',
            style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.5), width: 1.4),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Colors.cyan.withValues(alpha: 0.20), Colors.blue.withValues(alpha: 0.08)],
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ItemIconView(
                    iconValue: recipe!.outputItemId,
                    itemId: recipe!.outputItemId,
                    size: 52,
                    expand: true,
                    fallback: '❔',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        recipe!.outputName?.isNotEmpty == true ? recipe!.outputName! : recipe!.name,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: rarityColor),
                      ),
                      const SizedBox(height: 2),
                      Text('Miktar: x$totalOutput', style: const TextStyle(fontSize: 11, color: Colors.cyanAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Gerekli Malzemeler',
            style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          GameFixedGrid(
            crossAxisCount: 3,
            spacing: 8,
            itemCount: recipe!.ingredients.length,
            itemBuilder: (BuildContext context, int index) {
              final ing = recipe!.ingredients[index];
              final int owned = ownedQuantities[ing.itemId] ?? 0;
              final int required = ing.quantity * batchCount;
              final bool enough = owned >= required;
              final String ingredientName = ing.itemName.trim().isNotEmpty
                  ? ing.itemName
                  : (ing.itemId.isNotEmpty ? ing.itemId : 'Bilinmiyor');
              return Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: enough ? Colors.green.withValues(alpha: 0.55) : Colors.red.withValues(alpha: 0.55),
                    width: 1.3,
                  ),
                  color: enough ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                ),
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: ItemIconView(iconValue: ing.itemId, itemId: ing.itemId, size: 24, expand: true),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ingredientName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$owned / $required',
                      style: TextStyle(
                        fontSize: 10,
                        color: enough ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              _CraftingInfoChip(icon: Icons.military_tech_rounded, label: 'Sv${recipe!.requiredLevel}'),
              _CraftingInfoChip(
                icon: Icons.percent_rounded,
                label: '${(successRate * 100).round()}% Başarı',
                color: const Color(0xFFFCD34D),
              ),
              _CraftingInfoChip(icon: Icons.timer_rounded, label: timeLabel),
              _CraftingInfoChip(
                icon: Icons.diamond_rounded,
                label: '$gemCost 💎',
                color: showGemError ? Colors.redAccent : const Color(0xFFD8B4FE),
              ),
              if (recipe!.goldCost > 0)
                _CraftingInfoChip(
                  icon: Icons.paid_rounded,
                  label: '${recipe!.goldCost} 🪙',
                  color: const Color(0xFFFDE68A),
                ),
              _CraftingInfoChip(
                icon: Icons.auto_awesome_rounded,
                label: '+$totalXp XP',
                color: const Color(0xFFFCD34D),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              color: Colors.white.withValues(alpha: 0.04),
            ),
            child: Column(
              children: <Widget>[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Batch Sayısı',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white60),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: TextButton(
                        onPressed: batchCount > 1 ? onBatchDecrement : null,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('−', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$batchCount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: TextButton(
                        onPressed: batchCount < craftingBatchLimit ? onBatchIncrement : null,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('+', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Max: 5', style: TextStyle(fontSize: 10, color: Colors.white38)),
              ],
            ),
          ),
          if (showGemError) _buildErrorBox('⚠️ Elmas yetersiz'),
          if (showMatError) _buildErrorBox('⚠️ Malzeme yetersiz'),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: onClose,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.30),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: canCraft ? onCraft : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB45309),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    isCrafting ? 'Üretiliyor...' : '🔨 Üretimi Başlat (${batchCount}x)',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.14),
          border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFFFCA5A5))),
      ),
    );
  }
}

class _CraftingInfoChip extends StatelessWidget {
  const _CraftingInfoChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? Colors.white60;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }
}
