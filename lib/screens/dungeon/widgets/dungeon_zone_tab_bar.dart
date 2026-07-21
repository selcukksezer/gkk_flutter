import 'package:flutter/material.dart';

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
    return SizedBox(
      height: 44,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF1A2540),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        labelColor: const Color(0xFFF0F4FF),
        unselectedLabelColor: const Color(0xFF4A5880),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        tabs: <Widget>[
          const Tab(text: 'Tümü'),
          ...kDungeonZones.map((DungeonZone zone) {
            final int count = dungeons.where((DungeonData d) => zoneFor(d) == zone.number).length;
            return Tab(
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
      ),
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
