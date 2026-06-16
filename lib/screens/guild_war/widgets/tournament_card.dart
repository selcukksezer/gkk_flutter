import 'package:flutter/material.dart';

import '../../../components/common/gkk_card.dart';
import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

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
    if (tournament.isActive) return AppColors.success;
    if (tournament.isUpcoming) return AppColors.info;
    return AppColors.textDisabled;
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
    return GkkCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      accentColor: tournament.isActive ? AppColors.gold : null,
      borderGlow: tournament.isActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tournament.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusChip(color: _statusColor, label: _statusLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '👥 ${tournament.guildCount} Lonca',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            '🏆 Ödül: ${tournament.prizePool}',
            style: const TextStyle(color: AppColors.gold, fontSize: 12),
          ),
          if (tournament.isActive && _progress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: _progress!.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppColors.borderFaint,
                color: AppColors.gold,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDetail,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.borderDefault),
                  ),
                  child: const Text('Detay'),
                ),
              ),
              if (tournament.isActive && onJoin != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onJoin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgDeep,
                    ),
                    child: const Text('Katıl'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
