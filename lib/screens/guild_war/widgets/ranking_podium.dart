import 'package:flutter/material.dart';

import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import 'guild_war_design.dart';

class RankingPodium extends StatelessWidget {
  const RankingPodium({
    super.key,
    required this.rankings,
    this.highlightGuildName,
  });

  final List<GuildWarRanking> rankings;
  final String? highlightGuildName;

  @override
  Widget build(BuildContext context) {
    if (rankings.isEmpty) {
      return const WarEmptyTab(
        icon: '🏅',
        message: 'Henüz sıralama verisi yok. Sezon başladığında loncalar burada listelenecek.',
      );
    }

    final top3 = rankings.take(3).toList();
    final rest = rankings.length > 3 ? rankings.sublist(3) : <GuildWarRanking>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const WarSectionHeader(
          title: 'Şöhret Sıralaması',
          subtitle: 'Sezon puanlarına göre en güçlü loncalar',
          accent: WarPalette.gold,
        ),
        if (top3.isNotEmpty)
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (top3.length > 1)
                  Expanded(child: _PodiumSlot(entry: top3[1], medal: '🥈', barFlex: 4)),
                Expanded(child: _PodiumSlot(entry: top3[0], medal: '🥇', barFlex: 5)),
                if (top3.length > 2)
                  Expanded(child: _PodiumSlot(entry: top3[2], medal: '🥉', barFlex: 3)),
              ],
            ),
          ),
        ...rest.map(
          (GuildWarRanking r) => _RankingRow(
            entry: r,
            isHighlighted: highlightGuildName != null && r.guildName == highlightGuildName,
          ),
        ),
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.entry,
    required this.medal,
    required this.barFlex,
  });

  final GuildWarRanking entry;
  final String medal;
  final int barFlex;

  Color get _glowColor {
    if (medal == '🥇') return WarPalette.gold;
    if (medal == '🥈') return WarPalette.titanium;
    return WarPalette.coral;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(medal, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            entry.guildName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '${entry.points} puan',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _glowColor),
          ),
          const SizedBox(height: 6),
          Expanded(
            flex: barFlex,
            child: WarNeonCard(
              accent: _glowColor,
              glow: medal == '🥇',
              padding: EdgeInsets.zero,
              radius: 12,
              child: Center(
                child: Text(
                  '#${entry.rank}',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _glowColor.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.entry,
    this.isHighlighted = false,
  });

  final GuildWarRanking entry;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return WarNeonCard(
      accent: isHighlighted ? WarPalette.gold : WarPalette.obsidian,
      glow: isHighlighted,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: WarPalette.obsidian.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isHighlighted ? WarPalette.gold.withValues(alpha: 0.5) : AppColors.borderDefault,
              ),
            ),
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: isHighlighted ? WarPalette.gold : WarPalette.titanium,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.guildName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${entry.wins}G · ${entry.losses}M',
                  style: const TextStyle(color: WarPalette.titanium, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            '${entry.points}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: isHighlighted ? WarPalette.gold : AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
