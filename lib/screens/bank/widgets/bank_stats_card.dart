import 'package:flutter/material.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../theme/app_colors.dart';
import 'bank_design.dart';

class BankStatsCard extends StatelessWidget {
  const BankStatsCard({
    super.key,
    required this.totalSlots,
    required this.usedSlots,
    required this.maxSlots,
    required this.expanding,
    required this.actionInProgress,
    required this.onExpand,
  });

  final int totalSlots;
  final int usedSlots;
  final int maxSlots;
  final bool expanding;
  final bool actionInProgress;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final int freeSlots = (totalSlots - usedSlots).clamp(0, maxSlots);
    final double fillPct = totalSlots > 0
        ? (usedSlots / totalSlots).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: DottedPanel(
        borderColor: BankDesign.gold.withValues(alpha: 0.22),
        child: Column(
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(
                  Icons.account_balance_rounded,
                  color: BankDesign.gold,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'KASA',
                  style: TextStyle(
                    color: BankDesign.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _BankStatTile(label: 'Toplam', value: '$totalSlots'),
                _BankStatTile(label: 'Kullanılan', value: '$usedSlots'),
                _BankStatTile(label: 'Boş', value: '$freeSlots'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Doluluk ${(fillPct * 100).round()}%',
                        style: const TextStyle(
                          color: BankDesign.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fillPct,
                          backgroundColor: AppColors.darkObsidian,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            BankDesign.gold,
                          ),
                          minHeight: 7,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (totalSlots < maxSlots && fillPct >= 0.8)
                  FilledButton(
                    onPressed: (expanding || actionInProgress) ? null : onExpand,
                    style: FilledButton.styleFrom(
                      backgroundColor: BankDesign.gold,
                      foregroundColor: AppColors.carbonVoid,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: expanding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.carbonVoid,
                            ),
                          )
                        : Text(
                            'Genişlet ${bankExpandCost(totalSlots)} 💎',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  )
                else
                  const Text(
                    'Max slot',
                    style: TextStyle(color: BankDesign.muted, fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BankStatTile extends StatelessWidget {
  const _BankStatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.darkObsidian.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: BankDesign.gold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: BankDesign.muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
