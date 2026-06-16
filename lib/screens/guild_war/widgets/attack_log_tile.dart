import 'package:flutter/material.dart';

import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

class AttackLogTile extends StatelessWidget {
  const AttackLogTile({
    super.key,
    required this.log,
    this.myGuildId,
  });

  final GuildWarAttackLog log;
  final String? myGuildId;

  bool get _weWon =>
      myGuildId != null && log.attackerGuildId == myGuildId && log.success;

  bool get _weLost =>
      myGuildId != null &&
      log.defenderGuildId == myGuildId &&
      !log.success;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inHours < 1) return '${diff.inMinutes}dk önce';
    if (diff.inDays < 1) return '${diff.inHours}sa önce';
    return '${diff.inDays}g önce';
  }

  @override
  Widget build(BuildContext context) {
    final resultColor = log.success ? AppColors.success : AppColors.danger;
    final resultLabel = log.success ? 'Başarılı' : 'Başarısız';

    Color? borderColor;
    if (_weWon) borderColor = AppColors.success;
    if (_weLost) borderColor = AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: borderColor ?? AppColors.borderDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  log.territoryName ?? 'Bölge',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: resultColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  resultLabel,
                  style: TextStyle(
                    color: resultColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '⚔ ${log.attackerGuildName ?? '?'} → 🛡 ${log.defenderGuildName ?? 'Sahipsiz'}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${log.attackPower} vs ${log.defensePower} · +${log.pointsGained} puan',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
              ),
              Text(
                _timeAgo(log.createdAt),
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
