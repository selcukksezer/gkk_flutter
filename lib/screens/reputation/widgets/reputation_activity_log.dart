import 'package:flutter/material.dart';

import '../../../models/reputation_model.dart';
import 'reputation_design.dart';

class ReputationActivityLog extends StatelessWidget {
  const ReputationActivityLog({
    super.key,
    required this.entries,
  });

  final List<ReputationActivityEntry> entries;

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final Duration d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Az önce';
    if (d.inHours < 1) return '${d.inMinutes} dk önce';
    if (d.inDays < 1) return '${d.inHours} sa önce';
    return '${d.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const ReputationSectionTitle(
          title: 'SON HAREKETLER',
          subtitle: 'Kazanç ve harcamalar',
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          NeonPanel(
            accent: MekanPalette.titanium,
            padding: const EdgeInsets.all(20),
            child: const Text(
              'Henüz kayıt yok. PvP, zindan veya mağaza ile başla.',
              textAlign: TextAlign.center,
              style: TextStyle(color: MekanPalette.textMid, fontSize: 12),
            ),
          )
        else
          ...List<Widget>.generate(entries.length, (int i) {
            final ReputationActivityEntry e = entries[i];
            final Color c = e.isEarn ? MekanPalette.neon : MekanPalette.fuchsia;
            return Padding(
              padding: EdgeInsets.only(bottom: i < entries.length - 1 ? 6 : 0),
              child: ReputationSlideIn(
                index: i,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: MekanPalette.obsidian.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        e.isEarn ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 16,
                        color: c,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              e.displaySource(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MekanPalette.textHi,
                              ),
                            ),
                            Text(
                              _timeAgo(e.createdAt),
                              style: const TextStyle(fontSize: 10, color: MekanPalette.textLow),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${e.isEarn ? '+' : '-'}${e.amount}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: c,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
