import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../models/crafting_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../inventory/widgets/aion_rarity_glow.dart';

/// Ornate dark fantasy material socket widget for forge crafting screens.
class OrnateForgeMaterialSlot extends StatelessWidget {
  const OrnateForgeMaterialSlot({
    super.key,
    required this.ingredient,
    required this.owned,
    required this.requiredCount,
    this.inBank = 0,
    this.onTap,
  });

  final CraftIngredient ingredient;
  final int owned;
  final int requiredCount;
  final int inBank;
  final VoidCallback? onTap;

  bool get isSatisfied => owned >= requiredCount;
  bool get hasBankSurplus => !isSatisfied && inBank > 0;

  @override
  Widget build(BuildContext context) {
    final bool satisfied = isSatisfied;
    final bool bankHint = hasBankSurplus;

    final Color statusColor = satisfied
        ? const Color(0xFF10B981) // Emerald satisfied
        : (bankHint
            ? AppColors.liquidGold // Amber warning (can withdraw from bank)
            : const Color(0xFFEF4444)); // Ruby shortage

    final Color slotBg = satisfied
        ? const Color(0xFF0D231A).withValues(alpha: 0.85)
        : (bankHint
            ? const Color(0xFF241C0E).withValues(alpha: 0.85)
            : const Color(0xFF260D12).withValues(alpha: 0.85));

    final String displayName = ingredient.itemName.trim().isNotEmpty
        ? ingredient.itemName
        : (ingredient.itemId.isNotEmpty ? ingredient.itemId : 'Malzeme');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await AionHaptics.slotSelect();
          if (onTap != null) {
            onTap!();
          } else {
            _showMaterialDetailsSheet(context);
          }
        },
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: slotBg,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(
              color: statusColor.withValues(alpha: satisfied ? 0.45 : 0.7),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: statusColor.withValues(alpha: satisfied ? 0.12 : 0.22),
                blurRadius: 8,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Icon socket with ornate runic border
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    ItemIconView(
                      iconValue: ingredient.itemId,
                      itemId: ingredient.itemId,
                      size: 32,
                      expand: true,
                    ),
                    if (satisfied)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 8,
                            color: Colors.black,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              // Material Name
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.micro.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 3),
              // Quantity comparison: owned / required
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$owned / $requiredCount',
                  style: AppTextStyles.micro.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 9.5,
                  ),
                ),
              ),
              if (bankHint) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  'Banka: $inBank',
                  maxLines: 1,
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.liquidGold,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMaterialDetailsSheet(BuildContext context) {
    final String displayName = ingredient.itemName.trim().isNotEmpty
        ? ingredient.itemName
        : ingredient.itemId;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF121826),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: AppColors.liquidGold.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.liquidGold.withValues(alpha: 0.5),
                      ),
                    ),
                    child: ItemIconView(
                      iconValue: ingredient.itemId,
                      itemId: ingredient.itemId,
                      size: 38,
                      expand: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          displayName,
                          style: AppTextStyles.bodyBold.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'ID: ${ingredient.itemId}',
                          style: AppTextStyles.micro.copyWith(
                            color: AppColors.mutedTitanium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.mutedTitanium),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B101D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: <Widget>[
                    _buildRow('Gerekli Miktar:', '$requiredCount adet'),
                    const SizedBox(height: 8),
                    _buildRow(
                      'Çantadakiler:',
                      '$owned adet',
                      valueColor: isSatisfied ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                    const SizedBox(height: 8),
                    _buildRow(
                      'Bankadaki Stok:',
                      '$inBank adet',
                      valueColor: inBank > 0 ? AppColors.liquidGold : AppColors.mutedTitanium,
                    ),
                  ],
                ),
              ),
              if (!isSatisfied && inBank > 0) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.liquidGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.liquidGold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.account_balance_rounded, size: 16, color: AppColors.liquidGold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bu malzemeden bankada $inBank adet bulunuyor. Bankadan çekerek üretime devam edebilirsiniz.',
                          style: AppTextStyles.micro.copyWith(
                            color: AppColors.goldLight,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.mutedTitanium),
        ),
        Text(
          value,
          style: AppTextStyles.captionBold.copyWith(
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
