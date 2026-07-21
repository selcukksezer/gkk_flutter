import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../horse_race_provider.dart';
import 'horse_race_design.dart';

class HorseRecentWinnersPanel extends StatefulWidget {
  const HorseRecentWinnersPanel({super.key, required this.winners});

  final List<HorseRaceRecentWinner> winners;

  @override
  State<HorseRecentWinnersPanel> createState() =>
      _HorseRecentWinnersPanelState();
}

class _HorseRecentWinnersPanelState extends State<HorseRecentWinnersPanel> {
  static const int _previewCount = 5;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final List<HorseRaceRecentWinner> all = widget.winners;
    if (all.isEmpty) return const SizedBox.shrink();

    final bool canExpand = all.length > _previewCount;
    final List<HorseRaceRecentWinner> visible = (_showAll || !canExpand)
        ? all.take(30).toList(growable: false)
        : all.take(_previewCount).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HorseRaceSectionHeader(
          title: 'Son Kazananlar',
          subtitle: _showAll
              ? '${visible.length} kayıt'
              : 'Son $_previewCount tur',
          accent: HorseRaceDesign.gold,
        ),
        const SizedBox(height: 10),
        HorseRaceNeonPanel(
          accent: HorseRaceDesign.gold,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < visible.length; i++) ...<Widget>[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                HorseRaceFadeSlide(
                  index: i,
                  child: _WinnerRow(winner: visible[i], rank: i + 1),
                ),
              ],
            ],
          ),
        ),
        if (canExpand) ...<Widget>[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: HorseRacePressable(
              onTap: () => setState(() => _showAll = !_showAll),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: HorseRaceDesign.gold.withValues(alpha: 0.35),
                  ),
                  color: HorseRaceDesign.gold.withValues(alpha: 0.08),
                ),
                child: Text(
                  _showAll ? 'Daha az göster' : 'Tümünü gör',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: HorseRaceDesign.gold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WinnerRow extends StatelessWidget {
  const _WinnerRow({required this.winner, required this.rank});

  final HorseRaceRecentWinner winner;
  final int rank;

  Color get _rankColor => switch (rank) {
    1 => HorseRaceDesign.gold,
    2 => HorseRaceDesign.cyan,
    3 => HorseRaceDesign.fuchsia,
    _ => HorseRaceDesign.titanium,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: <Widget>[
          Text(
            '#$rank',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _rankColor,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _rankColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _rankColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              winner.winnerEmoji,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              winner.winnerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Icon(
            Icons.emoji_events_outlined,
            size: 16,
            color: _rankColor.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }
}
