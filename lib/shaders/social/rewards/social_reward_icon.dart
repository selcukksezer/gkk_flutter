import 'package:flutter/material.dart';
import '../theme/social_theme_tokens.dart';
import 'reward_types.dart';
import 'celestial_wings_painter.dart';
import 'daeva_chest_painter.dart';
import 'abyss_crystal_painter.dart';
import 'enchantment_stone_painter.dart';
import 'honor_insignia_painter.dart';

/// Predefined sizes for social progression reward icons.
enum SocialRewardSize {
  tiny(36.0),
  small(48.0),
  medium(68.0),
  large(92.0),
  hero(140.0);

  const SocialRewardSize(this.dimension);
  final double dimension;
}

/// Unified 2027 Aion 2 Mobile reward icon widget.
///
/// Wraps any of the 5 authentic social progression reward illustrations
/// (Celestial Wings, Daeva Chest, Abyss Crystal, Enchantment Stone, Honor Insignia)
/// in an authentic glassmorphic frame with rarity aura borders and count badges.
class SocialRewardIcon extends StatelessWidget {
  const SocialRewardIcon({
    super.key,
    required this.type,
    this.rarity = SocialRewardRarity.mythic,
    this.size = SocialRewardSize.medium,
    this.customSize,
    this.countText,
    this.showRarityFrame = true,
    this.showAuraGlow = true,
    this.isSelected = false,
    this.animate = true,
    this.animationDuration,
    this.onTap,
  });

  /// Factory for Celestial Archon Wings.
  factory SocialRewardIcon.wings({
    Key? key,
    SocialRewardRarity rarity = SocialRewardRarity.ancient,
    SocialRewardSize size = SocialRewardSize.medium,
    double? customSize,
    String? countText,
    bool showRarityFrame = true,
    bool showAuraGlow = true,
    bool isSelected = false,
    bool animate = true,
    Duration? animationDuration,
    VoidCallback? onTap,
  }) {
    return SocialRewardIcon(
      key: key,
      type: SocialRewardType.celestialArchonWings,
      rarity: rarity,
      size: size,
      customSize: customSize,
      countText: countText,
      showRarityFrame: showRarityFrame,
      showAuraGlow: showAuraGlow,
      isSelected: isSelected,
      animate: animate,
      animationDuration: animationDuration,
      onTap: onTap,
    );
  }

  /// Factory for Mythic Daeva Chest.
  factory SocialRewardIcon.chest({
    Key? key,
    SocialRewardRarity rarity = SocialRewardRarity.fabled,
    SocialRewardSize size = SocialRewardSize.medium,
    double? customSize,
    String? countText,
    bool showRarityFrame = true,
    bool showAuraGlow = true,
    bool isSelected = false,
    bool animate = true,
    Duration? animationDuration,
    VoidCallback? onTap,
  }) {
    return SocialRewardIcon(
      key: key,
      type: SocialRewardType.mythicDaevaChest,
      rarity: rarity,
      size: size,
      customSize: customSize,
      countText: countText,
      showRarityFrame: showRarityFrame,
      showAuraGlow: showAuraGlow,
      isSelected: isSelected,
      animate: animate,
      animationDuration: animationDuration,
      onTap: onTap,
    );
  }

  /// Factory for Abyss Crystal.
  factory SocialRewardIcon.crystal({
    Key? key,
    SocialRewardRarity rarity = SocialRewardRarity.heroic,
    SocialRewardSize size = SocialRewardSize.medium,
    double? customSize,
    String? countText,
    bool showRarityFrame = true,
    bool showAuraGlow = true,
    bool isSelected = false,
    bool animate = true,
    Duration? animationDuration,
    VoidCallback? onTap,
  }) {
    return SocialRewardIcon(
      key: key,
      type: SocialRewardType.abyssCrystal,
      rarity: rarity,
      size: size,
      customSize: customSize,
      countText: countText,
      showRarityFrame: showRarityFrame,
      showAuraGlow: showAuraGlow,
      isSelected: isSelected,
      animate: animate,
      animationDuration: animationDuration,
      onTap: onTap,
    );
  }

