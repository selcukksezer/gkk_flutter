import 'package:flutter/material.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'defense_power_bar.dart';
import 'guild_war_design.dart';

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

  static const List<String> _icons = <String>['🏰', '🌾', '🐉', '⚓', '🔥', '🏔'];

  @override
  Widget build(BuildContext context) {
    if (territories.isEmpty) {
      return const WarEmptyTab(
        icon: '🗺',
        message: 'Haritada henüz bölge yok. Sezon ilerledikçe bölgeler açılacak.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const WarSectionHeader(
          title: 'Savaş Haritası',
          subtitle: 'Bölgeye dokunarak detayları gör',
          accent: WarPalette.neon,
        ),
        const SizedBox(height: AppSpacing.sm),
        GameFixedGrid(
          crossAxisCount: 2,
          spacing: 10,
          itemCount: territories.length,
          itemBuilder: (BuildContext context, int index) {
            final TerritoryData t = territories[index];
            final bool isOwner = t.ownerGuildId == playerGuildId;
            return _MapTile(
              territory: t,
              icon: _icons[index % _icons.length],
              isOwner: isOwner,
              onTap: () => onTerritoryTap(t),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _LegendDot(color: WarPalette.gold, label: 'Senin loncan'),
            const SizedBox(width: 16),
            _LegendDot(color: WarPalette.titanium, label: 'Diğer'),
            const SizedBox(width: 16),
            _LegendDot(color: WarPalette.coral, label: 'Sahipsiz'),
          ],
        ),
      ],
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

  Color get _accent {
    if (isOwner) return WarPalette.gold;
    if (territory.isUnclaimed) return WarPalette.coral;
    return WarPalette.ruby;
  }

  @override
  Widget build(BuildContext context) {
    return WarPressable(
      onTap: onTap,
      child: WarHeroBanner(
        accent: _accent,
        child: SizedBox(
          height: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(icon, style: const TextStyle(fontSize: 26)),
                  const Spacer(),
                  if (isOwner)
                    const WarStatusPill(label: 'Sen', color: WarPalette.gold),
                ],
              ),
              const Spacer(),
              Text(
                territory.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                territory.isUnclaimed ? 'Sahipsiz' : (territory.ownerGuildName ?? '—'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: WarPalette.titanium, fontSize: 10),
              ),
              const SizedBox(height: 6),
              DefensePowerBar(
                current: territory.defensePower,
                max: territory.baseDefensePower,
                height: 4,
                showLabel: false,
              ),
            ],
          ),
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
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: WarPalette.titanium, fontSize: 10)),
      ],
    );
  }
}
