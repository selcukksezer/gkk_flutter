import 'package:flutter/material.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../models/reputation_model.dart';
import 'reputation_design.dart';

class ReputationShopGrid extends StatelessWidget {
  const ReputationShopGrid({
    super.key,
    required this.items,
    required this.globalRep,
    required this.purchasingId,
    required this.onPurchase,
  });

  final List<ReputationShopItem> items;
  final int globalRep;
  final String? purchasingId;
  final void Function(ReputationShopItem item) onPurchase;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const ReputationSectionTitle(
          title: 'İTİBAR MAĞAZASI',
          subtitle: 'Kazandığın itibarı güce çevir',
        ),
        const SizedBox(height: 12),
        ...List<Widget>.generate(items.length, (int i) {
          final ReputationShopItem item = items[i];
          final Color border = rarityBorderColor(item.rarity);
          final bool affordable = canAffordShopItem(item: item, globalRep: globalRep);
          final bool loading = purchasingId == item.id;

          return Padding(
            padding: EdgeInsets.only(bottom: i < items.length - 1 ? 10 : 0),
            child: ReputationSlideIn(
              index: i,
              child: PressableScale(
                enabled: affordable && !loading,
                onTap: () => onPurchase(item),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border.withValues(alpha: 0.55), width: 1.2),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        MekanPalette.navy.withValues(alpha: 0.95),
                        MekanPalette.void_.withValues(alpha: 0.98),
                      ],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: border.withValues(alpha: 0.12), blurRadius: 16),
                    ],
                  ),
                  child: Stack(
                    children: <Widget>[
                      const Positioned.fill(
                        child: CustomPaint(
                          painter: DotGridPainter(spacing: 16, dotOpacity: 0.045),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: border.withValues(alpha: 0.12),
                                border: Border.all(color: border.withValues(alpha: 0.4)),
                              ),
                              child: loading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : Icon(shopIconForKey(item.iconKey), color: border, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: MekanPalette.textHi,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: border.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.rarity.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                            color: border,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description,
                                    style: const TextStyle(fontSize: 11, color: MekanPalette.textMid),
                                  ),
                                  if (item.durationMinutes != null) ...<Widget>[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.durationMinutes} dk süre',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: MekanPalette.solar.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: affordable ? MekanPalette.gold : MekanPalette.ruby,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${item.costAmount}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: affordable ? MekanPalette.gold : MekanPalette.ruby,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'İtibar',
                                  style: TextStyle(fontSize: 9, color: MekanPalette.textLow),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