  /// Factory for Ancient Enchantment Stone.
  factory SocialRewardIcon.stone({
    Key? key,
    SocialRewardRarity rarity = SocialRewardRarity.rare,
    SocialRewardSize size = SocialRewardSize.medium,
    double? customSize,
    String? countText,
    bool showRarityFrame = true,
    bool showAuraGlow = true,
    bool isSelected = false,
    bool animate = true,
    Duration? animationDuration,
    VoidCallback? onTap,
  }) {
    return SocialRewardIcon(
      key: key,
      type: SocialRewardType.ancientEnchantmentStone,
      rarity: rarity,
      size: size,
      customSize: customSize,
      countText: countText,
      showRarityFrame: showRarityFrame,
      showAuraGlow: showAuraGlow,
      isSelected: isSelected,
      animate: animate,
      animationDuration: animationDuration,
      onTap: onTap,
    );
  }

  /// Factory for Faction Honor Insignia.
  factory SocialRewardIcon.insignia({
    Key? key,
    SocialRewardRarity rarity = SocialRewardRarity.heroic,
    SocialRewardSize size = SocialRewardSize.medium,
    double? customSize,
    String? countText,
    bool showRarityFrame = true,
    bool showAuraGlow = true,
    bool isSelected = false,
    bool animate = true,
    Duration? animationDuration,
    VoidCallback? onTap,
  }) {
    return SocialRewardIcon(
      key: key,
      type: SocialRewardType.factionHonorInsignia,
      rarity: rarity,
      size: size,
      customSize: customSize,
      countText: countText,
      showRarityFrame: showRarityFrame,
      showAuraGlow: showAuraGlow,
      isSelected: isSelected,
      animate: animate,
      animationDuration: animationDuration,
      onTap: onTap,
    );
  }

  final SocialRewardType type;
  final SocialRewardRarity rarity;
  final SocialRewardSize size;
  final double? customSize;
  final String? countText;
  final bool showRarityFrame;
  final bool showAuraGlow;
  final bool isSelected;
  final bool animate;
  final Duration? animationDuration;
  final VoidCallback? onTap;

  double get dimension => customSize ?? size.dimension;

