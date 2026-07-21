import 'package:flutter/material.dart';

import '../../../providers/mekan_provider.dart';
import 'mekan_design.dart';
import 'mekan_theme.dart';

class MekanArenaRankRow extends StatelessWidget {
  const MekanArenaRankRow({super.key, required this.row, required this.isMe});

  final ArenaRankRow row;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final Color rankColor = switch (row.rank) {
      1 => MekanPalette.gold,
      2 => const Color(0xFFC0C7D4),
      3 => MekanPalette.coral,
      _ => MekanPalette.textLow,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? MekanPalette.aqua.withValues(alpha: 0.12) : MekanPalette.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? MekanPalette.aqua : Colors.white.withValues(alpha: 0.06),
          width: isMe ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 32,
            child: Text(
              '#${row.rank}',
              style: TextStyle(
                fontSize: row.rank <= 3 ? 16 : 13,
                fontWeight: FontWeight.w900,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isMe ? '${row.username} (Sen)' : row.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: MekanPalette.textHi),
                ),
                Text(
                  '${row.wins}G / ${row.losses}M',
                  style: const TextStyle(fontSize: 11, color: MekanPalette.textLow, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.emoji_events_rounded, size: 14, color: MekanPalette.gold),
                  const SizedBox(width: 3),
                  Text(
                    '${row.pvpRating}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: MekanPalette.gold),
                  ),
                ],
              ),
              if (row.weeklyReward > 0)
                Text(
                  'Ödül: ${formatMekanGold(row.weeklyReward)}',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: MekanPalette.neon),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
