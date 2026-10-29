import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../inventory/widgets/aion_rarity_glow.dart';
import 'crafting_particle_burst.dart';
import 'critical_craft_fanfare.dart';

/// Stat row item displayed in the success dialog.
class CraftingStatReward {
  const CraftingStatReward({
    required this.label,
    required this.value,
    this.icon = Icons.star_rounded,
    this.color = AppColors.liquidGold,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

/// Rich animated success dialog for crafting completion.
///
/// Features:
/// - Smooth backdrop blur & elastic zoom entrance.
/// - Centered item showcase with Aion 2 rarity glow and tier-reactive palette.
/// - Automatic particle burst explosion upon display.
/// - Critical craft integration with rotating sunburst rays and celebratory fanfare.
/// - Rewards panel detailing XP, quantities, and bonus attributes.
/// - Liquid Gold primary button with haptic feedback.
class CraftingSuccessDialog extends StatefulWidget {
  const CraftingSuccessDialog({
    super.key,
    required this.itemName,
    required this.itemIcon,
    this.itemId,
    this.rarity = 'common',
    this.quantity = 1,
    this.itemType,
    this.xpReward,
    this.isCritical = false,
    this.criticalBonusTitle = 'Kusursuz İşçilik!',
    this.stats = const <CraftingStatReward>[],
    this.onClaim,
    this.claimButtonLabel = 'Koleksiyona Ekle',
  });

  final String itemName;
  final String itemIcon;
  final String? itemId;
  final String rarity;
  final int quantity;
  final String? itemType;
  final int? xpReward;
  final bool isCritical;
  final String criticalBonusTitle;
  final List<CraftingStatReward> stats;
  final VoidCallback? onClaim;
  final String claimButtonLabel;

  @override
  State<CraftingSuccessDialog> createState() => _CraftingSuccessDialogState();
}

class _CraftingSuccessDialogState extends State<CraftingSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  final CraftingParticleBurstController _burstController =
      CraftingParticleBurstController();

  late final AionRarityTier _tier;

  @override
  void initState() {
    super.initState();

    _tier = AionRarityTier.fromString(widget.rarity);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();

    // Trigger haptic & particle burst
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AionHaptics.craftSuccess();
      _burstController.burst(
        tier: widget.isCritical ? AionRarityTier.archon : _tier,
        count: widget.isCritical ? 56 : 38,
      );
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    AionHaptics.equipSuccess();
    widget.onClaim?.call();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = _tier.primaryColor;

    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            elevation: 0,
            child: CraftingParticleBurst(
              controller: _burstController,
              tier: widget.isCritical ? AionRarityTier.archon : _tier,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.carbonVoid.withValues(alpha: 0.95),
                      AppColors.spaceNavy.withValues(alpha: 0.98),
                      AppColors.carbonVoid.withValues(alpha: 0.95),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: widget.isCritical
                        ? AppColors.liquidGold
                        : rarityColor.withValues(alpha: 0.65),
                    width: 1.6,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (widget.isCritical ? AppColors.liquidGold : rarityColor)
                          .withValues(alpha: 0.28),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          // Critical Banner header or Standard Crafting Header
                          if (widget.isCritical) ...<Widget>[
                            _CriticalHeaderBadge(title: widget.criticalBonusTitle),
                            const SizedBox(height: 16),
                          ] else ...<Widget>[
                            _StandardHeaderBadge(rarityColor: rarityColor),
                            const SizedBox(height: 16),
                          ],

                          // Crafted Item Showcase Slot
                          _ItemShowcase(
                            itemIcon: widget.itemIcon,
                            itemId: widget.itemId,
                            tier: _tier,
                            quantity: widget.quantity,
                            isCritical: widget.isCritical,
                          ),

                          const SizedBox(height: 16),

                          // Item Name
                          Text(
                            widget.itemName,
                            style: AppTextStyles.h2.copyWith(
                              color: rarityColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              shadows: <Shadow>[
                                Shadow(
                                  color: rarityColor.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),

                          if (widget.itemType != null) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              widget.itemType!.toUpperCase(),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.mutedTitanium,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          // Stats & XP Rewards Grid
                          _RewardsPanel(
                            xpReward: widget.xpReward,
                            stats: widget.stats,
                            isCritical: widget.isCritical,
                          ),

                          const SizedBox(height: 22),

                          // Claim Button
                          _ClaimButton(
                            label: widget.claimButtonLabel,
                            onPressed: _handleConfirm,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CriticalHeaderBadge extends StatelessWidget {
  const _CriticalHeaderBadge({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.liquidGold.withValues(alpha: 0.25),
            AppColors.accentCyan.withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.8),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.auto_awesome, size: 16, color: AppColors.liquidGold),
          const SizedBox(width: 8),
          Text(
            'KRİTİK BAŞARI! · $title',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.liquidGold,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _StandardHeaderBadge extends StatelessWidget {
  const _StandardHeaderBadge({required this.rarityColor});

  final Color rarityColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkObsidian.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rarityColor.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle_outline_rounded, size: 16, color: rarityColor),
          const SizedBox(width: 8),
          Text(
            'ÜRETİM TAMAMLANDI',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemShowcase extends StatelessWidget {
  const _ItemShowcase({
    required this.itemIcon,
    required this.itemId,
    required this.tier,
    required this.quantity,
    required this.isCritical,
  });

  final String itemIcon;
  final String? itemId;
  final AionRarityTier tier;
  final int quantity;
  final bool isCritical;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          // Radiant backing glow
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: (isCritical ? AppColors.liquidGold : tier.primaryColor)
                      .withValues(alpha: 0.4),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),

          // Glowing Rarity Border Frame
          AionRarityGlowBorder(
            tier: isCritical ? AionRarityTier.archon : tier,
            borderRadius: 16,
            borderWidth: 2.0,
            isSelected: true,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.bgCardElevated,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: ItemIconView(
                  iconValue: itemIcon,
                  itemId: itemId,
                  size: 46,
                ),
              ),
            ),
          ),

          // Quantity badge pill (if > 1)
          if (quantity > 1)
            Positioned(
              right: -6,
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[AppColors.liquidGold, AppColors.goldLight],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'x$quantity',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.bgDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RewardsPanel extends StatelessWidget {
  const _RewardsPanel({
    required this.xpReward,
    required this.stats,
    required this.isCritical,
  });

  final int? xpReward;
  final List<CraftingStatReward> stats;
  final bool isCritical;

  @override
  Widget build(BuildContext context) {
    if (xpReward == null && stats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkObsidian.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.borderFaint,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          if (xpReward != null)
            Row(
              children: <Widget>[
                const Icon(Icons.star_rounded, size: 18, color: AppColors.liquidGold),
                const SizedBox(width: 6),
                Text(
                  '+$xpReward DP',
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.liquidGold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          for (final CraftingStatReward stat in stats)
            Row(
              children: <Widget>[
                Icon(stat.icon, size: 18, color: stat.color),
                const SizedBox(width: 6),
                Text(
                  '${stat.label}: ${stat.value}',
                  style: AppTextStyles.captionBold.copyWith(
                    color: stat.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ClaimButton extends StatelessWidget {
  const _ClaimButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[AppColors.liquidGold, AppColors.goldLight],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.liquidGold.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            label,
            style: AppTextStyles.dialogButton.copyWith(
              color: AppColors.bgDeep,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper method to display the animated crafting success dialog.
Future<bool?> showCraftingSuccessDialog(
  BuildContext context, {
  required String itemName,
  required String itemIcon,
  String? itemId,
  String rarity = 'common',
  int quantity = 1,
  String? itemType,
  int? xpReward,
  bool isCritical = false,
  String criticalBonusTitle = 'Kusursuz İşçilik!',
  List<CraftingStatReward> stats = const <CraftingStatReward>[],
  VoidCallback? onClaim,
  String claimButtonLabel = 'Koleksiyona Ekle',
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'CraftingSuccessDialog',
    barrierColor: AppColors.carbonVoid.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (
      BuildContext ctx,
      Animation<double> anim,
      Animation<double> secondary,
    ) {
      return CraftingSuccessDialog(
        itemName: itemName,
        itemIcon: itemIcon,
        itemId: itemId,
        rarity: rarity,
        quantity: quantity,
        itemType: itemType,
        xpReward: xpReward,
        isCritical: isCritical,
        criticalBonusTitle: criticalBonusTitle,
        stats: stats,
        onClaim: onClaim,
        claimButtonLabel: claimButtonLabel,
      );
    },
  );
}
