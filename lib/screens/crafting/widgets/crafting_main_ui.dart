import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../components/common/gkk_card.dart';
import '../../../components/common/gkk_tab_bar.dart';
import '../../../components/common/item_icon_view.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../models/crafting_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../inventory/widgets/aion_rarity_glow.dart';

/// Ornate Aion 2 Mobile Vault-style horizontal category filters with obsidian glass aesthetics.
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
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.liquidGold.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.45),
                    width: 0.8,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 11,
                  color: AppColors.liquidGold,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'DEMİRCİLİK KATEGORİLERİ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.micro.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    color: AppColors.liquidGold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.darkObsidian.withValues(alpha: 0.85),
                      AppColors.carbonVoid.withValues(alpha: 0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.12),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.handyman_rounded,
                      size: 9.5,
                      color: AppColors.liquidGold.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$recipeCount tarif',
                      style: AppTextStyles.micro.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GkkTabBar(
            controller: controller,
            padding: EdgeInsets.zero,
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

/// Staggered fade + slide entry per tasarım skill.
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
      duration: Duration(milliseconds: 240 + (index % 8) * 30),
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

/// Ornate 2027 Aion 2 Mobile Crafting Recipe Grid Card with obsidian dark-glass,
/// forge fire ambience, material slot pedestal glow, and responsive zero-overflow layout.
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

  AionRarityTier get _tier => AionRarityTier.fromString(widget.recipe.outputRarity);
  Color get _rarityColor => _tier.primaryColor;

  void _setPressed(bool pressed) {
    setState(() => _scale = pressed ? 0.96 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final bool dimmed = !widget.hasMaterials;
    final AionRarityTier tier = _tier;
    final Color accent = _rarityColor;
    final bool glow = widget.isSelected || widget.hasMaterials;

    final Color borderColor = widget.isSelected
        ? AppColors.liquidGold
        : (widget.hasMaterials
            ? accent.withValues(alpha: 0.65)
            : AppColors.borderDefault.withValues(alpha: 0.5));

    final Color runeColor = widget.isSelected
        ? AppColors.accentCyan
        : (widget.hasMaterials
            ? AppColors.liquidGold.withValues(alpha: 0.7)
            : AppColors.borderDefault.withValues(alpha: 0.35));

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () async {
        await AionHaptics.slotSelect();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Opacity(
          opacity: dimmed ? 0.60 : 1.0,
          child: Tooltip(
            message: dimmed ? 'Malzeme yetersiz' : widget.recipe.name,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: <Widget>[
                  // Subtle background dot matrix grid
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DotGridPainter(dotOpacity: 0.06, spacing: 14),
                    ),
                  ),

                  // Hearth ember radial warmth
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.05),
                          radius: 0.75,
                          colors: <Color>[
                            (widget.isSelected ? AppColors.liquidGold : accent)
                                .withValues(alpha: glow ? 0.18 : 0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Main Obsidian Glass Container with Runic Border
                  CustomPaint(
                    foregroundPainter: _AionGlassBorderPainter(
                      borderColor: borderColor,
                      borderWidth: widget.isSelected ? 1.6 : 1.0,
                      borderRadius: 14,
                      hasGlow: glow,
                      glowColor: widget.isSelected ? AppColors.accentCyan : accent,
                      showRunes: true,
                      secondaryRuneColor: runeColor,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            const Color(0xFF131A29).withValues(alpha: 0.96),
                            const Color(0xFF090D18).withValues(alpha: 0.98),
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.7),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                          if (glow)
                            BoxShadow(
                              color: (widget.isSelected ? AppColors.liquidGold : accent)
                                  .withValues(alpha: widget.isSelected ? 0.28 : 0.16),
                              blurRadius: widget.isSelected ? 16 : 8,
                              spreadRadius: 0.5,
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // 1. Header: Rarity gemstone dot, recipe name, and forge status
                          Row(
                            children: <Widget>[
                              Container(
                                width: 8,
                                height: 8,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent,
                                  boxShadow: glow
                                      ? <BoxShadow>[
                                          BoxShadow(
                                            color: accent.withValues(alpha: 0.65),
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  widget.recipe.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.captionBold.copyWith(
                                    fontSize: 10.5,
                                    letterSpacing: 0.2,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (widget.hasMaterials)
                                Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.liquidGold.withValues(alpha: 0.25),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.liquidGold.withValues(alpha: 0.6),
                                      width: 0.8,
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: AppColors.liquidGold.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 9.5,
                                    color: AppColors.liquidGold,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 9,
                                  color: AppColors.mutedTitanium.withValues(alpha: 0.45),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),

                          // 2. Center Chamber: Item Icon Pedestal with Living Aura
                          Expanded(
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AionRarityGlowBorder(
                                  tier: tier,
                                  borderRadius: 12,
                                  isSelected: widget.isSelected,
                                  hasActiveGlow: glow,
                                  child: Container(
                                    width: 58,
                                    height: 58,
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF070B16),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.35),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: <Widget>[
                                        if (tier.hasSparkles)
                                          Positioned.fill(
                                            child: EnchantingSparklesOverlay(
                                              tier: tier,
                                              particleCount: 4,
                                            ),
                                          ),
                                        ItemIconView(
                                          iconValue: widget.recipe.outputItemId,
                                          itemId: widget.recipe.outputItemId,
                                          size: 44,
                                          expand: true,
                                          fallback: '❔',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 3. Material mini indicators (up to 3 sockets)
                          if (widget.recipe.ingredients.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 3),
                            SizedBox(
                              height: 18,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: widget.recipe.ingredients.take(3).map((ing) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF090D18),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: widget.hasMaterials
                                              ? const Color(0xFF10B981).withValues(alpha: 0.6)
                                              : AppColors.liquidGold.withValues(alpha: 0.35),
                                          width: 0.7,
                                        ),
                                      ),
                                      child: ItemIconView(
                                        iconValue: ing.itemId,
                                        itemId: ing.itemId,
                                        size: 12,
                                        expand: true,
                                      ),
                                    ),
                                  );
                                }).toList(growable: false),
                              ),
                            ),
                          ],
                          const SizedBox(height: 3),

                          // 4. Footer: Level Requirement and Success Rate Gauge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF080D1A),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.white12, width: 0.6),
                                  ),
                                  child: Text(
                                    'Sv.${widget.recipe.requiredLevel}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.micro.copyWith(
                                      color: AppColors.mutedTitanium,
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.45),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.auto_awesome,
                                      size: 8.5,
                                      color: accent,
                                    ),
                                    const SizedBox(width: 2.5),
                                    Text(
                                      '%${(widget.recipe.normalizedSuccessRate * 100).round()}',
                                      style: AppTextStyles.micro.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 9.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // 5. Gem cost if present
                          if (widget.recipe.gemCost > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Text('💎', style: TextStyle(fontSize: 8)),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${widget.recipe.gemCost}',
                                    style: AppTextStyles.micro.copyWith(
                                      color: AppColors.cyberFuchsia,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 8.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // 6. Action status pill with high-fantasy gold/cyan finish
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: widget.hasMaterials
                                  ? LinearGradient(
                                      colors: <Color>[
                                        AppColors.liquidGold.withValues(alpha: 0.28),
                                        AppColors.accentCyan.withValues(alpha: 0.18),
                                      ],
                                    )
                                  : null,
                              color: widget.hasMaterials
                                  ? null
                                  : const Color(0xFF0A0F1D).withValues(alpha: 0.8),
                              border: Border.all(
                                color: widget.hasMaterials
                                    ? AppColors.liquidGold.withValues(alpha: 0.65)
                                    : Colors.white10,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  widget.hasMaterials
                                      ? Icons.hardware_rounded
                                      : Icons.search_rounded,
                                  size: 9,
                                  color: widget.hasMaterials
                                      ? AppColors.liquidGold
                                      : AppColors.mutedTitanium.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  widget.hasMaterials ? 'HAZIR' : 'İNCELE',
                                  style: AppTextStyles.micro.copyWith(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: widget.hasMaterials
                                        ? AppColors.liquidGold
                                        : AppColors.mutedTitanium.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

// ────────────────────────────────────────────────────────────────────────────
// 2027 AION 2 STANDALONE REUSABLE CRAFTING UI COMPONENTS
// ────────────────────────────────────────────────────────────────────────────

/// Standalone 2027 Aion 2 Mobile Material Slots Row.
/// Displays required ingredients as obsidian glass sockets with pedestal glow,
/// satisfied/shortage status rings, and bank surplus indicators.
/// Protected with horizontal scroll to guarantee zero render overflow.
class CraftingMaterialSlotsRow extends StatelessWidget {
  const CraftingMaterialSlotsRow({
    super.key,
    required this.ingredients,
    this.ownedQuantities = const <String, int>{},
    this.bankQuantities = const <String, int>{},
    this.batchCount = 1,
    this.compact = false,
    this.onTapIngredient,
  });

  final List<CraftIngredient> ingredients;
  final Map<String, int> ownedQuantities;
  final Map<String, int> bankQuantities;
  final int batchCount;
  final bool compact;
  final void Function(CraftIngredient)? onTapIngredient;

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) {
      return const SizedBox.shrink();
    }

    final double socketSize = compact ? 26.0 : 36.0;
    final double iconSize = compact ? 18.0 : 26.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ingredients.map((ing) {
          final int owned = ownedQuantities[ing.itemId] ?? 0;
          final int required = ing.quantity * batchCount;
          final bool satisfied = owned >= required;
          final int inBank = bankQuantities[ing.itemId] ?? 0;
          final bool bankHint = !satisfied && inBank > 0;

          final Color statusColor = satisfied
              ? const Color(0xFF10B981) // emerald
              : (bankHint ? AppColors.liquidGold : const Color(0xFFEF4444)); // ruby

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTapIngredient != null ? () => onTapIngredient!(ing) : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: compact
                      ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                      : const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D18).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: statusColor.withValues(alpha: satisfied ? 0.45 : 0.7),
                      width: 1.0,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.15),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: socketSize,
                        height: socketSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF070A12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.liquidGold.withValues(alpha: 0.25),
                            width: 0.6,
                          ),
                        ),
                        child: ItemIconView(
                          iconValue: ing.itemId,
                          itemId: ing.itemId,
                          size: iconSize,
                          expand: true,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            ing.itemName.isNotEmpty ? ing.itemName : ing.itemId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.micro.copyWith(
                              fontSize: compact ? 8.5 : 9.5,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$owned / $required',
                            style: AppTextStyles.micro.copyWith(
                              fontSize: compact ? 8.0 : 9.0,
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

/// Ornate 2027 Aion 2 Mobile Success Rate Gauge.
/// Displays a high-fantasy circular meter with liquid gold and celestial cyan
/// borders, glowing percentage text, and forge aura.
class CraftingSuccessGauge extends StatelessWidget {
  const CraftingSuccessGauge({
    super.key,
    required this.successRate,
    this.size = 46.0,
    this.strokeWidth = 3.5,
    this.showLabel = true,
  });

  final double successRate;
  final double size;
  final double strokeWidth;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final Color gold = AppColors.liquidGold;
    final Color cyan = AppColors.accentCyan;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size(size, size),
            painter: _SuccessGaugePainter(
              rate: successRate,
              primaryColor: gold,
              secondaryColor: cyan,
              backgroundColor: AppColors.darkObsidian.withValues(alpha: 0.5),
              strokeWidth: strokeWidth,
            ),
          ),
          if (showLabel)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '%${(successRate * 100).round()}',
                  style: AppTextStyles.micro.copyWith(
                    color: gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ornate 2027 Aion 2 Mobile Forge Action Button.
/// High-fantasy obsidian dark glass button with molten gold/cyan borders,
/// living ember glow, haptic feedback, and responsive layout.
class CraftingActionForgeButton extends StatefulWidget {
  const CraftingActionForgeButton({
    super.key,
    required this.label,
    required this.canCraft,
    required this.isCrafting,
    required this.onPressed,
    this.batchCount = 1,
    this.goldCost = 0,
    this.canAffordGold = true,
  });

  final String label;
  final bool canCraft;
  final bool isCrafting;
  final VoidCallback onPressed;
  final int batchCount;
  final int goldCost;
  final bool canAffordGold;

  @override
  State<CraftingActionForgeButton> createState() => _CraftingActionForgeButtonState();
}

class _CraftingActionForgeButtonState extends State<CraftingActionForgeButton> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    if (!widget.canCraft) return;
    setState(() => _scale = pressed ? 0.97 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.canCraft && !widget.isCrafting;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: enabled
          ? () async {
              await AionHaptics.craftSuccess();
              widget.onPressed();
            }
          : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: enabled
                ? const LinearGradient(
                    colors: <Color>[
                      Color(0xFFE65100), // molten forge amber
                      AppColors.liquidGold,
                      Color(0xFFD97706),
                    ],
                  )
                : LinearGradient(
                    colors: <Color>[
                      AppColors.darkObsidian.withValues(alpha: 0.6),
                      AppColors.carbonVoid.withValues(alpha: 0.8),
                    ],
                  ),
            border: Border.all(
              color: enabled
                  ? AppColors.goldLight.withValues(alpha: 0.85)
                  : Colors.white12,
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              if (enabled)
                BoxShadow(
                  color: AppColors.liquidGold.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Top specular sheen
              Positioned(
                top: 0,
                left: 12,
                right: 12,
                height: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (widget.isCrafting)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        enabled
                            ? Icons.local_fire_department_rounded
                            : Icons.lock_outline_rounded,
                        size: 18,
                        color: enabled ? Colors.white : AppColors.mutedTitanium,
                      ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.isCrafting ? 'DÖVÜLÜYOR...' : widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.captionBold.copyWith(
                          color: enabled ? Colors.white : AppColors.mutedTitanium,
                          letterSpacing: 0.6,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (widget.batchCount > 1) ...<Widget>[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${widget.batchCount}x',
                          style: AppTextStyles.micro.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
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

// ────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTERS: AION 2 DARK GLASS BORDERS & GAUGES
// ────────────────────────────────────────────────────────────────────────────

/// Custom painter for Aion 2 dark-glass borders, corner runes, and top specular sheen.
class _AionGlassBorderPainter extends CustomPainter {
  _AionGlassBorderPainter({
    required this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius = 14.0,
    this.hasGlow = false,
    this.glowColor,
    this.showRunes = true,
    this.secondaryRuneColor,
  });

  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final bool hasGlow;
  final Color? glowColor;
  final bool showRunes;
  final Color? secondaryRuneColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Outer glow if active
    if (hasGlow && glowColor != null) {
      final Paint glowPaint = Paint()
        ..color = glowColor!.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth + 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(rrect, glowPaint);
    }

    // Main border
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(rrect, borderPaint);

    // Top sheen
    final Paint sheenPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(rect.left + 10, rect.top),
        Offset(rect.right - 10, rect.top),
        <Color>[
          Colors.transparent,
          Colors.white.withValues(alpha: 0.18),
          AppColors.liquidGold.withValues(alpha: 0.25),
          Colors.transparent,
        ],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(rect.left + borderRadius, rect.top + 0.5),
      Offset(rect.right - borderRadius, rect.top + 0.5),
      sheenPaint,
    );

    // Corner Runes
    if (showRunes) {
      final Paint runePaint = Paint()
        ..color = secondaryRuneColor ?? AppColors.liquidGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;

      const double notch = 4.5;
      const double pad = 3.0;

      // Top Left
      canvas.drawLine(const Offset(pad, pad + notch), const Offset(pad, pad), runePaint);
      canvas.drawLine(const Offset(pad, pad), const Offset(pad + notch, pad), runePaint);

      // Top Right
      canvas.drawLine(Offset(size.width - pad - notch, pad), Offset(size.width - pad, pad), runePaint);
      canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad, pad + notch), runePaint);

      // Bottom Left
      canvas.drawLine(Offset(pad, size.height - pad - notch), Offset(pad, size.height - pad), runePaint);
      canvas.drawLine(Offset(pad, size.height - pad), Offset(pad + notch, size.height - pad), runePaint);

      // Bottom Right
      canvas.drawLine(Offset(size.width - pad - notch, size.height - pad), Offset(size.width - pad, size.height - pad), runePaint);
      canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad, size.height - pad - notch), runePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AionGlassBorderPainter old) {
    return old.borderColor != borderColor ||
        old.borderWidth != borderWidth ||
        old.borderRadius != borderRadius ||
        old.hasGlow != hasGlow ||
        old.glowColor != glowColor ||
        old.showRunes != showRunes ||
        old.secondaryRuneColor != secondaryRuneColor;
  }
}

/// Custom painter for radial success rate gauge with dual gradient.
class _SuccessGaugePainter extends CustomPainter {
  _SuccessGaugePainter({
    required this.rate,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  final double rate;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Background track
    final Paint bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    if (rate <= 0) return;

    // Glowing arc
    final Paint arcPaint = Paint()
      ..shader = ui.Gradient.sweep(
        center,
        <Color>[secondaryColor, primaryColor],
        <double>[0.0, rate.clamp(0.01, 1.0)],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final double startAngle = -math.pi / 2;
    final double sweepAngle = 2 * math.pi * rate.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SuccessGaugePainter old) =>
      old.rate != rate ||
      old.primaryColor != primaryColor ||
      old.secondaryColor != secondaryColor ||
      old.strokeWidth != strokeWidth;
}
