import 'package:flutter/material.dart';

String inferDungeonItemRarity(String itemIdOrName) {
  final String lower = itemIdOrName.toLowerCase();
  if (lower.contains('mythic')) return 'mythic';
  if (lower.contains('legendary')) return 'legendary';
  if (lower.contains('epic')) return 'epic';
  if (lower.contains('rare')) return 'rare';
  if (lower.contains('uncommon')) return 'uncommon';
  return 'common';
}

String formatDungeonItemName(String raw) {
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .map((String w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

Color dungeonRarityColor(String rarity) {
  switch (rarity.toLowerCase()) {
    case 'uncommon':
      return const Color(0xFF22C55E);
    case 'rare':
      return const Color(0xFF3B82F6);
    case 'epic':
      return const Color(0xFFA855F7);
    case 'legendary':
      return const Color(0xFFF59E0B);
    case 'mythic':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF94A3B8);
  }
}

bool isEpicPlusRarity(String rarity) {
  final String r = rarity.toLowerCase();
  return r == 'epic' || r == 'legendary' || r == 'mythic';
}

int raritySortWeight(String rarity) {
  switch (rarity.toLowerCase()) {
    case 'mythic':
      return 5;
    case 'legendary':
      return 4;
    case 'epic':
      return 3;
    case 'rare':
      return 2;
    case 'uncommon':
      return 1;
    default:
      return 0;
  }
}

List<String> zoneFlavorLines(int zone) {
  switch (zone) {
    case 1:
      return <String>[
        'Orman gölgeleri hareket ediyor...',
        'Yosunlu taşlar arasında ayak sesleri...',
        'Silva Obscura derinliklerine dalıyorsun.',
      ];
    case 2:
      return <String>[
        'Mağara duvarları yankılanıyor...',
        'Soğuk hava nefesini kesiyor...',
        'Caverna Profunda seni bekliyor.',
      ];
    case 3:
      return <String>[
        'Alevler yükseliyor...',
        'Kül rüzgarı yüzüne vuruyor...',
        'Desertum Ignis ateşi test ediyor.',
      ];
    case 4:
      return <String>[
        'Fırtına uğultusu artıyor...',
        'Yıldırımlar yolu aydınlatıyor...',
        'Mons Tempestatis öfkeli.',
      ];
    case 5:
      return <String>[
        'Inferno nefesi hissediliyor...',
        'Lav damlaları yanıyor...',
        'Infernum Subterra derinlerinde savaş.',
      ];
    case 6:
      return <String>[
        'Gökyüzü parçalanıyor...',
        'Eterik enerji dalgalanıyor...',
        'Caelum Fractum sınırları zorluyor.',
      ];
    case 7:
      return <String>[
        'Efsanevi güç uyanıyor...',
        'Antik runeler parlıyor...',
        'Mythica Pericula son sınav.',
      ];
    default:
      return <String>[
        'Karanlık koridorlara giriyorsun...',
        'Tehdit yaklaşıyor...',
        'Savaş başlıyor.',
      ];
  }
}
