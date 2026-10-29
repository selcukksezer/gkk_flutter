import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../core/utils/craft_gold.dart';
import '../../../models/crafting_model.dart';
import '../../../providers/crafting_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../inventory/widgets/aion_rarity_glow.dart';
import '../crafting_utils.dart';
import 'crafting_forge_effects.dart';
import 'crafting_material_slot.dart';
import 'crafting_queue_slots_panel.dart';

/// 2027 Aion 2 Mobile Ornate Forge Crafting Preview Panel
class CraftingPreviewPanel extends StatelessWidget {
  const CraftingPreviewPanel({
    super.key,
    required this.recipe,
    required this.batchCount,
    required this.canCraft,
    required this.isCrafting,
    required this.hasEnoughMaterials,
    required this.canAffordGold,
    required this.playerGold,
    required this.queueUsed,
    required this.queueMax,
    this.expandGemCost,
    this.canAffordExpand = false,
    this.isExpandingQueue = false,
    this.playerGems = 0,
    this.onExpandQueue,
    required this.ownedQuantities,
    this.bankQuantities = const <String, int>{},
    required this.onCraft,
    required this.onClose,
    required this.onBatchDecrement,
    required this.onBatchIncrement,
  });

  final CraftRecipe? recipe;
  final int batchCount;
  final bool canCraft;
  final bool isCrafting;
  final bool hasEnoughMaterials;
  final bool canAffordGold;
  final int playerGold;
  final int queueUsed;
  final int queueMax;
  final int? expandGemCost;
  final bool canAffordExpand;
  final bool isExpandingQueue;
  final double playerGems;
  final Future<bool> Function()? onExpandQueue;
  final Map<String, int> ownedQuantities;
  final Map<String, int> bankQuantities;
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
          color: const Color(0xFF0F1424),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.info_outline, color: AppColors.mutedTitanium, size: 20),
            const SizedBox(width: 10),
            Text(
              'Bir demircilik tarifi seçin',
              style: AppTextStyles.caption.copyWith(color: AppColors.mutedTitanium),
            ),
          ],
        ),
      );
    }

    final AionRarityTier tier = AionRarityTier.fromString(recipe!.outputRarity);
    final Color rarityColor = tier.primaryColor;
    final int? timeSec = recipe!.productionTimeSeconds;
    final String timeLabel = timeSec == null
        ? 'Anında'
        : formatCraftingDuration(timeSec * batchCount);
    final int totalOutput = recipe!.outputQuantity * batchCount;
    final int totalXp = (recipe!.xpReward ?? 0) * batchCount;
    final double successRate = recipe!.normalizedSuccessRate;

    final bool showMatError = !hasEnoughMaterials;
    final int bankCoveredShortfall = recipe!.ingredients.where((ing) {
      final int owned = ownedQuantities[ing.itemId] ?? 0;
      final int req = ing.quantity * batchCount;
      if (owned >= req) return false;
      return (bankQuantities[ing.itemId] ?? 0) > 0;
    }).length;
    final bool showBankWithdrawHint = showMatError && bankCoveredShortfall > 0;
    final int totalGoldCost = totalCraftGoldCost(recipe!, batchCount);
    final bool showGoldError = recipe!.goldCost > 0 && !canAffordGold;
    final bool queueFull = queueUsed >= queueMax;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF192033).withValues(alpha: 0.98),
            const Color(0xFF0D1220).withValues(alpha: 0.99),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: rarityColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: rarityColor.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Top Header: Title, Rarity, and Close Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: rarityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: rarityColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              tier.displayName,
                              style: AppTextStyles.micro.copyWith(
                                color: rarityColor,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sv.${recipe!.requiredLevel} Gereksinim',
                            style: AppTextStyles.micro.copyWith(
                              color: AppColors.mutedTitanium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recipe!.outputName?.isNotEmpty == true
                            ? recipe!.outputName!
                            : recipe!.name,
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
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
            const SizedBox(height: 12),
            // Item Chamber Pedestal
            AionRarityGlowBorder(
              tier: tier,
              borderRadius: 14,
              borderWidth: 1.5,
              hasActiveGlow: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: isCrafting ? 0.95 : 0.4,
                          child: CraftingPreviewForgeBackdrop(
                            isCrafting: isCrafting,
                            height: 80,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090D18).withValues(alpha: 0.8),
                      ),
                      child: Row(
                  children: <Widget>[
                    Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        if (tier.hasSparkles)
                          Positioned.fill(
                            child: EnchantingSparklesOverlay(
                              tier: tier,
                              particleCount: 5,
                            ),
                          ),
                        Container(
                          width: 58,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tier.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: tier.primaryColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: ItemIconView(
                            iconValue: recipe!.outputItemId,
                            itemId: recipe!.outputItemId,
                            size: 52,
                            expand: true,
                            fallback: '❔',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            recipe!.outputName?.isNotEmpty == true
                                ? recipe!.outputName!
                                : recipe!.name,
                            style: AppTextStyles.bodyBold.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Üretim Çıktısı: x$totalOutput adet',
                            style: AppTextStyles.captionBold.copyWith(
                              color: AppColors.liquidGold,
                              fontSize: 12,
                            ),
                          ),
                          if (recipe!.description.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              recipe!.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.micro.copyWith(
                                color: AppColors.mutedTitanium,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Material Slots Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'GEREKLİ MALZEMELER',
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.liquidGold,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${recipe!.ingredients.length} çeşit malzeme',
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.mutedTitanium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Material slots grid
            LayoutBuilder(
              builder: (context, constraints) {
                final int crossAxisCount = constraints.maxWidth > 340 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: recipe!.ingredients.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ing = recipe!.ingredients[index];
                    final int owned = ownedQuantities[ing.itemId] ?? 0;
                    final int requiredCount = ing.quantity * batchCount;
                    final int inBank = bankQuantities[ing.itemId] ?? 0;

                    return OrnateForgeMaterialSlot(
                      ingredient: ing,
                      owned: owned,
                      requiredCount: requiredCount,
                      inBank: inBank,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 14),
            // Info Chips (Level, Success Rate, Duration, Queue, Gold, XP)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                _CraftingInfoChip(
                  icon: Icons.military_tech_rounded,
                  label: 'Sv.${recipe!.requiredLevel}',
                ),
                _CraftingInfoChip(
                  icon: Icons.percent_rounded,
                  label: '%${(successRate * 100).round()} Başarı',
                  color: AppColors.liquidGold,
                ),
                _CraftingInfoChip(
                  icon: Icons.timer_rounded,
                  label: timeLabel,
                ),
                _CraftingInfoChip(
                  icon: Icons.inventory_2_outlined,
                  label: 'Kuyruk $queueUsed/$queueMax',
                  color: queueFull ? AppColors.mysticRuby : const Color(0xFF93C5FD),
                ),
                if (recipe!.goldCost > 0)
                  _CraftingInfoChip(
                    icon: Icons.paid_rounded,
                    label: '$totalGoldCost Altın',
                    color: showGoldError ? AppColors.mysticRuby : AppColors.goldLight,
                  ),
                _CraftingInfoChip(
                  icon: Icons.auto_awesome_rounded,
                  label: '+$totalXp XP',
                  color: AppColors.liquidGold,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Batch Count Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B101D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.liquidGold.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Üretim Adedi (Batch)',
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'En fazla $craftingBatchLimit adet aynı anda üretilebilir',
                        style: AppTextStyles.micro.copyWith(
                          color: AppColors.mutedTitanium,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Minus Button
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: OutlinedButton(
                      onPressed: batchCount > 1
                          ? () async {
                              await AionHaptics.slotSelect();
                              onBatchDecrement();
                            }
                          : null,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(
                          color: batchCount > 1
                              ? AppColors.liquidGold.withValues(alpha: 0.5)
                              : Colors.white12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('−', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.darkObsidian.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.liquidGold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '$batchCount',
                      style: AppTextStyles.captionBold.copyWith(
                        color: AppColors.liquidGold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Plus Button
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: OutlinedButton(
                      onPressed: batchCount < craftingBatchLimit
                          ? () async {
                              await AionHaptics.slotSelect();
                              onBatchIncrement();
                            }
                          : null,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(
                          color: batchCount < craftingBatchLimit
                              ? AppColors.liquidGold.withValues(alpha: 0.5)
                              : Colors.white12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('+', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Queue Slots Panel
            CraftingQueueSlotsPanel(
              unlockedSlots: queueMax,
              queueLength: queueUsed,
              playerGems: playerGems,
              isExpanding: isExpandingQueue,
              onRequestUnlock: onExpandQueue == null
                  ? () {}
                  : () {
                      onExpandQueue!();
                    },
            ),
            if (queueFull) ...<Widget>[
              const SizedBox(height: 8),
              _buildErrorBox('⚠️ Kuyruk dolu ($queueUsed/$queueMax) — slot açarak genişletin'),
              if (expandGemCost != null && !canAffordExpand)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Sonraki slot için $expandGemCost ELMAS gerekli',
                    style: AppTextStyles.micro.copyWith(color: const Color(0xFFFCA5A5)),
                  ),
                ),
            ],
            if (showGoldError)
              _buildErrorBox('⚠️ Altın yetersiz ($playerGold / $totalGoldCost)'),
            if (showMatError)
              _buildErrorBox('⚠️ Gerekli malzemeler yetersiz'),
            if (showBankWithdrawHint)
              _buildInfoBox(
                '🏦 $bankCoveredShortfall malzeme bankanızda mevcut — bankadan çekip üretime başlayabilirsiniz',
              ),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: () async {
                      await AionHaptics.slotSelect();
                      onClose();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      foregroundColor: AppColors.mutedTitanium,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('Vazgeç', style: AppTextStyles.captionBold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TutorialAnchorScope(
                    id: TutorialAnchorId.craftStartBtn,
                    child: FilledButton(
                      onPressed: canCraft
                          ? () async {
                              await AionHaptics.craftSuccess();
                              onCraft();
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        elevation: canCraft ? 4 : 0,
                        shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: canCraft
                                ? AppColors.liquidGold.withValues(alpha: 0.8)
                                : Colors.white12,
                          ),
                        ),
                      ),
                      child: Text(
                        isCrafting
                            ? 'Dövülüyor...'
                            : '🔨 Ocağı Ateşle (${batchCount}x)',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.captionBold.copyWith(
                          fontSize: 13,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
          color: AppColors.mysticRuby.withValues(alpha: 0.15),
          border: Border.all(color: AppColors.mysticRuby.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: AppTextStyles.micro.copyWith(
            color: const Color(0xFFFCA5A5),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.liquidGold.withValues(alpha: 0.14),
          border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: AppTextStyles.micro.copyWith(
            color: AppColors.goldLight,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CraftingInfoChip extends StatelessWidget {
  const _CraftingInfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? AppColors.mutedTitanium;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF090D18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.micro.copyWith(
              color: c,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
