import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';

typedef EnhUpgradeTableFormatter = String Function(int amount);
typedef EnhRiskLabelFn = String Function(int level);
typedef EnhRiskColorFn = Color Function(int level);
typedef EnhSuccessColorFn = Color Function(int chance);

const TextStyle _kTableText = TextStyle(
  decoration: TextDecoration.none,
  decorationThickness: 0,
);

/// Aion 2 standardında Güçlendirme ve Olasılık Matrisi Diyaloğu (+1 ~ +15).
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
  HapticFeedback.lightImpact();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0xDE050811),
    builder: (BuildContext ctx) {
      return DefaultTextStyle(
        style: _kTableText,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: _Aion2UpgradeTableSheet(
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

class _Aion2UpgradeTableSheet extends StatefulWidget {
  const _Aion2UpgradeTableSheet({
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

  @override
  State<_Aion2UpgradeTableSheet> createState() =>
      _Aion2UpgradeTableSheetState();
}

class _Aion2UpgradeTableSheetState extends State<_Aion2UpgradeTableSheet> {
  int _selectedTierTab = 0; // 0: Tümü (+1~+15), 1: Tier 1, 2: Tier 2, 3: Tier 3
  bool _showCatalystGuide = false;

  static const List<String> _tabs = <String>[
    'Tümü (+1~+15)',
    'Güvenli (+1~+5)',
    'Riskli (+6~+10)',
    'Abyss (+11~+15)',
  ];

  // Aion 2 Fallback Oranları (+11 ~ +15 için gerçek MMORPG olasılıkları)
  int _resolveChance(int level) {
    if (widget.upgradeChances.containsKey(level)) {
      return widget.upgradeChances[level]!;
    }
    // +11..+15 Aion 2 resmi güçlendirme matrisi
    switch (level) {
      case 10:
        return 45;
      case 11:
        return 40;
      case 12:
        return 30;
      case 13:
        return 22;
      case 14:
        return 15;
      case 15:
        return 10;
      default:
        return math.max(5, 50 - (level * 3));
    }
  }

  // Aion 2 Fallback Maliyetleri (+11 ~ +15 için)
  int _resolveCost(int level) {
    if (widget.upgradeCosts.containsKey(level)) {
      return widget.upgradeCosts[level]!;
    }
    final int base10 = widget.upgradeCosts[9] ?? widget.upgradeCosts[10] ?? 25000;
    final int extraSteps = level - 10;
    return (base10 * math.pow(1.45, extraSteps)).toInt();
  }

  String _resolveRiskLabel(int level) {
    if (level < 10) {
      return widget.riskLabel(level);
    }
    if (level == 10) return 'Seviye -1 Düşer';
    if (level <= 12) return 'Sıfırlanma Riski (+10)';
    return 'Yıkım / Parçalanma Riski';
  }

  Color _resolveRiskColor(int level) {
    if (level < 10) {
      return widget.riskColor(level);
    }
    if (level == 10) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _catalystBonusHint(int level) {
    if (level < 5) return 'Rün: +5% Şans';
    if (level < 10) return 'Godstone: +15% Şans';
    return 'Kutsama Parşömeni: 2.0× Çarpan & Koruma';
  }

  String _penaltyDetail(int level) {
    if (level < 5) return 'Kayıp Yok (Güvenli)';
    if (level < 10) return 'Başarısızlıkta -1 Seviye Azalır';
    if (level < 13) return 'Başarısızlıkta +10 Seviyesine İner';
    return 'Eşya Parçalanabilir (Aegis Mührü Gerekir)';
  }

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

  List<int> _filteredLevels() {
    // 0..14 represents upgrade steps targeting +1 through +15
    const List<int> all = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];
    switch (_selectedTierTab) {
      case 1:
        return all.sublist(0, 5); // 0..4 (+1..+5)
      case 2:
        return all.sublist(5, 10); // 5..9 (+6..+10)
      case 3:
        return all.sublist(10, 15); // 10..14 (+11..+15)
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<int> visibleLevels = _filteredLevels();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 420,
        height: 620,
        decoration: BoxDecoration(
          color: const Color(0xFF0C111D),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFFFD166).withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0xFF04060B),
              blurRadius: 36,
              spreadRadius: 8,
              offset: Offset(0, 6),
            ),
            BoxShadow(
              color: Color(0x33FFB800),
              blurRadius: 24,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            // Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const RadialGradient(
                        colors: <Color>[Color(0xFF382A0E), Color(0xFF131A29)],
                        radius: 0.85,
                      ),
                      border: Border.all(
                        color: AppColors.liquidGold.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.liquidGold.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_graph_rounded,
                        size: 20,
                        color: AppColors.liquidGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Aion 2 Olasılık Matrisi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          '+1 ~ +15 Seviye Şansları · Katalizör & Ceza Detayları',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedTitanium.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.mutedTitanium,
                    ),
                    tooltip: 'Kapat',
                  ),
                ],
              ),
            ),

            // Tier Summary Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: <Widget>[
                  _buildTierSummaryBadge(
                    title: 'GÜVENLİ',
                    range: '+1 ~ +5',
                    rate: '%100~85',
                    color: const Color(0xFF22C55E),
                  ),
                  const SizedBox(width: 6),
                  _buildTierSummaryBadge(
                    title: 'RİSKLİ',
                    range: '+6 ~ +10',
                    rate: '%70~45',
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 6),
                  _buildTierSummaryBadge(
                    title: 'ABYSS',
                    range: '+11 ~ +15',
                    rate: '%40~10',
                    color: const Color(0xFFEF4444),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Tab Filter Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List<Widget>.generate(_tabs.length, (int index) {
                    final bool isSelected = _selectedTierTab == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTierTab = index);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF292211)
                                : const Color(0xFF131826),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.liquidGold
                                  : Colors.white.withValues(alpha: 0.08),
                              width: isSelected ? 1.3 : 1.0,
                            ),
                          ),
                          child: Text(
                            _tabs[index],
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.liquidGold
                                  : AppColors.mutedTitanium,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Table Column Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D17),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Hedef',
                        style: _cellStyle(
                          size: 10,
                          color: AppColors.mutedTitanium,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Maliyet',
                        style: _cellStyle(
                          size: 10,
                          color: AppColors.mutedTitanium,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Şans (Temel)',
                        textAlign: TextAlign.center,
                        style: _cellStyle(
                          size: 10,
                          color: AppColors.mutedTitanium,
                          weight: FontWeight.w800,
                          align: TextAlign.center,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Risk Durumu',
                        textAlign: TextAlign.end,
                        style: _cellStyle(
                          size: 10,
                          color: AppColors.mutedTitanium,
                          weight: FontWeight.w800,
                          align: TextAlign.end,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Scrollable Rows
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                itemCount: visibleLevels.length,
                itemBuilder: (BuildContext context, int index) {
                  final int stepLevel = visibleLevels[index];
                  final int targetLevel = stepLevel + 1;
                  final bool isCurrent = stepLevel == widget.currentLevel;
                  final int chance = _resolveChance(stepLevel);
                  final int cost = _resolveCost(stepLevel);
                  final Color riskC = _resolveRiskColor(stepLevel);
                  final Color chanceC = widget.successColor(chance);
                  final String rLabel = _resolveRiskLabel(stepLevel);
                  final String catalystHint = _catalystBonusHint(stepLevel);
                  final String penalty = _penaltyDetail(stepLevel);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFF1E1A11)
                            : const Color(0xFF111726),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.liquidGold
                              : Colors.white.withValues(alpha: 0.07),
                          width: isCurrent ? 1.5 : 1.0,
                        ),
                        boxShadow: isCurrent
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.liquidGold.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                // Target level indicator
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCurrent
                                              ? AppColors.liquidGold
                                              : const Color(0xFF192237),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '+$targetLevel',
                                          style: _cellStyle(
                                            size: 11.5,
                                            color: isCurrent
                                                ? Colors.black
                                                : AppColors.textPrimary,
                                            weight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      if (isCurrent) ...<Widget>[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.arrow_right_rounded,
                                          size: 16,
                                          color: AppColors.liquidGold,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Cost
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.monetization_on_rounded,
                                        size: 12,
                                        color: Color(0xFFFFD166),
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          widget.formatGold(cost),
                                          style: _cellStyle(
                                            size: 11,
                                            color: const Color(0xFFFFE082),
                                            weight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Chance & Bar
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        '%$chance',
                                        textAlign: TextAlign.center,
                                        style: _cellStyle(
                                          size: 12,
                                          color: chanceC,
                                          weight: FontWeight.w900,
                                          align: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(99),
                                        child: SizedBox(
                                          height: 3,
                                          width: 48,
                                          child: LinearProgressIndicator(
                                            value: chance / 100.0,
                                            backgroundColor:
                                                Colors.white.withValues(alpha: 0.1),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(chanceC),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Risk label tag
                                Expanded(
                                  flex: 3,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: riskC.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(99),
                                        border: Border.all(
                                          color: riskC.withValues(alpha: 0.4),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        rLabel,
                                        style: _cellStyle(
                                          size: 9,
                                          color: riskC,
                                          weight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Sub-row: Catalyst boost & Penalty detail
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF090D18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 11,
                                    color: Color(0xFF7BA4FF),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      catalystHint,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: Color(0xFFBDD2FF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    penalty,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: riskC.withValues(alpha: 0.85),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
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

            // Catalyst Info Collapsible Drawer / Guide
            if (_showCatalystGuide)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131929),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF5B8FFF).withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF7BA4FF)),
                        SizedBox(width: 6),
                        Text(
                          'Aion 2 Güçlendirme Katalizör Kılavuzu',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFBDD2FF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Manastone & Godstone: +%5 ile +%25 ek başarı sağlar.\n'
                      '• Pristine/Felicitous: 1.75× ~ 2.0× çarpan sağlar.\n'
                      '• Aegis Koruma Mührü: +11 üzeri yükseltmelerde parçalanmayı %100 engeller.',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.mutedTitanium.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

            // Bottom Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Row(
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _showCatalystGuide = !_showCatalystGuide);
                    },
                    icon: Icon(
                      _showCatalystGuide
                          ? Icons.expand_less_rounded
                          : Icons.lightbulb_outline_rounded,
                      size: 15,
                      color: AppColors.liquidGold,
                    ),
                    label: Text(
                      _showCatalystGuide ? 'Gizle' : 'Katalizör Rehberi',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.liquidGold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0x55FFB800)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C2538),
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                      ),
                      child: Text(
                        'Kapat',
                        style: _cellStyle(
                          size: 12.5,
                          color: AppColors.textPrimary,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierSummaryBadge({
    required String title,
    required String range,
    required String rate,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1422),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              range,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              rate,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
