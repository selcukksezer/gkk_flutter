import 'package:flutter/material.dart';

import '../../../core/utils/gold_format.dart';
import '../../../models/dungeon_model.dart';
import '../dungeon_zone_data.dart';

class _LootRarity {
  const _LootRarity(this.label, this.color);
  final String label;
  final Color color;
}

class DungeonLootDialog extends StatelessWidget {
  const DungeonLootDialog({super.key, required this.dungeon, this.zone});

  final DungeonData dungeon;
  final DungeonZone? zone;

  String _fmtGold(int value) => formatCompactGold(value);

  String _pct(double chance) => '${(chance * 100).toStringAsFixed(0)}%';

  _LootRarity _rarityForKey(String key) {
    switch (key.toLowerCase()) {
      case 'mythic':
        return const _LootRarity('Mitik', Color(0xFFF43F5E));
      case 'legendary':
        return const _LootRarity('Efsanevi', Color(0xFFFBBF24));
      case 'epic':
        return const _LootRarity('Epik', Color(0xFFA78BFA));
      case 'rare':
        return const _LootRarity('Nadir', Color(0xFF60A5FA));
      case 'uncommon':
        return const _LootRarity('Sıradışı', Color(0xFF22C55E));
      default:
        return const _LootRarity('Sıradan', Color(0xFF6B7A99));
    }
  }

  Widget _sectionTitle(String text, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: accent.withValues(alpha: 0.85),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _dropChanceRow(String label, double chance, Color accent) {
    if (chance <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFFCCD4F0)),
            ),
          ),
          Text(
            _pct(chance),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rarityRow(String key, double weight) {
    final _LootRarity rarity = _rarityForKey(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 18,
            margin: const EdgeInsets.only(right: 8),
            color: rarity.color.withValues(alpha: 0.75),
          ),
          Expanded(
            child: Text(
              rarity.label,
              style: const TextStyle(fontSize: 12, color: Color(0xFFCCD4F0)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: rarity.color.withValues(alpha: 0.12),
              border: Border.all(color: rarity.color.withValues(alpha: 0.35)),
            ),
            child: Text(
              _pct(weight),
              style: TextStyle(
                fontSize: 10,
                color: rarity.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = zone?.color ?? const Color(0xFF5B8FFF);
    const List<String> rarityOrder = <String>[
      'mythic',
      'legendary',
      'epic',
      'rare',
      'uncommon',
      'common',
    ];

    final List<MapEntry<String, double>> rarityRows = <MapEntry<String, double>>[];
    for (final String key in rarityOrder) {
      final double? weight = dungeon.rarityWeights[key];
      if (weight != null && weight > 0) {
        rarityRows.add(MapEntry<String, double>(key, weight));
      }
    }
    dungeon.rarityWeights.forEach((String key, double weight) {
      if (rarityOrder.contains(key) || weight <= 0) return;
      rarityRows.add(MapEntry<String, double>(key, weight));
    });

    final bool hasDropChances = dungeon.equipmentDropChance > 0 ||
        dungeon.resourceDropChance > 0 ||
        dungeon.scrollDropChance > 0 ||
        dungeon.catalystDropChance > 0;

    return AlertDialog(
      backgroundColor: const Color(0xFF0D1525),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.3)),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            dungeon.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE8EDF8),
            ),
          ),
          Text(
            'Ödül Önizlemesi',
            style: TextStyle(fontSize: 11, color: accent.withValues(alpha: 0.8)),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFF5C842).withValues(alpha: 0.10),
                border: Border.all(color: const Color(0xFFF5C842).withValues(alpha: 0.30)),
              ),
              child: Text(
                'Altın aralığı: ${_fmtGold(dungeon.minGold)} - ${_fmtGold(dungeon.maxGold)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFF5C842),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (hasDropChances) ...<Widget>[
              _sectionTitle('DROP ŞANSLARI', accent),
              _dropChanceRow('Ekipman', dungeon.equipmentDropChance, accent),
              _dropChanceRow('Kaynak / Materyal', dungeon.resourceDropChance, accent),
              _dropChanceRow('Scroll', dungeon.scrollDropChance, accent),
              _dropChanceRow('Katalizör', dungeon.catalystDropChance, accent),
            ],
            if (rarityRows.isNotEmpty) ...<Widget>[
              _sectionTitle('NADİRLİK DAĞILIMI (eşya düştüğünde)', accent),
              ...rarityRows.map(
                (MapEntry<String, double> e) => _rarityRow(e.key, e.value),
              ),
            ],
            if (!hasDropChances && rarityRows.isEmpty)
              const Text(
                'Bu zindan için loot bilgisi bulunamadı.',
                style: TextStyle(color: Color(0xFF4A5880)),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.black,
          ),
          child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
