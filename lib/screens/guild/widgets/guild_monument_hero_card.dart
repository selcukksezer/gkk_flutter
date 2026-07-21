import 'package:flutter/material.dart';

import '../../../models/guild_model.dart';
import '../../../repositories/guild_monument_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import 'guild_monument_ui.dart';

class GuildMonumentHeroCard extends StatelessWidget {
  const GuildMonumentHeroCard({
    super.key,
    required this.level,
    required this.memberCount,
    required this.upgradeProgress,
    required this.canUpgrade,
    required this.upgrading,
    required this.onDonate,
    required this.onUpgrade,
  });

  final int level;
  final int memberCount;
  final MonumentUpgradeProgress? upgradeProgress;
  final bool canUpgrade;
  final bool upgrading;
  final VoidCallback onDonate;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return monumentPanel(
      borderColor: AppColors.cyberFuchsia.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.cyberFuchsia.withValues(alpha: 0.28),
                      AppColors.liquidGold.withValues(alpha: 0.12),
                    ],
                  ),
                  border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.45), width: 1.5),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: AppColors.liquidGold.withValues(alpha: 0.18), blurRadius: 14),
                  ],
                ),
                child: const Text('🏛️', style: TextStyle(fontSize: 34)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Seviye $level Anıt', style: AppTextStyles.h2.copyWith(fontSize: 18)),
                    if (upgradeProgress != null) ...<Widget>[
                      const SizedBox(height: 8),
                      monumentUpgradeProgressCompact(progress: upgradeProgress!),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Lonca üyelerinin güçlerini birleştirerek yükselttiği kutsal yapı.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.mutedTitanium),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    monumentPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      borderColor: AppColors.mutedTitanium.withValues(alpha: 0.16),
                      child: Row(
                        children: <Widget>[
                          Text(
                            '$memberCount / 50 Aktif Üye',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                          ),
                          const Spacer(),
                          Text(
                            guildSizeLabel(memberCount),
                            style: const TextStyle(
                              color: AppColors.liquidGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          monumentGoldButton(
            label: 'Bağış Yap',
            icon: Icons.volunteer_activism_rounded,
            onPressed: onDonate,
          ),
          if (canUpgrade) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            monumentAccentButton(
              label: upgrading ? 'Yükseltiliyor…' : 'Anıtı Yükselt',
              onPressed: upgrading ? null : onUpgrade,
            ),
          ],
        ],
      ),
    );
  }
}
