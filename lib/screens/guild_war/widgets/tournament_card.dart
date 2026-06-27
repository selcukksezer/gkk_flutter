import 'package:flutter/material.dart';

import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'guild_war_design.dart';

class TournamentCard extends StatelessWidget {
  const TournamentCard({
    super.key,
    required this.tournament,
    required this.onJoin,
    required this.onDetail,
  });

  final GuildWarTournament tournament;
  final VoidCallback? onJoin;
  final VoidCallback onDetail;

  Color get _statusColor {
    if (tournament.isActive) return WarPalette.neon;
    if (tournament.isUpcoming) return WarPalette.gold;
    return WarPalette.titanium;
  }

  String get _statusLabel {
    if (tournament.isActive) return 'Aktif';
    if (tournament.isUpcoming) return 'Yaklaşan';
    return 'Bitti';
  }

  double? get _progress {
    final start = tournament.startAt;
    final end = tournament.endAt;
    if (start == null || end == null || !end.isAfter(start)) return null;
    final now = DateTime.now();
    if (now.isBefore(start)) return 0;
    if (now.isAfter(end)) return 1;
    return now.difference(start).inMilliseconds / end.difference(start).inMilliseconds;
  }

  @override
  Widget build(BuildContext context) {
    return WarNeonCard(
      accent: tournament.isActive ? WarPalette.fuchsia : WarPalette.gold,
      glow: tournament.isActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      WarPalette.gold.withValues(alpha: 0.25),
                      WarPalette.fuchsia.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: WarPalette.gold.withValues(alpha: 0.35)),
                ),
                child: const Text('🏆', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tournament.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              WarStatusPill(
                label: _statusLabel,
                color: _statusColor,
                pulse: tournament.isActive,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              WarStatChip(
                emoji: '👥',
                label: '${tournament.guildCount} Lonca',
                accent: WarPalette.titanium,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ödül: ${tournament.prizePool}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: WarPalette.gold, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (tournament.isActive && _progress != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: _progress!.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: WarPalette.obsidian,
                color: WarPalette.gold,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: WarOutlineButton(
                  label: 'Detay',
                  onPressed: onDetail,
                  expand: true,
                  icon: Icons.open_in_new_rounded,
                ),
              ),
              if (tournament.isActive && onJoin != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: WarGoldButton(label: 'Katıl', onPressed: onJoin, expand: true),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
