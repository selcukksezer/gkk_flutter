import 'package:flutter/material.dart';

import '../../../components/common/gkk_card.dart';
import '../../../components/common/gkk_tab_bar.dart';
import '../../../components/common/item_icon_view.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../models/crafting_model.dart';
import '../../../theme/app_colors.dart';
import '../crafting_utils.dart';

/// Vault-style horizontal category filters — no duplicate page header.
class CraftingCategoryTabBar extends StatelessWidget {
  const CraftingCategoryTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    required this.recipeCount,
  });

  final TabController controller;
  final List<(String, String)> tabs;
  final int recipeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                'TARİFLER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: AppColors.mutedTitanium,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.darkObsidian.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  '$recipeCount kayıt',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mutedTitanium),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GkkTabBar(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            margin: EdgeInsets.zero,
            tabs: GkkTabBar.textTabs(
              tabs.map((t) => t.$2).toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

/// Staggered fade + slide entry per tasarım skill §5.
class CraftingRecipeGridTile extends StatelessWidget {
  const CraftingRecipeGridTile({
    super.key,
    required this.index,
    required this.recipe,
    required this.isSelected,
    required this.hasMaterials,
    required this.onTap,
  });

  final int index;
  final CraftRecipe recipe;
  final bool isSelected;
  final bool hasMaterials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('craft_tile_${recipe.id}_$index'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index % 8) * 35),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: CraftingRecipeGridCard(
        recipe: recipe,
        isSelected: isSelected,
        hasMaterials: hasMaterials,
        onTap: onTap,
      ),
    );
  }
}

class CraftingRecipeGridCard extends StatefulWidget {
  const CraftingRecipeGridCard({
    super.key,
    required this.recipe,
    required this.isSelected,
    required this.hasMaterials,
    required this.onTap,
  });

  final CraftRecipe recipe;
  final bool isSelected;
  final bool hasMaterials;
  final VoidCallback onTap;

  @override
  State<CraftingRecipeGridCard> createState() => _CraftingRecipeGridCardState();
}

class _CraftingRecipeGridCardState extends State<CraftingRecipeGridCard> {
  double _scale = 1;

  Color get _rarityColor => craftingRarityColor(widget.recipe.outputRarity);

  void _setPressed(bool pressed) {
    setState(() => _scale = pressed ? 0.96 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final bool dimmed = !widget.hasMaterials;
    final Color accent = _rarityColor;
    final bool glow = widget.isSelected || widget.hasMaterials;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Opacity(
          opacity: dimmed ? 0.5 : 1,
          child: Tooltip(
            message: dimmed ? 'Malzeme yetersiz' : widget.recipe.name,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DotGridPainter(dotOpacity: 0.08, spacing: 14),
                    ),
                  ),
                  GkkCard(
                    padding: const EdgeInsets.all(10),
                    accentColor: accent,
                    borderGlow: glow,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        GameScreenBackground.spaceNavy.withValues(alpha: 0.94),
                        AppColors.carbonVoid.withValues(alpha: 0.9),
                      ],
                    ),
                    borderRadius: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                                boxShadow: glow
                                    ? <BoxShadow>[
                                        BoxShadow(
                                          color: accent.withValues(alpha: 0.45),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.recipe.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: accent.withValues(alpha: 0.28)),
                                boxShadow: glow
                                    ? <BoxShadow>[
                                        BoxShadow(
                                          color: accent.withValues(alpha: 0.14),
                                          blurRadius: 14,
                                          spreadRadius: -4,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ItemIconView(
                                iconValue: widget.recipe.outputItemId,
                                itemId: widget.recipe.outputItemId,
                                size: 44,
                                expand: true,
                                fallback: '❔',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sv.${widget.recipe.requiredLevel}',
                          style: const TextStyle(fontSize: 10, color: AppColors.mutedTitanium),
                        ),
                        Text(
                          '${(widget.recipe.normalizedSuccessRate * 100).round()}% başarı',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accent.withValues(alpha: 0.9)),
                        ),
                        if (widget.recipe.gemCost > 0)
                          Text(
                            '💎 ${widget.recipe.gemCost}',
                            style: const TextStyle(fontSize: 10, color: AppColors.cyberFuchsia),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
