import 'package:flutter/material.dart';

import 'mekan_design.dart';
import 'mekan_theme.dart';

class MekanTypeArtCard extends StatelessWidget {
  const MekanTypeArtCard({
    super.key,
    required this.info,
    required this.selected,
    required this.locked,
    required this.affordable,
    required this.levelOk,
    required this.onTap,
    this.onLockedTap,
  });

  final MekanTypeInfo info;
  final bool selected;
  final bool locked;
  final bool affordable;
  final bool levelOk;
  final VoidCallback? onTap;
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = MekanPalette.accent(info.type);
    return PressableScale(
      onTap: locked ? onLockedTap : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accent : Colors.white.withValues(alpha: 0.08),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? <BoxShadow>[BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 18)]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            Container(
              height: 78,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[accent.withValues(alpha: 0.38), MekanPalette.navy],
                ),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Icon(MekanPalette.typeIcon(info.type), size: 96, color: accent.withValues(alpha: 0.20)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: <Widget>[
                        MekanTypeBadge(typeKey: info.type, size: 50),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                info.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: MekanPalette.textHi,
                                ),
                              ),
                              if (mekanSupportsPvp(info.type))
                                const Text(
                                  'PvP Arena destekli',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: MekanPalette.textMid,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle_rounded, color: accent, size: 26)
                        else if (locked)
                          const Icon(Icons.lock_rounded, color: MekanPalette.textLow, size: 22),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              color: MekanPalette.surface.withValues(alpha: 0.6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    info.description,
                    style: const TextStyle(fontSize: 12.5, color: MekanPalette.textMid, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      GlowChip(
                        icon: Icons.paid_rounded,
                        label: formatMekanGold(info.cost),
                        color: affordable ? MekanPalette.gold : MekanPalette.ruby,
                      ),
                      const SizedBox(width: 8),
                      GlowChip(
                        icon: Icons.military_tech_rounded,
                        label: 'Sv ${info.reqLevel}',
                        color: levelOk ? MekanPalette.neon : MekanPalette.ruby,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
