import 'package:flutter/material.dart';

import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'defense_power_bar.dart';

class TerritoryMapView extends StatelessWidget {
  const TerritoryMapView({
    super.key,
    required this.territories,
    required this.playerGuildId,
    required this.onTerritoryTap,
  });

  final List<TerritoryData> territories;
  final String? playerGuildId;
  final ValueChanged<TerritoryData> onTerritoryTap;

  static const List<String> _icons = ['🏰', '🌾', '🐉', '⚓'];

  @override
  Widget build(BuildContext context) {
    if (territories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemCount: territories.length,
              itemBuilder: (context, index) {
                final t = territories[index];
                final isOwner = t.ownerGuildId == playerGuildId;
                return _MapTile(
                  territory: t,
                  icon: _icons[index % _icons.length],
                  isOwner: isOwner,
                  onTap: () => onTerritoryTap(t),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: AppColors.gold, label: 'Senin loncan'),
                const SizedBox(width: 16),
                _LegendDot(color: AppColors.borderDefault, label: 'Diğer'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapTile extends StatelessWidget {
  const _MapTile({
    required this.territory,
    required this.icon,
    required this.isOwner,
    required this.onTap,
  });

  final TerritoryData territory;
  final String icon;
  final bool isOwner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isOwner
                ? [const Color(0xFF2A2010), const Color(0xFF1A2238)]
                : [AppColors.bgCard, AppColors.bgSurface],
          ),
          border: Border.all(
            color: isOwner ? AppColors.gold.withValues(alpha: 0.6) : AppColors.borderDefault,
            width: isOwner ? 2 : 1,
          ),
          boxShadow: isOwner
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const Spacer(),
            Text(
              territory.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              territory.isUnclaimed ? 'Sahipsiz' : (territory.ownerGuildName ?? '—'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
            const SizedBox(height: 6),
            DefensePowerBar(
              current: territory.defensePower,
              max: territory.baseDefensePower,
              height: 5,
              showLabel: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
      ],
    );
  }
}
