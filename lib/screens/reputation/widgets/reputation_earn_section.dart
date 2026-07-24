import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/reputation_model.dart';
import 'reputation_design.dart';

class ReputationEarnSection extends StatelessWidget {
  ReputationEarnSection({
    super.key,
    List<ReputationEarnSource>? sources,
  }) : sources = sources ?? defaultEarnSources();

  final List<ReputationEarnSource> sources;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const ReputationSectionTitle(
          title: 'NEREDEN KAZANIRSIN',
          subtitle: 'Oyun döngüsüne bağlı itibar kaynakları',
        ),
        const SizedBox(height: 12),
        ...List<Widget>.generate(sources.length, (int i) {
          final ReputationEarnSource src = sources[i];
          final Color accent = src.accent ?? MekanPalette.aqua;
          return Padding(
            padding: EdgeInsets.only(bottom: i < sources.length - 1 ? 8 : 0),
            child: ReputationSlideIn(
              index: i,
              child: PressableScale(
                onTap: () => context.push(src.route),
                child: NeonPanel(
                  accent: accent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  radius: 14,
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accent.withValues(alpha: 0.35)),
                          boxShadow: <BoxShadow>[
                            BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 12),
                          ],
                        ),
                        child: Icon(src.icon, color: accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              src.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: MekanPalette.textHi,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              src.subtitle,
                              style: const TextStyle(fontSize: 11, color: MekanPalette.textMid),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            src.repRange,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: MekanPalette.gold.withValues(alpha: 0.95),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: MekanPalette.textLow, size: 18),
                        ],
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