  /// Creates the corresponding [CustomPainter] delegate for this reward icon
  /// at a given animation [progress] [0.0 .. 1.0].
  ///
  /// Useful for canvas renderers, offline thumbnails, particle effects,
  /// or when rendering without an [AnimationController] ticker.
  CustomPainter createPainter({double progress = 0.0}) {
    final double glow = showAuraGlow ? 1.0 : 0.0;
    return switch (type) {
      SocialRewardType.celestialArchonWings => CelestialWingsPainter(
          progress: progress,
          glowIntensity: glow,
        ),
      SocialRewardType.mythicDaevaChest => DaevaChestPainter(
          progress: progress,
          glowIntensity: glow,
        ),
      SocialRewardType.abyssCrystal => AbyssCrystalPainter(
          progress: progress,
          variant: _crystalVariantForRarity(rarity),
          glowIntensity: glow,
        ),
      SocialRewardType.ancientEnchantmentStone => EnchantmentStonePainter(
          progress: progress,
          glowIntensity: glow,
        ),
      SocialRewardType.factionHonorInsignia => HonorInsigniaPainter(
          progress: progress,
          starCount: _starsForRarity(rarity),
          glowIntensity: glow,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final double dim = dimension;
    if (dim <= 0.0) return const SizedBox.shrink();

    final Color rarityCol = rarity.color;
    final double innerPadding = (dim * 0.08).clamp(2.0, 14.0);
    final double innerDim = (dim - (innerPadding * 2)).clamp(0.0, double.infinity);
    final double cornerRadius = (dim * 0.18).clamp(6.0, 16.0);
    final double innerCornerRadius = (cornerRadius - 1.0).clamp(4.0, 15.0);

    Widget illustration = _buildIllustration(innerDim);

    Widget card = Container(
      width: dim,
      height: dim,
      decoration: BoxDecoration(
        color: SocialThemeTokens.abyssCard,
        borderRadius: BorderRadius.circular(cornerRadius),
        border: showRarityFrame
            ? Border.all(
                color: isSelected ? Colors.white : rarityCol.withValues(alpha: 0.8),
                width: isSelected ? 2.0 : 1.2,
              )
            : null,
        boxShadow: [
          if (showAuraGlow)
            BoxShadow(
              color: rarityCol.withValues(alpha: isSelected ? 0.45 : 0.22),
              blurRadius: (dim * 0.15).clamp(4.0, 16.0),
              spreadRadius: isSelected ? 1.5 : 0.8,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerCornerRadius),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      rarityCol.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(innerPadding),
              child: SizedBox(
                width: innerDim,
                height: innerDim,
                child: Center(
                  child: illustration,
                ),
              ),
            ),
            if (countText != null)
              Positioned(
                right: (dim * 0.05).clamp(2.0, 6.0),
                bottom: (dim * 0.05).clamp(2.0, 6.0),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: (dim * 0.06).clamp(3.0, 6.0),
                    vertical: (dim * 0.02).clamp(1.0, 2.5),
                  ),
                  decoration: BoxDecoration(
                    color: SocialThemeTokens.abyssVoid.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(
                      color: rarityCol.withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    countText!,
                    style: TextStyle(
                      color: SocialThemeTokens.celestialGoldLight,
                      fontSize: (dim * 0.16).clamp(9.0, 13.0),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      card = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: card,
        ),
      );
    }

    return Semantics(
      button: onTap != null,
      selected: isSelected,
      label: '${rarity.name} ${type.displayName}${countText != null ? ', $countText' : ''}',
      child: card,
    );
  }

  Widget _buildIllustration(double dim) {
    if (!animate) {
      return CustomPaint(
        size: Size(dim, dim),
        painter: createPainter(progress: 0.0),
      );
    }

    return switch (type) {
      SocialRewardType.celestialArchonWings => CelestialArchonWingsWidget(
          size: dim,
          glowIntensity: showAuraGlow ? 1.0 : 0.0,
          duration: animationDuration ?? const Duration(seconds: 3),
        ),
      SocialRewardType.mythicDaevaChest => MythicDaevaChestWidget(
          size: dim,
          glowIntensity: showAuraGlow ? 1.0 : 0.0,
          duration: animationDuration ?? const Duration(seconds: 3),
        ),
      SocialRewardType.abyssCrystal => AbyssCrystalWidget(
          size: dim,
          variant: _crystalVariantForRarity(rarity),
          glowIntensity: showAuraGlow ? 1.0 : 0.0,
          duration: animationDuration ?? const Duration(seconds: 3),
        ),
      SocialRewardType.ancientEnchantmentStone => AncientEnchantmentStoneWidget(
          size: dim,
          glowIntensity: showAuraGlow ? 1.0 : 0.0,
          duration: animationDuration ?? const Duration(seconds: 4),
        ),
      SocialRewardType.factionHonorInsignia => FactionHonorInsigniaWidget(
          size: dim,
          starCount: _starsForRarity(rarity),
          glowIntensity: showAuraGlow ? 1.0 : 0.0,
          duration: animationDuration ?? const Duration(seconds: 3),
        ),
    };
  }

  CrystalColorVariant _crystalVariantForRarity(SocialRewardRarity r) {
    return switch (r) {
      SocialRewardRarity.common || SocialRewardRarity.uncommon => CrystalColorVariant.emerald,
      SocialRewardRarity.rare => CrystalColorVariant.abyssCyan,
      SocialRewardRarity.heroic => CrystalColorVariant.shadowAmethyst,
      SocialRewardRarity.fabled => CrystalColorVariant.dragonRuby,
      SocialRewardRarity.mythic || SocialRewardRarity.ancient => CrystalColorVariant.celestialDiamond,
    };
  }

  int _starsForRarity(SocialRewardRarity r) {
    return switch (r) {
      SocialRewardRarity.common => 1,
      SocialRewardRarity.uncommon => 2,
      SocialRewardRarity.rare => 3,
      SocialRewardRarity.heroic => 4,
      SocialRewardRarity.fabled || SocialRewardRarity.mythic || SocialRewardRarity.ancient => 5,
    };
  }
}
