import 'package:flutter/material.dart';

import '../../../components/common/gkk_tab_bar.dart';
import '../../../models/dungeon_model.dart';
import '../dungeon_zone_data.dart';

class DungeonZoneTabBar extends StatelessWidget {
  const DungeonZoneTabBar({
    super.key,
    required this.controller,
    required this.dungeons,
    required this.zoneFor,
  });

  final TabController controller;
  final List<DungeonData> dungeons;
  final int Function(DungeonData) zoneFor;

  @override
  Widget build(BuildContext context) {
    return GkkTabBar(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      tabs: <Widget>[
        GkkTabBar.labeledTab(child: const Text('Tümü')),
        ...kDungeonZones.map((DungeonZone zone) {
          final int count = dungeons.where((DungeonData d) => zoneFor(d) == zone.number).length;
          return GkkTabBar.labeledTab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(zone.icon, size: 12, color: zone.color),
                const SizedBox(width: 4),
                Text('B${zone.number}'),
                if (count > 0) ...<Widget>[
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
        }),
      ],
    );
  }
}

class DungeonZoneBanner extends StatelessWidget {
  const DungeonZoneBanner({super.key, required this.zone, required this.dungeonCount});

  final DungeonZone zone;
  final int dungeonCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: zone.color.withValues(alpha: 0.07),
        border: Border.all(color: zone.color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          Icon(zone.icon, size: 18, color: zone.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  zone.name,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: zone.color),
                ),
                Text(
                  'Bölge ${zone.number}  •  $dungeonCount zindan  •  #${zone.min}–${zone.max}',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
