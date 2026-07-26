import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../models/guild_war_model.dart';
import 'guild_war_design.dart';

class TerritoryGuildDuelPanel extends StatelessWidget {
  const TerritoryGuildDuelPanel({
    super.key,
    required this.attacker,
    this.defender,
  });

  final GuildWarGuildBrief attacker;
  final GuildWarGuildBrief? defender;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _guildCard('Saldıran', attacker, WarPalette.ruby)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('VS', style: TextStyle(color: WarPalette.gold, fontWeight: FontWeight.w900)),
        ),
        Expanded(
          child: _guildCard(
            'Savunan',
            defender ?? const GuildWarGuildBrief(id: '', name: 'Sahipsiz'),
            WarPalette.fuchsia,
          ),
        ),
      ],
    );
  }

  Widget _guildCard(String role, GuildWarGuildBrief guild, Color accent) {
    return WarNeonCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            role.toUpperCase(),
            style: GoogleFonts.urbanist(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: WarPalette.titanium,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            guild.displayLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.urbanist(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
