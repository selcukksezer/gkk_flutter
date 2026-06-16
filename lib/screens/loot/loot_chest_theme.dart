import 'package:flutter/material.dart';

class LootChestTheme {
  const LootChestTheme({
    required this.id,
    required this.assetPath,
    required this.displayName,
    required this.radialCenter,
    required this.radialEdge,
    required this.borderColor,
    required this.accentColor,
    required this.fullscreenBgStart,
    required this.fullscreenBgEnd,
    this.shortDescription = '',
  });

  final String id;
  final String assetPath;
  final String displayName;
  final Color radialCenter;
  final Color radialEdge;
  final Color borderColor;
  final Color accentColor;
  final Color fullscreenBgStart;
  final Color fullscreenBgEnd;
  final String shortDescription;
}

const LootChestTheme kDefaultLootChestTheme = LootChestTheme(
  id: 'default',
  assetPath: 'assets/elements/redcase512px.png',
  displayName: 'Kasa',
  radialCenter: Color(0xFF8B0000),
  radialEdge: Color(0xFF1A0000),
  borderColor: Color(0x4DFF0000),
  accentColor: Color(0xFFE50000),
  fullscreenBgStart: Color(0xFF3A0A0A),
  fullscreenBgEnd: Color(0xFF0A0202),
  shortDescription: 'Efsanevi ödüller seni bekliyor.',
);

