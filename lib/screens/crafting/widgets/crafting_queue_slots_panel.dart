import 'package:flutter/material.dart';

import '../../../components/common/gkk_card.dart';
import '../../../components/common/universal_game_dialog.dart';
import '../../../core/utils/crafting_queue_slots.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

Future<bool> showCraftQueueSlotUnlockDialog(
  BuildContext context, {
  required int nextSlot,
  required int gemCost,
  required int currentSlots,
}) async {
  final bool? confirmed = await UniversalGameDialog.show(
    context,
    title: 'Üretim Slotu Aç',
    message:
        'Slot $nextSlot kalıcı olarak açılacak.\n\n'
        '$gemCost ELMAS harcanır '
        '($currentSlots → $nextSlot / $craftingQueueMaxSlots).\n\n'
        'Bu genişletme geri alınamaz.',
    confirmLabel: '$gemCost ELMAS · Aç',
    cancelLabel: 'Vazgeç',
    accent: AppColors.accentPurple,
  );
  return confirmed == true;
}

class CraftingQueueSlotsPanel extends StatelessWidget {
  const CraftingQueueSlotsPanel({
    super.key,
    required this.unlockedSlots,
    required this.queueLength,
    required this.playerGems,
    required this.isExpanding,
    required this.onRequestUnlock,
  });

  final int unlockedSlots;
  final int queueLength;
  final double playerGems;
  final bool isExpanding;
  final VoidCallback onRequestUnlock;

  @override
  Widget build(BuildContext context) {
    final int? nextCost = nextCraftQueueSlotUnlockCost(unlockedSlots);
    final int nextSlot = unlockedSlots + 1;
    final bool canAffordNext = nextCost != null && playerGems >= nextCost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.grid_view_rounded, size: 14, color: AppColors.liquidGold.withValues(alpha: 0.9)),
            const SizedBox(width: 6),
            Text(
              'KUYRUK SLOTLARI',
              style: AppTextStyles.micro.copyWith(
                color: AppColors.liquidGold.withValues(alpha: 0.85),
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              '$unlockedSlots / $craftingQueueMaxSlots açık',
              style: AppTextStyles.micro.copyWith(color: AppColors.mutedTitanium),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: List<Widget>.generate(craftingQueueMaxSlots, (int index) {
            final int slotNumber = index + 1;
            final bool isUnlocked = slotNumber <= unlockedSlots;
            final bool isOccupied = isUnlocked && slotNumber <= queueLength;
            final bool isNextUnlock = !isUnlocked && slotNumber == nextSlot && nextCost != null;
            final bool isFutureLocked = !isUnlocked && !isNextUnlock;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: index == 0 ? 0 : 5),
                child: _CraftQueueSlotCell(
                  slotNumber: slotNumber,
                  isUnlocked: isUnlocked,
                  isOccupied: isOccupied,
                  isNextUnlock: isNextUnlock,
                  isFutureLocked: isFutureLocked,
                  unlockCost: isNextUnlock ? nextCost : null,
                  canAffordUnlock: canAffordNext,
                  isExpanding: isExpanding,
                  onUnlock: onRequestUnlock,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _CraftQueueSlotCell extends StatelessWidget {
  const _CraftQueueSlotCell({
    required this.slotNumber,
    required this.isUnlocked,
    required this.isOccupied,
    required this.isNextUnlock,
    required this.isFutureLocked,
    required this.canAffordUnlock,
    required this.isExpanding,
    required this.onUnlock,
    this.unlockCost,
  });

  final int slotNumber;
  final bool isUnlocked;
  final bool isOccupied;
  final bool isNextUnlock;
  final bool isFutureLocked;
  final int? unlockCost;
  final bool canAffordUnlock;
  final bool isExpanding;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    if (isNextUnlock) {
      return GkkCard(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        accentColor: AppColors.accentPurple,
        borderGlow: canAffordUnlock,
        onTap: isExpanding ? null : onUnlock,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.accentPurple.withValues(alpha: 0.22),
            AppColors.carbonVoid.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: AppSpacing.radiusMd,
        child: SizedBox(
          height: 88,
          child: isExpanding
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentPurple,
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.lock_open_rounded,
                      size: 18,
                      color: AppColors.accentPurple.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Slot $slotNumber',
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unlockCost != null ? '$unlockCost ELMAS' : '—',
                      style: AppTextStyles.captionBold.copyWith(
                        fontSize: 10,
                        color: canAffordUnlock ? AppColors.liquidGold : AppColors.mysticRuby,
                      ),
                    ),
                    Text(
                      'Slot Aç',
                      style: AppTextStyles.micro.copyWith(
                        color: canAffordUnlock
                            ? AppColors.accentPurple
                            : AppColors.mutedTitanium,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    if (isFutureLocked) {
      return GkkCard(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        accentColor: AppColors.mutedTitanium,
        borderRadius: AppSpacing.radiusMd,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.carbonVoid.withValues(alpha: 0.72),
            AppColors.darkObsidian.withValues(alpha: 0.92),
          ],
        ),
        child: SizedBox(
          height: 88,
          child: Opacity(
            opacity: 0.55,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.mutedTitanium),
                const SizedBox(height: 4),
                Text(
                  'Slot $slotNumber',
                  style: AppTextStyles.micro.copyWith(color: AppColors.textTertiary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kilitli',
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Color accent = isOccupied ? AppColors.toxicNeon : AppColors.liquidGold;
    return GkkCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      accentColor: accent,
      borderGlow: isOccupied,
      borderRadius: AppSpacing.radiusMd,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          isOccupied
              ? AppColors.toxicNeon.withValues(alpha: 0.12)
              : AppColors.spaceNavy.withValues(alpha: 0.82),
          AppColors.darkObsidian.withValues(alpha: 0.9),
        ],
      ),
      child: SizedBox(
        height: 88,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              isOccupied ? Icons.hourglass_top_rounded : Icons.check_circle_outline_rounded,
              size: 18,
              color: accent,
            ),
            const SizedBox(height: 4),
            Text(
              'Slot $slotNumber',
              style: AppTextStyles.micro.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isOccupied ? 'Dolu' : 'Boş',
              style: AppTextStyles.captionBold.copyWith(
                fontSize: 10,
                color: isOccupied ? AppColors.toxicNeon : AppColors.mutedTitanium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
