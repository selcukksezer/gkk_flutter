import 'package:flutter/material.dart';

import '../../../models/guild_war_model.dart';
import 'guild_war_siege_3d_viewport.dart';

/// Dark fantasy 3D Fortress Bastion card for TerritoryDetailScreen and Tactical Map:
/// Displays the genuine 3D fortress gate with destruction state, owner crest, and defenders.
class TerritoryFortress3DCard extends StatelessWidget {
  const TerritoryFortress3DCard({
    super.key,
    required this.territory,
    this.height = 240,
    this.interactive = true,
    this.onTap,
  });

  final TerritoryData territory;
  final double height;
  final bool interactive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final FactionType faction = territory.isUnclaimed
        ? FactionType.neutral
        : (territory.ownerGuildName?.toLowerCase().contains('elyos') == true
            ? FactionType.elyos
            : FactionType.asmodian);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GestureDetector(
          onTap: onTap,
          child: GuildWarSiege3DViewport(
            height: height,
            initialMode: SiegeViewportMode.fortressGate,
            defensePower: territory.defensePower,
            maxDefensePower: territory.baseDefensePower > 0
                ? territory.baseDefensePower
                : territory.defensePower,
            territoryName: territory.name,
            faction: faction,
            attackerPower: territory.attackGoldCost,
            showControls: true,
            showModeToggle: false,
            interactive: interactive,
          ),
        ),
      ],
    );
  }
}
