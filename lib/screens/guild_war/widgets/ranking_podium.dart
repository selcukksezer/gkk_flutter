import 'package:flutter/material.dart';

import '../../../components/common/gkk_card.dart';
import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

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
      return const SizedBox.shrink();
    }

    final top3 = rankings.take(3).toList();
    final rest = rankings.length > 3 ? rankings.sublist(3) : <GuildWarRanking>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (top3.isNotEmpty) ...[
          SizedBox(
            height: 188,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (top3.length > 1)
                  Expanded(child: _PodiumSlot(entry: top3[1], medal: '🥈', barFlex: 4)),
                Expanded(child: _PodiumSlot(entry: top3[0], medal: '🥇', barFlex: 5)),
                if (top3.length > 2)
                  Expanded(child: _PodiumSlot(entry: top3[2], medal: '🥉', barFlex: 3)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
        ],
        ...rest.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _RankingRow(
              entry: r,
              isHighlighted: highlightGuildName != null && r.guildName == highlightGuildName,
            ),
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
    if (medal == '🥇') return AppColors.gold;
    if (medal == '🥈') return const Color(0xFFC0C0C0);
    return const Color(0xFFCD7F32);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(medal, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(
            entry.guildName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '${entry.points} puan',
            style: TextStyle(fontSize: 9, color: _glowColor),
          ),
          const SizedBox(height: 4),
          Expanded(
            flex: barFlex,
            child: GkkCard(
              borderGlow: true,
              accentColor: _glowColor,
              padding: EdgeInsets.zero,
              child: Center(
                child: Text(
                  '#${entry.rank}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _glowColor.withValues(alpha: 0.8),
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
    return GkkCard(
      accentColor: isHighlighted ? AppColors.gold : null,
      borderGlow: isHighlighted,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Text(
              '${entry.rank}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.guildName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${entry.wins}G / ${entry.losses}M',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            '${entry.points}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
