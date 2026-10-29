import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../models/crafting_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../inventory/widgets/aion_rarity_glow.dart';
import '../crafting_utils.dart';

/// 2027 Aion 2 Mobile 3D Recipe Carousel for high-fantasy forge crafting.
class CraftingRecipeCarousel extends StatefulWidget {
  const CraftingRecipeCarousel({
    super.key,
    required this.recipes,
    required this.selectedRecipeId,
    required this.hasMaterials,
    required this.onSelectRecipe,
    required this.onOpenPreview,
  });

  final List<CraftRecipe> recipes;
  final String? selectedRecipeId;
  final bool Function(CraftRecipe) hasMaterials;
  final void Function(CraftRecipe) onSelectRecipe;
  final void Function(CraftRecipe) onOpenPreview;

  @override
  State<CraftingRecipeCarousel> createState() => _CraftingRecipeCarouselState();
}

class _CraftingRecipeCarouselState extends State<CraftingRecipeCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    int initialPage = 0;
    if (widget.selectedRecipeId != null) {
      final index = widget.recipes.indexWhere((r) => r.id == widget.selectedRecipeId);
      if (index >= 0) initialPage = index;
    }
    _currentPage = initialPage;
    _pageController = PageController(
      viewportFraction: 0.82,
      initialPage: initialPage,
    );
  }

  @override
  void didUpdateWidget(covariant CraftingRecipeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedRecipeId != null &&
        widget.selectedRecipeId != oldWidget.selectedRecipeId) {
      final index = widget.recipes.indexWhere((r) => r.id == widget.selectedRecipeId);
      if (index >= 0 && index != _currentPage && _pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recipes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: 380,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.recipes.length,
            onPageChanged: (int page) {
              setState(() => _currentPage = page);
              AionHaptics.slotSelect();
              widget.onSelectRecipe(widget.recipes[page]);
            },
            itemBuilder: (BuildContext context, int index) {
              final CraftRecipe recipe = widget.recipes[index];
              final bool canCraft = widget.hasMaterials(recipe);

              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    final double page = _pageController.page ?? _currentPage.toDouble();
                    value = (1.0 - ((page - index).abs() * 0.14)).clamp(0.85, 1.0);
                  } else {
                    value = index == _currentPage ? 1.0 : 0.88;
                  }

                  return Center(
                    child: SizedBox(
                      height: Curves.easeOut.transform(value) * 380,
                      width: Curves.easeOut.transform(value) * 320,
                      child: child,
                    ),
                  );
                },
                child: _CarouselRecipeCard(
                  recipe: recipe,
                  canCraft: canCraft,
                  isCurrent: index == _currentPage,
                  onTap: () => widget.onOpenPreview(recipe),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Page indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(
            math.min(widget.recipes.length, 12),
            (int index) {
              final bool active = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: active
                      ? AppColors.liquidGold
                      : AppColors.mutedTitanium.withValues(alpha: 0.3),
                  boxShadow: active
                      ? <BoxShadow>[
                          BoxShadow(
                            color: AppColors.liquidGold.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CarouselRecipeCard extends StatelessWidget {
  const _CarouselRecipeCard({
    required this.recipe,
    required this.canCraft,
    required this.isCurrent,
    required this.onTap,
  });

  final CraftRecipe recipe;
  final bool canCraft;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AionRarityTier tier = AionRarityTier.fromString(recipe.outputRarity);
    final Color rarityColor = tier.primaryColor;
    final int? timeSec = recipe.productionTimeSeconds;
    final String timeLabel = timeSec == null ? 'Anında' : formatCraftingDuration(timeSec);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await AionHaptics.slotSelect();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xFF1B2338).withValues(alpha: 0.95),
                const Color(0xFF0F1424).withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(
              color: isCurrent
                  ? rarityColor.withValues(alpha: 0.75)
                  : AppColors.borderDefault,
              width: isCurrent ? 1.8 : 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: isCurrent
                    ? rarityColor.withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: 0.4),
                blurRadius: isCurrent ? 24 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Top Rarity and Level Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B101D),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      'Gereksinim: Sv.${recipe.requiredLevel}',
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.mutedTitanium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Center Forging Pedestal / Chamber
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      // Pedestal ambient glow
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              rarityColor.withValues(alpha: 0.35),
                              rarityColor.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                      AionRarityGlowBorder(
                        tier: tier,
                        borderRadius: 16,
                        borderWidth: 1.5,
                        hasActiveGlow: isCurrent,
                        child: Container(
                          width: 86,
                          height: 86,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0E1A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: rarityColor.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              if (tier.hasSparkles)
                                Positioned.fill(
                                  child: EnchantingSparklesOverlay(
                                    tier: tier,
                                    particleCount: 5,
                                  ),
                                ),
                              ItemIconView(
                                iconValue: recipe.outputItemId,
                                itemId: recipe.outputItemId,
                                size: 70,
                                expand: true,
                                fallback: '❔',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Recipe Name
              Text(
                recipe.outputName?.isNotEmpty == true ? recipe.outputName! : recipe.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyBold.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              // Production Time & Success Rate Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.timer_outlined, size: 12, color: AppColors.mutedTitanium),
                  const SizedBox(width: 3),
                  Text(
                    timeLabel,
                    style: AppTextStyles.micro.copyWith(color: AppColors.mutedTitanium),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.auto_awesome, size: 12, color: AppColors.liquidGold),
                  const SizedBox(width: 3),
                  Text(
                    '%${(recipe.normalizedSuccessRate * 100).round()} Başarı',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.liquidGold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Materials Preview Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: recipe.ingredients.take(4).map((ing) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ItemIconView(
                      iconValue: ing.itemId,
                      itemId: ing.itemId,
                      size: 20,
                      expand: true,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // Action Button
              FilledButton(
                onPressed: () async {
                  await AionHaptics.slotSelect();
                  onTap();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: canCraft
                      ? const Color(0xFFD97706)
                      : AppColors.darkObsidian,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: canCraft
                          ? AppColors.liquidGold.withValues(alpha: 0.6)
                          : Colors.white12,
                    ),
                  ),
                  elevation: canCraft ? 4 : 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      canCraft ? Icons.hardware_rounded : Icons.info_outline_rounded,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      canCraft ? 'Döv ve Üret' : 'Gereksinimleri Gör',
                      style: AppTextStyles.captionBold.copyWith(
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
