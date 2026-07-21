import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

typedef EnhUpgradeTableFormatter = String Function(int amount);
typedef EnhRiskLabelFn = String Function(int level);
typedef EnhRiskColorFn = Color Function(int level);
typedef EnhSuccessColorFn = Color Function(int chance);

const TextStyle _kTableText = TextStyle(
  decoration: TextDecoration.none,
  decorationThickness: 0,
);

/// Güçlendirme tablosu — opak panel, dot grid / çizgi artefakt yok.
Future<void> showEnhancementUpgradeTableDialog({
  required BuildContext context,
  required int currentLevel,
  required Map<int, int> upgradeCosts,
  required Map<int, int> upgradeChances,
  required EnhUpgradeTableFormatter formatGold,
  required EnhRiskLabelFn riskLabel,
  required EnhRiskColorFn riskColor,
  required EnhSuccessColorFn successColor,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: AppColors.carbonVoid.withValues(alpha: 0.92),
    builder: (BuildContext ctx) {
      return DefaultTextStyle(
        style: _kTableText,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: _EnhancementUpgradeTableSheet(
            currentLevel: currentLevel,
            upgradeCosts: upgradeCosts,
            upgradeChances: upgradeChances,
            formatGold: formatGold,
            riskLabel: riskLabel,
            riskColor: riskColor,
            successColor: successColor,
          ),
        ),
      );
    },
  );
}

class _EnhancementUpgradeTableSheet extends StatelessWidget {
  const _EnhancementUpgradeTableSheet({
    required this.currentLevel,
    required this.upgradeCosts,
    required this.upgradeChances,
    required this.formatGold,
    required this.riskLabel,
    required this.riskColor,
    required this.successColor,
  });

  final int currentLevel;
  final Map<int, int> upgradeCosts;
  final Map<int, int> upgradeChances;
  final EnhUpgradeTableFormatter formatGold;
  final EnhRiskLabelFn riskLabel;
  final EnhRiskColorFn riskColor;
  final EnhSuccessColorFn successColor;

  static const Color _rowBg = Color(0xFF121824);
  static const Color _rowActiveBg = Color(0xFF1A2030);
  static const Color _headerBg = Color(0xFF0E131D);

  TextStyle _cellStyle({
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w600,
    TextAlign align = TextAlign.start,
  }) {
    return _kTableText.copyWith(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.25,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF101622),
      elevation: 16,
      shadowColor: Colors.black,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 360,
        height: 520,
        decoration: const BoxDecoration(
          border: Border.fromBorderSide(BorderSide(color: Color(0x33FFD700))),
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
              child: Row(
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFF252115),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.auto_graph_rounded, size: 18, color: AppColors.liquidGold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Güçlendirme Tablosu',
                          style: _cellStyle(size: 15, color: AppColors.textPrimary, weight: FontWeight.w800),
                        ),
                        Text(
                          'Maliyet · şans · risk',
                          style: _cellStyle(size: 11, color: AppColors.mutedTitanium, weight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.mutedTitanium),
                    tooltip: 'Kapat',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _headerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(
                    children: <Widget>[
                      Expanded(flex: 2, child: Text('Seviye', style: _cellStyle(size: 10, color: AppColors.mutedTitanium, weight: FontWeight.w700))),
                      Expanded(flex: 3, child: Text('Maliyet', style: _cellStyle(size: 10, color: AppColors.mutedTitanium, weight: FontWeight.w700))),
                      Expanded(flex: 2, child: Text('Şans', textAlign: TextAlign.center, style: _cellStyle(size: 10, color: AppColors.mutedTitanium, weight: FontWeight.w700, align: TextAlign.center))),
                      Expanded(flex: 3, child: Text('Risk', textAlign: TextAlign.end, style: _cellStyle(size: 10, color: AppColors.mutedTitanium, weight: FontWeight.w700, align: TextAlign.end))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                itemCount: 11,
                itemBuilder: (BuildContext context, int index) {
                  final int level = index;
                  final bool active = level == currentLevel;
                  final int chance = upgradeChances[level] ?? 0;
                  final Color riskC = riskColor(level);
                  final Color chanceC = successColor(chance);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: active ? _rowActiveBg : _rowBg,
                        borderRadius: BorderRadius.circular(8),
                        border: active
                            ? const Border(
                                left: BorderSide(color: AppColors.liquidGold, width: 3),
                              )
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: <Widget>[
                                  Text(
                                    '+$level',
                                    style: _cellStyle(
                                      size: 12,
                                      color: active ? AppColors.liquidGold : AppColors.textPrimary,
                                      weight: FontWeight.w800,
                                    ),
                                  ),
                                  if (active) ...<Widget>[
                                    const SizedBox(width: 6),
                                    Text(
                                      '· şimdi',
                                      style: _cellStyle(
                                        size: 9,
                                        color: AppColors.liquidGold,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                formatGold(upgradeCosts[level] ?? 0),
                                style: _cellStyle(size: 12, color: const Color(0xFFE8C547), weight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '$chance%',
                                textAlign: TextAlign.center,
                                style: _cellStyle(size: 12, color: chanceC, weight: FontWeight.w700, align: TextAlign.center),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: riskC.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Text(
                                      riskLabel(level),
                                      style: _cellStyle(size: 9, color: riskC, weight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C2433),
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Kapat', style: _cellStyle(size: 13, color: AppColors.textPrimary, weight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
