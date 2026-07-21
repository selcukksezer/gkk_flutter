import 'package:flutter/material.dart';

import '../../../providers/mekan_provider.dart';
import 'mekan_design.dart';

class MekanArenaFighterCard extends StatelessWidget {
  const MekanArenaFighterCard({
    super.key,
    required this.opponent,
    required this.enabled,
    required this.onFight,
  });

  final ArenaOpponent opponent;
  final bool enabled;
  final VoidCallback onFight;

  @override
  Widget build(BuildContext context) {
    return NeonPanel(
      accent: MekanPalette.amethyst,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  MekanPalette.amethyst.withValues(alpha: 0.4),
                  MekanPalette.amethyst.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: MekanPalette.amethyst.withValues(alpha: 0.6)),
            ),
            alignment: Alignment.center,
            child: Text(
              opponent.username.isNotEmpty ? opponent.username[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: MekanPalette.textHi),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  opponent.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: MekanPalette.textHi,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    GlowChip(
                      icon: Icons.military_tech_rounded,
                      label: 'Sv ${opponent.level}',
                      color: MekanPalette.aqua,
                    ),
                    const SizedBox(width: 6),
                    GlowChip(
                      icon: Icons.emoji_events_rounded,
                      label: '${opponent.pvpRating}',
                      color: MekanPalette.gold,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          NeonButton(
            label: 'Dövüş',
            icon: Icons.sports_mma_rounded,
            accent: MekanPalette.ruby,
            expand: false,
            onPressed: enabled ? onFight : null,
          ),
        ],
      ),
    );
  }
}
