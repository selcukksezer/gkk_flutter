import 'package:flutter/material.dart';

import '../../../models/dungeon_siege_model.dart';
import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'defense_power_bar.dart';
import 'guild_war_design.dart';

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
    return WarNeonCard(
      accent: isOwner ? WarPalette.gold : WarPalette.ruby,
      glow: isOwner,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (isOwner ? WarPalette.gold : WarPalette.ruby).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (isOwner ? WarPalette.gold : WarPalette.ruby).withValues(alpha: 0.35),
                  ),
                ),
                child: Text(isOwner ? '⭐' : '🏰', style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      territory.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      territory.isUnclaimed ? 'Sahipsiz bölge' : (territory.ownerGuildName ?? '—'),
                      style: const TextStyle(color: WarPalette.titanium, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                WarStatusPill(label: 'Senin', color: WarPalette.gold),
              if (territory.isUnclaimed)
                WarStatusPill(label: 'Boş', color: WarPalette.coral),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DefensePowerBar(
            current: territory.displayDefensePower,
            max: territory.displayDefensePower > territory.baseDefensePower
                ? territory.displayDefensePower
                : territory.baseDefensePower,
            height: 10,
          ),
          if (territory.gemDefenseBoost > 0) ...<Widget>[
            const SizedBox(height: 6),
            WarStatChip(
              emoji: '💎',
              label: '+${territory.gemDefenseBoost} elmas savunma',
              accent: WarPalette.neon,
            ),
          ],
          if (territory.zoneNumber != null &&
              territory.displayDefensePower > 0 &&
              DungeonSiegeConfig.territoryDefenseSiegeBonusPct(territory.displayDefensePower) > 0) ...<Widget>[
            const SizedBox(height: 6),
            WarStatChip(
              emoji: '⚔',
              label:
                  'Kuşatma +${(DungeonSiegeConfig.territoryDefenseSiegeBonusPct(territory.displayDefensePower) * 100).round()}% (owner slot)',
              accent: WarPalette.gold,
            ),
          ],
          if (territory.tradeIncome > 0) ...<Widget>[
            const SizedBox(height: 6),
            WarStatChip(
              emoji: '💰',
              label: territory.tradeIncomeHourly > 0
                  ? '${territory.tradeIncome}/gün (~${territory.tradeIncomeHourly.round()}/saat)'
                  : '${territory.tradeIncome}/gün ticaret',
              accent: WarPalette.neon,
            ),
          ],
          if (territory.hasTerritoryLoot) ...<Widget>[
            const SizedBox(height: 6),
            WarStatChip(
              emoji: '📦',
              label: '${territory.lootItemName ?? territory.lootItemId} · ${territory.lootChanceLabel}',
              accent: WarPalette.gold,
            ),
          ] else if (territory.reward.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '🎁 ${territory.reward}',
              style: const TextStyle(color: WarPalette.gold, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (!isOwner && onAttack != null)
            WarAttackButton(onPressed: onAttack)
          else if (isOwner && onAddDefense != null)
            WarDefenseButton(onPressed: onAddDefense),
        ],
      ),
    );
  }
}
