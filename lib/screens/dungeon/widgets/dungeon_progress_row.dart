import 'package:flutter/material.dart';

import '../../../models/dungeon_model.dart';

class DungeonProgressRow extends StatelessWidget {
  const DungeonProgressRow({
    super.key,
    required this.dungeon,
    required this.accent,
  });

  final DungeonData dungeon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final DungeonPlayerStats? stats = dungeon.playerStats;
    if (stats == null || stats.totalAttempts <= 0) {
      if (dungeon.isBoss) {
        return _bossChip('Bugün 0/${dungeon.dailyBossLimit} boss');
      }
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: <Widget>[
        _chip('${stats.totalAttempts} koşu', accent),
        _chip('%${stats.successRatePercent} başarı', accent),
        if (stats.hasFirstClear) _chip('İlk geçiş ✓', const Color(0xFFFBBF24)),
        if (stats.runsSinceBestRarity > 0)
          _chip('Son epic+: ${stats.runsSinceBestRarity} koşu', const Color(0xFFA855F7)),
        if (dungeon.isBoss)
          _bossChip(
            'Bugün ${stats.todayBossAttempts}/${dungeon.dailyBossLimit} boss',
          ),
      ],
    );
  }

  Widget _bossChip(String label) {
    return _chip(label, const Color(0xFFEF4444));
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: 0.95),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
