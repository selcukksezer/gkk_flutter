import 'package:flutter/material.dart';

import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'guild_war_design.dart';

class AttackLogTile extends StatelessWidget {
  const AttackLogTile({
    super.key,
    required this.log,
    this.myGuildId,
  });

  final GuildWarAttackLog log;
  final String? myGuildId;

  bool get _weWon => myGuildId != null && log.attackerGuildId == myGuildId && log.success;

  bool get _weLost =>
      myGuildId != null && log.defenderGuildId == myGuildId && !log.success;

  String _timeAgo(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inHours < 1) return '${diff.inMinutes}dk önce';
    if (diff.inDays < 1) return '${diff.inHours}sa önce';
    return '${diff.inDays}g önce';
  }

  @override
  Widget build(BuildContext context) {
    final Color resultColor = log.success ? WarPalette.neon : WarPalette.ruby;
    final String resultLabel = log.success ? 'Başarılı' : 'Başarısız';

    Color accent = WarPalette.obsidian;
    if (_weWon) accent = WarPalette.neon;
    if (_weLost) accent = WarPalette.ruby;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: WarNeonCard(
        accent: accent,
        glow: _weWon || _weLost,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    log.territoryName ?? 'Bölge',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                WarStatusPill(label: resultLabel, color: resultColor),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '⚔ ${log.attackerGuildName ?? '?'} → 🛡 ${log.defenderGuildName ?? 'Sahipsiz'}',
              style: const TextStyle(color: WarPalette.titanium, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
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
      ),
    );
  }
}
