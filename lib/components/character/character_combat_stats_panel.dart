import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../layout/game_screen_background.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';

/// Combat stats — compact grid, AppColors + AppTextStyles (tasarım skill).
class CharacterCombatStatsPanel extends StatelessWidget {
  const CharacterCombatStatsPanel({
    super.key,
    required this.power,
    required this.maxHealth,
    required this.attack,
    required this.defense,
    required this.luck,
    required this.pvpWinRate,
    required     this.pvpRating,
    this.initiallyExpanded = true,
    this.highlightPowerAnchor = false,
  });

  final String power;
  final String maxHealth;
  final String attack;
  final String defense;
  final String luck;
  final String pvpWinRate;
  final String pvpRating;
  final bool initiallyExpanded;
  final bool highlightPowerAnchor;

  static const _iconBase = 'assets/ui/character_status_bar/';
  static const double _iconSize = 52;

  @override
  Widget build(BuildContext context) {
    final List<_CombatStatDef> stats = <_CombatStatDef>[
      _CombatStatDef(
        label: 'Güç',
        value: power,
        icon: '${_iconBase}gucicon.png',
      ),
      _CombatStatDef(
        label: 'HP',
        value: maxHealth,
        icon: '${_iconBase}canicon.png',
      ),
      _CombatStatDef(
        label: 'Saldırı',
        value: attack,
        icon: '${_iconBase}saldira_icon.png',
      ),
      _CombatStatDef(
        label: 'Savunma',
        value: defense,
        icon: '${_iconBase}defansicon.png',
      ),
      _CombatStatDef(
        label: 'Şans',
        value: luck,
        icon: '${_iconBase}sansicon.png',
      ),
      _CombatStatDef(
        label: 'PvP Kazanma',
        value: pvpWinRate,
        icon: '${_iconBase}pvpicon.png',
      ),
      _CombatStatDef(
        label: 'Rating',
        value: pvpRating,
        icon: '${_iconBase}ratingicon.png',
      ),
    ];

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: initiallyExpanded,
        title: Text(
          'Gelişim & Savaş İstatistikleri',
          style: AppTextStyles.titleBold.copyWith(
            color: AppColors.textPrimary,
            letterSpacing: 0.15,
          ),
        ),
        iconColor: AppColors.liquidGold,
        collapsedIconColor: AppColors.mutedTitanium,
        children: <Widget>[
          Container(
            height: 1.5,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.liquidGold,
                  AppColors.warningSolar.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          GameFixedGrid(
            crossAxisCount: 4,
            spacing: 4,
            itemCount: stats.length,
            itemBuilder: (BuildContext context, int index) {
              final Widget tile =
                  _CombatStatTile(stat: stats[index], iconSize: _iconSize);
              if (highlightPowerAnchor && index == 0) {
                return TutorialAnchorScope(
                  id: TutorialAnchorId.characterPowerStat,
                  child: tile,
                );
              }
              return tile;
            },
          ),
        ],
      ),
    );
  }
}

class _CombatStatDef {
  const _CombatStatDef({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final String icon;
}

class _CombatStatTile extends StatelessWidget {
  const _CombatStatTile({required this.stat, required this.iconSize});

  final _CombatStatDef stat;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${stat.label}: ${stat.value}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              stat.icon,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, Object error, StackTrace? stack) => Icon(
                Icons.bolt,
                size: iconSize * 0.5,
                color: AppColors.mutedTitanium,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: double.infinity,
              child: Text(
                stat.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Text(
                stat.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.micro.copyWith(
                  color: AppColors.mutedTitanium,
                  height: 1.05,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
