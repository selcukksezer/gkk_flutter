import 'package:flutter/material.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../theme/app_colors.dart';
import '../facility_detail_data.dart';
import 'facilities_ui.dart';
import 'facility_detail_design.dart';

class FacRaritySimulatorAccordion extends StatefulWidget {
  const FacRaritySimulatorAccordion({super.key, required this.currentLevel});

  final int currentLevel;

  @override
  State<FacRaritySimulatorAccordion> createState() => _FacRaritySimulatorAccordionState();
}

class _FacRaritySimulatorAccordionState extends State<FacRaritySimulatorAccordion> {
  late final Set<int> _expandedLevels;

  @override
  void initState() {
    super.initState();
    _expandedLevels = <int>{widget.currentLevel};
  }

  void _toggleLevel(int level) {
    setState(() {
      if (_expandedLevels.contains(level)) {
        _expandedLevels.remove(level);
      } else {
        _expandedLevels.add(level);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DottedPanel(
      padding: FacilitiesUi.panelPadding,
      borderRadius: 12,
      borderColor: AppColors.cyberFuchsia.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          facilitiesSectionTitle('Drop Simülasyonu', trailing: 'Lv.1–10'),
          const SizedBox(height: FacilitiesUi.gapSm),
          ...List<Widget>.generate(10, (int idx) {
            final int rarityLevel = idx + 1;
            final bool isCurrent = rarityLevel == widget.currentLevel;
            final bool isExpanded = _expandedLevels.contains(rarityLevel);
            final Map<String, int> weights = facilityRarityWeightsAtLevel(rarityLevel);
            final int total = weights.values.fold<int>(0, (int sum, int v) => sum + v);

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.liquidGold.withValues(alpha: 0.45)
                        : AppColors.mutedTitanium.withValues(alpha: 0.18),
                  ),
                  color: isCurrent
                      ? AppColors.liquidGold.withValues(alpha: 0.08)
                      : AppColors.darkObsidian.withValues(alpha: 0.45),
                ),
                child: Column(
                  children: <Widget>[
                    InkWell(
                      onTap: () => _toggleLevel(rarityLevel),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(
                          children: <Widget>[
                            Text(
                              'Lv.$rarityLevel',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (isCurrent) ...<Widget>[
                              const SizedBox(width: 8),
                              Text(
                                'Mevcut Seviye',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.liquidGold.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: AppColors.mutedTitanium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: kFacilityResourceRarities.map((String rarity) {
                            final double pct = total > 0 ? ((weights[rarity] ?? 0) / total) * 100 : 0;
                            final int decimals =
                                (rarity == 'common' || rarity == 'uncommon' || rarity == 'rare') ? 0 : 1;

                            return Container(
                              width: (MediaQuery.of(context).size.width - 84) / 2,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.mutedTitanium.withValues(alpha: 0.2),
                                ),
                                color: AppColors.carbonVoid.withValues(alpha: 0.55),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text(
                                        facilityRarityTitle(rarity),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.mutedTitanium,
                                        ),
                                      ),
                                      Text(
                                        '${pct.toStringAsFixed(decimals)}%',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: (pct.clamp(0, 100)) / 100,
                                    minHeight: 4,
                                    backgroundColor: AppColors.darkObsidian,
                                    color: facRarityAccent(rarity),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
