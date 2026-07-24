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

class ReputationFactionStrip extends StatelessWidget {
  const ReputationFactionStrip({
    super.key,
    required this.factions,
  });

  final List<FactionReputation> factions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const ReputationSectionTitle(
          title: 'FRAKSİYON İTİBARI',
          subtitle: '0–100 — oyun içi kazanımlar',
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kReputationFactions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int i) {
              final ReputationFactionDef def = kReputationFactions[i];
              final int rep = factions
                      .where((FactionReputation f) => f.factionId == def.id)
                      .map((FactionReputation f) => f.reputation)
                      .firstOrNull ??
                  0;
              final Color tier = factionTierColor(rep);
              return Container(
                  width: 128,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: <Color>[
                        MekanPalette.navy.withValues(alpha: 0.9),
                        MekanPalette.void_.withValues(alpha: 0.95),
                      ],
                    ),
                    border: Border.all(color: def.accent.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(def.icon, style: const TextStyle(fontSize: 18)),
                      const Spacer(),
                      Text(
                        def.name.split(' ').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: MekanPalette.textHi,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: rep / 100,
                                minHeight: 4,
                                backgroundColor: MekanPalette.obsidian,
                                valueColor: AlwaysStoppedAnimation<Color>(tier),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$rep',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: tier),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
            },
          ),
        ),
      ],
    );
  }
}
