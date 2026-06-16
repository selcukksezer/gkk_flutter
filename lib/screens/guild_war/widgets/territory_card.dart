import 'package:flutter/material.dart';

import '../../../components/common/gkk_card.dart';
import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'defense_power_bar.dart';

class TerritoryCard extends StatelessWidget {
  const TerritoryCard({
    super.key,
    required this.territory,
    required this.isOwner,
    required this.onTap,
    this.onAttack,
    this.onAddDefense,
  });

  final TerritoryData territory;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback? onAttack;
  final VoidCallback? onAddDefense;

  @override
  Widget build(BuildContext context) {
    return GkkCard(
      accentColor: isOwner ? AppColors.gold : null,
      borderGlow: isOwner,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  territory.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isOwner)
                const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '🏰 ${territory.isUnclaimed ? 'Sahipsiz' : territory.ownerGuildName}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          DefensePowerBar(
            current: territory.defensePower,
            max: territory.baseDefensePower,
          ),
          if (territory.tradeIncome > 0) ...[
            const SizedBox(height: 4),
            Text(
              '💰 Trade: ${territory.tradeIncome}/gün',
              style: const TextStyle(color: AppColors.accentTeal, fontSize: 11),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '🎁 ${territory.reward}',
            style: const TextStyle(color: AppColors.gold, fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (!isOwner && onAttack != null)
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAttack,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Saldır'),
                  ),
                ),
              if (isOwner && onAddDefense != null)
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAddDefense,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Savunma Ekle'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
