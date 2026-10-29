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
          // Epic Aion-2 Abyss Core Warzone & Lord of War Cinematic Header
          Container(
            height: 165,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: WarPalette.ruby.withValues(alpha: 0.65),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: WarPalette.ruby.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 1.2),
              child: Stack(
                children: <Widget>[
                  // 1. Authentic Abyss Core Warzone illustration
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/backgrounds/dungeons/bg_abyss_core_warzone.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                  // 2. Procedural fortress HUD overlay at subtle blending opacity
                  const Positioned.fill(
                    child: Opacity(
                      opacity: 0.35,
                      child: FortressSiegeIllustration(
                        fortressName: 'Uçurum Bastionu',
                        faction: FactionType.elyos,
                        shieldIntegrity: 0.92,
                        isUnderSiege: true,
                        height: 165,
                        showTitle: false,
                      ),
                    ),
                  ),
                  // 3. Cinematic Vignette
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0.40),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.88),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 4. Top-left battle status tag
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                        border: Border.all(color: WarPalette.ruby.withValues(alpha: 0.7)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: WarPalette.ruby,
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(color: WarPalette.ruby, blurRadius: 6),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'UÇURUM BASTİONU • KUŞATMA DEVAM EDİYOR',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 5. Lord of War Zikel Portrait Inset
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: WarPalette.gold, width: 1.5),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: WarPalette.gold.withValues(alpha: 0.35),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/portraits/npcs/lord_zikel.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.military_tech_rounded,
                                color: WarPalette.gold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const <Widget>[
                            Text(
                              'SAVAŞ LORDU ZİKEL',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Uçurum Yüksek Komutanlığı',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: WarPalette.titanium,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 6. Shield integrity status pill
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                        border: Border.all(color: WarPalette.gold.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'KALKAN: %92',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: WarPalette.gold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

