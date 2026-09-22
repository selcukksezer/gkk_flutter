import 'package:flutter/material.dart';

import '../../../components/common/gkk_tab_bar.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../models/dungeon_model.dart';
import '../dungeon_zone_data.dart';

class DungeonZoneTabBar extends StatelessWidget {
  const DungeonZoneTabBar({
    super.key,
    required this.controller,
    required this.dungeons,
    required this.zoneFor,
    required this.playerLevel,
  });

  final TabController controller;
  final List<DungeonData> dungeons;
  final int Function(DungeonData) zoneFor;
  final int playerLevel;

  @override
  Widget build(BuildContext context) {
    return GkkTabBar(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      tabs: <Widget>[
        GkkTabBar.labeledTab(child: const Text('Tümü')),
        ...kDungeonZones.map((DungeonZone zone) {
          final int count = dungeons.where((DungeonData d) => zoneFor(d) == zone.number).length;
          final bool locked = !isZoneUnlockedForLevel(zone, playerLevel);
          final Color tabColor = locked ? zone.color.withValues(alpha: 0.45) : zone.color;
          Widget tab = GkkTabBar.labeledTab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  locked ? Icons.lock_outline : zone.icon,
                  size: 12,
                  color: tabColor,
                ),
                const SizedBox(width: 4),
                Text('B${zone.number}'),
                if (locked) ...<Widget>[
                  const SizedBox(width: 3),
                  Text(
                    'Lv${zone.requiredLevel}',
                    style: TextStyle(
                      fontSize: 9,
                      color: tabColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ] else if (count > 0) ...<Widget>[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: zone.color.withValues(alpha: 0.2),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(fontSize: 9, color: zone.color, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          );
          if (zone.number == 1) {
            tab = TutorialAnchorScope(
              id: TutorialAnchorId.dungeonZone1Tab,
              child: tab,
            );
          }
          return tab;
        }),
      ],
    );
  }
}

class DungeonZoneBanner extends StatelessWidget {
  const DungeonZoneBanner({
    super.key,
    required this.zone,
    required this.dungeonCount,
    required this.playerLevel,
  });

  final DungeonZone zone;
  final int dungeonCount;
  final int playerLevel;

  @override
  Widget build(BuildContext context) {
    final bool locked = !isZoneUnlockedForLevel(zone, playerLevel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: zone.color.withValues(alpha: locked ? 0.04 : 0.07),
        border: Border.all(
          color: locked
              ? const Color(0xFFFBBF24).withValues(alpha: 0.45)
              : zone.color.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            locked ? Icons.lock_outline : zone.icon,
            size: 18,
            color: locked ? const Color(0xFFFBBF24) : zone.color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  zone.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: locked ? const Color(0xFFFBBF24) : zone.color,
                  ),
                ),
                Text(
                  locked
                      ? 'Bölge kilitli  •  Lv.${zone.requiredLevel} gerekli  •  Senin: Lv.$playerLevel'
                      : 'Bölge ${zone.number}  •  $dungeonCount zindan  •  #${zone.min}–${zone.max}',
                  style: TextStyle(
                    fontSize: 11,
                    color: locked ? const Color(0xFFFBBF24).withValues(alpha: 0.85) : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