const List<LootChestTheme> kLootChestThemes = <LootChestTheme>[
  LootChestTheme(
    id: 'kasawitch',
    assetPath: 'assets/chest/kasawitch.png',
    displayName: 'Cadı Kasası',
    radialCenter: Color(0xFF5B2D82),
    radialEdge: Color(0xFF1A0A2E),
    borderColor: Color(0x66C084FC),
    accentColor: Color(0xFFF97316),
    fullscreenBgStart: Color(0xFF2D1B4E),
    fullscreenBgEnd: Color(0xFF0F0618),
    shortDescription: 'Büyülü iksirler ve cadı hazineleri.',
  ),
  LootChestTheme(
    id: 'kasauzay',
    assetPath: 'assets/chest/kasauzay.png',
    displayName: 'Uzay Kasası',
    radialCenter: Color(0xFF1E3A8A),
    radialEdge: Color(0xFF020617),
    borderColor: Color(0x6622D3EE),
    accentColor: Color(0xFF22D3EE),
    fullscreenBgStart: Color(0xFF0F172A),
    fullscreenBgEnd: Color(0xFF020617),
    shortDescription: 'Kozmik kristaller ve uzay hazineleri.',
  ),
  LootChestTheme(
    id: 'kasasekerleme',
    assetPath: 'assets/chest/kasasekerleme.png',
    displayName: 'Şekerleme Kasası',
    radialCenter: Color(0xFFFF6B9D),
    radialEdge: Color(0xFF4A1942),
    borderColor: Color(0x66FBCFE8),
    accentColor: Color(0xFFFBBF24),
    fullscreenBgStart: Color(0xFF5C1A3D),
    fullscreenBgEnd: Color(0xFF1F0A18),
    shortDescription: 'Tatlı sürprizler ve altın şekerler.',
  ),
  LootChestTheme(
    id: 'kasaokyanus',
    assetPath: 'assets/chest/kasaokyanus.png',
    displayName: 'Okyanus Kasası',
    radialCenter: Color(0xFF0E7490),
    radialEdge: Color(0xFF042F3A),
    borderColor: Color(0x662DD4BF),
    accentColor: Color(0xFF2DD4BF),
    fullscreenBgStart: Color(0xFF064E5E),
    fullscreenBgEnd: Color(0xFF021A22),
    shortDescription: 'Mercan hazineleri ve deniz altı ödülleri.',
  ),
  LootChestTheme(
    id: 'kasamarshmallow',
    assetPath: 'assets/chest/kasamarshmallow.png',
    displayName: 'Marshmallow Kasası',
    radialCenter: Color(0xFFF9A8D4),
    radialEdge: Color(0xFF3D1F2E),
    borderColor: Color(0x66FBCFE8),
    accentColor: Color(0xFFEC4899),
    fullscreenBgStart: Color(0xFF4A2038),
    fullscreenBgEnd: Color(0xFF1A0B14),
    shortDescription: 'Yumuşak tatlılar ve pembe sürprizler.',
  ),
  LootChestTheme(
    id: 'kasalav',
    assetPath: 'assets/chest/kasalav.png',
    displayName: 'Lav Kasası',
    radialCenter: Color(0xFFB45309),
    radialEdge: Color(0xFF1C0A05),
    borderColor: Color(0x66FB923C),
    accentColor: Color(0xFFEA580C),
    fullscreenBgStart: Color(0xFF3D1208),
    fullscreenBgEnd: Color(0xFF0A0302),
    shortDescription: 'Ateş kristalleri ve volkanik güç.',
  ),
  LootChestTheme(
    id: 'kasakorsan',
    assetPath: 'assets/chest/kasakorsan.png',
    displayName: 'Korsan Kasası',
    radialCenter: Color(0xFF1D4ED8),
    radialEdge: Color(0xFF0C1A3A),
    borderColor: Color(0x663B82F6),
    accentColor: Color(0xFFFBBF24),
    fullscreenBgStart: Color(0xFF1E3A5F),
    fullscreenBgEnd: Color(0xFF0A1428),
    shortDescription: 'Altın paralar ve korsan hazineleri.',
  ),
  LootChestTheme(
    id: 'kasabuzdevri',
    assetPath: 'assets/chest/kasabuzdevri.png',
    displayName: 'Buz Devri Kasası',
    radialCenter: Color(0xFF38BDF8),
    radialEdge: Color(0xFF0C2340),
    borderColor: Color(0x6693C5FD),
    accentColor: Color(0xFF7DD3FC),
    fullscreenBgStart: Color(0xFF0C4A6E),
    fullscreenBgEnd: Color(0xFF031525),
    shortDescription: 'Buz kristalleri ve kutup hazineleri.',
  ),
  LootChestTheme(
    id: 'kasaamazon',
    assetPath: 'assets/chest/kasaamazon.png',
    displayName: 'Amazon Kasası',
    radialCenter: Color(0xFF15803D),
    radialEdge: Color(0xFF052E16),
    borderColor: Color(0x664ADE80),
    accentColor: Color(0xFF22C55E),
    fullscreenBgStart: Color(0xFF14532D),
    fullscreenBgEnd: Color(0xFF052E16),
    shortDescription: 'Orman hazineleri ve tropik ödüller.',
  ),
  LootChestTheme(
    id: 'kasacevher',
    assetPath: 'assets/chest/kasacevher.png',
    displayName: 'Cevher Kasası',
    radialCenter: Color(0xFF7C3AED),
    radialEdge: Color(0xFF1E1033),
    borderColor: Color(0x66C084FC),
    accentColor: Color(0xFFD946EF),
    fullscreenBgStart: Color(0xFF3B1D6E),
    fullscreenBgEnd: Color(0xFF120A22),
    shortDescription: 'Steampunk cevherler ve nadir mücevherler.',
  ),
  LootChestTheme(
    id: 'kasadeniz',
    assetPath: 'assets/chest/kasadeniz.png',
    displayName: 'Deniz Kasası',
    radialCenter: Color(0xFF06B6D4),
    radialEdge: Color(0xFF083344),
    borderColor: Color(0x6622D3EE),
    accentColor: Color(0xFF22D3EE),
    fullscreenBgStart: Color(0xFF0E5C6E),
    fullscreenBgEnd: Color(0xFF032028),
    shortDescription: 'Deniz canlıları ve turkuaz hazineler.',
  ),
];

LootChestTheme resolveLootChestTheme(int boxIndex, {String? artAsset}) {
  if (artAsset != null && artAsset.isNotEmpty) {
    final String normalized = artAsset.toLowerCase();
    for (final LootChestTheme theme in kLootChestThemes) {
      if (normalized.contains(theme.id)) {
        return theme;
      }
    }
  }

  if (boxIndex >= 0 && boxIndex < kLootChestThemes.length) {
    return kLootChestThemes[boxIndex];
  }

  return kDefaultLootChestTheme;
}

String lootDropCategoryLabel(String itemId) {
  final String id = itemId.toLowerCase();
  if (id.startsWith('wpn_')) return 'SİLAH';
  if (id.startsWith('head_')) return 'KASK';
  if (id.startsWith('chest_')) return 'ZIRH';
  if (id.startsWith('legs_')) return 'BACAK';
  if (id.startsWith('boots_')) return 'AYAKKABI';
  if (id.startsWith('gloves_')) return 'ELDİVEN';
  if (id.startsWith('ring_')) return 'YÜZÜK';
  if (id.startsWith('neck_')) return 'AKSESUAR';
  if (id.contains('potion')) return 'İKSİR';
  if (id.contains('rune')) return 'RUNE';
  return 'EŞYA';
}
