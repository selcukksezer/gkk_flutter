import 'package:flutter/material.dart';

import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'faction_crest_painter.dart';
import 'fortress_siege_illustration.dart';
import 'guild_war_design.dart';

class GuildWarSeasonHeader extends StatelessWidget {
  const GuildWarSeasonHeader({
    super.key,
    required this.season,
    this.myRank,
    this.myPoints,
    this.guildName,
  });

  final GuildWarSeason? season;
  final int? myRank;
  final int? myPoints;
  final String? guildName;

  String _countdown(DateTime? endAt) {
    if (endAt == null) return '—';
    final diff = endAt.difference(DateTime.now());
    if (diff.isNegative) return 'Sezon bitti';
    if (diff.inDays > 0) return '${diff.inDays}g ${diff.inHours % 24}sa';
    if (diff.inHours > 0) return '${diff.inHours}sa ${diff.inMinutes % 60}dk';
    return '${diff.inMinutes}dk';
  }

  @override
  Widget build(BuildContext context) {
    final s = season;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // High-Res Aion-2 Fortress Siege Cinematic Header Illustration
          const FortressSiegeIllustration(
            fortressName: 'Uçurum Bastionu',
            faction: FactionType.elyos,
            shieldIntegrity: 0.92,
            isUnderSiege: true,
            height: 165,
            showTitle: false,
          ),
          const SizedBox(height: 8),
          WarHeroBanner(
            accent: WarPalette.fuchsia,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const GuildCustomCrestWidget(
                      symbol: GuildCrestSymbol.dragon,
                      primaryColor: WarPalette.gold,
                      secondaryColor: WarPalette.ruby,
                      frame: GuildHeraldicFrame.goldFiligree,
                      size: 46,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'LONCA SAVAŞI · HAREKAT ODASI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: WarPalette.titanium,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Sezon ${s?.season ?? '?'} · Hafta ${s?.week ?? '?'}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    WarStatusPill(
                      label: _countdown(s?.endAt),
                      color: WarPalette.gold,
                      pulse: s?.endAt != null && s!.endAt!.isAfter(DateTime.now()),
                    ),
                  ],
                ),
            if (guildName != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                guildName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: WarPalette.titanium,
                ),
              ),
            ],
            if (myRank != null || myPoints != null) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (myRank != null)
                    WarStatChip(emoji: '🏅', label: '#$myRank Sıra', accent: WarPalette.gold),
                  if (myPoints != null)
                    WarStatChip(emoji: '⭐', label: '$myPoints Puan', accent: WarPalette.neon),
                ],
              ),
            ],
          ],
        ),
      ),
        ],
      ),
    );
  }
}

