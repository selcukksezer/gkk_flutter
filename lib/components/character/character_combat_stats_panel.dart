import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/utils/reputation_tier.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/player_health_bar.dart';
import '../layout/game_screen_background.dart';

/// Combat stats — compact grid, AppColors + AppTextStyles (tasarım skill).
class CharacterCombatStatsPanel extends StatelessWidget {
  const CharacterCombatStatsPanel({
    super.key,
    required this.power,
    required this.health,
    required this.maxHealth,
    required this.attack,
    required this.defense,
    required this.luck,
    this.luckSubtitle,
    required this.pvpWinRate,
    required this.pvpRating,
    this.reputation,
    this.initiallyExpanded = true,
    this.highlightPowerAnchor = false,
  });

  final String power;
  final int health;
  final int maxHealth;
  final String attack;
  final String defense;
  final String luck;
  /// Optional second line under Şans (e.g. base luck after Faz 1 unbake).
  final String? luckSubtitle;
  final String pvpWinRate;
  final String pvpRating;
  final int? reputation;
  final bool initiallyExpanded;
  final bool highlightPowerAnchor;

  String _fmtCompact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

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
        label: 'Can Kapasitesi',
        value: _fmtCompact(maxHealth),
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
        subtitle: luckSubtitle,
        subtitleColor: AppColors.toxicNeon,
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
      if (reputation != null) _reputationStat(context, reputation!),
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
          if (maxHealth > 0) ...<Widget>[
            const SizedBox(height: 10),
            PlayerHealthBar(health: health, maxHealth: maxHealth, height: 9),
          ],
          GameFixedGrid(
            crossAxisCount: 4,
            spacing: 4,
            itemCount: stats.length,
            itemBuilder: (BuildContext context, int index) {
              final Widget tile = _CombatStatTile(
                stat: stats[index],
                iconSize: _iconSize,
              );
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

  _CombatStatDef _reputationStat(BuildContext context, int reputation) {
    final int rep = reputation.clamp(0, 999999999);
    final ReputationTier tier = reputationTierFor(rep);
    final ReputationTierProgress tierProgress = reputationTierProgressFor(rep);
    final int progressPct =
        (tierProgress.progress.clamp(0.0, 1.0) * 100).round();
    return _CombatStatDef(
      label: 'İtibar',
      value: _fmtCompact(rep),
      iconData: Icons.military_tech_rounded,
      iconColor: AppColors.liquidGold,
      subtitle: '${tier.title} · %$progressPct',
      subtitleColor: tier.color,
      onTap: () => context.push(AppRoutes.reputation),
    );
  }
}

class _CombatStatDef {
  const _CombatStatDef({
    required this.label,
    required this.value,
    this.icon,
    this.iconData,
    this.iconColor,
    this.subtitle,
    this.subtitleColor,
    this.onTap,
  });

  final String label;
  final String value;
  final String? icon;
  final IconData? iconData;
  final Color? iconColor;
  final String? subtitle;
  final Color? subtitleColor;
  final VoidCallback? onTap;
}

class _CombatStatTile extends StatelessWidget {
  const _CombatStatTile({required this.stat, required this.iconSize});

  final _CombatStatDef stat;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (stat.icon != null)
            Image.asset(
              stat.icon!,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, Object error, StackTrace? stack) => Icon(
                Icons.bolt,
                size: iconSize * 0.5,
                color: AppColors.mutedTitanium,
              ),
            )
          else
            Icon(
              stat.iconData ?? Icons.bolt,
              size: iconSize * 0.46,
              color: stat.iconColor ?? AppColors.mutedTitanium,
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
          if (stat.subtitle != null) ...<Widget>[
            const SizedBox(height: 1),
            SizedBox(
              width: double.infinity,
              child: Text(
                stat.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.micro.copyWith(
                  color: stat.subtitleColor ?? AppColors.liquidGold,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  fontSize: 8,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      label: '${stat.label}: ${stat.value}',
      button: stat.onTap != null,
      child: stat.onTap == null
          ? content
          : GestureDetector(
              onTap: stat.onTap,
              behavior: HitTestBehavior.opaque,
              child: content,
            ),
    );
  }
}
