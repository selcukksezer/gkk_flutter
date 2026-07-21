import 'package:flutter/material.dart';

import '../../models/dungeon_model.dart';

class DungeonZone {
  const DungeonZone({
    required this.number,
    required this.name,
    required this.color,
    required this.icon,
    required this.min,
    required this.max,
  });

  final int number;
  final String name;
  final Color color;
  final IconData icon;
  final int min;
  final int max;
}

const List<DungeonZone> kDungeonZones = <DungeonZone>[
  DungeonZone(number: 1, name: 'Gölgeli Orman', color: Color(0xFF4ADE80), icon: Icons.park, min: 1, max: 10),
  DungeonZone(number: 2, name: 'Derin Mağara', color: Color(0xFF94A3B8), icon: Icons.terrain, min: 11, max: 20),
  DungeonZone(number: 3, name: 'Ateş Çölü', color: Color(0xFFF97316), icon: Icons.local_fire_department, min: 21, max: 30),
  DungeonZone(number: 4, name: 'Fırtına Dağı', color: Color(0xFF60A5FA), icon: Icons.thunderstorm, min: 31, max: 40),
  DungeonZone(number: 5, name: 'Yeraltı Cehennemi', color: Color(0xFFEF4444), icon: Icons.whatshot, min: 41, max: 50),
  DungeonZone(number: 6, name: 'Kırık Gökyüzü', color: Color(0xFFA78BFA), icon: Icons.cloud_queue, min: 51, max: 60),
  DungeonZone(number: 7, name: 'Efsanevi Tehlikeler', color: Color(0xFFFBBF24), icon: Icons.auto_awesome, min: 61, max: 65),
];

int zoneForDungeon(DungeonData dungeon) {
  final RegExpMatch? match = RegExp(r'dng_0*(\d+)').firstMatch(dungeon.dungeonId);
  if (match == null) return 0;
  final int num = int.tryParse(match.group(1)!) ?? 0;
  for (final DungeonZone zone in kDungeonZones) {
    if (num >= zone.min && num <= zone.max) return zone.number;
  }
  return 0;
}

DungeonZone? zoneDataFor(int number) {
  if (number == 0) return null;
  try {
    return kDungeonZones.firstWhere((DungeonZone zone) => zone.number == number);
  } catch (_) {
    return null;
  }
}
