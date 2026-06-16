import 'package:flutter/material.dart';

import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

class GuildWarSeasonHeader extends StatelessWidget {
  const GuildWarSeasonHeader({
    super.key,
    required this.season,
    this.myRank,
    this.myPoints,
  });

  final GuildWarSeason? season;
  final int? myRank;
  final int? myPoints;

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
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1520), Color(0xFF1A2238), Color(0xFF2A2010)],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚔', style: TextStyle(fontSize: 28)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sezon ${s?.season ?? '?'} · Hafta ${s?.week ?? '?'}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Kalan: ${_countdown(s?.endAt)}',
                      style: const TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (myRank != null || myPoints != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (myRank != null)
                  _StatChip(
                    icon: '🏅',
                    label: '#$myRank Sıra',
                  ),
                if (myRank != null && myPoints != null)
                  const SizedBox(width: AppSpacing.sm),
                if (myPoints != null)
                  _StatChip(
                    icon: '⭐',
                    label: '$myPoints Puan',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(
        '$icon $label',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
    );
  }
}
