import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../inventory/widgets/aion_rarity_glow.dart';
import 'crafting_particle_burst.dart';

Future<void> showCraftingResultModal({
  required BuildContext context,
  required String itemName,
  required String itemId,
  required String rarity,
  required int quantity,
  int? xpReward,
  bool isFailed = false,
  bool isCritical = false,
  VoidCallback? onCraftAgain,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Üretim Sonucu',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: <Widget>[
            // Frosted dark acrylic backdrop
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                behavior: HitTestBehavior.opaque,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
            Center(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: CraftingResultModal(
                      itemName: itemName,
                      itemId: itemId,
                      rarity: rarity,
                      quantity: quantity,
                      xpReward: xpReward,
                      isFailed: isFailed,
                      isCritical: isCritical,
                      onClose: () => Navigator.of(dialogContext).pop(),
                      onCraftAgain: onCraftAgain != null
                          ? () {
                              Navigator.of(dialogContext).pop();
                              onCraftAgain();
                            }
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
    transitionBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.82, end: 1.0).animate(curved),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}

/// 2027 Aion 2 Mobile Ornate Dark Fantasy Crafting Result Modal
class CraftingResultModal extends StatelessWidget {
  const CraftingResultModal({
    super.key,
    required this.itemName,
    required this.itemId,
    required this.rarity,
    required this.quantity,
    this.xpReward,
    this.isFailed = false,
    this.isCritical = false,
    required this.onClose,
    this.onCraftAgain,
  });

  final String itemName;
  final String itemId;
  final String rarity;
  final int quantity;
  final int? xpReward;
  final bool isFailed;
  final bool isCritical;
  final VoidCallback onClose;
  final VoidCallback? onCraftAgain;

  @override
  Widget build(BuildContext context) {
    final AionRarityTier tier = isCritical
        ? AionRarityTier.archon
        : AionRarityTier.fromString(rarity);
    final Color accentColor = isFailed ? AppColors.mysticRuby : tier.primaryColor;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF1B2338).withValues(alpha: 0.98),
            const Color(0xFF0F1322).withValues(alpha: 0.99),
          ],
        ),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.65),
          width: 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accentColor.withValues(alpha: isFailed ? 0.3 : 0.4),
            blurRadius: 32,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Header badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFailed
                        ? AppColors.mysticRuby.withValues(alpha: 0.2)
                        : AppColors.liquidGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFailed
                          ? AppColors.mysticRuby.withValues(alpha: 0.6)
                          : AppColors.liquidGold.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        isFailed
                            ? Icons.error_outline_rounded
                            : Icons.auto_awesome_rounded,
                        size: 14,
                        color: isFailed ? AppColors.mysticRuby : AppColors.liquidGold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isFailed
                            ? 'DÖVME BAŞARISIZ'
                            : (isCritical ? 'KRİTİK BAŞARI!' : 'DÖVME TAMAMLANDI'),
                        style: AppTextStyles.micro.copyWith(
                          color: isFailed ? AppColors.mysticRuby : AppColors.liquidGold,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Centerpiece: Forged Item Pedestal with Particle Burst Juice
                CraftingParticleBurst(
                  tier: isCritical ? AionRarityTier.archon : tier,
                  autoBurst: !isFailed,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      // Halo bloom
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              accentColor.withValues(alpha: 0.45),
                              accentColor.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                      AionRarityGlowBorder(
                        tier: isFailed ? AionRarityTier.common : tier,
                        borderRadius: 18,
                        borderWidth: 2,
                        hasActiveGlow: true,
                      child: Container(
                        width: 90,
                        height: 90,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            if (!isFailed && tier.hasSparkles)
                              Positioned.fill(
                                child: EnchantingSparklesOverlay(
                                  tier: tier,
                                  particleCount: 6,
                                ),
                              ),
                            ItemIconView(
                              iconValue: itemId,
                              itemId: itemId,
                              size: 74,
                              expand: true,
                              fallback: isFailed ? '💥' : '✨',
                            ),
                            // Quantity chip
                            if (!isFailed && quantity > 1)
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: 0.6),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    'x$quantity',
                                    style: AppTextStyles.micro.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                const SizedBox(height: 16),
                // Item Name
                Text(
                  itemName,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h3.copyWith(
                    color: isFailed ? AppColors.textPrimary : accentColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                // Rarity Tagline
                Text(
                  isFailed
                      ? 'Ocağın ateşi malzemeleri yuttu'
                      : '${tier.displayName} · x$quantity Adet Üretildi',
                  style: AppTextStyles.caption.copyWith(
                    color: isFailed ? AppColors.mutedTitanium : accentColor.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isFailed && (xpReward ?? 0) > 0) ...<Widget>[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.liquidGold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.liquidGold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.military_tech_rounded,
                          size: 16,
                          color: AppColors.liquidGold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+$xpReward Demircilik XP',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.liquidGold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                // Actions
                Row(
                  children: <Widget>[
                    if (onCraftAgain != null) ...<Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await AionHaptics.slotSelect();
                            onCraftAgain!();
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.liquidGold.withValues(alpha: 0.6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Yeniden Üret',
                            style: AppTextStyles.captionBold.copyWith(
                              color: AppColors.liquidGold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () async {
                          await AionHaptics.equipSuccess();
                          onClose();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: isFailed
                              ? AppColors.darkObsidian
                              : const Color(0xFFD97706),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isFailed
                                  ? Colors.white12
                                  : AppColors.liquidGold.withValues(alpha: 0.8),
                            ),
                          ),
                          elevation: isFailed ? 0 : 4,
                        ),
                        child: Text(
                          isFailed ? 'Kapat' : 'Harika! Envantere Al',
                          style: AppTextStyles.captionBold.copyWith(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Close Icon top right
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}
